-- Run once on an existing database after backing it up.
-- Stores dropped inventory objects so they survive resource/server restarts.
CREATE TABLE IF NOT EXISTS `player_inventory_drops` (
    `id` VARCHAR(64) NOT NULL PRIMARY KEY,
    `item_name` VARCHAR(80) NOT NULL,
    `count` INT UNSIGNED NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `routing_bucket` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_inventory_drops_bucket` (`routing_bucket`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
