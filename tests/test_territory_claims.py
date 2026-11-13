from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_territories_are_individual_weekly_claims():
    config = read("resources/[FUNCTION]/rp_territories/shared/config.lua")
    server = read("resources/[FUNCTION]/rp_territories/server/main.lua")
    assert "Config.Price = 100" in config
    assert "Config.DurationDays = 7" in config
    assert "owner_identifier" in server
    assert "owner_character_id" in server
    assert "expires_at" in server
    assert "player.removeBank(Config.Price" in server
    assert "DELETE FROM rp_territories WHERE expires_at <= ?" in server
    assert "sameOwner" in server


def test_map_contains_many_white_default_squares_and_claim_points():
    config = read("resources/[FUNCTION]/rp_territories/shared/config.lua")
    client = read("resources/[FUNCTION]/rp_territories/client/main.lua")
    assert "row = 0, 9" in config
    assert "column = 0, 5" in config
    assert "Config.AreaSize = 500.0" in config
    assert "AddBlipForArea" in client
    assert "AddBlipForCoord" in client
    assert "SetBlipColour(area, color)" in client
    assert "or 0" in client


def test_claim_server_validates_distance_color_and_prevents_overwrite():
    server = read("resources/[FUNCTION]/rp_territories/server/main.lua")
    assert "IsNearSector(src, sectorId)" in server
    assert "Config.ColorById[colorId]" in server
    assert "if active and not sameOwner then" in server
    assert "sectorLocks[sectorId]" in server
    assert "CanPerformAction(src, 'territory:claim', 4000)" in server


def test_territory_ui_exposes_color_choice_and_renewal():
    html = read("resources/[FUNCTION]/rp_territories/html/index.html")
    js = read("resources/[FUNCTION]/rp_territories/html/app.js")
    assert 'id="colors"' in html
    assert "renderColors" in js
    assert "Renouveler 7 jours" in js
    assert "Revendiquer le secteur" in js


def test_diagnostics_include_source_line_and_error_context():
    server = read("resources/[FUNCTION]/rp_territories/server/main.lua")
    client = read("resources/[FUNCTION]/rp_territories/client/main.lua")
    app = read("resources/[FUNCTION]/rp_territories/html/app.js")
    assert "[rp_territories][SERVER][%s:%d]" in server
    assert "[rp_territories][CLIENT][%s:%d]" in client
    assert "debug.getinfo(2, 'Sl')" in server
    assert "debug.getinfo(2, 'Sl')" in client
    assert "MAP_BUILD_CRASH" in client
    assert "CLAIM_SQL_WRITE_FAILED" in server
    assert "UNCAUGHT_JS_ERROR" in app
    assert "UNHANDLED_PROMISE" in app
    assert "new Error().stack" in app

def test_claim_points_have_streamed_npcs_and_reliable_e_interaction():
    config = read("resources/[FUNCTION]/rp_territories/shared/config.lua")
    client = read("resources/[FUNCTION]/rp_territories/client/main.lua")
    assert "Config.InteractionDistance = 1.0" in config
    assert "Config.PedModel" in config
    assert "Config.PedSpawnDistance" in config
    assert "CreatePed(4, model" in client
    assert "TaskStartScenarioInPlace" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "rp_territories:server:requestOpen" in client
    assert "PED_GROUND_NOT_FOUND" in client


def test_free_territory_areas_are_neutral_until_claimed():
    config = read("resources/[FUNCTION]/rp_territories/shared/config.lua")
    client = read("resources/[FUNCTION]/rp_territories/client/main.lua")
    server = read("resources/[FUNCTION]/rp_territories/server/main.lua")
    assert "Config.AreaAlphaFree = 0" in config
    assert "Config.ServerValidationDistance = 1.5" in config
    assert "SetBlipColour(area, color)" in client
    assert "SetBlipDisplay(area, 3)" in client
    assert "SetBlipDisplay(point, 3)" in client
    build_map = client.split("local function BuildMap()", 1)[1].split("RegisterNetEvent('rp_territories:client:sync'", 1)[0]
    assert "RemoveMapBlips()" not in build_map
    assert "local area = areaBlips[index]" in build_map
    assert "local point = pointBlips[index]" in build_map
    assert "MENU_AUTO_CLOSED" in client
    assert "vector3(sector.x, sector.y, sector.z)) > 1.0" in client
    assert "verticalDistance <= 2.0" in client
    assert "local verticalNear = math.abs(coords.z - sector.z) <= 2.0" in server



def test_territory_tablet_uses_bank_payment_and_persists_custom_name():
    server = read("resources/[FUNCTION]/rp_territories/server/main.lua")
    html = read("resources/[FUNCTION]/rp_territories/html/index.html")
    js = read("resources/[FUNCTION]/rp_territories/html/app.js")
    assert "territory_name VARCHAR(64)" in server
    assert "SHOW COLUMNS FROM rp_territories LIKE 'territory_name'" in server
    assert "player.removeBank(Config.Price" in server
    assert "player.addBank(Config.Price" in server
    assert "territory_name = VALUES(territory_name)" in server
    assert "ownerName = active" in server
    assert "territoryName = active" in server
    assert 'id="territory-name"' in html
    assert 'id="owner-name"' in html
    assert 'id="bank-balance"' in html
    assert "post('claim', {sectorId: currentInfo.sectorId, colorId: selectedColor, territoryName})" in js


def test_territories_are_pause_map_only_with_grouped_flag_icons_and_quiet_textui():
    config = read("resources/[FUNCTION]/rp_territories/shared/config.lua")
    client = read("resources/[FUNCTION]/rp_territories/client/main.lua")
    assert "Config.PointBlipSprite = 38" in config
    assert "SetBlipDisplay(area, 3)" in client
    assert "SetBlipDisplay(point, 3)" in client
    assert "SetBlipCategory(point, 12)" in client
    assert "AddTextEntry('BLIP_CAT_12', 'Territoires')" in client
    assert "AddTextComponentString('Territoires')" in client
    assert "exports['rp_ui']:ShowTextUI" in client
    assert "exports['rp_ui']:HideTextUI" in client
    assert "DrawMarker(1, nearestSector" not in client
    assert "EndTextCommandDisplayHelp(0, false, true" not in client
