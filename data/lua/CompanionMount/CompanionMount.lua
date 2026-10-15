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

function Handlers.Order(player, order)
    if type(order) ~= "string" or not ORDERS[order] then
        return
    end
    player:RunCommand("companion " .. order)
    AIO.Handle(player, "CompanionMount", "State", State(player))
end
