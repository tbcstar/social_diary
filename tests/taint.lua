-- The client's globals stay the client's. An addon that reassigns one taints
-- that global for the session, and every secure thing Blizzard's own code
-- makes through it afterwards wears the taint: on 21 Nov 2026 this client
-- reported 「插件 social_diary 污染了安全函数 UseAction() 的调用」, while
-- Core/Compat/Textures.lua still replaced CreateFrame to strip a retail
-- template token. The wrapper is gone and the template is a probed value;
-- this file keeps both that way.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq

-- The client's own, captured before a line of the addon runs.
local NAMES = {
    "CreateFrame", "CreateFont", "SetMapByID", "SetMapToCurrentZone",
    "GetCurrentMapAreaID", "GetLocale", "SetBinding", "GetGuildInfo",
}
local client = {}
for _, name in ipairs(NAMES) do client[name] = rawget(_G, name) end

local ns = T.Load()

Section("no function of the client's is replaced")

for _, name in ipairs(NAMES) do
    if client[name] ~= nil then
        Eq(rawget(_G, name), client[name],
           name .. " is not the client's own function any more: a reassigned global is tainted, and so is everything the client's secure code builds through it")
    end
end

Section("the retail backdrop template is asked about, not assumed")

Eq(ns.BackdropTemplate, "BackdropTemplate",
   "the mock takes any template, so the probe should have handed back the token")
local panel = ns.UI.Chrome.Panel(nil, 100, 100, "probe")
Eq(panel.template, "BackdropTemplate", "the panel was made without the template the probe found")
local bare = ns.UI.Chrome.Panel(nil, 100, 100, nil, { bare = true })
Eq(bare.template, nil, "a bare panel asked for a template it does not draw")
