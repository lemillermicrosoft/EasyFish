-- EasyFish
-- Double right-click in empty world to apply bait to your fishing pole.
-- Initial scaffold: loads, registers slash command, prints hello.

local addonName, ns = ...
EasyFish = ns

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedName)
    if event == "ADDON_LOADED" and loadedName == addonName then
        EasyFishDB = EasyFishDB or {}
        print("|cff33b3ffEasyFish|r loaded. Type /easyfish for options.")
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

SLASH_EASYFISH1 = "/easyfish"
SLASH_EASYFISH2 = "/ef"
SlashCmdList["EASYFISH"] = function(msg)
    print("|cff33b3ffEasyFish|r: not yet implemented. Coming soon: double right-click to apply bait.")
end
