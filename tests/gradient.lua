-- Style.Gradient, the one place that knows what the client's SetGradient
-- takes (UI/Style/Draw.lua): numbers, and a fade through SetGradientAlpha,
-- on the 3.3.5 engine that CoA runs; colour objects on a retail client; and
-- a flat wash only where neither can be made. Never a colour object where a
-- number is wanted -- that engine takes it for 0 and paints the whole
-- gradient black, reporting no error at all, which is how the paper strips
-- came out black until 19 Nov.

local T = ...
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()
local Style = ns.Style

local function Near(a, b) return math.abs(a - b) < 1e-6 end

--------------------------------------------------------------------------
Section("the client takes numbers: the six that SetGradient wants")

local tex = UIParent:CreateTexture(nil, "ARTWORK")
Eq(Style.Gradient(tex, "HORIZONTAL", { 0.2, 0.4, 0.6, 1 }, { 0.8, 0.9, 1, 1 }), true,
    "a gradient the client can take is not reported as one")
local g = tex.recorded.calls.SetGradient
Check(g and g[1] == "HORIZONTAL", "the gradient does not run the way asked")
Check(g and type(g[2]) == "number", "a colour object went where the client wants a number")
Check(g and Near(g[2], 0.2) and Near(g[3], 0.4) and Near(g[4], 0.6), "the gradient's first end")
Check(g and Near(g[5], 0.8) and Near(g[6], 0.9) and Near(g[7], 1), "the gradient's second end")
Check(not tex.recorded.calls.SetGradientAlpha, "a plain gradient went through the fade")

--------------------------------------------------------------------------
Section("a fade: the eight that SetGradientAlpha wants")

local fade = UIParent:CreateTexture(nil, "ARTWORK")
Style.Gradient(fade, "VERTICAL", { 0.1, 0.1, 0.1, 0 }, { 0.1, 0.1, 0.1, 0.5 })
local f = fade.recorded.calls.SetGradientAlpha
Check(f and f[1] == "VERTICAL", "the fade does not run the way asked")
Check(f and Near(f[5], 0) and Near(f[9], 0.5), "the fade's alphas")
Check(f and Near(f[2], 0.1) and Near(f[6], 0.1), "the fade's colours")

--------------------------------------------------------------------------
Section("art kept: a tint does not paint the texture white")

local art = UIParent:CreateTexture(nil, "ARTWORK")
art:SetTexture("Interface\\\\ICONS\\\\INV_Misc_Book_09")
Style.Gradient(art, "VERTICAL", { 1, 1, 1, 1 }, { 0.94, 0.94, 0.94, 1 }, true)
Eq(art.recorded.calls.SetColorTexture, nil, "a tint wiped the art to a colour")

--------------------------------------------------------------------------
Section("no gradient to be had: the average, flat")

local flat = { recorded = { calls = {} } }
function flat:SetColorTexture(r, g, b, a) self.recorded.calls.SetColorTexture = { r, g, b, a } end
function flat:SetVertexColor(r, g, b, a) self.recorded.calls.SetVertexColor = { r, g, b, a } end
Eq(Style.Gradient(flat, "HORIZONTAL", { 0.2, 0.4, 0.6, 1 }, { 0.4, 0.6, 0.8, 1 }), false,
    "a texture that cannot take a gradient is not reported as a flat wash")
local c = flat.recorded.calls.SetColorTexture
Check(c and Near(c[1], 0.3) and Near(c[2], 0.5) and Near(c[3], 0.7) and Near(c[4], 1),
    "the flat wash is not the average of the two ends")
