-- A WoW API mock, just big enough to load the addon and exercise it.
--
-- We cannot run the client, so this is the only thing standing between a
-- refactor and a live Lua error. It is deliberately dumb: every API returns
-- what Session 1 actually observed, so a test that passes here is a test
-- against a real observation rather than against an assumption.
--
-- Returns a control table; loading it installs the globals.

local M = {}

M.now = 1789680679          -- the T-C6 timestamp
M.realm = "Classic Beta PvE"
M.registered = {}
M.units, M.byGUID = {}, {}

--------------------------------------------------------------------------
-- Fake secret values
--------------------------------------------------------------------------
--
-- A real secret errors on ==, arithmetic, #, indexing and use as a table key.
-- Lua 5.1 only fires __eq when both operands share a metatable, so `secret ==
-- nil` cannot be made to error here; indexing, length and concat can, and
-- those catch the common mistakes. Treat a green run as necessary, not
-- sufficient: the == rule still has to hold by inspection.

local SECRET = {}

local function Forbidden(op)
    return function()
        error("secret value: " .. op .. " is not allowed", 2)
    end
end

local secretMeta = {
    __index = Forbidden("indexing"),
    __len = Forbidden("length"),
    __concat = Forbidden("concat"),
    __add = Forbidden("arithmetic"),
    __tostring = function() return "<SECRET value>" end,
}

-- 3.3.5 has no secret values: everything a handler is handed is readable. The
-- retail mock wrapped such a value in a SECRET table so issecretvalue() said
-- yes; there is nothing to wrap here, so M.secret hands its argument straight
-- back and a test that used it reads the value like any other. issecretvalue
-- and scrubsecretvalues are the Compat layer's to define (Env.lua); the mock
-- must not, or a retail-shaped guard in the addon would look satisfied.
function M.secret(value)
    return value
end

--------------------------------------------------------------------------
-- Units
--------------------------------------------------------------------------

-- def: { guid, name = {a, b}, fullName = {a, b}, class = {loc, token, id},
--        race = {loc, token, id}, sex, level, faction = {a, b},
--        isPlayer = true, info = { ... } as GetPlayerInfoByGUID returns }
function M.SetUnit(token, def)
    M.units[token] = def
    if def and def.guid then
        M.byGUID[def.guid] = def
    end
end

function M.ClearUnits()
    M.units, M.byGUID = {}, {}
end

-- The creature cache, as far as model frames read it: NPC id -> display.
M.creatureDisplays = {}

local function Unit(token)
    return M.units[token]
end

-- A secret is itself a table here, so it has to be checked before the
-- multi-return unpack tries to index it. 3.3.5 has no secret values, so the
-- global may simply be absent until Core/Compat defines it: read it through
-- rawget, and never define it here (a retail-shaped guard would otherwise
-- look satisfied by its own mock).
local function IsSecret(value)
    local is = rawget(_G, "issecretvalue")
    return is ~= nil and is(value) == true
end

local function Unpack(def, key)
    local value = def and def[key]
    if IsSecret(value) or type(value) ~= "table" then return value end
    return value[1], value[2], value[3]
end

_G.UnitExists = function(token) return Unit(token) ~= nil end
_G.UnitIsPlayer = function(token) local u = Unit(token); return u ~= nil and u.isPlayer ~= false end
_G.UnitIsVisible = function(token) local u = Unit(token); return u ~= nil and u.visible ~= false end
_G.UnitGUID = function(token) return Unpack(Unit(token), "guid") end
_G.UnitName = function(token) return Unpack(Unit(token), "name") end
_G.UnitFullName = function(token) return Unpack(Unit(token), "fullName") end
_G.UnitClass = function(token) return Unpack(Unit(token), "class") end
_G.UnitRace = function(token) return Unpack(Unit(token), "race") end
_G.UnitSex = function(token) return Unpack(Unit(token), "sex") end
_G.UnitLevel = function(token) return Unpack(Unit(token), "level") end
_G.UnitFactionGroup = function(token) return Unpack(Unit(token), "faction") end
_G.UnitClassification = function(token) return Unpack(Unit(token), "classification") or "normal" end
_G.UnitIsInMyGuild = function(token) local u = Unit(token); return u ~= nil and u.inGuild == true end
_G.UnitCanAttack = function(_, token) local u = Unit(token); return u ~= nil and u.hostile == true end

-- Returns localizedClass, englishClass, localizedRace, englishRace, sex,
-- name, realm.
--
-- The name is the first name only, for the user's own character as well as
-- for strangers -- Session 2 saw "Ulverston" for a character UnitName calls
-- "Ulverston Nye". The realm carries a trailing index for other players
-- ("ClassicBetaPvE2").
_G.GetPlayerInfoByGUID = function(guid)
    local def = M.byGUID[guid]
    if not def then return nil end
    if def.info then return unpack(def.info) end

    local locClass, class = Unpack(def, "class")
    local locRace, race = Unpack(def, "race")

    local first = Unpack(def, "name")
    if type(first) == "string" then first = first:match("^%S+") end

    local realm = (M.realm:gsub("%s+", ""))
    if guid ~= (M.units.player and M.units.player.guid) then realm = realm .. "2" end

    return locClass, class, locRace, race, def.sex, first, realm
end

--------------------------------------------------------------------------
-- The rest
--------------------------------------------------------------------------

_G.UNKNOWNOBJECT = "Unknown"
_G.UNKNOWN = "Unknown"

_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print(msg) end }

--------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------
--
-- Layout is not modelled -- there is no way to check it without the client --
-- but construction and scripts are, and that is where addons actually break.
-- A widget method the addon calls that is not listed here raises on purpose:
-- the alternative is a silent no-op that hides a typo until you log in.

M.frames = {}

local NOOPS = {
    "SetSize", "SetWidth", "SetHeight", "SetPoint", "SetAllPoints", "ClearAllPoints",
    "SetFrameStrata", "SetFrameLevel", "SetToplevel", "Raise", "EnableMouse",
    "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing",
    "SetClampedToScreen", "SetClampRectInsets", "SetUserPlaced",
    "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor",
    "SetColorTexture", "SetTexture", "SetTexCoord", "SetVertexColor",
    "SetJustifyH", "SetJustifyV", "SetFontObject", "SetFont", "SetTextColor",
    "SetMultiLine", "SetAutoFocus", "SetMaxLetters", "SetCursorPosition",
    "HighlightText", "Insert",
    "LockHighlight", "UnlockHighlight", "Disable", "Enable", "SetAlpha",
    "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture",
    "SetWordWrap", "SetMaxLines", "EnableMouseWheel",
    "SetOrientation", "SetValueStep", "SetObeyStepOnDrag", "SetThumbTexture",
    "SetNumeric", "SetSpacing", "SetClipsChildren", "SetBlendMode", "SetScale",
    "SetShadowOffset", "SetShadowColor", "SetGradient", "SetGradientAlpha", "SetDesaturated",
    "SetAtlas", "AddMaskTexture", "SetRotation", "SetHitRectInsets",
    "SetFixedFrameStrata", "SetFixedFrameLevel", "SetSnapToPixelGrid", "SetTexelSnappingBias", "SetVertexOffset",
    "SetPassThroughButtons", "EnableKeyboard", "SetPropagateKeyboardInput", "SetHyperlinksEnabled", "SetFixedFrameStrata",
}

local ANCHORS = {}
for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT",
    "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
    ANCHORS[point] = true
end

-- What the layout calls left behind, for tests/uidump.lua's snapshot: the
-- last arguments of every no-op method, the anchors and the size, on
-- `w.recorded`. Recording only: nothing the addon or a test can read back
-- through the widget API changes.
local function Pack(...)
    return { n = select("#", ...), ... }
end

-- Calls are numbered, so the snapshot can tell which of two overriding
-- calls (SetTexture, SetColorTexture) came last.
local callCount = 0

local RECORDERS = {}
for i = 1, #NOOPS do
    local method = NOOPS[i]
    RECORDERS[method] = function(self, ...)
        if type(self) == "table" and self.recorded then
            callCount = callCount + 1
            local args = Pack(...)
            args.seq = callCount
            self.recorded.calls[method] = args
        end
    end
