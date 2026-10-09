-- Enemy HP HUD+ presentation. Native font, outlined numerals, slim health gauge.
-- Visual reference: HD2 HUD+ 0.1.13 by DDRK1NG
-- https://www.nexusmods.com/helldivers2/mods/15298
-- This module owns only its screen GUI; it does not read or write game memory.
return function(sr, font_ids, log)
    local Gui, World, App = sr.Gui, sr.World, sr.Application
    local V2, V3, Color, I = sr.Vector2, sr.Vector3, sr.Color, sr.IdString64
    local ui = { rects = {}, texts = {}, metrics = {} }
    local WHITE, MUTED, WARNING = {240, 240, 226}, {170, 176, 174}, {235, 140, 110}
    local function round(n) return math.floor(n + 0.5) end
    local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
    local function live(world)
        for _, w in ipairs(App.worlds()) do if w == world then return true end end
        return false
    end

    function ui:dispose()
        if self.gui and live(self.world) then
            if Gui.set_visible then pcall(Gui.set_visible, self.gui, false) end
            if World.destroy_gui then
                pcall(World.destroy_gui, self.world, self.gui)
            else
                for _, id in pairs(self.rects) do pcall(Gui.destroy_rect, self.gui, id) end
                for _, id in pairs(self.texts) do pcall(Gui.destroy_text, self.gui, id) end
            end
        end
        self.gui, self.world, self.font_key = nil, nil, nil
        self.font_hex, self.material_hex, self.first_draw_logged = nil, nil, nil
        self.rects, self.texts, self.metrics = {}, {}, {}
        self.key, self.visible = nil, false
    end

    function ui:hide()
        if self.gui and self.visible then
            if live(self.world) and Gui.set_visible then
                Gui.set_visible(self.gui, false)
            else
                self:dispose()
            end
        end
        self.visible, self.key = false, nil
    end

    function ui:ensure()
        local main, overlay = App.main_world(), nil
        for _, w in ipairs(App.worlds()) do if w ~= main then overlay = w break end end
        if self.gui and self.world ~= overlay then self:dispose() end
        if not overlay then return false end
        local fh, mh, ah = font_ids()
        if not fh or not mh or not ah then self:hide() return false end
        if not self.gui then
            self.gui = World.create_screen_gui(overlay, "scale", 1, 1)
            if not self.gui then return false end
            self.world = overlay
            -- New GUIs default to visible; track that before any drawing can fail.
            self.visible = true
        end
        local key = fh .. mh .. ah
        if self.font_key ~= key then
            -- IdString64 values live in the engine's temporary allocation pool.
            -- Retain only hex strings; resolve native IDs immediately at each
            -- call, just as the original renderer refreshed them on each draw.
            self.font_hex, self.material_hex = fh, mh
            local ink = assert(Gui.material(self.gui, I.from_hex(mh)), "Font material unavailable")
            local function slot(x) return I.from_hex(x .. "00000000") end
            -- Preserve Enemy HP's binding of the live game's font material/atlas.
            for _, x in ipairs({"8035c266", "5e8455fe", "309e7783", "82b803a8"}) do
                sr.Material.set_scalar(ink, slot(x), 0)
            end
            sr.Material.set_vector2(ink, slot("e13777ce"), V2(1, -1))
            sr.Material.set_vector4(ink, slot("7701209e"), Color(0, 0, 0, 0))
            sr.Material.set_texture(ink, slot("88bac99b"), I.from_hex(ah))
            self.font_key, self.metrics = key, {}
            if log then log("UI font bound: " .. fh .. " material " .. mh .. "; native IDs are not cached") end
        end
        return true
    end

    function ui:rect(key, x, y, w, h, layer, rgb, alpha)
        local at, size = V3(round(x), round(y), layer), V2(math.max(0, round(w)), math.max(0, round(h)))
        local tint = Color(round(alpha), rgb[1], rgb[2], rgb[3])
        local id = self.rects[key]
        if id then Gui.update_rect(self.gui, id, at, size, tint)
        else self.rects[key] = assert(Gui.rect(self.gui, at, size, tint)) end
    end

    function ui:measure(key, text, size)
        local m = self.metrics[key]
        if m and m.text == text and m.size == size then return m end
        m = {text = text, size = size, left = 0, width = #text * size * 0.6}
        -- Hidden labels have no width and need no native layout call.
        if text == "" then self.metrics[key] = m return m end
        local ok, lo, hi = pcall(Gui.text_extents, self.gui, text, I.from_hex(self.font_hex), size)
        if ok and lo and hi then
            -- HUD+ reads these Vector2 userdata through their native string form;
            -- Vector2.x is not a guaranteed API in the game's Lua bindings.
            local l = tonumber(string.match(tostring(lo), "^Vector2%(%s*([-%d%.]+)"))
            local r = tonumber(string.match(tostring(hi), "^Vector2%(%s*([-%d%.]+)"))
            if type(l) == "number" and type(r) == "number" and r >= l then
                m.left, m.width = l, r - l
            end
        end
        self.metrics[key] = m
        return m
    end

    function ui:text(key, value, size, x, y, rgb, alpha, outline)
        local m = self:measure(key, value, size)
        if value == "" then value, alpha = " ", 0 end
        x = x - m.left
        local steps = {{outline, 0}, {-outline, 0}, {0, outline}, {0, -outline}, {0, 0}}
        for index, delta in ipairs(steps) do
            local front = index == 5
            local c = front and rgb or {20, 23, 24}
            local tint = Color(round(front and alpha or alpha * 0.85), c[1], c[2], c[3])
            local at = V3(round(x + delta[1]), round(y + delta[2]), front and 954 or 953)
            local slot = key .. index
            local id = self.texts[slot]
            if id then Gui.update_text(self.gui, id, value, I.from_hex(self.font_hex), size,
                                       I.from_hex(self.material_hex), at, tint)
            else self.texts[slot] = assert(Gui.text(self.gui, value, I.from_hex(self.font_hex), size,
                                                   I.from_hex(self.material_hex), at, tint)) end
        end
    end

    function ui:draw(model, sx, sy, now, options)
        if not self:ensure() then return false end
        local sw, sh = Gui.resolution()
        if not sw or not sh or sw <= 0 or sh <= 0 then self:hide() return false end
        local scale = math.min(sw / 1920, sh / 1080) * (options.scale or 1)
        local edge = math.max(1, round(scale))
        local hp, maximum = math.max(0, model.hp or 0), math.max(0, model.max or 0)
        local ratio = maximum > 0 and clamp(hp / maximum, 0, 1) or 0
        local key = model.key
        if self.key ~= key then
            self.key, self.born, self.trail, self.last_ratio = key, now, ratio, ratio
            self.last_time, self.hold_until = now, now
        end
        local dt = clamp(now - self.last_time, 0, 0.1)
        self.last_time = now
        if ratio < self.last_ratio then self.hold_until = now + 0.16 end
        if ratio >= self.trail then self.trail = ratio
        elseif now > self.hold_until then self.trail = math.max(ratio, self.trail - dt * 0.8) end
        self.last_ratio = ratio
        local alpha = 230 * clamp((options.opacity or 100) / 100, 0, 1)
            * clamp((now - self.born) / 0.12, 0, 1)
        if model.dead_t then alpha = alpha * clamp((1.5 - (now - model.dead_t)) / 0.45, 0, 1) end
        local current = model.dead_t and "ELIMINATED" or string.format("%.0f", hp)
        local maximum_text = model.dead_t and "" or (" / " .. string.format("%.0f", maximum))
        local percent = model.dead_t and "" or (tostring(round(ratio * 100)) .. "%")
        local current_size = (model.dead_t and 14 or 20) * scale
        local small_size = 14 * scale
        local cw = self:measure("current", current, current_size).width
        local mw = self:measure("maximum", maximum_text, small_size).width
        local pw = self:measure("percent", percent, small_size).width
        local name = options.show_name and model.name or ""
        local nw = self:measure("name", name, small_size).width
        -- Use total maximum HP so an eligible enemy keeps its part HUD as it weakens.
        local rows, part_size = {}, 13 * scale
        local width = math.max((options.width or 172) * scale, cw + mw + pw + 20 * scale, nw)
        local parts = maximum >= 775 and not model.dead_t and (model.parts or (model.part and {model.part})) or {}
        for _, part in ipairs(parts) do
            if (not part.until_t or now <= part.until_t) and #rows < 3 then
                local index = #rows + 1
                local prefix = index == 1 and "part_" or ("part" .. index .. "_")
                local label = part.label
                if part.fatal then label = label .. " [FATAL]"
                elseif part.downed then label = label .. " [DOWN]" end
                local part_max = not part.shared and type(part.max) == "number"
                    and part.max > 0 and part.hp >= 0 and part.hp <= part.max and part.max or nil
                local part_ratio = part_max and clamp(part.hp / part_max, 0, 1) or nil
                local value = string.format("%.0f HP", math.max(0, part.hp))
                if part_ratio then
                    value = string.format("%.0f / %.0f  %d%%", part.hp, part_max, round(part_ratio * 100))
                elseif part.shared then value = value .. " (SHARED)" end
                local label_width = self:measure(prefix .. "label", label, part_size).width
                local value_width = self:measure(prefix .. "value", value, part_size).width
                width = math.max(width, label_width + value_width + 20 * scale)
                rows[index] = {label=label, value=value, value_width=value_width, ratio=part_ratio, hp=part.hp}
            end
        end
        width = round(width)
        local x = round(clamp((sx or sw / 2) - width / 2, 12 * scale, sw - width - 12 * scale))
        local bottom = #rows > 0 and (60 + (#rows - 1) * 38) or 16
        local y = round(clamp((sy or sh * 0.4) + (options.offset or -40), bottom * scale,
                             sh - (name ~= "" and 44 or 24) * scale))
        local fill = (ratio <= 0.25 or model.dead_t) and WARNING or WHITE
        local ping = model.colour or {255, 240, 240, 226}
        local accent = {ping[2], ping[3], ping[4]}
        local by, bh = y - round(12 * scale), math.max(3, round(7 * scale))
        local inner_w, inner_h = math.max(0, width - 2 * edge), math.max(1, bh - 2 * edge)
        -- Small class accent; typography stays neutral like HUD+.
        self:rect("accent", x - 5 * scale, by, 2 * scale, bh, 951, accent, alpha)
        self:rect("outline", x, by, width, bh, 950, {15, 18, 20}, alpha)
        self:rect("track", x + edge, by + edge, inner_w, inner_h, 951, {90, 96, 94}, alpha * 0.6)
        self:rect("trail", x + edge, by + edge, inner_w * self.trail, inner_h, 952, WARNING, alpha * 0.6)
        self:rect("fill", x + edge, by + edge, inner_w * ratio, inner_h, 953, fill, alpha)
        self:text("current", current, current_size, x, y, fill, alpha, edge)
        self:text("maximum", maximum_text, small_size, x + cw + 4 * scale, y, MUTED, alpha, edge)
        self:text("percent", percent, small_size, x + width - pw, y, MUTED, alpha, edge)
        for index = 1, 3 do
            local row = rows[index]
            local prefix = index == 1 and "part_" or ("part" .. index .. "_")
            if row or self.texts[prefix .. "label1"] then
                local part_alpha = row and alpha or 0
                local part_colour = row and row.hp == 0 and WARNING or {230, 192, 119}
                local dy = (index - 1) * 38 * scale
                self:text(prefix .. "label", row and row.label or "", part_size, x, y - 34 * scale - dy,
                    part_colour, part_alpha, edge)
                self:text(prefix .. "value", row and row.value or "", part_size,
                    x + width - (row and row.value_width or 0), y - 34 * scale - dy, part_colour, part_alpha, edge)
                local bar_alpha = row and row.ratio and part_alpha or 0
                local py, ph = y - round(48 * scale) - dy, math.max(5, round(9 * scale))
                local part_width, part_height = math.max(0, width - 2 * edge), math.max(1, ph - 2 * edge)
                self:rect(prefix .. "outline", x, py, width, ph, 950, {133, 118, 83}, bar_alpha)
                self:rect(prefix .. "track", x + edge, py + edge, part_width, part_height,
                    951, {67, 67, 60}, bar_alpha)
                self:rect(prefix .. "fill", x + edge, py + edge, part_width * (row and row.ratio or 0), part_height,
                    952, {240, 190, 80}, bar_alpha)
            end
        end
        if name ~= "" or self.texts.name1 then
            self:text("name", name, small_size, x, y + 24 * scale, WHITE, alpha, edge)
        end
        if not self.visible and Gui.set_visible then Gui.set_visible(self.gui, true) end
        self.visible = true
        if not self.first_draw_logged then
            if log then log("UI first draw submitted successfully") end
            self.first_draw_logged = true
        end
        return true
    end
    return ui
end
