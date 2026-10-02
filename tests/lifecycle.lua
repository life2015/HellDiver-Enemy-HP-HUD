-- Integrate the real ping controller, update controller and GUI presentation.
-- Native memory readers are fixtures; none of the target transitions are mocked.
local E = assert(loadstring(ENGINE_SOURCE))()
local sr, state = E.sr, {frames=0}
local ui = MAKE_PRESENTATION(sr, E.font_ids)
local target, last_hp, last_mark, shown
local OFFSET, UI_SCALE, BAR_WIDTH, SHOW_NAME = -40, 1, 172, false
local now, menu, mark, marked, health, position = 0, false, nil, true, 100, true
local readable, world = true, "main"
local os = {clock=function() return now end}
sr.Application.main_world = function() return world end
sr.Window = {show_cursor=function() return menu end}
local function log() end
local function hide() ui:hide(); shown=false end
local function local_creator() return 1 end
local function newest_mark() return marked and mark or nil end
local function entity_marked() return marked end
local function health_units()
    if not readable then return nil end
    if health == "missing" then return {} end
    return {[mark.entity]={entity=mark.entity, type="test", hp=health}}
end
local function unit_of_entity(hu, entity) return hu[entity] and entity, hu[entity] end
local function max_hp() return 100 end
local function name_of() return "Test enemy" end
local function marker_of() return 1 end
local function ping_colour() return {255,235,60,50} end
local function spot_of() return {r0=1} end
local NAMES={test="Test enemy"}
local function screen_of() if position then return 900,500 end end
local function damage_step() end -- This suite isolates manual-ping lifecycle.

--[[TARGET_CONTROLLER]]
--[[UPDATE_CONTROLLER]]

local function step(frame, time)
    state.frames, now = frame-1, time
    if mark then mark.age=mark.age+0.01 end
    E.next_frame(); tick()
end
local function label() return ui.gui.parts[ui.texts.current5] end
local function acquire(entity, frame, time)
    mark={entity=entity,slot=entity,age=0,kind=1}
    marked,health,position,readable=true,100,true,true
    step(frame,time);step(frame+1,time+0.15)
    assert(shown and not target.dead_t and label().text=="100" and label().tint.a>200)
end
local function finish_death(frame, time)
    assert(target and target.dead_t and shown and label().text=="ELIMINATED",
           "death must survive removal of the ping/target position")
    local dead_t=target.dead_t
    step(frame+1,time+0.2)
    assert(target.dead_t==dead_t and label().tint.a>200, "death timer must not restart")
    step(frame+2,time+1.3)
    assert(label().text=="ELIMINATED" and label().tint.a>0 and label().tint.a<150)
    step(frame+3,time+1.51)
    assert(target==nil and not shown and not ui.gui.visible, "death must finish and hide")
end

-- First death with a still-present ping.
acquire(10,1,0)
health=0;step(12,0.2);finish_death(12,0.2)
-- Later deaths: the game removes the ping before the next scheduled HP poll,
-- and the corpse's unit position is already unavailable.
for index=1,3 do
    local frame,time=24*index,3*index
    acquire(10+index,frame,time)
    marked,position=false,false
    health=index==2 and "missing" or 0
    step(frame+6,time+0.2)
    finish_death(frame+6,time+0.2)
end

-- Ping deletion may precede the final HP update by one frame.
acquire(20,100,13)
marked,position=false,false
step(102,13.2); assert(not shown, "unmarked live target should hide immediately")
health=0;step(103,13.23);finish_death(103,13.23)

-- Manual cancellation is never a kill while the target remains alive.
acquire(21,120,16)
marked=false;step(126,16.2)
assert(not shown and (not target or not target.dead_t))
step(127,16.4);assert(not target and not shown)
-- Unreadable health does not turn a cancelled mark into a kill.
acquire(22,140,18)
marked,readable=false,false
step(144,18.2);assert(not shown and (not target or not target.dead_t))
step(145,18.4);assert(not target and not shown)

-- A live target behind the camera and menus still hide as before.
acquire(23,160,20)
position=false;step(162,20.2);assert(not shown)
position=true;step(163,20.3);step(164,20.45);assert(shown)
menu=true;step(165,20.5);assert(not shown)
menu=false;step(166,20.6);assert(shown)

-- An explicit new mark replaces the old death card, with fresh animation state.
health=0;step(168,20.7);assert(target.dead_t)
acquire(24,169,20.8);assert(not target.dead_t and label().text=="100")
-- World changes must not create a death card for the previous mission.
world="other-main";health="missing";step(180,21.1)
assert(not target and not shown)
return "PASS: real ping/tick/render integration; repeated kills, removed pings/corpses, one-frame HP lag, independent fades, manual cancel, unreadable health, menus, target switch and world change"
