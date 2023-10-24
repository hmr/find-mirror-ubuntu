# find-mirror-ubuntu

The tool searches for Ubuntu Linux mirror repositories accessible via APT, checks existence of the architecture and the version, checks the download speed, and finally outputs the results as a list.

## Key features

- Gets <ins>up-to-date mirror list</ins> by checking launchpad.net
- Checks all mirror sites for the <ins>existence of the **architecture** and **version**</ins> you entered.
- Checks not only `ubuntu` directory <ins>but also `ubuntu-ports` directory</ins>.
- Checks <ins>download speed</ins> by downloading `"Contents-<ARCH>.gz"` file.
- Outputs the list of repositories that <ins>you can `apt update / upgrade / install`</ins> by writing into `/etc/apt/sources.list`.

## Usage

    ./find-mirror-ubuntu.bash <ARCH> <CODE NAME> <REPO TYPE> [mirror list]

where

- ARCH: Architecture type. e.g. `amd64`, `i386`, `arm64` and so on.
- CODE NAME: Codename of the release. e.g. `focal`, `jammy`, `lunar`, `mantic` and so on.
- REPO TYPE: One of {`main`, `restricted`, `universe`, `multiverse`}.
- mirror file: Filename of the mirror list. (optional)

### Make an up-to-date mirror list

```console
$ ./find-mirror-ubuntu.bash arm64 jammy main | tee mirror.list && sort -k 3nr mirror.list
```

### With using a prepared mirror list

Put the filename of prepared list as 4th argument.

```console
$ ./find-mirror-ubuntu.bash arm64 jammy main mirror.list | tee mirror.list && sort -k 3nr mirror.list
```

### Get Verbose output

Set `DEBUG` envitonment variable and you'll get verbose (debug) information.

```console
$ DEBUG=1 ./find-mirror-ubuntu.bash arm64 jammy main | tee mirror.list && sort -k 3nr mirror.list
```
You can get more verbose output by `DEBUG=2`

## Example of execution

```console
$ ./find-mirror-ubuntu.bash arm64 jammy main | tee mirror.list
Fetching mirror list from 'https://launchpad.net/ubuntu/+archivemirrors' Done. Total 784 sites.
[1/784] https://mirrors.dc.clear.net.ar/ubuntu/
[2/784] http://mirrors.dc.clear.net.ar/ubuntu/
[3/784] https://mirror.sitsa.com.ar/ubuntu/
[4/784] http://mirror.sitsa.com.ar/ubuntu/
[5/784] http://mirrors.eze.sysarmy.com/ubuntu/
(snip)
[780/784] http://mirrors.bkns.vn/ubuntu/
[781/784] http://mirrors.vhost.vn/ubuntu/
[782/784] http://mirror.clearsky.vn/ubuntu/
[783/784] http://mirrors.nhanhoa.com/ubuntu/
[784/784] http://opensource.xtdv.net/ubuntu/
Wait for 30 secs...
Checking download speed.
Mirror sites to check: 91
Arch: arm64, Dist: jammy, Repo: main
Idx     URL     Speed(MiB/s)
1 http://buaya.klas.or.id/ubuntu-ports/ 8.2
2 http://free.nchc.org.tw/ubuntu-ports/ 7.9
3 http://ftp.fau.de/ubuntu-ports/ 2.5
4 http://ftp.lanet.kr/ubuntu-ports/ 13.8
5 http://ftp.tsukuba.wide.ad.jp/ubuntu-ports/ 12.0
(snip)
86 https://repo.jing.rocks/ubuntu-ports/ 14.3
87 https://sby.mirror.bignet.id/ubuntu-ports/ 0
88 https://ubuntu-mirror.cloud.mu/ubuntu-ports/ 1.6
89 https://ubuntu-ports.mirror.net.in/ 5.2
90 https://ubuntu-ports.mirror.net.in/ubuntu-ports/ 3.6
91 https://ubuntu.anexia.at/ubuntu-ports/ 3.4

$ sort -k 3nr mirror.list
32 http://mirrors.cloud.tencent.com/ubuntu-ports/ 30.3
48 http://repo.jing.rocks/ubuntu-ports/ 24.9
5 http://ftp.tsukuba.wide.ad.jp/ubuntu-ports/ 20.7
75 https://mirrors.cloud.tencent.com/ubuntu-ports/ 19.8
28 http://mirror.yuki.net.uk/ubuntu-ports/ 18.3
...
```
