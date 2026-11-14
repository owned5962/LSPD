from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "resources/[CORE]/rp_core"
CHARACTERS = ROOT / "resources/[CORE]/rp_characters"
JOBS = ROOT / "resources/[JOB]"


def test_server_player_registry_only_exposes_fully_loaded_characters():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    characters = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")

    assert "player.isLoaded == true and player or nil" in server
    assert "exports('WaitForPlayerLoaded', WaitForPlayerLoaded)" in server
    assert "exports('IsPlayerLoaded'" in server
    assert "local copy = {}" in server
    assert "json.decode(json.encode(value))" in server
    assert "exports('RegisterPlayer', RegisterPlayer)" in server
    assert "exports('UnregisterPlayer', UnregisterPlayer)" in server
    assert "TriggerEvent('rp_core:server:playerLoaded', src, ClonePlayerRecord(player))" in server
    assert "TriggerEvent('rp_core:server:playerUnloaded', src, ClonePlayerRecord(player))" in server
    assert "RegisterPlayer(src, createdPlayer)" in characters
    assert "UnregisterPlayer(src, identifier)" in characters
    assert "self.isLoaded = true" in player


def test_client_receives_complete_authoritative_character_snapshot():
    server_player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    client = (CORE / "client/main.lua").read_text(encoding="utf-8")

    for field in (
        "isLoaded", "source", "identifier", "charId", "characterSlot",
        "firstname", "lastname", "name", "dateofbirth", "sex", "height", "phoneNumber", "isDead",
        "cash", "bank", "job", "jobLabel", "jobGrade", "jobGradeLabel",
        "group", "duty", "hunger", "thirst", "metadata", "position", "skin",
    ):
        assert f"{field} =" in server_player
        assert f"{field} =" in client

    assert "data.isLoaded == true and characterId ~= nil and characterId > 0" in client
    assert "PlayerData.metadata.hunger = PlayerData.hunger" in client
    assert "PlayerData.metadata.thirst = PlayerData.thirst" in client


def test_disconnect_final_save_retries_until_persisted():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    assert "while not saved and characterId do" in server
    assert "pendingDisconnectSaves[characterId] = nil" in server
    assert "math.min(30000, 1000 * attempt)" in server
    assert "after 20 attempts" not in server


def test_job_resources_do_not_load_unused_mysql_driver():
    job_folders = sorted(path for path in JOBS.iterdir() if path.is_dir() and path.name.startswith("job_"))
    assert len(job_folders) == 50

    for job in job_folders:
        manifest = (job / "fxmanifest.lua").read_text(encoding="utf-8")
        assert "@oxmysql/lib/MySQL.lua" not in manifest, f"{job.name} still loads oxmysql"

        for relative in ("server/main.lua", "client/main.lua", "config.lua"):
            source = (job / relative).read_text(encoding="utf-8")
            assert "MySQL." not in source, f"{job.name}/{relative} directly uses MySQL"

def test_core_restart_requests_a_safe_character_bootstrap():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    client = (CORE / "client/main.lua").read_text(encoding="utf-8")
    characters = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")

    assert "rp_core:client:requestCharacterBootstrap" in server
    assert "RegisterNetEvent('rp_core:client:requestCharacterBootstrap'" in client
    assert "TriggerServerEvent('rp_characters:server:checkPlayer')" in client
    assert "if IsPlayerLoaded() or bootstrapRequested then return end" in client
    assert "Duplicate bootstrap requests are expected" in characters


def test_inventory_is_preloaded_from_core_player_lifecycle_and_saved_on_unload():
    inventory = (ROOT / "resources/[FUNCTION]/rp_inventory/server/main.lua").read_text(encoding="utf-8")

    assert "AddEventHandler('rp_core:server:playerLoaded', WarmPlayerInventory)" in inventory
    assert "AddEventHandler('rp_core:server:playerUnloaded'" in inventory
    assert "inventoryLoadLocks[src] = charId" in inventory
    assert "restoredSavedInventory" in inventory
    assert "Default inventory could not be persisted" in inventory
    assert "Disconnect save failed" not in inventory

