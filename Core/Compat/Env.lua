-- Retail (Interface 16001) environment for a 3.3.5a client.
--
-- The addon is written against retail's global API. This file and its
-- neighbours in Core/Compat/ re-create the retail names the 3.3.5a client
-- lacks, in terms of what 3.3.5 does have, so no feature file has to be
-- rewritten (PORT.md §3).
--
-- Each global is defined only when the client (or the test mock) does not
-- already provide it: nothing the client has is replaced. Shapes follow the
-- retail documentation, because every caller was written against retail;
-- where 3.3.5 cannot supply the shape the function returns nil and the call
-- site's nil branch is what runs. Core/Compat/NOTES.md lists each one.

local addonName, ns = ...

-------------------------------------------------------------------------
-- Strings and tables: FrameXML helpers retail has and 3.3.5 may not
-------------------------------------------------------------------------
-- strsplit and wipe exist in 3.3.5 (PORT.md §1); strtrim and strjoin are
-- filled in below when absent.

if not strtrim then
    function strtrim(text, chars)
        if type(text) ~= "string" then return text end
        chars = chars or " \t\r\n"
        local first, last = 1, #text
        while first <= last and chars:find(text:sub(first, first), 1, true) do
            first = first + 1
        end
        while last >= first and chars:find(text:sub(last, last), 1, true) do
            last = last - 1
        end
        return text:sub(first, last)
    end
end

if not strjoin then
    function strjoin(separator, ...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        return table.concat(parts, separator)
    end
end

if not Mixin then
    -- Retail: copy every key of every later argument onto the first table,
    -- left to right (a later mixin wins), and return it.
    function Mixin(object, ...)
        for i = 1, select("#", ...) do
            local mixin = select(i, ...)
            if type(mixin) == "table" then
                for key, value in pairs(mixin) do
                    object[key] = value
                end
            end
        end
        return object
    end
end

if not CreateFromMixins then
    function CreateFromMixins(...)
        return Mixin({}, ...)
    end
end

-------------------------------------------------------------------------
-- Enum: the handful of retail's constant tables the addon reads
-------------------------------------------------------------------------
-- 3.3.5 has no Enum at all; the test mock has one with a single table. Add
-- the subtables used by the addon, never replacing one that already exists.

local Enum = _G.Enum
if not Enum then
    Enum = {}
    _G.Enum = Enum
end

if not Enum.UIMapType then
    Enum.UIMapType = { World = 1, Continent = 2, Zone = 3, Cosmic = 4, Vignette = 5 }
end

if not Enum.ItemClass then
    Enum.ItemClass = {
        Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4,
        Reagent = 5, Projectile = 6, TradeGoods = 7, Generic = 8,
        Recipe = 9, Money = 10, Quiver = 11, Quest = 12, Key = 13,
        Permanent = 14, Miscellaneous = 15, Glyph = 16,
    }
end

if not Enum.TooltipDataType then
    Enum.TooltipDataType = {}
end
-- The mock's value, kept: on 3.3.5 nothing reads it (TooltipDataProcessor is
-- retail-only and absent), so only the name has to exist.
if not Enum.TooltipDataType.Unit then
    Enum.TooltipDataType.Unit = 2
end

-------------------------------------------------------------------------
-- Unit tokens and group sizes
-------------------------------------------------------------------------

-- UnitName already returns name, realm on 3.3.5, which is exactly what
-- UnitFullName answers; the name itself exists in retail only.
UnitFullName = UnitFullName or function(unit)
    local name, realm = UnitName(unit)
    return name, realm
end

if not UnitTokenFromGUID then
    -- Scan the units this client can ask for, in the order a caller is most
    -- likely to want. nil when no unit has that GUID.
    function UnitTokenFromGUID(guid)
        if type(guid) ~= "string" or guid == "" then return nil end
        local fixed = { "player", "target", "focus", "mouseover", "pet", "vehicle" }
        for i = 1, #fixed do
            local unit = fixed[i]
            if UnitGUID(unit) == guid then return unit end
        end
        local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
        if raid > 0 then
            for i = 1, raid do
                local unit = "raid" .. i
                if UnitGUID(unit) == guid then return unit end
            end
        elseif IsInGroup and IsInGroup() then
            for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
                local unit = "party" .. i
                if UnitGUID(unit) == guid then return unit end
            end
        end
        return nil
    end
