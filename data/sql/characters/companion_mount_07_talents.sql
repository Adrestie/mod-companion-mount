-- mod-companion-mount — the talents each mount learned.
--
-- One row per character, mount spell and talent: the rank learned. The tree
-- of a mount is the tree of its talents (one tree per mount).
--
-- Replayable: nothing is created twice.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_talent_rank` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL,
  `talent_id` INT UNSIGNED NOT NULL,
  `rank` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`, `mount_spell`, `talent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the talents each mount of a character learned';
