--
-- QuickSplit
--
-- Copyright 2025 - 2026 SimGuy
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.
--

local _, Shared = ...

-- From Locales/Locales.lua
local L = Shared.Locale

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
        print(L["WARNING_ITEM_CLICKED"])
        activeItemLocation = nil
        usedSlots = {}
    end
    if itemLocation and IsAltKeyDown() and C_Item.DoesItemExist(itemLocation) then
        if GetCursorInfo() then
            print(L["WARNING_DROP_HELD_ITEM"])
            return
        end
        local container = itemLocation:GetBagAndSlot()
        local freeslots = C_Container.GetContainerNumFreeSlots(container)
        local bagname   = C_Container.GetBagName(container)
        if bagname == "" then bagname = L["CONTAINER"] end
        local itemcount = C_Item.GetStackCount(itemLocation)
        local itemlink  = C_Item.GetItemLink(itemLocation)
        if itemcount <= 1 then
            print(format(L["WARNING_STACK_OF_ONE"], itemlink))
        elseif freeslots == 0 then
            print(format(L["WARNING_CONTAINER_FULL"], itemlink, bagname))
        else
            print(format(L["INFO_SPLIT_STARTED"], itemcount, itemlink, freeslots, bagname))
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
    local bagname   = C_Container.GetBagName(container) or L["CONTAINER"]
    if bagname == "" then bagname = L["CONTAINER"] end

    -- If there's more work to do, pick up one item
    if itemcount > 1 and freeslots > 0 then
        C_Container.SplitContainerItem(container, slot, 1)

    -- If there's not, end the task here
    else
        if itemcount <= 1 then
            print(L["INFO_SPLIT_SUCCESSFUL"])
        elseif freeslots == 0 then
            print(format(L["INFO_SPLIT_FILLED"], bagname))
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
            print(L["ERROR_NO_MORE_ITEMS"])
        elseif freeslots == 0 then
            print(L["ERROR_NO_MORE_SPACE"])
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
            print(format(L["INFO_SPLIT_STARTED"], count, itemlink, "", L["GUILD_BANK"]))
            activeGuildItem = { tab, slot }
        else
            print(format(L["WARNING_STACK_OF_ONE"], itemlink))
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
            print(L["INFO_SPLIT_SUCCESSFUL"])
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
        print(format(L["INFO_SPLIT_FILLED"], L["GUILD_BANK"]))
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