end

-- What a texture was last painted, whichever form the client takes it in
-- (Style.Gradient in UI/Style/Draw.lua): its gradient's two ends as
-- { r, g, b, a } each, the orientation, and "gradient"; or its flat colour
-- as both ends, nil orientation, and "flat". Nothing painted, nothing back.
function M.Paint(w)
    local calls = w.recorded.calls
    local gradient, fade = calls.SetGradient, calls.SetGradientAlpha
    local ends = gradient
    if fade and (not ends or fade.seq > ends.seq) then ends = fade end
    local flat = calls.SetColorTexture
    if flat and (not ends or flat.seq > ends.seq) then
        local f = { r = flat[1], g = flat[2], b = flat[3], a = flat[4] or 1 }
        return f, f, nil, "flat"
    end
    if not ends then return end
    if ends == fade then
        return { r = fade[2], g = fade[3], b = fade[4], a = fade[5] or 1 },
            { r = fade[6], g = fade[7], b = fade[8], a = fade[9] or 1 }, fade[1], "gradient"
    end
    return { r = gradient[2], g = gradient[3], b = gradient[4], a = 1 },
        { r = gradient[5], g = gradient[6], b = gradient[7], a = 1 }, gradient[1], "gradient"
end

local function NewWidget(frameType, name, parent, template)
    local w = {
        frameType = frameType, name = name, parent = parent, template = template,
        scripts = {}, events = {}, shown = false, text = "",
    }
    -- The global name too: the addon is free to hang its own `name` on a
    -- frame (a font string, say).
    local rec = { calls = {}, points = {}, globalName = name }
    w.recorded = rec

    for i = 1, #NOOPS do
        w[NOOPS[i]] = RECORDERS[NOOPS[i]]
    end

    -- Anchors as the client keeps them: one per point, replaced by the same
    -- point again, all dropped by ClearAllPoints. SetAllPoints is two.
    local function Anchor(point, ...)
        local n = 0
        for i = 1, #rec.points do
            if rec.points[i].point == point then n = i end
        end
        local anchor = { point = point, args = Pack(...) }
        if n > 0 then rec.points[n] = anchor else rec.points[#rec.points + 1] = anchor end
    end
    function w:ClearAllPoints() rec.points = {} end
    function w:SetAllPoints(relative)
        rec.points = {}
        Anchor("TOPLEFT", relative or self.parent, "TOPLEFT")
        Anchor("BOTTOMRIGHT", relative or self.parent, "BOTTOMRIGHT")
    end

    -- Anchor names are strings the client checks and the mock otherwise
    -- would not: a typo'd point is a silent layout bug in game.
    function w:SetPoint(point, a, b, ...)
        assert(ANCHORS[point], "invalid anchor point: " .. tostring(point))
        if type(a) == "table" and type(b) == "string" then
            assert(ANCHORS[b], "invalid relative point: " .. b)
        elseif type(a) == "string" then
            assert(ANCHORS[a], "invalid relative point: " .. a)
        end
        Anchor(point, a, b, ...)
    end

    function w:SetScript(key, fn) self.scripts[key] = fn end
    function w:GetScript(key) return self.scripts[key] end
    function w:HookScript(key, fn)
        local previous = self.scripts[key]
        self.scripts[key] = function(...)
            if previous then previous(...) end
            fn(...)
        end
    end

    -- `shown` starts false here; in the client a region starts shown. The
    -- snapshot needs to know which it was told.
    function w:Show() self.shown, rec.toldShown = true, true end
    function w:Hide()
        self.shown, rec.toldShown = false, false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function w:IsShown() return self.shown end
    function w:GetParent() return self.parent end
    -- Whether the mouse is over it: what a test says (`mouseOver`).
    function w:IsMouseOver() return self.mouseOver == true end
    -- Whether it hears clicks: EnableMouse, then SetMouseClickEnabled.
    function w:SetMouseClickEnabled(on) self.clicksOn = on end
    function w:IsMouseClickEnabled()
        if self.clicksOn ~= nil then return self.clicksOn end
        local mouse = rec.calls.EnableMouse
        return mouse ~= nil and mouse[1] == true
    end
    function w:GetChildren() return unpack(self.children or {}) end
    function w:IsVisible() return self.shown end
    function w:SetShown(value) if value then self:Show() else self:Hide() end end

    -- Focus, as the client tracks it. Losing focus does not fire
    -- OnEditFocusLost here; tests call the script when they mean it.
    function w:SetFocus() self.focused = true end
    function w:ClearFocus() self.focused = false end
    function w:HasFocus() return self.focused == true end

    -- Scroll frames.
    w.scroll = 0
    function w:SetScrollChild(child) self.child = child end
    function w:GetVerticalScroll() return self.scroll end
    function w:SetVerticalScroll(value) self.scroll = value end
    function w:GetVerticalScrollRange() return 0 end
    function w:UpdateScrollChildRect() end
    function w:GetHeight() return self.height or 0 end
    -- Where it lies on the screen, for code that reads a frame back after
    -- it was dragged. Nothing is laid out: a test sets `w.at` = { x, top }.
    -- `at[3]`, when given, is its middle's height (else 0).
    function w:GetCenter() return self.at and self.at[1], self.at and (self.at[3] or 0) end
    function w:GetEffectiveScale() return self.effectiveScale or 1 end
    -- Its scale, as last set (SetScale is recorded with the no-ops).
    function w:GetScale()
        local scale = rec.calls.SetScale
        return scale and scale[1] or 1
    end
    function w:GetTop() return self.at and self.at[2] end
    -- Its right edge on the screen: what a test says (`right`), else nil.
    function w:GetRight() return self.right end
    -- Its left and bottom edges likewise (`left`, `bottom`), else nil: a
    -- test that lays a region out sets all four (`at[2]` the top).
    function w:GetLeft() return self.left end
    function w:GetBottom() return self.bottom end
    -- Its turn, as last set (SetRotation is recorded with the no-ops).
    function w:GetRotation()
        local turn = rec.calls.SetRotation
        return turn and turn[1] or 0
    end
    -- Its alpha, as last set (SetAlpha is recorded with the no-ops).
    function w:GetAlpha()
        local alpha = rec.calls.SetAlpha
        return alpha and alpha[1] or 1
    end

    -- A font string with no font refuses text in the client ("Font not
    -- set"): its font comes from a template, SetFont or SetFontObject.
    function w:SetText(value)
        if frameType == "FontString" and not (template or rec.calls.SetFont or rec.calls.SetFontObject) then
            error("FontString:SetText(): Font not set", 2)
        end
        self.text = value or ""
    end
    function w:GetText() return self.text end
    -- A button's own text as a font string, as the client keeps it: made the
    -- first time it is asked for, with a font (the button's template gives it
    -- one) and the words set so far.
    function w:GetFontString()
        if not self.fontString then
            self.fontString = w:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        end
        self.fontString:SetText(self.text or "")
        return self.fontString
    end

    -- Sliders. Like the client, SetValue clamps and fires OnValueChanged
    -- only when the value actually moves.
    w.min, w.max, w.value = 0, 0, 0
    function w:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
    function w:GetMinMaxValues() return self.min, self.max end
    function w:GetValue() return self.value end
    function w:SetValue(value)
        value = math.max(self.min, math.min(self.max, value))
        if value == self.value then return end
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end

    function w:CreateFontString(n, layer, t)
        local child = NewWidget("FontString", n, self, t)
        child.recorded.layer = layer
        return child
    end
    function w:CreateTexture(n, layer, t, sublevel)
        -- The client refuses a sublevel outside -8..7 (an error, not a clamp).
        assert(sublevel == nil or (sublevel >= -8 and sublevel <= 7), "Sublevel must be between -8 and 7")
        local child = NewWidget("Texture", n, self, t)
        child.recorded.layer, child.recorded.sublevel = layer, sublevel
        return child
    end
    function w:CreateMaskTexture(n) return NewWidget("MaskTexture", n, self) end
    -- The same limit when a region's layer is changed later.
    function w:SetDrawLayer(layer, sublevel)
        assert(sublevel == nil or (sublevel >= -8 and sublevel <= 7), "Sublevel must be between -8 and 7")
        self.recorded.layer, self.recorded.sublevel = layer, sublevel
    end

    -- No font metrics here: a rough width from the length keeps layout
    -- arithmetic honest about types, not about pixels. Colour codes take no
    -- room, as in the client.
    local function Shown(text)
        return ((text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:|]*:", ""):gsub("|H.-|h", ""):gsub("|h", "")
            :gsub("|r", ""))
    end
    function w:SetParent(parent) self.parent = parent end
    function w:GetStringWidth() return #Shown(self.text) * 6 end
    function w:GetStringHeight() return self.text ~= "" and 14 or 0 end
    function w:GetUnboundedStringWidth() return #Shown(self.text) * 6 end
    function w:IsTruncated() return true end
    -- A font string's colour and shadow, read back (the pad's look saves
    -- and restores them, UI/Pad/Look.lua): what was set on it last, unless
    -- a font object was given after it, whose own then counts (the mock
    -- takes SetFontObject to copy the object's, which is what the client is
    -- believed to do; checked in the client, see .claude/controller-plan.md),
    -- else the client's defaults: white, a black shadow, no offset.
    local function Last(method)
        local own, object = rec.calls[method], rec.calls.SetFontObject
        local font = object and object[1]
        local inherited = type(font) == "table" and font.recorded and font.recorded.calls[method]
        if own and not (object and object.seq > own.seq) then return own end
        return inherited
    end
    function w:GetTextColor()
        local c = Last("SetTextColor")
        if not c then return 1, 1, 1, 1 end
        return c[1], c[2], c[3], c[4] or 1
    end
    function w:GetShadowColor()
        local c = Last("SetShadowColor")
        if not c then return 0, 0, 0, 1 end
        return c[1], c[2], c[3], c[4] or 1
    end
    -- How it is set in its box, as last set (the client's defaults else).
    function w:GetJustifyH()
        local j = rec.calls.SetJustifyH
        return j and j[1] or "CENTER"
    end
    function w:GetJustifyV()
        local j = rec.calls.SetJustifyV
        return j and j[1] or "MIDDLE"
    end
    -- Its font file and size: SetFont's, else its font object's.
    function w:GetFont()
        local f = Last("SetFont")
        if f then return f[1], f[2], f[3] end
        return nil, nil, nil
    end
    function w:GetShadowOffset()
        local o = Last("SetShadowOffset")
        if not o then return 0, 0 end
        return o[1], o[2]
    end
    -- A frame's level: the one it was given, else one over its parent's,
    -- as the client gives a new frame.
    function w:GetFrameLevel()
        local level = rec.calls.SetFrameLevel
        if level then return level[1] end
        local parent = self.parent
        return parent and parent.GetFrameLevel and parent:GetFrameLevel() + 1 or 1
    end
    w.width = 0
    function w:GetWidth() return self.width end
    function w:SetWidth(value) self.width, rec.width = value, value end
    function w:SetHeight(value) rec.height = value end
    function w:SetSize(width, height) self.width, rec.width, rec.height = width, width, height end

    function w:RegisterEvent(event)
        self.events[event] = true
        M.registered[event] = true
    end

    -- The units are not kept: fire delivers to every frame, and a handler
    -- that asked for "player" checks its unit anyway.
    function w:RegisterUnitEvent(event)
        self:RegisterEvent(event)
    end

    function w:UnregisterEvent(event)
        self.events[event] = nil
        for i = 1, #M.frames do
            if M.frames[i].events[event] then return end
        end
        M.registered[event] = nil
    end

    -- The pad's input on a frame (UI/Pad/): whether it takes buttons and
    -- sticks. In the client setting OnGamePadButtonDown / Up turns the
    -- buttons on by itself; so here.
    function w:EnableGamePadButton(on) self.padButtons = on and true or false end
    function w:IsGamePadButtonEnabled() return self.padButtons == true end
    function w:EnableGamePadStick(on) self.padSticks = on and true or false end
    function w:IsGamePadStickEnabled() return self.padSticks == true end
    local setScript = w.SetScript
    function w:SetScript(key, fn)
        setScript(self, key, fn)
        if fn and (key == "OnGamePadButtonDown" or key == "OnGamePadButtonUp") then self.padButtons = true end
        if fn and key == "OnGamePadStick" then self.padSticks = true end
    end

    function w:SetChecked(value) self.checked = value and true or false end
    function w:GetChecked() return self.checked == true end

    -- A model frame, as far as reading what it shows: a creature's display
    -- (M.creatureDisplays, by NPC id) on the second read, as the client
    -- takes a moment to load it; 0 for a creature not in the cache.
    -- M.models counts SetCreature calls.
    if frameType == "PlayerModel" then
        function w:SetCreature(npcID)
            M.models = (M.models or 0) + 1
            self.display, self.loading = M.creatureDisplays[npcID] or 0, true
        end
        function w:GetDisplayInfo()
            if self.loading then
                self.loading = false
                return 0
            end
            return self.display or 0
        end

        -- Drawing from a display (the killer card, Features/Deaths/Card.lua): none
        -- of it verified in the client, so each call is only recorded, on
        -- `w.model` (its last arguments by method), for the tests to read.
        -- A display in M.blankDisplays draws nothing (GetModelFileID 0, as
        -- one the client cannot find). A method named in M.modelLacks is
        -- left off every model made after, as a client without it would.
        local calls = {}
        w.model = calls
        local function Record(method, fn)
            if (M.modelLacks or {})[method] then return end
            w[method] = function(self, ...)
                calls[method] = Pack(...)
                if fn then return fn(self, ...) end
            end
        end
        Record("SetDisplayInfo", function(self, display) self.display, self.loading = display, false end)
        Record("GetModelFileID", function(self)
            if not self.display or self.display == 0 or (M.blankDisplays or {})[self.display] then return 0 end
            return 100000 + self.display
        end)
        for _, method in ipairs({ "SetFogColor", "SetFogNear", "SetFogFar", "SetFacing", "SetPortraitZoom",
            "SetCamDistanceScale", "SetViewTranslation", "FreezeAnimation", "SetAnimation", "SetPaused", "SetLight",
            "ClearModel" }) do
            Record(method)
        end
        Record("HasAnimation", function(_, id) return id == 0 end)
        Record("HasScript", function(_, script) return script == "OnModelLoaded" end)
    end

    -- Simulates a click on a button. A check button flips before OnClick,
    -- as in the client.
    function w:Click(...)
        if self.frameType == "CheckButton" then self.checked = not self.checked end
        if self.scripts.OnClick then self.scripts.OnClick(self, ...) end
    end

    -- Widget methods are UpperCamelCase without exception, so an unknown one
    -- is a mock gap worth raising on. Anything else is a field the addon hung
    -- on the frame and has not set yet, where nil is the honest answer.
    setmetatable(w, {
        __index = function(_, key)
            if type(key) == "string" and key:match("^%u") then
                error(("widget method not modelled in wowmock: %s (on a %s)")
                    :format(key, frameType), 2)
            end
            return nil
        end,
    })

    M.frames[#M.frames + 1] = w
    return w
end

M.NewWidget = NewWidget

-- The globals named frames and fonts went into, for Reset. Not w.name: the
-- addon is free to hang its own `name` (a font string, say) on a frame.
local named = {}

_G.CreateFrame = function(frameType, name, parent, template)
    local w = NewWidget(frameType or "Frame", name, parent, template)
    if type(parent) == "table" then
        parent.children = parent.children or {}
        parent.children[#parent.children + 1] = w
    end
    if name then _G[name], named[#named + 1] = w, name end
    if type(template) == "string" and template:find("UIPanelCloseButton") then
        w.scripts.OnClick = function(self) _G.HideUIPanel(self:GetParent()) end
    end
    return w
end

_G.CreateFont = function(name)
    local font = NewWidget("Font", name)
    if name then _G[name], named[#named + 1] = font, name end
    return font
end

_G.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
-- (CreateVector3D/2D: Core/Compat/Extras.lua's, not the client's.)

-- A creature display's 2D portrait onto a texture (the killer card's
-- print): recorded as the texture's `portrait`.
_G.SetPortraitTextureFromCreatureDisplayID = function(texture, display) texture.portrait = display end

-- Sounds: a few SOUNDKIT names, and what was played, in order, as
-- { id, channel }.
_G.SOUNDKIT = { IG_QUEST_LOG_OPEN = 844, IG_QUEST_LOG_CLOSE = 845, IG_SPELLBOOK_OPEN = 829,
    IG_SPELLBOOK_CLOSE = 830, IG_CHARACTER_INFO_TAB = 841, IG_ABILITY_PAGE_TURN = 836,
    IG_WRITE_QUEST = 3093, IG_QUEST_LIST_OPEN = 875, IG_QUEST_LIST_SELECT = 877, RAID_WARNING = 8959,
    IG_BACKPACK_OPEN = 862 }
M.sounds = {}
_G.PlaySound = function(id, channel) M.sounds[#M.sounds + 1] = { id, channel } end

-- Every art path exists, unless a test says otherwise.
M.missingFiles = {}
_G.GetFileIDFromPath = function(path)
    if M.missingFiles[path] then return nil end
    return 1
end

_G.UIParent = NewWidget("Frame", "UIParent")

-- The minimap: 140 wide, its middle at (700, 500) on the screen. A test may
-- set _G.GetMinimapShape as an addon that reshapes it would.
local function NewMinimap()
    local minimap = NewWidget("Frame", "Minimap")
    minimap.width, minimap.at = 140, { 700, 570, 500 }
    return minimap
end
_G.Minimap = NewMinimap()

-- Blizzard's callback registry, as far as Edit Mode's two events: a test
-- calls M.EditMode(true) to open it and M.EditMode(false) to close it.
local function NewEventRegistry()
    local registry = { callbacks = {} }
    function registry:RegisterCallback(event, fn, owner)
        local list = self.callbacks[event] or {}
        self.callbacks[event] = list
        list[#list + 1] = { fn = fn, owner = owner }
    end
    function registry:TriggerEvent(event, ...)
        for _, cb in ipairs(self.callbacks[event] or {}) do cb.fn(cb.owner, ...) end
    end
    return registry
end
_G.EventRegistry = NewEventRegistry()

function M.EditMode(open)
    _G.EventRegistry:TriggerEvent(open and "EditMode.Enter" or "EditMode.Exit")
end
_G.UISpecialFrames = {}

-- Blizzard's panel manager, as far as closing goes: an addon's call in
-- combat is refused (and the "action blocked" message shown), out of combat
-- a window that is no UI panel is simply hidden. The close button template
-- clicks through it, as in the client.
M.blocked = 0
_G.DisplayInterfaceActionBlockedMessage = function() M.blocked = M.blocked + 1 end
_G.HideUIPanel = function(frame)
    if not frame or not frame:IsShown() then return end
    if M.inCombat then
        _G.DisplayInterfaceActionBlockedMessage()
        return
    end
    frame:Hide()
end

-- 3.3.5's own addon functions (C_AddOns is the retail namespace, and the
-- client has no such table: Core/Compat/Env.lua builds it from these).
M.addons = {}
_G.LoadAddOn = function(name) M.addons[name] = true return true end
_G.IsAddOnLoaded = function(name) return M.addons[name] == true, true end
_G.GetAddOnMetadata = function(name, key)
    if key == "Version" then return "4.1.1" end
    if key == "Title" then return "Social Diary" end
    return nil
end
_G.GetAddOnInfo = function(name) return name, name, "", true, "", "" end
_G.GetNumAddOns = function() return 1 end

_G.GetServerTime = function() return M.now end
-- 3.3.5a: the build the CoA client reports, and the locale it is installed in.
_G.GetBuildInfo = function() return "3.3.5", "12340", "Aug 12 2009", 30300 end
_G.GetLocale = function() return "enUS" end
_G.GetRealmName = function() return M.realm end
_G.GetNormalizedRealmName = function() return (M.realm:gsub("%s+", "")) end
_G.SlashCmdList = {}

--------------------------------------------------------------------------
-- Where the player is (Mulgore, as Session 1 saw it)
--------------------------------------------------------------------------

M.zone, M.subZone = "Mulgore", ""
-- The zone text SetMapToCurrentZone last worked the map out from. On the
-- client the text and the area id change together (both from the player's
-- position), so a change of text means a new area; an unchanged text means
-- a test that moved M.mapID on its own is describing where the player
-- stands now, and the id wins. Reset() clears it with everything else.
M.lastZone = nil
M.mapID = 1412
M.position = { x = 0.4213, y = 0.6157 }
M.inInstance, M.instanceName, M.instanceID = false, "The Deadmines", 36

_G.GetRealZoneText = function() return M.inInstance and M.instanceName or M.zone end
_G.GetZoneText = function() return M.zone end

-- "sanctuary", "friendly", "hostile", "contested" or nil.
M.pvpType = nil
_G.GetZonePVPInfo = function() return M.pvpType end
_G.GetSubZoneText = function() return M.subZone end

M.instanceType = "party"
_G.IsInInstance = function()
    if not M.inInstance then return false, "none" end
    return true, M.instanceType
end

_G.GetInstanceInfo = function()
    return M.instanceName, M.instanceType, 1, "Normal", 5, 0, 0, M.instanceID
end

-- Map art as a classic zone has it: one 1002 x 668 layer of 256-pixel tiles,
-- 4 x 3 of them. Maps not listed in M.mapArt have no art.
M.mapNames = { [1412] = "Mulgore", [1413] = "The Barrens", [1414] = "Kalimdor",
    [2000] = "Palemane Rock", [1454] = "Orgrimmar" }
M.mapArt = { [1412] = true, [1413] = true }
-- The areas explored on a map, as C_MapExplorationInfo hands them back.
M.explored = {}

-- The map tree, as Enum.UIMapType has it (2 continent, 3 zone, 5 micro):
-- a map not listed here is a zone, with no parent unless one is given.
-- 2000 is a cave in Mulgore, with its own 0..1 square.
M.mapTypes = { [1414] = 2, [2000] = 5 }
M.mapParents = { [2000] = 1412 }

-- Where each map lies in the world, in yards: left, top, width, height
-- (x right, y down; the C_Map world vectors turn these into the client's
-- (north, west)). A map not listed cannot be placed (GetWorldPosFromMapPos
-- returns nothing for it). Continent 1 for all of them.
M.mapRects = {
    [1412] = { 0, 0, 5000, 3333 },
    [1413] = { 5000, 0, 6000, 4000 },
    [2000] = { 1000, 1000, 200, 150 },
}

-- The world map, as 3.3.5 has it. No C_Map: continents by index, zones
-- within a continent, one of the two current. GetMapInfo takes NO
-- arguments and hands back the current map's art (the client's own
-- QuestLogFrame.lua:587 reads it as "local mapFileName, textureHeight =
-- GetMapInfo()"), and GetPlayerMapPosition is the only way to ask where
-- the player is on it. C_Map, its world vectors and UnitPosition are the
-- retail face of this and belong to Core/Compat (PORT.md section 3).
-- M.world stays as data only: 3.3.5 has no API that returns it.
M.world = nil

M.continents = { "Kalimdor", "Eastern Kingdoms", "Outland", "Northrend" }
-- Zone art per continent, in the client's order: the area id the client
-- reports for it, the texture GetMapInfo hands back and its height.
M.mapZones = {
    [1] = {
        { id = 1412, name = "Mulgore", file = "Interface\\WorldMap\\Kalimdor\\Mulgore\\Mulgore1", height = 668 },
        { id = 1413, name = "The Barrens", file = "Interface\\WorldMap\\Kalimdor\\TheBarrens\\TheBarrens1", height = 668 },
    },
    [2] = {
        { id = 1454, name = "Orgrimmar", file = "Interface\\WorldMap\\Azeroth\\Orgrimmar\\Orgrimmar1", height = 668 },
    },
}
M.continentIDs = { [1] = 1414, [2] = 1415, [3] = 1416, [4] = 1417 }
M.mapContinent, M.mapZone = 1, 1

_G.GetMapContinents = function() return unpack(M.continents) end

_G.GetMapZones = function(continent)
    local zones = M.mapZones[continent]
    if not zones then return end
    local names = {}
    for i, zone in ipairs(zones) do names[i] = zone.name end
    return unpack(names)
end

_G.SetMapZoom = function(continent, zone)
    M.mapContinent, M.mapZone = continent, zone
end
_G.GetCurrentMapContinent = function() return M.mapContinent end
_G.GetCurrentMapZone = function() return M.mapZone end

-- The area id of whatever the map is showing: a zone's own, or the
-- continent's when a whole continent is up.
function M.CurrentAreaID()
    local zones = M.mapZones[M.mapContinent]
    local zone = zones and zones[M.mapZone]
    if zone then return zone.id end
    return M.continentIDs[M.mapContinent]
end
_G.GetCurrentMapAreaID = function() return M.CurrentAreaID() end

-- The area id the client last announced. The client fires a zone event when
-- the map the player stands on changes (a cave, a district, a whole zone),
-- and Core/Compat/Map.lua drops its map cache on those events. Setting
-- M.mapID by hand is not a move unless the test says so, which is what
-- M.MoveTo is for: the client's own map callers never announce anything.
M.reportedArea = nil
function M.AnnounceArea()
    local id = M.CurrentAreaID()
    if id == M.reportedArea then return end
    M.reportedArea = id
    M.fire("ZONE_CHANGED_INDOORS")
end

-- The player moved: stand at `position` (0..1, or nil) on `mapID` and tell
-- the client, as walking into a cave or another district does. The map view
-- follows at once, so a caller reading the position straight afterwards sees
-- the new area, exactly as it does in game.
function M.MoveTo(mapID, position)
    M.mapID, M.position = mapID, position
    SetMapToCurrentZone()
    M.AnnounceArea()
end

-- Select a map by the id the client's SetMapByID takes: a WorldMapArea id,
-- one less than the area id GetCurrentMapAreaID reports for the same map
-- (the client's own FrameXML writes SetMapByID(mapID - 1)). The ids this
-- file holds are the reported ones, so the argument is stepped back up here:
-- a zone, a continent, or an id only M.mapNames names (a test's own map,
-- 9001 and the like, which joins the zone list the way the client's own
-- zone table would describe it, so a name can be read back for it).
_G.SetMapByID = function(dbcID)
    local areaID = dbcID and (dbcID + 1)
    local function choose()
    if not areaID then return end
    for continent, zones in pairs(M.mapZones) do
        for index, zone in ipairs(zones) do
            if zone.id == areaID then
                M.mapContinent, M.mapZone = continent, index
                return
            end
        end
    end
    for continent, id in pairs(M.continentIDs) do
        if id == areaID then M.mapContinent, M.mapZone = continent, 0 return end
    end
    local name = M.mapNames[areaID]
    if name then
        local zones = M.mapZones[1]
        zones[#zones + 1] = { id = areaID, name = name, file = nil, height = 0 }
        M.mapContinent, M.mapZone = 1, #zones
    end
    end
    choose()
end

-- The client works out the map from where the player stands: moving to a
-- new zone changes GetZoneText and the area id together. A test that moves
-- only M.zone is describing a move, so the text looks the id up; a test
-- that moves only M.mapID is describing where the player stands without
-- restating the text, and the id is used as it stands. M.lastZone is what
-- tells the two apart.
_G.SetMapToCurrentZone = function()
    local function choose()
    local here = M.zone
    if M.lastZone ~= here then
        M.lastZone = here
        for continent, zones in pairs(M.mapZones) do
            for index, zone in ipairs(zones) do
                if here ~= nil and zone.name == here then
                    M.mapID = zone.id
                    M.mapContinent, M.mapZone = continent, index
                    return
                end
            end
        end
    end
    if M.mapID ~= nil then
        for continent, zones in pairs(M.mapZones) do
            for index, zone in ipairs(zones) do
                if zone.id == M.mapID then
                    M.mapContinent, M.mapZone = continent, index
                    return
                end
            end
        end
        for continent, id in pairs(M.continentIDs) do
            if id == M.mapID then M.mapContinent, M.mapZone = continent, 0 return end
        end
        -- A sub-map (a cave, a building) has its own area id in the client's
        -- map table: the client selects it and reports that id back.
        if M.mapNames[M.mapID] then SetMapByID(M.mapID - 1) return end
    end
    -- An id the client cannot describe: no map is up at all.
    M.mapContinent, M.mapZone = 0, 0
    end
    choose()
end

_G.GetMapInfo = function()
    local zones = M.mapZones[M.mapContinent]
    local zone = zones and zones[M.mapZone]
    if not zone then return nil end
    return zone.file, zone.height
end

-- Where the player is on the map currently up, 0..1 (y down); 0, 0 for a
-- map the player is not on, as the client answers.
_G.GetPlayerMapPosition = function(unit)
    if not M.position or M.mapID == nil or M.CurrentAreaID() ~= M.mapID then return 0, 0 end
    return M.position.x, M.position.y
end

-- The C_Map the client itself ships: FrameXML\\Util\\C_WorldMap.lua:188 has
-- "C_Map = C_Map or {}", filled with GetBestMapForUnit built on the globals
-- above and with nothing else. Every other member is Core/Compat/Map.lua's.
_G.C_Map = {
    GetBestMapForUnit = function(unit)
        SetMapToCurrentZone()
        return GetCurrentMapAreaID()
    end,
}

-- Explored map overlays, as 3.3.5 has them: (texture, numTiles, explored)
-- per index. C_MapExplorationInfo is the retail face of this and belongs
-- to Core/Compat.
M.explored = {}
_G.GetNumMapOverlays = function() return #M.explored end
_G.GetMapOverlayInfo = function(index)
    local overlay = M.explored[index]
    if not overlay then return nil end
    return overlay.texture, overlay.tiles or 1, overlay.explored ~= false
end

M.onTaxi, M.afk, M.dead, M.ghost, M.resting = false, false, false, false, false
M.maxLevel = 60
_G.UnitOnTaxi = function() return M.onTaxi end
_G.UnitIsAFK = function() return M.afk end
_G.UnitIsDeadOrGhost = function() return M.dead or M.ghost end
_G.UnitIsGhost = function() return M.ghost end
-- Issue #33: a hunter's Feign Death, the user's (M.feigning) or a unit's
-- (its def's `feigning`).
M.feigning = false
_G.UnitIsFeignDeath = function(unit)
    if unit == "player" then return M.feigning end
    local def = M.units[unit]
    return def and def.feigning or false
end
_G.IsResting = function() return M.resting end
_G.GetMaxPlayerLevel = function() return M.maxLevel end

-- JRN-25: the player's health. Secret in combat on the client (probe, 11
-- Oct); a test makes it so with M.secret.
M.health, M.healthMax = 100, 100
_G.UnitHealth = function() return M.health end
_G.UnitHealthMax = function() return M.healthMax end

-- JRN-26: the quest log, as 3.3.5 has it (the retail C_QuestLog table is
-- Core/Compat/Quests.lua's job, not the mock's). M.quests is a list of
-- { questID, title, objectives = { { text, type, numFulfilled,
-- numRequired, finished } } }. The orders below are the client's own:
-- GetQuestLogTitle returns title, level, suggestedGroup, isHeader,
-- isCollapsed, isComplete, isDaily, questID (8 values), and
-- GetQuestLogLeaderBoard returns text, type, finished, have, need.
M.quests = {}
_G.GetNumQuestLogEntries = function() return #M.quests end
_G.GetQuestLogTitle = function(i)
    local q = M.quests[i]
    if not q then return end
    return q.title, q.level, q.suggestedGroup, false, false, q.complete, nil, q.questID
end
_G.GetQuestLink = function(i)
    local q = M.quests[i]
    return q and q.link
end
_G.GetNumQuestLeaderBoards = function(i)
    local q = M.quests[i]
    return q and #(q.objectives or {}) or 0
end
_G.GetQuestLogLeaderBoard = function(j, i)
    local q = M.quests[i]
    local o = q and q.objectives and q.objectives[j]
    if not o then return end
    return o.text, o.type, o.finished, o.numFulfilled, o.numRequired
end
_G.GetQuestLogQuestText = function(i)
    local q = M.quests[i]
    return q and q.detail, q and q.objectivesText
end

-- The loot window: M.loot is a list of { link, sources = { guid, n, ... } }.
M.loot = {}
_G.GetNumLootItems = function() return #M.loot end
_G.GetLootSlotLink = function(slot) return M.loot[slot] and M.loot[slot].link end
_G.GetLootSourceInfo = function(slot) return unpack(M.loot[slot] and M.loot[slot].sources or {}) end

--------------------------------------------------------------------------
-- Trade (T-E8). LE_GAME_ERR_* is deliberately left undefined so the capture
-- code's fallback to the observed message ids is what gets exercised.
--------------------------------------------------------------------------

_G.MAX_TRADE_ITEMS = 7
M.trade = { given = {}, received = {}, moneyGiven = 0, moneyReceived = 0 }

local function Slot(side, slot)
    return M.trade[side][slot]
end

_G.GetTradePlayerItemInfo = function(slot)
    local item = Slot("given", slot)
    if not item then return nil end
    return item.name, nil, item.count
end

_G.GetTradeTargetItemInfo = function(slot)
    local item = Slot("received", slot)
    if not item then return nil end
    return item.name, nil, item.count
end

_G.GetTradePlayerItemLink = function(slot)
    local item = Slot("given", slot)
    return item and item.link
end

_G.GetTradeTargetItemLink = function(slot)
    local item = Slot("received", slot)
    return item and item.link
end

_G.GetPlayerTradeMoney = function() return M.trade.moneyGiven end
_G.GetTargetTradeMoney = function() return M.trade.moneyReceived end

--------------------------------------------------------------------------
-- Bags and what is worn (Your Diary's firsts). M.bags[bag] = { size,
-- [slot] = { link, quality } }, bag 0 the backpack; a bag in a bag slot
-- is M.equipped[19 + bag]. M.itemInfo[itemID] = { equipLoc, classID,
-- subclassID }, what C_Item.GetItemInfoInstant reads without the cache.
--------------------------------------------------------------------------

_G.NUM_BAG_SLOTS = 4
M.bags = { [0] = { size = 16 } }
M.equipped = {}
M.itemInfo = {}

-- The container natives, 8 values flat as the client returns them:
-- texture, count, locked, quality, readable, lootable, hyperlink,
-- isFiltered.
_G.GetContainerNumSlots = function(bag)
    local b = M.bags[bag]
    if b then return b.size end
    local worn = M.equipped[19 + bag]
    return worn and worn.size or 0
end
_G.GetContainerItemInfo = function(bag, slot)
    local b = M.bags[bag]
    local item = b and b[slot]
    if not item then return end
    local id = item.link and tonumber(item.link:match("item:(%d+)"))
    local texture = id and select(10, GetItemInfo(id)) or item.texture or 134400
    return texture, item.count or 1, item.locked or false, item.quality, false, false, item.link, false
end
_G.GetContainerItemLink = function(bag, slot)
    local b = M.bags[bag]
    local item = b and b[slot]
    return item and item.link
end
_G.GetContainerNumFreeSlots = function(bag)
    local size = GetContainerNumSlots(bag)
    local used = 0
    for slot = 1, size do if GetContainerItemInfo(bag, slot) then used = used + 1 end end
    return size - used, 0
end
_G.ContainerIDToInventoryID = function(bag) return 19 + bag end

_G.GetInventoryItemLink = function(_, slot)
    local item = M.equipped[slot]
    return item and item.link
end

_G.GetInventoryItemQuality = function(_, slot)
    local item = M.equipped[slot]
    return item and item.quality
end

-- M.itemInfo[itemID] = { equipLoc, classID, subclassID, icon, quality,
-- name, type, subType, itemLevel, sellPrice }, what the item natives read.
-- GetItemInfoInstant is the client's 7-value form; GetItemInfo the
-- 11-value one (the tenth is the texture, which is what the container
-- native above reuses).
_G.GetItemInfoInstant = function(id)
    id = tonumber(id)
    local info = id and M.itemInfo[id]
    if not info then return id, "Miscellaneous", "Junk", "", 134400, 15, 0 end
    return id, info.type or "Miscellaneous", info.subType or "Junk",
        info.equipLoc or "", info.icon or 134400, info.classID or 15, info.subclassID or 0
end
_G.GetItemInfo = function(id)
    id = tonumber(id)
    local info = id and M.itemInfo[id]
    if not info then return end
    local link = info.link or ("|cff9d9d9d|Hitem:" .. id .. ":0:0:0:0:0:0:0|h[" .. (info.name or "Item") .. "]|h|r")
    return info.name or "Item", link, info.quality or 0, info.itemLevel or 1,
        info.minLevel or 1, info.type or "Miscellaneous", info.subType or "Junk",
        info.stackCount or 1, info.equipLoc or "", info.icon or 134400, info.sellPrice or 0
end

--------------------------------------------------------------------------
-- Professions (Your Diary's skill caps): the modern API, as on Forever.
-- M.professions[slot] = { name, rank, max, line }; a slot left nil is one
-- GetProfessions gives as nil (no second profession, no fishing).
--------------------------------------------------------------------------

M.professions = {}

_G.GetProfessions = function()
    local p = M.professions
    return p[1] and 1, p[2] and 2, p[3] and 3, p[4] and 4, p[5] and 5
end

_G.GetProfessionInfo = function(index)
    local p = M.professions[index]
    if not p then return nil end
    return p.name, 136235, p.rank, p.max, 0, 0, p.line, 0, -1, 0, p.name
end

--------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------

M.timers = {}
M.tickers = {}

-- Tickers are recorded, never run: tests drive the tick function directly,
-- with the clock where they want it.
_G.C_Timer = {
    After = function(delay, fn) M.timers[#M.timers + 1] = { delay = delay, fn = fn } end,
    NewTicker = function(interval, fn)
        local ticker = { interval = interval, fn = fn, Cancel = function() end }
        M.tickers[#M.tickers + 1] = ticker
        return ticker
    end,
}

-- Fires every pending timer regardless of its delay.
function M.RunTimers()
    local due = M.timers
    M.timers = {}
    for i = 1, #due do due[i].fn() end
end

--------------------------------------------------------------------------
-- The rest of the client the UI leans on
--------------------------------------------------------------------------

-- A clock that advances by `clockStep` ms on every read, so a test can make
-- work look expensive and watch the frame budget cut it off.
M.clock, M.clockStep = 0, 0
_G.debugprofilestop = function()
    M.clock = M.clock + M.clockStep
    return M.clock
end

M.cvars = { nameplateShowFriends = "0", nameplateShowEnemies = "1", nameplateMaxDistance = "41" }
_G.GetCVar = function(name) return M.cvars[name] end

_G.date = os.date
_G.CANCEL = "Cancel"

_G.RAID_CLASS_COLORS = {
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
}

M.guild = nil
_G.GetGuildInfo = function() return M.guild end

M.inRaid, M.groupSize = false, 0
_G.IsInRaid = function() return M.inRaid end
_G.IsInGroup = function() return M.groupSize > 0 end
_G.GetNumGroupMembers = function() return M.groupSize end

-- DIA-2a's unknown: whether this resolves in a build with no realm names.
-- (C_PlayerInfo is Core/Compat/'s: the client has no such namespace.)
M.locationGUID = nil

M.popups = {}
_G.StaticPopupDialogs = {}
-- As the client's: two text arguments, then the data the buttons get.
_G.StaticPopup_Show = function(which, text1, text2, data)
    local popup = { which = which, args = { text1, text2 }, data = data }
    M.popups[#M.popups + 1] = popup
    return popup
end

-- Runs a button on the most recent popup: "accept", "cancel" or "alt".
function M.AnswerPopup(button)
    local popup = M.popups[#M.popups]
    if not popup then return false end

    local dialog = StaticPopupDialogs[popup.which]
    local handler = dialog and dialog[
        button == "alt" and "OnAlt" or button == "cancel" and "OnCancel" or "OnAccept"]
    if not handler then return false end

    handler(popup, popup.data)
    return true
end

-- /reload: counted, so a test can tell it was asked for. Nothing reloads.
M.reloads = 0
_G.ReloadUI = function() M.reloads = M.reloads + 1 end

-- Menu.ModifyMenu callbacks, so a right-click can be simulated.
M.menus = {}
_G.Menu = {
    ModifyMenu = function(tag, callback)
        M.menus[tag] = M.menus[tag] or {}
        M.menus[tag][#M.menus[tag] + 1] = callback
    end,
}

-- MenuUtil.CreateContextMenu, for the journal's sort and filter menus. The
-- generator runs against a recorder; MenuClick walks it by label text.
local function Description(text, kind, a, b)
    local d = { text = text, kind = kind, a = a, b = b, children = {} }
    local function Adder(childKind)
        return function(self, childText, x, y)
            local child = Description(childText, childKind, x, y)
            self.children[#self.children + 1] = child
            return child
        end
    end
    d.CreateTitle = Adder("title")
    d.CreateButton = Adder("button")
    d.CreateRadio = Adder("radio")
    d.CreateCheckbox = Adder("checkbox")
    d.CreateDivider = Adder("divider")
    return d
end

-- MenuUtil is Core/Compat/Extras.lua's (retail's name is not the client's).
-- The recorder below is what the harness installs in its place: the same
-- generator runs against a description tree, so a test can walk it by
-- label (M.MenuClick).
M.contextMenu = nil
function M.DescribeMenu()
    return Description(nil, "root")
end

-- M.MenuClick("Tag", "friend") picks the radio under the submenu. Returns
-- false when the path does not exist.
function M.MenuClick(...)
    local node = M.contextMenu
    for i = 1, select("#", ...) do
        local want, found = select(i, ...), nil
        for _, child in ipairs(node and node.children or {}) do
            if child.text == want then found = child break end
        end
        if not found then return false end
        node = found
    end

    if node.kind == "radio" or node.kind == "checkbox" then
        node.b()
    elseif node.kind == "button" and node.a then
        node.a()
    end
    return true
end

-- Whether a radio in the last context menu reads as selected.
function M.MenuSelected(...)
    local node = M.contextMenu
    for i = 1, select("#", ...) do
        local want, found = select(i, ...), nil
        for _, child in ipairs(node and node.children or {}) do
            if child.text == want then found = child break end
        end
        if not found then return nil end
        node = found
    end
    return node.a and node.a() or false
end

_G.wipe = function(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

-- 3.3.5's own Interface Options registry, which Core/Compat/Settings.lua
-- backs retail's Settings table with (the Settings table itself is the
-- compat layer's, not the mock's). M.settingsCategories lists what was
-- added, in order, as { frame, name }; M.openedCategory the name the
-- options frame was last asked to show.
M.settingsCategories, M.openedCategory = {}, nil
_G.InterfaceOptions_AddCategory = function(frame)
    M.settingsCategories[#M.settingsCategories + 1] = { frame = frame, name = frame and frame.name }
    return true
end
_G.InterfaceOptionsFrame_OpenToCategory = function(which)
    if type(which) == "table" then M.openedCategory = which.name end
end

-- REU-2's combat check.
M.inCombat = false
_G.InCombatLockdown = function() return M.inCombat end
_G.UnitAffectingCombat = function() return M.inCombat end

-- Key bindings, for the empty People page's keycap: M.bindings is key to
-- command, as the client keeps them; SetBinding with no command unbinds,
-- and refuses in combat. M.bindingSaves counts SaveBindings. M.modifiers
-- says which of alt, ctrl and shift are held.
M.bindings, M.bindingSaves, M.modifiers = {}, 0, {}
_G.GetBindingKey = function(command)
    local keys = {}
    for key, bound in pairs(M.bindings) do
        if bound == command then keys[#keys + 1] = key end
    end
    table.sort(keys)
    return unpack(keys)
end
_G.GetBindingAction = function(key) return M.bindings[key] or "" end
_G.SetBinding = function(key, command)
    if M.inCombat then return false end
    M.bindings[key] = command
    return true
end
_G.SaveBindings = function(set) M.bindingSaves, M.bindingSet = M.bindingSaves + 1, set end
_G.GetCurrentBindingSet = function() return 2 end
_G.GetBindingText = function(key) return key end
_G.IsAltKeyDown = function() return M.modifiers.alt == true end
_G.IsControlKeyDown = function() return M.modifiers.ctrl == true end
_G.IsShiftKeyDown = function() return M.modifiers.shift == true end

-- The mouse on the screen, in the client's pixels (GetCursorPosition):
-- what a test says, M.pointer = { x, y }; scaled by a frame's
-- GetEffectiveScale (its `effectiveScale`, else 1).
M.pointer = { 0, 0 }
_G.GetCursorPosition = function() return M.pointer[1], M.pointer[2] end

-- The pad (UI/Pad/): Forever's Gamepad UI (M.pad.ui), gamepad input on
-- (M.pad.enabled), the pads plugged in (M.pad.devices, their ids), the
-- one in use's label style (M.pad.style), whether the player used it last
-- (M.pad.using), and the keys held down (M.keysDown, by binding key).
M.pad = { ui = false, enabled = false, devices = {}, style = "Letters", using = false,
    sticks = {}, axes = {}, buttons = {} }
M.keysDown = {}
-- (No gamepad API on 3.3.5 at all: InputUtil and C_GamePad are
-- Core/Compat/Extras.lua's empty stand-ins, and the pad is never on. Tests
-- that exercise the pad's UI install tests/pad_api.lua's stand-in for the
-- duration of the file, deliberately apart from the client-shaped mock.)
_G.IsUsingGamepad = function() return M.pad.using end
_G.IsKeyDown = function(key) return M.keysDown[key] == true end

-- A pad button pressed (down true) or let go on a frame, as the client
-- delivers it: only to a frame taking pad buttons. Returns whether nothing
-- was done with it (M.PadUnused), true for a frame not taking them; a
-- handler that passes it on errors.
function M.PadPress(frame, key, down)
    if not frame:IsGamePadButtonEnabled() then return true end
    local fn = frame.scripts[down and "OnGamePadButtonDown" or "OnGamePadButtonUp"]
    if not fn then return true end
    return M.PadUnused(frame, fn(frame, key))
end

-- A frame taking the pad never passes a press on (UI/Pad/Catcher.lua's
-- header: the game's binding would run tainted by the addon), so what the
-- PadPress and PadStick helpers give back is whether nothing was done with
-- it: the frame's `acted` false (true where the frame doesn't say).
function M.PadUnused(frame, propagate)
    if propagate == true then
        error("a pad press passed on from an addon's handler: the game's binding runs tainted", 3)
    end
    if frame.acted == nil then return false end
    return not frame.acted
end

-- A pad's stick moved on a frame (stick its config name, "Right",
-- "Camera", "Left", "Movement"; x, y in -1..1), as the client delivers it:
-- only to a frame taking sticks. Returns whether nothing was done with it
-- (M.PadUnused), true for a frame not taking them. The client
-- says when a stick changes, not every frame: a test runs the frames
-- itself (the catcher's ticker's OnUpdate).
function M.PadStick(frame, stick, x, y)
    if not frame:IsGamePadStickEnabled() then return true end
    local fn = frame.scripts.OnGamePadStick
    if not fn then return true end
    return M.PadUnused(frame, fn(frame, stick, x, y, math.sqrt(x * x + y * y)))
end

-- Macros, for the book Settings puts on an action bar: M.macros holds the
-- account's, in order, as { name, icon, body }; the index is the position,
-- as the client numbers account macros from 1. M.maxMacros is how many fit
-- (the client's 120 unless a test says otherwise); CreateMacro past it,
-- or in combat, errors as the client does. M.cursor is what PickupMacro
-- put on the cursor, { "macro", index }, until ClearCursor.
M.macros, M.maxMacros, M.cursor = {}, 120, nil
_G.GetMacroIndexByName = function(name)
    for i, macro in ipairs(M.macros) do
        if macro.name == name then return i end
    end
    return 0
end
_G.GetNumMacros = function() return #M.macros, 0 end
_G.CreateMacro = function(name, icon, body, perCharacter)
    assert(not perCharacter, "the mock models account macros only")
    if M.inCombat then error("Cannot create macros in combat") end
    if #M.macros >= M.maxMacros then error("Too many macros") end
    M.macros[#M.macros + 1] = { name = name, icon = icon, body = body }
    return #M.macros
end
_G.PickupMacro = function(index)
    if M.macros[index] then M.cursor = { "macro", index } end
end
_G.GetCursorInfo = function()
    if M.cursor then return unpack(M.cursor) end
end
_G.ClearCursor = function() M.cursor = nil end

-- REU-4: a tooltip for a unit. TooltipDataProcessor is Core/Compat/'s and
-- rides GameTooltip's OnTooltipSetUnit; its callbacks read data.guid, so the
-- mock's tooltip has to answer GetUnit and hold a unit token. M.UnitTooltip
-- sets one up for the guid and returns the lines added meanwhile.
M.tooltipUnit = nil
function M.UnitTooltip(guid)
    local token = "tooltipunit"
    for name, def in pairs(M.units) do
        if def.guid == guid then token = name break end
    end
    -- A token the test set up is left alone: only the tooltip's own
    -- temporary token is cleared afterwards (deleting a nameplate token
    -- here made later NAME_PLATE_UNIT_ADDED events read no unit at all).
    local made = false
    if not M.units[token] or M.units[token].guid ~= guid then
        M.SetUnit(token, { guid = guid, name = { "Tooltip", "Unit" }, isPlayer = true,
            class = "WARRIOR", race = "Human", sex = 2, level = 10,
            faction = "Alliance" })
        made = true
    end
    GameTooltip:SetOwner(nil, "ANCHOR_NONE")
    GameTooltip.unit = token
    GameTooltip:RunScript("OnTooltipSetUnit")
    local lines = {}
    for _, line in ipairs(GameTooltip.lines or {}) do lines[#lines + 1] = line[1] end
    if made then M.units[token] = nil end
    return lines
end

-- What it was last told: `text`, `link` (SetHyperlink) and the `lines`
-- added since SetOwner, each { text, r, g, b, wrap }. It runs its own
-- OnTooltipSetUnit scripts, which is how Core/Compat/'s
-- TooltipDataProcessor hears about a unit (it hooks this tooltip):
-- GetUnit is what the hook reads, so setting .unit is setting the unit.
_G.GameTooltip = {
    hooks = {},
    SetOwner = function(self) self.lines, self.link, self.unit = {}, nil, nil end,
    SetUnit = function(self, unit) self.unit = unit end,
    -- As 3.3.5: the tooltip remembers the unit's type and token, so
    -- GetUnit returns two values (`local _, unit = self:GetUnit()`).
    GetUnit = function(self) return "player", self.unit end,
    SetText = function(self, text) self.text = text end,
    SetHyperlink = function(self, link) self.link = link end,
    AddLine = function(self, text, r, g, b, wrap)
        self.lines = self.lines or {}
        self.lines[#self.lines + 1] = { text, r, g, b, wrap }
    end,
    HookScript = function(self, event, fn)
        self.hooks = self.hooks or {}
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end,
    RunScript = function(self, event, ...)
        for _, fn in ipairs((self.hooks or {})[event] or {}) do fn(self, ...) end
    end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}

-- Returns the buttons the addon added to that menu.
function M.OpenMenu(tag, contextData)
    local buttons = {}
    local root = {
        CreateDivider = function() end,
        CreateButton = function(_, text, callback)
            buttons[#buttons + 1] = { text = text, Click = callback }
            return {}
        end,
    }

    for _, callback in ipairs(M.menus[tag] or {}) do
        callback(nil, root, contextData)
    end

    return buttons
end

--------------------------------------------------------------------------

function M.fire(event, ...)
    for i = 1, #M.frames do
        local frame = M.frames[i]
        if frame.events[event] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, ...)
        end
    end
end

-- Loads the addon exactly as the TOC does: one shared namespace, in order.
-- The TOC's SavedVariables are noted, so Reset can take them away again.
function M.LoadAddon(root, toc)
    local ns = {}
    for line in io.lines(toc or (root .. "/social_diary.toc")) do
        local saved = line:match("^##%s*SavedVariables[%w]*:%s*(.-)%s*$")
        for name in (saved or ""):gmatch("[%w_]+") do
            M.savedVariables[#M.savedVariables + 1] = name
        end

        -- The 3.3.5 client resolves the TOC's backslash paths and nothing
        -- else, so the TOC spells them that way; the suite works in "/".
        local file = line:match("^([%w_]+[\\/][%w_\\/]+%.lua)%s*$")
        file = file and file:gsub("\\", "/")
        if file then
            -- loadfile's own message names the line of a syntax error; a
            -- generic "cannot load" would hide it.
            local chunk, err = loadfile(root .. "/" .. file)
            assert(chunk, err)
            chunk("social_diary", ns)
        end
    end
    return ns
end

M.savedVariables = {}

--------------------------------------------------------------------------
-- A fresh client
--------------------------------------------------------------------------
--
-- Each test file loads its own copy of the addon. Without a reset the old
-- copy would still be listening: its frames stay in M.frames, so M.fire
-- would run both copies' handlers, and its timers, menus and tooltip hooks
-- would fire alongside the new ones. Reset puts every plain field above
-- back to its value at load and empties what the client keeps between
-- addons: frames, named globals, saved variables, slash commands, popups.

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

-- Frames hold widgets, and `registered` follows them; both start empty.
local initial = {}
for key, value in pairs(M) do
    if type(value) ~= "function" and key ~= "frames" and key ~= "registered" then
        initial[key] = Copy(value)
    end
end

-- What the client (this mock) offers before any addon loads. Core/Compat/'s
-- shims are globals too, and their first install is a closure over the first
-- test file's state -- its own map cache, its own timer table. Later files
-- reload the addon, every "X = X or ..." guard skips, and that stale first
-- copy keeps answering. So Reset takes back everything the addon put in _G.
local clientGlobals = {}
for key, value in pairs(_G) do clientGlobals[key] = value end
local clientCMap = {}
if type(_G.C_Map) == "table" then
    for key, value in pairs(_G.C_Map) do clientCMap[key] = value end
end

function M.Reset()
    for i = 1, #named do _G[named[i]] = nil end
    wipe(named)

    -- The previous file's Compat shims (and any global it left) go before
    -- this file's load installs its own.
    for key in pairs(_G) do
        if clientGlobals[key] == nil then _G[key] = nil end
    end
    -- And the ones it changed in place: a file that stubs a client function
    -- (hooksecurefunc, a repaired GetLocale) would otherwise leave the stub
    -- wrapping once more on every later load.
    for key, value in pairs(clientGlobals) do
        if rawget(_G, key) ~= value then _G[key] = value end
    end
    if type(_G.C_Map) == "table" then
        for key in pairs(_G.C_Map) do
            if clientCMap[key] == nil then _G.C_Map[key] = nil end
        end
    end
    for i = 1, #M.savedVariables do _G[M.savedVariables[i]] = nil end

    -- 3.3.5 restores SavedVariables BEFORE the addon loads (which is why retail
    -- needed "## LoadSavedVariablesFirst" and 3.3.5 has no such directive), and
    -- Core/DB.lua keeps a table it finds instead of overwriting it. Seeding the
    -- saved language here is therefore exactly what a player who once picked
    -- English has in their file, and it keeps this suite's baseline English
    -- while Locale.default is Chinese on this client (a build below 4.0). A
    -- test that wants the unset case clears the table itself.
    _G.SocialDiaryDB = { settings = { language = "enUS" } }

    for key, value in pairs(M) do
        if type(value) ~= "function" then M[key] = nil end
    end
    for key, value in pairs(initial) do M[key] = Copy(value) end
    M.frames, M.registered, M.sounds = {}, {}, {}
    M.reportedArea = nil

    _G.UIParent = NewWidget("Frame", "UIParent")
    _G.Minimap = NewMinimap()
    _G.GetMinimapShape = nil
    _G.EventRegistry = NewEventRegistry()
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.StaticPopupDialogs = {}
    _G.ChatTypeInfo = nil
    GameTooltip.text, GameTooltip.shown, GameTooltip.link, GameTooltip.lines = nil, nil, nil, nil
end

return M
