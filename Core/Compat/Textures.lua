-- Textures: 3.3.5 has no Texture:SetColorTexture, no texture atlases and no
-- BackdropTemplate. The addon uses SetColorTexture for almost every coloured
-- surface, so the method is added to the shared widget table once; SetAtlas
-- becomes a no-op and every caller that needs art has its own fallback.

local addonName, ns = ...

-- A frame's metatable hands out its methods through __index, which is a shared
-- table in the client. The test mock gives every widget its own methods and no
-- metatable, so this quietly does nothing there.
local function WidgetMethods(widget)
    local ok, mt = pcall(getmetatable, widget)
    if not ok or type(mt) ~= "table" then return nil end
    if type(mt.__index) ~= "table" then return nil end
    return mt.__index
end

pcall(function()
    local probe = UIParent and UIParent:CreateTexture()
    local methods = probe and WidgetMethods(probe)
    if not methods then return end

    if not methods.SetColorTexture then
        methods.SetColorTexture = function(self, r, g, b, a)
            if type(r) == "table" then
                r, g, b, a = r.r or 1, r.g or 1, r.b or 1, r.a
            end
            self:SetTexture(r or 1, g or 1, b or 1, a or 1)
        end
    end

    if not methods.SetAtlas then
        methods.SetAtlas = function() end
    end

    -- A widget has no atlas lookup either; a caller that asks gets "no atlas"
    -- and takes its own coloured-texture branch.
    if not methods.GetAtlasInfo then
        methods.GetAtlasInfo = function() return nil end
    end
end)

-- A bare global of the same name, because some call sites read it as a
-- function rather than as a widget method (audit R1 counts it as a name).
GetAtlasInfo = GetAtlasInfo or function() return nil end

if not C_Texture then
    C_Texture = {
        -- No atlases: callers already branch to a coloured texture or skip.
        GetAtlasInfo = function() return nil end,
    }
end

-- 3.3.5 raises on an unknown template name, and retail wants
-- "BackdropTemplate" on a frame that then calls SetBackdrop (UI/Kit/Chrome.lua).
-- Ask the client once, with a throwaway frame, and let a caller pass the token
-- only where it is understood; 3.3.5 frames always take SetBackdrop.
--
-- The global CreateFrame is deliberately NOT replaced. Reassigning a global
-- from addon code marks it tainted for the rest of the session, and every
-- frame Blizzard's own secure code creates through it afterwards -- an action
-- button made when a vehicle's bar appears, say -- is tainted with it: on
-- 21 Nov 2026 this client reported 「插件 social_diary 污染了安全函数
-- UseAction() 的调用」, UseAction being what a secure action button calls.
-- A probe and a value do the same job without writing anything of the
-- client's.
local RealCreateFrame = CreateFrame
if RealCreateFrame then
    local ok = pcall(RealCreateFrame, "Frame", nil, UIParent, "BackdropTemplate")
    ns.BackdropTemplate = ok and "BackdropTemplate" or nil
end
