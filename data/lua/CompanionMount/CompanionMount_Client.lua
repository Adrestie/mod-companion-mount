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
    treeDps    = FR and "Fureur" or "Fury",
    treeTank   = FR and "Rempart" or "Rampart",
    treeHeal   = FR and "Bienveillance" or "Benevolence",
    noTree     = FR and "aucun arbre choisi" or "no tree chosen",
    points     = FR and "Points : %d/%d - %s" or "Points: %d/%d - %s",
    reset      = FR and "Réinitialiser" or "Reset",
    keyTip     = FR and "Sort clé : il dépend du type de la monture." or "Key spell: it depends on the kind of the mount.",
    rankLine   = FR and "Rang %d/%d" or "Rank %d/%d",
    otherTree  = FR and "La monture a déjà choisi un autre arbre : réinitialisez ses talents pour changer."
                     or "The mount already chose another tree: reset its talents to change.",
    needPoints = FR and "Demande %d points dans cet arbre." or "Requires %d points in this tree.",
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
--
-- Slots of the size and spacing of the bags' (37 px, 5 apart, as
-- ContainerFrameItemButtonTemplate and ForeverUI's bags), ten to a row. With
-- ForeverUI installed, its sprites: the empty slot of its bags and the frame
-- tinted by quality; otherwise the game's own slot.
--
-- Right click moves an item: in the player's bags, into the saddlebags (while
-- the window is open); in the saddlebags, back into the bags. An item dropped
-- on the window goes in too.
-- ---------------------------------------------------------------------------

local SEP = string.char(92)   -- a backslash, built so no escape can go wrong
local function Path(...) return table.concat({ ... }, SEP) end

local SLOT, GAP, COLUMNS = 37, 5, 10
local EMPTY_SLOT = Path("Interface", "Buttons", "UI-EmptySlot-Disabled")
local HOVER = Path("Interface", "Buttons", "ButtonHilight-Square")
local QUALITY_FRAME = Path("Interface", "ForeverUI", "common", "whiteiconframe")
local FRAME_GRAY = 0.39       -- ForeverUI frames every slot in this gray
local TINTED_QUALITY = 2      -- and tints it by quality from uncommon on

local function Forever()
    return type(ForeverUI) == "table" and type(ForeverUI.SetAtlas) == "function"
end

local bagItems = {}
local bagSlots = 50

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
    bgFile = Path("Interface", "DialogFrame", "UI-DialogBox-Background"),
    edgeFile = Path("Interface", "DialogFrame", "UI-DialogBox-Border"),
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

local function Deposit(bag, slot)
    AIO.Handle("CompanionMount", "BagPut", bag, slot)
end

-- An item of the player's bags dropped on the window: sent with its bag and
-- slot, while the container still shows it locked under the cursor.
local function DropOn()
    if CursorHasItem() and picked and select(3, GetContainerItemInfo(picked.bag, picked.slot)) then
        Deposit(picked.bag, picked.slot)
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
    b:SetSize(SLOT, SLOT)
    local row, col = math.floor((i - 1) / COLUMNS), (i - 1) % COLUMNS
    b:SetPoint("TOPLEFT", bagFrame, "TOPLEFT", 16 + col * (SLOT + GAP), -36 - row * (SLOT + GAP))

    -- Layers, bottom to top: the empty slot, the item, its frame, the count.
    b.slotArt = b:CreateTexture(nil, "BACKGROUND")
    b.slotArt:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.frame = b:CreateTexture(nil, "OVERLAY")
    b.frame:SetAllPoints()
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetHighlightTexture(HOVER, "ADD")

    b.place = i
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if DropOn() then return end
        if button == "RightButton" and bagItems[self.place] then
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

local function SkinSlot(b, item)
    local forever = Forever()
    if forever then
        -- ForeverUI: its empty-slot sprite, and every slot framed in gray, in
        -- the quality color from uncommon on.
        ForeverUI.SetAtlas(b.slotArt, "bags-item-slot64", true)
        b.slotArt:SetAllPoints()
        b.frame:SetTexture(QUALITY_FRAME)
        local quality = item and select(3, GetItemInfo(item.entry))
        if quality and quality >= TINTED_QUALITY then
            local r, g, bl = GetItemQualityColor(quality)
            b.frame:SetVertexColor(r, g, bl)
        else
            b.frame:SetVertexColor(FRAME_GRAY, FRAME_GRAY, FRAME_GRAY)
        end
        b.frame:Show()
    else
        b.slotArt:SetTexture(EMPTY_SLOT)
        b.slotArt:SetTexCoord(0, 1, 0, 1)
        b.frame:Hide()
    end
