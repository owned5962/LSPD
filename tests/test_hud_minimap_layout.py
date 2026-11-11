from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_needs_hud_is_above_native_minimap_on_desktop_and_compact_screens():
    css = (ROOT / "resources/[FUNCTION]/rp_ui/html/css/style.css").read_text(encoding="utf-8")
    client = (ROOT / "resources/[FUNCTION]/rp_ui/client/main.lua").read_text(encoding="utf-8")

    assert "bottom: 26vh !important;" in css
    assert "#player-hud { left:12px !important; bottom:26vh !important; }" in css
    assert "SetMinimapComponentPosition(" not in client
    assert "DisplayRadar(true)" in client


if __name__ == "__main__":
    test_needs_hud_is_above_native_minimap_on_desktop_and_compact_screens()
    print("HUD minimap layout checks passed.")
