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
 * mod-companion-mount — L'ENERGIE ET LES GAMBITS (docs/energie-gambits.md).
 *
 * L'ENERGIE : la bete en a 100, comme le voleur, et le coeur la lui rend
 * (+20 toutes les 2 s, Creature::Regenerate, pour une creature a un joueur).
 * Chaque sort en coute selon sa classe (mod_companion_mount_talent.energy) ;
 * l'ultime garde sa recharge propre.
 *
 * LES GAMBITS (Final Fantasy XII) : une liste de regles « cible + condition
 * -> action » que l'IA lit de haut en bas a chaque tour ; elle joue la
 * premiere dont la condition est vraie et l'action possible. 3 emplacements
 * au niveau 1, 12 au niveau 80. Tant que le joueur n'y a pas touche, la liste
 * est celle par defaut, tiree des sorts appris (elle suit les talents) ; la
 * sienne est gardee par monture (mod_companion_mount_gambit).
 *
 * LE PORTRAIT : le jeu n'en montre pas pour un gardien ; l'interface (ALE/AIO)
 * en dessine un, nourri par un message d'addon envoye quand les chiffres
 * changent (prefixe CMPF).
 */

#include "CompanionMount.h"

#include "CellImpl.h"
#include "Chat.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "Pet.h"
#include "Player.h"
#include "SpellAuras.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "WorldPacket.h"

#include <algorithm>

namespace CompanionMount
{
    namespace
    {
        constexpr float GROUP_RANGE = 40.0f;   // les membres que la bete peut soigner
        constexpr float FIGHT_RANGE = 8.0f;    // « ennemis autour » : au contact

        bool Usable(Creature* companion, Unit* unit)
        {
            return unit && unit->IsAlive() && unit->IsInWorld() && unit->GetMap() == companion->GetMap();
        }

        bool IsFoe(Creature* companion, Unit* unit)
        {
            return Usable(companion, unit) && companion->IsValidAttackTarget(unit)
                && unit->IsWithinDistInMap(companion, GetConfig().leashDistance);
        }

        // Les ennemis du combat : la cible de la bete et celle du maitre, ceux
        // qui s'en prennent a l'un ou a l'autre.
        std::vector<Unit*> Foes(Creature* companion, Player* owner)
        {
            std::vector<Unit*> foes;
            auto add = [&](Unit* unit)
            {
                if (IsFoe(companion, unit) && std::find(foes.begin(), foes.end(), unit) == foes.end())
                    foes.push_back(unit);
            };
            add(companion->GetVictim());
            add(owner->GetVictim());
            if (Unit* selected = owner->GetSelectedUnit())
                if (selected->IsInCombatWith(owner) || selected->IsInCombatWith(companion))
                    add(selected);
            for (Unit* attacker : owner->getAttackers())
                add(attacker);
            for (Unit* attacker : companion->getAttackers())
                add(attacker);
            return foes;
        }

        // Le groupe : le maitre, ses compagnons de groupe a portee, la bete et
        // le familier du maitre.
        std::vector<Unit*> Party(Creature* companion, Player* owner)
        {
            std::vector<Unit*> party;
            auto add = [&](Unit* unit)
            {
                if (Usable(companion, unit) && unit->IsWithinDistInMap(companion, GROUP_RANGE)
                    && std::find(party.begin(), party.end(), unit) == party.end())
                    party.push_back(unit);
            };
            add(owner);
            add(companion);
            if (Pet* pet = owner->GetPet())
                add(pet);
            if (Group* group = owner->GetGroup())
                for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
                    add(ref->GetSource());
            return party;
        }

        Unit* Lowest(std::vector<Unit*> const& units)
        {
            Unit* lowest = nullptr;
            for (Unit* unit : units)
                if (!lowest || unit->GetHealthPct() < lowest->GetHealthPct())
                    lowest = unit;
            return lowest;
        }

        bool HasHarmful(Unit* unit, uint32 dispel)
        {
            for (auto const& [id, application] : unit->GetAppliedAuras())
                if (!application->IsPositive() && application->GetBase()->GetSpellInfo()->Dispel == dispel)
                    return true;
            return false;
        }

