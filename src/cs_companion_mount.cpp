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
 * mod-companion-mount — LES COMMANDES.
 *
 * .companion summon [sort]   (SEC_PLAYER)  sort la monture-compagnon : celle
 *                                          que l'on chevauche, sinon le sort
 *                                          donne (id ou lien), sinon la derniere
 * .companion dismiss         (SEC_PLAYER)  la renvoie a l'ecurie
 * .companion info            (SEC_PLAYER)  quelle monture, et ou elle en est
 *
 * Elles sont le chemin que prendra l'interface (ALE) : le jeu reste jouable
 * au clavier en attendant.
 */

#include "CompanionMount.h"

#include "Chat.h"
#include "ChatCommand.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "SpellInfo.h"
#include "SpellMgr.h"

using namespace Acore::ChatCommands;
using namespace CompanionMount;

class companion_mount_commandscript : public CommandScript
{
public:
    companion_mount_commandscript() : CommandScript("companion_mount_commandscript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable companionTable =
        {
            { "summon",  HandleSummonCommand,  SEC_PLAYER, Console::No },
            { "dismiss", HandleDismissCommand, SEC_PLAYER, Console::No },
            { "info",    HandleInfoCommand,    SEC_PLAYER, Console::No },
        };

        static ChatCommandTable commandTable =
        {
            { "companion", companionTable },
        };

        return commandTable;
    }

    static bool HandleSummonCommand(ChatHandler* handler, Optional<SpellInfo const*> spell)
    {
        if (!GetConfig().enabled)
        {
            Say(handler, TEXT_DISABLED);
            return true;
        }

        Player* player = handler->GetPlayer();

        // QUELLE MONTURE : celle qu'on nomme, sinon celle qu'on chevauche,
        // sinon la derniere choisie.
        uint32 mountSpell = 0;
        if (spell)
            mountSpell = (*spell)->Id;
        else if (uint32 ridden = GetRiddenMountSpell(player))
            mountSpell = ridden;
        else
            mountSpell = GetState(player).mountSpell;

        if (!mountSpell)
        {
            Say(handler, TEXT_NO_MOUNT);
            return true;
        }

        if (!player->HasSpell(mountSpell) || !IsMountSpell(sSpellMgr->GetSpellInfo(mountSpell)))
        {
            Say(handler, TEXT_NOT_A_MOUNT, mountSpell);
            return true;
        }

        Summon(player, mountSpell);
        Say(handler, TEXT_SUMMONED, SpellName(player, mountSpell));
        return true;
    }

    static bool HandleDismissCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        if (!GetState(player).summoned)
        {
            Say(handler, TEXT_NONE);
            return true;
        }

        Dismiss(player);
        Say(handler, TEXT_DISMISSED);
        return true;
    }

    static bool HandleInfoCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        State const& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(handler, TEXT_NO_MOUNT);
            return true;
        }

        uint32 stateText = TEXT_STATE_DISMISSED;
        if (state.summoned)
            stateText = GetCompanion(player) ? TEXT_STATE_OUT : TEXT_STATE_WAITING;

        std::string const* stateString = handler->GetModuleString(MODULE, stateText);
        Say(handler, TEXT_INFO, SpellName(player, state.mountSpell), stateString ? *stateString : "");
        return true;
    }
};

void AddSC_companion_mount_commandscript()
{
    new companion_mount_commandscript();
}
