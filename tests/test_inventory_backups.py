from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def test_inventory_grant_exports_use_character_and_transfer_locks():
    server = read("resources/[FUNCTION]/rp_inventory/server/main.lua")
    add_item = server[server.index("local function AddItem("):server.index("exports('AddItem', AddItem)")]
    admin_set = server[server.index("local function AdminSetItem("):server.index("local function GetItemCatalog()")]
    for block in (add_item, admin_set):
        assert "AcquireCharacterLock" in block
        assert "ReleaseCharacterLock" in block
        assert "transferLocks[src] = true" in block
        assert "transferLocks[src] = nil" in block
        assert "MySQL.update.await" in block


def test_database_backup_scripts_are_verified_and_have_retention():
    bash = read("scripts/backup-db.sh")
    powershell = read("scripts/backup-db.ps1")
    docs = read("docs/INVENTORY_AND_BACKUPS.md")
    assert "--single-transaction" in bash and "gzip -t" in bash
    assert "sha256sum" in bash and "RETENTION_DAYS" in bash
    assert "--single-transaction" in powershell and "Get-FileHash -Algorithm SHA256" in powershell
    assert "GZipStream" in powershell and "RetentionDays" in powershell
    assert "player_inventories" in docs and "player_inventory_drops" in docs
    assert "test de restauration" in docs
