from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUSINESSES = ROOT / "resources/[FUNCTION]/rp_businesses"


def test_ammunation_client_uses_shared_blip_points_without_waiting_for_mysql():
    client = (BUSINESSES / "client/main.lua").read_text(encoding="utf-8")
    locations = (BUSINESSES / "shared/locations.lua").read_text(encoding="utf-8")

    assert "for _, category in ipairs(BusinessLocations or {}) do" in client
    assert "if category.id == 'ammunation' then" in client
    assert "addAmmunationLocation(point[1], point[2], point[3])" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "nearestHorizontal <= 6.0" in client
    assert "id = 'ammunation'" in locations


def test_ammunation_server_checks_same_shared_points_as_client_blips():
    server = (BUSINESSES / "server/main.lua").read_text(encoding="utf-8")
    assert "local function getAmmunationLocations()" in server
    assert "category.id == 'ammunation'" in server
    assert "locations[#locations + 1]" in server
    assert "AMMUNATION_INTERACTION_RADIUS = 12.0" in server
    assert "AMMUNATION_VERTICAL_TOLERANCE = 12.0" in server
    assert "getPlayerAtAmmunation(src)" in server
    assert "getPlayerAtAmmunation(src, 3.0)" not in server
    assert "getPlayerAtAmmunation(src, 4.0)" not in server


def test_ammunation_open_and_purchase_use_the_same_proximity_validation():
    server = (BUSINESSES / "server/main.lua").read_text(encoding="utf-8")
    open_block = server.split("RegisterNetEvent('rp_businesses:server:requestAmmunation'", 1)[1].split("RegisterNetEvent('rp_businesses:server:buyPistol'", 1)[0]
    buy_block = server.split("RegisterNetEvent('rp_businesses:server:buyPistol'", 1)[1].split("-- Catalogue des supérettes", 1)[0]
    assert "getPlayerAtAmmunation(src)" in open_block
    assert "getPlayerAtAmmunation(src)" in buy_block
    assert "openAmmunation" in open_block
    assert "AcquireCharacterLock(locks)" in buy_block
    assert "UPDATE characters" in buy_block
    assert "SET cash = cash - ?, metadata = ?" in buy_block
    assert "metadata.weapons" in buy_block
    assert "ReleaseCharacterLock(locks)" in buy_block


def test_inventory_contains_melee_weapons_and_mp5_item():
    config = (ROOT / "resources/[FUNCTION]/rp_inventory/config.lua").read_text(encoding="utf-8")
    for item in (
        "weapon_knife", "weapon_bat", "weapon_crowbar", "weapon_hammer",
        "weapon_golfclub", "weapon_knuckle", "weapon_machete", "weapon_flashlight",
        "weapon_bottle", "weapon_dagger", "weapon_hatchet", "weapon_switchblade",
        "weapon_poolcue", "weapon_wrench", "weapon_battleaxe", "weapon_stone_hatchet",
        "weapon_mp5"
    ):
        assert f"['{item}']" in config


if __name__ == "__main__":
    test_ammunation_client_uses_shared_blip_points_without_waiting_for_mysql()
    test_ammunation_server_checks_same_shared_points_as_client_blips()
    test_ammunation_open_and_purchase_use_the_same_proximity_validation()
    test_inventory_contains_melee_weapons_and_mp5_item()
    print("Ammu-Nation interaction checks passed.")