def test_job_duty_is_shared_with_the_authoritative_player_record():
    core_server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    core_player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    core_client = (CORE / "client/main.lua").read_text(encoding="utf-8")
    job_folders = sorted(path for path in JOBS.iterdir() if path.is_dir() and path.name.startswith("job_"))

    assert "exports('SetPlayerDuty', SetPlayerDuty)" in core_server
    assert "player.duty = status" in core_server
    assert "RegisterNetEvent('rp_core:client:setDuty'" in core_client
    assert "self.duty = false" in core_player
    assert "self.job, self.jobGrade, self.duty = jobName, grade, false" in core_player

    for job in job_folders:
        server = (job / "server/main.lua").read_text(encoding="utf-8")
        assert "SetPlayerDuty(src, status, Config.Job)" in server, f"{job.name} does not sync duty to rp_core"



def test_core_rejects_invalid_character_identity_and_never_falls_back_to_id_one():
    player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")

    assert "RequirePositiveInteger(charData.id, 'id')" in player
    assert "RequirePositiveInteger(charData.char_id, 'char_id')" in player
    assert "expected a FiveM license identifier" in player
    assert "self.charId = characterId" in player
    assert "tonumber(charData.id) or 1" not in player
    assert "is_dead = ?" in player
    assert "self.isDead == true and 1 or 0" in player
    assert "exports('GetPlayerSnapshot', GetPlayerSnapshot)" in server
    assert "charId = player.charId" in server
    assert "activePlayer.identifier == identifier or tonumber(activePlayer.charId) == characterId" in server


def test_identifier_lookup_does_not_expose_the_live_player_record():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    lookup = server.split("function GetPlayerByIdentifier(identifier)", 1)[1].split("function GetAllPlayers()", 1)[0]

    assert "return player" not in lookup
    assert "source = player.source" in lookup
    assert "identifier = player.identifier" in lookup
    assert "charId = player.charId" in lookup
    assert "slot = player.slot" in lookup



def test_core_job_exports_fail_soft_when_job_catalog_is_unavailable():
    player = (CORE / "server/player.lua").read_text(encoding="utf-8")

    assert "GetResourceState('rp_jobs') ~= 'started'" in player
    assert "Le catalogue des métiers est indisponible" in player
    assert "local lookupOk, isValid, jobObj = pcall(function()" in player
    assert "local jobObj = { label = self.job }" in player
    assert "local gradeData = { label = 'Grade ' .. tostring(self.jobGrade) }" in player
    assert "local lookupOk, resolvedJob, resolvedGrade = pcall(function()" in player



def test_character_resource_declares_job_catalog_startup_dependency():
    manifest = (CHARACTERS / "fxmanifest.lua").read_text(encoding="utf-8")
    cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")

    assert "'rp_jobs'" in manifest
    assert cfg.index("ensure rp_core") < cfg.index("ensure rp_jobs") < cfg.index("ensure rp_characters")

def test_core_rate_limits_and_player_waits_are_safe_across_timer_rollover():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    assert "local TIMER_MODULUS = 4294967296" in server
    assert "local elapsed = (now - lastAction) % TIMER_MODULUS" in server
    assert "elapsed < cooldown" in server
    assert "#action > 80" in server
    assert "math.min(60000, cooldown)" in server
    assert "local startedAt = GetGameTimer() % TIMER_MODULUS" in server
    assert "until ((GetGameTimer() % TIMER_MODULUS) - startedAt) % TIMER_MODULUS >= timeout" in server


def test_disconnect_lifecycle_emits_detached_player_snapshots():
    server = (CORE / "server/main.lua").read_text(encoding="utf-8")
    dropped = server.split("AddEventHandler('playerDropped'", 1)[1]
    assert "TriggerEvent('rp_core:server:playerUnloaded', src, ClonePlayerRecord(player))" in dropped
    assert "actionCooldowns[src] = nil" in dropped


