#!/usr/bin/env python3
"""Check that every Cromite Android GRDP fragment is wired into its parent GRD."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
patch_dir = root / "build" / "patches"
list_file = root / "build" / "cromite_patches_list.txt"
integration_name = "Integrate-Cromite-Android-string-parts.patch"
fragment_prefix = "chrome/browser/ui/android/strings/cromite_android_chrome_strings_grd/"

entries = [
    line.strip() for line in list_file.read_text(encoding="utf-8").splitlines()
    if line.strip() and not line.lstrip().startswith("#")
]
if not entries or entries[-1] != integration_name:
    sys.exit(f"ERROR: {integration_name} must be the final active patch")

created_at = {}
for index, name in enumerate(entries):
    patch_path = patch_dir / name
    if not patch_path.is_file():
        sys.exit(f"ERROR: missing patch: {name}")
    content = patch_path.read_text(encoding="utf-8", errors="replace")
    for path in re.findall(r"^\+\+\+ b/([^\n]+\.grdp)$", content, re.M):
        if path.startswith(fragment_prefix):
            created_at[path] = index

integration = (patch_dir / integration_name).read_text(encoding="utf-8")
included = set(re.findall(r'<part\s+file="([^"]+\.grdp)"\s*/>', integration))
included_paths = {fragment_prefix + item for item in included if not item.startswith("/")}

missing = sorted(set(created_at) - included_paths)
unknown = sorted(included_paths - set(created_at))
if missing:
    sys.exit("ERROR: Android GRDP fragments missing from parent GRD: " + ", ".join(missing))
if unknown:
    sys.exit("ERROR: parent GRD references fragments not created by this patch series: " + ", ".join(unknown))

print(f"OK: {len(created_at)} Cromite Android GRDP fragments are included by the final integration patch.")
