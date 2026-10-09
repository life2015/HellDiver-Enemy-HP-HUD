-- Integrate the real ping controller, update controller and GUI presentation.
-- Native memory readers are fixtures; none of the ping_target transitions are mocked.
local E = assert(loadstring(ENGINE_SOURCE))()
local sr, state = E.sr, {frames=0}
local ping_ui = MAKE_PRESENTATION(sr, E.font_ids)
local ui = MAKE_PRESENTATION(sr, E.font_ids)
local target, last_hp, shown
local ping_target, ping_hp, last_mark, ping_shown
local OFFSET, UI_SCALE, BAR_WIDTH, SHOW_NAME = -40, 1, 172, false
local now, menu, mark, marked, health, position = 0, false, nil, true, 100, true
local readable, world = true, "main"
local os = {clock=function() return now end}
sr.Application.main_world = function() return world end
sr.Window = {show_cursor=function() return menu end}
local function log() end
local function hide() ping_ui:hide(); ping_shown=false end
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
local death_confirmed=false
--[[TARGET_CONTROLLER]]
local function damage_step()
    -- Independent life-state reader fixture; health disappearance alone is not death.
    if ping_target and (death_confirmed or health==0) and readable then ping_target.observed_dead=true end
end


--[[UPDATE_CONTROLLER]]

local function step(frame, time)
    state.frames, now = frame-1, time
    if mark then mark.age=mark.age+0.01 end
    E.next_frame(); tick()
end
local function label() return ping_ui.gui.parts[ping_ui.texts.current5] end
local function acquire(entity, frame, time)
    mark={entity=entity,slot=entity,age=0,kind=1}
    marked,health,position,readable=true,100,true,true
    step(frame,time);step(frame+1,time+0.15)
    assert(ping_shown and not ping_target.dead_t and label().text=="100" and label().tint.a>200)
end
local function finish_death(frame, time)
    assert(ping_target and ping_target.dead_t and ping_shown and label().text=="ELIMINATED",
           "death must survive removal of the ping/ping_target position")
    local dead_t=ping_target.dead_t
    step(frame+1,time+0.2)
    assert(ping_target.dead_t==dead_t and label().tint.a>200, "death timer must not restart")
    step(frame+2,time+1.3)
    assert(label().text=="ELIMINATED" and label().tint.a>0 and label().tint.a<150)
    step(frame+3,time+1.51)
    assert(ping_target==nil and not ping_shown and not ping_ui.gui.visible, "death must finish and hide")
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
    death_confirmed=true
    health=index==2 and "missing" or 0
    step(frame+6,time+0.2)
    finish_death(frame+6,time+0.2)
    death_confirmed=false
end

-- Ping deletion may precede the final HP update by one frame.
acquire(20,100,13)
marked,position=false,false
step(102,13.2); assert(not ping_shown, "unmarked live ping_target should hide immediately")
health=0;step(103,13.23);finish_death(103,13.23)

-- Manual cancellation is never a kill while the ping_target remains alive.
acquire(21,120,16)
marked=false;step(126,16.2)
assert(not ping_shown and (not ping_target or not ping_target.dead_t))
step(127,16.4);assert(not ping_target and not ping_shown)
-- Unreadable health does not turn a cancelled mark into a kill.
acquire(22,140,18)
marked,readable=false,false
step(144,18.2);assert(not ping_shown and (not ping_target or not ping_target.dead_t))
step(145,18.4);assert(not ping_target and not ping_shown)

-- A live ping_target behind the camera and menus still hide as before.
acquire(23,160,20)
position=false;step(162,20.2);assert(not ping_shown)
position=true;step(163,20.3);step(164,20.45);assert(ping_shown)
menu=true;step(165,20.5);assert(not ping_shown)
menu=false;step(166,20.6);assert(ping_shown)

-- An explicit new mark replaces the old death card, with fresh animation state.
health=0;step(168,20.7);assert(ping_target.dead_t)
acquire(24,169,20.8);assert(not ping_target.dead_t and label().text=="100")
-- World changes must not create a death card for the previous mission.
world="other-main";health="missing";step(180,21.1)
assert(not ping_target and not ping_shown)
return "PASS: real ping/tick/render integration; repeated kills, removed pings/corpses, one-frame HP lag, independent fades, manual cancel, unreadable health, menus, ping_target switch and world change"
