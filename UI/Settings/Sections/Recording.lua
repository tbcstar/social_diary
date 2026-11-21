-- Settings: Recording, the first section (UI/Settings/Page.lua lists them;
-- its controls are UI/Settings/Kit.lua's): your own route, chat,
-- sightings and auto-add.

local addonName, ns = ...

local L, Fmt = ns.L, ns.Fmt

local Style = ns.Style
local SettingsUI = ns.UI.Settings
local Kit = SettingsUI.Kit
local Switch, Number, DependsOn, Saved = Kit.Switch, Kit.Number, Kit.DependsOn, Kit.Saved
local INDENT = Kit.INDENT

local MAX_CHAT_LINES = 5000  -- above it, "No maximum" says it better

local function BuildRecording(pane, c)
    local page = SettingsUI.page

    -- JRN-17: the timer starts and stops at once.
    c:Heading(L["Your Diary"])
    -- CoA: this client has no world-space position (UnitPosition and
    -- C_Map.GetWorldPosFromMapPos are retail; Core/Compat leaves both nil),
    -- so the roads and the places the character lingers cannot be measured.
    -- The switch still turns the timer on: levels, dungeons and fights are
    -- placed by zone-map fraction and are kept. /sd journey stats reports
    -- "no world position (UnitPosition)" for every tick that took none.
    local measurable = ns.WorldWhere() ~= nil
    page.keepRoute = Switch(c, L["Keep my own route"], "keepRoute", nil,
        function(on) ns.JourneyCapture.SetEnabled(on) end,
        measurable and L["Data needed for the 'Your Diary' Page: Where you go and what you do."]
            or L["This game client cannot measure distances: where you level, your dungeons and your fights are still kept, but the roads and the stops between them cannot be recorded."])

    c:Heading(L["Chat"])
    -- INT-4 asks for the hint to be said in the settings.
    page.storeChat = Switch(c, L["Keep whisper, /say and party text"], "storeChat", nil, nil,
        L["some text in dungeons cannot be accessed, fyi."])

    -- A lower limit applies now, to everyone's chat.
    page.chatLines = Number(c, L["Maximum chat lines kept per person"], L["lines"], "chatLines",
        1, MAX_CHAT_LINES, function() ns.Interactions.TrimChat() end)
    DependsOn(page.chatLines, function() return Saved().storeChat and not Saved().chatUnlimited end)
    page.chatUnlimited = Switch(c, L["Unlimited"], "chatUnlimited", INDENT,
        function(on) if not on then ns.Interactions.TrimChat() end end)
    DependsOn(page.chatUnlimited, "storeChat")
    c:Hint(L["Lines can still be lost if they exceed file size limits."])

    -- SIG-1 and SIG-5, through the same calls as /sd sightings on|off (Dev/)
    -- and /sd sightings city, so they take effect at once.
    c:Heading(L["Sightings"])
    local Capture = ns.SightingCapture
    page.detectSightings = Switch(c, L["Notice who passes you in the open world"], "detectSightings", nil,
        function(on) Capture.SetEnabled(on) end,
        L["Only works if nameplates are on. Doesn't work in dungeons, raids or battlegrounds."])

    -- The cities on SIG-5's list, two to a line. Saved, a city on means it
    -- pauses there; ticked here means it notices people there, so that a
    -- tick never stands for something that is not being recorded. The list
    -- is the one saved when the page was built; a city added by command
    -- shows after a reload.
    c:Hint(L["Enable sightings in cities - performance warning:"], INDENT)
    local cities = Capture.Cities()
    -- `shown` is what the reader sees; the row keeps its own key untouched
    -- (display-time translation only: the CoA name table is Chinese-only in
    -- this build, and a saved city key must never be turned over).
    for _, city in ipairs(cities) do
        city.shown = type(city.key) == "number"
            and (ns.MapNameShown(city.key) or Fmt(L["map %s"], city.key))
            or ns.ZoneShown(city.key)
    end
    table.sort(cities, function(a, b) return a.shown < b.shown end)

    local half = (c.width - INDENT) / 2
    local left
    page.cities = {}
    for i, city in ipairs(cities) do
        local box = Style.Checkbox(c.parent, half - 8, city.shown,
            function() return Saved().cities[city.key] ~= true end,
            function(on) Capture.SetCity(city.key, not on) end)
        if i % 2 == 1 then
            left = c:Place(box, box.height, INDENT, 4)
        else
            box:SetPoint("TOPLEFT", left, "TOPLEFT", half, 0)
        end
        DependsOn(box, "detectSightings")
        page.controls[#page.controls + 1] = box
        page.cities[city.key] = box
    end

    -- The one exception to DIA-1 (Core/AutoAdd.lua). Not tied to sightings:
    -- the group rule works without them, so the hint says which part needs it.
    -- Switched on, the people already waiting are offered once (UI/Windows/AutoAdd.lua).
    c:Heading(L["People"])
    page.autoAdd = Switch(c, L["Auto-Add Players"], "autoAdd", nil, function(on) ns.UI.AutoAdd.Offer(on) end,
        L["Off unless you switch it on. Adds someone after 5 minutes grouped with you without a break (not in battlegrounds), or once they’ve been seen near you 3 separate times. Anyone you remove from the diary stays out."])
    c:Hint(L["Sightings count only while “Notice who passes you in the open world” is on."])
end

SettingsUI.RegisterSection("recording", { order = 10, label = L["Recording"],
    build = BuildRecording })
