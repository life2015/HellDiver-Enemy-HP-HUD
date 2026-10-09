-- Real upstream rows.lua with native lifetime emulation based on build 25480438.
-- Deliberately model the flag omitted by native selector init, not a clean row.
return function(source)
    local memory, text, pending, paint, writes = {}, {}, {}, {}, {}
    local function get(p) return memory[p] or 0 end
    local function put(p,v) memory[p]=v end
    local function put8(p,v) writes[#writes+1]={p,v};put(p,v) end
    local content, rows = 10000000, 10144000
    local offsets={1150848,1179528,1253248,1287376,1153728,1156616,1290256,1293152}
    local native={}
    local mom={state={native=native},get32=get,get64=get,getf=get,put32=put,putf=put,put8=put8,
        valid_pointer=function(p) return p>0 end, PIVOT={},vector=function(x,y)return {x=x,y=y} end,
        aligned=function() return {},{} end, INERT_SETTING=139,TEXT_TEMPLATE=42,
        show_text=function(p,t)text[p]=t end,shows_text=function(p,t)return text[p]==t end,
        snap=function(_,v)return v end,set_pending=function(id,v)pending[id]=v end,
        shown_value=function(o)return o.applied end}
    local env=setmetatable({require=function(n)assert(n=='ffi');return {cast=function(_,v)return v end} end},{__index=_G})
    local fn=assert(loadstring(source));setfenv(fn,env);fn(mom)
    function native.row_reset() end
    function native.row_release() end -- destruction does not clear embedded flags
    function native.row_init(row,position,pivot,anchor,layer,settings,option)
        put(row+0x7acb,0) -- native parent row is re-enabled
        put(row+31428,139)
        put(row+31424,option.kind=='slider' and 1 or 2)
        if option.kind=='slider' then
            put(row+0x7ab9,0) -- native slider resets its child flag
        else
            -- Native selector resets +32f5/6 but retains +32f7.
            put(row+29072,#option.labels);put(row+29080,option.labels[1])
            paint[row]=get(row+16016+0x32f7)==0 and 'normal' or 'dim'
        end
    end
    function native.add_child() end
    function native.set_choice(selector,index)put(selector-16016+29068,index) end
    function native.set_slider(slider,value)put(slider-29176+31408,value) end
    function native.finish_simple()end
    function native.finish_access()end
    function native.set_opacity()end
    function native.scroll_thumb()end
    function native.scroll_extent()end
    function native.scroll_reset()end
    local options={}
    for i=1,32 do
        local kind=i%3==0 and 'slider' or i%3==1 and 'toggle' or 'choice'
        local o={id='opt'..i,kind=kind,label='Option '..i,labels={11,12},choices={'A','B'},
            applied=kind=='toggle' and true or kind=='slider' and 0.5 or 2,gap=i==6}
        o.descriptor=o;options[i]=o
    end
    local view={content=content,buttons={}}
    for category,offset in ipairs(offsets) do
        view.buttons[category]={order=options};put(content+offset+2816,rows)
        for repeat_build=1,3 do
            writes={}
            for i=0,31 do
                local row=rows+31464*i
                put(row+0x7acb,1);put(row+16016+0x32f7,1);put(row+0x7ab9,1)
                put(row+16016+0x32f8,83) -- adjacent unrelated byte must stay intact
            end
            assert(mom.build_page(view,category-1))
            local expected_writes=0
            for i,o in ipairs(options) do
                local row=rows+31464*(i-1)
                assert(get(row+0x7acb)==0)
                if o.kind~='slider' then
                    expected_writes=expected_writes+1
                    assert(paint[row]=='normal','Mod selector inherited native disabled state')
                    assert(get(row+16016+0x32f7)==0)
                    assert(get(row+16016+0x32f8)==83,'must not overwrite adjacent state')
                else assert(get(row+0x7ab9)==0) end
            end
            local selector_writes=0
            for _,w in ipairs(writes) do
                if w[1]>=rows and w[1]<rows+32*31464 then
                    assert((w[1]-rows)%31464==16016+0x32f7 and w[2]==0)
                    selector_writes=selector_writes+1
                else
                    assert((category==2 or category==3) and w[1]==content+offset+33254, 'only existing panel scroll flag may also change')
                end
            end
            assert(selector_writes==expected_writes,'write only the selector byte, once per constructed selector')
            assert(mom.page_intact(view))
            put(rows+29068,0);mom.poll_page(view)
            assert(pending.opt1==false,'toggle input still reaches pending changes')
            put(rows+31464+29068,0);mom.poll_page(view)
            assert(pending.opt2==1,'choice input still reaches pending changes')
            assert(options[1].applied==true and options[2].applied==2,'building/polling must not apply edits')
        end
    end
    return 'PASS: 8 category panels x 3 rebuilds x 32 reused rows; disabled selector cleared before paint, sliders intact, adjacent bytes preserved, toggle/choice input and pending values unchanged'
end
