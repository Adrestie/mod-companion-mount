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

#include "CompanionMount.h"

#include "Config.h"
#include "Creature.h"
#include "CreatureAI.h"
#include "CreatureData.h"
#include "DatabaseEnv.h"
#include "DBCStores.h"
#include "Map.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "PetDefines.h"
#include "SpellAuraEffects.h"
#include "SpellInfo.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"

#include <algorithm>

namespace CompanionMount
{
    namespace
    {
        constexpr char const* STATE_KEY = "CompanionMount";
        constexpr uint32 UPDATE_INTERVAL = 1000;  // ms entre deux regards

        Config sConfig;

        // LE GARDIEN PREND LE NIVEAU DU MAITRE et les chiffres d'une creature
        // de ce niveau (creature_classlevelstats), multiplies par la
        // configuration. Les talents et l'experience viendront plus tard.
        void ApplyStats(Creature* companion, uint8 level)
        {
            CreatureTemplate const* info = companion->GetCreatureTemplate();
            CreatureBaseStats const* stats = sObjectMgr->GetCreatureBaseStats(level, info->unit_class);
            if (!stats)
                return;

            companion->SetLevel(level);

            uint32 const health = std::max<uint32>(1, uint32(stats->GenerateHealth(info) * sConfig.healthRate));
            companion->SetCreateHealth(health);
            companion->SetStatFlatModifier(UNIT_MOD_HEALTH, BASE_VALUE, float(health));

            float const damage = stats->GenerateBaseDamage(info) * sConfig.damageRate;
            companion->SetBaseWeaponDamage(BASE_ATTACK, MINDAMAGE, damage);
            companion->SetBaseWeaponDamage(BASE_ATTACK, MAXDAMAGE, damage * 1.5f);
            companion->SetStatFlatModifier(UNIT_MOD_ATTACK_POWER, BASE_VALUE, float(stats->AttackPower));
            companion->SetStatFlatModifier(UNIT_MOD_ARMOR, BASE_VALUE, stats->GenerateArmor(info));

            companion->UpdateAllStats();
            companion->SetFullHealth();
        }

        // PEUT-ELLE ETRE DEHORS ? Dehors, le maitre vivant, a pied ou sur une
        // autre monture que la sienne, ni en vol ni en vehicule.
        bool CanBeOut(Player* player, State const& state)
        {
            if (!sConfig.enabled || !state.summoned || !state.mountSpell || state.reviveTimer)
                return false;
            if (!player->IsInWorld() || !player->IsAlive() || player->IsBeingTeleported())
                return false;
            if (player->IsInFlight() || player->GetVehicle())
                return false;
            // ELLE PORTE SON MAITRE : la bete n'est plus a cote, elle est dessous.
            if (player->HasAura(state.mountSpell))
                return false;
            if (!player->IsOutdoors())
                return false;

            Map const* map = player->GetMap();
            if (map->IsBattlegroundOrArena())
                return sConfig.allowInBattlegrounds;
            if (map->IsDungeon())
                return sConfig.allowInDungeons;
            return true;
        }

        void RememberTried(State& state, ObjectGuid guid)
        {
            state.lootTried.push_back(guid);
            if (state.lootTried.size() > LOOT_MEMORY)
                state.lootTried.erase(state.lootTried.begin());
        }

        // LE BUTIN, hors combat et quand elle suit : un corps a la fois. Elle y
        // marche (l'IA), et l'IA appelle OnLootReached une fois dessus.
        void UpdateLoot(Player* player, State& state, Creature* companion, uint32 elapsed)
        {
            if (!sConfig.lootEnabled || state.command != ORDER_FOLLOW)
            {
                state.lootTarget.Clear();
                return;
            }

            bool const busy = player->IsInCombat() || companion->IsInCombat() || companion->GetVictim();

            if (state.lootTarget)
            {
                state.lootTimer += elapsed;
                // Trop long, ou le combat reprend : elle renonce a ce corps.
                if (state.lootTimer >= LOOT_TIMEOUT || busy)
                {
                    if (state.lootTimer >= LOOT_TIMEOUT)
                        RememberTried(state, state.lootTarget);
                    state.lootTarget.Clear();
                    if (companion->IsAIEnabled)
                        companion->AI()->DoAction(ACTION_ORDERS_CHANGED);
                }
                return;
            }

            if (busy || player->GetLootGUID())
                return;

            // Les corps disparus sortent de sa memoire.
            state.lootTried.erase(std::remove_if(state.lootTried.begin(), state.lootTried.end(),
                [player](ObjectGuid const& guid) { return !player->GetMap()->GetCreature(guid); }),
                state.lootTried.end());

            if (Creature* corpse = FindCorpseToLoot(player, companion, state))
            {
                state.lootTarget = corpse->GetGUID();
                state.lootTimer = 0;
                if (companion->IsAIEnabled)
                    companion->AI()->DoAction(ACTION_LOOT);
            }
        }

