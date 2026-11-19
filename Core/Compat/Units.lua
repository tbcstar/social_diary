-- Units: the aura, player and party queries the retail API offers, built
-- from 3.3.5's own unit functions. Every table here mirrors the shape the
-- retail documentation promises, because the callers were written against it.
-- Nothing is defined when the client already has the global.

local addonName, ns = ...

-- 3.3.5's UnitAura does not hand back a spell ID, only the name. The one aura
-- the addon asks about by ID is the campfire countdown (Features/Campfire/
-- Capture.lua's COUNTDOWN), so its localized name is the only entry needed.
local AURA_NAME_IDS = {
    ["Welcoming Campfire"] = 1229739,
}

local function SpellIDOf(name, spellID)
    if spellID then return spellID end
    return AURA_NAME_IDS[name]
end

-- One aura in the retail C_UnitAuras.GetAuraDataByIndex shape. auraInstanceID
-- has to change when the aura is refreshed: the campfire code uses a new
-- instance as its "the buff was recast" signal, so the expiry time is folded
-- into it. On a refresh the expiry moves, so the id moves with it.
local function AuraData(unit, index, filter)
    if not UnitAura then return nil end
    local ok, name, rank, icon, count, dispelType, duration, expirationTime,
        source, isStealable, shouldConsolidate, spellID = pcall(UnitAura, unit, index, filter)
    if not ok or not name then return nil end
    local id = SpellIDOf(name, spellID)
    return {
        name = name,
        icon = icon,
        applications = count,
        dispelName = dispelType,
        duration = duration,
        expirationTime = expirationTime,
        sourceUnit = source,
        isStealable = isStealable,
        spellId = id,
        auraInstanceID = tostring(id or name) .. ":" .. tostring(expirationTime),
    }
end

if not C_UnitAuras then
    C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
            return AuraData(unit, index, filter)
        end,

        -- The first helpful aura on the player carrying this spell ID.
        GetPlayerAuraBySpellID = function(spellID)
            for i = 1, 40 do
                local aura = AuraData("player", i, "HELPFUL")
                if not aura then break end
                if aura.spellId == spellID then return aura end
            end
            return nil
        end,
    }
end

if not C_Secrets then
    -- 3.3.5 has no secret auras: every aura is readable.
    C_Secrets = {
        ShouldAurasBeSecret = function() return false end,
    }
end

if not C_PlayerInfo then
    -- 3.3.5 unit GUIDs are plain strings and a player's starts "Player-".
    C_PlayerInfo = {
        GUIDIsPlayer = function(guid)
            return type(guid) == "string" and guid:sub(1, 7) == "Player-"
        end,
    }
end

-- PlayerLocation has no 3.3.5 counterpart: the caller pcalls this and falls
-- back to the unit token, so an empty answer is the honest one.
C_PlayerInfo.GetGUIDFromPlayerLocation = C_PlayerInfo.GetGUIDFromPlayerLocation
    or function() return nil end

if not C_PartyInfo then
    local function InGroupToken(token)
        if not token then return false end
        if token == "player" then return true end
        if not (token:find("^party%d") or token:find("^raid%d")) then return false end
        return UnitExists and UnitExists(token) and true or false
    end

    C_PartyInfo = {
        IsGUIDInGroup = function(guid)
            local token = UnitTokenFromGUID and UnitTokenFromGUID(guid)
            return InGroupToken(token)
        end,

        -- No delves in 3.3.5; the caller only uses this as a stay-out signal.
        IsDelveInProgress = function() return false end,
    }
end

if not C_FriendList then
    -- 3.3.5's ignore list is a name list with no GUID lookup, so the unit the
    -- GUID names is resolved first; an absent unit is simply not ignored.
    C_FriendList = {
        IsIgnoredByGuid = function(guid)
            local token = UnitTokenFromGUID and UnitTokenFromGUID(guid)
            local name = token and UnitName and UnitName(token)
            if not name then return false end
            if not GetNumIgnores or not GetIgnoreName then return false end
            for i = 1, GetNumIgnores() do
                if GetIgnoreName(i) == name then return true end
            end
            return false
        end,
    }
end

-- Specializations arrived after 3.3.5: the client has no notion of one, and
-- every caller already treats a nil answer as "not known".
if not GetSpecialization then
    function GetSpecialization() return nil end
end

if not GetSpecializationInfo then
    function GetSpecializationInfo() return nil end
end
