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
 * .companion info            (SEC_PLAYER)  quelle monture, ou elle en est, ses ordres
 * .companion attack          (SEC_PLAYER)  attaque la cible du joueur
 * .companion follow|stay     (SEC_PLAYER)  suivre le joueur, ou rester sur place
 * .companion passive|defensive|aggressive  (SEC_PLAYER)  son attitude
 * .companion rename [nom]    (SEC_PLAYER)  nomme la monture choisie, sans nom : le retire
 * .companion bag             (SEC_PLAYER)  ce que portent les sacoches de la monture
 * .companion bag put <sac> <place>   (SEC_PLAYER)  y range un objet des sacs (numeros du serveur)
 * .companion bag take <place>        (SEC_PLAYER)  le reprend (places de 1 a N)
 * .companion talent          (SEC_PLAYER)  points et talents de la monture choisie
 * .companion talent learn <id>       (SEC_PLAYER)  un rang de plus
 * .companion talent reset    (SEC_PLAYER)  rend tous les points
 * .companion setlevel <n>    (SEC_GAMEMASTER)  le niveau de la monture choisie, pour les tests
 * .companion snapshot        (SEC_PLAYER)  ecrit la fiche de la monture, pour la fenetre (muet)
 * .companion debug           (SEC_GAMEMASTER)  la bete vue du serveur : PV, cible, mouvement
 *
 * Elles sont le chemin que prendra l'interface (ALE) : le jeu reste jouable
 * au clavier en attendant.
 */

#include "CompanionMount.h"

