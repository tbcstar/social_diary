-- The suite's development tooling: exactly the files the TOC's old
-- "#@do-not-package@" block listed, in its order. The port's TOC ships no
-- dev block (development tooling is not packaged), but /sd testdata and the
-- probes are what a third of the tests drive, so the suite loads them
-- itself after the addon. Dev/TestData.lua comes first (a feature's Dev.lua
-- calls TestData.Register at load time), and the order of the rest is the
-- order the slash list and the test data's route were written against.

local Dev = {}

-- As the TOC listed them (upstream social_diary.toc:464-497).
Dev.FILES = {
    "Dev/Art.lua",
    "Dev/Diagnostics.lua",
    "Dev/LootProbe.lua",
    "Dev/CloseCallProbe.lua",
    "Dev/HandTest.lua",
    "Dev/SightingsDebug.lua",
    "Dev/JourneyDebug.lua",
    "Dev/PaceDebug.lua",
    "Dev/TestData.lua",
    "Dev/TestMatches.lua",
    "Dev/Hints.lua",
    "Dev/Pad.lua",
    "Features/LevelUps/Dev.lua",
    "Features/Trade/Dev.lua",
    "Features/Chat/Dev.lua",
    "Features/Campfire/Dev.lua",
    "Features/Firsts/Dev.lua",
    "Features/Upgrades/Dev.lua",
    "Features/ProfessionCaps/Dev.lua",
    "Features/QuestFinales/Dev.lua",
    "Features/WorldPvP/Dev.lua",
    "Features/Deaths/Dev.lua",
    "Features/CloseCalls/Dev.lua",
    "Features/Witnesses/Dev.lua",
    "Features/Hunts/Dev.lua",
    "Features/Duels/Dev.lua",
    "Features/Classes/Hunter/Dev.lua",
}

function Dev.Load(root, ns)
    for _, file in ipairs(Dev.FILES) do
        local chunk, err = loadfile(root .. "/" .. file)
        if not chunk then
            error(("tests/dev.lua: %s: %s"):format(file, tostring(err)), 2)
        end
        chunk("social_diary", ns)
    end
end

return Dev
