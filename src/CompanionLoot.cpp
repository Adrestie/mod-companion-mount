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
 * mod-companion-mount — LA BETE RAMASSE LE BUTIN, COMME LE JOUEUR.
 *
 * Hors combat, elle va au corps le plus proche que son maitre a le droit de
 * fouiller, et le butin passe dans les sacs du maitre par les chemins du
 * coeur : Player::StoreLootItem pour les objets (regles des objets de quete,
 * des objets « chacun le sien », des conditions, hauts faits, message « vous
 * recevez »), et le partage de l'argent avec le groupe tel que
 * WorldSession::HandleLootMoneyOpcode le fait.
 *
 * Elle ne prend QUE ce que la fenetre de butin du joueur lui laisserait
 * prendre (les regles de LootView) : rien de ce qui est en jet de des, reserve
 * au maitre du butin ou au tour de role d'un autre. Ce qui reste reste sur le
 * corps, et le joueur peut toujours le fouiller lui-meme.
 *
 * COMME AVEC mod-aoe-loot : quand ce module est la, le joueur qui ouvre un
 * corps ramasse aussi celui des corps autour. La bete fait de meme : arrivee a
 * un corps, elle fouille aussi les autres corps a portee, avec les reglages de
 * mod-aoe-loot (AoeLoot.Enable, Range, MaxCorpses, LineOfSight) lus dans sa
 * configuration -- mesures depuis la bete, qui se tient au corps comme le
 * joueur s'y tiendrait. Sans mod-aoe-loot, un corps a la fois.
 *
 * PAS DE DOUBLON AVEC mod-aoe-loot : le butin est pris dans le meme objet
 * `creature->loot` que tout le monde -- ce qui est pris n'y est plus. Et la
 * bete ne touche a rien tant que le joueur a une fenetre de butin ouverte :
 * celle de mod-aoe-loot peut couvrir plusieurs corps a la fois.
 *
 * Les gestes du coeur sur un corps sont repris de mod-aoe-loot, qui les fait
 * deja pour les corps voisins de celui qu'on clique : l'ouverture (les jets du
 * groupe commencent a la premiere) et la fermeture (corps vide : il n'est plus
 * fouillable, et devient depecable).
 */

#include "CompanionMount.h"

#include "CellImpl.h"
#include "Config.h"
#include "Creature.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "Group.h"
#include "LootMgr.h"
#include "Opcodes.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WorldPacket.h"

#include <algorithm>

namespace CompanionMount
{
    namespace
    {
        // Les droits du joueur sur le butin d'une creature : ce que
        // Player::SendLoot calcule pour un corps (repris de mod-aoe-loot).
        PermissionTypes PermissionFor(Player* player, Creature* creature)
        {
            if (Group* recipientGroup = creature->GetLootRecipientGroup())
            {
                if (player->GetGroup() != recipientGroup)
                    return NONE_PERMISSION;

                switch (recipientGroup->GetLootMethod())
                {
                    case MASTER_LOOT:
                        return recipientGroup->GetMasterLooterGuid() == player->GetGUID() ? MASTER_PERMISSION : RESTRICTED_PERMISSION;
                    case FREE_FOR_ALL:
                        return ALL_PERMISSION;
                    case ROUND_ROBIN:
                        return ROUND_ROBIN_PERMISSION;
                    default:
                        return GROUP_PERMISSION;
                }
            }

            return creature->GetLootRecipientGUID() == player->GetGUID() ? OWNER_PERMISSION : NONE_PERMISSION;
        }

        // Ce que la ligne `slot` de la fenetre du joueur lui laisserait prendre :
        // les regles de LootView (LootMgr.cpp), objet par objet.
        bool MayTake(Player* player, Loot& loot, uint8 slot, PermissionTypes permission)
        {
            QuestItem* qitem = nullptr;
            QuestItem* ffaitem = nullptr;
            QuestItem* conditem = nullptr;
            LootItem* item = loot.LootItemInSlot(slot, player, &qitem, &ffaitem, &conditem);
            if (!item)
                return false;

            // Objet de quete, « chacun le sien », sous condition : la liste est
            // celle du joueur, LootItemInSlot a deja dit s'il l'a pris.
            if (qitem)
                return !qitem->is_looted;
            if (ffaitem)
                return !ffaitem->is_looted;
            if (conditem)
                return !conditem->is_looted && !item->is_looted;

            if (item->is_looted || item->freeforall || !item->conditions.empty())
                return false;
            if (!item->AllowedForPlayer(player, loot.sourceWorldObjectGUID))
                return false;
            if (item->rollWinnerGUID && item->rollWinnerGUID != player->GetGUID())
                return false;

            bool const othersTurn = loot.roundRobinPlayer && loot.roundRobinPlayer != player->GetGUID();
            switch (permission)
            {
                case ALL_PERMISSION:
                case OWNER_PERMISSION:
                    return true;
                case ROUND_ROBIN_PERMISSION:
                    return !othersTurn;
                case GROUP_PERMISSION:
                case MASTER_PERMISSION:
                case RESTRICTED_PERMISSION:
                    // en jet de des, ou au maitre du butin : pas pour la bete
                    return !item->is_blocked && (!othersTurn || !item->is_underthreshold);
                default:
                    return false;
            }
        }

