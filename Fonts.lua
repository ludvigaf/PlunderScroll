-------------------------------------------------------------------------------
--  PlunderScroll - Fonts.lua
--  Collects fonts from the game, LibSharedMedia (which EllesmereUI, ElvUI,
--  SharedMedia, Details!, Plater, WeakAuras ... register into), EllesmereUI's
--  own font table and user-added font paths.
-------------------------------------------------------------------------------
local _, ns = ...

local Fonts = {}
ns.Fonts = Fonts

local BLIZZARD = {
    { "Friz Quadrata TT", "Fonts\\FRIZQT__.TTF" },
    { "Arial Narrow", "Fonts\\ARIALN.TTF" },
    { "Morpheus", "Fonts\\MORPHEUS.TTF" },
    { "Skurri", "Fonts\\SKURRI.TTF" },
}

local entries, list = {}, nil

-- The addon folder a font path lives in, "Blizzard" for game fonts.
local function SourceOf(path)
    local _, e = path:lower():find("interface[\\/]addons[\\/]")
    if e then return path:sub(e + 1):match("^[^\\/]+") or "AddOn" end
    return "Blizzard"
end

local function Add(name, path, source)
    if type(name) ~= "string" or type(path) ~= "string" or name == "" or path == "" then return end
    if entries[name] then return end
    entries[name] = { name = name, path = path, source = source or SourceOf(path) }
end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

function Fonts:Rebuild()
    wipe(entries)
    list = nil
    Add("Game Default", STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", "Blizzard")
    for _, f in ipairs(BLIZZARD) do Add(f[1], f[2], "Blizzard") end

    -- EllesmereUI keeps its own table as well as registering into LSM.
    local EUI = _G.EllesmereUI
    if type(EUI) == "table" and type(EUI.FONT_FILES) == "table" then
        local media = EUI.MEDIA_PATH or "Interface\\AddOns\\EllesmereUI\\media\\"
        for name, file in pairs(EUI.FONT_FILES) do
            if type(file) == "string" then Add(name, media .. "fonts\\" .. file, "EllesmereUI") end
        end
    end

    local lib = LSM()
    if lib then
        local fonts = lib:HashTable("font")
        if fonts then
            for name, path in pairs(fonts) do Add(name, path) end
        end
    end

    for _, f in ipairs(ns.db.customFonts or {}) do Add(f.name, f.path, "Custom") end
end

function Fonts:Init()
    self:Rebuild()
    local lib = LSM()
    if lib and lib.RegisterCallback then
        lib.RegisterCallback(Fonts, "LibSharedMedia_Registered", function(_, mediaType, key)
            if mediaType ~= "font" then return end
            Fonts.dirty = true
            if key == ns.db.font then
                Fonts:Rebuild()
                ns.RefreshAll()
            end
        end)
    end
end

-- Sorted list of { name, path, source }: game fonts first, then by name.
function Fonts:GetList()
    if self.dirty or not list then
        self.dirty = false
        self:Rebuild()
        list = {}
        for _, e in pairs(entries) do list[#list + 1] = e end
        table.sort(list, function(a, b)
            local ab, bb = a.source == "Blizzard", b.source == "Blizzard"
            if ab ~= bb then return ab end
            return a.name:lower() < b.name:lower()
        end)
    end
    return list
end

function Fonts:Resolve(name)
    local e = entries[name]
    if e then return e.path end
    if self.dirty then
        self:Rebuild()
        e = entries[name]
        if e then return e.path end
    end
    return ns.db.fontPath or STANDARD_TEXT_FONT
end

function Fonts:Select(name)
    local path = self:Resolve(name)
    ns.db.font = name
    ns.db.fontPath = path
    ns.RefreshAll()
end

function Fonts:AddCustom(name, path)
    path = path and path:gsub("/", "\\"):gsub("^%s+", ""):gsub("%s+$", "")
    if not path or path == "" then return false, "Enter a font path." end
    if not path:lower():find("%.[ot]tf$") then return false, "The path must end in .ttf or .otf." end
    -- Probe the file: an unreadable font leaves the probe without a font.
    self.probe = self.probe or UIParent:CreateFontString(nil, "OVERLAY")
    self.probe:SetFont(STANDARD_TEXT_FONT, 12, "")
    local ok = pcall(self.probe.SetFont, self.probe, path, 12, "")
    local got = ok and self.probe:GetFont()
    if not got or got:lower() ~= path:lower() then
        return false, "WoW could not load that font. Check the path (fonts must be inside the WoW folder)."
    end
    if not name or name == "" then name = path:match("([^\\]+)%.[ot]tf$") or path end
    local custom = ns.db.customFonts
    for _, f in ipairs(custom) do
        if f.name == name then f.path = path; self.dirty = true; return true, name end
    end
    custom[#custom + 1] = { name = name, path = path }
    self.dirty = true
    return true, name
end

function Fonts:ClearCustom()
    wipe(ns.db.customFonts)
    self.dirty = true
end

-- Applies the configured font to a font string.
function Fonts:Apply(fs, size, outline)
    local db = ns.db
    local flags = outline or db.outline
    if not flags or flags == "NONE" then flags = "" end
    local path = self:Resolve(db.font)
    fs:SetFont(STANDARD_TEXT_FONT, size, flags)
    if path ~= STANDARD_TEXT_FONT then pcall(fs.SetFont, fs, path, size, flags) end
    if db.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end
