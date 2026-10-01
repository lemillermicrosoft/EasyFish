local _, EF = ...
if not EF then return end

local panel = CreateFrame("Frame")
panel.name = "EasyFish Forever"
EF.optionsPanel = panel

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("EasyFish Forever")

local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
subtitle:SetWidth(600)
subtitle:SetJustifyH("LEFT")
subtitle:SetText("A conservative Interface 16001 port. Every equip, lure, and cast step requires a separate physical click.")

local showButton = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
showButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -18)
showButton.Text:SetText("Show the on-screen fishing action button")
showButton:SetScript("OnClick", function(self)
    EF.db.showButton = self:GetChecked() and true or false
    EF.ApplyAppearance()
end)

local function createButton(text, x, y, width)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", x, y)
    button:SetSize(width or 210, 24)
    button:SetText(text)
    return button
end

local appearanceValues = { "native", "original", "custom" }
local appearance = createButton("Appearance", 16, -120, 250)
local function updateAppearanceText()
    appearance:SetText("Appearance: " .. tostring(EF.db and EF.db.appearance or "native"))
end
appearance:SetScript("OnClick", function()
    local current = 1
    for index, value in ipairs(appearanceValues) do
        if value == EF.db.appearance then current = index end
    end
    EF.db.appearance = appearanceValues[(current % #appearanceValues) + 1]
    EF.ApplyAppearance()
    updateAppearanceText()
end)

local bindingValues = { "NONE", "ALT-F", "ALT-BUTTON2", "SHIFT-BUTTON2" }
local binding = createButton("Quick binding", 16, -154, 250)
local function updateBindingText()
    binding:SetText("Quick binding: " .. tostring(EF.db and EF.db.bindingKey or "NONE"))
end
binding:SetScript("OnClick", function()
    if InCombatLockdown and InCombatLockdown() then
        EF.Say("bindings cannot be changed in combat")
        return
    end
    local current = 1
    for index, value in ipairs(bindingValues) do
        if value == EF.db.bindingKey then current = index end
    end
    EF.SetBindingKey(bindingValues[(current % #bindingValues) + 1])
    updateBindingText()
end)

local bindingHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
bindingHelp:SetPoint("TOPLEFT", binding, "BOTTOMLEFT", 0, -6)
bindingHelp:SetWidth(600)
bindingHelp:SetJustifyH("LEFT")
bindingHelp:SetText("Recommended: ALT-BUTTON2. NONE leaves input entirely to WoW's native Key Bindings panel. Plain BUTTON2/double-right is not offered.")

local refresh = createButton("Refresh prepared action", 16, -218, 250)
refresh:SetScript("OnClick", function()
    EF.RefreshAction()
    EF.Say("prepared action refreshed")
end)

local resetPosition = createButton("Reset button position", 282, -218, 210)
resetPosition:SetScript("OnClick", function() EF.ResetButtonPosition() end)

local import = createButton("Import original EasyFish lure order", 16, -252, 250)
import:SetScript("OnClick", function()
    local _, message = EF.ImportLegacy()
    EF.Say(message)
end)

local importHelp = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
importHelp:SetPoint("TOPLEFT", import, "BOTTOMLEFT", 0, -6)
importHelp:SetWidth(600)
importHelp:SetJustifyH("LEFT")
importHelp:SetText("Import is opt-in and never modifies EasyFishDB. The original EasyFish addon must be enabled for its SavedVariables to be loaded.")

local warning = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
warning:SetPoint("TOPLEFT", 16, -330)
warning:SetWidth(600)
warning:SetJustifyH("LEFT")
warning:SetText("|cffffcc00No bite detection or bobber auto-loot.|r Right-click the bobber yourself after a bite. Ctrl + left-drag moves the action button; right-clicking the action button restores the main-hand weapon EasyFish replaced.")

local state = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
state:SetPoint("TOPLEFT", warning, "BOTTOMLEFT", 0, -18)
state:SetWidth(600)
state:SetJustifyH("LEFT")

panel:SetScript("OnShow", function()
    if not EF.db then return end
    showButton:SetChecked(EF.db.showButton)
    updateAppearanceText()
    updateBindingText()
    local action = EF.currentAction and EF.currentAction[3] or "not prepared"
    state:SetText("Current prepared action: " .. tostring(action) .. "\nVersion: " .. EF.VERSION .. " | Interface: " .. EF.INTERFACE)
end)

local category
local function registerOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        EF.optionsCategoryID = category.GetID and category:GetID() or panel.name
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        EF.optionsCategoryID = panel.name
    end
end

function EF.OpenOptions()
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(EF.optionsCategoryID)
        return
    end
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    registerOptions()
end)
