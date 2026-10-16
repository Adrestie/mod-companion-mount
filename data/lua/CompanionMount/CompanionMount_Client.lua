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

    THE COMPANION PANEL: its own window, a Statistics tab (the 3D view and its
    figures, as the character sheet) and a Gambits tab. With ForeverUI, in its
    theme and opened by a micro button of its bar; without, in the game's
    theme and opened by a button at the edge of the minimap. /companion or
    /compagnon opens it too. THE BAR: its orders and its spells. THE PORTRAIT,
    the saddlebags, the talents.

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
    sheet      = ({ frFR = "Fiche", deDE = "Werte", esES = "Ficha", esMX = "Ficha", ruRU = "Сведения" })[GetLocale()] or "Sheet",
    moveTip    = FR and "Maj + glisser : déplacer la barre" or "Shift + drag: move the bar",
    autoOn     = FR and "Lancement automatique : activé" or "Autocast: on",
    autoOff    = FR and "Lancement automatique : désactivé" or "Autocast: off",
    spellTip   = FR and "Clic gauche : lancer. Clic droit : lancement automatique ou non."
                     or "Left click: cast. Right click: autocast on or off.",
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
    inTree     = FR and "%s : %d" or "%s: %d",
    available  = FR and "Points de talent disponibles : |cff00ff00%d|r  (monture niveau %d)"
                     or "Talent points available: |cff00ff00%d|r  (mount level %d)",
    bagTip     = FR and "Ouvre les sacoches de la monture : glissez-y un objet de vos sacs, cliquez sur un objet pour le reprendre."
                     or "Opens the saddlebags of the mount: drop an item of your bags on them, click an item to take it back.",
}

-- ---------------------------------------------------------------------------
-- ENERGY, PORTRAIT AND GAMBITS (docs/energie-gambits.md): texts in five
-- languages.
-- ---------------------------------------------------------------------------

local G_TEXTS = {
    enUS = {
        panelTitle = "Companion", tabStats = "Statistics",
        gambits = "Gambits", gambitsTip = "The rules of your companion: target and condition, then action, read from top to bottom.",
        help = "Read from top to bottom: the first rule whose condition holds and whose action is possible is played.",
        energy = "Energy", cost = "Energy cost: %d", locked = "Level %d", reset = "Reset",
        defaultList = "Default list (drawn from the spells learned)", customList = "Your list",
        pickCondition = "Choose a condition", pickAction = "Choose an action", empty = "(empty)", clear = "Clear the rule",
        attack = "Attack", comeBack = "Come back to you", up = "Up", down = "Down", enable = "On / off",
        portraitTip = "Click: target your companion. Shift + drag: move.",
        cat = { "You", "Companion", "Enemy", "Group", "Fight" },
        cond = {
            [1] = "HP < 30%", [2] = "HP < 50%", [3] = "HP < 70%", [4] = "HP < 90%", [5] = "Under attack",
            [6] = "Poisoned", [7] = "Diseased", [8] = "Magic effect", [9] = "Cursed",
            [10] = "HP < 30%", [11] = "HP < 50%", [12] = "HP < 70%", [13] = "Energy >= 40", [14] = "Energy >= 60", [15] = "Energy >= 80",
            [20] = "Your target", [21] = "Its target", [22] = "Nearest", [23] = "Attacking you", [24] = "HP < 20%",
            [25] = "HP < 35%", [26] = "HP < 50%", [27] = "HP >= 90%", [28] = "Casting", [29] = "Elite or boss",
            [30] = "A member HP < 50%", [31] = "3 members HP < 70%",
            [40] = "2+ enemies around", [41] = "3+ enemies around", [42] = "5+ enemies around", [43] = "Always",
        },
    },
    frFR = {
        panelTitle = "Compagnon", tabStats = "Statistiques",
        gambits = "Gambits", gambitsTip = "Les règles de votre compagnon : cible et condition, puis action, lues de haut en bas.",
        help = "Lues de haut en bas : la première règle dont la condition est vraie et l'action possible est jouée.",
        energy = "Énergie", cost = "Coût en énergie : %d", locked = "Niveau %d", reset = "Réinitialiser",
        defaultList = "Liste par défaut (tirée des sorts appris)", customList = "Votre liste",
        pickCondition = "Choisir une condition", pickAction = "Choisir une action", empty = "(vide)", clear = "Vider la règle",
        attack = "Attaquer", comeBack = "Revenir près de toi", up = "Monter", down = "Descendre", enable = "Activer / couper",
        portraitTip = "Clic : cibler votre compagnon. Maj + glisser : déplacer.",
        cat = { "Toi", "Le compagnon", "Ennemi", "Groupe", "Combat" },
        cond = {
            [1] = "PV < 30 %", [2] = "PV < 50 %", [3] = "PV < 70 %", [4] = "PV < 90 %", [5] = "Subit une attaque",
            [6] = "Empoisonné", [7] = "Malade", [8] = "Effet magique", [9] = "Maudit",
            [10] = "PV < 30 %", [11] = "PV < 50 %", [12] = "PV < 70 %", [13] = "Énergie >= 40", [14] = "Énergie >= 60", [15] = "Énergie >= 80",
            [20] = "Ta cible", [21] = "Sa cible", [22] = "Le plus proche", [23] = "Celui qui t'attaque", [24] = "PV < 20 %",
            [25] = "PV < 35 %", [26] = "PV < 50 %", [27] = "PV >= 90 %", [28] = "En train d'incanter", [29] = "Élite ou boss",
            [30] = "Un membre PV < 50 %", [31] = "3 membres PV < 70 %",
            [40] = "2 ennemis ou plus autour", [41] = "3 ennemis ou plus autour", [42] = "5 ennemis ou plus autour", [43] = "Toujours",
        },
    },
    deDE = {
        panelTitle = "Begleiter", tabStats = "Werte",
        gambits = "Gambits", gambitsTip = "Die Regeln Eures Begleiters: Ziel und Bedingung, dann Aktion, von oben nach unten gelesen.",
        help = "Von oben nach unten: Die erste Regel, deren Bedingung zutrifft und deren Aktion möglich ist, wird ausgeführt.",
        energy = "Energie", cost = "Energiekosten: %d", locked = "Stufe %d", reset = "Zurücksetzen",
        defaultList = "Standardliste (aus den erlernten Zaubern)", customList = "Eure Liste",
        pickCondition = "Bedingung wählen", pickAction = "Aktion wählen", empty = "(leer)", clear = "Regel leeren",
        attack = "Angreifen", comeBack = "Zu dir zurückkehren", up = "Hoch", down = "Runter", enable = "An / aus",
        portraitTip = "Klick: Begleiter anvisieren. Umschalt + Ziehen: verschieben.",
        cat = { "Du", "Begleiter", "Feind", "Gruppe", "Kampf" },
        cond = {
            [1] = "GP < 30%", [2] = "GP < 50%", [3] = "GP < 70%", [4] = "GP < 90%", [5] = "Wird angegriffen",
            [6] = "Vergiftet", [7] = "Krank", [8] = "Magischer Effekt", [9] = "Verflucht",
            [10] = "GP < 30%", [11] = "GP < 50%", [12] = "GP < 70%", [13] = "Energie >= 40", [14] = "Energie >= 60", [15] = "Energie >= 80",
            [20] = "Dein Ziel", [21] = "Sein Ziel", [22] = "Nächster", [23] = "Greift dich an", [24] = "GP < 20%",
            [25] = "GP < 35%", [26] = "GP < 50%", [27] = "GP >= 90%", [28] = "Wirkt einen Zauber", [29] = "Elite oder Boss",
            [30] = "Ein Mitglied GP < 50%", [31] = "3 Mitglieder GP < 70%",
            [40] = "2+ Feinde in der Nähe", [41] = "3+ Feinde in der Nähe", [42] = "5+ Feinde in der Nähe", [43] = "Immer",
        },
    },
    esES = {
        panelTitle = "Compañero", tabStats = "Estadísticas",
        gambits = "Gambits", gambitsTip = "Las reglas de tu compañero: objetivo y condición, luego acción, leídas de arriba abajo.",
        help = "De arriba abajo: se juega la primera regla cuya condición se cumple y cuya acción es posible.",
        energy = "Energía", cost = "Coste de energía: %d", locked = "Nivel %d", reset = "Restablecer",
        defaultList = "Lista por defecto (según los hechizos aprendidos)", customList = "Tu lista",
        pickCondition = "Elegir una condición", pickAction = "Elegir una acción", empty = "(vacía)", clear = "Vaciar la regla",
        attack = "Atacar", comeBack = "Volver a tu lado", up = "Subir", down = "Bajar", enable = "Activar / desactivar",
        portraitTip = "Clic: seleccionar a tu compañero. Mayús + arrastrar: mover.",
        cat = { "Tú", "Compañero", "Enemigo", "Grupo", "Combate" },
        cond = {
            [1] = "Salud < 30%", [2] = "Salud < 50%", [3] = "Salud < 70%", [4] = "Salud < 90%", [5] = "Bajo ataque",
            [6] = "Envenenado", [7] = "Enfermo", [8] = "Efecto mágico", [9] = "Maldito",
            [10] = "Salud < 30%", [11] = "Salud < 50%", [12] = "Salud < 70%", [13] = "Energía >= 40", [14] = "Energía >= 60", [15] = "Energía >= 80",
            [20] = "Tu objetivo", [21] = "Su objetivo", [22] = "El más cercano", [23] = "Quien te ataca", [24] = "Salud < 20%",
            [25] = "Salud < 35%", [26] = "Salud < 50%", [27] = "Salud >= 90%", [28] = "Lanzando un hechizo", [29] = "Élite o jefe",
            [30] = "Un miembro salud < 50%", [31] = "3 miembros salud < 70%",
            [40] = "2+ enemigos cerca", [41] = "3+ enemigos cerca", [42] = "5+ enemigos cerca", [43] = "Siempre",
        },
    },
    ruRU = {
        panelTitle = "Спутник", tabStats = "Характеристики",
        gambits = "Гамбиты", gambitsTip = "Правила вашего спутника: цель и условие, затем действие, сверху вниз.",
        help = "Сверху вниз: выполняется первое правило, условие которого верно, а действие возможно.",
        energy = "Энергия", cost = "Затраты энергии: %d", locked = "Уровень %d", reset = "Сбросить",
        defaultList = "Список по умолчанию (из изученных заклинаний)", customList = "Ваш список",
        pickCondition = "Выбрать условие", pickAction = "Выбрать действие", empty = "(пусто)", clear = "Очистить правило",
        attack = "Атаковать", comeBack = "Вернуться к тебе", up = "Вверх", down = "Вниз", enable = "Вкл. / выкл.",
        portraitTip = "Щелчок: выбрать спутника целью. Shift + перетаскивание: переместить.",
        cat = { "Ты", "Спутник", "Враг", "Группа", "Бой" },
        cond = {
            [1] = "Здоровье < 30%", [2] = "Здоровье < 50%", [3] = "Здоровье < 70%", [4] = "Здоровье < 90%", [5] = "Под атакой",
            [6] = "Отравлен", [7] = "Болен", [8] = "Магический эффект", [9] = "Проклят",
            [10] = "Здоровье < 30%", [11] = "Здоровье < 50%", [12] = "Здоровье < 70%", [13] = "Энергия >= 40", [14] = "Энергия >= 60", [15] = "Энергия >= 80",
            [20] = "Твоя цель", [21] = "Его цель", [22] = "Ближайший", [23] = "Атакует тебя", [24] = "Здоровье < 20%",
            [25] = "Здоровье < 35%", [26] = "Здоровье < 50%", [27] = "Здоровье >= 90%", [28] = "Читает заклинание", [29] = "Элита или босс",
            [30] = "Участник: здоровье < 50%", [31] = "3 участника: здоровье < 70%",
            [40] = "2+ врагов рядом", [41] = "3+ врагов рядом", [42] = "5+ врагов рядом", [43] = "Всегда",
        },
    },
}
local G = G_TEXTS[GetLocale()] or (GetLocale() == "esMX" and G_TEXTS.esES) or G_TEXTS.enUS

