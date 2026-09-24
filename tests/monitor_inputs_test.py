import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('monitor_inputs', Path(__file__).parents[1] / 'scripts/monitor_inputs.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)


class MonitorInputs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.edid = bytearray(128)
        self.edid[:8] = bytes.fromhex('00ffffffffffff00')
        self.edid[-1] = -sum(self.edid) % 256
        folder = self.root / 'card1-DP-1'
        folder.mkdir()
        (folder / 'edid').write_bytes(self.edid)
        (folder / 'status').write_text('connected\n')
        self.key = hashlib.sha256(self.edid).hexdigest()
        self.detect = 'Display 4\n   I2C bus: /dev/i2c-99\n   DRM connector: card1-DP-1\n   Monitor: MFG:Office:serial\n'
        self.calls = []

    def runner(self, arguments, deadline):
        self.calls.append(arguments)
        if arguments == ['detect', '--brief']:
            return self.detect
        if 'capabilities' in arguments:
            return 'Unparsed capabilities string: (vcp(10 60(0F 11 13) D6(01 04)))'
        return ''

    def test_scan_is_read_only_and_preserves_unknown_input_codes(self):
        result = bridge.execute(['scan'], self.runner, self.root)
        self.assertTrue(result['ok'])
        row = result['monitors'][0]
        self.assertEqual(row['id'], self.key)
        self.assertEqual([source['code'] for source in row['inputs']], ['0f', '11', '13'])
        self.assertEqual(row['inputs'][2]['label'], 'Input 0x13')
        self.assertNotIn('edid', row)
        self.assertFalse(any('setvcp' in call for call in self.calls))

    def test_switch_matches_hardware_instead_of_changed_display_or_bus_number(self):
        bridge.execute(['switch', self.key, '11'], self.runner, self.root)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.calls[-1], ['--skip-ddc-checks', '--edid', self.edid.hex(), 'setvcp', '0x60', '0x11', '--noverify'])
        self.assertNotIn('--bus', self.calls[-1])

    def test_missing_or_ambiguous_monitor_never_switches(self):
        (self.root / 'card1-DP-1/status').write_text('disconnected\n')
        with self.assertRaises(bridge.MonitorError):
            bridge.execute(['switch', self.key, '11'], self.runner, self.root)
        (self.root / 'card1-DP-1/status').write_text('connected\n')
        duplicate = self.root / 'card1-DP-2'
        duplicate.mkdir()
        (duplicate / 'edid').write_bytes(self.edid)
        (duplicate / 'status').write_text('connected\n')
        with self.assertRaises(bridge.MonitorError):
            bridge.execute(['switch', self.key, '11'], self.runner, self.root)
        self.assertFalse(any('setvcp' in call for call in self.calls))

    def test_invalid_requests_and_corrupt_identity_never_switch(self):
        for arguments in [['switch', '../bad', '11'], ['switch', self.key, '11;exit'], ['switch', self.key, '00']]:
            with self.assertRaises(bridge.MonitorError):
                bridge.execute(arguments, self.runner, self.root)
        (self.root / 'card1-DP-1/edid').write_bytes(bytes(128))
        with self.assertRaises(bridge.MonitorError):
            bridge.execute(['switch', self.key, '11'], self.runner, self.root)
        self.assertFalse(any('setvcp' in call for call in self.calls))

    def test_capability_failure_remains_visible_without_guessing_inputs(self):
        def failed_capabilities(arguments, deadline):
            if 'capabilities' in arguments:
                raise bridge.MonitorError('No DDC response')
            return self.runner(arguments, deadline)
        row = bridge.execute(['scan'], failed_capabilities, self.root)['monitors'][0]
        self.assertEqual(row['inputs'], [])
        self.assertEqual(row['error'], 'No DDC response')


if __name__ == '__main__':
    unittest.main()