def test_core_manifest_declares_supported_runtime_and_driver_once():
    manifest = (CORE / "fxmanifest.lua").read_text(encoding="utf-8")
    assert "fx_version 'cerulean'" in manifest
    assert "game 'gta5'" in manifest
    assert "lua54 'yes'" in manifest
    assert "dependency 'oxmysql'" in manifest
    assert manifest.count("'@oxmysql/lib/MySQL.lua'") == 1
    for relative in ("shared/config.lua", "shared/utils.lua", "client/main.lua",
                     "client/notify.lua", "server/main.lua", "server/player.lua",
                     "server/commands.lua"):
        assert relative in manifest


def test_character_creation_is_server_validated_and_slot_uniqueness_is_database_enforced():
    server = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")
    sql = (ROOT / "database.sql").read_text(encoding="utf-8")
    assert "CanPerformAction(src, 'character:create', 5000)" in server
    assert "IsValidDate(data.dateofbirth)" in server
    assert "data.gender ~= 'm' and data.gender ~= 'f'" in server
    assert "height < 120 or height > 220" in server
    assert "INSERT INTO characters" in server
    assert "UNIQUE KEY `unique_user_char` (`identifier`, `char_id`)" in sql
    assert "if not insertOk or not charId then" in server


def test_core_startup_order_does_not_depend_on_private_server_keys():
    cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    assert cfg.index("ensure oxmysql") < cfg.index("ensure rp_core")
    assert cfg.index("ensure rp_core") < cfg.index("ensure rp_jobs") < cfg.index("ensure rp_characters")
    assert "ensure rp_core" in cfg
    assert "ensure rp_characters" in cfg

def test_character_spawn_uses_validated_coordinates_and_wrap_safe_timeouts():
    player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    character_server = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")
    character_client = (CHARACTERS / "client/main.lua").read_text(encoding="utf-8")
    assert "Utils.NormalizePosition(savedPosition, Config.DefaultSpawn)" in player
    utils = (CORE / "shared/utils.lua").read_text(encoding="utf-8")
    assert "function Utils.NormalizePosition(value, fallback)" in utils
    assert "x < -6000 or x > 6000 or y < -6000 or y > 6000" in utils
    assert "z < -500 or z > 2000" in utils
    assert "self.position = Utils.NormalizePosition(savedPosition, Config.DefaultSpawn)" in player
    assert "spawnPlayer', src, player.position, char.sex, char.skin" in character_server
    assert "local function NormalizeClientSpawn(coords)" in character_client
    assert "local function SpawnWaitExpired(startedAt, duration)" in character_client
    assert "local fadeStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS" in character_client
    assert "local collisionStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS" in character_client
    assert "GetGameTimer() < fadeDeadline" not in character_client
    assert "GetGameTimer() < collisionDeadline" not in character_client

def test_every_declared_resource_dependency_starts_before_its_consumer():
    cfg = (ROOT / "server.cfg").read_text(encoding="utf-8")
    ensure_lines = [line.strip().split()[1] for line in cfg.splitlines()
                    if line.strip().startswith("ensure ")]
    assert len(ensure_lines) == len(set(ensure_lines)), "Duplicate ensure entries in server.cfg"
    order = {name: index for index, name in enumerate(ensure_lines)}

    for manifest_path in (ROOT / "resources").rglob("fxmanifest.lua"):
        resource = manifest_path.parent.name
        if resource not in order:
            continue
        manifest = manifest_path.read_text(encoding="utf-8")
        dependencies = re.findall(r"^\s*dependency\s+['\"]([^'\"]+)['\"]", manifest, re.MULTILINE)
        block = re.search(r"dependencies\s*\{([\s\S]*?)\}", manifest)
        if block:
            dependencies.extend(re.findall(r"['\"]([^'\"]+)['\"]", block.group(1)))
        for dependency in set(dependencies):
            if dependency in order:
                assert order[dependency] < order[resource], (
                    f"{resource} starts before its dependency {dependency}"
                )

