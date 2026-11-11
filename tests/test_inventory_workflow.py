from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_inventory_server_refresh_does_not_force_open_on_recipient():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    client = read("resources/[FUNCTION]/rp_inventory/client/main.lua")
    assert "TriggerClientEvent('rp_inventory:updateData', src, payload)" in server
    assert "TriggerClientEvent('rp_inventory:receiveData', src, payload)" in server
    assert "if type(data) ~= 'table' or not isInventoryOpen then return end" in client
    assert "sendInventory(src, player, true)" in server


def test_item_use_persists_inventory_and_character_needs_atomically():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    use = server[server.index("RegisterNetEvent('rp_inventory:useItem'"):server.index("RegisterNetEvent('rp_inventory:giveItem'")]
    assert "MySQL.transaction.await" in use
    assert "UPDATE characters SET metadata = ? WHERE id = ? AND identifier = ?" in use
    assert "INSERT INTO player_inventories (character_id, items)" in use
    assert "AcquireCharacterLock" in use and "ReleaseCharacterLock" in use


def test_giving_items_checks_distance_weight_and_commits_both_inventories():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    give = server[server.index("RegisterNetEvent('rp_inventory:giveItem'"):server.index("-- Les objets au sol")]
    assert "GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId)" in give
    assert "GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)" in give
    assert "getInventoryWeight(targetInventory) + definition.weight * count > Config.MaxWeight" in give
    assert give.count("INSERT INTO player_inventories (character_id, items)") == 2
    assert "MySQL.transaction.await" in give
    assert "AcquireCharacterLock({ player.charId, target.charId })" in give


def test_ground_drop_and_pickup_are_server_validated_and_persisted():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    client = read("resources/[FUNCTION]/rp_inventory/client/main.lua")
    drop = server[server.index("RegisterNetEvent('rp_inventory:dropItem'"):server.index("RegisterNetEvent('rp_inventory:server:pickupDrop'")]
    pickup = server[server.index("RegisterNetEvent('rp_inventory:server:pickupDrop'"):server.index("AddEventHandler('playerDropped'")]
    assert "CreateObjectNoOffset(DROP_MODEL" in drop
    assert "AcquireCharacterLock" in drop and "ON DUPLICATE KEY UPDATE" in drop
    assert "dropLocks[dropId]" in pickup
    assert "GetEntityCoords(drop.entity)" in pickup
    assert "getInventoryWeight(updated) + definition.weight * drop.count > Config.MaxWeight" in pickup
    assert "TriggerServerEvent('rp_inventory:server:pickupDrop'" in client
    assert "IsControlJustReleased(0, 38)" in client


def test_inventory_cache_is_reloaded_for_a_different_active_character():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert server.count("inventoryCharacterIds[src] ~= player.charId") >= 4


def test_inventory_client_and_ui_handle_incremental_server_refreshes():
    client = read("resources/[FUNCTION]/rp_inventory/client/main.lua")
    app = read("resources/[FUNCTION]/rp_inventory/html/js/app.js")
    assert "RegisterNetEvent('rp_inventory:updateData'" in client
    assert "data.action === 'open' || data.action === 'update'" in app
    assert "items.find(item => item.name === selectedItem.name)" in app
