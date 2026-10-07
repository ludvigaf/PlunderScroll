-------------------------------------------------------------------------------
--  PlunderScroll - Core.lua
--  Namespace, saved settings, loot/money chat parsing and slash commands.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local PS = CreateFrame("Frame")
ns.PS = PS
_G.PlunderScroll = ns

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMeta and GetMeta(ADDON, "Version")) or "1.0.0"

ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
ns.GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant

-------------------------------------------------------------------------------
--  Item qualities
-------------------------------------------------------------------------------
ns.QUALITIES = { 0, 1, 2, 3, 4, 5 } -- the ones the options list
ns.QUALITY_LABELS = {
    [0] = "Trash", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
    [4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom",
}
ns.QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
    [5] = { r = 1.00, g = 0.50, b = 0.00 },
    [6] = { r = 0.90, g = 0.80, b = 0.50 },
    [7] = { r = 0.00, g = 0.80, b = 1.00 },
}

-------------------------------------------------------------------------------
--  Gathering / opening counters, in display order. Each is a session field
--  (session[key]) and a countTypes toggle.
-------------------------------------------------------------------------------
ns.COUNTERS = {
    { key = "chests",     label = "Chests",       desc = "Chests and other lootable objects in the world." },
    { key = "lockboxes",  label = "Lockboxes",    desc = "Lockboxes, junkboxes and locked chests opened from your bags." },
    { key = "containers", label = "Containers",   desc = "Clams, satchels and other items opened from your bags." },
    { key = "herbs",      label = "Herbs",        desc = "Herb nodes gathered." },
    { key = "ore",        label = "Mining nodes", desc = "Mining nodes mined (each node counts once, however many hits it takes)." },
    { key = "gas",        label = "Gas clouds",   desc = "Gas clouds extracted." },
    { key = "skins",      label = "Skinned",      desc = "Beasts skinned." },
    { key = "fish",       label = "Fish caught",  desc = "Fishing catches." },
    { key = "pickpocket", label = "Pickpocketed", desc = "Successful pickpockets." },
    { key = "disenchant", label = "Disenchanted", desc = "Items disenchanted." },
    { key = "prospect",   label = "Prospected",   desc = "Ore prospected." },
    { key = "mill",       label = "Milled",       desc = "Herbs milled." },
}

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
ns.DEFAULTS = {
    enabled = true,
    locked = true,
    loginMessage = true,

    -- What is shown / tracked
    showItems = true,
    showMoney = true,
    includePushed = true,   -- quest rewards and other items received directly
    includeCreated = false, -- crafted / conjured items
    minTrackQuality = 0,
    countTypes = {          -- [counter key] = false stops counting it
        chests = true, lockboxes = true, containers = true, herbs = true, ore = true, gas = true,
        skins = true, fish = true, pickpocket = true, disenchant = true, prospect = true, mill = true,
    },
    qualityShown = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true },
    qualityLabels = {},     -- [quality] = custom label
    qualityColors = {},     -- [quality] = { r, g, b } custom colour

    -- Item line
    itemFormat = "{amount} {icon} {name} {rarity}",
    showAmount = true,
    showSingleAmount = false,
    amountStyle = "SUFFIX_X", -- 5x
    showIcon = true,
    iconSize = 0,             -- 0 = match the text height
    showName = true,
    nameBrackets = false,
    showRarity = false,
    rarityStyle = "BRACKETS",
    showTotal = false,

    -- Money line
    moneyFormat = "{money}",
    moneyStyle = "ICONS",
    coinSize = 0,
    moneyShowZero = false,
    moneySpace = false,

    -- Colours
    colorNameByQuality = true,
    colorRarityByQuality = true,
    textColor = { r = 1, g = 1, b = 1 },
    amountColor = { r = 1, g = 0.82, b = 0 },
    totalColor = { r = 0.65, g = 0.65, b = 0.65 },
    moneyTextColor = { r = 1, g = 1, b = 1 },

    -- Font
    font = "Friz Quadrata TT",
    fontPath = "Fonts\\FRIZQT__.TTF",
    customFonts = {},         -- { { name =, path = }, ... }
    fontSize = 16,
    outline = "OUTLINE",
    shadow = true,

    -- Animation
    mode = "SCROLL",          -- SCROLL | STACK
    direction = "UP",
    justify = "CENTER",
    duration = 4,
    distance = 220,
    fadeTime = 1,
    fadeIn = 0.2,
    spacing = 4,
    maxLines = 15,
    curve = 0,
    mergeWindow = 2,

    -- Session window
    sessionWindow = true,
    swLocked = true,
    swWidth = 260,
    swHeight = 300,
    swScale = 1,
    swStrata = "MEDIUM",
    swBgAlpha = 0.35,
    swBorder = true,
    swFontSize = 12,
    swSpacing = 3,
    swSort = "COUNT",
    swMinQuality = 0,
    swShowIcons = true,
    swColorNames = true,
    swShowTitle = true,
    swShowValue = true,       -- items' total value (best of vendor / auction price) in the heading
    swShowChests = true,
    swPos = { point = "RIGHT", relPoint = "RIGHT", x = -60, y = 120 },

    -- Frame
    width = 360,
    scale = 1,
    alpha = 1,
    strata = "HIGH",
    pos = { point = "CENTER", relPoint = "CENTER", x = 320, y = 40 },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end
