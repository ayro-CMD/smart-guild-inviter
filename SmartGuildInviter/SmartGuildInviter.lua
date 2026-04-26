-- ==============================
-- DETECTION VERSIONE WOW
-- ==============================
local _, _, _, tocversion = GetBuildInfo()

local WOW_PROJECT_CLASSIC                 = _G.WOW_PROJECT_CLASSIC or 2
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
local WOW_PROJECT_WRATH_CLASSIC           = _G.WOW_PROJECT_WRATH_CLASSIC or 11
local WOW_PROJECT_MAINLINE                = _G.WOW_PROJECT_MAINLINE or 1

local projectId = _G.WOW_PROJECT_ID

local IS_CLASSIC_ERA  = (projectId == WOW_PROJECT_CLASSIC) or (tocversion == 11404) or (tocversion == 11403)
local IS_TBC_CLASSIC   = (projectId == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) or (tocversion == 20504)
local IS_WRATH_CLASSIC = (projectId == WOW_PROJECT_WRATH_CLASSIC) or (tocversion == 30403) or (tocversion == 30300)
local IS_RETAIL = (projectId == WOW_PROJECT_MAINLINE) or (tocversion >= 90000)

if not IS_CLASSIC_ERA and not IS_TBC_CLASSIC and not IS_WRATH_CLASSIC and not IS_RETAIL then
    IS_WRATH_CLASSIC = true
end

local VERSION_TEXT = IS_CLASSIC_ERA and "Classic Era/SoD" or
                     IS_TBC_CLASSIC and "TBC Classic" or
                     IS_WRATH_CLASSIC and "Wrath Classic" or
                     IS_RETAIL and "Retail/Midnight" or "Unknown"

print("|cff00ff00[SGI]|r Detected version: " .. VERSION_TEXT .. " (TOC: " .. (tocversion or "unknown") .. ")")

-- ==============================
-- API COMPATIBILITY WRAPPERS
-- ==============================
local function SGI_After(delay, callback)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, callback)
    else
        local timerFrame = CreateFrame("Frame")
        timerFrame.elapsed = 0
        timerFrame:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= delay then
                self:SetScript("OnUpdate", nil)
                callback()
            end
        end)
    end
end

local function SGI_CanInviteToGuild()
    if IS_RETAIL then
        return C_GuildInfo and C_GuildInfo.CanGuildInvite and C_GuildInfo.CanGuildInvite()
    else
        if CanGuildInvite then
            return CanGuildInvite()
        end
        return IsInGuild()
    end
end

local function SGI_InviteToGuild(name)
    if IS_RETAIL then
        if C_GuildInfo and C_GuildInfo.Invite then
            return C_GuildInfo.Invite(name)
        end
    else
        if GuildInvite then
            return GuildInvite(name)
        end
    end
    return false
end

local function SGI_SendWhisper(target, message)
    if message and message ~= "" then
        SendChatMessage(message, "WHISPER", nil, target)
        return true
    end
    return false
end

local function SGI_GetMaxLevel()
    if GetMaxPlayerLevel then
        local lvl = GetMaxPlayerLevel()
        if lvl and lvl > 0 then return lvl end
    end
    if IS_RETAIL then
        return 80
    elseif IS_WRATH_CLASSIC then
        return 80
    elseif IS_TBC_CLASSIC then
        return 70
    elseif IS_CLASSIC_ERA then
        return 60
    else
        return 80
    end
end

local function SGI_IsTargetInGuild()
    if UnitInGuild then
        return UnitInGuild("target")
    elseif GetGuildInfo then
        return GetGuildInfo("target") ~= nil
    end
    return false
end

-- ==============================
-- CONFIGURAZIONE SALVATA
-- ==============================
SGI_Config = SGI_Config or {
    minLevel = 1,
    maxLevel = SGI_GetMaxLevel(),
    whisperMessage = "Hello! You have been invited to our guild! Welcome!"
}

if SGI_Config.maxLevel ~= SGI_GetMaxLevel() then
    SGI_Config.maxLevel = SGI_GetMaxLevel()
end

