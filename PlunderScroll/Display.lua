-------------------------------------------------------------------------------
--  PlunderScroll - Display.lua
--  The scrolling text area.
--    SCROLL: each line travels the scroll distance over the duration and fades
--            out near the end; a burst of loot pushes older lines ahead so
--            lines never overlap.
--    STACK:  lines stack from the anchor, wait for the duration, then fade.
-------------------------------------------------------------------------------
local _, ns = ...

local D = {}
ns.Display = D

local anchor, container
local active = {} -- oldest first
local pool = {}
local sin, pi, min, max = math.sin, math.pi, math.min, math.max

local function PointFor(db)
    local v = db.direction == "DOWN" and "TOP" or "BOTTOM"
    if db.justify == "LEFT" then return v .. "LEFT" end
    if db.justify == "RIGHT" then return v .. "RIGHT" end
    return v
end

local function Release(index)
    local l = table.remove(active, index)
    l.fs:Hide()
    l.fs:SetText("")
    l.key, l.data = nil, nil
    pool[#pool + 1] = l
end

local function Place(l, db, point, x)
    local y = db.direction == "DOWN" and -l.y or l.y
    l.fs:SetPoint(point, container, point, x or 0, y)
end

local function LineHeight(l, db)
    local h = l.fs:GetStringHeight() or 0
    local icon = db.showIcon and db.iconSize or 0
    return max(h, db.fontSize, icon)
end

local function OnUpdate(_, elapsed)
    local n = #active
    if n == 0 then
        anchor:SetScript("OnUpdate", nil)
        return
    end
    local db = ns.db
    local point = PointFor(db)
    local fadeIn = db.fadeIn
    if db.mode == "STACK" then
        local y = 0
        local life = db.duration + db.fadeTime
        for i = n, 1, -1 do
            local l = active[i]
            l.age = l.age + elapsed
            if l.age >= life then
                Release(i)
            else
                l.y = l.y + (y - l.y) * min(1, elapsed * 12)
                local a = 1
                if fadeIn > 0 and l.age < fadeIn then a = l.age / fadeIn end
                if l.age > db.duration and db.fadeTime > 0 then a = min(a, 1 - (l.age - db.duration) / db.fadeTime) end
                l.fs:SetAlpha(max(0, a))
                Place(l, db, point, 0)
                y = y + l.height + db.spacing
            end
        end
    else
        local distance = max(1, db.distance)
        local speed = distance / max(0.1, db.duration)
        local fadeDist = speed * db.fadeTime
        for i = n, 1, -1 do
            local l = active[i]
            l.age = l.age + elapsed
            l.y = l.y + speed * elapsed
            local left = distance - l.y - l.height
            if left <= 0 then
                Release(i)
            else
                local a = 1
                if fadeIn > 0 and l.age < fadeIn then a = l.age / fadeIn end
                if fadeDist > 0 and left < fadeDist then a = min(a, left / fadeDist) end
                l.fs:SetAlpha(max(0, a))
                local x = 0
                if db.curve ~= 0 then x = db.curve * sin(min(1, l.y / distance) * pi) end
                Place(l, db, point, x)
            end
        end
    end
end

function D:Init()
    anchor = CreateFrame("Frame", "PlunderScrollAnchor", UIParent, "BackdropTemplate")
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self) if not ns.db.locked then self:StartMoving() end end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        D:SavePosition()
    end)
    anchor:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Options:Show() end
    end)
    anchor:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })

    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    anchor.label:SetPoint("CENTER")
    anchor.label:SetText("|cffffd100Plunder|rScroll\n|cffffffffDrag to move. Right-click for options.|r\n|cffaaaaaa/ps lock when done|r")

    container = CreateFrame("Frame", nil, anchor)
    container:SetAllPoints()
    self.anchor = anchor
    self:ApplyStyle()
end

function D:SavePosition()
    local point, _, relPoint, x, y = anchor:GetPoint(1)
    local pos = ns.db.pos
    pos.point, pos.relPoint, pos.x, pos.y = point, relPoint, x, y
end

function D:UpdateLock()
    local locked = ns.db.locked
    anchor:EnableMouse(not locked)
    if locked then
        anchor:SetBackdropColor(0, 0, 0, 0)
        anchor:SetBackdropBorderColor(0, 0, 0, 0)
        anchor.label:Hide()
    else
        anchor:SetBackdropColor(0.05, 0.05, 0.05, 0.55)
        anchor:SetBackdropBorderColor(1, 0.82, 0, 0.9)
        anchor.label:Show()
    end
end

function D:StyleLine(l)
    local db = ns.db
    local fs = l.fs
    ns.Fonts:Apply(fs, db.fontSize)
    fs:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b)
    fs:SetJustifyH(db.justify)
    fs:SetWordWrap(false)
    fs:ClearAllPoints()
end

function D:RenderLine(l)
    l.fs:SetText(ns.Format.Line(l.data))
    l.height = LineHeight(l, ns.db)
end

function D:ApplyStyle()
    if not anchor then return end
    local db = ns.db
    anchor:SetScale(db.scale)
    anchor:SetFrameStrata(db.strata)
    container:SetAlpha(db.alpha)
    local h
    if db.mode == "STACK" then
        h = max(40, db.maxLines * (max(db.fontSize, db.iconSize) + db.spacing))
    else
        h = max(40, db.distance)
    end
    anchor:SetSize(db.width, h)
    local pos = db.pos
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    self:UpdateLock()
    for _, l in ipairs(active) do
        self:StyleLine(l)
        self:RenderLine(l)
    end
    container:SetShown(db.enabled)
end

function D:Clear()
    while active[1] do Release(1) end
end

-- Shows a line. Lines with the same key inside the merge window add up.
function D:Push(key, data)
    local db = ns.db
    if not anchor or not db.enabled then return end
    local now = GetTime()
    if key and db.mergeWindow > 0 then
        for _, l in ipairs(active) do
            if l.key == key and now - l.born <= db.mergeWindow then
                l.data.amount = l.data.amount + data.amount
                l.data.total = data.total or l.data.total
                self:RenderLine(l)
                if db.mode == "STACK" then l.age = min(l.age, db.fadeIn) end
                return
            end
        end
    end

    local l = table.remove(pool)
    if not l then l = { fs = container:CreateFontString(nil, "OVERLAY") } end
    l.key, l.data, l.born, l.age, l.y = key, data, now, 0, 0
    self:StyleLine(l)
    self:RenderLine(l)
    l.fs:SetAlpha(db.fadeIn > 0 and 0 or 1)
    l.fs:Show()

    if db.mode ~= "STACK" then
        -- Keep a gap between the new line and the one ahead of it.
        local ahead = active[#active]
        local need = l.height + db.spacing
        if ahead and ahead.y < need then
            local shift = need - ahead.y
            for _, o in ipairs(active) do o.y = o.y + shift end
        end
    end
    Place(l, db, PointFor(db), 0)
    active[#active + 1] = l
    while #active > db.maxLines do Release(1) end
    anchor:SetScript("OnUpdate", OnUpdate)
end