ns.CopyDefaults = CopyDefaults

local function InitDB()
    PlunderScrollDB = PlunderScrollDB or {}
    local root = PlunderScrollDB
    root.profile = CopyDefaults(ns.DEFAULTS, root.profile or {})
    root.chars = root.chars or {}
    root.nextSessionId = root.nextSessionId or 0
    ns.root = root
    ns.db = root.profile
end

function ns.ResetSettings()
    PlunderScrollDB.profile = CopyDefaults(ns.DEFAULTS, {})
    ns.db = PlunderScrollDB.profile
    ns.RefreshAll()
end

function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = msg:format(...) end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Plunder|rScroll: " .. msg)
end

-- Re-applies every setting to the display and any open settings page.
function ns.RefreshAll()
    if ns.Display and ns.Display.ApplyStyle then ns.Display:ApplyStyle() end
    if ns.SessionWindow and ns.SessionWindow.ApplyStyle then ns.SessionWindow:ApplyStyle() end
    if ns.Options and ns.Options.Refresh then ns.Options:Refresh() end
end

-- Tracked data changed (loot, new session, rename ...).
function ns.FireUpdate()
    if ns.History and ns.History.OnDataChanged then ns.History:OnDataChanged() end
    if ns.SessionWindow and ns.SessionWindow.OnDataChanged then ns.SessionWindow:OnDataChanged() end
    if ns.Options and ns.Options.OnDataChanged then ns.Options:OnDataChanged() end
end

