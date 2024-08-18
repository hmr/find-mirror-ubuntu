#!env bash

# vim: set noet syn=bash ft=sh ff=unix fenc=utf-8 ts=2 sw=0 : # GPP default modeline for zsh script
# shellcheck shell=bash disable=SC1091,SC2155,SC3010,SC3021,SC3037 source=${GPP_HOME}

# find-mirror-ubuntu.bash
# Copyright (C) 2022 hmr
#
# AUTHOR: hmr
# ORIGIN: 2022-08-03
# LICENSE: GPL3.0

if [[ $# -lt 3 ]]; then
	echo "Usage: $0 <arch> <dist> <repo> [<filename>]"
	echo
	echo "  <arch>: Architecture (eg. amd64, i386, arm64, armhf, powerpc, s390, riscv64 ...)"
	echo "  <dist>: Ubuntu version name (eg. focal, jammy, noble ...)"
	echo "  <repo>: Repository type (main, restricted, universe or multiverse)"
	echo "  <filename>: Instead of searching mirror sites, you can use existing file."
	exit
fi

# Delete temp file finally
function del_temp_file() {
	[[ -n "${TEMP_FILE}" && ${DEBUG} -lt 1 ]] && rm "${TEMP_FILE}"
	exit
}

# Get number of CPU cores
function get_cpu_cores() {
	local CPU_CORES

	case "$(uname)" in
		Linux)
			if [ -f /proc/cpuinfo ]; then
				CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
			elif command -v nproc > /dev/null; then
				CPU_CORES=$(nproc)
			fi
			;;
		Darwin)
			CPU_CORES=$(sysctl -n hw.logicalcpu)
			;;
		CYGWIN*|MINGW32*|MSYS*|MINGW*)
			# Windows (Git Bash, Cygwin, MinGW)
			CPU_CORES=$(wmic cpu get NumberOfLogicalProcessors | awk 'NR==2')
			;;
		*)
			echo "Unsupported OS"
			return 1
			;;
	esac

	echo "${CPU_CORES}"
}

# Check the environment
function check_env() {
	if [[ ! $(curl -V | head -n 1) =~ curl ]]; then
		echo "Error: This program needs cURL." > /dev/stderr
		exit 1
	fi
	if [[ $(grep -V) =~ "BSD grep" ]]; then
		echo "Error: This program needs GNU Grep" > /dev/stderr
		exit 1
	fi
	if [[ $(pgrep -V 2>& 1) =~ proctools ]]; then
		echo "pgrep from proctools detected." > /dev/stderr
		PGREP_PROCTOOLS=1
	fi
}

# Workaround for pgrep from procps or from proctools
function pgrep_bin() {
	(($# < 1)) && exit 1
	local target_proc=$1

	if (( PGREP_PROCTOOLS > 0 )); then
		pgrep "${target_proc}" | wc -l | tr -d ' '
	else
		pgrep -c "${target_proc}"
	fi
}


# Access to the Release file to check the last update date
function check_last_update() {
	(($# < 1)) && return 1
	local target_url=$1

	(( DEBUG > 0 )) && echo "  Processing $target_url" > /dev/stderr

	# Get HTTP headers
	while IFS=': ' read -r header value
	do
		shopt -s nocasematch
		case "$header" in
			Content-Length)
				content_length="$value"
				;;
			# Date)
			#   ;&
			Last-Modified)
				# Convert last_modified to epoch
				last_modified=$(date -d "$value" +%s)
				;;
		esac
		shopt -u nocasematch
	done < <(curl "${CURL_COMMON_OPT[@]}" -I "$target_url")

	if (( DEBUG > 0 )); then
		echo "last_modified=${last_modified}" > /dev/stderr
		echo "content_length=${content_length}" > /dev/stderr
	fi

	echo "${last_modified}"
	echo "${content_length}"
}

# Access to the URL to check existence of DIST/REPO/ARCH
function check_site() {
  (($# < 1)) && return 1
  local target_url=$1

	# Add URL_PATHNAME to target_url
  if [[ "${target_url: -1 : 1}" = "/" ]]; then
    target_url="${target_url}${URL_PATHNAME}"
  else
    target_url="${target_url}/${URL_PATHNAME}"
  fi

  (( DEBUG > 0 )) && echo "  Processing $target_url" > /dev/stderr

  # Retrieve the header for the URL $url/dists/$DIST/$REPO/binary-$ARCH/
	# Check if status code is of the form 2xx or 3xx
  local STATUS_CODE
  STATUS_CODE="$(curl "${CURL_COMMON_OPT[@]}" --head -w "%{response_code}" -o /dev/null "$target_url")"
  case ${STATUS_CODE} in
    2*)
      (( DEBUG > 0 )) && echo "    OK: ${STATUS_CODE} ${target_url}"    > /dev/stderr
      return 2
      ;;
    3*)
      (( DEBUG > 0 )) && echo "    MOVE: ${STATUS_CODE} ${target_url}"  > /dev/stderr
      return 3
      ;;
    4*)
      (( DEBUG > 0 )) && echo "    NG: ${STATUS_CODE} ${target_url}"    > /dev/stderr
      return 4
      ;;
    5*)
      (( DEBUG > 0 )) && echo "    NG: ${STATUS_CODE} ${target_url}"    > /dev/stderr
      return 5
      ;;
    *)
      (( DEBUG > 0 )) && echo "    OTHER: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 6
      ;;
  esac
}

