-------------------------------------------------------------------------------
--  PlunderScroll - Widgets.lua
--  Small flat-styled widget kit for the options and history windows.
-------------------------------------------------------------------------------
local _, ns = ...

local W = {}
ns.W = W

local WHITE = "Interface\\Buttons\\WHITE8x8"
W.BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
W.GOLD = { 1, 0.82, 0 }

function W.Skin(f, bgA, borderR, borderG, borderB, borderA)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop(W.BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.07, bgA or 0.95)
    f:SetBackdropBorderColor(borderR or 0.25, borderG or 0.25, borderB or 0.27, borderA or 1)
end

local function Tooltip(f, title, text)
    if not text then return end
    f:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 0.82, 0)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
W.Tooltip = Tooltip

-- Main window with a title bar, drag to move and a close button.
function W.Window(name, title, width, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    W.Skin(f, 0.96, 0.18, 0.18, 0.2)
    f:Hide()

    local bar = f:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(1, 0.82, 0, 0.9)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", -1, -1)
    bar:SetHeight(2)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText(title)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    f.close = close

    if name then table.insert(UISpecialFrames, name) end
    return f
end

function W.Button(parent, text, width, onClick, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 120, height or 24)
    W.Skin(b, 0.9, 0.3, 0.3, 0.32)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.32, 1) end)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnable", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnDisable", function(self) self.text:SetTextColor(0.45, 0.45, 0.45) end)
    function b:SetText(t) self.text:SetText(t) end
    return b
end

function W.EditBox(parent, width, height)
    local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    e:SetSize(width, height or 22)
    W.Skin(e, 0.9, 0.3, 0.3, 0.32)
    e:SetFontObject("ChatFontNormal")
    e:SetTextInsets(6, 6, 0, 0)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    e:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.32, 1) end)
    return e
end

-- A menu of items { value =, text =, font = } next to the clicked frame.
function W.OpenMenu(owner, items, isSelected, onSelect)
    local list = type(items) == "function" and items() or items
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(owner, function(_, root)
            if #list > 18 and root.SetScrollMode then root:SetScrollMode(420) end
            for _, it in ipairs(list) do
                local desc = root:CreateRadio(it.text, function() return isSelected(it.value) end,
                    function() onSelect(it.value) end, it.value)
                if it.font and desc.AddInitializer and desc.AddResetter then
                    desc:AddInitializer(function(button)
                        local fs = button.fontString
                        if fs then
                            button.psFont = { fs:GetFont() }
                            pcall(fs.SetFont, fs, it.font, 13, "")
                        end
                    end)
                    desc:AddResetter(function(button)
                        local fs, f = button.fontString, button.psFont
                        if fs and f and f[1] then pcall(fs.SetFont, fs, f[1], f[2], f[3] or "") end
                        button.psFont = nil
                    end)
                end
            end
        end)
    else
        -- No menu system: step to the next value.
        local idx = 1
        for i, it in ipairs(list) do if isSelected(it.value) then idx = i end end
        local nextItem = list[idx % #list + 1]
        if nextItem then onSelect(nextItem.value) end
    end
end

-- A button showing the current value that opens a menu of items.
function W.DropButton(parent, width, items, get, set)
    local b = W.Button(parent, "", width)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 8, 0)
    b.text:SetPoint("RIGHT", -20, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetRotation(-math.pi / 2)
    arrow:SetSize(12, 12)
    arrow:SetPoint("RIGHT", -6, 0)
    b:SetScript("OnClick", function(self)
        W.OpenMenu(self, items, function(v) return get() == v end, function(v)
            set(v)
            self:Refresh()
        end)
    end)
    function b:Refresh()
        local list = type(items) == "function" and items() or items
        local v = get()
        local text = tostring(v)
        for _, it in ipairs(list) do
            if it.value == v then text = it.text break end
        end
        self.text:SetText(text)
    end
    return b
end

-------------------------------------------------------------------------------
--  Pages: a scroll frame with a two-column auto layout.
-------------------------------------------------------------------------------
local COL_W, COL_GAP = 270, 24
W.COL_W, W.FULL_W = COL_W, COL_W * 2 + COL_GAP

local Page = {}
Page.__index = Page

function W.NewPage(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -14)
    scroll:SetPoint("BOTTOMRIGHT", -32, 14)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(W.FULL_W, 10)
    scroll:SetScrollChild(content)
    local p = setmetatable({ scroll = scroll, content = content, y = 0, col = 0, rowH = 0, widgets = {} }, Page)
    scroll:Hide()
    return p
end

function Page:Break()
    if self.rowH > 0 then self.y = self.y + self.rowH end
    self.col, self.rowH = 0, 0
end

function Page:Place(f, h, full)
    if full then
        self:Break()
        f:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -self.y)
        self.y = self.y + h
    else
        f:SetPoint("TOPLEFT", self.content, "TOPLEFT", self.col * (COL_W + COL_GAP), -self.y)
        self.rowH = math.max(self.rowH, h)
        if self.col == 0 then self.col = 1 else self:Break() end
    end
    self.content:SetHeight(self.y + self.rowH + 16)
    if f.Refresh then self.widgets[#self.widgets + 1] = f end
    return f
end

function Page:Refresh()
    for _, w in ipairs(self.widgets) do w:Refresh() end
end

function Page:Show() self.scroll:Show(); self:Refresh() end
function Page:Hide() self.scroll:Hide() end

function Page:Header(text)
    self:Break()
    if self.y > 0 then self.y = self.y + 10 end
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(W.FULL_W, 26)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("LEFT")
    t:SetText(text)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 8, 0)
    line:SetPoint("RIGHT")
    return self:Place(f, 30, true)
