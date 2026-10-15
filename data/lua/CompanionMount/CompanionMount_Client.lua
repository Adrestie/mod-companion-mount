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
    The companion mount, client side (sent by AIO).

    THE BAR: the pet bar of the companion mount, beside the pet's own. Call,
    send back, attack, follow, stay, and the three stances -- the same icons
    as the pet bar. The active order and stance are lit. Nothing is decided
    here: every button is sent to the server, which runs the module's command
    as the player and sends the state back.

    Shift + drag moves the bar (kept per character); /companion shows or hides
    it.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local Handlers = AIO.AddHandlers("CompanionMount", {})

-- ---------------------------------------------------------------------------
-- Texts, in the client's language
-- ---------------------------------------------------------------------------

local FR = GetLocale() == "frFR"
local L = {
    title      = FR and "Monture-compagnon" or "Companion mount",
    summon     = FR and "Appeler" or "Call",
    summonTip  = FR and "Fait sortir la monture que vous chevauchez, sinon la dernière choisie."
                     or "Calls the mount you ride, else the last one chosen.",
    dismiss    = FR and "Renvoyer" or "Send back",
    dismissTip = FR and "Renvoie la monture à l'écurie." or "Sends the mount back to the stable.",
    attack     = FR and "Attaquer" or "Attack",
    attackTip  = FR and "Attaque votre cible, quelle que soit l'attitude." or "Attacks your target, whatever the stance.",
    follow     = FR and "Suivre" or "Follow",
    followTip  = FR and "La monture vous suit." or "The mount follows you.",
    stay       = FR and "Rester" or "Stay",
    stayTip    = FR and "La monture reste sur place et y revient après un combat."
                     or "The mount stays where it is, and comes back there after a fight.",
    aggressive    = FR and "Agressive" or "Aggressive",
    aggressiveTip = FR and "Attaque aussi tout ennemi à 20 mètres." or "Also attacks any enemy within 20 yards.",
    defensive     = FR and "Défensive" or "Defensive",
    defensiveTip  = FR and "Attaque votre cible, ce qui vous attaque et ce qui l'attaque."
                        or "Attacks your target, what attacks you, and what attacks it.",
    passive       = FR and "Passive" or "Passive",
    passiveTip    = FR and "N'attaque que sur ordre." or "Attacks only when told to.",
    moveTip    = FR and "Maj + glisser : déplacer la barre" or "Shift + drag: move the bar",
    level      = FR and "Niv. %d" or "Lv %d",
    rename     = FR and "Renommer" or "Rename",
    renameTip  = FR and "Donne un nom à la monture choisie (vide : retire le nom)."
                     or "Names the chosen mount (empty: removes the name).",
    renameAsk  = FR and "Nouveau nom de votre monture-compagnon :" or "New name of your companion mount:",
}

-- ---------------------------------------------------------------------------
-- The state, as the server sends it
-- ---------------------------------------------------------------------------

local COMMAND_FOLLOW, COMMAND_STAY = 0, 1
local REACT_PASSIVE, REACT_DEFENSIVE, REACT_AGGRESSIVE = 0, 1, 2

local state = { mount = 0, summoned = false, command = COMMAND_FOLLOW, react = REACT_DEFENSIVE, level = 0 }
local hidden = false

-- ---------------------------------------------------------------------------
-- The bar
-- ---------------------------------------------------------------------------

local SIZE, GAP = 30, 4

local BUTTONS = {
    { order = "summon",     text = L.summon,     tip = L.summonTip,     icon = "Interface\\Icons\\Ability_Mount_RidingHorse" },
    { order = "dismiss",    text = L.dismiss,    tip = L.dismissTip,    icon = "Interface\\Icons\\Spell_Nature_SpiritWolf" },
    { order = "attack",     text = L.attack,     tip = L.attackTip,     icon = PET_ATTACK_TEXTURE, needsOut = true },
    { order = "follow",     text = L.follow,     tip = L.followTip,     icon = PET_FOLLOW_TEXTURE, needsOut = true,
      lit = function() return state.command == COMMAND_FOLLOW end },
    { order = "stay",       text = L.stay,       tip = L.stayTip,       icon = PET_WAIT_TEXTURE, needsOut = true,
      lit = function() return state.command == COMMAND_STAY end },
    { order = "aggressive", text = L.aggressive, tip = L.aggressiveTip, icon = PET_AGGRESSIVE_TEXTURE,
      lit = function() return state.react == REACT_AGGRESSIVE end },
    { order = "defensive",  text = L.defensive,  tip = L.defensiveTip,  icon = PET_DEFENSIVE_TEXTURE,
      lit = function() return state.react == REACT_DEFENSIVE end },
    { order = "passive",    text = L.passive,    tip = L.passiveTip,    icon = PET_PASSIVE_TEXTURE,
      lit = function() return state.react == REACT_PASSIVE end },
    { order = "rename",     text = L.rename,     tip = L.renameTip,     icon = "Interface\\Icons\\INV_Scroll_11",
      popup = "COMPANIONMOUNT_RENAME" },
}

