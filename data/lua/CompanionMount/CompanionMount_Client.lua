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
    bag        = FR and "Sacoches" or "Saddlebags",
    talents    = FR and "Talents" or "Talents",
    talentsTip = FR and "Ouvre les talents de la monture : un arbre par monture, cliquez pour apprendre un rang."
                     or "Opens the talents of the mount: one tree per mount, click to learn a rank.",
    treeDps    = "DPS",
    treeTank   = "Tank",
    treeHeal   = FR and "Soin" or "Heal",
    noTree     = FR and "aucun arbre choisi" or "no tree chosen",
    points     = FR and "Points : %d/%d - %s" or "Points: %d/%d - %s",
    reset      = FR and "Réinitialiser" or "Reset",
    keyTip     = FR and "Sort clé : il dépend du type de la monture." or "Key spell: it depends on the kind of the mount.",
    bagTip     = FR and "Ouvre les sacoches de la monture : glissez-y un objet de vos sacs, cliquez sur un objet pour le reprendre."
                     or "Opens the saddlebags of the mount: drop an item of your bags on them, click an item to take it back.",
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
    { order = "bag",        text = L.bag,        tip = L.bagTip,        icon = "Interface\\Icons\\INV_Misc_Bag_08",
      window = true },
    { order = "talents",    text = L.talents,    tip = L.talentsTip,    icon = "Interface\\Icons\\Ability_Hunter_BeastTraining",
      talents = true },
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
        if self.def.talents then
            self:SetChecked(false)
            CompanionMount_ToggleTalents()
            return
        end
        if self.def.window then
            self:SetChecked(false)
            CompanionMount_ToggleBag()
            return
        end
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
-- The saddlebags window
-- ---------------------------------------------------------------------------

local BAG_COLUMNS, BAG_SIZE = 4, 37
local bagItems = {}
local bagSlots = 16

-- The last item taken from the player's bags: the window needs its bag and
-- slot, the cursor only says what it holds.
local picked
hooksecurefunc("PickupContainerItem", function(bag, slot) picked = { bag = bag, slot = slot } end)

local bagFrame = CreateFrame("Frame", "CompanionMountBagFrame", UIParent)
bagFrame:SetPoint("CENTER", UIParent, "CENTER", 250, 0)
bagFrame:SetMovable(true)
bagFrame:EnableMouse(true)
bagFrame:SetClampedToScreen(true)
bagFrame:RegisterForDrag("LeftButton")
bagFrame:SetScript("OnDragStart", bagFrame.StartMoving)
bagFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(self) end
end)
bagFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
bagFrame:Hide()
tinsert(UISpecialFrames, "CompanionMountBagFrame")   -- the Escape key closes it

bagFrame.title = bagFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bagFrame.title:SetPoint("TOP", 0, -12)
bagFrame.title:SetText(L.bag)

