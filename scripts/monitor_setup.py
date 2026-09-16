"""On-demand readiness check and user-started, terminal-based monitor setup."""
import fcntl
import json
import os
import subprocess
import sys
from pathlib import Path


def check(system=Path('/'), access=os.access):
    installed = access(system / 'usr/bin/ddcutil', os.X_OK)
    driver = (system / 'sys/module/i2c_dev').exists() or any((system / 'sys/class/i2c-dev').glob('i2c-*'))
    buses = []
    for entry in (system / 'sys/class/i2c-dev').glob('i2c-*'):
        # Match the video-controller scope of ddcutil's packaged uaccess rule.
        for ancestor in (entry.resolve(), *entry.resolve().parents):
            if ancestor == system or ancestor == ancestor.parent:
                break
            try:
                if (ancestor / 'class').read_text().strip().startswith('0x03'):
                    buses.append(system / 'dev' / entry.name)
                    break
            except OSError:
                pass
    denied = sum(not access(bus, os.R_OK | os.W_OK) for bus in buses)
    state = ('missing-software' if not installed else 'missing-driver' if not driver
             else 'access-denied' if denied else 'no-display' if not buses else 'ready')
    return {'ok': True, 'state': state, 'installed': installed, 'driver': driver,
            'displayBuses': len(buses), 'deniedBuses': denied,
            'canPrepare': access(system / 'usr/bin/omarchy', os.X_OK) and access(system / 'usr/bin/sudo', os.X_OK)}


def prepare(runner=subprocess.run, checker=check):
    """Only fixed system commands receive privilege; this script stays unprivileged."""
    commands = []
    if not checker()['installed']:
        commands.append(['/usr/bin/omarchy', 'pkg', 'add', 'ddcutil'])
    commands.extend([
        ['/usr/bin/sudo', '/usr/bin/modprobe', 'i2c-dev'],
        ['/usr/bin/sudo', '/usr/bin/udevadm', 'control', '--reload'],
        ['/usr/bin/sudo', '/usr/bin/udevadm', 'trigger', '--action=change', '--subsystem-match=i2c-dev'],
        ['/usr/bin/udevadm', 'settle', '--timeout=10'],
    ])
    for command in commands:
        # The visible terminal owns password prompts and package-manager lifetime.
        # Never time out or terminate a package transaction from the shell plugin.
        result = runner(command, check=False, env={**os.environ, 'PATH': '/usr/bin:/usr/share/omarchy/bin'})
        if result.returncode != 0:
            return False
    return checker()['state'] in ('ready', 'no-display')


def interactive():
    if not sys.stdin.isatty():
        print('Open monitor setup from OmaDeck Preferences.')
        return 1
    if os.geteuid() == 0:
        print('Open this setup as your regular desktop user, not as root.')
        return 1
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/' + str(os.getuid())))
    fd = os.open(runtime / 'omadeck-monitor-setup.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Monitor setup is already open. Use the existing setup window.')
            return 1
        print('\nOmaDeck — monitor setup\n', flush=True)
        print('This installs monitor-control support if needed and activates its display access rules.')
        print('It does not change monitor inputs or display layouts.')
        print('Enter your computer password if asked. Password characters may not appear as you type.\n', flush=True)
        try:
            success = prepare()
        except (OSError, KeyboardInterrupt):
            success = False
        if success:
            print('\nComputer setup finished. Return to OmaDeck and tap “Check again”.')
        else:
            print('\nSetup did not finish. The messages above explain what stopped it.')
            print('For a download error, check your internet connection and try again.')
            print('If another update is running, let it finish first. Do not remove package lock files.')
            print('If display access is still unavailable, restart the computer and check again.')
            print('Return to OmaDeck and tap “Check again”. You can reopen setup there.')
        try:
            input('\nPress Enter to close this window. ')
        except (EOFError, KeyboardInterrupt):
            pass
        return 0 if success else 1


if __name__ == '__main__':
    if sys.argv[1:] == ['check']:
        try:
            print(json.dumps(check(), separators=(',', ':')))
        except OSError:
            print(json.dumps({'ok': False, 'error': 'Could not check monitor support. Try again.'}))
            sys.exit(1)
    elif sys.argv[1:] == ['prepare']:
        try:
            sys.exit(interactive())
        except OSError:
            print('Could not open monitor setup. Return to OmaDeck and try again.', file=sys.stderr)
            sys.exit(1)
    else:
        print('Choose check or prepare.', file=sys.stderr)
        sys.exit(1)