# Count running jobs only
# Args: none
function running_jobs_count() {
	jobs -r | wc -l
}

# Main loop block for concurrency
function check_site_loop() {
	check_site "${url}"
	if (( $? == 2 )); then
		echo "${url}" >> "${TEMP_FILE}"
	fi
	if ! [[ ${url} =~ .*/ubuntu-ports/ ]]; then
		url="$(echo "${url}" | grep -Po "https*://.*?/")ubuntu-ports/"
		check_site "${url}"
		if (( $? == 2 )); then
			echo "${url}" >> "${TEMP_FILE}"
		fi
	fi
}

# First, we retrieve the Launchpad mirror list, and massage it to obtain a newline-separated list of HTTP mirror
function make_mirror_list() {
	local funcname="make_mirror_list" url=""
	if [[ $# -lt 1 ]]; then
		echo "${funcname}(): Argument needed." > /dev/stderr
		return 1
	fi
	local listfile=$1
	if ! [[ -r ${listfile} ]]; then
		echo "${funcname}(): file '${listfile}' can't read." > /dev/stderr
		return 2
	fi

	echo -n "Fetching mirror list from '${OFFICIAL_MIRROR_PAGE}'" > /dev/stderr
	MIRROR_LIST+=( "${ORIGINAL_PORTS_SITE}" "${FIXED_SITES[@]}" )
	# Don't use CURL_COMMON_OPT to this curl
	for url in $(curl -s $OFFICIAL_MIRROR_PAGE | grep -Po 'https*://.*(?=">https*</a>)'); do
		MIRROR_LIST+=( "$url" )
	done
	local max=${#MIRROR_LIST[@]}
	echo " Done. Total ${max} sites." > /dev/stderr

	local count=1
	for url in "${MIRROR_LIST[@]}"; do
		echo "[${count}/${max}] ${url}" > /dev/stderr

		# Concurrent execution
		# Sleep if the num of processes reaches the limit
		while (( $(running_jobs_count) >= OPT_MAX_CONCURRENCY )); do
			sleep 1
		done
		check_site_loop &
		C_PID+=($!)
		sleep 0.05

		(( count++ ))
	done

	# Wait for threads
	for PID in "${C_PID[@]}"; do
		wait "${PID}"
	done
}

function speed_test () {
  local funcname="speed_test"
  if [[ $# -lt 1 ]]; then
    echo "${funcname}(): Argument needed." > /dev/stderr
    return 1
  fi
  local listfile=$1
  if ! [[ -r ${listfile} ]]; then
    echo "${funcname}(): file '${listfile}' can't read." > /dev/stderr
    return 2
  fi

  local lines query URL_PATHNAME oldifs tmp_res tmp_arr key value

  lines=$(sort -u "${listfile}" | wc -l | tr -d " ")

  query="original_url| %{url}; \
    effective_url| %{url_effective}; \
    redirect| %{redirect_url}; \
    remote_ip| %{remote_ip}; \
    scheme| %{scheme}; \
    code| %{response_code}; \
    size| %{size_download}; \
    speed| %{speed_download}; \
    time_total| %{time_total};"

  URL_PATHNAME="dists/$DIST/Contents-${ARCH}.gz"
  count2=1

  echo "Num of mirror sites to check: ${lines}" > /dev/stderr
  echo "Arch: ${ARCH}, Dist: ${DIST}, Repo: ${REPO}" > /dev/stderr
  # echo "Idx URL Speed(MiB/s) Orig_date Mirror_date"
	echo "Idx URL Speed(MiB/s) Delay(sec)"
  while read -r url; do
		echo -n "$((lines - count2 + 1)) " > /dev/stderr
    echo -n "${count2} "
    local oldifs=${IFS}
    IFS=";"
    local tmp_res="$(curl "${CURL_COMMON_OPT[@]}" -w "${query}" -o /dev/null "${url}${URL_PATHNAME}")"

    for tmp_arr in ${tmp_res// /}; do
      IFS="|"
      read -r key value< <(echo "${tmp_arr}")
      (( DEBUG > 2 )) && echo "${key} = ${value}"
      if [[ ${key} == "speed" ]]; then
        local value="$(echo "scale=1; ${value} / 1024 / 1024" | bc)"
        echo -n "${url} ${value}"
      fi
    done
    IFS=${oldifs}

		# Print last update date of Release file
		mapfile -t url_release < <(check_last_update "${url}${RELEASE_PATHNAME}")
		# echo -n " ${PORTS_RELEASE[0]} ${url_release[0]}"
		# echo " $((PORTS_RELEASE[0] - url_release[0] > 0 ? PORTS_RELEASE[0] - url_release[0] : 0))"
		echo " $(( PORTS_RELEASE[0] - url_release[0] ))"

    (( count2++ ))
  done < <(sort -u "${listfile}")

	echo > /dev/stderr
}

# =======================================================================================
# Definitions
# =======================================================================================
trap del_temp_file SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM ERR EXIT

# The architecture you're looking for (e.g., amd64, i386, arm64, armhf, armel, powerpc, ...).
# See https://wiki.ubuntu.com/UbuntuDevelopment/PackageArchive#Architectures
ARCH=$1
# The Ubuntu distribution you need (e.g., precise, saucy, trusty, ...)
# See https://wiki.ubuntu.com/DevelopmentCodeNames
DIST=$2
# The repository you're looking for (main, restricted, universe, multiverse)
# See https://help.ubuntu.com/community/Repositories/Ubuntu
REPO=$3

MIRROR_FILE=$4

# Max concurrency
OPT_MAX_CONCURRENCY=$(( OPT_MAX_CONCURRENCY ? OPT_MAX_CONCURRENCY : $(get_cpu_cores || echo 4) ))

# Common curl options
CURL_COMMON_OPT=("--silent" "--location" "--connect-timeout" "5" "--max-time" "10")

# URL of the Launchpad mirror list
OFFICIAL_MIRROR_PAGE="https://launchpad.net/ubuntu/+archivemirrors"

ORIGINAL_PORTS_SITE="http://ports.ubuntu.com/"
FIXED_SITES=("http://ftp.yz.yamagata-u.ac.jp/pub/linux/ubuntu/ports/")

URL_PATHNAME="dists/${DIST}/${REPO}/binary-${ARCH}/"
RELEASE_PATHNAME="dists/${DIST}-updates/${REPO}/binary-${ARCH}/Release"
TEMP_FILE="$(mktemp)"

MIRROR_LIST=()

# =======================================================================================
# Entry point
# =======================================================================================
(( DEBUG )) && echo "${TEMP_FILE}" > /dev/stderr
echo "Concurrency: ${OPT_MAX_CONCURRENCY}" > /dev/stderr

check_env

if [[ -n ${MIRROR_FILE} ]]; then
  speed_test "${MIRROR_FILE}"
  exit
fi

mapfile -t PORTS_RELEASE < <(check_last_update "${ORIGINAL_PORTS_SITE}${RELEASE_PATHNAME}")
echo "ports.ubuntu.com Release file timestamp: ${PORTS_RELEASE[0]}" > /dev/stderr

make_mirror_list "${TEMP_FILE}"

#echo "Wait for 30 secs..."
#sleep 30
#cat "${TEMP_FILE}"
echo > /dev/stderr

echo "Checking download speed." > /dev/stderr
echo "Wait until all the processes have finished..." > /dev/stderr
speed_test "${TEMP_FILE}" # | sort -k 3nr | column -t

