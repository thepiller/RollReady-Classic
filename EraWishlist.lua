local addonName, addonTable = ...

local EraWishlist = LibStub("AceAddon-3.0"):NewAddon(
    "EraWishlist",
    "AceConsole-3.0",
    "AceEvent-3.0"
)

addonTable[1] = EraWishlist
_G.EraWishlist = EraWishlist

--------------------------------------------------
-- Defaults / DB
--------------------------------------------------

local defaults = {
    char = {
        sets = {}, -- ["Healing Set"] = { items = { [itemID] = { note = "" } } }
        raidSession = {
            drops = {}, -- [itemID] = { { itemID, itemLink, time, source } }
        },
        options = {
            autoShowRaidWindow = true,
        },
    },
}

--------------------------------------------------
-- Utility
--------------------------------------------------

local function GetItemIDFromLink(link)
    if not link then return nil end
    local itemID = link:match("item:(%d+)")
    return itemID and tonumber(itemID) or nil
end

function EraWishlist:GetCharDB()
    return self.db.char
end

function EraWishlist:GetSetsForItem(itemID)
    local sets = {}
    local charDB = self:GetCharDB()
    if not charDB or not charDB.sets then return sets end

    for setName, setData in pairs(charDB.sets) do
        if setData.items and setData.items[itemID] then
            table.insert(sets, setName)
        end
    end

    return sets
end

function EraWishlist:IsWishlistItem(itemID)
    local charDB = self:GetCharDB()
    if not charDB or not charDB.sets then return false end

    for _, setData in pairs(charDB.sets) do
        if setData.items and setData.items[itemID] then
            return true
        end
    end
    return false
end

function EraWishlist:CreateSet(setName)
    local charDB = self:GetCharDB()
    charDB.sets[setName] = charDB.sets[setName] or { items = {} }
end

function EraWishlist:AddItemToSet(setName, itemID)
    local charDB = self:GetCharDB()
    charDB.sets[setName] = charDB.sets[setName] or { items = {} }
    charDB.sets[setName].items[itemID] = charDB.sets[setName].items[itemID] or {}
end

function EraWishlist:ResetRaidSession()
    local charDB = self:GetCharDB()
    charDB.raidSession = charDB.raidSession or {}
    charDB.raidSession.drops = {}
    self:Print("Cleared current raid drops.")
    if EraWishlistRaidWindow and EraWishlistRaidWindow:IsShown() then
        EraWishlistRaidWindow:ShowWithData()
    end
end

--------------------------------------------------
-- Tooltip hook
--------------------------------------------------

