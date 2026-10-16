-- mod-companion-mount — the saddlebags of the mounts.
--
-- One row per item a mount carries: the place in its saddlebags and the item
-- itself, which stays in `item_instance` (enchantments, gems, durability,
-- binding kept), out of `character_inventory` -- as a mail attachment.
--
-- Replayable: nothing is created twice.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_item` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL,
  `slot` TINYINT UNSIGNED NOT NULL,
  `item_guid` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `mount_spell`, `slot`),
  UNIQUE KEY `idx_item` (`item_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the items in the saddlebags of each mount';