        uint32 CountFoesAround(Creature* companion)
        {
            std::list<Unit*> around;
            Acore::AnyUnfriendlyUnitInObjectRangeCheck check(companion, companion, FIGHT_RANGE);
            Acore::UnitListSearcher<Acore::AnyUnfriendlyUnitInObjectRangeCheck> searcher(companion, around, check);
            Cell::VisitObjects(companion, searcher, FIGHT_RANGE);
            return uint32(std::count_if(around.begin(), around.end(), [&](Unit* unit)
            {
                return unit->IsInCombat() && companion->IsValidAttackTarget(unit);
            }));
        }

        // CE QUE DIT UN SORT pour la liste par defaut.
        bool IsTaunt(SpellInfo const* info)
        {
            return info->HasEffect(SPELL_EFFECT_ATTACK_ME) || info->HasAura(SPELL_AURA_MOD_TAUNT);
        }

        // Le type de dissipation d'un sort qui purifie (Abolir le poison passe
        // par un declenchement periodique), sinon 0.
        uint32 DispelType(SpellInfo const* info)
        {
            for (SpellEffectInfo const& effect : info->GetEffects())
            {
                if (effect.Effect == SPELL_EFFECT_DISPEL)
                    return uint32(effect.MiscValue);
                if (effect.ApplyAuraName == SPELL_AURA_PERIODIC_TRIGGER_SPELL)
                    if (SpellInfo const* triggered = sSpellMgr->GetSpellInfo(effect.TriggerSpell))
                        for (SpellEffectInfo const& inner : triggered->GetEffects())
                            if (inner.Effect == SPELL_EFFECT_DISPEL)
                                return uint32(inner.MiscValue);
            }
            return 0;
        }

        bool IsArea(SpellInfo const* info)
        {
            if (info->IsAffectingArea())
                return true;
            for (SpellEffectInfo const& effect : info->GetEffects())
                if (effect.ChainTarget > 1)
                    return true;
            return false;
        }

        // LA LISTE PAR DEFAUT, qui reproduit l'IA d'avant les gambits : l'ultime,
        // les secours, les soins (forts avant rapides), les purifications, la
        // provocation, les attaques ; et pour finir « ta cible -> Attaquer ».
        std::vector<Gambit> Defaults(State const& state)
        {
            std::vector<std::pair<uint8, Gambit>> rules;
            std::set<uint32> seen;
            for (ActiveSpell const& active : state.actives)
            {
                SpellInfo const* info = sSpellMgr->GetSpellInfo(active.spell);
                if (!info || !seen.insert(active.first).second)
                    continue;

                Gambit gambit;
                gambit.action = int32(active.first);
                uint8 priority = 10;
                bool const friendly = active.use == TALENT_USE_OWNER || active.use == TALENT_USE_OWNER_HEAL;
                uint32 const dispel = DispelType(info);

                if (active.energyClass == ENERGY_ULTIMATE)
                {
                    priority = 0;
                    gambit.condition = friendly ? GAMBIT_GROUP_THREE_70 : GAMBIT_FIGHT_3;
                }
                else if (active.use == TALENT_USE_SELF_HEAL)
                {
                    priority = 1;
                    gambit.condition = active.energyClass == ENERGY_DEFENSIVE ? GAMBIT_SELF_HP_30 : GAMBIT_SELF_HP_50;
                }
                else if (friendly && dispel)
                {
                    priority = 2;
                    gambit.condition = dispel == DISPEL_POISON ? GAMBIT_OWNER_POISON
                        : dispel == DISPEL_DISEASE ? GAMBIT_OWNER_DISEASE
                        : dispel == DISPEL_CURSE ? GAMBIT_OWNER_CURSE : GAMBIT_OWNER_MAGIC;
                }
                else if (active.use == TALENT_USE_OWNER_HEAL)
                {
                    if (IsArea(info))
                    {
                        priority = 3;
                        gambit.condition = GAMBIT_GROUP_THREE_70;
                    }
                    else if (active.energyClass != ENERGY_QUICK)
                    {
                        priority = 4;
                        gambit.condition = GAMBIT_OWNER_HP_50;
                    }
                    else
                    {
                        priority = 5;
                        gambit.condition = GAMBIT_OWNER_HP_70;
                    }
                }
                else if (active.use == TALENT_USE_OWNER)
                {
                    priority = 6;
                    gambit.condition = GAMBIT_OWNER_ATTACKED;
                }
                else if (active.use == TALENT_USE_VICTIM)
                {
                    priority = IsTaunt(info) ? 7 : 9;
                    gambit.condition = IsTaunt(info) ? GAMBIT_FOE_ATTACKING_YOU : GAMBIT_FOE_ITS_TARGET;
                }
                else if (active.use == TALENT_USE_SELF)
                {
                    bool const crowd = IsArea(info) && active.energyClass != ENERGY_QUICK;
                    priority = crowd ? 8 : 10;
                    gambit.condition = crowd ? GAMBIT_FIGHT_2 : GAMBIT_FOE_ITS_TARGET;
                }
                else
                    continue;
                rules.push_back({ priority, gambit });
            }

            std::stable_sort(rules.begin(), rules.end(), [](auto const& a, auto const& b) { return a.first < b.first; });

            std::vector<Gambit> gambits;
            for (auto const& [priority, gambit] : rules)
                if (gambits.size() < MAX_GAMBITS - 1)
                    gambits.push_back(gambit);
            gambits.push_back({ true, GAMBIT_FOE_YOUR_TARGET, GAMBIT_ACTION_ATTACK });
            return gambits;
        }

