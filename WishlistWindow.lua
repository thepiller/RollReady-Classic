local EraWishlist = _G.EraWishlist
if not EraWishlist then return end

StaticPopupDialogs = StaticPopupDialogs or {}

-- Note editor popup
if not StaticPopupDialogs["ERAWISHLIST_SET_NOTE"] then
    StaticPopupDialogs["ERAWISHLIST_SET_NOTE"] = {
        text = "Set note for this item:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 200,
        OnShow = function(self, data)
            local info = self.data or data
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if info and info.note then
                editBox:SetText(info.note)
                editBox:HighlightText()
            else
                editBox:SetText("")
            end
            editBox:SetFocus()
        end,
        OnAccept = function(self, data)
            local info = self.data or data
            if info and info.setName and info.itemID then
                local text = self.editBox:GetText()
                EraWishlist:SetItemNote(info.setName, info.itemID, text)
                if EraWishlistListWindow and EraWishlistListWindow.RefreshItems then
                    EraWishlistListWindow:RefreshItems()
                end
            end
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local info = parent.data
            if info and info.setName and info.itemID then
                local text = self:GetText()
                EraWishlist:SetItemNote(info.setName, info.itemID, text)
                if EraWishlistListWindow and EraWishlistListWindow.RefreshItems then
                    EraWishlistListWindow:RefreshItems()
                end
            end
            parent:Hide()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

-- Confirm deleting a whole set
StaticPopupDialogs["ERAWISHLIST_DELETE_SET"] = {
    text = "Delete this set?\nAll items and notes in it will be lost.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data or not data.setName then return end
        EraWishlist:DeleteSet(data.setName)
        if EraWishlistListWindow then
            EraWishlistListWindow.currentSet = nil
            EraWishlistListWindow:Refresh()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Confirm deleting an item from a set
StaticPopupDialogs["ERAWISHLIST_DELETE_ITEM"] = {
    text = "Remove this item from the selected set?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        if not data or not data.setName or not data.itemID then return end
        EraWishlist:RemoveItemFromSet(data.setName, data.itemID)
        if EraWishlistListWindow and EraWishlistListWindow.RefreshItems then
            EraWishlistListWindow:RefreshItems()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

--------------------------------------------------
-- Main frame
--------------------------------------------------

local DEFAULT_WIDTH  = 460
local DEFAULT_HEIGHT = 430

local frame = CreateFrame("Frame", "EraWishlistListWindow", UIParent, "BasicFrameTemplateWithInset")
EraWishlistListWindow = frame
frame:Hide()
frame:SetFrameStrata("DIALOG")

-- Blizzard inset region as container
local inset = _G[frame:GetName().."Inset"] or frame

--------------------------------------------------
-- Saved geometry
--------------------------------------------------

local charDB = EraWishlist:GetCharDB()
charDB.windows = charDB.windows or {}
charDB.windows.list = charDB.windows.list or {}
local win = charDB.windows.list

do
    local w = win.width or DEFAULT_WIDTH
    local h = win.height or DEFAULT_HEIGHT
    frame:SetSize(w, h)

    frame:ClearAllPoints()
    if win.left and win.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", win.left, win.top)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
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
    frame:SetResizeBounds(420, 260)
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
resizeButton:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -2, 2)
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
-- Title & hint
--------------------------------------------------

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
frame.title:SetText("RollReady Classic - Wishlist Manager")

local hintText = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
hintText:SetPoint("TOP", frame.TitleBg, "BOTTOM", 0, -2)
hintText:SetText("Right Click on an item to leave a note.")

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function GetSortedSetNames()
    local cdb = EraWishlist:GetCharDB()
    local sets = cdb.sets or {}
    local names = {}
    for setName in pairs(sets) do
        table.insert(names, setName)
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

local function GetItemsForSet(setName)
    local cdb = EraWishlist:GetCharDB()
    local set = cdb.sets[setName]
    if not set or not set.items then return {} end

    local items = {}
    for itemID in pairs(set.items) do
        table.insert(items, itemID)
    end
    table.sort(items)
    return items
end

--------------------------------------------------
-- Set dropdown
--------------------------------------------------

local dropdown = CreateFrame("Frame", "EraWishlistSetDropdown", inset, "UIDropDownMenuTemplate")
frame.dropdown = dropdown
dropdown:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -40)

frame.currentSet = nil

local function Dropdown_Initialize(self, level)
    local info
    local names = GetSortedSetNames()
    for _, setName in ipairs(names) do
        info = UIDropDownMenu_CreateInfo()
        info.text = setName
        info.func = function()
            frame.currentSet = setName
            UIDropDownMenu_SetSelectedName(dropdown, setName)
            frame:RefreshItems()
            frame:UpdateSetColorIndicator()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end

UIDropDownMenu_Initialize(dropdown, Dropdown_Initialize)
UIDropDownMenu_SetWidth(dropdown, 180)
UIDropDownMenu_SetText(dropdown, "Select set")

--------------------------------------------------
-- New set creation
--------------------------------------------------

local newSetLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
newSetLabel:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 16, -8)
newSetLabel:SetText("New set:")

