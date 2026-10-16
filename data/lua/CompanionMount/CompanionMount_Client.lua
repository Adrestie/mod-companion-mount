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

    THE SHEET of the companion mount: who it is, its level and experience,
    its numbers, its orders (call, send back, attack, follow, stay, the three
    stances, rename -- the pet bar's icons) and the doors to its talents and
    saddlebags. With ForeverUI, a tab of the Progression window (as Attriboost
    and Item Upgrade); without, a window opened by a button at the edge of the
    minimap. /companion or /compagnon opens it too.

    Nothing is decided here: every button is sent to the server, which runs
    the module's command as the player and sends the state back.
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
-- The orders (buttons of the sheet)
-- ---------------------------------------------------------------------------

local OSEP = string.char(92)
local function OPath(...) return table.concat({ ... }, OSEP) end

local BUTTONS = {
    { order = "summon",     text = L.summon,     tip = L.summonTip,     icon = OPath("Interface", "Icons", "Ability_Mount_RidingHorse") },
    { order = "dismiss",    text = L.dismiss,    tip = L.dismissTip,    icon = OPath("Interface", "Icons", "Spell_Nature_SpiritWolf") },
    { order = "attack",     text = L.attack,     tip = L.attackTip,     icon = PET_ATTACK_TEXTURE, needsOut = true },
    { order = "rename",     text = L.rename,     tip = L.renameTip,     icon = OPath("Interface", "Icons", "INV_Scroll_11"),
      popup = "COMPANIONMOUNT_RENAME" },
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

-- The Progression window of ForeverUI, carried by the modules: the common copy
-- below is IDENTICAL to the one in Attriboost_Client.lua and ItemUpgrade_Client.lua
-- (taken from mod-item-upgrade); whichever module loads first creates the window.
-- ---------------------------------------------------------------------------
-- DÉBUT DE LA FENÊTRE PROGRESSION -- copie commune, IDENTIQUE dans
-- Attriboost_Client.lua et ItemUpgrade_Client.lua : toute modification se
-- reporte dans l'autre fichier.
-- ---------------------------------------------------------------------------
-- Une fenêtre au thème de Camelot -- le LegacySystemFrame de camelot -- dont
-- les modules du serveur ajoutent les onglets (demande du 2026-09-29 : « si
-- le serveur a le module d'interface de mod-forever-ui d'installé, au lieu
-- d'avoir des boutons autour de la minimap et une interface grise, il faut un
-- bouton dans la barre des micro boutons. cliquer sur le bouton devra ouvrir
-- une fenêtre au thème de Camelot avec un onglet pour "Attriboost" et un
-- autre pour item upgrade (sachant que l'un ou l'autre peut être absent) » ;
-- l'icône : celle du menu Legacy de camelot ; le nom : Progression).
--
-- PORTÉE PAR LES MODULES (choix de l'utilisateur, 2026-09-29) : ce code
-- arrive avec chaque module, par AIO. Le premier module chargé crée la
-- fenêtre ; le suivant la trouve (global Progression) et n'y ajoute que son
-- onglet.
--
-- INDÉPENDANTE DE ForeverUI (règle de l'utilisateur, 2026-09-29 : les
-- modules « détectent si "forever-ui" est installé. Si non -> addon normaux,
-- si oui, ils montent leurs ui chacun avec les sources que "forever-ui" a
-- installé et qu'il lui dise "ajoute ce bouton dans ta micro barre" »).
-- ForeverUI ne connaît ni cette fenêtre ni ces modules, et ce code n'appelle
-- AUCUNE de ses fonctions de dessin : tout ce qui se dessine est écrit ici ou
-- dans la page du module. De ForeverUI, il ne prend que :
--   * ses FICHIERS de textures installés (Interface\ForeverUI\...), avec
--     leurs coordonnées recopiées dans les tables ci-dessous et dans celles
--     des pages ;
--   * sa micro-barre : ForeverUI.AddMicroButton (le bouton, avec le jeu
--     d'icônes « legacy » de ForeverUI) et ForeverUI.UpdateMicro (enfoncé tant
--     que la fenêtre est ouverte).
-- Sans ForeverUI.AddMicroButton, la fenêtre n'existe pas, et les modules
-- gardent leur interface d'origine.
--
-- RELEVÉ -- CAMELOT (blizzard_legacysystem : blizzard_legacysystem.xml /
-- .lua, blizzard_legacysystemtemplates.xml, _bootstrap.lua, _registration
-- .lua ; blizzard_micromenu : mainline/mainmenubarmicrobuttons.lua,
-- camelot/micromenucontaineroverrides.lua ; blizzard_sharedxml :
-- mainline/shareduipaneltemplates.xml, portraitframe.lua,
-- shared/button/threeslicebuttontemplate.xml / .lua) :
--   fenêtre      LegacySystemFrame, PortraitFrameTemplate, 920 x 575 ;
--                RegisterUIPanel : area "left", xoffset 35, pushable 1,
--                largeur 1005 ; ToggleFrame ; sons IG_CHARACTER_INFO_OPEN /
--                _CLOSE ; pas de titre
--   cadre        roche UI-Background-Rock en mosaïque de (2, -21) à
--                (-2, 2) ; stries _UI-Frame-TopTileStreaks de 43 à
--                (6, -21) ; coins du métal à (-13, 16), (2, 16), (-13, -8),
--                (2, -8), bords tendus entre eux ; bandeau du titre de
--                (58, -1) à (-24, -1), 20 de haut, texte GameFontNormal
--                à -5 de son haut
--   croix        UIPanelCloseButton : 24 x 24, RedButton-Exit / -pressed /
--                -disabled, lueur RedButton-Highlight en ADD, à TOPRIGHT
--                (-2, 1) de la fenêtre
--   portrait     SetPortraitAtlasRaw("Legacy-up-c60"), 45 x 62, TOPLEFT
--                (2, 10) ; le CircleMask du gabarit (TempPortraitAlphaMask)
--                le suit de (2, 0) à (-2, 4) ; le portrait (niveau 400)
--                passe sous le métal (500)
--   onglets      LegacySystemTabTemplate (LargeSideTabButtonTemplate,
--                fillToInterior) : le premier TOPLEFT sur le TOPRIGHT
--                (0, -60), chacun sous le précédent (0, -2) ; infobulle
--                tooltipText ; SelectPage : la page montrée, son onglet
--                coché ; les pages au niveau 100
--   bouton rouge ThreeSliceButtonTemplate : Left et Right à leur taille
--                d'atlas mise à l'échelle de la hauteur du bouton, Center
--                tendu entre eux, rognés s'ils ne tiennent pas dans la
--                largeur (UpdateScale) ; états -Pressed et -Disabled ;
--                lueur <atlas>-Highlight en ADD ; texte enfoncé de (-2, -1)
--   micro-bouton LegacyMicroButton : LoadMicroButtonTextures "Legacy",
--                après les talents ; grisé tant que le système est
--                verrouillé, enfoncé tant que la fenêtre est ouverte
--
-- CE QUI DIFFÈRE, ET POURQUOI.
--   * Les pages sont celles que déclarent les modules, par P.Ajouter. Chaque
--     page déclarée demande le micro-bouton : le premier module le crée, le
--     second le trouve déjà là ; sans module, il n'existe pas (demande du
--     2026-09-29). Camelot, lui, le grise.
--   * Un disque noir sous le portrait, dans le cercle (demande du
--     2026-09-29 : « l'icône dans le cercle du portrait de la fenêtre doit
--     avoir un fond noir ») : celui du portrait rond de PortraitFrameTemplate
--     (62 x 62 à (-5, 7), rogné par son CircleMask de (2, 0) à (-2, 4) : 58 x
--     58 à (-3, 7)), TempPortraitAlphaMask noirci, sous l'anneau de métal.
--   * La fenêtre a la taille de celle des métiers de ForeverUI (673 x 594) :
--     la page d'Item Upgrade reprend sa page de fabrication, à ses nombres.
--     La largeur du panneau garde la marge de camelot (1005 pour 920 : 85,
--     onglets compris).
--   * Un titre, « Progression » : le nom retenu par l'utilisateur. Il vient
--     des textes du module qui le donne (nomFenetre), lus à l'affichage : les
--     textes d'un module arrivent après son code.
--   * 3.3.5 n'a pas de masque : le portrait est une image où l'ellipse du
--     CircleMask est cuite. Chaque module installe la sienne (son
--     installeur l'écrit dans l'archive du jeu) et la donne à P.Ajouter ; la
--     fenêtre prend celle du module qui la crée.
--   * 3.3.5 n'a ni atlas ni découpe en neuf : les éléments se posent par
--     leurs coordonnées dans leur feuille (tables ci-dessous), les découpes
--     en morceaux posés à la main.
--   * Le panneau se déclare par ses attributs UIPanelLayout-*, sans toucher
--     à la table UIPanelWindows du client.
--
-- CE QUE LES MODULES APPELLENT (ils testent Progression.Ajouter et
-- Progression.Kit) :
--   P.Ajouter{ cle, ordre, titre, icone, construire, nomFenetre, portrait }
--     -- déclare une page et rend son cadre (toute la fenêtre ;
--     construire(page) le remplit, une fois, à sa première ouverture). titre :
--     un texte, ou une fonction qui le rend. ordre : la place de l'onglet (le
--     plus petit en haut). nomFenetre : le nom de la fenêtre et du
--     micro-bouton (texte ou fonction) ; portrait : le fichier du portrait ;
--     ceux de la page qui crée la fenêtre. Redéclarer une clé (un « .reload
--     ale ») remplace sa page par un cadre neuf.
--   P.Ouvrir(cle), P.Basculer(cle), P.Fermer(), P.Montree(cle).
--   P.Kit : la trousse de dessin écrite ici (voir plus bas) ; une page y
--     ajoute les coordonnées de ses propres éléments par K.AjouterArt.
if not (Progression and Progression.Ajouter) and ForeverUI and ForeverUI.AddMicroButton then
    Progression = {}
    local P = Progression
    local SEP = string.char(92)
    local ART = "Interface" .. SEP .. "ForeverUI" .. SEP
    local BOUTON = "ProgressionMicroButton"

    local N = {
        fenetre = { 673, 594 },
        -- l'image du portrait : la région utile de sa toile (198 x 273 sur
        -- 256 x 512), posée en 45 x 62
        portrait = { 45, 62, x = 2, y = 10, coords = { 0, 0.773438, 0, 0.533203 } },
        disque = { 58, x = -3, y = 7, fichier = ART .. "characterframe" .. SEP .. "tempportraitalphamask" },
        roche = { fichier = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", 2, -21, -2, 2 },
        stries = { 43, x = 6, y = -21, x2 = -2 },
        metal = {
            { nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
            { nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
            { nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
            { nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
        },
        titre = { x1 = 58, x2 = -24, y = -1, h = 20, texteY = -5 },
        -- les onglets latéraux (ceux du livre des métiers de ForeverUI)
        onglet = { cote = 55, y = -60, ecart = -2, icone = 50, iconeX = -3, rognage = 0.03125 },
        niveaux = { page = 1, onglets = 1, portrait = 19, metal = 20, titre = 21, croix = 22 },
    }

    -- RegisterUIPanel de camelot, plus whileDead (3.3.5 ne l'ouvre pas sans)
    local PANNEAU = { area = "left", xoffset = 35, pushable = 1, whileDead = 1, width = N.fenetre[1] + 85 }

    P.pages = {}
    P.ordre = {}

    -- ------------------------------------------------------------ la trousse

    -- LES ÉLÉMENTS, par leurs coordonnées dans les feuilles que ForeverUI
    -- installe (les éléments de camelot, aux tailles qu'il leur donne).
    -- art : { fichier, u1, u2, v1, v2, largeur, hauteur } ; decoupes : les
    -- éléments qui se découpent en morceaux (bouton rouge, croix, cadre
    -- intérieur), { fichier, u1, u2, v1, v2, largeur, hauteur, mosaïque
    -- horizontale, mosaïque verticale, découpe { gauche, haut, droite, bas } }.
    local K = { art = {}, decoupes = {} }
    P.Kit = K

    function K.AjouterArt(art, decoupes)
        for nom, e in pairs(art or {}) do K.art[nom] = e end
        for nom, e in pairs(decoupes or {}) do K.decoupes[nom] = e end
    end

    K.AjouterArt({
        ["!ui-frame-metal-edgeleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.001953, 0.373047, 0, 1, 95, 128 },
        ["!ui-frame-metal-edgeright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.376953, 0.748047, 0, 1, 95, 128 },
        ["_ui-frame-metal-edgebottom"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.001953, 0.392578, 128, 100 },
        ["_ui-frame-metal-edgetop"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.396484, 0.767578, 128, 95 },
        ["_ui-frame-toptilestreaks"] = { "interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0, 1, 0.007812, 0.34375, 256, 43 },
        ["common-sidetab"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.007812, 0.4375, 0.007812, 0.476562, 55, 60 },
        ["common-sidetab-hover"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.007812, 0.4375, 0.492188, 0.960938, 55, 60 },
        ["common-sidetab-selected"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.453125, 0.882812, 0.007812, 0.476562, 55, 60 },
        ["common-stat-bar-bg"] = { "interface\\ForeverUI\\common\\commonstatbarc60", 0.003906, 0.265625, 0.539062, 0.765625, 67, 29 },
        ["ui-frame-metal-cornerbottomleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.001953, 0.392578, 95, 100 },
        ["ui-frame-metal-cornerbottomright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.396484, 0.787109, 95, 100 },
        ["ui-frame-metal-cornertopright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.376953, 0.748047, 95, 95 },
        ["ui-frame-portraitmetal-cornertopleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.375977, 0.561523, 0.376953, 0.748047, 95, 95 },
    }, {
        ["redbutton-exit"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.007812, 0.257812, 32, 32, nil, nil },
        ["redbutton-exit-disabled"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.273438, 0.523438, 32, 32, nil, nil },
        ["redbutton-exit-pressed"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.539062, 0.789062, 32, 32, nil, nil },
        ["redbutton-highlight"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.402344, 0.527344, 0.007812, 0.257812, 32, 32, nil, nil },
    })

    -- la jauge des barres, celle de l'onglet Compétences : common-stat-bar-bg
    -- découpée à 10, 29 de haut, remplissage bleu de 15
    K.Jauge = { fond = "common-stat-bar-bg", coin = 10, hauteur = 29, remplissage = 15,
        fichier = ART .. "Bars" .. SEP .. "statbarfillblue" }

    function K.AtlasEntry(nom)
        return K.art[nom]
    end

    -- l'élément sur la texture ; garderTaille : sans lui, la texture prend
    -- sa taille. Rend vrai s'il est connu.
    function K.SetAtlas(t, nom, garderTaille)
        local e = K.art[nom]
        if not e then return false end
        t:SetTexture(e[1])
        t:SetTexCoord(e[2], e[3], e[4], e[5])
        if not garderTaille then
            t:SetWidth(e[6])
            t:SetHeight(e[7])
        end
        return true
    end

    function K.Montrer(r, oui)
        if oui then r:Show() else r:Hide() end
    end

    -- 3.3.5 rend 1 / nil, parfois 0 / 1 : zéro est vrai en Lua
    local function vrai(v)
        return v and v ~= 0 and true or false
    end

    -- EN NEUF : les coins gardent leur taille (coin), les bords ne s'étirent
    -- que dans un sens, le centre dans les deux ; marges { gauche, haut,
    -- droite, bas } : de combien l'image déborde du cadre. Rend les neuf
    -- morceaux, en régions du cadre, sur le calque donné.
    function K.NeufTranches(cadre, nom, coin, marges, calque)
        local e = K.art[nom]
        if not e then return nil end
        local du = (e[3] - e[2]) * coin / e[6]
        local dv = (e[5] - e[4]) * coin / e[7]
        local us = { e[2], e[2] + du, e[3] - du, e[3] }
        local vs = { e[4], e[4] + dv, e[5] - dv, e[5] }
        local morceaux = {}
        local function morceau(colonne, ligne)
            local t = cadre:CreateTexture(nil, calque or "BACKGROUND")
            t:SetTexture(e[1])
            t:SetTexCoord(us[colonne], us[colonne + 1], vs[ligne], vs[ligne + 1])
            morceaux[#morceaux + 1] = t
            return t
        end
        local hg, hd, bg, bd = morceau(1, 1), morceau(3, 1), morceau(1, 3), morceau(3, 3)
        local haut, bas = morceau(2, 1), morceau(2, 3)
        local gauche, droite = morceau(1, 2), morceau(3, 2)
        local centre = morceau(2, 2)
        for _, t in ipairs({ hg, hd, bg, bd }) do
            t:SetWidth(coin)
            t:SetHeight(coin)
        end
        haut:SetHeight(coin)
        bas:SetHeight(coin)
        gauche:SetWidth(coin)
        droite:SetWidth(coin)
        local G, H, D, B = marges[1], marges[2], marges[3], marges[4]
        hg:SetPoint("TOPLEFT", cadre, "TOPLEFT", -G, H)
        hd:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", D, H)
        bg:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", -G, -B)
        bd:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", D, -B)
        haut:SetPoint("TOPLEFT", hg, "TOPRIGHT")
        haut:SetPoint("TOPRIGHT", hd, "TOPLEFT")
        bas:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
        bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
        gauche:SetPoint("TOPLEFT", hg, "BOTTOMLEFT")
        gauche:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
        droite:SetPoint("TOPLEFT", hd, "BOTTOMLEFT")
        droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT")
        centre:SetPoint("TOPLEFT", hg, "BOTTOMRIGHT")
        centre:SetPoint("BOTTOMRIGHT", bd, "TOPLEFT")
        return morceaux
    end

    -- UN SÉPARATEUR VERTICAL EN TROIS : un embout en haut et en bas (embout
    -- pixels de l'image), le milieu tiré entre eux ; étirer l'élément entier
    -- étalerait ses embouts.
    function K.SeparateurVertical(parent, nom, embout, niveau)
        local e = K.art[nom]
        local cadre = CreateFrame("Frame", nil, parent)
        if not e then
            cadre:Hide()
            return cadre
        end
        embout = embout or 4
        cadre:SetWidth(e[6])
        cadre:SetFrameLevel(niveau or parent:GetFrameLevel())
        local dv = (e[5] - e[4]) * embout / e[7]
        local function tranche(v1, v2)
            local t = cadre:CreateTexture(nil, "OVERLAY")
            t:SetTexture(e[1])
            t:SetTexCoord(e[2], e[3], v1, v2)
            return t
        end
        local haut = tranche(e[4], e[4] + dv)
        haut:SetHeight(embout)
        haut:SetPoint("TOPLEFT", cadre, "TOPLEFT")
        haut:SetPoint("TOPRIGHT", cadre, "TOPRIGHT")
        local bas = tranche(e[5] - dv, e[5])
        bas:SetHeight(embout)
        bas:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT")
        bas:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT")
        local milieu = tranche(e[4] + dv, e[5] - dv)
        milieu:SetPoint("TOPLEFT", haut, "BOTTOMLEFT")
        milieu:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT")
        cadre.haut, cadre.milieu, cadre.bas = haut, milieu, bas
        return cadre
    end

    -- un élément à découper, posé sur une texture (sans changer sa taille) ;
    -- rend l'élément
    local function poserDecoupe(t, nom)
        local e = K.decoupes[nom]
        if not e then return nil end
        t:SetTexture(e[1])
        t:SetTexCoord(e[2], e[3], e[4], e[5])
        return e
    end

    -- L'ÉLÉMENT ÉTIRÉ. Un élément à découpe se pose en morceaux autour d'un
    -- rectangle invisible (rect) que la page ancre comme elle ancrerait
    -- l'élément : les marges gardent leur taille, le reste s'étire. Rend
    -- { rect, Poser(nom), Montrer(oui), Alpha(a) }.
    local function decouperEtire(obj)
        local e = obj.e
        local d = e[10]
        for _, t in ipairs(obj.morceaux) do t:Hide() end
        if not d then
            obj.rect:SetTexture(e[1])
            obj.rect:SetTexCoord(e[2], e[3], e[4], e[5])
            return
        end
        obj.rect:SetTexture(nil)
        local W, Ht = e[6], e[7]
        local g, h, dr, b = d[1], d[2], d[3], d[4]
        local us = { e[2], e[2] + (e[3] - e[2]) * g / W, e[3] - (e[3] - e[2]) * dr / W, e[3] }
        local vs = { e[4], e[4] + (e[5] - e[4]) * h / Ht, e[5] - (e[5] - e[4]) * b / Ht, e[5] }
        local largeurs, hauteurs = { g, nil, dr }, { h, nil, b }
        local r, n = obj.rect, 0
        for ligne = 1, 3 do
            for col = 1, 3 do
                local lw, lh = largeurs[col], hauteurs[ligne]
                if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
                    n = n + 1
                    local t = obj.morceaux[n]
                    if not t then
                        t = obj.hote:CreateTexture(nil, obj.calque)
                        obj.morceaux[n] = t
                    end
                    t:SetTexture(e[1])
                    t:SetTexCoord(us[col], us[col + 1], vs[ligne], vs[ligne + 1])
                    t:ClearAllPoints()
                    if col == 1 then
                        t:SetPoint("LEFT", r, "LEFT")
                        t:SetWidth(lw)
                    elseif col == 3 then
                        t:SetPoint("RIGHT", r, "RIGHT")
                        t:SetWidth(lw)
                    else
                        t:SetPoint("LEFT", r, "LEFT", g, 0)
                        t:SetPoint("RIGHT", r, "RIGHT", -dr, 0)
                    end
                    if ligne == 1 then
                        t:SetPoint("TOP", r, "TOP")
                        t:SetHeight(lh)
                    elseif ligne == 3 then
                        t:SetPoint("BOTTOM", r, "BOTTOM")
                        t:SetHeight(lh)
                    else
                        t:SetPoint("TOP", r, "TOP", 0, -h)
                        t:SetPoint("BOTTOM", r, "BOTTOM", 0, b)
                    end
                    if obj.visible ~= false then t:Show() end
                end
            end
        end
        obj.nombre = n
    end

    function K.AtlasEtire(hote, nom, calque)
        local obj = { hote = hote, calque = calque or "ARTWORK", morceaux = {} }
        obj.rect = hote:CreateTexture(nil, obj.calque)
        function obj:Poser(n)
            self.e = K.decoupes[n]
            decouperEtire(self)
        end
        function obj:Montrer(oui)
            self.visible = oui and true or false
            if self.e[10] then
                for i = 1, self.nombre or 0 do K.Montrer(self.morceaux[i], oui) end
            else
                K.Montrer(self.rect, oui)
            end
        end
        function obj:Alpha(a)
            self.rect:SetAlpha(a)
            for _, t in ipairs(self.morceaux) do t:SetAlpha(a) end
        end
        obj:Poser(nom)
        return obj
    end

    -- efface l'art que le client 3.3.5 pose sur ses propres boutons
    local function effacerArt(b)
        for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            local t = b[lire] and b[lire](b)
            if t then t:SetTexture(nil) end
        end
    end

    -- LE BOUTON ROUGE (ThreeSliceButtonTemplate) : voir le relevé plus haut.
    local function rogner(t, e, gaucheVersDroite, part)
        local u1, u2 = e[2], e[3]
        if gaucheVersDroite then
            t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
        else
            t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
        end
    end

    local function peindreTrois(b, etat)
        local r = b.trois
        if not vrai(b:IsEnabled()) then etat = "DISABLED" end
        local suffixe = (etat == "DISABLED" and "-disabled") or (etat == "PUSHED" and "-pressed") or ""
        local eg = poserDecoupe(r.gauche, r.atlas .. "-left" .. suffixe)
        poserDecoupe(r.centre, "_" .. r.atlas .. "-center" .. suffixe)
        local ed = poserDecoupe(r.droite, r.atlas .. "-right" .. suffixe)
        -- UpdateScale
        local hauteur, largeur = b:GetHeight(), b:GetWidth()
        local echelle = hauteur / eg[7]
        local lg, ld = eg[6] * echelle, ed[6] * echelle
        if lg + ld > largeur then
            local surplus = lg + ld - largeur
            local ng, nd = lg, ld
            if (lg - surplus) > ld then
                ng = lg - surplus
            elseif (ld - surplus) > lg then
                nd = ld - surplus
            else
                if lg ~= ld then
                    surplus = surplus - math.abs(lg - ld)
                    ng = math.min(lg, ld)
                    nd = ng
                end
                ng = ng - surplus / 2
                nd = nd - surplus / 2
            end
            rogner(r.gauche, eg, true, ng / lg)
            rogner(r.droite, ed, false, nd / ld)
            lg, ld = ng, nd
        end
        r.gauche:SetWidth(lg)
        r.gauche:SetHeight(hauteur)
        r.droite:SetWidth(ld)
        r.droite:SetHeight(hauteur)
        r.actif = vrai(b:IsEnabled())
    end

    -- atlas : le nom de l'élément, sans son suffixe (« 128-redbutton ») ;
    -- polices : { normale, survol, grisée }, des objets police
    function K.BoutonTroisTranches(b, atlas, polices)
        effacerArt(b)
        local r = { atlas = atlas }
        r.gauche = b:CreateTexture(nil, "BACKGROUND")
        r.gauche:SetPoint("TOPLEFT", b, "TOPLEFT")
        r.droite = b:CreateTexture(nil, "BACKGROUND")
        r.droite:SetPoint("TOPRIGHT", b, "TOPRIGHT")
        r.centre = b:CreateTexture(nil, "BACKGROUND")
        r.centre:SetPoint("TOPLEFT", r.gauche, "TOPRIGHT")
        r.centre:SetPoint("BOTTOMRIGHT", r.droite, "BOTTOMLEFT")
        b.trois = r
        -- la lueur, sur tout le bouton, en ADD
        b:SetHighlightTexture(K.decoupes[atlas .. "-highlight"][1])
        local lueur = b:GetHighlightTexture()
        poserDecoupe(lueur, atlas .. "-highlight")
        lueur:ClearAllPoints()
        lueur:SetAllPoints(b)
        lueur:SetBlendMode("ADD")
        if polices then
            b:SetNormalFontObject(polices[1])
            b:SetHighlightFontObject(polices[2] or polices[1])
            b:SetDisabledFontObject(polices[3] or polices[1])
        end
        local texte = b:GetFontString()
        if texte then
            texte:ClearAllPoints()
            texte:SetPoint("CENTER", b, "CENTER", 0, 0)
        end
        b:SetPushedTextOffset(-2, -1)
        b:HookScript("OnMouseDown", function(self)
            if vrai(self:IsEnabled()) then peindreTrois(self, "PUSHED") end
        end)
        b:HookScript("OnMouseUp", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnShow", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnSizeChanged", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnEnable", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnDisable", function(self) peindreTrois(self, "NORMAL") end)
        peindreTrois(b, "NORMAL")
        return b
    end

    -- la croix (UIPanelCloseButton) : voir le relevé plus haut
    local function croix(b, fenetre)
        b:SetWidth(24)
        b:SetHeight(24)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", fenetre, "TOPRIGHT", -2, 1)
        for _, v in ipairs({
            { "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
            { "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
            { "SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled" },
            { "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
        }) do
            b[v[1]](b, K.decoupes[v[3]][1])
            local t = b[v[2]](b)
            poserDecoupe(t, v[3])
            t:ClearAllPoints()
            t:SetAllPoints(b)
            if v[1] == "SetHighlightTexture" then t:SetBlendMode("ADD") end
        end
        return b
    end

    -- le cadre (PortraitFrameTemplate) : voir le relevé plus haut
    local function habiller(f, portrait)
        local R = N.roche
        local roche = f:CreateTexture(nil, "BACKGROUND")
        roche:SetTexture(R.fichier, true)
        if roche.SetHorizTile then
            roche:SetHorizTile(true)
            roche:SetVertTile(true)
        end
        roche:SetPoint("TOPLEFT", f, "TOPLEFT", R[1], R[2])
        roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", R[3], R[4])
        local stries = f:CreateTexture(nil, "BACKGROUND")
        K.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
        stries:SetHeight(N.stries[1])
        stries:SetPoint("TOPLEFT", f, "TOPLEFT", N.stries.x, N.stries.y)
        stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.stries.x2, N.stries.y)
        local metal = CreateFrame("Frame", nil, f)
        metal:SetAllPoints(f)
        metal:SetFrameLevel(f:GetFrameLevel() + N.niveaux.metal)
        local coins = {}
        for i, coin in ipairs(N.metal) do
            local t = metal:CreateTexture(nil, "OVERLAY")
            K.SetAtlas(t, coin.nom)
            t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
            coins[i] = t
        end
        local function bord(nom, a1, c1, r1, a2, c2, r2)
            local t = metal:CreateTexture(nil, "OVERLAY")
            K.SetAtlas(t, nom)
            t:SetPoint(a1, c1, r1)
            t:SetPoint(a2, c2, r2)
        end
        bord("_ui-frame-metal-edgetop", "TOPLEFT", coins[1], "TOPRIGHT", "TOPRIGHT", coins[2], "TOPLEFT")
        bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", coins[3], "BOTTOMRIGHT", "BOTTOMRIGHT", coins[4], "BOTTOMLEFT")
        bord("!ui-frame-metal-edgeleft", "TOPLEFT", coins[1], "BOTTOMLEFT", "BOTTOMLEFT", coins[3], "TOPLEFT")
        bord("!ui-frame-metal-edgeright", "TOPRIGHT", coins[2], "BOTTOMRIGHT", "BOTTOMRIGHT", coins[4], "TOPRIGHT")
        local cadrePortrait = CreateFrame("Frame", nil, f)
        cadrePortrait:SetAllPoints(f)
        cadrePortrait:SetFrameLevel(f:GetFrameLevel() + N.niveaux.portrait)
        local Pt = N.portrait
        local image = cadrePortrait:CreateTexture(nil, "OVERLAY")
        image:SetWidth(Pt[1])
        image:SetHeight(Pt[1])
        image:SetPoint("TOPLEFT", f, "TOPLEFT", Pt.x, Pt.y)
        image:SetTexture(portrait)
        local T = N.titre
        local bandeau = CreateFrame("Frame", nil, f)
        bandeau:SetFrameLevel(f:GetFrameLevel() + N.niveaux.titre)
        bandeau:SetHeight(T.h)
        bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", T.x1, T.y)
        bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", T.x2, T.y)
        local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titre:SetPoint("TOP", bandeau, "TOP", 0, T.texteY)
        titre:SetText("")
        -- 45 x 62, la région utile de l'image
        image:SetHeight(Pt[2])
        image:SetTexCoord(Pt.coords[1], Pt.coords[2], Pt.coords[3], Pt.coords[4])
        -- le fond noir du cercle, sous le portrait (même cadre, calque inférieur)
        local D = N.disque
        local disque = cadrePortrait:CreateTexture(nil, "ARTWORK")
        disque:SetTexture(D.fichier)
        disque:SetVertexColor(0, 0, 0, 1)
        disque:SetWidth(D[1])
        disque:SetHeight(D[1])
        disque:SetPoint("TOPLEFT", f, "TOPLEFT", D.x, D.y)
        return { roche = roche, stries = stries, metal = metal, portrait = image, titre = titre,
            bandeau = bandeau, cadrePortrait = cadrePortrait, disque = disque }
    end

    local function poser(r, ...)
        r:ClearAllPoints()
        r:SetPoint(...)
    end

    local function texte(v)
        if type(v) == "function" then return v() end
        return v
    end

    -- LE MICRO-BOUTON, dans la micro-barre de ForeverUI : demandé dès qu'une
    -- page existe (ForeverUI.AddMicroButton le crée une fois, après les
    -- talents, avec son jeu d'icônes Legacy ; en combat, à la sortie du
    -- combat), enfoncé tant que la fenêtre est ouverte.
    local majMicro
    local MICRO = {
        name = BOUTON, atlasSet = "legacy", after = "TalentMicroButton",
        tooltip = function() return texte(P.nom) or "" end,
        onClick = function() P.Basculer() end,
        ready = function() majMicro() end,
    }
    majMicro = function()
        if #P.ordre > 0 then
            ForeverUI.AddMicroButton(MICRO)
        end
        if ForeverUI.UpdateMicro then
            ForeverUI.UpdateMicro(BOUTON, (P.fenetre and P.fenetre:IsShown()) and true or false)
        end
    end

    -- ------------------------------------------------------------ les onglets

    local function creerOnglet(f, k)
        local O = N.onglet
        local b = CreateFrame("Button", "ProgressionTab" .. k, f)
        b:SetWidth(O.cote)
        b:SetHeight(O.cote)
        b:SetFrameLevel(f:GetFrameLevel() + N.niveaux.onglets)
        b:RegisterForClicks("LeftButtonUp")
        local fond = b:CreateTexture(nil, "BACKGROUND")
        K.SetAtlas(fond, "common-sidetab", true)
        fond:SetAllPoints(b)
        local icone = b:CreateTexture(nil, "ARTWORK")
        icone:SetWidth(O.icone)
        icone:SetHeight(O.icone)
        icone:SetPoint("CENTER", b, "CENTER", O.iconeX, 0)
        icone:SetTexCoord(O.rognage, 1 - O.rognage, O.rognage, 1 - O.rognage)
        local choisi = b:CreateTexture(nil, "OVERLAY")
        K.SetAtlas(choisi, "common-sidetab-selected", true)
        choisi:SetAllPoints(b)
        choisi:Hide()
        local survol = b:CreateTexture(nil, "HIGHLIGHT")
        K.SetAtlas(survol, "common-sidetab-hover", true)
        survol:SetAllPoints(b)
        b.icone, b.choisi = icone, choisi
        b:SetScript("OnEnter", function(self)
            local d = P.pages[self.cle or ""]
            if not d then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
            GameTooltip:SetText(texte(d.titre) or "")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnMouseDown", function(self, bouton)
            if bouton == "LeftButton" then poser(self.icone, "CENTER", self, "CENTER", O.iconeX + 1, -1) end
        end)
        b:SetScript("OnMouseUp", function(self, bouton)
            if bouton == "LeftButton" then
                poser(self.icone, "CENTER", self, "CENTER", O.iconeX, 0)
                PlaySound("igCharacterInfoTab")
            end
        end)
        b:SetScript("OnClick", function(self)
            if self.cle then P.Choisir(self.cle) end
        end)
        if k == 1 then
            b:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, O.y)
        else
            b:SetPoint("TOPLEFT", f.onglets[k - 1], "BOTTOMLEFT", 0, O.ecart)
        end
        return b
    end

    local function majOnglets()
        local f = P.fenetre
        if not f then return end
        for k, cle in ipairs(P.ordre) do
            local d = P.pages[cle]
            local b = f.onglets[k] or creerOnglet(f, k)
            f.onglets[k] = b
            b.cle = cle
            b.icone:SetTexture(d.icone)
            K.Montrer(b.choisi, cle == P.courante)
            b:Show()
        end
        for k = #P.ordre + 1, #f.onglets do f.onglets[k]:Hide() end
    end

    -- ------------------------------------------------------------ la fenêtre

    function P.Construire(portrait)
        if P.fenetre then return P.fenetre end
        local f = CreateFrame("Frame", "ProgressionFrame", UIParent)
        f:SetWidth(N.fenetre[1])
        f:SetHeight(N.fenetre[2])
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:Hide()
        -- le panneau, déclaré par ses attributs (GetUIPanelWindowInfo les lit
        -- avant la table UIPanelWindows)
        for k, v in pairs(PANNEAU) do
            f:SetAttribute("UIPanelLayout-" .. k, v)
        end
        f:SetAttribute("UIPanelLayout-defined", true)
        f:SetAttribute("UIPanelLayout-enabled", true)
        local habit = habiller(f, portrait)
        f.habit = habit
        local b = CreateFrame("Button", "ProgressionFrameCloseButton", f, "UIPanelCloseButton")
        croix(b, f)
        b:SetFrameLevel(f:GetFrameLevel() + N.niveaux.croix)
        f.croix = b
        f.onglets = {}
        f:SetScript("OnShow", function()
            habit.titre:SetText(texte(P.nom) or "")
            PlaySound("igCharacterInfoOpen")
            majMicro()
        end)
        f:SetScript("OnHide", function()
            PlaySound("igCharacterInfoClose")
            majMicro()
        end)
        P.fenetre = f
        return f
    end

    -- SelectPage : la page clé se montre (construite à sa première ouverture),
    -- les autres se cachent, son onglet est coché
    function P.Choisir(cle)
        local d = P.pages[cle]
        if not d then return end
        if not d.construite then
            d.construite = true
            d.construire(d.page)
        end
        for _, c in ipairs(P.ordre) do
            if c ~= cle then P.pages[c].page:Hide() end
        end
        P.courante = cle
        d.page:Show()
        majOnglets()
    end

    -- tri des onglets : ordre, puis clé
    local function avant(a, b)
        local x, y = P.pages[a], P.pages[b]
        if x.ordre ~= y.ordre then return x.ordre < y.ordre end
        return a < b
    end

    function P.Ajouter(d)
        if type(d) ~= "table" or type(d.cle) ~= "string" or type(d.construire) ~= "function" then return nil end
        local f = P.Construire(d.portrait)
        P.nom = P.nom or d.nomFenetre
        local ancienne = P.pages[d.cle]
        local montree = ancienne and ancienne.page:IsShown() and f:IsShown()
        if ancienne then
            ancienne.page:Hide()
        else
            table.insert(P.ordre, d.cle)
        end
        local page = CreateFrame("Frame", nil, f)
        page:SetAllPoints(f)
        page:SetFrameLevel(f:GetFrameLevel() + N.niveaux.page)
        page:Hide()
        P.pages[d.cle] = {
            cle = d.cle, ordre = tonumber(d.ordre) or 100, titre = d.titre or d.cle, icone = d.icone,
            construire = d.construire, page = page,
        }
        table.sort(P.ordre, avant)
        if montree then P.Choisir(d.cle) end
        majOnglets()
        majMicro()
        return page
    end

    -- ToggleLegacySystemUI : la page clé (sinon la dernière montrée, sinon la
    -- première)
    function P.Ouvrir(cle)
        if #P.ordre == 0 then return end
        local f = P.Construire()
        if not (cle and P.pages[cle]) then
            cle = (P.courante and P.pages[P.courante]) and P.courante or P.ordre[1]
        end
        if not f:IsShown() then ShowUIPanel(f) end
        if f:IsShown() and not (P.courante == cle and P.pages[cle].page:IsShown()) then
            P.Choisir(cle)
        end
    end

    function P.Fermer()
        if P.fenetre and P.fenetre:IsShown() then HideUIPanel(P.fenetre) end
    end

    -- la fenêtre ouverte sur cette page (ou sur toute page, sans clé) se ferme ;
    -- sinon elle s'ouvre sur elle
    function P.Basculer(cle)
        local f = P.fenetre
        if f and f:IsShown() and (not cle or cle == P.courante) then
            P.Fermer()
        else
            P.Ouvrir(cle)
        end
    end

    function P.Montree(cle)
        local f = P.fenetre
        return (f and f:IsShown() and P.courante == cle) and true or false
    end
end
-- ---------------------------------------------------------------------------
-- FIN DE LA FENÊTRE PROGRESSION (copie commune)
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- The sheet of the companion mount
--
-- Who it is (icon, name, kind, tree), its level and experience, its numbers
-- (the module writes them on request: `.companion snapshot`), its orders, and
-- the doors to its talents and saddlebags. It lives in a tab of the
-- Progression window when ForeverUI is installed (as Attriboost and Item
-- Upgrade do), else in a window of its own opened by a button at the edge of
-- the minimap.
-- ---------------------------------------------------------------------------

local UI = {
    sheet = { level = 0 },
    rows = {},
    orders = {},
    KINDS = {
        FR and "Cheval" or "Horse", FR and "Mort-vivant" or "Undead", FR and "Loup" or "Wolf",
        FR and "Félin" or "Feline", "Raptor", FR and "Bête lourde" or "Heavy beast", FR and "Ours" or "Bear",
        FR and "Oiseau" or "Bird", FR and "Dragon" or "Dragon", FR and "Bête ailée" or "Winged beast",
        FR and "Insecte" or "Insect", FR and "Machine" or "Machine",
    },
    -- The Progression tab: its key, its place (after Attriboost and Item
    -- Upgrade), its icon (a picture ForeverUI installs).
    CLE = "companionmount", ORDRE = 3,
    ONGLET_ICONE = OPath("Interface", "ForeverUI", "tabicons", "ability_hunter_beasttaming"),
    -- The minimap button, the standard 3.3.5 composition, at a fixed angle
    -- (Attriboost takes 120, Item Upgrade 155).
    MM_ANGLE = 190, MM_RAYON = 80, MM_TAILLE = 31,
    MM_FOND = OPath("Interface", "Minimap", "UI-Minimap-Background"),
    MM_BORDURE = OPath("Interface", "Minimap", "MiniMap-TrackingBorder"),
    MM_SURVOL = OPath("Interface", "Minimap", "UI-Minimap-ZoomButton-Highlight"),
    MM_ICONE = OPath("Interface", "Icons", "Ability_Mount_RidingHorse"),
}

local SL = {
    stateOut   = FR and "À vos côtés" or "At your side",
    stateWait  = FR and "En attente (elle ne sort qu'en extérieur, quand vous êtes à pied)"
                     or "Waiting (it only comes out of doors, while you walk)",
    stateStable = FR and "À l'écurie" or "In the stable",
    noMount    = FR and "Aucune monture-compagnon : montez une monture et cliquez sur Appeler."
                     or "No companion mount: ride a mount and click Call.",
    level      = FR and "Niveau %d" or "Level %d",
    xp         = FR and "%d / %d points d'expérience" or "%d / %d experience",
    xpMax      = FR and "Niveau maximal pour l'instant" or "Highest level for now",
    health     = FR and "Points de vie" or "Health",
    armor      = FR and "Armure" or "Armor",
    power      = FR and "Puissance d'attaque" or "Attack power",
    damage     = FR and "Dégâts" or "Damage",
    speed      = FR and "Vitesse d'attaque" or "Attack speed",
    crit       = FR and "Coups critiques" or "Critical strike",
    dodge      = FR and "Esquive" or "Dodge",
    parry      = FR and "Parade" or "Parry",
    points     = FR and "Points de talent" or "Talent points",
    orders     = FR and "Ordres" or "Orders",
    stats      = FR and "Caractéristiques" or "Statistics",
    progression = "Progression",
    mmTip      = FR and "Clic : la fiche de votre monture-compagnon." or "Click: the sheet of your companion mount.",
}

local function Percent(v) return string.format("%.2f %%", tonumber(v) or 0) end

-- The content, in any frame: the Progression page or the window.
function UI.Build(parent)
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -40)
    root:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -24, 20)
    UI.root = root

    -- Who it is.
    local icon = root:CreateTexture(nil, "ARTWORK")
    icon:SetSize(52, 52)
    icon:SetPoint("TOPLEFT", 0, 0)
    UI.icon = icon
    local frameTex = root:CreateTexture(nil, "OVERLAY")
    frameTex:SetTexture(OPath("Interface", "Buttons", "UI-Quickslot2"))
    frameTex:SetSize(88, 88)
    frameTex:SetPoint("CENTER", icon, "CENTER", 0, -1)

    UI.name = root:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -2)
    UI.subtitle = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.subtitle:SetPoint("TOPLEFT", UI.name, "BOTTOMLEFT", 0, -4)
    UI.status = root:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.status:SetPoint("TOPLEFT", UI.subtitle, "BOTTOMLEFT", 0, -4)

    -- Its level and experience: the pet's purple bar.
    UI.levelText = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.levelText:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -18)
    local xp = CreateFrame("StatusBar", nil, root)
    xp:SetSize(290, 14)
    xp:SetPoint("TOPLEFT", UI.levelText, "BOTTOMLEFT", 0, -6)
    xp:SetStatusBarTexture(OPath("Interface", "TargetingFrame", "UI-StatusBar"))
    xp:SetStatusBarColor(0.58, 0.0, 0.55)
    local xpBack = xp:CreateTexture(nil, "BACKGROUND")
    xpBack:SetAllPoints()
    xpBack:SetTexture(0, 0, 0, 0.5)
    local xpBorder = CreateFrame("Frame", nil, xp)
    xpBorder:SetPoint("TOPLEFT", -3, 3)
    xpBorder:SetPoint("BOTTOMRIGHT", 3, -3)
    xpBorder:SetBackdrop({ edgeFile = OPath("Interface", "Tooltips", "UI-Tooltip-Border"), edgeSize = 10 })
    UI.xpText = xp:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.xpText:SetPoint("CENTER")
    UI.xp = xp

    -- Its numbers, label left, value right.
    local statsTitle = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsTitle:SetPoint("TOPLEFT", xp, "BOTTOMLEFT", 0, -18)
    statsTitle:SetText(SL.stats)
    local labels = { "health", "armor", "power", "damage", "speed", "crit", "dodge", "parry", "points" }
    for i, key in ipairs(labels) do
        local label = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 6, -8 - (i - 1) * 18)
        label:SetText(SL[key])
        local value = root:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetPoint("RIGHT", label, "LEFT", 284, 0)
        value:SetJustifyH("RIGHT")
        UI.rows[key] = value
        local line = root:CreateTexture(nil, "BACKGROUND")
        line:SetTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0.08)
        line:SetPoint("TOPLEFT", label, "TOPLEFT", -6, 3)
        line:SetSize(290, 18)
    end

    -- Its orders, on the right.
    local ordersTitle = root:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ordersTitle:SetPoint("TOPLEFT", root, "TOPLEFT", 340, -88)
    ordersTitle:SetText(SL.orders)
    for i, def in ipairs(BUTTONS) do
        local b = CreateFrame("CheckButton", nil, root)
        b:SetSize(36, 36)
        local row, col = math.floor((i - 1) / 4), (i - 1) % 4
        b:SetPoint("TOPLEFT", ordersTitle, "BOTTOMLEFT", col * 46, -10 - row * 46)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(def.icon)
        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetTexture(OPath("Interface", "Buttons", "UI-Quickslot2"))
        border:SetSize(62, 62)
        border:SetPoint("CENTER", 0, -1)
        b:SetHighlightTexture(OPath("Interface", "Buttons", "ButtonHilight-Square"), "ADD")
        b:SetCheckedTexture(OPath("Interface", "Buttons", "CheckButtonHilight"))
        b:SetPushedTexture(OPath("Interface", "Buttons", "UI-Quickslot-Depress"))
        b.def = def
        b:SetScript("OnClick", function(self)
            if self.def.popup then
                self:SetChecked(false)
                StaticPopup_Show(self.def.popup)
                return
            end
            AIO.Handle("CompanionMount", "Order", self.def.order)
            self:SetChecked(self.def.lit and self.def.lit() or false)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.def.text, 1, 1, 1)
            GameTooltip:AddLine(self.def.tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        UI.orders[i] = b
    end

    -- The doors to its talents and saddlebags.
    local talents = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    talents:SetSize(130, 26)
    talents:SetPoint("TOPLEFT", ordersTitle, "BOTTOMLEFT", 0, -160)
    talents:SetText(L.talents)
    talents:SetScript("OnClick", function() CompanionMount_ToggleTalents() end)
    local bag = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    bag:SetSize(130, 26)
    bag:SetPoint("LEFT", talents, "RIGHT", 10, 0)
    bag:SetText(L.bag)
    bag:SetScript("OnClick", function() CompanionMount_ToggleBag() end)

    -- While it is shown, the numbers follow the fight.
    local elapsed = 0
    root:SetScript("OnShow", function() UI.Request() end)
    root:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 2 then
            elapsed = 0
            UI.Request()
        end
    end)
    UI.Refresh()
    return root
end

function UI.Request()
    AIO.Handle("CompanionMount", "SheetOpen")
end

function UI.Refresh()
    if not UI.root then return end
    local s = UI.sheet
    local mount = tonumber(s.mount_spell) or 0
    local name, _, spellIcon = GetSpellInfo(mount)
    UI.icon:SetTexture(spellIcon or UI.MM_ICONE)
    if mount == 0 then
        UI.name:SetText(L.title)
        UI.subtitle:SetText(SL.noMount)
        UI.status:SetText("")
    else
        UI.name:SetText((s.name and s.name ~= "") and s.name or (name or L.title))
        local tree = ({ L.treeDps, L.treeTank, L.treeHeal })[(tonumber(s.tree) or 255) + 1] or L.noTree
        UI.subtitle:SetText((UI.KINDS[tonumber(s.kind) or 0] or "") .. "  -  " .. (name or "") .. "  -  " .. tree)
        UI.status:SetText(s.out == 1 and SL.stateOut or (state.summoned and SL.stateWait or SL.stateStable))
    end

    local level = tonumber(s.level) or 0
    UI.levelText:SetText(string.format(SL.level, level))
    local nextXp = tonumber(s.xp_next) or 0
    UI.xp:SetMinMaxValues(0, math.max(1, nextXp))
    UI.xp:SetValue(tonumber(s.xp) or 0)
    if level == 0 then
        UI.xpText:SetText("")
    elseif nextXp > 0 and (tonumber(s.points_total) or 0) >= 0 and level < (UnitLevel("player") or level) then
        UI.xpText:SetText(string.format(SL.xp, tonumber(s.xp) or 0, nextXp))
    else
        UI.xpText:SetText(SL.xpMax)
    end

    local out = s.out == 1
    UI.rows.health:SetText(out and (s.health .. " / " .. s.max_health) or "-")
    UI.rows.armor:SetText(out and s.armor or "-")
    UI.rows.power:SetText(out and s.attack_power or "-")
    UI.rows.damage:SetText(out and (s.min_damage .. " - " .. s.max_damage) or "-")
    UI.rows.speed:SetText(out and string.format("%.2f", (tonumber(s.attack_time) or 0) / 1000) or "-")
    UI.rows.crit:SetText(out and Percent(s.crit) or "-")
    UI.rows.dodge:SetText(out and Percent(s.dodge) or "-")
    UI.rows.parry:SetText(out and Percent(s.parry) or "-")
    UI.rows.points:SetText((s.points_spent or 0) .. " / " .. (s.points_total or 0))

    for _, b in ipairs(UI.orders) do
        local usable = not b.def.needsOut or state.summoned
        b:SetChecked(b.def.lit and b.def.lit() or false)
        b.icon:SetDesaturated(not usable)
    end
end

-- ---------------------------------------------------------------------------
-- The hosts: a tab of the Progression window, or a window and a minimap button
-- ---------------------------------------------------------------------------

function UI.CreateWindow()
    local f = CreateFrame("Frame", "CompanionMountFrame", UIParent)
    f:SetSize(690, 470)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if LibWindow then LibWindow.SavePosition(self) end
    end)
    f:SetBackdrop({
        bgFile = OPath("Interface", "DialogFrame", "UI-DialogBox-Background"),
        edgeFile = OPath("Interface", "DialogFrame", "UI-DialogBox-Gold-Border"),
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    f:Hide()
    tinsert(UISpecialFrames, "CompanionMountFrame")
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture(OPath("Interface", "DialogFrame", "UI-DialogBox-Header"))
    header:SetSize(320, 64)
    header:SetPoint("TOP", 0, 12)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", header, "TOP", 0, -14)
    title:SetText(L.title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    f:SetScript("OnShow", function() PlaySound("igCharacterInfoOpen") end)
    f:SetScript("OnHide", function() PlaySound("igCharacterInfoClose") end)
    UI.Build(f)
    UI.window = f
    -- A size is set: LibWindow may read the position.
    AIO.SavePosition(f, true)
end

function UI.CreateMinimapButton()
    if not Minimap then return end
    -- `.reload ale` runs the file again: the button already there is reused.
    local b = _G["CompanionMountMiniButton"]
    if not b then
        b = CreateFrame("Button", "CompanionMountMiniButton", Minimap)
        b:SetWidth(UI.MM_TAILLE); b:SetHeight(UI.MM_TAILLE)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
        local fond = b:CreateTexture(nil, "BACKGROUND")
        fond:SetTexture(UI.MM_FOND)
        fond:SetWidth(20); fond:SetHeight(20)
        fond:SetPoint("CENTER", 0, 0)
        b.icone = b:CreateTexture(nil, "ARTWORK")
        b.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.icone:SetWidth(18); b.icone:SetHeight(18)
        b.icone:SetPoint("CENTER", 0, 0)
        local bordure = b:CreateTexture(nil, "OVERLAY")
        bordure:SetTexture(UI.MM_BORDURE)
        bordure:SetWidth(53); bordure:SetHeight(53)
        bordure:SetPoint("CENTER", 11, -12)
        b:SetHighlightTexture(UI.MM_SURVOL)
        local a = math.rad(UI.MM_ANGLE)
        b:SetPoint("CENTER", Minimap, "CENTER", UI.MM_RAYON * math.cos(a), UI.MM_RAYON * math.sin(a))
    end
    b.icone:SetTexture(UI.MM_ICONE)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.title)
        GameTooltip:AddLine(SL.mmTip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function() CompanionMount_Toggle() end)
end

-- With the Progression window (ForeverUI present), a tab replaces the window
-- and the minimap button.
if Progression and Progression.Ajouter and Progression.Kit then
    UI.page = Progression.Ajouter({
        cle = UI.CLE, ordre = UI.ORDRE, icone = UI.ONGLET_ICONE,
        titre = function() return L.title end,
        nomFenetre = function() return SL.progression end,
        construire = function(page) UI.Build(page) end,
    })
end
if not UI.page then
    UI.CreateWindow()
    UI.CreateMinimapButton()
end

function CompanionMount_Toggle()
    if UI.page then
        Progression.Basculer(UI.CLE)
    elseif UI.window then
        if UI.window:IsShown() then UI.window:Hide() else UI.window:Show() end
    end
end

-- ---------------------------------------------------------------------------
-- The server
-- ---------------------------------------------------------------------------

function Handlers.State(_, newState)
    if type(newState) ~= "table" then return end
    state = newState
    UI.Refresh()
end

function Handlers.Sheet(_, sheet)
    if type(sheet) ~= "table" then return end
    UI.sheet = sheet
    state.command = tonumber(sheet.command_state) or state.command
    state.react = tonumber(sheet.react_state) or state.react
    state.mount = tonumber(sheet.mount_spell) or state.mount
    UI.Refresh()
end

SLASH_COMPANIONMOUNT1 = "/companion"
SLASH_COMPANIONMOUNT2 = "/compagnon"
SlashCmdList["COMPANIONMOUNT"] = function() CompanionMount_Toggle() end

AIO.Handle("CompanionMount", "Hello")
