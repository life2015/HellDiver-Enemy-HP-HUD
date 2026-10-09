"""Reproduce on pinned upstream, then verify the separate selector hotfix."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from build_menu_hotfix import patched_rows
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute("assert(os.setlocale('C'))")
run=lua.execute((ROOT/'tests/menu_rows.lua').read_text(encoding='utf-8'))
original=(ROOT/'research/vendor/ModOptionsMenu/src/rows.lua').read_text(encoding='utf-8')
try:run(original)
except Exception as e:
    assert 'inherited native disabled state' in str(e),e
    print('PASS: original upstream reproduces the stale disabled-selector failure')
else:raise AssertionError('Regression must fail on original upstream')
print(run(patched_rows(original)))
source=(ROOT/'build/menu-selector-hotfix/mod_options_menu.lua').read_text(encoding='utf-8')
lua.eval('function(s) assert(loadstring(s)) end')(source)
print('PASS: complete hotfix addon compiles under Lua 5.1')
