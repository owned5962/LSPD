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
    assert "TriggerEvent('rp_core:server:playerLoaded', src, createdPlayer)" in characters
    assert "createdPlayer.isLoaded = true" in characters
    assert "self.isLoaded = true" in player


def test_client_receives_complete_authoritative_character_snapshot():
    server_player = (CORE / "server/player.lua").read_text(encoding="utf-8")
    client = (CORE / "client/main.lua").read_text(encoding="utf-8")

    for field in (
        "isLoaded", "source", "identifier", "charId", "characterSlot",
        "firstname", "lastname", "name", "dateofbirth", "sex", "height",
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


if __name__ == "__main__":
    test_server_player_registry_only_exposes_fully_loaded_characters()
    test_client_receives_complete_authoritative_character_snapshot()
    test_disconnect_final_save_retries_until_persisted()
    test_job_resources_do_not_load_unused_mysql_driver()
    print("Player session and SQL dependency checks passed.")
