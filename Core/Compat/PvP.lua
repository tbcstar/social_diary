-- PvP: the retail battleground queries over 3.3.5's scoreboard API. A match
-- still formats a scoreboard here; the retail match-state events only fire on
-- retail, so the story that hangs off them stands down.
-- Only defined when the client has no C_PvP.

local addonName, ns = ...

if not C_PvP then
    local function ScoreRow(index)
        if not GetBattlefieldScore then return nil end
        local ok, name, killingBlows, honorableKills, deaths, honorGained,
            faction, rank, race, class, classToken, damageDone, healingDone =
            pcall(GetBattlefieldScore, index)
        if not ok or not name then return nil end
        return {
            name = name,
            killingBlows = killingBlows,
            honorableKills = honorableKills,
            deaths = deaths,
            honorGained = honorGained,
            faction = faction,
            rank = rank,
            -- 3.3.5 hands back localized names here; keep both spellings so a
            -- caller can read either without guessing.
            race = race,
            raceName = race,
            class = class,
            classToken = classToken,
            damageDone = damageDone,
            healingDone = healingDone,
        }
    end

    C_PvP = {
        GetNumBattlefieldScores = function()
            if GetNumBattlefieldScores then return GetNumBattlefieldScores() end
            return 0
        end,

        GetScoreInfo = function(index)
            return ScoreRow(index)
        end,

        -- No match state on 3.3.5: the caller compares against nil and stops.
        GetActiveMatchState = function() return nil end,

        GetActiveMatchWinner = function()
            if GetBattlefieldWinner then return GetBattlefieldWinner() end
            return nil
        end,

        GetActiveMatchDuration = function()
            if GetBattlefieldInstanceRunTime then
                return GetBattlefieldInstanceRunTime() / 1000
            end
            return nil
        end,
    }
end
