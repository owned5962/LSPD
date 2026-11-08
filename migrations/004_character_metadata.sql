-- Apply once to an existing database to persist hunger, thirst and other character needs.
-- Back up the database before running this migration.
ALTER TABLE `characters`
    ADD COLUMN `metadata` LONGTEXT DEFAULT NULL;
