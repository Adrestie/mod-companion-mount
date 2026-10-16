-- mod-companion-mount — the gambits of each mount (docs/energie-gambits.md).
--
-- One row per slot, read from top to bottom: `cond` the target and condition, `action`
-- the first rank of a spell, -1 Attack, -2 Come back. `custom` 0: the default list,
-- drawn from the spells learned and written again as they change; 1: the player's own.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_gambit` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL,
  `slot` TINYINT UNSIGNED NOT NULL,
  `enabled` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `cond` SMALLINT UNSIGNED NOT NULL,
  `action` INT NOT NULL,
  `custom` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`guid`, `mount_spell`, `slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the gambits of each mount (target + condition -> action)';