end

-- Retail counts the player in the group (10 for a full raid). Written as a
-- fill-in rather than a definition because this client may already carry the
-- function; if it does, its own copy stays.
GetNumGroupMembers = GetNumGroupMembers or function()
    local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
    if raid > 0 then return raid end
    local party = GetNumPartyMembers and GetNumPartyMembers() or 0
    if party > 0 then return party + 1 end
    return 0
end

-------------------------------------------------------------------------
-- Item instant info: id, type, subtype, equip location, icon, class ids
-------------------------------------------------------------------------
-- 3.3.5's GetItemInfo needs the item cache and never returns class IDs; the
-- addon compares classID/subclassID against the client's own numbers
-- (Enum.ItemClass.Weapon and its subclasses), so those are mapped from the
-- class and subclass names the item cache does return.

local function ItemIDFrom(item)
        if type(item) == "number" then return item end
        if type(item) ~= "string" then return nil end
        local id = item:match("item:(%d+)")
        if id then return tonumber(id) end
        return tonumber(item)
    end

    local CLASS_IDS = {
        ["Consumable"] = 0, ["Container"] = 1, ["Weapon"] = 2, ["Gem"] = 3,
        ["Armor"] = 4, ["Reagent"] = 5, ["Projectile"] = 6, ["Trade Goods"] = 7,
        ["Item Enhancement"] = 8, ["Recipe"] = 9, ["Money"] = 10, ["Quiver"] = 11,
        ["Quest"] = 12, ["Key"] = 13, ["Permanent"] = 14,
        ["Miscellaneous"] = 15, ["Glyph"] = 16,
    }

    local SUBCLASS_IDS = {
        [2] = { -- Weapon
            ["One-Handed Axes"] = 0, ["Two-Handed Axes"] = 1, ["Bows"] = 2,
            ["Guns"] = 3, ["One-Handed Maces"] = 4, ["Two-Handed Maces"] = 5,
            ["Polearms"] = 6, ["One-Handed Swords"] = 7, ["Two-Handed Swords"] = 8,
            ["Staves"] = 9, ["Fist Weapons"] = 13, ["Daggers"] = 15,
            ["Thrown"] = 16, ["Crossbows"] = 18, ["Wands"] = 19,
            ["Fishing Poles"] = 20,
        },
        [1] = { -- Container
            ["Bag"] = 0, ["Bags"] = 0, ["Soul Bag"] = 1, ["Soul Bags"] = 1,
            ["Herb Bag"] = 2, ["Herb Bags"] = 2, ["Enchanting Bag"] = 3,
            ["Enchanting Bags"] = 3, ["Engineering Bag"] = 4,
            ["Engineering Bags"] = 4, ["Gem Bag"] = 5, ["Gem Bags"] = 5,
            ["Mining Bag"] = 6, ["Mining Bags"] = 6,
            ["Leatherworking Bag"] = 7, ["Leatherworking Bags"] = 7,
            ["Inscription Bag"] = 8, ["Inscription Bags"] = 8,
            ["Fishing Bag"] = 9, ["Fishing Bags"] = 9,
            ["Cooking Bag"] = 10, ["Cooking Bags"] = 10,
        },
    }

-- Fill-in, never a redefinition: a client that already has the function keeps it.
GetItemInfoInstant = GetItemInfoInstant or function(item)
    local id = ItemIDFrom(item)
    if not id then return nil end
    local name, link, quality, level, reqLevel, class, subclass, stack, equipLoc, icon = GetItemInfo(id)
    if not name then
        -- The client's cache has not seen it yet: the id is still known.
        return id
    end
    local classID = CLASS_IDS[class]
    local subclassID = classID and SUBCLASS_IDS[classID] and SUBCLASS_IDS[classID][subclass] or nil
    return id, class, subclass, equipLoc, icon, classID, subclassID
end

-------------------------------------------------------------------------
-- C_Timer: one hidden OnUpdate frame drives every timer
-------------------------------------------------------------------------

