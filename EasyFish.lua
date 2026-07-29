-- EasyFish
-- Double-press the configured binding in the empty game world to fish.
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
-- double-taps rather than trying to chain them in one press.
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

local DOUBLECLICK_WINDOW = 0.50 -- seconds between the two input presses
local LATEBIND_DOUBLECLICK_MIN = 0.05 -- min gap for late-bind double-click detection
local LATEBIND_DOUBLECLICK_MAX = 0.40 -- max gap for late-bind double-click detection
local FISHING_POLE_SUBTYPE = "Fishing Poles" -- TBC 2.5.6 GetItemInfo subtype
local FISHING_SPELL = "Fishing"
local FISHING_BOBBER_NAME = "Fishing Bobber" -- enUS tooltip substring; other locales fall back to alt/shift modes
local BINDING_COMMAND = "CLICK EasyFishSecureButton:LeftButton"
-- Each mode declares its key + whether it requires a double press. Modes
-- with names containing `-double-` need two taps within DOUBLECLICK_WINDOW;
-- the plain modified modes fire on a single press.
--
-- Note: plain BUTTON2 (right-click) as a *static* binding is intentionally
-- NOT offered. Binding BUTTON2 to our secure button hijacks WoW's native
-- right-click, which breaks bobber looting, camera turn, and left+right
-- run-forward. Modifier modes must include Alt / Shift / Ctrl or use a
-- non-mouse key.
--
-- The `double-right` mode is special: `lateBind = true` means setBindingMode
-- does NOT install a static SetBindingClick. Instead, a GLOBAL_MOUSE_DOWN
-- handler watches for a double-right-click on empty world, and only then
-- installs a one-shot SetOverrideBindingClick for BUTTON2 which is
-- immediately cleared in PostClick via SecureHandlerWrapScript. Net effect:
-- BUTTON2 is bound for exactly one synthetic click; normal right-click,
-- camera, bobber loot, and run-forward are untouched at all other times.
local BINDING_MODES = {
    ["alt-f"]              = { key = "ALT-F",          double = false },
    ["alt-double-f"]       = { key = "ALT-F",          double = true  },
    ["alt-right"]          = { key = "ALT-BUTTON2",    double = false },
    ["alt-double-right"]   = { key = "ALT-BUTTON2",    double = true  },
    ["shift-right"]        = { key = "SHIFT-BUTTON2",  double = false },
    ["shift-double-right"] = { key = "SHIFT-BUTTON2",  double = true  },
    ["double-right"]       = { key = nil,              double = true, lateBind = true },
}

-- Back-compat table of just the keys (used for binding cleanup). Skips
-- lateBind modes which have no static key.
local BINDING_KEYS = {}
for name, info in pairs(BINDING_MODES) do
    if info.key then BINDING_KEYS[name] = info.key end
end

local PREFIX = "|cff33b3ffEasyFish|r"
local debugEnabled = false

BINDING_HEADER_EASYFISH = "EasyFish"
_G["BINDING_NAME_" .. BINDING_COMMAND] = "Advance fishing setup"

-------------------------------------------------
-- Utilities
-------------------------------------------------

local function say(msg)
    print(PREFIX .. ": " .. msg)
end

local function dbg(msg)
    if debugEnabled then say("debug: " .. msg) end
end

local function setBindingMode(mode)
    if InCombatLockdown() then
        return false, "cannot change bindings in combat"
    end

    EasyFishDB.replacedBindings = EasyFishDB.replacedBindings or {}

    for _, key in pairs(BINDING_KEYS) do
        if GetBindingAction(key) == BINDING_COMMAND then
            local previous = EasyFishDB.replacedBindings[key]
            SetBinding(key, previous ~= "" and previous or nil)
            EasyFishDB.replacedBindings[key] = nil
        end
    end

    local info = BINDING_MODES[mode]
    local key = info and info.key
    if key then
        local previous = GetBindingAction(key)
        EasyFishDB.replacedBindings[key] = previous or ""
        if not SetBindingClick(key, "EasyFishSecureButton", "LeftButton") then
            return false, "could not bind " .. key
        end
    end
    -- Late-bind modes install no static binding; the GLOBAL_MOUSE_DOWN
    -- handler wires the override on demand.

    EasyFishDB.bindingMode = mode
    SaveBindings(GetCurrentBindingSet())
    return true
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
--   type  = "item" | "macro" | "spell" | nil (no-op)
--   value = item name, macro text, or spell name
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
            local macroText = "/use " .. bait .. "\n/use 16"
            return "macro", macroText, "applying " .. bait .. " (click again after 5s)"
        end
        -- No lure available: fall through to fishing.
        return "spell", FISHING_SPELL, "no lure in bags; casting Fishing"
    end

    return "spell", FISHING_SPELL, nil
end

-------------------------------------------------
-- Secure action button + double-input gate
-------------------------------------------------

