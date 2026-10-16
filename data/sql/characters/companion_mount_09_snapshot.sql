-- mod-companion-mount — the sheet of the companion mount, for the interface.
--
-- One row per character, written again by `.companion snapshot` whenever the window
-- asks: the numbers ALE cannot read from a creature (armor, damage, critical strike,
-- dodge, parry...), and those of the module (level, experience, talents, orders).
-- Nothing in it is kept: it is rebuilt at every request.
--
-- Replayable: nothing is created twice.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_snapshot` (
  `guid` INT UNSIGNED NOT NULL,
  `mount_spell` INT UNSIGNED NOT NULL DEFAULT 0,
  `name` VARCHAR(24) NOT NULL DEFAULT '',
  `kind` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `creature` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'the creature the mount spell shows, for the 3D view',
  `display` INT UNSIGNED NOT NULL DEFAULT 0,
  `level` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `xp` INT UNSIGNED NOT NULL DEFAULT 0,
  `xp_next` INT UNSIGNED NOT NULL DEFAULT 0,
  `out` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `health` INT UNSIGNED NOT NULL DEFAULT 0,
  `max_health` INT UNSIGNED NOT NULL DEFAULT 0,
  `armor` INT UNSIGNED NOT NULL DEFAULT 0,
  `attack_power` INT UNSIGNED NOT NULL DEFAULT 0,
  `min_damage` INT UNSIGNED NOT NULL DEFAULT 0,
  `max_damage` INT UNSIGNED NOT NULL DEFAULT 0,
  `attack_time` INT UNSIGNED NOT NULL DEFAULT 0,
  `crit` FLOAT NOT NULL DEFAULT 0,
  `dodge` FLOAT NOT NULL DEFAULT 0,
  `parry` FLOAT NOT NULL DEFAULT 0,
  `tree` TINYINT UNSIGNED NOT NULL DEFAULT 255 COMMENT '255: none',
  `points_spent` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `points_total` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `command_state` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `react_state` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the sheet of the companion mount, rebuilt for the interface';
