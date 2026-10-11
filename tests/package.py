import sys,json,configparser
from pathlib import Path
r=Path(sys.argv[1]);m=json.loads((r/'zml-package.json').read_text())
assert m['id']=='more-teams' and len(m['files'])==len(set(m['files']))==7
c=configparser.ConfigParser();c.read(r/'mod.ini',encoding='utf8');assert c['mod']['id']=='more-teams' and c['mod']['library']=='MoreTeams.dll'
src=Path(__file__).resolve().parents[1]/'mod'
assert set(p.name for p in r.iterdir()if p.is_file())==set(m['files'])|{'zml-package.json'}
for name in m['files']:
 assert Path(name).name==name and (r/name).is_file()
 if name!='MoreTeams.dll':assert (r/name).read_bytes()==(src/name).read_bytes()
print('PASS exact package whitelist and source assets; no extracted game files/private data')

# Generated mod icon provenance and exact RGBA delivery, independently of Pillow.
import hashlib,struct
root=src.parent
icon=(r/'icon.png').read_bytes();meta=json.loads((root/'design/icon/index.json').read_text(encoding='utf8'))
assert icon[:8]==b'\x89PNG\r\n\x1a\n'
assert struct.unpack('>IIBBBBB',icon[16:29])==(256,256,8,6,0,0,0)
assert meta['source']=='image_gen' and meta['iconSha256']==hashlib.sha256(icon).hexdigest()
assert meta['sourceSha256']==hashlib.sha256((root/'design/icon'/meta['sourceFile']).read_bytes()).hexdigest()
assert meta['alphaExtrema']==[0,255] and meta['iconSize']==[256,256]
print('PASS generated RGBA mod icon and source provenance')
