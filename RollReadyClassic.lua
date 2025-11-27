local addonName, addonTable = ...

local EraWishlist = LibStub("AceAddon-3.0"):NewAddon(
    "EraWishlist",
    "AceConsole-3.0",
    "AceEvent-3.0"
)

addonTable[1] = EraWishlist
_G.EraWishlist = EraWishlist

--------------------------------------------------
-- Simple SavedVariables DB (no AceDB)
--------------------------------------------------

local function GetCharKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName()
    return name .. "-" .. realm
end

function EraWishlist:EnsureDB()
    EraWishlistDB = EraWishlistDB or {}
    EraWishlistDB.char = EraWishlistDB.char or {}

    local key = GetCharKey()
    self.charKey = key

    local charDB = EraWishlistDB.char[key]
    if not charDB then
        charDB = {
            sets = {},
            raidSession = {
                drops = {},
            },
            options = {
                autoShowRaidWindow = true,
                minimap = {
                    hide = false,
                },
            },
            windows = {
                list  = {},
                drops = {},
            },
        }
        EraWishlistDB.char[key] = charDB
    else
        charDB.sets = charDB.sets or {}
        charDB.raidSession = charDB.raidSession or {}
        charDB.raidSession.drops = charDB.raidSession.drops or {}
        charDB.options = charDB.options or {}
        if charDB.options.autoShowRaidWindow == nil then
            charDB.options.autoShowRaidWindow = true
        end
        charDB.options.minimap = charDB.options.minimap or { hide = false }

        charDB.windows = charDB.windows or {}
        charDB.windows.list  = charDB.windows.list  or {}
        charDB.windows.drops = charDB.windows.drops or {}

        -- Migration: old item entries might just be "true"
        for _, set in pairs(charDB.sets) do
            if set.items then
                for itemID, v in pairs(set.items) do
                    if v == true then
                        set.items[itemID] = {}
                    end
                end
            end
        end
    end

    self._charDB = charDB
end

function EraWishlist:GetCharDB()
    if not self._charDB then
        self:EnsureDB()
    end
    return self._charDB
end

--------------------------------------------------
-- Utility
--------------------------------------------------

local function GetItemIDFromLink(link)
    if not link then return nil end
    local itemID = link:match("item:(%d+)")
    return itemID and tonumber(itemID) or nil
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

    table.sort(sets)
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

function EraWishlist:NotifyOptionsChanged()
    local ACR = LibStub("AceConfigRegistry-3.0", true)
    if ACR then
        ACR:NotifyChange("EraWishlist")
    end
end

function EraWishlist:CreateSet(setName)
    local charDB = self:GetCharDB()
    charDB.sets[setName] = charDB.sets[setName] or { items = {} }
    self:NotifyOptionsChanged()
end

function EraWishlist:AddItemToSet(setName, itemID)
    local charDB = self:GetCharDB()
    charDB.sets[setName] = charDB.sets[setName] or { items = {} }
    local items = charDB.sets[setName].items
    if not items[itemID] then
        items[itemID] = {}   -- table so we can store note, flags, etc.
        self:NotifyOptionsChanged()
    end
end

function EraWishlist:RemoveItemFromSet(setName, itemID)
    local charDB = self:GetCharDB()
    local set = charDB.sets[setName]
    if set and set.items and set.items[itemID] then
        set.items[itemID] = nil
        self:NotifyOptionsChanged()
    end
end

function EraWishlist:DeleteSet(setName)
    local charDB = self:GetCharDB()
    if charDB.sets[setName] then
        charDB.sets[setName] = nil
        self:NotifyOptionsChanged()
    end
end

-- Per-item notes
function EraWishlist:SetItemNote(setName, itemID, note)
    if not setName or not itemID then return end

    local charDB = self:GetCharDB()
    charDB.sets = charDB.sets or {}
    local set = charDB.sets[setName]
    if not set then return end

    set.notes = set.notes or {}

    -- store / clear
    if note and note ~= "" then
        set.notes[itemID] = note
    else
        set.notes[itemID] = nil
    end
