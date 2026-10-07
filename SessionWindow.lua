-------------------------------------------------------------------------------
--  PlunderScroll - SessionWindow.lua
--  An optional see-through window listing everything looted in the current
--  session (icon, name, amount) with the session's money total.
--  Click-through while locked; drag to move while unlocked.
-------------------------------------------------------------------------------
local _, ns = ...

local SW = {}
ns.SessionWindow = SW

local frame
local rows = {}
local PAD = 8
local GRIP = 16
local BAR_W = 5
local offset = 0 -- first item row shown (scroll position)
local MIN_W, MIN_H, MAX_W, MAX_H = 120, 60, 1000, 1200

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

local function Text(parent, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Row(i)
    local r = rows[i]
    if r then return r end
    r = { name = Text(frame), count = Text(frame, "RIGHT") }
    rows[i] = r
    return r
end

function SW:Init()
    frame = CreateFrame("Frame", "PlunderScrollSessionWindow", UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not ns.db.swLocked or IsShiftKeyDown() then
            self.moving = true
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.moving = false
        SW:SavePosition()
        SW:UpdateMouse()
    end)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_W, MIN_H)
        frame:SetMaxResize(MAX_W, MAX_H)
    end
    frame:SetScript("OnSizeChanged", function()
        if frame.sizing then SW:Refresh() end
    end)

    -- Resize grip in the bottom right corner.
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP, GRIP)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(frame:GetFrameLevel() + 5)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        -- Size from a top-left anchor so the top-left corner stays put.
        local left, top = frame:GetLeft(), frame:GetTop()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        frame.sizing, frame.moving = true, true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        if not frame.sizing then return end
        frame:StopMovingOrSizing()
        frame.sizing, frame.moving = false, false
        ns.db.swWidth = math.floor(frame:GetWidth() + 0.5)
        ns.db.swHeight = math.floor(frame:GetHeight() + 0.5)
        SW:SavePosition()
        ns.RefreshAll()
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Drag to resize")
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.grip = grip
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.History:Show() end
    end)
    frame:SetBackdrop(ns.W.BACKDROP)
    frame.title = Text(frame)
    frame.title:SetPoint("TOPLEFT", PAD, -PAD)
    frame.title:SetPoint("TOPRIGHT", -(PAD + 18), -PAD)

    -- Help button with Blizzard's help-plate art (the MainHelpPlateButton
    -- texture); has its own mouse so it works while the window is click-through.
    local HELP_ART = "Interface\\Common\\help-i"
    local help = CreateFrame("Button", nil, frame)
    help:SetSize(22, 22)
    help:SetPoint("TOPRIGHT", 0, 0)
    help:SetFrameLevel(frame:GetFrameLevel() + 5)
    help:SetNormalTexture(HELP_ART)
    help:SetHighlightTexture(HELP_ART, "ADD")
    help:GetHighlightTexture():SetAlpha(0.3)
    help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("|cffffd100Plunder|rScroll Session Window")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Move", 1, 0.82, 0)
        GameTooltip:AddLine("Hold Shift and drag the window. (When unlocked in the options, just drag it.)", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Resize", 1, 0.82, 0)
        GameTooltip:AddLine("Hold Shift and drag the grip in the bottom right corner, or use the Width and Height sliders on the Session Window options page.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Hide", 1, 0.82, 0)
        GameTooltip:AddLine("Type /ps window, or untick \"Show session window\" in /ps > Session Window.", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open the Session Window options.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function() GameTooltip:Hide() end)
    help:SetScript("OnClick", function() ns.Options:Show("Session Window") end)
    frame.help = help
    frame.more = Text(frame)
    frame.total = Text(frame)
    frame.counts = {} -- [counter key] = font string
    for _, c in ipairs(ns.COUNTERS) do frame.counts[c.key] = Text(frame) end
    frame.totalCount = Text(frame, "RIGHT")
    frame.line = frame:CreateTexture(nil, "ARTWORK")
    frame.line:SetHeight(1)

    -- Item list scrolling: mouse wheel over the window (works while it is
    -- click-through) and a slim draggable scroll bar.
    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        SW:Refresh()
    end)
    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BAR_W)
    bar:SetFrameLevel(frame:GetFrameLevel() + 4)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar.track = bar:CreateTexture(nil, "BACKGROUND")
    bar.track:SetAllPoints()
    bar.track:SetColorTexture(1, 1, 1, 0.08)
    bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    bar.thumb = bar:GetThumbTexture()
    bar.thumb:SetVertexColor(1, 0.82, 0, 0.7)
    bar.thumb:SetWidth(BAR_W)
    bar:SetScript("OnValueChanged", function(_, value, user)
        if not user then return end
        value = math.floor(value + 0.5)
        if value ~= offset then
            offset = value
            SW:Refresh()
        end
    end)
    bar:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta
        SW:Refresh()
    end)
    bar:EnableMouseWheel(true)
    bar:Hide()
    frame.bar = bar
    -- Locked windows are click-through, except while Shift is held so they
    -- can still be dragged.
    frame:RegisterEvent("MODIFIER_STATE_CHANGED")
    -- Restyle once after the loading screen: on a cold start (e.g. after a
    -- patch) font files can still be loading at PLAYER_LOGIN, and text set
    -- before that stays blank until it is set again.
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            self:UnregisterEvent(event)
            C_Timer.After(0.5, function() SW:ApplyStyle() end)
            return
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            self:UnregisterEvent(event) -- Refresh registers it again if items are still missing
            SW:OnDataChanged()
            return
        end
        SW:UpdateMouse()
        SW:Refresh()
    end)
    self:ApplyStyle()
