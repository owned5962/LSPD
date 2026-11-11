from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def test_police_interaction_resource_is_registered_after_world():
    cfg = read("server.cfg")
    assert "ensure rp_police_interaction" in cfg
    assert cfg.index("ensure rp_world") < cfg.index("ensure rp_police_interaction")
    assert "resources/[FUNCTION]/rp_police_interaction" in str(ROOT / "resources/[FUNCTION]/rp_police_interaction")

def test_wanted_stars_remain_disabled():
    world = read("resources/[FUNCTION]/rp_world/client/main.lua")
    police = read("resources/[FUNCTION]/rp_police_interaction/client/main.lua")
    for source in (world, police):
        assert "SetMaxWantedLevel(0)" in source
        assert "SetPlayerWantedLevel" in source
        assert "SetPoliceIgnorePlayer" in source

def test_all_confirmed_offences_have_server_owned_labels():
    config = read("resources/[FUNCTION]/rp_police_interaction/config.lua")
    for offence in ("assault_npc", "assault_player", "murder_npc", "murder_player",
                    "public_shooting", "vehicle_theft", "pedestrian_collision"):
        assert offence in config
    server = read("resources/[FUNCTION]/rp_police_interaction/server/main.lua")
    assert "Config.Offences[offence]" in server
    assert "CanPerformAction" in server

def test_surrender_and_refusal_have_distinct_server_and_client_paths():
    client = read("resources/[FUNCTION]/rp_police_interaction/client/main.lua")
    server = read("resources/[FUNCTION]/rp_police_interaction/server/main.lua")
    assert "RegisterNUICallback('surrender'" in client
    assert "Config.Prison.x" in client and "Config.SurrenderFreezeMs" in client
    assert "FreezeEntityPosition(ped, true)" in client
    assert "RegisterNUICallback('refuse'" in client
    assert "TaskCombatPed(activeOfficer, PlayerPedId()" in client
    assert "rp_police_interaction:server:refused" in client
    assert "broadcastAlert(alert)" in server

def test_dispatch_alerts_are_limited_to_police_on_duty():
    server = read("resources/[FUNCTION]/rp_police_interaction/server/main.lua")
    tablet_client = read("resources/[FUNCTION]/rp_tablet_job/client/main.lua")
    tablet_html = read("resources/[FUNCTION]/rp_tablet_job/html/index.html")
    tablet_ui = read("resources/[FUNCTION]/rp_tablet_job/html/app.js")
    assert "player.job == 'police'" in server
    assert "exports['job_police']:IsOnDuty" in server
    assert "rp_tablet_job:client:policeAlert" in server
    assert "currentJob == 'police' and currentDuty" in tablet_client
    assert 'data-tab="police"' in tablet_html
    assert "policeWaypoint" in tablet_client and "markPoliceAlert" in tablet_client
    assert "GPS suspect" in tablet_ui and "Prendre en charge" in tablet_ui

if __name__ == "__main__":
    checks = [value for name, value in globals().items() if name.startswith("test_") and callable(value)]
    for check in checks:
        check()
    print(f"All {len(checks)} police interaction regression checks passed.")
