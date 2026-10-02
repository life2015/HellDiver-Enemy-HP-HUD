"""Exercise upstream event attribution with synthetic memory, never the game.

Needs lupa.lua51 and the pinned HD2Runtime checkout in vendor/. This exercises
the string-read path and drives events.tick directly, not Windows FFI or startup.
"""
from pathlib import Path
import sys

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parent / 'vendor' / 'HD2Runtime'
sys.path.insert(0, str(ROOT / 'tests'))
import support
import test_event_sources

preloads = []
for folder in ['api', 'core', 'runtime', 'schemas', 'domains', 'examples',
               'validation', 'primary_mapper']:
    for path in sorted((ROOT / folder).glob('*.lua')):
        name = 'hd2runtime/' + path.relative_to(ROOT).with_suffix('').as_posix()
        # Preserve the original Lua bytes, including non-UTF-8 string data.
        preloads.append(('package.preload["' + name + '"]=function(...)\n').encode()
                        + path.read_bytes() + b'\nend\n')

# The game's LuaJIT accepts xpcall arguments; stock Lua 5.1 ignores them.
compat = b'''
local original_xpcall=xpcall
xpcall=function(fn,handler,...)
    local args,n={...},select('#',...)
    return original_xpcall(function()return fn(unpack(args,1,n))end,handler)
end
'''
body = r'''
local function tick()events.tick(0.125)end
local mod=api.mod('mods/research/hud_attribution')
local hits,deaths={},{}
mod:on('entity_damaged',function(e)hits[#hits+1]=e end)
mod:on('entity_died',function(e)deaths[#deaths+1]=e end)
W.state(4);W.players({{peer=LOCAL},{peer=OTHER}},LOCAL);tick()
W.add{entity=900,type=MARAUDER,unit=9900,health=100};tick()
W.set(900,{health=90,creditor=LOCAL});tick()
assert(#hits==1 and hits[1].entity_id==900 and hits[1].local_attacker,'local victim/credit')

-- Both players deal damage between polls; only the last creditor survives.
W.set(900,{health=80,creditor=LOCAL})
W.set(900,{health=75,creditor=OTHER});tick()
assert(#hits==2 and hits[2].damage==15 and not hits[2].local_attacker,'last-creditor aggregation')

-- An unchanged creditor is still attributed to the earlier player.
W.set(900,{health=65,creditor=LOCAL});tick()
W.set(900,{health=60});tick()
assert(hits[4].local_attacker and hits[4].damage==5,'retained-creditor attribution')

-- A lethal transition is a death event, not entity_damaged.
local before=#hits
W.set(900,{health=0,life=2,creditor=LOCAL});tick()
assert(#hits==before and #deaths==1 and deaths[1].local_killer,'lethal death event')

-- A one-shot kill removed between polls leaves no fresh creditor to read.
W.add{entity=901,type=MARAUDER,unit=9901,health=100};tick()
W.set(901,{health=0,life=2,creditor=LOCAL})
W.replace_by_corpse(901,1901);tick()
assert(#deaths==2 and deaths[2].observed=='corpse' and not deaths[2].local_killer,
       'corpse cannot recover unseen killing creditor')
return 'PASS: 5 attribution cases (synthetic memory, Lua 5.1 compatibility adapter; NOT in-game)'
'''
program = (compat + b''.join(preloads) + support.fixture().encode() + b'\n'
           + test_event_sources.PRELUDE.encode() + body.encode())
print(LuaRuntime(encoding=None, unpack_returned_tuples=True).execute(program).decode())