-------------------------------------------------------------------------------
--  Chat line matching (uses the client's own localised format strings)
-------------------------------------------------------------------------------
local function Compile(fmt, anchored)
    local parts, i, first = {}, 1, nil
    while true do
        local s, e, pos, kind = fmt:find("%%(%d?)%$?([sd])", i)
        parts[#parts + 1] = (fmt:sub(i, s and s - 1):gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0"))
        if not s then break end
        first = first or tonumber(pos)
        parts[#parts + 1] = kind == "d" and "(%d+)" or "(.-)"
        i = e + 1
    end
    local p = table.concat(parts)
    return { pat = anchored and ("^" .. p .. "$") or p, swap = first == 2 }
end

local compiled = {}
local function Match(key, text, loose)
    local id = loose and (key .. "~") or key
    local c = compiled[id]
    if c == nil then
        local fmt = _G[key]
        c = type(fmt) == "string" and fmt ~= "" and Compile(fmt, not loose) or false
        compiled[id] = c
    end
    if not c then return end
    local a, b = text:match(c.pat)
    if c.swap then return b, a end
    return a, b
end
ns.Match = Match

-- Own loot only. Multiple-item formats first: the single ones match them too.
local ITEM_KEYS = {
    { key = "LOOT_ITEM_SELF_MULTIPLE" },
    { key = "LOOT_ITEM_SELF" },
    { key = "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE" },
    { key = "LOOT_ITEM_BONUS_ROLL_SELF" },
    { key = "LOOT_ITEM_PUSHED_SELF_MULTIPLE", kind = "pushed" },
    { key = "LOOT_ITEM_PUSHED_SELF", kind = "pushed" },
    { key = "LOOT_ITEM_CREATED_SELF_MULTIPLE", kind = "created" },
    { key = "LOOT_ITEM_CREATED_SELF", kind = "created" },
}

local MONEY_KEYS = { "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT", "YOU_LOOT_MONEY_GUILD", "LOOT_MONEY_SPLIT_GUILD" }
local COIN_KEYS = { { "GOLD_AMOUNT", 10000 }, { "SILVER_AMOUNT", 100 }, { "COPPER_AMOUNT", 1 } }

local function ParseCoins(text)
    local copper = 0
    for _, c in ipairs(COIN_KEYS) do
        local n = Match(c[1], text, true)
        if n then copper = copper + (tonumber(n) or 0) * c[2] end
    end
    return copper
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

-- Item string field 7 is the random suffix ("of the Monkey"); same item id,
-- different item, so it is part of the tracking key.
local function ItemKey(link)
    local itemString = link:match("|Hitem:([^|]+)|h") or link:match("item:([%-%d:]+)")
    if not itemString then return end
    local fields = { strsplit(":", itemString) }
    local id = tonumber(fields[1])
    if not id then return end
    local suffix = tonumber(fields[7])
    if suffix and suffix ~= 0 then return id .. ":" .. suffix, id end
    return tostring(id), id
end
ns.ItemKey = ItemKey

-- Name, quality and icon of link; calls back once the item is cached.
local function ResolveItem(link, id, callback)
    local name, _, quality, _, _, _, _, _, _, icon = ns.GetItemInfo(link)
    if name then return callback(name, quality or 1, icon) end
    local function Fallback()
        local n, _, q, _, _, _, _, _, _, i = ns.GetItemInfo(link)
        local instIcon = select(5, ns.GetItemInfoInstant(id))
        callback(n or link:match("%[(.-)%]") or ("item:" .. id), q or 1, i or instIcon or 134400)
    end
    if Item and Item.CreateFromItemLink then
        local item = Item:CreateFromItemLink(link)
        if item and not item:IsItemEmpty() then
            item:ContinueOnItemLoad(Fallback)
            return
        end
    end
    Fallback()
end

function ns.HandleItem(link, amount)
    local key, id = ItemKey(link)
    if not key then return end
    ResolveItem(link, id, function(name, quality, icon)
        local db = ns.db
        local total
        if quality >= (db.minTrackQuality or 0) then
            total = ns.Tracker:AddItem(key, id, link, name, quality, icon, amount)
        end
        if db.showItems and db.qualityShown[quality] ~= false then
            ns.Display:Push("item:" .. key, {
                kind = "item", link = link, name = name, quality = quality, icon = icon,
                amount = amount, total = total,
            })
        end
    end)
end

function ns.HandleMoney(copper)
    local total = ns.Tracker:AddMoney(copper)
    if ns.db.showMoney then
        ns.Display:Push("money", { kind = "money", amount = copper, total = total })
    end
end

local function OnLootMessage(text)
    for _, entry in ipairs(ITEM_KEYS) do
        local link, count = Match(entry.key, text)
        if link then
            if not link:find("|Hitem:", 1, true) then return end
            if entry.kind == "pushed" and not ns.db.includePushed then return end
            if entry.kind == "created" and not ns.db.includeCreated then return end
            ns.HandleItem(link, tonumber(count) or 1)
            return
        end
    end
end

local function OnMoneyMessage(text)
    local own
    local anyKnown = false
    for _, key in ipairs(MONEY_KEYS) do
        if type(_G[key]) == "string" then anyKnown = true end
        local m = Match(key, text)
        if m then own = m break end
    end
    if not own then
        if anyKnown then return end -- someone else's money line
        own = text
    end
    local copper = ParseCoins(own)
    if copper > 0 then ns.HandleMoney(copper) end
end

-------------------------------------------------------------------------------
--  Gathering / opening counts (ns.COUNTERS). A loot window is classified by
--  the player's last spell (within 5s) and its loot source: a gathering spell
--  names the counter; without one, a game object is a chest and an item from
--  the bags a lockbox (by item ID, or by name as a fallback) or a container.
--  The loot events fire several times per window, so each window counts once.
--  World sources (nodes, chests, corpses) also count once per GUID for 10
--  minutes, since they can be looted again (a mining node takes several hits).
-------------------------------------------------------------------------------
local LOCKBOX_IDS = {
    [4632] = true, [4633] = true, [4634] = true, [4636] = true, [4637] = true, [4638] = true, -- bronze .. reinforced steel
    [5758] = true, [5759] = true, [5760] = true,                                            -- mithril, thorium, eternium
    [6354] = true, [6355] = true, [13875] = true, [13918] = true,                           -- locked chests
    [16882] = true, [16883] = true, [16884] = true, [16885] = true,                         -- junkboxes
    [29569] = true, [31952] = true, [43575] = true, [43622] = true, [43624] = true,          -- later expansions
}
local LOCKBOX_NAMES = { "lockbox", "lock box", "junkbox", "locked chest" }

local function IsLockbox(itemID)
    if not itemID then return false end
    if LOCKBOX_IDS[itemID] then return true end
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
        or (ns.GetItemInfo(itemID))
    if type(name) ~= "string" then return false end
    name = name:lower()
    for _, pattern in ipairs(LOCKBOX_NAMES) do
        if name:find(pattern, 1, true) then return true end
    end
    return false
end

local function ItemIDFromGUID(guid)
    if C_Item and C_Item.GetItemIDByGUID then
        local ok, id = pcall(C_Item.GetItemIDByGUID, guid)
        if ok and type(id) == "number" then return id end
    end
end

-- Spell IDs per counter (all ranks / expansions); also matched by localized
-- name, so ranks missing here still count.
local GATHER_SPELLS = {
    herbs      = { 2366, 2368, 3570, 11993, 28695, 50300 },        -- Herb Gathering
    ore        = { 2575, 2576, 3564, 10248, 29354, 32606, 50310 }, -- Mining
    skins      = { 8613, 8617, 8618, 10768, 32678, 50305 },        -- Skinning
    gas        = { 30427 },                                        -- Extract Gas
    fish       = { 7620, 7731, 7732, 18248, 33095, 51294 },        -- Fishing
    pickpocket = { 921 },                                          -- Pick Pocket
    disenchant = { 13262 },
    prospect   = { 31252 },
    mill       = { 51005 },
}
-- Counted when the cast succeeds: the gas goes straight to the bags.
local COUNT_ON_CAST = { gas = true }

local spellCategory -- spell ID / localized name -> counter key
local lastSpell, lastSpellName, lastSpellTime = nil, nil, 0
local spellUsed = -1         -- lastSpellTime of the cast that was already counted
local windowCounted = false  -- the open loot window was already counted
local countedSources = {}    -- counter key .. guid -> GetTime() when counted
local RECOUNT_AFTER = 600

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id))
end

local function SpellCategory(id, name)
    if not spellCategory then
        spellCategory = {}
        for cat, ids in pairs(GATHER_SPELLS) do
            for _, sid in ipairs(ids) do
                spellCategory[sid] = cat
                local n = SpellName(sid)
                if n then spellCategory[n] = cat end
            end
        end
    end
    return (id and spellCategory[id]) or (name and spellCategory[name]) or nil
end

local function Count(key)
    if ns.db.countTypes[key] == false then return end
    ns.Tracker:AddCount(key)
end

local function OnSpellSucceeded(spellID)
    if IsSecret(spellID) or type(spellID) ~= "number" then return end
    lastSpell, lastSpellName, lastSpellTime = spellID, SpellName(spellID), GetTime()
    local cat = SpellCategory(lastSpell, lastSpellName)
    if cat and COUNT_ON_CAST[cat] then
        spellUsed = lastSpellTime
        Count(cat)
    end
end

local function LootSource()
    for slot = 1, GetNumLootItems() do
        local guid = GetLootSourceInfo(slot)
        if guid and not IsSecret(guid) and type(guid) == "string" then
            return guid, guid:match("^(%a+)%-")
        end
    end
end

local function OnLootWindow()
    if windowCounted or not GetLootSourceInfo or not GetNumLootItems then return end
    local now = GetTime()
    local guid, kind = LootSource()
    -- A cast that already produced a count doesn't classify later windows.
    local spellCat = now - lastSpellTime < 5 and spellUsed ~= lastSpellTime
        and SpellCategory(lastSpell, lastSpellName)
    local cat
    if IsFishingLoot and IsFishingLoot() then
        cat = "fish"
    elseif spellCat then
        cat = spellCat
    elseif kind == "GameObject" then
        cat = "chests"
    elseif kind == "Item" then
        cat = IsLockbox(ItemIDFromGUID(guid)) and "lockboxes" or "containers"
    end
    if not cat then return end -- ordinary corpse loot
    windowCounted = true
    if spellCat then spellUsed = lastSpellTime end
    if guid and (kind == "GameObject" or kind == "Creature" or cat == "lockboxes") then
        local id = cat .. guid
        local seen = countedSources[id]
        if seen and now - seen < RECOUNT_AFTER then return end
        countedSources[id] = now
    end
    Count(cat)
end

-------------------------------------------------------------------------------
--  Test loot (display only, never tracked)
-------------------------------------------------------------------------------
ns.SAMPLES = {
    { id = 4865, name = "Ruined Pelt", quality = 0, amount = 3, total = 11 },
    { id = 14047, name = "Runecloth", quality = 1, amount = 6, total = 48 },
    { id = 13468, name = "Black Lotus", quality = 2, amount = 1, total = 2 },
    { id = 13340, name = "Cape of the Black Baron", quality = 3, amount = 1, total = 1 },
    { id = 12640, name = "Lionheart Helm", quality = 4, amount = 1, total = 1 },
    { id = 19019, name = "Thunderfury, Blessed Blade of the Windseeker", quality = 5, amount = 1, total = 1 },
}

function ns.SampleData(i)
    local s = ns.SAMPLES[i]
    local icon = select(5, ns.GetItemInfoInstant(s.id)) or 134400
    return { kind = "item", name = s.name, quality = s.quality, icon = icon, amount = s.amount, total = s.total,
        link = "item:" .. s.id }
end

function ns.Test()
    local d = ns.Display
    local n = #ns.SAMPLES
    for i = 1, n do
        C_Timer.After((i - 1) * 0.35, function() d:Push(nil, ns.SampleData(i)) end)
    end
    C_Timer.After(n * 0.35, function() d:Push(nil, { kind = "money", amount = 101010, total = 1234567 }) end)
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
PS:RegisterEvent("ADDON_LOADED")
PS:RegisterEvent("PLAYER_LOGIN")
PS:RegisterEvent("PLAYER_LOGOUT")
PS:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        ns.Tracker:Init()
        ns.Fonts:Init()
        ns.Display:Init()
        ns.SessionWindow:Init()
        ns.Options:Init()
        ns.InitLauncher()
        self:RegisterEvent("CHAT_MSG_LOOT")
        self:RegisterEvent("CHAT_MSG_MONEY")
        self:RegisterEvent("LOOT_READY")
        self:RegisterEvent("LOOT_OPENED")
        self:RegisterEvent("LOOT_CLOSED")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        if ns.db.loginMessage then
            local cur = ns.Tracker:Current()
            ns.Print("v%s loaded. Session |cffffffff%s|r is active (%s). Type |cffffd100/ps|r for options.",
                ns.version, cur.name, ns.Format.MoneyPlain(cur.money))
        end
    elseif event == "PLAYER_LOGOUT" then
        ns.Tracker:CommitPlayTime()
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        OnLootWindow()
    elseif event == "LOOT_CLOSED" then
        windowCounted = false
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnSpellSucceeded(select(3, ...))
    elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_MONEY" then
        local text = ...
        if IsSecret(text) or type(text) ~= "string" then return end
        if event == "CHAT_MSG_LOOT" then OnLootMessage(text) else OnMoneyMessage(text) end
    end
end)

