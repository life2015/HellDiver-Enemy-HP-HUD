return function(make, names)
    local function pack(n)
        local out={};for i=1,4 do out[i]=string.char(n%256);n=math.floor(n/256) end
        return table.concat(out)
    end
    local function u32(s,o) local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216 end
    local function i32(s,o) local n=u32(s,o);return n>=2147483648 and n-4294967296 or n end
    local function hex(s,o) return string.format("%08X%08X",u32(s,o+4),u32(s,o)) end
    local function bytes(size,fields)
        local s=string.rep("\0",size)
        for o,v in pairs(fields) do s=s:sub(1,o)..v..s:sub(o+#v+1) end
        return s
    end
    local game,hm,net,root,descriptor=0x10000000,0x20000000,0x30000000,0x40000000,0x50000000
    local type_bytes=pack(0x12345678)..pack(0xABCDEF12)
    local row={manager=hm,type=hex(type_bytes,0),descriptor=descriptor,entity=55,unit=66,network=77}
    local pointers={[game+0x3326688]=hm,[game+0x346BF98]=net,[net+0xF12B78]=root}
    local memory,blocks={},0
    local zone=root+0x3EA0+7*0x5650+0x208+2*0x228
    local function reset()
        pointers[net+0xF12B78]=root
        memory={
            [hm+0x10A8]=pack(0),
            [descriptor]=type_bytes..pack(55)..pack(66)..pack(77)..pack(0),
            [root]=bytes(1002*16,{[15*16]=type_bytes..pack(7)..pack(0)}),
            [zone]=bytes(256,{[96]=pack(2354409673),[232]=pack(500),[244]=string.char(1)})}
    end
    local function read(a,n)
        for base,s in pairs(memory) do
            if a>=base and a+n<=base+#s then return s:sub(a-base+1,a-base+n) end
        end
    end
    local api={game=game,read=read,pointer=function(a) return pointers[a] end,
        block=function(a,n) blocks=blocks+1;assert(n<=16032);return read(a,n) end,
        u32=u32,i32=i32,hex64=hex,names=names}
    local get=make(api)
    reset();local m=get(row,3)
    assert(m and m.label=="HEAD" and m.max==500 and m.fatal and not m.downed and not m.shared)
    memory[zone]=bytes(256,{[96]=pack(361496362),[232]=pack(800),[243]=string.char(1)})
    m=get(row,3);assert(m.label=="LEFT ARM" and m.max==800 and m.downed and not m.fatal)
    memory[zone]=bytes(256,{[232]=pack(0xFFFFFFFF)})
    m=get(row,3);assert(m.shared and not m.max and not m.label, "shared pool has no invented independent maximum")
    memory[zone]=bytes(256,{[232]=pack(0)})
    assert(not get(row,3).max, "zero maximum remains numeric-only")
    memory[zone]=bytes(256,{[232]=pack(10000001)})
    assert(not get(row,3), "invalid max rejected")
    reset();memory[zone]=bytes(256,{[232]=pack(500),[244]=string.char(2)})
    assert(not get(row,3), "invalid flags rejected")
    reset();memory[hm+0x10A8]=pack(1);blocks=0
    assert(not get(row,3) and blocks==0, "unresolved instance settings must not use shared max")
    reset();memory[descriptor]=type_bytes..pack(56)..pack(66)..pack(77)..pack(0)
    assert(not get(row,3), "recycled entity rejected")
    reset();memory[zone]=nil;assert(not get(row,3), "missing metadata is optional")
    reset();assert(not get(row,0) and not get(row,39) and not get(row,1.5))
    memory[root]=bytes(1002*16,{[15*16]=type_bytes..pack(1002)..pack(0)})
    assert(not get(row,3), "settings index bounded")
    reset();api.block=function(a,n) local s=read(a,n);pointers[net+0xF12B78]=root+16;return s end
    assert(not make(api)(row,3), "changed table root rejected")
    return "PASS: native zone metadata, exact name hashes, configured maxima, fatal/down flags, shared/unknown fallback, bounds, identity and read-race guards"
end