end

function Page:Text(text, h)
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(W.FULL_W, h or 18)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t:SetPoint("TOPLEFT")
    t:SetWidth(W.FULL_W)
    t:SetJustifyH("LEFT")
    t:SetText(text)
    t:SetTextColor(0.75, 0.75, 0.75)
    f.text = t
    return self:Place(f, (h or 18) + 4, true)
end

function Page:Check(label, get, set, tip)
    local f = CreateFrame("Button", nil, self.content)
    f:SetSize(COL_W, 26)
    local box = CreateFrame("Frame", nil, f, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", 2, 0)
    W.Skin(box, 0.9, 0.35, 0.35, 0.38)
    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    mark:SetPoint("CENTER")
    mark:SetSize(22, 22)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", box, "RIGHT", 8, 0)
    t:SetPoint("RIGHT")
    t:SetJustifyH("LEFT")
    t:SetText(label)
    f.label = t
    f:SetScript("OnClick", function()
        set(not get())
        f:Refresh()
    end)
    f:SetScript("OnEnter", function() box:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    f:SetScript("OnLeave", function() box:SetBackdropBorderColor(0.35, 0.35, 0.38, 1) end)
    Tooltip(f, label, tip)
    function f:Refresh() mark:SetShown(get() and true or false) end
    return self:Place(f, 28)
end

local function FormatNum(v, step)
    if step >= 1 then return tostring(math.floor(v + 0.5)) end
    local s = ("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", "")
    return s
end

function Page:Slider(label, minV, maxV, step, get, set, tip)
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(COL_W, 44)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 2, 0)
    t:SetText(label)

    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(COL_W - 70, 10)
    s:SetPoint("TOPLEFT", 4, -24)
    W.Skin(s, 0.9, 0.3, 0.3, 0.32)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(8, 16)
    thumb:SetVertexColor(1, 0.82, 0, 1)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    s:EnableMouseWheel(true)

    local e = W.EditBox(f, 54, 20)
    e:SetPoint("LEFT", s, "RIGHT", 10, 0)
    e:SetJustifyH("CENTER")

    local function Commit(v)
        v = math.max(minV, math.min(maxV, v))
        v = math.floor(v / step + 0.5) * step
        set(v)
        e:SetText(FormatNum(v, step))
    end
    s:SetScript("OnValueChanged", function(_, v, user)
        if user then Commit(v) end
    end)
    s:SetScript("OnMouseWheel", function(self, delta)
        local v = get() + delta * step
        Commit(v)
        self:SetValue(get())
    end)
    e:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then Commit(v) s:SetValue(get()) end
        self:ClearFocus()
    end)
    e:HookScript("OnEditFocusLost", function(self) self:SetText(FormatNum(get(), step)) end)
    Tooltip(s, label, tip)
    function f:Refresh()
        s:SetValue(get())
        if not e:HasFocus() then e:SetText(FormatNum(get(), step)) end
    end
    return self:Place(f, 50)
