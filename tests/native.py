import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from lupa.lua54 import LuaRuntime
root=Path(__file__).resolve().parents[1]
def runtime():
 lua=LuaRuntime()
 lua.execute((root/'tests/native_mock.lua').read_text(encoding='utf8'))
 for name in ('ctrl','phase'):
  p=Path(sys.argv[2])/(name+'.lua');s=p.read_text(encoding='utf8')
  lua.eval('function(s) local f,e=load(s);assert(f,e) end')(s)
  lua.execute(s)
 return lua
lua=runtime()
lua.execute((root/'tests/native_scenarios.lua').read_text(encoding='utf8'))
lua=runtime()
source=Path(sys.argv[3])
# Execute current client list/selection methods and utility functions, not a
# hand-written replacement that hides the native five-team bounds.
utility=(source/'common/utils/charinfoutils.lua').read_text(encoding='utf8')
for name in ('getCharInfoList','checkCharInTeam','IsServerDefaultChar'):
 start=utility.index('function CharInfoUtils.'+name+'(')
 end=utility.find('\nfunction ',start+1)
 lua.execute(utility[start:end if end>=0 else len(utility)])
lua.execute((source/'ui/widgets/charformationlist.lua').read_text(encoding='utf8'))
lua.execute((root/'tests/editor_scenarios.lua').read_text(encoding='utf8'))
