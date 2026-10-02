"""Offline verification with Lua 5.1 and a strict retained-GUI fake."""
import hashlib
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import struct
import sys
import subprocess
import zipfile

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "scripts"))
from build import ORIGINAL, ARCHIVE, RESOURCE_NAME, RESOURCE_TYPE, LOADER, GAME_BUILD, RELEASE_NAME


def discovered_entries(lua, discovery_source):
    discovery = lua.execute(discovery_source)
    entry = LOADER["entry"]
    # The actual BSL parser scans our actual packaged archive. The pure Python
    # reference hasher supplies raw hash bytes; Windows enumeration is not used.
    spec = importlib.util.spec_from_file_location("bsl_archive", ROOT.parent / "BingusSharedLoader/scripts/archive.py")
    archive_module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(archive_module)
    assert archive_module.resource_hash(entry) == RESOURCE_NAME
    escaped = "".join(f"\\{byte:03d}" for byte in struct.pack("<Q", RESOURCE_NAME))
    hash_name = lua.eval('function(name) assert(name == "' + entry + '"); return "' + escaped + '" end')
    paths = lua.table_from([str(ROOT / "build/package/Addon" / ARCHIVE)])
    entries, warnings = discovery.scan(paths, hash_name, lua.globals().io.open)
    assert list(entries.values()) == [entry] and len(warnings) == 0
    return entries


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    source = (ROOT / "build/enemy_hp.lua").read_text()
    original = ORIGINAL.read_text()
    compile_lua = lua.eval("function(s) local f,e=loadstring(s); assert(f,e); return true end")
    for path in [ROOT / "build/enemy_hp.lua", *sorted((ROOT / "src").glob("*.lua"))]:
        assert compile_lua(path.read_text())
    print("PASS: generated script and renderer compile under Lua 5.1")
    # Check exact preservation of game-reading functions and version guard.
    for begin, end in [("-- --------------------------------------------------------------------- ffi --", "local last_mark = nil"),
                       ("local cam, cam_t = nil, -1", "local shown = false"),
                       ("-- ------------------------------------------------------------- game build --", "local original_update =")]:
        assert original[original.index(begin):original.index(end)] == source[source.index(begin):source.index(end)]
    print("PASS: native memory/health/ping readers, world projection and build guard are byte-for-byte unchanged (target lifecycle updated)")
    env = lua.execute((ROOT / "tests/engine.lua").read_text())
    factory = lua.execute((ROOT / "src/presentation.lua").read_text())
    run = lua.execute((ROOT / "tests/presentation.lua").read_text())
    print(run(factory, env))
    # Exercise real target transitions together with the real renderer, including
    # the game's removal of marks and units between scheduled HP polls.
    tick = source[source.index("local function tick()"):source.index("-- ------------------------------------------------------------- game build --")]
    ring = source[source.index("local last_mark = nil"):source.index("-- ------------------------------------------------------------------ drawing --")]
    lua.globals().ENGINE_SOURCE = (ROOT / "tests/engine.lua").read_text()
    lua.globals().MAKE_PRESENTATION = factory
    lifecycle = (ROOT / "tests/lifecycle.lua").read_text()
    print(lua.execute(lifecycle.replace("--[[TARGET_CONTROLLER]]", ring).replace("--[[UPDATE_CONTROLLER]]", tick)))
    reader_factory = lua.execute((ROOT / "src/damage_reader.lua").read_text())
    detector_factory = lua.execute((ROOT / "src/damage_detector.lua").read_text())
    print(lua.execute((ROOT / "tests/damage_reader.lua").read_text())(reader_factory))
    print(lua.execute((ROOT / "tests/damage.lua").read_text())(detector_factory))
    lua.globals().MAKE_DAMAGE_DETECTOR = detector_factory
    damage_lifecycle = (ROOT / "tests/damage_lifecycle.lua").read_text()
    print(lua.execute(damage_lifecycle.replace("--[[TARGET_CONTROLLER]]", ring)
                      .replace("--[[DAMAGE_CONTROLLER]]", (ROOT / "src/damage_target.lua").read_text())
                      .replace("--[[UPDATE_CONTROLLER]]", tick)))
    startup = lua.execute((ROOT / "tests/startup.lua").read_text())
    hud = (ROOT / "unpacked/hud_plus/COMMON/9ba626afa44a3aa3.patch_0/ef0157640928609f.lua").read_text()
    bsl = (ROOT / LOADER["path"]).resolve()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=bsl, text=True).strip()
    assert commit == LOADER["commit"], "BSL checkout differs from pinned dependency"
    assert LOADER["minimum_release"] == 15 and LOADER["api"] == 1
    assert LOADER["upstream_release_for_game_build"][GAME_BUILD] == 17
    assert LOADER["deployment_target_release"] == 15
    for release, runtime_version in [("v15", 16), (LOADER["tag"], 17)]:
        def upstream(path):
            return subprocess.check_output(["git", "show", f"{release}:{path}"], cwd=bsl, text=True)
        entries = discovered_entries(lua, upstream("src/discover.lua"))
        loader = "local addon_discovery={discover=function() return DISCOVERED_ENTRIES,{} end}\n"
        if release == "v18":
            loader += "local jit_budget=(function()\n" + upstream("src/jit_budget.lua") + "\nend)()\n"
        loader += upstream("src/shared_loader.lua")
        print(release + " " + startup(source, hud, loader, entries, runtime_version))
    print("PASS: release v15/v18 parsers discover the packaged addon; minimum v15/API 1; deployment target v15; upstream source pinned to v18")
    # Whole-module loading: no FFI remains a safe early return.
    lua.execute('EnemyHp=nil; require=function() error("no ffi") end')
    lua.execute(source)
    assert lua.globals().EnemyHp.status == "no_ffi"
    print("PASS: whole-module missing-FFI guard")
    patch_path = ROOT / "build/package/Addon" / ARCHIVE
    blob = patch_path.read_bytes()
    assert struct.unpack_from("<III", blob) == (0xF0000011,1,1)
    row = struct.unpack_from("<7Q6I", blob,104)
    assert row[:2] == (RESOURCE_NAME, RESOURCE_TYPE)
    payload = blob[row[2]:row[2]+row[7]]
    assert struct.unpack_from("<II", payload) == (len(payload)-8,2)
    assert payload[8:] == source.encode()
    assert len(blob)%16 == 0 and row[2]%16 == 0
    inventory = json.loads((ROOT/"unpacked/inventory.json").read_text())
    hud_resources = {(r["name"],r["type"]) for a in inventory if a["archive"].startswith("HD2 HUD") for r in a["resources"]}
    assert (f"{RESOURCE_NAME:016x}",f"{RESOURCE_TYPE:016x}") not in hud_resources
    for archive in inventory:
        b=(ROOT.parent/archive["archive"]).read_bytes()
        assert hashlib.sha256(b).hexdigest()==archive["sha256"]
        for resource in archive["resources"]:
            for part in resource["parts"]:
                raw=(ROOT/part["file"]).read_bytes()
                suffix={"main":"","stream":".stream","gpu_resources":".gpu_resources"}[part["kind"]]
                full=(ROOT.parent/(archive["archive"]+suffix)).read_bytes()
                assert raw == full[part["offset"]:part["offset"]+part["bytes"]]
    zpath=ROOT/"dist"/RELEASE_NAME
    with zipfile.ZipFile(zpath) as z:
        assert z.testzip() is None
        manifest=json.loads(z.read("manifest.json"))
        assert manifest["Options"][0]["Include"]==["Addon"]
        assert z.read("Addon/"+ARCHIVE)==blob
        assert json.loads(z.read("dependencies.json"))["runtime_dependencies"] == [LOADER]
        assert set(z.namelist()) == {"manifest.json", "README.txt", "THIRD_PARTY.txt", "enemy_hp.cfg.example", "dependencies.json",
                                    "Addon/"+ARCHIVE, "Addon/"+ARCHIVE+".stream", "Addon/"+ARCHIVE+".gpu_resources"}
    print("PASS: all 77 extracted resources match originals; single-addon archive and ZIP valid; no resource collision with HUD+")
    print("NOT VERIFIED: Windows filesystem enumeration and Wwise bytecode startup, native font pixels, live gameplay and HUD visibility settings")


if __name__ == "__main__":
    output = io.StringIO()
    report_path = ROOT / "build/build-report.json"
    report = json.loads(report_path.read_text())
    report.pop("offline_validation", None)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    try:
        with contextlib.redirect_stdout(output):
            main()
    finally:
        text = output.getvalue()
        (ROOT / "build/offline-tests.txt").write_text(text)
        print(text, end="")
    report["offline_validation"] = {"passed": True, "lua_runtime": "Lua 5.1 (lupa)",
                                    "report": "build/offline-tests.txt",
                                    "source_sha256": report["source_sha256"],
                                    "loader_releases": ["v15", LOADER["tag"]],
                                    "loader_commit": LOADER["commit"]}
    report_path.write_text(json.dumps(report, indent=2) + "\n")
