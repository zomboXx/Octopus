"""Non-billable notification smoke test on the dedicated Octopus AVD.

Seeds a synthetic session close to minute 40, moves the normal APK to background,
then observes Android's real alarm and notification. Restores app data/permission
in finally. No integration APK, uninstall, server request or device-clock change.
"""
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

root = Path(__file__).resolve().parents[1]
adb = str(Path.home() / 'AppData/Local/Android/Sdk/platform-tools/adb.exe')
pkg = 'vn.octopus.mobile'

def run(*parts, data=None):
    return subprocess.run([adb, '-s', 'emulator-5554', *parts], input=data,
                          capture_output=True, check=True, timeout=30).stdout

assert 'Octopus_API_33' in run('emu', 'avd', 'name').decode()
run('shell', 'am', 'force-stop', pkg)
backup = root / f'.android-dev/pre-wellbeing-{time.time_ns()}.tar'
backup.parent.mkdir(exist_ok=True)
backup.write_bytes(run('exec-out', 'run-as', pkg, 'tar', '-cf', '-', 'shared_prefs', 'files'))
original_state = run('exec-out', 'run-as', pkg, 'cat', 'shared_prefs/octopus_prototype.xml')
package = run('shell', 'dumpsys', 'package', pkg).decode()
was_allowed = bool(re.search(r'android.permission.POST_NOTIFICATIONS: granted=true', package))
out = root / 'test-results'
out.mkdir(exist_ok=True)

def iso(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat().replace('+00:00', 'Z')

def own_notification():
    dump = run('shell', 'dumpsys', 'notification', '--noredact').decode('utf-8', errors='replace')
    blocks = re.split(r'(?=NotificationRecord\()', dump)
    return next((block.split('  Notification List:')[0] for block in blocks
                 if block.startswith('NotificationRecord(') and f'pkg={pkg}' in block[:500]
                 and 'id=442' in block[:500]), None)

try:
    run('shell', 'pm', 'grant', pkg, 'android.permission.POST_NOTIFICATIONS')
    now = int(run('shell', 'date', '+%s').decode().strip())
    # Genuine production interval, accelerated only by the synthetic start time.
    start = now - 40 * 60 + 12
    state = {'version': 1, 'onboardingComplete': True,
             'profile': {'name': 'An', 'birthday': '2005-01-01', 'authMode': 'guest'},
             'tasks': [], 'plan': [], 'activities': [], 'circles': [], 'checkins': [], 'commitments': [],
             'wellbeingReminders': True, 'focusStart': iso(start), 'focusEnd': iso(start + 90 * 60),
             'focusMinutes': 0, 'protection': {'enabled': False, 'blockInternet': False}}
    mapping = ET.Element('map')
    ET.SubElement(mapping, 'string', {'name': 'state'}).text = json.dumps(state, ensure_ascii=False)
    run('exec-in', 'run-as', pkg, 'tee', 'shared_prefs/octopus_prototype.xml',
        data=ET.tostring(mapping, encoding='utf-8', xml_declaration=True))
    run('shell', 'am', 'start', '-n', pkg + '/.MainActivity')
    time.sleep(3)
    run('shell', 'input', 'keyevent', 'KEYCODE_HOME')
    print('Normal APK is in background; waiting for real Android alarm.', flush=True)
    deadline = time.monotonic() + 85
    notification = None
    while time.monotonic() < deadline:
        notification = own_notification()
        if notification:
            break
        time.sleep(1)
    if not notification:
        raise RuntimeError('No wellbeing notification observed within the smoke-test window.')
    assert 'octopus_wellbeing_v1' in notification
    assert '40' in notification
    time.sleep(.8)  # Allow SystemUI to draw its heads-up animation after notify().
    (out / 'wellbeing062-native-headsup.png').write_bytes(run('exec-out', 'screencap', '-p'))
    # Save only our record, not other applications' notification data.
    (out / 'wellbeing062-notification.txt').write_text(notification.split('Ranking Config:')[0], encoding='utf-8')
    run('shell', 'cmd', 'statusbar', 'expand-notifications')
    time.sleep(1)
    (out / 'wellbeing062-native-notification.png').write_bytes(run('exec-out', 'screencap', '-p'))
    values = ET.fromstring(run('exec-out', 'run-as', pkg, 'cat', 'shared_prefs/octopus_wellbeing.xml'))
    assert values.find("long[@name='delivered']").attrib['value'] == '1'
    time.sleep(3)
    values = ET.fromstring(run('exec-out', 'run-as', pkg, 'cat', 'shared_prefs/octopus_wellbeing.xml'))
    assert values.find("long[@name='delivered']").attrib['value'] == '1'
    run('shell', 'uiautomator', 'dump', '/sdcard/octopus-wellbeing-test.xml')
    nodes = ET.fromstring(run('shell', 'cat', '/sdcard/octopus-wellbeing-test.xml')).iter('node')
    item = next(n for n in nodes if 'Đã tập trung 40 phút' in n.get('text', ''))
    x1, y1, x2, y2 = map(int, re.findall(r'\d+', item.attrib['bounds']))
    run('shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))
    time.sleep(2)
    (out / 'wellbeing062-native-opened.png').write_bytes(run('exec-out', 'screencap', '-p'))
    print(json.dumps({'ok': True, 'background': True, 'realAlarm': True, 'boundary': 1,
                      'channel': 'octopus_wellbeing_v1', 'duplicate': False}), flush=True)
finally:
    run('shell', 'cmd', 'statusbar', 'collapse')
    run('shell', 'am', 'force-stop', pkg)
    run('exec-in', 'run-as', pkg, 'tar', '-xf', '-', data=backup.read_bytes())
    restored = run('exec-out', 'run-as', pkg, 'cat', 'shared_prefs/octopus_prototype.xml')
    assert ET.fromstring(restored).find("string[@name='state']").text == ET.fromstring(original_state).find("string[@name='state']").text
    if not was_allowed:
        run('shell', 'pm', 'revoke', pkg, 'android.permission.POST_NOTIFICATIONS')
    run('shell', 'am', 'start', '-n', pkg + '/.MainActivity')
    print('Original guest state and notification permission restored.', flush=True)