local button = CreateFrame("Button", "EasyFishSecureButton", UIParent, "SecureActionButtonTemplate")
button:SetAttribute("useOnKeyDown", false)
-- IMPORTANT: register only one phase. AnyUp+AnyDown makes a single physical
-- press fire PreClick twice (down, then up), which the double-press gate
-- would misread as a legitimate double-click.
button:RegisterForClicks("AnyUp")
button:Hide() -- invisible; we drive it via the binding override
button:Show() -- must be shown for RegisterForClicks to route through

local lastArmedClick = 0
local pendingMessage = nil

local function disarmButton()
    button:SetAttribute("type", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("macrotext", nil)
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
    local currentMode = EasyFishDB and EasyFishDB.bindingMode
    local requiresDouble = currentMode and BINDING_MODES[currentMode] and BINDING_MODES[currentMode].double

    if requiresDouble then
        if (now - lastArmedClick) > DOUBLECLICK_WINDOW then
            -- First click of the pair: register the timestamp but do NOT arm.
            disarmButton()
            lastArmedClick = now
            dbg("first input press")
            return
        end
        -- Second click within window: fall through to arm.
        lastArmedClick = 0
    else
        -- Single-press mode: arm on every qualifying click.
        lastArmedClick = 0
    end

    local actionType, value, msg = nextAction()
    if not actionType then
        disarmButton()
        if msg then say(msg) end
        return
    end
    button:SetAttribute("type", actionType)
    if actionType == "macro" then
        button:SetAttribute("macrotext", value)
    else
        button:SetAttribute(actionType, value)
    end
    pendingMessage = msg
    dbg("armed " .. actionType .. "=" .. tostring(value):gsub("\n", "; "))
end)

button:SetScript("PostClick", function(self)
    -- Disarm immediately so a stray click can't refire the same action.
    if pendingMessage then say(pendingMessage) end
    disarmButton()
end)

-- Late-bind restricted-environment cleanup: whenever the secure button's
-- PostClick fires, the restricted snippet clears any override bindings it
-- currently holds. Paired with SetOverrideBindingClick in the
-- GLOBAL_MOUSE_DOWN handler below, this makes the BUTTON2 override live
-- for exactly one synthetic click. Wrapped once at load; safe because
-- ClearBindings() is a no-op when no override is set.
SecureHandlerWrapScript(button, "PostClick", button, [[ self:ClearBindings() ]])

-------------------------------------------------
-- Late-bind (plain double-right-click) mode
-------------------------------------------------
--
-- FishingBuddy-style technique: listen to GLOBAL_MOUSE_DOWN (still on the
-- hardware-event code path so a protected call scheduled here counts as
-- user-driven). On a right-button double-press over empty world -- and only
-- if the cursor is NOT on a fishing bobber and the player is not already
-- channeling Fishing -- install SetOverrideBindingClick(BUTTON2 ->
-- EasyFishSecureButton:LeftButton). The same physical press then routes
-- through the SA button, PreClick arms the action, Blizzard fires the
-- protected action, and PostClick's SecureHandlerWrapScript snippet clears
-- the override. Any normal right-click at any other time is unaffected.

local lateBindLastRightDown = 0

local function tooltipOverFishingBobber()
    -- Peek at the GameTooltip's current lines. If it's showing a Fishing
    -- Bobber, we're hovering a bobber and must let the native right-click
    -- pass through so the bite-loot works.
    if not GameTooltip or not GameTooltip:IsShown() then return false end
    for i = 1, GameTooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        local text = line and line:GetText()
        if text and text:find(FISHING_BOBBER_NAME, 1, true) then
            return true
        end
    end
    return false
end

local function playerIsChannelingFishing()
    if not UnitChannelInfo then return false end
    local name = UnitChannelInfo("player")
    return name == FISHING_SPELL
end

local lateBindFrame = CreateFrame("Frame")
local lateBindActive = false

local function armLateBindOverride()
    local actionType, value, msg = nextAction()
    if not actionType then
        if msg then say(msg) end
        return false
    end
    button:SetAttribute("type", actionType)
    if actionType == "macro" then
        button:SetAttribute("macrotext", value)
    else
        button:SetAttribute(actionType, value)
    end
    pendingMessage = msg
    -- Install the one-shot override. PostClick's wrapped snippet will
    -- ClearBindings() as soon as the click resolves.
    if not SetOverrideBindingClick(button, true, "BUTTON2", "EasyFishSecureButton", "LeftButton") then
        disarmButton()
        dbg("SetOverrideBindingClick failed")
        return false
    end
    dbg("late-bind armed " .. actionType .. "=" .. tostring(value):gsub("\n", "; "))
    return true
end

