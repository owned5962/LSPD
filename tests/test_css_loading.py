#!/usr/bin/env python3
"""CSS loading rules for FiveM NUI: prefer one stylesheet, forbid @import chains."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

# NUI entry stylesheets (relative to resource html root)
ENTRY_STYLES = [
    Path("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css"),
    Path("resources/[FUNCTION]/rp_tablet_creator/html/style.css"),
    Path("resources/[FUNCTION]/rp_anticheat/html/css/style.css"),
    Path("resources/[FUNCTION]/rp_loadscreen/html/css/style.css"),
    Path("resources/[FUNCTION]/rp_ui/html/css/style.css"),
    Path("resources/[FUNCTION]/rp_tablet_job/html/style.css"),
]


def main() -> int:
    for rel in ENTRY_STYLES:
        path = ROOT / rel
        if not path.is_file():
            errors.append(f"missing entry stylesheet: {rel}")
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        imports = re.findall(r"@import\s+url\(['\"]([^'\"]+)['\"]\)", text)
        if len(imports) > 1:
            errors.append(
                f"{rel}: sequential @import chain ({len(imports)} files) — "
                "inline into a single stylesheet for faster NUI load"
            )
        if len(text) < 400:
            errors.append(f"{rel}: suspiciously small ({len(text)} bytes)")
        # Entry file should contain real rules, not only imports
        if imports and not re.search(r"[{}]\s*[a-zA-Z.#:\[]", text):
            # only imports, no selectors
            body = re.sub(r"@import[^;]+;", "", text).strip()
            if len(body) < 80:
                errors.append(f"{rel}: entry is import-only; CEF loads each @import sequentially")

    if errors:
        print("CSS LOADING FAILURES:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("CSS loading checks passed (no multi-file @import chains).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
