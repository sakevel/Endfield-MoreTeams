"""Validate icon atlas structure and embedded assets."""
from pathlib import Path
import base64, re, json, struct, zlib, hashlib

root=Path(__file__).resolve().parents[1]
lua=(root/'mod/marks.lua').read_text(encoding='utf8')
data=base64.b64decode(re.search(r"FromBase64String\('([^']+)'\)",lua)[1],validate=True)
assert data==(root/'design/marks/atlas.png').read_bytes()
assert data[:8]==b'\x89PNG\r\n\x1a\n'
pos=8; compressed=b''
while pos<len(data):
    size=struct.unpack_from('>I',data,pos)[0];kind=data[pos+4:pos+8];chunk=data[pos+8:pos+8+size]
    assert zlib.crc32(kind+chunk)&0xffffffff==struct.unpack_from('>I',data,pos+8+size)[0]
    if kind==b'IHDR':assert struct.unpack('>IIBBBBB',chunk)==(256,256,8,6,0,0,0)
    if kind==b'IDAT':compressed+=chunk
    pos+=size+12
raw=zlib.decompress(compressed);assert len(raw)==256*(1+256*4)
rows=[]
def paeth(a,b,c):
    p=a+b-c;d=[abs(p-a),abs(p-b),abs(p-c)]
    return (a,b,c)[d.index(min(d))]
for y in range(256):
    start=y*1025;kind=raw[start];line=bytearray(raw[start+1:start+1025]);assert kind in range(5)
    previous=rows[-1]if rows else bytes(1024)
    for x in range(1024):
        a=line[x-4]if x>=4 else 0;b=previous[x];c=previous[x-4]if x>=4 else 0
        prediction=(0,a,b,(a+b)//2,paeth(a,b,c))[kind]
        line[x]=(line[x]+prediction)&255
    rows.append(line)
assert all(row[x:x+3]==b'\xff\xff\xff'for row in rows for x in range(0,1024,4)if row[x+3])
index=json.loads((root/'design/marks/index.json').read_text())
assert index['source']=='image_gen' and set(index['ids'])=={str(i)for i in range(2,17)}
assert hashlib.sha256((root/'design/marks'/index['sourceFile']).read_bytes()).hexdigest()==index['sourceSha256']
references=json.loads((root/'design/marks/reference-index.json').read_text(encoding='utf8'))
assert index['referenceContextSha256']==references['contextSha256']
assert re.fullmatch('[0-9a-f]{64}',references['contextSha256'])
assert index['references']==references['icons']
assert [v['id']for v in index['references']]==list(range(2,17))
assert len({v['native']for v in index['references']})==15
assert all(re.fullmatch('[0-9a-f]{64}',v['fileSha256'])for v in index['references'])
silhouettes=set()
for i in range(15):
    # PNG origin is top-left; runtime Sprite UV rect flips atlas row origin.
    alpha=bytes(rows[i//4*64+y][(i%4*64+x)*4+3]for y in range(64)for x in range(64))
    points=[(x%64,x//64)for x,a in enumerate(alpha)if a]
    assert points and all(3<=x<=60 and 3<=y<=60 for x,y in points),'transparent gutter prevents filtering bleed'
    assert sum(a>=250 for a in alpha)>300,'bold near-opaque strokes, not thin/translucent textures'
    silhouettes.add(alpha)
assert len(silhouettes)==15
assert not any(rows[y][x*4+3]for y in range(192,256)for x in range(192,256))
print('PASS 15 referenced image-generated bold icons; source/reference provenance; tintable white RGB; atlas order/gutters; embedded PNG exact')
