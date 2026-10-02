return function(make, E)
    local ui = make(E.sr, E.font_ids)
    local options = {offset=-40, scale=1, width=172}
    local model = {key="a", hp=6500, max=6500, name="Bile Titan", colour={255,235,60,50}}
    local function draw(t) E.next_frame(); assert(ui:draw(model,960,540,t,options)) end
    local function rect(key) return ui.gui.parts[ui.rects[key]] end
    local function text(key) return ui.gui.parts[ui.texts[key..5]] end
    local function close(a,b) assert(math.abs(a-b) < 1.1, tostring(a).." ~= "..tostring(b)) end
    draw(0); draw(0.2)
    assert(text("current").text == "6500" and text("percent").text == "100%")
    assert(rect("fill").tint.r == 240 and rect("fill").tint.b == 226)
    close(rect("fill").size.x,rect("track").size.x)
    local ids = E.next_id
    for i=1,120 do draw(0.2+i/60) end
    assert(E.next_id == ids and E.binds == 1, "retained parts/materials should be reused")
    model.hp=2073; draw(2.3)
    assert(text("percent").text == "32%")
    close(rect("fill").size.x,rect("track").size.x*2073/6500)
    assert(rect("trail").size.x > rect("fill").size.x)
    for i=1,120 do draw(2.3+i/60) end
    close(rect("trail").size.x,rect("fill").size.x)
    model.hp=900; draw(4.4)
    assert(text("current").tint.r == 235 and text("current").tint.g == 140)
    model.key="b"; draw(4.5)
    close(rect("trail").size.x,rect("fill").size.x)
    model.hp=6500; draw(4.7)
    close(rect("trail").size.x,rect("fill").size.x)
    model.hp=9999999; model.max=9999999; draw(4.8)
    local max_right=text("maximum").at.x + #text("maximum").text*text("maximum").size*0.58
    assert(max_right < text("percent").at.x, "large values overlap percentage")
    for _, wh in ipairs({{1280,720},{1920,1080},{2560,1440},{3440,1440},{3840,2160}}) do
        E.width,E.height=wh[1],wh[2]
        model.hp=2073; model.max=6500
        for _, factor in ipairs({0.5,1,2}) do
            options.scale=factor
            for _, point in ipairs({{0,0},{wh[1],wh[2]}}) do
                assert(ui:draw(model,point[1],point[2],5,options))
                local bar=rect("outline")
                assert(bar.at.x >= 0 and bar.at.y >= 0)
                assert(bar.at.x+bar.size.x <= E.width and bar.at.y+bar.size.y <= E.height)
                assert(text("percent").at.y + text("percent").size <= E.height)
            end
        end
    end
    E.width,E.height=1920,1080; options.scale=1
    model.max=0; model.hp=0; draw(5.1)
    assert(rect("fill").size.x == 0 and text("percent").text == "0%")
    model.max=6500; model.hp=900; model.dead_t=6
    draw(6); draw(7.3)
    assert(text("current").text == "ELIMINATED" and text("current").tint.a < 230)
    assert(text("maximum").tint.a == 0 and text("percent").tint.a == 0)
    ui:hide(); assert(not ui.gui.visible)
    local hidden_ids = E.next_id
    ui:hide(); assert(E.next_id == hidden_ids)
    model.dead_t=nil; draw(8); draw(8.2); assert(ui.gui.visible)
    options.show_name=true; draw(8.3); assert(text("name").text == "Bile Titan")
    options.show_name=false; draw(8.4); assert(text("name").tint.a == 0)
    E.atlas="new-atlas"; draw(8.5); assert(E.binds == 2)
    E.metrics_fail=true; model.hp=500; draw(8.6); E.metrics_fail=false
    E.no_font=true; assert(not ui:draw(model,960,540,8.7,options)); assert(not ui.gui.visible)
    E.no_font=false; draw(8.8)
    E.worlds={"main","new-overlay"}; draw(9)
    assert(E.created == 2 and ui.world == "new-overlay", "must recreate after world change")
    -- Old world is already dead: the fake rejects any native API call against it.
    E.worlds={"main"}; assert(not ui:draw(model,960,540,9.1,options)); assert(ui.gui == nil)
    E.worlds={"main","overlay"}; E.create_fail=true
    assert(not ui:draw(model,960,540,9.2,options)); E.create_fail=false
    draw(9.3); ui:dispose(); assert(E.destroyed == 1 and ui.gui == nil)
    ui:dispose(); assert(E.destroyed == 1)
    return "PASS: temporary native ID recycling between frames, layout, retained handles, damage trail, target changes, 5 resolutions x 3 scales, death fade, visibility, font refresh, GUI recreation/disposal"
end
