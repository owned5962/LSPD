-- GTA 5 Roleplay schema (MySQL 8 / MariaDB compatible)
CREATE TABLE IF NOT EXISTS `users` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL UNIQUE,
    `license` VARCHAR(64) DEFAULT NULL,
    `discord` VARCHAR(64) DEFAULT NULL,
    `name` VARCHAR(64) NOT NULL,
    `group` VARCHAR(32) NOT NULL DEFAULT 'user',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_seen` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(64) NOT NULL,
    `char_id` TINYINT UNSIGNED NOT NULL DEFAULT 1,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `dateofbirth` DATE NOT NULL,
    `sex` CHAR(1) NOT NULL DEFAULT 'm',
    `height` SMALLINT UNSIGNED NOT NULL DEFAULT 175,
    `phone_number` VARCHAR(16) DEFAULT NULL,
    `cash` BIGINT NOT NULL DEFAULT 2500,
    `bank` BIGINT NOT NULL DEFAULT 10000,
    `job` VARCHAR(50) NOT NULL DEFAULT 'unemployed',
    `job_grade` INT NOT NULL DEFAULT 0,
    `position` LONGTEXT DEFAULT NULL,
    `skin` LONGTEXT DEFAULT NULL,
    `is_dead` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_user_char` (`identifier`, `char_id`),
    CONSTRAINT `fk_characters_users` FOREIGN KEY (`identifier`) REFERENCES `users` (`identifier`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `character_id` INT NOT NULL,
    `type` ENUM('deposit', 'withdraw', 'transfer_send', 'transfer_receive', 'salary') NOT NULL,
    `amount` BIGINT NOT NULL,
    `sender_or_receiver` VARCHAR(128) DEFAULT NULL,
    `reason` VARCHAR(255) DEFAULT 'Transaction',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT `fk_bank_characters` FOREIGN KEY (`character_id`) REFERENCES `characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `jobs` (
    `name` VARCHAR(50) PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `category` VARCHAR(50) NOT NULL DEFAULT 'civilian',
    `whitelisted` TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `job_grades` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job_name` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `label` VARCHAR(100) NOT NULL,
    `salary` INT NOT NULL DEFAULT 200,
    UNIQUE KEY `unique_job_grade` (`job_name`, `grade`),
    CONSTRAINT `fk_job_grades_jobs` FOREIGN KEY (`job_name`) REFERENCES `jobs` (`name`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `admin_identifier` VARCHAR(64) NOT NULL,
    `admin_name` VARCHAR(64) NOT NULL,
    `action` VARCHAR(64) NOT NULL,
    `target_identifier` VARCHAR(64) DEFAULT NULL,
    `details` TEXT DEFAULT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `items` (
    `name` VARCHAR(50) PRIMARY KEY,
    `label` VARCHAR(100) NOT NULL,
    `weight` DECIMAL(10,2) NOT NULL DEFAULT 1.0,
    `rare` TINYINT(1) NOT NULL DEFAULT 0,
    `can_remove` TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
('bread', 'Pain', 0.5, 0, 1), ('water', 'Bouteille d\'eau', 0.5, 0, 1),
('medikit', 'Kit de secours', 1.0, 0, 1), ('bandage', 'Bandage', 0.2, 0, 1),
('repairkit', 'Kit de réparation', 3.0, 0, 1), ('handcuffs', 'Menottes de police', 0.8, 0, 1),
('phone', 'Téléphone portable', 0.2, 0, 1), ('id_card', 'Carte d\'identité', 0.1, 0, 0),
('driver_license', 'Permis de conduire', 0.1, 0, 0), ('radio', 'Talkie-walkie', 0.5, 0, 1);

CREATE TABLE IF NOT EXISTS `billing` (
    `id` INT AUTO_INCREMENT PRIMARY KEY, `identifier` VARCHAR(64) NOT NULL,
    `sender` VARCHAR(64) NOT NULL, `target_type` VARCHAR(50) NOT NULL DEFAULT 'player',
    `target` VARCHAR(64) NOT NULL, `label` VARCHAR(255) NOT NULL, `amount` INT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `user_outfits` (
    `id` INT AUTO_INCREMENT PRIMARY KEY, `identifier` VARCHAR(64) NOT NULL,
    `character_id` INT NOT NULL, `name` VARCHAR(50) NOT NULL, `skin_data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (`identifier`), INDEX (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
