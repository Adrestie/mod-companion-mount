-- mod-companion-mount — characters schema.
--
-- What a character chose: the mount spell that gives the companion its look,
-- and whether he wants it at his side. Levels, experience, talents, bags and
-- names of the mounts will come in tables of their own.
--
-- Idempotent: the file may be replayed, it creates nothing that already exists.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_character` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL DEFAULT 0,
  `summoned` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the companion mount a character chose';
