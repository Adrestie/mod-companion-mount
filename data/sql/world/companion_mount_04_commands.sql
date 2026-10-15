-- mod-companion-mount — the help of the commands (.help companion).
--
-- Idempotent: the file may be replayed.

DELETE FROM `command` WHERE `name` = 'companion' OR `name` LIKE 'companion %';
INSERT INTO `command` (`name`, `security`, `help`) VALUES
('companion', 0, 'Syntax: .companion $subcommand\n\nThe companion mount: one of your mounts walks and fights at your side, out of doors. Right-click it to ride it.'),
('companion summon', 0, 'Syntax: .companion summon [$spell]\n\nCalls your companion mount: the mount you ride, else the mount spell given (id or link), else the last one chosen.'),
('companion dismiss', 0, 'Syntax: .companion dismiss\n\nSends your companion mount back to the stable.'),
('companion info', 0, 'Syntax: .companion info\n\nWhich mount is your companion, and where it is.');
