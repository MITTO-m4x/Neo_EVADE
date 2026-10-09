--[[
  NEO HYPER — Theme Library (external)
  Load: loadstring(game:HttpGet(URL))()
  Returns table: { Themes = {...}, Apply = function(WindUI, name), List = function(), Default = "Pure Mono" }
]]

local NeoThemes = {}

NeoThemes.Default = "Pure Mono"

-- name, Accent, Background, Button, Text, Outline, Dialog, Icon, Toggle/Slider/Checkbox
local RAW = {
    { "Pure Mono",      "FFFFFF", "000000", "121212", "FFFFFF", "DCDCDC", "080808", "FFFFFF" },
    { "Obsidian",       "E8E8E8", "0A0A0A", "161616", "F0F0F0", "3A3A3A", "050505", "FFFFFF" },
    { "Midnight",       "7EB6FF", "0B1020", "141A2E", "E8F0FF", "2A3550", "080C18", "A8C8FF" },
    { "Carbon",         "CFCFCF", "121212", "1C1C1C", "F5F5F5", "444444", "0C0C0C", "FFFFFF" },
    { "Steel",          "B8C0CC", "14181E", "1E242C", "E8ECF0", "3A4450", "0C1014", "D0D8E0" },
    { "Arctic",         "E8F4FF", "0E141C", "182028", "F5FAFF", "4A6070", "0A1016", "FFFFFF" },
    { "Neon Cyan",      "00F0FF", "050A0C", "0C1418", "E0FFFF", "006878", "030608", "00F0FF" },
    { "Neon Pink",      "FF2D95", "0C050A", "1A0C14", "FFE0F0", "801040", "080308", "FF2D95" },
    { "Neon Lime",      "B8FF00", "080C04", "121A08", "F0FFE0", "507800", "040804", "B8FF00" },
    { "Royal Gold",     "FFC828", "120E06", "1E180C", "FFF8E8", "785818", "0A0804", "FFD040" },
    { "Crimson",        "FF3030", "120606", "1E0C0C", "FFE8E8", "781818", "0A0404", "FF5050" },
    { "Emerald",        "20E080", "06120A", "0C1E14", "E8FFF0", "187848", "040A06", "40F0A0" },
    { "Violet",         "A060FF", "0C0814", "160E22", "F0E8FF", "482878", "080610", "B080FF" },
    { "Ocean",          "2090E0", "061018", "0C1A28", "E0F0FF", "185078", "040C12", "40A8F0" },
    { "Sunset",         "FF7040", "140A08", "22140E", "FFF0E8", "783828", "0C0604", "FF9060" },
    { "Rose",           "FF80A0", "140810", "22141C", "FFE8F0", "783050", "0C060A", "FFA0B8" },
    { "Sand",           "E0C890", "14120C", "221E16", "FFF8E8", "706040", "0C0A06", "F0D8A0" },
    { "Forest",         "50A060", "0A120C", "121E14", "E8F0E8", "285830", "060A06", "70C080" },
    { "Ice",            "C0E8FF", "0C1218", "141E28", "F0F8FF", "486878", "080C10", "E0F4FF" },
    { "Lava",           "FF4000", "140805", "220E08", "FFE8E0", "782000", "0C0402", "FF6020" },
    { "Graphite",       "9A9A9A", "101010", "1A1A1A", "EAEAEA", "3C3C3C", "080808", "C0C0C0" },
    { "Amethyst",       "C080FF", "100818", "1A0E26", "F4E8FF", "582888", "0A0610", "D0A0FF" },
    { "Teal",           "20C0B0", "061210", "0C1E1A", "E0FFF8", "186858", "040C0A", "40E0D0" },
    { "Amber",          "FFB020", "141008", "221A0C", "FFF8E8", "785818", "0C0A04", "FFC840" },
    { "Blood",          "C01020", "100408", "1A080C", "FFE0E4", "600810", "080204", "E02030" },
    { "Sky",            "60B0FF", "0A121C", "121C2A", "E8F4FF", "285878", "060C14", "80C8FF" },
    { "Mint",           "60E0B0", "081410", "0E1E18", "E8FFF4", "287858", "040C08", "80F0C8" },
    { "Indigo",         "5060E0", "080A18", "101228", "E8E8FF", "283078", "040610", "7080F0" },
    { "Copper",         "D08040", "14100A", "221810", "FFF0E0", "704020", "0C0804", "E0A060" },
    { "Pearl",          "F0F0F0", "181818", "242424", "FFFFFF", "606060", "101010", "FFFFFF" },
    { "Halloween",      "FF7018", "22160E", "482814", "FFF5E6", "914818", "1E130C", "FF842A" },
    { "Halloween Soft", "FFB45A", "281C2C", "3E2822", "FFF8EC", "DC96FF", "302034", "FFBE64" },
    { "Glass",          "282830", "14141C", "3C3C46", "F5F5FA", "C8C8D2", "181820", "E6E6F0" },
}

