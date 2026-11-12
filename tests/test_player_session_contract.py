from pathlib import Path

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
    assert "TriggerEvent('rp_core:server:playerLoaded', src, player)" in server
    assert "TriggerEvent('rp_core:server:playerUnloaded', src, player)" in server
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


if __name__ == "__main__":
    test_server_player_registry_only_exposes_fully_loaded_characters()
    test_client_receives_complete_authoritative_character_snapshot()
    test_disconnect_final_save_retries_until_persisted()
    test_job_resources_do_not_load_unused_mysql_driver()
    test_core_restart_requests_a_safe_character_bootstrap()
    test_inventory_is_preloaded_from_core_player_lifecycle_and_saved_on_unload()
    print("Player session and SQL dependency checks passed.")
