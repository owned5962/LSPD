from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADMIN = ROOT / "resources/[FUNCTION]/rp_tablet_admin"
CREATOR = ROOT / "resources/[FUNCTION]/rp_tablet_creator"


def test_f10_key_mapping_and_manual_commands_are_registered():
    client = (ADMIN / "client/main.lua").read_text(encoding="utf-8")
    assert "RegisterCommand('rp_admin_tablet_toggle', ToggleAdminTablet, false)" in client
    assert "RegisterKeyMapping('rp_admin_tablet_toggle', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')" in client
    assert "RegisterCommand('admin', ToggleAdminTablet, false)" in client
    assert "RegisterCommand('adminmenu', ToggleAdminTablet, false)" in client


def test_admin_open_waits_for_server_and_reports_denial_or_timeout():
    client = (ADMIN / "client/main.lua").read_text(encoding="utf-8")
    assert "local isAdminOpening = false" in client
    assert "isAdminOpening = true" in client
    assert "SetTimeout(7000" in client
    assert "rp_tablet_admin:client:openDenied" in client
    assert "isAdminOpening = false" in client
    assert "rp_tablet_admin:server:requestOpen" in client


def test_server_checks_admin_permissions_and_returns_explicit_open_result():
    server = (ADMIN / "server/main.lua").read_text(encoding="utf-8")
    event = server.split("RegisterNetEvent('rp_tablet_admin:server:requestOpen'", 1)[1].split("RegisterNetEvent('rp_tablet_admin:server:saveWeaponPolicy'", 1)[0]
    assert "IsPlayerAdmin(src)" in event
    assert "CanUseTablet(src, 'admin')" in event
    assert "rp_tablet_admin:client:openDenied" in event
    assert "rp_tablet_admin:client:openAuthorized" in event
    assert "local buildOk, payload = pcall(function()" in event
    assert "rp_jobs:GetAllJobs indisponible" in event


def test_admin_role_matching_is_case_insensitive_and_creator_tables_wait_for_mysql():
    server = (ADMIN / "server/main.lua").read_text(encoding="utf-8")
    creator = (CREATOR / "server/main.lua").read_text(encoding="utf-8")
    assert "tostring(player.group or ''):lower()" in server
    assert "MySQL.ready(function()" in creator
    assert "for attempt = 1, 10 do" in creator
    assert "ensureCreatorTables()" in creator


if __name__ == "__main__":
    test_f10_key_mapping_and_manual_commands_are_registered()
    test_admin_open_waits_for_server_and_reports_denial_or_timeout()
    test_server_checks_admin_permissions_and_returns_explicit_open_result()
    test_admin_role_matching_is_case_insensitive_and_creator_tables_wait_for_mysql()
    print("Admin F10 workflow checks passed.")
