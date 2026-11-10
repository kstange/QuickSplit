--
-- QuickSplit
--
-- Locales\enUS.lua -- enUS Localization File
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.
--

-- Please use CurseForge to submit localization content for another language:
-- https://www.curseforge.com/wow/addons/quicksplit/localization

-- allow enUS to fill empty strings for other locales
--local Locale = GetLocale()
--if Locale ~= "enUS" then return end

local _, Shared = ...
local L = Shared.Locale

L["INFO_SPLIT_STARTED"]       = "Splitting %d %s into %s available slots in %s"
L["INFO_SPLIT_SUCCESSFUL"]    = "Finished splitting successfully"
L["INFO_SPLIT_FILLED"]        = "Finished splitting early because %s is full"
L["WARNING_ITEM_CLICKED"]     = "Cancelling splitting because another item was clicked"
L["WARNING_DROP_HELD_ITEM"]   = "You must drop the item you are holding before splitting"
L["WARNING_STACK_OF_ONE"]     = "Unable to split %s because there is only one item in the stack"
L["WARNING_CONTAINER_FULL"]   = "Unable to split %s because %s is full"
L["ERROR_NO_MORE_ITEMS"]      = "No more items left to move (this might be a bug)"
L["ERROR_NO_MORE_SPACE"]      = "No space left for next item (this might be a bug)"

L["GUILD_BANK"] = "Guild Bank"
L["CONTAINER"]  = "the container"
