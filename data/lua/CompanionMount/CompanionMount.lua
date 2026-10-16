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

-- The orders the interface may give: the subcommands of `.companion`, nothing else.
local ORDERS = {
    summon = true, dismiss = true, attack = true,
    follow = true, stay = true,
    passive = true, defensive = true, aggressive = true,
}

-- The spells the mount learned, for the bar (defined with the talents below).
local Spells

local function State(player)
    local q = CharDBQuery(string.format(
        "SELECT c.mount_spell, c.summoned, c.command_state, c.react_state, m.level "
        .. "FROM mod_companion_mount_character c "
        .. "LEFT JOIN mod_companion_mount_mount m ON m.guid = c.guid AND m.mount_spell = c.mount_spell "
        .. "WHERE c.guid = %d", player:GetGUIDLow()))
    if not q then
        return { mount = 0, summoned = false, command = 0, react = 1, level = 0, spells = {} }
    end
    return {
        spells = Spells(player),
        mount = q:GetUInt32(0),
        summoned = q:GetUInt8(1) ~= 0,
        command = q:GetUInt8(2),
        react = q:GetUInt8(3),
        -- the level is written as it changes, a moment later: the interface
        -- shows it as of the last order or command
        level = q:IsNull(4) and 0 or q:GetUInt8(4),
    }
end

