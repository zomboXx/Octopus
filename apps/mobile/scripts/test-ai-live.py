"""Billable UI -> local API -> GPT -> preview -> confirm check on Octopus AVD.

Uses synthetic state temporarily and restores the pre-test app-data tar in finally.
No integration APK/uninstall: pinned widgets and normal app installation survive.
"""
import argparse,json,re,subprocess,time,xml.etree.ElementTree as ET
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--run-live',action='store_true');args=p.parse_args()
if not args.run_live:raise SystemExit('Pass --run-live to authorize one billable model request.')
root=Path(__file__).resolve().parents[1]
adb=str(Path.home()/'AppData/Local/Android/Sdk/platform-tools/adb.exe')
pkg='vn.octopus.mobile'
def run(*parts,data=None):
    return subprocess.run([adb,'-s','emulator-5554',*parts],input=data,capture_output=True,check=True,timeout=30).stdout
assert 'Brain10_API_33' in run('emu','avd','name').decode()
run('shell','am','force-stop',pkg)
backup=root/f'.android-dev/pre-ai-ui-{time.time_ns()}.tar'
backup.parent.mkdir(exist_ok=True)
backup.write_bytes(run('exec-out','run-as',pkg,'tar','-cf','-','shared_prefs','files'))
out=root/'test-results';out.mkdir(exist_ok=True)
def shot(name): (out/(name+'.png')).write_bytes(run('exec-out','screencap','-p'))
def nodes():
    run('shell','uiautomator','dump','/sdcard/octopus-ai-test.xml')
    return list(ET.fromstring(run('shell','cat','/sdcard/octopus-ai-test.xml')).iter('node'))
def tap(node):
    a,b,c,d=map(int,re.findall(r'\d+',node.attrib['bounds']))
    run('shell','input','tap',str((a+c)//2),str((b+d)//2));time.sleep(.4)
def find(label,scroll=True):
    for _ in range(12 if scroll else 1):
        for n in nodes():
            if label in (n.get('text','')+'\n'+n.get('content-desc','')) and n.get('enabled')!='false':return n
        if scroll:run('shell','input','swipe','540','1700','540','650','300');time.sleep(.5)
    return None
def click(label):
    n=find(label)
    if n is None:raise RuntimeError('UI control missing: '+label.encode('ascii','backslashreplace').decode())
    tap(n)
def fill(index,text):
    # Flutter exposes editable semantics but not floating labels to API33's dump.
    fields=[n for n in nodes() if n.get('class')=='android.widget.EditText']
    if len(fields)<=index:raise RuntimeError('Expected two visible planning inputs.')
    tap(fields[index]);run('shell','input','text',text.replace(' ','%s'));run('shell','input','keyevent','4');time.sleep(.5)

state={'version':1,'profile':{'name':'Nguyễn An','birthday':'2005-01-01','authMode':'guest'},'onboardingComplete':True,
       'tasks':[],'activities':[],'plan':[],'circles':[],'checkins':[],
       'commitments':[{'id':'ai-live-fixture','title':'Lịch học mẫu','weekdays':[1,2,3,4,5],'startMinute':420,'endMinute':720}],
       'studyPreferences':{'startMinute':1080,'endMinute':1320,'sessionMinutes':30,'dailyMinutes':30},
       'protection':{'enabled':False,'blockInternet':False},'focusMinutes':0}
mapping=ET.Element('map');ET.SubElement(mapping,'string',{'name':'state'}).text=json.dumps(state,ensure_ascii=False)
try:
    run('shell','am','force-stop',pkg)
    run('exec-in','run-as',pkg,'tee','shared_prefs/octopus_prototype.xml',data=ET.tostring(mapping,encoding='utf-8',xml_declaration=True))
    run('shell','am','start','-n',pkg+'/.MainActivity');time.sleep(4)
    click('Lịch trình');click('Lên kế hoạch cùng AI')
    fill(0,'DBMS exam in 3 days. Plan only one 30 minute JOIN review session.')
    fill(1,'DBMS INNER JOIN and LEFT JOIN. One worked example and one self test.')
    click('Tạo kế hoạch để xem trước')
    deadline=time.monotonic()+110
    while time.monotonic()<deadline:
        current=nodes();text='\n'.join(n.get('text','')+' '+n.get('content-desc','') for n in current)
        if 'Đang sắp xếp kế hoạch' not in text:break
        time.sleep(2)
    current=json.loads(ET.fromstring(run('exec-out','run-as',pkg,'cat','shared_prefs/octopus_prototype.xml')).find("string[@name='state']").text)
    assert not current['plan'],'Plan must not save before confirmation.'
    confirm=find('Xác nhận thêm vào lịch')
    if confirm is None:shot('ai060-native-error');raise RuntimeError('No AI draft confirmation. Check the native error screenshot.')
    shot('ai060-native-preview');tap(confirm);time.sleep(2)
    current=json.loads(ET.fromstring(run('exec-out','run-as',pkg,'cat','shared_prefs/octopus_prototype.xml')).find("string[@name='state']").text)
    assert current['plan'] and all(v.get('objectives') and v.get('steps') for v in current['plan'])
    shot('ai060-native-confirmed')
    print(json.dumps({'ok':True,'platform':'Android AVD API33','sessions':len(current['plan']),'confirmed':True,'model':'gpt-5.4-mini'}),flush=True)
finally:
    run('shell','am','force-stop',pkg)
    run('exec-in','run-as',pkg,'tar','-xf','-',data=backup.read_bytes())
    run('shell','am','start','-n',pkg+'/.MainActivity')
    print('Original app data restored; normal app reopened.',flush=True)