def test_every_core_export_consumer_declares_core_dependency():
    for category in ("[CORE]", "[FUNCTION]", "[JOB]"):
        for manifest_path in (ROOT / "resources" / category).glob("*/fxmanifest.lua"):
            resource = manifest_path.parent
            if resource.name == "rp_core":
                continue
            source_files = list(resource.rglob("*.lua"))
            if not any(re.search(r"exports\s*\[\s*['\"]rp_core['\"]\s*\]|exports\.rp_core", path.read_text(encoding="utf-8"))
                       for path in source_files):
                continue
            manifest = manifest_path.read_text(encoding="utf-8")
            assert re.search(r"dependency\s+['\"]rp_core['\"]|['\"]rp_core['\"]", manifest), (
                f"{resource.name} calls rp_core exports without declaring rp_core dependency"
            )


if __name__ == "__main__":
    test_server_player_registry_only_exposes_fully_loaded_characters()
    test_client_receives_complete_authoritative_character_snapshot()
    test_disconnect_final_save_retries_until_persisted()
    test_job_resources_do_not_load_unused_mysql_driver()
    test_core_restart_requests_a_safe_character_bootstrap()
    test_inventory_is_preloaded_from_core_player_lifecycle_and_saved_on_unload()
    test_job_duty_is_shared_with_the_authoritative_player_record()
    test_core_rejects_invalid_character_identity_and_never_falls_back_to_id_one()
    test_identifier_lookup_does_not_expose_the_live_player_record()
    test_core_job_exports_fail_soft_when_job_catalog_is_unavailable()
    test_character_resource_declares_job_catalog_startup_dependency()
    test_core_rate_limits_and_player_waits_are_safe_across_timer_rollover()
    test_disconnect_lifecycle_emits_detached_player_snapshots()
    test_core_manifest_declares_supported_runtime_and_driver_once()
    test_character_creation_is_server_validated_and_slot_uniqueness_is_database_enforced()
    test_core_startup_order_does_not_depend_on_private_server_keys()
    test_character_spawn_uses_validated_coordinates_and_wrap_safe_timeouts()
    test_every_declared_resource_dependency_starts_before_its_consumer()
    test_every_core_export_consumer_declares_core_dependency()
    print("Player session, core architecture and SQL dependency checks passed.")


def test_character_creation_is_serialized_and_uses_bounded_json_payloads():
    server = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")
    assert "local creationLocks = {}" in server
    assert "if creationLocks[identifier] then" in server
    assert "creationLocks[identifier] = src" in server
    assert "creationLocks[identifier] = nil" in server
    assert "locked character count query" in server
    assert "locked character slot query" in server
    assert "#encodedPosition > 1024 or #encodedSkin > 16384" in server
    assert "pcall(function()" in server
    assert "UNIQUE KEY `unique_user_char` (`identifier`, `char_id`)" in (ROOT / "database.sql").read_text(encoding="utf-8")


def test_character_creator_validates_form_and_recovers_after_server_rejection():
    ui = (CHARACTERS / "html/js/app.js").read_text(encoding="utf-8")
    client = (CHARACTERS / "client/main.lua").read_text(encoding="utf-8")
    server = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")
    assert "form.reportValidity()" in ui
    assert "submitButton.dataset.pending === 'true'" in ui
    assert "data.action === 'creationResult' && data.ok === false" in ui
    assert "creationSubmissionPending" in client
    assert "rp_characters:client:creationResult" in client
    assert "local function CreationError(src, message, kind)" in server
    assert "TriggerClientEvent('rp_characters:client:creationResult'" in server


def test_character_selector_only_receives_minimum_display_fields():
    server = (CHARACTERS / "server/main.lua").read_text(encoding="utf-8")
    assert "SELECT char_id, firstname, lastname, job FROM characters WHERE identifier = ?" in server
    assert "SELECT id, char_id, firstname, lastname, dateofbirth, sex, height, phone_number, cash, bank, job, job_grade, position, skin, metadata, is_dead FROM characters WHERE identifier = ? ORDER BY char_id ASC" not in server


if __name__ == "__main__":
    test_character_creation_is_serialized_and_uses_bounded_json_payloads()
    test_character_creator_validates_form_and_recovers_after_server_rejection()
    test_character_selector_only_receives_minimum_display_fields()
