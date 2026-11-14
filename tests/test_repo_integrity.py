#!/usr/bin/env python3
"""Repository integrity checks for FiveM resources (catches truncated / incomplete pushes)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def fail(msg: str) -> None:
    errors.append(msg)


def check_min_size(rel: str, minimum: int) -> None:
    path = ROOT / rel
    if not path.is_file():
        fail(f"missing file: {rel}")
        return
    size = path.stat().st_size
    if size < minimum:
        fail(f"too small ({size} < {minimum} bytes): {rel}")


def check_not_placeholder(rel: str) -> None:
    path = ROOT / rel
    if not path.is_file():
        return
    text = path.read_text(encoding="utf-8", errors="replace").strip()
    if text.upper() in {"PLACEHOLDER", "TODO", "FIXME"} or text == "":
        fail(f"placeholder/empty stub: {rel}")


def check_fxmanifest_files(manifest_rel: str) -> None:
    path = ROOT / manifest_rel
    if not path.is_file():
        fail(f"missing fxmanifest: {manifest_rel}")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    base = path.parent
    for match in re.finditer(r"""['\"]([^'\"]+)['\"]""", text):
        rel = match.group(1)
        if rel.startswith("@"):
            continue
        if (
            rel.endswith(".lua")
            or rel.endswith(".html")
            or "/html/" in rel
            or rel.startswith("client/")
            or rel.startswith("server/")
            or rel.startswith("html/")
        ):
            candidate = base / rel
            if not candidate.is_file():
                window = text[max(0, match.start() - 200) : match.start()]
                if "files" in window or "client_scripts" in window or "server_scripts" in window:
                    fail(f"{manifest_rel}: listed file missing: {rel}")


def check_characters_bootstrap() -> None:
    main = ROOT / "resources/[CORE]/rp_characters/client/main.lua"
    if not main.is_file():
        fail("missing characters client/main.lua")
        return
    text = main.read_text(encoding="utf-8", errors="replace")
    if "PART_COUNT" not in text and "LoadResourceFile" not in text and "function" not in text:
        fail("characters client/main.lua looks empty or invalid")
    # Prefer assembled parts present when using split loader
    if "PART_COUNT" in text:
        m = re.search(r"PART_COUNT\s*=\s*(\d+)", text)
        if m:
            n = int(m.group(1))
            for i in range(1, n + 1):
                check_min_size(f"resources/[CORE]/rp_characters/client/p{i}.lua", 200)


def main() -> int:
    check_min_size("resources/[CORE]/rp_characters/client/main.lua", 200)
    check_min_size("resources/[CORE]/rp_characters/server/main.lua", 5000)
    check_min_size("resources/[CORE]/rp_characters/html/css/style.css", 1500)
    check_not_placeholder("resources/[CORE]/rp_characters/html/css/style.css")
    check_min_size("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css", 2000)
    check_not_placeholder("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css")
    check_min_size("resources/[FUNCTION]/rp_loadscreen/html/css/style.css", 5000)
    check_fxmanifest_files("resources/[CORE]/rp_characters/fxmanifest.lua")
    check_fxmanifest_files("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    check_characters_bootstrap()

    if errors:
        print("INTEGRITY FAILURES:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("Repository integrity checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
