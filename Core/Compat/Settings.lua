-- Settings: the retail options registry, backed by 3.3.5's own Interface
-- Options frame. The addon registers one small signpost page
-- (UI/Blizzard/Signpost.lua); its real settings live in its own window.
-- Only what that page uses is provided.

local addonName, ns = ...

if not Settings then
    local categories = {}
    local byKey = {}
    local nextId = 0

    local Settings = {}
    _G.Settings = Settings

    function Settings.RegisterCanvasLayoutCategory(frame, name)
        nextId = nextId + 1
        local key = name or ("SocialDiary" .. nextId)
        local category = {
            name = key,
            frame = frame,
            ID = nextId,
            isAddOnCategory = true,
        }
        -- InterfaceOptions_AddCategory reads frame.name, and returns silently
        -- when it is missing. The signpost frame is a plain frame.
        if frame and not frame.name then frame.name = key end
        categories[#categories + 1] = category
        byKey[key] = category
        byKey[nextId] = category
        return category
    end

    function Settings.RegisterAddOnCategory(category)
        if type(category) ~= "table" or not category.frame then return end
        if not InterfaceOptions_AddCategory then return end
        pcall(InterfaceOptions_AddCategory, category.frame)
    end

    local function Resolve(key)
        local category = byKey[key]
        if category then return category end
        for i = 1, #categories do
            if categories[i].name == key then return categories[i] end
        end
        return nil
    end

    function Settings.OpenToCategory(key)
        local category = Resolve(key)
        if not category or not category.frame then return end
        if not InterfaceOptionsFrame_OpenToCategory then return end
        -- 3.3.5's first call only raises the options frame; the second one
        -- actually selects the page.
        pcall(InterfaceOptionsFrame_OpenToCategory, category.frame)
        pcall(InterfaceOptionsFrame_OpenToCategory, category.frame)
    end
end
