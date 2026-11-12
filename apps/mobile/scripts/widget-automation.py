"""Exercise only Octopus launcher widgets on the dedicated development AVD."""
import os, re, subprocess, time
from pathlib import Path
import xml.etree.ElementTree as ET
adb = str(Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk/platform-tools/adb.exe')
pkg = 'vn.octopus.mobile'
def run(*args):
    return subprocess.run([adb, '-s', 'emulator-5554', *args], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=20).stdout
if 'Brain10_API_33' not in run('emu', 'avd', 'name').splitlines(): raise SystemExit('Wrong AVD')
def nodes():
    run('shell', 'rm', '-f', '/sdcard/octopus-widget-test.xml')
    run('shell', 'uiautomator', 'dump', '/sdcard/octopus-widget-test.xml')
    try: return list(ET.fromstring(run('shell', 'cat', '/sdcard/octopus-widget-test.xml')).iter('node'))
    except ET.ParseError: return []
def tap(n):
    a,b,c,d = map(int,re.findall(r'\d+',n.get('bounds')))
    run('shell','input','tap',str((a+c)//2),str((b+d)//2))
def capture(name):
    path = Path('test-results') / f'{name}.png'
    path.write_bytes(subprocess.check_output([adb,'-s','emulator-5554','exec-out','screencap','-p']))
widget_path=[]
def home_default():
    run('shell','input','keyevent','3'); time.sleep(.3)
    run('shell','input','keyevent','3'); time.sleep(.8)

def reveal_widgets():
    home_default()
    for swipe in widget_path:
        run('shell','input','swipe',*swipe); time.sleep(.5)

def find_widget(predicate, name):
    global widget_path
    home_default()
    route=[]
    for attempt in range(4):
        matches = [n for n in nodes() if predicate(n)]
        if matches:
            widget_path=route.copy()
            capture(name); return matches[0]
        swipe=['900','1100','150','1100','350'] if attempt < 2 else ['150','1100','900','1100','350']
        run('shell','input','swipe',*swipe)
        route.append(swipe)
        time.sleep(.5)
    capture(name+'-missing')
    print('Visible Octopus widget text:', ascii([(n.get('resource-id'),n.get('text')) for n in nodes() if n.get('resource-id','').startswith(pkg)]), flush=True)
    raise RuntimeError(f'Widget not found: {name}')
last = ''
deadline = time.monotonic()+420
while time.monotonic()<deadline:
    phase = run('shell','run-as',pkg,'cat','code_cache/octopus-guard-phase').strip()
    if phase == last or not phase: time.sleep(.4); continue
    print('Starting '+phase,flush=True)
    if phase == 'permissions':
        run('shell','appops','set',pkg,'ACTIVATE_VPN','allow')
        run('shell','settings','put','secure','enabled_accessibility_services',pkg+'/.FocusAccessibilityService')
        run('shell','settings','put','secure','accessibility_enabled','1')
    elif phase.startswith('pin_'):
        time.sleep(1)
        for n in nodes():
            if n.get('resource-id','').endswith('/pin_item_confirmation') or n.get('text','').lower() in ['add to home screen','add automatically','thêm','thêm tự động']: tap(n); break
        run('shell','am','start','-n',pkg+'/.MainActivity')
    elif phase == 'widget_add':
        tap(find_widget(lambda n:n.get('content-desc')=='Thêm việc bằng văn bản', 'v051-widget-small'))
    elif phase == 'widget_focus':
        start_node=find_widget(lambda n:n.get('content-desc')=='Bắt đầu tập trung 30 phút', 'v051-widget-start')
        # Snapshot the checkbox target while idle. Live chronometers can prevent
        # uiautomator's waitForIdle and otherwise leave a stale XML dump.
        check_node=next((n for n in nodes() if n.get('content-desc')=='Hoàn thành Widget reading'),None)
        tap(start_node)
    elif phase == 'widget_complete':
        if check_node is not None:
            reveal_widgets(); capture('v051-widget-active')
            n=check_node
        else:
            n=find_widget(lambda n:n.get('content-desc')=='Hoàn thành Widget reading','v051-widget-active')
        tap(n)
    elif phase == 'widget_voice':
        before = run('logcat','-d','-s','OctopusSpeech:I','*:S').count('Recognition UI requested')
        tap(find_widget(lambda n:n.get('content-desc')=='Thêm việc bằng giọng nói','v051-widget-mic'))
    elif phase == 'speech_cancel':
        for _ in range(20):
            if run('logcat','-d','-s','OctopusSpeech:I','*:S').count('Recognition UI requested') > before: break
            time.sleep(.3)
        else: raise RuntimeError('Mic did not launch the Android speech recognizer')
        time.sleep(1); capture('v051-speech-native')
        # User-cancel path. No synthesized speech or automatic grant of microphone.
        run('shell','input','keyevent','4')
        time.sleep(1)
        run('shell','am','start','-n',pkg+'/.MainActivity')
    elif phase == 'widget_schedule':
        # Capture live countdown states without uiautomator: recurring clock
        # accessibility events prevent its idle barrier. Review these real images.
        reveal_widgets(); capture('v051-widget-schedule')
    elif phase == 'done':
        run('shell','settings','put','secure','enabled_accessibility_services','null')
        run('shell','settings','put','secure','accessibility_enabled','0')
    else: time.sleep(.4); continue
    time.sleep(.6)
    run('shell','run-as',pkg,'sh','-c',f'"echo {phase} > code_cache/octopus-guard-ack"')
    print(phase,flush=True); last=phase
    if phase=='done': break
