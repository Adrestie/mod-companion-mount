-- mod-companion-mount — a key spell per kind of mount AND per tree, and the ultimates.
--
-- The key talent at the top of each tree (90010 Fury, 90011 Rampart, 90012 Benevolence)
-- now gives a spell of the tree's role, chosen for the animal: an attack in Fury, a
-- defence in Rampart, a heal in Benevolence. `use` as mod_companion_mount_talent.use:
-- 1 its victim, 2 itself in combat, 3 itself under half health, 4 its master in combat,
-- 5 its master under 80 % health. Ranked spells take the rank the mount's level allows.
--
-- The ultimates: Heroism tops Fury (1014), Challenging Shout tops Rampart (1114), as
-- Tranquility tops Benevolence (1213).
--
-- Replayable: the table is created once, the rows written again.

CREATE TABLE IF NOT EXISTS `mod_companion_mount_key_spell` (
  `kind` TINYINT UNSIGNED NOT NULL,
  `tree` TINYINT UNSIGNED NOT NULL COMMENT '0 Fury, 1 Rampart, 2 Benevolence',
  `key_spell` INT UNSIGNED NOT NULL COMMENT 'first rank',
  `use` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `comment` VARCHAR(48) NOT NULL DEFAULT '',
  PRIMARY KEY (`kind`, `tree`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='CompanionMount: the key spell of each kind of mount, per tree';

DELETE FROM `mod_companion_mount_key_spell`;
INSERT INTO `mod_companion_mount_key_spell` (`kind`, `tree`, `key_spell`, `use`, `comment`) VALUES
(1, 0, 5568, 1, 'horse: Trample'),
(1, 1, 3411, 4, 'horse: Intervene'),
(1, 2, 635, 5, 'horse: Holy Light'),
(2, 0, 17238, 1, 'undead: Drain Life'),
(2, 1, 48707, 2, 'undead: Anti-Magic Shell'),
(2, 2, 47540, 5, 'undead: Penance'),
(3, 0, 6673, 2, 'wolf: Battle Shout'),
(3, 1, 12975, 3, 'wolf: Last Stand'),
(3, 2, 331, 5, 'wolf: Healing Wave'),
(4, 0, 3391, 1, 'feline: Thrash'),
(4, 1, 5277, 2, 'feline: Evasion'),
(4, 2, 5185, 5, 'feline: Healing Touch'),
(5, 0, 8599, 2, 'raptor: Enrage'),
(5, 1, 20230, 2, 'raptor: Retaliation'),
(5, 2, 8004, 5, 'raptor: Lesser Healing Wave'),
(6, 0, 20549, 2, 'heavy beast: War Stomp'),
(6, 1, 6343, 2, 'heavy beast: Thunder Clap'),
(6, 2, 596, 5, 'heavy beast: Prayer of Healing'),
(7, 0, 16508, 1, 'bear: Intimidating Roar'),
(7, 1, 99, 2, 'bear: Demoralizing Roar'),
(7, 2, 50464, 5, 'bear: Nourish'),
(8, 0, 1160, 2, 'bird: Demoralizing Shout'),
(8, 1, 19263, 3, 'bird: Deterrence'),
(8, 2, 2061, 5, 'bird: Flash Heal'),
(9, 0, 59197, 1, 'dragon: Fire Breath'),
(9, 1, 11426, 2, 'dragon: Ice Barrier'),
(9, 2, 48438, 5, 'dragon: Wild Growth'),
(10, 0, 50521, 1, 'winged beast: Wing Buffet'),
(10, 1, 498, 3, 'winged beast: Divine Protection'),
(10, 2, 19750, 5, 'winged beast: Flash of Light'),
(11, 0, 11971, 1, 'insect: Sunder Armor'),
(11, 1, 49222, 2, 'insect: Bone Shield'),
(11, 2, 2060, 5, 'insect: Greater Heal'),
(12, 0, 5164, 1, 'machine: Knockdown'),
(12, 1, 2565, 2, 'machine: Shield Block'),
(12, 2, 2054, 5, 'machine: Heal');

-- THE ULTIMATES, top left of Fury and Rampart.
DELETE FROM `mod_companion_mount_talent` WHERE `id` IN (1014, 1114);
INSERT INTO `mod_companion_mount_talent` (`id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, `cooldown`) VALUES
(1014, 0, 5, 0, 32182, 0, 0, 0, 0, 2, 0),   -- Heroism: +30 % haste for the party
(1114, 1, 5, 0, 1161, 0, 0, 0, 0, 2, 0);    -- Challenging Shout: every enemy around attacks the mount
