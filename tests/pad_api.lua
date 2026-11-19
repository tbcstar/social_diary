-- The pad is a retail-only feature: 3.3.5 has no gamepad API at all, so
-- Core/Compat/Extras.lua installs C_GamePad and InputUtil as empty tables
-- and the pad can never turn on in game. The pad's UI code is still worth
-- testing, so the files named pad_* run with this stand-in installed for
-- the duration of the file only; it lives here, apart from the
-- client-shaped mock in wowmock.lua, so the shared mock never pretends the
-- client has an API it does not. VERIFY.md records the gap.
local M = {}

-- What the stand-in replaced, so a file that runs after a pad file sees
-- Core/Compat/'s own empty tables again (the mock's Reset also takes back
-- globals no other file installed, but the pad's are installed late).
local saved

function M.Install(mock)
    if saved then return end
    saved = { InputUtil = rawget(_G, "InputUtil"), C_GamePad = rawget(_G, "C_GamePad") }
    local pad = mock.pad
    _G.InputUtil = { IsGamepadUIEnabled = function() return pad.ui end }
    _G.C_GamePad = {
        IsEnabled = function() return pad.enabled end,
        GetAllDeviceIDs = function() return pad.devices end,
        GetDeviceMappedState = function()
            if #pad.devices == 0 then return nil end
            return { name = "Mock pad", labelStyle = pad.style, buttonCount = #pad.buttons,
                axisCount = #pad.axes, stickCount = #pad.sticks,
                buttons = pad.buttons, axes = pad.axes, sticks = pad.sticks }
        end,
    }
end

function M.Uninstall()
    if not saved then return end
    _G.InputUtil, _G.C_GamePad = saved.InputUtil, saved.C_GamePad
    saved = nil
end

return M