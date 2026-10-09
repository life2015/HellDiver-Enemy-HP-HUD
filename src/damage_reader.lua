-- Read-only layout for Steam build 25480438. Offsets checked against HD2Runtime
-- 96ab2d2 runtime/event_world.lua and scripts/research_event_combat.py.
-- This adapter has no native hooks and never writes game memory.
return function(api)
    local rd, ptr, block = api.read, api.pointer, api.block
    local u32, i32, hex = api.u32, api.i32, api.hex64
    local function pointer_bytes(bytes, offset)
        local p = u32(bytes, offset) + u32(bytes, offset + 4) * 4294967296
        if p >= 65536 and p < 0x800000000000 then return p end
    end
    return function()
        local user = ptr(api.game + 0x347CEF0)
        local peer_bytes = user and rd(user + 0xB398, 8)
        local peer = peer_bytes and hex(peer_bytes, 0)
        if not peer or peer == "0000000000000000" or peer == "FFFFFFFFFFFFFFFF" then
            return nil, nil, "local peer unavailable"
        end
        local hm = ptr(api.game + 0x3326688)
        local count_bytes = hm and rd(hm + 0x1020, 4)
        if not count_bytes then return nil, peer, "health manager unavailable" end
        local count = u32(count_bytes, 0)
        if count > 2048 then return nil, peer, "health count out of range" end
        local descriptors, records = ptr(hm + 0x1048), ptr(hm + 0x1058)
        if not descriptors or not records then return nil, peer, "health arrays unavailable" end
        local result = {manager=hm, records={}, count=count}
        if count == 0 then return result, peer end
        -- Bulk-read the two arrays once per poll, bounded below the 1 MiB buffer.
        local pointers = block(descriptors, count * 8)
        local data = block(records, count * 0x1B8)
        if not pointers or not data then return nil, peer, "health snapshot unreadable" end
        for index = 0, count - 1 do
            local descriptor = pointer_bytes(pointers, index * 8)
            local d = descriptor and rd(descriptor, 24)
            if not d then return nil, peer, "descriptor snapshot unreadable" end
            local unit, entity = u32(d, 12), u32(d, 8)
            local offset = index * 0x1B8
            if entity ~= 0 and entity ~= 0xFFFFFFFF and unit ~= 0xFFFFFFFF then
                local parts = {}
                for zone = 0, 37 do
                    local health = i32(data, offset + 0xF8 + zone * 4)
                    -- Keep signed values so sentinels cannot become huge HP.
                    parts[zone + 1] = health
                end
                result.records[unit] = {manager=hm, unit=unit, entity=entity, type=hex(d, 0),
                    descriptor=descriptor, network=u32(d, 16), hp=i32(data, offset + 0x14),
                    life=u32(data, offset + 0x19C), creditor=hex(data, offset + 0x38), parts=parts}
            end
        end
        -- If the manager resized or changed while sampling, discard the sample.
        if ptr(api.game + 0x3326688) ~= hm or rd(hm + 0x1020, 4) ~= count_bytes
            or ptr(hm + 0x1048) ~= descriptors or ptr(hm + 0x1058) ~= records then
            return nil, peer, "health snapshot changed during read"
        end
        return result, peer
    end
end