local newSetEdit = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
frame.newSetEdit = newSetEdit
newSetEdit:SetSize(160, 20)
newSetEdit:SetPoint("LEFT", newSetLabel, "RIGHT", 5, 0)
newSetEdit:SetAutoFocus(false)

local newSetButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
newSetButton:SetSize(60, 20)
newSetButton:SetPoint("LEFT", newSetEdit, "RIGHT", 5, 0)
newSetButton:SetText("Create")

newSetButton:SetScript("OnClick", function()
    local name = newSetEdit:GetText() or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return end

    EraWishlist:CreateSet(name)
    newSetEdit:SetText("")

    UIDropDownMenu_Initialize(dropdown, Dropdown_Initialize)
    UIDropDownMenu_SetSelectedName(dropdown, name)
    frame.currentSet = name
    frame:RefreshItems()
    frame:UpdateSetColorIndicator()
end)

--------------------------------------------------
-- Delete set button (confirmation)
--------------------------------------------------

local delSetButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
delSetButton:SetSize(100, 22)
delSetButton:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -10, -40)
delSetButton:SetText("Delete set")

delSetButton:SetScript("OnClick", function()
    local setName = frame.currentSet
    if not setName then
        EraWishlist:Print("No set selected.")
        return
    end
    StaticPopup_Show("ERAWISHLIST_DELETE_SET", nil, nil, { setName = setName })
end)

--------------------------------------------------
-- Set colour button + label
--------------------------------------------------

local colorButton = CreateFrame("Button", nil, inset)
frame.colorButton = colorButton
colorButton:SetSize(18, 18)
colorButton:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -40, -64)
colorButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local swatch = colorButton:CreateTexture(nil, "ARTWORK")
swatch:SetTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
swatch:SetAllPoints()
colorButton.swatch = swatch

local border = colorButton:CreateTexture(nil, "BACKGROUND")
border:SetTexture(0, 0, 0, 1)
border:SetPoint("TOPLEFT", swatch, -2, 2)
border:SetPoint("BOTTOMRIGHT", swatch, 2, -2)
colorButton.border = border

local colorLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colorLabel:SetPoint("TOP", colorButton, "BOTTOM", 0, -2)
colorLabel:SetText("Choose Colour")

function frame:UpdateSetColorIndicator()
    if not self.colorButton then return end
    local btn = self.colorButton
    if not self.currentSet then
        btn.swatch:SetVertexColor(1, 1, 1)
        btn.swatch:SetAlpha(0.3)
        return
    end
    local r, g, b = EraWishlist:GetSetColor(self.currentSet)
    if r then
        btn.swatch:SetVertexColor(r, g, b)
        btn.swatch:SetAlpha(1)
    else
        btn.swatch:SetVertexColor(1, 1, 1)
        btn.swatch:SetAlpha(0.3)
    end
end

local colorPickerData = {
    setName = nil,
    prevR = 1, prevG = 1, prevB = 1,
}

