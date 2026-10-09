local E=assert(loadstring(ENGINE_SOURCE))()
local sr,state=E.sr,{frames=0}
local ui=MAKE_PRESENTATION(sr,E.font_ids)
local ping_ui=MAKE_PRESENTATION(sr,E.font_ids)
local now,world,menu,position=0,"main",false,true
local target,last_hp,shown,mark,marked
local OFFSET,UI_SCALE,BAR_WIDTH,SHOW_NAME=-40,1,172,false
local AUTO_DAMAGE,DAMAGE_DURATION=true,3
local AUTO_DAMAGE_MIN_HP=0
local PART_HUD=false
local MULTI_PARTS=false
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
local enemy_max=100
local type_max={}
local function max_hp(kind) return type_max[kind] or enemy_max end
local function name_of() return "Enemy" end
local function marker_of() return 1 end
local function spot_of() return {r0=1} end
local function ping_colour() return {255,235,60,50} end
local NAMES={enemy="Enemy"}
local split_positions=false
local function screen_of(_,subject)
    if position then return split_positions and subject and subject.unit*10 or 900,500 end
end
local function make_damage_reader()
    return function()
        reads=reads+1
        local copy={};for unit,row in pairs(rows) do copy[unit]={};for k,v in pairs(row) do copy[unit][k]=v end end
        return {manager=1,records=copy,count=2},peer
    end
end
local make_damage_detector=MAKE_DAMAGE_DETECTOR
local metadata={}
local function make_part_metadata() return function(row,index) return metadata[index] end end
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

-- Manual and damage selection are independent; both cards remain visible.
row(11,100);mark={entity=11,slot=1,age=0,kind=1};marked=true
step(6.1);assert(ping_target.unit==11 and target.unit==10 and ping_shown and shown)
row(10,20);step(6.3);assert(ping_target.unit==11 and target.unit==10 and ping_shown and shown)
marked=false;state.frames=5;step(6.5);assert(not ping_shown and shown)
row(10,10);step(6.65);assert(target.unit==10 and target.source=="damage")

menu=true;step(6.8);assert(not shown)
row(10,5);local before=reads;step(6.95);assert(reads==before, "menus suspend observer")
menu=false;step(7.1);assert(target.until_t==9.65, "reopening must baseline, not attribute paused damage")
world="new-main";step(7.3);assert(not target and not shown)
row(10,3);step(7.5);assert(target and target.world==world)

AUTO_DAMAGE=false;before=reads;step(7.7);step(8)
assert(not target and not shown and reads==before, "turning auto off immediately hides its target")
AUTO_DAMAGE=true;step(8.2);assert(not target, "re-enabling baselines instead of replaying damage")
row(10,2);step(8.4);assert(target.until_t==11.4, "next observed hit activates after re-enabling")
-- Part prototype uses the real reader/controller/render boundary with snapshot fixtures.
local function pstep(time) if marked then state.frames=5 end;step(time) end
PART_HUD=true;world="parts-world";target=nil;marked=false;rows={}
enemy_max=775
local function first_part() return target and target.parts and target.parts[1] end
local function partrow(unit,hp,a,b,credit)
    row(unit,hp,credit);rows[unit].parts={[1]=a,[2]=b}
