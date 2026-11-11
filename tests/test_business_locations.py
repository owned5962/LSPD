from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def test_business_map_categories_and_server_startup_are_registered():
    locations = (ROOT / "resources/[FUNCTION]/rp_businesses/shared/locations.lua").read_text(encoding="utf-8")
    client = (ROOT / "resources/[FUNCTION]/rp_businesses/client/main.lua").read_text(encoding="utf-8")
    manifest = (ROOT / "resources/[FUNCTION]/rp_businesses/fxmanifest.lua").read_text(encoding="utf-8")
    server_cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    clothing = (ROOT / "resources/[FUNCTION]/rp_clothing/client/main.lua").read_text(encoding="utf-8")
    economy = (ROOT / "resources/[FUNCTION]/rp_economy/client/main.lua").read_text(encoding="utf-8")

    for category in ("barber", "beauty", "nightclub", "ammunation", "food"):
        assert f"id = '{category}'" in locations
    assert "ATMBlipLocations" in locations
    assert "SetBlipSprite(blip,  277)" in client
    assert "shared/locations.lua" in manifest
    assert "ensure rp_businesses" in server_cfg
    assert clothing.count("vector3(") >= 10
    assert "local BankPositions" in economy
    assert "local ATMModels" in economy


if __name__ == "__main__":
    test_business_map_categories_and_server_startup_are_registered()
    print("Business location checks passed.")
