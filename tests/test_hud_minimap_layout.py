from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_hud_sits_beside_minimap_and_vehicle_speedometer_is_centered():
    css = (ROOT / "resources/[FUNCTION]/rp_ui/html/css/style.css").read_text(encoding="utf-8")
    client = (ROOT / "resources/[FUNCTION]/rp_ui/client/main.lua").read_text(encoding="utf-8")
    html = (ROOT / "resources/[FUNCTION]/rp_ui/html/index.html").read_text(encoding="utf-8")

    final_layout = css.split("/* Final HUD layout:", 1)[1]
    assert "left: clamp(185px, 17vw, 330px) !important;" in final_layout
    assert "bottom: 3.5vh !important;" in final_layout
    assert "left: 50% !important;" in final_layout
    assert "transform: translateX(-50%) !important;" in final_layout
    assert 'id="vehicle-speed"' in html
    assert 'id="vehicle-fuel"' in html
    assert 'id="vehicle-fuel-bar"' in html
    assert "SETUP_HEALTH_ARMOUR" in client
    assert "ScaleformMovieMethodAddParamInt(3)" in client
    assert 'id="hud-health"' not in html
    assert 'id="hud-armor"' not in html
    assert "SetMinimapComponentPosition(" not in client
    assert "DisplayRadar(true)" in client


if __name__ == "__main__":
    test_hud_sits_beside_minimap_and_vehicle_speedometer_is_centered()
    print("HUD layout checks passed.")
