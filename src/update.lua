local function update_target(target, last_hp, ui, now, menu, suppressed)
    local function hide() pcall(ui.hide, ui) end
    if not target then hide() return target, last_hp, false end
    if target.world ~= sr.Application.main_world() then
        target = nil; last_hp = nil; hide(); return target, last_hp, false
    end
    if menu then hide() return target, last_hp, false end
    if target.observed_dead and not target.dead_t then
        target.dead_t = now; last_hp = 0; target.until_t = now + 1.5
        target.death_sx, target.death_sy = target.last_sx, target.last_sy
        log("death entity " .. tostring(target.entity) .. "; confirmed life state; animation 1.5s")
    end

    -- A killed enemy's ping may disappear before its final life-state update. Keep a
    -- short, hidden pending target so that ping removal cannot discard death.
    -- A living cancelled target is hidden immediately and never called a kill.
    local damage_expired = target.source == "damage" and now > target.until_t
    if not target.dead_t and target.source ~= "damage" and now > target.until_t and not target.mark_lost_at then
        target.mark_lost_at = now
    end
    if not target.dead_t and (state.frames % 12 == 0 or not last_hp or target.mark_lost_at or damage_expired) then
        local hu = health_units()
        local rec = hu and hu[target.unit]
        if rec and rec.entity == target.entity and rec.hp then
            last_hp = math.max(0, rec.hp)
            if target.max and rec.hp > target.max then target.max = rec.hp end
        elseif hu and (not rec or rec.entity ~= target.entity) then
            -- Despawn/read gaps and downed HP=0 are not proof of death.
            target = nil; last_hp = nil; hide(); return target, last_hp, false
        end
    end
    if damage_expired and not target.dead_t then
        target = nil; last_hp = nil; hide(); return target, last_hp, false
    end
    if not target.dead_t and target.mark_lost_at then
        if now - target.mark_lost_at >= 0.15 then target = nil; last_hp = nil end
        hide(); return target, last_hp, false
    end
    if target.dead_t and now > target.dead_t + 1.5 then
        target = nil; last_hp = nil; hide(); return target, last_hp, false
    end

    local sx, sy
    if target.dead_t then
        -- The unit can be removed immediately on death. Finish the card at its
        -- last visible position without requiring a surviving corpse/marker.
        sx, sy = target.death_sx, target.death_sy
    else
        local okp
        okp, sx, sy = pcall(screen_of, now, target)
        if not okp then
            state.last_proj_error = tostring(sx); sx, sy = nil, nil
        end
    end
    if target.off and not sx then hide() return target, last_hp, false end
    local wres, hres = sr.Gui.resolution()
    if sx and (sx < 0 or sx > wres or sy < 0 or sy > hres) then hide() return target, last_hp, false end
    if suppressed then
        -- Keep a position for an automatic death fade if its ping is later replaced.
        if not target.dead_t then target.last_sx, target.last_sy = sx, sy end
        hide(); return target, last_hp, false
    end
    local ok, result = pcall(ui.draw, ui, {key = target, hp = last_hp or 0,
        max = target.max or last_hp or 0, name = target.name,
        colour = target.colour, dead_t = target.dead_t,
        parts = PART_HUD and not target.dead_t and target.parts or nil}, sx, sy, now,
        {offset = OFFSET, scale = UI_SCALE, opacity = UI_OPACITY, width = BAR_WIDTH, show_name = SHOW_NAME})
    local shown = ok and result == true
    if shown and not target.dead_t then target.last_sx, target.last_sy = sx, sy end
    if not ok then
        hide()
        if state.last_draw_error ~= tostring(result) then
            state.last_draw_error = tostring(result); log("draw error: " .. tostring(result))
        end
    end
    return target, last_hp, shown
end

local function tick()
    if settings then settings:step() end
    state.frames = state.frames + 1
    local now = os.clock()
    local okr, er = pcall(ring_step, now)
    if not okr and state.last_ring_error ~= tostring(er) then
        state.last_ring_error = tostring(er); log("ring error: " .. tostring(er))
    end

    local menu = false
    pcall(function() menu = sr.Window.show_cursor() == true end)
    local okd, ed = pcall(damage_step, now, menu)
    if not okd then
        damage_detector:reset()
        if target then target.parts = nil end
        if ping_target then ping_target.parts = nil end
        if state.last_damage_error ~= tostring(ed) then
            state.last_damage_error = tostring(ed); log("damage observer error: " .. tostring(ed))
        end
    end
    ping_target, ping_hp, ping_shown = update_target(ping_target, ping_hp, ping_ui, now, menu)
    -- The same enemy uses the ping card while visible; keep the damage timer so
    -- cancelling a ping can reveal the still-valid automatic card without replaying a hit.
    local duplicate = ping_shown and target and ping_target
        and target.world == ping_target.world and target.unit == ping_target.unit
        and target.entity == ping_target.entity and target.type == ping_target.type
    target, last_hp, shown = update_target(target, last_hp, ui, now, menu, duplicate)
end
