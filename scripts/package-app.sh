#!/bin/zsh
set -euo pipefail

FUWA_SCRIPT_DIR="${0:A:h}"
FUWA_PROJECT_DIR="${FUWA_SCRIPT_DIR:h}"
FUWA_APP_DIR="${FUWA_PROJECT_DIR}/dist/Fuwa.app"
FUWA_CONTENTS_DIR="${FUWA_APP_DIR}/Contents"
FUWA_MACOS_DIR="${FUWA_CONTENTS_DIR}/MacOS"
FUWA_RESOURCES_DIR="${FUWA_CONTENTS_DIR}/Resources"
FUWA_SDK_15="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
FUWA_CODESIGN_IDENTITY="${FUWA_CODESIGN_IDENTITY:--}"
FUWA_BUILD_UNIVERSAL="${FUWA_BUILD_UNIVERSAL:-1}"

if [[ -d "${FUWA_SDK_15}" ]]; then
    export SDKROOT="${FUWA_SDK_15}"
fi

export CLANG_MODULE_CACHE_PATH="/private/tmp/fuwa-package-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="/private/tmp/fuwa-package-swift-cache"

cd "${FUWA_PROJECT_DIR}"
if [[ "${FUWA_BUILD_UNIVERSAL}" == "1" ]]; then
    FUWA_ARCH_BINARIES=()
    for FUWA_ARCH in arm64 x86_64; do
        FUWA_ARCH_SCRATCH="${FUWA_PROJECT_DIR}/.build/package-${FUWA_ARCH}"
        swift build \
            --disable-sandbox \
            --scratch-path "${FUWA_ARCH_SCRATCH}" \
            --configuration release \
            --product Fuwa \
            --arch "${FUWA_ARCH}" \
            -Xswiftc -strict-concurrency=complete \
            -Xswiftc -warnings-as-errors
        FUWA_ARCH_BIN_DIR="$(swift build \
            --disable-sandbox \
            --scratch-path "${FUWA_ARCH_SCRATCH}" \
            --configuration release \
            --arch "${FUWA_ARCH}" \
            --show-bin-path)"
        FUWA_ARCH_BINARIES+=("${FUWA_ARCH_BIN_DIR}/Fuwa")
    done

    FUWA_UNIVERSAL_DIR="${FUWA_PROJECT_DIR}/.build/package-universal"
    mkdir -p "${FUWA_UNIVERSAL_DIR}"
    lipo -create "${FUWA_ARCH_BINARIES[@]}" -output "${FUWA_UNIVERSAL_DIR}/Fuwa"
    FUWA_BINARY_SOURCE="${FUWA_UNIVERSAL_DIR}/Fuwa"
else
    swift build \
        --disable-sandbox \
        --configuration release \
        --product Fuwa \
        -Xswiftc -strict-concurrency=complete \
        -Xswiftc -warnings-as-errors
    FUWA_BIN_DIR="$(swift build \
        --disable-sandbox \
        --configuration release \
        --product Fuwa \
        --show-bin-path)"
    FUWA_BINARY_SOURCE="${FUWA_BIN_DIR}/Fuwa"
fi
FUWA_VERSION="$(/usr/libexec/PlistBuddy \
    -c 'Print :CFBundleShortVersionString' \
    "${FUWA_PROJECT_DIR}/Resources/Info.plist")"
FUWA_ARCHIVE_NAME="Fuwa-${FUWA_VERSION}.zip"
FUWA_ARCHIVE_PATH="${FUWA_PROJECT_DIR}/dist/${FUWA_ARCHIVE_NAME}"

rm -rf "${FUWA_APP_DIR}"
rm -f "${FUWA_ARCHIVE_PATH}" "${FUWA_ARCHIVE_PATH}.sha256"
mkdir -p "${FUWA_MACOS_DIR}" "${FUWA_RESOURCES_DIR}"
cp "${FUWA_BINARY_SOURCE}" "${FUWA_MACOS_DIR}/Fuwa"
cp "${FUWA_PROJECT_DIR}/Resources/Info.plist" "${FUWA_CONTENTS_DIR}/Info.plist"
cp "${FUWA_PROJECT_DIR}/Resources/AppIcon.icns" "${FUWA_RESOURCES_DIR}/AppIcon.icns"
cp -R "${FUWA_PROJECT_DIR}/Resources/en.lproj" "${FUWA_RESOURCES_DIR}/en.lproj"
cp -R "${FUWA_PROJECT_DIR}/Resources/zh-Hans.lproj" "${FUWA_RESOURCES_DIR}/zh-Hans.lproj"
chmod +x "${FUWA_MACOS_DIR}/Fuwa"

plutil -lint "${FUWA_CONTENTS_DIR}/Info.plist"

if [[ "${FUWA_CODESIGN_IDENTITY}" == "-" ]]; then
    codesign \
        --force \
        --sign - \
        --timestamp=none \
        "${FUWA_APP_DIR}"
else
    codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "${FUWA_CODESIGN_IDENTITY}" \
        "${FUWA_APP_DIR}"
fi

codesign --verify --deep --strict --verbose=2 "${FUWA_APP_DIR}"
pushd "${FUWA_PROJECT_DIR}/dist" >/dev/null
/usr/bin/zip -q -r -y -X "${FUWA_ARCHIVE_NAME}" "Fuwa.app"
shasum -a 256 "${FUWA_ARCHIVE_NAME}" > "${FUWA_ARCHIVE_NAME}.sha256"
popd >/dev/null

echo "Built ${FUWA_APP_DIR}"
echo "Archived ${FUWA_ARCHIVE_PATH}"
