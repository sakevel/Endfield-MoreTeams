import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from lupa.lua54 import LuaRuntime
r=Path(__file__).resolve().parents[1];lua=LuaRuntime()
lua.execute((r/'tests/native_mock.lua').read_text(encoding='utf8'))
lua.execute(Path(sys.argv[2]).read_text(encoding='utf8'))
lua.execute('PanelId.NaviTargetActionMenu=2')
lua.execute(Path(sys.argv[3]).read_text(encoding='utf8'))
lua.execute((r/'tests/ui_scenarios.lua').read_text(encoding='utf8'))
