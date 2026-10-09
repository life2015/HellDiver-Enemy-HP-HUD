return function(make, fresh)
    local prefix='retrox.enemy_hp_hud.'
    local initial={auto_damage=true,auto_min_hp=0,part_hud=true,multi_parts=false,scale=1,opacity=100}
    local current,globals,logs={}, {}, {}
    local function changed(v) for k,x in pairs(v) do current[k]=x end end
    changed(initial)
    local S=make(globals,initial,changed,function(s) logs[#logs+1]=s end)
    S:step();globals.ModOptionsMenu={api=2};S:step()
    globals.ModOptionsMenu={api=1};S:step();assert(not S.menu)
    local menu,state,mom,saved=fresh('other.mod.option\t7\n')
    globals.ModOptionsMenu=menu;S:step()
    assert(#state.mods==1 and state.mods[1].id=='retrox.enemy_hp_hud' and state.option_count==6, table.concat(logs,'\n'))
    assert(current.auto_damage and current.part_hud and current.auto_min_hp==0)
    assert(menu.get(prefix..'auto_damage')==true and menu.get(prefix..'part_hud')==true)
    assert(menu.get(prefix..'auto_min_hp')==1)
    assert(menu.get(prefix..'multi_parts')==false and current.multi_parts==false, 'new option defaults off for existing users')
    assert(menu.get(prefix..'scale')==1 and menu.get(prefix..'opacity')==100)
    assert(state.options[prefix..'part_hud'].label=='Large enemy part HP')
    local function language(tag)
        globals.BingusTranslations={game_language=tag,steam_language='zh-Hans',override='zh-Hans'}
        mom.translation.refresh()
    end
    for _,tag in ipairs({'zh','zh-Hans','zh-Hant','zh-CN','zh-TW','ZH_hans'}) do
        language(tag)
        assert(state.options[prefix..'auto_damage'].label=='造成伤害自动显示血条')
        assert(state.options[prefix..'part_hud'].label=='大型单位显示部位血量')
        assert(state.options[prefix..'multi_parts'].label=='显示多个部位血条')
        assert(state.options[prefix..'scale'].label=='HUD 缩放'
            and state.options[prefix..'opacity'].label=='HUD 不透明度 (%)')
        assert(state.options[prefix..'auto_min_hp'].choices[1]=='全部')
        assert(state.options[prefix..'auto_min_hp'].choices[2]=='中型单位 (HP 500+)')
        assert(state.options[prefix..'part_hud'].description:find('最大总血量',1,true))
    end
    for _,tag in ipairs({'en','fr','ja','ko','ru','unknown',''}) do
        language(tag)
        assert(state.options[prefix..'auto_damage'].label=='Auto HP on damage')
        assert(state.options[prefix..'part_hud'].label=='Large enemy part HP')
        assert(state.options[prefix..'multi_parts'].label=='Show multiple part bars')
        assert(state.options[prefix..'scale'].label=='HUD Scale'
            and state.options[prefix..'opacity'].label=='HUD Opacity (%)')
        assert(state.options[prefix..'auto_min_hp'].choices[3]=='HEAVY (HP 1000+)')
        assert(state.options[prefix..'part_hud'].description:find('Show damaged part HP',1,true))
    end
    language(nil)
    assert(state.option_count==6 and #state.mods==1 and menu.get(prefix..'part_hud')==true,
        'language changes must not re-register, disable, or reset settings')
    for i=1,20 do S:step() end
    for _,callbacks in pairs(state.callbacks) do assert(#callbacks==1) end
    mom.set_pending(prefix..'auto_damage',false)
    mom.set_pending(prefix..'auto_min_hp',3)
    mom.set_pending(prefix..'part_hud',false)
    mom.set_pending(prefix..'multi_parts',true)
    mom.set_pending(prefix..'scale',1.5);mom.set_pending(prefix..'opacity',40)
    S:step();assert(current.auto_damage and current.part_hud and current.auto_min_hp==0,
        'pending edits must not affect gameplay')
    assert(current.scale==1 and current.opacity==100 and current.multi_parts==false)
    mom.drop_pending();S:step();assert(current.auto_damage and current.auto_min_hp==0)
    mom.set_pending(prefix..'auto_damage',false)
    mom.set_pending(prefix..'auto_min_hp',3)
    mom.set_pending(prefix..'part_hud',false)
    mom.set_pending(prefix..'multi_parts',true)
    mom.set_pending(prefix..'scale',1.5);mom.set_pending(prefix..'opacity',40)
    mom.apply_pending()
    assert(not current.auto_damage and not current.part_hud and current.auto_min_hp==1000)
    assert(current.scale==1.5 and current.opacity==40 and current.multi_parts==true)
    assert(saved():find('other.mod.option\t7\n',1,true), 'other mods saved values must be preserved')
    local restored={}
    local menu2,state2,mom2=fresh(saved())
    local S2=make({ModOptionsMenu=menu2},initial,function(v) for k,x in pairs(v) do restored[k]=x end end)
    S2:step();assert(restored.auto_damage==false and restored.part_hud==false and restored.auto_min_hp==1000)
    assert(restored.scale==1.5 and restored.opacity==40 and restored.multi_parts==true, 'sliders must survive restarting')
    assert(menu2.set(prefix..'opacity',0));S2:step();assert(restored.opacity==0, 'zero opacity is valid')
    assert(menu2.set(prefix..'scale',0.5));S2:step();assert(restored.scale==0.5)
    assert(menu2.set(prefix..'scale',2));S2:step();assert(restored.scale==2)
    assert(not menu2.set(prefix..'opacity',0/0) and not menu2.set(prefix..'scale',math.huge))
    assert(menu2.set(prefix..'auto_min_hp',2));S2:step();assert(restored.auto_min_hp==500)
    assert(not menu2.set(prefix..'auto_min_hp',4) and not menu2.set(prefix..'auto_min_hp',1.5))
    assert(not menu2.set(prefix..'part_hud',1))
    S2:shutdown();mom2.set_pending(prefix..'part_hud',true);mom2.apply_pending();S2:step()
    assert(restored.part_hud==false, 'shutdown stops callbacks and polling')
    local count=0
    local rejected={api=1,register_option=function() count=count+1;return false,'full' end,
        on_change=function() error('must not subscribe') end,get=function() error('must not read') end}
    local failed=make({ModOptionsMenu=rejected},initial,function() error('must retain fallback') end)
    failed:step();failed:step();assert(count==6 and #failed.registered==0)
    local menu3= fresh(prefix..'auto_damage\tgarbage\n'..prefix..'auto_min_hp\t99\n')
    local invalid=make({ModOptionsMenu=menu3},initial,function() error('defaults must survive corrupt saves') end)
    invalid:step()
    return 'PASS: game Text Language Chinese/English callbacks, fallback and live refresh without setting resets; six menu defaults, actual upstream API registration, UTF-8 limits, APPLY/discard, persistence, late load, one subscription, 0/500/1000 mapping, invalid values and shutdown'
end
