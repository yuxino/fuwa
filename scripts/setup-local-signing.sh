#!/bin/zsh
set -euo pipefail

# Creates the one long-lived local identity shared by this developer's macOS
# apps. The private key exists only in a mode-600 temporary directory while it
# is being imported, is then deleted, and is never stored in the repository. Existing
# certificates are never deleted or rotated here: an identity change would
# itself trigger one more macOS authorization.

readonly FUWA_SCRIPT_DIR="${0:A:h}"
readonly FUWA_IDENTITY_NAME="mimi Local Development"

fail() {
    print -u2 -r -- "error: $*"
    exit 1
}

if FUWA_EXISTING_IDENTITY="$(
    FUWA_CODESIGN_IDENTITY="${FUWA_IDENTITY_NAME}" \
        "${FUWA_SCRIPT_DIR}/codesign-identity.sh" 2>&1
)"; then
    print -r -- "Stable local signing identity already exists: ${FUWA_EXISTING_IDENTITY}"
    exit 0
else
    FUWA_IDENTITY_RESOLUTION_STATUS=$?
fi
if (( FUWA_IDENTITY_RESOLUTION_STATUS != 4 )); then
    [[ -z "${FUWA_EXISTING_IDENTITY}" ]] \
        || print -u2 -r -- "${FUWA_EXISTING_IDENTITY}"
    fail "refusing to create a certificate because identity resolution did not complete safely"
fi

if ! FUWA_DEFAULT_KEYCHAIN_OUTPUT="$(/usr/bin/security default-keychain -d user)"; then
    fail "the user default keychain query failed"
fi
FUWA_DEFAULT_KEYCHAIN="$(
    print -r -- "${FUWA_DEFAULT_KEYCHAIN_OUTPUT}" \
        | /usr/bin/tr -d '"' \
        | /usr/bin/xargs
)"
[[ -n "${FUWA_DEFAULT_KEYCHAIN}" && -f "${FUWA_DEFAULT_KEYCHAIN}" ]] \
    || fail "the user default keychain could not be located"

if ! FUWA_EXISTING_CERTIFICATES="$(
    /usr/bin/security find-certificate \
        -a \
        -c "${FUWA_IDENTITY_NAME}" \
        -Z \
        "${FUWA_DEFAULT_KEYCHAIN}"
)"; then
    fail "the existing local signing certificate query failed"
fi
if [[ -n "${FUWA_EXISTING_CERTIFICATES}" ]]; then
    cat >&2 <<EOF
error: a certificate named '${FUWA_IDENTITY_NAME}' exists, but it is not a
valid code-signing identity with an accessible private key.

It was left untouched because silently replacing it would change every app's
identity and cause another authorization migration. Repair that identity in
Keychain Access or deliberately remove it before rerunning this setup.
EOF
    exit 1
fi

if [[ "${FUWA_CONFIRM_LOCAL_SIGNING_TRUST:-0}" != "1" ]]; then
    cat >&2 <<EOF
This one-time setup will create a ten-year self-signed code-signing certificate
named '${FUWA_IDENTITY_NAME}' in your default user keychain. Trust is limited
to the macOS code-signing policy; it is not added as website or TLS trust.

Keeping this certificate and private key is what lets local app rebuilds retain
the same privacy-permission identity. Deleting or replacing it causes one more
authorization migration for every app that uses it.
EOF
    if [[ ! -t 0 ]]; then
        print -u2 -r -- "error: interactive confirmation is required"
        print -u2 -r -- "After reviewing the message, rerun interactively or set FUWA_CONFIRM_LOCAL_SIGNING_TRUST=1."
        exit 1
    fi
    read -r "FUWA_CONFIRMATION?Type CREATE to continue: "
    [[ "${FUWA_CONFIRMATION}" == "CREATE" ]] || {
        print -u2 -r -- "Cancelled without changing the keychain."
        exit 1
    }
fi

FUWA_TEMP_DIR="$(/usr/bin/mktemp -d /private/tmp/fuwa-signing.XXXXXX)"
case "${FUWA_TEMP_DIR}" in
    /private/tmp/fuwa-signing.*) ;;
    *) fail "refusing an unexpected temporary directory: ${FUWA_TEMP_DIR}" ;;
esac

cleanup() {
    case "${FUWA_TEMP_DIR:-}" in
        /private/tmp/fuwa-signing.*)
            /bin/rm -f \
                "${FUWA_TEMP_DIR}/certificate.pem" \
                "${FUWA_TEMP_DIR}/private-key.pem" \
                "${FUWA_TEMP_DIR}/identity.p12"
            /bin/rmdir "${FUWA_TEMP_DIR}" 2>/dev/null || true
            ;;
    esac
}
trap cleanup EXIT

FUWA_P12_PASSWORD="$(/usr/bin/openssl rand -hex 32)"
/usr/bin/openssl req \
    -new \
    -newkey rsa:2048 \
    -nodes \
    -x509 \
    -days 3650 \
    -config "${FUWA_SCRIPT_DIR}/local-signing-openssl.cnf" \
    -keyout "${FUWA_TEMP_DIR}/private-key.pem" \
    -out "${FUWA_TEMP_DIR}/certificate.pem" >/dev/null 2>&1
/bin/chmod 600 "${FUWA_TEMP_DIR}/private-key.pem"

/usr/bin/openssl pkcs12 \
    -export \
    -inkey "${FUWA_TEMP_DIR}/private-key.pem" \
    -in "${FUWA_TEMP_DIR}/certificate.pem" \
    -out "${FUWA_TEMP_DIR}/identity.p12" \
    -passout "pass:${FUWA_P12_PASSWORD}" >/dev/null 2>&1

/usr/bin/security import \
    "${FUWA_TEMP_DIR}/identity.p12" \
    -k "${FUWA_DEFAULT_KEYCHAIN}" \
    -P "${FUWA_P12_PASSWORD}" \
    -T /usr/bin/codesign >/dev/null

/usr/bin/security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "${FUWA_DEFAULT_KEYCHAIN}" \
    "${FUWA_TEMP_DIR}/certificate.pem"

FUWA_CREATED_IDENTITY="$(
    FUWA_CODESIGN_IDENTITY="${FUWA_IDENTITY_NAME}" \
        "${FUWA_SCRIPT_DIR}/codesign-identity.sh"
)"
[[ -n "${FUWA_CREATED_IDENTITY}" && "${FUWA_CREATED_IDENTITY}" != "-" ]] \
    || fail "the imported certificate did not become a valid code-signing identity"

print -r -- "Created stable local signing identity: ${FUWA_CREATED_IDENTITY}"
print -r -- "Keep this identity for every current and future local macOS app."
