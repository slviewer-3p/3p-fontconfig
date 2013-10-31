#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

FONTCONFIG_VERSION=2.11.0
FONTCONFIG_SOURCE_DIR="fontconfig"


# load autobuild provided shell functions and variables
eval "$("$AUTOBUILD" source_environment)"

stage="$(pwd)/stage"

pushd "$FONTCONFIG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        "linux")
            # Prefer gcc-4.1 if available
            # if [[ -f /usr/bin/gcc-4.1 && -f /usr/bin/gcc-4.1 ]] ; then
            #     export CC=/usr/bin/gcc-4.1
            #     export CXX=/usr/bin/gcc-4.1
            # fi
            
            LDFLAGS="-m32  -L$stage/packages/lib/release" CFLAGS="-m32" CXXFLAGS="-m32" ./configure --prefix="$stage"
            make
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
        *)
            echo "build not supported."
            exit -1
        ;;
    esac

    mkdir -p "$stage/include"
    cp -a fontconfig "$stage/include"

    mkdir -p "$stage/LICENSES"
    cp COPYING "$stage/LICENSES/fontconfig.txt"
popd

pass