-- The conditions by category, as the server numbers them (CompanionMount.h).
local G_CATEGORIES = {
    { 1, 2, 3, 4, 5, 6, 7, 8, 9 },
    { 10, 11, 12, 13, 14, 15 },
    { 20, 21, 22, 23, 24, 25, 26, 27, 28, 29 },
    { 30, 31 },
    { 40, 41, 42, 43 },
}
local GAMBIT_ATTACK, GAMBIT_RETURN = -1, -2

local function ConditionText(cond)
    for c, list in ipairs(G_CATEGORIES) do
        for _, code in ipairs(list) do
            if code == cond then return G.cat[c] .. " : " .. (G.cond[cond] or "?") end
        end
    end
    return G.pickCondition
end

local function ActionText(action)
    if action == GAMBIT_ATTACK then return G.attack, PET_ATTACK_TEXTURE end
    if action == GAMBIT_RETURN then return G.comeBack, PET_FOLLOW_TEXTURE end
    if action and action > 0 then
        local name, _, icon = GetSpellInfo(action)
        return name or ("#" .. action), icon
    end
    return G.pickAction, nil
end

-- ---------------------------------------------------------------------------
-- The state, as the server sends it
-- ---------------------------------------------------------------------------

local COMMAND_FOLLOW, COMMAND_STAY = 0, 1
local REACT_PASSIVE, REACT_DEFENSIVE, REACT_AGGRESSIVE = 0, 1, 2

local state = { mount = 0, summoned = false, command = COMMAND_FOLLOW, react = REACT_DEFENSIVE, level = 0 }
local hidden = false

-- ---------------------------------------------------------------------------
-- The rename popup
-- ---------------------------------------------------------------------------

local OSEP = string.char(92)
local function OPath(...) return table.concat({ ... }, OSEP) end

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

-- The points left, big, under the title.
talentFrame.available = talentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
talentFrame.available:SetPoint("TOP", 0, -24)

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
    talentFrame.available:SetText(string.format(L.available, left, talentData.level or 0))
    -- One tree per mount: the tree chosen; any tree: the points of this one.
    local where = talentData.oneTree and (chosen and TREES[chosen + 1].name or L.noTree)
        or string.format(L.inTree, tree.name, inTree)
    footer:SetText(string.format(L.points, spent, talentData.points or 0, where))

    for _, b in pairs(cells) do b:Hide() end
    for _, t in ipairs(talentData.talents) do
        if t.tree == shownTree - 1 then
            local b = TalentCell(t.tier, t.col)
            local rank = talentData.ranks[t.id] or 0
            local max = t.key and 1 or #t.ranks
            local perTier = tonumber(talentData.perTier) or 5
            local reached = inTree >= t.tier * perTier
            local otherTree = talentData.oneTree and chosen ~= nil and chosen ~= t.tree

            local state, reason
            if rank >= max then
                state = "maxed"
            elseif otherTree then
                state, reason = "disabled", L.otherTree
            elseif not reached then
                state, reason = "locked", string.format(L.needPoints, t.tier * perTier)
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
-- The sheet of the companion mount
--
-- Who it is, its level and experience, its numbers (the module writes them on
-- request: `.companion snapshot`), and the doors to its talents and
-- saddlebags: the Statistics tab of the companion panel (below).
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
    xpMax      = FR and "Niveau max" or "Max Level",
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
    mainStats  = FR and "Caractéristiques principales" or "Main Stats",
    melee      = FR and "Mêlée" or "Melee",
    spell      = FR and "Sorts" or "Spell",
    defense    = FR and "Défense" or "Defense",
    misc       = FR and "Divers" or "Misc.",
    mmTip      = FR and "Clic : la fiche de votre monture-compagnon." or "Click: the sheet of your companion mount.",
    bagDrag    = FR and "Clic : ouvre les sacoches. Glissez l'icône dans une barre d'action pour l'y garder."
                     or "Click: opens the saddlebags. Drag the icon to an action bar to keep it there.",
}

local function Percent(v) return string.format("%.2f %%", tonumber(v) or 0) end

-- ---------------------------------------------------------------------------
-- THE COMPANION PANEL: its own window, "Compagnon", with two tabs -- the 3D
-- view and the figures, as the character sheet; the gambits.
--
-- With ForeverUI, the window wears its theme (the rock, the metal frame, the
-- round portrait, the red cross, the side tabs, the character sheet's panes)
-- drawn here from the textures ForeverUI installs (nothing of its drawing code
-- is called), and opens from a micro button of its bar, as Attriboost's
-- (ForeverUI.AddMicroButton, the "collections" icons). Without it, the
-- game's own dialog, tabs at the bottom, opened by a button at the edge of
-- the minimap.
-- ---------------------------------------------------------------------------

local FUI = ForeverUI and ForeverUI.AddMicroButton and true or false
local FUI_ART = OPath("Interface", "ForeverUI") .. string.char(92)
-- The character sheet's size (ForeverUI: 631 x 484, panes 398 + 233 under a 20 px
-- title); the game's dialog adds its border around the same panes.
local PANEL_W, PANEL_H = 631, 484
if not FUI then PANEL_W, PANEL_H = 655, 514 end
local MICRO_NAME = "CompanionMountMicroButton"