end

function Page:Dropdown(label, items, get, set, tip)
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(COL_W, 48)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 2, 0)
    t:SetText(label)
    local b = W.DropButton(f, COL_W - 16, items, get, set)
    b:SetPoint("TOPLEFT", 2, -18)
    Tooltip(b, label, tip)
    function f:Refresh() b:Refresh() end
    return self:Place(f, 52)
end

function W.ColorSwatch(parent, get, set)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(22, 22)
    W.Skin(b, 1, 0.4, 0.4, 0.42)
    local tex = b:CreateTexture(nil, "OVERLAY")
    tex:SetPoint("TOPLEFT", 3, -3)
    tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetColorTexture(1, 1, 1)
    b:SetScript("OnClick", function()
        local c = get()
        local prev = { r = c.r, g = c.g, b = c.b }
        local function Apply(r, g, bl)
            set({ r = r, g = g, b = bl })
            b:Refresh()
        end
        local info = {
            r = c.r, g = c.g, b = c.b, hasOpacity = false,
            swatchFunc = function() Apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function() Apply(prev.r, prev.g, prev.b) end,
        }
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow(info)
        else
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = info.swatchFunc, info.cancelFunc
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)
            ColorPickerFrame:Show()
        end
    end)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.82, 0, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.4, 0.4, 0.42, 1) end)
    function b:Refresh()
        local c = get()
        tex:SetColorTexture(c.r, c.g, c.b)
    end
    return b
end

function Page:Color(label, get, set, tip)
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(COL_W, 28)
    local sw = W.ColorSwatch(f, get, set)
    sw:SetPoint("LEFT", 0, 0)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    t:SetText(label)
    Tooltip(sw, label, tip)
    function f:Refresh() sw:Refresh() end
    return self:Place(f, 30)
end

function Page:Input(label, get, set, tip, full)
    local width = full and W.FULL_W or COL_W
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(width, 48)
    local t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("TOPLEFT", 2, 0)
    t:SetText(label)
    local e = W.EditBox(f, width - 16, 22)
    e:SetPoint("TOPLEFT", 2, -18)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEscapePressed", function(self)
        self.cancel = true
        self:ClearFocus()
    end)
    -- Enter or clicking away applies the text, Escape reverts it.
    e:HookScript("OnEditFocusLost", function(self)
        if self.cancel then
            self.cancel = nil
        elseif self:GetText() ~= (get() or "") then
            set(self:GetText())
        end
        self:SetText(get() or "")
    end)
    Tooltip(e, label, tip)
    f.edit = e
    function f:Refresh()
        if not e:HasFocus() then e:SetText(get() or "") end
    end
    return self:Place(f, 52, full)
end

function Page:Buttons(defs)
    local f = CreateFrame("Frame", nil, self.content)
    f:SetSize(W.FULL_W, 28)
    local x = 0
    for _, d in ipairs(defs) do
        local b = W.Button(f, d[1], d[3] or 130, d[2])
        b:SetPoint("LEFT", x, 0)
        if d[4] then Tooltip(b, d[1], d[4]) end
        x = x + (d[3] or 130) + 8
    end
    return self:Place(f, 34, true)
end
