#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
feed=${1:?Usage: sign-feed.sh FEED_DIRECTORY}
test -n "${APK_SIGNING_KEY_PEM:?Set APK_SIGNING_KEY_PEM}"
feed=$(cd "$feed" && pwd)
keydir=$(mktemp -d)
trap 'rm -rf "$keydir"' EXIT
umask 077
printf '%s' "$APK_SIGNING_KEY_PEM" > "$keydir/private.pem"
openssl ec -in "$keydir/private.pem" -pubout -out "$keydir/public.pem"
cmp "$keydir/public.pem" "$repo/keys/openwrt-it87.pem"
mkdir "$keydir/trusted"
cp "$repo/keys/openwrt-it87.pem" "$keydir/trusted/"
cp "$repo/keys/openwrt-it87.pem" "$feed/"
cd "$feed"
shopt -s nullglob
packages=(*.apk)
[[ ${#packages[@]} -gt 0 ]]
for package in "${packages[@]}"; do
    apk adbsign --allow-untrusted --reset-signatures --sign-key "$keydir/private.pem" "$package"
done
apk mkndx --allow-untrusted --sign-key "$keydir/private.pem" --output packages.adb "${packages[@]}"
# adbsign can report a failure without a nonzero exit; verify every output.
apk --keys-dir "$keydir/trusted" verify "${packages[@]}" packages.adb
apk adbdump --format json packages.adb > index.json
sha256sum "${packages[@]}" packages.adb openwrt-it87.pem > SHA256SUMS
