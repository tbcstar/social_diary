-- C_Map on a 3.3.5a client: the world map without retail's map objects.
--
-- The client describes one map at a time: SetMapByID or SetMapToCurrentZone
-- select it, GetCurrentMapAreaID / GetCurrentMapContinent / GetCurrentMapZone
-- read it, GetMapZones and GetMapContinents name it. Every read below saves
-- the player's own map view first and puts it back afterwards, so a call from
-- the HUD never moves the world map the player is browsing (PORT.md section
-- 5).
--
-- What 3.3.5 cannot answer is nil: there are no world coordinates, no
-- map-space conversion and no explored-art rectangles. Callers already have
-- nil branches (Core/Location.lua's Project, Core/Journey.lua's MapYards,
-- UI/Map/Art.lua's overlay data), and Core/Compat/NOTES.md records each one.

local addonName, ns = ...

-- The client's own functions, under names of their own: a local with the
-- retail name below would shadow the global it has to call.
local ClientPlayerMapPosition = GetPlayerMapPosition

do
    local function Number(value, default)
        if type(value) == "number" then return value end
        return default
    end

    -- The player's current world-map view, as (continent, zone); 0 means the
    -- map was never opened on this client.
    local function SaveView()
        return Number(GetCurrentMapContinent and GetCurrentMapContinent(), 0),
            Number(GetCurrentMapZone and GetCurrentMapZone(), 0)
    end

    local function RestoreView(continent, zone)
        -- A continent of 0 is "no map open": SetMapZoom(0, ...) is not a
        -- view, so there is nothing to put back.
        if not SetMapZoom or type(continent) ~= "number" or continent <= 0 then return end
        pcall(SetMapZoom, continent, type(zone) == "number" and zone or 0)
    end

    local function ZoneKey()
        local zone = GetRealZoneText and GetRealZoneText() or ""
        local sub = GetSubZoneText and GetSubZoneText() or ""
        return zone .. "|" .. sub
    end

    local bestKey, bestMapID = nil, nil
    local infoCache = {}
    local continentIDs = {}

    -- The ID of a continent's own map, for a zone's parentMapID.
    local function ContinentMapID(continent)
        local cached = continentIDs[continent]
        if cached ~= nil then return cached or nil end
        local viewContinent, viewZone = SaveView()
        local id
        if pcall(SetMapZoom, continent, 0) then
            id = GetCurrentMapAreaID()
        end
        RestoreView(viewContinent, viewZone)
        if type(id) ~= "number" or id <= 0 then id = nil end
        continentIDs[continent] = id or false
        return id
    end

    local function BestMapForUnit(unit)
        -- 3.3.5 can only describe the player's own map view.
        if unit ~= nil and unit ~= "player" then return nil end
        local key = ZoneKey()
        if bestKey == key and bestMapID ~= nil then
            return bestMapID or nil
        end
        local viewContinent, viewZone = SaveView()
        local id
        if SetMapToCurrentZone and pcall(SetMapToCurrentZone) then
            id = GetCurrentMapAreaID()
        end
        RestoreView(viewContinent, viewZone)
        if type(id) ~= "number" or id <= 0 then id = nil end
        bestKey, bestMapID = key, id or false
        return id
    end

    -- The client's name for the map it is showing: a zone's own name from
    -- GetMapZones, a continent's from GetMapContinents. Both are the
    -- localized names the game itself draws.
    local function MapName(continent, zone)
        if type(zone) == "number" and zone > 0 and GetMapZones then
            local name = select(zone, GetMapZones(continent))
            if type(name) == "string" and name ~= "" then return name end
        end
        if type(continent) == "number" and continent > 0 and GetMapContinents then
            local name = select(continent, GetMapContinents())
            if type(name) == "string" and name ~= "" then return name end
        end
        return nil
    end

    local function MapInfo(mapID)
        if type(mapID) ~= "number" then return nil end
        local cached = infoCache[mapID]
        if cached then return cached end

        local viewContinent, viewZone = SaveView()
        -- SetMapByID does not fail on an id the client cannot describe: it
        -- silently keeps the current view, so the read-back has to be checked.
        -- It takes the WorldMapArea.dbc id, and GetCurrentMapAreaID answers
        -- one past that (the client's FrameXML subtracts one before every
        -- SetMapByID), so the ids read from the client are one past the
        -- ids it is asked for here.
        local areaID, continent, zone, ok
        if SetMapByID then
            ok = pcall(SetMapByID, mapID - 1)
            if ok then
                areaID = GetCurrentMapAreaID()
                continent = GetCurrentMapContinent()
                zone = GetCurrentMapZone()
            end
        end
        RestoreView(viewContinent, viewZone)

        if not ok or type(areaID) ~= "number" or areaID <= 0 then return nil end
        -- The answer has to be the map asked for. An id the client cannot
        -- describe leaves the view where it was, which reads back as some
        -- other map (often the player's own zone): retail's nil, never a
        -- stand-in for whatever the view happened to be.
        if areaID ~= mapID then return nil end

        local mapType = 1
        if type(zone) == "number" and zone > 0 then
            mapType = 3
        elseif type(continent) == "number" and continent > 0 then
            mapType = 2
        end

        -- Parent links do not exist on this client: the zone list is flat, so
        -- a map's parent is unknown rather than guessed from its continent.
        -- Callers that need the continent take it from the map's own name.
        local parentMapID = nil

        local name = MapName(continent, zone)
        -- A map the zone list does not name is still the player's zone, and
        -- the client always knows that name.
        if not name and areaID == BestMapForUnit("player") then
            name = GetRealZoneText()
        end

        local info = { name = name, mapType = mapType, parentMapID = parentMapID, mapID = areaID }
        infoCache[areaID] = info
        -- Only the id the client actually answered for is cached: an alias
        -- would pin this answer onto an id the client may describe differently
        -- later, so an alias is re-resolved instead of memoised.
        return info
    end

    local function IsSecret(value)
        return issecretvalue ~= nil and issecretvalue(value) == true
    end

    local function PlayerPosition(mapID, unit)
        unit = unit or "player"
        if not ClientPlayerMapPosition then return nil end
        local viewContinent, viewZone = SaveView()
        local x, y
        if SetMapToCurrentZone and pcall(SetMapToCurrentZone) then
            local ok, px, py = pcall(ClientPlayerMapPosition, unit)
            if ok then x, y = px, py end
        end
        RestoreView(viewContinent, viewZone)

        if IsSecret(x) or IsSecret(y) then return nil end
        if type(x) ~= "number" or type(y) ~= "number" then return nil end

        -- Asked for another map: the number above is the player's position on
        -- the player's map, which is not the answer.
        if mapID ~= nil then
            local best = BestMapForUnit(unit)
            if best and mapID ~= best then return nil end
        end
        return { GetXY = function() return x, y end }
    end

    -- This client carries its own C_Map already (it answers GetBestMapForUnit),
    -- so every member is filled in only when missing. A wholesale table would
    -- overwrite what the client already answers correctly.
    if not C_Map then C_Map = {} end
    if not C_Map.GetBestMapForUnit then C_Map.GetBestMapForUnit = BestMapForUnit end
    if not C_Map.GetMapInfo then C_Map.GetMapInfo = MapInfo end
    if not C_Map.GetPlayerMapPosition then C_Map.GetPlayerMapPosition = PlayerPosition end
    -- No world coordinates on this client: a nil answer makes every caller
    -- take its documented nil branch.
    if not C_Map.GetWorldPosFromMapPos then C_Map.GetWorldPosFromMapPos = function() return nil end end
    if not C_Map.GetMapPosFromWorldPos then C_Map.GetMapPosFromWorldPos = function() return nil end end
    if not C_Map.GetMapWorldSize then C_Map.GetMapWorldSize = function() return nil end end
    if not C_Map.GetMapArtLayers then C_Map.GetMapArtLayers = function() return nil end end
    if not C_Map.GetMapArtLayerTextures then C_Map.GetMapArtLayerTextures = function() return nil end end

    -- The zone cache is keyed by the zone text, so a zone change already
    -- gives a new key; the event only drops the old entries.
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ZONE_CHANGED")
    watcher:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    watcher:RegisterEvent("ZONE_CHANGED_INDOORS")
    watcher:SetScript("OnEvent", function()
        bestKey, bestMapID = nil, nil
    end)
end

-- Retail's explored-map art: 3.3.5 has no API for it, so there is never an
-- explored piece and the caller falls back on its own overlay data.
if not C_MapExplorationInfo then
    C_MapExplorationInfo = {
        GetExploredMapTextures = function() return {} end,
    }
end

-- Retail's vector constructor. 3.3.5 has no world coordinates to build one
-- from, so the object only carries the numbers it was given: enough for the
-- callers that pass a position straight back into a nil-returning C_Map.
if not CreateVector2D then
    function CreateVector2D(x, y)
        return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
    end
end

-- PORT.md section 5: no world position on this client. The function exists
-- so the addon's "if the client has UnitPosition" check is answered by the
-- nil result rather than by the global's absence.
if not UnitPosition then
    function UnitPosition() return nil end
end
