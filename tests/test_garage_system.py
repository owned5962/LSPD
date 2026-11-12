from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]  # Repository root for isolated garage, ownership and tuning checks.
RESOURCE = ROOT / "resources" / "[FUNCTION]" / "rp_garages"


def read(relative):
    return (RESOURCE / relative).read_text(encoding="utf-8")


def test_garage_resource_is_registered_and_started_after_dealership():
    manifest = read("fxmanifest.lua")
    config = read("config.lua")
    server_cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    for path in ("config.lua", "client/main.lua", "server/main.lua", "html/index.html", "html/style.css", "html/app.js"):
        assert path in manifest
        assert (RESOURCE / path).is_file()
    for garage in ("legion", "sandy", "paleto"):
        assert f"id = '{garage}'" in config
    assert "ensure rp_vehicle_dealership" in server_cfg
    assert "ensure rp_garages" in server_cfg
    assert server_cfg.index("ensure rp_vehicle_dealership") < server_cfg.index("ensure rp_garages")


def test_garage_storage_is_server_validated_and_persisted():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "WHERE plate = ? AND character_id = ? AND identifier = ?" in server
    assert "GetPedInVehicleSeat(vehicle, -1) ~= ped" in server
    assert "GetEntityModel(vehicle) ~= GetHashKey(tostring(owned.model))" in server
    assert "UPDATE rp_owned_vehicles SET stored = 1, vehicle_props = ?" in server
    assert "DeleteEntity(vehicle)" in server
    assert "captureVehicleProperties(vehicle)" in client
    assert "TriggerServerEvent('rp_garages:server:store'" in client
    assert "validProps(rawProps" in server


def test_garage_retrieval_uses_stored_owner_record_and_spawn_ack():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "WHERE id = ? AND character_id = ? AND identifier = ? LIMIT 1" in server
    assert "tonumber(row.stored) ~= 1" in server
    assert "UPDATE rp_owned_vehicles SET stored = 0" in server
    assert "UPDATE rp_owned_vehicles SET stored = 1" in server
    assert "NetworkGetEntityOwner(entity) ~= src" in server
    assert "GetVehicleNumberPlateText(entity)" in server
    assert "TriggerServerEvent('rp_garages:server:spawned'" in client
    assert "applyVehicleProperties(vehicle, data.props)" in client
    assert "SetNetworkIdCanMigrate(netId, true)" in client


def test_garage_ui_has_store_and_retrieve_controls():
    html = read("html/index.html")
    js = read("html/app.js")
    assert 'id="store"' in html
    assert 'id="vehicle-list"' in html
    assert "post('retrieveVehicle'" in js
    assert "post('storeVehicle')" in js
    assert "escapeHtml" in js


if __name__ == "__main__":
    test_garage_resource_is_registered_and_started_after_dealership()
    test_garage_storage_is_server_validated_and_persisted()
    test_garage_retrieval_uses_stored_owner_record_and_spawn_ack()
    test_garage_ui_has_store_and_retrieve_controls()
    print("Garage regression checks passed.")


def test_workshop_tuning_is_server_priced_and_persisted():
    config = read("config.lua")
    server = read("server/main.lua")
    client = read("client/main.lua")
    html = read("html/index.html")
    js = read("html/app.js")
    assert "Config.Workshops" in config
    assert "[11] = { id = 'engine'" in config
    assert "[18] = { id = 'turbo'" in config
    assert "rp_garages:server:openWorkshop" in server
    assert "getOwnedDrivenVehicle" in server
    assert "Config.TuningCategories[modType]" in server
    assert "player.removeBank, price" in server
    assert "rp_garages:server:saveTune" in server
    assert "UPDATE rp_owned_vehicles SET vehicle_props = ?" in server
    assert "refundPendingTune" in server
    assert "rp_garages:client:applyPurchasedTune" in client
    assert "rp_garages:client:tuneRollback" in client
    assert "GetNumVehicleMods(vehicle, modType)" in client
    assert "id=\"tuning-category\"" in html
    assert "id=\"tuning-level\"" in html
    assert "post('previewTune'" in js
    assert "post('buyTune'" in js
    assert "alreadyInstalled" in js


if __name__ == "__main__":
    test_workshop_tuning_is_server_priced_and_persisted()