-------------------------------------------------------------------------------
--  Launchers: addon compartment and LibDataBroker
-------------------------------------------------------------------------------
local function LauncherClick(button)
    if button == "RightButton" or IsShiftKeyDown() then ns.History:Toggle() else ns.Options:Toggle() end
end

local function LauncherTooltip(tt)
    local cur = ns.Tracker:Current()
    tt:AddLine("|cffffd100Plunder|rScroll")
    if cur then
        tt:AddDoubleLine("Session", cur.name, 1, 0.82, 0, 1, 1, 1)
        tt:AddDoubleLine("Money looted", ns.Format.Money(cur.money, "ICONS", 0, false, true), 1, 0.82, 0, 1, 1, 1)
        tt:AddDoubleLine("Items looted", cur.itemTotal, 1, 0.82, 0, 1, 1, 1)
    end
    tt:AddLine(" ")
    tt:AddLine("|cffffffffLeft-click|r options, |cffffffffRight-click|r history", 0.7, 0.7, 0.7)
end

function PlunderScroll_OnAddonCompartmentClick(_, button) LauncherClick(button) end
function PlunderScroll_OnAddonCompartmentEnter(_, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    LauncherTooltip(GameTooltip)
    GameTooltip:Show()
end
function PlunderScroll_OnAddonCompartmentLeave() GameTooltip:Hide() end

function ns.InitLauncher()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB or LDB:GetDataObjectByName("PlunderScroll") then return end
    LDB:NewDataObject("PlunderScroll", {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Bag_10",
        OnClick = function(_, button) LauncherClick(button) end,
        OnTooltipShow = LauncherTooltip,
    })
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
local HELP = {
    "|cffffd100/ps|r - open options",
    "|cffffd100/ps history|r - open the session history",
    "|cffffd100/ps new [name]|r - archive the current session and start a new one",
    "|cffffd100/ps stats|r - print the current session totals",
    "|cffffd100/ps window|r - toggle the session window",
    "|cffffd100/ps test|r - show sample loot",
    "|cffffd100/ps lock|r / |cffffd100unlock|r - lock or move the scroll area",
    "|cffffd100/ps reset|r - reset the scroll area position",
}

SLASH_PLUNDERSCROLL1 = "/ps"
SLASH_PLUNDERSCROLL2 = "/plunder"
SLASH_PLUNDERSCROLL3 = "/plunderscroll"
SlashCmdList.PLUNDERSCROLL = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "" or cmd == "options" or cmd == "config" then
        ns.Options:Toggle()
    elseif cmd == "history" or cmd == "h" then
        ns.History:Toggle()
    elseif cmd == "new" then
        ns.Tracker:StartNew(rest ~= "" and rest or nil)
    elseif cmd == "stats" then
        local cur = ns.Tracker:Current()
        local opened = ns.Format.CountsText(cur, ", ")
        ns.Print("|cffffffff%s|r: %s money, %d items (%d unique)%s, %s played.", cur.name,
            ns.Format.Money(cur.money, "ICONS", 0, false, true), cur.itemTotal, ns.Tracker:UniqueCount(cur),
            opened ~= "" and (", " .. opened) or "",
            ns.Format.Duration(ns.Tracker:PlayTime(cur)))
    elseif cmd == "window" or cmd == "w" then
        ns.SessionWindow:Toggle()
    elseif cmd == "test" then
        ns.Test()
    elseif cmd == "lock" or cmd == "unlock" then
        ns.db.locked = cmd == "lock"
        ns.RefreshAll()
        ns.Print(ns.db.locked and "Scroll area locked." or "Scroll area unlocked - drag it to move.")
    elseif cmd == "reset" then
        ns.db.pos = CopyDefaults(ns.DEFAULTS.pos, {})
        ns.RefreshAll()
    else
        for _, line in ipairs(HELP) do ns.Print(line) end
    end
end
