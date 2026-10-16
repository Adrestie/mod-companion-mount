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
 * mod-companion-mount — CE QUE FAIT LA BETE.
 *
 * Elle obeit comme un familier, aux memes ordres :
 *   SUIVRE / RESTER   elle marche a cote du maitre, ou garde sa place ;
 *   PASSIVE           elle ne frappe que ce qu'on lui dit d'attaquer ;
 *   DEFENSIVE         elle frappe ce que son maitre frappe, ce qui frappe son
 *                     maitre, ou ce qui la frappe (attitude par defaut) ;
 *   AGRESSIVE         elle va en plus chercher tout ennemi a 20 metres ;
 *   ATTAQUER          la cible du maitre, quelle que soit l'attitude.
 * Hors combat, quand elle suit, elle va aux corps a fouiller que
 * CompanionMount lui designe (State::lootTarget), puis revient.
 * Trop loin du maitre, elle lache sa proie et revient (la laisse).
 *
 * Les ordres vivent dans l'etat du maitre (CompanionMount::State) : la bete
 * meurt, rentre, ressort, ils restent. L'IA les relit a chaque decision.
 *
 * LE CLIC DROIT : la creature porte UNIT_NPC_FLAG_SPELLCLICK et une ligne de
 * npc_spellclick_spells, ce qui montre le curseur et fait envoyer le clic par
 * le client. BeforeSpellClick l'intercepte et rend `false` : le sort de la
 * table n'est jamais lance, c'est le sort de monture du joueur qui l'est.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "PetDefines.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "ScriptedCreature.h"
#include "SpellInfo.h"
#include "Spell.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"

#include <algorithm>
#include <unordered_map>

using namespace CompanionMount;

struct npc_companion_mount : public ScriptedAI
{
    npc_companion_mount(Creature* creature) : ScriptedAI(creature) { }

    void InitializeAI() override
    {
        ScriptedAI::InitializeAI();
        // Le coeur ne choisit rien pour elle : tout passe par SelectTarget.
        me->SetReactState(REACT_DEFENSIVE);
        _decideTimer = 0;
        _hasStayPos = false;
    }

    // Elle ne s'en prend a personne parce qu'elle l'a vu passer : meme
    // agressive, c'est SelectTarget qui decide, a sa cadence.
    void MoveInLineOfSight(Unit* /*who*/) override { }

    bool BeforeSpellClick(Unit* clicker) override
    {
        if (Player* player = clicker->ToPlayer())
            Ride(player, me);
        return false;
    }

    // LA BETE ACHEVE : l'experience est pour elle (le joueur qui acheve passe
    // par CompanionMountPlayerScript::OnPlayerCreatureKill).
    void KilledUnit(Unit* victim) override
    {
        if (Creature* killed = victim->ToCreature())
            if (Player* owner = GetOwnerPlayer())
                GiveKillXP(owner, killed);
    }

    void JustDied(Unit* /*killer*/) override
    {
        if (Player* owner = GetOwnerPlayer())
            OnCompanionDied(owner);
    }

    void DoAction(int32 action) override
    {
        Player* owner = GetOwnerPlayer();
        if (!owner)
            return;
        State& state = GetState(owner);

        switch (action)
        {
            case ACTION_ATTACK:
                if (Unit* target = ObjectAccessor::GetUnit(*me, state.attackTarget))
                    AttackStart(target);
                break;
            case ACTION_LOOT:
                if (Creature* corpse = ObjectAccessor::GetCreature(*me, state.lootTarget))
                {
                    me->GetMotionMaster()->Clear(false);
                    me->GetMotionMaster()->MovePoint(POINT_LOOT, corpse->GetPosition());
                }
                break;
            case ACTION_ORDERS_CHANGED:
                // RESTER : ici meme. Un nouvel ordre, ou passive : elle lache
                // tout et rejoint son poste.
                if (state.command == ORDER_STAY)
                {
                    _stayPos = me->GetPosition();
                    _hasStayPos = true;
                }
                if (state.command == ORDER_STAY || state.react == REACT_PASSIVE || !me->GetVictim())
                    ReturnToPost(owner, state);
                break;
            default:
                break;
        }
    }

    void UpdateAI(uint32 diff) override
    {
        Player* owner = GetOwnerPlayer();
        if (!owner)
            return;
        State& state = GetState(owner);

        _decideTimer += diff;
        if (_decideTimer >= 500)
        {
            _decideTimer = 0;

            // LA LAISSE : trop loin du maitre, elle revient.
            if (me->GetVictim() && !me->IsWithinDistInMap(owner, GetConfig().leashDistance))
            {
                state.attackTarget.Clear();
                ReturnToPost(owner, state);
                return;
            }

            Unit* target = SelectTarget(owner, state);
            if (target && target != me->GetVictim())
                AttackStart(target);
        }

        if (Unit* victim = me->GetVictim())
        {
            if (!victim->IsAlive() || !me->IsValidAttackTarget(victim))
            {
                if (victim->GetGUID() == state.attackTarget)
                    state.attackTarget.Clear();
                ReturnToPost(owner, state);
                return;
            }
            CastTalents(owner, state, victim, diff);
            DoMeleeAttackIfReady();
        }
        else
            CastTalents(owner, state, nullptr, diff);

        if (me->GetVictim())
            return;
        if (state.lootTarget)
            GoLoot(owner, state);
        else
            KeepPost(owner, state);
    }

private:
    Player* GetOwnerPlayer() const
    {
        Unit* owner = me->GetOwner();
        return owner ? owner->ToPlayer() : nullptr;
    }

