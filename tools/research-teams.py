"""Bounded read-only native team request/response audit. No runtime offsets used by mod."""
from pathlib import Path
import struct,re,bisect,json,hashlib
import pefile,capstone
game=Path(r'D:\Game\Hypergryph Launcher\games\Endfield Game')
out=Path(__file__).resolve().parents[1]/'artifacts/research';out.mkdir(parents=True,exist_ok=True)
b=(game/'Endfield_Data/il2cpp_data/Metadata/global-metadata.dat').read_bytes();h=struct.unpack_from('<64I',b)
assert h[:2]==(0xfab11baf,29)
def s(i):return b[h[6]+i:b.index(b'\0',h[6]+i)].decode('utf8')
types=[struct.unpack_from('<17i8H2I',b,i) for i in range(h[40],h[40]+h[41],92)]
images=[struct.unpack_from('<10I',b,i) for i in range(h[42],h[42]+h[43],40)]
pe=pefile.PE(str(game/'GameAssembly.dll'),fast_load=True);base=pe.OPTIONAL_HEADER.ImageBase;raw=pe.__data__
def offset(va):return pe.get_offset_from_rva(va-base)
def q(va):return struct.unpack_from('<Q',raw,offset(va))[0]
tables={};names={};targets=[]
wanted={'CharBagSystem':{'SetTeamWithSkill','SetTeam','SendSetActiveTeam','_Handle_CharBagSetTeam','_Handle_SetCurTeamIndex','_Handle_SetTeamName'}, 'Player':{'get_playerInfo'}}
for image in ('Gameplay.Beyond.dll',):
    candidates=[]
    for m in re.finditer(re.escape(image.encode()+b'\0'),raw):
        va=base+pe.get_rva_from_offset(m.start())
        for ref in re.finditer(re.escape(struct.pack('<Q',va)),raw):
            n=struct.unpack_from('<I',raw,ref.start()+8)[0];ptr=struct.unpack_from('<Q',raw,ref.start()+16)[0]
            if 100<n<300000 and base<=ptr<base+pe.OPTIONAL_HEADER.SizeOfImage:candidates.append((n,ptr))
    assert len(candidates)==1,(image,candidates)
    n,ptr=candidates[0];tables[image]=(ptr,sorted(set(q(ptr+i*8) for i in range(n))))
    indices=next(i for i in images if s(i[0])==image)
    for t in types[indices[2]:indices[2]+indices[3]]:
        cls=s(t[0]);full='.'.join(filter(None,(s(t[1]),cls)))
        for ix in range(t[9],t[9]+t[17]):
            method=struct.unpack_from('<6i4H',b,h[12]+ix*32);token=method[5]&0xffffff
            if not 1<=token<=n:continue
            va=q(ptr+(token-1)*8);name=s(method[0]);names.setdefault(va,[]).append(full+'.'+name)
            selection=wanted.get(full,wanted.get(cls,set()))
            if name in selection:targets.append((image,full,name,va))
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
with (out/'teams-disassembly.txt').open('w',encoding='utf8') as f:
    for image,cls,name,va in targets:
        _,addresses=tables[image];i=bisect.bisect_right(addresses,va)
        size=min(6000,addresses[i]-va if i<len(addresses) else 0)
        f.write(f'\n{cls}.{name} VA={va:x} bytes={size}\n')
        for ins in md.disasm(raw[offset(va):offset(va)+size],va):
            note=''
            if ins.mnemonic in ('call','jmp') and ins.op_str.startswith('0x'):
                note=' ; '+','.join(names.get(int(ins.op_str,16),[]))
            f.write(f'{ins.address:x} {ins.mnemonic} {ins.op_str}{note}\n')
(out/'binary-provenance.json').write_text(json.dumps({'gameAssemblySHA256':hashlib.sha256(raw).hexdigest(),'metadataSHA256':hashlib.sha256(b).hexdigest(),'targetCount':len(targets),'readOnly':True},indent=2))
print('Audited',len(targets),'native team methods (bounded read-only disassembly)')
