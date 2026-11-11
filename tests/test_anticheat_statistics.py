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

if __name__ == "__main__":
    test_statistics_are_persistent_and_access_controlled()
    print("Anticheat statistics checks passed.")
