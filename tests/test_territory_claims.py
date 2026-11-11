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
    assert "player.removeCash(Config.Price)" in server
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