end
partrow(20,100,300,200);pstep(20)
partrow(20,100,250,200);pstep(20.2)
assert(shown and target.unit==20 and first_part().index==1 and not target.dead_t)
local function partlabel() return ui.gui.parts[ui.texts.part_label5] end
local function partvalue() return ui.gui.parts[ui.texts.part_value5] end
assert(partlabel().text=="PART 01" and partvalue().text=="250 HP" and label().text=="100")
partrow(20,100,250,160);pstep(20.4)
assert(first_part().index==2 and partvalue().text=="160 HP")
partrow(20,100,250,0);pstep(20.6)
assert(first_part().hp==0 and not target.dead_t and label().text=="100", "part zero is not ELIMINATED")
local expiry=target.until_t
partrow(20,100,250,100,"other");pstep(20.8)
assert(partvalue().text=="100 HP" and target.until_t==expiry, "display refresh does not falsely renew local hit")
partrow(21,100,100,100);pstep(21)
partrow(21,75,100,100);pstep(21.2)
assert(target.unit==21 and not first_part() and partvalue().tint.a==0, "retarget clears retained part label")
local function pingpart() return ping_target and ping_target.parts and ping_target.parts[1] end
local function pingvalue() return ping_ui.gui.parts[ping_ui.texts.part_value5] end
local function pingmain() return ping_ui.gui.parts[ping_ui.texts.current5] end
-- Manual ping must still update its parts when automatic target selection is disabled.
mark={entity=20,slot=2,age=0,kind=1};marked=true;pstep(21.4)
AUTO_DAMAGE=false
partrow(20,100,200,100);pstep(21.6)
assert(ping_target.unit==20 and ping_target.source~="damage" and pingpart().index==1)
partrow(21,60,10,100);pstep(21.8)
assert(ping_target.unit==20 and pingpart().index==1, "foreign target cannot replace pinned part")
state.frames=5;pstep(24.7);assert(not pingpart() and pingvalue().tint.a==0 and ping_shown, "part expires independently of manual HUD")
partrow(20,100,150,100);pstep(24.9);assert(pingpart())
menu=true;pstep(25.1);assert(not pingpart() and not ping_shown)
menu=false;pstep(25.3);assert(not pingpart())
partrow(20,100,100,100);pstep(25.5);assert(pingpart())
PART_HUD=false;pstep(25.7);assert(not pingpart() and pingvalue().tint.a==0)
PART_HUD=true;pstep(25.9)
partrow(20,0,0,100);rows[20].life=2;pstep(26.1)
state.frames=11;step(26.11)
assert(pingmain().text=="ELIMINATED" and pingvalue().tint.a==0, "enemy death hides part row")
-- Metadata, bars and fatal flags must remain independent from observed death.
world="part-bars";target=nil;marked=false;rows={};AUTO_DAMAGE=true;PART_HUD=true
metadata[1]={label="HEAD",max=500,fatal=true}
partrow(30,100,500,100);step(40)
partrow(30,100,150,100);step(40.2)
assert(partlabel().text=="HEAD [FATAL]" and partvalue().text=="150 / 500  30%")
local function partrect(key) return ui.gui.parts[ui.rects[key]] end
assert(math.abs(partrect("part_fill").size.x/partrect("part_track").size.x-0.3)<0.01)
partrow(30,100,0,100);step(40.4)
assert(not target.dead_t and label().text=="100" and partrect("part_fill").size.x==0,
    "fatal flag plus empty part pool is not itself confirmed death")
metadata[1]=nil;step(40.6)
assert(partlabel().text=="PART 01" and partrect("part_track").tint.a==0,
    "metadata loss hides old percentage/bar and reverts to numeric")
metadata[1]={label="HEAD",max=500,fatal=true};partrow(30,0,0,100);rows[30].life=1;step(40.8)
assert(not target.dead_t and label().text=="0", "downed main HP zero is not death")
rows[30].life=2;step(41)
assert(target.dead_t and label().text=="ELIMINATED" and partrect("part_track").tint.a==0,
    "life state alone confirms death even without another HP drop")
world="shared-bars";target=nil;rows={}
metadata[1]={label="BODY",shared=true,fatal=false}
partrow(31,100,500,100);step(43)
partrow(31,100,400,100);step(43.2)
assert(partvalue().text=="400 HP (SHARED)" and partrect("part_track").tint.a==0)
metadata[1]={label="HEAD",max=300,fatal=true};step(43.4)
assert(not first_part().max and partrect("part_track").tint.a==0,
    "observed HP above configured maximum cannot produce a guessed/clamped bar")
metadata[1]={label="HEAD",max=500,downed=true};step(43.6)
assert(partlabel().text=="HEAD [DOWN]" and partvalue().text=="400 / 500  80%")
rows={};state.frames=11;step(43.8)
assert(not target and not shown, "unobserved despawn must not produce ELIMINATED")
-- Automatic thresholds use maximum HP (inclusive), not injured current HP.
local time=50
for _, threshold in ipairs({0,500,1000}) do
    for _, maximum in ipairs({100,499,500,999,1000}) do
        world='threshold-'..threshold..'-'..maximum;target=nil;rows={};marked=false
        AUTO_DAMAGE=true;AUTO_DAMAGE_MIN_HP=threshold;enemy_max=maximum
        row(40,maximum);step(time)
        row(40,1);step(time+0.2)
        assert(shown==(maximum>=threshold), 'inclusive maximum HP filter failed')
        if shown then assert(target.max==maximum and label().text=='1') end
        time=time+1
    end
end
-- Filter candidates before AoE ranking; the excluded small enemy loses far more HP.
world='threshold-aoe';target=nil;rows={};AUTO_DAMAGE_MIN_HP=1000
type_max.small=499;type_max.large=1500
row(41,499);rows[41].type='small';row(42,1500);rows[42].type='large';step(70)
row(41,1);rows[41].type='small';row(42,1499);rows[42].type='large';step(70.2)
assert(target.unit==42, 'excluded target must not win AoE ranking')
-- APPLY changes hide an ineligible automatic target before the next damage poll.
AUTO_DAMAGE_MIN_HP=0;row(41,0);rows[41].type='small';step(70.4)
assert(target.unit==41)
AUTO_DAMAGE_MIN_HP=500;step(70.41);assert(not target and not shown)
-- A marked medium enemy remains visible under the heavy filter, even with auto off.
world='threshold-manual';target=nil;rows={};enemy_max=775;AUTO_DAMAGE_MIN_HP=1000
partrow(43,100,500,100);mark={entity=43,slot=3,age=0,kind=1};marked=true;AUTO_DAMAGE=false
pstep(72);partrow(43,100,400,100);pstep(72.2)
assert(ping_target.unit==43 and ping_target.source~='damage' and ping_shown and pingpart())
PART_HUD=false;pstep(72.21)
assert(ping_shown and not pingpart() and pingvalue().tint.a==0,
    'part toggle hides immediately while retaining manually marked main HP')