-- The pieces of ForeverUI's sheets used here: { file, u1, u2, v1, v2, width, height }.
local PANEL_ART = {
    edgeLeft = { "framegeneral" .. string.char(92) .. "uiframemetalvertical2xc60", 0.001953, 0.373047, 0, 1, 95, 128 },
    edgeRight = { "framegeneral" .. string.char(92) .. "uiframemetalvertical2xc60", 0.376953, 0.748047, 0, 1, 95, 128 },
    edgeBottom = { "framegeneral" .. string.char(92) .. "uiframemetalhorizontal2xc60", 0, 1, 0.001953, 0.392578, 128, 100 },
    edgeTop = { "framegeneral" .. string.char(92) .. "uiframemetalhorizontal2xc60", 0, 1, 0.396484, 0.767578, 128, 95 },
    streaks = { "framegeneral" .. string.char(92) .. "uiframehorizontal", 0, 1, 0.007812, 0.34375, 256, 43 },
    cornerBL = { "framegeneral" .. string.char(92) .. "uiframemetal2xc60", 0.000977, 0.186523, 0.001953, 0.392578, 95, 100 },
    cornerBR = { "framegeneral" .. string.char(92) .. "uiframemetal2xc60", 0.000977, 0.186523, 0.396484, 0.787109, 95, 100 },
    cornerTR = { "framegeneral" .. string.char(92) .. "uiframemetal2xc60", 0.188477, 0.374023, 0.376953, 0.748047, 95, 95 },
    cornerTL = { "framegeneral" .. string.char(92) .. "uiframemetal2xc60", 0.375977, 0.561523, 0.376953, 0.748047, 95, 95 },
    tab = { "common" .. string.char(92) .. "commonsidetabc60", 0.007812, 0.4375, 0.007812, 0.476562, 55, 60 },
    tabHover = { "common" .. string.char(92) .. "commonsidetabc60", 0.007812, 0.4375, 0.492188, 0.960938, 55, 60 },
    tabSelected = { "common" .. string.char(92) .. "commonsidetabc60", 0.453125, 0.882812, 0.007812, 0.476562, 55, 60 },
    exit = { "buttons" .. string.char(92) .. "redbuttonsc60", 0.136719, 0.261719, 0.007812, 0.257812, 32, 32 },
    exitPressed = { "buttons" .. string.char(92) .. "redbuttonsc60", 0.136719, 0.261719, 0.539062, 0.789062, 32, 32 },
    exitHighlight = { "buttons" .. string.char(92) .. "redbuttonsc60", 0.402344, 0.527344, 0.007812, 0.257812, 32, 32 },
    -- the character sheet (UIAtlas_05_character_sheet)
    generalBg = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart2c60", 0.000977, 0.389648, 0.000977, 0.454102, 398, 464 },
    statBg = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart2c60", 0.621094, 0.848633, 0.376953, 0.750977, 233, 383 },
    statTitle = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart1c60", 0.283203, 0.479492, 0.056641, 0.087891, 201, 32 },
    statLight = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart1c60", 0.491211, 0.699219, 0.000977, 0.018555, 213, 18 },
    statDark = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart1c60", 0.263672, 0.462891, 0.000977, 0.021484, 204, 21 },
    stone = { "paperdollinfoframe" .. string.char(92) .. "paperdollinfopart1c60", 0.459961, 0.687500, 0.859375, 0.942383, 233, 85 },
    divider = { "common" .. string.char(92) .. "commonframedividerc60", 0.062500, 0.750000, 0.015625, 0.796875, 11, 50 },
}

local function Art(t, name, keepSize)
    local e = PANEL_ART[name]
    t:SetTexture(FUI_ART .. e[1])
    t:SetTexCoord(e[2], e[3], e[4], e[5])
    if not keepSize then
        t:SetWidth(e[6])
        t:SetHeight(e[7])
    end
    return t
end

-- The ForeverUI frame: the rock, the streaks, the metal, the round portrait,
-- the title on its strip (the Progression window's numbers).
local function DressForever(f)
    local rock = f:CreateTexture(nil, "BACKGROUND")
    rock:SetTexture(FUI_ART .. "framegeneral" .. string.char(92) .. "ui-background-rock", true)
    if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
    rock:SetPoint("TOPLEFT", 2, -21)
    rock:SetPoint("BOTTOMRIGHT", -2, 2)
    local streaks = Art(f:CreateTexture(nil, "BACKGROUND"), "streaks", true)
    streaks:SetHeight(43)
    streaks:SetPoint("TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", -2, -21)

    local metal = CreateFrame("Frame", nil, f)
    metal:SetAllPoints(f)
    metal:SetFrameLevel(f:GetFrameLevel() + 20)
    local function corner(name, point, x, y)
        local t = Art(metal:CreateTexture(nil, "OVERLAY"), name)
        t:SetPoint(point, metal, point, x, y)
        return t
    end
    local tl, tr = corner("cornerTL", "TOPLEFT", -13, 16), corner("cornerTR", "TOPRIGHT", 2, 16)
    local bl, br = corner("cornerBL", "BOTTOMLEFT", -13, -8), corner("cornerBR", "BOTTOMRIGHT", 2, -8)
    local function edge(name, a1, c1, r1, a2, c2, r2)
        local t = Art(metal:CreateTexture(nil, "OVERLAY"), name)
        t:SetPoint(a1, c1, r1)
        t:SetPoint(a2, c2, r2)
    end
    edge("edgeTop", "TOPLEFT", tl, "TOPRIGHT", "TOPRIGHT", tr, "TOPLEFT")
    edge("edgeBottom", "BOTTOMLEFT", bl, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "BOTTOMLEFT")
    edge("edgeLeft", "TOPLEFT", tl, "BOTTOMLEFT", "BOTTOMLEFT", bl, "TOPLEFT")
    edge("edgeRight", "TOPRIGHT", tr, "BOTTOMRIGHT", "BOTTOMRIGHT", br, "TOPRIGHT")

    -- The round portrait: the mount's icon, under the metal ring.
    local ring = CreateFrame("Frame", nil, f)
    ring:SetAllPoints(f)
    ring:SetFrameLevel(f:GetFrameLevel() + 19)
    local portrait = ring:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(58, 58)
    portrait:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 7)
    f.portrait = portrait

    local strip = CreateFrame("Frame", nil, f)
    strip:SetFrameLevel(f:GetFrameLevel() + 21)
    strip:SetHeight(20)
    strip:SetPoint("TOPLEFT", 58, -1)
    strip:SetPoint("TOPRIGHT", -24, -1)
    f.title = strip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", strip, "TOP", 0, -5)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 1)
    close:SetFrameLevel(f:GetFrameLevel() + 22)
    for _, v in ipairs({ { "GetNormalTexture", "exit" }, { "GetPushedTexture", "exitPressed" },
            { "GetHighlightTexture", "exitHighlight" } }) do
        local t = close[v[1]](close)
        if t then
            Art(t, v[2], true)
            t:ClearAllPoints()
            t:SetAllPoints(close)
        end
    end
    close:GetHighlightTexture():SetBlendMode("ADD")
end

-- The game's own frame: the dialog box and its header.
local function DressDefault(f)
    f:SetBackdrop({
        bgFile = OPath("Interface", "DialogFrame", "UI-DialogBox-Background"),
        edgeFile = OPath("Interface", "DialogFrame", "UI-DialogBox-Border"),
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetTexture(OPath("Interface", "DialogFrame", "UI-DialogBox-Header"))
    header:SetSize(320, 64)
    header:SetPoint("TOP", 0, 12)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", header, "TOP", 0, -14)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
end

local Panel = { pages = {}, tabs = {}, current = 1 }

local TAB_DEFS = {
    { text = function() return G.tabStats end, icon = OPath("Interface", "Icons", "Ability_Hunter_BeastTaming") },
    { text = function() return G.gambits end, icon = OPath("Interface", "Icons", "INV_Misc_Book_09") },
}

function Panel.Select(index)
    Panel.current = index
    for i, page in ipairs(Panel.pages) do
        if i == index then page:Show() else page:Hide() end
    end
    for i, tab in ipairs(Panel.tabs) do
        if FUI then
            if i == index then tab.selected:Show() else tab.selected:Hide() end
        end
    end
    if not FUI and Panel.frame then PanelTemplates_SetTab(Panel.frame, index) end
end

local function SideTab(f, i)
    local b = CreateFrame("Button", "CompanionMountPanelSideTab" .. i, f)
    b:SetSize(55, 55)
    b:SetFrameLevel(f:GetFrameLevel() + 1)
    Art(b:CreateTexture(nil, "BACKGROUND"), "tab", true):SetAllPoints(b)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(50, 50)
    icon:SetPoint("CENTER", -3, 0)
    icon:SetTexCoord(0.03125, 0.96875, 0.03125, 0.96875)
    icon:SetTexture(TAB_DEFS[i].icon)
    b.selected = Art(b:CreateTexture(nil, "OVERLAY"), "tabSelected", true)
    b.selected:SetAllPoints(b)
    b.selected:Hide()
    Art(b:CreateTexture(nil, "HIGHLIGHT"), "tabHover", true):SetAllPoints(b)
    if i == 1 then
        b:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -60)
    else
        b:SetPoint("TOPLEFT", Panel.tabs[i - 1], "BOTTOMLEFT", 0, -2)
    end
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
        GameTooltip:SetText(TAB_DEFS[i].text())
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        Panel.Select(i)
    end)
    return b