        void WriteGambits(Player* player, State const& state)
        {
            ObjectGuid::LowType const guid = player->GetGUID().GetCounter();
            CharacterDatabase.DirectExecute("DELETE FROM `mod_companion_mount_gambit` WHERE `guid` = {} AND `mount_spell` = {}",
                guid, state.mountSpell);
            if (state.gambits.empty())
                return;
            std::string values;
            for (size_t i = 0; i < state.gambits.size(); ++i)
            {
                Gambit const& gambit = state.gambits[i];
                values += Acore::StringFormat("{}({}, {}, {}, {}, {}, {}, {})", values.empty() ? "" : ", ",
                    guid, state.mountSpell, uint32(i), uint32(gambit.enabled), uint32(gambit.condition), gambit.action,
                    uint32(state.gambitsCustom));
            }
            CharacterDatabase.DirectExecute("INSERT INTO `mod_companion_mount_gambit` "
                "(`guid`, `mount_spell`, `slot`, `enabled`, `cond`, `action`, `custom`) VALUES " + values);
        }
    }

    uint32 EnergyCost(ActiveSpell const& active)
    {
        Config const& config = GetConfig();
        if (!config.energyEnabled || active.energyClass >= MAX_ENERGY_CLASS)
            return 0;
        return std::min(config.energyCost[active.energyClass], config.energyMax);
    }

    // 3 emplacements au niveau 1, le dernier au niveau 80, reguliers entre deux.
    uint32 GambitSlots(uint8 level)
    {
        Config const& config = GetConfig();
        uint32 const first = std::min(config.gambitFirstSlots, config.gambitMaxSlots);
        uint32 const extra = config.gambitMaxSlots - first;
        uint32 const steps = std::min<uint32>(std::max<uint8>(level, 1) - 1, 79);
        return first + extra * steps / 79;
    }

    uint8 GambitSlotLevel(uint32 slot)
    {
        for (uint32 level = 1; level <= 80; ++level)
            if (GambitSlots(uint8(level)) > slot)
                return uint8(level);
        return 80;
    }

    bool IsGambitCondition(uint32 condition)
    {
        return (condition >= GAMBIT_OWNER_HP_30 && condition <= GAMBIT_OWNER_CURSE)
            || (condition >= GAMBIT_SELF_HP_30 && condition <= GAMBIT_SELF_ENERGY_80)
            || (condition >= GAMBIT_FOE_YOUR_TARGET && condition <= GAMBIT_FOE_ELITE)
            || (condition >= GAMBIT_GROUP_ONE_50 && condition <= GAMBIT_GROUP_THREE_70)
            || (condition >= GAMBIT_FIGHT_2 && condition <= GAMBIT_ALWAYS);
    }

    void LoadGambits(Player* player, State& state)
    {
        state.gambits.clear();
        state.gambitsCustom = false;
        if (QueryResult result = CharacterDatabase.Query(
                "SELECT `enabled`, `cond`, `action`, `custom` FROM `mod_companion_mount_gambit` "
                "WHERE `guid` = {} AND `mount_spell` = {} ORDER BY `slot`",
                player->GetGUID().GetCounter(), state.mountSpell))
        {
            do
            {
                Field* fields = result->Fetch();
                if (state.gambits.size() >= MAX_GAMBITS || !IsGambitCondition(fields[1].Get<uint16>()))
                    continue;
                state.gambits.push_back({ fields[0].Get<uint8>() != 0, fields[1].Get<uint16>(), fields[2].Get<int32>() });
                if (fields[3].Get<uint8>())
                    state.gambitsCustom = true;
            } while (result->NextRow());
        }
    }

