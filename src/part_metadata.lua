-- Read-only HealthComponentData metadata for build 25480438.
-- Resolve by native entity type + zone index, never infer max HP from a hit.
-- Instance-specific settings are intentionally unsupported: fail closed rather
-- than presenting a shared class maximum for a potentially modified instance.
return function(api)
    local rd, ptr, block = api.read, api.pointer, api.block
    local u32, i32, hex = api.u32, api.i32, api.hex64
    local function identity(row, bytes)
        return bytes and hex(bytes, 0) == row.type and u32(bytes, 8) == row.entity
            and u32(bytes, 12) == row.unit and u32(bytes, 16) == row.network
    end
    return function(row, index)
        if not row or type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 38 then return nil end
        local hm = ptr(api.game + 0x3326688)
        if not hm or (row.manager and row.manager ~= hm) then return nil end
        local copies = rd(hm + 0x10A8, 4)
        if not copies or u32(copies, 0) ~= 0 then return nil end
        local descriptor = row.descriptor and rd(row.descriptor, 24)
        if not identity(row, descriptor) then return nil end
        local net = ptr(api.game + 0x346BF98)
        local root = net and ptr(net + 0xF12B78)
        if not root then return nil end
        local table_bytes = block(root, 1002 * 16)
        if not table_bytes or #table_bytes ~= 1002 * 16 then return nil end
        local slot, settings_index
        for i = 0, 1001 do
            if hex(table_bytes, i * 16) == row.type then
                if slot then return nil end -- ambiguous/corrupt type lookup
                slot, settings_index = i, u32(table_bytes, i * 16 + 8)
            end
        end
        if not slot or settings_index >= 1002 then return nil end
        local address = root + 0x3EA0 + settings_index * 0x5650 + 0x208 + (index - 1) * 0x228
        local bytes = rd(address, 256)
        if not bytes or #bytes ~= 256 then return nil end
        local maximum = i32(bytes, 232)
        local down, fatal = bytes:byte(244), bytes:byte(245)
        if maximum < -1 or maximum > 10000000 or down > 1 or fatal > 1 then return nil end
        -- Check roots, descriptor, copy count and the matched settings slot again.
        if ptr(api.game + 0x3326688) ~= hm or rd(hm + 0x10A8, 4) ~= copies
            or ptr(api.game + 0x346BF98) ~= net or ptr(net + 0xF12B78) ~= root
            or rd(row.descriptor, 24) ~= descriptor
            or rd(root + slot * 16, 16) ~= table_bytes:sub(slot * 16 + 1, slot * 16 + 16)
            or rd(address, 256) ~= bytes then return nil end
        local name = api.names[u32(bytes, 96)]
        return {label=name, max=maximum > 0 and maximum or nil,
            shared=maximum == -1, fatal=fatal == 1, downed=down == 1}
    end
end
