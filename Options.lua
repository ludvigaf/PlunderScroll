-------------------------------------------------------------------------------
--  PlunderScroll - Options.lua
-------------------------------------------------------------------------------
local _, ns = ...

local O = {}
ns.Options = O

local W = ns.W
local frame, pages, tabs, current = nil, {}, {}, nil

local function G(key) return function() return ns.db[key] end end
local function S(key) return function(v) ns.db[key] = v; ns.RefreshAll() end end

local function Choices(...)
    local out = {}
    for i = 1, select("#", ...), 2 do
        out[#out + 1] = { value = select(i, ...), text = select(i + 1, ...) }
    end
    return out
end

local QUALITY_CHOICES = function()
    local out = {}
    for _, q in ipairs(ns.QUALITIES) do
        out[#out + 1] = { value = q, text = ns.Format.Colorize(ns.Format.QualityLabel(q), ns.Format.QualityColor(q)) }
    end
    return out
end

local function FontChoices()
    local out = {}
    for _, f in ipairs(ns.Fonts:GetList()) do
        out[#out + 1] = { value = f.name, text = f.name .. "  |cff888888" .. f.source .. "|r", font = f.path }
    end
    return out
end

-------------------------------------------------------------------------------
--  Live preview box
-------------------------------------------------------------------------------
local function AddPreview(page)
    local f = CreateFrame("Frame", nil, page.content, "BackdropTemplate")
    f:SetSize(W.FULL_W, 150)
    W.Skin(f, 0.7, 0.2, 0.2, 0.22)
    f:SetClipsChildren(true)
    local tag = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tag:SetPoint("TOPRIGHT", -6, -4)
    tag:SetText("Preview")
    local lines = {}
    for i = 1, 5 do
        lines[i] = f:CreateFontString(nil, "OVERLAY")
        lines[i]:SetWordWrap(false)
    end
    local samples = { 2, 3, 4, 6 }
    function f:Refresh()
        local db = ns.db
        local y = 10
        for i = 1, 5 do
            local fs = lines[i]
            local d = samples[i] and ns.SampleData(samples[i]) or { kind = "money", amount = 101010, total = 1234567 }
            ns.Fonts:Apply(fs, db.fontSize)
            fs:SetTextColor(db.textColor.r, db.textColor.g, db.textColor.b)
            fs:SetText(ns.Format.Line(d))
            fs:ClearAllPoints()
            local point = db.justify == "LEFT" and "TOPLEFT" or db.justify == "RIGHT" and "TOPRIGHT" or "TOP"
            local x = db.justify == "LEFT" and 10 or db.justify == "RIGHT" and -10 or 0
            fs:SetPoint(point, f, point, x, -y)
            y = y + math.max(fs:GetStringHeight(), db.fontSize, db.showIcon and db.iconSize or 0) + db.spacing
        end
    end
    page:Place(f, 160, true)
    return f
end

-------------------------------------------------------------------------------
--  Pages
-------------------------------------------------------------------------------
local function BuildGeneral(p)
    p:Header("General")
    p:Check("Enable PlunderScroll", G("enabled"), S("enabled"), "Show the scrolling loot text. Tracking continues while disabled.")
    p:Check("Lock scroll area", G("locked"), S("locked"), "Unlock to drag the scroll area around the screen.")
    p:Check("Show looted items", G("showItems"), S("showItems"))
    p:Check("Show looted money", G("showMoney"), S("showMoney"))
    p:Check("Include quest rewards / received items", G("includePushed"), S("includePushed"),
        "Items put straight into your bags (quest rewards, mail-less pushes). Affects both the display and tracking.")
    p:Check("Include crafted / created items", G("includeCreated"), S("includeCreated"),
        "Items you create (crafting, conjuring). Affects both the display and tracking.")
    p:Check("Login message", G("loginMessage"), S("loginMessage"))
    p:Buttons({
        { "Test", function() ns.Test() end, 100, "Show sample loot in the scroll area." },
        { "Toggle Lock", function() ns.db.locked = not ns.db.locked; ns.RefreshAll() end, 110 },
        { "Reset Position", function() ns.db.pos = ns.CopyDefaults(ns.DEFAULTS.pos, {}); ns.RefreshAll() end, 120 },
        { "History", function() ns.History:Show() end, 100 },
    })

    p:Header("Frame")
    p:Slider("Width", 100, 1200, 10, G("width"), S("width"))
    p:Slider("Scale", 0.5, 2.5, 0.05, G("scale"), S("scale"))
    p:Slider("Opacity", 0.1, 1, 0.05, G("alpha"), S("alpha"))
    p:Dropdown("Frame strata", Choices("BACKGROUND", "Background", "LOW", "Low", "MEDIUM", "Medium", "HIGH", "High",
        "DIALOG", "Dialog", "TOOLTIP", "Tooltip"), G("strata"), S("strata"))

    p:Header("Reset")
    p:Buttons({
        { "Reset All Settings", function() StaticPopup_Show("PLUNDERSCROLL_RESET_SETTINGS") end, 160,
            "Restores every display setting. Loot sessions are not touched." },
    })
end

local function BuildText(p)
    AddPreview(p)
    p:Header("Item line")
    p:Input("Item line template", G("itemFormat"), S("itemFormat"),
        "Tokens: {amount} {icon} {name} {rarity} {total}. Anything else is shown as typed. Press Enter to apply.", true)
    p:Text("Tokens: |cffffd100{amount}|r  |cffffd100{icon}|r  |cffffd100{name}|r  |cffffd100{rarity}|r  |cffffd100{total}|r (session total of that item)")
    p:Check("Show amount", G("showAmount"), S("showAmount"))
    p:Check("Show amount for single items", G("showSingleAmount"), S("showSingleAmount"), "Show \"1x\" when one item is looted.")
    p:Dropdown("Amount style", Choices("SUFFIX_X", "5x", "PREFIX_X", "x5", "PLUS", "+5", "PLAIN", "5"),
        G("amountStyle"), S("amountStyle"))
    p:Check("Show item icon", G("showIcon"), S("showIcon"))
    p:Slider("Icon size (0 = text height)", 0, 64, 1, G("iconSize"), S("iconSize"))
    p:Check("Show item name", G("showName"), S("showName"))
    p:Check("Brackets around name", G("nameBrackets"), S("nameBrackets"))
    p:Check("Show rarity", G("showRarity"), S("showRarity"))
    p:Dropdown("Rarity style", Choices("BRACKETS", "[Epic]", "PARENS", "(Epic)", "PLAIN", "Epic", "DASH", "- Epic"),
        G("rarityStyle"), S("rarityStyle"))
    p:Check("Show session total", G("showTotal"), S("showTotal"), "How many of that item you have looted this session.")

    p:Header("Money line")
    p:Input("Money line template", G("moneyFormat"), S("moneyFormat"),
        "Tokens: {money} {total} {icon}. Press Enter to apply.", true)
    p:Text("Tokens: |cffffd100{money}|r  |cffffd100{total}|r (session money)  |cffffd100{icon}|r (coin bag)")
    p:Dropdown("Coin style", Choices("ICONS", "10[g]10[s]10[c] - coin icons", "LETTERS", "10g10s10c - letters"),
        G("moneyStyle"), S("moneyStyle"))
    p:Slider("Coin icon size (0 = text height)", 0, 48, 1, G("coinSize"), S("coinSize"))
    p:Check("Show empty coins (1g0s5c)", G("moneyShowZero"), S("moneyShowZero"))
    p:Check("Space between coins", G("moneySpace"), S("moneySpace"))
end

local function BuildFont(p)
    AddPreview(p)
    p:Header("Font")
    p:Dropdown("Font", FontChoices, G("font"), function(v) ns.Fonts:Select(v) end,
        "Fonts from the game, LibSharedMedia (EllesmereUI, ElvUI, SharedMedia, Details!, Plater, ...) and your custom fonts.")
    p:Slider("Font size", 6, 64, 1, G("fontSize"), S("fontSize"))
    p:Dropdown("Outline", Choices("NONE", "None", "OUTLINE", "Outline", "THICKOUTLINE", "Thick outline",
        "MONOCHROME", "Monochrome", "OUTLINE, MONOCHROME", "Outline + monochrome"), G("outline"), S("outline"))
    p:Check("Text shadow", G("shadow"), S("shadow"))

    p:Header("Add a font by path")
    local nameField, pathField
    pathField = p:Input("Font file path", function() return O.newPath or "" end, function(v) O.newPath = v end,
        "For example: Interface\\AddOns\\MyMedia\\fonts\\MyFont.ttf", true)
    nameField = p:Input("Display name (optional)", function() return O.newName or "" end, function(v) O.newName = v end)
    pathField.edit:HookScript("OnTextChanged", function(self, user) if user then O.newPath = self:GetText() end end)
    nameField.edit:HookScript("OnTextChanged", function(self, user) if user then O.newName = self:GetText() end end)
    p:Buttons({
        { "Add Font", function()
            O.newPath = pathField.edit:GetText()
            O.newName = nameField.edit:GetText()
            local ok, res = ns.Fonts:AddCustom(O.newName, O.newPath)
            if ok then
                ns.Print("Added font |cffffffff%s|r.", res)
                O.newPath, O.newName = nil, nil
                ns.Fonts:Select(res)
            else
                ns.Print("|cffff4040%s|r", res)
            end
        end, 110 },
        { "Remove Custom Fonts", function() ns.Fonts:ClearCustom(); ns.RefreshAll() end, 160 },
        { "Rescan Fonts", function() ns.Fonts.dirty = true; ns.Fonts:GetList(); ns.Print("%d fonts found.", #ns.Fonts:GetList()) end, 120 },
    })

    p:Header("Colours")
    p:Check("Colour item names by rarity", G("colorNameByQuality"), S("colorNameByQuality"))
    p:Check("Colour rarity text by rarity", G("colorRarityByQuality"), S("colorRarityByQuality"))
    p:Color("Text colour", G("textColor"), S("textColor"), "Names (when not coloured by rarity) and template text.")
    p:Color("Amount colour", G("amountColor"), S("amountColor"))
    p:Color("Session total colour", G("totalColor"), S("totalColor"))
    p:Color("Money number colour", G("moneyTextColor"), S("moneyTextColor"))
end

local function BuildRarity(p)
    p:Header("Rarities")
    p:Text("Choose which rarities scroll, their colours and the label shown by {rarity}. Every rarity is still tracked.", 30)
    for _, q in ipairs(ns.QUALITIES) do
        local row = CreateFrame("Frame", nil, p.content)
        row:SetSize(W.FULL_W, 30)
        local check = CreateFrame("Button", nil, row, "BackdropTemplate")
        check:SetSize(18, 18)
        check:SetPoint("LEFT", 2, 0)
        W.Skin(check, 0.9, 0.35, 0.35, 0.38)
        local mark = check:CreateTexture(nil, "OVERLAY")
        mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        mark:SetPoint("CENTER")
        mark:SetSize(22, 22)
        check:SetScript("OnClick", function()
            ns.db.qualityShown[q] = ns.db.qualityShown[q] == false
            ns.RefreshAll()
        end)
        W.Tooltip(check, "Show", "Show this rarity in the scroll area.")

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", check, "RIGHT", 10, 0)
        name:SetWidth(110)
        name:SetJustifyH("LEFT")

        local swatch = W.ColorSwatch(row, function() return ns.Format.QualityColor(q) end, function(c)
            ns.db.qualityColors[q] = c
            ns.RefreshAll()
        end)
        swatch:SetPoint("LEFT", name, "RIGHT", 10, 0)

        local edit = W.EditBox(row, 180, 22)
        edit:SetPoint("LEFT", swatch, "RIGHT", 14, 0)
        edit:SetScript("OnEnterPressed", function(self)
            local t = self:GetText()
            ns.db.qualityLabels[q] = (t ~= "" and t ~= ns.QUALITY_LABELS[q]) and t or nil
            self:ClearFocus()
            ns.RefreshAll()
        end)
        edit:HookScript("OnEditFocusLost", function(self) self:SetText(ns.Format.QualityLabel(q)) end)
        W.Tooltip(edit, "Label", "Text shown by {rarity}. Press Enter to apply.")

        local reset = W.Button(row, "Default", 70, function()
            ns.db.qualityColors[q] = nil
            ns.db.qualityLabels[q] = nil
            ns.RefreshAll()
        end, 22)
        reset:SetPoint("LEFT", edit, "RIGHT", 10, 0)

        function row:Refresh()
            mark:SetShown(ns.db.qualityShown[q] ~= false)
            name:SetText(ns.Format.Colorize(ns.QUALITY_LABELS[q], ns.Format.QualityColor(q)))
            swatch:Refresh()
            if not edit:HasFocus() then edit:SetText(ns.Format.QualityLabel(q)) end
        end
        p:Place(row, 32, true)
    end
end

local function BuildAnimation(p)
    p:Header("Animation")
    p:Dropdown("Mode", Choices("SCROLL", "Scroll - lines travel and fade", "STACK", "Stack - lines pile up and fade"),
        G("mode"), S("mode"))
    p:Dropdown("Direction", Choices("UP", "Up", "DOWN", "Down"), G("direction"), S("direction"))
    p:Dropdown("Text alignment", Choices("LEFT", "Left", "CENTER", "Center", "RIGHT", "Right"), G("justify"), S("justify"))
    p:Slider("Duration (seconds)", 0.5, 20, 0.5, G("duration"), S("duration"),
        "Scroll: time to travel the whole distance. Stack: time before a line fades.")
    p:Slider("Scroll distance", 40, 1000, 10, G("distance"), S("distance"), "Height of the scroll area (scroll mode).")
    p:Slider("Curve", -300, 300, 5, G("curve"), S("curve"), "Bends the scroll path sideways (scroll mode). 0 = straight.")
    p:Slider("Fade out (seconds)", 0, 5, 0.1, G("fadeTime"), S("fadeTime"))
    p:Slider("Fade in (seconds)", 0, 2, 0.05, G("fadeIn"), S("fadeIn"))
    p:Slider("Line spacing", 0, 40, 1, G("spacing"), S("spacing"))
    p:Slider("Max lines", 1, 50, 1, G("maxLines"), S("maxLines"))
    p:Slider("Merge window (seconds)", 0, 10, 0.5, G("mergeWindow"), S("mergeWindow"),
        "Loot of the same item (or money) within this time adds to the line already showing. 0 = off.")
    p:Buttons({ { "Test", function() ns.Test() end, 100 } })
end

local function BuildSessions(p)
    p:Header("Current session")
    local info = p:Text("", 130)
    info.text:SetFontObject("GameFontHighlight")
    function info:Refresh()
        local T, F = ns.Tracker, ns.Format
        local cur = T:Current()
        if not cur then return end
        local played = T:PlayTime(cur)
        local perHour = played > 60 and (cur.money / (played / 3600)) or 0
        local q = {}
        for _, i in ipairs(ns.QUALITIES) do
            q[#q + 1] = F.Colorize(F.QualityLabel(i) .. ": " .. (cur.quality[i] or 0), F.QualityColor(i))
        end
        local lines = {
            "|cffffd100Name:|r " .. cur.name .. "   |cff888888(" .. T.charKey .. ")|r",
            "|cffffd100Started:|r " .. date("%Y-%m-%d %H:%M", cur.started) .. "    |cffffd100Played:|r " .. F.Duration(played),
            "|cffffd100Money:|r " .. F.Money(cur.money, "ICONS", 0, false, true) .. "    |cffffd100Per hour:|r "
                .. F.Money(math.floor(perHour), "ICONS", 0, false, true),
            "|cffffd100Items:|r " .. cur.itemTotal .. " (" .. T:UniqueCount(cur) .. " unique)",
        }
        local counts = F.CountsText(cur, "    ", "|cffffd100%s|r")
        if counts ~= "" then lines[#lines + 1] = counts end
        lines[#lines + 1] = table.concat(q, "   ")
        self.text:SetText(table.concat(lines, "\n"))
    end
    p.widgets[#p.widgets + 1] = info
    p:Buttons({
        { "New Session", function() StaticPopup_Show("PLUNDERSCROLL_NEW_SESSION") end, 130,
            "Archive the current session to History and start counting from zero." },
        { "Open History", function() ns.History:Show() end, 130 },
    })
    p:Text("Your current session is saved between logins and reloads. It only ends when you start a new one; the old session is then kept in History, where you can view, rename, export, resume or delete it.", 44)

    p:Header("Tracking")
    p:Dropdown("Track items of at least", QUALITY_CHOICES, G("minTrackQuality"), S("minTrackQuality"),
        "Lower rarities are not counted in sessions (they may still scroll).")

    p:Header("Gathering & opening")
    p:Text("Count what you gather and open in each session. Unticking stops new counts; counts already in a session are kept.", 30)
    for _, c in ipairs(ns.COUNTERS) do
        p:Check(c.label, function() return ns.db.countTypes[c.key] ~= false end,
            function(v) ns.db.countTypes[c.key] = v; ns.RefreshAll() end, c.desc)
    end
end

local function BuildSessionWindow(p)
    p:Header("Session window")
    p:Text("A see-through window listing everything looted this session with the money total. Right-click it (while unlocked) to open History.", 30)
    p:Check("Show session window", G("sessionWindow"), S("sessionWindow"))
    p:Check("Lock session window", G("swLocked"), S("swLocked"), "Locked: click-through; hold Shift to drag it. Unlocked: drag to move.")
    p:Check("Show heading", G("swShowTitle"), S("swShowTitle"), "\"Current Plunder\" above the list.")
    p:Check("Show item value", G("swShowValue"), S("swShowValue"),
        "Total value of the session's items next to the heading. Each item counts at its vendor price or its auction price (from Auctionator or TradeSkillMaster, if installed), whichever is higher.")
    p:Check("Show gathering & opening counts", G("swShowChests"), S("swShowChests"),
        "Chests, herbs, mining nodes ... shown above the money total once above 0. Choose what is counted on the Sessions page.")
    p:Check("Show item icons", G("swShowIcons"), S("swShowIcons"))
    p:Check("Colour names by rarity", G("swColorNames"), S("swColorNames"))
    p:Check("Show border", G("swBorder"), S("swBorder"))
    p:Dropdown("Sort by", Choices("COUNT", "Amount", "QUALITY", "Rarity", "NAME", "Name", "RECENT", "Last looted"),
        G("swSort"), S("swSort"))
    p:Dropdown("Show items of at least", QUALITY_CHOICES, G("swMinQuality"), S("swMinQuality"))

    p:Header("Look")
    p:Slider("Background opacity", 0, 1, 0.05, G("swBgAlpha"), S("swBgAlpha"), "0 = fully transparent.")
    p:Slider("Width", 120, 1000, 5, G("swWidth"), S("swWidth"), "You can also drag the grip in the window's bottom right corner.")
    p:Slider("Height", 60, 1200, 5, G("swHeight"), S("swHeight"), "You can also drag the grip in the window's bottom right corner. Items that don't fit can be scrolled with the mouse wheel.")
    p:Slider("Font size", 6, 32, 1, G("swFontSize"), S("swFontSize"), "Uses the font chosen on the Font page.")
    p:Slider("Row spacing", 0, 20, 1, G("swSpacing"), S("swSpacing"))
    p:Slider("Scale", 0.5, 2.5, 0.05, G("swScale"), S("swScale"))
    p:Dropdown("Frame strata", Choices("BACKGROUND", "Background", "LOW", "Low", "MEDIUM", "Medium", "HIGH", "High",
        "DIALOG", "Dialog"), G("swStrata"), S("swStrata"))
    p:Buttons({
        { "Reset Position", function() ns.db.swPos = ns.CopyDefaults(ns.DEFAULTS.swPos, {}); ns.RefreshAll() end, 120 },
    })
end

local PAGES = {
    { "General", BuildGeneral },
    { "Text & Format", BuildText },
    { "Font & Colours", BuildFont },
    { "Rarity", BuildRarity },
    { "Animation", BuildAnimation },
    { "Sessions", BuildSessions },
    { "Session Window", BuildSessionWindow },
}

-------------------------------------------------------------------------------
--  Window
-------------------------------------------------------------------------------
local function SelectPage(i)
    for j, pg in ipairs(pages) do
        if j == i then pg:Show() else pg:Hide() end
        tabs[j]:SetBackdropBorderColor(j == i and 1 or 0.3, j == i and 0.82 or 0.3, j == i and 0 or 0.32, 1)
        tabs[j].text:SetTextColor(j == i and 1 or 0.85, j == i and 0.82 or 0.85, j == i and 0 or 0.85)
    end
    current = pages[i]
end

local function Build()
    frame = W.Window("PlunderScrollOptions", "|cffffd100Plunder|rScroll  |cff888888v" .. ns.version .. "|r", 800, 600)

    local side = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 10, -40)
    side:SetPoint("BOTTOMLEFT", 10, 10)
    side:SetWidth(150)
    W.Skin(side, 0.6, 0.15, 0.15, 0.17)

    local body = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    body:SetPoint("TOPLEFT", side, "TOPRIGHT", 8, 0)
    body:SetPoint("BOTTOMRIGHT", -10, 10)
    W.Skin(body, 0.6, 0.15, 0.15, 0.17)

    for i, def in ipairs(PAGES) do
        local tab = W.Button(side, def[1], 134, function() SelectPage(i) end, 28)
        tab:SetPoint("TOP", 0, -8 - (i - 1) * 34)
        tab:SetScript("OnLeave", nil)
        tab:SetScript("OnEnter", nil)
        tabs[i] = tab
        local pg = W.NewPage(body)
        def[2](pg)
        pages[i] = pg
    end
    SelectPage(1)
end

function O:Refresh()
    if frame and frame:IsShown() and current then current:Refresh() end
end

function O:OnDataChanged()
    if frame and frame:IsShown() and current == pages[6] then current:Refresh() end
end

-- pageName (optional) opens that tab, e.g. "Session Window".
function O:Show(pageName)
    if not frame then Build() end
    frame:Show()
    if pageName then
        for i, def in ipairs(PAGES) do
            if def[1] == pageName then SelectPage(i) end
        end
    end
    if current then current:Refresh() end
end

function O:Toggle()
    if frame and frame:IsShown() then frame:Hide() else self:Show() end
end

-------------------------------------------------------------------------------
--  Popups and the game settings entry
-------------------------------------------------------------------------------
local function PopupEdit(self)
    return self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
end
ns.PopupEdit = PopupEdit

function O:Init()
    StaticPopupDialogs.PLUNDERSCROLL_NEW_SESSION = {
        text = "Start a new PlunderScroll session?\n\nThe current session is archived to History.\nName for the new session (optional):",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 64,
        OnShow = function(self) local e = PopupEdit(self); if e then e:SetText(""); e:SetFocus() end end,
        OnAccept = function(self)
            local e = PopupEdit(self)
            local name = e and e:GetText() or ""
            ns.Tracker:StartNew(name ~= "" and name or nil)
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            local name = self:GetText()
            ns.Tracker:StartNew(name ~= "" and name or nil)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.PLUNDERSCROLL_RESET_SETTINGS = {
        text = "Reset all PlunderScroll display settings to their defaults?\n(Loot sessions are kept.)",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        OnAccept = function() ns.ResetSettings() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        panel.name = "PlunderScroll"
        local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 16, -16)
        t:SetText("|cffffd100Plunder|rScroll")
        local b = W.Button(panel, "Open Options", 160, function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            O:Show()
        end, 26)
        b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12)
        local h = W.Button(panel, "Open History", 160, function()
            if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
            ns.History:Show()
        end, 26)
        h:SetPoint("LEFT", b, "RIGHT", 8, 0)
        local category = Settings.RegisterCanvasLayoutCategory(panel, "PlunderScroll")
        Settings.RegisterAddOnCategory(category)
    end
end
