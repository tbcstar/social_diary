-- Extras: the remaining retail names the addon touches. Where 3.3.5 has no
-- equivalent the table is left empty on purpose: every call site already
-- checks for the method before using it, so an empty table turns the feature
-- off instead of erroring.

local addonName, ns = ...

-- The client carries its own C_CVar. The table is created only when absent and
-- each member is added only when missing: assigning to a name the client
-- already provides taints it for the session, and Blizzard code reading it
-- then fails in a secure context (taint.log 21 Nov 2026, the UseAction report;
-- PORT.md rule 22).
if not C_CVar then C_CVar = {} end
if not C_CVar.GetCVar then
    C_CVar.GetCVar = function(name)
        if GetCVar then return GetCVar(name) end
        return nil
    end
end
if not C_CVar.SetCVar then
    C_CVar.SetCVar = function(name, value)
        if SetCVar then return SetCVar(name, value) end
        return nil
    end
end
if not C_CVar.GetCVarBool then
    C_CVar.GetCVarBool = function(name)
        if GetCVarBool then return GetCVarBool(name) end
        return false
    end
end

-- Retail-only tables. Empty means "the feature cannot run here"; the callers
-- guard each method, so a missing feature never raises.
if not C_Bank then C_Bank = {} end
if not C_CreatureInfo then C_CreatureInfo = {} end
if not C_DamageMeter then C_DamageMeter = {} end
if not C_DeathRecap then C_DeathRecap = {} end
if not C_GamePad then C_GamePad = {} end
if not C_InputInterfaceStyle then C_InputInterfaceStyle = {} end
if not C_InstanceEncounter then C_InstanceEncounter = {} end
if not C_LootHistory then C_LootHistory = {} end
-- Probe-only names: Dev/Diagnostics.lua lists them to show what this client
-- does not have, and no caller reaches into them. An empty table keeps the
-- probe honest ("no") instead of erroring on an unknown global.
if not C_LFGInfo then C_LFGInfo = {} end
if not C_ChallengeMode then C_ChallengeMode = {} end
if not C_EncounterTimeline then C_EncounterTimeline = {} end
if not C_RecentAllies then C_RecentAllies = {} end
if not C_EncodingUtil then C_EncodingUtil = {} end
if not scrubsecretvalues then scrubsecretvalues = function(value) return value end end

if not C_NamePlate then C_NamePlate = {} end
if not InputUtil then InputUtil = {} end

-- CreateVector3D exists only to keep a caller's positioning branch honest: the
-- vector it needs is used with CreateVector2D, which 3.3.5 also lacks, so the
-- branch that would project across maps never runs.
if not CreateVector3D then
    function CreateVector3D(x, y, z)
        return {
            x = x or 0, y = y or 0, z = z or 0,
            GetXYZ = function(self) return self.x, self.y, self.z end,
        }
    end
end

