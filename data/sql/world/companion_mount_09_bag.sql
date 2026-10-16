-- mod-companion-mount — the saddlebags: texts and help.
--
-- Ids 29-32 of `module_string` (Text enum of src/CompanionMount.h).
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 29 AND 32;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 29, 'Your companion mount cannot carry that.'),
('mod-companion-mount', 30, 'The saddlebags of your companion mount are full.'),
('mod-companion-mount', 31, 'Saddlebags: {}/{} places used.'),
('mod-companion-mount', 32, '  {}: {} x{}');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 29 AND 32;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 29, 'frFR', 'Votre monture-compagnon ne peut pas porter cela.'),
('mod-companion-mount', 30, 'frFR', 'Les sacoches de votre monture-compagnon sont pleines.'),
('mod-companion-mount', 31, 'frFR', 'Sacoches : {}/{} places occupées.'),
('mod-companion-mount', 32, 'frFR', '  {} : {} x{}');

DELETE FROM `command` WHERE `name` IN ('companion bag', 'companion bag put', 'companion bag take');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion bag', 0, 'Syntax: .companion bag\n\nWhat the saddlebags of your companion mount carry. The bar of the companion mount opens them as a window.'),
('companion bag put', 0, 'Syntax: .companion bag put $bag $slot\n\nPuts an item of your bags into the saddlebags (server numbering: backpack 255 and slots 23-38, bags 19-22 and slots from 0). The companion mount must be out.'),
('companion bag take', 0, 'Syntax: .companion bag take $place\n\nTakes back the item at that place of the saddlebags (1 to N). The companion mount must be out.');
