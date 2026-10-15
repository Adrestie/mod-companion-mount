-- mod-companion-mount — the levels: texts.
--
-- Ids 23-25 of `module_string` (Text enum of src/CompanionMount.h).
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 23 AND 25;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 23, 'Level {} - {}/{} experience.'),
('mod-companion-mount', 24, 'Level {} (the highest it may reach for now).'),
('mod-companion-mount', 25, 'Your companion mount reaches level {}!');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 23 AND 25;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 23, 'frFR', 'Niveau {} - {}/{} points d''expérience.'),
('mod-companion-mount', 24, 'frFR', 'Niveau {} (le plus haut qu''elle puisse atteindre pour l''instant).'),
('mod-companion-mount', 25, 'frFR', 'Votre monture-compagnon atteint le niveau {} !');