        void Despawn(State& state, Creature* companion)
        {
            state.companion.Clear();
            state.lootTarget.Clear();
            if (companion && companion->IsSummon())
                companion->ToTempSummon()->UnSummon();
        }

        Creature* Spawn(Player* player, State& state)
        {
            SpellInfo const* mountInfo = sSpellMgr->GetSpellInfo(state.mountSpell);
            CreatureTemplate const* mountTemplate = mountInfo
                ? sObjectMgr->GetCreatureTemplate(GetMountCreatureEntry(mountInfo)) : nullptr;
            SummonPropertiesEntry const* properties = sSummonPropertiesStore.LookupEntry(SUMMON_PROPERTIES);
            if (!mountTemplate || !properties)
                return nullptr;

            float x, y, z;
            player->GetClosePoint(x, y, z, player->GetCombatReach(), PET_FOLLOW_DIST, FOLLOW_ANGLE);
            Position const pos(x, y, z, player->GetOrientation());

            TempSummon* summon = player->GetMap()->SummonCreature(NPC_COMPANION, pos, properties, 0, player);
            if (!summon)
                return nullptr;

            // LE VISAGE DE LA MONTURE : celui que le sort pose sous le joueur.
            CreatureModel model = *ObjectMgr::ChooseDisplayId(mountTemplate);
            sObjectMgr->GetCreatureModelRandomGender(&model, mountTemplate);
            summon->SetDisplayId(model.CreatureDisplayID, model.DisplayScale);
            summon->SetNativeDisplayId(model.CreatureDisplayID);

            ApplyStats(summon, EffectiveLevel(player, state));
            ApplyName(summon, state);

            if (summon->HasUnitTypeMask(UNIT_MASK_MINION))
                static_cast<Minion*>(summon)->SetFollowAngle(FOLLOW_ANGLE);
            summon->GetMotionMaster()->Clear(false);
            summon->GetMotionMaster()->MoveFollow(player, PET_FOLLOW_DIST, FOLLOW_ANGLE, MOTION_SLOT_ACTIVE);

            state.companion = summon->GetGUID();
            return summon;
        }
    }

    Config const& GetConfig()
    {
        return sConfig;
    }

