from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE = ROOT / "resources" / "[FUNCTION]" / "rp_drivingschool"


def read(relative):
    return (RESOURCE / relative).read_text(encoding="utf-8")


def test_five_license_categories_and_exam_configuration():
    config = read("config.lua")
    for category in ("moto", "voiture", "avion", "bateau", "helicoptere"):
        assert category + " =" in config
    assert config.count("questions = {") == 5
    assert "PassMark = 4" in config
    assert "model = 'bati'" in config
    assert "model = 'blista'" in config
    assert "model = 'dodo'" in config
    assert "model = 'seashark'" in config
    assert "model = 'maverick'" in config


def test_server_owns_theory_scoring_and_practical_checkpoint_validation():
    server = read("server/main.lua")
    assert "question.correct" in server
    assert "score < Config.PassMark" in server
    assert "NetworkGetEntityOwner(entity) ~= src" in server
    assert "GetPedInVehicleSeat(entity, -1) ~= ped" in server
    assert "GetEntityModel(entity) ~= GetHashKey(definition.model)" in server
    assert "Config.CheckpointRadius" in server
    assert "INSERT IGNORE INTO rp_driving_licenses" in server
    assert "player.charId ~= session.characterId" in server


def test_client_and_nui_are_registered_and_started():
    manifest = read("fxmanifest.lua")
    client = read("client/main.lua")
    html = read("html/index.html")
    js = read("html/app.js")
    css = read("html/style.css")
    cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    database = (ROOT / "database.sql").read_text(encoding="utf-8")
    for path in ("config.lua", "client/main.lua", "server/main.lua", "html/index.html", "html/style.css", "html/app.js"):
        assert path in manifest
        assert (RESOURCE / path).is_file()
    assert "rp_drivingschool:server:startTheory" in client
    assert "rp_drivingschool:server:submitTheory" in client
    assert "rp_drivingschool:server:checkpointReached" in client
    assert "rp_drivingschool" in cfg
    assert "rp_driving_licenses" in database
    assert "UNIQUE KEY `uq_rp_driving_license_character_category`" in database
    assert "submitTheory" in js
    assert "startTheory" in js
    assert 'id="catalog"' in html
    assert 'id="exam"' in html
    assert "escapeHtml" not in js  # All displayed strings use textContent, not HTML injection.


if __name__ == "__main__":
    test_five_license_categories_and_exam_configuration()
    test_server_owns_theory_scoring_and_practical_checkpoint_validation()
    test_client_and_nui_are_registered_and_started()
    print("Driving school regression checks passed.")
