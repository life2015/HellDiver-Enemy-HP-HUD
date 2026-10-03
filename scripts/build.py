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
LOADER = json.loads((ROOT / "dependencies.json").read_text())["runtime_dependencies"][0]
LOADER_REQUIREMENT = f"Bingus Shared Loader v{LOADER['minimum_release']}+ / API {LOADER['api']} with addon discovery"
RELEASE_NAME = "Enemy HP HUD+ 1.1.2-ui4-BSL15.zip"


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Expected exactly one source anchor: {old[:100]}")
    return source.replace(old, new, 1)


def patched_source():
    source = original = ORIGINAL.read_text()
    source = replace_once(source, 'local state = rawget(_G, "EnemyHp")\nif state and state.revision == "ehp-1.0" then return end\nlocal REVISION = "ehp-1.1.2"',
                          'local REVISION = "ehp-1.1.2-ui4-bsl15"\nlocal state = rawget(_G, "EnemyHp")\nif state and state.revision == REVISION then return end')
    source = replace_once(source, "local OFFSET = -40", "local OFFSET = -40\nlocal UI_SCALE, BAR_WIDTH = 1, 172\nlocal AUTO_DAMAGE, DAMAGE_DURATION = true, 3")
    source = replace_once(source, 'if k == "offset" and v and v >= -400 and v <= 400 then OFFSET = v end',
                          'if k == "offset" and v and v >= -400 and v <= 400 then OFFSET = v end\n'
                          '        if k == "scale" and v and v >= 0.5 and v <= 2 then UI_SCALE = v end\n'
                          '        if k == "width" and v and v >= 120 and v <= 320 then BAR_WIDTH = v end\n'
                          '        if k == "auto_damage" and (v == 0 or v == 1) then AUTO_DAMAGE = v == 1 end\n'
                          '        if k == "damage_duration" and v and v >= 0.5 and v <= 10 then DAMAGE_DURATION = v end')
    drawing_start = source.index("local ui = { gui = nil")
    font_start = source.index("local function font_ids()", drawing_start)
    font_end = source.index("local function ensure_gui()", font_start)
    drawing_end = source.index("local cam, cam_t = nil, -1", font_end)
    font_function = source[font_start:font_end]
    presentation = (ROOT / "src/presentation.lua").read_text()
    replacement = (font_function + "local make_presentation = (function()\n" + presentation +
                   "\nend)()\nlocal ui = make_presentation(sr, font_ids, log)\n")
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
    start = source.index("local function tick()")
    end = source.index("-- ------------------------------------------------------------- game build --", start)
    damage = ""
    for name in ("damage_reader", "damage_detector"):
        damage += "local make_" + name + " = (function()\n" + (ROOT / "src" / (name + ".lua")).read_text() + "\nend)()\n"
    damage += (ROOT / "src/damage_target.lua").read_text() + "\n"
    source = source[:start] + damage + (ROOT / "src/update.lua").read_text() + "\n" + source[end:]
    source = replace_once(source, '        if not ok and state.last_error ~= tostring(err) then state.last_error = tostring(err) log("error: " .. tostring(err)) end',
                          '        if not ok then\n'
                          '            hide()\n'
                          '            if state.last_error ~= tostring(err) then state.last_error = tostring(err) log("error: " .. tostring(err)) end\n'
                          '        end')
    source = replace_once(source, '    read_overrides()\n    state.status = "hooked"',
                          '    local original_shutdown = rawget(_G, "shutdown")\n'
                          '    if type(original_shutdown) == "function" then\n'
                          '        rawset(_G, "shutdown", function(...)\n'
                          '            pcall(ui.dispose, ui)\n'
                          '            return original_shutdown(...)\n'
                          '        end)\n'
                          '    end\n'
                          '    read_overrides()\n    state.status = "hooked"')
    source = replace_once(source, "-- Enemy HP 1.1.2: when", "-- UI variant: Enemy HP HUD+ ui4. See README.txt and THIRD_PARTY.txt.\n-- Enemy HP 1.1.2: when")
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
                                                                      fromfile="Enemy HP 1.1.2", tofile="Enemy HP HUD+ ui4")))
    patch = archive(source)
    package = build / "package"
    (package / "Addon").mkdir(parents=True, exist_ok=True)
    (package / "Addon" / ARCHIVE).write_bytes(patch)
    for suffix in (".stream", ".gpu_resources"):
        (package / "Addon" / (ARCHIVE + suffix)).write_bytes(b"")
    manifest = json.loads((WORKSPACE / "Enemy HP 1.1.2/manifest.json").read_text())
    manifest["Name"] = "Enemy HP HUD+"
    manifest["Description"] = ("Enemy HP 1.1.2 with a HUD+ inspired slim gauge, native font, outlined numbers and damage trail. "
                               f"Requires {LOADER_REQUIREMENT}. Replace the original Enemy HP. In-game validation pending.")
    manifest["Options"][0]["Name"] = "Enemy HP HUD+"
    manifest["Options"][0]["Description"] = "Compact HP gauge for marked targets and observed locally credited damage."
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
    report = {"source_sha256": sha(source.encode()), "original_source_sha256": sha(original.encode()),
              "archive_sha256": sha(patch), "zip_sha256": sha(release.read_bytes()),
              "resource": f"{RESOURCE_NAME:016x}.{RESOURCE_TYPE:016x}",
              "game_build": GAME_BUILD, "requires_loader": LOADER_REQUIREMENT,
              "runtime_dependencies": [LOADER], "release": RELEASE_NAME,
              "deployment_target_loader_release": LOADER["deployment_target_release"], "in_game_verified": False}
    (build / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(release)


if __name__ == "__main__":
    main()
