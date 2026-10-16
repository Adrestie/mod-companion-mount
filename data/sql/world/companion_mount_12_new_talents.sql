-- mod-companion-mount — the talents of the mounts, their own (no longer the hunter pets').
--
-- Three trees of spells the 3.3.5 client already knows (icon, tooltip):
--   DPS  "Fury"        (1001-1013)
--   Tank "Rampart"     (1101-1114)
--   Heal "Benevolence" (1201-1214)
-- Passives: class talents WITHOUT class masks (they modify no class's own spells, so they
-- work on any creature), up to five ranks. Actives: spells of NPCs (family 0) or ranked
-- spells -- the mount casts the highest rank its level allows. The KEY talent (90010-90012)
-- tops every tree; its spell depends on the mount's kind (mod_companion_mount_kind_spell).
--
-- `use`: 0 passive aura on the mount, 1 cast on its victim, 2 on itself in combat, 3 on
-- itself under half health, 4 on its master in combat, 5 on its master under 80 % health.
-- `cooldown`: milliseconds between two casts by the AI, 0 for the spell's own cooldown.
--
-- Replayable: the columns are added once, the rows written again.

SET @companion_mount_has := (SELECT COUNT(*) FROM `information_schema`.`COLUMNS`
    WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = 'mod_companion_mount_talent' AND `COLUMN_NAME` = 'spell_4');
SET @companion_mount_sql := IF(@companion_mount_has = 0,
    'ALTER TABLE `mod_companion_mount_talent` ADD COLUMN `spell_4` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `spell_3`, ADD COLUMN `spell_5` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `spell_4`',
    'DO 0');
PREPARE companion_mount_stmt FROM @companion_mount_sql;
EXECUTE companion_mount_stmt;
DEALLOCATE PREPARE companion_mount_stmt;

DELETE FROM `mod_companion_mount_talent`;
INSERT INTO `mod_companion_mount_talent` (`id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, `cooldown`) VALUES
-- DPS: Fury
(1001, 0, 0, 1, 12320, 12852, 12853, 12855, 12856, 0, 0),       -- Cruelty: +1-5 % critical strike
(1002, 0, 0, 2, 13705, 13832, 13843, 13844, 13845, 0, 0),       -- Precision: +1-5 % hit
(1003, 0, 1, 0, 3391, 0, 0, 0, 0, 1, 8000),                     -- Thrash: 2 extra attacks
(1004, 0, 1, 1, 30902, 30903, 30904, 30905, 30906, 0, 0),       -- Deadliness: +2-10 % attack power
(1005, 0, 1, 2, 31866, 31867, 31868, 0, 0, 0, 0),               -- Crusade: +1-3 % damage
(1006, 0, 2, 1, 12319, 12971, 12972, 12973, 12974, 0, 0),       -- Flurry: haste after a critical strike
(1007, 0, 2, 2, 15284, 0, 0, 0, 0, 1, 6000),                    -- Cleave: the target and its neighbours
(1008, 0, 2, 3, 11971, 0, 0, 0, 0, 1, 6000),                    -- Sunder Armor: armor down, stacks
(1009, 0, 3, 0, 13712, 13788, 13789, 0, 0, 0, 0),               -- Lightning Reflexes: dodge and melee haste
(1010, 0, 3, 1, 5568, 0, 0, 0, 0, 1, 10000),                    -- Trample: damage around
(1011, 0, 4, 1, 8599, 0, 0, 0, 0, 2, 45000),                    -- Enrage: physical damage and attack speed
(1012, 0, 4, 2, 30802, 30808, 30809, 0, 0, 0, 0),               -- Unleashed Rage: attack power of the party
(1013, 0, 4, 3, 6673, 0, 0, 0, 0, 2, 110000),                   -- Battle Shout (ranked): attack power of the party
(90010, 0, 5, 1, 0, 0, 0, 0, 0, 1, 0),                          -- KEY
-- Tank: Rampart
(1101, 1, 0, 1, 12299, 12761, 12762, 12763, 12764, 0, 0),       -- Toughness: +2-10 % armor
(1102, 1, 0, 2, 16252, 16306, 16307, 16308, 16309, 0, 0),       -- Toughness: +2-10 % stamina
(1103, 1, 1, 0, 12297, 12750, 12751, 12752, 12753, 0, 0),       -- Anticipation: +1-5 % dodge
(1104, 1, 1, 1, 29060, 0, 0, 0, 0, 1, 10000),                   -- Taunt (NPC, no stance)
(1105, 1, 1, 2, 16462, 16463, 16464, 16465, 16466, 0, 0),       -- Deflection: +1-5 % parry
(1106, 1, 2, 0, 16929, 16930, 16931, 0, 0, 0, 0),               -- Thick Hide: +4-10 % armor
(1107, 1, 2, 1, 5164, 0, 0, 0, 0, 1, 15000),                    -- Knockdown: stuns the target
(1108, 1, 2, 2, 1160, 0, 0, 0, 0, 2, 30000),                    -- Demoralizing Shout (ranked): attack power of enemies down
(1109, 1, 3, 1, 31380, 31382, 31383, 0, 0, 0, 0),               -- Deadened Nerves: -2-6 % damage taken
(1110, 1, 3, 2, 16508, 0, 0, 0, 0, 1, 30000),                   -- Intimidating Roar: terror on the target and around
(1111, 1, 4, 0, 31244, 31245, 0, 0, 0, 0, 0),                   -- Quick Recovery: +10-20 % healing taken
(1112, 1, 4, 1, 20549, 0, 0, 0, 0, 2, 0),                       -- War Stomp: stuns enemies around
(1113, 1, 4, 2, 15062, 0, 0, 0, 0, 3, 180000),                  -- Shield Wall (NPC): damage taken down, under half health
(90011, 1, 5, 1, 0, 0, 0, 0, 0, 1, 0),                          -- KEY
-- Heal: Benevolence
(1201, 2, 0, 1, 774, 0, 0, 0, 0, 5, 12000),                     -- Rejuvenation (ranked), on the master
(1202, 2, 0, 2, 63646, 63647, 63648, 63649, 63650, 0, 0),       -- Divinity: +1-5 % healing done and taken
(1203, 2, 1, 0, 139, 0, 0, 0, 0, 5, 12000),                     -- Renew (ranked), on the master
(1204, 2, 1, 1, 16252, 16306, 16307, 0, 0, 0, 0),               -- Toughness: +2-6 % stamina
(1205, 2, 1, 2, 2893, 0, 0, 0, 0, 4, 20000),                    -- Abolish Poison, on the master
(1206, 2, 2, 1, 33142, 33145, 33146, 0, 0, 0, 0),               -- Blessed Resilience: +1-3 % healing
(1207, 2, 2, 2, 8936, 0, 0, 0, 0, 5, 15000),                    -- Regrowth (ranked), on the master
(1208, 2, 2, 3, 17, 0, 0, 0, 0, 4, 30000),                      -- Power Word: Shield (ranked), on the master
(1209, 2, 3, 0, 31244, 31245, 0, 0, 0, 0, 0),                  -- Quick Recovery: +10-20 % healing taken
(1210, 2, 3, 1, 1064, 0, 0, 0, 0, 5, 10000),                    -- Chain Heal (ranked), on the master and the party
(1211, 2, 4, 1, 33763, 0, 0, 0, 0, 5, 10000),                   -- Lifebloom (ranked), on the master
(1212, 2, 4, 2, 33076, 0, 0, 0, 0, 4, 0),                       -- Prayer of Mending (ranked), on the master
(1213, 2, 5, 0, 740, 0, 0, 0, 0, 5, 0),                         -- Tranquility (ranked): the tree's ultimate
(90012, 2, 5, 1, 0, 0, 0, 0, 0, 1, 0);                          -- KEY

-- THE KEY SPELLS, of NPCs or ranked, no longer hunter pet techniques.
DELETE FROM `mod_companion_mount_kind_spell`;
INSERT INTO `mod_companion_mount_kind_spell` (`kind`, `key_spell`, `use`, `comment`) VALUES
(1, 5568, 1, 'horse'),          -- Trample
(2, 17238, 1, 'undead'),        -- Drain Life
(3, 6673, 2, 'wolf'),           -- Battle Shout (ranked)
(4, 3391, 1, 'feline'),         -- Thrash
(5, 8599, 2, 'raptor'),         -- Enrage
(6, 20549, 2, 'heavy beast'),   -- War Stomp
(7, 16508, 1, 'bear'),          -- Intimidating Roar
(8, 1160, 2, 'bird'),           -- Demoralizing Shout (ranked)
(9, 59197, 1, 'dragon'),        -- Fire Breath
(10, 50521, 1, 'winged beast'), -- Wing Buffet
(11, 11971, 1, 'insect'),       -- Sunder Armor
(12, 5164, 1, 'machine');       -- Knockdown
