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
    model.part={label="FRONT LEFT THRUSTER",hp=1000000,max=10000000,fatal=true}
    model.max=775; model.hp=100; draw(4.9)
    assert(text("part_label").tint.a>0 and rect("part_track").tint.a>0,
        "775 maximum HP is eligible even when current HP is below 775")
    model.max=774; draw(4.95)
    assert(text("part_label").tint.a==0 and text("part_value").tint.a==0
        and rect("part_outline").tint.a==0 and rect("part_track").tint.a==0
        and rect("part_fill").tint.a==0 and text("current").tint.a>0,
        "below 775 maximum HP clears every retained part element but keeps main HP")
    model.max=776; draw(4.99)
    assert(text("part_label").tint.a>0 and rect("part_track").tint.a>0,
        "part HUD returns when switching back to an eligible enemy")
    model.parts={model.part,{label='REAR LEFT LEG',hp=300,max=500},
        {label='REAR RIGHT LEG',hp=200,max=400}}
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
                assert(text("part_label").at.y - text("part_label").size*0.2 >= 0)
                assert(rect("part_track").at.y>=0 and rect("part_track").at.x+rect("part_track").size.x<=E.width)
                close(rect("part_fill").size.x,rect("part_track").size.x*0.1)
                assert(text("part_value").at.x + #text("part_value").text*text("part_value").size*0.58 <= E.width)
                assert(text("part_label").at.x + #text("part_label").text*text("part_label").size*0.58 < text("part_value").at.x)
                for _,prefix in ipairs({'part2_','part3_'}) do
                    local track=rect(prefix..'track')
                    assert(track.at.y>=0 and track.at.x+track.size.x<=E.width)
                    assert(text(prefix..'label').at.x + #text(prefix..'label').text*text(prefix..'label').size*0.58 < text(prefix..'value').at.x)
                end
                assert(rect('part_track').at.y>text('part2_label').at.y+text('part2_label').size)
                assert(rect('part2_track').at.y>text('part3_label').at.y+text('part3_label').size)
            end
        end
    end
    E.width,E.height=1920,1080; options.scale=1
    draw(5)
    local alphas={}
    for id,p in pairs(ui.gui.parts) do alphas[id]=p.tint.a end
    options.opacity=50;draw(5.001)
    for id,p in pairs(ui.gui.parts) do close(p.tint.a,alphas[id]*0.5) end
    options.opacity=0;draw(5.002)
    for _,p in pairs(ui.gui.parts) do assert(p.tint.a==0, 'zero opacity hides bars, text and outlines') end
    options.opacity=100;draw(5.003)
    for id,p in pairs(ui.gui.parts) do close(p.tint.a,alphas[id]) end
    model.parts[1].until_t=5.01; draw(5.02)
    assert(text('part_label').text=='REAR LEFT LEG' and text('part3_label').tint.a==0,
        'expiration is filtered between health polls, compacting rows and hiding the third slot')
    model.parts[1].until_t=nil
    model.max=0; model.hp=0; draw(5.1)
    assert(rect("fill").size.x == 0 and text("percent").text == "0%")
    model.max=6500; model.hp=900; model.dead_t=6
    draw(6); draw(7.3)
    local death_alpha=text('current').tint.a
    options.opacity=50;draw(7.3);close(text('current').tint.a,death_alpha*0.5)
    options.opacity=100;draw(7.3)
    assert(text("current").text == "ELIMINATED" and text("current").tint.a < 230)
    assert(text("maximum").tint.a == 0 and text("percent").tint.a == 0)
    assert(text("part_value").tint.a == 0 and text("part_label").tint.a == 0)
    assert(text('part2_label').tint.a==0 and text('part3_label').tint.a==0
        and rect('part2_fill').tint.a==0 and rect('part3_fill').tint.a==0)
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
    return "PASS: temporary native ID recycling between frames, layout, retained handles, damage trail, target changes, main/part layout at 5 resolutions x 3 scales, death fade, visibility, font refresh, GUI recreation/disposal"
end
