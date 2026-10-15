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
 * mod-companion-mount — LE NOM DE LA MONTURE.
 *
 * Toutes les montures-compagnons partagent un modele (91000) : le client lit
 * le nom d'une creature dans son modele, le meme pour toutes. Un nom PROPRE
 * passe par le chemin des familiers : une creature qui porte un numero de
 * familier (UNIT_FIELD_PETNUMBER) voit son nom demande a part
 * (CMSG_PET_NAME_QUERY), et le coeur repond avec Creature::GetName() -- le
 * nom pose ici. L'horodatage (UNIT_FIELD_PET_NAME_TIMESTAMP) change a chaque
 * nom : le client redemande au lieu de garder l'ancien.
 *
 * Le nom suit les regles des noms de familiers (ObjectMgr::CheckPetName :
 * longueur, alphabet, noms reserves et grossiers), et un refus s'affiche avec
 * le message du jeu.
 */

#include "CompanionMount.h"

#include "Creature.h"
#include "GameTime.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "Util.h"
#include "WorldSession.h"

namespace CompanionMount
{
    namespace
    {
        // Un numero de familier qu'aucun vrai familier ne porte : le haut de
        // l'espace, le compteur de la creature et l'heure du nom.
        constexpr uint32 PETNUMBER_BASE = 0x7F000000;
    }

    void ApplyName(Creature* companion, State const& state)
    {
        if (state.name.empty())
        {
            companion->SetName(companion->GetCreatureTemplate()->Name);
            companion->SetUInt32Value(UNIT_FIELD_PETNUMBER, 0);
            return;
        }

        // Le numero change avec le nom (l'heure dans l'octet bas) : un client
        // qui garderait le nom en cache sous l'ancien numero le redemande.
        uint32 const now = uint32(GameTime::GetGameTime().count());
        companion->SetName(state.name);
        companion->SetUInt32Value(UNIT_FIELD_PETNUMBER,
            PETNUMBER_BASE | ((companion->GetGUID().GetCounter() & 0xFFFF) << 8) | (now & 0xFF));
        companion->SetUInt32Value(UNIT_FIELD_PET_NAME_TIMESTAMP, now);
    }

    bool Rename(Player* player, std::string name)
    {
        State& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(player, TEXT_NO_MOUNT);
            return false;
        }

        // UNE MAJUSCULE, le reste tel quel, comme le jeu ecrit les noms.
        std::wstring wname;
        if (!name.empty() && Utf8toWStr(name, wname) && !wname.empty())
        {
            wname[0] = wcharToUpper(wname[0]);
            WStrToUtf8(wname, name);
        }

        if (!name.empty())
        {
            PetNameInvalidReason const reason = ObjectMgr::CheckPetName(name);
            if (reason != PET_NAME_SUCCESS)
            {
                player->GetSession()->SendPetNameInvalid(reason, name, nullptr);
                return false;
            }
        }

        state.name = name;
        SaveMount(player, state);

        if (Creature* companion = GetCompanion(player))
            ApplyName(companion, state);

        if (name.empty())
            Say(player, TEXT_UNNAMED);
        else
            Say(player, TEXT_RENAMED, name);
        return true;
    }
}
