#!/usr/bin/env python3
"""Static regression checks for persistent FiveM character/account flows."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_admin_tablet_has_no_source_one_bypass():
    source = read("resources/[roleplay]/rp_tablet_admin/server/main.lua")
    assert "if source == 1 then" not in source
    assert 'IsPlayerAceAllowed(source, "rp_admin")' in source
    assert "GetOnlineTargetId" in source
    assert "amount > 1000000" in source
    assert "selectedJob.grades[grade]" in source


def test_character_creation_uses_database_and_license():
    source = read("resources/[roleplay]/rp_characters/server/main.lua")
    assert "GetLicenseIdentifier" in source
    assert "if not identifier or type(data) ~= 'table' then" in source
    assert "MySQL.insert.await" in source
    assert "MySQL.query.await" in source
    assert "MySQL.single.await" in source
    assert "MAX_CHARACTERS = 3" in source
    assert "rp_characters:server:selectCharacter" in source
    assert "InMemoryCharacters" not in source


def test_core_exposes_player_factory_and_saves():
    core = read("resources/[roleplay]/rp_core/server/player.lua")
    manifest = read("resources/[roleplay]/rp_core/fxmanifest.lua")
    main = read("resources/[roleplay]/rp_core/server/main.lua")
    assert "exports('CreateRPPlayer', CreateRPPlayer)" in core
    assert "UPDATE characters SET cash = ?, bank = ?, job = ?" in core
    assert "@oxmysql/lib/MySQL.lua" in manifest
    assert "player.save()" in main
    assert "5 * 60 * 1000" in main


def test_database_schema_has_unique_character_slots_and_one_job_grades_table():
    sql = read("database.sql")
    assert "UNIQUE KEY `unique_user_char` (`identifier`, `char_id`)" in sql
    assert sql.count("CREATE TABLE IF NOT EXISTS `job_grades`") == 1
    assert "FOREIGN KEY (`identifier`) REFERENCES `users`" in sql


def test_startup_orders_oxmysql_before_core():
    cfg = read("server.cfg")
    assert "ensure oxmysql" in cfg
    assert cfg.index("ensure oxmysql") < cfg.index("ensure rp_core")
    assert "CHANGE_ME" in cfg
    assert "root:password" not in cfg


def test_character_ui_has_selection_and_creation_callbacks():
    client = read("resources/[roleplay]/rp_characters/client/main.lua")
    ui = read("resources/[roleplay]/rp_characters/html/js/app.js")
    assert "openCharacterSelection" in client
    assert "beginCreation" in client
    assert "selectCharacter" in client
    assert "openCharacterSelection" in ui
    assert "postNui('selectCharacter'" in ui
    assert "textContent" in ui


if __name__ == "__main__":
    for check in (
        test_admin_tablet_has_no_source_one_bypass,
        test_character_creation_uses_database_and_license,
        test_core_exposes_player_factory_and_saves,
        test_database_schema_has_unique_character_slots_and_one_job_grades_table,
        test_startup_orders_oxmysql_before_core,
        test_character_ui_has_selection_and_creation_callbacks,
    ):
        check()
    print("All security and persistence regression checks passed.")
