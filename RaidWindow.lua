local EraWishlist = _G.EraWishlist
if not EraWishlist then return end

local DEFAULT_WIDTH  = 360
local DEFAULT_HEIGHT = 420

StaticPopupDialogs = StaticPopupDialogs or {}

StaticPopupDialogs["ERAWISHLIST_CLEAR_DROPS"] = {
    text = "Are you sure you want to clear the current drops list?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if EraWishlist and EraWishlist.ResetRaidSession then
            EraWishlist:ResetRaidSession()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["ERAWISHLIST_REMOVE_DROP"] = {
    text = "Remove this item from the drops list?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not (data and data.entry) then return end
        if EraWishlist and EraWishlist.RemoveDropEntry then
            EraWishlist:RemoveDropEntry(data.entry)
        end
        if EraWishlistRaidWindow and EraWishlistRaidWindow.Refresh then
            EraWishlistRaidWindow:Refresh()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs["ERAWISHLIST_REMOVE_DROP_AND_LISTS"] = {
    text = "Remove this item from the drops list and all wishlists?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not (data and data.entry) then return end
        if EraWishlist then
            if EraWishlist.RemoveDropEntry then
                EraWishlist:RemoveDropEntry(data.entry)
            end
            if EraWishlist.RemoveItemFromAllSets then
                EraWishlist:RemoveItemFromAllSets(data.entry.itemID)
            end
        end
        if EraWishlistRaidWindow and EraWishlistRaidWindow.Refresh then
            EraWishlistRaidWindow:Refresh()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Main frame
local frame = CreateFrame("Frame", "EraWishlistRaidWindowFrame", UIParent, "BasicFrameTemplateWithInset")
EraWishlistRaidWindow = frame
frame:Hide()
frame:SetFrameStrata("HIGH")

local inset = _G[frame:GetName().."Inset"] or frame

--------------------------------------------------
-- Saved geometry
--------------------------------------------------

local charDB = EraWishlist:GetCharDB()
charDB.windows = charDB.windows or {}
charDB.windows.drops = charDB.windows.drops or {}
local win = charDB.windows.drops

do
    local w = win.width or DEFAULT_WIDTH
    local h = win.height or DEFAULT_HEIGHT
    frame:SetSize(w, h)

    frame:ClearAllPoints()
    if win.left and win.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", win.left, win.top)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    end
end

local function SaveGeometry()
    win.width  = frame:GetWidth()
    win.height = frame:GetHeight()
    win.left   = frame:GetLeft()
    win.top    = frame:GetTop()
end

--------------------------------------------------
-- Movable & resizable
--------------------------------------------------

frame:SetMovable(true)
frame:SetResizable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")

if frame.SetResizeBounds then
    frame:SetResizeBounds(260, 250)
end

frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveGeometry()
end)

frame:SetScript("OnSizeChanged", function(self, w, h)
    SaveGeometry()
end)

local resizeButton = CreateFrame("Button", nil, inset)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -4, 4)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeButton:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        frame:StartSizing("BOTTOMRIGHT")
    end
end)
resizeButton:SetScript("OnMouseUp", function(self)
    frame:StopMovingOrSizing()
    SaveGeometry()
end)

--------------------------------------------------
-- Title
--------------------------------------------------

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
frame.title:SetText("RollReady Classic - Wishlist Drops")

--------------------------------------------------
-- Top buttons
--------------------------------------------------

local summaryButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
summaryButton:SetSize(90, 22)
summaryButton:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -26)
summaryButton:SetText("Summary")
summaryButton:SetScript("OnClick", function()
    if EraWishlist and EraWishlist.PrintRaidSummary then
        EraWishlist:PrintRaidSummary()
    end
end)

local clearButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
clearButton:SetSize(80, 22)
clearButton:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -26)
clearButton:SetText("Clear")
clearButton:SetScript("OnClick", function()
    StaticPopup_Show("ERAWISHLIST_CLEAR_DROPS")
end)

--------------------------------------------------
-- Scrollframe + rows
--------------------------------------------------

local scrollFrame = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -68)
scrollFrame:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 24)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

frame.content = content
frame.rows = {}

local ROW_HEIGHT = 32
local MAX_ROWS = 18

local function UpdateRowWidths()
    local scrollWidth = scrollFrame:GetWidth() or 0
    if scrollWidth <= 0 then return end

    local rowWidth  = scrollWidth - 10
    local textWidth = rowWidth - 90 -- leave room for Hide + Forget buttons

    for _, row in ipairs(frame.rows) do
        row:SetWidth(rowWidth)
        row.linkText:SetWidth(textWidth)
        row.setsText:SetWidth(textWidth)
    end
