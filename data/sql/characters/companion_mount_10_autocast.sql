-- mod-companion-mount — the spells of the bar: those whose automatic casting the player cut.
--
-- Like the abilities of a hunter's pet, every spell a mount learned casts by itself; a
-- right click on the bar cuts it (a row here, per mount and first rank), another one
-- gives it back.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_autocast` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL,
  `spell` INT UNSIGNED NOT NULL COMMENT 'first rank',
  PRIMARY KEY (`guid`, `mount_spell`, `spell`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the spells whose automatic casting the player cut';
