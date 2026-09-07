#!/bin/zsh
set -euo pipefail

# Exercise dyld's runtime policy with the packaged host's actual entitlements.
# codesign --verify alone cannot detect Team ID / Library Validation failures.
# This probe loads no windows, requests no privacy permissions and runs no app UI.
FUWA_VERIFY_SCRIPT_DIR="${0:A:h}"
if [[ $# != 1 || ! -d "$1/Contents/Frameworks/Sparkle.framework" ]]; then
    print -u2 -r -- "usage: $0 <Fuwa.app>"
    exit 64
fi
FUWA_VERIFY_APP="${1:A}"
FUWA_VERIFY_IDENTITY="$("${FUWA_VERIFY_SCRIPT_DIR}/codesign-identity.sh")"
FUWA_VERIFY_TEMP="$(mktemp -d /private/tmp/fuwa-framework-probe.XXXXXX)"
trap 'rm -rf "${FUWA_VERIFY_TEMP}"' EXIT

cat > "${FUWA_VERIFY_TEMP}/probe.c" <<'EOF'
#include <dlfcn.h>
#include <stdio.h>
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *framework = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!framework) {
        fprintf(stderr, "%s\n", dlerror());
        return 1;
    }
    dlclose(framework);
    puts("Packaged Sparkle framework loads under the host signing policy.");
    return 0;
}
EOF
/usr/bin/cc "${FUWA_VERIFY_TEMP}/probe.c" -o "${FUWA_VERIFY_TEMP}/probe"
codesign --display --entitlements - --xml "${FUWA_VERIFY_APP}" \
    > "${FUWA_VERIFY_TEMP}/entitlements.plist"
FUWA_VERIFY_ENTITLEMENTS=()
if [[ -s "${FUWA_VERIFY_TEMP}/entitlements.plist" ]]; then
    plutil -lint "${FUWA_VERIFY_TEMP}/entitlements.plist" >/dev/null
    FUWA_VERIFY_ENTITLEMENTS=(--entitlements "${FUWA_VERIFY_TEMP}/entitlements.plist")
fi
codesign --force --options runtime --timestamp=none \
    "${FUWA_VERIFY_ENTITLEMENTS[@]}" \
    --sign "${FUWA_VERIFY_IDENTITY}" "${FUWA_VERIFY_TEMP}/probe"
"${FUWA_VERIFY_TEMP}/probe" \
    "${FUWA_VERIFY_APP}/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle"