-- ==============================
-- FUNZIONE DI CONTROLLO FILTRO
-- ==============================
local function IsTargetEligible()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print("|cffff0000[SGI]|r No valid player target selected.")
        return false
    end

    local level = UnitLevel("target")
    if level < SGI_Config.minLevel or level > SGI_Config.maxLevel then
        print("|cffff0000[SGI]|r Level " .. level .. " is outside range (" .. SGI_Config.minLevel .. "-" .. SGI_Config.maxLevel .. ").")
        return false
    end

    if SGI_IsTargetInGuild() then
        print("|cffff0000[SGI]|r Target is already in a guild.")
        return false
    end

    if not SGI_CanInviteToGuild() then
        print("|cffff0000[SGI]|r You don't have permission to invite to guild.")
        return false
    end

    return true
end

-- ==============================
-- FUNZIONE INVITO CON WHISPER
-- ==============================
local function InviteWithWhisper(targetName)
    local success = SGI_InviteToGuild(targetName)

    if success ~= false then
        print("|cff00ff00[SGI]|r Successfully invited: " .. targetName)

        if SGI_Config.whisperMessage and SGI_Config.whisperMessage ~= "" then
            SGI_SendWhisper(targetName, SGI_Config.whisperMessage)
            print("|cff00ff00[SGI]|r Whisper sent to: " .. targetName)
        end
        return true
    else
        print("|cffff0000[SGI]|r Failed to invite " .. targetName)
        return false
    end
end

-- ==============================
-- PULSANTE "INVITA TARGET" UNIVERSALE
-- ==============================
local inviteButton = CreateFrame("Button", "SGI_InviteButton", UIParent, "UIPanelButtonTemplate")
inviteButton:SetSize(130, 35)
inviteButton:SetText("Invite to Guild")
inviteButton:SetPoint("CENTER", 0, 0)
inviteButton:SetMovable(true)
inviteButton:EnableMouse(true)
inviteButton:RegisterForDrag("LeftButton")
inviteButton:SetClampedToScreen(true)

inviteButton:SetScript("OnDragStart", function(self)
    self:StartMoving()
    self.isMoving = true
end)

inviteButton:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    self.isMoving = false
end)

inviteButton:SetScript("OnClick", function()
    if IsTargetEligible() then
        local targetName = UnitName("target")
        if targetName then
            InviteWithWhisper(targetName)
        end
    end
end)

inviteButton:SetNormalFontObject("GameFontNormal")
inviteButton:SetHighlightFontObject("GameFontHighlight")
inviteButton:SetDisabledFontObject("GameFontDisable")

local bg = inviteButton:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
if IS_RETAIL then
    bg:SetColorTexture(0.1, 0.1, 0.2, 0.8)
elseif IS_WRATH_CLASSIC then
    bg:SetColorTexture(0.2, 0.1, 0.1, 0.8)
else
    bg:SetColorTexture(0.1, 0.2, 0.1, 0.8)
end

inviteButton:Hide()

-- ==============================
-- BOTTONE MINIMAPPA
-- ==============================
local miniBtn = CreateFrame("Button", "SGI_MinimapButton", Minimap)
miniBtn:SetSize(28, 28)
miniBtn:SetFrameStrata("MEDIUM")
miniBtn:SetFrameLevel(10)

local bgCircle = miniBtn:CreateTexture(nil, "BACKGROUND")
bgCircle:SetAllPoints()
bgCircle:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bgCircle:SetTexCoord(0, 1, 0, 1)

local border = miniBtn:CreateTexture(nil, "BORDER")
border:SetSize(36, 36)
border:SetPoint("CENTER")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local icon = miniBtn:CreateTexture(nil, "ARTWORK")
icon:SetSize(20, 20)
icon:SetPoint("CENTER")

local iconPaths = {
    "Interface\\AddOns\\SmartGuildInviter\\icon.tga",
    "Interface\\AddOns\\SmartGuildInviter\\minimap-icon.tga",
    "Interface\\GuildFrame\\GuildLogo-NoLogoSm",
    "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
    "Interface\\Icons\\INV_Elemental_Primal_Mana"
}

