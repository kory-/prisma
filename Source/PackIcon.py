"""Package original vector-rendered PNG sizes into a standard macOS ICNS container."""
import struct,sys
from pathlib import Path
src,dest=map(Path,sys.argv[1:])
chunks=[]
for tag,size in [('icp4',16),('icp5',32),('icp6',64),('ic07',128),('ic08',256),('ic09',512),('ic10',1024)]:
 data=(src/f'prism-{size}.png').read_bytes();chunks.append(tag.encode()+struct.pack('>I',8+len(data))+data)
body=b''.join(chunks);dest.write_bytes(b'icns'+struct.pack('>I',8+len(body))+body)