end

local function BottomTab(f, i)
    local b = CreateFrame("Button", "CompanionMountPanelTab" .. i, f, "CharacterFrameTabButtonTemplate")
    b:SetID(i)
    b:SetText(TAB_DEFS[i].text())
    if i == 1 then
        b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 8)
    else
        b:SetPoint("LEFT", Panel.tabs[i - 1], "RIGHT", -16, 0)
    end
    PanelTemplates_TabResize(b, 0)
    b:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        Panel.Select(i)
    end)
    return b
end

function Panel.Create()
    if Panel.frame then return Panel.frame end
    local f = CreateFrame("Frame", "CompanionMountPanel", UIParent)
    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:Hide()
    -- A panel of the game, as the character sheet (Progression's numbers).
    for k, v in pairs({ area = "left", xoffset = 35, pushable = 1, whileDead = 1, width = PANEL_W + 85 }) do
        f:SetAttribute("UIPanelLayout-" .. k, v)
    end
    f:SetAttribute("UIPanelLayout-defined", true)
    f:SetAttribute("UIPanelLayout-enabled", true)
    if FUI then DressForever(f) else DressDefault(f) end
    f.title:SetText(G.panelTitle)
    Panel.frame = f

    for i = 1, #TAB_DEFS do
        -- The statistics fill the window under the title, as the sheet's panes;
        -- the gambits keep a margin.
        local page = CreateFrame("Frame", nil, f)
        if i == 1 then
            page:SetPoint("TOPLEFT", f, "TOPLEFT", FUI and 0 or 12, FUI and -20 or -38)
            page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", FUI and 0 or -12, FUI and 0 or 12)
        else
            page:SetPoint("TOPLEFT", f, "TOPLEFT", 18, FUI and -30 or -40)
            page:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
        end
        page:SetFrameLevel(f:GetFrameLevel() + 2)
        page:Hide()
        Panel.pages[i] = page
        Panel.tabs[i] = FUI and SideTab(f, i) or BottomTab(f, i)
    end
    if not FUI then
        PanelTemplates_SetNumTabs(f, #TAB_DEFS)
    end

    f:SetScript("OnShow", function()
        PlaySound("igCharacterInfoOpen")
        if FUI and ForeverUI.UpdateMicro then ForeverUI.UpdateMicro(MICRO_NAME, true) end
    end)
    f:SetScript("OnHide", function()
        PlaySound("igCharacterInfoClose")
        if FUI and ForeverUI.UpdateMicro then ForeverUI.UpdateMicro(MICRO_NAME, false) end
    end)

    UI.Build(Panel.pages[1])
    CompanionMount_AttachGambits(Panel.pages[2])
    Panel.Select(1)
    return f
end

function Panel.Open(index)
    local f = Panel.Create()
    if not f:IsShown() then ShowUIPanel(f) end
    Panel.Select(index or Panel.current or 1)
end

function Panel.Toggle(index)
    local f = Panel.Create()
    if f:IsShown() and (not index or index == Panel.current) then
        HideUIPanel(f)
    else
        Panel.Open(index)
    end
end

-- The portrait follows the mount chosen.
function Panel.SetPortrait(mount)
    if not (Panel.frame and Panel.frame.portrait) then return end
    local icon = (mount or 0) ~= 0 and select(3, GetSpellInfo(mount)) or UI.MM_ICONE
    if SetPortraitToTexture then
        SetPortraitToTexture(Panel.frame.portrait, icon)
    else
        Panel.frame.portrait:SetTexture(icon)
    end
end

-- ---------------------------------------------------------------------------
-- The "Statistics" tab, as the character sheet: on the left the mount in 3D
-- (drag to turn it) with its name and level, its experience below; on the
-- right its figures; at the bottom its name, its saddlebags (a button that can
-- be dragged to an action bar) and its talents.
-- ---------------------------------------------------------------------------
function UI.Build(parent)
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)
    UI.root = root
    local LEFT_PANE, RIGHT_PANE = 398, 233

    local function Backdrop(frame, alpha)
        frame:SetBackdrop({
            bgFile = OPath("Interface", "Tooltips", "UI-Tooltip-Background"),
            edgeFile = OPath("Interface", "Tooltips", "UI-Tooltip-Border"),
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0, 0, 0, alpha)
    end

    -- THE LEFT PANE: the mount in 3D (drag to turn it), its name above it.
    local left = CreateFrame("Frame", nil, root)
    left:SetPoint("TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", 0, 0)
    left:SetWidth(LEFT_PANE)
    if FUI then
        Art(left:CreateTexture(nil, "BACKGROUND"), "generalBg"):SetPoint("TOPLEFT", 0, 0)
    else
        Backdrop(left, 0.75)
    end
    local model = CreateFrame("PlayerModel", nil, left)
    model:SetPoint("TOPLEFT", 10, -44)
    model:SetPoint("BOTTOMRIGHT", -10, 48)
    model.rotation = 0.6
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(self) self.turning = GetCursorPosition() end)
    model:SetScript("OnMouseUp", function(self) self.turning = nil end)
    model:SetScript("OnUpdate", function(self)
        if self.turning then
            local x = GetCursorPosition()
            self.rotation = self.rotation + (x - self.turning) / 80
            self.turning = x
            self:SetRotation(self.rotation)
        end
    end)
    UI.model = model
    UI.name = left:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.name:SetPoint("TOP", left, "TOP", 0, -14)

    -- The saddlebags, bottom left of the view: an icon that opens them, and
    -- that can be dragged to an action bar (the macro /compagnon sacoches).
    local bag = CreateFrame("Button", "CompanionMountSheetBagButton", left)
    bag:SetSize(30, 30)
    bag:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 16, 12)
    local bagIcon = bag:CreateTexture(nil, "ARTWORK")
    bagIcon:SetAllPoints()
    bagIcon:SetTexture(OPath("Interface", "Icons", "INV_Misc_Bag_08"))
    local bagBorder = bag:CreateTexture(nil, "OVERLAY")
    bagBorder:SetTexture(OPath("Interface", "Buttons", "UI-Quickslot2"))
    bagBorder:SetSize(58, 58)
    bagBorder:SetPoint("CENTER", 0, -1)
    bag:SetHighlightTexture(OPath("Interface", "Buttons", "ButtonHilight-Square"), "ADD")
    bag:SetPushedTexture(OPath("Interface", "Buttons", "UI-Quickslot-Depress"))
    bag:RegisterForDrag("LeftButton")
    bag:SetScript("OnClick", function() CompanionMount_ToggleBag() end)
    bag:SetScript("OnDragStart", function() UI.PickupBagMacro() end)
    bag:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L.bag, 1, 1, 1)
        GameTooltip:AddLine(SL.bagDrag, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    bag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local bagLabel = left:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagLabel:SetPoint("LEFT", bag, "RIGHT", 8, 0)
    bagLabel:SetText(L.bag)

    -- THE RIGHT PANE, as the character sheet's: its background, the stone band
    -- (level and experience), the divider against the view.
    local right = CreateFrame("Frame", nil, root)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(RIGHT_PANE)
    if FUI then
        Art(right:CreateTexture(nil, "BACKGROUND"), "statBg", true):SetAllPoints(right)
        Art(right:CreateTexture(nil, "ARTWORK"), "stone"):SetPoint("TOPLEFT", 0, 0)
        -- The divider: a cap at each end, the middle drawn between them.
        local divider = CreateFrame("Frame", nil, right)
        divider:SetWidth(11)
        divider:SetPoint("TOPLEFT", right, "TOPLEFT", -6, -1)
        divider:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", -6, 0)
        divider:SetFrameLevel(right:GetFrameLevel() + 3)
        local e = PANEL_ART.divider
        local cap = (e[5] - e[4]) * 4 / e[7]
        local function slice(v1, v2)
            local t = divider:CreateTexture(nil, "OVERLAY")
            t:SetTexture(FUI_ART .. e[1])
            t:SetTexCoord(e[2], e[3], v1, v2)
            return t
        end
        local top, bottom = slice(e[4], e[4] + cap), slice(e[5] - cap, e[5])
        top:SetHeight(4)
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        bottom:SetHeight(4)
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        local middle = slice(e[4] + cap, e[5] - cap)
        middle:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
        middle:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    else
        Backdrop(right, 0.6)
    end

    UI.levelText = right:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.levelText:SetPoint("TOP", right, "TOP", 0, -18)
    local xp = CreateFrame("StatusBar", nil, right)
    xp:SetSize(RIGHT_PANE - 40, 14)
    xp:SetPoint("TOP", UI.levelText, "BOTTOM", 0, -10)
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

    -- THE FIGURES: a header (the sheet's title art), its rows on alternating
    -- bands -- dark first, then light, starting again with each header.
    local STEP, MARGIN = 15, 20
    local function Header(y)
        local h = CreateFrame("Button", nil, right)
        h:SetSize(RIGHT_PANE - 2 * MARGIN + 10, 34)
        h:SetPoint("TOP", right, "TOP", 0, y)
        local art = h:CreateTexture(nil, "ARTWORK")
        art:SetAllPoints(h)
        if FUI then Art(art, "statTitle", true) else art:SetTexture(1, 1, 1, 0.08) end
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        h.text:SetPoint("CENTER", 0, 1)
        return h
    end
    local function Row(y, index)
        local band = right:CreateTexture(nil, "ARTWORK")
        band:SetSize(RIGHT_PANE - 2 * MARGIN, STEP)
        band:SetPoint("TOP", right, "TOP", 0, y)
        if FUI then
            Art(band, (index % 2 == 1) and "statDark" or "statLight", true)
        else
            band:SetTexture(1, 1, 1, (index % 2 == 1) and 0.04 or 0.08)
        end
        local label = right:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", band, "LEFT", 4, 0)
        local value = right:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetPoint("RIGHT", band, "RIGHT", -4, 0)
        value:SetJustifyH("RIGHT")
        return { band = band, label = label, value = value }
    end

    local y = -95
    local main = Header(y)
    main.text:SetText(SL.mainStats)
    UI.mainRows = {}
    for i, key in ipairs({ "health", "armor" }) do
        local r = Row(y - 34 - (i - 1) * STEP, i)
        r.label:SetText(SL[key])
        r.key = key
        UI.mainRows[i] = r
    end

    -- Two categories, each under a dropdown, as the sheet's left and right
    -- stat frames: Melee, Spell, Defense, Misc.
    UI.groups = {}
    local defaults = { "melee", "defense" }
    y = y - 34 - 2 * STEP - 14
    for g = 1, 2 do
        local header = Header(y)
        local group = { header = header, rows = {}, category = UI.groupChoice and UI.groupChoice[g] or defaults[g] }
        for i = 1, 3 do group.rows[i] = Row(y - 34 - (i - 1) * STEP, i) end
        header.arrow = header:CreateTexture(nil, "OVERLAY")
        header.arrow:SetTexture(OPath("Interface", "ChatFrame", "UI-ChatIcon-ScrollDown-Up"))
        header.arrow:SetSize(18, 18)
        header.arrow:SetPoint("RIGHT", header, "RIGHT", -8, 1)
        header:SetScript("OnClick", function(self)
            local menu = {}
            for _, cat in ipairs(UI.CATEGORIES) do
                menu[#menu + 1] = {
                    text = SL[cat.key], checked = group.category == cat.key,
                    func = function()
                        group.category = cat.key
                        UI.groupChoice = UI.groupChoice or {}
                        UI.groupChoice[g] = cat.key
                        UI.RenderStats()
                        CloseDropDownMenus()
                    end,
                }
            end
            EasyMenu(menu, UI.statMenu, self, 0, 0, "MENU")
        end)
        UI.groups[g] = group
        y = y - 34 - 3 * STEP - 14
    end
    UI.statMenu = UI.statMenu or CreateFrame("Frame", "CompanionMountStatMenu", UIParent, "UIDropDownMenuTemplate")

    -- ITS NAME AND ITS TALENTS, at the foot of the right pane.
    local rename = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    rename:SetSize(96, 24)
    rename:SetPoint("BOTTOMLEFT", right, "BOTTOMLEFT", 14, 14)
    rename:SetText(L.rename)
    rename:SetScript("OnClick", function() StaticPopup_Show("COMPANIONMOUNT_RENAME") end)
    local talents = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    talents:SetSize(96, 24)
    talents:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -14, 14)
    talents:SetText(L.talents)
    talents:SetScript("OnClick", function() CompanionMount_ToggleTalents() end)

    -- While it is shown, the numbers follow the fight (every 3 s: each
    -- request has the module write the sheet in the database).
    local elapsed = 0
    root:SetScript("OnShow", function() UI.Request() end)
    root:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 3 then
            elapsed = 0
            UI.Request()
        end
    end)
    UI.Refresh()
    return root
