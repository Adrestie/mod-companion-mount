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
 * mod-companion-mount — LA MONTURE QUI MARCHE A COTE DU JOUEUR.
 *
 * Une monture que le joueur connait sort de l'ecurie et le suit a pied : elle
 * combat avec lui, dehors. Un clic droit dessus et il la chevauche -- le sort
 * de monture correspondant est lance sur lui et la bete disparait comme un
 * familier renvoye. Il met pied a terre : elle revient a ses cotes.
 *
 * LA MECANIQUE : un GARDIEN (Guardian), comme le loup fantome du chaman, et
 * non un familier. Un joueur n'a qu'un emplacement de familier ; le gardien
 * n'en prend aucun, si bien que le chasseur ou le demoniste garde le sien.
 *
 * L'ETAT d'un joueur vit sur le joueur lui-meme (Player::CustomData) : les
 * cartes se mettent a jour en parallele, une table commune ne le supporterait
 * pas sans verrou.
 */

#ifndef MOD_COMPANION_MOUNT_H
#define MOD_COMPANION_MOUNT_H

#include "Chat.h"
#include "DataMap.h"
#include "ObjectGuid.h"
#include "Player.h"
#include "SharedDefines.h"

#include <string>
#include <vector>

class Creature;
class SpellInfo;

namespace CompanionMount
{
    constexpr char const* MODULE = "mod-companion-mount";

    // IDENTIFIANTS PROVISOIRES. La tranche 91 est libre dans ID_RANGES.md ;
    // elle n'est PAS encore attribuee au module. A confirmer avant toute
    // diffusion : ne pas s'en servir ailleurs en attendant.
    constexpr uint32 NPC_COMPANION     = 91000;  // creature_template
    constexpr uint32 SPELL_CLICK_RIDE  = 91000;  // spell_dbc, jamais lance

    // SummonProperties 61 : categorie ALLY, type GUARDIAN, aucun emplacement --
    // celles du loup fantome. Elles font un gardien sans prendre la place du
    // familier.
    constexpr uint32 SUMMON_PROPERTIES = 61;

    // Le compagnon se tient a la droite du joueur ; le familier, a sa gauche.
    constexpr float FOLLOW_ANGLE = 4.712389f;  // 3 pi / 2

    // Les textes de module_string (data/sql/world/companion_mount_03_strings.sql).
    enum Text : uint32
    {
        TEXT_DISABLED        = 1,
        TEXT_NOT_A_MOUNT     = 2,
        TEXT_NO_MOUNT        = 3,
        TEXT_SUMMONED        = 4,
        TEXT_DISMISSED       = 5,
        TEXT_NONE            = 6,
        TEXT_INFO            = 7,
        TEXT_STATE_OUT       = 8,
        TEXT_STATE_WAITING   = 9,
        TEXT_STATE_DISMISSED = 10,
        TEXT_DIED            = 11,
        TEXT_NOT_YOURS       = 12,
        TEXT_TOO_FAR         = 13,
        TEXT_BAD_TARGET      = 14,
        TEXT_NOT_OUT         = 15,
        TEXT_CMD_FOLLOW      = 16,
        TEXT_CMD_STAY        = 17,
        TEXT_REACT_PASSIVE   = 18,
        TEXT_REACT_DEFENSIVE = 19,
        TEXT_REACT_AGGRESSIVE = 20,
        TEXT_INFO_FULL       = 21,  // remplace TEXT_INFO (7), retire
        TEXT_BAGS_FULL       = 22,
    };

    // LES ORDRES, comme ceux de la barre du familier.
    enum Order : uint8
    {
        ORDER_FOLLOW = 0,
        ORDER_STAY   = 1,
    };

    // Ce que l'IA recoit de CompanionMount (CreatureAI::DoAction).
    enum Action : int32
    {
        ACTION_ORDERS_CHANGED = 1,   // suivre/rester ou attitude changes
        ACTION_ATTACK         = 2,   // State::attackTarget vient d'etre pose
        ACTION_LOOT           = 3,   // State::lootTarget vient d'etre pose
    };

    // Ce que la bete a fait d'un corps.
    enum LootResult : uint8
    {
        LOOT_RESULT_NOTHING   = 0,   // rien a prendre, ou pas maintenant
        LOOT_RESULT_DONE      = 1,   // tout ce qu'elle avait le droit de prendre
        LOOT_RESULT_BAGS_FULL = 2,   // des objets restent faute de place
    };

