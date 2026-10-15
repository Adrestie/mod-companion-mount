-- mod-companion-mount — the loot: texts.
--
-- Id 22 of `module_string` (Text enum of src/CompanionMount.h).
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` = 22;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 22, 'Your bags are full: your companion mount leaves the rest of the loot on the corpses.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` = 22;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 22, 'frFR', 'Vos sacs sont pleins : votre monture-compagnon laisse le reste du butin sur les corps.');
