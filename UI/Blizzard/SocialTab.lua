-- A tab on the Friends window (O) that opens the journal.
--
-- The client is 3.3.5a: its Social window is FriendsFrame, whose tabs are
-- FriendsFrameTab1..5, made by FrameXML (PanelTemplates_SetNumTabs(FriendsFrame,
-- 5); the WHO tab is disabled; the rest are Friends, Guild, Chat, Raid). We add
-- one more button after the last tab the client has, built from the same
-- template so it looks native.
--
-- Ours stays outside the window's tab system: we never call
-- PanelTemplates_SetNumTabs and never write FriendsFrame.selectedTab (which
-- FriendsFrame_Update switches on, with no branch past 5), so a click cannot
-- leave Blizzard's window parked on a tab index it does not know. The click
-- closes the window and opens the book, which is what the side tab on retail's
-- Social frame did.
--
-- The build runs inside one pcall and under ENABLED: if the client surprises us
-- (another tab count, no tab template) no tab is registered at all and the
-- journal stays reachable from the minimap button.

local addonName, ns = ...

local L = ns.L

-- The off switch: false and no tab is ever created.
local ENABLED = true

-- The tab this file built, for the checks below. Local: no other layer calls
-- it, so it is not one of ns.UI's entry points (tests/ui_layout.lua).
local FriendsTab = {}

-- FrameXML spaces the window's own tabs 15 to the left of each other.
local GAP = -15

-- The icon the minimap button wears (UI/Blizzard/Minimap.lua registered it).
local LOGO = "minimapLogo"
local LOGO_SIZE = 20

local function PlayTabSound()
    if SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
        pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
    else
        pcall(PlaySound, "igCharacterInfoTab")
    end
end

-- The last of the window's own tabs this client has: the highest index that
-- exists, whether or not it is shown (WHO is hidden here, Raid is not).
local function LastNativeTab()
    local last
    for i = 1, 12 do
        local native = _G["FriendsFrameTab" .. i]
        if native then last = native end
    end
    return last
end

local function OpenJournal()
    if HideUIPanel then
        pcall(HideUIPanel, FriendsFrame)
    else
        FriendsFrame:Hide()
    end
    ns.UI.OpenJournal()
end

-- A button from the window's tab template, or a plain one when this client
-- has no such template (the tooltip and the click are ours either way).
local function MakeTab()
    local ok, tab = pcall(CreateFrame, "Button", FriendsTab.name, FriendsFrame, "FriendsFrameTabTemplate")
    if ok and tab then return tab, tab.SetText ~= nil end
    tab = CreateFrame("Button", FriendsTab.name, FriendsFrame)
    return tab, false
end

local function Build()
    local last = LastNativeTab()

    local tab, templated = MakeTab()

    -- As wide as the words need: the window's tabs are sized by
    -- PanelTemplates for English labels, and "Social Diary" is longer.
    local needed = 74
    if templated then
        tab:SetText(L["Social Diary"])
        local fs = tab.GetFontString and tab:GetFontString()
        if fs then
            local w = fs:GetStringWidth()
            if w and w > 0 then needed = w + LOGO_SIZE + 16 end
        end
    else
        tab:SetSize(74, 22)
        local text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER")
        text:SetText(L["Social Diary"])
        tab.text = text
        local w = text:GetStringWidth()
        if w and w > 0 then needed = w + 16 end
    end

    -- The logo the minimap button wears, small, before the text: the tab
    -- reads as ours and not as one more Blizzard tab.
    tab.logo = tab:CreateTexture(nil, "ARTWORK")
    tab.logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    tab.logo:SetTexture(ns.Style.Art(LOGO))

    tab:ClearAllPoints()
    if last then
        tab:SetPoint("LEFT", last, "RIGHT", GAP, 0)
    else
        -- No tab found: sit where FrameXML puts the first one.
        tab:SetPoint("BOTTOMLEFT", FriendsFrame, "BOTTOMLEFT", 11, 46)
    end
    -- Never narrower than the native tabs, never narrower than the words.
    local native = last and last:GetWidth() or 0
    if native > needed then needed = native end
    tab:SetWidth(needed)

    -- The logo goes in the tab's left end, the text keeps the middle; both
    -- are laid out again whenever the client re-sizes the tabs.
    local function PlaceLogo()
        if tab.text then
            tab.logo:SetPoint("LEFT", tab, "LEFT", 8, 0)
        else
            tab.logo:SetPoint("LEFT", tab, "LEFT", 6, 0)
            local text = tab:GetFontString()
            if text then text:SetPoint("LEFT", tab.logo, "RIGHT", 4, 0) end
        end
    end
    PlaceLogo()

    ns.Style.Tooltip(tab, { { L["Social Diary"] }, { L["Open your journal."], 1, 1, 1 } }, "ANCHOR_RIGHT",
        function(self, over)
            if self.logo then self.logo:SetAlpha(over and 1 or 0.75) end
        end)
    tab.logo:SetAlpha(0.75)

    -- Replaces the template's OnClick, which would have told PanelTemplates
    -- this button is a tab of the window (and set a selectedTab of nil).
    tab:SetScript("OnClick", function()
        PlayTabSound()
        OpenJournal()
    end)

    FriendsTab.frame = tab
    return tab
end

local function Try()
    if not ENABLED or FriendsTab.frame then return end
    if not FriendsFrame then return end

    local ok, err = pcall(Build)
    if not ok then
        FriendsTab.error = tostring(err)
        FriendsTab.frame = nil
    end
end

ns.On("PLAYER_LOGIN", Try)

-- The window ships in Blizzard_FriendsFrame on some builds; build as soon as
-- the frame exists either way.
ns.On("ADDON_LOADED", function()
    if not FriendsTab.frame then Try() end
end)
