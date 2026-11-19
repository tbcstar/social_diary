-- The widget methods this client lacks (Core/Compat/Widgets.lua): filled once
-- on the shared method table of each widget type, only where missing.
--
-- In game on 19 Nov 2026 the journal raised "attempt to call method
-- 'SetClipsChildren' (a nil value)" from UI/Kit/List.lua:362: retail widget
-- methods are called all over the addon and 23 of them do not exist here.
-- The mock has no metatables, so this test hands the loader a widget of the
-- client's shape -- methods through a metatable's __index -- and checks what
-- gets filled, what falls back, and what is left alone.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq

local ns = T.Load()
local compat = ns.WidgetCompat
Check(compat, "the widget compat was not exposed")

Section("a widget that hands out its methods through a metatable")

local methods = {
    GetStringWidth = function() return 42 end,
    SetDesaturated = function(self, on) self.grey = on end,
    -- A member this client does have: it must survive untouched.
    SetMaxLines = function(self, lines) self.lines = lines end,
}
local widget = setmetatable({}, { __index = methods })

Eq(compat.MethodsOf(widget), methods, "the method table was not found")
compat.Fill(widget)

Eq(widget:GetUnboundedStringWidth(), 42, "the unbounded width did not fall back to GetStringWidth")
Eq(widget:GetRotation(), 0, "a rotation of something that cannot turn")
Eq(widget:IsTruncated(), false, "the text reported as cut")
Eq(widget:IsMouseClickEnabled(), true, "the mouse reported as gone")
Eq(widget:IsGamePadButtonEnabled(), false, "a pad button on a client without a pad")
Eq(widget:GetOpenMenu(), nil, "a menu that does not exist")
Eq(widget:GetFontObjectForAlphabet("roman"), nil, "a font object for an alphabet")

Check(pcall(widget.SetClipsChildren, widget, true), "SetClipsChildren raised")
Check(pcall(widget.SetSnapToPixelGrid, widget, false), "SetSnapToPixelGrid raised")
Check(pcall(widget.SetTexelSnappingBias, widget, 0), "SetTexelSnappingBias raised")
Check(pcall(widget.SetPropagateKeyboardInput, widget, false), "SetPropagateKeyboardInput raised")

widget:SetDesaturation(1)
Eq(widget.grey, true, "a desaturated texture stayed in colour")
widget:SetDesaturation(0)
Eq(widget.grey, false, "a restored texture stayed grey")

widget:SetMaxLines(3)
Eq(widget.lines, 3, "a method the client has was replaced")

Eq(compat.Fill(widget), methods, "a second fill did not find the method table again")

Section("a widget of the mock's shape, and one with nothing")

Eq(compat.Fill({}), nil, "a widget with no metatable got methods anyway")
Eq(compat.Fill(nil), nil, "no widget at all was filled")
Eq(compat.MethodsOf(nil), nil, "no widget at all had a method table")

Section("every name in the table is a method")

local count = 0
for name, shim in pairs(compat.SHIMS) do
    count = count + 1
    Check(type(name) == "string" and type(shim) == "function", "a shim is not a function: " .. tostring(name))
end
Check(count >= 15, "too few shims to cover the methods the probe found missing: " .. count)
