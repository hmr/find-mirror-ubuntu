#!/bin/bash

# vim: set noet syn=bash ft=sh ff=unix fenc=utf-8 ts=2 sw=0 : # GPP default modeline for zsh script
# shellcheck shell=bash disable=SC1091,SC2155,SC3010,SC3021,SC3037 source=${GPP_HOME}

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <arch> <dist> <repo> [<filename>]"
  echo
  echo "  <arch>: Architecture (eg. amd64, i386, arm64, armhf, powerpc, s390, ...)"
  echo "  <dist>: Ubuntu version name (eg. xenial, bionic, focal, jammy, ...)"
  echo "  <repo>: Repository type (main, restricted, universe or multiverse)"
  echo "  <filename>: Use <filename> for mirror list instead of searching mirror sites"
  exit
fi

# URL of the Launchpad mirror list
MIRROR_LIST=https://launchpad.net/ubuntu/+archivemirrors

# Set to the architecture you're looking for (e.g., amd64, i386, arm64, armhf, armel, powerpc, ...).
# See https://wiki.ubuntu.com/UbuntuDevelopment/PackageArchive#Architectures
ARCH=$1
# Set to the Ubuntu distribution you need (e.g., precise, saucy, trusty, ...)
# See https://wiki.ubuntu.com/DevelopmentCodeNames
DIST=$2
# Set to the repository you're looking for (main, restricted, universe, multiverse)
# See https://help.ubuntu.com/community/Repositories/Ubuntu
REPO=$3

MIRROR_FILE=$4

url_pathname="dists/$DIST/$REPO/binary-$ARCH/"
TEMP_FILE="$(mktemp)"

mirrorList=()

function del_temp_file() {
  [[ -n "${TEMP_FILE}" && ${DEBUG} -lt 1 ]] && rm "${TEMP_FILE}"
  exit
}

trap del_temp_file SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM ERR EXIT

function check_site() {
  (($# < 1)) && return 1
  local target_url=$1

  # Spinlock if num of curl process is exceeded max concurrency
  while (( $(pgrep -c curl) > 4 )); do
    sleep 1
  done

  if [[ "${target_url: -1 : 1}" = "/" ]]; then
    target_url="${target_url}${url_pathname}"
  else
    target_url="${target_url}/${url_pathname}"
  fi
  # If you like some output while the script is running (feel free to comment out the following line)
  (( DEBUG > 0 )) && echo "  Processing $target_url" > /dev/stderr
  # retrieve the header for the URL $url/dists/$DIST/$REPO/binary-$ARCH/; check if status code is of the form 2.. or 3..
  local STATUS_CODE
  # STATUS_CODE="$(curl --connect-timeout 5 -m 10 -s --head "$target_url" | head -n 1)"
  # STATUS_CODE="$(echo "${STATUS_CODE}" | grep -Po "\d\d\d")"
  STATUS_CODE="$(curl -L --connect-timeout 5 -m 10 -s --head -w "%{response_code}" -o /dev/null "$target_url")"
  case ${STATUS_CODE} in
    2*)
      (( DEBUG > 0 )) && echo "    OK: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 2
      ;;
    3*)
      (( DEBUG > 0 )) && echo "    MOVE: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 3
      ;;
    4*)
      (( DEBUG > 0 )) && echo "    NG: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 4
      ;;
    5*)
      (( DEBUG > 0 )) && echo "    NG: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 5
      ;;
    *)
      (( DEBUG > 0 )) && echo "    OTHER: ${STATUS_CODE} ${target_url}" > /dev/stderr
      return 6
      ;;
  esac
}

# First, we retrieve the Launchpad mirror list, and massage it to obtain a newline-separated list of HTTP mirror
function make_mirror_list() {
  local funcname="make_mirror_list"
  if [[ $# -lt 1 ]]; then
    echo "${funcname}(): Argument needed." > /dev/stderr
    return 1
  fi
  local listfile=$1
  if ! [[ -r ${listfile} ]]; then
    echo "${funcname}(): file '${listfile}' can't read." > /dev/stderr
    return 2
  fi

  echo -n "Fetching mirror list from '${MIRROR_LIST}'" > /dev/stderr
  for url in $(curl -s $MIRROR_LIST | grep -Po 'https*://.*(?=">https*</a>)'); do
    mirrorList+=( "$url" )
  done
  max=${#mirrorList[@]}
  echo " Done. Total ${max} sites." > /dev/stderr

  count=1
  for url in "${mirrorList[@]}"; do
    (
      echo "[${count}/${max}] ${url}" > /dev/stderr
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
    )
    (( count++ ))
  done

wait
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

  local lines query url_pathname oldifs tmp_res tmp_arr key value

  lines=$(sort -u "${listfile}" | wc -l)

  query="original_url| %{url}; \
    effective_url| %{url_effective}; \
    redirect| %{redirect_url}; \
    remote_ip| %{remote_ip}; \
    scheme| %{scheme}; \
    code| %{response_code}; \
    size| %{size_download}; \
    speed| %{speed_download}; \
    time_total| %{time_total};"

  url_pathname="dists/$DIST/Contents-${ARCH}.gz"
  count2=1

  TMP=${url_pathname}

  echo "Checking download speed." > /dev/stderr
  echo "Mirror sites to check: ${lines}" > /dev/stderr
  echo "Arch: ${ARCH}, Dist: ${DIST}, Repo: ${REPO}"
  echo "Idx     URL     Speed(MiB/s)"
  while read -r url; do
    echo -n "${count2} "
    oldifs=${IFS}
    IFS=";"
    tmp_res="$(curl -m 30 -w "${query}" -s -o /dev/null -L "${url}${url_pathname}")"

    for tmp_arr in ${tmp_res// /}; do
      IFS="|"
      read -r key value< <(echo "${tmp_arr}")
      (( DEBUG > 2 )) && echo "${key} = ${value}"
      if [[ ${key} == "speed" ]]; then
        value="$(echo "scale=1; ${value} / 1024 / 1024" | bc)"
        echo "${url} ${value}"
      fi
    done
    IFS=${oldifs}
    (( count2++ ))
  done < <(sort -u "${listfile}")
}

# =======================================================================================
# Entry point
# =======================================================================================
if [[ -n ${MIRROR_FILE} ]]; then
  speed_test "${MIRROR_FILE}"
  exit
fi

make_mirror_list "${TEMP_FILE}"
echo "Wait for 30 secs..."
sleep 30

speed_test "${TEMP_FILE}"

