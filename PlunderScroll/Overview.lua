-------------------------------------------------------------------------------
--  PlunderScroll - Overview.lua
--  The Overview tab of the options window: everything looted all-time (the
--  Tracker's c.lifetime ledgers) with totals, a rarity breakdown, gathering
--  counts and a searchable item table.
--  The table can hold thousands of items, so only the visible rows exist. It
--  fills the page whatever the window's size, dropping columns when narrow.
-------------------------------------------------------------------------------
local _, ns = ...

local O = {}
ns.Overview = O

local W = ns.W
local F -- ns.Format, set in CreatePage
local frame
local ALL = "ALL"
local scope, search, rarity, itemType = ALL, "", nil, ALL
local sortKey, sortAsc = "count", false
local data            -- the Tracker:Lifetime view of the scope
local list = {}       -- item entries after filtering and sorting
local rows, statRows, rarityRows, counterRows, headers = {}, {}, {}, {}, {}
local ROW_H = 24
local LEFT_W, LEFT_INNER = 230, 210

-- Right to left: the item name fills what is left of the row. A column only
-- shows when a row is at least minRow wide.
local COLUMNS = {
    { key = "last", label = "Last looted", width = 76, minRow = 500 },
    { key = "first", label = "First looted", width = 76, minRow = 580 },
    { key = "count", label = "Amount", width = 64, right = true, minRow = 0 },
    { key = "quality", label = "Rarity", width = 80, minRow = 400 },
}
local nameRight = -8 -- room the shown columns take from the right of a row

local function UpdateColumns(rowWidth)
    nameRight = -8
    for _, col in ipairs(COLUMNS) do
        col.shown = rowWidth >= col.minRow
        if col.shown then
            col.x = nameRight
            nameRight = nameRight - col.width - 10
        end
    end
end
UpdateColumns(0)

-- Places a row's or the header's cells (by column key) and its name cell.
local function PlaceColumns(cells, nameCell)
    for _, col in ipairs(COLUMNS) do
        local cell = cells[col.key]
        cell:SetShown(col.shown)
        if col.shown then cell:SetPoint("RIGHT", col.x, 0) end
    end
    nameCell:SetPoint("RIGHT", nameRight, 0)
end

local function Day(t)
    return t and date("%Y-%m-%d", t) or "-"
end

local typeCache = {} -- itemID -> item type name
local function ItemType(id)
    local t = typeCache[id]
    if not t then
        t = (id and select(2, ns.GetItemInfoInstant(id))) or "Other"
        if id then typeCache[id] = t end
    end
    return t
end

-------------------------------------------------------------------------------
--  Item table
-------------------------------------------------------------------------------
local function ShowItemTooltip(row)
    local e = row.entry
    if not e then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if not pcall(GameTooltip.SetHyperlink, GameTooltip, e.link or ("item:" .. (e.id or 0))) then
        GameTooltip:SetText(e.name or "?")
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine(scope == ALL and "Looted all-time" or "Looted by " .. scope, F.Number(e.count),
        1, 0.82, 0, 1, 1, 1)
    if scope == ALL then
        for _, key in ipairs(ns.Tracker:Characters()) do
            local c = ns.root.chars[key]
            local own = c and c.lifetime and c.lifetime.items[e.key]
            if own and own.count < e.count then
                local color = c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
                GameTooltip:AddDoubleLine(color and ("|c" .. color.colorStr .. key .. "|r") or key, F.Number(own.count),
                    1, 1, 1, 1, 1, 1)
            end
        end
    end
    if e.first then GameTooltip:AddDoubleLine("First looted", date("%Y-%m-%d %H:%M", e.first), 1, 0.82, 0, 1, 1, 1) end
    if e.last then GameTooltip:AddDoubleLine("Last looted", date("%Y-%m-%d %H:%M", e.last), 1, 0.82, 0, 1, 1, 1) end
    local value = ns.Tracker:ItemValue(e)
    if value and value > 0 then
        GameTooltip:AddDoubleLine("Value of all looted", F.Money(value * e.count, "ICONS", 0, false, true),
            1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function NewRow(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW_H)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ROW_H - 4, ROW_H - 4)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.cols = {}
    for _, col in ipairs(COLUMNS) do
        local fs = b:CreateFontString(nil, "OVERLAY", col.key == "count" and "GameFontHighlight" or "GameFontHighlightSmall")
        fs:SetWidth(col.width)
        fs:SetJustifyH(col.right and "RIGHT" or "LEFT")
        fs:SetWordWrap(false)
        b.cols[col.key] = fs
    end
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    PlaceColumns(b.cols, b.name)
    b:SetScript("OnEnter", ShowItemTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local e = self.entry
        if e and e.link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(e.link) end
    end)
    return b
end

-- Places the pooled rows over the part of the list that is scrolled into view.
local function RenderRows()
    local scroll, content = frame.scroll, frame.content
    local first = math.floor(scroll:GetVerticalScroll() / ROW_H)
    local needed = math.ceil(scroll:GetHeight() / ROW_H) + 1
    for i = 1, math.max(needed, #rows) do
        local index = first + i
        local e = i <= needed and list[index]
        if e then
            local row = rows[i] or NewRow(content)
            rows[i] = row
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(index - 1) * ROW_H)
            row.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0)
            row.entry = e
            row.icon:SetTexture(e.icon or 134400)
            local q = e.quality or 1
            local color = F.QualityColor(q)
            row.name:SetText(F.Colorize(e.name or "?", color))
            row.cols.quality:SetText(F.Colorize(F.QualityLabel(q), color))
            row.cols.count:SetText(F.Number(e.count))
            row.cols.first:SetText(Day(e.first))
            row.cols.last:SetText(Day(e.last))
            row:Show()
            -- The mouse doesn't move while the wheel scrolls another item under it.
            if GameTooltip:IsOwned(row) then ShowItemTooltip(row) end
        elseif rows[i] then
            rows[i].entry = nil
            rows[i]:Hide()
        end
    end
