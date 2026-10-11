"""Local-only client Lua envelope decoder with byte-exact roundtrip validation."""
import base64, struct, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
K=struct.unpack('<4I',b'd41d8cd98f00b204'); MASK=0xffffffff; DELTA=0x9e3779b9
def crypt(data, forward):
    n=(len(data)+3)//4+1 if forward else len(data)//4
    assert forward or len(data)%4==0 and n>=2
    v=list(struct.unpack('<%dI'%n,data.ljust(n*4,b'\0')))
    if forward:v[-1]=len(data)
    rounds=6+52//n; total=0 if forward else DELTA*rounds&MASK
    carry=v[-1] if forward else v[0]
    def mix(z,y,p):return (((z>>5 ^ y<<2)+(y>>3 ^ z<<4)) ^ ((total^y)+(K[(p&3)^((total>>2)&3)]^z)))&MASK
    for _ in range(rounds):
        if forward:
            total=(total+DELTA)&MASK
            for p in range(n):v[p]=(v[p]+mix(carry,v[(p+1)%n],p))&MASK;carry=v[p]
        else:
            for p in range(n-1,-1,-1):v[p]=(v[p]-mix(v[(p-1)%n],carry,p))&MASK;carry=v[p]
            total=(total-DELTA)&MASK
    raw=struct.pack('<%dI'%n,*v)
    if forward:return raw
    assert n*4-7<=v[-1]<=(n-1)*4
    return raw[:v[-1]]
if __name__=='__main__':
    result=[]
    for src in (ROOT/'artifacts/research/current/raw/data/luascripts').rglob('*.lua'):
        raw=src.read_bytes(); plain=crypt(base64.b64decode(raw,validate=True),False)
        assert base64.b64encode(crypt(plain,True))==raw
        assert b'\0' not in plain;plain.decode('utf8')
        dst=ROOT/'artifacts/research/decrypted'/src.relative_to(ROOT/'artifacts/research/current/raw/data/luascripts')
        dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(plain)
        result.append({'module':str(src.relative_to(ROOT/'artifacts/research/current/raw/data/luascripts')),'sha256':hashlib.sha256(plain).hexdigest(),'roundtrip':True})
    (ROOT/'artifacts/research/lua-roundtrip.json').write_text(json.dumps(result,indent=2))
    print('Byte-exact Lua roundtrips:',len(result))