end

function SW:SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local pos = ns.db.swPos
    pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
end

-- Locked: click-through and no grip, unless Shift is held.
function SW:UpdateMouse()
    if not frame or frame.moving then return end
    local active = not ns.db.swLocked or IsShiftKeyDown()
    frame:EnableMouse(active)
    frame.grip:SetShown(active)
end

function SW:ApplyStyle()
    if not frame then return end
    local db = ns.db
    frame:SetShown(db.sessionWindow)
    if not db.sessionWindow then return end
    frame:SetScale(db.swScale)
    frame:SetFrameStrata(db.swStrata)
    frame:SetSize(db.swWidth, db.swHeight)
    frame:ClearAllPoints()
    local pos = db.swPos
    frame:SetPoint(pos.point or "RIGHT", UIParent, pos.relPoint or "RIGHT", pos.x or 0, pos.y or 0)
    self:UpdateMouse()
    frame:SetBackdropColor(0, 0, 0, db.swBgAlpha)
    if db.swLocked then
        frame:SetBackdropBorderColor(0, 0, 0, db.swBorder and db.swBgAlpha or 0)
    else
        frame:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    end
    frame.line:SetColorTexture(1, 0.82, 0, db.swBgAlpha > 0 and 0.35 or 0)
    local size = db.swFontSize
    for _, fs in ipairs({ frame.title, frame.more, frame.total, frame.totalCount }) do
        ns.Fonts:Apply(fs, size)
    end
    for _, fs in pairs(frame.counts) do ns.Fonts:Apply(fs, size) end
    for _, r in ipairs(rows) do
        ns.Fonts:Apply(r.name, size)
        ns.Fonts:Apply(r.count, size)
    end
    self:Refresh()
end

