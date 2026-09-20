import subprocess,struct,json,uuid,select,sys
from pathlib import Path
root=Path(__file__).resolve().parents[1];session=str(uuid.uuid4())
identifier=(root/'Source/ChromeExtensionID.h').read_text().split('@"')[1].split('"')[0]
probe=subprocess.Popen([sys.argv[1],session],stdout=subprocess.PIPE,bufsize=0)
assert probe.stdout.readline().strip()==b'READY'
host=subprocess.Popen([str(root/'Prisma.app/Contents/MacOS/PrismaChromeHost'),f'chrome-extension://{identifier}/'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,bufsize=0)
def exact(n):
 data=b''
 while len(data)<n:
  assert select.select([host.stdout],[],[],5)[0], 'Native response timed out'
  chunk=host.stdout.read(n-len(data));assert chunk;data+=chunk
 return data
try:
 message={'type':'state','session':session,'tabs':[{'id':701,'name':'Prisma 接続テスト A','volume':.6,'muted':False,'playing':False},{'id':702,'name':'Prisma 接続テスト B','volume':.9,'muted':False,'playing':False}]}
 data=json.dumps(message).encode();host.stdin.write(struct.pack('<I',len(data))+data);host.stdin.flush()
 for _ in range(20):
  message=json.loads(exact(struct.unpack('<I',exact(4))[0]))
  if message['type']=='command':
   assert message['session']==session and message['id']==701 and message['op']=='set' and message['value']==.35
   break
 else: raise AssertionError('No command received')
 assert probe.wait(timeout=5)==0
 host.stdin.close();assert host.wait(timeout=5)==0
finally:
 for p in [host,probe]:
  if p.poll() is None:p.kill();p.wait()
print('PASS: extension-format state → native host → macOS notification → targeted command → native host response')
