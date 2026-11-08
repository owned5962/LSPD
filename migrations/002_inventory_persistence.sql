-- Run once on an existing database after backing it up.
CREATE TABLE IF NOT EXISTS `player_inventories` (
    `character_id` INT NOT NULL PRIMARY KEY,
    `items` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT `fk_inventory_character` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
