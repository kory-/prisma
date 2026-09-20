"""Create an importable Stream Deck + profile with four automatic Prisma dials."""
import uuid,json,zipfile
from pathlib import Path
out=Path(__file__).resolve().parents[1]
profile=str(uuid.UUID('230A9A45-13E5-4D86-BB9F-AB4A078B6152')).upper()+'.sdProfile'
page=str(uuid.UUID('F9607212-4DF0-4A65-8D91-59EDFE09A3A1'))
root={'Device':{'Model':'20GBD9901','UUID':''},'Name':'Prisma Auto','Pages':{'Current':page,'Default':page,'Pages':[page]},'Version':'3.0'}
actions={}
for i in range(4):
 actions[f'{i},0']={'ActionID':str(uuid.uuid4()),'LinkedTitle':True,'Name':'Playing Apps','Plugin':{'Name':'Prisma','UUID':'io.github.kory-.prisma','Version':'0.4.1.0'},'Settings':{'mode':'auto','slot':i,'step':5},'State':0,'States':[{}],'UUID':'io.github.kory-.prisma.auto'}
doc={'Controllers':[{'Actions':actions,'Type':'Encoder'},{'Actions':{},'Type':'Keypad'}],'Name':'Prisma Auto','Icon':''}
with zipfile.ZipFile(out/'Prisma Auto.streamDeckProfile','w',zipfile.ZIP_DEFLATED) as z:
 z.writestr(profile+'/manifest.json',json.dumps(root,ensure_ascii=False));z.writestr(profile+'/Profiles/'+page.upper()+'/manifest.json',json.dumps(doc,ensure_ascii=False))
