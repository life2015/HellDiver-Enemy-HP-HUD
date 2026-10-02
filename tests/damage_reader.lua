return function(make)
    local function u32(s,o)
        local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
    end
    local function i32(s,o) local n=u32(s,o);return n>=2147483648 and n-4294967296 or n end
    local function hex(s,o) return string.format("%08X%08X",u32(s,o+4),u32(s,o)) end
    local function pack(n)
        local b={};for i=1,4 do b[i]=string.char(n%256);n=math.floor(n/256) end;return table.concat(b)
    end
    local function bytes(size,fields)
        local s=string.rep("\0",size)
        for o,v in pairs(fields) do s=s:sub(1,o)..v..s:sub(o+#v+1) end
        return s
    end
    local game,hm,user,descriptors,records,d=0x10000000,0x20000000,0x21000000,0x22000000,0x23000000,0x24000000
    local pointers={[game+0x3326688]=hm,[game+0x347CEF0]=user,[hm+0x1048]=descriptors,[hm+0x1058]=records}
    local memory={[user+0xB398]=pack(0x76543210)..pack(0xFEDCBA98),[hm+0x1020]=pack(1),
        [descriptors]=pack(d)..pack(0),
        [records]=bytes(0x1B8,{[0x14]=pack(75),[0x38]=pack(0x76543210)..pack(0xFEDCBA98),[0x19C]=pack(0)}),
        [d]=pack(0x12345678)..pack(0xABCDEF12)..pack(453)..pack(12662)..pack(99)..pack(0)}
    local blocks=0
    local function read(a,n) local s=memory[a];return s and #s==n and s or nil end
    local reader=make({game=game,u32=u32,i32=i32,hex64=hex,read=read,pointer=function(a) return pointers[a] end,
        block=function(a,n) assert(n<=1048576);blocks=blocks+1;return read(a,n) end})
    local snapshot,peer=reader();local r=snapshot.records[12662]
    assert(blocks==2 and peer=="FEDCBA9876543210")
    assert(r.entity==453 and r.type=="ABCDEF1212345678" and r.descriptor==d and r.network==99)
    assert(r.hp==75 and r.life==0 and r.creditor==peer)
    memory[records]=bytes(0x1B8,{[0x14]=pack(0xFFFFFFFF),[0x19C]=pack(2)})
    snapshot=reader();assert(snapshot.records[12662].hp==-1 and snapshot.records[12662].life==2)
    memory[hm+0x1020]=pack(2049);blocks=0
    assert(not reader() and blocks==0, "reject excessive count before bulk read")
    memory[hm+0x1020]=pack(0);snapshot=reader();assert(snapshot.count==0 and next(snapshot.records)==nil)
    memory[hm+0x1020]=pack(1);local saved=memory[records];memory[records]=nil
    assert(not reader(), "failed bulk read must not produce a partial baseline")
    memory[records]=saved;local saved_d=memory[d];memory[d]=nil
    assert(not reader(), "failed descriptor read must discard snapshot")
    memory[d]=saved_d
    local unstable=make({game=game,u32=u32,i32=i32,hex64=hex,read=read,pointer=function(a) return pointers[a] end,
        block=function(a,n) local s=read(a,n);if a==records then pointers[hm+0x1058]=records+1 end;return s end})
    assert(not unstable(), "changed manager arrays must discard snapshot")
    pointers[hm+0x1058]=records;memory[user+0xB398]=string.rep("\0",8)
    assert(not reader(), "unknown local peer must disable attribution")
    return "PASS: byte-layout adapter, signed HP/life, 64-bit peer, two bounded bulk reads, invalid count/partial reads/manager race and unknown peer"
end
