-------------------------------------------------------------------------------
--  PlunderScroll - Tracker.lua
--  Per-character loot sessions. The current session persists across logins
--  and reloads until the user starts a new one; the old one then moves to
--  the character's history.
--
--  PlunderScrollDB.chars["Name-Realm"] = {
--      class = "MAGE",
--      current = session,
--      history = { session, ... },   -- newest first
--  }
--  session = { id, name, char, started, ended, lastActivity, playTime,
--              money, moneyLoots, itemTotal, itemLoots, quality = { [q] = n },
--              items = { [key] = { id, name, quality, icon, link, count, first, last } },
--              chests, lockboxes, herbs, ore, ... }   -- one count per ns.COUNTERS key, nil = 0
-------------------------------------------------------------------------------
local _, ns = ...

local T = {}
ns.Tracker = T

local segmentStart -- GetTime() when the current session's play time was last committed

local function CharKey()
    local name = UnitName("player") or "Unknown"
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("%s", "")
    return name .. "-" .. realm
end

function T:NewSessionTable(name)
    local root = ns.root
    root.nextSessionId = (root.nextSessionId or 0) + 1
    return {
        id = root.nextSessionId,
        name = (name and name ~= "") and name or date("%Y-%m-%d %H:%M"),
        char = self.charKey,
        started = time(),
        playTime = 0,
        money = 0,
        moneyLoots = 0,
        itemTotal = 0,
        itemLoots = 0,
        quality = {},
        items = {},
    }
end

-- Default names used to be "Session <date time>"; they are now just the date
-- and time. Custom names are left alone.
local function StripOldDefaultName(s)
    local stamp = s.name and s.name:match("^Session (%d%d%d%d%-%d%d%-%d%d %d%d:%d%d)$")
    if stamp then s.name = stamp end
end

function T:Init()
    local chars = ns.root.chars
    for _, c in pairs(chars) do
        if c.current then StripOldDefaultName(c.current) end
        for _, s in ipairs(c.history or {}) do StripOldDefaultName(s) end
    end
    self.charKey = CharKey()
    local c = chars[self.charKey] or {}
    chars[self.charKey] = c
    c.history = c.history or {}
    c.class = select(2, UnitClass("player"))
    if not c.current then c.current = self:NewSessionTable() end
    self.char = c
    segmentStart = GetTime()
end

function T:Current()
    return self.char and self.char.current
end

function T:CommitPlayTime()
    local cur = self:Current()
    if cur and segmentStart then
        local now = GetTime()
        cur.playTime = (cur.playTime or 0) + (now - segmentStart)
        segmentStart = now
    end
end

function T:PlayTime(session)
    local t = session.playTime or 0
    if session == self:Current() and segmentStart then t = t + (GetTime() - segmentStart) end
    return t
end

function T:UniqueCount(session)
    local n = 0
    for _ in pairs(session.items) do n = n + 1 end
    return n
end

function T:IsEmpty(session)
    if (session.itemTotal or 0) > 0 or (session.money or 0) > 0 then return false end
    for _, c in ipairs(ns.COUNTERS) do
        if (session[c.key] or 0) > 0 then return false end
    end
    return true
end

-- Returns the session total for that item.
function T:AddItem(key, id, link, name, quality, icon, amount)
    local cur = self:Current()
    if not cur then return end
    local now = time()
    local e = cur.items[key]
    if not e then
        e = { id = id, count = 0, first = now }
        cur.items[key] = e
    end
    e.name, e.quality, e.icon, e.link = name, quality, icon, link
    e.count = e.count + amount
    e.last = now
    cur.itemTotal = (cur.itemTotal or 0) + amount
    cur.itemLoots = (cur.itemLoots or 0) + 1
    cur.quality[quality] = (cur.quality[quality] or 0) + amount
    cur.lastActivity = now
    ns.FireUpdate()
    return e.count
end

-------------------------------------------------------------------------------
--  Item value: per unit, the higher of the vendor sell price and the auction
--  price from Auctionator or TradeSkillMaster when one is installed.
-------------------------------------------------------------------------------
local sellCache = {} -- itemID -> vendor sell price (copper)

