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
assert any(p.startswith('kmod-hwmon-it87=') for p in info['provides']), info['provides']
payload = json.dumps(package)
assert 'it87.ko' in payload, 'Module missing from APK'
assert 'hwmon-it87-it8613' in payload, 'Autoload file missing from APK'
print('Verified architecture, exact kernel ABI dependency, stock-package conflict and payload.')