local function OpenColorPickerForCurrentSet()
    if not frame.currentSet then return end

    local r, g, b = EraWishlist:GetSetColor(frame.currentSet)
    if not r then r, g, b = 1, 1, 1 end

    colorPickerData.setName = frame.currentSet
    colorPickerData.prevR, colorPickerData.prevG, colorPickerData.prevB = r, g, b

    ColorPickerFrame:SetScript("OnColorSelect", function(self, nr, ng, nb)
        if not colorPickerData.setName then return end
        EraWishlist:SetSetColor(colorPickerData.setName, nr, ng, nb)
        frame:UpdateSetColorIndicator()
        frame:RefreshItems()
    end)

    ColorPickerFrame.func = nil
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.previousValues = { r = r, g = g, b = b }
    ColorPickerFrame.cancelFunc = function(restore)
        if not colorPickerData.setName then return end
        EraWishlist:SetSetColor(
            colorPickerData.setName,
            colorPickerData.prevR,
            colorPickerData.prevG,
            colorPickerData.prevB
        )
        frame:UpdateSetColorIndicator()
        frame:RefreshItems()
    end

    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame:Show()
end

colorButton:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if frame.currentSet then
            EraWishlist:SetSetColor(frame.currentSet, nil, nil, nil)
            frame:UpdateSetColorIndicator()
            frame:RefreshItems()
        end
    else
        OpenColorPickerForCurrentSet()
    end
end)

colorButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Set colour", 1, 1, 1)
    GameTooltip:AddLine("Left-click to choose", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click to clear", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
colorButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

--------------------------------------------------
-- Items scroll frame
--------------------------------------------------

local itemScroll = CreateFrame("ScrollFrame", "EraWishlistItemsScrollFrame", inset, "UIPanelScrollFrameTemplate")
frame.itemScroll = itemScroll
itemScroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 20, -110)
itemScroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 40)

local itemContent = CreateFrame("Frame", nil, itemScroll)
frame.itemContent = itemContent
itemContent:SetSize(1, 1)
itemScroll:SetScrollChild(itemContent)

frame.itemRows = {}
local ITEM_ROW_HEIGHT = 32
local MAX_ITEM_ROWS = 14

local function UpdateRowWidths()
    local scrollWidth = itemScroll:GetWidth() or 0
    if scrollWidth <= 0 then return end
    -- leave room for scrollbar; 60px for the Del button
    local rowWidth = scrollWidth - 10
    local textWidth = rowWidth - 60

    for _, row in ipairs(frame.itemRows) do
        row:SetWidth(rowWidth)
        row.text:SetWidth(textWidth)
        row.noteText:SetWidth(textWidth)
    end
end

for i = 1, MAX_ITEM_ROWS do
    local row = CreateFrame("Button", nil, itemContent)
    row:SetHeight(ITEM_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i-1)*ITEM_ROW_HEIGHT)

    row.itemID = nil
    row.itemLink = nil

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.text:SetPoint("TOPLEFT", 0, -2)
    row.text:SetJustifyH("LEFT")

    row.noteText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.noteText:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
    row.noteText:SetJustifyH("LEFT")

    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeBtn = removeBtn
    removeBtn:SetSize(40, 18)
    removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, -4)
    removeBtn:SetText("Del")

    removeBtn:SetScript("OnClick", function(self)
        if frame.currentSet and row.itemID then
            StaticPopup_Show("ERAWISHLIST_DELETE_ITEM", nil, nil, {
                setName = frame.currentSet,
                itemID  = row.itemID,
            })
        end
    end)

    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if not (frame.currentSet and self.itemID) then return end
            local note = EraWishlist:GetItemNote(frame.currentSet, self.itemID)
            StaticPopup_Show("ERAWISHLIST_SET_NOTE", nil, nil, {
                setName = frame.currentSet,
                itemID  = self.itemID,
                note    = note,
            })
            return
        end

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

    frame.itemRows[i] = row
end

itemScroll:SetScript("OnSizeChanged", function()
    UpdateRowWidths()
end)

--------------------------------------------------
-- Add item box
--------------------------------------------------