-- The client says hello once its side is loaded.
function Handlers.Hello(player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
    player:RunCommand("companion frame")
end

-- A `.companion` typed in the chat changes the state too: the sheet follows,
-- once the command has run (the event comes before it). Not for
-- `.companion snapshot`, which the sheet itself runs every few seconds.
local PLAYER_EVENT_ON_COMMAND = 42

local function SendState(_, _, _, player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, function(_, player, command)
    if player and type(command) == "string" and command:lower():find("^%.?companion")
        and not command:lower():find("snapshot", 1, true) then
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
    Handlers.SheetOpen(player)   -- defined below: read when the name changes
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

-- CompanionMount.Talent.FirstLevel, LevelsPerPoint and PointsPerTier: the
-- points of a level and the cost of a row (the module's configuration, mirrored).
local TALENT_FIRST_LEVEL, TALENT_LEVELS_PER_POINT, TALENT_POINTS_PER_TIER = 4, 2, 5
local TALENT_ONE_TREE = false   -- CompanionMount.Talent.OneTree

local function TalentPoints(level)
    if level < TALENT_FIRST_LEVEL then return 0 end
    return 1 + math.floor((level - TALENT_FIRST_LEVEL) / TALENT_LEVELS_PER_POINT)
end

-- Read at each opening: `.companion reload` changes it without a restart.
local function Catalogue()
    if not HasWorldTable("mod_companion_mount_talent") or not HasWorldColumn("mod_companion_mount_talent", "spell_5") then
        return {}
    end
    local catalogue = {}
    local hasEnergy = HasWorldColumn("mod_companion_mount_talent", "energy")
    local q = WorldDBQuery("SELECT `id`, `tree`, `tier`, `col`, `spell_1`, `spell_2`, `spell_3`, `spell_4`, `spell_5`, `use`, "
        .. (hasEnergy and "`energy`" or "0") .. " FROM `mod_companion_mount_talent`")
    if q then
        repeat
            local ranks = {}
            for i = 4, 8 do
                local spell = q:GetUInt32(i)
                if spell > 0 then ranks[#ranks + 1] = spell end
            end
            catalogue[#catalogue + 1] = {
                id = q:GetUInt32(0), tree = q:GetUInt8(1), tier = q:GetUInt8(2), col = q:GetUInt8(3),
                ranks = ranks, key = q:GetUInt32(4) == 0, active = q:GetUInt8(9) ~= 0 and q:GetUInt8(9) ~= 6,
                energy = q:GetUInt32(10),
            }
        until not q:NextRow()
    end
    return catalogue
end

-- The rank of a spell the mount casts at its level (the module writes the
-- ranks and their levels at startup): the tooltip shows what it casts.
local function RankForLevel(spell, level)
    if not HasWorldTable("mod_companion_mount_rank_level") then return spell end
    local q = WorldDBQuery(string.format(
        "SELECT r.`spell` FROM `mod_companion_mount_rank_level` r "
        .. "JOIN `mod_companion_mount_rank_level` s ON s.`first_spell` = r.`first_spell` AND s.`spell` = %d "
        .. "WHERE r.`level` <= %d ORDER BY r.`level` DESC, r.`spell` DESC LIMIT 1", spell, level))
    return q and q:GetUInt32(0) or spell
end

local function Talents(player)
    local guid = player:GetGUIDLow()
    local data = { talents = Catalogue(), ranks = {}, points = 0, keys = {}, level = 0, perTier = TALENT_POINTS_PER_TIER,
        oneTree = TALENT_ONE_TREE }
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
            data.keys[k:GetUInt8(0)] = RankForLevel(k:GetUInt32(1), data.level)
        until not k:NextRow()
    end
    -- An active talent shows the rank its mount casts, not the first.
    for _, t in ipairs(data.talents) do
        if t.active and #t.ranks == 1 then
            t.ranks = { RankForLevel(t.ranks[1], data.level) }
        end
    end
    return data
end

local function SendTalents(player)
    AIO.Handle(player, "CompanionMount", "Talents", Talents(player))
end

-- CompanionMount.Energy.Cost.*, by class: quick, strong or area, defensive or
-- control, key spell, ultimate (the module's configuration, mirrored).
local ENERGY_COSTS = { [0] = 25, [1] = 40, [2] = 50, [3] = 60, [4] = 80 }
local ENERGY_KEY = 3

-- THE SPELL BAR: the spells the mount learned (its active talents and its key
-- spell), at the rank it casts, in the order of the trees; `auto` is false
-- for those whose automatic casting the player cut.
Spells = function(player)
    local data = Talents(player)
    local off = {}
    if HasCharTable("mod_companion_mount_autocast") and HasWorldTable("mod_companion_mount_rank_level") then
        local q = CharDBQuery(string.format(
            "SELECT a.`spell` FROM `mod_companion_mount_autocast` a "
            .. "JOIN `mod_companion_mount_character` c ON c.`guid` = a.`guid` AND c.`mount_spell` = a.`mount_spell` "
            .. "WHERE a.`guid` = %d", player:GetGUIDLow()))
        if q then
            repeat
                local first = q:GetUInt32(0)
                off[first] = true
                local r = WorldDBQuery(string.format(
                    "SELECT `spell` FROM `mod_companion_mount_rank_level` WHERE `first_spell` = %d", first))
                if r then
                    repeat off[r:GetUInt32(0)] = true until not r:NextRow()
                end
            until not q:NextRow()
        end
    end

    local learned = {}
    for _, t in ipairs(data.talents) do
        local rank = data.ranks[t.id] or 0
        if rank > 0 and (t.key or t.active) then
            local spell = t.key and data.keys[t.tree] or t.ranks[math.min(rank, #t.ranks)]
            if spell then
                local class = t.key and ENERGY_KEY or (t.energy or 0)
                learned[#learned + 1] = { spell = spell, order = t.tree * 100 + t.tier * 10 + t.col,
                    cost = ENERGY_COSTS[class] or 0 }
            end
        end
    end
    table.sort(learned, function(a, b) return a.order < b.order end)

    local spells = {}
    for _, l in ipairs(learned) do
        spells[#spells + 1] = { spell = l.spell, auto = not off[l.spell], cost = l.cost }
    end
    return spells
end

-- ---------------------------------------------------------------------------
-- The gambits. The C++ module plays them and keeps them (`.companion gambit
-- save|reset`); here the list of the chosen mount is read for the window.
-- ---------------------------------------------------------------------------

-- CompanionMount.Gambit.FirstSlots and MaxSlots (mirrored): 3 at level 1, 10 at 80.
local GAMBIT_FIRST, GAMBIT_MAX = 3, 10

local function GambitSlots(level)
    level = math.max(1, math.min(level, 80))
    return GAMBIT_FIRST + math.floor((GAMBIT_MAX - GAMBIT_FIRST) * (level - 1) / 79)
end

local function Gambits(player)
    local data = { rows = {}, slots = GAMBIT_FIRST, max = GAMBIT_MAX, unlock = {}, custom = false, spells = {} }
    for slot = 0, GAMBIT_MAX - 1 do
        for level = 1, 80 do
            if GambitSlots(level) > slot then data.unlock[slot + 1] = level break end
        end
    end
    local state = State(player)
    data.spells = state.spells or {}
    data.slots = GambitSlots(math.max(state.level or 1, 1))
    data.mount = state.mount
    if not HasCharTable("mod_companion_mount_gambit") or (state.mount or 0) == 0 then
        return data
    end
    local q = CharDBQuery(string.format(
        "SELECT `enabled`, `cond`, `action`, `custom` FROM `mod_companion_mount_gambit` "
        .. "WHERE `guid` = %d AND `mount_spell` = %d ORDER BY `slot`", player:GetGUIDLow(), state.mount))
    if q then
        repeat
            data.rows[#data.rows + 1] = { enabled = q:GetUInt8(0) ~= 0, cond = q:GetUInt32(1), action = q:GetInt32(2) }
            if q:GetUInt8(3) ~= 0 then data.custom = true end
        until not q:NextRow()
    end
    return data
end

local function SendGambits(player)
    AIO.Handle(player, "CompanionMount", "Gambits", Gambits(player))
end

function Handlers.GambitOpen(player)
    SendGambits(player)
end

-- The whole list, as the window has it: "enabled:condition:action", comma separated.
function Handlers.GambitSave(player, rows)
    if type(rows) ~= "table" then return end
    local parts = {}
    for i = 1, math.min(#rows, GAMBIT_MAX) do
        local r = rows[i]
        local cond, action = tonumber(type(r) == "table" and r.cond), tonumber(type(r) == "table" and r.action)
        if not cond or not action then return end
        parts[#parts + 1] = string.format("%d:%d:%d", r.enabled and 1 or 0, cond, action)
    end
    player:RunCommand("companion gambit save " .. table.concat(parts, ","))
    SendGambits(player)
end

function Handlers.GambitReset(player)
    player:RunCommand("companion gambit reset")
    SendGambits(player)
end

-- A click on a spell of the bar: cast by hand. A right click: its automatic
-- casting cut, or given back.
function Handlers.Cast(player, spell)
    spell = tonumber(spell)
    if not spell then return end
    player:RunCommand(string.format("companion cast %d", spell))
end

function Handlers.Autocast(player, spell)
    spell = tonumber(spell)
    if not spell then return end
    player:RunCommand(string.format("companion autocast %d", spell))
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

function Handlers.TalentOpen(player)
    SendTalents(player)
end

function Handlers.TalentLearn(player, id)
    id = tonumber(id)
    if not id then return end
    player:RunCommand(string.format("companion talent learn %d", id))
    SendTalents(player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

function Handlers.TalentReset(player)
    player:RunCommand("companion talent reset")
    SendTalents(player)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end

-- ---------------------------------------------------------------------------
-- The sheet. ALE cannot read a creature's armor, damage or chances: the module
-- writes them (`.companion snapshot`, a direct write) and they are read back.
-- ---------------------------------------------------------------------------

local SHEET_COLUMNS = {
    "mount_spell", "name", "kind", "creature", "display", "level", "xp", "xp_next", "out", "health", "max_health", "armor",
    "attack_power", "min_damage", "max_damage", "attack_time", "crit", "dodge", "parry", "tree",
    "points_spent", "points_total", "command_state", "react_state",
}

local function Sheet(player)
    if not HasCharTable("mod_companion_mount_snapshot") then
        return {}
    end
    player:RunCommand("companion snapshot")
    -- Every column between backquotes: `out` is a reserved word of MySQL 8,
    -- and a syntax error stops the server (error 1064).
    local q = CharDBQuery(string.format("SELECT `%s` FROM mod_companion_mount_snapshot WHERE guid = %d",
        table.concat(SHEET_COLUMNS, "`, `"), player:GetGUIDLow()))
    local sheet = {}
    if q then
        for i, column in ipairs(SHEET_COLUMNS) do
            if column == "name" then
                sheet[column] = q:GetString(i - 1)
            elseif column == "crit" or column == "dodge" or column == "parry" then
                sheet[column] = q:GetFloat(i - 1)
            else
                sheet[column] = q:GetUInt32(i - 1)
            end
        end
    end
    return sheet
end

function Handlers.SheetOpen(player)
    AIO.Handle(player, "CompanionMount", "Sheet", Sheet(player))
end

function Handlers.Order(player, order)
    if type(order) ~= "string" or not ORDERS[order] then
        return
    end
    player:RunCommand("companion " .. order)
    AIO.Handle(player, "CompanionMount", "State", State(player))
    AIO.Handle(player, "CompanionMount", "Sheet", Sheet(player))
end
