from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_all_historical_sql_migrations_are_in_database_sql():
    schema = (ROOT / "database.sql").read_text(encoding="utf-8")

    # 001 + 004: character date normalization and metadata persistence.
    assert "rp_dateofbirth_type" in schema
    assert "MODIFY COLUMN `dateofbirth` DATE NOT NULL" in schema
    assert "rp_metadata_exists" in schema
    assert "ADD COLUMN `metadata` LONGTEXT DEFAULT NULL" in schema

    # 002 + both 003 migrations: inventory, ground drops, persistent bans.
    for table in ("player_inventories", "player_inventory_drops", "player_bans"):
        assert f"CREATE TABLE IF NOT EXISTS `{table}`" in schema

    # 005 + 006: complete job catalogue and shared job bank accounts.
    assert "Catalogue initial des métiers et de leurs grades" in schema
    assert "INSERT IGNORE INTO `jobs`" in schema
    assert "INSERT IGNORE INTO `job_grades`" in schema
    assert "CREATE TABLE IF NOT EXISTS `rp_job_bank_accounts`" in schema
    assert "CREATE TABLE IF NOT EXISTS `rp_job_bank_transactions`" in schema

    # 007 + 008 + 009: backward-compatible reports and bank ledger upgrades.
    assert "rp_report_status_stmt" in schema
    assert "'accepted','resolved','rejected'" in schema
    assert "rp_salary_index_stmt" in schema
    assert "idx_bank_salary_reason_created" in schema
    assert "rp_bank_type_stmt" in schema
    assert "'fuel_refund','fuel'" in schema

    # 010: AEGIS configuration and legacy evidence provenance.
    for table in ("anticheat_protection_config", "anticheat_runtime_config", "anticheat_event_log"):
        assert f"CREATE TABLE IF NOT EXISTS `{table}`" in schema
    assert "`source_type` VARCHAR(16) NOT NULL DEFAULT 'legacy'" in schema
    assert "rp_aegis_source_type_stmt" in schema

    assert not (ROOT / "migrations").exists()
