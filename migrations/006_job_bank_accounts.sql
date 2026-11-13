
-- Comptes bancaires partagés par métier et historique des dépôts/retraits.
CREATE TABLE IF NOT EXISTS `rp_job_bank_accounts` (
    `job` VARCHAR(64) NOT NULL PRIMARY KEY,
    `balance` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `allow_deposit` TINYINT(1) NOT NULL DEFAULT 1,
    `allow_withdraw` TINYINT(1) NOT NULL DEFAULT 1,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `rp_job_bank_transactions` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(64) NOT NULL,
    `character_id` INT NOT NULL,
    `player_name` VARCHAR(128) NOT NULL,
    `transaction_type` ENUM('deposit','withdraw') NOT NULL,
    `amount` BIGINT UNSIGNED NOT NULL,
    `balance_after` BIGINT UNSIGNED NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_job_bank_history` (`job`, `id`),
    KEY `idx_job_bank_character` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
