from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_f4_tablet_uses_core_server_duty_not_client_reported_state():
    server = read("resources/[FUNCTION]/rp_tablet_job/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_job/client/main.lua")
    assert "duty = player.duty == true" in server
    assert "duty = member.duty == true" in server
    assert "rp_tablet_job:server:setDutyState" not in server
    assert "rp_tablet_job:server:setDutyState" not in client
    assert "player.duty ~= true" in server


def test_f4_missions_are_server_catalogued_and_bound_to_character_and_job():
    server = read("resources/[FUNCTION]/rp_tablet_job/server/main.lua")
    assert "local catalog = {" in server
    assert "local description = type(title) == 'string' and catalog[player.job] and catalog[player.job][title]" in server
    assert "description = description" in server
    assert "characterId = tonumber(player.charId)" in server
    assert "jobName = player.job" in server
    assert "tonumber(mission.characterId) ~= tonumber(player.charId)" in server


def test_f4_tablet_validates_opening_and_police_waypoint_payload():
    client = read("resources/[FUNCTION]/rp_tablet_job/client/main.lua")
    assert "player.job == 'unemployed'" in client
    assert "math.abs(x) > 5000 or math.abs(y) > 5000" in client
    assert "alertId % 1 ~= 0" in client
    assert "status ~= 'Pris en charge' and status ~= 'Clôturée'" in client


def test_f4_tablet_nui_handles_failed_requests_and_prevents_double_bank_submission():
    ui = read("resources/[FUNCTION]/rp_tablet_job/html/app.js")
    assert "if (!response.ok) throw new Error" in ui
    assert "let jobBankSubmitting = false" in ui
    assert "if (jobBankSubmitting) return" in ui
    assert "textContent = 'La communication avec le serveur a échoué." in ui