    // La liste par defaut suit les sorts appris, tant que le joueur n'a pas
    // fait la sienne ; elle est ecrite pour que l'interface la lise.
    void RefreshDefaultGambits(Player* player, State& state)
    {
        if (state.gambitsCustom || !state.mountSpell)
            return;
        std::vector<Gambit> defaults = Defaults(state);
        bool same = defaults.size() == state.gambits.size();
        for (size_t i = 0; same && i < defaults.size(); ++i)
            same = defaults[i].enabled == state.gambits[i].enabled && defaults[i].condition == state.gambits[i].condition
                && defaults[i].action == state.gambits[i].action;
        if (same)
            return;
        state.gambits = std::move(defaults);
        WriteGambits(player, state);
    }

    bool SaveGambits(Player* player, std::vector<Gambit> const& gambits)
    {
        State& state = GetState(player);
        if (!state.mountSpell || gambits.size() > MAX_GAMBITS)
            return false;
        for (Gambit const& gambit : gambits)
            if (!IsGambitCondition(gambit.condition) || gambit.action == 0 || gambit.action < GAMBIT_ACTION_RETURN)
                return false;
        state.gambits = gambits;
        state.gambitsCustom = true;
        WriteGambits(player, state);
        return true;
    }

    void ResetGambits(Player* player)
    {
        State& state = GetState(player);
        state.gambitsCustom = false;
        state.gambits.clear();
        RefreshDefaultGambits(player, state);
    }

    void DeleteGambits(ObjectGuid::LowType guid)
    {
        CharacterDatabase.Execute("DELETE FROM `mod_companion_mount_gambit` WHERE `guid` = {}", guid);
    }

