-- Apply once to an existing database created with the previous schema.
-- MySQL/MariaDB will convert valid YYYY-MM-DD VARCHAR values to DATE.
ALTER TABLE `characters`
    MODIFY COLUMN `dateofbirth` DATE NOT NULL;

-- The unique (identifier, char_id) key already exists in the previous schema.
-- If this is a fresh installation, import database.sql instead of this migration.
