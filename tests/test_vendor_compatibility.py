"""Optional integration check against an externally supplied official source tree.

PVE_MANAGER_SOURCE=/path/to/pve-manager make test
No Proxmox services or package commands run. Requires node and perl.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = os.environ.get('PVE_MANAGER_SOURCE')


@unittest.skipUnless(SOURCE and shutil.which('node') and shutil.which('perl'),
                     'Set PVE_MANAGER_SOURCE and install node/perl for vendor compatibility checks')
class VendorCompatibility(unittest.TestCase):
    def test_actual_vendor_patch_and_renderers(self):
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            source = Path(SOURCE)
            pm = work / 'Nodes.pm'
            js = work / 'pvemanagerlib.js'
            pm.write_text((source / 'PVE/API2/Nodes.pm').read_text())
            js.write_text((source / 'www/manager6/node/StatusView.js').read_text() + '\n' +
                          (source / 'www/manager6/node/Summary.js').read_text())
            (work / 'bin').mkdir()
            (work / 'backups').mkdir()
            sensor_data = {
                'coretemp-isa-0000': {'Package id 0': {'temp1_input': 42}, 'Core 0': {'temp2_input': 40}},
                'nct6798-isa-0290': {'fan1': {'fan1_input': 800}},
            }
            (work / 'sensors.json').write_text(json.dumps(sensor_data))
            mocks = {
                'sensors': 'cat "$FIXTURE_DIR/sensors.json"',
                'upsc': "printf '%s\\n' 'device.model: Fixture UPS' 'ups.status: OL' 'battery.charge: 100'",
                'dmidecode': "printf '%s\\n' 'Manufacturer: Fixture' 'Product Name: Test Machine'",
            }
            for name, body in mocks.items():
                command = work / 'bin' / name
                command.write_text('#!/bin/sh\n' + body + '\n')
                command.chmod(0o755)
            # Source the actual vendor functions; bypass only its root check.
            vendor = (ROOT / 'vendor/pve-mod-gui-sensors.sh').read_text().split('# Process the arguments using')[0]
            (work / 'driver.sh').write_text(vendor + '\ncheck_root_privileges() { :; }\ninstall_mod\n')
            env = {**os.environ, 'PATH': str(work / 'bin') + ':' + os.environ['PATH'],
                   'FIXTURE_DIR': str(work), 'NODES_PM_FILE': str(pm),
                   'PVE_MANAGER_LIB_JS_FILE': str(js), 'PVE_MOD_STAGING': 'true',
                   'PVE_MOD_AUTOMATED': 'true', 'PVE_MOD_TMPDIR': str(work),
                   'PVE_MOD_BACKUP_DIR': str(work / 'backups'), 'UPS_NAME': 'fixture',
                   'UPS_HOST': 'localhost', 'GUI_CPU_MODE': 'C', 'GUI_TEMP_UNIT': 'C',
                   'GUI_ZERO_FANS': 'y', 'GUI_SYSTEM_INFO': '1'}
            def run(*args):
                result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stdout
            run('bash', str(work / 'driver.sh'))
            run('node', '--check', str(js))
            patched = pm.read_text()
            start = patched.index('\t\t# Collect sensor data from lm-sensors')
            end = patched.index("        my $dinfo = df('/', 1);")
            # PVE dependencies are unavailable locally: compile and execute just
            # the inserted retrievers, rather than pretending to load Nodes.pm.
            perl = work / 'retrievers.pl'
            perl.write_text('use strict; use warnings; my $res = {};\n' + patched[start:end] +
                            '\nuse JSON::PP; print encode_json($res);\n')
            run('perl', '-c', str(perl))
            response = json.loads(run('perl', str(perl)))
            self.assertEqual(json.loads(response['sensorsOutput'])['coretemp-isa-0000']['Core 0']['temp2_input'], 40)
            self.assertIn('Fixture UPS', response['upsc'])
            run('node', str(ROOT / 'tests/vendor_renderers.cjs'), str(js), str(work / 'sensors.json'))