local addItemLabel = inset:CreateFontString(nil, "OVERLAY", "GameFontNormal")
addItemLabel:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 20, 18)
addItemLabel:SetText("Add item:")

local addItemEdit = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
frame.addItemEdit = addItemEdit
addItemEdit:SetSize(260, 20)
addItemEdit:SetPoint("LEFT", addItemLabel, "RIGHT", 5, 0)
addItemEdit:SetAutoFocus(false)

addItemEdit:SetScript("OnMouseDown", function(self)
    self:SetFocus()
end)
addItemEdit:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
end)

local function ParseItemInput(val)
    if not val or val == "" then return nil end

    local link = val:match("|c%x+|Hitem:.-|h%[.-%]|h|r")
    if link then
        local id = link:match("item:(%d+)")
        return id and tonumber(id) or nil
    end

    local num = tonumber(val)
    if num then return num end

    return nil
end

local function AddItemFromEditBox()
    local setName = frame.currentSet
    if not setName then
        EraWishlist:Print("Select a set first.")
        return
    end

    local val = addItemEdit:GetText() or ""
    local itemID = ParseItemInput(val)
    if not itemID then
        EraWishlist:Print("Could not read item from input. Shift-click an item into the box.")
        return
    end

    EraWishlist:AddItemToSet(setName, itemID)
    addItemEdit:SetText("")
    frame:RefreshItems()
end

addItemEdit:SetScript("OnEnterPressed", function(self)
    AddItemFromEditBox()
    self:ClearFocus()
end)

local addItemButton = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
addItemButton:SetSize(60, 20)
addItemButton:SetPoint("LEFT", addItemEdit, "RIGHT", 5, 0)
addItemButton:SetText("Add")
addItemButton:SetScript("OnClick", function()
    AddItemFromEditBox()
end)

--------------------------------------------------
-- Refresh methods
--------------------------------------------------

function frame:RefreshSets()
    local names = GetSortedSetNames()
    if #names == 0 then
        self.currentSet = nil
        UIDropDownMenu_SetText(dropdown, "No sets")
    else
        if not self.currentSet or not EraWishlist:GetCharDB().sets[self.currentSet] then
            self.currentSet = names[1]
        end
        UIDropDownMenu_SetSelectedName(dropdown, self.currentSet)
        UIDropDownMenu_SetText(dropdown, self.currentSet)
    end
    self:UpdateSetColorIndicator()
end

function frame:RefreshItems()
    UpdateRowWidths()

    local setName = self.currentSet
    local items = {}
    if setName then
        items = GetItemsForSet(setName)
    end

    for i, row in ipairs(self.itemRows) do
        local itemID = items[i]
        if itemID then
            row.itemID = itemID
            local name, link = GetItemInfo(itemID)
            row.itemLink = link or ("item:" .. itemID)

            local text
            if link then
                text = link
            elseif name then
                text = ("%s (ID %d)"):format(name, itemID)
            else
                text = ("ItemID %d"):format(itemID)
            end

            row.text:SetText(text)

            local note = EraWishlist:GetItemNote(setName, itemID)
            if note and note ~= "" then
                row.noteText:SetText("|cffaaaaaaNote:|r " .. note)
            else
                row.noteText:SetText("")
            end

            row:Show()
        else
            row.itemID = nil
            row.itemLink = nil
            row.text:SetText("")
            row.noteText:SetText("")
            row:Hide()
        end
    end

    frame.itemContent:SetHeight(math.max(#items, 1) * ITEM_ROW_HEIGHT)
end

function frame:Refresh()
    self:RefreshSets()
    self:RefreshItems()
end

--------------------------------------------------
-- Shift-click support
--------------------------------------------------

hooksecurefunc("ChatEdit_InsertLink", function(link)
    if not link then return end
    if EraWishlistListWindow
       and EraWishlistListWindow:IsShown()
       and EraWishlistListWindow.addItemEdit
       and EraWishlistListWindow.addItemEdit:HasFocus() then
        EraWishlistListWindow.addItemEdit:Insert(link)
    end
end)
