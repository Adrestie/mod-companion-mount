-- mod-companion-mount — the names: texts and help.
--
-- Ids 26-28 of `module_string` (Text enum of src/CompanionMount.h).
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 26 AND 28;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 26, 'Your companion mount is now called {}.'),
('mod-companion-mount', 27, 'Your companion mount no longer has a name of its own.'),
('mod-companion-mount', 28, 'Name: {}.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 26 AND 28;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 26, 'frFR', 'Votre monture-compagnon s''appelle désormais {}.'),
('mod-companion-mount', 27, 'frFR', 'Votre monture-compagnon n''a plus de nom à elle.'),
('mod-companion-mount', 28, 'frFR', 'Nom : {}.');

DELETE FROM `command` WHERE `name` = 'companion rename';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion rename', 0, 'Syntax: .companion rename [$name]\n\nNames your companion mount (the mount chosen), as a pet is named. Without a name, it takes back the name of all companion mounts.');
