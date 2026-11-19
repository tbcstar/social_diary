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

-- 3.3.5 raises on an unknown template name, and the addon asks for
-- "BackdropTemplate" (UI/Kit/Chrome.lua). The token is stripped and the rest
-- of the template list is passed through; 3.3.5 frames already support
-- SetBackdrop, which is what the addon calls.
local RealCreateFrame = CreateFrame
if RealCreateFrame then
    local function WithoutBackdropTemplate(template)
        if type(template) ~= "string" then return template end
        if not template:find("BackdropTemplate", 1, true) then return template end
        local names = {}
        for piece in template:gmatch("[^,]+") do
            local token = piece:match("^%s*(.-)%s*$")
            if token ~= "" and token ~= "BackdropTemplate" then
                names[#names + 1] = token
            end
        end
        if #names == 0 then return nil end
        return table.concat(names, ",")
    end

    _G.CreateFrame = function(frameType, name, parent, template, id)
        return RealCreateFrame(frameType, name, parent, WithoutBackdropTemplate(template), id)
    end
end
