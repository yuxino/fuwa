#!/bin/zsh
set -euo pipefail

FUWA_ICON_SCRIPT_DIR="${0:A:h}"
FUWA_ICON_PROJECT_DIR="${FUWA_ICON_SCRIPT_DIR:h}"
FUWA_ICON_SOURCE="${FUWA_ICON_PROJECT_DIR}/Resources/AppIcon.png"
FUWA_ICON_OUTPUT="${FUWA_ICON_PROJECT_DIR}/Resources/AppIcon.icns"
FUWA_ICON_MODE="write"

case "${1:-}" in
    "") ;;
    --check) FUWA_ICON_MODE="check" ;;
    *)
        print -u2 -r -- "usage: ./scripts/generate-app-icon.sh [--check]"
        exit 64
        ;;
esac

FUWA_ICON_WIDTH="$(sips -g pixelWidth "${FUWA_ICON_SOURCE}" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')"
FUWA_ICON_HEIGHT="$(sips -g pixelHeight "${FUWA_ICON_SOURCE}" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')"
FUWA_ICON_HAS_ALPHA="$(sips -g hasAlpha "${FUWA_ICON_SOURCE}" 2>/dev/null | awk '/hasAlpha:/ { print $2 }')"

if [[ -z "${FUWA_ICON_WIDTH}" || -z "${FUWA_ICON_HEIGHT}" ]]; then
    print -u2 -r -- "error: unable to read ${FUWA_ICON_SOURCE}"
    exit 1
fi
if [[ "${FUWA_ICON_WIDTH}" != "${FUWA_ICON_HEIGHT}" || "${FUWA_ICON_WIDTH}" -lt 1024 ]]; then
    print -u2 -r -- "error: AppIcon.png must be square and at least 1024 px"
    exit 1
fi
if [[ "${FUWA_ICON_HAS_ALPHA}" != "yes" ]]; then
    print -u2 -r -- "error: AppIcon.png must keep a real alpha channel for transparent corners"
    exit 1
fi

FUWA_ICON_TEMP_DIR="$(mktemp -d /private/tmp/fuwa-app-icon.XXXXXX)"
trap 'rm -rf "${FUWA_ICON_TEMP_DIR}"' EXIT
FUWA_ICONSET_DIR="${FUWA_ICON_TEMP_DIR}/AppIcon.iconset"
FUWA_ICON_GENERATED="${FUWA_ICON_TEMP_DIR}/AppIcon.icns"
mkdir -p "${FUWA_ICONSET_DIR}"

FUWA_ICON_SDK_15="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ -d "${FUWA_ICON_SDK_15}" ]]; then
    export SDKROOT="${FUWA_ICON_SDK_15}"
fi
export CLANG_MODULE_CACHE_PATH="${FUWA_ICON_TEMP_DIR}/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${FUWA_ICON_TEMP_DIR}/swift-cache"
swift "${FUWA_ICON_SCRIPT_DIR}/verify-icon-alpha.swift" "${FUWA_ICON_SOURCE}"

FUWA_ICON_VARIANTS=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

for FUWA_ICON_VARIANT in "${FUWA_ICON_VARIANTS[@]}"; do
    FUWA_ICON_SIZE="${FUWA_ICON_VARIANT%%:*}"
    FUWA_ICON_FILENAME="${FUWA_ICON_VARIANT#*:}"
    sips \
        -z "${FUWA_ICON_SIZE}" "${FUWA_ICON_SIZE}" \
        "${FUWA_ICON_SOURCE}" \
        --out "${FUWA_ICONSET_DIR}/${FUWA_ICON_FILENAME}" \
        >/dev/null
done

swift "${FUWA_ICON_SCRIPT_DIR}/make-icns.swift" \
    "${FUWA_ICONSET_DIR}" \
    "${FUWA_ICON_GENERATED}"

if [[ "${FUWA_ICON_MODE}" == "check" ]]; then
    if ! cmp -s "${FUWA_ICON_GENERATED}" "${FUWA_ICON_OUTPUT}"; then
        print -u2 -r -- "error: AppIcon.icns is stale; run ./scripts/generate-app-icon.sh"
        exit 1
    fi
    print -r -- "App icon master and generated ICNS are in sync."
else
    cp "${FUWA_ICON_GENERATED}" "${FUWA_ICON_OUTPUT}"
    print -r -- "Generated ${FUWA_ICON_OUTPUT} from ${FUWA_ICON_SOURCE}."
fi
