-- Match the current view every call. Engine camera/vector handles never survive
-- a frame or world transition. Based on the inspected Sentry HUD camera path.
return function(sr, unit_position, report)
    local function finite(n) return type(n) == 'number' and n == n and math.abs(n) < 1e8 end
    local function project(subject)
        local world = sr.Application.main_world()
        if not world or not subject or subject.world ~= world then return nil, nil, 'world_changed' end
        local off = subject.off
        if not off or not finite(off[1]) or not finite(off[2]) or not finite(off[3]) then
            return nil, nil, 'invalid_offset'
        end
        local x,y,z = unit_position(subject.unit)
        if not finite(x) or not finite(y) or not finite(z) then return nil, nil, 'position_unavailable' end
        local sw,sh = sr.Gui.resolution()
        if not finite(sw) or not finite(sh) or sw <= 0 or sh <= 0 then return nil, nil, 'invalid_viewport' end
        local V,Mat,C = sr.Vector3,sr.Matrix4x4,sr.Camera
        local view = sr.World.debug_camera_pose(world)
        local at,fwd = Mat.translation(view),Mat.forward(view)
        local cameras = sr.World.units_by_resource(world, 'core/units/camera')
        if type(cameras) ~= 'table' or #cameras > 64 then return nil, nil, 'camera_list_unavailable' end
        local best,origin,forward,score
        for _,unit in ipairs(cameras) do
            local ok,cam,pos,dir,d2,alignment = pcall(function()
                local candidate = sr.Unit.camera(unit,1)
                if not candidate then return end
                local pose = C.world_pose(candidate)
                local p,d = Mat.translation(pose),Mat.forward(pose)
                local delta = p-at
                return candidate,p,d,V.dot(delta,delta),V.dot(d,fwd)
            end)
            if ok and cam and finite(d2) and finite(alignment) and d2 <= 16 and alignment >= 0.98 then
                local error = d2 + 100*math.max(0,1-alignment)
                if not score or error < score then best,origin,forward,score = cam,pos,dir,error end
            end
        end
        if not best then return nil, nil, 'no_matching_camera' end
        local wp = V(x+off[1],y+off[2],z+off[3])
        local depth = V.dot(wp-origin,forward)
        if not finite(depth) or depth <= 0.5 then return nil, nil, 'behind_camera' end
        -- HD2 returns clip-space depth, not metres, as its second result.
        local sp = C.world_to_screen(best,wp,nil,sr.Vector2(sw,sh))
        local sx,sy = V.x(sp),V.y(sp)
        if not finite(sx) or not finite(sy) then return nil, nil, 'invalid_projection' end
        if sx < 0 or sx > sw or sy < 0 or sy > sh then return nil, nil, 'off_screen' end
        if sr.Application.main_world() ~= world then return nil, nil, 'world_changed' end
        return sx,sy,'ready'
    end
    return function(now, subject)
        local ok,x,y,reason = pcall(project,subject)
        local detail
        if not ok then detail=tostring(x); x,y,reason=nil,nil,'projection_error' end
        if report then report(subject,reason,detail,now) end
        return x,y
    end
end
