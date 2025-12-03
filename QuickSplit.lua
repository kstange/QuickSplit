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

local QuickSplit = {}
local activeItemLocation = nil
local activeGuildItem = nil
local Events = nil

-- Handle events for splitting stacks
function QuickSplit:HandleEvent(event, _)
    -- Continue splitting after each successful bag update
    if event == "BAG_UPDATE_DELAYED" then
        QuickSplit:Split()
    end

    -- Continue splitting each time the lock state changes in the guild bank
    if event == "GUILDBANK_ITEM_LOCK_CHANGED" then
        C_Timer.After(0.5, QuickSplit.GuildItemCheck)
    end
end

-- Start splitting items in a regular container such as player bags or bank
function QuickSplit:QuickSplit(itemLocation)
    if itemLocation and IsAltKeyDown() and C_Item.DoesItemExist(itemLocation) and
            C_Item.GetStackCount(itemLocation) > 1 then
        print("Splitting stack of", C_Item.GetItemLink(itemLocation))
        activeItemLocation = itemLocation
        QuickSplit:Split()
    end
end

-- Pick up one item and place it in another slot
-- If there are no more items, or no more slots, mark the task as done
function QuickSplit:Split()
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

-- Start splitting items in the guild bank, but due to the way the guild bank
-- works, the first click will pick up the stack, so drop it first
function QuickSplit:GuildQuickSplit(slot)
    local tab = self
    local type = GetCursorInfo()
    if IsAltKeyDown() and type == "item" and not activeGuildItem then
        print("Splitting stack of", GetGuildBankItemLink(tab, slot))
        --print("dropping item")
        PickupGuildBankItem(tab, slot)
        activeGuildItem = { tab, slot }
    end
end

-- Each time the lock state is changed, generally when an item is picked up or
-- put down in the bank, see if we're holding something and then react accordingly
function QuickSplit:GuildItemCheck()
    local type = GetCursorInfo()
    if not type then
        --print("nothing on cursor")
        QuickSplit:GuildItemPickup()
    else
        --print(type, "on cursor")
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
            --print("picking up item")
            SplitGuildBankItem(tab, slot, 1)
        else
            print("all done: no more to split")
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
function QuickSplit:Init()
    Events = CreateFrame("Frame")
    Events:RegisterEvent("BAG_UPDATE_DELAYED")
    Events:RegisterEvent("GUILDBANK_ITEM_LOCK_CHANGED")
    Events:SetScript("OnEvent", QuickSplit.HandleEvent)

    hooksecurefunc("HandleModifiedItemClick", QuickSplit.QuickSplit)
    hooksecurefunc("PickupGuildBankItem", QuickSplit.GuildQuickSplit)
end

QuickSplit:Init()
