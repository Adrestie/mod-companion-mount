-- mod-companion-mount — the names of the mounts.
--
-- name   empty: the companion mount bears the name of its template.
--
-- Replayable: the column is added only when it is missing.

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_mount'
      AND `COLUMN_NAME` = 'name');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_mount` ADD COLUMN `name` VARCHAR(24) NOT NULL DEFAULT '''' AFTER `pool_seen`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;
