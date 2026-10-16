-- mod-companion-mount — energy and gambits (docs/energie-gambits.md).
--
-- Every spell of the mount costs energy (100, +10 a second): its class here, the amounts in
-- the configuration (CompanionMount.Energy.Cost.*). 0 quick attack or heal (25), 1 strong
-- heal or attack, area spell (40), 2 defensive or control spell (50); the key spell (60)
-- and the ultimates (80) are told apart by the module. Energy replaces the delays between
-- two casts: only Shield Wall keeps one, as the ultimates keep their own cooldown.
--
-- Replayable: the column is added once, the rows written again.

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_talent' AND `COLUMN_NAME` = 'energy');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_talent` ADD COLUMN `energy` TINYINT UNSIGNED NOT NULL DEFAULT 0 AFTER `cooldown`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

UPDATE `mod_companion_mount_talent` SET `energy` = 0;
-- Strong heal or attack, area spell.
UPDATE `mod_companion_mount_talent` SET `energy` = 1 WHERE `id` IN (1007, 1010, 1011, 1013, 1207, 1210, 1212);
-- Defensive or control spell.
UPDATE `mod_companion_mount_talent` SET `energy` = 2 WHERE `id` IN (1104, 1107, 1108, 1110, 1112, 1113, 1208);
-- The ultimates.
UPDATE `mod_companion_mount_talent` SET `energy` = 4 WHERE `id` IN (1014, 1114, 1213);

UPDATE `mod_companion_mount_talent` SET `cooldown` = 0 WHERE `id` <> 1113 AND `use` NOT IN (0, 6);

DELETE FROM `command` WHERE `name` IN ('companion gambit', 'companion gambit save', 'companion gambit reset', 'companion frame');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion gambit', 0, 'Syntax: .companion gambit\n\nThe gambits of your companion mount: target and condition, then action, read from top to bottom. The Gambits window changes them.'),
('companion gambit save', 0, 'Syntax: .companion gambit save $enabled:$condition:$action,...\n\nWrites the whole list of gambits of your companion mount (what the Gambits window sends).'),
('companion gambit reset', 0, 'Syntax: .companion gambit reset\n\nGives your companion mount back the default gambits, drawn from the spells it learned.'),
('companion frame', 0, 'Syntax: .companion frame\n\nSends the portrait of your companion mount to the interface again.');
