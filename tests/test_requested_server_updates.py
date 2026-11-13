from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_character_creator_preview_clothing_rotation_and_spawn_recovery():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    ui = read("resources/[CORE]/rp_characters/html/index.html")
    js = read("resources/[CORE]/rp_characters/html/js/app.js")
    assert "RegisterNUICallback('rotateCharacter'" in client
    assert "UpdateCreatorCamera()" in client
    assert "GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.25, 0.9)" in client
    assert "SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ" in client
    assert "RequestCollisionAtCoord(spawnX, spawnY, spawnZ)" in client
    assert "skin.components = {}" in server and "skin.props = {}" in server
    assert "rotate-character-left" in ui and "rotate-character-right" in ui
    assert "postNui('rotateCharacter'" in js


def test_creator_has_separate_tabs_for_each_requested_function():
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    for tab in ("weather", "announcement", "mapping", "blips", "configuration", "jobs", "gangs", "bank", "weapons"):
        assert f'data-tab="{tab}"' in html
        assert f'data-tab-panel="{tab}"' in html
    assert "Banque Job" in html
    assert "creator-weapon-list" in html
    assert "RegisterNetEvent('rp_tablet_creator:server:saveWeaponPolicy'" in server
    assert "RegisterNUICallback('saveWeaponPolicy'" in client
    assert "creator:weapon_policy_write" in server
    assert "creator-weapon-save" in ui


def test_admin_player_table_reports_and_map_teleport():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    assert "admin-player-table" in html and '<tbody id="players-list">' in html
    assert "function renderOnlinePlayers()" in ui and "admin-map-teleport" in html
    assert "teleportToMapPoint" in ui and "teleportToMapPoint" in client
    assert "AllowExtendedAction(src, 'teleport_map_point'" in server
    assert "RegisterCommand('rapport'" in client
    assert "player-report-overlay" in html and "player-report-submit" in ui
    assert "rp_tablet_admin:server:submitPlayerReport" in server
    assert "rawStatus == 'accepted'" in server
    assert "Votre rapport a bien été pris en charge par un membre du staff." in server
    assert "handled_by" in server
    assert 'data-admin-view="weapons"' not in html and 'id="admin-weapons-view"' not in html


def test_f4_salary_statistics_are_based_on_persisted_salary_transactions():
    server = read("resources/[FUNCTION]/rp_tablet_job/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_job/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_job/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_job/html/app.js")
    assert "rp_tablet_job:server:requestSalaryStats" in server
    assert "FROM bank_transactions bt" in server
    assert "WHERE bt.type = 'salary' AND bt.reason = ?" in server
    assert "rp_tablet_job:client:salaryStats" in client
    assert 'data-tab="stats"' in html and 'id="salary-chart"' in html
    assert "function renderSalaryStats(data)" in ui


def test_inventory_hides_balances_and_uses_per_item_artwork():
    html = read("resources/[FUNCTION]/rp_inventory/html/index.html")
    ui = read("resources/[FUNCTION]/rp_inventory/html/js/app.js")
    assert "inv-wallet" not in html and "cash-val" not in html and "bank-val" not in html
    assert "stable per-item hash" in ui and "const hue = Math.abs(hash) % 360" in ui
    assert "label = name.replace" in ui


def test_fuel_default_is_increased_and_creator_can_configure_it():
    config = read("resources/[FUNCTION]/rp_fuel/shared/config.lua")
    server = read("resources/[FUNCTION]/rp_fuel/server/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    assert "ConsumptionMultiplier = 3.5" in config
    assert "FuelConfig.ConsumptionMultiplier or 3.5" in server
    assert 'id="creator-fuel-consumption"' in html and 'value="3.5"' in html


def test_readme_only_contains_server_identity_jobs_and_feature_catalogue():
    readme = read("README.md")
    assert "# Los Santos Roleplay" in readme
    assert "**Slots :** 64" in readme
    assert "**Version :** Développement continu" in readme
    assert "## Métiers disponibles" in readme
    assert "50." in readme and "winemaker" in readme
    assert "## Fonctionnalités présentes" in readme


if __name__ == "__main__":
    checks = [
        test_character_creator_preview_clothing_rotation_and_spawn_recovery,
        test_creator_has_separate_tabs_for_each_requested_function,
        test_admin_player_table_reports_and_map_teleport,
        test_f4_salary_statistics_are_based_on_persisted_salary_transactions,
        test_inventory_hides_balances_and_uses_per_item_artwork,
        test_fuel_default_is_increased_and_creator_can_configure_it,
        test_readme_only_contains_server_identity_jobs_and_feature_catalogue,
    ]
    for check in checks:
        check()
    print(f"{len(checks)} requested-server regression checks passed.")