end

local function RefreshBag()
    local rows = math.ceil(bagSlots / COLUMNS)
    bagFrame:SetSize(32 + COLUMNS * SLOT + (COLUMNS - 1) * GAP, 52 + rows * SLOT + (rows - 1) * GAP)
    for i = 1, math.max(bagSlots, #bagButtons) do
        local b = BagButton(i)
        local item = bagItems[i]
        if i > bagSlots then
            b:Hide()
        else
            SkinSlot(b, item)
            b.icon:SetTexture(item and GetItemIcon(item.entry) or nil)
            b.count:SetText(item and item.count > 1 and item.count or "")
            b:Show()
        end
    end
end

-- RIGHT CLICK IN THE PLAYER'S BAGS while the saddlebags are open: into the
-- saddlebags, as the bank does with its own window. Installed the first time
-- the window opens, so a player who never opens it keeps the game's own click.
local hooked = false
local function HookBags()
    if hooked then return end
    hooked = true
    local original = ContainerFrameItemButton_OnClick
    ContainerFrameItemButton_OnClick = function(self, button, ...)
        if button == "RightButton" and bagFrame:IsShown() and not IsModifierKeyDown() and not CursorHasItem() then
            local bag, slot = self:GetParent():GetID(), self:GetID()
            if GetContainerItemInfo(bag, slot) then
                Deposit(bag, slot)
                return
            end
        end
        return original(self, button, ...)
    end
end

function CompanionMount_ToggleBag()
    if bagFrame:IsShown() then
        bagFrame:Hide()
    else
        HookBags()
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
--
-- The talent frame of the game: the art of a tree (the client's WarriorFury,
-- WarriorProtection, DruidRestoration), buttons laid as TalentFrame lays
-- them (63 px apart), the slot and the rank colored as Blizzard colors them --
-- green while a rank can be learned, yellow at the top rank, gray out of
-- reach -- tabs at the bottom, the points in the footer. With ForeverUI
-- installed, its square talent nodes.
-- ---------------------------------------------------------------------------

local TP = string.char(92)
local function TPath(...) return table.concat({ ... }, TP) end

local TREES = {
    { name = L.treeDps,  art = "WarriorFury" },
    { name = L.treeTank, art = "WarriorProtection" },
    { name = L.treeHeal, art = "DruidRestoration" },
}
-- TalentFrame: INITIAL_TALENT_OFFSET_X/Y and the step between two buttons.
local T_X, T_Y, T_STEP, T_BUTTON = 35, 20, 63, 37
local T_ART_W, T_ART_H = 320, 384      -- the four pieces of a tree's art
local T_INSET_X, T_INSET_Y = 14, 40    -- where the art sits in the window
local GREEN, YELLOW, GRAY = { 0.1, 1, 0.1 }, { 1, 0.82, 0 }, { 0.5, 0.5, 0.5 }

local talentData = { talents = {}, ranks = {}, points = 0, keys = {} }
local shownTree = 1

local function TForever()
    return type(ForeverUI) == "table" and type(ForeverUI.SetAtlas) == "function"
end

local talentFrame = CreateFrame("Frame", "CompanionMountTalentFrame", UIParent)
talentFrame:SetSize(T_ART_W + 2 * T_INSET_X, T_ART_H + T_INSET_Y + 54)
talentFrame:SetPoint("CENTER", UIParent, "CENTER", -250, 0)
talentFrame:SetMovable(true)
talentFrame:EnableMouse(true)
talentFrame:SetClampedToScreen(true)
talentFrame:SetToplevel(true)
talentFrame:RegisterForDrag("LeftButton")
talentFrame:SetScript("OnDragStart", talentFrame.StartMoving)
talentFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(self) end
end)
talentFrame:SetBackdrop({
    bgFile = TPath("Interface", "DialogFrame", "UI-DialogBox-Background"),
    edgeFile = TPath("Interface", "DialogFrame", "UI-DialogBox-Gold-Border"),
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
talentFrame:Hide()
tinsert(UISpecialFrames, "CompanionMountTalentFrame")

-- The header: the window's title on the game's title strip.
local header = talentFrame:CreateTexture(nil, "ARTWORK")
header:SetTexture(TPath("Interface", "DialogFrame", "UI-DialogBox-Header"))
header:SetSize(300, 64)
header:SetPoint("TOP", 0, 12)
talentFrame.title = talentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
talentFrame.title:SetPoint("TOP", header, "TOP", 0, -14)

local tclose = CreateFrame("Button", nil, talentFrame, "UIPanelCloseButton")
tclose:SetPoint("TOPRIGHT", -2, -2)

-- The tree's art, in its four pieces.
local art = CreateFrame("Frame", nil, talentFrame)
art:SetSize(T_ART_W, T_ART_H)
art:SetPoint("TOPLEFT", T_INSET_X, -T_INSET_Y)
local pieces = {
    { "TopLeft", 256, 256, "TOPLEFT", 0, 0 },
    { "TopRight", 64, 256, "TOPLEFT", 256, 0 },
    { "BottomLeft", 256, 128, "TOPLEFT", 0, -256 },
    { "BottomRight", 64, 128, "TOPLEFT", 256, -256 },
}
for _, p in ipairs(pieces) do
    local t = art:CreateTexture(nil, "BACKGROUND")
    t:SetSize(p[2], p[3])
    t:SetPoint(p[4], art, "TOPLEFT", p[5], p[6])
    p.texture = t
end

-- The footer: the points, the tree chosen, the reset.
local footer = talentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
footer:SetPoint("BOTTOMLEFT", 20, 22)

local reset = CreateFrame("Button", nil, talentFrame, "UIPanelButtonTemplate")
reset:SetSize(110, 22)
reset:SetPoint("BOTTOMRIGHT", -16, 16)
reset:SetText(L.reset)
reset:SetScript("OnClick", function() AIO.Handle("CompanionMount", "TalentReset") end)

-- The tabs, under the window, as the game's.
local tabs = {}
for i, tree in ipairs(TREES) do
    local tab = CreateFrame("Button", "CompanionMountTalentFrameTab" .. i, talentFrame, "CharacterFrameTabButtonTemplate")
    tab:SetID(i)
    tab:SetText(tree.name)
    if i == 1 then
        tab:SetPoint("TOPLEFT", talentFrame, "BOTTOMLEFT", 12, 6)
    else
        tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", -16, 0)
    end
    tab:SetScript("OnClick", function(self)
        shownTree = self:GetID()
        PlaySound("igCharacterInfoTab")
        CompanionMount_RefreshTalents()
    end)
    tabs[i] = tab
end
PanelTemplates_SetNumTabs(talentFrame, #TREES)
PanelTemplates_SetTab(talentFrame, 1)

local cells = {}
local function TalentCell(tier, col)
    local key = tier * 10 + col
    local b = cells[key]
    if b then return b end
    b = CreateFrame("Button", nil, art)
    b:SetSize(T_BUTTON, T_BUTTON)
    b:SetPoint("TOPLEFT", art, "TOPLEFT", T_X + col * T_STEP, -(T_Y + tier * T_STEP))

    -- TalentButtonTemplate: the slot, the icon, the frame, the rank in its border.
    b.slot = b:CreateTexture(nil, "BACKGROUND")
    b.slot:SetTexture(TPath("Interface", "Buttons", "UI-EmptySlot-White"))
    b.slot:SetSize(64, 64)
    b.slot:SetPoint("CENTER")
    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetPoint("CENTER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.frame = b:CreateTexture(nil, "OVERLAY")
    b.frame:SetPoint("CENTER", 0, -1)
    b:SetHighlightTexture(TPath("Interface", "Buttons", "ButtonHilight-Square"), "ADD")
    b:SetPushedTexture(TPath("Interface", "Buttons", "UI-Quickslot-Depress"))
    b.rankBorder = b:CreateTexture(nil, "OVERLAY")
    b.rankBorder:SetTexture(TPath("Interface", "TalentFrame", "TalentFrame-RankBorder"))
    b.rankBorder:SetSize(32, 32)
    b.rankBorder:SetPoint("CENTER", b, "BOTTOMRIGHT", 0, 0)
    b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.rank:SetPoint("CENTER", b.rankBorder, "CENTER", 0, 0)

    b:SetScript("OnClick", function(self)
        if self.talent then AIO.Handle("CompanionMount", "TalentLearn", self.talent.id) end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.spell then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.spell)
        GameTooltip:AddLine(string.format(L.rankLine, self.rankValue or 0, self.maxRank or 1), 1, 1, 1)
        if self.talent and self.talent.key then
            GameTooltip:AddLine(L.keyTip, 1, 0.82, 0, true)
        end
        if self.reason then
            GameTooltip:AddLine(self.reason, 1, 0.1, 0.1, true)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cells[key] = b
    return b
end

local function Paint(b, state)
    local c = state == "maxed" and YELLOW or (state == "selectable" and GREEN or GRAY)
    if TForever() then
        -- ForeverUI: its square node, colored by state.
        b.slot:Hide()
        local border = state == "maxed" and "yellow" or (state == "selectable" and "green" or "gray")
        ForeverUI.SetAtlas(b.shadow, "talents-node-square-shadow", true)
        b.shadow:SetSize(39, 39)
        b.shadow:Show()
        ForeverUI.SetAtlas(b.frame, "talents-node-square-" .. border, true)
        b.frame:SetSize(40, 40)
        b.frame:SetVertexColor(1, 1, 1)
        b.icon:ClearAllPoints()
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(36, 36)
    else
        b.icon:ClearAllPoints()
        b.icon:SetAllPoints()
        -- The game's: the white slot tinted, under the quickslot frame.
        b.shadow:Hide()
        b.slot:Show()
        b.slot:SetVertexColor(c[1], c[2], c[3])
        b.frame:SetTexture(TPath("Interface", "Buttons", "UI-Quickslot2"))
        b.frame:SetTexCoord(0, 1, 0, 1)
        b.frame:SetSize(64, 64)
        b.frame:SetVertexColor(1, 1, 1)
    end
    b.icon:SetDesaturated(state == "disabled" or state == "locked")
    b.rank:SetTextColor(c[1], c[2], c[3])
end

function CompanionMount_RefreshTalents()
    local tree = TREES[shownTree]
    for _, p in ipairs(pieces) do
        p.texture:SetTexture(TPath("Interface", "TalentFrame", tree.art .. "-" .. p[1]))
    end
    PanelTemplates_SetTab(talentFrame, shownTree)
    talentFrame.title:SetText(L.talents .. " - " .. tree.name)

    -- Points spent, overall and in the tree shown; the tree already chosen.
    local spent, inTree, chosen = 0, 0, nil
    for _, t in ipairs(talentData.talents) do
        local rank = talentData.ranks[t.id] or 0
        if rank > 0 then
            spent = spent + rank
            chosen = t.tree
            if t.tree == shownTree - 1 then inTree = inTree + rank end
        end
    end
    local left = math.max(0, (talentData.points or 0) - spent)
    footer:SetText(string.format(L.points, spent, talentData.points or 0,
        chosen and TREES[chosen + 1].name or L.noTree))

    for _, b in pairs(cells) do b:Hide() end
    for _, t in ipairs(talentData.talents) do
        if t.tree == shownTree - 1 then
            local b = TalentCell(t.tier, t.col)
            local rank = talentData.ranks[t.id] or 0
            local max = t.key and 1 or #t.ranks
            local reached = inTree >= t.tier * 3
            local otherTree = chosen ~= nil and chosen ~= t.tree

            local state, reason
            if rank >= max then
                state = "maxed"
            elseif otherTree then
                state, reason = "disabled", L.otherTree
            elseif not reached then
                state, reason = "locked", string.format(L.needPoints, t.tier * 3)
            elseif left > 0 then
                state = "selectable"
            else
                state = rank > 0 and "selectable" or "disabled"
            end

            b.talent, b.rankValue, b.maxRank, b.reason = t, rank, max, reason
            b.spell = t.key and (talentData.keys or {})[t.tree] or t.ranks[math.max(1, math.min(rank + 1, max))]
            local _, _, icon = GetSpellInfo(b.spell or 0)
            b.icon:SetTexture(icon or TPath("Interface", "Icons", "INV_Misc_QuestionMark"))
            Paint(b, state)
            b.rank:SetText(rank)
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
        PlaySound("TalentScreenOpen")
    end
end

talentFrame:SetScript("OnHide", function() PlaySound("TalentScreenClose") end)

function Handlers.Talents(_, data)
    if type(data) ~= "table" then return end
    local first = talentData.talents == nil or #talentData.talents == 0
    talentData = data
    talentData.ranks = talentData.ranks or {}
    talentData.talents = talentData.talents or {}
    -- On opening, the tab of the tree already chosen.
    if first then
        for _, t in ipairs(talentData.talents) do
            if (talentData.ranks[t.id] or 0) > 0 then shownTree = t.tree + 1 break end
        end
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
