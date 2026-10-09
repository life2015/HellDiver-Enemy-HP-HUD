return function(make_projection)
    local epoch,world=0,'A'
    local mt={}
    local function vector(x,y,z) return setmetatable({x=x,y=y,z=z,epoch=epoch},mt) end
    local function alive(v) assert(v.epoch==epoch,'expired native value');return v end
    mt.__sub=function(a,b)alive(a);alive(b);return vector(a.x-b.x,a.y-b.y,a.z-b.z)end
    local V=setmetatable({x=function(v)return alive(v).x end,y=function(v)return alive(v).y end,
        dot=function(a,b)alive(a);alive(b);return a.x*b.x+a.y*b.y+a.z*b.z end},
        {__call=function(_,...)return vector(...)end})
    local views={A={0,0,0},B={100,0,0}}
    local poses={player={0,0,0,0,1,0},map={0,0,501,0,0,-1},wrong={0,0,0,0,-1,0},
        second={100,0,0,0,1,0},near={1,0,0,0,1,0}}
    local list={'map','player'}
    local roots={[1]={10,50,2},[2]={-10,50,2}}
    local sw,sh=1920,1080
    local selected,viewport,calls,reason
    local missing,error_project,invalid,offscreen,change_during_project=false,false,false,false,false
    local sr={Vector3=V,Vector2=function(x,y)return {x=x,y=y}end,
        Application={main_world=function()return world end},Gui={resolution=function()return sw,sh end},
        Matrix4x4={translation=function(p)return p.at end,forward=function(p)return p.fwd end},
        World={units_by_resource=function()return list end,debug_camera_pose=function()
            local p=views[world];return {at=vector(p[1],p[2],p[3]),fwd=vector(0,1,0)}end},
        Unit={camera=function(unit,index)assert(index==1);if unit=='broken' then error('stale camera')end
            return {unit=unit,epoch=epoch,world=world}end},Camera={}}
    function sr.Camera.world_pose(c)
        assert(c.epoch==epoch and c.world==world)
        local p=poses[c.unit];return {at=vector(p[1],p[2],p[3]),fwd=vector(p[4],p[5],p[6])}
    end
    function sr.Camera.world_to_screen(c,p,unused,vp)
        assert(c.epoch==epoch and c.world==world,'cached camera');assert(unused==nil)
        selected,viewport,calls=c.unit,vp,(calls or 0)+1
        if error_project then error('camera destroyed during projection')end
        if change_during_project then world='B' end
        if invalid then return vector(0/0,100,0) end
        if offscreen then return vector(sw+1,100,0) end
        return vector(vp.x/2+p.x,vp.y/2+p.z,0),0.000001
    end
    local project=make_projection(sr,function(unit)
        if missing then return nil end
        return unpack(roots[unit])
    end,function(_,status) reason=status end)
    local a={world='A',unit=1,off={0,0,1}}
    local b={world='A',unit=2,off={0,0,1}}
    local time=0
    local function step(target)
        epoch=epoch+1;time=time+0.01;return project(time,target or a)
    end
    -- First camera is unrelated. Every order must select the actual player view.
    for _,order in ipairs({{'map','player'},{'player','map'},{'broken','wrong','map','player'},
                           {'near','player','map'},{'map','near','player'}}) do
        list=order;local x,y=step();assert(x==970 and y==543 and selected=='player' and reason=='ready')
    end
    local ax=step(a);local bx=project(time,b);assert(ax==970 and bx==950,'independent target positions')
    -- No five-second window: a new world selects a fresh camera immediately.
    world='B';a.world='B';list={'map','second'}
    step();assert(selected=='second' and reason=='ready')
    assert(step(b)==nil and reason=='world_changed')
    -- Same world can replace/reorder camera units during a long mission.
    views.B={0,0,0};list={'wrong','player','map'}
    step();assert(selected=='player')
    list={'map','wrong'};assert(step()==nil and reason=='no_matching_camera')
    list={'broken','player'};assert(step()~=nil and reason=='ready','recover without reload')
    -- Zoom camera within the bounded match tolerance and explicit viewport.
    list={'near'};sw,sh=3440,1440
    assert(step()==1730 and selected=='near' and viewport.x==3440 and viewport.y==1440)
    -- The returned tiny reverse-Z depth is valid; world forward distance controls visibility.
    roots[1]={10,-50,2};local before=calls
    assert(step()==nil and reason=='behind_camera' and calls==before)
    roots[1]={10,50,2}
    missing=true;assert(step()==nil and reason=='position_unavailable');missing=false
    roots[1]={math.huge,50,2};assert(step()==nil and reason=='position_unavailable');roots[1]={10,50,2}
    invalid=true;assert(step()==nil and reason=='invalid_projection');invalid=false
    offscreen=true;assert(step()==nil and reason=='off_screen');offscreen=false
    error_project=true;assert(step()==nil and reason=='projection_error');error_project=false
    assert(step()~=nil and reason=='ready')
    sw=0;assert(step()==nil and reason=='invalid_viewport');sw=1920
    list={};for i=1,65 do list[i]='player' end
    assert(step()==nil and reason=='camera_list_unavailable')
    list={'player'};world='A';a.world='A';change_during_project=true
    assert(step()==nil and reason=='world_changed')
    return 'PASS: real projection module; camera orders, competing/stale cameras, immediate world/camera changes, temporary handle lifetimes, recovery, dual targets, viewport, reverse-Z, invalid/offscreen/behind positions'
end
