-- Apply safely to an existing database. Re-running the migration is harmless.
-- Back up the database before applying schema changes.
SET @rp_metadata_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'characters'
      AND COLUMN_NAME = 'metadata'
);
SET @rp_metadata_sql = IF(
    @rp_metadata_exists = 0,
    'ALTER TABLE `characters` ADD COLUMN `metadata` LONGTEXT DEFAULT NULL',
    'SELECT 1'
);
PREPARE rp_metadata_stmt FROM @rp_metadata_sql;
EXECUTE rp_metadata_stmt;
DEALLOCATE PREPARE rp_metadata_stmt;
