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


def test_rental_price_and_server_side_validation():
    config = read("config.lua")
    server = read("server/main.lua")
    assert "Config.PricePerTenMinutes = 100" in config
    assert "Config.MaxHours = 12" in config
    assert "validDuration" in server
    assert "chargePlayer(src, cost" in server
    assert "CanPerformAction" in server


def test_rental_expiry_and_vehicle_return_flow():
    server = read("server/main.lua")
    client = read("client/main.lua")
    assert "renewalRequired" in server
    assert "ExpiryGraceSeconds" in server
    assert "forceReturn" in server
    assert "TaskLeaveVehicle" in client
    assert "SetVehicleDoorsLockedForAllPlayers" in client
    assert "drawTimer" in client
