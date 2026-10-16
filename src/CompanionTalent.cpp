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
 * mod-companion-mount — LES TALENTS.
 *
 * Trois arbres, ceux des familiers de chasseur que le client connait deja
 * (icones, noms, infobulles) : DPS = Ferocite, Tank = Tenacite, Soin = Astuce
 * dont les coups sont remplaces par des soins. Chacun se termine par le SORT
 * CLE, qui depend du type de la monture (cheval : Charge, loup : Hurlement
 * furieux...). Le catalogue est en base (mod_companion_mount_talent,
 * mod_companion_mount_kind, mod_companion_mount_kind_spell).
 *
 * LES REGLES, celles du familier : un point au niveau 20 puis un tous les
 * quatre niveaux (16 au niveau 80) ; une rangee demande 3 points de plus que
 * la precedente dans l'arbre ; UN SEUL ARBRE par monture -- le premier point
 * le choisit, une remise a zero le libere.
 *
 * L'EFFET : un talent passif pose son aura sur la bete (rang appris) ; un
 * talent actif entre dans la liste que son IA lance en combat (State::actives),
 * au plus haut rang que son niveau permet.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "DatabaseEnv.h"
#include "Player.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"

#include <algorithm>
#include <set>
#include <unordered_map>

namespace CompanionMount
{
    namespace
    {
        struct TalentEntry
        {
            uint32 id = 0;
            uint8 tree = 0;
            uint8 tier = 0;
            uint8 col = 0;
            std::vector<uint32> ranks;   // un sort par rang ; vide : le talent cle
            uint8 use = TALENT_USE_PASSIVE;
            uint32 cooldown = 0;
            bool key = false;
        };

        struct KindSpell
        {
            uint32 spell = 0;
            uint8 use = TALENT_USE_VICTIM;
        };

        std::unordered_map<uint32, TalentEntry> sTalents;
        std::unordered_map<uint32, uint8> sMountKind;        // sort de monture -> type
        std::unordered_map<uint8, KindSpell> sKindSpell;     // type -> sort cle
        std::set<uint32> sPassiveSpells;                      // tout ce que ApplyTalents pose

        TalentEntry const* FindTalent(uint32 id)
        {
            auto itr = sTalents.find(id);
            return itr == sTalents.end() ? nullptr : &itr->second;
        }

        uint8 MaxRank(TalentEntry const& talent)
        {
            return talent.key ? 1 : uint8(talent.ranks.size());
        }

        uint32 SpentIn(State const& state, int32 tree)
        {
            uint32 spent = 0;
            for (auto const& [id, rank] : state.talentRanks)
                if (TalentEntry const* talent = FindTalent(id))
                    if (tree < 0 || talent->tree == tree)
                        spent += rank;
            return spent;
        }

        void SaveRank(Player* player, State const& state, uint32 talentId, uint8 rank)
        {
            CharacterDatabase.DirectExecute(
                "REPLACE INTO `mod_companion_mount_talent_rank` (`guid`, `mount_spell`, `talent_id`, `rank`) VALUES ({}, {}, {}, {})",
                player->GetGUID().GetCounter(), state.mountSpell, talentId, uint32(rank));
        }
    }