for _, path in ipairs(iconPaths) do
    local testTex = miniBtn:CreateTexture()
    testTex:SetTexture(path)
    if testTex:GetTexture() then
        icon:SetTexture(path)
        testTex:SetTexture(nil)
        break
    end
    testTex:SetTexture(nil)
end

local highlight = miniBtn:CreateTexture(nil, "HIGHLIGHT")
highlight:SetAllPoints(icon)
highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
highlight:SetBlendMode("ADD")

SGI_MinimapPos = SGI_MinimapPos or 45

local function UpdateMinimapButton()
    local angle = math.rad(SGI_MinimapPos)
    local x, y
    local radius = 78

    if IS_RETAIL then
        x = math.cos(angle) * radius
        y = math.sin(angle) * radius
    else
        x = math.cos(angle) * (radius * 0.9)
        y = math.sin(angle) * (radius * 0.9)
    end

    miniBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

miniBtn:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        self.isDragging = true
        self:SetScript("OnUpdate", function()
            if self.isDragging then
                local mx, my = Minimap:GetCenter()
                local px, py = GetCursorPosition()
                local scale = Minimap:GetEffectiveScale()
                px, py = px / scale, py / scale
                SGI_MinimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
                UpdateMinimapButton()
            end
        end)
    end
end)

miniBtn:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and self.isDragging then
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end
end)

miniBtn:RegisterForDrag("LeftButton")

miniBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if inviteButton:IsShown() then
            inviteButton:Hide()
            print("|cff00ff00[SGI]|r Invite button hidden")
        else
            inviteButton:Show()
            print("|cff00ff00[SGI]|r Invite button shown")
        end
    elseif button == "RightButton" then
        SGI_OpenSettings()
    end
end)

miniBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Smart Guild Inviter", 1, 1, 1)
    GameTooltip:AddLine("Version: " .. VERSION_TEXT, 0.6, 0.8, 1.0)
    GameTooltip:AddLine("Left Click: Toggle invite button", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right Click: Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move around minimap", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

miniBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ==============================
-- SLASH COMMANDS & SETTINGS
-- ==============================
SLASH_SMARTGUILDINVITER1 = "/sgi"
SLASH_SMARTGUILDINVITER2 = "/sgioptions"
SLASH_SMARTGUILDINVITER3 = "/sgihelp"

local optionsPanel

local function SGI_OpenSettings()
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("Smart Guild Inviter")
    elseif InterfaceOptionsFrame_OpenToCategory then
        if InterfaceOptionsFrame_Show then
            InterfaceOptionsFrame_Show()
        end
        InterfaceOptionsFrame_OpenToCategory("Smart Guild Inviter")
    else
        print("|cffff0000[SGI]|r Cannot open settings on this version.")
    end
    print("|cff00ff00[SGI]|r Opening settings...")
end

SlashCmdList["SMARTGUILDINVITER"] = function(msg)
    msg = msg:lower()

    if msg == "options" or msg == "config" or msg == "settings" then
        SGI_OpenSettings()
    elseif msg == "help" or msg == "?" then
        print("|cff00ff00[SGI]|r === Smart Guild Inviter Commands ===")
        print("|cff00ff00/sgi|r - Toggle invite button")
        print("|cff00ff00/sgioptions|r - Open settings panel")
        print("|cff00ff00/sgihelp|r - Show this help")
        print("|cff00ff00[SGI]|r Click minimap icon for quick access")
    elseif msg == "hide" then
        inviteButton:Hide()
        print("|cff00ff00[SGI]|r Invite button hidden")
    elseif msg == "show" then
        inviteButton:Show()
        print("|cff00ff00[SGI]|r Invite button shown")
    elseif msg == "test" then
        if UnitExists("target") and UnitIsPlayer("target") then
            local targetName = UnitName("target")
            print("|cff00ff00[SGI]|r Testing invite to: " .. targetName)
            if IsTargetEligible() then
                print("|cff00ff00[SGI]|r Target is eligible for invite")
            else
                print("|cffff0000[SGI]|r Target is NOT eligible")
            end
        else
            print("|cffff0000[SGI]|r No player target selected")
        end
    else
        if inviteButton:IsShown() then
            inviteButton:Hide()
            print("|cff00ff00[SGI]|r Invite button hidden")
        else
            inviteButton:Show()
            print("|cff00ff00[SGI]|r Invite button shown")
        end
    end
end

-- ==============================
-- SETTINGS PANEL
-- ==============================
local panelParent = InterfaceOptionsFramePanelContainer or UIParent

optionsPanel = CreateFrame("Frame", "SGI_OptionsPanel", panelParent)
optionsPanel.name = "Smart Guild Inviter"
optionsPanel.okay = function() end
optionsPanel.cancel = function() end
optionsPanel.default = function() end

local title = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("Smart Guild Inviter |cFF00FF00v2.2|r")

local versionText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
versionText:SetText("Compatible with: " .. VERSION_TEXT)
versionText:SetTextColor(0.6, 0.8, 1.0)

local minLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
minLabel:SetPoint("TOPLEFT", versionText, "BOTTOMLEFT", 0, -20)
minLabel:SetText("Minimum Level:")

local minInput = CreateFrame("EditBox", "SGI_MinInput", optionsPanel, "InputBoxTemplate")
minInput:SetSize(60, 24)
minInput:SetPoint("LEFT", minLabel, "RIGHT", 10, 0)
minInput:SetAutoFocus(false)
if minInput.SetNumeric then
    minInput:SetNumeric(true)
end
minInput:SetMaxLetters(3)

local maxLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
maxLabel:SetPoint("TOPLEFT", minLabel, "BOTTOMLEFT", 0, -25)
maxLabel:SetText("Maximum Level:")

local maxInput = CreateFrame("EditBox", "SGI_MaxInput", optionsPanel, "InputBoxTemplate")
maxInput:SetSize(60, 24)
maxInput:SetPoint("LEFT", maxLabel, "RIGHT", 10, 0)
maxInput:SetAutoFocus(false)
if maxInput.SetNumeric then
    maxInput:SetNumeric(true)
end
maxInput:SetMaxLetters(3)

local maxLevelNote = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
maxLevelNote:SetPoint("LEFT", maxInput, "RIGHT", 10, 0)
maxLevelNote:SetText("(Max: " .. SGI_GetMaxLevel() .. ")")
maxLevelNote:SetTextColor(0.7, 0.7, 0.7)

local whisperLabel = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
whisperLabel:SetPoint("TOPLEFT", maxLabel, "BOTTOMLEFT", 0, -30)
whisperLabel:SetText("Whisper Message:")

local whisperInput = CreateFrame("EditBox", "SGI_WhisperInput", optionsPanel, "InputBoxTemplate")
whisperInput:SetWidth(250)
whisperInput:SetHeight(24)
whisperInput:SetPoint("TOPLEFT", whisperLabel, "BOTTOMLEFT", 0, -5)
whisperInput:SetAutoFocus(false)
whisperInput:SetMultiLine(false)
whisperInput:SetMaxLetters(255)

local whisperHelp = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
whisperHelp:SetPoint("TOPLEFT", whisperInput, "BOTTOMLEFT", 0, -5)
whisperHelp:SetText("Leave empty to disable whispers. Supports macros: {name} = player name")
whisperHelp:SetTextColor(0.7, 0.7, 0.7)

local saveButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
saveButton:SetSize(100, 25)
saveButton:SetPoint("TOPLEFT", whisperHelp, "BOTTOMLEFT", 0, -20)
saveButton:SetText("Save")
saveButton:SetScript("OnClick", function()
    SGI_Config.minLevel = tonumber(minInput:GetText()) or 1
    SGI_Config.maxLevel = tonumber(maxInput:GetText()) or SGI_GetMaxLevel()
    SGI_Config.whisperMessage = whisperInput:GetText() or ""

    if SGI_Config.maxLevel > SGI_GetMaxLevel() then
        SGI_Config.maxLevel = SGI_GetMaxLevel()
        maxInput:SetText(SGI_Config.maxLevel)
    end

    print("|cff00ff00[SGI]|r Settings saved!")
    print("|cff00ff00[SGI]|r Level range: " .. SGI_Config.minLevel .. "-" .. SGI_Config.maxLevel)
end)

local resetButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
resetButton:SetSize(100, 25)
resetButton:SetPoint("LEFT", saveButton, "RIGHT", 10, 0)
resetButton:SetText("Reset")
resetButton:SetScript("OnClick", function()
    SGI_Config.minLevel = 1
    SGI_Config.maxLevel = SGI_GetMaxLevel()
    SGI_Config.whisperMessage = "Hello! You have been invited to our guild! Welcome!"

    minInput:SetText(SGI_Config.minLevel)
    maxInput:SetText(SGI_Config.maxLevel)
    whisperInput:SetText(SGI_Config.whisperMessage)

    print("|cffffcc00[SGI]|r Settings reset to defaults")
end)

local testButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
testButton:SetSize(120, 25)
testButton:SetPoint("LEFT", resetButton, "RIGHT", 10, 0)
testButton:SetText("Test Whisper")
testButton:SetScript("OnClick", function()
    if UnitExists("target") and UnitIsPlayer("target") then
        local targetName = UnitName("target")
        local message = whisperInput:GetText() or SGI_Config.whisperMessage
        if message and message ~= "" then
            message = message:gsub("{name}", targetName or "")
            local targetLevel = UnitLevel("target")
            if targetLevel then
                message = message:gsub("{level}", tostring(targetLevel))
            end
            local _, targetClass = UnitClass("target")
            if targetClass then
                message = message:gsub("{class}", targetClass)
            end

            SGI_SendWhisper(targetName, message)
            print("|cff00ff00[SGI]|r Test whisper sent to: " .. targetName)
        else
            print("|cffff0000[SGI]|r No whisper message configured")
        end
    else
        print("|cffff0000[SGI]|r No player target selected")
    end
end)

local commandsTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
commandsTitle:SetPoint("TOPLEFT", saveButton, "BOTTOMLEFT", 0, -30)
commandsTitle:SetText("Quick Commands:")
commandsTitle:SetTextColor(1, 1, 0.5)

local commands = {
    "/sgi - Toggle invite button",
    "/sgioptions - Open settings",
    "/sgihelp - Show commands",
    "/sgi test - Test target eligibility"
}

for i, cmd in ipairs(commands) do
    local cmdText = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmdText:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 10, -((i-1)*15)-5)
    cmdText:SetText(cmd)
    cmdText:SetTextColor(0.8, 0.8, 0.8)
