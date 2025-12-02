--
-- QuickSplit 
--
-- Copyright 2025 SimGuy
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.
--

local _, _ = ...

-- Handle events for bags
function Addon:HandleEvent(event, target)
	if event == "BAG_UPDATE_DELAYED" then
	end
end

local activeItemLocation = nil

function Addon:Split()
    local itemLocation = activeItemLocation
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        local container, slot = itemLocation:GetBagAndSlot()
        local freeslots = C_Container.GetContainerNumFreeSlots(container)
        if C_Item.GetStackCount(itemLocation) > 1 and freeslots > 0 then 
            print("Using up to", freeslots, "available spaces")
            target = (C_Container.GetContainerFreeSlots(container))[1]
            C_Container.SplitContainerItem(container, slot, 1)
            C_Container.PickupContainerItem(container, target)
        else
            print("All done")
            activeItemLocation = nil
        end
    end
end

-- These are init steps specific to this addon
-- This should be run before Core:Init()
function Addon:Init()
	Addon.Events = CreateFrame("Frame")
	Addon.Events:RegisterEvent("BAG_UPDATE_DELAYED")

	hooksecurefunc("HandleModifiedItemClick", Addon.QuickSplit)
end

function Addon:QuickSplit(itemLink, itemLocation)
	if itemLocation and IsAltKeyDown() and
	   C_Item.DoesItemExist(itemLocation) and C_Item.GetStackCount(itemLocation) > 1 then
		print("Splitting stack of", C_Item.GetItemName(itemLocation))
		activeItemLocation = itemLocation
        	Addon:Split()
	end
end

Addon:Init()