end

for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i-1)*ROW_HEIGHT)

    row.itemID   = nil
    row.itemLink = nil
    row.entry    = nil

    row.linkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.linkText:SetPoint("TOPLEFT", 0, -2)
    row.linkText:SetJustifyH("LEFT")

    row.setsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.setsText:SetPoint("TOPLEFT", row.linkText, "BOTTOMLEFT", 0, -2)
    row.setsText:SetJustifyH("LEFT")

    local removeDropBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeDropBtn = removeDropBtn
    removeDropBtn:SetSize(40, 18)
    removeDropBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -46, -2)
    removeDropBtn:SetText("Hide")
    removeDropBtn:SetScript("OnClick", function(self)
        local r = self:GetParent()
        if not r.entry then return end
        StaticPopup_Show("ERAWISHLIST_REMOVE_DROP", nil, nil, { entry = r.entry })
    end)
    removeDropBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Hide this item", 1, 1, 1)
        GameTooltip:AddLine("Removes this drop from the list only.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    removeDropBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local removeAllBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeAllBtn = removeAllBtn
    removeAllBtn:SetSize(40, 18)
    removeAllBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    removeAllBtn:SetText("Forget")
    removeAllBtn:SetScript("OnClick", function(self)
        local r = self:GetParent()
        if not r.entry then return end
        StaticPopup_Show("ERAWISHLIST_REMOVE_DROP_AND_LISTS", nil, nil, { entry = r.entry })
    end)
    removeAllBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Forget this item", 1, 0.8, 0.8)
        GameTooltip:AddLine("Removes this drop and removes the item from all wishlists.", 0.9, 0.7, 0.7)
        GameTooltip:Show()
    end)
    removeAllBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row:SetScript("OnClick", function(self)
        if self.itemLink then
            HandleModifiedItemClick(self.itemLink)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame.rows[i] = row
end

scrollFrame:SetScript("OnSizeChanged", function()
    UpdateRowWidths()
end)

--------------------------------------------------
-- Refresh / ShowWithData
--------------------------------------------------

function frame:Refresh()
    UpdateRowWidths()

    local cdb = EraWishlist:GetCharDB()
    if not cdb or not cdb.raidSession or not cdb.raidSession.drops then
        for _, row in ipairs(self.rows) do
            row.itemID   = nil
            row.itemLink = nil
            row.entry    = nil
            row.linkText:SetText("")
            row.setsText:SetText("")
            row:Hide()
        end
        self.content:SetHeight(1)
        return
    end

    local flat = {}
    for itemID, drops in pairs(cdb.raidSession.drops) do
        for _, entry in ipairs(drops) do
            table.insert(flat, entry)
        end
    end

    table.sort(flat, function(a, b) return a.time < b.time end)

    for i, row in ipairs(self.rows) do
        local entry = flat[i]
        if entry then
            row.itemID   = entry.itemID
            row.itemLink = entry.itemLink
            row.entry    = entry

            row.linkText:SetText(entry.itemLink or ("item:" .. tostring(entry.itemID)))

            local sets = EraWishlist:GetSetsForItem(entry.itemID)
            local colored = {}
            for _, setName in ipairs(sets) do
                local r, g, b = EraWishlist:GetSetColor(setName)
                if r then
                    table.insert(colored, ("|cff%02x%02x%02x%s|r"):format(
                        math.floor(r * 255 + 0.5),
                        math.floor(g * 255 + 0.5),
                        math.floor(b * 255 + 0.5),
                        setName
                    ))
                else
                    table.insert(colored, setName)
                end
            end

            local baseText = (#colored > 0) and table.concat(colored, ", ") or ""

            local notesInfo = EraWishlist:GetItemNotesForItem(entry.itemID)
            local noteText
            if #notesInfo > 0 then
                local parts = {}
                for _, n in ipairs(notesInfo) do
                    table.insert(parts, n.setName .. ": " .. n.note)
                end
                noteText = table.concat(parts, " ; ")
            end

            if noteText then
                row.setsText:SetText(baseText .. " |cffaaaaaa- Note:|r " .. noteText)
            else
                row.setsText:SetText(baseText)
            end

            row:Show()
        else
            row.itemID   = nil
            row.itemLink = nil
            row.entry    = nil
            row.linkText:SetText("")
            row.setsText:SetText("")
            row:Hide()
        end
    end

    self.content:SetHeight(math.max(#flat, 1) * ROW_HEIGHT)
end

function frame:ShowWithData()
    self:Refresh()
    self:Show()
end
