"""Render a schematic comparison from actual Lua GUI calls; no game screenshot."""
from pathlib import Path
import math

from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT = "/System/Library/Fonts/Menlo.ttc"
LABEL = "/System/Library/Fonts/HelveticaNeue.ttc"


def font(size, label=False):
    return ImageFont.truetype(LABEL if label else FONT, max(1, round(size)))


def scene(hp=2073, death=False, trail=False, original=False, part=None, parts=None):
    lua=LuaRuntime(unpack_returned_tuples=True)
    e=lua.execute((ROOT/"tests/engine.lua").read_text())
    e.measure=lambda text,size: font(size).getlength(text)
    if original:
        source=(ROOT/"unpacked/enemy_hp/Addon/9ba626afa44a3aa3.patch_0/0cdb2ce39c96e9a4.lua").read_text()
        draw=source[source.index("local function draw("):source.index("local cam, cam_t")]
        lua.globals().sr=e.sr
        gui=lua.execute('return sr.World.create_screen_gui("overlay")')
        lua.globals().fixture_gui=gui
        lua.execute('local ui={gui=fixture_gui}; local OFFSET=-40; local function ensure_gui() return "font","material" end\n'+draw+'\ndraw("2073 / 6500  (32%)", {255,235,60,50},960,540)')
    else:
        make=lua.execute((ROOT/"src/presentation.lua").read_text())
        ui=make(e.sr,e.font_ids)
        model=lua.table_from(dict(key="target",hp=6500 if trail else hp,max=6500,colour=lua.table_from([255,235,60,50])))
        if part is not None:
            model.part=lua.table_from(part)
        if parts is not None:
            model.parts=lua.table_from([lua.table_from(p) for p in parts])
        options=lua.table_from(dict(offset=-40,scale=1,width=172))
        ui.draw(ui,model,960,540,0,options)
        ui.draw(ui,model,960,540,0.2,options)
        if trail:
            model.hp=hp
            ui.draw(ui,model,960,540,0.3,options)
        if death:
            model.hp=0; model.dead_t=0.3
            ui.draw(ui,model,960,540,0.3,options)
        gui=ui.gui
    return sorted(gui.parts.values(),key=lambda p:p.at.z)


def main():
    image=Image.new("RGBA",(1280,840),(13,19,24,255))
    d=ImageDraw.Draw(image)
    d.text((46,35),"ENEMY HP",font=font(15,True),fill="#c8bd8b")
    d.text((44,63),"A quieter, clearer combat readout.",font=font(36,True),fill="#f0f0e2")
    d.text((46,117),"HUD+ Integrated inspired / actual Lua geometry / preview font substitute",font=font(16,True),fill="#8c9b9f")
    panels=[(44,165,576,300,"01 / ORIGINAL",2073,False,False,True),
            (660,165,576,300,"02 / HUD STYLE",2073,False,False,False),
            (44,503,370,240,"FULL HEALTH",6500,False,False,False),
            (455,503,370,240,"DAMAGE RECEIVED",900,False,True,False),
            (866,503,370,240,"TARGET ELIMINATED",0,True,False,False)]
    for x,y,w,h,title,hp,dead,trail,old in panels:
        d.rounded_rectangle((x,y,x+w,y+h),radius=12,fill="#1a242c",outline="#303e46",width=1)
        d.text((x+24,y+20),title,font=font(13,True),fill="#a0adb0")
        # Abstract terrain-like lines show transparency without pretending this is a game capture.
        d.polygon([(x+1,y+h-55),(x+w*.25,y+72),(x+w*.43,y+h-90),(x+w*.67,y+90),(x+w-1,y+h-25),(x+w-1,y+h-1),(x+1,y+h-1)],fill="#202d35")
        cx,cy=x+w/2,y+h/2+20
        zoom=1.5 if w>400 else 1.45
        if not dead:
            my=cy-64
            d.line([(cx,my-7),(cx+7,my),(cx,my+7),(cx-7,my),(cx,my-7)],fill="#eb6a5b",width=2)
            d.text((cx,my+15),"BILE TITAN",anchor="mt",font=font(11),fill="#b0b9b8")
        for part in scene(hp,dead,trail,old):
            c=part.tint; rgba=(int(c.r),int(c.g),int(c.b),int(c.a))
            at=part.at
            px,py=cx+(at.x-960)*zoom,cy-(at.y-500)*zoom
            layer=Image.new("RGBA",image.size,(0,0,0,0)); ld=ImageDraw.Draw(layer)
            if part.kind=="rect":
                ww,hh=part.size.x*zoom,part.size.y*zoom
                if ww<=0 or hh<=0: continue
                ld.rectangle((round(px),round(py-hh),round(px+ww)-1,round(py)-1),fill=rgba)
            else:
                ld.text((px,py),part.text,anchor="ls",font=font(part.size*zoom),fill=rgba)
            image=Image.alpha_composite(image,layer)
        d=ImageDraw.Draw(image)
        note="Single colour / boxed label" if old else ("Warm-white numbers / slim gauge" if w>400 else ("Recent damage lingers briefly" if trail else "Fades out after the kill" if dead else "Full gauge, neutral typography"))
        d.text((x+24,y+h-32),note,font=font(13,True),fill="#94a2a6")
    d.text((46,775),"SCHEMATIC PREVIEW",font=font(12,True),fill="#c8bd8b")
    d.text((46,800),"Not an in-game screenshot. The mod uses the game's native font; final placement needs an in-game check.",font=font(14,True),fill="#8c9b9f")
    output=ROOT/"preview/comparison.png"
    output.parent.mkdir(exist_ok=True)
    image.convert("RGB").save(output)
    print(output)


if __name__=="__main__": main()
