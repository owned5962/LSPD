from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "resources/[FUNCTION]/rp_vehicle_loot/client/main.lua"
SERVER = ROOT / "resources/[FUNCTION]/rp_vehicle_loot/server/main.lua"


def test_tire_removal_is_disabled_on_client_and_server():
    client = CLIENT.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")

    assert "local ENABLE_TIRE_REMOVAL = false" in client
    assert "if ENABLE_TIRE_REMOVAL then" in client
    assert "local ENABLE_TIRE_REMOVAL = false" in server
    assert "if not ENABLE_TIRE_REMOVAL then return end" in server


def test_server_rejects_forged_start_and_completion_events_while_disabled():
    server = SERVER.read_text(encoding="utf-8")

    start = server.split("RegisterNetEvent('rp_vehicle_loot:server:startTire'", 1)[1]
    start = start.split("RegisterNetEvent('rp_vehicle_loot:server:cancelTire'", 1)[0]
    complete = server.split("RegisterNetEvent('rp_vehicle_loot:server:completeTire'", 1)[1]
    complete = complete.split("AddEventHandler('playerDropped'", 1)[0]

    assert "if not ENABLE_TIRE_REMOVAL then return end" in start
    assert "if not ENABLE_TIRE_REMOVAL then return end" in complete
