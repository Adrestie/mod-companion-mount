--[[
    This file is part of mod-companion-mount.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
]]

--[[----------------------------------------------------------------------------
    The companion mount, server side (ALE).

    THIS FILE DECIDES NOTHING. It relays every button of the bar to the
    module's `.companion` commands, RUN AS THE PLAYER -- every rule and every
    message lives in the C++ module -- and sends the state back: the module
    writes it synchronously, so the row read right after a command is what
    the command wrote.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local Handlers = AIO.AddHandlers("CompanionMount", {})

-- The orders the bar may give: the subcommands of `.companion`, nothing else.
local ORDERS = {
    summon = true, dismiss = true, attack = true,
    follow = true, stay = true,
    passive = true, defensive = true, aggressive = true,
}

local function State(player)
    local q = CharDBQuery(string.format(
        "SELECT c.mount_spell, c.summoned, c.command_state, c.react_state, m.level "
        .. "FROM mod_companion_mount_character c "
        .. "LEFT JOIN mod_companion_mount_mount m ON m.guid = c.guid AND m.mount_spell = c.mount_spell "
        .. "WHERE c.guid = %d", player:GetGUIDLow()))
    if not q then
        return { mount = 0, summoned = false, command = 0, react = 1, level = 0 }
    end
    return {
        mount = q:GetUInt32(0),
        summoned = q:GetUInt8(1) ~= 0,
        command = q:GetUInt8(2),
        react = q:GetUInt8(3),
        -- the level is written as it changes, a moment later: the bar shows
        -- it as of the last order or command
        level = q:IsNull(4) and 0 or q:GetUInt8(4),
    }
end

-- The client says hello once its side is loaded.
function Handlers.Hello(player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

-- A `.companion` typed in the chat changes the state too: the bar follows,
-- once the command has run (the event comes before it).
local PLAYER_EVENT_ON_COMMAND = 42

local function SendState(_, _, _, player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, function(_, player, command)
    if player and type(command) == "string" and command:lower():find("^%.?companion") then
        player:RegisterEvent(SendState, 100, 1)
    end
end)

-- The rename window: the name goes to `.companion rename`, which checks it
-- as a pet's name. Only printable characters, and no more than a name holds.
function Handlers.Rename(player, name)
    if type(name) ~= "string" then
        return
    end
    name = name:gsub("[%c|]", ""):sub(1, 48)
    player:RunCommand("companion rename " .. name)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

-- ---------------------------------------------------------------------------
-- The saddlebags. The C++ module moves the items (`.companion bag put|take`);
-- here only the client's numbering is translated, and the contents read back.
-- ---------------------------------------------------------------------------

local BAG_SLOTS = 16   -- CompanionMount.Bag.Slots

local function Bag(player)
    local items = {}
    local q = CharDBQuery(string.format(
        "SELECT ci.slot, ii.itemEntry, ii.count, ii.enchantments, ii.randomPropertyId "
        .. "FROM mod_companion_mount_item ci "
        .. "JOIN mod_companion_mount_character c ON c.guid = ci.guid AND c.mount_spell = ci.mount_spell "
        .. "JOIN item_instance ii ON ii.guid = ci.item_guid WHERE ci.guid = %d", player:GetGUIDLow()))
    if q then
        repeat
            local enchant = tonumber((q:GetString(3) or ""):match("^(%d+)")) or 0
            items[q:GetUInt32(0) + 1] = {
                entry = q:GetUInt32(1),
                count = q:GetUInt32(2),
                link = string.format("item:%d:%d:0:0:0:0:%d:0", q:GetUInt32(1), enchant, q:GetInt32(4)),
            }
        until not q:NextRow()
    end
    return items
end

local function SendBag(player)
    AIO.Handle(player, "CompanionMount", "Bag", Bag(player), BAG_SLOTS)
end

function Handlers.BagOpen(player)
    SendBag(player)
end

-- The client's bags: 0 the backpack (slots 1-16), 1-4 the bags. The server's:
-- 255 the backpack (slots 23-38), 19-22 the bags (slots from 0).
function Handlers.BagPut(player, bag, slot)
    bag, slot = tonumber(bag), tonumber(slot)
    if not bag or not slot or bag < 0 or bag > 4 or slot < 1 or slot > 36 then
        return
    end
    local serverBag, serverSlot
    if bag == 0 then
        serverBag, serverSlot = 255, 22 + slot
    else
        serverBag, serverSlot = 18 + bag, slot - 1
    end
    player:RunCommand(string.format("companion bag put %d %d", serverBag, serverSlot))
    SendBag(player)
end

function Handlers.BagTake(player, place)
    place = tonumber(place)
    if not place or place < 1 or place > 98 then
        return
    end
    player:RunCommand(string.format("companion bag take %d", place))
    SendBag(player)
end

function Handlers.Order(player, order)
    if type(order) ~= "string" or not ORDERS[order] then
        return
    end
    player:RunCommand("companion " .. order)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end