local function AnnotateTooltip(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end

    local itemID = GetItemIDFromLink(link)
    if not itemID then return end

    local sets = EraWishlist:GetSetsForItem(itemID)
    if #sets == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ff00Wishlist:|r " .. table.concat(sets, ", "))
    tooltip:Show()
end

function EraWishlist:HookTooltips()
    if self.tooltipsHooked then return end
    self.tooltipsHooked = true

    GameTooltip:HookScript("OnTooltipSetItem", AnnotateTooltip)
    ItemRefTooltip:HookScript("OnTooltipSetItem", AnnotateTooltip)
end

--------------------------------------------------
-- Raid-drop tracking
--------------------------------------------------

function EraWishlist:RecordWishlistDrop(itemID, itemLink, sourceInfo)
    if not self:IsWishlistItem(itemID) then return end

    local charDB = self:GetCharDB()
    charDB.raidSession = charDB.raidSession or { drops = {} }
    charDB.raidSession.drops = charDB.raidSession.drops or {}

    local entry = {
        itemID   = itemID,
        itemLink = itemLink,
        time     = time(),
        source   = sourceInfo,
    }

    charDB.raidSession.drops[itemID] = charDB.raidSession.drops[itemID] or {}
    table.insert(charDB.raidSession.drops[itemID], entry)

    if charDB.options.autoShowRaidWindow and EraWishlistRaidWindow then
        EraWishlistRaidWindow:ShowWithData()
    end
end

function EraWishlist:ENCOUNTER_LOOT_RECEIVED(event, encounterID, itemID, itemLink, quantity, playerName, classFile)
    local src = ("Boss loot (encounter %d) -> %s"):format(encounterID or 0, playerName or "?")
    self:RecordWishlistDrop(itemID, itemLink, src)
end

function EraWishlist:CHAT_MSG_LOOT(event, msg)
    -- Simple En locale parsing; good enough for first test
    local itemLink = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not itemLink then return end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    self:RecordWishlistDrop(itemID, itemLink, "Loot chat")
end

--------------------------------------------------
-- Slash commands
--------------------------------------------------

-- /erawish  or  /ewl
function EraWishlist:SlashHandler(input)
    input = input or ""
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "add" then
        self:SlashAdd(rest)

    elseif cmd == "clear" then
        self:ResetRaidSession()

    elseif cmd == "help" or cmd == "" then
        self:Print("Commands:")
        self:Print("/erawish add <Set Name>  - Add hovered item to a set")
        self:Print("/erawish clear          - Clear this raid's wishlist drops")
        self:Print("/erawish show           - Toggle raid drops window")
        self:Print("You can also use /ewadd <Set Name> as a shortcut.")
        if EraWishlistRaidWindow then
            if EraWishlistRaidWindow:IsShown() then
                EraWishlistRaidWindow:Hide()
            else
                EraWishlistRaidWindow:ShowWithData()
            end
        end

    elseif cmd == "show" then
        if EraWishlistRaidWindow then
            if EraWishlistRaidWindow:IsShown() then
                EraWishlistRaidWindow:Hide()
            else
                EraWishlistRaidWindow:ShowWithData()
            end
        end
    else
        self:Print("Unknown command. Try /erawish help")
    end
end

-- /ewadd Healing Set
function EraWishlist:SlashAdd(rest)
    local setName = rest and rest:match("^%s*(.-)%s*$")
    if not setName or setName == "" then
        self:Print("Usage: /ewadd Set Name  (while hovering an item)")
        return
    end

    local _, link = GameTooltip:GetItem()
    if not link then
        self:Print("Hover the item in its tooltip first, then use /ewadd.")
        return
    end

    local itemID = GetItemIDFromLink(link)
    if not itemID then
        self:Print("Could not read itemID from tooltip.")
        return
    end

    self:CreateSet(setName)
    self:AddItemToSet(setName, itemID)
    self:Print(("Added %s to set '%s'."):format(link, setName))
end

--------------------------------------------------
-- AceConfig options
--------------------------------------------------

function EraWishlist:SetupOptions()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    local options = {
        type = "group",
        name = "EraWishlist",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    autoShowRaidWindow = {
                        type = "toggle",
                        name = "Auto-show raid drops window",
                        desc = "Show the wishlist drops window when a wishlist item drops.",
                        get = function()
                            return self.db.char.options.autoShowRaidWindow
                        end,
                        set = function(_, val)
                            self.db.char.options.autoShowRaidWindow = val
                        end,
                        width = "full",
                        order = 1,
                    },
                    resetRaid = {
                        type = "execute",
                        name = "Clear current raid drops",
                        desc = "Clears all wishlist drops stored for this raid.",
                        func = function() self:ResetRaidSession() end,
                        order = 2,
                    },
                    info = {
                        type = "description",
                        name = [[
Usage:
- /ewadd <Set Name> while hovering an item to add it to a wishlist set.
- /erawish show to toggle the raid drops window.
- Tooltip will show which sets an item is in.]],
                        order = 99,
                    },
                },
            },
        },
    }

    AceConfig:RegisterOptionsTable("EraWishlist", options)
    AceConfigDialog:AddToBlizOptions("EraWishlist", "EraWishlist")
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------

function EraWishlist:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("EraWishlistDB", defaults, true)

    self:SetupOptions()
    self:HookTooltips()

    self:RegisterChatCommand("erawish", "SlashHandler")
    self:RegisterChatCommand("ewl", "SlashHandler")
    self:RegisterChatCommand("ewadd", "SlashAdd")
end

function EraWishlist:OnEnable()
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
end

function EraWishlist:OnDisable()
    -- nothing special for now
end
