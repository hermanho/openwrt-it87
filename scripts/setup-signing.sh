#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
private_key=${1:?Usage: setup-signing.sh HOMEPROXY_PRIVATE_KEY_FILE [OWNER/REPOSITORY]}
repository=${2:-hermanho/openwrt-it87}
test -r "$private_key"
keydir=$(mktemp -d)
trap 'rm -rf "$keydir"' EXIT
umask 077
# Verify identity before uploading; never generate or substitute another key.
openssl ec -in "$private_key" -pubout -out "$keydir/public.pem"
cmp "$keydir/public.pem" "$repo/keys/openwrt-it87.pem" || {
    echo 'Private key does not match the committed HomeProxy public key.' >&2
    exit 1
}
gh api --method PUT "repos/$repository/environments/feed-production" >/dev/null
gh secret set APK_SIGNING_KEY_PEM --repo "$repository" --env feed-production < "$private_key"
# Remove the obsolete independent repository-level key only after the shared key is set.
if gh secret list --repo "$repository" --json name --jq '.[].name' | grep -qx APK_SIGNING_KEY_PEM; then
    gh secret delete APK_SIGNING_KEY_PEM --repo "$repository"
fi
echo 'Existing HomeProxy signing key configured in feed-production.'
