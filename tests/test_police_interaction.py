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


def test_server_position_validation_uses_server_supported_health_native():
    server = read("resources/[FUNCTION]/rp_police_interaction/server/main.lua")
    assert "GetEntityHealth(ped) <= 0" in server
    assert "IsEntityDead(ped)" not in server

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


def test_vehicle_theft_detection_creates_mdt_dispatch_alert_immediately():
    server = read("resources/[FUNCTION]/rp_police_interaction/server/main.lua")
    client = read("resources/[FUNCTION]/rp_police_interaction/client/main.lua")
    assert "if offence == 'vehicle_theft' then" in server
    assert "title = details.label" in server
    assert "suspect = safeName(player, src)" in server
    assert "details = 'Vol de véhicule détecté automatiquement'" in server
    assert "alerts[#alerts + 1] = alert" in server
    assert "broadcastAlert(alert)" in server
    assert "return" in server[server.index("if offence == 'vehicle_theft' then"):server.index("TriggerClientEvent('rp_police_interaction:client:interpellation'")]
    assert "report('vehicle_theft')" in client
    assert "IsPedJacking(ped)" in client

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


def test_world_density_is_per_frame_but_police_dispatch_settings_are_not():
    world = read("resources/[FUNCTION]/rp_world/client/main.lua")
    police = read("resources/[FUNCTION]/rp_police_interaction/client/main.lua")
    density_loop = world.split("CreateThread(function()", 1)[1]
    assert "SetPedDensityMultiplierThisFrame" in density_loop
    assert "SetScenarioPedDensityMultiplierThisFrame" in density_loop
    assert "SetVehicleDensityMultiplierThisFrame" in density_loop
    assert "Wait(0)" in density_loop
    assert "ApplyPoliceSettings()" in world
    assert "AddEventHandler('playerSpawned', ApplyPoliceSettings)" in world
    assert "ApplyWantedSettings()" in police
    assert "AddEventHandler('playerSpawned', ApplyWantedSettings)" in police
    wanted_section = police.split("local function ApplyWantedSettings()", 1)[1]
    police_loop = wanted_section.split("CreateThread(function()", 1)[1].split("AddEventHandler('onResourceStop'", 1)[0]
    assert "SetMaxWantedLevel(0)" not in police_loop
    assert "SetPoliceIgnorePlayer" not in police_loop

if __name__ == "__main__":
    checks = [value for name, value in globals().items() if name.startswith("test_") and callable(value)]
    for check in checks:
        check()
    print(f"All {len(checks)} police interaction regression checks passed.")
