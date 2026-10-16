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
 * mod-companion-mount — LES SACOCHES DE LA MONTURE.
 *
 * Chaque monture a ses sacoches : un nombre de places (16 par defaut), propre
 * a chaque personnage et chaque sort de monture (mod_companion_mount_item).
 *
 * L'OBJET RESTE UN OBJET. Comme le courrier du coeur : il quitte l'inventaire
 * du joueur (Player::MoveItemFromInventory), sa ligne de character_inventory
 * disparait, et la ligne d'item_instance demeure -- enchantements, gemmes,
 * durabilite, liaison, tout est garde. Les sacoches ne notent que le lien
 * place -> item_instance. Pour le reprendre, l'objet est recharge depuis
 * item_instance (Item::LoadFromDB) et range dans les sacs, comme une piece
 * jointe qu'on prend.
 *
 * Les ecritures sont IMMEDIATES (DirectCommitTransaction) : la fenetre (ALE)
 * relit les sacoches juste apres la commande.
 */

#include "CompanionMount.h"

#include "Bag.h"
#include "DatabaseEnv.h"
#include "Item.h"
#include "ObjectMgr.h"
#include "Player.h"

namespace CompanionMount
{
    namespace
    {
        // Les colonnes qu'Item::LoadFromDB attend (0-10), puis les notres.
        constexpr char const* SELECT_ITEMS =
            "SELECT ii.creatorGuid, ii.giftCreatorGuid, ii.count, ii.duration, ii.charges, ii.flags, ii.enchantments, "
            "ii.randomPropertyId, ii.durability, ii.playedTime, ii.text, ci.slot, ii.itemEntry, ii.guid "
            "FROM mod_companion_mount_item ci JOIN item_instance ii ON ii.guid = ci.item_guid "
            "WHERE ci.guid = {} AND ci.mount_spell = {}";

        bool CanUseBag(Player* player, State const& state)
        {
            if (!state.mountSpell)
            {
                Say(player, TEXT_NO_MOUNT);
                return false;
            }
            // Les sacoches sont sur la bete : il faut qu'elle soit la.
            if (GetConfig().bagRequiresOut && !GetCompanion(player))
            {
                Say(player, TEXT_NOT_OUT);
                return false;
            }
            return true;
        }

        int32 FreeSlot(Player* player, State const& state)
        {
            std::vector<bool> used(GetConfig().bagSlots, false);
            if (QueryResult result = CharacterDatabase.Query(
                    "SELECT `slot` FROM `mod_companion_mount_item` WHERE `guid` = {} AND `mount_spell` = {}",
                    player->GetGUID().GetCounter(), state.mountSpell))
            {
                do
                {
                    uint32 const slot = result->Fetch()[0].Get<uint32>();
                    if (slot < used.size())
                        used[slot] = true;
                } while (result->NextRow());
            }
            for (size_t slot = 0; slot < used.size(); ++slot)
                if (!used[slot])
                    return int32(slot);
            return -1;
        }
    }

    bool BagDeposit(Player* player, uint8 bag, uint8 slot)
    {
        State& state = GetState(player);
        if (!CanUseBag(player, state))
            return false;

        Item* item = player->GetItemByPos(bag, slot);
        if (!item || !player->IsInventoryPos(bag, slot))
        {
            Say(player, TEXT_BAG_REFUSED);
            return false;
        }

        // Ce que le courrier refuse aussi : un sac plein, un objet qui
        // s'evapore (invoque, a duree), un objet en cours d'echange.
        ItemTemplate const* proto = item->GetTemplate();
        if (item->IsNotEmptyBag() || item->IsInTrade() || proto->HasFlag(ITEM_FLAG_CONJURED)
            || item->GetUInt32Value(ITEM_FIELD_DURATION))
        {
            Say(player, TEXT_BAG_REFUSED);
            return false;
        }

        int32 const free = FreeSlot(player, state);
        if (free < 0)
        {
            Say(player, TEXT_BAG_FULL);
            return false;
        }

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        player->MoveItemFromInventory(bag, slot, true);
        item->DeleteFromInventoryDB(trans);
        item->FSetState(ITEM_CHANGED);
        item->SaveToDB(trans);
        trans->Append("INSERT INTO `mod_companion_mount_item` (`guid`, `mount_spell`, `slot`, `item_guid`) VALUES ({}, {}, {}, {})",
            player->GetGUID().GetCounter(), state.mountSpell, free, item->GetGUID().GetCounter());
        player->SaveInventoryAndGoldToDB(trans);
        CharacterDatabase.DirectCommitTransaction(trans);

        // L'objet vit desormais en base seulement, comme une piece jointe.
        delete item;
        return true;
    }

    bool BagWithdraw(Player* player, uint32 bagSlot)
    {
        State& state = GetState(player);
        if (!CanUseBag(player, state))
            return false;

        QueryResult result = CharacterDatabase.Query(std::string(SELECT_ITEMS) + " AND ci.slot = {}",
            player->GetGUID().GetCounter(), state.mountSpell, bagSlot);
        if (!result)
            return false;

        Field* fields = result->Fetch();
        uint32 const entry = fields[12].Get<uint32>();
        ObjectGuid::LowType const itemGuid = fields[13].Get<uint32>();
        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(entry);
        if (!proto)
            return false;

        Item* item = NewItemOrBag(proto);
        if (!item->LoadFromDB(itemGuid, player->GetGUID(), fields, entry))
        {
            delete item;
            return false;
        }

        ItemPosCountVec dest;
        InventoryResult const msg = player->CanStoreItem(NULL_BAG, NULL_SLOT, dest, item, false);
        if (msg != EQUIP_ERR_OK)
        {
            player->SendEquipError(msg, item, nullptr);
            delete item;
            return false;
        }

        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        trans->Append("DELETE FROM `mod_companion_mount_item` WHERE `guid` = {} AND `mount_spell` = {} AND `slot` = {}",
            player->GetGUID().GetCounter(), state.mountSpell, bagSlot);
        item->SetState(ITEM_UNCHANGED);   // comme une piece jointe prise
        player->MoveItemToInventory(dest, item, true);
        player->SaveInventoryAndGoldToDB(trans);
        CharacterDatabase.DirectCommitTransaction(trans);
        return true;
    }

    void BagList(ChatHandler* handler, Player* player)
    {
        State const& state = GetState(player);
        if (!state.mountSpell)
        {
            Say(handler, TEXT_NO_MOUNT);
            return;
        }

        uint32 count = 0;
        if (QueryResult result = CharacterDatabase.Query(SELECT_ITEMS, player->GetGUID().GetCounter(), state.mountSpell))
        {
            do
            {
                Field* fields = result->Fetch();
                ++count;
                ItemTemplate const* proto = sObjectMgr->GetItemTemplate(fields[12].Get<uint32>());
                Say(handler, TEXT_BAG_LINE, fields[11].Get<uint32>() + 1,
                    proto ? proto->Name1 : std::to_string(fields[12].Get<uint32>()), fields[2].Get<uint32>());
            } while (result->NextRow());
        }
        Say(handler, TEXT_BAG_HEADER, count, GetConfig().bagSlots);
    }

    void BagDeleteAll(ObjectGuid::LowType guid)
    {
        CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();
        trans->Append("DELETE ii FROM item_instance ii JOIN mod_companion_mount_item ci ON ci.item_guid = ii.guid WHERE ci.guid = {}", guid);
        trans->Append("DELETE FROM mod_companion_mount_item WHERE guid = {}", guid);
        CharacterDatabase.CommitTransaction(trans);
    }
}
