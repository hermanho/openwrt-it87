#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
repository=${1:-hermanho/openwrt-it87}
test ! -e "$repo/keys/openwrt-it87.pem" || { echo 'Public key already exists; do not rotate it accidentally.' >&2; exit 1; }
keydir=$(mktemp -d)
trap 'rm -rf "$keydir"' EXIT
umask 077
openssl ecparam -name prime256v1 -genkey -noout -out "$keydir/private.pem"
openssl ec -in "$keydir/private.pem" -pubout -out "$keydir/public.pem"
gh secret set APK_SIGNING_KEY_PEM --repo "$repository" < "$keydir/private.pem"
mkdir -p "$repo/keys"
cp "$keydir/public.pem" "$repo/keys/openwrt-it87.pem"
chmod 644 "$repo/keys/openwrt-it87.pem"
echo 'Signing secret uploaded. Commit keys/openwrt-it87.pem before publishing.'
echo 'The temporary private key is deleted on exit; rotate the key pair if the secret is lost.'
