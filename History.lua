-------------------------------------------------------------------------------
--  PlunderScroll - History.lua
--  Browse the current and archived loot sessions of every character.
-------------------------------------------------------------------------------
local _, ns = ...

local H = {}
ns.History = H

local W = ns.W
local F -- ns.Format, set on build
local frame
local selChar, selIndex = nil, 0 -- selIndex 0 = current session
local search, minQuality, sortBy = "", -1, "COUNT"
local sessionRows, itemRows = {}, {}
local ITEM_ROW_H, SESSION_ROW_H = 24, 44

local function CharData()
    return ns.root.chars[selChar]
end

local function Selected()
    local c = CharData()
    if not c then return end
    if selIndex == 0 then return c.current end
    return c.history[selIndex]
end

local function IsOwnChar()
    return selChar == ns.Tracker.charKey
end

-------------------------------------------------------------------------------
--  Session list
-------------------------------------------------------------------------------
local function SessionRow(parent, i)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(212, SESSION_ROW_H - 4)
    W.Skin(b, 0.5, 0.2, 0.2, 0.22)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * SESSION_ROW_H)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("TOPLEFT", 8, -6)
    b.name:SetPoint("RIGHT", -6, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sub:SetPoint("BOTTOMLEFT", 8, 6)
    b.sub:SetPoint("RIGHT", -6, 0)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)
    b:SetScript("OnClick", function(self)
        selIndex = self.index
        H:Refresh()
    end)
    b:SetScript("OnEnter", function(self) if self.index ~= selIndex then self:SetBackdropBorderColor(0.6, 0.5, 0.1, 1) end end)
    b:SetScript("OnLeave", function(self) if self.index ~= selIndex then self:SetBackdropBorderColor(0.2, 0.2, 0.22, 1) end end)
    return b
end

