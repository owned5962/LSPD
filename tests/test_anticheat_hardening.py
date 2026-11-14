from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


SERVER_PATH = "resources/[FUNCTION]/rp_anticheat/server/main.lua"


def test_client_reported_flags_never_trigger_automatic_sanctions():
    server = read(SERVER_PATH)
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    start = server.index("local function recordDetection(")
    end = server.index("-- Server-side resources can report trusted detections", start)
    recorder = server[start:end]

    assert "sourceKind = trustedServerEvent == true and 'server' or 'client'" in recorder
    assert "or 'review'" in recorder
    assert "if trustedServerEvent == true and persisted then" in recorder
    assert "lastFlagAt[src][sourceKind]" in recorder
    assert "RegisterNetEvent('rp_anticheat:flag'" in server
    flag_start = server.index("RegisterNetEvent('rp_anticheat:flag'")
    flag_end = server.index("RegisterNetEvent('rp_anticheat:requestSpectate'", flag_start)
    assert "recordDetection(src, reason)" in server[flag_start:flag_end]
    assert "recordDetection(src, 'Arme interdite détectée : ' .. weaponName, true)" in server
    assert "recordDetection(owner, 'Entity spam détecté', true)" in server
    assert "recordDetection(src, 'Explosion spam détecté', true)" in server
    assert "Signalement client — vérification manuelle requise" in read(
        "resources/[FUNCTION]/rp_anticheat/html/js/app.js"
    )
    assert "PREUVE SERVEUR" in client and "SIGNAL CLIENT À VÉRIFIER" in client


def test_detection_audit_is_required_before_automatic_sanction():
    server = read(SERVER_PATH)
    start = server.index("local function recordDetection(")
    end = server.index("-- Server-side resources can report trusted detections", start)
    recorder = server[start:end]
    assert "anticheat_event_log" in recorder
    assert "source_type" in recorder
    assert "or 'review'" in recorder
    assert "if trustedServerEvent == true and persisted then" in recorder


def test_protection_and_prison_settings_persist_and_sync_to_late_joiners():
    server = read(SERVER_PATH)
    database = read("database.sql")
    assert "CREATE TABLE IF NOT EXISTS anticheat_protection_config" in server
    assert "CREATE TABLE IF NOT EXISTS anticheat_runtime_config" in server
    assert "local function loadProtectionConfig()" in server
    assert "local function loadRuntimeConfig()" in server
    assert "loadProtectionConfig()" in server and "loadRuntimeConfig()" in server
    assert "MySQL.transaction.await" in server
    assert "prison_minutes" in server
    assert "INSERT INTO anticheat_protection_config" in server
    assert "syncProtections', src, Config.Protections" in server
    assert "anticheat_protection_config" in database
    assert "anticheat_runtime_config" in database
    assert "CREATE TABLE IF NOT EXISTS `anticheat_event_log`" in database
    assert "`source_type` VARCHAR(16) NOT NULL DEFAULT 'legacy'" in database
    assert "PREPARE rp_aegis_source_type_stmt" in database
    assert not (ROOT / "migrations").exists()


def test_moderation_protects_staff_hierarchy_and_writes_audit_logs():
    server = read(SERVER_PATH)
    assert "local function isFounder(src)" in server
    assert "local function canModerateTarget(src, targetId)" in server
    assert "local function getStaffLevel(src)" in server
    assert "return targetLevel == 0 or getStaffLevel(src) > targetLevel" in server
    assert "local function recordAdminAudit(adminId, action, targetId, details)" in server
    assert "INSERT INTO admin_logs" in server
    punish_start = server.index("RegisterNetEvent('rp_anticheat:punish'")
    punish_end = server.index("RegisterNetEvent('rp_anticheat:prisonExpired'", punish_start)
    punish = server[punish_start:punish_end]
    assert "if not canModerateTarget(src, targetId) then" in punish
    for action in ("anticheat_manual_warn", "anticheat_manual_prison", "anticheat_manual_ban", "anticheat_manual_kick"):
        assert action in punish
    assert "anticheat_unban" in server
    assert "anticheat_auto_ban" in server


def test_prison_confinement_is_enforced_by_server_not_only_client():
    server = read(SERVER_PATH)
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    assert "local activeJails = {}" in server
    assert "GetEntityCoords(ped)" in server
    assert "SetEntityCoords(ped, jailCoords.x, jailCoords.y, jailCoords.z" in server
    assert "Config.PrisonRadius" in server
    assert "jail.endsAt <= os.time()" in server
    assert "RegisterNetEvent('rp_anticheat:prisonExpired'" in server
    assert "if not jail or jail.endsAt > os.time() then return end" in server
    assert "prisonCenter" in client


def test_policy_requests_are_rate_limited_and_staff_access_remains_server_checked():
    server = read(SERVER_PATH)
    assert "policyRequestAt[src] and now - policyRequestAt[src] < 3" in server
    assert "if not isStaff(src) or not canUseAnticheatTablet(src)" in server
    assert "RegisterNetEvent('rp_anticheat:toggleProtection'" in server
    assert "RegisterNetEvent('rp_anticheat:saveSanctionConfig'" in server
    assert "CanUseTablet(src, 'anticheat')" in server


if __name__ == "__main__":
    checks = [
        test_client_reported_flags_never_trigger_automatic_sanctions,
        test_detection_audit_is_required_before_automatic_sanction,
        test_protection_and_prison_settings_persist_and_sync_to_late_joiners,
        test_moderation_protects_staff_hierarchy_and_writes_audit_logs,
        test_prison_confinement_is_enforced_by_server_not_only_client,
        test_policy_requests_are_rate_limited_and_staff_access_remains_server_checked,
    ]
    for check in checks:
        check()
    print(f"All {len(checks)} AEGIS hardening checks passed.")