end

-- The categories of the dropdowns and their figures (Spell: none yet).
UI.CATEGORIES = {
    { key = "melee", stats = { "power", "speed", "crit" } },
    { key = "spell", stats = {} },
    { key = "defense", stats = { "dodge", "parry" } },
    { key = "misc", stats = { "points" } },
}

function UI.RenderStats()
    local values = UI.values or {}
    for _, r in ipairs(UI.mainRows or {}) do
        r.value:SetText(values[r.key] or "-")
    end
    for _, group in ipairs(UI.groups or {}) do
        local cat
        for _, c in ipairs(UI.CATEGORIES) do
            if c.key == group.category then cat = c end
        end
        group.header.text:SetText(SL[group.category] or "")
        for i, r in ipairs(group.rows) do
            local key = cat and cat.stats[i]
            if key then
                r.label:SetText(SL[key])
                r.value:SetText(values[key] or "-")
                r.band:Show()
                r.label:Show()
                r.value:Show()
            else
                r.band:Hide()
                r.label:Hide()
                r.value:Hide()
            end
        end
    end
end

-- The saddlebags on an action bar: a macro of the player's own, made once.
function UI.PickupBagMacro()
    if InCombatLockdown() then return end
    local name = L.bag
    local index = GetMacroIndexByName(name)
    if index == 0 then
        local icon = 1
        for i = 1, GetNumMacroIcons() do
            local texture = GetMacroIconInfo(i)
            if texture and texture:lower():find("inv_misc_bag_08", 1, true) then
                icon = i
                break
            end
        end
        local ok, created = pcall(CreateMacro, name, icon, "/compagnon sacoches", 1)
        index = ok and created or 0
    end
    if index and index > 0 then
        PickupMacro(index)
    end
end

function UI.Request()
    AIO.Handle("CompanionMount", "SheetOpen")
end

function UI.Refresh()
    if not UI.root then return end
    local s = UI.sheet
    local mount = tonumber(s.mount_spell) or 0
    local name = GetSpellInfo(mount)
    Panel.SetPortrait(mount)

    -- The 3D view: the beast's own model when it is out, else the mount's.
    local display, creature = tonumber(s.display) or 0, tonumber(s.creature) or 0
    if display ~= UI.shownDisplay or creature ~= UI.shownCreature then
        UI.shownDisplay, UI.shownCreature = display, creature
        UI.model:ClearModel()
        if display > 0 and UI.model.SetDisplayInfo then
            UI.model:SetDisplayInfo(display)
        elseif creature > 0 then
            UI.model:SetCreature(creature)
        end
        UI.model:SetRotation(UI.model.rotation)
    end

    if mount == 0 then
        UI.name:SetText(SL.noMount)
    else
        UI.name:SetText((s.name and s.name ~= "") and s.name or (name or L.title))
    end

    local level = tonumber(s.level) or 0
    UI.levelText:SetText(string.format(SL.level, level))
    local nextXp = tonumber(s.xp_next) or 0
    UI.xp:SetMinMaxValues(0, math.max(1, nextXp))
    UI.xp:SetValue(tonumber(s.xp) or 0)
    if level == 0 then
        UI.xpText:SetText("")
    elseif level < (UnitLevel("player") or level) then
        UI.xpText:SetText(string.format(SL.xp, tonumber(s.xp) or 0, nextXp))
    else
        UI.xp:SetMinMaxValues(0, 1)
        UI.xp:SetValue(1)
        UI.xpText:SetText(SL.xpMax)
    end

    local out = s.out == 1
    UI.values = {
        health = out and (s.health .. " / " .. s.max_health) or nil,
        armor = out and s.armor or nil,
        power = out and s.attack_power or nil,
        speed = out and string.format("%.2f", (tonumber(s.attack_time) or 0) / 1000) or nil,
        crit = out and Percent(s.crit) or nil,
        dodge = out and Percent(s.dodge) or nil,
        parry = out and Percent(s.parry) or nil,
        points = (s.points_spent or 0) .. " / " .. (s.points_total or 0),
    }
    UI.RenderStats()
end

-- ---------------------------------------------------------------------------
-- The doors: a micro button with ForeverUI, else a button at the edge of the
-- minimap.
-- ---------------------------------------------------------------------------

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

if FUI then
    ForeverUI.AddMicroButton({
        name = MICRO_NAME, atlasSet = "collections", after = "TalentMicroButton",
        tooltip = function() return G.panelTitle end,
        onClick = function() Panel.Toggle() end,
    })
else
    UI.CreateMinimapButton()
end

function CompanionMount_Toggle()
    Panel.Toggle(1)
end

