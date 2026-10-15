#!/bin/sh
#
# Removes from a GCC cross-toolchain what the platforms of the image do not
# use: the multilibs other than KEEP, C++, Fortran, LTO, the debugger of the
# toolchain (the image debugs with gdb-multiarch) and the documentation. The
# host executables are stripped; the target libraries keep their debug
# information.
#
# Usage: slim-toolchain.sh PREFIX TARGET KEEP

set -eu

prefix=$1
target=$2
keep=$3

gcc="${prefix}/bin/${target}-gcc"
gcclib=$(dirname "$("${gcc}" -print-libgcc-file-name)")
tlib="${prefix}/${target}/lib"

# Files of every other multilib; a directory may also hold the kept one below
"${gcc}" -print-multi-lib | cut -d';' -f1 | while read -r dir; do
    if [ "${dir}" != "${keep}" ]; then
        for base in "${gcclib}" "${tlib}"; do
            if [ -d "${base}/${dir}" ]; then
                find "${base}/${dir}" -maxdepth 1 -type f \
                    \( -name '*.a' -o -name '*.o' \) -delete
            fi
        done
    fi
done

find "${gcclib}" "${tlib}" \( -name 'libstdc++*' -o -name 'libsupc++*' \
    -o -name 'libgfortran*' \) -delete
find "${gcclib}" "${tlib}" -type d -empty -delete
rm -rf "${prefix}/${target}/include/c++"

rm -f "${prefix}/bin/${target}-c++" "${prefix}/bin/${target}-g++" \
    "${prefix}/bin/${target}-gfortran" "${prefix}/bin/${target}-lto-dump" \
    "${prefix}/bin/${target}"-gdb*
rm -f "${prefix}/libexec/gcc/${target}"/*/cc1plus \
    "${prefix}/libexec/gcc/${target}"/*/f951 \
    "${prefix}/libexec/gcc/${target}"/*/lto1

rm -rf "${prefix}/doc" "${prefix}/share/doc" "${prefix}/share/info" \
    "${prefix}/share/man" "${prefix}/share/locale" "${prefix}/share/gdb" \
    "${prefix}"/share/gcc-*

# Scripts among them are left as they are
find "${prefix}/bin" "${prefix}/libexec" -type f \
    -exec strip --strip-unneeded {} + 2>/dev/null || true