local function RefreshSessions()
    local c = CharData()
    local list = {}
    if c then
        if c.current then list[#list + 1] = { 0, c.current } end
        for i, s in ipairs(c.history) do list[#list + 1] = { i, s } end
    end
    local content = frame.sessionContent
    for i, entry in ipairs(list) do
        local row = sessionRows[i] or SessionRow(content, i)
        sessionRows[i] = row
        local idx, s = entry[1], entry[2]
        row.index = idx
        local label = idx == 0 and "|cff20ff20Current|r  " .. s.name or s.name
        row.name:SetText(label)
        local when = date("%Y-%m-%d", s.started)
        row.sub:SetText("|cff999999" .. when .. "|r  " .. F.Money(s.money, "ICONS", 0, false, false)
            .. "  |cff999999" .. (s.itemTotal or 0) .. " items|r")
        local sel = idx == selIndex
        row:SetBackdropBorderColor(sel and 1 or 0.2, sel and 0.82 or 0.2, sel and 0 or 0.22, 1)
        row:SetBackdropColor(sel and 0.18 or 0.06, sel and 0.15 or 0.06, sel and 0.05 or 0.07, sel and 0.9 or 0.5)
        row:Show()
    end
    for i = #list + 1, #sessionRows do sessionRows[i]:Hide() end
    content:SetHeight(math.max(1, #list * SESSION_ROW_H))
end

-------------------------------------------------------------------------------
--  Item list
-------------------------------------------------------------------------------
local function ItemRow(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(parent:GetWidth(), ITEM_ROW_H)
    b:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_ROW_H)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 0.82, 0, 0.08)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(ITEM_ROW_H - 4, ITEM_ROW_H - 4)
    b.icon:SetPoint("LEFT", 4, 0)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.count:SetPoint("RIGHT", -8, 0)
    b.count:SetWidth(60)
    b.count:SetJustifyH("RIGHT")
    b.rarity = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.rarity:SetPoint("RIGHT", b.count, "LEFT", -10, 0)
    b.rarity:SetWidth(90)
    b.rarity:SetJustifyH("LEFT")
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.name:SetPoint("RIGHT", b.rarity, "LEFT", -8, 0)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local link = e.link or ("item:" .. (e.id or 0))
        if not pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:SetText(e.name or "?") end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Looted this session", e.count, 1, 0.82, 0, 1, 1, 1)
        if e.first then GameTooltip:AddDoubleLine("First looted", date("%Y-%m-%d %H:%M", e.first), 1, 0.82, 0, 1, 1, 1) end
        if e.last then GameTooltip:AddDoubleLine("Last looted", date("%Y-%m-%d %H:%M", e.last), 1, 0.82, 0, 1, 1, 1) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local e = self.entry
        if e and e.link and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then ChatEdit_InsertLink(e.link) end
    end)
    return b
end

local SORTS = {
    COUNT = function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return (a.name or "") < (b.name or "")
    end,
    QUALITY = function(a, b)
        if (a.quality or 1) ~= (b.quality or 1) then return (a.quality or 1) > (b.quality or 1) end
        if a.count ~= b.count then return a.count > b.count end
        return (a.name or "") < (b.name or "")
    end,
    NAME = function(a, b) return (a.name or "") < (b.name or "") end,
    RECENT = function(a, b) return (a.last or 0) > (b.last or 0) end,
}

local function RefreshItems(s)
    local list = {}
    if s then
        local needle = search:lower()
        for _, e in pairs(s.items) do
            if (e.quality or 1) >= minQuality and (needle == "" or (e.name or ""):lower():find(needle, 1, true)) then
                list[#list + 1] = e
            end
        end
    end
    table.sort(list, SORTS[sortBy] or SORTS.COUNT)
    local content = frame.itemContent
    for i, e in ipairs(list) do
        local row = itemRows[i] or ItemRow(content, i)
        itemRows[i] = row
        row.entry = e
        row.icon:SetTexture(e.icon or 134400)
        local q = e.quality or 1
        row.name:SetText(F.Colorize(e.name or "?", F.QualityColor(q)))
        row.rarity:SetText(F.Colorize(F.QualityLabel(q), F.QualityColor(q)))
        row.count:SetText("x" .. e.count)
        row:Show()
    end
    for i = #list + 1, #itemRows do
        itemRows[i]:Hide()
        itemRows[i].entry = nil
    end
    content:SetHeight(math.max(1, #list * ITEM_ROW_H))
    frame.empty:SetShown(#list == 0)
end

-------------------------------------------------------------------------------
--  Details
-------------------------------------------------------------------------------
local function RefreshDetails()
    local s = Selected()
    if not s then
        selIndex = 0
        s = Selected()
    end
    if not s then
        frame.dTitle:SetText("No data")
        frame.dSub:SetText("")
        frame.dStats:SetText("")
        frame.dQuality:SetText("")
        RefreshItems(nil)
        return
    end
    local T = ns.Tracker
    frame.dTitle:SetText(s.name)
    local ended = s.ended and date("%Y-%m-%d %H:%M", s.ended) or "|cff20ff20active|r"
    frame.dSub:SetText(("|cff999999%s  -  %s  ->  %s|r"):format(s.char or selChar or "?",
        date("%Y-%m-%d %H:%M", s.started), ended))

    local played = (selIndex == 0 and IsOwnChar()) and T:PlayTime(s) or (s.playTime or 0)
    local perHour = played > 60 and math.floor(s.money / (played / 3600)) or 0
    local counts = F.CountsText(s, "      ", "|cffffd100%s|r")
    frame.dStats:SetText(("|cffffd100Money|r  %s      |cffffd100Per hour|r  %s      |cffffd100Played|r  %s\n|cffffd100Items|r  %d  (%d unique, %d loots)      |cffffd100Money loots|r  %d%s")
        :format(F.Money(s.money, "ICONS", 0, false, true), F.Money(perHour, "ICONS", 0, false, true), F.Duration(played),
            s.itemTotal or 0, T:UniqueCount(s), s.itemLoots or 0, s.moneyLoots or 0, counts ~= "" and ("\n" .. counts) or ""))

    local q = {}
    for _, i in ipairs(ns.QUALITIES) do
        q[#q + 1] = F.Colorize(F.QualityLabel(i) .. " " .. (s.quality[i] or 0), F.QualityColor(i))
    end
    frame.dQuality:SetText(table.concat(q, "    "))
    RefreshItems(s)

    local own = IsOwnChar()
    frame.bNew:SetEnabled(own)
    frame.bResume:SetEnabled(own and selIndex > 0)
    frame.bDelete:SetEnabled(selIndex > 0)
    frame.bForget:SetShown(not own)
end

function H:Refresh()
    if not (frame and frame:IsShown()) then return end
    if not selChar or not ns.root.chars[selChar] then selChar = ns.Tracker.charKey end
    frame.charButton:Refresh()
    RefreshSessions()
    RefreshDetails()
end

-- Loot comes in often; batch redraws to once per half second.
local pending
function H:OnDataChanged()
    if not (frame and frame:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        H:Refresh()
    end)
end

-------------------------------------------------------------------------------
--  Export
-------------------------------------------------------------------------------
local exportFrame
local function Export(s)
    if not exportFrame then
        exportFrame = W.Window("PlunderScrollExport", "Export Session", 520, 420)
        exportFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        local scroll = CreateFrame("ScrollFrame", nil, exportFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -44)
        scroll:SetPoint("BOTTOMRIGHT", -34, 14)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(460)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() exportFrame:Hide() end)
        scroll:SetScrollChild(edit)
        exportFrame.edit = edit
    end
    local lines = {
        "PlunderScroll session: " .. s.name,
        "Character: " .. (s.char or "?"),
        "Started: " .. date("%Y-%m-%d %H:%M", s.started) .. (s.ended and ("   Ended: " .. date("%Y-%m-%d %H:%M", s.ended)) or ""),
        "Money: " .. F.MoneyPlain(s.money) .. "   Items: " .. (s.itemTotal or 0) .. "   " .. F.CountsText(s, "   "),
        "",
        "Count;Rarity;Item;ItemID",
    }
    local items = {}
    for _, e in pairs(s.items) do items[#items + 1] = e end
    table.sort(items, SORTS.QUALITY)
    for _, e in ipairs(items) do
        lines[#lines + 1] = ("%d;%s;%s;%s"):format(e.count, ns.QUALITY_LABELS[e.quality or 1] or "?", e.name or "?", tostring(e.id or ""))
    end
    exportFrame.edit:SetText(table.concat(lines, "\n"))
    exportFrame:Show()
    exportFrame.edit:SetFocus()
    exportFrame.edit:HighlightText()
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

local function Build()
    F = ns.Format
    frame = W.Window("PlunderScrollHistory", "|cffffd100Plunder|rScroll  |cffffffffHistory|r", 900, 580)
    frame:SetScript("OnShow", function() H:Refresh() end)

    -- Left: character and sessions
    local left = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    left:SetPoint("TOPLEFT", 10, -40)
    left:SetPoint("BOTTOMLEFT", 10, 10)
    left:SetWidth(250)
    W.Skin(left, 0.6, 0.15, 0.15, 0.17)

    frame.charButton = W.DropButton(left, 234, function()
        local out = {}
        for _, key in ipairs(ns.Tracker:Characters()) do
            local c = ns.root.chars[key]
            local color = c and c.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c.class]
            out[#out + 1] = { value = key, text = color and ("|c" .. color.colorStr .. key .. "|r") or key }
        end
        return out
    end, function() return selChar end, function(v)
        selChar, selIndex = v, 0
        H:Refresh()
    end)
    frame.charButton:SetPoint("TOP", 0, -8)

    local sScroll = CreateFrame("ScrollFrame", nil, left, "UIPanelScrollFrameTemplate")
    sScroll:SetPoint("TOPLEFT", 8, -40)
    sScroll:SetPoint("BOTTOMRIGHT", -28, 8)
    local sContent = CreateFrame("Frame", nil, sScroll)
    sContent:SetSize(212, 1)
    sScroll:SetScrollChild(sContent)
    frame.sessionContent = sContent

    -- Right: details
    local right = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", -10, 10)
    W.Skin(right, 0.6, 0.15, 0.15, 0.17)

    frame.dTitle = Label(right, "GameFontNormalLarge")
    frame.dTitle:SetPoint("TOPLEFT", 14, -12)
    frame.dTitle:SetPoint("RIGHT", -14, 0)
    frame.dSub = Label(right, "GameFontHighlightSmall")
    frame.dSub:SetPoint("TOPLEFT", frame.dTitle, "BOTTOMLEFT", 0, -4)
    frame.dStats = Label(right, "GameFontHighlight")
    frame.dStats:SetPoint("TOPLEFT", frame.dSub, "BOTTOMLEFT", 0, -10)
    frame.dStats:SetSpacing(4)
    frame.dQuality = Label(right, "GameFontHighlight")
    frame.dQuality:SetPoint("TOPLEFT", frame.dStats, "BOTTOMLEFT", 0, -10)

    -- Filters
    local searchBox = W.EditBox(right, 200, 22)
    -- Follows the stats, which gain a line when the session has gathering counts.
    searchBox:SetPoint("TOPLEFT", frame.dQuality, "BOTTOMLEFT", 0, -12)
    local ph = Label(searchBox, "GameFontDisableSmall", "Search items...")
    ph:SetPoint("LEFT", 6, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        search = self:GetText() or ""
        ph:SetShown(search == "")
        local s = Selected()
        if s then RefreshItems(s) end
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local qualityButton = W.DropButton(right, 150, function()
        local out = { { value = -1, text = "All rarities" } }
        for _, q in ipairs(ns.QUALITIES) do
            out[#out + 1] = { value = q, text = F.Colorize(F.QualityLabel(q) .. "+", F.QualityColor(q)) }
        end
        return out
    end, function() return minQuality end, function(v)
        minQuality = v
        RefreshItems(Selected())
    end)
    qualityButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    qualityButton:Refresh()

    local sortButton = W.DropButton(right, 160, {
        { value = "COUNT", text = "Sort: Amount" },
        { value = "QUALITY", text = "Sort: Rarity" },
        { value = "NAME", text = "Sort: Name" },
        { value = "RECENT", text = "Sort: Last looted" },
    }, function() return sortBy end, function(v)
        sortBy = v
        RefreshItems(Selected())
    end)
    sortButton:SetPoint("LEFT", qualityButton, "RIGHT", 8, 0)
    sortButton:Refresh()

    -- Items
    local listBg = CreateFrame("Frame", nil, right, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -8)
    listBg:SetPoint("BOTTOMRIGHT", -10, 46)
    W.Skin(listBg, 0.5, 0.12, 0.12, 0.14)
    local iScroll = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
    iScroll:SetPoint("TOPLEFT", 4, -4)
    iScroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local iContent = CreateFrame("Frame", nil, iScroll)
    iContent:SetSize(580, 1)
    iScroll:SetScrollChild(iContent)
    iScroll:SetScript("OnSizeChanged", function(self, w)
        iContent:SetWidth(w)
        for _, row in ipairs(itemRows) do row:SetWidth(w) end
    end)
    frame.itemContent = iContent
    frame.empty = Label(listBg, "GameFontDisable", "No items looted yet.")
    frame.empty:SetPoint("CENTER")

    -- Actions
    local x = 10
    local function Action(text, width, onClick, tip)
        local b = W.Button(right, text, width, onClick, 26)
        b:SetPoint("BOTTOMLEFT", x, 12)
        x = x + width + 6
        if tip then W.Tooltip(b, text, tip) end
        return b
    end
    frame.bNew = Action("New Session", 110, function() StaticPopup_Show("PLUNDERSCROLL_NEW_SESSION") end,
        "Archive your current session and start a new one.")
    frame.bResume = Action("Resume", 80, function()
        if selIndex > 0 and IsOwnChar() then
            ns.Tracker:Resume(selIndex)
            selIndex = 0
            H:Refresh()
        end
    end, "Make this archived session your current one again (the current one is archived).")
    frame.bRename = Action("Rename", 80, function()
        local s = Selected()
        if s then StaticPopup_Show("PLUNDERSCROLL_RENAME", nil, nil, s) end
    end)
    frame.bExport = Action("Export", 80, function()
        local s = Selected()
        if s then Export(s) end
    end, "Copyable text of this session.")
    frame.bDelete = Action("Delete", 80, function()
        local s = Selected()
        if s and selIndex > 0 then
            StaticPopup_Show("PLUNDERSCROLL_DELETE", s.name, nil, { char = selChar, index = selIndex })
        end
    end, "Delete this archived session.")
    frame.bForget = Action("Forget Character", 130, function()
        StaticPopup_Show("PLUNDERSCROLL_FORGET", selChar, nil, selChar)
    end, "Delete every session of this character.")

    local opts = W.Button(right, "Options", 80, function() ns.Options:Show() end, 26)
    opts:SetPoint("BOTTOMRIGHT", -10, 12)

    StaticPopupDialogs.PLUNDERSCROLL_RENAME = {
        text = "Rename session:",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 64,
        OnShow = function(self, data)
            local e = ns.PopupEdit(self)
            if e and data then e:SetText(data.name or ""); e:HighlightText(); e:SetFocus() end
        end,
        OnAccept = function(self, data)
            local e = ns.PopupEdit(self)
            if e then ns.Tracker:Rename(data, e:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self, data)
            local parent = self:GetParent()
            ns.Tracker:Rename(data or parent.data, self:GetText())
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.PLUNDERSCROLL_DELETE = {
        text = "Delete session \"%s\"?\nThis cannot be undone.",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            ns.Tracker:Delete(data.char, data.index)
            selIndex = 0
            H:Refresh()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
    }
    StaticPopupDialogs.PLUNDERSCROLL_FORGET = {
        text = "Delete ALL PlunderScroll sessions of %s?\nThis cannot be undone.",
        button1 = DELETE or "Delete",
        button2 = CANCEL or "Cancel",
        OnAccept = function(_, data)
            ns.Tracker:DeleteCharacter(data)
            selChar, selIndex = ns.Tracker.charKey, 0
            H:Refresh()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
    }
end

function H:Show()
    if not frame then Build() end
    selChar = selChar or ns.Tracker.charKey
    frame:Show()
    self:Refresh()
end

function H:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Show() end
end
