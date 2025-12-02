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
function HandleEvent(_, event, _)
	if event == "BAG_UPDATE_DELAYED" then
		Split()
	end
	if event == "GUILDBANK_ITEM_LOCK_CHANGED" then
		C_Timer.After(0.5, GuildItemCheck)
	end
end

local activeItemLocation = nil
local activeGuildItem = nil
local Events = nil

function QuickSplit(_, itemLocation)
	if itemLocation and IsAltKeyDown() and
	   C_Item.DoesItemExist(itemLocation) and C_Item.GetStackCount(itemLocation) > 1 then
		print("Splitting stack of", C_Item.GetItemLink(itemLocation))
		activeItemLocation = itemLocation
		Split()
	end
end

function Split()
    local itemLocation = activeItemLocation
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        local container, slot = itemLocation:GetBagAndSlot()
        local freeslots = C_Container.GetContainerNumFreeSlots(container)
        if C_Item.GetStackCount(itemLocation) > 1 and freeslots > 0 then
            --print("Using up to", freeslots, "available spaces")
            local target = (C_Container.GetContainerFreeSlots(container))[1]
            C_Container.SplitContainerItem(container, slot, 1)
            C_Container.PickupContainerItem(container, target)
        else
            print("All done")
            activeItemLocation = nil
        end
    end
end

function GuildQuickSplit(tab, slot)
	local type = GetCursorInfo()
	if IsAltKeyDown() and type == "item" and not activeGuildItem then
		print("Splitting stack of", GetGuildBankItemLink(tab, slot))
		--print("dropping item")
		PickupGuildBankItem(tab, slot)
                activeGuildItem = { tab, slot }
	end
end

function GuildItemCheck()
    local type = GetCursorInfo()
    if not type then
        --print("nothing on cursor")
        GuildItemPickup()
    else
        --print(type, "on cursor")
        GuildItemDrop()
    end
end

function GuildItemPickup()
    if not activeGuildItem then return end
    local tab = activeGuildItem[1]
    local slot = activeGuildItem[2]
    local _, count = GetGuildBankItemInfo(tab, slot)
    local type = GetCursorInfo()
    if not type then
        if count > 1 then
            --print("picking up item")
            SplitGuildBankItem(tab, slot, 1)
        else
            print("all done: no more to split")
            activeGuildItem = nil
        end
    end
end

function GuildItemDrop()
    if not activeGuildItem then return end
    local tab = activeGuildItem[1]
    local slot = activeGuildItem[2]
    local type = GetCursorInfo()
    if type == "item" then
        for i = 1, 98 do
            local item = GetGuildBankItemInfo(tab, i)
	    --print('checking slot', i, ' remaining', count)
	    if not item then
                --print("placing 1 in slot", i)
                PickupGuildBankItem(tab, i)
                return
            end
        end
        PickupGuildBankItem(tab, slot)
        print("all done: no more room")
        activeGuildItem = nil
    end
end

-- These are init steps specific to this addon
-- This should be run before Core:Init()
function Init()
	Events = CreateFrame("Frame")
	Events:RegisterEvent("BAG_UPDATE")
	Events:RegisterEvent("BAG_UPDATE_DELAYED")
	Events:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
	Events:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
	Events:SetScript("OnEvent", HandleEvent)

	hooksecurefunc("HandleModifiedItemClick", QuickSplit)
        hooksecurefunc("PickupGuildBankItem", GuildQuickSplit)
end


Init()
