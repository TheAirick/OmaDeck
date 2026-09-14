import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

spec = importlib.util.spec_from_file_location('monitor_setup', Path(__file__).parents[1] / 'scripts/monitor_setup.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class MonitorSetup(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for directory in ['usr/bin', 'sys/module/i2c_dev', 'sys/class/i2c-dev', 'sys/devices/video/i2c-3', 'dev']:
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        for name in ['ddcutil', 'omarchy', 'sudo']:
            path = self.root / 'usr/bin' / name
            path.touch()
            path.chmod(0o700)
        (self.root / 'sys/devices/video/class').write_text('0x030000\n')
        (self.root / 'sys/class/i2c-dev/i2c-3').symlink_to(self.root / 'sys/devices/video/i2c-3')
        (self.root / 'dev/i2c-3').touch()

    def test_check_reports_software_driver_and_access_separately(self):
        self.assertEqual(setup.check(self.root)['state'], 'ready')
        denied = setup.check(self.root, lambda path, mode: False if path.name == 'i2c-3' else os.access(path, mode))
        self.assertEqual((denied['state'], denied['deniedBuses']), ('access-denied', 1))
        (self.root / 'sys/class/i2c-dev/i2c-3').unlink()
        (self.root / 'sys/module/i2c_dev').rmdir()
        self.assertEqual(setup.check(self.root)['state'], 'missing-driver')
        (self.root / 'usr/bin/ddcutil').unlink()
        self.assertEqual(setup.check(self.root)['state'], 'missing-software')

    def test_non_display_buses_do_not_require_broader_permissions(self):
        (self.root / 'sys/devices/video/class').write_text('0x0c0500\n')
        state = setup.check(self.root, lambda path, mode: False if path.name == 'i2c-3' else os.access(path, mode))
        self.assertEqual(state['displayBuses'], 0)
        self.assertEqual(state['state'], 'no-display')

    def test_prepare_uses_only_fixed_packaged_commands_then_rechecks(self):
        calls = []
        states = iter([{'installed': False}, {'state': 'ready'}])
        def runner(command, **kwargs):
            calls.append(command)
            self.assertFalse(kwargs['check'])
            return SimpleNamespace(returncode=0)
        self.assertTrue(setup.prepare(runner, lambda: next(states)))
        self.assertEqual(calls, [
            ['/usr/bin/omarchy', 'pkg', 'add', 'ddcutil'],
            ['/usr/bin/sudo', '/usr/bin/modprobe', 'i2c-dev'],
            ['/usr/bin/sudo', '/usr/bin/udevadm', 'control', '--reload'],
            ['/usr/bin/sudo', '/usr/bin/udevadm', 'trigger', '--action=change', '--subsystem-match=i2c-dev'],
            ['/usr/bin/udevadm', 'settle', '--timeout=10'],
        ])

    def test_cancelled_or_failed_install_stops_before_access_changes(self):
        calls = []
        def runner(command, **kwargs):
            calls.append(command)
            return SimpleNamespace(returncode=1)
        self.assertFalse(setup.prepare(runner, lambda: {'installed': False}))
        self.assertEqual(calls, [['/usr/bin/omarchy', 'pkg', 'add', 'ddcutil']])

    def test_successful_commands_are_not_enough_to_claim_readiness(self):
        calls = []
        def runner(command, **kwargs):
            calls.append(command)
            return SimpleNamespace(returncode=0)
        self.assertFalse(setup.prepare(runner, lambda: {'installed': True, 'state': 'access-denied'}))
        self.assertNotIn('ddcutil', [arg for call in calls for arg in call])


if __name__ == '__main__':
    unittest.main()
