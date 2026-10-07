-------------------------------------------------------------------------------
--  PlunderScroll - Format.lua
--  Builds the text of item and money lines from the user's templates.
-------------------------------------------------------------------------------
local _, ns = ...

local F = {}
ns.Format = F

local floor = math.floor

local COIN_ICONS = {
    "Interface\\MoneyFrame\\UI-GoldIcon",
    "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon",
}
local COIN_LETTERS = { "g", "s", "c" }
local COIN_COLORS = { "ffffd700", "ffc7c7cf", "ffeda55f" }
local MONEY_BAG = "Interface\\Icons\\INV_Misc_Coin_01"

function F.Hex(c)
    return ("ff%02x%02x%02x"):format(floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5))
end

function F.Colorize(text, c)
    return "|c" .. F.Hex(c) .. text .. "|r"
end

function F.QualityColor(q)
    return ns.db.qualityColors[q] or ns.QUALITY_COLORS[q] or ns.QUALITY_COLORS[1]
end

function F.QualityLabel(q)
    local custom = ns.db.qualityLabels[q]
    if custom and custom ~= "" then return custom end
    return ns.QUALITY_LABELS[q] or "?"
end

function F.Icon(texture, size)
    size = size or 0
    return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(texture or 134400), size, size)
end

local function Group(n)
    if n >= 1000 and BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    return tostring(n)
end

-- copper as 10g10s10c. style ICONS or LETTERS, size of coin icons (0 =
-- text height), showZero keeps empty middle/trailing coins, space separates
-- the coins, numColor colours the numbers (a {r,g,b} table or nil).
function F.Money(copper, style, size, showZero, space, numColor)
    copper = floor(copper or 0)
    local values = { floor(copper / 10000), floor((copper % 10000) / 100), copper % 100 }
    local parts = {}
    for i = 1, 3 do
        local v = values[i]
        local higher = (i > 1 and values[1] > 0) or (i > 2 and values[2] > 0)
        if v > 0 or (showZero and higher) or (i == 3 and #parts == 0) then
            local num = Group(v)
            if numColor then num = F.Colorize(num, numColor) end
            if style == "LETTERS" then
                parts[#parts + 1] = num .. "|c" .. COIN_COLORS[i] .. COIN_LETTERS[i] .. "|r"
            else
                parts[#parts + 1] = ("%s|T%s:%d:%d:2:0|t"):format(num, COIN_ICONS[i], size or 0, size or 0)
            end
        end
    end
    return table.concat(parts, space and " " or "")
end

-- Plain-text money for chat and exports: 10g 10s 10c.
function F.MoneyPlain(copper)
    copper = floor(copper or 0)
    local g, s, c = floor(copper / 10000), floor((copper % 10000) / 100), copper % 100
    if g > 0 then return ("%sg %ds %dc"):format(Group(g), s, c) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return c .. "c"
end

-- Money with the current display settings.
function F.MoneyStyled(copper)
    local db = ns.db
    return F.Money(copper, db.moneyStyle, db.coinSize, db.moneyShowZero, db.moneySpace, db.moneyTextColor)
end

-- "Chests: 3<sep>Herbs: 12 ...", leaving out counts of 0 ("" when all are 0).
-- label wraps each label (e.g. in a colour code).
function F.CountsText(s, sep, label)
    label = label or "%s"
    local parts = {}
    for _, c in ipairs(ns.COUNTERS) do
        local n = s[c.key] or 0
        if n > 0 then parts[#parts + 1] = label:format(c.label .. ":") .. " " .. n end
    end
    return table.concat(parts, sep or "  ")
end

function F.Duration(seconds)
    seconds = floor(seconds or 0)
    local h, m = floor(seconds / 3600), floor((seconds % 3600) / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    if m > 0 then return ("%dm %02ds"):format(m, seconds % 60) end
    return seconds .. "s"
end

local AMOUNT_STYLES = {
    SUFFIX_X = "%dx",
    PREFIX_X = "x%d",
    PLUS = "+%d",
    PLAIN = "%d",
}
F.AMOUNT_STYLES = AMOUNT_STYLES

local RARITY_STYLES = {
    BRACKETS = "[%s]",
    PARENS = "(%s)",
    PLAIN = "%s",
    DASH = "- %s",
}
F.RARITY_STYLES = RARITY_STYLES

local function Fill(template, parts)
    local out = template:gsub("{(%a+)}", function(k) return parts[k:lower()] or "" end)
    out = out:gsub("  +", " ")
    out = out:gsub("^%s+", "")
    out = out:gsub("%s+$", "")
    return out
end

function F.RarityText(q)
    local db = ns.db
    local label = (RARITY_STYLES[db.rarityStyle] or "%s"):format(F.QualityLabel(q))
    return F.Colorize(label, db.colorRarityByQuality and F.QualityColor(q) or db.textColor)
end

function F.ItemLine(d)
    local db = ns.db
    local q = d.quality or 1
    local parts = {}
    if db.showIcon then parts.icon = F.Icon(d.icon, db.iconSize) end
    if db.showAmount and (d.amount > 1 or db.showSingleAmount) then
        parts.amount = F.Colorize((AMOUNT_STYLES[db.amountStyle] or "%dx"):format(d.amount), db.amountColor)
    end
    if db.showName then
        local name = d.name or "?"
        if db.nameBrackets then name = "[" .. name .. "]" end
        parts.name = F.Colorize(name, db.colorNameByQuality and F.QualityColor(q) or db.textColor)
    end
    if db.showRarity then parts.rarity = F.RarityText(q) end
    if db.showTotal and d.total then
        parts.total = F.Colorize("(" .. d.total .. ")", db.totalColor)
    end
    return Fill(db.itemFormat, parts)
end

function F.MoneyLine(d)
    local db = ns.db
    local parts = {
        money = F.MoneyStyled(d.amount),
        icon = F.Icon(MONEY_BAG, db.iconSize),
    }
    if d.total then
        parts.total = F.Colorize("(", db.totalColor) .. F.MoneyStyled(d.total) .. F.Colorize(")", db.totalColor)
    end
    return Fill(db.moneyFormat, parts)
end

function F.Line(d)
    if d.kind == "money" then return F.MoneyLine(d) end
    return F.ItemLine(d)
end
