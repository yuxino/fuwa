#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" != "3" ]]; then
  echo "usage: $0 <package> <checksum> <accepted-sha256>" >&2
  exit 2
fi

package_path="$1"
checksum_path="$2"
accepted_hash="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
package_name="$(basename -- "$package_path")"

if [[ ! -f "$package_path" || ! -f "$checksum_path" ]]; then
  echo "The package and checksum must both exist as files." >&2
  exit 1
fi
if [[ ! "$accepted_hash" =~ ^[0-9a-f]{64}$ ]]; then
  echo "Accepted SHA-256 must contain exactly 64 hexadecimal characters." >&2
  exit 1
fi

line_count="$(
  awk 'NF { count += 1 } END { print count + 0 }' "$checksum_path"
)"
if [[ "$line_count" != "1" ]]; then
  echo "$checksum_path must contain exactly one non-empty checksum record." >&2
  exit 1
fi

read -r recorded_hash recorded_name < "$checksum_path"
recorded_hash="$(printf '%s' "$recorded_hash" | tr '[:upper:]' '[:lower:]')"
# CPack writes checksum files with the native Windows CRLF ending. Bash read
# removes LF but intentionally retains CR, so remove exactly one terminal CR.
# Any additional byte (including a second CR) remains and fails the exact-name
# comparison below.
recorded_name="${recorded_name%$'\r'}"
recorded_name="${recorded_name#\*}"
if [[ "$recorded_hash" != "$accepted_hash" \
    || "$recorded_name" != "$package_name" ]]; then
  echo "$checksum_path does not record the accepted package bytes." >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_hash="$(sha256sum "$package_path" | awk '{ print tolower($1) }')"
elif command -v shasum >/dev/null 2>&1; then
  actual_hash="$(shasum -a 256 "$package_path" | awk '{ print tolower($1) }')"
else
  echo "No SHA-256 tool is available; install sha256sum or shasum." >&2
  exit 1
fi
if [[ "$actual_hash" != "$accepted_hash" ]]; then
  echo "$package_path does not match its independently accepted SHA-256." >&2
  exit 1
fi
