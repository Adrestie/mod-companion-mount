-- mod-companion-mount — the texts.
--
-- English in `module_string`, other languages in `module_string_locale`
-- (English when a language is missing). Ids match the Text enum of
-- src/CompanionMount.h and are never reused once retired.
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount';
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount',  1, 'Companion mount: the module is disabled.'),
('mod-companion-mount',  2, 'Spell {} is not a mount you know.'),
('mod-companion-mount',  3, 'No companion mount chosen. Ride a mount and type .companion summon, or give its spell: .companion summon <spell>.'),
('mod-companion-mount',  4, '{} now walks at your side. Right-click it to ride it.'),
('mod-companion-mount',  5, 'Your companion mount goes back to the stable.'),
('mod-companion-mount',  6, 'You have no companion mount out.'),
('mod-companion-mount',  7, 'Companion mount: {} - {}.'),
('mod-companion-mount',  8, 'at your side'),
('mod-companion-mount',  9, 'waiting (it only comes out of doors, while you walk)'),
('mod-companion-mount', 10, 'in the stable'),
('mod-companion-mount', 11, 'Your companion mount fell. It comes back in {} seconds.'),
('mod-companion-mount', 12, 'This is not your mount.'),
('mod-companion-mount', 13, 'You are too far from your mount.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount';
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount',  1, 'frFR', 'Monture-compagnon : le module est désactivé.'),
('mod-companion-mount',  2, 'frFR', 'Le sort {} n''est pas une monture que vous connaissez.'),
('mod-companion-mount',  3, 'frFR', 'Aucune monture-compagnon choisie. Montez une monture et tapez .companion summon, ou donnez son sort : .companion summon <sort>.'),
('mod-companion-mount',  4, 'frFR', '{} marche maintenant à vos côtés. Clic droit dessus pour la chevaucher.'),
('mod-companion-mount',  5, 'frFR', 'Votre monture-compagnon retourne à l''écurie.'),
('mod-companion-mount',  6, 'frFR', 'Vous n''avez pas de monture-compagnon dehors.'),
('mod-companion-mount',  7, 'frFR', 'Monture-compagnon : {} - {}.'),
('mod-companion-mount',  8, 'frFR', 'à vos côtés'),
('mod-companion-mount',  9, 'frFR', 'en attente (elle ne sort qu''en extérieur, quand vous êtes à pied)'),
('mod-companion-mount', 10, 'frFR', 'à l''écurie'),
('mod-companion-mount', 11, 'frFR', 'Votre monture-compagnon est tombée. Elle revient dans {} secondes.'),
('mod-companion-mount', 12, 'frFR', 'Ce n''est pas votre monture.'),
('mod-companion-mount', 13, 'frFR', 'Vous êtes trop loin de votre monture.');
