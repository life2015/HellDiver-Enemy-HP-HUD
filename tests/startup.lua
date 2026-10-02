return function(enemy, hud, loader, entries, runtime_version)
    local function u32(n)
        local out={}
        for i=1,4 do out[i]=string.char(n%256); n=math.floor(n/256) end
        return table.concat(out)
    end
    local function bytes(n, fields)
        local out=string.rep("\0",n)
        for offset,value in pairs(fields) do out=out:sub(1,offset)..value..out:sub(offset+#value+1) end
        return out
    end
    for _, order in ipairs({"enemy-first","hud-first","unsupported"}) do
        local env={}
        for k,v in pairs(_G) do env[k]=v end
        env._G=env
        env.os={clock=function() return 10 end, getenv=function() return nil end}
        env.io={open=function() error("unexpected filesystem access") end}
        env.print=function() end
        env.package={loaded={}}
        env.DISCOVERED_ENTRIES=entries
        env.jit=nil -- Never change the test host's JIT settings.
        local memory={}
        for _, row in ipairs({{0x10000000,0x6AB3B43F,0x4744000,0xECDA6F},
                              {0x20000000,0x6AB382E4,0x39E8000,0xE48B1D}}) do
            memory[row[1]]=bytes(64,{[0]="MZ",[60]=u32(128)})
            memory[row[1]+128]=bytes(96,{[0]="PE\0\0",[8]=u32(order=="unsupported" and 1 or row[2]),
                                                       [80]=u32(row[3]),[88]=u32(row[4])})
        end
        local kernel={GetCurrentProcess=function() return 1 end,
                      GetModuleHandleA=function(name) return name=="game.dll" and 0x10000000 or 0x20000000 end,
                      ReadProcessMemory=function(process,address,buffer,size,got)
                          local data=memory[address]
                          if not data then return 0 end
                          assert(#data==size); buffer.data=data; got[0]=size; return 1
                      end}
        local ffi={cdef=function() end, load=function() return kernel end,
                   new=function(kind,value) if kind=="uint64_t" then return value end return {} end,
                   cast=function(kind,value) return value end, string=function(buffer) return buffer.data end}
        local engine=assert(loadstring(ENGINE_SOURCE))()
        env.stingray=engine.sr
        env.loadstring=function(source,name) local chunk,err=loadstring(source,name); if chunk then setfenv(chunk,env) end return chunk,err end
        local addon_loads=0
        env.stingray.Application.can_get=function(kind,name)
            assert(kind=="lua")
            return name=="mods/combat/enemy_hp"
        end
        env.require=function(name)
            if name=="ffi" then return ffi end
            if name=="mods/combat/enemy_hp" then
                addon_loads=addon_loads+1
                return assert(env.loadstring(enemy))()
            end
            error("not installed: "..name)
        end
        local calls,shutdowns=0,0
        env.update=function(a,b) calls=calls+1; return a,nil,b end
        env.shutdown=function(a) shutdowns=shutdowns+1; return a,nil,7 end
        local before=env.update
        if order=="hud-first" then assert(env.loadstring(hud))() end
        assert(env.loadstring(loader))()
        assert(env.CowboyBingusModLoader.api==1 and env.CowboyBingusModLoader.version==runtime_version)
        assert(env.CowboyBingusModLoader.modules['mods/combat/enemy_hp']=="loaded")
        assert(env.CowboyBingusModLoader.discovery=="1 declared entries" and addon_loads==1)
        if order=="unsupported" then
            assert(env.EnemyHp.status=="unsupported_build" and env.update==before)
        else
            assert(env.EnemyHp.status=="hooked")
            if order=="enemy-first" then assert(env.loadstring(hud))() end
            local installed=env.update
            assert(env.loadstring(loader))()
            assert(addon_loads==1, "BSL must initialize the discovered addon only once")
            assert(env.loadstring(enemy))()
            assert(env.update==installed, "reloading addon must not add another wrapper")
            local a,b,c=env.update("first","last")
            assert(a=="first" and b==nil and c=="last" and calls==1)
            assert(env.EnemyHp.frames==1, "tick must execute exactly once through both wrappers")
            a,b,c=env.shutdown("done")
            assert(a=="done" and b==nil and c==7 and shutdowns==1)
        end
    end
    return "PASS: BSL discovery-to-require startup with actual Enemy HP/HUD+ scripts in both orders; single initialization, update/shutdown returns and unsupported-build guard"
end
