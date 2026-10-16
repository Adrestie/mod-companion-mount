-- mod-companion-mount — the gambit presets: named lists of gambits of each character,
-- which any of its mounts may load (the Gambits tab, or /compagnon preset <name>).
-- The interface creates the table too if it is missing (the same statement).

CREATE TABLE IF NOT EXISTS `mod_companion_mount_gambit_preset` (
  `guid` INT UNSIGNED NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `slot` TINYINT UNSIGNED NOT NULL,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `cond` SMALLINT UNSIGNED NOT NULL,
  `action` INT NOT NULL,
  PRIMARY KEY (`guid`, `name`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the gambit presets of each character';