end

function EraWishlist:GetItemNote(setName, itemID)
    if not setName or not itemID then return nil end

    local charDB = self:GetCharDB()
    local sets = charDB.sets
    if not sets then return nil end

    local set = sets[setName]
    if not set or not set.notes then return nil end

    return set.notes[itemID]
end

-- For drops list: get all notes for this item across sets
function EraWishlist:GetItemNotesForItem(itemID)
    local results = {}
    if not itemID then return results end

    local charDB = self:GetCharDB()
    local sets = charDB.sets or {}

    for setName, set in pairs(sets) do
        local notesTable = set.notes
        if notesTable then
            local note = notesTable[itemID]
            if note and note ~= "" then
                table.insert(results, {
                    setName = setName,
                    note    = note,
                })
            end
        end
    end

    return results
end

-- Per-set colour
function EraWishlist:SetSetColor(setName, r, g, b)
    local charDB = self:GetCharDB()
    local set = charDB.sets[setName]
    if not set then return end

    if r and g and b then
        set.color = { r = r, g = g, b = b }
    else
        set.color = nil
    end
    self:NotifyOptionsChanged()
end

function EraWishlist:GetSetColor(setName)
    local charDB = self:GetCharDB()
    local set = charDB.sets[setName]
    if set and set.color and set.color.r and set.color.g and set.color.b then
        return set.color.r, set.color.g, set.color.b
    end
    return nil
end

local function ColorCodeSetName(setName)
    local r, g, b = EraWishlist:GetSetColor(setName)
    if not r then
        return setName
    end
    return ("|cff%02x%02x%02x%s|r"):format(
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5),
        setName
    )
end

function EraWishlist:ResetRaidSession()
    local charDB = self:GetCharDB()
    charDB.raidSession = charDB.raidSession or {}
    charDB.raidSession.drops = {}
    self:Print("Cleared current raid drops.")
    self:NotifyOptionsChanged()

    if EraWishlistRaidWindow and EraWishlistRaidWindow.Refresh then
        EraWishlistRaidWindow:Refresh()
    end
end

function EraWishlist:RemoveDropEntry(entry)
    if not entry or not entry.itemID then return end
    local charDB = self:GetCharDB()
    local rs = charDB.raidSession
    if not rs or not rs.drops then return end

    local list = rs.drops[entry.itemID]
    if not list then return end

    for i, e in ipairs(list) do
        if e == entry then
            table.remove(list, i)
            break
        end
    end

    if list and #list == 0 then
        rs.drops[entry.itemID] = nil
    end
end

function EraWishlist:RemoveItemFromAllSets(itemID)
    if not itemID then return end
    local charDB = self:GetCharDB()
    local changed = false

    for _, set in pairs(charDB.sets or {}) do
        if set.items and set.items[itemID] then
            set.items[itemID] = nil
            changed = true
        end
    end

    if changed then
        self:NotifyOptionsChanged()
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

    local parts = {}
    for _, setName in ipairs(sets) do
        table.insert(parts, ColorCodeSetName(setName))
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ff00Wishlist:|r " .. table.concat(parts, ", "))
    tooltip:Show()
end

function EraWishlist:HookTooltips()
    if self.tooltipsHooked then return end
    self.tooltipsHooked = true

    GameTooltip:HookScript("OnTooltipSetItem", AnnotateTooltip)
    ItemRefTooltip:HookScript("OnTooltipSetItem", AnnotateTooltip)
end

--------------------------------------------------
-- Raid-drop tracking (Classic: via CHAT_MSG_LOOT only)
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

    if charDB.options.autoShowRaidWindow and EraWishlistRaidWindow and EraWishlistRaidWindow.ShowWithData then
        EraWishlistRaidWindow:ShowWithData()
    end
end

function EraWishlist:CHAT_MSG_LOOT(event, msg)
    local itemLink = msg:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if not itemLink then return end

    local itemID = GetItemIDFromLink(itemLink)
    if not itemID then return end

    self:RecordWishlistDrop(itemID, itemLink, "Loot chat")