        // La premiere ouverture d'un corps : les jets du groupe commencent, ou
        // le maitre du butin recoit la liste (Player::SendLoot, repris de
        // mod-aoe-loot).
        void OpenCorpse(Player* player, Creature* creature)
        {
            Loot& loot = creature->loot;

            if (loot.loot_type == LOOT_NONE)
            {
                if (Group* recipientGroup = creature->GetLootRecipientGroup())
                {
                    switch (recipientGroup->GetLootMethod())
                    {
                        case GROUP_LOOT:
                            recipientGroup->GroupLoot(&loot, creature);
                            break;
                        case NEED_BEFORE_GREED:
                            recipientGroup->NeedBeforeGreed(&loot, creature);
                            break;
                        case MASTER_LOOT:
                            recipientGroup->MasterLoot(&loot, creature);
                            break;
                        default:
                            break;
                    }
                }
            }

            loot.loot_type = LOOT_CORPSE;

            sScriptMgr->OnPlayerBeforeSendLoot(player, creature->GetGUID(), &loot);
        }

        // L'argent : ce que WorldSession::HandleLootMoneyOpcode paie pour un
        // corps -- partage entre les membres du groupe proches du joueur.
        void TakeMoney(Player* player, Loot& loot)
        {
            if (!loot.gold || player->HasPlayerFlag(PLAYER_FLAGS_NO_PLAY_TIME))
                return;

            sScriptMgr->OnPlayerBeforeLootMoney(player, &loot);
            loot.NotifyMoneyRemoved();

            if (Group* group = player->GetGroup())
            {
                std::vector<Player*> playersNear;
                for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
                {
                    Player* member = itr->GetSource();
                    if (member && player->IsAtLootRewardDistance(member))
                        playersNear.push_back(member);
                }

                uint32 const goldPerPlayer = playersNear.empty() ? 0 : uint32(loot.gold / playersNear.size());

                for (Player* member : playersNear)
                {
                    uint32 finalGold = goldPerPlayer;
                    if (member->HasPlayerFlag(PLAYER_FLAGS_NO_PLAY_TIME))
                        continue;
                    if (member->HasPlayerFlag(PLAYER_FLAGS_PARTIAL_PLAY_TIME))
                    {
                        finalGold /= 2;
                        if (!finalGold)
                            continue;
                    }

                    member->ModifyMoney(finalGold);
                    member->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, finalGold);

                    WorldPacket data(SMSG_LOOT_MONEY_NOTIFY, 4 + 1);
                    data << uint32(finalGold);
                    data << uint8(playersNear.size() > 1 ? 0 : 1);     // 0 « votre part », 1 « vous ramassez »
                    member->SendDirectMessage(&data);
                }
            }
            else
            {
                uint32 finalGold = loot.gold;
                if (player->HasPlayerFlag(PLAYER_FLAGS_PARTIAL_PLAY_TIME))
                    finalGold /= 2;

                sScriptMgr->OnPlayerAfterCreatureLootMoney(player);

                if (finalGold)
                {
                    player->ModifyMoney(finalGold);
                    player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, finalGold);

                    WorldPacket data(SMSG_LOOT_MONEY_NOTIFY, 4 + 1);
                    data << uint32(finalGold);
                    data << uint8(1);
                    player->SendDirectMessage(&data);
                }
            }