-- ---------------------------------------------------------------------------
-- THE BAR: the orders, as the pet bar beside the pet's own -- call, send
-- back, attack, follow, stay, and the three stances, with the pet bar's
-- icons -- then the spells the mount learned. The active order and stance are
-- lit. A spell: left click casts it, right click turns its automatic casting
-- off or on, as a hunter's pet abilities (the same golden shine). Nothing is
-- decided here: every button goes to the server, which runs the module's
-- command as the player and sends the state back. The sheet keeps the rest
-- (rename, saddlebags, talents).
--
-- Shift + drag moves the bar (kept per character); /compagnon barre shows or
-- hides it.
-- ---------------------------------------------------------------------------

local BAR_SIZE, BAR_GAP = 30, 4
local MOUNT_ICON = OPath("Interface", "Icons", "Ability_Mount_RidingHorse")

local BAR_BUTTONS = {
    { order = "summon",     text = L.summon,     tip = L.summonTip,     icon = MOUNT_ICON },
    { order = "dismiss",    text = L.dismiss,    tip = L.dismissTip,    icon = OPath("Interface", "Icons", "Spell_Nature_SpiritWolf") },
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
}

local bar = CreateFrame("Frame", "CompanionMountBar", UIParent)
bar:SetSize(#BAR_BUTTONS * (BAR_SIZE + BAR_GAP) + BAR_GAP, BAR_SIZE + 2 * BAR_GAP)
bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 170)
bar:SetMovable(true)
bar:SetClampedToScreen(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetBackdrop({
    bgFile = OPath("Interface", "Tooltips", "UI-Tooltip-Background"),
    edgeFile = OPath("Interface", "Tooltips", "UI-Tooltip-Border"),
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
bar:SetBackdropColor(0, 0, 0, 0.6)
bar:Hide()

local function BarStartMove()
    if IsShiftKeyDown() then bar:StartMoving() end
end

local function BarStopMove()
    bar:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(bar) end
end

bar:SetScript("OnDragStart", BarStartMove)
bar:SetScript("OnDragStop", BarStopMove)

local barButtons = {}
for i, def in ipairs(BAR_BUTTONS) do
    local b = CreateFrame("CheckButton", "CompanionMountBarButton" .. i, bar)
    b:SetSize(BAR_SIZE, BAR_SIZE)
    b:SetPoint("LEFT", bar, "LEFT", BAR_GAP + (i - 1) * (BAR_SIZE + BAR_GAP), 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(def.icon)
    b:SetHighlightTexture(OPath("Interface", "Buttons", "ButtonHilight-Square"), "ADD")
    b:SetCheckedTexture(OPath("Interface", "Buttons", "CheckButtonHilight"))
    b:SetPushedTexture(OPath("Interface", "Buttons", "UI-Quickslot-Depress"))
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", BarStartMove)
    b:SetScript("OnDragStop", BarStopMove)
    b.def = def
    b:SetScript("OnClick", function(self)
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
    barButtons[i] = b
end

-- The level of the mount, on the call button.
local barLevel = barButtons[1]:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
barLevel:SetPoint("BOTTOMRIGHT", barButtons[1], "BOTTOMRIGHT", -1, 2)

-- The spells, after the orders and a gap; made as the mount learns them.
local SPELL_GAP = 10
local AUTOCASTABLE = OPath("Interface", "Buttons", "UI-AutoCastableOverlay")
local spellButtons = {}

local function SpellButton(i)
    if spellButtons[i] then return spellButtons[i] end
    local b = CreateFrame("Button", "CompanionMountBarSpell" .. i, bar)
    b:SetSize(BAR_SIZE, BAR_SIZE)
    b:SetPoint("LEFT", bar, "LEFT",
        BAR_GAP + #BAR_BUTTONS * (BAR_SIZE + BAR_GAP) + SPELL_GAP + (i - 1) * (BAR_SIZE + BAR_GAP), 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b:SetHighlightTexture(OPath("Interface", "Buttons", "ButtonHilight-Square"), "ADD")
    b:SetPushedTexture(OPath("Interface", "Buttons", "UI-Quickslot-Depress"))
    -- The corners of a spell that can cast itself, as on the pet bar.
    b.autocastable = b:CreateTexture(nil, "OVERLAY")
    b.autocastable:SetTexture(AUTOCASTABLE)
    b.autocastable:SetSize(BAR_SIZE * 2 - 2, BAR_SIZE * 2 - 2)
    b.autocastable:SetPoint("CENTER")
    -- The golden shine while it casts itself (the pet bar's, when the client has it).
    local ok, shine = pcall(CreateFrame, "Frame", "CompanionMountBarSpell" .. i .. "Shine", b, "AutoCastShineTemplate")
    if ok and shine and AutoCastShine_AutoCastStart then
        shine:SetAllPoints()
        b.shine = shine
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", BarStartMove)
    b:SetScript("OnDragStop", BarStopMove)
    b:SetScript("OnClick", function(self, mouse)
        if not self.spell then return end
        if mouse == "RightButton" then
            AIO.Handle("CompanionMount", "Autocast", self.spell)
        else
            AIO.Handle("CompanionMount", "Cast", self.spell)
        end
    end)
    b:SetScript("OnEnter", function(self)
        if not self.spell then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetHyperlink("spell:" .. self.spell)
        GameTooltip:AddLine(" ")
        if (self.cost or 0) > 0 then
            GameTooltip:AddLine(string.format(G.cost, self.cost), 1, 1, 0)
        end
        GameTooltip:AddLine(self.auto and L.autoOn or L.autoOff, 1, 0.82, 0)
        GameTooltip:AddLine(L.spellTip, 0.5, 0.5, 0.5, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    spellButtons[i] = b
    return b
end

local function RefreshSpells()
    local spells = type(state.spells) == "table" and state.spells or {}
    for i, entry in ipairs(spells) do
        local b = SpellButton(i)
        b.spell = tonumber(entry.spell)
        b.auto = entry.auto and true or false
        b.cost = tonumber(entry.cost) or 0
        b.icon:SetTexture(select(3, GetSpellInfo(b.spell)) or OPath("Interface", "Icons", "INV_Misc_QuestionMark"))
        local usable = state.summoned
        b.icon:SetDesaturated(not usable)
        local shade = usable and 1 or 0.6
        b.icon:SetVertexColor(shade, shade, shade)
        if b.shine then
            if b.auto then AutoCastShine_AutoCastStart(b.shine) else AutoCastShine_AutoCastStop(b.shine) end
        end
        b:Show()
    end
    for i = #spells + 1, #spellButtons do
        spellButtons[i].spell = nil
        if spellButtons[i].shine then AutoCastShine_AutoCastStop(spellButtons[i].shine) end
        spellButtons[i]:Hide()
    end
    local width = #BAR_BUTTONS * (BAR_SIZE + BAR_GAP) + BAR_GAP
    if #spells > 0 then
        width = width + SPELL_GAP + #spells * (BAR_SIZE + BAR_GAP)
    end
    bar:SetWidth(width)
end

local barHidden = false
local RefreshSpellEnergy   -- below, with the portrait that knows the energy

-- No bar in a dungeon, a raid, a battleground or an arena.
local function InGroupInstance()
    local inside, kind = IsInInstance()
    return inside and (kind == "party" or kind == "raid" or kind == "pvp" or kind == "arena")
end

local function RefreshBar()
    -- The call button wears the face of the chosen mount.
    local icon = (state.mount or 0) ~= 0 and select(3, GetSpellInfo(state.mount))
    barButtons[1].icon:SetTexture(icon or MOUNT_ICON)
    barLevel:SetText((state.level or 0) > 0 and string.format(L.level, state.level) or "")
    for _, b in ipairs(barButtons) do
        local usable = not b.def.needsOut or state.summoned
        b:SetChecked(b.def.lit and b.def.lit() or false)
        b.icon:SetDesaturated(not usable)
        local shade = usable and 1 or 0.6
        b.icon:SetVertexColor(shade, shade, shade)
    end
    RefreshSpells()
    if RefreshSpellEnergy then RefreshSpellEnergy() end
    if barHidden or (state.mount or 0) == 0 or InGroupInstance() then bar:Hide() else bar:Show() end
end

-- Entering or leaving a dungeon, a raid or a battleground: the bar follows.
local barWatch = CreateFrame("Frame")
barWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
barWatch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
barWatch:SetScript("OnEvent", function() RefreshBar() end)

AIO.SavePosition(bar, true)

-- ---------------------------------------------------------------------------
-- THE PORTRAIT: the game shows none for a guardian. Its name, its level, its
-- health and, below, its energy in yellow, as any unit with a resource; a
-- click targets it. The server sends the figures as they change (addon
-- message CMPF: "out;hp;max hp;energy;max energy;level;display;creature;name").
-- ---------------------------------------------------------------------------

local companionEnergy = 0
local portrait = { out = false, name = "" }

local unitFrame = CreateFrame("Button", "CompanionMountUnitFrame", UIParent, "SecureActionButtonTemplate")
unitFrame:SetSize(170, 52)
unitFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 150, 22)
unitFrame:SetMovable(true)
unitFrame:SetClampedToScreen(true)
unitFrame:RegisterForClicks("AnyUp")
unitFrame:RegisterForDrag("LeftButton")
unitFrame:SetAttribute("type", "macro")
unitFrame:SetBackdrop({
    bgFile = OPath("Interface", "Tooltips", "UI-Tooltip-Background"),
    edgeFile = OPath("Interface", "Tooltips", "UI-Tooltip-Border"),
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
unitFrame:SetBackdropColor(0, 0, 0, 0.75)
unitFrame:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end
end)
unitFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if LibWindow then LibWindow.SavePosition(self) end
end)
unitFrame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine(portrait.name ~= "" and portrait.name or L.title, 1, 1, 1)
    GameTooltip:AddLine(G.portraitTip, 0.5, 0.5, 0.5, true)
    GameTooltip:Show()
end)
unitFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

local portraitModel = CreateFrame("PlayerModel", nil, unitFrame)
portraitModel:SetSize(42, 42)
portraitModel:SetPoint("LEFT", 5, 0)

local portraitName = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
portraitName:SetPoint("TOPLEFT", portraitModel, "TOPRIGHT", 6, 1)
portraitName:SetPoint("RIGHT", unitFrame, "RIGHT", -28, 0)
portraitName:SetJustifyH("LEFT")
local portraitLevel = unitFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
portraitLevel:SetPoint("TOPRIGHT", unitFrame, "TOPRIGHT", -7, -6)

local function PortraitBar(r, g, b, height)
    local bar = CreateFrame("StatusBar", nil, unitFrame)
    bar:SetStatusBarTexture(OPath("Interface", "TargetingFrame", "UI-StatusBar"))
    bar:SetStatusBarColor(r, g, b)
    bar:SetHeight(height)
    bar:SetPoint("LEFT", portraitModel, "RIGHT", 6, 0)
    bar:SetPoint("RIGHT", unitFrame, "RIGHT", -7, 0)
    bar:SetMinMaxValues(0, 1)
    local back = bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetTexture(0, 0, 0, 0.5)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.text:SetPoint("CENTER", 0, 0)
    return bar
end
local healthBar = PortraitBar(0, 1, 0, 12)
healthBar:SetPoint("TOP", portraitName, "BOTTOM", 0, -3)
local energyBar = PortraitBar(1, 1, 0, 9)
energyBar:SetPoint("TOP", healthBar, "BOTTOM", 0, -2)

-- A protected frame can not be shown or hidden in combat: then it only fades.
local pendingVisibility
local function ApplyPortraitVisibility()
    local wanted = portrait.out and not InGroupInstance()
    if InCombatLockdown() then
        unitFrame:SetAlpha(wanted and 1 or 0)
        pendingVisibility = true
        return
    end
    pendingVisibility = nil
    unitFrame:SetAlpha(1)
    if wanted then unitFrame:Show() else unitFrame:Hide() end
    unitFrame:SetAttribute("macrotext", "/targetexact " .. (portrait.name or ""))
end

local lastModel
local function RefreshPortrait()
    portraitName:SetText(portrait.name or "")
    portraitLevel:SetText(portrait.level or "")
    healthBar:SetMinMaxValues(0, math.max(1, portrait.maxHealth or 1))
    healthBar:SetValue(portrait.health or 0)
    healthBar.text:SetText((portrait.health or 0) .. " / " .. (portrait.maxHealth or 0))
    energyBar:SetMinMaxValues(0, math.max(1, portrait.maxEnergy or 1))
    energyBar:SetValue(portrait.energy or 0)
    energyBar.text:SetText(portrait.energy or 0)
    local modelKey = (portrait.display or 0) .. ":" .. (portrait.creature or 0)
    if portrait.out and modelKey ~= lastModel then
        lastModel = modelKey
        if (portrait.display or 0) > 0 and portraitModel.SetDisplayInfo then
            portraitModel:SetDisplayInfo(portrait.display)
        elseif (portrait.creature or 0) > 0 then
            portraitModel:SetCreature(portrait.creature)
        end
        portraitModel:SetCamera(0)
    end
    ApplyPortraitVisibility()
end


local portraitWatch = CreateFrame("Frame")
portraitWatch:RegisterEvent("CHAT_MSG_ADDON")
portraitWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
portraitWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
portraitWatch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
portraitWatch:SetScript("OnEvent", function(_, event, prefix, message)
    if event == "CHAT_MSG_ADDON" then
        if prefix ~= "CMPF" or type(message) ~= "string" then return end
        local out, hp, maxHp, energy, maxEnergy, level, display, creature, name =
            message:match("^(%d);(%d+);(%d+);(%d+);(%d+);(%d+);(%d+);(%d+);(.*)$")
        if out then
            portrait.out = true
            portrait.health, portrait.maxHealth = tonumber(hp), tonumber(maxHp)
            portrait.energy, portrait.maxEnergy = tonumber(energy), tonumber(maxEnergy)
            portrait.level, portrait.display, portrait.creature = tonumber(level), tonumber(display), tonumber(creature)
            portrait.name = name or ""
        else
            portrait.out = false
            portrait.energy = 0
        end
        companionEnergy = portrait.energy or 0
        RefreshPortrait()
        if RefreshSpellEnergy then RefreshSpellEnergy() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingVisibility then ApplyPortraitVisibility() end
    else
        ApplyPortraitVisibility()
    end
end)
unitFrame:Hide()
AIO.SavePosition(unitFrame, true)

-- ---------------------------------------------------------------------------
-- THE GAMBITS, in the companion's sheet: the Gambits button swaps the 3D view
-- and the figures for the rules -- a line each: on/off, target and condition,
-- action, up and down. The locked slots are grayed with the level they open
-- at. Every change sends the whole list; the server answers with it as it
-- keeps it.
-- ---------------------------------------------------------------------------

local GAMBIT_ROW_HEIGHT = 34
local gambitData = { rows = {}, slots = 3, max = 10, unlock = {}, spells = {}, custom = false }
local gambitRows = {}

local gambitFrame = CreateFrame("Frame", "CompanionMountGambitPanel", UIParent)
gambitFrame:Hide()

local gambitTitle = gambitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
gambitTitle:SetPoint("TOPLEFT", 0, -2)
gambitTitle:SetText(G.gambits)
local gambitHelp = gambitFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
gambitHelp:SetPoint("TOPLEFT", gambitTitle, "BOTTOMLEFT", 0, -3)
gambitHelp:SetPoint("RIGHT", 0, 0)
gambitHelp:SetJustifyH("LEFT")
gambitHelp:SetText(G.help)

local gambitStatus = gambitFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gambitStatus:SetPoint("BOTTOMLEFT", 0, 4)
local gambitReset = CreateFrame("Button", nil, gambitFrame, "UIPanelButtonTemplate")
gambitReset:SetSize(130, 22)
gambitReset:SetPoint("BOTTOMRIGHT", 0, 0)
gambitReset:SetText(G.reset)
gambitReset:SetScript("OnClick", function() AIO.Handle("CompanionMount", "GambitReset") end)

local gambitMenu = CreateFrame("Frame", "CompanionMountGambitMenu", UIParent, "UIDropDownMenuTemplate")

-- The list as the window shows it: the rules, then empty unlocked lines.
local function GambitRow(i)
    return gambitData.rows[i] or { enabled = false }
end

local function SaveGambits(rows)
    local list = {}
    for i = 1, math.max(gambitData.max or 12, #rows) do
        local r = rows[i]
        if r and r.cond and r.action then
            list[#list + 1] = { enabled = r.enabled and true or false, cond = r.cond, action = r.action }
        end
    end
    AIO.Handle("CompanionMount", "GambitSave", list)
end

local function EditedRows()
    local rows = {}
    for i = 1, gambitData.max do rows[i] = gambitData.rows[i] end
    return rows
end

local function ConditionMenu(index)
    local menu = {}
    for c, list in ipairs(G_CATEGORIES) do
        local sub = {}
        for _, code in ipairs(list) do
            sub[#sub + 1] = {
                text = G.cond[code], notCheckable = true,
                func = function()
                    local rows = EditedRows()
                    local r = rows[index] or {}
                    rows[index] = { enabled = r.cond == nil and true or r.enabled, cond = code, action = r.action or GAMBIT_ATTACK }
                    SaveGambits(rows)
                    CloseDropDownMenus()
                end,
            }
        end
        menu[#menu + 1] = { text = G.cat[c], hasArrow = true, notCheckable = true, menuList = sub }
    end
    return menu
end

local function ActionMenu(index)
    local menu = {}
    local function pick(action)
        return function()
            local rows = EditedRows()
            local r = rows[index] or {}
            if action then
                rows[index] = { enabled = r.cond == nil and true or r.enabled, cond = r.cond or 43, action = action }
            else
                rows[index] = nil
                local compact = {}
                for i = 1, gambitData.max do if rows[i] then compact[#compact + 1] = rows[i] end end
                rows = compact
            end
            SaveGambits(rows)
            CloseDropDownMenus()
        end
    end
    for _, entry in ipairs(gambitData.spells or {}) do
        local id = tonumber(entry.spell)
        local name, _, icon = GetSpellInfo(id)
        menu[#menu + 1] = { text = name or ("#" .. id), icon = icon, notCheckable = true, func = pick(id) }
    end
    menu[#menu + 1] = { text = G.attack, icon = PET_ATTACK_TEXTURE, notCheckable = true, func = pick(GAMBIT_ATTACK) }
    menu[#menu + 1] = { text = G.comeBack, icon = PET_FOLLOW_TEXTURE, notCheckable = true, func = pick(GAMBIT_RETURN) }
    menu[#menu + 1] = { text = G.clear, notCheckable = true, func = pick(nil) }
    return menu
end

-- The spell a gambit names is a first rank; the bar knows the rank cast.
local function GambitSpellShown(action)
    for _, entry in ipairs(gambitData.spells or {}) do
        local id = tonumber(entry.spell)
        if id and GetSpellInfo(id) == GetSpellInfo(action) then return id end
    end
    return action
end

local function Move(index, step)
    local rows = EditedRows()
    local other = index + step
    if other < 1 or other > math.min(gambitData.slots, gambitData.max) then return end
    rows[index], rows[other] = rows[other], rows[index]
    local compact = {}
    for i = 1, gambitData.max do if rows[i] then compact[#compact + 1] = rows[i] end end
    SaveGambits(compact)
end

local function MakeGambitRow(i)
    local row = CreateFrame("Frame", nil, gambitFrame)
    row:SetSize(590, GAMBIT_ROW_HEIGHT - 2)
    row:SetPoint("TOPLEFT", 0, -52 - (i - 1) * GAMBIT_ROW_HEIGHT)

    row.number = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.number:SetPoint("LEFT", 0, 0)
    row.number:SetWidth(22)
    row.number:SetText(i .. ".")

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(26, 26)
    row.check:SetPoint("LEFT", 22, 0)
    row.check:SetScript("OnClick", function(self)
        local rows = EditedRows()
        if rows[i] then
            rows[i] = { enabled = self:GetChecked() and true or false, cond = rows[i].cond, action = rows[i].action }
            SaveGambits(rows)
        end
    end)
    row.check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(G.enable)
        GameTooltip:Show()
    end)
    row.check:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.condition = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.condition:SetSize(240, 22)
    row.condition:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
    row.condition:SetScript("OnClick", function(self)
        EasyMenu(ConditionMenu(i), gambitMenu, self, 0, 0, "MENU")
    end)

    row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.arrow:SetPoint("LEFT", row.condition, "RIGHT", 3, 0)
    row.arrow:SetText(">")

    row.action = CreateFrame("Button", nil, row)
    row.action:SetSize(200, 24)
    row.action:SetPoint("LEFT", row.arrow, "RIGHT", 3, 0)
    row.action.icon = row.action:CreateTexture(nil, "ARTWORK")
    row.action.icon:SetSize(22, 22)
    row.action.icon:SetPoint("LEFT")
    row.action.text = row.action:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.action.text:SetPoint("LEFT", row.action.icon, "RIGHT", 5, 0)
    row.action.text:SetPoint("RIGHT")
    row.action.text:SetJustifyH("LEFT")
    row.action:SetHighlightTexture(OPath("Interface", "QuestFrame", "UI-QuestTitleHighlight"), "ADD")
    row.action:SetScript("OnClick", function(self)
        EasyMenu(ActionMenu(i), gambitMenu, self, 0, 0, "MENU")
    end)
    row.action:SetScript("OnEnter", function(self)
        local r = gambitData.rows[i]
        if r and r.action and r.action > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink("spell:" .. GambitSpellShown(r.action))
            GameTooltip:Show()
        end
    end)
    row.action:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetPoint("LEFT", row.action, "RIGHT", 2, 6)
    row.up:SetScript("OnClick", function() Move(i, -1) end)
    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetPoint("LEFT", row.action, "RIGHT", 2, -6)
    row.down:SetScript("OnClick", function() Move(i, 1) end)

    row.locked = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.locked:SetPoint("LEFT", row.check, "RIGHT", 8, 0)

    gambitRows[i] = row
    return row
end

local function RefreshGambits()
    local open = math.min(gambitData.slots or 3, gambitData.max or 12)
    for i = 1, (gambitData.max or 10) do
        local row = gambitRows[i] or MakeGambitRow(i)
        row:Show()
        local r = gambitData.rows[i]
        if i > open then
            row.check:Hide()
            row.condition:Hide()
            row.arrow:Hide()
            row.action:Hide()
            row.up:Hide()
            row.down:Hide()
            row.locked:Show()
            row.locked:SetText(string.format(G.locked, gambitData.unlock[i] or 80))
            row.number:SetTextColor(0.5, 0.5, 0.5)
        else
            row.locked:Hide()
            row.number:SetTextColor(1, 0.82, 0)
            row.check:Show()
            row.condition:Show()
            row.arrow:Show()
            row.action:Show()
            row.up:Show()
            row.down:Show()
            row.check:SetChecked(r and r.enabled or false)
            row.check:Enable()
            if not r then row.check:Disable() end
            row.condition:SetText(r and r.cond and ConditionText(r.cond) or G.empty)
            local text, icon = ActionText(r and r.action)
            row.action.text:SetText(r and r.action and text or G.empty)
            row.action.icon:SetTexture(icon or OPath("Interface", "Buttons", "UI-EmptySlot-Disabled"))
            local dim = r and not r.enabled
            row.action.icon:SetDesaturated(dim and true or false)
            row.condition:SetAlpha(dim and 0.6 or 1)
        end
    end
    gambitStatus:SetText(gambitData.custom and G.customList or G.defaultList)
end

-- The Gambits tab of the panel: the list, its state and Reset at the bottom.
-- It asks for the list as the tab opens.
function CompanionMount_AttachGambits(page)
    gambitFrame:SetParent(page)
    gambitFrame:ClearAllPoints()
    gambitFrame:SetAllPoints(page)
    gambitFrame:Show()
    gambitReset:SetParent(gambitFrame)
    gambitReset:ClearAllPoints()
    gambitReset:SetSize(130, 24)
    gambitReset:SetPoint("BOTTOMRIGHT", gambitFrame, "BOTTOMRIGHT", 0, 6)
    gambitStatus:ClearAllPoints()
    gambitStatus:SetPoint("BOTTOMLEFT", gambitFrame, "BOTTOMLEFT", 0, 12)
    RefreshGambits()
    page:HookScript("OnShow", function() AIO.Handle("CompanionMount", "GambitOpen") end)
end

function CompanionMount_ToggleGambits()
    Panel.Toggle(2)
end

function Handlers.Gambits(_, data)
    if type(data) ~= "table" then return end
    gambitData = data
    gambitData.rows = type(data.rows) == "table" and data.rows or {}
    gambitData.unlock = type(data.unlock) == "table" and data.unlock or {}
    if gambitFrame:IsVisible() then RefreshGambits() end
end


-- The spell bar: a spell the energy can not pay is dimmed blue, as the
-- game dims a spell without mana.
RefreshSpellEnergy = function()
    for _, b in ipairs(spellButtons) do
        if b.spell and b:IsShown() and state.summoned then
            if (b.cost or 0) > companionEnergy then
                b.icon:SetVertexColor(0.4, 0.4, 1)
            else
                b.icon:SetVertexColor(1, 1, 1)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The server
-- ---------------------------------------------------------------------------

function Handlers.State(_, newState)
    if type(newState) ~= "table" then return end
    state = newState
    UI.Refresh()
    RefreshBar()
end

function Handlers.Sheet(_, sheet)
    if type(sheet) ~= "table" then return end
    UI.sheet = sheet
    state.command = tonumber(sheet.command_state) or state.command
    state.react = tonumber(sheet.react_state) or state.react
    state.mount = tonumber(sheet.mount_spell) or state.mount
    UI.Refresh()
    RefreshBar()
end

SLASH_COMPANIONMOUNT1 = "/companion"
SLASH_COMPANIONMOUNT2 = "/compagnon"
SlashCmdList["COMPANIONMOUNT"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(%S*)")
    if msg == "sacoches" or msg == "bag" then
        CompanionMount_ToggleBag()
    elseif msg == "talents" then
        CompanionMount_ToggleTalents()
    elseif msg == "gambits" or msg == "gambit" then
        CompanionMount_ToggleGambits()
    elseif msg == "barre" or msg == "bar" then
        barHidden = not barHidden
        RefreshBar()
    else
        CompanionMount_Toggle()
    end
end

AIO.Handle("CompanionMount", "Hello")
