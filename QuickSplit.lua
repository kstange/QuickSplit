--
-- QuickSplit
--
-- Copyright 2025 - 2026 SimGuy
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.
--

local _, _ = ...

local QuickSplit = {}
local activeItemLocation = nil
local activeGuildItem = nil
local usedSlots = {}
local Events = nil

-- Handle events for splitting stacks
function QuickSplit:HandleEvent(event, _, value2, value3)
    -- CURSOR_CHANGED can indicate that we picked up an item
    if event == "CURSOR_CHANGED" then
        local newCursor = value2
        local oldCursor = value3
        if newCursor == Enum.UICursorType.Item and oldCursor == Enum.UICursorType.Default then
            QuickSplit:DropItem()
        end
    end

    -- BAG_UPDATE_DELAYED can indicate that we placed an item
    if event == "BAG_UPDATE_DELAYED" then
        QuickSplit:PickUpItem()
    end

    -- GUILDBANK_ITEM_LOCK_CHANGED indicates that the items in the guild bank were updated
    if event == "GUILDBANK_ITEM_LOCK_CHANGED" then
        C_Timer.After(0.5, QuickSplit.GuildItemCheck)
    end
end

-- This hook is needed for Classic because the HandleModifiedItemClick() doesn't have the
-- ItemLocation parameter, so we need to calculate the location manually.
function QuickSplit:QuickSplitClassic()
    if self and self:GetParent() then
        local itemLocation = ItemLocation:CreateFromBagAndSlot(self:GetParent():GetID(), self:GetID())
        QuickSplit.QuickSplit(nil, itemLocation)
    end
end

-- Start splitting items in a regular container such as player bags or bank
function QuickSplit:QuickSplit(itemLocation)
    if activeItemLocation then
        print("Cancelling splitting because another item was clicked")
        activeItemLocation = nil
        usedSlots = {}
    end
    if itemLocation and IsAltKeyDown() and C_Item.DoesItemExist(itemLocation) then
        if GetCursorInfo() then
            print("You must drop the item you are holding before splitting")
            return
        end
        local container = itemLocation:GetBagAndSlot()
        local freeslots = C_Container.GetContainerNumFreeSlots(container)
        local bagname   = C_Container.GetBagName(container)
        local itemcount = C_Item.GetStackCount(itemLocation)
        local itemlink  = C_Item.GetItemLink(itemLocation)
        if itemcount <= 1 then
            print("Unable to split", itemlink, "because there is only one item in the stack")
        elseif freeslots == 0 then
            print("Unable to split", itemlink, "because", bagname, "is full")
        else
            print("Splitting", itemcount, itemlink, "into", freeslots, "available slots in", bagname)
            activeItemLocation = itemLocation
            QuickSplit:PickUpItem()
        end
    end
end

-- Pick up one of the item in the stack
function QuickSplit:PickUpItem()
    -- Don't try to pick up an item if there's one already on the cursor
    if GetCursorInfo() then
        return
    end

    -- If there's no longer an item at the requested location, cancel the task
    local itemLocation = activeItemLocation
    if not itemLocation or not C_Item.DoesItemExist(itemLocation) then
        activeItemLocation = nil
        usedSlots = {}
        return
    end

    local container, slot = itemLocation:GetBagAndSlot()
    local itemcount = C_Item.GetStackCount(itemLocation)
    local freeslots = C_Container.GetContainerNumFreeSlots(container)
    local bagname   = C_Container.GetBagName(container)

    -- If there's more work to do, pick up one item
    if itemcount > 1 and freeslots > 0 then
        C_Container.SplitContainerItem(container, slot, 1)

    -- If there's not, end the task here
    else
        if itemcount <= 1 then
            print("Finished splitting successfully")
        elseif freeslots == 0 then
            print("Finished splitting early because", bagname, "is full")
        end
        activeItemLocation = nil
        usedSlots = {}
    end
end

