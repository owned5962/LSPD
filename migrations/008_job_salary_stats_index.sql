-- Add the salary aggregation index only when it is not already present.
-- The main database.sql schema already creates this index on fresh installations.
SET @rp_salary_index_exists = (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'bank_transactions'
      AND INDEX_NAME = 'idx_bank_salary_reason_created'
);
SET @rp_salary_index_sql = IF(
    @rp_salary_index_exists = 0,
    'ALTER TABLE `bank_transactions` ADD INDEX `idx_bank_salary_reason_created` (`type`, `reason`, `created_at`)',
    'SELECT 1'
);
PREPARE rp_salary_index_stmt FROM @rp_salary_index_sql;
EXECUTE rp_salary_index_stmt;
DEALLOCATE PREPARE rp_salary_index_stmt;