local function AuctionPrice(link, id)
    local A = _G.Auctionator
    local api = A and A.API and A.API.v1
    if api then
        local ok, p
        if link and api.GetAuctionPriceByItemLink then
            ok, p = pcall(api.GetAuctionPriceByItemLink, "PlunderScroll", link)
        end
        if not (ok and type(p) == "number") and id and api.GetAuctionPriceByItemID then
            ok, p = pcall(api.GetAuctionPriceByItemID, "PlunderScroll", id)
        end
        if ok and type(p) == "number" and p > 0 then return p end
    end
    local TSM = _G.TSM_API
    if TSM and TSM.GetCustomPriceValue and TSM.ToItemString then
        local ok, itemString = pcall(TSM.ToItemString, link or ("item:" .. id))
        if ok and itemString then
            local ok2, p = pcall(TSM.GetCustomPriceValue, "DBMarket", itemString)
            if ok2 and type(p) == "number" and p > 0 then return p end
        end
    end
end

-- Value of one unit of an item entry; nil while the item isn't cached yet.
function T:ItemValue(e)
    local sell = sellCache[e.id]
    if sell == nil then
        sell = select(11, ns.GetItemInfo(e.link or e.id))
        if sell == nil then return nil end
        sellCache[e.id] = sell
    end
    return math.max(sell, AuctionPrice(e.link, e.id) or 0)
end

-- Total value of a session's items, and whether some items weren't cached
-- yet (they are requested from the server and left out of the total).
function T:SessionValue(session)
    local total, missing = 0, false
    for _, e in pairs(session.items) do
        local v = self:ItemValue(e)
        if v then total = total + v * e.count else missing = true end
    end
    return total, missing
end

-- Adds one to a counter (an ns.COUNTERS key); returns the session count.
function T:AddCount(key)
    local cur = self:Current()
    if not cur then return end
    cur[key] = (cur[key] or 0) + 1
    cur.lastActivity = time()
    ns.FireUpdate()
    return cur[key]
end

-- Returns the session money total.
function T:AddMoney(copper)
    local cur = self:Current()
    if not cur then return end
    cur.money = (cur.money or 0) + copper
    cur.moneyLoots = (cur.moneyLoots or 0) + 1
    cur.lastActivity = time()
    ns.FireUpdate()
    return cur.money
end

-- Archives the current session (unless nothing was looted in it) and starts
-- a fresh one.
function T:StartNew(name)
    self:CommitPlayTime()
    local c = self.char
    local old = c.current
    if old and not self:IsEmpty(old) then
        old.ended = time()
        table.insert(c.history, 1, old)
        ns.Print("Session |cffffffff%s|r archived to History (%s, %d items).", old.name,
            ns.Format.MoneyPlain(old.money), old.itemTotal)
    end
    c.current = self:NewSessionTable(name)
    segmentStart = GetTime()
    ns.Print("New session |cffffffff%s|r started.", c.current.name)
    ns.FireUpdate()
    return c.current
end

-- Makes an archived session of this character current again; the current
-- one goes to history in its place.
function T:Resume(index)
    local c = self.char
    local s = c.history[index]
    if not s then return end
    self:CommitPlayTime()
    table.remove(c.history, index)
    local old = c.current
    if old and not self:IsEmpty(old) then
        old.ended = time()
        table.insert(c.history, 1, old)
    end
    s.ended = nil
    c.current = s
    segmentStart = GetTime()
    ns.Print("Resumed session |cffffffff%s|r.", s.name)
    ns.FireUpdate()
    return s
end

function T:Delete(charKey, index)
    local c = ns.root.chars[charKey]
    if c and c.history[index] then
        table.remove(c.history, index)
        ns.FireUpdate()
    end
end

-- Removes a character's whole record (never the logged-in one).
function T:DeleteCharacter(charKey)
    if charKey == self.charKey then return end
    ns.root.chars[charKey] = nil
    ns.FireUpdate()
end

function T:Rename(session, name)
    if session and name and name ~= "" then
        session.name = name
        ns.FireUpdate()
    end
end

-- Characters with data, the logged-in one first.
function T:Characters()
    local out = {}
    for key in pairs(ns.root.chars) do
        if key ~= self.charKey then out[#out + 1] = key end
    end
    table.sort(out)
    table.insert(out, 1, self.charKey)
    return out
end
