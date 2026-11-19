-- C_QuestLog and C_Spell on a 3.3.5a client.
--
-- 3.3.5 answers these from the quest log, not from a quest cache: a quest
-- the player does not have is unknown here, where retail could still name it
-- through GetTitleForQuestID. Every caller already accepts nil.

local addonName, ns = ...

if not C_QuestLog then
    -- 3.3.5 GetQuestLogTitle returns (title, level, suggestedGroup, isHeader,
    -- isCollapsed, isComplete, isDaily, questID): the header flag is the 4th
    -- value and the quest id is the 8th.
    local function LogEntry(index)
        if not GetQuestLogTitle then return nil end
        local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(index)
        if isHeader then
            return { title = title, isHeader = true }
        end
        return { title = title, questID = questID, isHeader = false, isComplete = isComplete }
    end

    local function NumEntries()
        if not GetNumQuestLogEntries then return 0 end
        return GetNumQuestLogEntries() or 0
    end

    local function LogTitle(questID)
        if type(questID) ~= "number" or not GetNumQuestLogEntries or not GetQuestLogTitle then
            return nil
        end
        for i = 1, NumEntries() do
            local entry = LogEntry(i)
            -- A header row has no quest id and no title to give.
            if entry and not entry.isHeader and entry.questID == questID then return entry.title end
        end
        return nil
    end

    C_QuestLog = {
        -- Retail reads the log by index through these two; the counts and the
        -- row shape are the 3.3.5 quest log's own.
        GetNumQuestLogEntries = function() return NumEntries() end,
        GetInfo = function(index) return LogEntry(index) end,

        IsQuestFlaggedCompleted = function(questID)
            if not IsQuestFlaggedCompleted then return nil end
            return IsQuestFlaggedCompleted(questID)
        end,

        IsOnQuest = function(questID) return LogTitle(questID) ~= nil end,

        GetTitleForQuestID = function(questID) return LogTitle(questID) end,

        GetQuestLink = function(questID)
            if not GetQuestLink then return nil end
            return GetQuestLink(questID)
        end,

        -- 3.3.5 tracks the watched quest by log index, not by quest id.
        IsQuestWatched = function() return nil end,
    }
end

if not C_Spell then
    C_Spell = {
        GetSpellInfo = function(spell) return GetSpellInfo(spell) end,
        GetSpellLink = function(spell)
            if not GetSpellLink then return nil end
            return GetSpellLink(spell)
        end,
        IsSpellKnown = function(spell, isPet) return IsSpellKnown(spell, isPet) end,
        -- Retail's name-only answer; 3.3.5 returns it as GetSpellInfo's first.
        GetSpellName = function(spell) return GetSpellInfo(spell) end,
        GetSpellTexture = function(spell) return GetSpellTexture(spell) end,
        GetSpellDescription = function(spell)
            if not GetSpellDescription then return nil end
            return GetSpellDescription(spell)
        end,
    }
end
