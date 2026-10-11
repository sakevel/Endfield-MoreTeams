"""Pack the approved image_gen sheet into tintable sprites; no hand-drawn replacement.

Preserves generated alpha silhouettes. RGB is white for Unity runtime tinting.
Source sheet and prompts remain in design/marks, outside the runtime package.
"""
from pathlib import Path
from PIL import Image
import base64, hashlib, io, json, re

ROOT=Path(__file__).resolve().parents[1]
NAMES=['guard','defender','support','caster','vanguard','striker','protocol',
       'energy','monument','danger','fragment','relic','echo','training','exploration']

def render():
    folder=ROOT/'design/marks'
    source=folder/'generated-sheet.png'
    references=json.loads((folder/'reference-index.json').read_text(encoding='utf8'))
    assert [icon['id'] for icon in references['icons']]==list(range(2,17))
    sheet=Image.open(source).convert('RGBA')
    atlas=Image.new('RGBA',(256,256),(255,255,255,0))
    for i,name in enumerate(NAMES):
        x,y=i%4,i//4
        box=(round(x*sheet.width/4),round(y*sheet.height/4),
             round((x+1)*sheet.width/4),round((y+1)*sheet.height/4))
        alpha=sheet.crop(box).getchannel('A')
        bounds=alpha.getbbox()
        assert bounds, f'Empty generated icon: {name}'
        alpha=alpha.crop(bounds)
        ratio=52/max(alpha.size)
        alpha=alpha.resize((max(1,round(alpha.width*ratio)),max(1,round(alpha.height*ratio))),Image.Resampling.LANCZOS)
        tile=Image.new('RGBA',(64,64),(255,255,255,0))
        a=Image.new('L',(64,64));a.paste(alpha,((64-alpha.width)//2,(64-alpha.height)//2))
        tile.putalpha(a);atlas.paste(tile,(x*64,y*64))
    data=io.BytesIO();atlas.save(data,format='PNG',optimize=True)
    png=data.getvalue();(folder/'atlas.png').write_bytes(png)
    lua=ROOT/'mod/marks.lua'
    content=lua.read_text(encoding='utf8')
    content=re.sub(r"FromBase64String\('[^']+'\)","FromBase64String('"+base64.b64encode(png).decode()+"')",content)
    content=re.sub(r'^--[^\n]*', '-- Image-generated icon atlas, packed by tools/pack-generated-marks.py. Do not hand edit.',content)
    lua.write_text(content,encoding='utf8')
    (folder/'index.json').write_text(json.dumps({'source':'image_gen','sourceFile':source.name,
        'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'viewBox':64,
        'referenceContextSha256':references['contextSha256'],
        'references':references['icons'],
        'ids':{i+2:name for i,name in enumerate(NAMES)}},indent=2),encoding='utf8')
    preview=Image.new('RGBA',(640,240),(49,49,49,255))
    for i in range(15):
        tile=atlas.crop((i%4*64,i//4*64,(i%4+1)*64,(i//4+1)*64))
        for row,size in enumerate((24,48)):
            preview.alpha_composite(tile.resize((size,size),Image.Resampling.LANCZOS),
                ((i%8)*80+16,(i//8)*120+row*54+12))
    preview.convert('RGB').save(ROOT/'artifacts/generated-marks-preview.png')
    print(f'Packed {len(NAMES)} image-generated alpha silhouettes, PNG {len(png)} bytes')

if __name__=='__main__':render()
