-- mod-companion-mount — the hunter pet talents are gone: their points come back.
--
-- The first trees reused the hunter pets' talents (ids from Talent.dbc, 2106-2278, and
-- 90001-90003). The new trees (companion_mount_12_new_talents.sql, world) use their own ids:
-- what was learned in the old ones is erased, every point is free again. The key talents
-- (90010-90012) stay.
--
-- Replayable: only the old ids are touched.

DELETE FROM `mod_companion_mount_talent_rank`
WHERE `talent_id` BETWEEN 2000 AND 2999 OR `talent_id` BETWEEN 90001 AND 90003;
