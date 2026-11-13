from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "resources" / "[FUNCTION]" / "rp_vehicle_rental"


def read(relative):
    return (RESOURCE / relative).read_text(encoding="utf-8")


def test_rental_resource_is_registered_and_has_all_spawn_locations():
    manifest = read("fxmanifest.lua")
    config = read("config.lua")
    for path in ("client/main.lua", "server/main.lua", "html/index.html", "html/css/style.css", "html/js/app.js"):
        assert path in manifest
        assert (RESOURCE / path).is_file()
    for location in ("airport", "train", "hospital", "jobcenter"):
        assert f"{location} =" in config
    assert "Config.MapBlip" in config
    assert "sprite = 225" in config
    assert "enabled = true" in config
    assert "createRentalBlips()" in read("client/main.lua")
    assert "AddBlipForCoord" in read("client/main.lua")
    assert "RemoveBlip" in read("client/main.lua")


def test_rental_price_and_server_side_validation():
    config = read("config.lua")
    server = read("server/main.lua")
    assert "Config.PricePerTenMinutes = 100" in config
    assert "Config.MaxHours = 12" in config
    assert "Config.InteractionDistance = 2.0" in config
    assert "Config.InteractionDistance) or 2.0" in server
    assert "validDuration" in server
    assert "chargePlayer(src, cost" in server
    assert "CanPerformAction" in server


def test_rental_expiry_and_vehicle_return_flow():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "renewalRequired" in server
    assert "ExpiryGraceSeconds" in server
    assert "forceReturn" in server
    assert "refundRental" in server
    assert "calculateUnusedRefund" in server
    assert "AddEventHandler('onResourceStop'" in server
    assert "refundAmount" in server
    assert "rental.amount = cost" in server
    register_handler = server.split("RegisterNetEvent('rp_vehicle_rental:server:registerVehicle'", 1)[1].split("RegisterNetEvent('rp_vehicle_rental:server:spawnFailed'", 1)[0]
    assert "Never delete an arbitrary client-owned entity" in register_handler
    assert "DeleteEntity(entity)" not in register_handler
    assert "TaskLeaveVehicle" in client
    assert "SetVehicleDoorsLockedForAllPlayers" in client
    assert "drawTimer" in client


if __name__ == "__main__":
    test_rental_resource_is_registered_and_has_all_spawn_locations()
    test_rental_price_and_server_side_validation()
    test_rental_expiry_and_vehicle_return_flow()
    print("Vehicle rental regression checks passed.")
