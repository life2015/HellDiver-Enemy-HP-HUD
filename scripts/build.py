"""Rebuild the addon with the HUD presentation and target lifecycle fixes."""
import difflib
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile

sys.dont_write_bytecode = True
from unpack import ROOT, WORKSPACE, extract, sha

ORIGINAL = ROOT / "unpacked/enemy_hp/Addon/9ba626afa44a3aa3.patch_0/0cdb2ce39c96e9a4.lua"
ARCHIVE = "9ba626afa44a3aa3.patch_0"
RESOURCE_NAME = 0x0CDB2CE39C96E9A4
RESOURCE_TYPE = 0xA14E8DFA2CD117E2
GAME_BUILD = "25480438"
DEPENDENCIES = json.loads((ROOT / "dependencies.json").read_text())["runtime_dependencies"]
LOADER, MENU = DEPENDENCIES
LOADER_REQUIREMENT = f"Bingus Shared Loader v{LOADER['minimum_release']}+ / API {LOADER['api']} with addon discovery"
MOD_VERSION = "1.7.1"
RELEASE_NAME = f"Enemy HP HUD+ {MOD_VERSION}-BSL18.zip"


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Expected exactly one source anchor: {old[:100]}")
    return source.replace(old, new, 1)


def patched_source():
    source = original = ORIGINAL.read_text()
    source = replace_once(source, 'local state = rawget(_G, "EnemyHp")\nif state and state.revision == "ehp-1.0" then return end\nlocal REVISION = "ehp-1.1.2"',
                          f'local REVISION = "ehp-{MOD_VERSION}-bsl18"\nlocal state = rawget(_G, "EnemyHp")\nif state and state.revision == REVISION then return end')
    source = replace_once(source, 'rawset(_G, "EnemyHp", state)',
                          'rawset(_G, "EnemyHp", state)\n'
                          '-- BSL v18 uses internal version 17; jit state is its shared cache capability.\n'
                          'local loader = rawget(_G, "CowboyBingusModLoader")\n'
                          'if type(loader) ~= "table" or loader.api ~= 1 or type(loader.version) ~= "number"\n'
                          '    or loader.version < 17 or type(loader.jit) ~= "table" then\n'
                          '    state.status = "requires_bsl_v18"\n'
                          '    print("[Enemy HP HUD+] Bingus Shared Loader v18 or newer is required")\n'
                          '    return {revision=REVISION, state=state}\nend')
    source = replace_once(source, "local OFFSET = -40", "local OFFSET = -40\nlocal UI_SCALE, BAR_WIDTH = 1, 172\nlocal UI_OPACITY = 100\nlocal AUTO_DAMAGE, DAMAGE_DURATION = true, 3\nlocal AUTO_DAMAGE_MIN_HP = 0\nlocal PART_HUD = true\nlocal MULTI_PARTS = false")
    source = replace_once(source, 'if k == "offset" and v and v >= -400 and v <= 400 then OFFSET = v end',
                          'if k == "offset" and v and v >= -400 and v <= 400 then OFFSET = v end\n'
                          '        if k == "scale" and v and v >= 0.5 and v <= 2 then UI_SCALE = v end\n'
                          '        if k == "opacity" and v and v >= 0 and v <= 100 then UI_OPACITY = v end\n'
                          '        if k == "width" and v and v >= 120 and v <= 320 then BAR_WIDTH = v end\n'
                          '        if k == "auto_damage" and (v == 0 or v == 1) then AUTO_DAMAGE = v == 1 end\n'
                          '        if k == "auto_min_hp" and (v == 0 or v == 500 or v == 1000) then AUTO_DAMAGE_MIN_HP = v end\n'
                          '        if k == "multi_parts" and (v == 0 or v == 1) then MULTI_PARTS = v == 1 end\n'
                          '        if k == "part_hud" and (v == 0 or v == 1) then PART_HUD = v == 1 end\n'
                          '        if k == "damage_duration" and v and v >= 0.5 and v <= 10 then DAMAGE_DURATION = v end')
    drawing_start = source.index("local ui = { gui = nil")
    font_start = source.index("local function font_ids()", drawing_start)
    font_end = source.index("local function ensure_gui()", font_start)
    drawing_end = source.index("local cam, cam_t = nil, -1", font_end)
    font_function = source[font_start:font_end]
    presentation = (ROOT / "src/presentation.lua").read_text()
    replacement = (font_function + "local make_presentation = (function()\n" + presentation +
                   "\nend)()\nlocal ui = make_presentation(sr, font_ids, log)\nlocal ping_ui = make_presentation(sr, font_ids, log)\n")
    source = source[:drawing_start] + replacement + source[drawing_end:]
    source = replace_once(source, 'local function hide() if shown then pcall(draw, " ", { 0, 0, 0, 0 }) shown = false end end',
                          'local function hide() pcall(ui.hide, ui) shown = false end')
    source = replace_once(source,
                          '        if entity_marked(creator, target.entity) then target.until_t = now + 0.5\n'
                          '        else target = nil; last_hp = nil end',
                          '        if entity_marked(creator, target.entity) then\n'
                          '            target.until_t = now + 0.5; target.mark_lost_at = nil\n'
                          '        else target.mark_lost_at = target.mark_lost_at or now end')
    source = replace_once(source,
                          '    -- the label follows the game\'s mark: gone (expired / cancelled with the ping key) -> label gone',
                          '    -- Hide a missing mark, but let tick confirm death before discarding the target.')
    source = replace_once(source,
                          '    target.marker = marker_of(rec.type)',
                          '    target.world = sr.Application.main_world()\n    target.marker = marker_of(rec.type)')
    source = replace_once(source,
                          'if target and target.entity and not target.dead_t and state.frames % 6 == 0 then',
                          'if target and target.source ~= "damage" and target.entity and not target.dead_t and state.frames % 6 == 0 then')
    # Give the native ping controller its own state. Damage selection must never
    # write it; both controllers retain the original read-only native readers.
    ring_start = source.index("local last_mark = nil")
    ring_end = source.index("-- ------------------------------------------------------------------ drawing --", ring_start)
    ring = source[ring_start:ring_end]
    import re
    ring = re.sub(r"\btarget\b", "ping_target", ring)
    ring = re.sub(r"\blast_hp\b", "ping_hp", ring)
    ring = ring.replace("local last_mark = nil", "local last_mark = nil\nlocal ping_target, ping_hp, ping_shown")
    source = source[:ring_start] + ring + source[ring_end:]
    projection_start = source.index("local cam, cam_t = nil, -1")
    projection_end = source.index("local shown = false", projection_start)
    projection = "local make_projection = (function()\n" + (ROOT / "src/projection.lua").read_text() + "\nend)()\n"
    projection += """local screen_of = make_projection(sr, unit_position, function(subject, reason, detail, now)
    local channel = subject and subject.source == "damage" and "damage" or "ping"
    state.projection = state.projection or {}
    local previous = state.projection[channel]
    state.projection[channel] = {reason=reason, detail=detail, unit=subject and subject.unit,
        log_t=previous and previous.log_t, log_reason=previous and previous.log_reason}
    if (not previous or previous.log_reason ~= reason) and
        (not previous or not previous.log_t or now - previous.log_t >= 5) then
        state.projection[channel].log_t = now
        state.projection[channel].log_reason = reason
        log("projection " .. channel .. ": " .. reason .. (detail and ("; " .. detail) or ""))
    end
end)
"""
    source = source[:projection_start] + projection + source[projection_end:]
    start = source.index("local function tick()")
    end = source.index("-- ------------------------------------------------------------- game build --", start)
    damage = ""
    for name in ("damage_reader", "damage_detector", "part_metadata", "settings"):
        damage += "local make_" + name + " = (function()\n" + (ROOT / "src" / (name + ".lua")).read_text() + "\nend)()\n"
    damage += "local part_names = (function()\n" + (ROOT / "src/part_names.lua").read_text() + "\nend)()\n"
    damage += 'local settings\n' + (ROOT / "src/damage_target.lua").read_text() + "\n"
    source = source[:start] + damage + (ROOT / "src/update.lua").read_text() + "\n" + source[end:]
    source = replace_once(source, '        if not ok and state.last_error ~= tostring(err) then state.last_error = tostring(err) log("error: " .. tostring(err)) end',
                          '        if not ok then\n'
                          '            hide()\n'
                          '            pcall(ping_ui.hide, ping_ui)\n'
                          '            if state.last_error ~= tostring(err) then state.last_error = tostring(err) log("error: " .. tostring(err)) end\n'
                          '        end')
    source = replace_once(source, '    read_overrides()\n    state.status = "hooked"',
                          '    local original_shutdown = rawget(_G, "shutdown")\n'
                          '    if type(original_shutdown) == "function" then\n'
                          '        rawset(_G, "shutdown", function(...)\n'
                          '            if settings then settings:shutdown() end\n'
                          '            pcall(ui.dispose, ui)\n'
                          '            pcall(ping_ui.dispose, ping_ui)\n'
                          '            return original_shutdown(...)\n'
                          '        end)\n'
                          '    end\n'
                          '    read_overrides()\n'
                          '    settings = make_settings(_G, {auto_damage=AUTO_DAMAGE, auto_min_hp=AUTO_DAMAGE_MIN_HP, part_hud=PART_HUD, multi_parts=MULTI_PARTS, scale=UI_SCALE, opacity=UI_OPACITY},\n'
                          '        function(values)\n'
                          '            AUTO_DAMAGE, AUTO_DAMAGE_MIN_HP, PART_HUD = values.auto_damage, values.auto_min_hp, values.part_hud\n'
                          '            MULTI_PARTS = values.multi_parts\n'
                          '            UI_SCALE, UI_OPACITY = values.scale, values.opacity\n'
                          '        end, log)\n'
                          '    settings:step()\n'
                          '    if type(loader.after_startup) == "function" then pcall(loader.after_startup, function() settings:step() end) end\n'
                          '    state.status = "hooked"')
    source = replace_once(source, "-- Enemy HP 1.1.2: when", f"-- UI variant: Enemy HP HUD+ {MOD_VERSION}. See README.txt and THIRD_PARTY.txt.\n-- Enemy HP 1.1.2: when")
    return original, source


