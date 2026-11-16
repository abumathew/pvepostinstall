"""Exercise the repair transaction with fake packages/services, without a PVE host."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GuiRepair(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ('scripts', 'vendor', 'bin', 'state', 'config'):
            (self.root / directory).mkdir()
        self.js = self.root / 'live/pvemanagerlib.js'
        self.pm = self.root / 'live/Nodes.pm'
        self.js.parent.mkdir()
        self.js.write_text('original js')
        self.pm.write_text('original perl')
        shutil.copy(ROOT / 'config/defaults.env', self.root / 'config')
        shutil.copy(ROOT / '.env.example', self.root / '.env')
        common = (ROOT / 'scripts/common.sh').read_text().replace('[[ "${EUID}" -eq 0 ]] || fail "Run this as root."', ':')
        (self.root / 'scripts/common.sh').write_text(common)
        sensors = (ROOT / 'scripts/sensors.sh').read_text().replace('js=/usr/share/pve-manager/js/pvemanagerlib.js', f'js={self.js}').replace('pm=/usr/share/perl5/PVE/API2/Nodes.pm', f'pm={self.pm}')
        (self.root / 'scripts/sensors.sh').write_text(sensors)
        (self.root / 'vendor/pve-mod-gui-sensors.sh').write_text("""#!/bin/bash
printf '%s\\n' 'patched js' "itemId: 'upsc'" > "$PVE_MANAGER_LIB_JS_FILE"
printf '%s\\n' 'patched perl' '$res->{upsc}' > "$NODES_PM_FILE"
""")
        mocks = {
            'apt-get': 'echo "$*" >> "$ROOT_DIR/apt.log"\n[[ "$1" != download ]] || touch fixture.deb\n',
            'dpkg-query': 'if [[ "$1" == -S ]]; then echo "pve-manager: $2"; else echo 9.1-fixture; fi\n',
            'dpkg-deb': 'mkdir -p "$3$(dirname "$LIVE_JS")"; echo clean-js > "$3$LIVE_JS"; echo clean-perl > "$3$LIVE_PM"\n',
            'upsc': 'echo "device.model: Fixture UPS"\n',
            'perl': '[[ "${FAIL_PERL:-false}" != true ]]\n',
            'systemctl': 'if [[ "${FAIL_SERVICE:-false}" == true && ! -f "$ROOT_DIR/service-failed" ]]; then touch "$ROOT_DIR/service-failed"; exit 1; fi\n',
        }
        for name, body in mocks.items():
            script = self.root / 'bin' / name
            script.write_text('#!/bin/bash\n' + body)
            script.chmod(0o755)
        self.env = {**os.environ, 'ROOT_DIR': str(self.root), 'STATE_DIR': str(self.root / 'state'), 'PATH': str(self.root / 'bin') + ':' + os.environ['PATH'], 'LIVE_JS': str(self.js), 'LIVE_PM': str(self.pm)}

    def repair(self, success=True, **env):
        result = subprocess.run(['bash', '-e', '-c', 'source "$ROOT_DIR/scripts/common.sh"; load_config "$ROOT_DIR" --repair-gui; bash "$ROOT_DIR/scripts/sensors.sh"'], env={**self.env, **env}, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_repair_idempotence_and_partial_upgrade(self):
        self.repair()
        self.assertIn('download pve-manager=9.1-fixture', (self.root / 'apt.log').read_text())
        self.assertIn('intact', self.repair().stdout)
        self.js.write_text('upgraded js')
        self.repair()
        self.assertIn('patched js', self.js.read_text())
        self.assertIn('intact', self.repair().stdout)

    def test_validation_failure_keeps_live_files(self):
        self.repair(success=False, FAIL_PERL='true')
        self.assertEqual(self.js.read_text(), 'original js')
        self.assertEqual(self.pm.read_text(), 'original perl')
        self.assertFalse((self.root / 'state/gui.sha256').exists())

    def test_failed_restart_rolls_back_both_files(self):
        self.repair(success=False, FAIL_SERVICE='true')
        self.assertEqual(self.js.read_text(), 'original js')
        self.assertEqual(self.pm.read_text(), 'original perl')
        self.assertFalse((self.root / 'state/gui.sha256').exists())
