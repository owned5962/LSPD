#!/usr/bin/env python3
"""Repository integrity checks for FiveM resources (catches truncated / incomplete pushes)."""
from __future__ import annotations

import os
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
        if rel.endswith(".lua") or rel.endswith(".html") or "/html/" in rel or rel.startswith("client/") or rel.startswith("server/") or rel.startswith("html/"):
            candidate = base / rel
            if not candidate.is_file():
                window = text[max(0, match.start() - 200) : match.start()]
                if "files" in window or "client_scripts" in window or "server_scripts" in window:
                    fail(f"{manifest_rel}: listed file missing: {rel}")


def check_css_imports(css_rel: str) -> None:
    path = ROOT / css_rel
    if not path.is_file():
        fail(f"missing css: {css_rel}")
        return
    text = path.read_text(encoding="utf-8", errors="replace")
    base = path.parent
    imports = re.findall(r"""@import\s+url\(['\"]([^'\"]+)['\"]\)""", text)
    if imports and len(text) < 2000:
        for imp in imports:
            target = (base / imp).resolve()
            if not target.is_file():
                fail(f"{css_rel}: import missing: {imp}")
            elif target.stat().st_size < 50:
                fail(f"{css_rel}: import empty/tiny: {imp}")
    if not imports and ":root" not in text and "body" not in text:
        fail(f"{css_rel}: does not look like a stylesheet")


def main() -> int:
    check_min_size("resources/[CORE]/rp_characters/client/main.lua", 15000)
    check_min_size("resources/[CORE]/rp_characters/fxmanifest.lua", 200)
    check_min_size("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css", 5000)
    check_min_size("resources/[FUNCTION]/rp_anticheat/html/css/style.css", 1000)
    check_min_size("database.sql", 5000)

    for manifest in ROOT.glob("resources/**/fxmanifest.lua"):
        rel = str(manifest.relative_to(ROOT)).replace("\\", "/")
        check_fxmanifest_files(rel)

    check_css_imports("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css")

    char_client = ROOT / "resources/[CORE]/rp_characters/client"
    bootstrap = char_client / "bootstrap.lua"
    main_lua = char_client / "main.lua"
    if bootstrap.is_file():
        listed = re.findall(r"client/(p\d+\.lua)", bootstrap.read_text(encoding="utf-8", errors="replace"))
        for name in listed:
            part = char_client / name
            if not part.is_file():
                fail(f"characters bootstrap lists missing {name}")
        if main_lua.is_file() and main_lua.stat().st_size < 15000 and listed:
            missing = [n for n in listed if not (char_client / n).is_file()]
            if missing:
                fail("characters client is in broken split mode (bootstrap + incomplete parts)")

    if errors:
        print("INTEGRITY FAILURES:")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("Integrity checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
