# find-mirror-ubuntu

This tool finds Ubuntu Linux mirror repository and sort by downloading speed.

## Usage

    ./find-mirror-ubuntu.bash <ARCH> <CODENAME> <REPO TYPE> [mirror list]

where

- ARCH: Architecture type. e.g. amd64, i386, arm64 and so on.
- CODENAME: Codename of the release. e.g. focal, jammy, lunar, mantic and so on.
- TYPE: One of {main, restricted, universe, multiverse}.
- mirror file: Filename of the mirror list.

### Make a mirror list from internet

```console
$ ./find-mirror-ubuntu.bash arm64 jammy main
```

### Using prepared mirror list

Put the filename of prepared list as 4th argument.

```console
$ ./find-mirror-ubuntu.bash arm64 jammy main mirror.list
```

