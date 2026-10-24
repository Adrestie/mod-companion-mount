-- mod-companion-mount — the sheet shows the stats of the family: strength, agility, stamina,
-- spell damage and healing power. Replayable: each column is added once.

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_snapshot' AND `COLUMN_NAME` = 'strength');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_snapshot` ADD COLUMN `strength` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `agility` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `stamina` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `spell_damage` INT UNSIGNED NOT NULL DEFAULT 0, ADD COLUMN `healing_power` INT UNSIGNED NOT NULL DEFAULT 0',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;