local function hex(h)
    h = tostring(h or "FFFFFF"):gsub("#", "")
    local n = tonumber(h, 16) or 0xFFFFFF
    return Color3.fromRGB(bit32.rshift(n, 16) % 256, bit32.rshift(n, 8) % 256, n % 256)
end

-- Fallback if bit32 missing
if not bit32 then
    function hex(h)
        h = tostring(h or "FFFFFF"):gsub("#", "")
        local r = tonumber(h:sub(1, 2), 16) or 255
        local g = tonumber(h:sub(3, 4), 16) or 255
        local b = tonumber(h:sub(5, 6), 16) or 255
        return Color3.fromRGB(r, g, b)
    end
end

NeoThemes.Themes = {}
NeoThemes.Order = {}

for _, row in ipairs(RAW) do
    local name = row[1]
    local accent = hex(row[2])
    local bg = hex(row[3])
    local btn = hex(row[4])
    local text = hex(row[5])
    local outline = hex(row[6])
    local dialog = hex(row[7])
    local icon = hex(row[8])
    NeoThemes.Themes[name] = {
        Name = name,
        Accent = accent,
        Background = bg,
        Button = btn,
        Text = text,
        Placeholder = Color3.fromRGB(
            math.floor(text.R * 180),
            math.floor(text.G * 180),
            math.floor(text.B * 180)
        ),
        Outline = outline,
        Dialog = dialog,
        Icon = icon,
        Toggle = accent,
        Slider = accent,
        Checkbox = accent,
        ElementBackground = btn,
        ElementBackgroundTransparency = 0.08,
        -- panel bg mode: "black" | "theme"
        PanelBackgroundMode = "theme",
    }
    table.insert(NeoThemes.Order, name)
end

function NeoThemes.List()
    return table.clone(NeoThemes.Order)
end

function NeoThemes.Get(name)
    return NeoThemes.Themes[name] or NeoThemes.Themes[NeoThemes.Default]
end

function NeoThemes.Apply(WindUI, name, panelMode)
    if not WindUI then return false end
    name = name or NeoThemes.Default
    local t = NeoThemes.Get(name)
    if not t then return false end
    panelMode = panelMode or "theme" -- "black" or "theme"
    local themeCopy = {}
    for k, v in pairs(t) do themeCopy[k] = v end
    if panelMode == "black" then
        themeCopy.Background = Color3.fromRGB(0, 0, 0)
        themeCopy.Dialog = Color3.fromRGB(0, 0, 0)
        themeCopy.ElementBackground = Color3.fromRGB(12, 12, 12)
    end
    pcall(function()
        WindUI:AddTheme(themeCopy)
        WindUI:SetTheme(name)
    end)
    return true
end

function NeoThemes.RegisterAll(WindUI)
    if not WindUI then return end
    for _, name in ipairs(NeoThemes.Order) do
        pcall(function()
            WindUI:AddTheme(NeoThemes.Themes[name])
        end)
    end
    pcall(function()
        WindUI:SetTheme(NeoThemes.Default)
    end)
end

getgenv().NeoThemes = NeoThemes
return NeoThemes