#include "Chat.h"
#include "ChatCommand.h"
#include "CellImpl.h"
#include "Creature.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "MotionMaster.h"
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
        static ChatCommandTable bagTable =
        {
            { "put",  HandleBagPutCommand,  SEC_PLAYER, Console::No },
            { "take", HandleBagTakeCommand, SEC_PLAYER, Console::No },
            { "",     HandleBagCommand,     SEC_PLAYER, Console::No },
        };

        static ChatCommandTable talentTable =
        {
            { "learn", HandleTalentLearnCommand, SEC_PLAYER, Console::No },
            { "reset", HandleTalentResetCommand, SEC_PLAYER, Console::No },
            { "",      HandleTalentCommand,      SEC_PLAYER, Console::No },
        };

        static ChatCommandTable companionTable =
        {
            { "talent",  talentTable },
            { "bag",     bagTable },
            { "summon",  HandleSummonCommand,  SEC_PLAYER, Console::No },
            { "dismiss", HandleDismissCommand, SEC_PLAYER, Console::No },
            { "info",    HandleInfoCommand,    SEC_PLAYER, Console::No },
            { "attack",  HandleAttackCommand,  SEC_PLAYER, Console::No },
            { "follow",  HandleFollowCommand,  SEC_PLAYER, Console::No },
            { "stay",    HandleStayCommand,    SEC_PLAYER, Console::No },
            { "passive",    HandlePassiveCommand,    SEC_PLAYER, Console::No },
            { "defensive",  HandleDefensiveCommand,  SEC_PLAYER, Console::No },
            { "aggressive", HandleAggressiveCommand, SEC_PLAYER, Console::No },
            { "rename",     HandleRenameCommand,     SEC_PLAYER, Console::No },
            { "snapshot",   HandleSnapshotCommand,   SEC_PLAYER, Console::No },
            { "setlevel",   HandleSetLevelCommand,   SEC_GAMEMASTER, Console::No },
            { "debug",      HandleDebugCommand,      SEC_GAMEMASTER, Console::No },
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
        uint32 const commandText = state.command == ORDER_STAY ? TEXT_CMD_STAY : TEXT_CMD_FOLLOW;
        uint32 reactText = TEXT_REACT_DEFENSIVE;
        if (state.react == REACT_PASSIVE)
            reactText = TEXT_REACT_PASSIVE;
        else if (state.react == REACT_AGGRESSIVE)
            reactText = TEXT_REACT_AGGRESSIVE;

        if (!state.name.empty())
            Say(handler, TEXT_NAME, state.name);
        Say(handler, TEXT_INFO_FULL, SpellName(player, state.mountSpell), String(handler, stateText),
            String(handler, commandText), String(handler, reactText));

        uint8 const level = EffectiveLevel(player, state);
        if (state.xp || level < player->GetLevel())
            Say(handler, TEXT_LEVEL, uint32(level), state.xp, NextLevelXP(level));
        else
            Say(handler, TEXT_LEVEL_MAX, uint32(level));
        return true;
    }

    static bool HandleTalentCommand(ChatHandler* handler)
    {
        ListTalents(handler, handler->GetPlayer());
        return true;
    }

    static bool HandleTalentLearnCommand(ChatHandler* handler, uint32 talentId)
    {
        LearnTalent(handler->GetPlayer(), talentId);
        return true;
    }

    static bool HandleTalentResetCommand(ChatHandler* handler)
    {
        ResetTalents(handler->GetPlayer());
        return true;
    }

    static bool HandleBagCommand(ChatHandler* handler)
    {
        BagList(handler, handler->GetPlayer());
        return true;
    }

    static bool HandleBagPutCommand(ChatHandler* handler, uint8 bag, uint8 slot)
    {
        BagDeposit(handler->GetPlayer(), bag, slot);
        return true;
    }

    static bool HandleBagTakeCommand(ChatHandler* handler, uint32 place)
    {
        if (place >= 1)
            BagWithdraw(handler->GetPlayer(), place - 1);
        return true;
    }

    static bool HandleSnapshotCommand(ChatHandler* handler)
    {
        WriteSnapshot(handler->GetPlayer());
        return true;
    }

    static bool HandleRenameCommand(ChatHandler* handler, Optional<Tail> name)
    {
        Rename(handler->GetPlayer(), name ? std::string(*name) : std::string());
        return true;
    }

    static bool HandleAttackCommand(ChatHandler* handler)
    {
        OrderAttack(handler->GetPlayer(), handler->getSelectedUnit());
        return true;
    }

    static bool HandleFollowCommand(ChatHandler* handler)
    {
        SetCommand(handler->GetPlayer(), ORDER_FOLLOW);
        return true;
    }

    static bool HandleStayCommand(ChatHandler* handler)
    {
        SetCommand(handler->GetPlayer(), ORDER_STAY);
        return true;
    }

    static bool HandlePassiveCommand(ChatHandler* handler)
    {
        SetReact(handler->GetPlayer(), REACT_PASSIVE);
        return true;
    }

    static bool HandleDefensiveCommand(ChatHandler* handler)
    {
        SetReact(handler->GetPlayer(), REACT_DEFENSIVE);
        return true;
    }

    static bool HandleAggressiveCommand(ChatHandler* handler)
    {
        SetReact(handler->GetPlayer(), REACT_AGGRESSIVE);
        return true;
    }

    // POUR LES TESTS : le niveau de la monture choisie, sans la faire monter.
    // Il reste borne par le niveau du maitre quand la conf le veut ; la mise a
    // jour suivante refait ses chiffres et ses talents.
    static bool HandleSetLevelCommand(ChatHandler* handler, uint8 level)
    {
        Player* player = handler->GetPlayer();
        State& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(handler, TEXT_NO_MOUNT);
            return true;
        }
        state.level = std::max<uint8>(1, level);
        state.xp = 0;
        SaveMount(player, state);
        Say(handler, TEXT_LEVEL_SET, uint32(EffectiveLevel(player, state)));
        return true;
    }

    // POUR LES TESTS : ce que le serveur sait de la bete, en clair (non traduit).
    static bool HandleDebugCommand(ChatHandler* handler)
    {
        Player* player = handler->GetPlayer();
        State const& state = GetState(player);
        handler->PSendSysMessage("companion: spell {} summoned {} order {} react {} attackTarget {} reviveTimer {}",
            state.mountSpell, state.summoned, uint32(state.command), uint32(state.react),
            state.attackTarget.ToString(), state.reviveTimer);

        Creature* companion = GetCompanion(player);
        if (!companion)
        {
            handler->SendSysMessage("companion: not out");
            return true;
        }

        Unit* victim = companion->GetVictim();
        handler->PSendSysMessage("companion: {} level {} hp {}/{} display {} dist {:.1f} motion {} combat {} victim {}",
            companion->GetGUID().ToString(), companion->GetLevel(), companion->GetHealth(), companion->GetMaxHealth(),
            companion->GetDisplayId(), companion->GetDistance(player),
            uint32(companion->GetMotionMaster()->GetCurrentMovementGeneratorType()), companion->IsInCombat(),
            victim ? victim->GetName() + " " + victim->GetGUID().ToString() : std::string("none"));

        Unit* nearest = companion->SelectNearestTarget(AGGRESSIVE_RANGE);
        handler->PSendSysMessage("companion: script {} evade {} nearest hostile {} at {:.1f}",
            companion->GetScriptName(), companion->IsInEvadeMode(),
            nearest ? nearest->GetName() : std::string("none"), nearest ? companion->GetDistance(nearest) : 0.0f);
        handler->PSendSysMessage("companion: lootTarget {} tried {}", state.lootTarget.ToString(), state.lootTried.size());

        // Les creatures autour du joueur, avec le GUID que les commandes
        // attendent (.die, .companion attack avec une cible).
        std::list<Creature*> around;
        Acore::AllWorldObjectsInRange check(player, 15.0f);
        Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(player, around, check);
        Cell::VisitObjects(player, searcher, 15.0f);
        uint32 shown = 0;
        for (Creature* creature : around)
        {
            if (creature == companion || ++shown > 10)
                continue;
            handler->PSendSysMessage("  {} {} alive {} lootable {} for you {}", creature->GetName(),
                creature->GetGUID().ToString(), creature->IsAlive(), creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE),
                IsLootableCorpse(player, creature));
        }
        return true;
    }

private:
    static std::string String(ChatHandler* handler, uint32 id)
    {
        std::string const* text = handler->GetModuleString(MODULE, id);
        return text ? *text : "";
    }
};

void AddSC_companion_mount_commandscript()
{
    new companion_mount_commandscript();
}