local close = CreateFrame("Button", nil, bagFrame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

local bagButtons = {}

-- An item of the player's bags dropped on the window: sent with its bag and
-- slot, while the container still shows it locked under the cursor.
local function DropOn()
    if CursorHasItem() and picked and select(3, GetContainerItemInfo(picked.bag, picked.slot)) then
        AIO.Handle("CompanionMount", "BagPut", picked.bag, picked.slot)
        ClearCursor()
        picked = nil
        return true
    end
    return false
end

local function BagButton(i)
    local b = bagButtons[i]
    if b then return b end
    b = CreateFrame("Button", "CompanionMountBagButton" .. i, bagFrame)
    b:SetSize(BAG_SIZE, BAG_SIZE)
    local row, col = math.floor((i - 1) / BAG_COLUMNS), (i - 1) % BAG_COLUMNS
    b:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 14 + col * (BAG_SIZE + 4), -34 - row * (BAG_SIZE + 4))
    b:SetNormalTexture("Interface\\Buttons\\UI-EmptySlot-Disabled")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b.place = i
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self)
        if DropOn() then return end
        if bagItems[self.place] then
            AIO.Handle("CompanionMount", "BagTake", self.place)
        end
    end)
    b:SetScript("OnReceiveDrag", DropOn)
    b:SetScript("OnEnter", function(self)
        local item = bagItems[self.place]
        if item then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(item.link)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagButtons[i] = b
    return b
end

local function RefreshBag()
    local rows = math.ceil(bagSlots / BAG_COLUMNS)
    bagFrame:SetSize(28 + BAG_COLUMNS * (BAG_SIZE + 4) - 4, 48 + rows * (BAG_SIZE + 4))
    for i = 1, math.max(bagSlots, #bagButtons) do
        local b = BagButton(i)
        local item = bagItems[i]
        if i > bagSlots then
            b:Hide()
        else
            b:Show()
            b.icon:SetTexture(item and GetItemIcon(item.entry) or nil)
            b.count:SetText(item and item.count > 1 and item.count or "")
        end
    end
end

function CompanionMount_ToggleBag()
    if bagFrame:IsShown() then
        bagFrame:Hide()
    else
        AIO.Handle("CompanionMount", "BagOpen")
        RefreshBag()
        bagFrame:Show()
    end
end

function Handlers.Bag(_, items, slots)
    if type(items) ~= "table" then return end
    bagItems = items
    bagSlots = tonumber(slots) or bagSlots
    RefreshBag()
end

-- A size BEFORE LibWindow reads the position: a frame without one has no
-- edges (GetLeft() is nil) and LibWindow.SavePosition fails on it.
RefreshBag()
AIO.SavePosition(bagFrame, true)

-- ---------------------------------------------------------------------------
-- The talents window
-- ---------------------------------------------------------------------------

local TREES = { L.treeDps, L.treeTank, L.treeHeal }
local T_SIZE, T_GAP, T_COLS, T_ROWS = 36, 10, 4, 6
local talentData = { talents = {}, ranks = {}, points = 0, key = 0 }
local shownTree = 1

local talentFrame = CreateFrame("Frame", "CompanionMountTalentFrame", UIParent)
talentFrame:SetSize(2 * 20 + T_COLS * T_SIZE + (T_COLS - 1) * T_GAP, 120 + T_ROWS * T_SIZE + (T_ROWS - 1) * T_GAP)
talentFrame:SetPoint("CENTER", UIParent, "CENTER", -250, 0)
talentFrame:SetMovable(true)
talentFrame:EnableMouse(true)
talentFrame:SetClampedToScreen(true)
talentFrame:RegisterForDrag("LeftButton")
talentFrame:SetScript("OnDragStart", talentFrame.StartMoving)
talentFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(self) end
end)
talentFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
talentFrame:Hide()
tinsert(UISpecialFrames, "CompanionMountTalentFrame")

talentFrame.title = talentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
talentFrame.title:SetPoint("TOP", 0, -12)
talentFrame.title:SetText(L.talents)

talentFrame.points = talentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
talentFrame.points:SetPoint("TOP", 0, -30)

local tclose = CreateFrame("Button", nil, talentFrame, "UIPanelCloseButton")
tclose:SetPoint("TOPRIGHT", -2, -2)

local tabs = {}
for i, name in ipairs(TREES) do
    local tab = CreateFrame("Button", "CompanionMountTalentTab" .. i, talentFrame, "UIPanelButtonTemplate")
    tab:SetSize(70, 20)
    tab:SetPoint("TOPLEFT", talentFrame, "TOPLEFT", 16 + (i - 1) * 74, -48)
    tab:SetText(name)
    tab:SetScript("OnClick", function() shownTree = i; CompanionMount_RefreshTalents() end)
    tabs[i] = tab
end

local reset = CreateFrame("Button", nil, talentFrame, "UIPanelButtonTemplate")
reset:SetSize(110, 22)
reset:SetPoint("BOTTOM", 0, 14)
reset:SetText(L.reset)
reset:SetScript("OnClick", function() AIO.Handle("CompanionMount", "TalentReset") end)

local cells = {}
local function Cell(tier, col)
    local key = tier * 10 + col
    local b = cells[key]
    if b then return b end
    b = CreateFrame("Button", nil, talentFrame)
    b:SetSize(T_SIZE, T_SIZE)
    b:SetPoint("TOPLEFT", talentFrame, "TOPLEFT", 20 + col * (T_SIZE + T_GAP), -78 - tier * (T_SIZE + T_GAP))
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b.rank = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.rank:SetPoint("BOTTOMRIGHT", 4, -4)
    b:SetScript("OnClick", function(self)
        if self.talent then AIO.Handle("CompanionMount", "TalentLearn", self.talent.id) end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.spell then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.spell)
        if self.talent and self.talent.key then
            GameTooltip:AddLine(L.keyTip, 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[key] = b
    return b
end

function CompanionMount_RefreshTalents()
    local spent, tree = 0, nil
    for id, rank in pairs(talentData.ranks) do
        spent = spent + rank
    end
    for _, t in ipairs(talentData.talents) do
        if (talentData.ranks[t.id] or 0) > 0 then tree = t.tree end
    end
    talentFrame.points:SetText(string.format(L.points, spent, talentData.points,
        tree and TREES[tree + 1] or L.noTree))
    for i, tab in ipairs(tabs) do
        if i == shownTree then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    for _, b in pairs(cells) do b:Hide() end
    for _, t in ipairs(talentData.talents) do
        if t.tree == shownTree - 1 then
            local b = Cell(t.tier, t.col)
            local rank = talentData.ranks[t.id] or 0
            local max = t.key and 1 or #t.ranks
            b.talent = t
            b.spell = t.key and talentData.key or t.ranks[math.max(1, math.min(rank + 1, max))]
            local _, _, icon = GetSpellInfo(b.spell or 0)
            b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.icon:SetDesaturated(rank == 0)
            b.rank:SetText(rank .. "/" .. max)
            b:Show()
        end
    end
end

function CompanionMount_ToggleTalents()
    if talentFrame:IsShown() then
        talentFrame:Hide()
    else
        AIO.Handle("CompanionMount", "TalentOpen")
        CompanionMount_RefreshTalents()
        talentFrame:Show()
    end
end

function Handlers.Talents(_, data)
    if type(data) ~= "table" then return end
    talentData = data
    talentData.ranks = talentData.ranks or {}
    talentData.talents = talentData.talents or {}
    for _, t in ipairs(talentData.talents) do
        if (talentData.ranks[t.id] or 0) > 0 then shownTree = t.tree + 1 break end
    end
    CompanionMount_RefreshTalents()
end

AIO.SavePosition(talentFrame, true)

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
