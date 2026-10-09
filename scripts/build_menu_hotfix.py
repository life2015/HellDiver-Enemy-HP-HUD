"""Build a separate, pinned Mod Options Menu 1.2 selector-state hotfix.

Does not modify the vendor checkout, Enemy HP package, or any installed mod.
Run tests/menu_rows.lua (Lua 5.1) and the staged upstream Windows suite before deployment.
"""
import difflib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
UPSTREAM = ROOT / 'research/vendor/ModOptionsMenu'
COMMIT = 'fd0160807b6cc75c2eeb74dbf9793a3c5d30deb6'
STAGE = ROOT / 'build/menu-selector-hotfix'
ANCHOR = '        native.row_init(row, vector(0, (position - 1) * -ROW_HEIGHT + gap), PIVOT, PIVOT, 10,\n'
FIX = '''        -- Native selector init (0x17fc640, build 25480438) resets +0x32f5/6
        -- but leaves +0x32f7 (disabled) from the previous native setting.
        -- The parent row is re-enabled, so input works while its value/arrows
        -- stay dim. Clear the child flag BEFORE init paints its native colours.
        -- Sliders reset their own disabled flag; they need no extra write.
        if option.kind ~= 'slider' then put8(row + ROW_SELECTOR + 0x32f7, 0) end
'''

def patched_rows(source):
    assert source.count(ANCHOR) == 1, 'Pinned row builder anchor changed'
    return source.replace(ANCHOR, FIX + ANCHOR)


def main():
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=UPSTREAM, text=True).strip() == COMMIT
    data = subprocess.check_output(['git', 'archive', COMMIT], cwd=UPSTREAM)
    STAGE.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive:
            p = Path(member.name)
            if member.isfile() and p.parts[0] in ('src', 'locales', 'tests'):
                assert '..' not in p.parts and not p.is_absolute()
                dest = STAGE / p
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(archive.extractfile(member).read())
    row_path = STAGE / 'src/rows.lua'
    original = row_path.read_text(encoding='utf-8')
    fixed = patched_rows(original)
    row_path.write_text(fixed, encoding='utf-8')
    (STAGE / 'rows-original.lua').write_text(original, encoding='utf-8')
    patch = ''.join(difflib.unified_diff(original.splitlines(True), fixed.splitlines(True),
                                       fromfile='a/src/rows.lua', tofile='b/src/rows.lua'))
    (STAGE / 'selector-state.diff').write_text(patch, encoding='utf-8')
    # Extend the upstream emulator to reproduce the observed native lifetime bug.
    # Native settings may leave any selector disabled; row_init does not clear it.
    test_path = STAGE / 'tests/test_options_tab.lua'
    test = test_path.read_text(encoding='utf-8')
    seed = '        put32(target + 31424, 2)\n'
    check = '    if words[2] == 2 then\n'
    assert test.count(seed) == test.count(check) == 1
    test = test.replace(seed, seed + '        put8(target + 16016 + 0x32f7, 1) -- inherited disabled selector\n')
    test = test.replace(check, check + "        assert(get8(at + 16016 + 0x32f7) == 0, 'Mod selector inherited native disabled state')\n")
    test_path.write_text(test, encoding='utf-8')
    spec = importlib.util.spec_from_file_location('mom_entry_hotfix', UPSTREAM / 'scripts/entry.py')
    entry = importlib.util.module_from_spec(spec);spec.loader.exec_module(entry)
    source = entry.entry_text(STAGE)
    (STAGE / 'mod_options_menu.lua').write_bytes(source)
    sys.path.insert(0, str(ROOT.parent / 'BingusSharedLoader/scripts'))
    from build_addon import build_addon
    output = ROOT / 'dist/Mod Options Menu 1.2 - Selector State Hotfix.zip'
    build_addon('mods/cowboybingus/mod_options_menu', source, '95ef276a-6287-465f-ac5b-8512d2227b74',
                output, 'Mod Options Menu v1.2 (Selector State Hotfix)')
    # Preserve upstream identity: this replaces the existing menu, not a second addon.
    with zipfile.ZipFile(output) as z:
        files = {n:z.read(n) for n in z.namelist()}
    manifest = json.loads(files['manifest.json'])
    description = 'Mod Options Menu v1.2 with selector disabled-state reset. Requires BSL v18+. Replace the existing menu; do not install two copies.'
    manifest['Description'] = manifest['Options'][0]['Description'] = description
    files['manifest.json'] = (json.dumps(manifest, indent=2)+'\n').encode()
    files['README.txt'] = (ROOT / 'compat/menu-selector-hotfix.txt').read_bytes()
    files['selector-state.diff'] = patch.encode()
    with zipfile.ZipFile(output, 'w') as z:
        for name, payload in sorted(files.items()):
            info=zipfile.ZipInfo(name, (1980,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
            info.external_attr=0o100644 << 16;z.writestr(info,payload)
    report = {'upstream_commit':COMMIT,'source_sha256':hashlib.sha256(source).hexdigest(),
              'archive_sha256':hashlib.sha256(files['Addon/9ba626afa44a3aa3.patch_0']).hexdigest(),
              'zip_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
              'live_game_verified':False,'changes':'Reset selector child disabled byte before native row initialization.'}
    (STAGE / 'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(output)

if __name__ == '__main__':main()
