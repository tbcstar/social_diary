-- Widgets: the retail client's widget methods that this one does not have.
-- Probing every method the addon calls on the 16 widget types it builds (the
-- sd_probe addon, 19 Nov 2026: 345 names x 16 types) left 23 names that exist
-- on none of them, and the first one reached in play raised
-- "attempt to call method 'SetClipsChildren' (a nil value)" from
-- UI/Kit/List.lua:362 while the journal was opening.
--
-- A widget's methods come through its metatable's __index, one shared table per
-- widget type (Core/Compat/Textures.lua adds SetColorTexture the same way), so
-- each missing name is filled once here instead of at ~40 call sites. Only
-- members the client lacks are set: one the client already has is never
-- touched.
--
-- What is NOT filled: masks (CreateMaskTexture/AddMaskTexture), vertex offsets
-- (SetVertexOffset) and the EventRegistry callbacks. A fake mask would print
-- wrong art rather than skip it, and every caller of those asks for the method
-- first; see UI/Map/Dungeon. A fake vertex offset is worse: Style.Quad asks
-- whether the client can move a texture's corners and on yes draws that shape,
-- so filling it in made every stroke and torn edge paint its axis-aligned box
-- instead (19 Nov 2026: the journal's pages came out as solid slabs). The
-- addon's own fallbacks are what should run.
--
-- The mock gives each widget its own methods and no metatable, so nothing here
-- installs under tests; tests/widgets.lua covers it with a metatable of its own.

local addonName, ns = ...

-- The method table a widget of this shape hands out, or nil where it has none.
local function MethodsOf(widget)
    if not widget then return nil end
    local ok, mt = pcall(getmetatable, widget)
    if not ok or type(mt) ~= "table" or type(mt.__index) ~= "table" then return nil end
    return mt.__index
end

-- 3.3.5 measures a string whole: the closest thing to the unbounded width.
local function Width(self)
    local fn = self.GetStringWidth
    if not fn then return 0 end
    local ok, width = pcall(fn, self)
    return ok and width or 0
end

local SHIMS = {
    -- Retail's pixel snapping, clipping and keyboard plumbing: this client has
    -- no counterpart, and none of them changes what is drawn here.
    SetSnapToPixelGrid = function() end,
    SetTexelSnappingBias = function() end,
    SetClipsChildren = function() end,
    SetMaxLines = function() end,
    SetPropagateKeyboardInput = function() end,
    SetFixedFrameStrata = function() end,
    SetMouseClickEnabled = function() end,
    EnableGamePadButton = function() end,
    EnableGamePadStick = function() end,

    -- Greying: 3.3.5 desaturates a texture whole, there is no percentage, so
    -- any amount above zero greys and zero restores the colour.
    SetDesaturation = function(self, amount)
        local fn = self.SetDesaturated
        if fn then pcall(fn, self, amount == nil or amount > 0) end
    end,

    -- Questions only the retail client can answer, answered the way the
    -- addon's own fallbacks answer them.
    GetRotation = function() return 0 end,
    GetUnboundedStringWidth = function(self) return Width(self) end,
    IsTruncated = function() return false end,
    IsGamePadButtonEnabled = function() return false end,
    IsGamePadStickEnabled = function() return false end,
    IsMouseClickEnabled = function() return true end,
    GetOpenMenu = function() return nil end,
    GetFontObjectForAlphabet = function() return nil end,
}

-- Fill the members a widget's shape lacks; nil where it hands out no table.
local function Fill(widget, shims)
    local methods = MethodsOf(widget)
    if not methods then return nil end
    for name, shim in pairs(shims or SHIMS) do
        if not methods[name] then methods[name] = shim end
    end
    return methods
end

ns.WidgetCompat = { MethodsOf = MethodsOf, Fill = Fill, SHIMS = SHIMS }

-- Each widget type the addon builds, probed once at load. A type the client
-- cannot make is skipped; the ones it can are left hidden and unsized.
local PROBES = {
    function() return UIParent:CreateTexture() end,
    function() return UIParent:CreateFontString(nil, "OVERLAY") end,
    function() return CreateFrame("Frame") end,
    function() return CreateFrame("Button") end,
    function() return CreateFrame("CheckButton") end,
    function() return CreateFrame("EditBox") end,
    function() return CreateFrame("ScrollFrame") end,
    function() return CreateFrame("Slider") end,
    function() return CreateFrame("StatusBar") end,
    function() return CreateFrame("Cooldown") end,
    function() return CreateFrame("PlayerModel") end,
    function() return CreateFrame("MessageFrame") end,
    function() return CreateFrame("SimpleHTML") end,
}

for _, make in ipairs(PROBES) do
    pcall(function()
        local widget = make()
        if widget then
            Fill(widget)
            if widget.Hide then widget:Hide() end
        end
    end)
end
