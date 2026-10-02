local function read_damage_block(address, size)
    if not address or address < 65536 or size <= 0 or size > BIG then return nil end
    if kernel.ReadProcessMemory(process, ffi.cast("const void *", address), big, size, got) == 0
        or got[0] ~= size then return nil end
    return ffi.string(big, size)
end
local damage_reader = make_damage_reader({game=game, read=rd, pointer=ptr, block=read_damage_block,
                                         u32=u32, i32=i32, hex64=hex64})
local damage_detector = make_damage_detector(function(kind)
    local marker = marker_of(kind)
    return marker and marker >= 1 and marker <= 4
end)
local damage_next, damage_world, damage_status = 0, nil, nil
local function damage_step(now, menu)
    local world = sr.Application.main_world()
    if not AUTO_DAMAGE or menu or not world then
        damage_detector:reset(); damage_next = 0; damage_status = nil; return
    end
    if world ~= damage_world then
        damage_detector:reset(); damage_next = 0; damage_world = world; damage_status = nil
    end
    if now < damage_next then return end
    damage_next = now + 0.125
    local snapshot, peer, why = damage_reader()
    local status = snapshot and "ready" or (why or "waiting")
    if damage_status ~= status then
        log("damage observer: " .. status .. (snapshot and ("; records " .. snapshot.count .. "; interval 0.125s") or ""))
        damage_status = status
    end
    local event = damage_detector:observe(snapshot, peer, world,
        target and target.source == "damage" and target.unit or nil)
    if not event then return end
    -- Keep manual selection until its mark is lost or the target dies.
    if target and target.world == world and target.source ~= "damage"
        and not target.dead_t and not target.mark_lost_at then return end
    local rec = event.record
    local same = target and target.source == "damage" and target.world == world
        and target.unit == rec.unit and target.entity == rec.entity and target.type == rec.type
        and target.descriptor == rec.descriptor and not target.dead_t
    if not same then
        local mx = max_hp(rec.type) or math.max(event.previous_hp, rec.hp, 1)
        local marker, sp = marker_of(rec.type), spot_of(rec.type)
        target = {source="damage", unit=rec.unit, entity=rec.entity, type=rec.type,
            descriptor=rec.descriptor, name=name_of(rec.type), max=mx, world=world,
            marker=marker, colour=ping_colour(marker), off={0,0,0.9 * ((sp and sp.r0) or 1)}}
        log("damage target " .. target.name .. " entity " .. rec.entity .. "; local credit; delta " .. event.damage)
    end
    target.until_t, target.mark_lost_at = now + DAMAGE_DURATION, nil
    target.max, last_hp = math.max(target.max, rec.hp), math.max(0, rec.hp)
    if event.dead then
        local ok, sx, sy = pcall(screen_of, now)
        target.dead_t, target.until_t, last_hp = now, now + 1.5, 0
        target.death_sx = ok and sx or target.last_sx
        target.death_sy = ok and sy or target.last_sy
        log("death entity " .. rec.entity .. "; damage observation; animation 1.5s")
    end
end
