-- Run once on an existing database after backing it up.
CREATE TABLE IF NOT EXISTS `player_bans` (
    `identifier` VARCHAR(64) NOT NULL PRIMARY KEY,
    `reason` VARCHAR(255) NOT NULL,
    `banned_by` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