    // Combien de temps la bete cherche a atteindre un corps avant d'y renoncer.
    constexpr uint32 LOOT_TIMEOUT = 15000;   // ms
    // Combien de corps deja visites elle se rappelle (pour ne pas y revenir).
    constexpr size_t LOOT_MEMORY = 64;

    // Distance a laquelle une monture AGRESSIVE va chercher la bagarre.
    constexpr float AGGRESSIVE_RANGE = 20.0f;

    // Jusqu'ou une monture a qui l'on a dit de rester attend son maitre.
    constexpr float STAY_RANGE = 100.0f;

    struct Config
    {
        bool enabled = true;
        bool allowInDungeons = false;
        bool allowInBattlegrounds = false;
        bool instantMount = true;
        uint32 reviveDelay = 60;      // secondes
        float healthRate = 1.0f;
        float damageRate = 1.0f;
        float leashDistance = 40.0f;  // metres
        float clickDistance = 10.0f;  // metres
        bool lootEnabled = true;
        float lootRange = 30.0f;      // metres autour du joueur
        bool killsRewardOwner = true; // ses coups ouvrent butin et recompense
    };

    // CE QUE LE JOUEUR A CHOISI, et ou en est sa monture.
    struct State : public DataMap::Base
    {
        bool loaded = false;
        uint32 mountSpell = 0;        // le sort de monture qui donne le modele
        bool summoned = false;        // le joueur la veut a ses cotes
        ObjectGuid companion;         // la creature, quand elle est dehors
        uint32 updateTimer = 0;
        uint32 reviveTimer = 0;       // ms avant qu'elle revienne apres sa mort

        // LES ORDRES. L'attitude est gardee en base ; suivre/rester aussi, mais
        // une connexion repart toujours sur « suivre » -- l'endroit ou elle
        // restait n'a plus de sens.
        uint8 command = ORDER_FOLLOW;
        ReactStates react = REACT_DEFENSIVE;
        ObjectGuid attackTarget;      // la cible designee par « attaquer »

        // LE BUTIN : le corps vers lequel elle marche, depuis quand, et ceux
        // qu'elle a deja fouilles (ce qui y reste n'est pas pour elle).
        ObjectGuid lootTarget;
        uint32 lootTimer = 0;
        std::vector<ObjectGuid> lootTried;
        uint32 bagsFullTimer = 0;     // ms avant de redire « sacs pleins »
    };

    Config const& GetConfig();
    void LoadConfig();

    State& GetState(Player* player);
    void LoadState(Player* player);
    void SaveState(Player* player);
    void DeleteState(ObjectGuid::LowType guid);

    // LES SORTS DE MONTURE : ceux qui portent l'aura SPELL_AURA_MOUNTED.
    bool IsMountSpell(SpellInfo const* spellInfo);
    uint32 GetMountCreatureEntry(SpellInfo const* spellInfo);
    uint32 GetRiddenMountSpell(Player* player);

    Creature* GetCompanion(Player* player);

    // Les gestes du joueur.
    bool Summon(Player* player, uint32 mountSpell);
    void Dismiss(Player* player);
    bool Ride(Player* player, Creature* companion);
    void SetCommand(Player* player, Order order);
    void SetReact(Player* player, ReactStates react);
    bool OrderAttack(Player* player, Unit* target);

    // LE BUTIN (CompanionLoot.cpp).
    bool IsLootableCorpse(Player* player, Creature* creature);
    Creature* FindCorpseToLoot(Player* player, Creature* companion, State const& state);
    LootResult LootCorpse(Player* player, Creature* creature);
    // Appelee par l'IA arrivee au corps (ou qui y renonce).
    void OnLootReached(Player* player, Creature* corpse);

    // Les evenements.
    void Update(Player* player, uint32 diff);
    void OnCompanionDied(Player* owner);
    void OnLogout(Player* player);

    // Le nom d'un sort dans la langue du joueur.
    std::string SpellName(Player* player, uint32 spellId);

    // UN TEXTE DE module_string dans la langue du joueur, en message systeme.
    // Un texte absent de la base ne fait pas tomber le serveur : il se tait.
    template<typename... Args>
    void Say(ChatHandler* handler, uint32 id, Args&&... args)
    {
        if (handler->GetModuleString(MODULE, id))
            handler->PSendModuleSysMessage(MODULE, id, std::forward<Args>(args)...);
    }

    template<typename... Args>
    void Say(Player* player, uint32 id, Args&&... args)
    {
        ChatHandler handler(player->GetSession());
        Say(&handler, id, std::forward<Args>(args)...);
    }
}

#endif
