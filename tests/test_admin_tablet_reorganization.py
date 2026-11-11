from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding="utf-8")

class IdCollector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
    def handle_starttag(self, tag, attrs):
        for key, value in attrs:
            if key == "id" and value:
                self.ids.append(value)

def test_admin_tabs_and_page_controls_are_separated():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    parser = IdCollector()
    parser.feed(html)
    assert len(parser.ids) == len(set(parser.ids)), "duplicate HTML id"
    for tab in ("players", "gives", "weapons", "sanctions", "functions", "jobs", "weather", "map", "audit"):
        assert f'data-admin-view="{tab}"' in html
        assert f'id="admin-{tab}-view"' in html
    for prefix in ("give", "sanction", "function", "job"):
        assert f'id="{prefix}-player-search"' in html
        assert f'id="{prefix}-player-target"' in html
    for control in ("admin-vehicle-model", "admin-give-cash-amount", "admin-give-bank-amount",
                    "admin-weapon-name", "admin-item-name", "admin-item-count",
                    "admin-kick-reason", "admin-ban-reason", "admin-job-name",
                    "admin-job-grade", "admin-weather", "admin-world-hours",
                    "admin-world-minutes", "admin-audit-table-body", "player-map"):
        assert f'id="{control}"' in html

def test_admin_ui_routes_each_tab_and_player_search_to_its_own_target():
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "const panelTargets = { give: null, sanction: null, function: null, job: null }" in ui
    assert "function renderPlayerPicker(prefix)" in ui
    assert "function getPanelTarget(prefix)" in ui
    assert "function giveAdminMoney(type)" in ui
    assert "function giveAdminVehicle()" in ui
    assert "function giveAdminWeapon()" in ui
    assert "function renderWeaponPolicy()" in ui
    assert "function saveWeaponPolicy()" in ui
    assert "data.weaponPolicy" in ui
    assert "weaponPolicy.filter(weapon => weapon && weapon.enabled === true)" in ui
    assert "function giveAdminItem()" in ui
    assert "function sanctionPlayer(action)" in ui
    assert "function banSelectedPlayer()" in ui
    assert "function playerAction(action)" in ui
    assert "function setSelectedJob()" in ui
    assert "function applyAdminWorldTime()" in ui
    assert "function renderAuditLogs(logs)" in ui
    assert "cell.textContent = String(value)" in ui

def test_admin_gta_map_uses_real_satellite_tiles_and_world_positions():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    css = read("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css")
    assert "leaflet@1.9.4" in html
    assert "gtav-map-tiles/satelite/{z}/{x}-{y}.webp" in ui
    assert "new L.Transformation(1/32, 0, 1/32, 0)" in ui
    assert "function worldToMap(position)" in ui
    assert "const GTA_MAP_SCALE = 8192 / (GTA_WORLD.maxY - GTA_WORLD.minY)" in ui
    assert "const GTA_MAP_OFFSET_X" in ui
    assert "L.marker(worldToMap(player.position)" in ui
    assert "gta-player-marker" in css

def test_admin_item_grants_are_server_validated_persisted_and_audited():
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    main = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    manifest = read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert "function(adminData, playersList, jobsList, frozenPlayers, itemCatalog)" in client
    assert "RegisterServerCallback('giveItem'" in client
    assert "exports['rp_inventory']:GetItemCatalog()" in main
    assert "RegisterNetEvent('rp_tablet_admin:server:giveItem'" in extended
    assert "AllowExtendedAction(src, 'give_item', 750)" in extended
    assert "exports['rp_inventory']:AdminSetItem(targetId, itemName, 'add', count)" in extended
    assert "LogExtendedAction(src, 'give_item'" in extended
    assert "exports('AdminSetItem', AdminSetItem)" in inventory
    assert "'rp_inventory'" in manifest


def test_admin_job_picker_excludes_unloaded_characters_and_server_waits_for_core_player():
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    main = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    assert "player.characterLoaded !== false" in ui
    assert "characterLoaded = player ~= nil" in main
    assert "characterLoaded = player ~= nil" in extended
    assert "for attempt = 1, 10 do" in main
    assert "Wait(200)" in main
    assert "pcall(target.setJob, jobName, grade)" in main
    assert "Votre métier a été défini sur " in main




def test_admin_weapon_grants_use_anticheat_policy_and_persistent_admin_controls():
    main = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    manifest = read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "exports['rp_anticheat']:GetWeaponPolicy()" in main
    assert "exports['rp_anticheat']:SaveWeaponPolicy(src, rawPolicy)" in main
    assert "exports['rp_anticheat']:IsWeaponAllowed(weapon)" in extended
    assert "AllowedAdminWeapons" not in extended
    assert "weaponPolicy = weaponPolicy or {}" in client
    assert "RegisterServerCallback('saveWeaponPolicy'" in client
    assert 'data-admin-view="weapons"' in html and 'id="admin-weapons-view"' in html
    assert "function renderWeaponPolicy()" in ui and "function saveWeaponPolicy()" in ui
    assert "weaponPolicy.filter(weapon => weapon && weapon.enabled === true)" in ui
    assert "'rp_anticheat'" in manifest


def test_admin_tablet_has_no_conflicting_handlers_and_all_tabs_switch():
    import re

    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    css = read("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css")

    declarations = re.findall(r"^function\\s+([A-Za-z_$][\\w$]*)\\s*\\(", ui, re.MULTILINE)
    for name in (
        "setupAdminSubViews", "banSelectedPlayer", "refreshPlayerMap",
        "updateOnlinePlayerPositions", "giveAdminVehicle", "giveAdminWeapon",
    ):
        assert declarations.count(name) == 1, f"conflicting duplicate {name} declaration"

    assert "document.querySelectorAll('.admin-subview').forEach(view => view.classList.toggle('active'" in ui
    assert "else if (target==='audit') requestAuditLogs()" in ui
    assert "getPanelTarget('give')" in ui
    assert "getPanelTarget('sanction')" in ui
    assert "renderPlayerPickers();" in ui
    assert "RegisterKeyMapping('rp_admin_tablet_toggle', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')" in client
    assert "RegisterNUICallback('close'" in client
    assert "closeButton.addEventListener('click', closeAdminTablet)" in ui
    assert "width: min(1200px, 96vw)" in css
    assert "height: min(740px, 94vh)" in css


if __name__ == "__main__":
    for name, check in sorted(globals().items()):
        if name.startswith("test_") and callable(check):
            check()
    print("All focused admin tablet reorganization checks passed.")
