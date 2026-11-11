from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_needs_hud_is_above_native_minimap_on_desktop_and_compact_screens():
    css = (ROOT / "resources/[FUNCTION]/rp_ui/html/css/style.css").read_text(encoding="utf-8")
    client = (ROOT / "resources/[FUNCTION]/rp_ui/client/main.lua").read_text(encoding="utf-8")

    assert "bottom: 26vh !important;" in css
    assert "@media (max-width: 600px)" in css
    compact = css.split("@media (max-width: 600px)", 1)[1]
    assert "#player-hud { left:12px !important; bottom:26vh !important; }" in compact
    assert "SetMinimapComponentPosition(" not in client
    assert "DisplayRadar(true)" in client
