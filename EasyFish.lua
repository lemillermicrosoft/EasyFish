-- EasyFish
-- Double right-click in empty world to apply bait to your fishing pole.
--
-- Behavior:
--   * When a fishing pole is equipped in main-hand, double right-clicking
--     empty world (no target, no mouseover) applies your top preferred bait
--     from bags to the pole. Silent no-op if pole not equipped or lure
--     already active.
--
-- SavedVariable: EasyFishDB
--   preferredBait: ordered list of bait item names (highest priority first).

local addonName, ns = ...
EasyFish = ns

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

local DOUBLECLICK_WINDOW = 0.30 -- seconds
local FISHING_POLE_SUBTYPE = "Fishing Poles" -- TBC 2.5.6 GetItemInfo subtype for poles

local PREFIX = "|cff33b3ffEasyFish|r"

-------------------------------------------------
-- Utilities
-------------------------------------------------

local function say(msg)
    print(PREFIX .. ": " .. msg)
end

local function isFishingPoleEquipped()
    local link = GetInventoryItemLink("player", 16) -- 16 = main hand
    if not link then return false end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(link)
    if itemSubType == FISHING_POLE_SUBTYPE then return true end
    -- Fallback: some clients localize "Fishing Poles". Match by localized name via GetAuctionItemSubClasses is overkill;
    -- just look for "Fishing" in itemSubType as a safety net.
    if itemSubType and string.find(itemSubType, "Fishing") then return true end
    return false
end

local function hasFishingLureBuff()
    -- Main-hand weapon enchant slot; second return is expiration ms.
    local hasMainHandEnchant = GetWeaponEnchantInfo()
    return hasMainHandEnchant and true or false
end

local function findFirstBaitInBags(preferredList)
    -- Walk preferred list in order; return first item found in any bag.
    for _, baitName in ipairs(preferredList) do
        local count = GetItemCount(baitName)
        if count and count > 0 then
            return baitName
        end
    end
    return nil
end

local function isEmptyWorldClick()
    -- Skip if a target exists or mouse is over a UI frame / unit.
    if UnitExists("target") then return false end
    if UnitExists("mouseover") then return false end
    local focus = GetMouseFocus()
    if focus and focus ~= WorldFrame then return false end
    -- SpellIsTargeting means the client is waiting for a click cast; don't interfere.
    if SpellIsTargeting and SpellIsTargeting() then return false end
    return true
end

-------------------------------------------------
-- Core: try to apply bait
-------------------------------------------------

local function tryApplyBait()
    if not isFishingPoleEquipped() then return end
    if hasFishingLureBuff() then return end -- silent skip when already lured

    local db = EasyFishDB or {}
    local preferred = db.preferredBait or DEFAULT_BAIT
    local bait = findFirstBaitInBags(preferred)
    if not bait then
        say("no bait in bags")
        return
    end

    -- Combat safety: UseItemByName is protected in combat. Fishing is always
    -- out of combat, but check anyway.
    if InCombatLockdown() then return end

    UseItemByName(bait)
    say("applied " .. bait)
end

-------------------------------------------------
-- Double-right-click detector on WorldFrame
-------------------------------------------------

local lastRightClick = 0

local function onWorldFrameMouseDown(self, button)
    if button ~= "RightButton" then return end
    if not isEmptyWorldClick() then
        lastRightClick = 0
        return
    end
    local now = GetTime()
    if (now - lastRightClick) <= DOUBLECLICK_WINDOW then
        tryApplyBait()
        lastRightClick = 0
    else
        lastRightClick = now
    end
end

-- Hook without breaking existing OnMouseDown handlers on WorldFrame.
WorldFrame:HookScript("OnMouseDown", onWorldFrameMouseDown)

-------------------------------------------------
-- Load / SavedVariables
-------------------------------------------------

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedName)
    if event == "ADDON_LOADED" and loadedName == addonName then
        EasyFishDB = EasyFishDB or {}
        if not EasyFishDB.preferredBait then
            EasyFishDB.preferredBait = {}
            for i, v in ipairs(DEFAULT_BAIT) do EasyFishDB.preferredBait[i] = v end
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
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "" or msg == "help" then
        say("commands:")
        print("  /ef list          - show preferred bait order")
        print("  /ef reset         - reset to defaults")
        print("  /ef prefer <name> - move <name> to top of preference list")
        print("  /ef test          - dry-run bait selection (no application)")
        return
    end

    if msg == "list" then
        say("preferred bait order:")
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
        say("preferred bait reset to defaults")
        return
    end

    if msg == "test" then
        if not isFishingPoleEquipped() then say("test: no fishing pole equipped"); return end
        if hasFishingLureBuff() then say("test: pole is already lured"); return end
        local bait = findFirstBaitInBags(EasyFishDB.preferredBait or DEFAULT_BAIT)
        if bait then say("test: would apply " .. bait) else say("test: no bait in bags") end
        return
    end

    local prefer = msg:match("^prefer%s+(.+)$")
    if prefer and prefer ~= "" then
        -- Move prefer to top; if it wasn't in the list, prepend.
        local list = EasyFishDB.preferredBait or {}
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
