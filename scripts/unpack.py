"""Extract these Stingray patch archives without running any mod code."""
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent
LUA_TYPE = 0xA14E8DFA2CD117E2
TYPES = {LUA_TYPE: "lua", 0xCD4238C6A0C69E32: "texture", 0xEAC0B497876ADEDF: "material"}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def extract():
    report = []
    for folder, alias in [("Enemy HP 1.1.2", "enemy_hp"), ("HD2 HUD Plus 0.1.13", "hud_plus")]:
        source = WORKSPACE / folder
        for patch in sorted(source.rglob("*.patch_*")):
            if patch.suffix in (".stream", ".gpu_resources"):
                continue
            data = patch.read_bytes()
            magic, num_types, count = struct.unpack_from("<III", data)
            if magic != 0xF0000011:
                raise ValueError(f"Unexpected archive: {patch}")
            table_end = 72 + 32 * num_types + 80 * count
            if table_end > len(data):
                raise ValueError(f"Truncated archive: {patch}")
            destination = ROOT / "unpacked" / alias / patch.parent.name / patch.name
            destination.mkdir(parents=True, exist_ok=True)
            record = {"archive": str(patch.relative_to(WORKSPACE)), "sha256": sha(data), "resources": []}
            companions = [data] + [Path(str(patch) + ext).read_bytes() for ext in (".stream", ".gpu_resources")]
            for index in range(count):
                row = struct.unpack_from("<7Q6I", data, 72 + 32 * num_types + index * 80)
                name, kind = row[:2]
                stem = f"{name:016x}.{TYPES.get(kind, f'{kind:016x}')}"
                resource = {"name": f"{name:016x}", "type": f"{kind:016x}", "parts": []}
                for part, offset, size, blob in zip(("main", "stream", "gpu_resources"), row[2:5], row[7:10], companions):
                    if size == 0:
                        continue
                    if offset + size > len(blob) or (part == "main" and offset < table_end):
                        raise ValueError(f"Invalid resource bounds: {patch} {stem} {part}")
                    payload = blob[offset:offset + size]
                    output = destination / (stem + "." + part)
                    output.write_bytes(payload)
                    resource["parts"].append({"kind": part, "offset": offset, "bytes": size,
                                               "sha256": sha(payload), "file": str(output.relative_to(ROOT))})
                    if kind == LUA_TYPE and part == "main":
                        length, version = struct.unpack_from("<II", payload)
                        if version != 2 or length != len(payload) - 8:
                            raise ValueError(f"Unexpected Lua header: {output}")
                        code = payload[8:]
                        suffix = ".ljbc" if code.startswith(b"\x1bLJ") else ".lua"
                        if suffix == ".lua":
                            code.decode("utf-8")
                        output.with_name(f"{name:016x}" + suffix).write_bytes(code)
                record["resources"].append(resource)
            report.append(record)
    (ROOT / "unpacked" / "inventory.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Extracted {len(report)} archives, {sum(len(x['resources']) for x in report)} resources")
    return report


if __name__ == "__main__":
    extract()
