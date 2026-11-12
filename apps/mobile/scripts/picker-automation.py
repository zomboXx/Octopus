"""Select a non-sensitive fixture in Android's real document picker.

Run alongside the emulator integration suite. Refuses devices other than the
dedicated Octopus AVD. Uses only adb/uiautomator and Python's standard library.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

parser = argparse.ArgumentParser()
parser.add_argument('--serial', default='emulator-5554')
parser.add_argument('--grant-usage', action='store_true', help='Grant Usage Access only on this dedicated AVD')
parser.add_argument('--grant-guard', action='store_true', help='Grant native focus permissions only on this dedicated AVD')
args = parser.parse_args()
sdk = Path(os.environ.get('ANDROID_HOME', Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk'))
adb = str(sdk / 'platform-tools/adb.exe')

def run(*parts):
    try:
        return subprocess.run([adb, '-s', args.serial, *parts], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=20).stdout
    except subprocess.TimeoutExpired:
        # A fresh emulator can still be scanning files after boot_completed.
        # Retry on the next poll instead of aborting the whole picker harness.
        return ''

if 'Brain10_API_33' not in run('emu', 'avd', 'name').splitlines():
    raise SystemExit('Refusing to drive a device other than Brain10_API_33')
fixture = Path(__file__).resolve().parents[1] / 'integration_test/fixtures/activity.png'
if not fixture.exists():
    raise SystemExit('Missing fixture: integration_test/fixtures/activity.png')
print(run('push', str(fixture), '/sdcard/Download/octopus-test.png').strip(), flush=True)
run('shell', 'am', 'broadcast', '--async', '-a', 'android.intent.action.MEDIA_SCANNER_SCAN_FILE', '-d', 'file:///sdcard/Download/octopus-test.png')
deadline = time.monotonic() + 360
captured = set()
while time.monotonic() < deadline:
    if args.grant_usage:
        # flutter test reinstalls/removes the test app; apply after it appears.
        run('shell','appops','set','vn.octopus.mobile','GET_USAGE_STATS','allow')
    if args.grant_guard:
        run('shell','appops','set','vn.octopus.mobile','ACTIVATE_VPN','allow')
        run('shell','settings','put','secure','enabled_accessibility_services','vn.octopus.mobile/.FocusAccessibilityService')
        run('shell','settings','put','secure','accessibility_enabled','1')
    phase = run('shell', 'run-as', 'vn.octopus.mobile', 'cat', 'code_cache/octopus-ui-shot').strip()
    if phase in ['usage_bars', 'usage_donut', 'guard_off', 'ai_error', 'ai_preview', 'v05_home', 'v05_checkout', 'v05_circles'] and phase not in captured:
        if phase == 'guard_off':
            args.grant_guard = False
            run('shell','settings','put','secure','enabled_accessibility_services','null')
            run('shell','settings','put','secure','accessibility_enabled','0')
        else:
            destination = Path(__file__).resolve().parents[1] / 'test-results' / (phase + '.png')
            shot = subprocess.run([adb, '-s', args.serial, 'exec-out', 'screencap', '-p'], capture_output=True, timeout=20, check=True)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(shot.stdout)
        run('shell','run-as','vn.octopus.mobile','sh','-c',f'"echo {phase} > code_cache/octopus-ui-ack"')
        captured.add(phase)
    windows = run('shell', 'dumpsys', 'window')
    focus = next((line for line in windows.splitlines() if 'mCurrentFocus=' in line), '')
    is_picker = 'documentsui' in focus
    if not is_picker and not any(x in focus.lower() for x in ['launcher', 'pinitemrequest']):
        time.sleep(2)
        continue
    run('shell', 'uiautomator', 'dump', '/sdcard/octopus-picker.xml')
    xml = run('shell', 'cat', '/sdcard/octopus-picker.xml')
    try:
        nodes = list(ET.fromstring(xml).iter('node'))
    except ET.ParseError:
        time.sleep(1)
        continue
    if not is_picker:
        # Confirm only Octopus pin dialogs on the dedicated test launcher.
        if not any('octopus' in (n.get('text','') + n.get('content-desc','')).lower() for n in nodes):
            time.sleep(1)
            continue
        pin = [n for n in nodes if n.get('clickable') == 'true' and
               (n.get('resource-id','').endswith('/pin_item_confirmation') or n.get('text','').lower() in ['add to home screen','add automatically','add','thêm','thêm tự động'])]
        if pin:
            x1,y1,x2,y2 = map(int,re.findall(r'\d+',pin[0].get('bounds')))
            run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
            print('Confirmed Octopus home-screen widget pin.',flush=True)
        time.sleep(1)
        continue
    matches = [n for n in nodes if 'octopus-test' in (n.get('text', '') + n.get('content-desc', ''))]
    if matches:
        node = matches[0]
        x1,y1,x2,y2 = map(int,re.findall(r'\d+',node.get('bounds')))
        run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
        print('Selected octopus-test.png in Android document picker.',flush=True)
        break
    # Open the Downloads root if the picker started elsewhere.
    downloads = [n for n in nodes if n.get('text') in ['Downloads','Tải xuống']]
    navigation = [n for n in nodes if n.get('content-desc') in ['Show roots','Hiển thị thư mục gốc','Open navigation drawer']]
    choices = downloads or navigation
    if choices:
        x1,y1,x2,y2=map(int,re.findall(r'\d+',choices[0].get('bounds')))
        run('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
    time.sleep(2)
else:
    raise SystemExit('Document picker timed out')