    void LoadTalentCatalogue()
    {
        sTalents.clear();
        sMountKind.clear();
        sKindSpell.clear();
        sPassiveSpells.clear();

        if (QueryResult result = WorldDatabase.Query(
                "SELECT `id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `use`, `cooldown` FROM `mod_companion_mount_talent`"))
        {
            do
            {
                Field* fields = result->Fetch();
                TalentEntry talent;
                talent.id = fields[0].Get<uint32>();
                talent.tree = fields[1].Get<uint8>();
                talent.tier = fields[2].Get<uint8>();
                talent.col = fields[3].Get<uint8>();
                for (uint8 i = 0; i < 3; ++i)
                    if (uint32 spell = fields[4 + i].Get<uint32>())
                        if (sSpellMgr->GetSpellInfo(spell))
                            talent.ranks.push_back(spell);
                talent.use = fields[7].Get<uint8>();
                talent.cooldown = fields[8].Get<uint32>();
                talent.key = !fields[4].Get<uint32>();
                if (talent.tree > 2 || (!talent.key && talent.ranks.empty()))
                    continue;
                if (talent.use == TALENT_USE_PASSIVE)
                    sPassiveSpells.insert(talent.ranks.begin(), talent.ranks.end());
                sTalents[talent.id] = std::move(talent);
            } while (result->NextRow());
        }

        if (QueryResult result = WorldDatabase.Query("SELECT `mount_spell`, `kind` FROM `mod_companion_mount_kind`"))
            do
                sMountKind[result->Fetch()[0].Get<uint32>()] = result->Fetch()[1].Get<uint8>();
            while (result->NextRow());

        if (QueryResult result = WorldDatabase.Query("SELECT `kind`, `key_spell`, `use` FROM `mod_companion_mount_kind_spell`"))
            do
            {
                Field* fields = result->Fetch();
                if (sSpellMgr->GetSpellInfo(fields[1].Get<uint32>()))
                    sKindSpell[fields[0].Get<uint8>()] = { fields[1].Get<uint32>(), fields[2].Get<uint8>() };
            } while (result->NextRow());

        LOG_INFO("module", "CompanionMount: {} talent(s), {} mount kind(s), {} key spell(s) loaded.",
            sTalents.size(), sMountKind.size(), sKindSpell.size());
    }

    uint8 MountKind(uint32 mountSpell)
    {
        auto itr = sMountKind.find(mountSpell);
        return itr == sMountKind.end() ? 1 : itr->second;   // inconnue : un cheval
    }

    uint32 KeySpell(uint32 mountSpell)
    {
        auto itr = sKindSpell.find(MountKind(mountSpell));
        return itr == sKindSpell.end() ? 0 : itr->second.spell;
    }

