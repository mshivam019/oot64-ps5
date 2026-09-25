#!/usr/bin/env bash
# Cross-build the static third-party libraries SoH and libultraship need into $PS5SDK_ROOT/prefix.
set -euo pipefail
source "$(dirname "$0")/env.sh"

work=$PS5SDK_ROOT/deps
mkdir -p "$work" "$DEPS_PREFIX/lib" "$DEPS_PREFIX/include"
cd "$work"

fetch() {
    local name=$1 url tag
    url=$(lock "['dependencies']['$name'][0]")
    tag=$(lock "['dependencies']['$name'][1]")
    [ -d "$name" ] || git -c advice.detachedHead=false clone -q --depth 1 -b "$tag" "$url" "$name"
}

build() {
    local name=$1; shift
    echo "=== $name"
    rm -rf "build-$name"
    cmake -S "$name" -B "build-$name" -G Ninja -DCMAKE_TOOLCHAIN_FILE="$REPO/ps5/cmake/ps5-native.cmake" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" "$@" > "build-$name.log" 2>&1 \
        || { tail -30 "build-$name.log"; exit 1; }
    cmake --build "build-$name" --target install >> "build-$name.log" 2>&1 \
        || { grep -m5 -A5 error "build-$name.log"; exit 1; }
}

for name in zlib libzip nlohmann_json tinyxml2 spdlog ogg vorbis opus opusfile; do
    fetch "$name"
done

# zlib: static library only (the shared library and examples do not link for PS5).
echo "=== zlib"
rm -rf build-zlib
cmake -S zlib -B build-zlib -G Ninja -DCMAKE_TOOLCHAIN_FILE="$REPO/ps5/cmake/ps5-native.cmake" \
    -DCMAKE_BUILD_TYPE=Release -DZLIB_BUILD_EXAMPLES=OFF > build-zlib.log 2>&1
cmake --build build-zlib --target zlibstatic >> build-zlib.log 2>&1
cp build-zlib/libz.a "$DEPS_PREFIX/lib/"
cp zlib/zlib.h build-zlib/zconf.h "$DEPS_PREFIX/include/"

build libzip -C "$REPO/ps5/cmake/libzip-cache.cmake" -DENABLE_BZIP2=OFF -DENABLE_LZMA=OFF \
    -DENABLE_ZSTD=OFF -DENABLE_OPENSSL=OFF -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF \
    -DENABLE_COMMONCRYPTO=OFF -DENABLE_WINDOWS_CRYPTO=OFF -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF \
    -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF \
    -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include"
build nlohmann_json -DJSON_BuildTests=OFF -DJSON_Install=ON
build tinyxml2 -Dtinyxml2_BUILD_TESTING=OFF
build spdlog -DSPDLOG_BUILD_EXAMPLE=OFF -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_NO_TLS=ON -DSPDLOG_NO_THREAD_ID=ON
build ogg -DINSTALL_DOCS=OFF -DBUILD_TESTING=OFF
build vorbis -DOGG_ROOT="$DEPS_PREFIX"
build opus -DOPUS_BUILD_TESTING=OFF -DOPUS_BUILD_PROGRAMS=OFF -DOPUS_INSTALL_PKG_CONFIG_MODULE=ON \
    -DOPUS_STACK_PROTECTOR=OFF -DOPUS_FORTIFY_SOURCE=OFF
# opusfile derives its version from git; a shallow clone has none, so pin it.
echo 'PACKAGE_VERSION="0.12"' > opusfile/package_version
build opusfile -DOP_DISABLE_HTTP=ON -DOP_DISABLE_DOCS=ON -DOP_DISABLE_EXAMPLES=ON
echo "dependencies installed in $DEPS_PREFIX"
