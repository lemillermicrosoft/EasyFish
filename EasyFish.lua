-- EasyFish
-- Alt + double right-click in the empty game world to fish.
--
-- One press advances the next required step:
--   1. Equip a fishing pole from bags (if none is main-hand equipped).
--   2. Apply the top-priority available lure (if the pole has no lure buff).
--   3. Cast Fishing.
--
-- Why a state machine? WoW's "Interface Action" APIs (EquipItemByName,
-- UseItemByName, CastSpellByName) are protected: they only fire when driven
-- by a real hardware click on a SecureActionButton, and each click can only
-- perform one protected action. So we split the flow across successive
-- Alt+double-right-clicks rather than trying to chain them in one press.
--
-- SavedVariable: EasyFishDB
--   preferredBait: ordered list of lure item names (highest priority first).

local addonName = ...

-------------------------------------------------
-- Defaults / constants
-------------------------------------------------

local DEFAULT_BAIT = {
    "Bright Baubles",
    "Aquadynamic Fish Attractor",
    "Aquadynamic Fish Lens",
    "Nightcrawlers",
    "Shiny Bauble",
}

local DOUBLECLICK_WINDOW = 0.50 -- seconds between the two Alt+right-clicks
local FISHING_POLE_SUBTYPE = "Fishing Poles" -- TBC 2.5.6 GetItemInfo subtype
local FISHING_SPELL = "Fishing"

local PREFIX = "|cff33b3ffEasyFish|r"
local debugEnabled = false

-------------------------------------------------
-- Utilities
-------------------------------------------------

local function say(msg)
    print(PREFIX .. ": " .. msg)
end

local function dbg(msg)
    if debugEnabled then say("debug: " .. msg) end
end

local function itemSubType(link)
    if not link then return nil end
    local _, _, _, _, _, _, subType = GetItemInfo(link)
    return subType
end

local function isPoleSubType(subType)
    if not subType then return false end
    if subType == FISHING_POLE_SUBTYPE then return true end
    -- Safety net for localized clients.
    if string.find(subType, "Fishing") then return true end
    return false
end

local function equippedPoleName()
    local link = GetInventoryItemLink("player", 16) -- main hand
    if not link then return nil end
    if not isPoleSubType(itemSubType(link)) then return nil end
    local name = GetItemInfo(link)
    return name
end

local function findPoleInBags()
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local link = GetContainerItemLink(bag, slot)
            if link and isPoleSubType(itemSubType(link)) then
                return (GetItemInfo(link))
            end
        end
    end
    return nil
end

local function hasLureBuff()
    -- Main-hand temporary weapon enchant (lure) is the first return.
    local hasMainHand = GetWeaponEnchantInfo()
    return hasMainHand and true or false
end

local function findFirstBaitInBags(preferredList)
    for _, name in ipairs(preferredList) do
        local count = GetItemCount(name)
        if count and count > 0 then
            return name
        end
    end
    return nil
end

local function isEmptyWorldClick()
    if UnitExists("mouseover") then return false, "cursor is over a unit" end
    local focus = GetMouseFocus()
    if focus and focus ~= WorldFrame then
        return false, "cursor is over a UI frame"
    end
    if SpellIsTargeting and SpellIsTargeting() then
        return false, "spell is targeting"
    end
    return true
end

-------------------------------------------------
-- Decide the next protected action
-------------------------------------------------
--
-- Returns (type, value, message) tuple:
--   type  = "item" | "spell" | nil (no-op)
--   value = item name or spell name
--   message = optional user-facing chat line to print AFTER the click
--
-- The secure button's attributes are set from this so the actual protected
-- call is dispatched by Blizzard's own action-button code path.

local function nextAction()
    local pole = equippedPoleName()
    if not pole then
        local bagPole = findPoleInBags()
        if not bagPole then
            return nil, nil, "no fishing pole equipped or in bags"
        end
        return "item", bagPole, "equipping " .. bagPole .. " (click again after it swaps)"
    end

    if not hasLureBuff() then
        local db = EasyFishDB or {}
        local preferred = db.preferredBait or DEFAULT_BAIT
        local bait = findFirstBaitInBags(preferred)
        if bait then
            return "item", bait, "applying " .. bait .. " (click again after 5s)"
        end
        -- No lure available: fall through to fishing.
        return "spell", FISHING_SPELL, "no lure in bags; casting Fishing"
    end

    return "spell", FISHING_SPELL, nil
end

-------------------------------------------------
-- Secure action button + Alt+double-right-click gate
-------------------------------------------------