    uint32 SpellRankForLevel(uint32 spellId, uint8 level)
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(spellId);
        if (!info)
            return spellId;
        info = info->GetFirstRankSpell();
        while (SpellInfo const* next = info->GetNextRankSpell())
        {
            if (next->SpellLevel > level)
                break;
            info = next;
        }
        return info->Id;
    }

    uint32 TalentPoints(uint8 level)
    {
        Config const& config = GetConfig();
        if (level < config.talentFirstLevel)
            return 0;
        return 1 + (level - config.talentFirstLevel) / std::max<uint32>(1, config.talentLevelsPerPoint);
    }

    uint32 TalentPointsSpent(State const& state)
    {
        return SpentIn(state, -1);
    }

    int32 TalentTree(State const& state)
    {
        for (auto const& [id, rank] : state.talentRanks)
            if (TalentEntry const* talent = FindTalent(id))
                if (rank)
                    return talent->tree;
        return -1;
    }

    void LoadTalentRanks(Player* player, State& state)
    {
        state.talentRanks.clear();
        if (QueryResult result = CharacterDatabase.Query(
                "SELECT `talent_id`, `rank` FROM `mod_companion_mount_talent_rank` WHERE `guid` = {} AND `mount_spell` = {} AND `rank` > 0",
                player->GetGUID().GetCounter(), state.mountSpell))
        {
            do
            {
                Field* fields = result->Fetch();
                if (TalentEntry const* talent = FindTalent(fields[0].Get<uint32>()))
                    state.talentRanks[talent->id] = std::min(fields[1].Get<uint8>(), MaxRank(*talent));
            } while (result->NextRow());
        }
    }

    void ApplyTalents(Creature* companion, Player* player, State& state)
    {
        // Tout ce que les talents ont pu poser part, puis le rang appris revient.
        for (uint32 spell : sPassiveSpells)
            companion->RemoveAurasDueToSpell(spell);

        state.actives.clear();
        uint8 const level = companion->GetLevel();

        for (auto const& [id, rank] : state.talentRanks)
        {
            TalentEntry const* talent = FindTalent(id);
            if (!talent || !rank)
                continue;

            if (talent->key)
            {
                auto itr = sKindSpell.find(MountKind(state.mountSpell));
                if (itr != sKindSpell.end())
                    state.actives.push_back({ SpellRankForLevel(itr->second.spell, level), itr->second.use, talent->cooldown });
                continue;
            }

            uint32 const spell = talent->ranks[std::min<size_t>(rank, talent->ranks.size()) - 1];
            if (talent->use == TALENT_USE_PASSIVE)
                companion->AddAura(spell, companion);
            else if (talent->use != TALENT_USE_NONE)
                state.actives.push_back({ SpellRankForLevel(spell, level), talent->use, talent->cooldown });
        }
        (void)player;
    }

    bool LearnTalent(Player* player, uint32 talentId)
    {
        State& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(player, TEXT_NO_MOUNT);
            return false;
        }

        TalentEntry const* talent = FindTalent(talentId);
        if (!talent)
        {
            Say(player, TEXT_TALENT_UNKNOWN);
            return false;
        }

        uint8 const rank = state.talentRanks.count(talentId) ? state.talentRanks[talentId] : 0;
        if (rank >= MaxRank(*talent))
        {
            Say(player, TEXT_TALENT_MAXED);
            return false;
        }

        if (TalentPointsSpent(state) >= TalentPoints(EffectiveLevel(player, state)))
        {
            Say(player, TEXT_TALENT_NO_POINTS);
            return false;
        }

        int32 const tree = TalentTree(state);
        if (GetConfig().talentOneTree && tree >= 0 && tree != talent->tree)
        {
            Say(player, TEXT_TALENT_OTHER_TREE);
            return false;
        }

        uint32 const needed = talent->tier * GetConfig().talentPointsPerTier;
        if (SpentIn(state, talent->tree) < needed)
        {
            Say(player, TEXT_TALENT_TIER, needed);
            return false;
        }

        if (talent->key && !KeySpell(state.mountSpell))
        {
            Say(player, TEXT_TALENT_NO_KEY);
            return false;
        }

        state.talentRanks[talentId] = rank + 1;
        SaveRank(player, state, talentId, rank + 1);

        if (Creature* companion = GetCompanion(player))
            ApplyTalents(companion, player, state);
        return true;
    }

    void ResetTalents(Player* player)
    {
        State& state = GetState(player);
        if (!state.mountSpell)
            return;

        state.talentRanks.clear();
        CharacterDatabase.DirectExecute(
            "DELETE FROM `mod_companion_mount_talent_rank` WHERE `guid` = {} AND `mount_spell` = {}",
            player->GetGUID().GetCounter(), state.mountSpell);

        if (Creature* companion = GetCompanion(player))
            ApplyTalents(companion, player, state);
        Say(player, TEXT_TALENT_RESET);
    }

    void ListTalents(ChatHandler* handler, Player* player)
    {
        State const& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(handler, TEXT_NO_MOUNT);
            return;
        }

        int32 const tree = TalentTree(state);
        std::string const* treeName = handler->GetModuleString(MODULE, tree < 0 ? TEXT_TALENT_TREE_NONE : TEXT_TALENT_TREE_DPS + tree);
        Say(handler, TEXT_TALENT_HEADER, TalentPointsSpent(state), TalentPoints(EffectiveLevel(player, state)),
            treeName ? *treeName : "");

        LocaleConstant const locale = handler->GetSessionDbcLocale();
        for (auto const& [id, rank] : state.talentRanks)
        {
            TalentEntry const* talent = FindTalent(id);
            if (!talent || !rank)
                continue;
            uint32 const spell = talent->key ? KeySpell(state.mountSpell) : talent->ranks[0];
            SpellInfo const* info = sSpellMgr->GetSpellInfo(spell);
            char const* name = info ? info->SpellName[locale] : nullptr;
            if (!name || !*name)
                name = info ? info->SpellName[LOCALE_enUS] : "?";
            Say(handler, TEXT_TALENT_LINE, id, name, uint32(rank), uint32(MaxRank(*talent)));
        }
    }

    void DeleteTalents(ObjectGuid::LowType guid)
    {
        CharacterDatabase.Execute("DELETE FROM `mod_companion_mount_talent_rank` WHERE `guid` = {}", guid);
    }
}
