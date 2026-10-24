-- mod-companion-mount — the stats of each family, and the magic damage tree (docs/stats-familles.md).
--
-- At each level-up a family gains fixed amounts: `*_low` / `*_high`, the high one on even levels
-- ("1 to 2" gives 1, 2, 1, 2...). `first_tree`: 0 Fury (physical DPS) or 3 Sorcery (magic DPS),
-- the first tree its talent window shows. Kinds: 1 horse, 2 undead, 3 wolf, 4 feline, 5 raptor,
-- 6 heavy beast, 7 bear, 8 bird, 9 dragon, 10 winged beast, 11 insect, 12 machine.
--
-- Replayable: the tables are created once, the rows written again.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_kind_stats` (
  `kind` TINYINT UNSIGNED NOT NULL,
  `first_tree` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `strength_low` TINYINT UNSIGNED NOT NULL DEFAULT 0, `strength_high` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `agility_low` TINYINT UNSIGNED NOT NULL DEFAULT 0, `agility_high` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `stamina_low` TINYINT UNSIGNED NOT NULL DEFAULT 0, `stamina_high` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `spell_damage_low` TINYINT UNSIGNED NOT NULL DEFAULT 0, `spell_damage_high` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `healing_low` TINYINT UNSIGNED NOT NULL DEFAULT 0, `healing_high` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `comment` VARCHAR(48) NOT NULL DEFAULT '',
  PRIMARY KEY (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: what each family gains per level, and its first tree';

DELETE FROM `mod_companion_mount_kind_stats`;
INSERT INTO `mod_companion_mount_kind_stats` (`kind`, `first_tree`, `strength_low`, `strength_high`, `agility_low`, `agility_high`,
    `stamina_low`, `stamina_high`, `spell_damage_low`, `spell_damage_high`, `healing_low`, `healing_high`, `comment`) VALUES
(3, 0, 3, 3, 2, 2, 1, 2, 0, 0, 0, 0, 'wolf: physical DPS'),
(5, 0, 3, 3, 2, 2, 1, 2, 0, 0, 0, 0, 'raptor: physical DPS'),
(4, 0, 3, 3, 1, 1, 1, 1, 0, 0, 2, 2, 'feline: physical DPS'),
(6, 0, 3, 3, 0, 0, 3, 4, 0, 0, 0, 0, 'heavy beast: tank'),
(12, 0, 3, 3, 0, 0, 3, 4, 0, 0, 0, 0, 'machine: tank'),
(7, 0, 2, 2, 0, 0, 3, 3, 0, 0, 2, 2, 'bear: tank'),
(11, 0, 2, 2, 0, 0, 3, 3, 0, 0, 2, 2, 'insect: tank'),
(9, 3, 0, 0, 0, 0, 2, 2, 4, 5, 0, 0, 'dragon: magic DPS'),
(2, 3, 0, 0, 0, 0, 1, 1, 3, 4, 1, 2, 'undead: magic DPS'),
(1, 0, 2, 2, 0, 0, 2, 2, 0, 0, 4, 5, 'horse: healer'),
(10, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 4, 'winged beast: healer'),
(8, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 4, 'bird: healer');

-- SORCERY (tree 3): the magic damage tree of the undead and the dragon, in Fury's place.
-- `use`: 0 passive, 1 its victim, 2 itself in combat (area around it). `energy`: 0 quick,
-- 1 strong or area, 2 control, 4 the ultimate.
DELETE FROM `mod_companion_mount_talent` WHERE `id` BETWEEN 1301 AND 1316 OR `id` = 90013;
INSERT INTO `mod_companion_mount_talent` (`id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, `cooldown`, `energy`) VALUES
(1301, 3, 0, 1, 48987, 49477, 49478, 49479, 49480, 0, 0, 0),   -- Dark Conviction: +1-5 % critical strike
(1302, 3, 0, 2, 44400, 44402, 44403, 0, 0, 0, 0, 0),           -- Netherwind Presence: +2-6 % spell haste
(1303, 3, 1, 0, 13705, 13832, 13843, 13844, 13845, 0, 0, 0),   -- Precision: +1-5 % hit
(1304, 3, 1, 1, 686, 0, 0, 0, 0, 1, 0, 0),                     -- Shadow Bolt (ranked)
(1305, 3, 1, 2, 172, 0, 0, 0, 0, 1, 0, 0),                     -- Corruption (ranked)
(1306, 3, 2, 0, 16255, 16302, 16303, 16304, 16305, 0, 0, 0),   -- Thundering Strikes: +1-5 % critical strike
(1307, 3, 2, 1, 133, 0, 0, 0, 0, 1, 0, 1),                     -- Fireball (ranked)
(1308, 3, 2, 2, 116, 0, 0, 0, 0, 1, 0, 0),                     -- Frostbolt (ranked): slows
(1309, 3, 2, 3, 122, 0, 0, 0, 0, 2, 0, 2),                     -- Frost Nova (ranked): roots around it
(1310, 3, 3, 0, 63349, 63350, 63351, 0, 0, 0, 0, 0),           -- Molten Skin: -2-6 % damage taken
(1311, 3, 3, 1, 421, 0, 0, 0, 0, 1, 0, 1),                     -- Chain Lightning (ranked)
(1312, 3, 3, 2, 8042, 0, 0, 0, 0, 1, 0, 2),                    -- Earth Shock (ranked): interrupts
(1313, 3, 3, 3, 1449, 0, 0, 0, 0, 2, 0, 1),                    -- Arcane Explosion (ranked): around it
(90013, 3, 4, 0, 0, 0, 0, 0, 0, 1, 0, 0),                      -- the key spell of the family
(1314, 3, 4, 1, 11113, 0, 0, 0, 0, 2, 0, 1),                   -- Blast Wave (ranked): around it
(1315, 3, 4, 2, 8921, 0, 0, 0, 0, 1, 0, 0),                    -- Moonfire (ranked)
(1316, 3, 5, 1, 48505, 0, 0, 0, 0, 2, 0, 4);                   -- Starfall (ranked): the ultimate

-- The key spells of Sorcery: those the undead and the dragon had in Fury.
DELETE FROM `mod_companion_mount_key_spell` WHERE `tree` = 3;
INSERT INTO `mod_companion_mount_key_spell` (`kind`, `tree`, `key_spell`, `use`, `comment`) VALUES
(2, 3, 17238, 1, 'undead: Drain Life'),
(9, 3, 59197, 1, 'dragon: Fire Breath');

-- The name of the tree, and the refusal of a talent of the other damage tree.
DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` IN (47, 48);
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 47, 'Sorcery'),
('mod-companion-mount', 48, 'That talent is not in the trees of this kind of mount.');
DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` IN (47, 48);
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 47, 'frFR', 'Sorcellerie'),
('mod-companion-mount', 48, 'frFR', 'Ce talent n''est pas dans les arbres de ce type de monture.');
