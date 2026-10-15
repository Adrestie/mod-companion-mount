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
 * mod-companion-mount — LES EVENEMENTS DU JEU.
 *
 * Tout passe par la mise a jour du joueur, une fois par seconde : elle sort
 * la bete quand elle peut l'etre (dehors, a pied, vivant...) et la rentre
 * sinon. Descendre de monture, revenir dehors, ressusciter, changer de carte :
 * un seul endroit decide, sans un crochet par cas.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "Player.h"
#include "ScriptMgr.h"

using namespace CompanionMount;

class CompanionMountWorldScript : public WorldScript
{
public:
    CompanionMountWorldScript() : WorldScript("CompanionMountWorldScript",
        {
            WORLDHOOK_ON_AFTER_CONFIG_LOAD
        }) { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadConfig();
    }
};

class CompanionMountPlayerScript : public PlayerScript
{
public:
    // CETTE LISTE OUVRE LES APPELS : un crochet absent d'ici n'est jamais appele.
    CompanionMountPlayerScript() : PlayerScript("CompanionMountPlayerScript",
        {
            PLAYERHOOK_ON_LOGIN,
            PLAYERHOOK_ON_LOGOUT,
            PLAYERHOOK_ON_DELETE,
            PLAYERHOOK_ON_UPDATE,
            PLAYERHOOK_ON_CREATURE_KILL,
        }) { }

    void OnPlayerLogin(Player* player) override
    {
        LoadState(player);
    }

    void OnPlayerLogout(Player* player) override
    {
        OnLogout(player);
    }

    void OnPlayerDelete(ObjectGuid guid, uint32 /*accountId*/) override
    {
        DeleteState(guid.GetCounter());
    }

    void OnPlayerCreatureKill(Player* killer, Creature* killed) override
    {
        GiveKillXP(killer, killed);
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Update(player, diff);
    }
};

// LES COUPS DE LA BETE COMPTENT COMME CEUX DU MAITRE. Le coeur ne donne butin
// et recompense que si un JOUEUR a frappe (Creature::_damagedByPlayer) : un
// monstre tue par un familier seul ne rapporte rien. La monture-compagnon
// combat a la place du joueur : ses coups lui ouvrent les memes droits.
class CompanionMountUnitScript : public UnitScript
{
public:
    CompanionMountUnitScript() : UnitScript("CompanionMountUnitScript", true, { UNITHOOK_ON_DAMAGE }) { }

    void OnDamage(Unit* attacker, Unit* victim, uint32& damage) override
    {
        if (!attacker || !victim || !damage || !GetConfig().killsRewardOwner)
            return;

        Creature* companion = attacker->ToCreature();
        if (!companion || companion->GetEntry() != NPC_COMPANION)
            return;

        Creature* target = victim->ToCreature();
        if (!target || target->IsControlledByPlayer())
            return;

        if (Player* owner = companion->GetCharmerOrOwnerPlayerOrPlayerItself())
            target->LowerPlayerDamageReq(std::min(damage, target->GetHealth()), true, owner->GetLevel());
    }
};

void AddSC_companion_mount_scripts()
{
    new CompanionMountWorldScript();
    new CompanionMountPlayerScript();
    new CompanionMountUnitScript();
}
