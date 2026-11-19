-- C_Item and C_Container on a 3.3.5a client.
--
-- The information is the same as retail's; the shapes differ. 3.3.5's
-- GetItemInfo already returns retail's 11 values, so C_Item.GetItemInfo is a
-- pass-through; the container API returns eight flat values where retail
-- returns one table, which is wrapped below. Core/Compat/NOTES.md records
-- what a field means when 3.3.5 has no equivalent.

local addonName, ns = ...

if not C_Item then
    local function ItemIDFrom(item)
        if type(item) == "number" then return item end
        if type(item) ~= "string" then return nil end
        return tonumber(item:match("item:(%d+)"))
    end

    C_Item = {
        -- Retail: the same 11 values 3.3.5 returns.
        GetItemInfo = function(item) return GetItemInfo(item) end,

        -- The global is the one Core/Compat/Env.lua fills in when the client
        -- does not have it.
        GetItemInfoInstant = function(item) return GetItemInfoInstant(item) end,

        -- 3.3.5 returns an icon path; retail returns a file ID. Every caller
        -- hands the result to Texture:SetTexture, which takes either.
        GetItemIconByID = function(itemID) return select(10, GetItemInfo(itemID)) end,

        GetItemQualityByID = function(itemID) return select(3, GetItemInfo(itemID)) end,

        -- Retail's detailed level includes item upgrades; 3.3.5 has no
        -- bonuses, so it is the item's own level. nil keeps the caller's
        -- "no level" branch instead of inventing 0.
        GetDetailedItemLevelInfo = function(item)
            local level = select(4, GetItemInfo(item))
            if type(level) == "number" and level > 0 then return level end
            return nil
        end,
    }

    -- Kept for symmetry: nothing in this addon reads it, but a caller that
    -- asks for an item's id from a link gets the same parse as above.
    C_Item.GetItemID = function(item) return ItemIDFrom(item) end
end

if not C_Container then
    local function ItemIDFrom(link)
        if type(link) ~= "string" then return nil end
        return tonumber(link:match("item:(%d+)"))
    end

    C_Container = {
        GetContainerNumSlots = function(bag) return GetContainerNumSlots(bag) end,

        -- Retail's table, from 3.3.5's eight returns. itemID is parsed from
        -- the link, which is the one field 3.3.5 does not hand out.
        GetContainerItemInfo = function(bag, slot)
            local icon, count, locked, quality, readable, lootable, link, isFiltered =
                GetContainerItemInfo(bag, slot)
            if not icon and not link then return nil end
            return {
                icon = icon, count = count, locked = locked, quality = quality,
                readable = readable, lootable = lootable, hyperlink = link,
                isFiltered = isFiltered, itemID = ItemIDFrom(link),
            }
        end,

        GetContainerItemLink = function(bag, slot) return GetContainerItemLink(bag, slot) end,

        GetContainerItemID = function(bag, slot)
            local link = GetContainerItemLink(bag, slot)
            return ItemIDFrom(link)
        end,

        -- Bag 0 is the backpack; the other bag slots follow the same mapping
        -- the client uses for inventory ids.
        ContainerIDToInventoryID = function(bag) return 19 + bag end,

        GetContainerNumFreeSlots = function(bag) return GetContainerNumFreeSlots(bag) end,

        PickupContainerItem = function(bag, slot) return PickupContainerItem(bag, slot) end,
    }
end
