-- EasyFish Forever
-- One physical click advances at most one protected fishing action.
-- Protected attributes are prepared out of combat, never from cursor data or
-- dynamically inside PreClick. This deliberately avoids late-binding BUTTON2.

local addonName, EF = ...
EF = EF or {}
_G.EasyFishForever = EF

EF.ADDON_NAME = addonName
EF.VERSION = "0.1.0-rc1"
EF.INTERFACE = 16001
EF.FISHING_SPELL_ID = 7620
EF.PREFIX = "|cff33b3ffEasyFish Forever|r"

BINDING_HEADER_EASYFISH_FOREVER = "EasyFish Forever"
_G["BINDING_NAME_CLICK EasyFishForeverActionButton:LeftButton"] = "Advance prepared fishing action"

local DEFAULT_LURES = {
    "Sharpened Fish Hook",
    "Aquadynamic Fish Lens",
    "Aquadynamic Fish Attractor",
    "Bright Baubles",
    "Flesh Eating Worm",
    "Nightcrawlers",
    "Shiny Bauble",
}

EF.DEFAULTS = {
    schema = 1,
    appearance = "native",
    showButton = true,
    bindingKey = "NONE",
    preferredLures = DEFAULT_LURES,
    importedLegacy = false,
    buttonPoint = "CENTER",
    buttonX = 0,
    buttonY = -120,
}

local BINDING_KEYS = {
    NONE = nil,
    ["ALT-F"] = "ALT-F",
    ["ALT-BUTTON2"] = "ALT-BUTTON2",
    ["SHIFT-BUTTON2"] = "SHIFT-BUTTON2",
}

local eventFrame = CreateFrame("Frame")
local actionButton = CreateFrame("Button", "EasyFishForeverActionButton", UIParent, "SecureActionButtonTemplate")
EF.actionButton = actionButton

actionButton:SetSize(44, 44)
actionButton:RegisterForClicks("AnyUp")
actionButton:SetClampedToScreen(true)

actionButton.icon = actionButton:CreateTexture(nil, "ARTWORK")
actionButton.icon:SetPoint("TOPLEFT", 4, -4)
actionButton.icon:SetPoint("BOTTOMRIGHT", -4, 4)
actionButton.icon:SetTexture(136245)
actionButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

actionButton.background = actionButton:CreateTexture(nil, "BACKGROUND")
actionButton.background:SetAllPoints()
actionButton.background:SetColorTexture(0.08, 0.08, 0.08, 0.92)

actionButton.border = actionButton:CreateTexture(nil, "OVERLAY")
actionButton.border:SetPoint("TOPLEFT", -2, 2)
actionButton.border:SetPoint("BOTTOMRIGHT", 2, -2)
actionButton.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

actionButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
actionButton:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

actionButton.status = actionButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
actionButton.status:SetPoint("TOP", actionButton, "BOTTOM", 0, -3)
actionButton.status:SetWidth(180)
actionButton.status:SetText("Fishing")

local function say(message)
    print(EF.PREFIX .. ": " .. tostring(message))
end
EF.Say = say

local function copyArray(source)
    local result = {}
    for index, value in ipairs(source or {}) do
        result[index] = value
    end
    return result
end

local function applyDefaults()
    EasyFishForeverDB = EasyFishForeverDB or {}
    local db = EasyFishForeverDB
    for key, value in pairs(EF.DEFAULTS) do
        if db[key] == nil then
            db[key] = type(value) == "table" and copyArray(value) or value
        end
    end
    EF.db = db
end

local function isSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function safeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g = pcall(func, ...)
    if not ok then return nil end
    if isSecret(a) or isSecret(b) or isSecret(c) or isSecret(d) or isSecret(e) or isSecret(f) or isSecret(g) then
        return nil
    end
    return a, b, c, d, e, f, g
end

local function containerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return safeCall(C_Container.GetContainerNumSlots, bag) or 0
    end
    return safeCall(GetContainerNumSlots, bag) or 0
end