    void LoadConfig()
    {
        sConfig.enabled = sConfigMgr->GetOption<bool>("CompanionMount.Enable", true);
        sConfig.allowInDungeons = sConfigMgr->GetOption<bool>("CompanionMount.AllowInDungeons", false);
        sConfig.allowInBattlegrounds = sConfigMgr->GetOption<bool>("CompanionMount.AllowInBattlegrounds", false);
        sConfig.instantMount = sConfigMgr->GetOption<bool>("CompanionMount.InstantMount", true);
        sConfig.reviveDelay = sConfigMgr->GetOption<uint32>("CompanionMount.ReviveDelay", 60);
        sConfig.healthRate = std::max(0.01f, sConfigMgr->GetOption<float>("CompanionMount.HealthRate", 1.0f));
        sConfig.damageRate = std::max(0.0f, sConfigMgr->GetOption<float>("CompanionMount.DamageRate", 1.0f));
        sConfig.leashDistance = std::max(10.0f, sConfigMgr->GetOption<float>("CompanionMount.LeashDistance", 40.0f));
        sConfig.clickDistance = std::max(2.0f, sConfigMgr->GetOption<float>("CompanionMount.ClickDistance", 10.0f));
        sConfig.lootEnabled = sConfigMgr->GetOption<bool>("CompanionMount.Loot.Enable", true);
        sConfig.lootRange = std::max(5.0f, sConfigMgr->GetOption<float>("CompanionMount.Loot.Range", 30.0f));
        sConfig.killsRewardOwner = sConfigMgr->GetOption<bool>("CompanionMount.KillsRewardOwner", true);
        sConfig.levelEnabled = sConfigMgr->GetOption<bool>("CompanionMount.Level.Enable", true);
        sConfig.levelStart = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("CompanionMount.Level.Start", 1), 1, 255);
        sConfig.levelCapToOwner = sConfigMgr->GetOption<bool>("CompanionMount.Level.CapToOwner", true);
        sConfig.levelXpNeedRate = std::max(0.001f, sConfigMgr->GetOption<float>("CompanionMount.Level.XpNeedRate", 0.05f));
        sConfig.levelXpKillRate = std::max(0.0f, sConfigMgr->GetOption<float>("CompanionMount.Level.XpKillRate", 1.0f));
        sConfig.levelSharedPercent = std::min<uint32>(sConfigMgr->GetOption<uint32>("CompanionMount.Level.SharedPercent", 10), 100);
    }

    State& GetState(Player* player)
    {
        return *player->CustomData.GetDefault<State>(STATE_KEY);
    }

    void LoadState(Player* player)
    {
        State& state = GetState(player);
        state = State();
        state.loaded = true;

        QueryResult result = CharacterDatabase.Query(
            "SELECT `mount_spell`, `summoned`, `react_state`, `shared_pool` FROM `mod_companion_mount_character` WHERE `guid` = {}",
            player->GetGUID().GetCounter());
        if (!result)
            return;

        Field* fields = result->Fetch();
        state.pool = fields[3].Get<uint64>();
        uint8 const react = fields[2].Get<uint8>();
        state.react = react <= REACT_AGGRESSIVE ? ReactStates(react) : REACT_DEFENSIVE;

        uint32 const mountSpell = fields[0].Get<uint32>();
        // Une monture oubliee depuis (sort retire, base changee) ne revient pas.
        if (!player->HasSpell(mountSpell) || !IsMountSpell(sSpellMgr->GetSpellInfo(mountSpell)))
            return;

        state.mountSpell = mountSpell;
        state.summoned = fields[1].Get<bool>();
        LoadMount(player, state);
        // La connexion repart sur « suivre » : la base le dit aussi a l'interface.
        SaveState(player);
    }

    // ECRITURE IMMEDIATE : l'interface (ALE) relit la ligne juste apres la
    // commande ; une ecriture differee lui montrerait l'etat d'avant.
    void SaveState(Player* player)
    {
        State const& state = GetState(player);
        CharacterDatabase.DirectExecute(
            "REPLACE INTO `mod_companion_mount_character` (`guid`, `mount_spell`, `summoned`, `command_state`, `react_state`, `shared_pool`) "
            "VALUES ({}, {}, {}, {}, {}, {})",
            player->GetGUID().GetCounter(), state.mountSpell, state.summoned ? 1 : 0,
            uint32(state.command), uint32(state.react), state.pool);
    }

    void DeleteState(ObjectGuid::LowType guid)
    {
        CharacterDatabase.Execute("DELETE FROM `mod_companion_mount_character` WHERE `guid` = {}", guid);
    }

    bool IsMountSpell(SpellInfo const* spellInfo)
    {
        return GetMountCreatureEntry(spellInfo) != 0;
    }

    uint32 GetMountCreatureEntry(SpellInfo const* spellInfo)
    {
        if (!spellInfo)
            return 0;
        for (uint8 i = 0; i < MAX_SPELL_EFFECTS; ++i)
            if (spellInfo->Effects[i].ApplyAuraName == SPELL_AURA_MOUNTED)
                return uint32(spellInfo->Effects[i].MiscValue);
        return 0;
    }

    uint32 GetRiddenMountSpell(Player* player)
    {
        Unit::AuraEffectList const& mounts = player->GetAuraEffectsByType(SPELL_AURA_MOUNTED);
        return mounts.empty() ? 0 : mounts.front()->GetId();
    }

    Creature* GetCompanion(Player* player)
    {
        State& state = GetState(player);
        if (!state.companion)
            return nullptr;

        Creature* companion = ObjectAccessor::GetCreature(*player, state.companion);
        if (!companion || !companion->IsInWorld() || !companion->IsAlive()
            || companion->GetOwnerGUID() != player->GetGUID())
        {
            // Partie avec la carte, morte, ou disparue : on l'oublie.
            state.companion.Clear();
            return nullptr;
        }
        return companion;
    }

    bool Summon(Player* player, uint32 mountSpell)
    {
        State& state = GetState(player);
        Despawn(state, GetCompanion(player));

        // UNE AUTRE MONTURE : la precedente garde sa progression, la nouvelle
        // reprend la sienne (et sa part du pot commun).
        if (state.mountSpell != mountSpell || !state.loaded)
        {
            SaveMount(player, state);
            state.mountSpell = mountSpell;
            LoadMount(player, state);
        }
        state.summoned = true;
        state.reviveTimer = 0;
        state.updateTimer = 0;
        SaveState(player);

        // SUR CETTE MONTURE-LA : le joueur descend, elle marche a cote.
        if (player->HasAura(mountSpell))
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);

        if (CanBeOut(player, state))
            return Spawn(player, state) != nullptr;
        return true;
    }

    void Dismiss(Player* player)
    {
        State& state = GetState(player);
        Despawn(state, GetCompanion(player));
        state.summoned = false;
        state.reviveTimer = 0;
        SaveState(player);
    }

    bool Ride(Player* player, Creature* companion)
    {
        State& state = GetState(player);
        if (companion->GetOwnerGUID() != player->GetGUID())
        {
            Say(player, TEXT_NOT_YOURS);
            return false;
        }
        if (!player->IsWithinDistInMap(companion, GetConfig().clickDistance))
        {
            Say(player, TEXT_TOO_FAR);
            return false;
        }
        if (!state.mountSpell || !player->HasSpell(state.mountSpell))
        {
            Say(player, TEXT_NO_MOUNT);
            return false;
        }

        // Une autre monture sous le joueur : il en descend d'abord.
        if (player->IsMounted())
            player->RemoveAurasByType(SPELL_AURA_MOUNTED);

        // LE SORT DE MONTURE, lance sur le joueur. Ses verifications restent
        // (combat, interieur, zone sans vol...) : un refus s'affiche comme
        // d'habitude et la bete reste la.
        TriggerCastFlags const flags = sConfig.instantMount
            ? TriggerCastFlags(TRIGGERED_CAST_DIRECTLY | TRIGGERED_IGNORE_GCD)
            : TRIGGERED_NONE;
        if (player->CastSpell(player, state.mountSpell, flags) != SPELL_CAST_OK)
            return false;

        // Monte tout de suite : elle s'en va comme un familier renvoye. Avec
        // un temps d'incantation, la mise a jour suivante s'en charge.
        if (player->HasAura(state.mountSpell))
            Despawn(state, companion);
        return true;
    }

    void Update(Player* player, uint32 diff)
    {
        State& state = GetState(player);
        if (!state.loaded)
            return;

        state.updateTimer += diff;
        if (state.updateTimer < UPDATE_INTERVAL)
            return;
        uint32 const elapsed = state.updateTimer;
        state.updateTimer = 0;

        if (state.reviveTimer)
            state.reviveTimer = elapsed >= state.reviveTimer ? 0 : state.reviveTimer - elapsed;
        if (state.bagsFullTimer)
            state.bagsFullTimer = elapsed >= state.bagsFullTimer ? 0 : state.bagsFullTimer - elapsed;

        Creature* companion = GetCompanion(player);
        bool const canBeOut = CanBeOut(player, state);

        if (companion && !canBeOut)
            Despawn(state, companion);
        else if (!companion && canBeOut)
            Spawn(player, state);
        else if (companion)
        {
            // TROP LOIN (teleportation proche, chute, poursuite) : elle revient
            // aupres du maitre plutot que de courir a travers la zone. Celle a
            // qui on a dit de RESTER attend plus loin, jusqu'a la limite de vue ;
            // au-dela elle revient, et suit de nouveau.
            float const farAway = state.command == ORDER_STAY ? STAY_RANGE : sConfig.leashDistance * 2.0f;
            if (!companion->IsWithinDistInMap(player, farAway))
            {
                if (state.command == ORDER_STAY)
                {
                    state.command = ORDER_FOLLOW;
                    SaveState(player);
                }
                state.attackTarget.Clear();
                Despawn(state, companion);
                Spawn(player, state);
            }
            else
            {
                if (companion->GetLevel() != EffectiveLevel(player, state))
                    ApplyStats(companion, EffectiveLevel(player, state));
                UpdateLoot(player, state, companion, elapsed);
            }
        }
        else
            state.lootTarget.Clear();
    }

    void OnLootReached(Player* player, Creature* corpse)
    {
        State& state = GetState(player);
        state.lootTarget.Clear();

        // Le joueur fouille lui-meme a cet instant : on reviendra.
        if (player->GetLootGUID())
            return;

        // COMME LE JOUEUR AVEC mod-aoe-loot : les corps autour avec celui-ci.
        bool bagsFull = false;
        Creature* companion = GetCompanion(player);
        std::vector<Creature*> corpses = companion
            ? FindAreaCorpses(player, companion, corpse) : std::vector<Creature*>{ corpse };
        for (Creature* each : corpses)
        {
            if (LootCorpse(player, each) == LOOT_RESULT_BAGS_FULL)
                bagsFull = true;
            RememberTried(state, each->GetGUID());
        }

        if (bagsFull && !state.bagsFullTimer)
        {
            Say(player, TEXT_BAGS_FULL);
            state.bagsFullTimer = 60 * IN_MILLISECONDS;
        }
    }

    void SetCommand(Player* player, Order order)
    {
        State& state = GetState(player);
        state.command = order;
        state.attackTarget.Clear();
        SaveState(player);
        if (Creature* companion = GetCompanion(player))
            if (companion->IsAIEnabled)
                companion->AI()->DoAction(ACTION_ORDERS_CHANGED);
    }

    void SetReact(Player* player, ReactStates react)
    {
        State& state = GetState(player);
        state.react = react;
        state.attackTarget.Clear();
        SaveState(player);
        if (Creature* companion = GetCompanion(player))
            if (companion->IsAIEnabled)
                companion->AI()->DoAction(ACTION_ORDERS_CHANGED);
    }

    // « ATTAQUER » : quelle que soit l'attitude, meme passive, comme le
    // familier. La cible reste designee jusqu'a sa mort ou un autre ordre.
    bool OrderAttack(Player* player, Unit* target)
    {
        Creature* companion = GetCompanion(player);
        if (!companion)
        {
            Say(player, TEXT_NOT_OUT);
            return false;
        }
        if (!target || target == player || !target->IsAlive() || !companion->IsValidAttackTarget(target)
            || !player->IsValidAttackTarget(target))
        {
            Say(player, TEXT_BAD_TARGET);
            return false;
        }

        State& state = GetState(player);
        state.attackTarget = target->GetGUID();
        if (companion->IsAIEnabled)
            companion->AI()->DoAction(ACTION_ATTACK);
        return true;
    }

    void OnCompanionDied(Player* owner)
    {
        State& state = GetState(owner);
        state.companion.Clear();
        state.reviveTimer = sConfig.reviveDelay * IN_MILLISECONDS;
        if (state.reviveTimer)
            Say(owner, TEXT_DIED, sConfig.reviveDelay);
    }

    void OnLogout(Player* player)
    {
        State& state = GetState(player);
        Despawn(state, GetCompanion(player));
    }

    std::string SpellName(Player* player, uint32 spellId)
    {
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            return std::to_string(spellId);
        char const* name = spellInfo->SpellName[player->GetSession()->GetSessionDbcLocale()];
        if (!name || !*name)
            name = spellInfo->SpellName[LOCALE_enUS];
        return name ? name : std::to_string(spellId);
    }
}
