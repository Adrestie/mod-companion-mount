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
 * Elle ne cherche pas la bagarre : elle ne frappe que ce que son maitre
 * frappe, ce qui frappe son maitre, ou ce qui la frappe -- un familier en
 * mode DEFENSIF. Trop loin du maitre, elle lache sa proie et revient.
 *
 * LE CLIC DROIT : la creature porte UNIT_NPC_FLAG_SPELLCLICK et une ligne de
 * npc_spellclick_spells, ce qui montre le curseur et fait envoyer le clic par
 * le client. BeforeSpellClick l'intercepte et rend `false` : le sort de la
 * table n'est jamais lance, c'est le sort de monture du joueur qui l'est.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "MotionMaster.h"
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
        // DEFENSIF : rien sur un simple regard (voir MoveInLineOfSight).
        me->SetReactState(REACT_DEFENSIVE);
        _assistTimer = 0;
    }

    // Elle ne s'en prend a personne parce qu'elle l'a vu passer.
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

    void UpdateAI(uint32 diff) override
    {
        Player* owner = GetOwnerPlayer();
        if (!owner)
            return;

        _assistTimer += diff;
        if (_assistTimer >= 500)
        {
            _assistTimer = 0;

            // LA LAISSE : trop loin du maitre, elle revient.
            if (me->GetVictim() && !me->IsWithinDistInMap(owner, GetConfig().leashDistance))
            {
                ReturnToOwner();
                return;
            }

            Unit* target = SelectAssistTarget(owner);
            if (target && target != me->GetVictim())
                AttackStart(target);
        }

        if (Unit* victim = me->GetVictim())
        {
            if (!victim->IsAlive() || !me->IsValidAttackTarget(victim))
            {
                ReturnToOwner();
                return;
            }
            DoMeleeAttackIfReady();
        }
        else if (me->GetMotionMaster()->GetCurrentMovementGeneratorType() != FOLLOW_MOTION_TYPE)
            ReturnToOwner();
    }

private:
    Player* GetOwnerPlayer() const
    {
        Unit* owner = me->GetOwner();
        return owner ? owner->ToPlayer() : nullptr;
    }

    bool CanAssistAgainst(Unit* target) const
    {
        return target && target->IsAlive() && me->IsValidAttackTarget(target)
            && target->IsWithinDistInMap(me, GetConfig().leashDistance);
    }

    // QUI FRAPPER : la cible du maitre d'abord, puis qui l'attaque, puis qui
    // l'attaque elle. Elle garde sa proie tant que le maitre n'en change pas.
    Unit* SelectAssistTarget(Player* owner) const
    {
        if (!owner->IsInCombat() && !me->IsInCombat())
            return nullptr;

        if (Unit* victim = owner->GetVictim())
            if (CanAssistAgainst(victim))
                return victim;

        // Un lanceur de sorts ne frappe pas au corps a corps : sa cible est
        // celle qu'il a selectionnee, si elle se bat contre lui.
        if (Unit* selected = owner->GetSelectedUnit())
            if (selected->IsInCombatWith(owner) && CanAssistAgainst(selected))
                return selected;

        if (Unit* current = me->GetVictim())
            if (CanAssistAgainst(current))
                return current;

        if (Unit* attacker = owner->getAttackerForHelper())
            if (CanAssistAgainst(attacker))
                return attacker;

        if (Unit* attacker = me->getAttackerForHelper())
            if (CanAssistAgainst(attacker))
                return attacker;

        return nullptr;
    }

    void ReturnToOwner()
    {
        Player* owner = GetOwnerPlayer();
        me->AttackStop();
        me->CombatStop(true);
        me->GetMotionMaster()->Clear(false);
        if (owner)
            me->GetMotionMaster()->MoveFollow(owner, PET_FOLLOW_DIST, FOLLOW_ANGLE, MOTION_SLOT_ACTIVE);
    }

    uint32 _assistTimer = 0;
};

void AddSC_npc_companion_mount()
{
    RegisterCreatureAI(npc_companion_mount);
}
