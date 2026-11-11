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
    assert "items_snapshot LONGTEXT NULL" in server
    assert "weapons_snapshot LONGTEXT NULL" in server
    assert "cash_snapshot BIGINT NULL" in server and "bank_snapshot BIGINT NULL" in server
    assert "job_grade_label VARCHAR(100) NULL" in server
    assert "capturePlayerSnapshot(src)" in server
    assert "GetPlayerInventory" in server and "exports('GetPlayerInventory'" in read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert "type(GetPedWeapons) == 'function'" in server
    assert "Never trust a client-reported loadout" in server
    assert "snapshot.items" in server and "snapshot.weapons" in server
    assert "alert.snapshotAvailable = alert.snapshot ~= nil" in server
    assert "alert.jobGradeLabel = snapshot.jobGradeLabel" in server
    assert "items_snapshot AS itemsSnapshot" in server
    assert "buildSnapshotDetails(log)" in ui
    assert "OBJETS" in ui and "ARMES" in ui and "BANQUE" in ui
    assert "rp_inventory" in read("resources/[FUNCTION]/rp_anticheat/fxmanifest.lua")
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




def test_weapon_policy_is_persistent_and_drives_client_and_server_anticheat():
    config = read("resources/[FUNCTION]/rp_anticheat/shared/config.lua")
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    assert "Config.WeaponCatalog" in config and "Config.WeaponPolicy" in config
    weapon_names = [line.split("name = '", 1)[1].split("'", 1)[0] for line in config.splitlines() if "name = 'WEAPON_" in line]
    assert len(weapon_names) >= 100
    assert len(weapon_names) == len(set(weapon_names))
    assert "CREATE TABLE IF NOT EXISTS anticheat_weapon_rules" in server
    assert "INSERT IGNORE INTO anticheat_weapon_rules" in server
    assert "exports('GetWeaponPolicy'" in server
    assert "exports('IsWeaponAllowed'" in server
    assert "exports('SaveWeaponPolicy'" in server
    assert "MySQL.transaction.await(queries)" in server
    assert "TriggerClientEvent('rp_anticheat:syncWeaponPolicy', -1" in server
    assert "Config.WeaponHashToName[weaponType]" in server
    assert "Config.WeaponPolicy[weaponName] ~= true" in server
    assert "RegisterNetEvent('rp_anticheat:requestWeaponPolicy'" in server
    assert "RegisterNetEvent('rp_anticheat:syncWeaponPolicy'" in client
    assert "Config.WeaponPolicy = policy" in client
    assert "Config.BlacklistedWeapons" in client
    assert "RemoveWeaponFromPed(ped, weaponHash)" in client
    assert "weaponHash == nil" not in server


def test_anticheat_tablet_javascript_is_not_duplicated_or_corrupted():
    import re

    ui = read("resources/[FUNCTION]/rp_anticheat/html/js/app.js")
    declarations = re.findall(r"^function\s+([A-Za-z_$][\w$]*)\s*\(", ui, re.MULTILINE)
    duplicates = sorted({name for name in declarations if declarations.count(name) > 1})
    assert not duplicates, f"duplicate Anticheat UI functions: {duplicates}"
    assert ui.count("window.setInterval(updateClock, 1000)") == 1
    assert ui.count("window.addEventListener('message'") == 1
    assert "function buildSnapshotDetails(snapshot)" in ui
    assert "function renderPlayerDetail()" in ui
    assert "function renderLogs()" in ui
    assert "detailCell.colSpan = 6" in ui
    assert "snapshot.cash == null" in ui
    assert "snapshot.bank == null" in ui
    assert "const panel = $('player-detail');" in ui
    assert "+ Number(snapshot.cash)" not in ui
    assert "+ Number(snapshot.bank)" not in ui


if __name__ == "__main__":
    test_statistics_are_persistent_and_access_controlled()
    test_weapon_policy_is_persistent_and_drives_client_and_server_anticheat()
    test_anticheat_tablet_javascript_is_not_duplicated_or_corrupted()
    print("Anticheat statistics checks passed.")
