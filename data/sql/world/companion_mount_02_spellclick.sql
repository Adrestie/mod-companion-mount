-- mod-companion-mount — the right click.
--
-- The client shows the "mount" cursor and sends the click only for a creature
-- that carries UNIT_NPC_FLAG_SPELLCLICK AND a row of npc_spellclick_spells;
-- the core removes the flag from a template without one. The row names spell
-- 91000, which is NEVER CAST: the AI (BeforeSpellClick) catches the click,
-- casts the player's own mount spell on him, and refuses the table's spell.
--
-- 91000 lives only on the server (spell_dbc): a do-nothing spell, hidden
-- (SPELL_ATTR0_DO_NOT_DISPLAY), that the core needs to accept the row.
--
-- user_type 3 (party): the cursor shows for the master and his group; the AI
-- answers only the master.
--
-- IDENTIFIERS ARE PROVISIONAL (see companion_mount_01_creature.sql).

DELETE FROM `spell_dbc` WHERE `ID` = 91000;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `CastingTimeIndex`, `DurationIndex`, `RangeIndex`,
    `Effect_1`, `ImplicitTargetA_1`, `Name_Lang_enUS`, `Name_Lang_Mask`) VALUES
(91000, 0x80, 1, 0, 1, 3, 1, 'Companion Mount: Ride', 16712190);

DELETE FROM `npc_spellclick_spells` WHERE `npc_entry` = 91000;
INSERT INTO `npc_spellclick_spells` (`npc_entry`, `spell_id`, `cast_flags`, `user_type`) VALUES
(91000, 91000, 1, 3);
