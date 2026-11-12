"""Companion to guard_test.dart. Never operates on a physical/non-Octopus device."""
import http.server
import os
from pathlib import Path
import subprocess
import threading
import time

ADB = str(Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe')
PACKAGE = 'vn.octopus.mobile'
SERVICE = PACKAGE + '/.FocusAccessibilityService'
OUT = Path(__file__).resolve().parents[1] / 'test-results/guard'
OUT.mkdir(parents=True, exist_ok=True)

def adb(*args, check=True):
    return subprocess.run([ADB, '-s', 'emulator-5554', *args], capture_output=True, timeout=15, check=check)

assert b'Brain10_API_33' in adb('emu', 'avd', 'name').stdout, 'Dedicated AVD required'

class Health(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{"ok":true}')
    def log_message(self, *args):
        pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 4188), Health)
threading.Thread(target=server.serve_forever, daemon=True).start()

def accessibility(enabled):
    adb('shell', 'settings', 'put', 'secure', 'enabled_accessibility_services', SERVICE if enabled else 'null')
    adb('shell', 'settings', 'put', 'secure', 'accessibility_enabled', '1' if enabled else '0')

def open_app():
    adb('shell', 'am', 'start', '-n', PACKAGE + '/.MainActivity')

def chrome():
    adb('shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'http://10.0.2.2:4188/health', '-p', 'com.android.chrome')

previous = ''
deadline = time.monotonic() + 480
try:
    while time.monotonic() < deadline:
        result = adb('shell', 'run-as', PACKAGE, 'cat', 'code_cache/octopus-guard-phase', check=False)
        phase = result.stdout.decode().strip() if result.returncode == 0 else ''
        if not phase or phase == previous:
            time.sleep(.4); continue
        if phase == 'permissions':
            adb('shell', 'appops', 'set', PACKAGE, 'GET_USAGE_STATS', 'allow')
            adb('shell', 'appops', 'set', PACKAGE, 'ACTIVATE_VPN', 'allow')
            adb('shell', 'pm', 'grant', PACKAGE, 'android.permission.POST_NOTIFICATIONS')
            accessibility(True)
        elif phase in ('schedule_chrome', 'focus_chrome', 'focus_chrome_again', 'fixed_chrome'):
            chrome()
        elif phase.startswith('capture_'):
            (OUT / (phase + '.png')).write_bytes(adb('exec-out', 'screencap', '-p').stdout)
            (OUT / (phase + '.txt')).write_bytes(adb('shell', 'dumpsys', 'window').stdout)
            if phase == 'capture_vpn':
                (OUT / 'vpn-connectivity.txt').write_bytes(adb('shell', 'dumpsys', 'connectivity').stdout)
                (OUT / 'vpn-routes.txt').write_bytes(adb('shell', 'ip', 'rule').stdout)
        elif phase in ('return_app', 'return_after_expiry', 'return_fixed'):
            open_app()
        elif phase == 'dialer':
            adb('shell', 'am', 'start', '-a', 'android.intent.action.DIAL', '-d', 'tel:')
            time.sleep(1)
            (OUT / 'dialer.png').write_bytes(adb('exec-out', 'screencap', '-p').stdout)
        elif phase == 'revoke_accessibility':
            accessibility(False)
        elif phase == 'restore_accessibility':
            accessibility(True)
        elif phase == 'done':
            result = adb('shell', 'run-as', PACKAGE, 'cat', 'code_cache/octopus-guard-result.json', check=False)
            if result.returncode == 0: (OUT / 'result.json').write_bytes(result.stdout)
            accessibility(False)
        else:
            raise RuntimeError('Unknown phase: ' + phase)
        # Phase values are fixed identifiers controlled by this test, never user text.
        adb('shell', 'run-as', PACKAGE, 'sh', '-c', f'"echo {phase} > code_cache/octopus-guard-ack"')
        print('DRIVER', phase, flush=True)
        previous = phase
        if phase == 'done': break
finally:
    server.shutdown()
