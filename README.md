# OpenWrt IT8613 fan monitoring

Build a signed, installable APK for IT8613E fan-speed monitoring with GitHub Actions.
No firmware image or replacement kernel is built. The package compiles an external
`it87.ko` against the exact official OpenWrt SDK and uses OpenWrt's native
`KernelPackage` packaging, including the complete kernel ABI dependency.

## Supported target

| OpenWrt | Target | Kernel | Kernel ABI |
| --- | --- | --- | --- |
| 25.12.2 | x86/64 | 6.12.74 | dad96e0b324e75e311f44d061391d208 |

Package: `kmod-hwmon-it87-it8613`. It conflicts with stock `kmod-hwmon-it87`,
because both install `it87.ko`. A versioned `kmod-hwmon-it87` provide makes the
packages mutually exclusive under APK; `CONFLICTS` also records the build-time
conflict. GPIO and watchdog packages are separate and can remain.
The package version starts at `6.12.74.1-r2`; `1` is the backport version.

Tested on TianBei N1 PRO, Intel N150, IT8613E revision 12 at `0xa30`.
Initial readings were approximately 2,350–2,370 RPM on `fan2`; `fan3` reported 0.
The physical connector mapping has not been confirmed.

For IT8613, only fan RPM attributes are exposed. PWM, voltage, temperature, limits,
beeps and alarms are hidden. Monitoring-start and tachometer-enable writes are
skipped; BIOS remains responsible for fan control and must have enabled monitoring.

## GitHub Actions

Every push to `main`, pull request, or manual run builds and verifies the APK.
Download the APK and metadata from the run's `it87-25.12.2-x86-64-<commit>` artifact.
PR builds have no access to the signing secret and cannot publish a feed.

The workflow follows HomeProxy's three-job layout:

1. `build`: compile and verify the APK and build the pinned APK signing tool.
2. `publish`: use the `feed-production` Environment to sign APKs and the index,
   retain previous versions in the `feed` Release, and upload the Pages artifact.
3. `deploy`: deploy the signed feed to GitHub Pages using the `github-pages` Environment.

The signing key is the **same existing key as `hermanho/homeproxy`**. The committed
`keys/openwrt-it87.pem` is identical to HomeProxy's public key. Both repositories rotated to this shared key on 2026-10-22. Its PEM-file SHA-256
is `6482e69befdf634c47511007055c66b9101b47ba24d8f2fe2cd87df1d67c618e`.
Private keys are never committed. GitHub secrets cannot be read back or copied between repositories
through the API; import the original local key once:

```sh
bash scripts/setup-signing.sh /path/to/homeproxy-private.pem hermanho/openwrt-it87
```

The script verifies the private key against the committed public key before setting
`APK_SIGNING_KEY_PEM` in the `feed-production` Environment, then removes the
obsolete repository-level signing secret. It never creates a new key. Publishing fails if the secret is missing or the public key does not match.
Enable GitHub Pages with **GitHub Actions** as the source. The feed URL is:

```text
https://hermanho.github.io/openwrt-it87/packages.adb
```

The GitHub Release feed remains available as a fallback:
`https://github.com/hermanho/openwrt-it87/releases/download/feed/packages.adb`.

## Install the signed feed

Run these commands on the router. First confirm `apk info -v kernel` matches the
supported target above; the APK also enforces this dependency.

```sh
curl -fL https://hermanho.github.io/openwrt-it87/openwrt-it87.pem \
  -o /etc/apk/keys/openwrt-it87.pem
echo 'https://hermanho.github.io/openwrt-it87/packages.adb' \
  > /etc/apk/repositories.d/it87.list
apk update
apk add --simulate kmod-hwmon-it87-it8613
```

Install after reviewing the proposed replacement. APK replaces the stock driver
atomically using the versioned provide; unrelated thermal dependencies are retained:

```sh
mkdir -p /root/it87-backup
cp -p /lib/modules/$(uname -r)/it87.ko /root/it87-backup/it87.ko
# Installation does not unload an already loaded kernel module.
apk add kmod-hwmon-it87-it8613
[ ! -d /sys/module/it87 ] || rmmod it87
modprobe it87
sensors it8613-isa-0a30
```

The APK owns the module and its `/etc/modules.d/` autoload entry, so no manual
module copying is needed. A reboot is not required. Keep the existing working
module loaded until the replacement APK is installed successfully.

An unsigned artifact can be tested locally with `apk add --allow-untrusted ./FILE.apk`
and APK will replace the stock package; normal feed installs use signature verification.

### Restore the stock package

```sh
[ ! -d /sys/module/it87 ] || rmmod it87
apk del kmod-hwmon-it87-it8613
apk add kmod-hwmon-it87
```

The stock 6.12.74 driver cannot expose this IT8613's RPM. The earlier manual-test
backup at `/root/it8613-fan-backup-6.12.74-20261022/` is separate; after switching to
APK management, use package removal/reinstallation for rollback.

## Build locally

Use Linux x86_64 with the prerequisites listed in `.github/workflows/build.yml`:

```sh
bash scripts/build.sh 25.12.2-x86-64
```

Output is in `dist/25.12.2-x86-64/`: APK, module, target lock, package metadata and
checksums. SDK archives are checksum-verified and cached in `.work/downloads/`.
The build rejects an unexpected SDK ABI or incompatible APK metadata.

## Maintenance and provenance

- `package/it87-it8613/src/it87.c`: vendored, patched Linux 6.12.74 source, including
  upstream copyright notices. Its hash is pinned in `targets/25.12.2-x86-64.json`.
- `patches/it8613-6.12.74-fan-readonly.patch`: changes against original 6.12.74.
- `docs/provenance.md`: source URLs, patch basis and local adaptations.
- Bump `PKG_RELEASE` in the package Makefile whenever package contents change.
- A new kernel or ABI needs a new target lock and validation. Never bypass the
  kernel dependency or automatically build against the latest OpenWrt branch.
- Revisit the backport when the official driver gains IT8613 support.

Driver and packaging sources are GPL-2.0-or-later; see `LICENSE`.
