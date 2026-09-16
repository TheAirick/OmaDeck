import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

source = Path(__file__).resolve().parents[1] / 'scripts/launcher-command'
loader = importlib.machinery.SourceFileLoader('launcher', str(source))
spec = importlib.util.spec_from_loader(loader.name, loader)
launcher = importlib.util.module_from_spec(spec)
loader.exec_module(launcher)

class CommandLauncher(unittest.TestCase):
    def test_saved_identity_and_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            filename = Path(directory) / 'launcher.json'
            command = dict(id='custom:example', command='touch should-not-exist', directory='', terminal=False)
            filename.write_text(json.dumps(dict(version=2, entries=['custom:example'], custom=[command])))
            self.assertEqual(launcher.read_command(filename, 'custom:example'), command)
            self.assertFalse((Path(directory) / 'should-not-exist').exists())
            with self.assertRaises(ValueError): launcher.read_command(filename, 'custom:missing')
            link = Path(directory) / 'link.json'; link.symlink_to(filename)
            with self.assertRaises(OSError): launcher.read_command(link, 'custom:example')
            filename.chmod(0o666)
            with self.assertRaises(ValueError): launcher.read_command(filename, 'custom:example')

    def test_exact_shell_command_folder_and_terminal_argv(self):
        with tempfile.TemporaryDirectory(prefix='omadeck command ') as directory:
            command = 'printf "%s" "a quoted value & a semicolon;" > "output file"'
            entry = dict(command=command, directory=directory, terminal=False)
            class Finished:
                def wait(self, timeout): return 0
            calls = []
            def capture(argv, **kwargs): calls.append((argv, kwargs)); return Finished()
            with patch.object(launcher.subprocess, 'Popen', side_effect=capture), patch.object(launcher.os, 'access', return_value=True):
                launcher.launch(entry)
            argv, kwargs = calls[0]
            self.assertEqual(argv, ['/usr/bin/uwsm-app', '--', '/usr/bin/bash', '-c', command])
            self.assertEqual(kwargs['cwd'], directory)
            self.assertTrue(kwargs['close_fds'] and kwargs['start_new_session'])
            subprocess.run(argv[2:], cwd=kwargs['cwd'], check=True)
            self.assertEqual((Path(directory) / 'output file').read_text(), 'a quoted value & a semicolon;')
            entry['terminal'] = True
            with patch.object(launcher.subprocess, 'Popen', return_value=Finished()) as process, patch.object(launcher.os, 'access', return_value=True):
                launcher.launch(entry)
                self.assertEqual(process.call_args.args[0][2:4], ['/usr/bin/xdg-terminal-exec', '--dir=' + directory])

    def test_unavailable_folder_and_failed_launch(self):
        with patch.object(launcher.subprocess, 'Popen') as process:
            with self.assertRaises(ValueError): launcher.launch(dict(command='true', directory='/not-an-omadeck-test-folder'))
            process.assert_not_called()
        with tempfile.TemporaryDirectory() as directory, patch.object(launcher.subprocess, 'Popen') as process, patch.object(launcher.os, 'access', return_value=True):
            process.return_value.wait.return_value = 1
            with self.assertRaises(RuntimeError): launcher.launch(dict(command='false', directory=directory))
            process.return_value.wait.side_effect = subprocess.TimeoutExpired('fixture', 0.2)
            launcher.launch(dict(command='long-running-fixture', directory=directory))
            process.return_value.kill.assert_not_called()

if __name__ == '__main__': unittest.main()
