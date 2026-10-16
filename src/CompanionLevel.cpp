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
 * mod-companion-mount — L'EXPERIENCE ET LES NIVEAUX.
 *
 * Chaque monture a sa progression (mod_companion_mount_mount : un niveau et
 * l'experience vers le suivant, par personnage et par sort de monture). Celle
 * qui est dehors gagne de l'experience a chaque monstre que son maitre ou elle
 * acheve : la formule du coeur (Acore::XP::BaseGain), calculee a SON niveau,
 * doublee pour un elite. Il lui faut, pour un niveau, une part de ce qu'il
 * faut au joueur (5 % par defaut, comme le familier du chasseur). Elle ne
 * depasse pas le niveau de son maitre.
 *
 * LES AUTRES MONTURES, celles qui restent a l'ecurie, recoivent une part de
 * cette experience (10 % par defaut) -- meme celles qui ne sont jamais
 * sorties. Plutot que d'ecrire dans chaque ligne a chaque monstre, le
 * personnage tient un POT commun (`shared_pool`) : tout ce qui a ete partage
 * depuis toujours. Chaque monture note ce qu'elle en a deja recu
 * (`pool_seen`) ; quand elle sort, elle recoit la difference.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Formulas.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "World.h"

#include <algorithm>

namespace CompanionMount
{
    namespace
    {
        // Le plus haut niveau que la monture peut atteindre maintenant.
        uint8 LevelCap(Player* player)
        {
            uint8 cap = uint8(sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL));
            if (GetConfig().levelCapToOwner)
                cap = std::min(cap, player->GetLevel());
            return std::max<uint8>(1, cap);
        }

        void SavePool(Player* player, State const& state)
        {
            CharacterDatabase.Execute(
                "UPDATE `mod_companion_mount_character` SET `shared_pool` = {} WHERE `guid` = {}",
                state.pool, player->GetGUID().GetCounter());
        }
    }

    uint32 NextLevelXP(uint8 level)
    {
        return std::max<uint32>(1, uint32(sObjectMgr->GetXPForLevel(level) * GetConfig().levelXpNeedRate));
    }

    uint8 EffectiveLevel(Player* player, State const& state)
    {
        if (!GetConfig().levelEnabled)
            return player->GetLevel();
        return std::min(state.level, LevelCap(player));
    }

    void SaveMount(Player* player, State const& state)
    {
        if (!state.mountSpell)
            return;
        std::string name = state.name;
        CharacterDatabase.EscapeString(name);
        CharacterDatabase.Execute(
            "REPLACE INTO `mod_companion_mount_mount` (`guid`, `mount_spell`, `level`, `xp`, `pool_seen`, `name`) VALUES ({}, {}, {}, {}, {}, '{}')",
            player->GetGUID().GetCounter(), state.mountSpell, uint32(state.level), state.xp, state.poolSeen, name);
    }

    void AddXP(Player* player, State& state, uint32 amount)
    {
        uint8 const cap = LevelCap(player);
        bool leveled = false;

        if (state.level < cap)
        {
            state.xp += amount;
            while (state.level < cap)
            {
                uint32 const need = NextLevelXP(state.level);
                if (state.xp < need)
                    break;
                state.xp -= need;
                ++state.level;
                leveled = true;
            }
        }
        // AU PLAFOND : l'experience ne s'amasse pas, comme pour le familier.
        if (state.level >= cap)
            state.xp = 0;

        if (leveled)
            Say(player, TEXT_LEVEL_UP, uint32(state.level));
    }

    void LoadMount(Player* player, State& state)
    {
        state.level = uint8(std::clamp<uint32>(GetConfig().levelStart, 1, 255));
        state.xp = 0;
        state.poolSeen = 0;
        state.name.clear();

        if (QueryResult result = CharacterDatabase.Query(
                "SELECT `level`, `xp`, `pool_seen`, `name` FROM `mod_companion_mount_mount` WHERE `guid` = {} AND `mount_spell` = {}",
                player->GetGUID().GetCounter(), state.mountSpell))
        {
            Field* fields = result->Fetch();
            state.level = std::max<uint8>(1, fields[0].Get<uint8>());
            state.xp = fields[1].Get<uint32>();
            state.poolSeen = fields[2].Get<uint64>();
            state.name = fields[3].Get<std::string>();
        }

        // CE QUE LES AUTRES ONT GAGNE PENDANT QU'ELLE ETAIT A L'ECURIE.
        if (GetConfig().levelEnabled && state.pool > state.poolSeen)
            AddXP(player, state, uint32(std::min<uint64>(state.pool - state.poolSeen, 0xFFFFFFFF)));
        state.poolSeen = state.pool;

        SaveMount(player, state);
        LoadTalentRanks(player, state);
        LoadAutocast(player, state);
    }

    void GiveKillXP(Player* owner, Creature* victim)
    {
        Config const& config = GetConfig();
        if (!config.enabled || !config.levelEnabled || !owner || !victim)
            return;

        State& state = GetState(owner);
        if (!state.mountSpell || !GetCompanion(owner))
            return;

        // Ce qui ne donne rien au joueur ne donne rien a la bete.
        if (victim->IsCritter() || victim->IsTotem() || victim->IsControlledByPlayer()
            || victim->GetCreatureTemplate()->HasFlagsExtra(CREATURE_FLAG_EXTRA_NO_XP) || !victim->isTappedBy(owner))
            return;

        uint8 const level = EffectiveLevel(owner, state);
        uint32 xp = Acore::XP::BaseGain(level, victim->GetLevel(),
            GetContentLevelsForMapAndZone(victim->GetMapId(), victim->GetZoneId()));
        if (!xp)
            return;
        if (victim->isElite())
            xp *= 2;
        xp = uint32(xp * config.levelXpKillRate);
        if (!xp)
            return;

        AddXP(owner, state, xp);

        // LA PART DES AUTRES, dans le pot commun ; celle-ci l'a deja.
        uint64 const shared = uint64(xp) * config.levelSharedPercent / 100;
        if (shared)
        {
            state.pool += shared;
            state.poolSeen += shared;
            SavePool(owner, state);
        }
        SaveMount(owner, state);
    }
}
