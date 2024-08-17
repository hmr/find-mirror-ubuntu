# find-mirror-ubuntu

This tool searches for Ubuntu Linux mirror repositories accessible via http, checks existence of the architecture and the version, checks the download speed, and finally outputs the results as a list.

## Key features

- Generates <ins>up-to-date mirror list</ins> by checking launchpad.net
- Checks all mirror sites for the <ins>existence of the **architecture** and **version**</ins> you entered.
- Checks not only `ubuntu` directory <ins>but also `ubuntu-ports` directory</ins>.
- Checks <ins>download speed</ins> by downloading `"Contents-<ARCH>.gz"` file.
- Checks <ins>mirroring delay</ins> by checking timestamp of `"Release:` file.
- Outputs the list of mirrors that <ins>you can `apt update / upgrade / install`</ins> by writing into `/etc/apt/sources.list.d/ubuntu.list`.

## Prerequisites

This tool needs external softwares below:

- bash 4.4+
- GNU Grep
- cURL

## Usage

    ./find-mirror-ubuntu.bash <ARCH> <CODE NAME> <REPO TYPE> [mirror list]

where

- ARCH: Architecture type. e.g. `amd64`, `i386`, `arm64`, `riscv64` and so on.
- CODE NAME: Codename of the release. e.g. `focal`, `jammy`, `noble` and so on.
- REPO TYPE: One of {`main`, `restricted`, `universe`, `multiverse`}.
- mirror file: Filename of the mirror list. (optional)

### Make an up-to-date mirror list

```console
$ ./find-mirror-ubuntu.bash riscv64 noble main | (read -r header && echo "$header" && sort -k 4n -k 3nr) | column -t | tee mirror-list.txt
```

This displays a list of mirrors which is ordered by delay and download speed from ports.ubuntu.com. The higher the line means smaller mirroring delay and faster download speed.

### Get Verbose output

Set `DEBUG` envitonment variable and you'll get verbose (debug) information.

```console
$ DEBUG=1 ./find-mirror-ubuntu.bash riscv64 noble main | (read -r header && echo "$header" && sort -k 4n -k 3nr) | column -t | tee mirror-list.txt
```
You can get more verbose output by `DEBUG=2`


### Adjust concurrency

This tool executes curl in concurrency. The maximum number of concurrent executions can be adjusted using the environment variable `OPT_MAX_CONCURRENCY`. The default value is the number of CPU cores.

```console
$ OPT_MAX_CONCURRENCY=4 ./find-mirror-ubuntu.bash arm64 noble main
```

## Example of execution

```console
$ ./find-mirror-ubuntu.bash riscv64 noble main | (read -r header && echo "$header" && sort -k 4n -k 3nr) | column -t
Concurrency: 12
pgrep from proctools detected.
ports.ubuntu.com Release file timestamp: 1723901682
Fetching mirror list from 'https://launchpad.net/ubuntu/+archivemirrors' Done. Total 849 sites.
[1/849] http://ports.ubuntu.com/
[2/849] http://ftp.yz.yamagata-u.ac.jp/pub/linux/ubuntu/ports/
[3/849] https://mirrors.dc.clear.net.ar/ubuntu/
[4/849] http://mirrors.dc.clear.net.ar/ubuntu/
[5/849] https://mirror.sitsa.com.ar/ubuntu/
[6/849] http://mirror.sitsa.com.ar/ubuntu/
[7/849] https://ubuntu.zero.com.ar/ubuntu/
[8/849] http://ubuntu.zero.com.ar/ubuntu/
...

Checking download speed.
Wait until all the processes have finished...
Num of mirror sites to check: 94
Arch: riscv64, Dist: noble, Repo: main
94 93 92 91 90 89 88 87 86 85 84 83 82 81 80 79 78 77 76 75 74 73 72 71 70 69 68 67 66 65 64 63 62 61 60 59 58 57 56 55 54 53 52 51 50 49 48 47 46 45 44 43 42 41 40 39 38 37 36 35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1
Idx  URL                                                     Speed(MiB/s)  Diff
77   https://mirror.twds.com.tw/ubuntu/                      22.4          0
29   http://mirror.twds.com.tw/ubuntu-ports/                 20.8          0
62   https://ftp.lanet.kr/ubuntu-ports/                      20.7          0
76   https://mirror.twds.com.tw/ubuntu-ports/                19.2          0
30   http://mirror.twds.com.tw/ubuntu/                       17.8          0
...
```
