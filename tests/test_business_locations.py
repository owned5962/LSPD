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


def test_mysql_world_location_registry_covers_all_map_location_types():
    server = (ROOT / "resources/[FUNCTION]/rp_businesses/server/main.lua").read_text(encoding="utf-8")
    locations = (ROOT / "resources/[FUNCTION]/rp_businesses/shared/locations.lua").read_text(encoding="utf-8")
    manifest = (ROOT / "resources/[FUNCTION]/rp_businesses/fxmanifest.lua").read_text(encoding="utf-8")
    economy = (ROOT / "resources/[FUNCTION]/rp_economy/server/main.lua").read_text(encoding="utf-8")
    fuel = (ROOT / "resources/[FUNCTION]/rp_fuel/server/main.lua").read_text(encoding="utf-8")
    player = (ROOT / "resources/[CORE]/rp_core/server/player.lua").read_text(encoding="utf-8")
    core = (ROOT / "resources/[CORE]/rp_core/server/main.lua").read_text(encoding="utf-8")

    for location_type in ("atm", "bank", "shop", "gas_station"):
        assert f"'{location_type}'" in server
    for column in ("shop_style", "icon", "x DOUBLE", "y DOUBLE", "z DOUBLE",
                   "blip_enabled", "blip_sprite", "blip_scale", "blip_colour"):
        assert column in server
    assert "INSERT IGNORE INTO" in server
    schema = (ROOT / "database.sql").read_text(encoding="utf-8")
    assert "CREATE TABLE IF NOT EXISTS `rp_world_locations`" in schema
    assert "GetLocationsByType" in server
    assert "getLocationsByType('bank')" in economy
    assert "getLocationsByType('atm')" in economy
    assert "GetLocationsByType('gas_station')" in fuel
    assert "BankLocations =" in locations and "GasStationLocations =" in locations
    assert "server/main.lua" in manifest and "@oxmysql/lib/MySQL.lua" in manifest
    assert "local savedPosition = charData.position" in player and "json.encode(position)" in player
    assert "Wait(60 * 1000)" in core

if __name__ == "__main__":
    test_business_map_categories_and_server_startup_are_registered()
    test_mysql_world_location_registry_covers_all_map_location_types()
    print("Business location checks passed.")
