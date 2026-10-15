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
    };

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
