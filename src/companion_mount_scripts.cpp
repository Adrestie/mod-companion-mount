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

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        Update(player, diff);
    }
};

void AddSC_companion_mount_scripts()
{
    new CompanionMountWorldScript();
    new CompanionMountPlayerScript();
}