end

local function LayoutColumns(rowWidth)
    UpdateColumns(rowWidth)
    PlaceColumns(headers, headers.name)
    for _, row in ipairs(rows) do PlaceColumns(row.cols, row.name) end
end

local function SortValue(e)
    if sortKey == "name" then return e.name or "" end
    if sortKey == "quality" then return e.quality or 1 end
    return e[sortKey] or 0
end

local function Compare(a, b)
    local va, vb = SortValue(a), SortValue(b)
    if va ~= vb then
        if sortAsc then return va < vb end
        return va > vb
    end
    if a.name ~= b.name then return (a.name or "") < (b.name or "") end
    return a.key < b.key
end

local function RefreshHeaders()
    for key, h in pairs(headers) do
        local mark = key == sortKey and (sortAsc and " ^" or " v") or ""
        h.text:SetText(h.label .. mark)
        h.text:SetTextColor(1, key == sortKey and 0.82 or 1, key == sortKey and 0 or 1)
    end
end

local function RefreshList(toTop)
    wipe(list)
    local needle = search:lower():match("^%s*(.-)%s*$")
    local idNeedle = tonumber(needle)
    local looted = 0
    for _, e in pairs(data.items) do
        if (not rarity or (e.quality or 1) == rarity)
            and (itemType == ALL or ItemType(e.id) == itemType)
            and (needle == "" or (e.name or ""):lower():find(needle, 1, true) or e.id == idNeedle) then
            list[#list + 1] = e
            looted = looted + e.count
        end
    end
    table.sort(list, Compare)

    frame.content:SetHeight(math.max(1, #list * ROW_H))
    frame.scroll:UpdateScrollChildRect()
    if toTop then
        frame.scroll:SetVerticalScroll(0)
    else
        local maxOffset = math.max(0, #list * ROW_H - frame.scroll:GetHeight())
        if frame.scroll:GetVerticalScroll() > maxOffset then frame.scroll:SetVerticalScroll(maxOffset) end
    end
    RenderRows()
    RefreshHeaders()

    local filtered = needle ~= "" or rarity ~= nil or itemType ~= ALL
    frame.status:SetText(("Showing |cffffffff%s|r of |cffffffff%s|r items  -  |cffffffff%s|r looted%s"):format(
        F.Number(#list), F.Number(data.unique), F.Number(looted),
        rarity and ("  -  only " .. F.Colorize(F.QualityLabel(rarity), F.QualityColor(rarity))) or ""))
    frame.clear:SetEnabled(filtered)
    frame.empty:SetText(data.unique == 0 and "Nothing looted yet." or "No items match your filters.")
    frame.empty:SetShown(#list == 0)
end

-------------------------------------------------------------------------------
--  Left column
-------------------------------------------------------------------------------
local function RefreshRarity()
    local total = data.itemTotal
    local y = frame.rarityTop
    for _, row in ipairs(rarityRows) do
        local q = row.quality
        local n = data.quality[q] or 0
        -- Artifact and Heirloom are rare enough to only take room when looted.
        local show = q <= 5 or n > 0 or (data.uniqueByQuality[q] or 0) > 0
        row:SetShown(show)
        if show then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.left, "TOPLEFT", 10, -y)
            y = y + 22
            local color = F.QualityColor(q)
            row.label:SetText(F.Colorize(F.QualityLabel(q), color))
            local share = total > 0 and n / total or 0
            row.value:SetText(("%s  |cff999999%d%%|r"):format(F.Number(n), math.floor(share * 100 + 0.5)))
            row.bar:SetVertexColor(color.r, color.g, color.b, 0.3)
            row.bar:SetWidth(math.max(1, (LEFT_INNER - 2) * share))
            row.bar:SetShown(n > 0)
            local sel = rarity == q
            row:SetBackdropBorderColor(sel and 1 or 0.2, sel and 0.82 or 0.2, sel and 0 or 0.22, 1)
        end
    end
    frame.countersHeader:ClearAllPoints()
    frame.countersHeader:SetPoint("TOPLEFT", frame.left, "TOPLEFT", 10, -(y + 10))
    for i, cell in ipairs(counterRows) do
        local n = data[cell.key] or 0
        cell.value:SetText(F.Number(n))
        cell.value:SetTextColor(n > 0 and 1 or 0.45, n > 0 and 1 or 0.45, n > 0 and 1 or 0.45)
        cell.label:SetTextColor(n > 0 and 1 or 0.45, n > 0 and 0.82 or 0.45, n > 0 and 0 or 0.45)
        local column, line = (i - 1) % 2, math.floor((i - 1) / 2)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", frame.left, "TOPLEFT", 10 + column * (LEFT_INNER / 2 + 4), -(y + 34 + line * 18))
    end
end

local function RefreshStats()
    local played = data.playTime
    local perHour = played > 60 and math.floor(data.money / (played / 3600)) or 0
    local values = {
        F.Money(data.money, "ICONS", 0, false, true),
        F.Money(perHour, "ICONS", 0, false, true),
        F.Number(data.itemTotal),
        F.Number(data.unique),
        F.Number(data.itemLoots + data.moneyLoots),
        F.Duration(played),
        F.Number(data.sessions),
        Day(data.since),
    }
    for i, row in ipairs(statRows) do row.value:SetText(values[i]) end
end

function O:Refresh(toTop)
    if not (frame and frame:IsVisible()) then return end
    if scope ~= ALL and not ns.root.chars[scope] then scope = ALL end
    data = ns.Tracker:Lifetime(scope ~= ALL and scope or nil)
    LayoutColumns(frame.scroll:GetWidth())
    frame.scope:Refresh()
    frame.typeButton:Refresh()
    RefreshStats()
    RefreshRarity()
    RefreshList(toTop)
end

-- Loot comes in often and this sums everything; redraw at most once a second.
local pending
function O:OnDataChanged()
    if not (frame and frame:IsVisible()) or pending then return end
    pending = true
    C_Timer.After(1, function()
        pending = false
        O:Refresh()
    end)
end

-------------------------------------------------------------------------------
--  Build
-------------------------------------------------------------------------------
local function Label(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

local function SectionHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(LEFT_INNER, 20)
    local t = Label(f, "GameFontNormal", text)
    t:SetPoint("LEFT")
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 8, 0)
    line:SetPoint("RIGHT")
    return f
end

local function BuildLeft(left)
    frame.scope = W.DropButton(left, LEFT_INNER, function()
        local out = { { value = ALL, text = "All characters" } }
        for _, key in ipairs(ns.Tracker:Characters()) do
            local c = ns.root.chars[key]
            local color = c and c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
            out[#out + 1] = { value = key, text = color and ("|c" .. color.colorStr .. key .. "|r") or key }
        end
        return out
    end, function() return scope end, function(v)
        scope = v
        O:Refresh(true)
    end)
    frame.scope:SetPoint("TOPLEFT", 10, -10)

    local y = 42
    SectionHeader(left, "Totals"):SetPoint("TOPLEFT", 10, -y)
    y = y + 22
    for _, text in ipairs({ "Gold looted", "Gold per hour", "Items looted", "Different items", "Times looted",
        "Time played", "Sessions saved", "Tracking since" }) do
        local row = CreateFrame("Frame", nil, left)
        row:SetSize(LEFT_INNER, 17)
        row:SetPoint("TOPLEFT", 10, -y)
        y = y + 17
        Label(row, "GameFontNormal", text):SetPoint("LEFT")
        row.value = Label(row, "GameFontHighlight")
        row.value:SetPoint("RIGHT")
        row.value:SetJustifyH("RIGHT")
        statRows[#statRows + 1] = row
    end

    y = y + 8
    SectionHeader(left, "By rarity"):SetPoint("TOPLEFT", 10, -y)
    frame.rarityTop = y + 22
    for q = 0, 7 do
        local row = CreateFrame("Button", nil, left, "BackdropTemplate")
        row:SetSize(LEFT_INNER, 20)
        W.Skin(row, 0.5, 0.2, 0.2, 0.22)
        row.quality = q
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.bar:SetPoint("TOPLEFT", 1, -1)
        row.bar:SetPoint("BOTTOMLEFT", 1, 1)
        row.label = Label(row, "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 6, 0)
        row.value = Label(row, "GameFontHighlightSmall")
        row.value:SetPoint("RIGHT", -6, 0)
        row.value:SetJustifyH("RIGHT")
        row:SetScript("OnClick", function(self)
            rarity = rarity ~= self.quality and self.quality or nil
            RefreshRarity()
            RefreshList(true)
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(F.QualityLabel(self.quality), 1, 0.82, 0)
            GameTooltip:AddLine(("%s different items"):format(F.Number(data.uniqueByQuality[self.quality] or 0)), 1, 1, 1)
            GameTooltip:AddLine("Click to show only these items; click again to show all.", 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        rarityRows[#rarityRows + 1] = row
    end

    frame.countersHeader = SectionHeader(left, "Opened & gathered")
    for _, c in ipairs(ns.COUNTERS) do
        local cell = CreateFrame("Frame", nil, left)
        cell:SetSize(LEFT_INNER / 2 - 4, 18)
        cell.key = c.key
        cell:EnableMouse(true)
        cell.label = Label(cell, "GameFontHighlightSmall", c.label)
        cell.label:SetPoint("LEFT")
        cell.value = Label(cell, "GameFontHighlightSmall")
        cell.value:SetPoint("RIGHT")
        cell.value:SetJustifyH("RIGHT")
        W.Tooltip(cell, c.label, c.desc)
        counterRows[#counterRows + 1] = cell
    end
end

local function HeaderButton(parent, key, label)
    local h = CreateFrame("Button", nil, parent)
    h:SetHeight(20)
    h.label = label
    h.text = Label(h, "GameFontNormalSmall")
    h.text:SetAllPoints()
    h:SetScript("OnClick", function()
        if sortKey == key then
            sortAsc = not sortAsc
        else
            sortKey, sortAsc = key, key == "name"
        end
        RefreshList(true)
    end)
    local hl = h:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.08)
    headers[key] = h
    return h
end

local function BuildRight(right)
    local searchBox = W.EditBox(right, 240, 22)
    searchBox:SetPoint("TOPLEFT", 12, -10)
    searchBox:SetPoint("TOPRIGHT", -12, -10)
    local placeholder = Label(searchBox, "GameFontDisableSmall", "Search by item name or ID...")
    placeholder:SetPoint("LEFT", 6, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        search = self:GetText() or ""
        placeholder:SetShown(search == "")
        if data then RefreshList(true) end
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    frame.typeButton = W.DropButton(right, 140, function()
        local types, out = {}, {}
        for _, e in pairs(data and data.items or {}) do types[ItemType(e.id)] = true end
        for t in pairs(types) do out[#out + 1] = t end
        table.sort(out)
        for i, t in ipairs(out) do out[i] = { value = t, text = t } end
        table.insert(out, 1, { value = ALL, text = "All item types" })
        return out
    end, function() return itemType end, function(v)
        itemType = v
        RefreshList(true)
    end)
    frame.typeButton:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)

    frame.clear = W.Button(right, "Clear Filters", 100, function()
        rarity, itemType = nil, ALL
        searchBox:SetText("") -- also refreshes, but not when the box was already empty
        frame.typeButton:Refresh()
        RefreshRarity()
        RefreshList(true)
    end)
    frame.clear:SetPoint("LEFT", frame.typeButton, "RIGHT", 8, 0)

    local history = W.Button(right, "History", 80, function() ns.History:Show() end)
    history:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -6)
    W.Tooltip(history, "History", "Browse your current and archived sessions one by one.")

    frame.status = Label(right, "GameFontHighlightSmall")
    frame.status:SetPoint("TOPLEFT", frame.typeButton, "BOTTOMLEFT", 0, -6)
    frame.status:SetPoint("RIGHT", -12, 0)
    frame.status:SetWordWrap(false)
    frame.status:SetTextColor(0.75, 0.75, 0.75)

    local listBg = CreateFrame("Frame", nil, right, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", 8, -86)
    listBg:SetPoint("BOTTOMRIGHT", -8, 8)
    W.Skin(listBg, 0.5, 0.12, 0.12, 0.14)

    -- Lines up with the rows in the scroll frame below it.
    local header = CreateFrame("Frame", nil, listBg)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -26, -4)
    header:SetHeight(20)
    local nameHeader = HeaderButton(header, "name", "Item")
    nameHeader:SetPoint("LEFT", 4, 0)
    for _, col in ipairs(COLUMNS) do
        local h = HeaderButton(header, col.key, col.label)
        h:SetWidth(col.width)
        if col.right then h.text:SetJustifyH("RIGHT") end
    end

    local scroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(600, 1)
    scroll:SetScrollChild(content)
    frame.scroll, frame.content = scroll, content
    scroll:HookScript("OnVerticalScroll", RenderRows)
    scroll:HookScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
        LayoutColumns(width)
        RenderRows()
    end)

    frame.empty = Label(listBg, "GameFontDisable")
    frame.empty:SetPoint("CENTER")
end

-- The page object the options window shows, hides and refreshes.
function O:CreatePage(parent)
    F = ns.Format
    frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints()
    frame:Hide()

    local left = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    left:SetPoint("TOPLEFT", 8, -8)
    left:SetPoint("BOTTOMLEFT", 8, 8)
    left:SetWidth(LEFT_W)
    W.Skin(left, 0.6, 0.15, 0.15, 0.17)
    frame.left = left

    local right = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", -8, 8)
    W.Skin(right, 0.6, 0.15, 0.15, 0.17)

    BuildLeft(left)
    BuildRight(right)

    return {
        Show = function()
            frame:Show()
            O:Refresh()
        end,
        Hide = function() frame:Hide() end,
        Refresh = function() O:Refresh() end,
    }
end

function O:Show()
    ns.Options:Show("Overview")
end

function O:Toggle()
    if ns.Options:IsShowing("Overview") then ns.Options:Hide() else self:Show() end
end
