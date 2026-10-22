#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
target=${1:-25.12.2-x86-64}
[[ "$target" =~ ^[a-zA-Z0-9._-]+$ ]] || { echo 'Invalid target' >&2; exit 1; }
config="$repo/targets/$target.json"
test -f "$config"
[[ $(uname -sm) == 'Linux x86_64' ]] || { echo 'Build on Linux x86_64 (GitHub Actions or a container).' >&2; exit 1; }
get() { jq -er --arg key "$1" '.[$key]' "$config"; }
release=$(get release)
board=$(get target)
sdk_archive=$(get sdk)
sdk_hash=$(get sdk_sha256)
kernel=$(get kernel)
abi=$(get kernel_abi)
kernel_release=$(get kernel_release)
work=${IT87_WORK_DIR:-"$repo/.work"}
sdk="$work/sdk-$target"
downloads="$work/downloads"
mkdir -p "$downloads" "$repo/dist/$target"
source_file="$repo/package/it87-it8613/src/it87.c"
printf '%s  %s\n' "$(get source_sha256)" "$source_file" | sha256sum -c -
archive="$downloads/$sdk_archive"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 --connect-timeout 20 --max-time 600 --output "$archive.part" \
        "https://downloads.openwrt.org/releases/$release/targets/$board/$sdk_archive"
    mv "$archive.part" "$archive"
fi
printf '%s  %s\n' "$sdk_hash" "$archive" | sha256sum -c -
if [[ ! -f "$sdk/.it87-sdk-hash" ]] || [[ $(cat "$sdk/.it87-sdk-hash") != "$sdk_hash" ]]; then
    test ! -e "$sdk" || { echo "Remove stale SDK directory: $sdk" >&2; exit 1; }
    mkdir -p "$sdk"
    tar --zstd -xf "$archive" -C "$sdk" --strip-components=1
    printf '%s\n' "$sdk_hash" > "$sdk/.it87-sdk-hash"
fi
# Verify the SDK's own ABI; never invent a compatible dependency for an unknown SDK.
grep -Fq "$abi" "$sdk/include/kernel.mk"
kernel_dir="$sdk/build_dir/target-x86_64_musl/linux-x86_64/linux-$kernel"
[[ $(cat "$kernel_dir/include/config/kernel.release") == "$kernel" ]]
grep -Eq "^LINUX_RELEASE[?:]?=$kernel_release$" "$sdk/include/kernel-version.mk"
package="$sdk/package/it87-it8613"
mkdir -p "$package"
cp -R "$repo/package/it87-it8613/." "$package/"
(
    cd "$sdk"
    touch .config
    # Preserve the prepared kernel configuration; change package selection only.
    # SDK defaults can select every kmod, including the conflicting stock package.
    for option in ALL ALL_NONSHARED ALL_KMODS PACKAGE_kmod-hwmon-it87 PACKAGE_kmod-hwmon-it87-it8613; do
        sed -i "/^CONFIG_${option}=/d; /^# CONFIG_${option} is not set$/d" .config
    done
    printf '\n# CONFIG_ALL is not set\n# CONFIG_ALL_NONSHARED is not set\n# CONFIG_ALL_KMODS is not set\n# CONFIG_PACKAGE_kmod-hwmon-it87 is not set\nCONFIG_PACKAGE_kmod-hwmon-it87-it8613=m\n' >> .config
    make defconfig
    make -j"${IT87_JOBS:-2}" package/it87-it8613/compile V=s
)
mapfile -t packages < <(find "$sdk/bin" -type f -name 'kmod-hwmon-it87-it8613-*.apk' | sort)
[[ ${#packages[@]} == 1 ]] || { echo "Expected one APK, found ${#packages[@]}" >&2; exit 1; }
out="$repo/dist/$target"
cp "${packages[0]}" "$out/"
cp "$config" "$out/target.json"
apk="$sdk/staging_dir/host/bin/apk"
"$apk" adbdump --format json "${packages[0]}" > "$out/package.json"
python3 "$repo/scripts/verify-package.py" "$config" "$out/package.json"
find "$sdk/build_dir" -path '*/it87-it8613-*/it87.ko' -exec cp '{}' "$out/it87.ko" \;
test -s "$out/it87.ko"
strings "$out/it87.ko" | grep -F 'IT8613E'
strings "$out/it87.ko" | grep -F "vermagic=$kernel SMP mod_unload"
(
    cd "$out"
    sha256sum ./*.apk it87.ko target.json package.json > SHA256SUMS
)
echo "Build verified: $out"
