# Driver provenance

Base: Linux v6.12.74, `drivers/hwmon/it87.c`.
https://raw.githubusercontent.com/gregkh/linux/v6.12.74/drivers/hwmon/it87.c
Base SHA256: 814a4f9ce1b63a16c04ae9fcd702a51eb4e2c763a548a4df443c06e01539a537

Basis: Jerome Tollet, [RFC PATCH v2] hwmon: it87: Add basic IT8613E fan monitoring
support, 2026-08-29. Original patch and authorship:
https://lists.openwall.net/linux-kernel/2026/08/29/387

Local adaptations:
1. Adapt the chip enum to v6.12.74, which has no `it8689` entry.
2. For IT8613, skip tachometer-enable and monitoring-start writes during probe/resume.
3. For IT8613, stop cached register updates after fan readings, avoiding unrelated
   temperature, PWM and alarm register maps.

`patches/it8613-6.12.74-fan-readonly.patch` records the complete changes, not just the
upstream RFC. This is an experimental backport, not an upstream release.

The resulting source was compiled with the official 25.12.2 x86/64 SDK and tested
on TianBei N1 PRO / IT8613E rev 12. Detection, repeated RPM reads and module reload
succeeded. No PWM attributes were exposed; the kernel remained 6.12.74.
