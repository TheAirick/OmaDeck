import importlib.util
from pathlib import Path
import re
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('bridge', Path(__file__).resolve().parents[1] / 'scripts/notification_control.py')
bridge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bridge)

class NotificationCommands(unittest.TestCase):
    def test_independent_availability_and_malformed_status(self):
        with patch.object(bridge, 'run_command', side_effect=[RuntimeError(), '{"enabled":true}']):
            self.assertEqual(bridge.status(), dict(ok=True, dndAvailable=False, nightAvailable=True, dnd=False, night=True))
        for response in ('null', '[]', '{"enabled":"true"}', 'not json'):
            with patch.object(bridge, 'run_command', side_effect=['on', response]):
                state = bridge.status()
                self.assertTrue(state['dndAvailable'] and state['dnd'])
                self.assertFalse(state['nightAvailable'])

    def test_clear_serializes_owner_operations_and_stops_on_failure(self):
        with patch.object(bridge, 'run_command', side_effect=['ok', 'ok']) as run:
            self.assertTrue(bridge.dispatch('clear')['ok'])
            self.assertEqual([call.args for call in run.call_args_list], [
                ('omarchy-shell', 'notifications', 'dismissAll'), ('omarchy-shell', 'notifications', 'clear')])
        with patch.object(bridge, 'run_command', return_value='unavailable') as run:
            with self.assertRaises(RuntimeError): bridge.dispatch('clear')
            self.assertEqual(run.call_count, 1)
        with patch.object(bridge, 'run_command', side_effect=['ok', 'failed']):
            with self.assertRaises(RuntimeError): bridge.dispatch('clear')

    def test_setters_require_confirmed_state(self):
        with patch.object(bridge, 'run_command', return_value='on') as run:
            bridge.dispatch('dnd', 'on')
            run.assert_called_once_with('omarchy-shell', 'notifications', 'setDnd', 'on')
        with patch.object(bridge, 'run_command', return_value='disabled') as run:
            bridge.dispatch('night', 'off')
            run.assert_called_once_with('omarchy-shell', 'nightlight', 'disable')
        with patch.object(bridge, 'run_command', return_value='off'):
            with self.assertRaises(RuntimeError): bridge.dispatch('dnd', 'on')

    def test_focus_is_literal_and_invalid_input_executes_nothing(self):
        app = 'Chat.*; $(command) [test]'
        with patch.object(bridge, 'run_command', return_value='') as run:
            bridge.dispatch('focus', app)
            run.assert_called_once_with('omarchy-hyprland-focus-app', re.escape(app))
        with patch.object(bridge, 'run_command') as run:
            for action, value in [('clear', 'extra'), ('focus', ''), ('focus', 'a'*257), ('dnd', 'yes'), ('unknown', '')]:
                with self.assertRaises(ValueError): bridge.dispatch(action, value)
            run.assert_not_called()

    def test_fixed_path_argv_and_timeout(self):
        with patch.object(bridge.shutil, 'which', return_value='/usr/bin/omarchy-shell') as which, patch.object(bridge.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, 'off\n')) as run:
            self.assertEqual(bridge.run_command('omarchy-shell', 'notifications', 'dndState'), 'off')
            which.assert_called_once_with('omarchy-shell', path=bridge.SAFE_PATH)
            self.assertEqual(run.call_args.args[0], ['/usr/bin/omarchy-shell', 'notifications', 'dndState'])
            self.assertEqual(run.call_args.kwargs['timeout'], 3)
            self.assertTrue(run.call_args.kwargs['check'])
            self.assertNotIn('shell', run.call_args.kwargs)

if __name__ == '__main__': unittest.main()
