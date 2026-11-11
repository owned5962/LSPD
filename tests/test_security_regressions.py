#!/usr/bin/env python3
"""Static regression checks for persistent FiveM character/account flows."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_admin_tablet_freeze_control_toggles_both_states():
    app = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "const frozenPlayers = new Set()" in app
    assert "payload.freeze = !frozenPlayers.has(selectedPlayerId)" in app
    assert "frozenPlayers.delete(selectedPlayerId)" in app


def test_admin_tablet_vehicle_spawn_is_server_authorized_and_has_no_delete_callback():
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    assert "RegisterNUICallback('spawnVehicle'" in client
    assert "TriggerServerEvent('rp_tablet_admin:server:spawnVehicle', data.model)" in client
    assert "RegisterNUICallback('deleteVehicle'" not in client
    assert "AllowExtendedAction(src, 'spawn_vehicle', 1000)" in server
    assert "type(rawModel) ~= 'string'" in server
    assert "ADMINISTRATEUR</span>" in html
    assert '<span id="current-rank-label">FONDATEUR</span>' not in html


def test_admin_freeze_state_is_restored_from_server_on_tablet_open():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    app = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert server.index("local FrozenPlayers = {}") < server.index("RegisterNetEvent('rp_tablet_admin:server:requestOpen'")
    assert "frozenPlayers[#frozenPlayers + 1] = targetId" in server
    assert "frozenPlayers = frozenPlayers or {}" in client
    assert "data.frozenPlayers.forEach" in app


def test_admin_tablet_has_no_source_one_bypass():
    source = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    assert "if source == 1 then" not in source
    assert 'IsPlayerAceAllowed(source, "rp_admin")' in source
    assert "GetOnlineTargetId" in source
    assert "amount > 1000000" in source
    assert "selectedJob.grades[grade]" in source


def test_character_creation_uses_database_and_license():
    source = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "GetLicenseIdentifier" in source
    assert "if not identifier or type(data) ~= 'table' then" in source
    assert "MySQL.insert.await" in source
    assert "MySQL.query.await" in source
    assert "MySQL.single.await" in source
    assert "MAX_CHARACTERS = 3" in source
    assert "rp_characters:server:selectCharacter" in source
    assert "InMemoryCharacters" not in source


def test_core_exposes_player_factory_and_saves():
    core = read("resources/[CORE]/rp_core/server/player.lua")
    manifest = read("resources/[CORE]/rp_core/fxmanifest.lua")
    main = read("resources/[CORE]/rp_core/server/main.lua")
    assert "exports('CreateRPPlayer', CreateRPPlayer)" in core
    assert "UPDATE characters SET cash = ?, bank = ?, job = ?" in core
    assert "self.metadata" in core and "metadata = ?" in core
    assert "@oxmysql/lib/MySQL.lua" in manifest
    assert "player.save()" in main
    assert "5 * 60 * 1000" in main


def test_database_schema_has_unique_character_slots_and_one_job_grades_table():
    sql = read("database.sql")
    assert "UNIQUE KEY `unique_user_char` (`identifier`, `char_id`)" in sql
    assert sql.count("CREATE TABLE IF NOT EXISTS `job_grades`") == 1
    assert "FOREIGN KEY (`identifier`) REFERENCES `users`" in sql
    assert "`metadata` LONGTEXT DEFAULT NULL" in sql


def test_startup_orders_oxmysql_before_core():
    cfg = read("server.cfg")
    assert "ensure oxmysql" in cfg
    assert cfg.index("ensure oxmysql") < cfg.index("ensure rp_core")
    assert "CHANGE_ME" in cfg
    assert "root:password" not in cfg


def test_character_ui_has_selection_and_creation_callbacks():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    ui = read("resources/[CORE]/rp_characters/html/js/app.js")
    assert "openCharacterSelection" in client
    assert "beginCreation" in client
    assert "selectCharacter" in client
    assert "openCharacterSelection" in ui
    assert "postNui('selectCharacter'" in ui
    assert "textContent" in ui


def test_new_character_onboarding_is_shown_and_persisted_per_character():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "rp_characters:server:requestTutorial" in client
    assert "rp_characters:client:startTutorial" in client
    assert "tutorialPages" in client and "TON INVENTAIRE" in client
    assert "F2" in client and "/jobcenter" in client
    assert "lieu de travail" in client and "F6" not in client
    assert "rp_characters:server:completeTutorial" in client
    assert "tutorialStarted[src] ~= true" in server
    assert "player.metadata.tutorialCompleted == true" in server
    assert "player.metadata.tutorialCompleted = true" in server
    assert "if not player.save() then" in server


def test_character_appearance_is_applied_and_persisted():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "mp_f_freemode_01" in client and "mp_m_freemode_01" in client
    assert "SetPedHairColor" in client
    assert "skin.components" in client and "skin.props" in client
    assert "char.position, char.sex, char.skin" in server
    assert "sendAppearancePreview" in read("resources/[CORE]/rp_characters/html/js/app.js")


def test_clothing_presets_and_outfits_are_saved():
    client = read("resources/[FUNCTION]/rp_clothing/client/main.lua")
    server = read("resources/[FUNCTION]/rp_clothing/server/main.lua")
    manifest = read("resources/[FUNCTION]/rp_clothing/fxmanifest.lua")
    ui = read("resources/[FUNCTION]/rp_clothing/html/js/app.js")
    assert "ApplyPreset(data.outfit)" in client
    assert "CaptureAppearance()" in client
    assert "GetPlayerFromId(src)" in server
    assert "INSERT INTO user_outfits" in server
    assert "UPDATE characters SET skin" in server
    assert "@oxmysql/lib/MySQL.lua" in manifest
    assert "/applyPreset" in ui



def test_legacy_core_exports_and_notifications_are_compatible():
    core = read("resources/[CORE]/rp_core/server/main.lua")
    notify = read("resources/[CORE]/rp_core/client/notify.lua")
    assert "exports('GetPlayer', GetPlayerFromId)" in core
    assert "RegisterNetEvent('rp_core:notify'" in notify
    assert "TriggerEvent('rp_core:client:notify', message, notificationType" in notify


def test_mysql_manifests_use_oxmysql_only():
    manifests = list((ROOT / "resources").rglob("fxmanifest.lua"))
    assert manifests
    for manifest in manifests:
        content = manifest.read_text(encoding="utf-8")
        assert "@mysql-async/lib/MySQL.lua" not in content, str(manifest)


def test_interaction_actions_are_authorized_and_distance_checked():
    source = read("resources/[FUNCTION]/rp_interactions/server/main.lua")
    assert "actionAllowed(jobName, action)" in source
    assert "isNearby(src, targetId, 3.0)" in source
    assert "cost > 100000" in source
    assert "GetPlayerFromId" in source
    assert "IsEntityDead(targetPed)" in source
    assert "rp_interactions:medicalAction" in source
    assert "isOnDuty(jobName, src)" in source
    for job in ("police", "ambulance", "mechanic", "taxi", "towtruck"):
        duty_source = read(f"resources/[JOB]/job_{job}/server/main.lua")
        assert "exports('IsOnDuty'" in duty_source
    client = read("resources/[FUNCTION]/rp_interactions/client/main.lua")
    config = read("resources/[FUNCTION]/rp_interactions/shared/config.lua")
    assert "NetworkResurrectLocalPlayer" in client
    assert "{ id = 'heal'" in config and "{ id = 'revive'" in config
    assert "rp_interactions:executeVehicleAction" in source
    assert "NetworkGetEntityFromNetworkId" in source
    assert "SetVehicleFixed" in source and "SetVehicleDirtLevel" in source
    assert "Impossible de mettre en fourrière un véhicule occupé." in source
    assert "rp_interactions:executeVehicleAction" in client


def test_inventory_is_persistent_and_server_validates_transfers():
    source = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    sql = read("database.sql")
    assert "player_inventories" in sql
    assert "MySQL.single.await" in source
    assert "ON DUPLICATE KEY UPDATE items" in source
    assert "targetPed" in source and "Config.MaxWeight" in source
    assert "rp_inventory:giveItem" in source
    assert "itemDef.hunger" in source and "itemDef.thirst" in source
    assert "rp_inventory:applyMedicalItem" in source
    assert "MySQL.transaction.await" in source


def test_economy_has_sql_logging_and_transaction_limits():
    source = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    manifest = read("resources/[FUNCTION]/rp_economy/fxmanifest.lua")
    assert "@oxmysql/lib/MySQL.lua" in manifest
    assert "rp_economy:server:logTransaction" in source
    assert "MAX_TRANSACTION = 1000000" in source
    assert "MySQL.insert.await" in source


def test_anticheat_rate_limits_reports_and_persists_bans():
    source = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    sql = read("database.sql")
    assert "lastFlagAt" in source and "now - lastFlagAt[src] < 5" in source
    assert "player_bans" in sql
    assert "INSERT INTO player_bans" in source
    assert "AddEventHandler('playerConnecting'" in source
    assert "RegisterCommand('rp_unban'" in source


def test_followup_hardening_keeps_internal_logs_private_and_money_atomic():
    economy = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    core = read("resources/[CORE]/rp_core/server/player.lua")
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    interactions = read("resources/[FUNCTION]/rp_interactions/server/main.lua")
    anticheat = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    police = read("resources/[JOB]/job_police/server/main.lua")
    assert "AddEventHandler('rp_economy:server:logTransaction'" in economy
    assert "RegisterNetEvent('rp_economy:server:logTransaction'" not in economy
    assert "UPDATE characters SET cash = cash - ?, bank = bank + ?" in economy
    assert "UPDATE characters AS sender JOIN characters AS recipient" in economy
    assert "if not self.save() then" in core
    assert "MySQL.transaction.await" in inventory
    assert "itemDef.hunger" in inventory and "itemDef.thirst" in inventory
    assert "UPDATE characters AS sender JOIN characters AS target" in interactions
    assert "connection refused" in anticheat
    assert "isAt(Config.ArmoryCoords" in police


def test_all_job_duty_events_are_rate_limited_and_reconcile_state():
    job_root = ROOT / "resources" / "[JOB]"
    server_files = sorted(job_root.glob("job_*/server/main.lua"))
    assert server_files, "No job server scripts found"
    for path in server_files:
        source = path.read_text(encoding="utf-8")
        if "RegisterNetEvent(" not in source or ":setDuty" not in source:
            continue
        job_name = path.parent.parent.name
        event_name = f"{job_name}:setDuty"
        assert f"CanPerformAction(src, '{event_name}', 2000)" in source, path
        assert f"{job_name}:dutyUpdated" in source, path
        assert "dutyPlayers[src] == true" in source, path


def test_job_center_hiring_requires_server_side_proximity():
    server = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "local JobCenterCoords = vector3(-268.3, -956.8, 31.2)" in server
    assert "local function IsAtJobCenter(src)" in server
    assert "GetEntityCoords(ped) - JobCenterCoords" in server
    assert "if not IsAtJobCenter(src) then" in server
    assert "Vous devez être au Pôle Emploi" in server


def test_delivery_duty_is_rate_limited_and_server_authoritative():
    server = read("resources/[JOB]/job_delivery/server/main.lua")
    client = read("resources/[JOB]/job_delivery/client/main.lua")
    assert "CanPerformAction(src, 'job_delivery:setDuty', 2000)" in server
    assert "TriggerClientEvent('job_delivery:dutyUpdated', src, dutyPlayers[src] == true)" in server
    assert "exports('IsOnDuty'" in server
    assert "local dutyRequestPending = false" in client
    assert "if not dutyRequestPending then" in client
    assert "onDuty = status == true" in client
    assert "onDuty = not onDuty" not in client


def test_job_duty_events_validate_job_and_boolean_status():
    jobs = (
        "police", "taxi", "miner", "chef", "diver", "pilot", "judge",
        "ranger", "tailor", "farmer", "lawyer", "banker", "brewer",
        "welder", "butcher", "postman", "armorer", "florist", "plumber",
        "garbage", "cleaner", "it_tech", "towtruck", "security", "smuggler",
        "event_planner", "delivery", "mechanic", "bartender", "ambulance",
        "fisherman", "cardealer", "architect", "winemaker", "journalist",
        "pharmacist", "lumberjack", "bus_driver", "realestate", "electrician",
        "dock_worker", "firefighter", "train_driver", "photographer",
        "bike_courier", "boat_captain", "veterinarian", "casino_dealer",
        "fitness_coach", "cinema_operator"
    )
    for job in jobs:
        source = read(f"resources/[JOB]/job_{job}/server/main.lua")
        assert f"player.job ~= '{job}'" in source, job
        assert "type(status) ~= 'boolean'" in source, job
        assert "isAt(Config.DutyCoords, src, 5.0)" in source, job
        assert "AddEventHandler('playerDropped'" in source, job



def test_clothing_saved_outfits_can_be_listed_and_applied_safely():
    server = read("resources/[FUNCTION]/rp_clothing/server/main.lua")
    client = read("resources/[FUNCTION]/rp_clothing/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_clothing/html/js/app.js")
    html = read("resources/[FUNCTION]/rp_clothing/html/index.html")
    assert "MySQL.transaction.await" in server
    assert "rp_clothing:requestOutfits" in server
    assert "rp_clothing:applySavedOutfit" in server
    assert "WHERE id = ? AND identifier = ? AND character_id = ?" in server
    assert "rp_clothing:receiveOutfits" in client
    assert "rp_clothing:applyAppearance" in client
    assert "requestOutfits" in ui and "applySavedOutfit" in ui
    assert "outfit-list" in html
    assert "textContent" in ui


def test_job_hiring_only_confirms_persisted_changes():
    source = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "local ok, applied = pcall(player.setJob, jobName, 0)" in source
    assert "if applied ~= true then" in source
    assert "if not targetPlayer.setJob(jobName, grade) then" in source

def test_character_creator_persists_genetics_and_face_morphs():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    html = read("resources/[CORE]/rp_characters/html/index.html")
    ui = read("resources/[CORE]/rp_characters/html/js/app.js")
    assert "SetPedHeadBlendData" in client
    assert "SetPedFaceFeature" in client
    assert "SetPedHeadOverlay" in client
    assert "SetPedEyeColor" in client
    assert "headBlend" in server and "faceFeatures" in server and "overlays" in server
    assert "safeNumber(blend.shapeFirst, 0, 45, true)" in server
    assert "safeNumber(input.faceFeatures" in server
    assert 'data-tab="heritage"' in html and 'data-tab="face"' in html
    assert "father" in ui and "mother" in ui and "faceFeatures" in ui
    assert "sendAppearancePreview" in ui


def test_pay_command_uses_atomic_transfer_and_rate_limit():
    commands = read("resources/[CORE]/rp_core/server/commands.lua")
    core = read("resources/[CORE]/rp_core/server/main.lua")
    player = read("resources/[CORE]/rp_core/server/player.lua")
    assert "CanPerformAction(src, 'pay', 1500)" in commands
    assert "TransferCash(src, targetId, amount)" in commands
    assert "amount > 1000000" in commands
    assert "UPDATE characters AS sender" in player
    assert "JOIN characters AS recipient" in player
    assert "sender.cash >= ?" in player
    assert "exports('TransferCash', TransferCash)" in player
    assert "exports('CanPerformAction', CanPerformAction)" in core
    assert "local saveLocks = {}" in player
    assert player.count("local transferLocks = {}") == 1
    assert "if transferLocks[self.charId] or saveLocks[self.charId] then return false end" in player
    assert "or saveLocks[sender.charId] or saveLocks[recipient.charId]" in player
    assert "affected < 2" in player


def test_job_center_application_is_rate_limited_and_payload_validated():
    source = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "CanPerformAction(src, 'job_center_hire', 5000)" in source
    assert "type(jobName) ~= 'string' or #jobName > 50" in source


def test_admin_tablet_uses_live_players_and_never_fakes_success():
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    assert "function handleTabletMessage(event)" in ui
    assert "function renderOnlinePlayers()" in ui
    assert "function filterPlayers()" in ui
    assert "data.players" in ui
    assert "Permissions enregistrées avec succès" not in ui
    assert "Cette fonction n’est pas encore disponible." in ui
    assert 'id="players-list"></div>' in html
    assert "Sarah_Connor" not in html and "Alexandre_Vance" not in html
    assert "RegisterNUICallback('setWeatherTime'" in client
    assert "RegisterNUICallback('broadcastAnnouncement'" in client


def test_admin_tablet_controls_are_backed_by_server_authorization():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")

    for permission, action in (
        ("spectate", "spectate"),
        ("heal", "heal"),
        ("noclip", "noclip"),
        ("godmode", "godmode"),
        ("ban", "ban"),
        ("revive", "revive"),
    ):
        button = next(line for line in html.splitlines() if f'data-perm="{permission}"' in line)
        assert "disabled" not in button, permission
    assert "AllowExtendedAction(src, 'spectate', 500)" in extended
    assert "AllowExtendedAction(src, 'heal', 500)" in extended
    assert "AllowExtendedAction(src, 'noclip', 500)" in extended
    assert "AllowExtendedAction(src, 'godmode', 500)" in extended
    assert "AllowExtendedAction(src, 'ban', 1500)" in extended
    assert "AllowAdminAction(src, 'revive', 500)" in server
    assert "onclick=\"manageSelectedMoney('give')\"" in html
    assert "onclick=\"manageSelectedMoney('remove')\"" in html
    assert "AllowAdminAction(src, 'economy', 750)" in server
    assert "onclick=\"spawnAdminVehicle()\"" in html
    assert "AllowExtendedAction(src, 'spawn_vehicle', 1000)" in extended


def test_admin_tablet_can_read_audit_logs_only_through_authorized_server_event():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    assert "AllowAdminAction(src, 'audit_logs', 2000)" in server
    assert "ORDER BY id DESC LIMIT 50" in server
    assert "rp_tablet_admin:client:auditLogs" in client
    assert "RegisterNUICallback('requestAuditLogs'" in client
    assert "function renderAuditLogs(logs)" in ui
    assert "details.textContent" in ui
    assert 'id="admin-audit-logs"' in html


def test_admin_tablet_rate_limits_and_persists_audit_logs():
    source = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    manifest = read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    sql = read("database.sql")
    assert "local function LogAdminAction" in source
    assert "INSERT INTO admin_logs" in source
    assert "CREATE TABLE IF NOT EXISTS `admin_logs`" in sql
    assert "local function AllowAdminAction" in source
    assert "CanPerformAction(src, 'admin:open', 1000)" in source
    for action in ("kick", "freeze", "goto", "bring", "revive", "economy", "setjob", "world", "broadcast"):
        assert f"AllowAdminAction(src, '{action}'" in source
    assert "@oxmysql/lib/MySQL.lua" in manifest



def test_player_job_assignment_rejects_unknown_job_names():
    jobs = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    player = read("resources/[CORE]/rp_core/server/player.lua")
    assert "function IsValidJob(name)" in jobs
    assert "exports('IsValidJob', IsValidJob)" in jobs
    assert "if not exports['rp_jobs']:IsValidJob(jobName) then" in player
    assert "Métier inconnu. Aucun changement appliqué." in player


def test_character_lifecycle_events_are_rate_limited_server_side():
    source = read("resources/[CORE]/rp_characters/server/main.lua")
    expected = {
        "requestTutorial": "character:tutorial_request",
        "completeTutorial": "character:tutorial_complete",
        "checkPlayer": "character:check_player",
        "selectCharacter": "character:select",
        "createCharacter": "character:create",
    }
    for event, action in expected.items():
        assert f"rp_characters:server:{event}" in source
        assert f"CanPerformAction(src, '{action}'," in source


def test_first_account_creation_is_idempotent_and_reloads_database_group():
    source = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "INSERT IGNORE INTO users" in source
    assert "SELECT identifier, `group` FROM users WHERE identifier = ?" in source
    assert "if not user then" in source
    assert "Impossible de créer ou charger votre compte." in source


def test_bank_transactions_share_character_locks_with_core_saves():
    core = read("resources/[CORE]/rp_core/server/player.lua")
    economy = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    assert "exports('AcquireCharacterLock', AcquireCharacterLock)" in core
    assert "exports('ReleaseCharacterLock', ReleaseCharacterLock)" in core
    assert "transferLocks[id] or saveLocks[id]" in core
    assert economy.count("AcquireCharacterLock(lockedIds)") == 3
    assert economy.count("ReleaseCharacterLock(lockedIds)") == 3
    assert "local lockedIds = { player.charId, target.charId }" in economy


def test_core_resources_declare_runtime_dependencies_explicitly():
    jobs = read("resources/[FUNCTION]/rp_jobs/fxmanifest.lua")
    economy = read("resources/[FUNCTION]/rp_economy/fxmanifest.lua")
    inventory = read("resources/[FUNCTION]/rp_inventory/fxmanifest.lua")
    characters = read("resources/[CORE]/rp_characters/fxmanifest.lua")
    admin = read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    assert "dependency 'rp_core'" in jobs
    assert "'rp_core', 'rp_jobs'" in economy
    assert "'oxmysql', 'rp_core'" in inventory
    assert "'oxmysql', 'rp_core'" in characters
    assert "'rp_core', 'rp_jobs'" in admin
    assert "lua54 'yes'" in inventory


def test_character_database_reads_fail_gracefully():
    source = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "local function SafeDatabaseCall(src, operation, callback)" in source
    assert "local ok, result = pcall(callback)" in source
    assert "La base de données est temporairement indisponible." in source
    for operation in ("account lookup", "character list query", "character selection query", "character count query", "character slot query"):
        assert operation in source


def test_inventory_item_use_cannot_be_overwritten_by_core_autosave():
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert "CanPerformAction(src, 'inventory:request_data', 2000)" in inventory
    assert "CanPerformAction(src, 'inventory:use_item', 1000)" in inventory
    start = inventory.index("RegisterNetEvent('rp_inventory:useItem'")
    end = inventory.index("RegisterNetEvent('rp_inventory:giveItem'", start)
    handler = inventory[start:end]
    assert handler.index("AcquireCharacterLock({ player.charId })") < handler.index("MySQL.transaction.await")
    assert handler.index("MySQL.transaction.await") < handler.index("ReleaseCharacterLock({ player.charId })")


def test_disconnect_save_does_not_read_a_reused_player_source_id():
    core = read("resources/[CORE]/rp_core/server/main.lua")
    player = read("resources/[CORE]/rp_core/server/player.lua")
    assert "pcall(player.save, true)" in core
    assert "function self.save(skipPosition)" in player
    assert "local ped = not skipPosition and GetPlayerPed(self.source) or 0" in player


def test_bank_transaction_events_are_rate_limited():
    economy = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    assert "CanPerformAction(src, 'economy:deposit', 1500)" in economy
    assert "CanPerformAction(src, 'economy:withdraw', 1500)" in economy
    assert "CanPerformAction(src, 'economy:transfer', 2000)" in economy


def test_inventory_give_item_event_is_rate_limited():
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert "CanPerformAction(src, 'inventory:give_item', 1500)" in inventory



def test_core_save_treats_unchanged_existing_character_as_success():
    player = read("resources/[CORE]/rp_core/server/player.lua")
    assert "if type(affected) ~= 'number' then" in player
    assert "if affected > 0 then return true end" in player
    assert "SELECT 1 FROM characters WHERE id = ? AND identifier = ? LIMIT 1" in player
    assert "return tonumber(exists) == 1" in player





def test_core_save_releases_lock_after_native_json_or_sql_failure():
    player = read("resources/[CORE]/rp_core/server/player.lua")
    save_start = player.index("function self.save(skipPosition)")
    save_end = player.index("function self.syncClient()", save_start)
    save = player[save_start:save_end]
    assert "saveLocks[self.charId] = true" in save
    assert "local ok, result = pcall(function()" in save
    assert "saveLocks[self.charId] = nil" in save
    assert save.index("saveLocks[self.charId] = nil") > save.index("local ok, result = pcall(function()")
    assert "return result == true" in save



def test_reconnect_waits_for_final_disconnect_save():
    core = read("resources/[CORE]/rp_core/server/main.lua")
    characters = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "local pendingDisconnectSaves = {}" in core
    assert "local pendingDisconnectPlayers = {}" in core
    assert "exports('IsCharacterSavePending', IsCharacterSavePending)" in core
    assert "pendingDisconnectSaves[characterId] = true" in core
    assert "pendingDisconnectPlayers[characterId] = player" in core
    assert "pcall(player.save, true)" in core
    assert "for attempt = 1, 20 do" in core
    assert "if saved and characterId then" in core
    assert "elseif characterId then" in core
    assert "Keep reconnect blocked" in core
    assert "AddEventHandler('onResourceStop'" in core
    assert "exports['rp_core']:IsCharacterSavePending(char.id)" in characters
    assert "Votre dernière sauvegarde est en cours." in characters

def test_admin_tablet_stays_hidden_until_authorized_open_message():
    css = read("resources/[FUNCTION]/rp_tablet_admin/html/css/style.css")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    assert "#tablet-wrapper" in css and "display: none;" in css
    assert "#tablet-wrapper.is-open" in css
    assert "tabletWrapper.classList.remove('is-open')" in ui
    assert "tabletWrapper.classList.add('is-open')" in ui
    assert "data.action === 'closeTablet'" in ui
    assert "SetNuiFocus(false, false)" in client
    assert "RegisterCommand('rp_admin_tablet_toggle'" in client
    assert "RegisterKeyMapping('rp_admin_tablet_toggle', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')" in client
    assert "RegisterCommand('adminmenu', ToggleAdminTablet, false)" in client



def test_character_loading_screen_closes_before_creator_or_selection_and_times_out():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    loadscreen_manifest = read("resources/[FUNCTION]/rp_loadscreen/fxmanifest.lua")
    assert "loadscreen_manual_shutdown 'yes'" in loadscreen_manifest

    assert "local function FinishCharacterBoot()" in client
    open_menu = client[client.index("RegisterNetEvent('rp_characters:client:openMenu'"):client.index("RegisterNetEvent('rp_characters:client:closeMenu'")]
    assert "FinishCharacterBoot()" in open_menu
    assert "openCharacterSelection" in open_menu
    assert "Wait(20000)" in client
    assert "characterBootPending" in client
    assert "NetworkIsSessionStarted()" in client
    assert "RegisterNetEvent('rp_characters:client:bootError'" in client
    assert "TriggerClientEvent('rp_characters:client:bootError'" in server
    assert "Vérifiez oxmysql" in server

def test_character_spawn_cannot_wait_forever_on_screen_fade():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "local fadeDeadline = GetGameTimer() + 5000" in client
    assert "GetGameTimer() < fadeDeadline" in client
    assert "ShutdownLoadingScreen()" in client
    assert "ShutdownLoadingScreenNui()" in client
    assert "Failed to initialize character" in server
    assert "sending spawn event" in server






def test_admin_tablet_close_controls_and_keyboard_bindings_do_not_conflict():
    admin = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    anticheat = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "RegisterKeyMapping('admin', 'Ouvrir la Tablette Admin', 'keyboard', 'F10')" in admin
    assert "RegisterKeyMapping('openanticheat', 'Ouvrir le menu Anticheat', 'keyboard', 'F9')" in anticheat
    assert "if isTabletOpen then" in admin and "CloseAdminTablet()" in admin
    assert "closeButton.addEventListener('click', closeAdminTablet)" in ui
    assert "nuiPost('close', { source })" in ui
    assert "if (event.key !== 'Escape') return;" in ui
    assert "lastAdminToggleAt" in admin
    assert "data.source == 'f10'" in admin
    assert "if wasOpen then StopTabletAnimation() end" in admin
    assert "SetNuiFocus(false, false)" in admin

def test_admin_live_map_uses_authorized_server_world_positions():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    assert "GetEntityCoords(ped)" in server and "isSelf = pid == src" in server
    assert "position = { x = coords.x, y = coords.y, z = coords.z }" in server
    assert "AllowExtendedAction(src, 'positions', 1800)" in extended
    assert "RegisterNetEvent('rp_tablet_admin:server:requestPlayerPositions'" in extended
    assert "RegisterNUICallback('requestPlayerPositions'" in client
    assert "RegisterNetEvent('rp_tablet_admin:client:playerPositions'" in client
    assert "RegisterNUICallback('healPlayer'" in client
    assert 'id="player-map"' in html and 'id="admin-map-view"' in html
    assert "function renderPlayerMap()" in ui
    assert "function changeMapZoom(factor)" in ui
    assert "function updateOnlinePlayerPositions(players)" in ui



def test_admin_player_snapshot_always_includes_requesting_admin():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "for _, rawId in pairs(GetPlayers()) do" in server
    assert "isSelf = pid == src" in server
    assert "if not seen[src] and GetPlayerName(src) then" in server
    assert "table.sort(onlinePlayers" in server
    assert "player.isSelf ? ' (VOUS)' : ''" in ui


def test_admin_tablet_exposes_working_heal_economy_and_job_actions():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    extended = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "AllowExtendedAction(src, 'heal', 500)" in extended
    assert "rp_tablet_admin:client:heal" in extended and "client:heal" in client
    assert "RegisterNUICallback('manageEconomy'" in client
    assert "RegisterNUICallback('setJob'" in client
    assert 'onclick="playerAction(\'heal\')"' in html
    assert 'onclick="manageSelectedMoney(\'give\')"' in html
    assert 'onclick="manageSelectedMoney(\'remove\')"' in html
    assert 'onclick="setSelectedJob()"' in html
    assert "function manageSelectedMoney(operation)" in ui
    assert "function setSelectedJob()" in ui



def test_all_security_regressions_are_run_by_the_test_script():
    source = read("tests/test_security_regressions.py")
    runner_index = source.rindex('def test_anticheat_tablet_has_live_dashboard_player_tools_logs_and_ban_management():
    root = "resources/[FUNCTION]/rp_anticheat/"
    html = read(root + "html/index.html")
    ui = read(root + "html/js/app.js")
    client = read(root + "client/main.lua")
    server = read(root + "server/main.lua")
    config = read(root + "shared/config.lua")
    css = read(root + "html/css/style.css")

    for tab in ("dashboard", "protections", "players", "surveillance", "logs", "bans"):
        assert f'data-tab="{tab}"' in html
        assert f'id="pane-{tab}"' in html
    assert "requestLogs" in client and "requestBans" in client and "unban" in client
    assert "RegisterNetEvent('rp_anticheat:requestLogs'" in server
    assert "RegisterNetEvent('rp_anticheat:requestBans'" in server
    assert "RegisterNetEvent('rp_anticheat:unban'" in server
    assert "canUseAnticheatTablet(src)" in server
    assert "entity_spam" in config and "AddEventHandler('entityCreating'" in server
    assert "MaxEntitiesPerWindow" in config and "CancelEvent()" in server
    assert "textContent" in ui
    assert "spectateStarted" in ui and "spectateStopped" in ui
    assert ".ac-shell" in css and ".metric-grid" in css


def test_anticheat_detection_log_and_staff_actions_are_bounded():
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    assert "if #detectionsLog > 250 then table.remove(detectionsLog) end" in server
    assert "allowStaffAction(src, 'toggle_protection', 1)" in server
    assert "allowStaffAction(src, 'punish', 2)" in server
    assert "allowStaffAction(src, 'unban', 2)" in server
    assert "allowStaffAction(src, 'request_logs', 1)" in server
    assert "allowStaffAction(src, 'request_bans', 2)" in server
    assert "openRequestAt[src] and now - openRequestAt[src] < 1" in server
    assert "ORDER BY created_at DESC LIMIT 100" in server


if __name__ == "__main__":')

def test_loadscreen_has_offline_visual_banners_and_correct_keybinds():
    manifest = read("resources/[FUNCTION]/rp_loadscreen/fxmanifest.lua")
    html = read("resources/[FUNCTION]/rp_loadscreen/html/index.html")
    css = read("resources/[FUNCTION]/rp_loadscreen/html/css/style.css")
    for asset in ("los_santos_ems.svg", "los_santos_jobs.svg", "los_santos_coast.svg"):
        assert asset in manifest
        assert asset in html
        assert (ROOT / "resources/[FUNCTION]/rp_loadscreen/html/images" / asset).is_file()
    assert "https://cdnjs.cloudflare.com" not in html
    assert "fonts.googleapis.com" not in html
    assert 'kbd>F2</kbd><span>Inventaire joueur' in html
    assert 'kbd>F5</kbd><span>Menu des métiers' in html
    assert 'kbd>F9</kbd><span>Tablette anticheat' in html
    assert 'kbd>F10</kbd><span>Tablette administrateur' in html
    assert 'kbd>F11</kbd><span>Créateur de personnage' in html
    assert "data-stage" in html and "--stage-color" in css


def test_loadscreen_phase_progress_uses_fivem_events_and_real_resource_starts():
    manifest = read("resources/[FUNCTION]/rp_loadscreen/fxmanifest.lua")
    client = read("resources/[FUNCTION]/rp_loadscreen/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_loadscreen/html/js/app.js")
    character = read("resources/[CORE]/rp_characters/client/main.lua")
    assert "'client/main.lua'" in manifest
    assert "onClientResourceStart" in client
    assert "resourceName == 'rp_anticheat'" in client
    assert "resourceName:match('^job_[%w_]+$')" in client
    assert "mission_" in client and "rp_missions" in client
    assert "SendLoadingScreenMessage" in client
    assert "eventName === 'loadProgress'" in ui
    assert "eventName === 'lssStage'" in ui
    assert "performMapLoadFunction" in ui
    assert "Chargement du joueur" in ui
    assert "eventName = 'lssStage'" in character
    assert "Chargement des missions" in ui




def test_admin_permanent_ban_requires_staff_reason_and_persists_license():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "AllowExtendedAction(src, 'ban', 1500)" in server
    assert "Un motif de bannissement est obligatoire." in server
    assert "INSERT INTO player_bans (identifier, reason, banned_by)" in server
    assert "DropPlayer(targetId, '[ADMINISTRATION - BAN PERMANENT] '" in server
    assert "RegisterNUICallback('banPlayer'" in client
    assert 'onclick="banSelectedPlayer()"' in html
    assert 'id="admin-ban-reason"' in html
    assert "function banSelectedPlayer()" in ui
    assert "window.confirm(" in ui


def test_admin_tablet_javascript_has_valid_player_position_string():
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "Number(player.ping || 0).toFixed(0)" not in ui
    assert "Number(player.ping || 0) + ' ms'" in ui
    assert "function closeAdminTablet(source = 'button')" in ui
    assert "classList.remove('is-open')" in ui


def test_jobcenter_resource_name_and_application_feedback_are_not_recursive_or_silent():
    ui = read("resources/[FUNCTION]/rp_jobs/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_jobs/client/main.lua")
    server = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "function GetParentResourceName()" not in ui
    assert "const NUI_RESOURCE" in ui
    assert "jobSelectionResult" in ui
    assert "RegisterNetEvent('rp_jobs:client:jobSelectionResult'" in client
    assert "RespondToJobSelection(src, true, message)" in server
    assert "local function IsAtJobCenter(src)" in server
    assert "GetEntityCoords(ped) - JobCenterCoords" in server
    assert "if not IsAtJobCenter(src) then" in server
    assert "Vous devez être au Pôle Emploi" in server


def test_bank_requires_physical_proximity_and_e_interaction():
    client = read("resources/[FUNCTION]/rp_economy/client/main.lua")
    server = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    ui = read("resources/[FUNCTION]/rp_economy/html/js/app.js")
    assert "RegisterCommand('bank'" in client and "GetNearbyBank(3.0)" in client
    assert "RegisterCommand('atm'" in client and "GetNearbyATM(2.0)" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "function GetParentResourceName()" not in ui
    assert "IsNearBankOrATM(src, true)" in server
    assert "IsNearBankOrATM(src, false)" in server


def test_player_hud_is_updated_from_loaded_character_data():
    client = read("resources/[FUNCTION]/rp_ui/client/main.lua")
    html = read("resources/[FUNCTION]/rp_ui/html/index.html")
    ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")
    manifest = read("resources/[FUNCTION]/rp_ui/fxmanifest.lua")
    assert "exports['rp_core']:GetPlayerData()" in client
    assert "action = 'updateHUD'" in client
    assert 'id="player-hud"' in html
    assert "function updatePlayerHUD(data)" in ui
    assert "dependency 'rp_core'" in manifest


def test_other_nui_menus_reset_focus_and_support_close_paths():
    inventory = read("resources/[FUNCTION]/rp_inventory/client/main.lua")
    clothing = read("resources/[FUNCTION]/rp_clothing/client/main.lua")
    interactions = read("resources/[FUNCTION]/rp_interactions/client/main.lua")
    anticheat = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    assert "onClientResourceStart" in inventory and "RegisterNUICallback('close'" in inventory
    assert "onClientResourceStart" in clothing and "RegisterNUICallback('close'" in clothing
    assert "onClientResourceStart" in interactions and "RegisterNUICallback('close'" in interactions
    assert "onClientResourceStart" in anticheat and "RegisterNUICallback('close'" in anticheat


def test_admin_advanced_actions_are_server_authorized():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    for action in ("spectate", "noclip", "godmode", "spawn_vehicle"):
        assert "AllowExtendedAction(src, '" + action + "'" in server
    assert "RegisterNUICallback('spectatePlayer'" in client
    assert "RegisterNUICallback('toggleNoclip'" in client
    assert "RegisterNUICallback('toggleGodmode'" in client
    assert "RegisterNUICallback('spawnVehicle'" in client
    assert 'onclick="toggleAdminMode(\'noclip\')"' in html
    assert "function spawnAdminVehicle()" in ui




def test_nui_endpoints_are_fixed_and_do_not_recurse_through_parent_lookup():
    resources = {
        "rp_jobs": "resources/[FUNCTION]/rp_jobs/html/js/app.js",
        "rp_economy": "resources/[FUNCTION]/rp_economy/html/js/app.js",
        "rp_tablet_admin": "resources/[FUNCTION]/rp_tablet_admin/html/js/app.js",
        "rp_inventory": "resources/[FUNCTION]/rp_inventory/html/js/app.js",
        "rp_clothing": "resources/[FUNCTION]/rp_clothing/html/js/app.js",
        "rp_interactions": "resources/[FUNCTION]/rp_interactions/html/js/app.js",
        "rp_anticheat": "resources/[FUNCTION]/rp_anticheat/html/js/app.js",
    }
    for resource, path in resources.items():
        ui = read(path)
        assert "GetParentResourceName" not in ui
        assert "https://${rp_" not in ui
        assert f"https://{resource}/" in ui or f"NUI_RESOURCE = '{resource}'" in ui


def test_jobcenter_application_returns_server_result_and_closes_focus_on_success():
    ui = read("resources/[FUNCTION]/rp_jobs/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_jobs/client/main.lua")
    server = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "const NUI_RESOURCE = 'rp_jobs'" in ui
    assert "pendingJobTimeout = setTimeout" in ui
    assert "if (data.success) closeJobCenter()" in ui
    assert "RegisterNUICallback('selectJob'" in client
    assert "RegisterNetEvent('rp_jobs:client:jobSelectionResult'" in client
    assert "pcall(player.setJob, jobName, 0)" in server
    assert "Embauche confirmée" in ui


def test_bank_ui_is_only_opened_at_real_bank_or_atm_and_server_checks_distance():
    client = read("resources/[FUNCTION]/rp_economy/client/main.lua")
    server = read("resources/[FUNCTION]/rp_economy/server/main.lua")
    ui = read("resources/[FUNCTION]/rp_economy/html/js/app.js")
    assert "RegisterCommand('bank'" in client and "OpenBankUI(false)" in client
    assert "RegisterCommand('atm'" in client and "OpenBankUI(true)" in client
    assert "IsControlJustReleased(0, 38)" in client
    assert "if not GetNearbyBank(3.0)" in client
    assert "IsNearBankOrATM(src, true)" in server
    assert "IsNearBankOrATM(src, false)" in server
    assert "https://rp_economy/close" in ui


def test_hud_is_refreshed_from_character_and_balance_events():
    client = read("resources/[FUNCTION]/rp_ui/client/main.lua")
    html = read("resources/[FUNCTION]/rp_ui/html/index.html")
    ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")
    css = read("resources/[FUNCTION]/rp_ui/html/css/style.css")
    assert "function UpdatePlayerHUD()" in client
    assert "RegisterNetEvent('rp_core:client:setPlayerData'" in client
    assert "RegisterNetEvent('rp_core:client:updateCash'" in client
    assert "RegisterNetEvent('rp_core:client:updateBank'" in client
    assert 'id="player-hud"' in html
    assert "function updatePlayerHUD(data)" in ui
    assert "#player-hud" in css and "z-index: 1000" in css


def test_cfx_default_resources_are_documented_and_start_order_is_valid():
    config = read("server.cfg")
    readme = read("README.md")
    assert "ensure oxmysql" in config
    assert config.index("ensure rp_jobs") < config.index("ensure rp_economy")
    assert "ensure spawnmanager" in config
    assert "ensure sessionmanager" in config
    assert "ensure hardcap" in config
    assert "ensure baseevents" in config
    assert "set onesync on" in config
    assert not any(line.strip() == "onesync on" for line in config.splitlines())
    assert "cfx-server-data" in readme
    assert "bash install-cfx-defaults.sh" in readme
    assert "install-cfx-defaults.ps1" in readme
    windows_installer = read("install-cfx-defaults.ps1")
    for resource in ("spawnmanager", "sessionmanager", "hardcap", "baseevents"):
        assert resource in windows_installer
    installer = read("install-cfx-defaults.sh")
    for resource in ("spawnmanager", "sessionmanager", "hardcap", "baseevents"):
        assert resource in installer
    assert "spawnmanager" in readme and "baseevents" in readme



def test_character_registration_name_is_published_as_player_name():
    source = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "local roleplayName =" in source
    assert "SetPlayerName(src, roleplayName)" in source


def test_anticheat_self_is_visible_and_receives_live_telemetry():
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    ui = read("resources/[FUNCTION]/rp_anticheat/html/js/app.js")
    assert "openStaff[src] = true" in server
    assert "isSelf = id == src" in server
    assert "rp_anticheat:updatePlayers" in server and "Wait(1000)" in server
    assert "rp_anticheat:updatePlayers" in client
    assert "p.isSelf ? ' (VOUS)' : ''" in ui
    assert "Selecting yourself is supported for live telemetry" in ui


def test_creator_tablet_is_separate_and_started():
    admin_html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    creator_client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    config = read("server.cfg")
    assert "view-creator" not in admin_html and "mode-switcher" not in admin_html
    assert "RegisterCommand('creator'" in creator_client
    assert "RegisterKeyMapping('creator', 'Ouvrir la tablette Créateur', 'keyboard', 'F11')" in creator_client
    jobs = read("resources/[FUNCTION]/rp_jobs/client/main.lua")
    inventory = read("resources/[FUNCTION]/rp_inventory/client/main.lua")
    assert "RegisterKeyMapping('jobcenter', 'Ouvrir le menu des métiers', 'keyboard', 'F5')" in jobs
    assert "RegisterKeyMapping('openinventory'" in inventory and "'F2'" in inventory
    assert "ensure rp_tablet_creator" in config
    assert "server/extended.lua" in read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")


def test_jobcenter_blocks_duplicate_clicks_until_server_result():
    ui = read("resources/[FUNCTION]/rp_jobs/html/js/app.js")
    assert "let activeJobRequest = false" in ui
    assert "if (activeJobRequest) return" in ui
    assert "activeJobRequest = false" in ui
    assert "chooseJob(job.name, actionBtn)" in ui



def test_character_has_a_visible_default_freemode_skin_when_saved_skin_is_missing_or_invalid():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    assert "local fallbackModel = joaat('mp_m_freemode_01')" in client
    assert "SetPedDefaultComponentVariation(ped)" in client
    assert "SetEntityVisible(ped, true, false)" in client
    assert "ResetEntityAlpha(ped)" in client
    assert "SetEntityCollision(ped, true, true)" in client
    assert "local appearanceApplied = ApplyCharacterAppearance(gender, skin)" in client
    assert "Appearance fallback was required" in client
    assert "outfits.casual" in client


def test_admin_tablet_server_audit_and_open_handlers_are_well_formed():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    assert "adminName = adminName:gsub('^%s*(.-)%s*$', '%1')" in server
    assert "local function LogAdminAction(src, action, targetId, details)" in server
    assert server.count("RegisterNetEvent('rp_tablet_admin:server:requestOpen'") == 1
    assert "server:requestAuditLogs" in server
    assert "server:broadcastAnnouncement" in server
    assert "adminName:gsub('^%s*(.-)%s*, function()" not in server
    assert "\\n, '%1')" not in server


def test_character_server_trim_helper_uses_a_complete_pattern():
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "return value:match('^%s*(.-)%s*$') or ''" in server
    assert "value:gsub('^%s*(.-)%s*'" not in server


def test_character_player_controls_stay_locked_until_a_character_is_loaded():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    assert "SetPlayerControl(PlayerId(), false, 0)" in client
    assert "SetPlayerControl(PlayerId(), true, 0)" in client
    assert "SetEntityVisible(ped, false, false)" in client
    assert "FreezeEntityPosition(PlayerPedId(), not characterSessionReady)" in client


def test_admin_server_has_no_duplicate_legacy_event_handlers():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    for event in ("kickPlayer", "freezePlayer", "teleportToPlayer", "bringPlayer", "revivePlayer", "manageEconomy", "setJob", "setWeatherTime", "broadcastAnnouncement"):
        assert server.count("RegisterNetEvent('rp_tablet_admin:server:" + event + "'") == 1


def test_admin_give_actions_are_server_authorized_and_audited():
    server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    assert "AllowExtendedAction(src, 'give_vehicle', 1000)" in server
    assert "AllowExtendedAction(src, 'give_weapon', 750)" in server
    assert "AllowedAdminWeapons[weapon]" in server
    assert "RegisterNUICallback('giveVehicle'" in client
    assert "RegisterNUICallback('giveWeapon'" in client
    assert "LogExtendedAction(src, 'give_vehicle'" in server
    assert "LogExtendedAction(src, 'give_weapon'" in server


def test_admin_job_picker_and_world_time_controls_are_present():
    html = read("resources/[FUNCTION]/rp_tablet_admin/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert '<select id="admin-job-name"' in html
    assert '<select id="admin-job-grade"' in html
    assert "function renderJobGrades()" in ui
    assert "function applyAdminWorldTime()" in ui
    assert 'id="admin-world-hours"' in html and 'id="admin-world-minutes"' in html


def test_anticheat_server_protects_weapon_damage_and_explosion_spam():
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    config = read("resources/[FUNCTION]/rp_anticheat/shared/config.lua")
    assert "AddEventHandler('weaponDamageEvent'" in server
    assert "AddEventHandler('explosionEvent'" in server
    assert "CancelEvent()" in server
    assert "explosion_spam" in config and "weapon_damage" in config
    assert "AddEventHandler('rp_anticheat:setAdminInvulnerability'" in server
    assert "RegisterNetEvent('rp_anticheat:setAdminInvulnerability'" not in server


def test_admin_map_uses_local_custom_artwork_and_player_overlay():
    manifest = read("resources/[FUNCTION]/rp_tablet_admin/fxmanifest.lua")
    ui = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "html/images/los_santos_map.svg" in manifest
    assert "backgroundSize" in ui and "getMapMarkers" in ui


def test_spectate_is_server_authorized_and_streams_target_coordinates():
    anticheat_server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    anticheat_client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    admin_server = read("resources/[FUNCTION]/rp_tablet_admin/server/extended.lua")
    admin_client = read("resources/[FUNCTION]/rp_tablet_admin/client/main.lua")
    assert "RegisterNetEvent('rp_anticheat:requestSpectate'" in anticheat_server
    assert "not isStaff(src)" in anticheat_server
    assert "GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId)" in anticheat_server
    assert "SetFocusPosAndVel" in anticheat_client and "RequestCollisionAtCoord" in anticheat_client
    assert "SetFocusPosAndVel" in admin_client and "RequestCollisionAtCoord" in admin_client
    assert "GetPlayerRoutingBucket(src) ~= GetPlayerRoutingBucket(targetId)" in admin_server


def test_character_boot_resumes_only_when_core_already_has_a_loaded_player():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    server = read("resources/[CORE]/rp_characters/server/main.lua")
    assert "rp_characters:client:resumeLoadedCharacter" in client
    assert "FinishCharacterBoot()" in client[client.index("RegisterNetEvent('rp_characters:client:resumeLoadedCharacter'"):client.index("RegisterNetEvent('rp_characters:client:bootError'")]
    assert "if exports['rp_core']:GetPlayerFromId(src) then" in server
    assert "TriggerClientEvent('rp_characters:client:resumeLoadedCharacter', src)" in server


def test_fivem_server_icon_is_registered():
    config = read("server.cfg")
    assert "load_server_icon server-icon.png" in config
    assert (ROOT / "server-icon.png").is_file()


def test_creator_console_server_and_player_management_is_server_authorized():
    server = read("resources/[FUNCTION]/rp_tablet_creator/server/main.lua")
    client = read("resources/[FUNCTION]/rp_tablet_creator/client/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_creator/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_creator/html/app.js")
    assert "CanUseTablet" in server and "creatorAccessAllowed(src)" in server
    assert "server:setServerSettings" in server
    assert "server:setModuleState" in server
    assert "server:updatePlayerIdentity" in server
    assert "server:updatePlayerBalances" in server
    assert "server:updatePlayerJob" in server
    assert "server:updatePlayerInventory" in server
    assert "server:updatePlayerAccess" in server
    assert "server:requestAdminTools" in client
    assert "creator-server-name" in html and "creator-server-slots" in html
    assert "creator-access-anticheat" in html and "creator-access-admin" in html
    assert "creatorAdminData" in ui


def test_creator_player_inventory_api_validates_items_and_weight():
    inventory = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    assert "local function AdminSetItem" in inventory
    assert "Config.DefaultItems[itemName]" in inventory
    assert "getInventoryWeight(inventory) > Config.MaxWeight" in inventory
    assert "exports('AdminSetItem', AdminSetItem)" in inventory
    assert "exports('GetItemCatalog', GetItemCatalog)" in inventory


def test_anticheat_surveillance_snapshot_is_shared_between_staff():
    server = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    client = read("resources/[FUNCTION]/rp_anticheat/client/main.lua")
    assert "Build the player snapshot once per second" in server
    assert server.count("BuildSurveillanceSnapshot()") == 2
    assert "markCurrentPlayer(playersList)" in client


def test_staff_tablet_access_is_checked_server_side():
    admin = read("resources/[FUNCTION]/rp_tablet_admin/server/main.lua")
    anticheat = read("resources/[FUNCTION]/rp_anticheat/server/main.lua")
    assert "CanUseTablet(src, 'admin')" in admin
    assert "CanUseTablet(src, 'anticheat')" in anticheat


def test_creator_skin_updates_use_existing_character_appearance_pipeline():
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    assert "rp_characters:client:adminApplySkin" in client
    assert "ApplyCharacterAppearance(gender, skin)" in client

if __name__ == "__main__":
    checks = sorted(
        (name, check)
        for name, check in globals().items()
        if name.startswith("test_") and callable(check)
    )
    for name, check in checks:
        check()
    print(f"All {len(checks)} security and persistence regression checks passed.")


def test_character_creator_has_left_panel_french_birth_date_and_clothing_controls():
    html = read("resources/[CORE]/rp_characters/html/index.html")
    css = read("resources/[CORE]/rp_characters/html/css/style.css")
    ui = read("resources/[CORE]/rp_characters/html/js/app.js")
    client = read("resources/[CORE]/rp_characters/client/main.lua")
    assert 'placeholder="JJ/MM/AAAA"' in html
    assert 'pattern="[0-9]{2}/[0-9]{2}/[0-9]{4}"' in html
    assert "inset: 3vh auto 3vh 2vw" in css
    for control in ("component-5", "component-9", "prop-1", "prop-7"):
        assert 'id="' + control + '"' in html
        assert control in ui
    assert "components: Object.fromEntries" in ui
    assert "props: Object.fromEntries" in ui
    assert "UpdatePedHeadBlendData(ped, true)" in client


def test_job_center_is_proximity_gated_and_waits_for_core_character_load():
    client = read("resources/[FUNCTION]/rp_jobs/client/main.lua")
    server = read("resources/[FUNCTION]/rp_jobs/server/main.lua")
    assert "local function IsPlayerAtJobCenter()" in client
    assert "if not IsPlayerAtJobCenter() then" in client
    assert "RegisterKeyMapping('jobcenter'" in client and "'F5'" in client
    assert "for attempt = 1, 24 do" in server
    assert "Wait(250)" in server
    assert "Votre personnage est encore en cours de chargement" in server


def test_hud_has_separate_job_panel_and_no_money_display():
    html = read("resources/[FUNCTION]/rp_ui/html/index.html")
    css = read("resources/[FUNCTION]/rp_ui/html/css/style.css")
    ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")
    client = read("resources/[FUNCTION]/rp_ui/client/main.lua")
    assert 'id="hud-job-panel"' in html
    assert 'id="hud-cash"' not in html and 'id="hud-bank"' not in html
    assert "#hud-job-panel" in css
    assert "hud-job-panel" in ui
    assert "cash = tonumber(data.cash)" not in client
    assert "SetMinimapClipType(1)" in client


def test_f12_client_diagnostics_are_registered_and_rendered():
    client = read("resources/[FUNCTION]/rp_ui/client/main.lua")
    html = read("resources/[FUNCTION]/rp_ui/html/index.html")
    ui = read("resources/[FUNCTION]/rp_ui/html/js/app.js")
    assert "RegisterKeyMapping('clientdiagnostics'" in client
    assert "'F12'" in client
    assert "GetFrameTime()" in client
    assert 'id="client-diagnostics"' in html
    assert "updateDiagnostics" in ui


def test_inventory_and_admin_hotkeys_do_not_close_their_own_newly_opened_nui():
    inventory = read("resources/[FUNCTION]/rp_inventory/html/js/app.js")
    admin = read("resources/[FUNCTION]/rp_tablet_admin/html/js/app.js")
    assert "e.key === 'Escape' || e.key === 'F2'" not in inventory
    assert "if (e.key === 'Escape')" in inventory
    assert "event.key !== 'Escape' && event.key !== 'F10'" not in admin
    assert "if (event.key !== 'Escape') return;" in admin


def test_contextual_job_tablet_is_registered_on_f4_and_uses_server_validation():
    manifest = read("resources/[FUNCTION]/rp_tablet_job/fxmanifest.lua")
    client = read("resources/[FUNCTION]/rp_tablet_job/client/main.lua")
    server = read("resources/[FUNCTION]/rp_tablet_job/server/main.lua")
    html = read("resources/[FUNCTION]/rp_tablet_job/html/index.html")
    ui = read("resources/[FUNCTION]/rp_tablet_job/html/app.js")
    cfg = read("server.cfg")
    assert "RegisterKeyMapping('jobtablet'" in client and "'F4'" in client
    assert "ensure rp_tablet_job" in cfg
    assert "dependencies" in manifest and "'rp_core'" in manifest and "'rp_jobs'" in manifest
    assert "GetPlayerFromId(src)" in server and "GetAllPlayers()" in server
    assert "rp_tablet_job:server:startMission" in server
    assert "rp_tablet_job:server:finishMission" in server
    assert 'data-tab="team"' in html and 'data-tab="missions"' in html
    assert "missionCatalog" in ui
    assert "cb({ ok = true })" in client

