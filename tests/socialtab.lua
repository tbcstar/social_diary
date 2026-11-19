-- The tab on the Social window (UI/Blizzard/SocialTab.lua): the button it
-- builds carries the name that FrameXML's tab scripts look its pieces up by,
-- and the template's OnShow — the handler that needs that name — is gone.
--
-- In game on 19 Nov 2026 the Social window raised "attempt to concatenate
-- local 'tabName' (a nil value)" from FrameXML/UIPanelTemplates.lua:41 every
-- time something showed it (DragonUI's warm-up did): our tab came out of
-- FriendsFrameTabTemplate without a name, and the template's OnShow hands the
-- button to PanelTemplates_TabResize, which concatenates GetName().
--
-- The mock builds no templates, so this test installs the one half that
-- matters — the template's OnShow, attached as the client attaches it, on any
-- button made from FriendsFrameTabTemplate.

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq

local NAME = "SocialDiaryFriendsTab"

-- The template's OnShow, in the shape that hurts: it reaches the button's
-- pieces through its name (the mock has no GetName, so it reads the name
-- CreateFrame filed).
local function WithTabTemplate()
    local createFrame = _G.CreateFrame
    _G.CreateFrame = function(frameType, name, parent, template)
        local w = createFrame(frameType, name, parent, template)
        if template == "FriendsFrameTabTemplate" then
            w.scripts.OnShow = function(self)
                local middle = _G[tostring(self.recorded.globalName) .. "Middle"]
                if not middle then error("a tab of this template has no name", 0) end
            end
        end
        return w
    end
end

--------------------------------------------------------------------------
Section("the tab, built when the client logs in")

-- The addon, loaded but before any event: the Social window exists by the
-- time the client fires the first of these, as on the machine.
local ns = T.Load()
WithTabTemplate()
local window = _G.CreateFrame("Frame", "FriendsFrame", _G.UIParent)
-- The window's own last tab: a width, as the client always has one (the mock
-- reports none until told, and Build reads it).
local native = _G.CreateFrame("Button", "FriendsFrameTab1", window)
native:SetWidth(96)

mock.SetUnit("player", T.F.SELF)
mock.fire("ADDON_LOADED", ns.addonName)
ns.db.settings.introSeen = true
mock.fire("PLAYER_LOGIN")

local tab = _G[NAME]
Check(tab, "no tab under the name FrameXML looks a tab up by")
Eq(tab and tab.parent, window, "the tab is not the Social window's child")
Eq(tab and tab.template, "FriendsFrameTabTemplate", "the tab is not built from the client's tab template")
Eq(tab:GetScript("OnShow"), nil, "the template's OnShow was left on the tab")
Check(tab.logo, "the tab wears no logo")
Eq(tab:GetText(), ns.L["Social Diary"], "the tab's words")

--------------------------------------------------------------------------
Section("the OnShow that was dropped, on a nameless tab")

local nameless = _G.CreateFrame("Button", nil, window, "FriendsFrameTabTemplate")
Check(nameless.scripts.OnShow, "the test's template attached no OnShow")
Check(not pcall(nameless.scripts.OnShow, nameless),
    "the template's OnShow no longer needs the tab's name: this test proves nothing")

--------------------------------------------------------------------------
Section("a click opens the journal")

window:Show()
tab.scripts.OnClick()
Check(not window:IsShown(), "the click left the Social window open")