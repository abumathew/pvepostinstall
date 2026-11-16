import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('repos', ROOT / 'scripts/configure_repos.py')
repos = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repos)


class Repositories(unittest.TestCase):
    def test_legacy_and_deb822_idempotence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            directory = root / 'etc/apt/sources.list.d'
            directory.mkdir(parents=True)
            key = root / 'usr/share/keyrings/proxmox-archive-keyring.gpg'
            key.parent.mkdir(parents=True)
            key.touch()
            debian = 'deb http://deb.debian.org/debian trixie main\n'
            source = root / 'etc/apt/sources.list'
            source.write_text(debian + 'deb https://enterprise.proxmox.com/debian/pve trixie pve-enterprise\n')
            ceph = directory / 'ceph.sources'
            ceph.write_text('Types: deb\nURIs: https://enterprise.proxmox.com/debian/ceph-squid\nSuites: trixie\nComponents: enterprise\n')
            pve = directory / 'pve.sources'
            pve.write_text('Types: deb\nURIs: http://download.proxmox.com/debian/pve\nSuites: trixie\nComponents: pve-no-subscription\n')
            repos.configure(root, 'trixie')
            before = {p: p.read_text() for p in directory.iterdir()}
            repos.configure(root, 'trixie')
            self.assertEqual(before, {p: p.read_text() for p in directory.iterdir()})
            self.assertTrue(source.read_text().startswith(debian))
            self.assertIn('# pvepostinstall disabled: deb', source.read_text())
            self.assertIn('Enabled: no', pve.read_text())
            self.assertIn('Components: no-subscription', ceph.read_text())
            self.assertIn('download.proxmox.com/debian/ceph-squid', ceph.read_text())
            self.assertIn('Signed-By:', (directory / 'pvepostinstall.sources').read_text())

    def test_mixed_stanza_rejected(self):
        with self.assertRaises(ValueError):
            repos.rewrite('URIs: http://download.proxmox.com/debian/pve http://other.test/debian\nComponents: pve-no-subscription\n', True)

    def test_bookworm_no_suite_change(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repos.configure(root, 'bookworm')
            self.assertIn('Suites: bookworm', (root / 'etc/apt/sources.list.d/pvepostinstall.sources').read_text())


class Bootstrap(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(ROOT / 'config', self.root / 'config')
        shutil.copy(ROOT / '.env.example', self.root / '.env')
        shutil.copy(ROOT / 'bootstrap.sh', self.root)
        (self.root / 'scripts').mkdir()
        # Only the fixture bypasses root; no host commands are executed.
        common = (ROOT / 'scripts/common.sh').read_text().replace('[[ "${EUID}" -eq 0 ]] || fail "Run this as root."', ':')
        (self.root / 'scripts/common.sh').write_text(common)
        self.state = self.root / 'state'
        self.log = self.root / 'calls'
        for step in ('repos', 'post_install', 'nut_client', 'sensors', 'storage', 'iommu', 'powertop', 'verify'):
            (self.root / f'scripts/{step}.sh').write_text(f'echo {step} >> "$CALLS"\n')

    def run_bootstrap(self, *args, success=True):
        result = subprocess.run(['bash', str(self.root / 'bootstrap.sh'), *args], env={**os.environ, 'STATE_DIR': str(self.state), 'CALLS': str(self.log)}, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_reboot_resume_rerun_and_repair(self):
        self.run_bootstrap()
        self.assertEqual(self.log.read_text().splitlines(), ['repos', 'post_install'])
        self.run_bootstrap()
        self.assertEqual(self.log.read_text().splitlines(), ['repos', 'post_install'])
        (self.state / 'update-reboot').write_text('previous-boot')
        self.run_bootstrap()
        self.assertTrue((self.state / 'verify.done').exists())
        count = len(self.log.read_text().splitlines())
        self.run_bootstrap()
        self.assertEqual(len(self.log.read_text().splitlines()), count + 1)  # repo reconciliation
        self.run_bootstrap('--repair-gui')
        self.assertEqual(self.log.read_text().splitlines()[-1], 'sensors')
        self.run_bootstrap('--rerun')
        self.assertEqual(self.log.read_text().splitlines()[-1], 'post_install')
        self.assertTrue((self.state / 'update-reboot').exists())
        (self.state / 'update-reboot').write_text('previous-boot\n--rerun\n')
        self.run_bootstrap()
        self.assertEqual(self.log.read_text().splitlines().count('nut_client'), 2)
        self.run_bootstrap('--rerun')
        self.run_bootstrap('--reset')
        self.assertTrue((self.state / 'update-reboot').exists())

    def test_failed_step_is_retryable(self):
        (self.root / 'scripts/post_install.sh').write_text('exit 1\n')
        self.run_bootstrap(success=False)
        self.assertFalse((self.state / 'post_install.done').exists())
        self.assertFalse((self.state / 'update-reboot').exists())

    def test_interrupted_rerun_clears_stale_markers(self):
        self.state.mkdir()
        for step in ('post_install', 'nut_client', 'sensors', 'storage', 'iommu', 'powertop', 'verify'):
            (self.state / f'{step}.done').touch()
        self.run_bootstrap('--rerun')
        self.assertFalse((self.state / 'sensors.done').exists())
        (self.state / 'update-reboot').write_text('previous-boot\n--rerun\n')
        (self.root / 'scripts/nut_client.sh').write_text('exit 1\n')
        self.run_bootstrap(success=False)
        (self.root / 'scripts/nut_client.sh').write_text('echo nut_client >> "$CALLS"\n')
        self.run_bootstrap()
        self.assertIn('sensors', self.log.read_text().splitlines())
        self.assertTrue((self.state / 'verify.done').exists())

    def test_backup_is_repeatable(self):
        path = self.root / 'config.txt'
        path.write_text('original')
        result = subprocess.run(['bash', '-e', '-c', 'source "$1"; backup_file "$2"; backup_file "$2"', '_', str(self.root / 'scripts/common.sh'), str(path)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(path.with_suffix('.txt.bak').read_text(), 'original')

    def test_help_and_unknown_arguments(self):
        self.run_bootstrap('--help')
        self.run_bootstrap('--unknown', success=False)


if __name__ == '__main__':
    unittest.main()