            sScriptMgr->OnLootMoney(player, loot.gold);
            loot.gold = 0;
        }

        // La fermeture : vide, le corps n'est plus fouillable (et devient
        // depecable) ; sinon le tour de role du joueur se libere.
        void CloseCorpse(Player* player, Creature* creature)
        {
            Loot& loot = creature->loot;

            if (loot.isLooted())
            {
                creature->AllLootRemovedFromCorpse();
                creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
                loot.clear();
                return;
            }

            if (player->GetGUID() == loot.roundRobinPlayer)
            {
                loot.roundRobinPlayer.Clear();
                if (Group* group = player->GetGroup())
                    group->SendLooter(creature, nullptr);
            }

            creature->ForceValuesUpdateAtIndex(UNIT_DYNAMIC_FLAGS);
        }

        class LootableCorpseCheck
        {
        public:
            LootableCorpseCheck(Player* player, Creature* companion, State const& state, float range)
                : _player(player), _companion(companion), _state(state), _range(range) { }

            bool operator()(Creature* creature) const
            {
                if (creature == _companion || !_player->IsWithinDistInMap(creature, _range))
                    return false;
                if (std::find(_state.lootTried.begin(), _state.lootTried.end(), creature->GetGUID()) != _state.lootTried.end())
                    return false;
                if (!IsLootableCorpse(_player, creature))
                    return false;
                return _companion->IsWithinLOSInMap(creature);
            }

        private:
            Player* _player;
            Creature* _companion;
            State const& _state;
            float _range;
        };
    }

    // Un corps que le joueur pourrait fouiller lui-meme : mort, encore
    // fouillable, un butin de corps (ni depecage ni vol a la tire), et a lui
    // -- tue par lui, ou par son groupe.
    bool IsLootableCorpse(Player* player, Creature* creature)
    {
        if (creature->IsAlive() || !creature->HasDynamicFlag(UNIT_DYNFLAG_LOOTABLE))
            return false;

        LootType const lootType = creature->loot.loot_type;
        if (lootType != LOOT_NONE && lootType != LOOT_CORPSE)
            return false;

        if (creature->loot.isLooted())
            return false;

        if (PermissionFor(player, creature) == NONE_PERMISSION)
            return false;

        return sScriptMgr->OnAllowedToLootContainerCheck(player, creature->GetGUID());
    }

    std::vector<Creature*> FindAreaCorpses(Player* player, Creature* companion, Creature* reached)
    {
        std::vector<Creature*> corpses{ reached };

        // Les reglages de mod-aoe-loot, s'il est la (sans bruit sinon).
        if (!sConfigMgr->GetOption<bool>("AoeLoot.Enable", false, false))
            return corpses;
        float const range = std::clamp(sConfigMgr->GetOption<float>("AoeLoot.Range", 30.0f, false), 5.0f, 100.0f);
        uint32 const maxCorpses = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("AoeLoot.MaxCorpses", 15, false), 1, 50);
        bool const lineOfSight = sConfigMgr->GetOption<bool>("AoeLoot.LineOfSight", true, false);

        std::list<Creature*> found;
        auto check = [&](Creature* creature)
        {
            return creature != reached && creature != companion && companion->IsWithinDistInMap(creature, range)
                && IsLootableCorpse(player, creature) && (!lineOfSight || companion->IsWithinLOSInMap(creature));
        };
        Acore::CreatureListSearcher<decltype(check)> searcher(companion, found, check);
        Cell::VisitObjects(companion, searcher, range);

        std::vector<Creature*> others(found.begin(), found.end());
        std::sort(others.begin(), others.end(), [companion](Creature* a, Creature* b)
        {
            return companion->GetExactDist2dSq(a) < companion->GetExactDist2dSq(b);
        });
        // le corps atteint compte dans la limite, comme celui que le joueur clique
        if (others.size() > maxCorpses - 1)
            others.resize(maxCorpses - 1);

        corpses.insert(corpses.end(), others.begin(), others.end());
        return corpses;
    }

    Creature* FindCorpseToLoot(Player* player, Creature* companion, State const& state)
    {
        float const range = GetConfig().lootRange;

        Creature* nearest = nullptr;
        std::list<Creature*> found;
        LootableCorpseCheck check(player, companion, state, range);
        Acore::CreatureListSearcher<LootableCorpseCheck> searcher(player, found, check);
        Cell::VisitObjects(player, searcher, range);

        for (Creature* corpse : found)
            if (!nearest || companion->GetExactDist2dSq(corpse) < companion->GetExactDist2dSq(nearest))
                nearest = corpse;
        return nearest;
    }

    LootResult LootCorpse(Player* player, Creature* creature)
    {
        // Une fenetre de butin ouverte (celle du jeu ou de mod-aoe-loot) : la
        // bete attend, elle ne prend rien sous les yeux du joueur.
        if (player->GetLootGUID() || !IsLootableCorpse(player, creature))
            return LOOT_RESULT_NOTHING;

        if (player->HasPlayerFlag(PLAYER_FLAGS_NO_PLAY_TIME))
            return LOOT_RESULT_NOTHING;

        PermissionTypes const permission = PermissionFor(player, creature);
        OpenCorpse(player, creature);

        Loot& loot = creature->loot;
        LootResult result = LOOT_RESULT_DONE;

        // Les lignes de la fenetre : les objets communs, puis ceux de quete du
        // joueur.
        size_t slots = loot.items.size();
        QuestItemMap const& questItems = loot.GetPlayerQuestItems();
        auto mine = questItems.find(player->GetGUID());
        if (mine != questItems.end())
            slots += mine->second->size();

        for (size_t slot = 0; slot < slots && slot < 256; ++slot)
        {
            uint8 const lootSlot = uint8(slot);
            if (!MayTake(player, loot, lootSlot, permission))
                continue;

            // Les sacs d'abord : sans place, l'objet reste sur le corps, sans
            // le message d'erreur du coeur a chaque passage.
            LootItem* item = loot.LootItemInSlot(lootSlot, player);
            ItemPosCountVec dest;
            if (!item || player->CanStoreNewItem(NULL_BAG, NULL_SLOT, dest, item->itemid, item->count) != EQUIP_ERR_OK)
            {
                result = LOOT_RESULT_BAGS_FULL;
                continue;
            }

            sScriptMgr->OnPlayerAfterCreatureLoot(player);
            InventoryResult msg;
            player->StoreLootItem(lootSlot, &loot, msg);
        }

        TakeMoney(player, loot);
        CloseCorpse(player, creature);
        return result;
    }
}
