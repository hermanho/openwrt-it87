#!/usr/bin/env python3
"""Reject incorrect kernel dependencies, package conflicts or module payloads."""
import json
import sys

target = json.load(open(sys.argv[1]))
package = json.load(open(sys.argv[2]))
info = package['info']
assert info['name'] == 'kmod-hwmon-it87-it8613', info
assert info['arch'] == target['arch'], info
dependency = f"kernel={target['kernel']}~{target['kernel_abi']}-r{target['kernel_release']}"
assert dependency in info['depends'], info['depends']
assert f"kmod-hwmon-it87={info['version']}" in info['provides'], info['provides']
files = {
    f"{directory.get('name', '')}/{entry['name']}": entry
    for directory in package['paths']
    for entry in directory.get('files', [])
}
module = f"lib/modules/{target['kernel']}/it87.ko"
autoload = 'etc/modules.d/hwmon-it87-it8613'
assert module in files and files[module]['size'] > 0, 'Module missing from APK'
assert autoload in files and files[autoload]['size'] > 0, 'Autoload file missing from APK'
print('Verified architecture, exact kernel ABI dependency, stock-package conflict and payload.')
