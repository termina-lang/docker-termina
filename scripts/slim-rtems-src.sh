#!/bin/sh
#
# Keeps of an RTEMS source tree what the debug information of the BSP points
# to: cpukit and the sources of ARCH and of the BSP family FAMILY. GDB finds
# them because the tree stays at the path where the BSP was built.
#
# Usage: slim-rtems-src.sh DIR ARCH FAMILY

set -eu

dir=$1
arch=$2
family=$3

cd "${dir}"
rm -rf testsuites doc spec autom4te.cache

# The empty directories of the build stay, since the debug information walks
# up from them with ..
if [ -d build ]; then
    find build -type f -delete
fi

for d in bsps c/src/lib/libbsp c/src/lib/libcpu cpukit/score/cpu; do
    if [ -d "${d}" ]; then
        for a in "${d}"/*/; do
            case $(basename "${a}") in
                "${arch}"|shared|include|no_cpu) ;;
                *) rm -rf "${a}" ;;
            esac
        done
    fi
done

for d in bsps/"${arch}" c/src/lib/libbsp/"${arch}"; do
    if [ -d "${d}" ]; then
        for f in "${d}"/*/; do
            case $(basename "${f}") in
                "${family}"|shared|include) ;;
                *) rm -rf "${f}" ;;
            esac
        done
    fi
done
