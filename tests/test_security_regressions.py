#!/usr/bin/env python3
"""Static regression checks for persistent FiveM character/account flows."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


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
    for job in ("police", "ambulance", "mechanic", "taxi"):
        duty_source = read(f"resources/[JOB]/job_{job}/server/main.lua")
        assert "exports('IsOnDuty'" in duty_source
    client = read("resources/[FUNCTION]/rp_interactions/client/main.lua")
    config = read("resources/[FUNCTION]/rp_interactions/shared/config.lua")
    assert "NetworkResurrectLocalPlayer" in client
    assert "{ id = 'heal'" in config and "{ id = 'revive'" in config


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
    assert "Objet conservé." in inventory
    assert "UPDATE characters AS sender JOIN characters AS target" in interactions
    assert "connection refused" in anticheat
    assert "isAt(Config.ArmoryCoords" in police


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


if __name__ == "__main__":
    for check in (
        test_admin_tablet_has_no_source_one_bypass,
        test_character_creation_uses_database_and_license,
        test_core_exposes_player_factory_and_saves,
        test_database_schema_has_unique_character_slots_and_one_job_grades_table,
        test_startup_orders_oxmysql_before_core,
        test_character_ui_has_selection_and_creation_callbacks,
        test_character_appearance_is_applied_and_persisted,
        test_clothing_presets_and_outfits_are_saved,
        test_legacy_core_exports_and_notifications_are_compatible,
        test_mysql_manifests_use_oxmysql_only,
        test_interaction_actions_are_authorized_and_distance_checked,
        test_inventory_is_persistent_and_server_validates_transfers,
        test_economy_has_sql_logging_and_transaction_limits,
        test_anticheat_rate_limits_reports_and_persists_bans,
        test_followup_hardening_keeps_internal_logs_private_and_money_atomic,
        test_job_duty_events_validate_job_and_boolean_status,
    ):
        check()
    print("All security and persistence regression checks passed.")
