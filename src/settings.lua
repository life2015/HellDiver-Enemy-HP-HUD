-- Mod Options Menu owns the native UI, APPLY semantics and persistence.
-- Stable IDs must survive package/version changes. CFG remains the fallback.
return function(globals, initial, changed, log)
    local S = {values={auto_damage=initial.auto_damage, auto_min_hp=initial.auto_min_hp,
                       part_hud=initial.part_hud, multi_parts=initial.multi_parts == true, scale=initial.scale or 1,
                       opacity=initial.opacity or 100}, registered={}}
    local thresholds = {0, 500, 1000}
    -- MOM observes the game's Text Language before refreshing text callbacks
    -- on each menu opening. Read that shared observation, not Steam/OS language
    -- or a translation-pack override. Unknown/non-Chinese languages use English.
    local function translated(zh, en)
        return function()
            local registry = rawget(globals, "BingusTranslations")
            local language = type(registry) == "table" and registry.game_language
            if type(language) == "string" then
                language = language:lower():gsub("_", "-")
                if language == "zh" or language:match("^zh%-") then return zh end
            end
            return en
        end
    end
    local specs = {
        {key="auto_damage", type="toggle", default=true,
         label=translated("造成伤害自动显示血条", "Auto HP on damage"),
         description=translated("造成伤害后自动显示敌人血条；关闭不影响手动标记。",
             "Show enemy HP after dealing damage. Manual pings remain available when disabled.")},
        {key="auto_min_hp", type="choice", default=1,
         label=translated("自动显示血条阈值", "Auto HP threshold"),
         choices={translated("全部", "All"), translated("中型单位 (HP 500+)", "Medium (HP 500+)"),
                  translated("重型单位 (HP 1000+)", "Heavy (HP 1000+)")},
         description=translated("按最大总血量筛选自动显示，残血仍符合条件。手动标记不受限制。",
             "Filter automatic display by maximum total HP, not current HP. Manual pings bypass this filter.")},
        {key="part_hud", type="toggle", default=true,
         label=translated("大型单位显示部位血量", "Large enemy part HP"),
         description=translated("最大总血量至少 775 时显示受伤部位血量。已知上限时显示部位条。",
             "Show damaged part HP for enemies with max HP >= 775. Show bars when part maxima are known.")},
        {key="multi_parts", type="toggle", default=initial.multi_parts == true,
         label=translated("显示多个部位血条", "Show multiple part bars"),
         description=translated("默认关闭，只显示最近受伤的一个部位。开启后最多保留三个部位，致死部位优先，其次按最近受伤时间排列。需开启部位血量显示。",
             "Off by default: show only the most recently damaged part. When enabled, retain up to three parts, fatal first then newest hit. Requires part HP display.")},
        {key="scale", type="slider", min=0.5, max=2, step=0.05, default=initial.scale or 1, gap=true,
         label=translated("HUD 缩放", "HUD Scale"),
         description=translated("整体缩放主血条、部位血条和文字。1.00 为原始大小。",
             "Scale the main health bar, part bars and text together. 1.00 is the original size.")},
        {key="opacity", type="slider", min=0, max=100, step=5, default=initial.opacity or 100,
         label=translated("HUD 不透明度 (%)", "HUD Opacity (%)"),
         description=translated("整体调整血条、文字和描边的不透明度。0% 完全透明，100% 保持原有显示强度。",
             "Adjust opacity of all bars, text and outlines. 0% is invisible; 100% keeps the original appearance.")},
    }
    local function apply(spec, value)
        if S.stopped then return end
        if spec.type == "toggle" then
            if type(value) ~= "boolean" then return end
        elseif spec.type == "choice" then
            if type(value) ~= "number" or not thresholds[value] then return end
            value = thresholds[value]
        else
            if type(value) ~= "number" or value ~= value or value < spec.min or value > spec.max then return end
        end
        if S.values[spec.key] ~= value then
            S.values[spec.key] = value
            changed(S.values)
        end
    end
    function S:step()
        if self.stopped then return end
        local menu = rawget(globals, "ModOptionsMenu")
        if not self.menu then
            if type(menu) ~= "table" or menu.api ~= 1 or type(menu.register_option) ~= "function"
                or type(menu.get) ~= "function" or type(menu.on_change) ~= "function" then return end
            self.menu = menu
            for _, spec in ipairs(specs) do
                local current = spec
                local id = "retrox.enemy_hp_hud." .. current.key
                local descriptor = {mod="Enemy HP HUD+", mod_id="retrox.enemy_hp_hud"}
                for k, v in pairs(current) do if k ~= "key" then descriptor[k] = v end end
                -- Pre-v1.1 menus accept strings only; current required v1.2
                -- accepts callbacks and refreshes without re-registering options.
                if (tonumber(menu.version) or 1) < 2 then
                    descriptor.label, descriptor.description = current.label(), current.description()
                    if current.choices then
                        descriptor.choices = {}
                        for i, choice in ipairs(current.choices) do descriptor.choices[i] = choice() end
                    end
                end
                local ok, why = pcall(function()
                    local accepted, reason = menu.register_option(id, descriptor)
                    if not accepted then error(reason or "registration refused") end
                    local subscribed, reason2 = menu.on_change(id, function(value) apply(current, value) end)
                    if not subscribed then error(reason2 or "subscription refused") end
                    self.registered[#self.registered + 1] = {id=id, spec=current}
                end)
                if not ok and log then log("Mod Options: " .. id .. ": " .. tostring(why)) end
            end
            if log then log("Mod Options: " .. #self.registered .. " options registered; use APPLY to save") end
        end
        -- get() restores saved values, and also observes programmatic set(),
        -- which deliberately does not call on_change. Never write menu values.
        for _, option in ipairs(self.registered) do
            local ok, value = pcall(self.menu.get, option.id)
            if ok then apply(option.spec, value) end
        end
    end
    function S:shutdown() self.stopped = true end
    return S
end
