local function tick()
    state.frames = state.frames + 1
    local now = os.clock()
    local okr, er = pcall(ring_step, now)
    if not okr and state.last_ring_error ~= tostring(er) then
        state.last_ring_error = tostring(er); log("ring error: " .. tostring(er))
    end

    local menu = false
    pcall(function() menu = sr.Window.show_cursor() == true end)
    if not target then hide() return end
    if target.world ~= sr.Application.main_world() then
        target = nil; last_hp = nil; hide(); return
    end
    if menu then hide() return end

    -- A killed enemy's ping may disappear before its final HP update. Keep a
    -- short, hidden pending target so that ping removal cannot discard death.
    -- A living cancelled target is hidden immediately and never called a kill.
    if not target.dead_t and now > target.until_t and not target.mark_lost_at then
        target.mark_lost_at = now
    end
    if not target.dead_t and (state.frames % 12 == 0 or not last_hp or target.mark_lost_at) then
        local hu = health_units()
        local rec = hu and hu[target.unit]
        if rec and rec.entity == target.entity and rec.hp and rec.hp > 0 then
            last_hp = rec.hp
            if target.max and rec.hp > target.max then target.max = rec.hp end
        elseif hu and (not rec or rec.entity ~= target.entity or (rec.hp and rec.hp <= 0)) then
            target.dead_t = now; last_hp = 0; target.until_t = now + 1.5
            target.death_sx, target.death_sy = target.last_sx, target.last_sy
            log("death entity " .. tostring(target.entity) .. "; animation 1.5s")
        end
    end
    if not target.dead_t and target.mark_lost_at then
        if now - target.mark_lost_at >= 0.15 then target = nil; last_hp = nil end
        hide(); return
    end
    if target.dead_t and now > target.dead_t + 1.5 then
        target = nil; last_hp = nil; hide(); return
    end

    local sx, sy
    if target.dead_t then
        -- The unit can be removed immediately on death. Finish the card at its
        -- last visible position without requiring a surviving corpse/marker.
        sx, sy = target.death_sx, target.death_sy
    else
        local okp
        okp, sx, sy = pcall(screen_of, now)
        if not okp then
            state.last_proj_error = tostring(sx); sx, sy = nil, nil
        end
    end
    if target.off and not sx then hide() return end
    local wres, hres = sr.Gui.resolution()
    if sx and (sx < 0 or sx > wres or sy < 0 or sy > hres) then hide() return end
    local ok, result = pcall(ui.draw, ui, {key = target, hp = last_hp or 0,
        max = target.max or last_hp or 0, name = target.name,
        colour = target.colour, dead_t = target.dead_t}, sx, sy, now,
        {offset = OFFSET, scale = UI_SCALE, width = BAR_WIDTH, show_name = SHOW_NAME})
    shown = ok and result == true
    if shown and not target.dead_t then target.last_sx, target.last_sy = sx, sy end
    if not ok then
        hide()
        if state.last_draw_error ~= tostring(result) then
            state.last_draw_error = tostring(result); log("draw error: " .. tostring(result))
        end
    end
end
