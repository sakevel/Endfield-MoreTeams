import sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from lupa.lua54 import LuaRuntime
r=Path(__file__).resolve().parents[1];lua=LuaRuntime()
lua.globals().Factory=lua.execute((r/'mod/controller.lua').read_text(encoding='utf8'))
lua.execute((r/'tests/behavior.lua').read_text(encoding='utf8'))
