-- mod-companion-mount — the creature that walks beside the player.
--
-- IDENTIFIERS ARE PROVISIONAL: tranche 91 is free in ID_RANGES.md but not yet
-- given to this module. Change them everywhere (src/CompanionMount.h too)
-- once the range is decided.
--
--   creature 91000   the companion mount, cloned from the Brown Horse (284)
--
-- The clone keeps the model, skeleton and animations of a real mount. What it
-- changes is what makes it OURS: the right-click flag (UNIT_NPC_FLAG_SPELLCLICK,
-- 0x01000000), no civilian flag, the module's AI, the Wrath statistics
-- (exp 2). Display, level, health and damage are set at summon time from the
-- master and from the mount spell he chose.
--
-- Idempotent: the file may be replayed.

DROP TEMPORARY TABLE IF EXISTS `companion_mount_clone`;
CREATE TEMPORARY TABLE `companion_mount_clone` AS
    SELECT * FROM `creature_template` WHERE `entry` = 284;
UPDATE `companion_mount_clone` SET `entry` = 91000, `name` = 'Companion Mount',
    `subname` = '', `IconName` = '', `faction` = 35, `npcflag` = 16777216,
    `unit_flags` = 0, `unit_flags2` = 0, `unit_class` = 1, `exp` = 2,
    `minlevel` = 1, `maxlevel` = 80, `HealthModifier` = 1, `DamageModifier` = 1,
    `ArmorModifier` = 1, `RegenHealth` = 1, `AIName` = '',
    `ScriptName` = 'npc_companion_mount', `flags_extra` = 0, `lootid` = 0,
    `skinloot` = 0, `pickpocketloot` = 0, `mingold` = 0, `maxgold` = 0;
DELETE FROM `creature_template` WHERE `entry` = 91000;
INSERT INTO `creature_template` SELECT * FROM `companion_mount_clone`;
DROP TEMPORARY TABLE IF EXISTS `companion_mount_clone`;

DELETE FROM `creature_template_model` WHERE `CreatureID` = 91000;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(91000, 0, 2404, 1, 1, 0);

DELETE FROM `creature_template_locale` WHERE `entry` = 91000;
INSERT INTO `creature_template_locale` (`entry`, `locale`, `Name`, `Title`, `VerifiedBuild`) VALUES
(91000, 'frFR', 'Monture-compagnon', '', 0),
(91000, 'deDE', 'Begleitreittier', '', 0),
(91000, 'esES', 'Montura compañera', '', 0),
(91000, 'esMX', 'Montura compañera', '', 0);
