-- mod-companion-mount — the horse's Rampart key spell: Devotion Aura instead of Intervene.
--
-- Intervene is a warrior charge towards an ally; Devotion Aura (ranked, the rank the
-- mount's level allows) raises the armor of the mount, its master and the master's party
-- while the mount wears it. The AI puts it on in combat and does not cast it again while
-- it lasts.
--
-- Replayable: the row is written again.

DELETE FROM `mod_companion_mount_key_spell` WHERE `kind` = 1 AND `tree` = 1;
INSERT INTO `mod_companion_mount_key_spell` (`kind`, `tree`, `key_spell`, `use`, `comment`) VALUES
(1, 1, 465, 2, 'horse: Devotion Aura');
