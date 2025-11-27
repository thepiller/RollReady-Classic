local EraWishlist = _G.EraWishlist
if not EraWishlist then return end

EraWishlistRaidWindow = CreateFrame("Frame", "EraWishlistRaidWindowFrame", UIParent, "BasicFrameTemplateWithInset")
EraWishlistRaidWindow:SetSize(360, 420)
EraWishlistRaidWindow:SetPoint("CENTER")
EraWishlistRaidWindow:Hide()

EraWishlistRaidWindow.title = EraWishlistRaidWindow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
EraWishlistRaidWindow.title:SetPoint("CENTER", EraWishlistRaidWindow.TitleBg, "CENTER")
EraWishlistRaidWindow.title:SetText("Wishlist Drops (This Raid)")

-- Scrollframe
local scrollFrame = CreateFrame("ScrollFrame", nil, EraWishlistRaidWindow, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

EraWishlistRaidWindow.content = content
EraWishlistRaidWindow.rows = {}

local ROW_HEIGHT = 20
local MAX_ROWS = 18

for i = 1, MAX_ROWS do
    local row = CreateFrame("Button", nil, content)
    row:SetSize(300, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(i-1)*ROW_HEIGHT)

    row.linkText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.linkText:SetPoint("LEFT", 0, 0)
    row.linkText:SetWidth(180)
    row.linkText:SetJustifyH("LEFT")

    row.setsText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.setsText:SetPoint("LEFT", 185, 0)
    row.setsText:SetWidth(140)
    row.setsText:SetJustifyH("LEFT")

    row:SetScript("OnClick", function(self)
        if self.itemLink then
            HandleModifiedItemClick(self.itemLink)
        end
    end)

    EraWishlistRaidWindow.rows[i] = row
end

function EraWishlistRaidWindow:Refresh()
    local charDB = EraWishlist:GetCharDB()
    if not charDB or not charDB.raidSession or not charDB.raidSession.drops then
        for _, row in ipairs(self.rows) do
            row.itemLink = nil
            row.linkText:SetText("")
            row.setsText:SetText("")
            row:Hide()
        end
        self.content:SetHeight(1)
        return
    end

    local flat = {}
    for itemID, drops in pairs(charDB.raidSession.drops) do
        for _, entry in ipairs(drops) do
            table.insert(flat, entry)
        end
    end

    table.sort(flat, function(a, b) return a.time < b.time end)

    for i, row in ipairs(self.rows) do
        local entry = flat[i]
        if entry then
            local sets = EraWishlist:GetSetsForItem(entry.itemID)
            row.itemLink = entry.itemLink
            row.linkText:SetText(entry.itemLink)
            row.setsText:SetText(table.concat(sets, ", "))
            row:Show()
        else
            row.itemLink = nil
            row.linkText:SetText("")
            row.setsText:SetText("")
            row:Hide()
        end
    end

    self.content:SetHeight(math.max(#flat, 1) * ROW_HEIGHT)
end

function EraWishlistRaidWindow:ShowWithData()
    self:Refresh()
    self:Show()
end
