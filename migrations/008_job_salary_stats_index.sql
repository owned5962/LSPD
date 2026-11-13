-- Accélère l'agrégation des salaires par métier et période.
ALTER TABLE `bank_transactions`
    ADD INDEX `idx_bank_salary_reason_created` (`type`, `reason`, `created_at`);
