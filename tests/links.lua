-- Your Diary on a client that has no hyperlink scripts (3.3.5a): a frame
-- takes no OnHyperlink* script at all and setting one raises ("<unnamed>
-- doesn't have a 'OnHyperlinkClick' script", in the client 19 Nov 2026), so
-- the diary asks before it sets one -- and, where the answer is no, sets the
-- names in the accent colour without the link markup, which that client
-- would read out as raw text.

local T = ...
local mock, F = T.mock, T.F
local Section, Check, Eq = T.Section, T.Check, T.Eq
local DAY = T.DAY

-- The client's frames, before the addon is loaded: any hyperlink script on
-- one raises, as it does there.
local create = _G.CreateFrame
_G.CreateFrame = function(...)
    local frame = create(...)
    local setScript = frame.SetScript
    frame.SetScript = function(self, key, fn)
        if key == "OnHyperlinkClick" or key == "OnHyperlinkEnter" or key == "OnHyperlinkLeave" then
            error("this client has no " .. key .. " script", 2)
        end
        return setScript(self, key, fn)
    end
    return frame
end

local ns = T.Boot()
local SELF = F.SELF
mock.now = 1791000000
SELF.level = 12
mock.SetUnit("player", SELF)

local ACCENT = "|cff" .. ns.Style.HEX.accent
local function Any(list, pattern)
    for _, text in ipairs(list) do
        if text:find(pattern, 1, true) then return true end
    end
    return false
end

-- A road with a level and a person crossed on it, so the prose says a name
-- (JRN-22's link, as journey_ui builds it).
local A = F.STRANGER.guid
ns.Characters.Observe(A, { first = "Bram", surname = "Redfen", level = 11, faction = "Horde" })
ns.Diary.Add(A, { source = "test" })
local t0 = mock.now - 3 * DAY
ns.db.journey[SELF.guid] = nil
local j = ns.Journey.Begin(SELF.guid, t0, 10, 1412)
j.segments[#j.segments + 1] = { kind = "stop", from = t0, to = t0 + 1800, mapID = 1412, x = 0.40, y = 0.60,
    r = 50, seconds = 1800, act = { combat = 900 }, subZone = "Red Rocks", levelFrom = 10, levelTo = 10 }
j.segments[#j.segments + 1] = { kind = "stop", from = t0 + 1800, to = t0 + 3600, mapID = 1412, x = 0.60,
    y = 0.45, r = 30, seconds = 1800, act = { resting = 1500 }, subZone = "Bloodhoof Village",
    levelFrom = 10, levelTo = 12 }
j.levels[11] = { at = t0 + 2000, mapID = 1412, x = 0.50, y = 0.50 }
j.levels[12] = { at = t0 + 3000 }
ns.Sessions.New({ me = SELF.guid, source = "group", startedAt = t0 + 300, endedAt = t0 + 1500,
    participants = { [A] = { since = t0 + 300, last = t0 + 1500, seconds = 900, levelStart = 10 } } })
ns.Journey.Touch()

Section("the book opens, and its rows take no link scripts")

-- Building the whole book (the introduction's tour, the left page's rows)
-- raises nothing on this client.
ns.UI.ShowJournal()
local page = ns.UI.JourneyPage()
ns.UI.SetJournalView("people")
ns.UI.SetJournalView("journey")
Eq(page.state, "entries", "the road is not shown as entries")
Check(page.items, "the page's rows were never built")
local function Scripts()
    local count = 0
    for _, frame in ipairs(mock.frames) do
        local scripts = frame.scripts
        if scripts then
            if scripts.OnHyperlinkClick then count = count + 1 end
            if scripts.OnHyperlinkEnter then count = count + 1 end
            if scripts.OnHyperlinkLeave then count = count + 1 end
        end
    end
    return count
end
Eq(Scripts(), 0, "a row takes hyperlink scripts where the client has none")

Section("the names are kept, set plain")

local texts, linked = {}, 0
local count = #page.recap.entries
Check(count > 0, "the road has no entries")
for i = 1, count do
    ns.UI.YourDiary.OpenLevel(i)
    for _, item in ipairs(page.items) do
        if item.text then texts[#texts + 1] = item.text end
        if item.linked then
            linked = linked + 1
            texts[#texts + 1] = item.linked
            Eq(item.linked:find(ACCENT, 1, true), 1, "a hindsight name does not open in the accent colour")
        end
    end
end
local accent = 0
for _, text in ipairs(texts) do
    if text:find(ACCENT, 1, true) then accent = accent + 1 end
end
Check(not Any(texts, "|H"), "a name still carries link markup, which this client reads out as text")
Check(not Any(texts, "|h"), "a name still ends in link markup")
Check(accent > 0, "no name is set in the accent colour: the prose lost its names")

-- The row shows what was built for it, and takes no clicks.
ns.UI.YourDiary.OpenLevel(1)
page.entries:SetOffset(0)
local row
for _, shown in ipairs(page.entries.rows) do
    if shown:IsShown() and shown.item and shown.item.text and shown.item.text:find(ACCENT, 1, true) then
        row = shown
    end
end
Check(row, "the prose row is not on the page")
Eq(row.text:GetText(), row.item.text, "the row shows other words than its item's")
Check(not row.scripts.OnHyperlinkClick, "the prose row takes link clicks")
Eq(Scripts(), 0, "a row took a hyperlink script as the page was read")
