-- mod-companion-mount — enough points in Benevolence to reach its last rows, and no
-- Toughness twice.
--
-- With 5 points per row, the next to last row asks 20 points in the tree and the last
-- one 25; Benevolence held only 19 in its first four rows. Its Toughness, a tank talent,
-- gives way to Netherwind Presence (+2-6 % spell haste: quicker heals), and Conviction
-- (+1-5 % critical strike, heals included) joins the fourth row: 24 points before the next
-- to last row, 27 before the ultimate.
--
-- Rampart had two talents named Toughness (armor and stamina): the armor one gives way to
-- Spell Warding (-2-10 % spell damage taken); Thick Hide already raises the armor.
--
-- Replayable: the rows are written again.

UPDATE `mod_companion_mount_talent`
SET `spell_1` = 44400, `spell_2` = 44402, `spell_3` = 44403, `spell_4` = 0, `spell_5` = 0
WHERE `id` = 1204;   -- Netherwind Presence: +2-6 % spell haste

DELETE FROM `mod_companion_mount_talent` WHERE `id` = 1215;
INSERT INTO `mod_companion_mount_talent` (`id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, `cooldown`) VALUES
(1215, 2, 3, 2, 20117, 20118, 20119, 20120, 20121, 0, 0);   -- Conviction: +1-5 % critical strike

UPDATE `mod_companion_mount_talent`
SET `spell_1` = 27900, `spell_2` = 27901, `spell_3` = 27902, `spell_4` = 27903, `spell_5` = 27904
WHERE `id` = 1101;   -- Spell Warding: -2-10 % spell damage taken

-- `.companion reload`: the talents read again from the database, without a restart.
DELETE FROM `command` WHERE `name` = 'companion reload';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion reload', 3, 'Syntax: .companion reload\n\nReads the talents, the kinds of mounts and the key spells again from the database.');

-- The help of `.companion talent learn` still told of one tree and 3 points per row.
UPDATE `command` SET `help` = 'Syntax: .companion talent learn $id\n\nOne more rank of a talent of your companion mount (5 points in its tree per row).'
WHERE `name` = 'companion talent learn';
