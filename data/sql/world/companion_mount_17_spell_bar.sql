-- mod-companion-mount — the commands of the spell bar.
--
-- Replayable: the rows are written again.

DELETE FROM `command` WHERE `name` IN ('companion cast', 'companion autocast');
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion cast', 0, 'Syntax: .companion cast $spell\n\nYour companion mount casts one of the spells it learned, at once, on its usual target (any rank of the spell).'),
('companion autocast', 0, 'Syntax: .companion autocast $spell\n\nTurns off, or back on, the automatic casting of one of the spells of your companion mount (any rank of the spell).');
