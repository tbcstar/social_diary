-- A sheet on a client whose textures cannot have their corners moved
-- (the 3.3.5 client, PORT.md §5): the paper is drawn as if laid flat -- one
-- piece, one tone, no creases, no grime -- because the mesh only says how paper that
-- CAN bend is lit. Drawn otherwise, each facet is a plain rectangle of its
-- own tone, and the page wears a mosaic of them (the tour's sheet, 19 Nov).

local T = ...
local mock = T.mock
local Section, Check, Eq = T.Section, T.Check, T.Eq
local ns = T.Boot()

-- What the sheet drew: how many tones its paper facets were painted, how
-- many creases, how many wear pieces and how many grain crops it laid on,
-- and its ink edges (`edges`) with the biggest of them.
local function Paper(view)
    local tones, creases, worn, grain = {}, 0, 0, 0
    local tiles, wide, tall = 0, 0, 0
    local edges, bigEdge = 0, 0
    for _, region in ipairs(mock.frames) do
        local rec = region.parent == view.sheet and region.shown and region.recorded
        if rec then
            local colour = rec.calls.SetColorTexture
            if colour and rec.layer == "BACKGROUND" and rec.sublevel == -5 then
                tones[colour[1]] = true
                tiles = tiles + 1
                wide, tall = math.max(wide, rec.width or 0), math.max(tall, rec.height or 0)
            end
            if colour and rec.layer == "BACKGROUND" and rec.sublevel == -6 then
                edges = edges + 1
                bigEdge = math.max(bigEdge, math.min(rec.width or 0, rec.height or 0))
            end
            if rec.layer == "ARTWORK" and rec.sublevel == 4 then creases = creases + 1 end
            local texture = rec.calls.SetTexture
            if texture and texture[1] == ns.Style.Art("grime") then worn = worn + 1 end
            if texture and texture[1] == ns.Style.Art("grain") then grain = grain + 1 end
            if rec.layer == "ARTWORK" and rec.sublevel == 5 then worn = worn + 1 end
        end
    end
    local n = 0
    for _ in pairs(tones) do n = n + 1 end
    return n, creases, worn, grain, tiles, wide, tall, edges, bigEdge
end

Section("a sheet the client cannot bend")

local view, K = ns.UI.LooseSheet(UIParent, 900, 620)
K.Fall("a client without corners", 0)
K.Lay()
Check(view.bends, "the mock's sheet does not bend")
local bentTones, bentCreases, bentWorn, bentGrain = Paper(view)
Check(bentTones > 1, "a crumpled sheet's facets are lit alike: " .. bentTones)
Check(bentCreases > 0 and bentWorn > 0, "a crumpled sheet has no creases or grime on it")
Check(bentGrain > 1, "a crumpled sheet does not grain each facet: " .. bentGrain)

-- The same sheet where corners cannot move: it is drawn flat, not bent.
view.canBend = false
K.Lay()
Check(not view.bends, "a sheet was bent on a client that cannot move a corner")
local tones, creases, worn, grain, tiles, wide, tall, edges, bigEdge = Paper(view)
Eq(tones, 1, "unbent, the sheet's facets are lit differently: a mosaic of tones over the page")
Eq(creases, 0, "unbent, the sheet still draws its creases")
Eq(worn, 0, "unbent, the sheet still draws its wear and grime")
Eq(grain, 1, "unbent, the sheet's grain is cropped a facet at a time: a grid of seams over the page")
Eq(tiles, 1, "unbent, the paper is still tiled a facet at a time: a hairline seam at every facet edge")
Check(wide >= 890 and tall >= 610, "the flat sheet's paper does not cover the sheet: " .. wide .. "x" .. tall)
-- The ink edge is a pixel out on each side, drawn over the paper. One box
-- its size, set behind it, is drawn on top by this client whatever its
-- sublevel, and INK at the page's edge alpha washes the whole sheet.
Eq(edges, 4, "unbent, the sheet's ink edge is not four sides")
Eq(bigEdge, 1, "unbent, the sheet's ink edge is a box over the paper: " .. bigEdge .. "px thick")

-- And back, when the corners can move again.
view.canBend = true
K.Lay()
Check(view.bends, "the sheet does not bend when its corners can move again")
local againTones, againCreases, againWorn, againGrain = Paper(view)
Check(againTones > 1 and againCreases > 0 and againWorn > 0 and againGrain > 1,
    "the mosaic and the creases did not come back")