-- Drop the held item in then next available bag slot
function QuickSplit:DropItem()
    -- Don't try to drop an item if there's nothing on the cursor
    if not GetCursorInfo() then
        return
    end

    -- If there's no longer an item at the requested location, cancel the task
    local itemLocation = activeItemLocation
    if not itemLocation or not C_Item.DoesItemExist(itemLocation) then
        activeItemLocation = nil
        usedSlots = {}
        return
    end

    local container, slot = itemLocation:GetBagAndSlot()
    local freeslots = C_Container.GetContainerNumFreeSlots(container)
    local itemcount = C_Item.GetStackCount(itemLocation)

    -- If there's more work to do, drop the item on the cursor
    if itemcount > 1 and freeslots > 0 then
        local target = C_Container.GetContainerFreeSlots(container)[1]

        -- This works around an issue where sometimes the inventory
        -- state hasn't updated when we receive a BAG_UPDATE_DELAYED
        -- trigger, so put the item back where it came from and try again
        if usedSlots[target] then
            C_Container.PickupContainerItem(container, slot)
        end

        -- Put the item down in the first empty slot and log which slot it was
        C_Container.PickupContainerItem(container, target)
        usedSlots[target] = true

    -- If there's no work to do, something went wrong, print an error and put
    -- the item back where it came from and stop the task
    else
        if itemcount <= 1 then
            print("No more items left to move (this might be a bug)")
        elseif freeslots == 0 then
            print("No space left for next item (this might be a bug)")
        end
        C_Container.PickupContainerItem(container, slot)
        activeItemLocation = nil
        usedSlots = {}
    end
end

-- Start splitting items in the guild bank, but due to the way the guild bank
-- works, the first click will pick up the stack, so drop it first
function QuickSplit:GuildQuickSplit(slot)
    local tab = self
    local type = GetCursorInfo()
    if IsAltKeyDown() and type == "item" and not activeGuildItem then
        local _, count = GetGuildBankItemInfo(tab, slot)
        local itemlink = GetGuildBankItemLink(tab, slot)
        PickupGuildBankItem(tab, slot)
        if (count > 1) then
            print("Splitting", count, itemlink, "into available slots of Guild Bank")
            activeGuildItem = { tab, slot }
        else
            print("Unable to split", itemlink, "because there is only one item in the stack")
        end
    end
end

-- Each time the lock state is changed, generally when an item is picked up or
-- put down in the bank, see if we're holding something and then react accordingly
function QuickSplit:GuildItemCheck()
    local type = GetCursorInfo()
    if not type then
        QuickSplit:GuildItemPickup()
    else
        QuickSplit:GuildItemDrop()
    end
end

-- Pick up a guild item and put it on the cursor unless we have no more items to pick up
function QuickSplit:GuildItemPickup()
    if not activeGuildItem then return end
    local tab = activeGuildItem[1]
    local slot = activeGuildItem[2]
    local _, count = GetGuildBankItemInfo(tab, slot)
    local type = GetCursorInfo()
    if not type then
        if count > 1 then
            SplitGuildBankItem(tab, slot, 1)
        else
            print("Finished splitting successfully")
            activeGuildItem = nil
        end
    end
end

-- Put down the item we have on the cursor in a new slot, unless there's nowhere to put
-- it, in which case put it back where we found it
function QuickSplit:GuildItemDrop()
    if not activeGuildItem then return end
    local tab = activeGuildItem[1]
    local slot = activeGuildItem[2]
    local type = GetCursorInfo()
    if type == "item" then
        for i = 1, 98 do
            local item = GetGuildBankItemInfo(tab, i)
        if not item then
                PickupGuildBankItem(tab, i)
                return
            end
        end
        PickupGuildBankItem(tab, slot)
        print("Finished splitting early because Guild Bank is full")
        activeGuildItem = nil
    end
end

-- These are init steps specific to this addon
function QuickSplit:Init()
    Events = CreateFrame("Frame")
    Events:RegisterEvent("CURSOR_CHANGED")
    Events:RegisterEvent("BAG_UPDATE_DELAYED")
    Events:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
    Events:SetScript("OnEvent", QuickSplit.HandleEvent)

    hooksecurefunc("HandleModifiedItemClick", QuickSplit.QuickSplit)
    hooksecurefunc("PickupGuildBankItem", QuickSplit.GuildQuickSplit)
    if ContainerFrameItemButton_OnModifiedClick then
        hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", QuickSplit.QuickSplitClassic)
        if BankFrameItemButtonGeneric_OnModifiedClick then
	        hooksecurefunc("BankFrameItemButtonGeneric_OnModifiedClick", QuickSplit.QuickSplitClassic)
        end
    end
end

QuickSplit:Init()