end

--------------------------------------------------
-- Raid summary printer
--------------------------------------------------

function EraWishlist:PrintRaidSummary()
    local charDB = self:GetCharDB()
    local rs = charDB.raidSession
    if not rs or not rs.drops or not next(rs.drops) then
        self:Print("No wishlist drops recorded for this raid.")
        return
    end

    local flat = {}
    for itemID, drops in pairs(rs.drops) do
        for _, entry in ipairs(drops) do
            table.insert(flat, entry)
        end
    end
    table.sort(flat, function(a, b) return a.time < b.time end)

    self:Print("Wishlist drops this raid:")
    for _, entry in ipairs(flat) do
        local sets = self:GetSetsForItem(entry.itemID)
        local colored = {}
        for _, setName in ipairs(sets) do
            table.insert(colored, ColorCodeSetName(setName))
        end
        local setsStr = (#colored > 0) and (" (" .. table.concat(colored, ", ") .. ")") or ""
        local link = entry.itemLink or ("item:" .. tostring(entry.itemID))
        self:Print(("- %s%s"):format(link, setsStr))
    end
end

--------------------------------------------------
-- Windows toggles (raid + list)
--------------------------------------------------

function EraWishlist:ToggleRaidWindow()
    if not EraWishlistRaidWindow then return end
    if EraWishlistRaidWindow:IsShown() then
        EraWishlistRaidWindow:Hide()
    else
        if EraWishlistRaidWindow.ShowWithData then
            EraWishlistRaidWindow:ShowWithData()
        else
            EraWishlistRaidWindow:Show()
        end
    end
end

function EraWishlist:ToggleListWindow()
    if not EraWishlistListWindow then
        self:Print("Wishlist window not loaded.")
        return
    end

    if EraWishlistListWindow.Refresh then
        EraWishlistListWindow:Refresh()
    end

    if EraWishlistListWindow:IsShown() then
        EraWishlistListWindow:Hide()
    else
        EraWishlistListWindow:Show()
    end
end

--------------------------------------------------
-- Slash commands
--------------------------------------------------

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
        self:Print("New: /ew list, /ew drops, /ew summary.")

    elseif cmd == "show" then
        self:ToggleRaidWindow()
    else
        self:Print("Unknown command. Try /erawish help")
    end
end

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

function EraWishlist:SlashEW(input)
    input = input or ""
    local cmd, rest = input:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()

    if cmd == "" or cmd == "list" then
        self:ToggleListWindow()

    elseif cmd == "drops" then
        self:ToggleRaidWindow()

    elseif cmd == "add" then
        self:SlashAdd(rest)

    elseif cmd == "summary" then
        self:PrintRaidSummary()

    elseif cmd == "help" then
        self:Print("RollReady Classic commands:")
        self:Print("/ew list      - Wishlist manager window")
        self:Print("/ew drops     - Raid drops window")
        self:Print("/ew add <Set> - Add hovered item to set")
        self:Print("/ew summary   - Print this raid's wishlist drops")
        self:Print("Right-click items in /ew list to add notes.")

    else
        self:Print("Unknown subcommand. Use /ew help.")
    end
end

--------------------------------------------------
-- Minimap button + simple dropdown (list / drops)
--------------------------------------------------

local minimapDropdown = CreateFrame("Frame", "EraWishlist_MinimapDropdown", UIParent, "UIDropDownMenuTemplate")
minimapDropdown.displayMode = "MENU"

local function MinimapMenu_Initialize(frame, level, menuList)
    local info

    -- Title
    info = UIDropDownMenu_CreateInfo()
    info.text = "RollReady Classic"
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Wishlist Manager
    info = UIDropDownMenu_CreateInfo()
    info.text = "Wishlist Manager"
    info.func = function() EraWishlist:ToggleListWindow() end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Drops Window
    info = UIDropDownMenu_CreateInfo()
    info.text = "Drops Window"
    info.func = function() EraWishlist:ToggleRaidWindow() end
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

function EraWishlist:ShowMinimapMenu()
    UIDropDownMenu_Initialize(minimapDropdown, MinimapMenu_Initialize, "MENU")
    ToggleDropDownMenu(1, nil, minimapDropdown, "cursor", 0, 0)
end

function EraWishlist:CreateMinimapButton()
    if EraWishlistMinimapButton then return end

    local btn = CreateFrame("Button", "EraWishlistMinimapButton", Minimap)
    EraWishlistMinimapButton = btn

    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -4, 4)

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_06")
    icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    icon:SetPoint("CENTER")
    icon:SetSize(20, 20)
    btn.icon = icon

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnClick", function(self, button)
        EraWishlist:ShowMinimapMenu()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:AddLine("RollReady Classic", 1, 1, 1)
        GameTooltip:AddLine("Click for menu", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    self:UpdateMinimapButton()
end

function EraWishlist:UpdateMinimapButton()
    if not EraWishlistMinimapButton then return end
    local cdb = self:GetCharDB()
    local hide = cdb.options.minimap and cdb.options.minimap.hide
    if hide then
        EraWishlistMinimapButton:Hide()
    else
        EraWishlistMinimapButton:Show()
    end
end

--------------------------------------------------
-- AceConfig options
--------------------------------------------------

function EraWishlist:BuildOptionsTable()
    local options = {
        type = "group",
        name = "RollReady Classic",
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
                            local cdb = self:GetCharDB()
                            return cdb.options.autoShowRaidWindow
                        end,
                        set = function(_, val)
                            local cdb = self:GetCharDB()
                            cdb.options.autoShowRaidWindow = val and true or false
                        end,
                        width = "full",
                        order = 1,
                    },
                    showMinimap = {
                        type = "toggle",
                        name = "Show minimap button",
                        desc = "Toggle the RollReady Classic minimap button.",
                        get = function()
                            local cdb = self:GetCharDB()
                            return not (cdb.options.minimap and cdb.options.minimap.hide)
                        end,
                        set = function(_, val)
                            local cdb = self:GetCharDB()
                            cdb.options.minimap = cdb.options.minimap or {}
                            cdb.options.minimap.hide = not val
                            self:UpdateMinimapButton()
                        end,
                        width = "full",
                        order = 2,
                    },
                    resetRaid = {
                        type = "execute",
                        name = "Clear current raid drops",
                        desc = "Clears all wishlist drops stored for this raid.",
                        func = function() self:ResetRaidSession() end,
                        order = 3,
                    },
                    info = {
                        type = "description",
                        name = [[
Wishlist management:

Use /ew list to open the Wishlist manager window.
Use /ew drops to open the Raid drops window.
Use /ew summary to print wishlist drops this raid.

Quick commands:
- /ew add <Set Name> while hovering an item to add it.
- Right-click items in the Wishlist manager to add notes.
- Tooltip will show which sets an item is in, using set colours if set.]],
                        order = 99,
                    },
                },
            },
        },
    }

    return options
end

function EraWishlist:SetupOptions()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")

    AceConfig:RegisterOptionsTable("EraWishlist", function() return self:BuildOptionsTable() end)
    AceConfigDialog:AddToBlizOptions("EraWishlist", "RollReady Classic")
end

--------------------------------------------------
-- Lifecycle
--------------------------------------------------

function EraWishlist:OnInitialize()
    self:EnsureDB()
    self:SetupOptions()
    self:HookTooltips()

    self:RegisterChatCommand("erawish", "SlashHandler")
    self:RegisterChatCommand("ewl", "SlashHandler")
    self:RegisterChatCommand("ewadd", "SlashAdd")
    self:RegisterChatCommand("ew", "SlashEW")

    self:CreateMinimapButton()
end

function EraWishlist:OnEnable()
    self:RegisterEvent("CHAT_MSG_LOOT")
end

function EraWishlist:OnDisable()
end
