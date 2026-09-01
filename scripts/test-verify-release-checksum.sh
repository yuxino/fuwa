#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
verifier="$script_dir/verify-release-checksum.sh"
fixture_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fuwa-checksum-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT

package_name="Fuwa-0.1.2-windows-arm64-setup.exe"
package_path="$fixture_dir/$package_name"
checksum_path="$fixture_dir/${package_name}.sha256"
printf 'Fuwa checksum parser fixture\n' > "$package_path"
package_hash="$(sha256sum "$package_path" | awk '{ print tolower($1) }')"

expect_failure() {
  if bash "$verifier" \
      "$package_path" "$checksum_path" "$package_hash" >/dev/null 2>&1; then
    echo "Checksum verifier unexpectedly accepted invalid fixture: $1" >&2
    exit 1
  fi
}

# This is a literal CRLF record, matching CPack's Windows output bytes.
printf '%s  %s\r\n' "$package_hash" "$package_name" > "$checksum_path"
bash "$verifier" "$package_path" "$checksum_path" "$package_hash"

# A normal LF record remains valid for the macOS package checksum.
printf '%s  %s\n' "$package_hash" "$package_name" > "$checksum_path"
bash "$verifier" "$package_path" "$checksum_path" "$package_hash"

printf '%s  %s\r\n%s  %s\r\n' \
  "$package_hash" "$package_name" \
  "$package_hash" "$package_name" > "$checksum_path"
expect_failure 'multiple non-empty records'

printf '%s  %s\r\n' "$package_hash" 'wrong-name.exe' > "$checksum_path"
expect_failure 'wrong filename'

wrong_hash="$(printf '%064d' 0)"
printf '%s  %s\r\n' "$wrong_hash" "$package_name" > "$checksum_path"
expect_failure 'wrong recorded hash'

printf '%s  %s\r\r\n' "$package_hash" "$package_name" > "$checksum_path"
expect_failure 'more than one terminal carriage return'

echo 'Release checksum parser tests passed.'
