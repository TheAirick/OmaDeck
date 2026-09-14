"""Small, on-demand DDC input bridge. No settings, scripts, or polling daemon."""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

INPUT_NAMES = {1: 'VGA 1', 2: 'VGA 2', 3: 'DVI 1', 4: 'DVI 2',
               15: 'DisplayPort 1', 16: 'DisplayPort 2', 17: 'HDMI 1', 18: 'HDMI 2'}


class MonitorError(Exception):
    pass


def run_ddc(arguments, deadline):
    remaining = min(8, deadline - time.monotonic())
    if remaining <= 0:
        raise MonitorError('Monitor discovery timed out. Try scanning again.')
    try:
        result = subprocess.run(['/usr/bin/ddcutil', '--noconfig', *arguments],
                                capture_output=True, timeout=remaining,
                                env={'PATH': '/usr/bin', 'LC_ALL': 'C', 'HOME': os.path.expanduser('~')})
    except FileNotFoundError:
        raise MonitorError('Install ddcutil to use monitor switching.') from None
    except subprocess.TimeoutExpired:
        raise MonitorError('The monitor did not respond in time.') from None
    if result.returncode:
        raise MonitorError('Could not communicate with the monitor. Check DDC/CI and I2C access.')
    if len(result.stdout) > 65536:
        raise MonitorError('The monitor returned an oversized response.')
    return result.stdout.decode('utf-8', errors='replace')


def parse_detect(text):
    records = []
    for block in re.split(r'(?m)^(?=Display \d+\s*$|Invalid display)', text):
        if not re.match(r'Display \d+\s*\n', block):
            continue
        connector = re.search(r'DRM connector:\s*(card\d+-[A-Za-z0-9-]{1,48})\s*$', block, re.M)
        model = re.search(r'Monitor:\s*([^\n]+)', block)
        if not connector:
            continue
        parts = model.group(1).strip().split(':') if model else []
        name = parts[1].strip() if len(parts) > 1 else connector.group(1)
        records.append({'connector': connector.group(1), 'label': name[:48]})
    return records[:16]


def read_edid(connector, drm_root):
    try:
        with (Path(drm_root) / connector / 'edid').open('rb') as stream:
            edid = stream.read(128)
    except OSError:
        raise MonitorError('The monitor disconnected. Scan again.') from None
    if len(edid) != 128 or edid[:8] != bytes.fromhex('00ffffffffffff00') or sum(edid) % 256:
        raise MonitorError('The monitor has no usable hardware identity.')
    return edid


def discover(runner, deadline, drm_root):
    rows = parse_detect(runner(['detect', '--brief'], deadline))
    result = []
    for row in rows:
        try:
            edid = read_edid(row['connector'], drm_root)
        except MonitorError:
            continue
        result.append({**row, 'id': hashlib.sha256(edid).hexdigest(), 'edid': edid.hex()})
    return result


def parse_inputs(text):
    match = re.search(r'(?:^|[\s(])60\(([^()]{0,1024})\)', text, re.I)
    if not match:
        return []
    values = []
    for token in match.group(1).split():
        if not re.fullmatch(r'[0-9a-fA-F]{2}', token) or int(token, 16) == 0:
            continue
        code = token.lower()
        if any(value['code'] == code for value in values):
            continue
        values.append({'code': code, 'label': INPUT_NAMES.get(int(code, 16), 'Input 0x' + code.upper())})
    return values[:32]


def execute(arguments, runner=run_ddc, drm_root='/sys/class/drm'):
    deadline = time.monotonic() + 20
    if arguments == ['scan']:
        monitors = discover(runner, deadline, drm_root)
        public = []
        for monitor in monitors:
            row = {key: monitor[key] for key in ['id', 'label', 'connector']}
            row.update(inputs=[], error='')
            if sum(other['id'] == monitor['id'] for other in monitors) != 1:
                row['error'] = 'Multiple monitors report the same identity; switching is unavailable.'
            else:
                try:
                    row['inputs'] = parse_inputs(runner(['--edid', monitor['edid'], 'capabilities', '--terse'], deadline))
                    if not row['inputs']:
                        row['error'] = 'This monitor does not report selectable inputs.'
                except MonitorError as error:
                    row['error'] = str(error)
            public.append(row)
        return {'ok': True, 'monitors': public}
    if len(arguments) != 3 or arguments[0] != 'switch' or not re.fullmatch(r'[0-9a-f]{64}', arguments[1]) \
            or not re.fullmatch(r'[0-9a-f]{2}', arguments[2]) or arguments[2] == '00':
        raise MonitorError('Invalid monitor input request.')
    matches = [row for row in discover(runner, deadline, drm_root) if row['id'] == arguments[1]]
    if len(matches) != 1:
        raise MonitorError('The saved monitor is disconnected or ambiguous. Scan again.')
    # Match EDID again inside ddcutil; display numbers and I2C buses can change.
    runner(['--edid', matches[0]['edid'], 'setvcp', '0x60', '0x' + arguments[2], '--noverify'], deadline)
    return {'ok': True, 'message': 'Input switch requested'}


def main():
    try:
        result = execute(sys.argv[1:])
    except (MonitorError, OSError) as error:
        result = {'ok': False, 'error': str(error) if isinstance(error, MonitorError) else 'Monitor access failed.'}
    print(json.dumps(result, ensure_ascii=True, separators=(',', ':')))
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