-- Independent retained parts: fatal first, newest damage next, three rows max.
world='multi-parts';target=nil;rows={};marked=false;AUTO_DAMAGE=true;AUTO_DAMAGE_MIN_HP=0
PART_HUD=true;MULTI_PARTS=true;enemy_max=2000
metadata={[1]={label='HEAD',max=500,fatal=true},[2]={label='LEFT ARM',max=500},
          [3]={label='RIGHT ARM',max=500},[4]={label='CORE',max=500,fatal=true},[5]={label='LEG',max=500}}
local pools={500,500,500,500,500}
local function hitparts(time,losses,credit)
    for i,loss in pairs(losses or {}) do pools[i]=pools[i]-loss end
    row(50,1000,credit);rows[50].parts={unpack(pools)};step(time)
end
local function order(...)
    local expected={...};assert(target and target.parts and #target.parts==#expected)
    for i,index in ipairs(expected) do assert(target.parts[i].index==index, 'unexpected part ordering') end
end
hitparts(100);hitparts(101,{[1]=10});hitparts(101.2,{[2]=10});order(1,2)
assert(target.parts[1].until_t==104, 'a different part hit must not renew this timer')
hitparts(101.4,{[3]=10});order(1,3,2)
hitparts(101.6,{[5]=10});order(1,5,3)
hitparts(101.8,{[4]=1,[2]=20});order(4,1,2)
assert(target.parts[1].damage==1, 'a small fatal-part hit must not be dropped behind a larger normal hit')
hitparts(102,{[1]=10});order(1,4,2)
hitparts(102.2,{[4]=499},'other');order(1,4,2)
assert(target.parts[2].hp==0 and target.parts[2].until_t==104.8 and not target.dead_t,
    'foreign changes update pool health without renewal/reordering or a false kill')
hitparts(104.81);order(1)
assert(partrect('part2_track').tint.a==0 and partrect('part3_track').tint.a==0,
    'expired retained slots must clear all old bars')
hitparts(104.95,{[3]=10,[5]=10});order(1,3,5)
metadata[1]=nil;hitparts(105.1);order(3,5)
rows[50].life=2;step(105.3)
assert(label().text=='ELIMINATED' and partrect('part_track').tint.a==0
    and partrect('part2_track').tint.a==0 and partrect('part3_track').tint.a==0)
-- Default single-part mode follows the latest hit, including after a fatal part.
world='optional-multi-parts';target=nil;rows={};MULTI_PARTS=false
metadata[1]={label='HEAD',max=500,fatal=true};pools={500,500,500,500,500}
hitparts(110);hitparts(110.2,{[1]=10});order(1)
hitparts(110.4,{[2]=10});order(2)
assert(partrect('part2_track').tint.a==0 and partrect('part3_track').tint.a==0)
MULTI_PARTS=true
hitparts(110.6,{[1]=10});hitparts(110.8,{[3]=10});order(1,3,2)
local latest_until=target.parts[2].until_t
MULTI_PARTS=false
local reads_before=reads
step(110.81);order(3)
assert(reads==reads_before and target.parts[1].until_t==latest_until,
    'turning multi off must collapse immediately without polling or renewing timers')
assert(partrect('part2_track').tint.a==0 and partrect('part3_track').tint.a==0)
MULTI_PARTS=true;step(110.82);order(3) -- removed rows are not resurrected
hitparts(111,{[2]=10});order(2,3)
PART_HUD=false;step(111.01);assert(not target.parts and partrect('part_track').tint.a==0)
PART_HUD=true;hitparts(111.2,{[1]=10});order(1)
-- Two channels: real ping, observer and renderer, independent parts/lifetimes.
world='dual-targets';target=nil;rows={};marked=true;AUTO_DAMAGE=true;AUTO_DAMAGE_MIN_HP=0
PART_HUD=true;MULTI_PARTS=true;split_positions=true;position=true;enemy_max=2000
mark={entity=60,slot=60,age=0,kind=1}
partrow(60,1000,500,500);partrow(61,1000,500,500)
local function dual(t) state.frames=5;step(t) end
local function hitmain() return ui.gui.parts[ui.texts.current5] end
local function hitpartvalue() return ui.gui.parts[ui.texts.part_value5] end
dual(120);assert(ping_shown and ping_target.unit==60 and not shown)
-- Both enemies lose parts in one sample; the larger hit wins auto selection,
-- while the ping channel still receives its own event and part metadata.
partrow(60,990,490,500);partrow(61,950,500,450);dual(120.2)
assert(ping_target.unit==60 and target.unit==61 and ping_shown and shown)
assert(pingpart().index==1 and first_part().index==2)
assert(ping_target.parts~=target.parts and pingpart()~=first_part())
assert(ui.gui~=ping_ui.gui and ui.gui.visible and ping_ui.gui.visible)
assert(ping_target.last_sx==600 and target.last_sx==610, 'each card projects its own enemy')
local ping_identity=ping_target
-- Stopping attacks expires only the automatic card; ping continues indefinitely.
dual(123.21);assert(not target and not shown and ping_target==ping_identity and ping_shown)
partrow(61,900,500,400);dual(123.4);assert(shown and ping_shown)
-- Killing the pinged enemy does not replace/hide the living damage target.
rows[60].life=2;rows[60].creditor='other';dual(123.6)
assert(ping_target.dead_t and pingmain().text=='ELIMINATED')
assert(target.unit==61 and not target.dead_t and shown and hitmain().text=='900')
dual(125.11);assert(not ping_target and not ping_shown and shown and target.unit==61)
-- New ping while automatic remains visible, then death of automatic only.
partrow(62,1000,500,500);mark={entity=62,slot=62,age=0,kind=1};dual(125.3)
rows[61].life=2;rows[61].hp=0;dual(125.5)
assert(shown and hitmain().text=='ELIMINATED' and ping_shown and not ping_target.dead_t)
dual(127.01);assert(not shown and not target and ping_shown)
-- A shared enemy renders once; cancelling its ping exposes its unexpired damage card.
partrow(62,950,450,500);dual(127.2)
assert(target.unit==62 and ping_target.unit==62 and ping_shown and not shown)
marked=false;dual(127.4)
assert(not ping_shown and shown and target.unit==62)
dual(127.6);assert(not ping_target and shown)
-- Auto off or a stricter threshold affects only automatic cards, never a ping.
mark={entity=60,slot=63,age=0,kind=1};marked=true;partrow(60,1000,500,500);dual(127.8)
AUTO_DAMAGE=false;dual(127.81);assert(not target and not shown and ping_shown)
AUTO_DAMAGE_MIN_HP=1000;enemy_max=775
partrow(63,700,500,500);mark={entity=63,slot=64,age=0,kind=1};dual(128)
partrow(63,690,450,500);dual(128.2)
assert(ping_shown and pingpart() and not target, 'manual part hits bypass automatic filtering')
AUTO_DAMAGE=true;partrow(63,680,400,500);dual(128.4)
assert(ping_shown and not target, 'automatic threshold cannot suppress manual HUD')
-- Menu hides both and world changes clear both, without retaining stale GUI rows.
enemy_max=2000;partrow(64,1000,500,500);dual(128.6)
partrow(64,900,500,400);dual(128.8);assert(shown and ping_shown)
menu=true;dual(129);assert(not shown and not ping_shown and not ui.gui.visible and not ping_ui.gui.visible)
menu=false;dual(129.2);assert(shown and ping_shown)
world='dual-next-world';marked=false;rows={};dual(129.4)
assert(not target and not ping_target and not shown and not ping_shown)
-- Shared-target death: one animation, then a new ping reveals the old auto fade
-- at its retained position even when the dead unit can no longer be projected.
world='shared-death';rows={};marked=true;AUTO_DAMAGE_MIN_HP=0;enemy_max=2000
mark={entity=65,slot=65,age=0,kind=1};partrow(65,1000,500,500);dual(130)
partrow(65,950,450,500);dual(130.2);assert(ping_shown and not shown)
position=false;rows[65].hp=0;rows[65].life=2;dual(130.4)
assert(ping_shown and not shown and pingmain().text=='ELIMINATED')
position=true;partrow(66,1000,500,500);mark={entity=66,slot=66,age=0,kind=1};dual(130.6)
assert(ping_target.unit==66 and ping_shown and shown and target.unit==65)
assert(target.death_sx==650 and hitmain().text=='ELIMINATED')
dual(131.91);assert(ping_shown and not shown and not target)
return "PASS: independent ping/damage targets and GUIs, simultaneous part hits, independent expiry/death, shared-target dedup/cancel, auto-off/threshold isolation, menus/world reset; default single-part mode, optional three-part mode, immediate collapse and re-enable, simultaneous hits, fatal/newest priority, independent expiry and renewal, row cleanup, native metadata, part-only hits, observed death, foreign updates, manual-only mode, menu/toggle, HP thresholds and AoE filtering; automatic target lifecycle and fades"
