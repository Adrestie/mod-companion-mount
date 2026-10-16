-- mod-companion-mount — enough points in Benevolence to reach its last rows.
--
-- With 5 points per row, the next to last row asks 20 points in the tree and the last
-- one 25; Benevolence held only 19 in its first four rows. Toughness gets its five
-- ranks (16252, 16306-16309) and Deadened Nerves (-2 to -6 % damage taken) joins the
-- fourth row: 24 points before the next to last row, 27 before the ultimate.
--
-- Replayable: the rows are written again.

UPDATE `mod_companion_mount_talent` SET `spell_4` = 16308, `spell_5` = 16309 WHERE `id` = 1204;

DELETE FROM `mod_companion_mount_talent` WHERE `id` = 1215;
INSERT INTO `mod_companion_mount_talent` (`id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, `cooldown`) VALUES
(1215, 2, 3, 2, 31380, 31382, 31383, 0, 0, 0, 0);   -- Deadened Nerves: -2-6 % damage taken

-- `.companion reload`: the talents read again from the database, without a restart.
DELETE FROM `command` WHERE `name` = 'companion reload';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion reload', 3, 'Syntax: .companion reload

Reads the talents, the kinds of mounts and the key spells again from the database.');
