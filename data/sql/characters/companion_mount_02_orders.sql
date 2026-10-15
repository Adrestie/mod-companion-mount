-- mod-companion-mount — the orders of the companion mount.
--
-- command_state  0 follow, 1 stay (a login always starts on follow)
-- react_state    0 passive, 1 defensive, 2 aggressive (ReactStates)
--
-- Replayable: each column is added only when it is missing.

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_character'
      AND `COLUMN_NAME` = 'command_state');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_character` ADD COLUMN `command_state` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `summoned`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_character'
      AND `COLUMN_NAME` = 'react_state');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_character` ADD COLUMN `react_state` TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER `command_state`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;