local button = CreateFrame("Button", "EasyFishSecureButton", UIParent, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyUp") -- only "LeftButton" is dispatched via SetOverrideBindingClick
button:Hide() -- invisible; we drive it via the binding override
button:Show() -- must be shown for RegisterForClicks to route through

local lastArmedClick = 0
local pendingMessage = nil

local function disarmButton()
    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("spell", nil)
    pendingMessage = nil
end

-- PreClick fires *before* the secure click resolves the protected action, but
-- is still driven by the hardware event, so SetAttribute here is honored by
-- the same click. This is the standard Classic secure-button trick.
button:SetScript("PreClick", function(self)
    if InCombatLockdown() then
        disarmButton()
        dbg("in combat, ignoring")
        return
    end

    local isEmpty, reason = isEmptyWorldClick()
    if not isEmpty then
        disarmButton()
        lastArmedClick = 0
        dbg("ignored: " .. (reason or "not empty world"))
        return
    end

    local now = GetTime()
    if (now - lastArmedClick) > DOUBLECLICK_WINDOW then
        -- First click of the pair: register the timestamp but do NOT arm.
        disarmButton()
        lastArmedClick = now
        dbg("first Alt+right-click")
        return
    end

    -- Second click within window: arm the next action.
    lastArmedClick = 0
    local actionType, value, msg = nextAction()
    if not actionType then
        disarmButton()
        if msg then say(msg) end
        return
    end
    button:SetAttribute("type", actionType)
    button:SetAttribute(actionType, value)
    pendingMessage = msg
    dbg("armed " .. actionType .. "=" .. tostring(value))
end)

button:SetScript("PostClick", function(self)
    -- Disarm immediately so a stray click can't refire the same action.
    if pendingMessage then say(pendingMessage) end
    disarmButton()
end)

-------------------------------------------------
-- Load / SavedVariables / binding
-------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        EasyFishDB = EasyFishDB or {}
        if not EasyFishDB.preferredBait then
            EasyFishDB.preferredBait = {}
            for i, v in ipairs(DEFAULT_BAIT) do
                EasyFishDB.preferredBait[i] = v
            end
        end
    elseif event == "PLAYER_LOGIN" then
        -- Route Alt+RightButton to a LeftButton click on our secure button.
        -- Using an *override* binding keeps user keybinds intact and survives
        -- action-bar swaps; it's cleared at logout automatically.
        SetOverrideBindingClick(button, true, "ALT-BUTTON2", button:GetName(), "LeftButton")
    end
end)

-------------------------------------------------
-- Slash commands
-------------------------------------------------

SLASH_EASYFISH1 = "/easyfish"
SLASH_EASYFISH2 = "/ef"
SlashCmdList["EASYFISH"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""

    if msg == "" or msg == "help" then
        say("commands:")
        print("  /ef list          - show preferred lure order + bag counts")
        print("  /ef prefer <name> - move <name> to top of the priority list")
        print("  /ef reset         - restore default lure priority")
        print("  /ef test          - report the next action without arming")
        print("  /ef debug         - toggle verbose right-click logging")
        print("  /ef status        - show input binding + arm state")
        return
    end

    if msg == "status" then
        local action = GetBindingAction("ALT-BUTTON2", true)
        say("Alt+right-click binding: " .. ((action ~= "" and action) or "not registered"))
        say("secure button shown: " .. (button:IsShown() and "yes" or "no"))
        say("in combat: " .. (InCombatLockdown() and "yes" or "no"))
        return
    end

    if msg == "debug" then
        debugEnabled = not debugEnabled
        say("debug " .. (debugEnabled and "enabled" or "disabled"))
        return
    end

    if msg == "list" then
        say("preferred lure order:")
        local list = (EasyFishDB and EasyFishDB.preferredBait) or DEFAULT_BAIT
        for i, name in ipairs(list) do
            local count = GetItemCount(name) or 0
            print(string.format("  %d. %s (bags: %d)", i, name, count))
        end
        return
    end

    if msg == "reset" then
        EasyFishDB.preferredBait = {}
        for i, v in ipairs(DEFAULT_BAIT) do EasyFishDB.preferredBait[i] = v end
        say("preferred lure order reset to defaults")
        return
    end

    if msg == "test" then
        local t, v, m = nextAction()
        if not t then
            say("test: " .. (m or "no action available"))
        else
            say("test: next click would fire " .. t .. "=" .. tostring(v))
            if m then say("test: (message would be: " .. m .. ")") end
        end
        return
    end

    local prefer = msg:match("^prefer%s+(.+)$")
    if prefer and prefer ~= "" then
        local list = (EasyFishDB and EasyFishDB.preferredBait) or {}
        local new = { prefer }
        for _, name in ipairs(list) do
            if name:lower() ~= prefer:lower() then table.insert(new, name) end
        end
        EasyFishDB.preferredBait = new
        say("preferred: '" .. prefer .. "' moved to top")
        return
    end

    say("unknown command. try /ef help")
end
