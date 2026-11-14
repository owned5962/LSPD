-- AEGIS runtime settings and evidence provenance.
CREATE TABLE IF NOT EXISTS `anticheat_protection_config` (
    `protection_key` VARCHAR(50) NOT NULL,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`protection_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `anticheat_runtime_config` (
    `config_key` VARCHAR(40) NOT NULL,
    `config_value` VARCHAR(255) NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `anticheat_event_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id` INT NOT NULL,
    `player_identifier` VARCHAR(80) NULL,
    `player_name` VARCHAR(100) NOT NULL,
    `detection_type` VARCHAR(40) NOT NULL,
    `reason` VARCHAR(180) NOT NULL,
    `severity` VARCHAR(16) NOT NULL,
    `sanction` VARCHAR(16) NOT NULL DEFAULT 'warn',
    `source_type` VARCHAR(16) NOT NULL DEFAULT 'legacy',
    `items_snapshot` LONGTEXT NULL,
    `weapons_snapshot` LONGTEXT NULL,
    `cash_snapshot` BIGINT NULL,
    `bank_snapshot` BIGINT NULL,
    `job_name` VARCHAR(50) NULL,
    `job_label` VARCHAR(100) NULL,
    `job_grade` INT NULL,
    `job_grade_label` VARCHAR(100) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `idx_anticheat_event_created` (`created_at`),
    INDEX `idx_anticheat_event_player` (`player_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @aegis_source_type_exists = (
    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'anticheat_event_log'
      AND COLUMN_NAME = 'source_type'
);
SET @aegis_source_type_sql = IF(
    @aegis_source_type_exists = 0,
    'ALTER TABLE `anticheat_event_log` ADD COLUMN `source_type` VARCHAR(16) NOT NULL DEFAULT ''legacy'' AFTER `sanction`',
    'SELECT 1'
);
PREPARE aegis_source_type_stmt FROM @aegis_source_type_sql;
EXECUTE aegis_source_type_stmt;
DEALLOCATE PREPARE aegis_source_type_stmt;
