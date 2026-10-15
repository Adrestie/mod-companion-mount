-- mod-companion-mount — the levels of the mounts.
--
-- mod_companion_mount_mount   one row per character and mount spell: its
--                              level, the experience toward the next one, and
--                              how much of the shared pool it has received.
-- shared_pool (character)      all the experience ever shared with the mounts
--                              left in the stable; a mount coming out receives
--                              what it has not seen of it yet.
--
-- Replayable: nothing is created twice.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_mount` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL,
  `level` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `pool_seen` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`, `mount_spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the level and experience of each mount of a character';

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_character'
      AND `COLUMN_NAME` = 'shared_pool');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_character` ADD COLUMN `shared_pool` BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER `react_state`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;