    bool CanFight(Unit* target) const
    {
        return target && target->IsAlive() && me->IsValidAttackTarget(target)
            && target->IsWithinDistInMap(me, GetConfig().leashDistance);
    }

    // QUI FRAPPER. L'ordre d'attaque d'abord ; puis, selon l'attitude, la
    // cible du maitre, qui l'attaque, qui l'attaque elle, et pour l'agressive
    // l'ennemi le plus proche.
    Unit* SelectTarget(Player* owner, State& state) const
    {
        if (state.attackTarget)
        {
            Unit* ordered = ObjectAccessor::GetUnit(*me, state.attackTarget);
            if (CanFight(ordered))
                return ordered;
            state.attackTarget.Clear();
        }

        if (state.react == REACT_PASSIVE)
            return nullptr;

        if (owner->IsInCombat() || me->IsInCombat())
        {
            if (Unit* victim = owner->GetVictim())
                if (CanFight(victim))
                    return victim;

            // Un lanceur de sorts ne frappe pas au corps a corps : sa cible est
            // celle qu'il a selectionnee, si elle se bat contre lui.
            if (Unit* selected = owner->GetSelectedUnit())
                if (selected->IsInCombatWith(owner) && CanFight(selected))
                    return selected;

            if (Unit* current = me->GetVictim())
                if (CanFight(current))
                    return current;

            if (Unit* attacker = owner->getAttackerForHelper())
                if (CanFight(attacker))
                    return attacker;

            if (Unit* attacker = me->getAttackerForHelper())
                if (CanFight(attacker))
                    return attacker;
        }

        if (state.react == REACT_AGGRESSIVE && !me->GetVictim())
            if (Unit* enemy = me->SelectNearestTarget(AGGRESSIVE_RANGE))
                if (CanFight(enemy))
                    return enemy;

        return nullptr;
    }

    void ReturnToPost(Player* owner, State const& state)
    {
        me->AttackStop();
        me->CombatStop(true);
        me->GetMotionMaster()->Clear(false);
        if (state.command == ORDER_STAY)
        {
            if (!_hasStayPos)
            {
                _stayPos = me->GetPosition();
                _hasStayPos = true;
            }
            me->GetMotionMaster()->MovePoint(0, _stayPos);
        }
        else
            me->GetMotionMaster()->MoveFollow(owner, PET_FOLLOW_DIST, FOLLOW_ANGLE, MOTION_SLOT_ACTIVE);
    }

    // LES SORTS DES TALENTS, chacun selon son usage, quand son temps de
    // recharge est passe. Le cout (focalisation d'un familier, mana) est
    // ignore : la bete n'a ni l'un ni l'autre.
    void CastTalents(Player* owner, State& state, Unit* victim, uint32 diff)
    {
        _talentTimer += diff;
        for (auto& [spell, ready] : _cooldowns)
            ready = ready > diff ? ready - diff : 0;
        if (me->HasUnitState(UNIT_STATE_CASTING))
            return;

        // LANCE A LA MAIN (la barre, .companion cast) : tout de suite, sur sa
        // cible naturelle, sans les conditions de l'automatique ; un sort en
        // recharge attend.
        if (uint32 const wanted = state.castRequest)
        {
            state.castRequest = 0;
            for (ActiveSpell const& active : state.actives)
            {
                if (FirstRank(active.spell) != wanted)
                    continue;
                // Le refus s'affiche comme celui d'un sort du joueur (texte rouge).
                if (_cooldowns[active.spell])
                    Refuse(owner, active, SPELL_FAILED_NOT_READY);
                else if (Unit* target = TalentTarget(active, owner, victim, true))
                {
                    if (TryCast(active, target, false))
                        return;
                    Refuse(owner, active, SpellCastResult(active.lastRefusal));
                }
                else
                    Refuse(owner, active, SPELL_FAILED_BAD_TARGETS);
                break;
            }
        }

        if (_talentTimer < 1000)
            return;
        _talentTimer = 0;

        for (ActiveSpell const& active : state.actives)
        {
            // Le joueur a coupe son lancement automatique (clic droit sur la barre).
            if (_cooldowns[active.spell] || state.autocastOff.count(FirstRank(active.spell)))
                continue;
            if (TryCast(active, TalentTarget(active, owner, victim, false), true))
                return;   // un sort par tour
        }
    }

