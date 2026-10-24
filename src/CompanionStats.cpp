/*
 * This file is part of mod-companion-mount.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
 * Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * mod-companion-mount — LA FICHE DE LA MONTURE, pour l'interface.
 *
 * ALE ne sait lire d'une creature ni l'armure, ni les degats, ni les chances
 * de critique ou d'esquive. La fenetre (Lua) demande donc une FICHE : le
 * module l'ecrit dans mod_companion_mount_snapshot, d'une ecriture directe
 * (une requete ordinaire, sans les requetes preparees des objets), et la
 * fenetre la relit aussitot. Une ligne par personnage, reecrite a chaque
 * demande.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "SpellMgr.h"

namespace CompanionMount
{
    void WriteSnapshot(Player* player)
    {
        State const& state = GetState(player);
        Creature* companion = GetCompanion(player);
        uint8 const level = EffectiveLevel(player, state);

        uint32 health = 0, maxHealth = 0, armor = 0, attackPower = 0, minDamage = 0, maxDamage = 0, attackTime = 0;
        uint32 strength = 0, agility = 0, stamina = 0, spellDamage = 0, healing = 0;
        float crit = 0.0f, dodge = 0.0f, parry = 0.0f;
        if (companion)
        {
            health = companion->GetHealth();
            maxHealth = companion->GetMaxHealth();
            armor = companion->GetArmor();
            attackPower = uint32(companion->GetTotalAttackPowerValue(BASE_ATTACK));
            minDamage = uint32(companion->GetFloatValue(UNIT_FIELD_MINDAMAGE));
            maxDamage = uint32(companion->GetFloatValue(UNIT_FIELD_MAXDAMAGE));
            attackTime = companion->GetAttackTime(BASE_ATTACK);
            crit = companion->GetUnitCriticalChance(BASE_ATTACK, companion);
            dodge = companion->GetUnitDodgeChance();
            parry = companion->GetUnitParryChance();
            strength = uint32(companion->GetStat(STAT_STRENGTH));
            agility = uint32(companion->GetStat(STAT_AGILITY));
            stamina = uint32(companion->GetStat(STAT_STAMINA));
            spellDamage = uint32(std::max(0, companion->SpellBaseDamageBonusDone(SPELL_SCHOOL_MASK_MAGIC)));
            healing = uint32(std::max(0, companion->SpellBaseHealingBonusDone(SPELL_SCHOOL_MASK_ALL)));
        }

        // La vue 3D montre la creature du sort de monture, au modele de la bete
        // quand elle est dehors.
        uint32 const creature = GetMountCreatureEntry(sSpellMgr->GetSpellInfo(state.mountSpell));
        uint32 const display = companion ? companion->GetDisplayId() : 0;

        int32 const tree = TalentTree(state);
        std::string name = state.name;
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.DirectExecute(
            "REPLACE INTO `mod_companion_mount_snapshot` (`guid`, `mount_spell`, `name`, `kind`, `creature`, `display`, `level`, `xp`, `xp_next`, "
            "`out`, `health`, `max_health`, `armor`, `attack_power`, `min_damage`, `max_damage`, `attack_time`, "
            "`crit`, `dodge`, `parry`, `tree`, `points_spent`, `points_total`, `command_state`, `react_state`, "
            "`strength`, `agility`, `stamina`, `spell_damage`, `healing_power`) "
            "VALUES ({}, {}, '{}', {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {:.2f}, {:.2f}, {:.2f}, {}, {}, {}, {}, {}, "
            "{}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), state.mountSpell, name, uint32(MountKind(state.mountSpell)), creature, display, uint32(level),
            state.xp, NextLevelXP(level), companion ? 1 : 0, health, maxHealth, armor, attackPower, minDamage, maxDamage,
            attackTime, crit, dodge, parry, tree < 0 ? 255 : tree, TalentPointsSpent(state), TalentPoints(level),
            uint32(state.command), uint32(state.react), strength, agility, stamina, spellDamage, healing);
    }
}
