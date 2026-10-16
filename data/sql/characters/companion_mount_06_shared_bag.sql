-- mod-companion-mount — ONE pair of saddlebags per character.
--
-- The same saddlebags on all the mounts of a character: one row per item, its
-- place and the item itself, which stays in `item_instance` (enchantments,
-- gems, durability, binding kept), out of `character_inventory` -- as a mail
-- attachment.
--
-- The first version (companion_mount_05_bag.sql) kept one bag per mount in
-- `mod_companion_mount_item`: what it holds moves into the shared bag,
-- numbered after what the shared bag already holds, and the old table goes
-- once empty.
--
-- Replayable: nothing is created or moved twice.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_bag` (
  `guid` INT UNSIGNED NOT NULL,
  `slot` TINYINT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `slot`),
  UNIQUE KEY `idx_item` (`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the items in the saddlebags of a character';

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`TABLES`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_item');

-- The items of the old bags, after those of the shared bag.
SET @companion_mount_sql := IF(@companion_mount_has = 0, 'DO 0',
    'INSERT IGNORE INTO `mod_companion_mount_bag` (`guid`, `slot`, `item_guid`)
     SELECT o.`guid`,
            IFNULL((SELECT MAX(b.`slot`) + 1 FROM `mod_companion_mount_bag` b WHERE b.`guid` = o.`guid`), 0)
              + ROW_NUMBER() OVER (PARTITION BY o.`guid` ORDER BY o.`mount_spell`, o.`slot`) - 1,
            o.`item_guid`
     FROM `mod_companion_mount_item` o
     WHERE o.`item_guid` NOT IN (SELECT `item_guid` FROM `mod_companion_mount_bag`)');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

SET @companion_mount_sql := IF(@companion_mount_has = 0, 'DO 0',
    'DELETE FROM `mod_companion_mount_item` WHERE `item_guid` IN (SELECT `item_guid` FROM `mod_companion_mount_bag`)');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

-- The old table goes only when nothing is left in it.
SET @companion_mount_left := 0;
SET @companion_mount_sql := IF(@companion_mount_has = 0, 'DO 0',
    'SELECT COUNT(*) INTO @companion_mount_left FROM `mod_companion_mount_item`');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

SET @companion_mount_sql := IF(@companion_mount_has = 0 OR @companion_mount_left > 0, 'DO 0',
    'DROP TABLE `mod_companion_mount_item`');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;
