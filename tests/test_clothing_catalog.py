from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_clothing_shop_exposes_live_variations_for_all_requested_categories():
    client = read("resources/[FUNCTION]/rp_clothing/client/main.lua")
    html = read("resources/[FUNCTION]/rp_clothing/html/index.html")
    ui = read("resources/[FUNCTION]/rp_clothing/html/js/app.js")
    required = {
        "tops", "undershirts", "pants", "shoes", "hats",
        "glasses", "ears", "watches", "bracelets", "accessories",
    }
    for category in required:
        assert f"id = '{category}'" in client
        assert category in ui
    assert "GetNumberOfPedDrawableVariations" in client
    assert "GetNumberOfPedPropDrawableVariations" in client
    assert "GetNumberOfPedPropTextureVariations" in client
    assert "RegisterNUICallback('previewVariation'" in client
    assert "previewVariation" in ui
    assert 'id="category-list"' in html
    assert 'id="texture-range"' in html
    assert 'id="prev-item"' in html and 'id="next-item"' in html
    assert "s'affiche directement sur ton personnage" in html
    assert "CreateCam('DEFAULT_SCRIPTED_CAMERA', true)" in client
    assert "RenderScriptCams(true, true, 500" in client
    assert "RegisterNUICallback('rotatePlayer'" in client
    assert "stopClothingCamera()" in client
    assert "activeShopPosition = pos" in client
    assert "GetEntityCoords(ped) - activeShopPosition) > 1.0" in client
    assert "Boutique fermée : vous avez quitté la zone." in client
    assert 'id="rotate-left"' in html and 'id="rotate-right"' in html
