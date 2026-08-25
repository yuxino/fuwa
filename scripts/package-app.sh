#!/bin/zsh
set -euo pipefail

WINDOW_PIN_SCRIPT_DIR="${0:A:h}"
WINDOW_PIN_PROJECT_DIR="${WINDOW_PIN_SCRIPT_DIR:h}"
WINDOW_PIN_APP_DIR="${WINDOW_PIN_PROJECT_DIR}/dist/Fuwa.app"
WINDOW_PIN_CONTENTS_DIR="${WINDOW_PIN_APP_DIR}/Contents"
WINDOW_PIN_MACOS_DIR="${WINDOW_PIN_CONTENTS_DIR}/MacOS"
WINDOW_PIN_RESOURCES_DIR="${WINDOW_PIN_CONTENTS_DIR}/Resources"
WINDOW_PIN_SDK_15="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"

if [[ -d "${WINDOW_PIN_SDK_15}" ]]; then
    export SDKROOT="${WINDOW_PIN_SDK_15}"
fi

export CLANG_MODULE_CACHE_PATH="/private/tmp/fuwa-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/fuwa-swift-cache"

cd "${WINDOW_PIN_PROJECT_DIR}"
swift build \
    --disable-sandbox \
    --configuration release \
    --product Fuwa

WINDOW_PIN_BIN_DIR="$(swift build \
    --disable-sandbox \
    --configuration release \
    --product Fuwa \
    --show-bin-path)"

rm -rf "${WINDOW_PIN_APP_DIR}"
mkdir -p "${WINDOW_PIN_MACOS_DIR}" "${WINDOW_PIN_RESOURCES_DIR}"
cp "${WINDOW_PIN_BIN_DIR}/Fuwa" "${WINDOW_PIN_MACOS_DIR}/Fuwa"
cp "${WINDOW_PIN_PROJECT_DIR}/Resources/Info.plist" "${WINDOW_PIN_CONTENTS_DIR}/Info.plist"
chmod +x "${WINDOW_PIN_MACOS_DIR}/Fuwa"

plutil -lint "${WINDOW_PIN_CONTENTS_DIR}/Info.plist"
codesign --force --sign - --timestamp=none "${WINDOW_PIN_APP_DIR}"
codesign --verify --strict --verbose=2 "${WINDOW_PIN_APP_DIR}"

echo "Built ${WINDOW_PIN_APP_DIR}"