do
    local driver
    local jobs = {}

    local function Compact()
        local kept = 0
        for i = 1, #jobs do
            local job = jobs[i]
            if not job.done then
                kept = kept + 1
                jobs[kept] = job
            end
        end
        for i = #jobs, kept + 1, -1 do
            jobs[i] = nil
        end
        if kept == 0 and driver and driver:IsShown() then
            driver:Hide()
        end
    end

    local function Report(err)
        local handler = geterrorhandler and geterrorhandler()
        if handler then
            handler(err)
        else
            print(err)
        end
    end

    local function Fire(job)
        local ok, err = pcall(job.fn)
        if not ok then Report(err) end
    end

    local function OnUpdate(_, elapsed)
        if type(elapsed) ~= "number" or elapsed < 0 then elapsed = 0 end
        local due
        for i = 1, #jobs do
            local job = jobs[i]
            if not job.done then
                job.waited = job.waited + elapsed
                if job.waited >= job.delay then
                    job.waited = job.waited - job.delay
                    if job.iterations then
                        job.iterations = job.iterations - 1
                        if job.iterations <= 0 then job.done = true end
                    end
                    due = due or {}
                    due[#due + 1] = job
                end
            end
        end
        if due then
            for i = 1, #due do Fire(due[i]) end
        end
        Compact()
    end

    local function Add(fn, delay, iterations, repeating)
        if type(fn) ~= "function" then return nil end
        if type(delay) ~= "number" or delay < 0 then delay = 0 end
        if not driver then
            driver = CreateFrame("Frame")
            driver:Hide()
            driver:SetScript("OnUpdate", OnUpdate)
        end
        local job = { fn = fn, delay = delay, waited = 0, done = false }
        if repeating then
            if type(iterations) == "number" and iterations >= 1 then
                job.iterations = iterations
            end
        else
            job.iterations = 1
        end
        job.handle = {}
        function job.handle:Cancel()
            job.done = true
            Compact()
        end
        jobs[#jobs + 1] = job
        driver:Show()
        return job.handle
    end

    -- This client carries its own C_Timer, so each call is filled in only when
    -- missing rather than replacing the table (which would drop the client's).
    C_Timer = C_Timer or {}
    -- Retail: one callback after the delay; the handle's :Cancel() works.
    C_Timer.After = C_Timer.After or function(delay, fn)
        return Add(fn, delay, 1, false)
    end
    -- Retail: callback "iterations" times (one by default), each a "delay"
    -- apart on the same clock.
    C_Timer.NewTimer = C_Timer.NewTimer or function(delay, fn, iterations)
        return Add(fn, delay, iterations, true)
    end
    -- Retail: repeats until :Cancel() (or "iterations" times).
    C_Timer.NewTicker = C_Timer.NewTicker or function(delay, fn, iterations)
        return Add(fn, delay, iterations, true)
    end
end

-------------------------------------------------------------------------
-- AddOn metadata and addon chat
-------------------------------------------------------------------------

-- 3.3.5 hands out plain values everywhere: nothing a handler receives is
-- secret, so the retail secret check is a constant false. It only exists
-- because retail-shaped code asks for it (Core/Addon.lua's ns.IsSecret).
if not issecretvalue then
    function issecretvalue() return false end
end

if not C_AddOns then
    C_AddOns = {
        GetAddOnMetadata = function(name, field) return GetAddOnMetadata(name, field) end,
        IsAddOnLoaded = function(name) return IsAddOnLoaded(name) end,
        LoadAddOn = function(name) return LoadAddOn(name) end,
        GetAddOnInfo = function(name) return GetAddOnInfo(name) end,
    }
end

if not C_ChatInfo then
    C_ChatInfo = {
        -- The 3.3.5 call is SendAddonMessage(prefix, text, chatType, target);
        -- the channel names are the retail ones already ("PARTY", "RAID"...).
        SendAddonMessage = function(prefix, text, chatType, target)
            return SendAddonMessage(prefix, text, chatType, target)
        end,
        -- Prefix registration arrived with the modern client; 3.3.5 accepts
        -- any prefix, so these only have to exist.
        RegisterAddonMessagePrefix = function() return true end,
        IsAddonMessagePrefixRegistered = function() return true end,
    }
end
