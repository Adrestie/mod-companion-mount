-- mod-companion-mount — the orders: texts and help.
--
-- Ids 14-21 of `module_string` (Text enum of src/CompanionMount.h). Id 21
-- replaces id 7, retired: `.companion info` now tells the orders too.
--
-- Idempotent: the file may be replayed.

DELETE FROM `module_string` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 14 AND 21;
INSERT INTO `module_string` (`module`, `id`, `string`) VALUES
('mod-companion-mount', 14, 'Your companion mount cannot attack that.'),
('mod-companion-mount', 15, 'Your companion mount is not out.'),
('mod-companion-mount', 16, 'follows you'),
('mod-companion-mount', 17, 'stays'),
('mod-companion-mount', 18, 'passive'),
('mod-companion-mount', 19, 'defensive'),
('mod-companion-mount', 20, 'aggressive'),
('mod-companion-mount', 21, 'Companion mount: {} - {}, {}, {}.');

DELETE FROM `module_string_locale` WHERE `module` = 'mod-companion-mount' AND `id` BETWEEN 14 AND 21;
INSERT INTO `module_string_locale` (`module`, `id`, `locale`, `string`) VALUES
('mod-companion-mount', 14, 'frFR', 'Votre monture-compagnon ne peut pas attaquer cela.'),
('mod-companion-mount', 15, 'frFR', 'Votre monture-compagnon n''est pas dehors.'),
('mod-companion-mount', 16, 'frFR', 'vous suit'),
('mod-companion-mount', 17, 'frFR', 'reste sur place'),
('mod-companion-mount', 18, 'frFR', 'passive'),
('mod-companion-mount', 19, 'frFR', 'défensive'),
('mod-companion-mount', 20, 'frFR', 'agressive'),
('mod-companion-mount', 21, 'frFR', 'Monture-compagnon : {} - {}, {}, {}.');

DELETE FROM `command` WHERE `name` IN ('companion attack', 'companion follow', 'companion stay',
    'companion passive', 'companion defensive', 'companion aggressive', 'companion debug');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion attack', 0, 'Syntax: .companion attack\n\nYour companion mount attacks your target, whatever its stance.'),
('companion follow', 0, 'Syntax: .companion follow\n\nYour companion mount follows you.'),
('companion stay', 0, 'Syntax: .companion stay\n\nYour companion mount stays where it is, and comes back there after a fight.'),
('companion passive', 0, 'Syntax: .companion passive\n\nYour companion mount fights only what you tell it to attack.'),
('companion defensive', 0, 'Syntax: .companion defensive\n\nYour companion mount fights your target, what attacks you, and what attacks it.'),
('companion aggressive', 0, 'Syntax: .companion aggressive\n\nYour companion mount also attacks any enemy within 20 yards.'),
('companion debug', 2, 'Syntax: .companion debug\n\nWhat the server knows of your companion mount: orders, health, victim, movement. For tests.');