def archive(source):
    payload = source.encode("utf-8")
    resource = struct.pack("<II", len(payload), 2) + payload
    offset = 192
    end = (offset + len(resource) + 15) & ~15
    header = struct.pack("<III20sQQ24s", 0xF0000011, 1, 1, b"", end, 0, b"")
    types = struct.pack("<IIQIIII", 0, 0, RESOURCE_TYPE, 1, 0, 16, 16)
    entry = struct.pack("<7Q6I", RESOURCE_NAME, RESOURCE_TYPE, offset, 0, 0, 0, 0, len(resource), 0, 0, 16, 16, 0)
    return (header + types + entry).ljust(offset, b"\0") + resource + b"\0" * (end - offset - len(resource))


def main():
    extract()
    original, source = patched_source()
    build, dist = ROOT / "build", ROOT / "dist"
    build.mkdir(exist_ok=True)
    dist.mkdir(exist_ok=True)
    (build / "enemy_hp.lua").write_text(source)
    (build / "ui-changes.diff").write_text("".join(difflib.unified_diff(original.splitlines(True), source.splitlines(True),
                                                                      fromfile="Enemy HP 1.1.2", tofile=f"Enemy HP HUD+ {MOD_VERSION}")))
    patch = archive(source)
    package = build / "package"
    (package / "Addon").mkdir(parents=True, exist_ok=True)
    (package / "Addon" / ARCHIVE).write_bytes(patch)
    for suffix in (".stream", ".gpu_resources"):
        (package / "Addon" / (ARCHIVE + suffix)).write_bytes(b"")
    manifest = json.loads((WORKSPACE / "Enemy HP 1.1.2/manifest.json").read_text())
    manifest["Name"] = f"Enemy HP HUD+ {MOD_VERSION}"
    manifest["Description"] = ("Independent ping and damage-triggered enemy health HUDs with native font, damage trails and part health bars. "
                               f"Requires {LOADER_REQUIREMENT} and Mod Options Menu v{MENU['minimum_release']}+ for in-game settings. Replace older Enemy HP / Enemy HP HUD+. In-game validation pending.")
    manifest["Options"][0]["Name"] = "Enemy HP HUD+"
    manifest["Options"][0]["Description"] = "Enemy health and one damaged part by default (optional three-part mode) for enemies with maximum total HP >= 775. Three-part mode: fatal parts first, then most recently damaged; independent expiry. Native part names and verified part HP bars. Unknown maxima stay numeric."
    (package / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for name in ("README.txt", "THIRD_PARTY.txt", "enemy_hp.cfg.example", "dependencies.json"):
        (package / name).write_bytes((ROOT / name).read_bytes())
    release = dist / RELEASE_NAME
    with zipfile.ZipFile(release, "w", zipfile.ZIP_DEFLATED) as z:
        for path in sorted(package.rglob("*")):
            if path.is_file():
                info = zipfile.ZipInfo(path.relative_to(package).as_posix(), (2026, 10, 2, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                z.writestr(info, path.read_bytes())
    report = {"version": MOD_VERSION, "source_sha256": sha(source.encode()), "original_source_sha256": sha(original.encode()),
              "archive_sha256": sha(patch), "zip_sha256": sha(release.read_bytes()),
              "resource": f"{RESOURCE_NAME:016x}.{RESOURCE_TYPE:016x}",
              "game_build": GAME_BUILD, "requires_loader": LOADER_REQUIREMENT,
              "runtime_dependencies": DEPENDENCIES, "release": RELEASE_NAME,
              "deployment_target_loader_release": LOADER["deployment_target_release"], "in_game_verified": False}
    (build / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(release)


if __name__ == "__main__":
    main()
