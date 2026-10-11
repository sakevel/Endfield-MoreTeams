import sys,subprocess
from pathlib import Path
exe=Path(sys.argv[1]);pkg=Path(sys.argv[2]);p=subprocess.Popen([str(exe),'--serve',str(pkg/'mod.ini')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def route(name):
 p.stdin.write((name+'\n').encode());p.stdin.flush();line=p.stdout.readline();assert line;return p.stdout.read(int(line)).decode('utf8')
try:
 registry=route('ZML/Api');assert 'more-teams' in registry and 'MoreTeams.dll' not in registry
 assert '更多编队' in registry and 'none' in registry
 assert 'ok=true' in route('ZML/Get/more-teams')
 icon=route('ZML/Icon/more-teams');assert 'ok=true' in icon and 'iVBOR' in icon
 assert 'ok=true' in route('ZML/Report/more-teams/test_ready')
 print('PASS actual Loader manifest/catalog/icon/report service, no required config menu/dependency')
finally:
 p.stdin.close()
 try:p.wait(timeout=10)
 except subprocess.TimeoutExpired:p.kill();p.wait()
 if p.returncode:raise RuntimeError(p.stderr.read().decode(errors='replace'))
