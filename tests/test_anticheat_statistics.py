from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

def test_statistics_are_persistent_and_access_controlled():
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    html = read("resources/[FUNCTION]/rp_anticheat/html/index.html")
    ui = read("resources/[FUNCTION]/rp_anticheat/html/js/app.js")
    css = read("resources/[FUNCTION]/rp_anticheat/html/css/style.css")
    assert "CREATE TABLE IF NOT EXISTS anticheat_detections" in server
    assert "INSERT INTO anticheat_detections" in server
    assert "RegisterNetEvent('rp_anticheat:requestStatistics'" in server
    assert "if not isStaff(src) or not canUseAnticheatTablet(src)" in server
    assert "DATE_FORMAT(created_at, ?)" in server
    assert "RecordServerDetection" in server
    assert "trustedServerEvent == true" in server
    assert "RegisterNUICallback('requestStatistics'" in client
    assert "rp_anticheat:updateStatistics" in client
    assert 'data-tab="statistics"' in html and 'id="pane-statistics"' in html
    assert 'id="stats-period"' in html
    for category in ("godmode", "money", "vehicle_spawn", "weapon_spawn", "weapon_blacklist", "speedhack", "gravity", "spam"):
        assert category in ui
    for severity in ("low", "medium", "high", "critical"):
        assert "severity-" + severity in css
    assert "Une détection est un signal" in html
    assert 'id="nav-surveillance"' in html and 'disabled aria-disabled="true"' in html
    assert 'id="nav-surveillance-count"' in html
    assert 'data-tab="configuration"' in html and 'id="pane-configuration"' in html
    assert "anticheat_event_log" in server
    assert "INSERT INTO anticheat_event_log" in server
    assert "sanction VARCHAR(16)" in server and "alert.sanction" in server
    assert "ORDER BY id DESC LIMIT 250" in server
    logs_query = server[server.index("RegisterNetEvent('rp_anticheat:requestLogs'"):server.index("RegisterNetEvent('rp_anticheat:requestSanctionConfig'")]
    assert "severity, sanction" in logs_query
    assert "detectionCount" in server and "totalDetections" in server
    assert "RegisterNetEvent('rp_anticheat:saveSanctionConfig'" in server
    assert "applyConfiguredSanction(src, alert)" in server
    assert "warn = true" in server and "kick = true" in server and "ban = true" in server and "prison = true" in server
    assert "CREATE TABLE IF NOT EXISTS anticheat_jails" in server
    assert "RegisterNetEvent('rp_anticheat:prisonExpired'" in server
    assert "Config.Sanctions" in read("resources/[FUNCTION]/rp_anticheat/shared/config.lua")
    assert "RegisterNUICallback('saveSanctionConfig'" in client
    assert "RegisterNetEvent('rp_anticheat:applyPrison'" in client
    assert "function updateSurveillanceTab()" in ui
    assert "function renderSanctionConfig()" in ui
    assert "Non défini" in ui and "log.sanction" in ui
    assert "function saveSanctionConfig()" in ui

if __name__ == "__main__":
    test_statistics_are_persistent_and_access_controlled()
    print("Anticheat statistics checks passed.")