    // SUR QUI. Automatique : selon son usage et l'instant (PV, combat).
    // A la main : la cible naturelle du sort, sans condition.
    Unit* TalentTarget(ActiveSpell const& active, Player* owner, Unit* victim, bool byHand) const
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(active.spell);
        if (!info)
            return nullptr;

        bool const fighting = victim || me->IsInCombat();
        switch (active.use)
        {
            case TALENT_USE_VICTIM:
            {
                Unit* target = victim;
                if (!target && byHand)
                    if (Unit* selected = owner->GetSelectedUnit())
                        if (me->IsValidAttackTarget(selected))
                            target = selected;
                if (target && me->IsWithinDistInMap(target, std::max(info->GetMaxRange(false), 5.0f)))
                    return target;
                return nullptr;
            }
            case TALENT_USE_SELF:
                // une aura deja posee n'est pas relancee
                return (byHand || (fighting && !me->HasAura(info->Id))) ? me : nullptr;
            case TALENT_USE_SELF_HEAL:
                return (byHand || me->HealthBelowPct(50)) ? me : nullptr;
            case TALENT_USE_OWNER:
                if ((byHand || owner->IsInCombat()) && me->IsWithinDistInMap(owner, 30.0f))
                    return owner;
                return nullptr;
            case TALENT_USE_OWNER_HEAL:
                if (owner->IsAlive() && (byHand || owner->HealthBelowPct(80)) && me->IsWithinDistInMap(owner, 40.0f))
                    return owner;
                return nullptr;
            default:
                return nullptr;
        }
    }

    void Refuse(Player* owner, ActiveSpell const& active, SpellCastResult result) const
    {
        if (SpellInfo const* info = sSpellMgr->GetSpellInfo(active.spell))
            Spell::SendCastResult(owner, info, 0, result);
    }

    // Lance le sort ; reussi, sa recharge commence. Refuse en automatique, il
    // attend 3 s (portee, cible) avant d'etre retente.
    bool TryCast(ActiveSpell const& active, Unit* target, bool automatic)
    {
        SpellInfo const* info = sSpellMgr->GetSpellInfo(active.spell);
        if (!info || !target)
            return false;

        // Ni mana ni rage, ni forme ni posture : une bete n'en a pas.
        TriggerCastFlags const flags = TriggerCastFlags(TRIGGERED_IGNORE_POWER_AND_REAGENT_COST | TRIGGERED_IGNORE_GCD
            | TRIGGERED_IGNORE_SHAPESHIFT);
        SpellCastResult const result = me->CastSpell(target, info, flags);
        if (result == SPELL_CAST_OK)
        {
            ++active.casts;
            uint32 cooldown = active.cooldown;
            if (!cooldown)
                cooldown = std::max<uint32>({ info->RecoveryTime, info->CategoryRecoveryTime, 6000 });
            _cooldowns[active.spell] = cooldown;
            return true;
        }
        active.lastRefusal = int32(result);
        if (automatic)
            _cooldowns[active.spell] = 3000;
        return false;
    }

    // AU CORPS : arrivee, elle fouille (pour son maitre) et revient.
    void GoLoot(Player* owner, State& state)
    {
        Creature* corpse = ObjectAccessor::GetCreature(*me, state.lootTarget);
        if (!corpse)
        {
            state.lootTarget.Clear();
            ReturnToPost(owner, state);
            return;
        }

        if (me->GetExactDist2d(corpse) <= LOOT_REACH)
        {
            OnLootReached(owner, corpse);
            ReturnToPost(owner, state);
        }
        else if (me->GetMotionMaster()->GetCurrentMovementGeneratorType() != POINT_MOTION_TYPE)
            me->GetMotionMaster()->MovePoint(POINT_LOOT, corpse->GetPosition());
    }

    // Sans proie : a son poste. Rester, c'est revenir a sa place si un combat
    // l'en a ecartee ; suivre, c'est suivre.
    void KeepPost(Player* owner, State const& state)
    {
        MovementGeneratorType const motion = me->GetMotionMaster()->GetCurrentMovementGeneratorType();
        if (state.command == ORDER_STAY)
        {
            if (!_hasStayPos)
            {
                _stayPos = me->GetPosition();
                _hasStayPos = true;
            }
            if (motion != POINT_MOTION_TYPE && me->GetExactDist(&_stayPos) > 2.0f)
                ReturnToPost(owner, state);
        }
        else if (motion != FOLLOW_MOTION_TYPE)
        {
            _hasStayPos = false;
            ReturnToPost(owner, state);
        }
    }

    static constexpr uint32 POINT_LOOT = 1;
    static constexpr float LOOT_REACH = 4.0f;    // metres

    uint32 _decideTimer = 0;
    uint32 _talentTimer = 0;
    std::unordered_map<uint32, uint32> _cooldowns;   // sort -> ms avant de pouvoir le relancer
    bool _hasStayPos = false;
    Position _stayPos;
};

void AddSC_npc_companion_mount()
{
    RegisterCreatureAI(npc_companion_mount);
}
