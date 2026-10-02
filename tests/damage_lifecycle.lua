local E=assert(loadstring(ENGINE_SOURCE))()
local sr,state=E.sr,{frames=0}
local ui=MAKE_PRESENTATION(sr,E.font_ids)
local now,world,menu,position=0,"main",false,true
local target,last_hp,shown,mark,marked
local OFFSET,UI_SCALE,BAR_WIDTH,SHOW_NAME=-40,1,172,false
local AUTO_DAMAGE,DAMAGE_DURATION=true,3
local peer,rows,reads="FEDCBA9876543210",{},0
local os={clock=function() return now end}
sr.Application.main_world=function() return world end
sr.Window={show_cursor=function() return menu end}
local function log() end
local function hide() ui:hide();shown=false end
local function local_creator() return 1 end
local function newest_mark() return marked and mark or nil end
local function entity_marked() return marked end
local function health_units() return rows end
local function unit_of_entity(hu,entity) return hu[entity] and entity,hu[entity] end
local function max_hp() return 100 end
local function name_of() return "Enemy" end
local function marker_of() return 1 end
local function spot_of() return {r0=1} end
local function ping_colour() return {255,235,60,50} end
local NAMES={enemy="Enemy"}
local function screen_of() if position then return 900,500 end end
local function make_damage_reader()
    return function()
        reads=reads+1
        local copy={};for unit,row in pairs(rows) do copy[unit]={};for k,v in pairs(row) do copy[unit][k]=v end end
        return {manager=1,records=copy,count=2},peer
    end
end
local make_damage_detector=MAKE_DAMAGE_DETECTOR
--[[TARGET_CONTROLLER]]
--[[DAMAGE_CONTROLLER]]
--[[UPDATE_CONTROLLER]]
local function row(unit,hp,creditor)
    rows[unit]={unit=unit,entity=unit,type="enemy",descriptor=1000+unit,network=unit,
                hp=hp,life=0,creditor=creditor or peer}
end
local function step(time) now=time;E.next_frame();tick() end
local function label() return ui.gui.parts[ui.texts.current5] end

row(10,100);row(11,100)
step(0);assert(not target and not shown and reads==1)
row(10,75);step(0.05);assert(not target and reads==1, "poll must be throttled")
step(0.15);assert(target.source=="damage" and target.unit==10 and shown and label().text=="75")
local first=target
row(10,50);step(0.3);assert(target==first and target.until_t==3.3, "hit must renew without restarting animation")
step(0.5);assert(target.until_t==3.3, "unchanged health does not renew")
row(11,80);step(0.65);assert(target.unit==11 and target~=first, "newly damaged enemy becomes active")
row(11,0);rows[11].life=2;step(0.8)
assert(target.dead_t==0.8 and shown and label().text=="ELIMINATED")
position=false;step(2.1);assert(shown and label().tint.a>0 and label().tint.a<150)
step(2.31);assert(not target and not shown)

position=true;row(10,40);step(2.5);assert(target.unit==10 and shown)
step(5.51);assert(not target and not shown, "automatic target expires after 3s without needing a ping")
-- The baseline persists after timeout: only a new observed hit can reactivate.
step(5.7);assert(not target)
row(10,30);step(5.9);assert(target.unit==10 and shown)

-- Manual mark overrides automatic selection, and remains pinned during hits elsewhere.
row(11,100);mark={entity=11,slot=1,age=0,kind=1};marked=true
step(6.1);assert(target.unit==11 and target.source~="damage")
row(10,20);step(6.3);assert(target.unit==11, "manual mark has priority")
marked=false;state.frames=5;step(6.5);assert(not shown)
row(10,10);step(6.65);assert(target.unit==10 and target.source=="damage")

menu=true;step(6.8);assert(not shown)
row(10,5);local before=reads;step(6.95);assert(reads==before, "menus suspend observer")
menu=false;step(7.1);assert(target.until_t==9.65, "reopening must baseline, not attribute paused damage")
world="new-main";step(7.3);assert(not target and not shown)
row(10,3);step(7.5);assert(target and target.world==world)

AUTO_DAMAGE=false;before=reads;step(7.7);step(8);assert(reads==before, "disabled observer performs no scans")
AUTO_DAMAGE=true;row(10,2);step(8.2);assert(target.until_t==10.5, "re-enabling starts with a baseline")
return "PASS: real automatic target/tick/render integration; throttling, 3s renewal/expiry, switching, lethal fade, manual priority, menus, world reset and off switch"
