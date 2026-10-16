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

-- A TABLE THE SERVER DOES NOT HAVE YET STOPS IT: AzerothCore aborts on MySQL
-- error 1146 ("your database structure is not up to date"). These scripts may
-- be reloaded (.reload ale) ahead of the binary and the SQL that create the
-- module's newer tables: every such table is asked for first.
local known = {}
local function HasTable(query, name)
    if known[name] then return true end
    local q = query(string.format(
        "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = '%s'", name))
    known[name] = q ~= nil
    return known[name]
end
local function HasCharTable(name) return HasTable(CharDBQuery, name) end
local function HasWorldTable(name) return HasTable(WorldDBQuery, name) end

-- The same for a column a newer SQL file adds (MySQL error 1054 stops it too).
local function HasWorldColumn(tableName, column)
    local key = tableName .. "." .. column
    if known[key] then return true end
    local q = WorldDBQuery(string.format(
        "SELECT 1 FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() "
        .. "AND TABLE_NAME = '%s' AND COLUMN_NAME = '%s'", tableName, column))
    known[key] = q ~= nil
    return known[key]
end

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

local BAG_SLOTS = 50   -- CompanionMount.Bag.Slots

local function Bag(player)
    local items = {}
    if not HasCharTable("mod_companion_mount_bag") then
        return items
    end
    local q = CharDBQuery(string.format(
        "SELECT ci.slot, ii.itemEntry, ii.count, ii.enchantments, ii.randomPropertyId "
        .. "FROM mod_companion_mount_bag ci "
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

-- The module writes the saddlebags asynchronously, as the mail does: the
-- contents are read a moment after the command.
local function SendBagLater(player)
    player:RegisterEvent(function(_, _, _, p) SendBag(p) end, 500, 1)
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
    SendBagLater(player)
end

function Handlers.BagTake(player, place)
    place = tonumber(place)
    if not place or place < 1 or place > 98 then
        return
    end
    player:RunCommand(string.format("companion bag take %d", place))
    SendBagLater(player)
end

-- ---------------------------------------------------------------------------
-- The talents. The C++ module decides (`.companion talent learn|reset`); here
-- the catalogue, the ranks and the points are read for the window.
-- ---------------------------------------------------------------------------

-- CompanionMount.Talent.FirstLevel and LevelsPerPoint: the points of a level.
local TALENT_FIRST_LEVEL, TALENT_LEVELS_PER_POINT = 20, 4

local function TalentPoints(level)
    if level < TALENT_FIRST_LEVEL then return 0 end
    return 1 + math.floor((level - TALENT_FIRST_LEVEL) / TALENT_LEVELS_PER_POINT)
end

local catalogue
local function Catalogue()
    if catalogue then return catalogue end
    if not HasWorldTable("mod_companion_mount_talent") or not HasWorldColumn("mod_companion_mount_talent", "spell_5") then
        return {}
    end
    catalogue = {}
    local q = WorldDBQuery("SELECT id, tree, tier, col, spell_1, spell_2, spell_3, spell_4, spell_5 FROM mod_companion_mount_talent")
    if q then
        repeat
            local ranks = {}
            for i = 4, 8 do
                local spell = q:GetUInt32(i)
                if spell > 0 then ranks[#ranks + 1] = spell end
            end
            catalogue[#catalogue + 1] = {
                id = q:GetUInt32(0), tree = q:GetUInt8(1), tier = q:GetUInt8(2), col = q:GetUInt8(3),
                ranks = ranks, key = q:GetUInt32(4) == 0,
            }
        until not q:NextRow()
    end
    return catalogue
end

local function Talents(player)
    local guid = player:GetGUIDLow()
    local data = { talents = Catalogue(), ranks = {}, points = 0, keys = {}, level = 0 }
    if not HasCharTable("mod_companion_mount_talent_rank") or not HasWorldTable("mod_companion_mount_key_spell") then
        return data
    end
    local q = CharDBQuery(string.format(
        "SELECT c.mount_spell, IFNULL(m.level, 1) FROM mod_companion_mount_character c "
        .. "LEFT JOIN mod_companion_mount_mount m ON m.guid = c.guid AND m.mount_spell = c.mount_spell "
        .. "WHERE c.guid = %d", guid))
    if not q or q:GetUInt32(0) == 0 then
        return data
    end
    local mount = q:GetUInt32(0)
    data.level = math.min(q:GetUInt32(1), player:GetLevel())
    data.points = TalentPoints(data.level)
    local r = CharDBQuery(string.format(
        "SELECT talent_id, `rank` FROM mod_companion_mount_talent_rank WHERE guid = %d AND mount_spell = %d AND `rank` > 0",
        guid, mount))
    if r then
        repeat
            data.ranks[r:GetUInt32(0)] = r:GetUInt8(1)
        until not r:NextRow()
    end
    -- The key spell of each tree, for this kind of mount (a horse if unknown).
    local kq = WorldDBQuery(string.format("SELECT kind FROM mod_companion_mount_kind WHERE mount_spell = %d", mount))
    local kind = kq and kq:GetUInt8(0) or 1
    local k = WorldDBQuery(string.format(
        "SELECT tree, key_spell FROM mod_companion_mount_key_spell WHERE kind = %d", kind))
    if k then
        repeat
            data.keys[k:GetUInt8(0)] = k:GetUInt32(1)
        until not k:NextRow()
    end
    return data
end

local function SendTalents(player)
    AIO.Handle(player, "CompanionMount", "Talents", Talents(player))
end

function Handlers.TalentOpen(player)
    SendTalents(player)
end

function Handlers.TalentLearn(player, id)
    id = tonumber(id)
    if not id then return end
    player:RunCommand(string.format("companion talent learn %d", id))
    SendTalents(player)
end

function Handlers.TalentReset(player)
    player:RunCommand("companion talent reset")
    SendTalents(player)
end

function Handlers.Order(player, order)
    if type(order) ~= "string" or not ORDERS[order] then
        return
    end
    player:RunCommand("companion " .. order)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end