lateBindFrame:SetScript("OnEvent", function(self, event, mouseButton)
    if event ~= "GLOBAL_MOUSE_DOWN" then return end
    if mouseButton ~= "RightButton" then return end
    if InCombatLockdown() then return end

    -- Never intercept a right-click on a fishing bobber -- the native
    -- right-click must loot the bite.
    if tooltipOverFishingBobber() then
        lateBindLastRightDown = 0
        dbg("late-bind: cursor over bobber; ignoring")
        return
    end

    -- Skip if we're already channeling Fishing.
    if playerIsChannelingFishing() then
        lateBindLastRightDown = 0
        dbg("late-bind: fishing channel active; ignoring")
        return
    end

    -- Empty-world / no-mouseover / no-UI-focus gates. Same rules as PreClick.
    local isEmpty, reason = isEmptyWorldClick()
    if not isEmpty then
        lateBindLastRightDown = 0
        dbg("late-bind: " .. (reason or "not empty world"))
        return
    end

    local now = GetTime()
    local gap = now - lateBindLastRightDown
    if gap >= LATEBIND_DOUBLECLICK_MIN and gap <= LATEBIND_DOUBLECLICK_MAX then
        -- Second press of a double-right within the window: fire.
        lateBindLastRightDown = 0
        armLateBindOverride()
    else
        -- First press (or gap too long / too short): just record it.
        lateBindLastRightDown = now
        dbg("late-bind: first right press")
    end
end)

local function setLateBindActive(active)
    if active == lateBindActive then return end
    if active then
        lateBindFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    else
        lateBindFrame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        -- Belt-and-suspenders: clear any lingering override.
        if not InCombatLockdown() then
            ClearOverrideBindings(button)
        end
    end
    lateBindActive = active
end

-- Rewire setBindingMode to also toggle the late-bind listener.
local _origSetBindingMode = setBindingMode
setBindingMode = function(mode)
    local ok, err = _origSetBindingMode(mode)
    if ok then
        setLateBindActive(mode == "double-right")
    end
    return ok, err
end

-------------------------------------------------
-- Load / SavedVariables
-------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        EasyFishDB = EasyFishDB or {}
        if not EasyFishDB.preferredBait then
            EasyFishDB.preferredBait = {}
            for i, v in ipairs(DEFAULT_BAIT) do
                EasyFishDB.preferredBait[i] = v
            end
        end
        -- New installs default to double-right (safe late-bind override).
        -- Existing users keep whatever they had set previously.
        EasyFishDB.bindingMode = EasyFishDB.bindingMode or "double-right"
        -- Migrate old plain-`right` mode (which hijacked BUTTON2 statically);
        -- the new `double-right` mode is the safe late-bind replacement.
        if EasyFishDB.bindingMode == "right" then
            EasyFishDB.bindingMode = "double-right"
        end
        -- Activate the GLOBAL_MOUSE_DOWN listener if late-bind mode is set.
        if EasyFishDB.bindingMode == "double-right" then
            setLateBindActive(true)
        end
        self:UnregisterEvent("ADDON_LOADED")
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
        print("  /ef binding <mode> - double-right, alt-right, alt-double-right, alt-f, alt-double-f, shift-right, shift-double-right, or off")
        print("    (plain-modifier modes fire on a single press; -double- modes require two taps within 0.5s)")
        print("    (double-right uses a late-bound override so native right-click, camera, and bobber loot still work)")
        print("  /ef debug         - toggle verbose input logging")
        print("  /ef status        - show input binding + arm state")
        return
    end

    if msg == "status" then
        local keyboardAction = GetBindingAction("ALT-F", true)
        local altRightAction = GetBindingAction("ALT-BUTTON2", true)
        local shiftRightAction = GetBindingAction("SHIFT-BUTTON2", true)
        say("binding mode: " .. ((EasyFishDB and EasyFishDB.bindingMode) or "unknown"))
        if EasyFishDB and EasyFishDB.bindingMode == "double-right" then
            say("late-bind listener: " .. (lateBindActive and "active" or "inactive"))
        end
        say("Alt+F binding: " .. ((keyboardAction ~= "" and keyboardAction) or "not registered"))
        say("Alt+right binding: " .. ((altRightAction ~= "" and altRightAction) or "not registered"))
        say("Shift+right binding: " .. ((shiftRightAction ~= "" and shiftRightAction) or "not registered"))
        say("secure button shown: " .. (button:IsShown() and "yes" or "no"))
        say("secure button key phase: " .. (button:GetAttribute("useOnKeyDown") and "down" or "up"))
        say("in combat: " .. (InCombatLockdown() and "yes" or "no"))
        return
    end

    if msg == "bind" then msg = "binding alt-double-right" end
    
    local bindingMode = msg:match("^binding%s+(%S+)$")
    if bindingMode and (BINDING_MODES[bindingMode] or bindingMode == "off") then
        local ok, err = setBindingMode(bindingMode)
        if not ok then
            say(err)
        elseif bindingMode == "double-right" then
            say("binding set to plain double-right-click (late-bound override; native right-click still works)")
        elseif bindingMode == "shift-right" or bindingMode == "shift-double-right" then
            local kind = (BINDING_MODES[bindingMode] and BINDING_MODES[bindingMode].double) and "double-" or ""
            say("binding set to shift+" .. kind .. "right-click")
        else
            say("binding set to " .. bindingMode)
        end
        return
    end

    if msg:match("^binding") then
        say("usage: /ef binding double-right|alt-right|alt-double-right|alt-f|alt-double-f|shift-right|shift-double-right|off")
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