end

optionsPanel.refresh = function()
    minInput:SetText(SGI_Config.minLevel)
    maxInput:SetText(SGI_Config.maxLevel)
    whisperInput:SetText(SGI_Config.whisperMessage or "")
end

optionsPanel:SetScript("OnShow", optionsPanel.refresh)

-- Register with Interface Options
if InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(optionsPanel)
end

-- Register with new Settings API
if Settings and Settings.RegisterAddOnCategory then
    local category, layout = Settings.RegisterCanvasLayoutCategory(optionsPanel, optionsPanel.name)
    category.ID = optionsPanel.name
    Settings.RegisterAddOnCategory(category)
end

-- ==============================
-- INITIALIZATION
-- ==============================
local function InitializeAddon()
    UpdateMinimapButton()

    local function ShowWelcome()
        print("|cff00ff00========================|r")
        print("|cff00ff00Smart Guild Inviter v2.2|r")
        print("|cff00ff00Compatible with: " .. VERSION_TEXT .. "|r")
        print("|cff00ff00Type |cffffff00/sgi|r to toggle invite button")
        print("|cff00ff00Type |cffffff00/sgihelp|r for commands")
        print("|cff00ff00Click minimap icon for quick access|r")
        print("|cff00ff00========================|r")
    end

    SGI_After(2, ShowWelcome)
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "SmartGuildInviter" then
        InitializeAddon()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

local minimapFrame = CreateFrame("Frame")
minimapFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
minimapFrame:SetScript("OnEvent", UpdateMinimapButton)