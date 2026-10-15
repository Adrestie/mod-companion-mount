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
#include "TemporarySummon.h"

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
            DoMeleeAttackIfReady();
        }
        else if (state.lootTarget)
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
    bool _hasStayPos = false;
    Position _stayPos;
};

void AddSC_npc_companion_mount()
{
    RegisterCreatureAI(npc_companion_mount);
}
