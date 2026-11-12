from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUSINESSES = ROOT / "resources/[FUNCTION]/rp_businesses"
INVENTORY = ROOT / "resources/[FUNCTION]/rp_inventory"


def test_ammunation_client_uses_shared_blip_points_and_one_metre_prompt():
    client = (BUSINESSES / "client/main.lua").read_text(encoding="utf-8")
    locations = (BUSINESSES / "shared/locations.lua").read_text(encoding="utf-8")
    assert "for _, category in ipairs(BusinessLocations or {}) do" in client
    assert "if category.id == 'ammunation' then" in client
    assert "addAmmunationLocation(point[1], point[2], point[3])" in client
    assert "nearestHorizontal <= 1.0" in client
    assert "nearestVertical <= 2.0" in client
    assert "ammunationOpening = true" in client
    assert "SetTimeout(5000" in client
    assert "rp_businesses:client:openDenied" in client
    assert "products = type(products) == 'table' and products or {}" in client
    assert "RegisterNUICallback('buyAmmunationWeapon'" in client
    assert "id = 'ammunation'" in locations


def test_ammunation_server_checks_shared_points_and_one_metre_range():
    server = (BUSINESSES / "server/main.lua").read_text(encoding="utf-8")
    client = (BUSINESSES / "client/main.lua").read_text(encoding="utf-8")
    assert "local function getAmmunationLocations()" in server
    assert "category.id == 'ammunation'" in server
    assert "AMMUNATION_INTERACTION_RADIUS = 1.5" in server
    assert "AMMUNATION_VERTICAL_TOLERANCE = 2.0" in server
    assert "getPlayerAtAmmunation(src)" in server
    assert "rp_businesses:client:openDenied" in server
    assert "nearestHorizontal <= 1.0" in client


def test_ammunation_payment_is_atomic_and_weapon_metadata_is_persistent():
    server = (BUSINESSES / "server/main.lua").read_text(encoding="utf-8")
    open_block = server.split("RegisterNetEvent('rp_businesses:server:requestAmmunation'", 1)[1].split("RegisterNetEvent('rp_businesses:server:buyPistol'", 1)[0]
    buy_block = server.split("local function purchaseAmmunationWeapon(src, itemName)", 1)[1].split("RegisterNetEvent('rp_businesses:server:buyAmmunationWeapon'", 1)[0]
    assert "getPlayerAtAmmunation(src)" in open_block
    assert "getPlayerAtAmmunation(src)" in buy_block
    assert "AcquireCharacterLock(locks)" in buy_block
    assert "UPDATE characters" in buy_block
    assert "SET cash = cash - ?, metadata = ?" in buy_block
    assert "metadata.weapons" in buy_block
    assert "ReleaseCharacterLock(locks)" in buy_block
    assert "weaponPurchased" in buy_block
    assert "AMMUNATION_WEAPONS" in server
    assert "weapon_mp5" in server and "weapon_battleaxe" in server and "weapon_knife" in server
    assert "buildAmmunationCatalog()" in open_block
    ui = (ROOT / "resources/[FUNCTION]/rp_businesses/html/js/app.js").read_text(encoding="utf-8")
    assert "currentMode === 'ammu' ? 'buyAmmunationWeapon'" in ui
    assert "renderProducts(data.products)" in ui
    assert "product.category" in ui


def test_inventory_contains_equipable_melee_weapons_and_mp5():
    config = (INVENTORY / "config.lua").read_text(encoding="utf-8")
    server = (INVENTORY / "server/main.lua").read_text(encoding="utf-8")
    client = (INVENTORY / "client/main.lua").read_text(encoding="utf-8")
    for item in (
        "weapon_pistol", "weapon_knife", "weapon_nightstick", "weapon_bat", "weapon_crowbar",
        "weapon_hammer", "weapon_golfclub", "weapon_knuckle", "weapon_machete",
        "weapon_flashlight", "weapon_bottle", "weapon_dagger", "weapon_hatchet",
        "weapon_switchblade", "weapon_poolcue", "weapon_wrench", "weapon_battleaxe",
        "weapon_stone_hatchet", "weapon_candycane", "weapon_mp5"
    ):
        assert f"['{item}']" in config
    assert "itemDef.type == 'weapon'" in server
    assert "useWeaponItem(src, player, inventory, itemName, itemDef)" in server
    assert "exports['rp_anticheat']:IsWeaponAllowed(weaponName)" in server
    assert "metadata.weapons[#metadata.weapons + 1]" in server
    assert "MySQL.transaction.await" in server
    assert "RegisterNetEvent('rp_inventory:client:giveWeapon'" in client


def test_ammunation_client_has_one_valid_weapon_delivery_handler():
    client = (BUSINESSES / "client/main.lua").read_text(encoding="utf-8")
    assert client.count("RegisterNetEvent('rp_businesses:client:weaponPurchased'") == 1
    assert "if not weaponName:match('^WEAPON_[A-Z0-9_]+$') then return end" in client


if __name__ == "__main__":
    test_ammunation_client_uses_shared_blip_points_and_one_metre_prompt()
    test_ammunation_server_checks_shared_points_and_one_metre_range()
    test_ammunation_payment_is_atomic_and_weapon_metadata_is_persistent()
    test_inventory_contains_equipable_melee_weapons_and_mp5()
    test_ammunation_client_has_one_valid_weapon_delivery_handler()
    print("Ammu-Nation and weapon inventory checks passed.")