function SW:Refresh()
    if not (frame and frame:IsShown()) then return end
    local db = ns.db
    local F = ns.Format
    local cur = ns.Tracker:Current()
    if not cur then return end
    local size = db.swFontSize
    local rowH = math.max(size, db.swShowIcons and size or 0) + db.swSpacing
    local y = PAD

    local showHead = db.swShowTitle or db.swShowValue
    frame.title:SetShown(showHead)
    if showHead then
        local head = db.swShowTitle and "|cffffd100Current Plunder|r" or ""
        if db.swShowValue then
            local value, missing = ns.Tracker:SessionValue(cur)
            -- Uncached items are left out; redraw once the server sends them.
            if missing then frame:RegisterEvent("GET_ITEM_INFO_RECEIVED") end
            head = head .. (head ~= "" and "  " or "") .. F.MoneyStyled(value)
        end
        frame.title:SetText(head)
        y = y + math.max(size, db.coinSize) + 6
    end

    local list = {}
    for _, e in pairs(cur.items) do
        if (e.quality or 1) >= db.swMinQuality then list[#list + 1] = e end
    end
    table.sort(list, SORTS[db.swSort] or SORTS.COUNT)

    -- Rows that fit between the title and the footer.
    local moneyH = math.max(size, db.coinSize)
    -- Gathering / opening counts sit above the money line, only when above 0.
    local openLines = {}
    if db.swShowChests then
        for _, c in ipairs(ns.COUNTERS) do
            local n = cur[c.key] or 0
            if n > 0 then openLines[#openLines + 1] = { frame.counts[c.key], c.label .. ":", n } end
        end
    end
    local footH = moneyH + #openLines * (size + 4)
    local bottom = PAD + footH + 9
    -- The saved height, except while resizing: GetHeight() can be stale right
    -- after login, which left the item list empty until the next redraw.
    local height = frame.sizing and frame:GetHeight() or db.swHeight
    local fit = math.max(0, math.floor((height - y - bottom) / rowH))
    local maxOffset = math.max(0, #list - fit)
    offset = math.max(0, math.min(offset, maxOffset))
    local shown = math.min(fit, #list - offset)
    local scrolling = maxOffset > 0
    local rightPad = PAD + (scrolling and (BAR_W + 4) or 0)

    local bar = frame.bar
    frame:EnableMouseWheel(scrolling)
    bar:SetShown(scrolling)
    if scrolling then
        local barH = fit * rowH
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -y)
        bar:SetHeight(barH)
        bar.thumb:SetHeight(math.max(10, barH * fit / #list))
        bar:SetMinMaxValues(0, maxOffset)
        bar:SetValue(offset)
    end

    for i = 1, shown do
        local e, r = list[offset + i], Row(i)
        if not r.styled then
            ns.Fonts:Apply(r.name, size)
            ns.Fonts:Apply(r.count, size)
            r.styled = true
        end
        local q = e.quality or 1
        local name = e.name or "?"
        if db.swColorNames then name = F.Colorize(name, F.QualityColor(q)) end
        if db.swShowIcons then name = F.Icon(e.icon, size) .. " " .. name end
        r.name:SetText(name)
        r.count:SetText(F.Colorize("x" .. e.count, db.amountColor))
        r.count:ClearAllPoints()
        r.count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rightPad, -y)
        r.name:ClearAllPoints()
        r.name:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        r.name:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r.name:Show()
        r.count:Show()
        y = y + rowH
    end
    for i = shown + 1, #rows do
        rows[i].name:Hide()
        rows[i].count:Hide()
    end

    if #list == 0 then
        frame.more:SetText("|cff999999Nothing looted yet.|r")
        frame.more:ClearAllPoints()
        frame.more:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -y)
        frame.more:Show()
        y = y + rowH
    else
        frame.more:Hide()
    end

    frame.line:ClearAllPoints()
    frame.line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD + footH + 5)
    frame.line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD + footH + 5)
    frame.total:ClearAllPoints()
    frame.total:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    frame.total:SetText("|cffffd100Money:|r " .. F.MoneyStyled(cur.money))
    for _, fs in pairs(frame.counts) do fs:Hide() end
    local lineY = PAD + moneyH + 4
    for i = #openLines, 1, -1 do -- last entry sits lowest, right above the money
        local fs, label, count = openLines[i][1], openLines[i][2], openLines[i][3]
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, lineY)
        fs:SetText("|cffffd100" .. label .. "|r " .. count)
        fs:Show()
        lineY = lineY + size + 4
    end
    frame.totalCount:ClearAllPoints()
    frame.totalCount:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + (frame.grip:IsShown() and GRIP - 4 or 0)), PAD)
    frame.totalCount:SetText("|cff999999" .. (cur.itemTotal or 0) .. " items|r")
end

-- Loot can arrive in bursts; redraw at most every 0.2s.
local pending
function SW:OnDataChanged()
    if not (frame and frame:IsShown()) or pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        SW:Refresh()
    end)
end

function SW:Toggle()
    ns.db.sessionWindow = not ns.db.sessionWindow
    ns.RefreshAll()
end
