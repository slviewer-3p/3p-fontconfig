#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

FONTCONFIG_SOURCE_DIR="fontconfig-2.12.6"

stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
"$autobuild" source_environment > "$stage/variables_setup.sh" || exit 1
. "$stage/variables_setup.sh"

ZLIB_INCLUDE="${stage}"/packages/include/zlib-ng

[ -f "$ZLIB_INCLUDE"/zlib.h ] || fail "You haven't yet run 'autobuild install'."

pushd "$FONTCONFIG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        linux*)
            # Default target per autobuild --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD}"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS" 
            fi

            # Fontconfig is a strange one.  We use it in the Linux build and we ship it
            # but we ship the .so in a way that it isn't used in an installation.  Worse,
            # a casual build can export other libraries and we don't want that.  So,
            # we carefully build .so's here that we won't activate and which won't damage
            # the library resolution logic when this library is used with either shipped
            # products (viewer) or unit tests (namely INTEGRATION_TEST_llurlentry).
            # A better fix is to build this right and use it or just remove it (and
            # freetype).

            # Anyway, --disable-silent-rules is present for chatty log files
            # so you can review the actual library link and confirm it's sane.
            # Point configuration to use libexpat from dependent packages.
            # Make-time LDFLAGS adds an --exclude-libs option to prevent
            # re-export of archive symbols.

	    autoreconf
	    export PKG_CONFIG_PATH=$stage/packages/lib/release/pkgconfig
	    export CXXFLAGS="$opts"
            export LDFLAGS="$opts -L$stage/packages/lib/release/"
	    export FREETYPE_CFLAGS="-I$stage/packages/include/freetype2 -I$stage/packages/include/"
            export LDFLAGS="$opts -L$stage/packages/lib/release/ -Wl,--exclude-libs,libz:libxml2:libexpat:libfreetype"
	    
            CFLAGS="$opts" \
                ./configure \
                --enable-static --enable-shared --disable-docs \
                --with-pic --disable-silent-rules \
                --with-expat-includes="$stage"/packages/include/expat/ \
                --with-expat-lib="$stage"/packages/lib/release/ \
                --prefix="$stage" --libdir="$stage"/lib/release/
            make 
            make install

            # conditionally run unit tests
            if [ "${DISABLE_UNIT_TESTS:-0}" = "0" ]; then
                make check
            fi

            make distclean 
        ;;

        *)
            fail "Unsupported AUTOBUILD_PLATFORM='$AUTOBUILD_PLATFORM'."
        ;;
    esac

    mkdir -p "$stage/include"
    cp -a fontconfig "$stage/include"

    mkdir -p "$stage/LICENSES"
    cp COPYING "$stage/LICENSES/fontconfig.txt"

popd

mkdir -p "$stage"/docs/fontconfig/
cp -a README.Linden "$stage"/docs/fontconfig/

sed -n -E "s/PACKAGE_VERSION='([0-9.]+)'.*/\\1/p" "$FONTCONFIG_SOURCE_DIR/configure" > "$stage/VERSION.txt"