local function containerLink(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return safeCall(C_Container.GetContainerItemLink, bag, slot)
    end
    return safeCall(GetContainerItemLink, bag, slot)
end

local function getItemInfoInstant(item)
    if C_Item and C_Item.GetItemInfoInstant then
        return safeCall(C_Item.GetItemInfoInstant, item)
    end
    return safeCall(GetItemInfoInstant, item)
end

local function getItemName(item)
    if C_Item and C_Item.GetItemNameByID and type(item) == "number" then
        local name = safeCall(C_Item.GetItemNameByID, item)
        if name then return name end
    end
    local name = safeCall(GetItemInfo, item)
    return name
end

local function getItemCount(item)
    if C_Item and C_Item.GetItemCount then
        return safeCall(C_Item.GetItemCount, item, false, false, false) or 0
    end
    return safeCall(GetItemCount, item) or 0
end

local function fishingPoleSubclass()
    if Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole then
        return Enum.ItemWeaponSubclass.Fishingpole
    end
    return 20
end

local function isFishingPole(item)
    if not item or isSecret(item) then return false end
    local _, _, _, _, _, classID, subclassID = getItemInfoInstant(item)
    return classID == 2 and subclassID == fishingPoleSubclass()
end

local function equippedPole()
    local link = safeCall(GetInventoryItemLink, "player", 16)
    if link and isFishingPole(link) then return link end
    return nil
end

local function bagPole()
    local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, maxBag do
        for slot = 1, containerSlots(bag) do
            local link = containerLink(bag, slot)
            if link and isFishingPole(link) then return link end
        end
    end
    return nil
end

local function hasLure()
    local enchanted = safeCall(GetWeaponEnchantInfo)
    return enchanted and true or false
end

local function availableLure()
    for _, lure in ipairs(EF.db.preferredLures or DEFAULT_LURES) do
        -- SavedVariables/imported legacy data is untrusted macro input. Only
        -- ordinary single-line item names may become secure macro text.
        local safeName = type(lure) == "string"
            and #lure > 0 and #lure <= 120
            and not string.find(lure, "[\r\n]")
        if safeName and not isSecret(lure) and getItemCount(lure) > 0 then return lure end
    end
    return nil
end

local function fishingSpell()
    if C_Spell and C_Spell.GetSpellName then
        local name = safeCall(C_Spell.GetSpellName, EF.FISHING_SPELL_ID)
        if name then return name end
    end
    local name = safeCall(GetSpellInfo, EF.FISHING_SPELL_ID)
    return name or EF.FISHING_SPELL_ID
end

function EF.DecideAction()
    local pole = equippedPole()
    if not pole then
        local found = bagPole()
        if found then
            return "item", found, "Equip fishing pole"
        end
        return nil, nil, "No fishing pole found"
    end

    if not hasLure() then
        local lure = availableLure()
        if lure then
            return "macro", "/use " .. lure .. "\n/use 16", "Apply " .. lure
        end
    end

    return "spell", fishingSpell(), "Cast Fishing"
end

local function clearProtectedAttributes()
    actionButton:SetAttribute("type", nil)
    actionButton:SetAttribute("item", nil)
    actionButton:SetAttribute("macrotext", nil)
    actionButton:SetAttribute("spell", nil)
end

function EF.RefreshAction()
    if not EF.db then return end
    if InCombatLockdown and InCombatLockdown() then
        EF.refreshAfterCombat = true
        actionButton.status:SetText("Locked in combat")
        return
    end

    clearProtectedAttributes()
    local actionType, value, label = EF.DecideAction()
    if actionType then
        actionButton:SetAttribute("type", actionType)
        if actionType == "macro" then
            actionButton:SetAttribute("macrotext", value)
        else
            actionButton:SetAttribute(actionType, value)
        end
        actionButton:Enable()
    else
        actionButton:Disable()
    end
    actionButton.status:SetText(label or "Unavailable")
    EF.currentAction = { actionType, value, label }
end

function EF.ApplyBinding()
    if not EF.db then return false end
    if InCombatLockdown and InCombatLockdown() then
        EF.bindingAfterCombat = true
        return false
    end
    ClearOverrideBindings(actionButton)
    local key = BINDING_KEYS[EF.db.bindingKey]
    if key then
        SetOverrideBindingClick(actionButton, true, key, "EasyFishForeverActionButton", "LeftButton")
    end
    return true
end

function EF.SetBindingKey(key)
    if BINDING_KEYS[key] == nil and key ~= "NONE" then return false end
    EF.db.bindingKey = key
    EF.ApplyBinding()
    return true
end

function EF.ImportLegacy()
    if type(EasyFishDB) ~= "table" then
        return false, "EasyFishDB is not loaded; enable the original EasyFish once, then reload"
    end
    if type(EasyFishDB.preferredBait) == "table" and #EasyFishDB.preferredBait > 0 then
        EF.db.preferredLures = copyArray(EasyFishDB.preferredBait)
    end
    local modeMap = {
        ["alt-f"] = "ALT-F",
        ["alt-right"] = "ALT-BUTTON2",
        ["shift-right"] = "SHIFT-BUTTON2",
    }
    if modeMap[EasyFishDB.bindingMode] then
        EF.db.bindingKey = modeMap[EasyFishDB.bindingMode]
    end
    EF.db.importedLegacy = true
    EF.ApplyBinding()
    EF.RefreshAction()
    return true, "legacy lure order imported (original data was not changed)"
end

function EF.ApplyAppearance()
    if not EF.db then return end
    local mode = EF.db.appearance
    actionButton:SetNormalTexture(nil)
    actionButton.border:Show()
    if mode == "original" then
        actionButton.background:SetColorTexture(0.02, 0.12, 0.18, 0.94)
        actionButton.border:SetColorTexture(0.20, 0.70, 1.00, 1.00)
        actionButton.border:SetPoint("TOPLEFT", -2, 2)
        actionButton.border:SetPoint("BOTTOMRIGHT", 2, -2)
    elseif mode == "custom" then
        actionButton.background:SetColorTexture(0.12, 0.03, 0.16, 0.94)
        actionButton.border:SetColorTexture(0.80, 0.35, 1.00, 1.00)
    else
        actionButton.background:SetColorTexture(0.08, 0.08, 0.08, 0.92)
        actionButton.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        actionButton.border:SetVertexColor(1, 1, 1, 1)
    end
    -- CLICK bindings require the secure button to remain shown. Hiding the
    -- visual therefore uses alpha/mouse state while preserving binding clicks.
    actionButton:Show()
    actionButton:SetAlpha(EF.db.showButton and 1 or 0)
    actionButton:EnableMouse(EF.db.showButton and true or false)
end

local function resetPosition()
    actionButton:ClearAllPoints()
    actionButton:SetPoint(EF.db.buttonPoint or "CENTER", UIParent, EF.db.buttonPoint or "CENTER", EF.db.buttonX or 0, EF.db.buttonY or -120)
end

local function openOptions()
    if EF.OpenOptions then EF.OpenOptions() else say("Options are not ready; try again after login") end
end

local function status()
    local current = EF.currentAction or {}
    say("version " .. EF.VERSION .. ", Interface " .. EF.INTERFACE)
    say("next action: " .. tostring(current[3] or "not prepared"))
    say("quick binding: " .. tostring(EF.db.bindingKey) .. " (native Key Bindings also supported)")
    say("combat lockdown: " .. ((InCombatLockdown and InCombatLockdown()) and "yes" or "no"))
end

SLASH_EASYFISHFOREVER1 = "/easyfishforever"
SLASH_EASYFISHFOREVER2 = "/eff"
SlashCmdList.EASYFISHFOREVER = function(raw)
    local command, argument = string.match(raw or "", "^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    if command == "" or command == "options" then openOptions(); return end
    if command == "status" then status(); return end
    if command == "refresh" then EF.RefreshAction(); say("action state refreshed"); return end
    if command == "import" then
        local ok, message = EF.ImportLegacy()
        say(message)
        return
    end
    if command == "bind" then
        local aliases = { off = "NONE", none = "NONE", ["alt-f"] = "ALT-F", ["alt-right"] = "ALT-BUTTON2", ["shift-right"] = "SHIFT-BUTTON2" }
        local key = aliases[string.lower(argument or "")]
        if key and EF.SetBindingKey(key) then say("quick binding set to " .. key); return end
        say("usage: /eff bind off|alt-f|alt-right|shift-right")
        return
    end
    if command == "help" then
        say("/eff options, /eff status, /eff refresh, /eff import, /eff bind <off|alt-f|alt-right|shift-right>")
        say("Plain double-right-click is intentionally unsupported on the restricted client; use a modifier or native Key Bindings.")
        return
    end
    say("unknown command; use /eff help")
end

actionButton:SetScript("PostClick", function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, EF.RefreshAction)
        C_Timer.After(1.25, EF.RefreshAction)
    end
end)

actionButton:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("EasyFish Forever")
    GameTooltip:AddLine((EF.currentAction and EF.currentAction[3]) or "Fishing action", 1, 1, 1)
    GameTooltip:AddLine("One click performs one prepared action.", 0.75, 0.75, 0.75)
    GameTooltip:Show()
end)
actionButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        applyDefaults()
        resetPosition()
        EF.ApplyAppearance()
        EF.RefreshAction()
    elseif event == "PLAYER_LOGIN" then
        EF.ApplyBinding()
        EF.RefreshAction()
        if not EF.db.seenStartup then
            EF.db.seenStartup = true
            say("ready. Open Esc > Options > AddOns > EasyFish Forever, or type /eff help.")
            say("Choose a modifier binding or WoW Key Bindings; plain double-right is disabled for taint safety.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if EF.bindingAfterCombat then EF.bindingAfterCombat = nil; EF.ApplyBinding() end
        if EF.refreshAfterCombat then EF.refreshAfterCombat = nil end
        EF.RefreshAction()
    elseif event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
        return
    elseif EF.db then
        EF.RefreshAction()
    end
end)
