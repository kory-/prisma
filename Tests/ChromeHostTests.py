import json, struct, subprocess, select, sys, time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
identifier=(root/'Source/ChromeExtensionID.h').read_text().split('@"')[1].split('"')[0]
host=root/'Prisma.app/Contents/MacOS/PrismaChromeHost'
assert subprocess.run([str(host),'chrome-extension://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/'],stdout=subprocess.PIPE).returncode==1
process=subprocess.Popen([str(host),f'chrome-extension://{identifier}/'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,bufsize=0)
def read_exact(n):
    data=b''; deadline=time.monotonic()+5
    while len(data)<n:
        assert time.monotonic()<deadline, 'Native host response timed out'
        if select.select([process.stdout],[],[],.2)[0]:
            chunk=process.stdout.read(n-len(data)); assert chunk, 'Host exited early'; data+=chunk
    return data
try:
    body=json.dumps({'type':'hello'}).encode(); packet=struct.pack('<I',len(body))+body
    for chunk in [packet[:2],packet[2:7],packet[7:]]:
        process.stdin.write(chunk);process.stdin.flush();time.sleep(.02)
    for _ in range(20):
        size=struct.unpack('<I',read_exact(4))[0]; assert size<1024*1024
        message=json.loads(read_exact(size))
        if message['type']=='ready': break
    else: raise AssertionError('Missing native handshake')
    process.stdin.close(); assert process.wait(timeout=5)==0
finally:
    if process.poll() is None: process.kill();process.wait()
process=subprocess.Popen([str(host),f'chrome-extension://{identifier}/'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,bufsize=0)
process.stdin.write(struct.pack('<I',256*1024+1));process.stdin.flush();assert process.wait(timeout=5)==0
print('PASS: extension origin restriction, fragmented native frames, handshake, clean EOF, oversized frame rejection')
