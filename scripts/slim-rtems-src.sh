#!/bin/sh
#
# Keeps of an RTEMS source tree what the debug information of the BSPs points
# to: cpukit and the sources of each ARCH and of its BSP family FAMILY. GDB
# finds them because the tree stays at the path where the BSPs were built.
#
# Usage: slim-rtems-src.sh DIR ARCH:FAMILY...

set -eu

dir=$1
shift
pairs=$*

cd "${dir}"
rm -rf testsuites doc spec autom4te.cache

# The empty directories of the build stay, since the debug information walks
# up from them with ..
if [ -d build ]; then
    find build -type f -delete
fi

# Whether NAME is the architecture of one of the pairs
is_arch() {
    for p in ${pairs}; do
        if [ "${p%%:*}" = "$1" ]; then
            return 0
        fi
    done
    return 1
}

# Whether NAME is one of the families of ARCH
is_family() {
    for p in ${pairs}; do
        if [ "${p}" = "$1:$2" ]; then
            return 0
        fi
    done
    return 1
}

for d in bsps c/src/lib/libbsp c/src/lib/libcpu cpukit/score/cpu; do
    if [ -d "${d}" ]; then
        for a in "${d}"/*/; do
            name=$(basename "${a}")
            case ${name} in
                shared|include|no_cpu) ;;
                *) is_arch "${name}" || rm -rf "${a}" ;;
            esac
        done
    fi
done

for p in ${pairs}; do
    arch=${p%%:*}
    for d in bsps/"${arch}" c/src/lib/libbsp/"${arch}"; do
        if [ -d "${d}" ]; then
            for f in "${d}"/*/; do
                name=$(basename "${f}")
                case ${name} in
                    shared|include) ;;
                    *) is_family "${arch}" "${name}" || rm -rf "${f}" ;;
                esac
            done
        fi
    done
done