    Unit* GambitSubject(Creature* companion, Player* owner, uint16 condition)
    {
        switch (condition)
        {
            case GAMBIT_OWNER_HP_30: return owner->IsAlive() && owner->HealthBelowPct(30) ? owner : nullptr;
            case GAMBIT_OWNER_HP_50: return owner->IsAlive() && owner->HealthBelowPct(50) ? owner : nullptr;
            case GAMBIT_OWNER_HP_70: return owner->IsAlive() && owner->HealthBelowPct(70) ? owner : nullptr;
            case GAMBIT_OWNER_HP_90: return owner->IsAlive() && owner->HealthBelowPct(90) ? owner : nullptr;
            case GAMBIT_OWNER_ATTACKED: return owner->IsAlive() && !owner->getAttackers().empty() ? owner : nullptr;
            case GAMBIT_OWNER_POISON: return owner->IsAlive() && HasHarmful(owner, DISPEL_POISON) ? owner : nullptr;
            case GAMBIT_OWNER_DISEASE: return owner->IsAlive() && HasHarmful(owner, DISPEL_DISEASE) ? owner : nullptr;
            case GAMBIT_OWNER_MAGIC: return owner->IsAlive() && HasHarmful(owner, DISPEL_MAGIC) ? owner : nullptr;
            case GAMBIT_OWNER_CURSE: return owner->IsAlive() && HasHarmful(owner, DISPEL_CURSE) ? owner : nullptr;

            case GAMBIT_SELF_HP_30: return companion->HealthBelowPct(30) ? companion : nullptr;
            case GAMBIT_SELF_HP_50: return companion->HealthBelowPct(50) ? companion : nullptr;
            case GAMBIT_SELF_HP_70: return companion->HealthBelowPct(70) ? companion : nullptr;
            case GAMBIT_SELF_ENERGY_40: return companion->GetPower(POWER_ENERGY) >= 40 ? companion : nullptr;
            case GAMBIT_SELF_ENERGY_60: return companion->GetPower(POWER_ENERGY) >= 60 ? companion : nullptr;
            case GAMBIT_SELF_ENERGY_80: return companion->GetPower(POWER_ENERGY) >= 80 ? companion : nullptr;

            case GAMBIT_FOE_YOUR_TARGET:
            {
                Unit* selected = owner->GetSelectedUnit();
                return IsFoe(companion, selected) ? selected : nullptr;
            }
            case GAMBIT_FOE_ITS_TARGET:
                return IsFoe(companion, companion->GetVictim()) ? companion->GetVictim() : nullptr;
            case GAMBIT_FOE_ATTACKING_YOU:
            {
                Unit* attacker = owner->getAttackerForHelper();
                return IsFoe(companion, attacker) ? attacker : nullptr;
            }
            case GAMBIT_FOE_NEAREST:
            case GAMBIT_FOE_HP_20:
            case GAMBIT_FOE_HP_35:
            case GAMBIT_FOE_HP_50:
            case GAMBIT_FOE_HP_90_UP:
            case GAMBIT_FOE_CASTING:
            case GAMBIT_FOE_ELITE:
            {
                Unit* found = nullptr;
                for (Unit* foe : Foes(companion, owner))
                {
                    bool match = false;
                    switch (condition)
                    {
                        case GAMBIT_FOE_NEAREST:
                            match = !found || companion->GetDistance(foe) < companion->GetDistance(found);
                            break;
                        case GAMBIT_FOE_HP_20: match = foe->HealthBelowPct(20); break;
                        case GAMBIT_FOE_HP_35: match = foe->HealthBelowPct(35); break;
                        case GAMBIT_FOE_HP_50: match = foe->HealthBelowPct(50); break;
                        case GAMBIT_FOE_HP_90_UP: match = foe->HealthAbovePct(89); break;
                        case GAMBIT_FOE_CASTING: match = foe->IsNonMeleeSpellCast(false); break;
                        case GAMBIT_FOE_ELITE:
                            if (Creature* creature = foe->ToCreature())
                                match = creature->isElite() || creature->isWorldBoss() || creature->IsDungeonBoss();
                            break;
                        default:
                            break;
                    }
                    if (!match)
                        continue;
                    found = foe;
                    if (condition != GAMBIT_FOE_NEAREST)
                        break;
                }
                return found;
            }

            case GAMBIT_GROUP_ONE_50:
            {
                std::vector<Unit*> hurt;
                for (Unit* member : Party(companion, owner))
                    if (member->HealthBelowPct(50))
                        hurt.push_back(member);
                return Lowest(hurt);
            }
            case GAMBIT_GROUP_THREE_70:
            {
                std::vector<Unit*> hurt;
                for (Unit* member : Party(companion, owner))
                    if (member->HealthBelowPct(70))
                        hurt.push_back(member);
                return hurt.size() >= 3 ? Lowest(hurt) : nullptr;
            }

            case GAMBIT_FIGHT_2:
            case GAMBIT_FIGHT_3:
            case GAMBIT_FIGHT_5:
            {
                uint32 const wanted = condition == GAMBIT_FIGHT_2 ? 2 : condition == GAMBIT_FIGHT_3 ? 3 : 5;
                if (CountFoesAround(companion) < wanted)
                    return nullptr;
                return IsFoe(companion, companion->GetVictim()) ? companion->GetVictim() : companion;
            }
            case GAMBIT_ALWAYS:
                return owner;
            default:
                return nullptr;
        }
    }

    // LE PORTRAIT : « dehors;PV;PV max;energie;energie max;niveau;modele;creature;nom »
    // (la creature de la monture, pour un client sans SetDisplayInfo).
    void SendFrame(Player* player, State& state, Creature* companion, bool force)
    {
        std::string payload = "0";
        if (companion && companion->IsInWorld())
            payload = Acore::StringFormat("1;{};{};{};{};{};{};{};{}", companion->GetHealth(), companion->GetMaxHealth(),
                companion->GetPower(POWER_ENERGY), companion->GetMaxPower(POWER_ENERGY), uint32(companion->GetLevel()),
                companion->GetDisplayId(), GetMountCreatureEntry(sSpellMgr->GetSpellInfo(state.mountSpell)),
                state.name.empty() ? companion->GetName() : state.name);
        if (!force && payload == state.frameSent)
            return;
        state.frameSent = payload;

        WorldPacket data;
        ChatHandler::BuildChatPacket(data, CHAT_MSG_WHISPER, LANG_ADDON, player, player, "CMPF\t" + payload);
        player->SendDirectMessage(&data);
    }
}
