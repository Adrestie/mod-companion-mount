-- mod-companion-mount — the talents: texts and help.
--
-- Ids 33-45 of `module_string` (Text enum of src/CompanionMount.h).
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 33 AND 45;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 33, 'Talents: {}/{} points spent - {}.'),
('mod-companion-mount', 34, '  [{}] {} - rank {}/{}'),
('mod-companion-mount', 35, 'Your companion mount has no talent point left.'),
('mod-companion-mount', 36, 'Your companion mount already learned in another tree. Reset its talents first.'),
('mod-companion-mount', 37, 'Spend {} points in this tree to reach this row.'),
('mod-companion-mount', 38, 'This talent is already at its highest rank.'),
('mod-companion-mount', 39, 'Unknown talent.'),
('mod-companion-mount', 40, 'The talents of your companion mount are reset: every point is free again.'),
('mod-companion-mount', 41, 'DPS tree'),
('mod-companion-mount', 42, 'Tank tree'),
('mod-companion-mount', 43, 'Heal tree'),
('mod-companion-mount', 44, 'no tree chosen'),
('mod-companion-mount', 45, 'This mount has no key spell.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 33 AND 45;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 33, 'frFR', 'Talents : {}/{} points dépensés - {}.'),
('mod-companion-mount', 34, 'frFR', '  [{}] {} - rang {}/{}'),
('mod-companion-mount', 35, 'frFR', 'Votre monture-compagnon n''a plus de point de talent.'),
('mod-companion-mount', 36, 'frFR', 'Votre monture-compagnon a déjà appris dans un autre arbre. Réinitialisez d''abord ses talents.'),
('mod-companion-mount', 37, 'frFR', 'Dépensez {} points dans cet arbre pour atteindre cette rangée.'),
('mod-companion-mount', 38, 'frFR', 'Ce talent est déjà à son rang le plus haut.'),
('mod-companion-mount', 39, 'frFR', 'Talent inconnu.'),
('mod-companion-mount', 40, 'frFR', 'Les talents de votre monture-compagnon sont réinitialisés : tous les points sont de nouveau libres.'),
('mod-companion-mount', 41, 'frFR', 'arbre DPS'),
('mod-companion-mount', 42, 'frFR', 'arbre Tank'),
('mod-companion-mount', 43, 'frFR', 'arbre Soin'),
('mod-companion-mount', 44, 'frFR', 'aucun arbre choisi'),
('mod-companion-mount', 45, 'frFR', 'Cette monture n''a pas de sort clé.');

DELETE FROM `command` WHERE `name` IN ('companion talent', 'companion talent learn', 'companion talent reset');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion talent', 0, 'Syntax: .companion talent\n\nThe talent points and talents of your companion mount. The bar of the companion mount opens them as a window.'),
('companion talent learn', 0, 'Syntax: .companion talent learn $id\n\nOne more rank of a talent of your companion mount (one tree per mount, 3 points per row).'),
('companion talent reset', 0, 'Syntax: .companion talent reset\n\nFrees every talent point of your companion mount.');
