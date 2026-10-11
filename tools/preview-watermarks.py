"""Offline layout preview; uses runtime pill coverage, not a game/GPU screenshot."""
from pathlib import Path
import sys
sys.path.insert(0, sys.argv[1])
from lupa.lua54 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.execute('CS={UnityEngine={}}; ZMLMoreTeams={}')
lua.execute((root/'mod/ui.lua').read_text(encoding='utf8'))
coverage = lua.globals().ZMLMoreTeams.pillCoverage
fill = lua.globals().ZMLMoreTeams.fillAlpha
atlas = Image.open(root/'design/marks/atlas.png').convert('RGBA')
scale, w, h = 4, 132, 38
size = h*1.8
preview = Image.new('RGB', (880, 390), '#202020')
label = ImageDraw.Draw(preview)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 18)
number_font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 64)
label.text((18, 8), '0.1.14 - unselected / selected (offline preview)', font=font, fill='white')
colors = [(255,98,61), (255,192,0), (33,198,208), (158,220,35), (136,136,136)]
for i in range(15):
    tile = atlas.crop((i%4*64, i//4*64, i%4*64+64, i//4*64+64))
    for selected in (False, True):
        button = Image.new('RGBA', (w*scale,h*scale), (0,0,0,0))
        mask = Image.new('L', button.size)
        mask.putdata([round(255*coverage((x+.5)/scale,(y+.5)/scale,w,h,h*.5))
                      for y in range(h*scale) for x in range(w*scale)])
        base = Image.new('RGBA', button.size, '#eeeeee' if selected else '#313131')
        base.putalpha(mask);button.alpha_composite(base)
        color = Image.new('RGBA', button.size, colors[i%5])
        color.putalpha(Image.frombytes('L',button.size,bytes(
            round(255*fill((x+.5)/scale,(y+.5)/scale,w,h,h*.5))
            for y in range(h*scale) for x in range(w*scale))))
        button.alpha_composite(color)
        mark = Image.new('RGBA', button.size)
        large = tile.resize((round(size*scale),)*2, Image.Resampling.BILINEAR)
        shade, opacity = (49,.32) if selected else (round(.92*255),.4)
        large = Image.merge('RGBA', (Image.new('L',large.size,shade),)*3
                            +(large.getchannel('A').point(lambda a:round(a*opacity)),))
        mark.paste(large, (round((w*.2-size*.5)*scale),round((h-size)*.5*scale)))
        # UGUI stencil clips alpha > .001; a static preview cannot prove GPU rendering.
        mark.putalpha(Image.frombytes('L',button.size,bytes(
            a if m else 0 for a,m in zip(mark.getchannel('A').tobytes(),mask.tobytes()))))
        button.alpha_composite(mark)
        draw = ImageDraw.Draw(button)
        draw.text((w*.72*scale,h*.5*scale), f'{i+2:02}',font=number_font,
                  fill='#313131' if selected else '#bbbbbb',anchor='mm')
        button = button.resize((w,h),Image.Resampling.LANCZOS)
        x, y = 18+(i%5)*174, 40+(i//5)*112+int(selected)*46
        preview.paste(button,(x,y),button)
preview.save(root/'artifacts/watermarks-0114-preview.png')
print('Saved runtime-geometry watermark preview (not live UI evidence)')
