local function read_damage_block(address, size)
    if not address or address < 65536 or size <= 0 or size > BIG then return nil end
    if kernel.ReadProcessMemory(process, ffi.cast("const void *", address), big, size, got) == 0
        or got[0] ~= size then return nil end
    return ffi.string(big, size)
end
local damage_reader = make_damage_reader({game=game, read=rd, pointer=ptr, block=read_damage_block,
                                         u32=u32, i32=i32, hex64=hex64})
local part_metadata = make_part_metadata({game=game, read=rd, pointer=ptr, block=read_damage_block,
                                         u32=u32, i32=i32, hex64=hex64, names=part_names})
local function describe_part(part, row)
    -- Metadata is optional; a failed metadata read must not disable main HP.
    local ok, meta = pcall(part_metadata, row, part.index)
    part.label, part.max, part.fatal, part.downed, part.shared =
        string.format("PART %02d", part.index), nil, nil, nil, nil
    if ok and meta then
        part.label = meta.label or part.label
        part.fatal, part.downed, part.shared = meta.fatal, meta.downed, meta.shared
        if meta.max and part.hp <= meta.max then part.max = meta.max end
    end
end
local damage_detector = make_damage_detector(function(kind)
    local marker = marker_of(kind)
    return marker and marker >= 1 and marker <= 4
end)
local damage_next, damage_world, damage_status = 0, nil, nil
local function rank_parts(parts)
    table.sort(parts, function(a, b)
        if MULTI_PARTS and (a.fatal == true) ~= (b.fatal == true) then return a.fatal == true end
        if a.hit_t ~= b.hit_t then return a.hit_t > b.hit_t end
        return a.index < b.index -- simultaneous sampled hits have no finer time order
    end)
    while #parts > (MULTI_PARTS and 3 or 1) do table.remove(parts) end
    return #parts > 0 and parts or nil
end
local function damage_step(now, menu)
    local world = sr.Application.main_world()
    if target and target.source == "damage" and
        (not AUTO_DAMAGE or (target.max or 0) < AUTO_DAMAGE_MIN_HP) then
        target, last_hp = nil, nil
    end
    local function configure_parts(t)
        if not t then return end
        if not PART_HUD then t.parts = nil
        elseif t.parts and not MULTI_PARTS then t.parts = rank_parts(t.parts) end
    end
    configure_parts(target); configure_parts(ping_target)
    if (not AUTO_DAMAGE and not ping_target) or menu or not world then
        if target then target.parts = nil end
        if ping_target then ping_target.parts = nil end
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
    local event, ping_event = damage_detector:observe(snapshot, peer, world,
        target and target.unit or nil, PART_HUD == true, function(row, old)
            local selected = target and target.world == world and target.unit == row.unit
                and target.entity == row.entity and target.type == row.type
                and target.descriptor == row.descriptor
            local maximum = selected and target.max or max_hp(row.type)
            maximum = maximum or math.max(old.hp, row.hp, 1)
            return AUTO_DAMAGE and maximum >= AUTO_DAMAGE_MIN_HP
        end, ping_target and ping_target.unit or nil)
    local function refresh(t)
        if not t then return end
        local row = snapshot and snapshot.records[t.unit]
        if t.world == world and not t.dead_t and row and row.entity == t.entity
            and row.type == t.type and (not t.descriptor or row.descriptor == t.descriptor) then
            t.observed_dead = row.life == 2
        end
        if not t.parts then return end
        local kept = {}
        for _, part in ipairs(t.parts) do
            local hp = row and row.parts and row.parts[part.index]
            if PART_HUD and t.world == world and now <= part.until_t
                and row and row.entity == t.entity and row.type == t.type
                and row.descriptor == part.descriptor and row.network == part.network
                and type(hp) == "number" and hp >= 0 and hp <= 10000000 then
                part.hp = hp; describe_part(part, row); kept[#kept + 1] = part
            end
        end
        t.parts = rank_parts(kept)
    end
    refresh(target); refresh(ping_target)
    local function show_part(t, hit)
        if not PART_HUD or not hit or not hit.part then return end
        local parts, r = t.parts or {}, hit.record
        for _, p in ipairs(hit.parts) do
            local part
            for _, existing in ipairs(parts) do
                if existing.index == p.index then part = existing; break end
            end
            if not part then part = {index=p.index}; parts[#parts + 1] = part end
            part.hp, part.damage, part.hit_t, part.until_t = p.hp, p.damage, now, now + DAMAGE_DURATION
            part.descriptor, part.network = r.descriptor, r.network
            describe_part(part, r)
        end
        t.parts = rank_parts(parts)
    end
    if ping_target and ping_target.world == world and not ping_target.dead_t
        and not ping_target.mark_lost_at and ping_event
        and ping_target.entity == ping_event.record.entity and ping_target.type == ping_event.record.type then
        show_part(ping_target, ping_event)
    end
    if not event or not AUTO_DAMAGE then return end
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
    show_part(target, event)
    if event.dead then
        local ok, sx, sy = pcall(screen_of, now, target)
        target.dead_t, target.until_t, last_hp = now, now + 1.5, 0
        target.death_sx = ok and sx or target.last_sx
        target.death_sy = ok and sy or target.last_sy
        log("death entity " .. rec.entity .. "; damage observation; animation 1.5s")
    end
end
