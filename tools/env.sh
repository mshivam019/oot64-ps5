# Shared paths for the build scripts. Source this file; override any variable beforehand.
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export PS5SDK_ROOT=${PS5SDK_ROOT:-/opt/ps5sdk}
export PS5_NATIVE_APP_TEMPLATE=${PS5_NATIVE_APP_TEMPLATE:-$PS5SDK_ROOT/native-app-boilerplate}
export PS5_PAYLOAD_SDK=${PS5_PAYLOAD_SDK:-$PS5_NATIVE_APP_TEMPLATE/.deps/native/ps5-payload-sdk}
export PS5_OPENGL_SDK=${PS5_OPENGL_SDK:-$PS5SDK_ROOT/extracted/ps5-opengl-sdk-0.3.0/sdk}
export PS5_OPENGL_ROOT=${PS5_OPENGL_ROOT:-$PS5SDK_ROOT/ps5-opengl-030/ps5-opengl}
export SOH_SOURCE=${SOH_SOURCE:-$PS5SDK_ROOT/src/Shipwright}
export SOH_BUILD=${SOH_BUILD:-$PS5SDK_ROOT/build/soh-ps5}
TOOLCHAIN=$REPO/ps5/cmake/ps5-soh.cmake
DEPS_PREFIX=$PS5SDK_ROOT/prefix
lock() { python3 -c "import json,sys; d=json.load(open('$REPO/sources.lock.json')); print(d$1)"; }
