-- mod-companion-mount — one talent alone on the last row of each tree: its ultimate.
--
-- Bladestorm (Fury), Challenging Shout (Rampart) and Tranquility (Benevolence) stand
-- alone, in the middle of the last row; the key talents (90010-90012) move one row up,
-- where a place is free.
--
-- Replayable: the rows are moved to the same places every time.

UPDATE `mod_companion_mount_talent` SET `tier` = 5, `col` = 1 WHERE `id` IN (1014, 1114, 1213);
UPDATE `mod_companion_mount_talent` SET `tier` = 4, `col` = 0 WHERE `id` = 90010;
UPDATE `mod_companion_mount_talent` SET `tier` = 4, `col` = 3 WHERE `id` = 90011;
UPDATE `mod_companion_mount_talent` SET `tier` = 4, `col` = 0 WHERE `id` = 90012;
