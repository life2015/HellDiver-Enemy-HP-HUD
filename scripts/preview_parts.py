"""Part prototype schematic from actual Lua draw calls; substitute font, sample HP."""
from PIL import Image, ImageDraw
from preview import ROOT, font, scene


def main():
    image = Image.new("RGBA", (1600, 740), "#0d1318")
    d = ImageDraw.Draw(image)
    d.text((40, 32), "ENEMY HP HUD+ / MULTI-PART HEALTH BARS / 1.4.0", font=font(28, True), fill="#f0f0e2")
    d.text((40, 80), "WHITE BAR = ENEMY HEALTH     /     GOLD BAR = PART HEALTH",
           font=font(18, True), fill="#aab8bb")
    head = {"label": "HEAD", "hp": 150, "max": 500, "fatal": True}
    arm = {"label": "LEFT ARM", "hp": 80, "max": 400}
    leg = {"label": "LEG", "hp": 240, "max": 600}
    panels = [
        ("01 / FIRST HIT", 2073, False, [head], "Head appears first"),
        ("02 / HIT ANOTHER PART", 2073, False, [head, arm], "Head stays; FATAL keeps first place"),
        ("03 / THREE PARTS", 2073, False, [head, leg, arm], "FATAL first, then newest hit first"),
        ("04 / OLD PART EXPIRES", 2073, False, [leg, arm], "Each part expires independently"),
    ]
    for index, (title, hp, dead, parts, note) in enumerate(panels):
        x, y, w, h = 40 + index * 390, 140, 360, 420
        d.rounded_rectangle((x, y, x+w, y+h), radius=12, fill="#1a242c", outline="#394952")
        d.text((x+18, y+20), title, font=font(15, True), fill="#c6d0d1")
        cx, cy, zoom = x+w/2, y+160, 1.4
        for p in scene(hp=hp, death=dead, parts=parts):
            rgba = tuple(int(v) for v in (p.tint.r, p.tint.g, p.tint.b, p.tint.a))
            px, py = cx+(p.at.x-960)*zoom, cy-(p.at.y-500)*zoom
            layer = Image.new("RGBA", image.size)
            draw = ImageDraw.Draw(layer)
            if p.kind == "rect":
                ww, hh = p.size.x*zoom, p.size.y*zoom
                if ww <= 0 or hh <= 0: continue
                draw.rectangle((round(px), round(py-hh), round(px+ww)-1, round(py)-1), fill=rgba)
            else:
                draw.text((px, py), p.text, anchor="ls", font=font(p.size*zoom), fill=rgba)
            image = Image.alpha_composite(image, layer)
        d = ImageDraw.Draw(image)
        d.text((x+18, y+h-48), note, font=font(14, True), fill="#aab8bb")
    d.text((40, 600), "SCHEMATIC — SAMPLE VALUES — NOT A GAME SCREENSHOT", font=font(17, True), fill="#e6c077")
    d.text((40, 638), "Unknown names keep PART numbers. Shared or unverified maximums show current HP only, without a gauge.",
           font=font(17, True), fill="#aab8bb")
    d.text((40, 678), "Layout uses actual Lua GUI calls; the preview font substitutes for the game's native font.",
           font=font(17, True), fill="#aab8bb")
    output = ROOT / "preview/multi-part-bars-preview.png"
    output.parent.mkdir(exist_ok=True)
    image.convert("RGB").save(output)
    print(output)


if __name__ == "__main__":
    main()
