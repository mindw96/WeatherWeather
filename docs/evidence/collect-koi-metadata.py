#!/usr/bin/env python3
"""Read local Koi metadata only; never execute Koi or copy its assets/code.

Usage: python3 docs/evidence/collect-koi-metadata.py > docs/evidence/koi-local-metadata.json
"""

import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess

bundle = Path("/Applications/Koi.app")
binary = bundle / "Contents/MacOS/Koi"
plist = bundle / "Contents/Info.plist"


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


info = plistlib.loads(plist.read_bytes())
classes = []
metadata = run("/usr/bin/otool", "-arch", "arm64", "-ov", str(binary))
for block in re.split(r"(?m)^[0-9a-f]{16} 0x[0-9a-f]+$", metadata):
    block = block.split("Meta Class")[0]
    name = re.search(r"(?m)^        name +0x[0-9a-f]+ (.*)$", block)
    if name and re.search(r"(Snow|Rain)", name.group(1)):
        # Only ivar declarations, not method or implementation bodies.
        ivars = block.split("        ivars          ", 1)[-1]
        fields = re.findall(r"(?m)^            name +0x[0-9a-f]+ (.*)$", ivars)
        classes.append({"class": name.group(1), "fields": fields})

imports = run("/usr/bin/nm", "-arch", "arm64", "-u", str(binary))
selected_imports = [line.strip() for line in imports.splitlines()
                    if re.search(r"CGWindow|CGDisplay|CGPreflightScreen|CGRequestScreen|Metal|MTL|AXObserver|AXUIElement|AXIsProcess", line)]
all_strings = run("/usr/bin/strings", "-a", str(binary)).splitlines()
selected_messages = sorted(set(all_strings) & {
    "Snow on your screen", "It's snowing", "Rain falls",
    "Snow that piles up on your windows and the Dock",
    "It settles on your windows and the Dock. The snowflake in the notch stops it.",
    "Rain that splashes on your windows, with lightning now and then",
})
report = {
    "observation_id": "LOCAL-KOI-METADATA-2026-11-05",
    "kind": "local-shell-static-observation-not-REA-Evidence",
    "artifact": {"path": str(binary), "sha256": digest(binary),
                 "format": run("/usr/bin/file", "-b", str(binary)).strip()},
    "plist": {"sha256": digest(plist), "fields": {
        key: info.get(key) for key in (
            "CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
            "LSMinimumSystemVersion", "LSUIElement")}},
    "architecture_selected_for_metadata": "arm64",
    "classes": classes,
    "imports": selected_imports,
    "messages": selected_messages,
    "frameworks": [line.strip() for line in run("/usr/bin/otool", "-arch", "arm64", "-L", str(binary)).splitlines()
                   if re.search(r"/(AppKit|SwiftUI|Metal|QuartzCore|CoreGraphics|ApplicationServices)\.framework", line)],
    "resource_names": sorted(p.name for p in (bundle / "Contents/Resources").iterdir()
                             if re.search(r"snow|rain|weather|\.metallib$", p.name, re.I)),
    "limitations": [
        "Static metadata and symbol declarations do not prove runtime calls.",
        "Only the arm64 slice was examined for class fields and imports.",
        "No decompilation, target launch, network request, or asset/code copying was performed.",
        "Field names suggest architecture but do not establish algorithms, timing, or thresholds.",
    ],
}
print(json.dumps(report, ensure_ascii=False, indent=2))