StaticPopupDialogs["COMPANIONMOUNT_RENAME"] = {
    text = L.renameAsk,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 12,
    OnAccept = function(self)
        AIO.Handle("CompanionMount", "Rename", self.editBox:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self)
        AIO.Handle("CompanionMount", "Rename", self:GetText() or "")
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local bar = CreateFrame("Frame", "CompanionMountBar", UIParent)
bar:SetSize(#BUTTONS * (SIZE + GAP) + GAP, SIZE + 2 * GAP)
bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 170)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
bar:SetBackdropColor(0, 0, 0, 0.6)
bar:Hide()

local function StartMove(self)
    if IsShiftKeyDown() then bar:StartMoving() end
end

local function StopMove(self)
    bar:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(bar) end
end

bar:SetScript("OnDragStart", StartMove)
bar:SetScript("OnDragStop", StopMove)

local buttons = {}

for i, def in ipairs(BUTTONS) do
    local b = CreateFrame("CheckButton", "CompanionMountBarButton" .. i, bar)
    b:SetSize(SIZE, SIZE)
    b:SetPoint("LEFT", bar, "LEFT", GAP + (i - 1) * (SIZE + GAP), 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(def.icon)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", StartMove)
    b:SetScript("OnDragStop", StopMove)
    b.def = def

    b:SetScript("OnClick", function(self)
        if self.def.popup then
            self:SetChecked(false)
            StaticPopup_Show(self.def.popup)
            return
        end
        AIO.Handle("CompanionMount", "Order", self.def.order)
        -- The server answers with the state; until then, the lit button is
        -- the one that was lit.
        self:SetChecked(self.def.lit and self.def.lit() or false)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.def.text, 1, 1, 1)
        GameTooltip:AddLine(self.def.tip, nil, nil, nil, true)
        GameTooltip:AddLine(L.moveTip, 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)

    buttons[i] = b
end

-- The level of the mount, on the call button.
local levelText = buttons[1]:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
levelText:SetPoint("BOTTOMRIGHT", buttons[1], "BOTTOMRIGHT", -1, 2)

local function Refresh()
    -- The call button wears the face of the chosen mount.
    local icon = state.mount ~= 0 and select(3, GetSpellInfo(state.mount))
    buttons[1].icon:SetTexture(icon or BUTTONS[1].icon)
    levelText:SetText((state.level or 0) > 0 and string.format(L.level, state.level) or "")

    for _, b in ipairs(buttons) do
        local usable = not b.def.needsOut or state.summoned
        b:SetChecked(b.def.lit and b.def.lit() or false)
        b:EnableMouse(true)
        b.icon:SetDesaturated(not usable)
        b.icon:SetVertexColor(usable and 1 or 0.6, usable and 1 or 0.6, usable and 1 or 0.6)
    end

    if hidden or state.mount == 0 then
        bar:Hide()
    else
        bar:Show()
    end
end

-- ---------------------------------------------------------------------------
-- The server
-- ---------------------------------------------------------------------------

function Handlers.State(_, newState)
    if type(newState) ~= "table" then return end
    state = newState
    Refresh()
end

AIO.SavePosition(bar, true)

SLASH_COMPANIONMOUNT1 = "/companion"
SLASH_COMPANIONMOUNT2 = "/compagnon"
SlashCmdList["COMPANIONMOUNT"] = function()
    hidden = not hidden
    Refresh()
end

AIO.Handle("CompanionMount", "Hello")