-- MenuUtil: the retail menu builder. Callers only use the element methods, and
-- a button's element doubles as a submenu root. Elements are collected here and
-- handed to 3.3.5's EasyMenu when the menu opens.
if not MenuUtil then
    local ElementMeta = {}
    local function Noop() end
    ElementMeta.__index = function(self, key)
        if type(key) == "string" and key:find("^[A-Z]") then return Noop end
        return nil
    end

    local function Element(kind, text, callback, data)
        return setmetatable({
            kind = kind, text = text, callback = callback, data = data,
            children = {},
        }, ElementMeta)
    end

    local function Add(root, child)
        if root and child then
            root.children[#root.children + 1] = child
            return child
        end
        return child
    end

    local Menu

    local function Entry(element)
        local kind = element.kind
        if kind == "title" then
            return { text = element.text, isTitle = true, notCheckable = true }
        end
        if kind == "divider" then
            return { text = "-", isTitle = false, disabled = true, notCheckable = true }
        end
        if kind == "spacer" then
            return { text = " ", isTitle = false, disabled = true, notCheckable = true }
        end
        if kind == "radio" or kind == "checkbox" then
            local checked = false
            if element.callback then
                local ok, value = pcall(element.callback, element.data)
                checked = ok and value == true
            end
            return {
                text = element.text,
                checked = checked,
                notCheckable = false,
                func = function()
                    if element.callback then pcall(element.callback, element.data) end
                end,
            }
        end
        local entry = {
            text = element.text,
            notCheckable = true,
            func = function()
                if element.callback then pcall(element.callback, element.data) end
            end,
        }
        if #element.children > 0 then entry.menuList = Menu(element.children) end
        return entry
    end

    Menu = function(elements)
        local list = {}
        for i = 1, #elements do
            local ok, entry = pcall(Entry, elements[i])
            if ok and entry then list[#list + 1] = entry end
        end
        return list
    end

    local rootMethods = {
        CreateTitle = function(self, text) return Add(self, Element("title", text)) end,
        CreateDivider = function(self) return Add(self, Element("divider")) end,
        CreateSpacer = function(self) return Add(self, Element("spacer")) end,
        CreateButton = function(self, text, callback, data)
            return Add(self, Element("button", text, callback, data))
        end,
        CreateRadio = function(self, text, isSelected, setSelected, data)
            local element = Add(self, Element("radio", text, setSelected, data))
            element.isSelected = isSelected
            return element
        end,
        CreateCheckbox = function(self, text, isSelected, setSelected, data)
            local element = Add(self, Element("checkbox", text, setSelected, data))
            element.isSelected = isSelected
            return element
        end,
    }
    ElementMeta.__index = function(self, key)
        local method = rootMethods[key]
        if method then return method end
        if type(key) == "string" and key:find("^[A-Z]") then return Noop end
        return nil
    end

    -- A radio's checked state needs the isSelected function, which the element
    -- keeps for the renderer; the recorder itself ignores it.
    local function Render(root)
        if not root then return end
        if not (EasyMenu and UIDropDownMenu_Create) then return end
        local menuFrame = UIDropDownMenu_Create("SocialDiaryMenu", UIParent)
        EasyMenu(Menu(root.children), menuFrame, "cursor", 0, 0, "MENU", 2)
    end

    MenuUtil = {
        CreateContextMenu = function(owner, generator, ...)
            if type(generator) ~= "function" then return end
            local root = setmetatable({ kind = "root", children = {} }, ElementMeta)
            local ok = pcall(generator, owner, root, ...)
            if not ok then return end
            pcall(Render, root)
        end,
    }
end

-- TooltipDataProcessor: 3.3.5 fires OnTooltipSetUnit when the tooltip shows a
-- unit, and the addon only reads data.guid. The callback list lives on the
-- shared table and the hook checks the tooltip object, so a second addon load
-- (the test suite's per-file reload) replaces the callbacks instead of adding
-- a second hook that listens to the first load's closures.
-- The client has no TooltipDataProcessor of its own (no FrameXML reference
-- in the 3.3.5 UI tree), so this table and its members are ours; the global
-- is still created only when absent, because writing over a name the client
-- provides taints it for the session (PORT.md rule 22).
if not TooltipDataProcessor then TooltipDataProcessor = {} end
TooltipDataProcessor.__callbacks = {}

function TooltipDataProcessor.AddTooltipPostCall(dataType, fn)
    if type(fn) ~= "function" then return end
    local unitType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
    if unitType and dataType ~= unitType then return end
    local callbacks = TooltipDataProcessor.__callbacks
    callbacks[#callbacks + 1] = fn
    if not GameTooltip or GameTooltip.socialDiaryTooltipProcessor then return end
    GameTooltip.socialDiaryTooltipProcessor = true
    GameTooltip:HookScript("OnTooltipSetUnit", function(self)
        -- GetUnit answers type, token on 3.3.5 (FrameXML/GameTooltip.lua),
        -- so only the second value is the unit. It cannot be written as
        -- "local _, unit = self.GetUnit and self:GetUnit()": an "and"
        -- expression is adjusted to one value, which drops the token.
        if not (self.GetUnit and UnitGUID) then return end
        local _, unit = self:GetUnit()
        if not unit then return end
        local data = { unit = unit, guid = UnitGUID(unit) }
        local list = TooltipDataProcessor.__callbacks
        for i = 1, #list do
            pcall(list[i], self, data)
        end
    end)
end
