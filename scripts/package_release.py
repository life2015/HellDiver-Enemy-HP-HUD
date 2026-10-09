"""Validate and return the standard, directly importable HUD release ZIP."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def main():
    report = json.loads((ROOT / 'build/build-report.json').read_text())
    assert report['offline_validation']['passed']
    assert report['source_sha256'] == report['offline_validation']['source_sha256']
    assert hashlib.sha256((ROOT / 'build/enemy_hp.lua').read_bytes()).hexdigest() == report['source_sha256']
    output = ROOT / 'dist' / report['release']
    assert hashlib.sha256(output.read_bytes()).hexdigest() == report['zip_sha256']
    with zipfile.ZipFile(output) as z:
        assert z.testzip() is None
        assert 'manifest.json' in z.namelist()
        assert not any(n.lower().endswith('.zip') for n in z.namelist()), 'No nested install ZIPs'
        manifest = json.loads(z.read('manifest.json'))
        assert manifest['Options'][0]['Include'] == ['Addon']
        patch = z.read('Addon/9ba626afa44a3aa3.patch_0')
        assert hashlib.sha256(patch).hexdigest() == report['archive_sha256']
    print(output)
    print('Verified standard mod ZIP: root manifest + Addon, no nested archives')

if __name__ == '__main__':
    main()
