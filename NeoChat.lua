--[[
    NeoChat v3.2.3  —  Firebase chat for WindUI  (Neo Hyper)
    Full feature pack:
    - All Yin stickers + favorites strip
    - Image-only sticker display (never shows [[STICKER]] text)
    - Icon actions + long-press menu + double-tap react
    - Pinned message (owners) | Search | Mute room
    - Online list | Recent DMs | Unread private badge
    - Compact mode | Chat accent theme
    - Profile peek | Friend request nudge
    - Owners: v_orc, n_oqv
]]

local NeoChat = {
    DatabaseURL = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app",
    Version = "3.2.3",
    StickersURL = "https://raw.githubusercontent.com/Sephtis32/Yin-stickers/refs/heads/main/YinYang_Stickers.lua",
}

-- Safe globals (some executors lack getgenv / table.clear / utf8 helpers)
local function envGet()
    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    if type(_G) == "table" then return _G end
    return shared or {}
end
local function tableClear(t)
    if type(t) ~= "table" then return end
    if type(table.clear) == "function" then
        table.clear(t)
        return
    end
    for k in pairs(t) do t[k] = nil end
end
local function utf8Codes(str)
    if utf8 and type(utf8.codes) == "function" then
        return utf8.codes(str)
    end
    -- fallback: byte iterator (ASCII-ish)
    local i = 0
    local s = tostring(str or "")
    return function()
        i = i + 1
        if i > #s then return nil end
        return i, string.byte(s, i)
    end
end
local function utf8Char(code)
    if utf8 and type(utf8.char) == "function" then
        return utf8.char(code)
    end
    code = tonumber(code) or 63
    if code >= 0 and code < 128 then return string.char(code) end
    return "?"
end

local cr = cloneref or function(x) return x end
local Players          = cr(game:GetService("Players"))
local HttpService      = cr(game:GetService("HttpService"))
local TweenService     = cr(game:GetService("TweenService"))
local TeleportService  = cr(game:GetService("TeleportService"))
local MarketplaceService = cr(game:GetService("MarketplaceService"))
local UserInputService = cr(game:GetService("UserInputService"))
local LocalPlayer      = Players.LocalPlayer

local OWNERS = { ["v_orc"] = true, ["n_oqv"] = true }
local function isOwner(name)
    return OWNERS[tostring(name or ""):lower()] == true
end
local ME_IS_OWNER = isOwner(LocalPlayer.Name)

------------------------------------------------------------------ Icons
local IconsLib = nil
pcall(function()
    local fetch = game.HttpGetAsync or game.HttpGet
    local raw = fetch(game, "https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua")
    IconsLib = loadstring(raw)()
    if IconsLib and IconsLib.SetIconsType then pcall(function() IconsLib.SetIconsType("lucide") end) end
end)
local function getIconImage(name)
    if not IconsLib then return nil end
    local ok, img = pcall(function()
        if IconsLib.GetIcon then
            return IconsLib.GetIcon(name)
        end
        return nil
    end)
    if ok and type(img) == "string" and img ~= "" then return img end
    ok, img = pcall(function()
        if type(IconsLib) == "table" and IconsLib[name] then return IconsLib[name] end
        return nil
    end)
    if ok and type(img) == "string" and img ~= "" then return img end
    return nil
end

------------------------------------------------------------------ HTTP
local rawRequest = (syn and syn.request) or (http and http.request) or http_request
    or (fluxus and fluxus.request) or request
local JSON_HEADERS = { ["Content-Type"] = "application/json" }

local function call(method, url, body)
    if rawRequest then
        local ok, res = pcall(rawRequest, { Url = url, Method = method, Headers = JSON_HEADERS, Body = body })
        if not ok or type(res) ~= "table" then return false, tostring(res) end
        local code = tonumber(res.StatusCode or res.Status) or 0
        return (res.Success == true) or (code >= 200 and code < 300), res.Body, code
    end
    local ok, res = pcall(function()
        return HttpService:RequestAsync({ Url = url, Method = method, Headers = JSON_HEADERS, Body = body })
    end)
    if ok and res then return res.Success, res.Body, res.StatusCode end
    return false, tostring(res)
end
local function decode(s)
    local ok, r = pcall(function() return HttpService:JSONDecode(s) end)
    return ok and r or nil
end
local function encode(t) return HttpService:JSONEncode(t) end
local function esc(s)
    s = tostring(s or "")
    return s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function clipUtf8(s, max)
    local len = utf8.len(s)
    if not len then return s:sub(1, max) end
    if len <= max then return s end
    return s:sub(1, (utf8.offset(s, max + 1) or (#s + 1)) - 1)
end
local function cleanName(s)
    s = tostring(s or "?"):gsub("[%c%z]", ""):gsub("%s+", " ")
    if #s > 26 then s = s:sub(1, 23) .. "..." end
    return s
end

local REACT_SET = { "❤️", "😂", "🔥", "👍", "😮", "😢" }
local INVITE_COOLDOWN = 30

------------------------------------------------------------------ Stickers
local StickerCatalog = { Order = {}, Stickers = {}, Ready = false }
local function loadStickers(url)
    task.spawn(function()
        local ok, raw = pcall(function() return game:HttpGet(url or NeoChat.StickersURL, true) end)
        if not ok or type(raw) ~= "string" then return end
        local ok2, data = pcall(function() return loadstring(raw)() end)
        if not ok2 or type(data) ~= "table" then return end
        StickerCatalog.Order = data.Order or {}
        StickerCatalog.Stickers = data.Stickers or {}
        StickerCatalog.Ready = true
    end)
end
local function stickerPayload(image)
    local img = tostring(image or "")
    if img == "" then return nil end
    return "[[STICKER:" .. img .. "]]"
end
local function parseSticker(text)
    local body = tostring(text or ""):match("^%[%[STICKER:(.-)%]%]$")
    if not body then return nil end
    local frames, interval = {}, 0.4
    for part in body:gmatch("[^|]+") do
        part = trim(part)
        local n = tonumber(part)
        if n and n >= 0.1 and n <= 5 and not part:find("rbxassetid", 1, true) then
            interval = n
        else
            if not part:find("rbxassetid://", 1, true) and part:match("^%d+$") then
                part = "rbxassetid://" .. part
            end
            if part:find("rbxassetid://", 1, true) then frames[#frames + 1] = part end
        end
    end
    if #frames == 0 or #frames > 3 then return nil end
    return frames, interval
end

------------------------------------------------------------------ Settings
local function loadSettings()
    local def = {
        SideNotifs = true,
        SideNotifDuration = 3.2,
        MentionsEnabled = true,
        ShowScriptIcon = true,
        HideMyName = false,
        MessageAnims = true,
        FirstAskDone = false,
        CompactMode = false,
        ChatAccent = "default", -- default | blue | purple | green | rose
        MutedRooms = {},
        StickerFavs = {},
        RecentDMs = {},
        SearchOpen = false,
    }
    local s = envGet().NeoChatSettings
    if type(s) ~= "table" then
        envGet().NeoChatSettings = def
        return def
    end
    for k, v in pairs(def) do
        if s[k] == nil then s[k] = v end
    end
    if type(s.MutedRooms) ~= "table" then s.MutedRooms = {} end
    if type(s.StickerFavs) ~= "table" then s.StickerFavs = {} end
    if type(s.RecentDMs) ~= "table" then s.RecentDMs = {} end
    return s
end

local ACCENTS = {
    default = nil, -- uses theme primary
    blue    = Color3.fromRGB(55, 120, 220),
    purple  = Color3.fromRGB(140, 90, 230),
    green   = Color3.fromRGB(40, 180, 120),
    rose    = Color3.fromRGB(220, 90, 130),
}

------------------------------------------------------------------ Init
function NeoChat.Init(WindUI, Window, cfg)
    cfg = cfg or {}
    cfg.DatabaseURL = cfg.DatabaseURL or NeoChat.DatabaseURL
    assert(type(cfg.DatabaseURL) == "string", "NeoChat: DatabaseURL is required")
    assert(Window, "NeoChat: Window is required")

    loadStickers(cfg.StickersURL or NeoChat.StickersURL)

    local BASE       = (cfg.DatabaseURL:gsub("/+$", ""))
    local MAXLEN     = cfg.MaxLength or 200
    local POLL       = cfg.PollInterval or 1.55
    local HISTORY    = cfg.History or 40
    local COOLDOWN   = cfg.Cooldown or 1.15
    local BADGE_MODE = cfg.BadgeMode or "senders"
    local TOAST      = cfg.Notifications ~= false
    local SCRIPT_NAME = tostring(cfg.ScriptName or "Neo")
    local SCRIPT_IMG  = tostring(cfg.ScriptImage or "")
    local ME_ID, ME_NAME, ME_DN = LocalPlayer.UserId, LocalPlayer.Name, LocalPlayer.DisplayName
    local Settings = loadSettings()

    local S = {
        alive = true, kind = "global", room = nil, gen = 0, lastKey = nil, loaded = false,
        seen = {}, pending = {}, unread = {}, dmUnread = {}, lastSend = 0, lastToast = 0, fails = 0,
        online = 1, panelOpen = false, shown = 0, lastBadge = 0,
        replyTo = nil, privateTarget = nil, privateName = nil,
        typing = false, lastTypingPush = 0, lastInvite = 0,
        pin = nil, searchQuery = "", onlineMap = {},
        menuOpen = nil, profileOpen = nil,
    }

    local function roomName(kind, targetUid)
        if kind == "private" and targetUid then
            local a, b = ME_ID, tonumber(targetUid)
            if a > b then a, b = b, a end
            return "dm_" .. a .. "_" .. b
        end
        return (tostring(cfg.Room or "global"):gsub("[%.%$#%[%]/]", "_"))
    end
    S.room = roomName("global")

    local function urlFor(path, query)
        return BASE .. "/" .. path .. ".json" .. (query and ("?" .. query) or "")
    end

    local function isMuted()
        return Settings.MutedRooms[S.room] == true
    end
    local function toggleMute()
        Settings.MutedRooms[S.room] = not isMuted()
        envGet().NeoChatSettings = Settings
        return isMuted()
    end

    local function pushRecentDM(uid, name)
        uid = tonumber(uid)
        if not uid then return end
        local list = Settings.RecentDMs
        local out = { { uid = uid, name = tostring(name or "?"), ts = os.time() } }
        for _, e in ipairs(list) do
            if tonumber(e.uid) ~= uid then out[#out + 1] = e end
            if #out >= 12 then break end
        end
        Settings.RecentDMs = out
        envGet().NeoChatSettings = Settings
    end

    local function pushStickerFav(image)
        image = tostring(image or "")
        if image == "" then return end
        local list = Settings.StickerFavs
        local out = { image }
        for _, e in ipairs(list) do
            if e ~= image then out[#out + 1] = e end
            if #out >= 8 then break end
        end
        Settings.StickerFavs = out
        envGet().NeoChatSettings = Settings
    end

    local Creator = WindUI and WindUI.Creator
    local function themeColor(tag, default)
        local ok, c = pcall(function()
            if not Creator then return nil end
            if Creator.GetThemeProperty then
                return Creator.GetThemeProperty(tag, WindUI and WindUI.Theme)
            end
            if type(Creator.GetThemeProperty) == "function" then
                return Creator:GetThemeProperty(tag, WindUI and WindUI.Theme)
            end
            return nil
        end)
        if ok and typeof(c) == "Color3" then return c end
        return default
    end
    local function luminance(c) return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B end
    local P = {}
    local function computePalette()
        local bg = themeColor("Background", Color3.fromRGB(16, 16, 16))
        local tx = themeColor("Text", Color3.new(1, 1, 1))
        local prim = WindUI and WindUI.Theme and WindUI.Theme.Primary
        local own = (typeof(prim) == "Color3") and prim or tx
        local accent = ACCENTS[Settings.ChatAccent]
        if accent then own = accent end
        P = {
            text = tx, bg = bg, muted = bg:Lerp(tx, 0.55), placeholder = bg:Lerp(tx, 0.5),
            card = bg:Lerp(tx, 0.10), other = bg:Lerp(tx, 0.14),
            own = own, ownText = luminance(own) > 0.55 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1),
        }
    end
    computePalette()

    local painted = {}
    local function bind(obj, prop, key)
        obj[prop] = P[key]
        painted[#painted + 1] = { obj, prop, key }
    end
    local onTheme = {}
    local function applyTheme()
        computePalette()
        local keep = {}
        for _, e in ipairs(painted) do
            if e[1].Parent then pcall(function() e[1][e[2]] = P[e[3]] end); keep[#keep + 1] = e end
        end
        painted = keep
        for _, f in ipairs(onTheme) do pcall(f) end
    end

    local function New(class, props, children)
        props = props or {}
        local binds = props.Bind
        props.Bind = nil
        local o
        if Creator and Creator.New then
            local ok, obj = pcall(function()
                return Creator:New(class, props, children)
            end)
            if ok and obj then o = obj end
        end
        if not o then
            o = Instance.new(class)
            pcall(function() o.BorderSizePixel = 0 end)
            for k, v in pairs(props) do pcall(function() o[k] = v end) end
            for _, c in ipairs(children or {}) do c.Parent = o end
        end
        for prop, key in pairs(binds or {}) do bind(o, prop, key) end
        return o
    end
    local function corner(r) return New("UICorner", { CornerRadius = UDim.new(0, r) }) end
    local function pad(l, t, r, b)
        return New("UIPadding", {
            PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
            PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b)
        })
    end

    local function iconButton(parent, iconName, fallbackLetter, x, size, callback)
        size = size or 28
        local btn = New("TextButton", {
            Position = UDim2.new(0, x, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, size, 0, size),
            Text = "", BackgroundTransparency = 1,
            AutoButtonColor = false, Parent = parent,
        })
        local asset = getIconImage(iconName)
        if asset then
            local img = New("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(0, size - 10, 0, size - 10),
                BackgroundTransparency = 1, Image = asset,
                ScaleType = Enum.ScaleType.Fit, Parent = btn,
            })
            pcall(function() img.ImageColor3 = P.text end)
            painted[#painted + 1] = { img, "ImageColor3", "text" }
        else
            New("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = fallbackLetter or "?", TextSize = 13, Font = Enum.Font.GothamBold,
                Bind = { TextColor3 = "text" }, Parent = btn,
            })
        end
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end

    local tab = cfg.Tab
    if not tab then
        local okTab, t = pcall(function()
            return Window:Tab({ Title = cfg.Title or "Chat", Icon = cfg.Icon or "message-circle" })
        end)
        if okTab then tab = t end
    end
    assert(tab, "NeoChat: Chat tab is missing")

    local function resolveTabCanvas(t)
        local ue = t and t.UIElements
        if type(ue) == "table" or typeof(ue) == "Instance" then
            local c = ue.ContainerFrameCanvas or ue.ContainerCanvas or ue.Canvas or ue.Container
            if c then return c, ue.Main or ue.Button or ue.TabButton or t end
            if ue.ContainerFrame then return ue.ContainerFrame, ue.Main or t end
        end
        -- fallbacks used by some WindUI forks
        if t.ContainerFrameCanvas then return t.ContainerFrameCanvas, t end
        if t.Canvas then return t.Canvas, t end
        if t.Frame then return t.Frame, t end
        return nil, t
    end

    local canvas, sideBtn = resolveTabCanvas(tab)
    if not canvas then
        -- last resort: create our own holder inside the window if possible
        local host = nil
        pcall(function() host = Window.UIElements and Window.UIElements.Main end)
        canvas = Instance.new("Frame")
        canvas.Name = "NeoChatFallbackCanvas"
        canvas.BackgroundTransparency = 1
        canvas.Size = UDim2.fromScale(1, 1)
        canvas.Parent = host or game:GetService("CoreGui")
        sideBtn = sideBtn or tab
        warn("[NeoChat] UIElements.ContainerFrameCanvas missing — using fallback canvas")
    end
    sideBtn = sideBtn or tab

    task.spawn(function()
        for _ = 1, 2 do
            task.wait(0.25)
            pcall(function()
                local ue = tab.UIElements
                if not ue or not ue.ContainerFrame then return end
                local dummy = Instance.new("Frame")
                dummy.Size = UDim2.new(0, 0, 0, 0)
                dummy.BackgroundTransparency = 1
                dummy.Parent = ue.ContainerFrame
                ue.ContainerFrame.Visible = false
            end)
        end
    end)

    local HEADER, INPUT_H, PANEL_H, REPLY_H, PRIV_H, PIN_H, SEARCH_H = 40, 48, 168, 34, 18, 28, 30
    local root = New("Frame", {
        Name = "NeoChat", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Parent = canvas,
    })

    local title = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.42, 0, 0, HEADER),
        BackgroundTransparency = 1, RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 13,
        Text = "Chat", Bind = { TextColor3 = "text" }, Parent = root,
    })

    -- top utility icons: search, online, mute
    local utilBar = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -172, 0, HEADER / 2),
        Size = UDim2.new(0, 90, 0, 26),
        BackgroundTransparency = 1, Parent = root,
    })
    local searchToggleBtn, onlineBtn, muteBtn

    local pills = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0, HEADER / 2),
        Size = UDim2.new(0, 158, 0, 26),
        Bind = { BackgroundColor3 = "card" }, Parent = root,
    }, { corner(13) })

    local pillBtns = {}
    local dmBadgeRefs = { badge = nil, label = nil } -- never set custom fields on WindUI instances
    local function makePill(kind, text, x)
        local b = New("TextButton", {
            Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(0.5, -4, 1, -4),
            Text = text, TextSize = 12, Font = Enum.Font.GothamMedium,
            BackgroundTransparency = 1, AutoButtonColor = false,
            Bind = { TextColor3 = "text" }, Parent = pills,
        }, { corner(11) })
        pillBtns[kind] = b
        -- private unread badge (store refs in table, not on the button)
        if kind == "private" then
            local badge = New("Frame", {
                Name = "DMBadge",
                AnchorPoint = Vector2.new(1, 0),
                Position = UDim2.new(1, -2, 0, 1),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.fromRGB(230, 60, 60),
                Visible = false, ZIndex = 5, Parent = b,
            }, { corner(7) })
            local bl = New("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                Text = "0", TextColor3 = Color3.new(1, 1, 1),
                TextSize = 9, Font = Enum.Font.GothamBold, Parent = badge,
            })
            dmBadgeRefs.badge = badge
            dmBadgeRefs.label = bl
        end
        return b
    end
    makePill("global", "Global", 0)
    makePill("private", "Private", 0.5)

    local function updateDMBadge()
        local n = 0
        for _, c in pairs(S.dmUnread) do n = n + c end
        local badge = dmBadgeRefs.badge
        local label = dmBadgeRefs.label
        if not badge or not label then return end
        if n <= 0 or S.kind == "private" then
            badge.Visible = false
        else
            badge.Visible = true
            label.Text = n > 9 and "9+" or tostring(n)
        end
    end

    local privHeader = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, HEADER - 2),
        Size = UDim2.new(1, -24, 0, PRIV_H),
        BackgroundTransparency = 1, Text = "",
        TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.3, Bind = { TextColor3 = "text" },
        Visible = false, Parent = root,
    })

    -- Pin bar
    local pinBar = New("Frame", {
        Position = UDim2.new(0, 8, 0, HEADER),
        Size = UDim2.new(1, -16, 0, PIN_H),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, Parent = root,
    }, { corner(8) })
    New("Frame", {
        Size = UDim2.new(0, 3, 1, -6), Position = UDim2.new(0, 4, 0, 3),
        BackgroundColor3 = Color3.fromRGB(255, 200, 50), Parent = pinBar,
    }, { corner(2) })
    local pinText = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1, Text = "",
        TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Bind = { TextColor3 = "text" }, Parent = pinBar,
    })
    local pinClose = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 22, 0, 22),
        Text = "X", TextSize = 11, Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1, Bind = { TextColor3 = "text" },
        Visible = ME_IS_OWNER, Parent = pinBar,
    })

    -- Search bar
    local searchBar = New("Frame", {
        Position = UDim2.new(0, 8, 0, HEADER),
        Size = UDim2.new(1, -16, 0, SEARCH_H),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, Parent = root,
    }, { corner(8) })
    local searchBox = New("TextBox", {
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1, PlaceholderText = "Search messages...",
        Text = "", ClearTextOnFocus = false, TextSize = 12,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text", PlaceholderColor3 = "placeholder" }, Parent = searchBar,
    })

    local scroll = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, HEADER),
        Size = UDim2.new(1, 0, 1, -(HEADER + INPUT_H)),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 7) }),
        pad(10, 6, 10, 6),
    })

    local emptyLbl = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0, 40),
        BackgroundTransparency = 1, Text = "No messages yet",
        TextSize = 14, Font = Enum.Font.Gotham, TextTransparency = 0.4,
        Bind = { TextColor3 = "text" }, Visible = false, Parent = root,
    })

    -- Stickers / private / online panel
    local panel = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -(INPUT_H)),
        Size = UDim2.new(1, -16, 0, PANEL_H - 8),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 5, Parent = root,
    }, { corner(12) })
    local panelTitle = New("TextLabel", {
        Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 18),
        BackgroundTransparency = 1, Text = "Stickers",
        TextSize = 12, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text" }, Parent = panel,
    })
    local favRow = New("Frame", {
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1, Visible = false, Parent = panel,
    }, {
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        pad(8, 0, 8, 0),
    })
    local panelScroll = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -26),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 6, Parent = panel,
    }, {
        New("UIGridLayout", {
            CellSize = UDim2.new(0, 44, 0, 44),
            CellPadding = UDim2.new(0, 4, 0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        pad(8, 4, 8, 8),
    })
    local privateList = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 1, -26),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 6, Parent = panel,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
        pad(8, 4, 8, 8),
    })

    -- Long-press context menu
    local ctxMenu = New("Frame", {
        Size = UDim2.new(0, 140, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 50, Parent = root,
    }, { corner(10), pad(4, 4, 4, 4),
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
    })

    -- Profile peek card
    local profileCard = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.new(0, 220, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 55, Parent = root,
    }, { corner(12), pad(12, 12, 12, 12),
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
    })

    local replyBar = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -(INPUT_H - 6)),
        Size = UDim2.new(1, -16, 0, REPLY_H),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 4, Parent = root,
    }, { corner(10) })
    New("Frame", {
        Size = UDim2.new(0, 3, 1, -8), Position = UDim2.new(0, 6, 0, 4),
        BackgroundColor3 = Color3.fromRGB(0, 170, 255), Parent = replyBar,
    }, { corner(2) })
    local replyNameLbl = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 2), Size = UDim2.new(1, -44, 0, 13),
        BackgroundTransparency = 1, Text = "", TextSize = 11,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.fromRGB(0, 170, 255), Parent = replyBar,
    })
    local replyTextLbl = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 15), Size = UDim2.new(1, -44, 0, 13),
        BackgroundTransparency = 1, Text = "", TextSize = 11,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.35, Bind = { TextColor3 = "text" }, Parent = replyBar,
    })
    local replyClose = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 24, 0, 24),
        Text = "X", TextSize = 12, Font = Enum.Font.GothamBold,
        BackgroundTransparency = 1, Bind = { TextColor3 = "text" }, Parent = replyBar,
    })

    -- Quick Reply menu: reacts + sticker reply when user presses Reply
    local QUICK_H = 40
    local quickReply = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -(INPUT_H - 6 + REPLY_H)),
        Size = UDim2.new(1, -16, 0, QUICK_H),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 6, Parent = root,
    }, {
        corner(10),
        pad(6, 4, 6, 4),
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local quickLabel = New("TextLabel", {
        Size = UDim2.new(0, 44, 1, 0),
        BackgroundTransparency = 1,
        Text = "Reply",
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text" },
        LayoutOrder = 0,
        Parent = quickReply,
    })

    local inputRow = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -8),
        Size = UDim2.new(1, -16, 0, 36),
        Bind = { BackgroundColor3 = "card" }, Parent = root,
    }, { corner(12) })

    local sendBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 54, 0, 28),
        Text = "Send", TextSize = 12, Font = Enum.Font.GothamBold,
        Bind = { BackgroundColor3 = "own", TextColor3 = "ownText" }, Parent = inputRow,
    }, { corner(8) })
    local input = New("TextBox", {
        Position = UDim2.new(0, 72, 0, 0), Size = UDim2.new(1, -72 - 60, 1, 0),
        BackgroundTransparency = 1, PlaceholderText = "Type a message...",
        Text = "", ClearTextOnFocus = false, TextSize = 13,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text", PlaceholderColor3 = "placeholder" }, Parent = inputRow,
    })

    local openStickersPanel, openPrivatePanel, openOnlinePanel, sendInvite, doSend, send, setRoom, relayout, refreshPinBar

    local stickerBtn = iconButton(inputRow, "sticker", "S", 6, 30, function()
        if S.panelOpen and panelTitle.Text == "Stickers" then
            S.panelOpen = false
        else
            openStickersPanel()
        end
        relayout()
    end)
    local inviteBtn = iconButton(inputRow, "send", "I", 38, 30, function() sendInvite() end)

    searchToggleBtn = iconButton(utilBar, "search", "?", 0, 26, function()
        Settings.SearchOpen = not Settings.SearchOpen
        if not Settings.SearchOpen then S.searchQuery = ""; searchBox.Text = "" end
        envGet().NeoChatSettings = Settings
        relayout()
        -- refilter
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") and c:GetAttribute("MsgText") then
                local q = S.searchQuery:lower()
                if q == "" then c.Visible = true
                else c.Visible = tostring(c:GetAttribute("MsgText")):lower():find(q, 1, true) ~= nil end
            end
        end
    end)
    onlineBtn = iconButton(utilBar, "users", "O", 30, 26, function()
        openOnlinePanel()
        relayout()
    end)
    muteBtn = iconButton(utilBar, "bell-off", "M", 60, 26, function()
        local muted = toggleMute()
        pcall(function()
            if WindUI and WindUI.Notify then
                WindUI:Notify({
                    Title = muted and "Muted" or "Unmuted",
                    Content = muted and "This room is muted" or "Notifications on",
                    Duration = 1.5, Icon = muted and "bell-off" or "bell",
                })
            end
        end)
    end)

    function relayout()
        local extraTop = (S.kind == "private" and PRIV_H or 0)
        if pinBar.Visible then extraTop = extraTop + PIN_H + 4 end
        if searchBar.Visible or Settings.SearchOpen then
            searchBar.Visible = true
            extraTop = extraTop + SEARCH_H + 4
            searchBar.Position = UDim2.new(0, 8, 0, HEADER + (S.kind == "private" and PRIV_H or 0) + (pinBar.Visible and PIN_H + 4 or 0))
        else
            searchBar.Visible = false
        end
        if pinBar.Visible then
            pinBar.Position = UDim2.new(0, 8, 0, HEADER + (S.kind == "private" and PRIV_H or 0))
        end
        local hasReply = S.replyTo ~= nil
        local hasQuick = hasReply and quickReply.Visible
        local bottom = INPUT_H
            + (S.panelOpen and PANEL_H or 0)
            + (hasReply and REPLY_H or 0)
            + (hasQuick and QUICK_H or 0)
        scroll.Position = UDim2.new(0, 0, 0, HEADER + extraTop)
        scroll.Size = UDim2.new(1, 0, 1, -(HEADER + extraTop + bottom))
        panel.Visible = S.panelOpen
        replyBar.Visible = hasReply
        privHeader.Visible = S.kind == "private"
        local lift = INPUT_H + (S.panelOpen and PANEL_H or 0)
        if hasReply then
            replyBar.Position = UDim2.new(0, 8, 1, -(lift - 6 + (hasQuick and QUICK_H or 0)))
        end
        if hasQuick then
            quickReply.Position = UDim2.new(0, 8, 1, -(lift + REPLY_H))
        end
        panel.Position = UDim2.new(0, 8, 1, -(INPUT_H + (hasReply and REPLY_H or 0) + (hasQuick and QUICK_H or 0)))
    end

    local function clearReply()
        S.replyTo = nil
        replyNameLbl.Text = ""
        replyTextLbl.Text = ""
        quickReply.Visible = false
        relayout()
    end

    local function buildQuickReply(m)
        -- wipe old react / sticker buttons (keep layout + label)
        for _, c in ipairs(quickReply:GetChildren()) do
            if c:IsA("TextButton") or (c:IsA("TextLabel") and c ~= quickLabel) then
                if c ~= quickLabel then c:Destroy() end
            end
        end
        -- reaction shortcuts
        for i, emoji in ipairs(REACT_SET) do
            local b = New("TextButton", {
                Size = UDim2.new(0, 30, 0, 28),
                BackgroundTransparency = 0.85,
                Text = emoji,
                TextSize = 16,
                Font = Enum.Font.Gotham,
                AutoButtonColor = false,
                LayoutOrder = i,
                Bind = { BackgroundColor3 = "other" },
                Parent = quickReply,
            }, { corner(8) })
            b.MouseButton1Click:Connect(function()
                if m and m._k then
                    task.spawn(function()
                        call("PUT", urlFor("chat/" .. S.room .. "/messages/" .. tostring(m._k) .. "/reacts/" .. HttpService:UrlEncode(emoji)), encode(1))
                    end)
                end
                -- also optional: send emoji as reply text
                -- send(emoji)
                clearReply()
            end)
        end
        -- Sticker reply button
        local st = New("TextButton", {
            Size = UDim2.new(0, 64, 0, 28),
            Text = "Sticker",
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = false,
            LayoutOrder = 50,
            Bind = { BackgroundColor3 = "own", TextColor3 = "ownText" },
            Parent = quickReply,
        }, { corner(8) })
        st.MouseButton1Click:Connect(function()
            -- keep S.replyTo so the sticker is sent as a reply quote
            quickReply.Visible = false
            openStickersPanel()
            relayout()
        end)
        -- Type instead
        local ty = New("TextButton", {
            Size = UDim2.new(0, 56, 0, 28),
            Text = "Type",
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            AutoButtonColor = false,
            LayoutOrder = 51,
            Bind = { BackgroundColor3 = "other", TextColor3 = "text" },
            Parent = quickReply,
        }, { corner(8) })
        ty.MouseButton1Click:Connect(function()
            quickReply.Visible = false
            relayout()
            pcall(function() input:CaptureFocus() end)
        end)
    end

    local function setReply(m)
        if not m then return clearReply() end
        local t = tostring(m.text or ""):sub(1, 80)
        if t:match("^%[%[STICKER:") then t = "[Sticker]" end
        S.replyTo = {
            uid = m.uid, user = m.user or "?", dn = m.dn or m.user or "?",
            text = t, key = m._k,
        }
        replyNameLbl.Text = cleanName(S.replyTo.dn)
        replyTextLbl.Text = t
        buildQuickReply(m)
        quickReply.Visible = true
        relayout()
    end
    replyClose.MouseButton1Click:Connect(clearReply)

    local function hideCtx()
        ctxMenu.Visible = false
        if S._menuDim then S._menuDim.Visible = false end
        S.menuOpen = nil
    end
    local function hideProfile()
        profileCard.Visible = false
        for _, c in ipairs(profileCard:GetChildren()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") or c:IsA("ImageLabel") then c:Destroy() end
        end
        S.profileOpen = nil
    end

    local function showProfile(m)
        hideProfile()
        hideCtx()
        S.profileOpen = m
        profileCard.Visible = true
        local av = New("ImageLabel", {
            Size = UDim2.new(0, 48, 0, 48), BackgroundTransparency = 0.5,
            Bind = { BackgroundColor3 = "other" }, LayoutOrder = 1, Parent = profileCard,
        }, { corner(24) })
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(tonumber(m.uid) or 0, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content and av.Parent then av.Image = content end
        end)
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
            Text = cleanName(m.dn or m.user or "?"),
            TextSize = 14, Font = Enum.Font.GothamBold, LayoutOrder = 2,
            Bind = { TextColor3 = "text" }, Parent = profileCard,
        })
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
            Text = "@" .. cleanName(m.user or "?"),
            TextSize = 11, Font = Enum.Font.Gotham, TextTransparency = 0.35,
            LayoutOrder = 3, Bind = { TextColor3 = "text" }, Parent = profileCard,
        })
        if m.script and m.script ~= "" then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
                Text = "Script: " .. tostring(m.script),
                TextSize = 11, Font = Enum.Font.Gotham, LayoutOrder = 4,
                Bind = { TextColor3 = "text" }, Parent = profileCard,
            })
        end
        local dmBtn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), Text = "Private message",
            TextSize = 12, Font = Enum.Font.GothamBold, LayoutOrder = 5,
            Bind = { BackgroundColor3 = "own", TextColor3 = "ownText" }, Parent = profileCard,
        }, { corner(8) })
        dmBtn.MouseButton1Click:Connect(function()
            hideProfile()
            setRoom("private", tonumber(m.uid), m.dn or m.user)
        end)
        local frBtn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 28), Text = "Friend request",
            TextSize = 12, Font = Enum.Font.GothamMedium, LayoutOrder = 6,
            Bind = { BackgroundColor3 = "other", TextColor3 = "text" }, Parent = profileCard,
        }, { corner(8) })
        frBtn.MouseButton1Click:Connect(function()
            send("👋 Friend request to @" .. tostring(m.user or ""), { t = "msg" })
            hideProfile()
            pcall(function()
                if WindUI and WindUI.Notify then
                    WindUI:Notify({ Title = "Sent", Content = "Friend request message sent", Duration = 1.5, Icon = "user-plus" })
                end
            end)
        end)
        local closeP = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 24), Text = "Close",
            TextSize = 11, Font = Enum.Font.Gotham, LayoutOrder = 7,
            BackgroundTransparency = 1, Bind = { TextColor3 = "text" }, Parent = profileCard,
        })
        closeP.MouseButton1Click:Connect(hideProfile)
    end

    -- full-screen dim behind context menu; tap anywhere to close
    if not S._menuDim then
        local menuDim = New("TextButton", {
            Name = "NeoMenuDim",
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.55,
            Text = "",
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 40,
            Parent = root,
        })
        S._menuDim = menuDim
        menuDim.MouseButton1Click:Connect(function()
            hideCtx()
            hideProfile()
            if S._menuDim then S._menuDim.Visible = false end
        end)
    end
    local menuDim = S._menuDim

    local function showCtx(m, own, anchorGui)
        hideCtx()
        hideProfile()
        S.menuOpen = m
        for _, c in ipairs(ctxMenu:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local function item(label, cb)
            local b = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 28), Text = "  " .. label,
                TextSize = 12, Font = Enum.Font.GothamMedium,
                TextXAlignment = Enum.TextXAlignment.Left,
                Bind = { BackgroundColor3 = "other", TextColor3 = "text" },
                LayoutOrder = #ctxMenu:GetChildren(), Parent = ctxMenu,
                ZIndex = 45,
            }, { corner(6) })
            b.MouseButton1Click:Connect(function() hideCtx(); if menuDim then menuDim.Visible = false end; cb() end)
        end
        if not parseSticker(m.text) then
            item("Copy", function()
                local txt = tostring(m.text or "")
                pcall(function()
                    if setclipboard then setclipboard(txt) elseif toclipboard then toclipboard(txt) end
                end)
            end)
        end
        item("Reply", function() setReply(m) end)
        for _, em in ipairs(REACT_SET) do
            item("React " .. em, function() addReact(m._k, em) end)
        end
        if ME_IS_OWNER and m._k then
            item("Pin", function()
                task.spawn(function()
                    call("PUT", urlFor("chat/" .. S.room .. "/pin"), encode({
                        key = m._k, text = tostring(m.text or ""):sub(1, 120),
                        user = m.user, dn = m.dn, uid = m.uid,
                    }))
                    S.pin = { key = m._k, text = tostring(m.text or ""):sub(1, 120), user = m.user, dn = m.dn }
                    refreshPinBar()
                end)
            end)
            item("Delete", function()
                task.spawn(function() call("DELETE", urlFor("chat/" .. S.room .. "/messages/" .. m._k)) end)
                local ui = msgUi[tostring(m._k)]
                if ui and ui.row then pcall(function() ui.row:Destroy() end) end
            end)
        end
        -- position menu next to the message bubble (follow the message)
        local rootPos = root.AbsolutePosition
        local ax, ay = root.AbsoluteSize.X * 0.5 - 70, root.AbsoluteSize.Y * 0.35
        if anchorGui and anchorGui.Parent then
            local ap = anchorGui.AbsolutePosition
            local asz = anchorGui.AbsoluteSize
            ax = ap.X - rootPos.X
            ay = ap.Y - rootPos.Y + asz.Y + 4
            -- keep on screen
            if ax + 140 > root.AbsoluteSize.X then ax = math.max(8, root.AbsoluteSize.X - 148) end
            if ax < 8 then ax = 8 end
            if ay + 180 > root.AbsoluteSize.Y then ay = math.max(8, ap.Y - rootPos.Y - 160) end
        end
        ctxMenu.ZIndex = 45
        ctxMenu.Position = UDim2.new(0, math.floor(ax), 0, math.floor(ay))
        if menuDim then menuDim.Visible = true end
        ctxMenu.Visible = true
    end

    function refreshPinBar()
        if S.pin and S.pin.text then
            local t = tostring(S.pin.text)
            if t:match("^%[%[STICKER:") then t = "[Sticker]" end
            pinText.Text = "📌 " .. cleanName(S.pin.dn or S.pin.user or "") .. ": " .. t
            pinBar.Visible = true
        else
            pinBar.Visible = false
        end
        relayout()
    end
    pinClose.MouseButton1Click:Connect(function()
        if not ME_IS_OWNER then return end
        task.spawn(function() call("DELETE", urlFor("chat/" .. S.room .. "/pin")) end)
        S.pin = nil
        refreshPinBar()
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        S.searchQuery = searchBox.Text or ""
        local q = S.searchQuery:lower()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("Frame") and c:GetAttribute("MsgText") ~= nil then
                if q == "" then c.Visible = true
                else c.Visible = tostring(c:GetAttribute("MsgText")):lower():find(q, 1, true) ~= nil end
            end
        end
    end)

    -------------------------------------------------------------- Stickers (ALL + favorites)
    function openStickersPanel()
        S.panelOpen = true
        panelTitle.Text = "Stickers"
        panelScroll.Visible = true
        privateList.Visible = false
        for _, c in ipairs(panelScroll:GetChildren()) do
            if c:IsA("ImageButton") then c:Destroy() end
        end
        for _, c in ipairs(favRow:GetChildren()) do
            if c:IsA("ImageButton") then c:Destroy() end
        end
        local order = StickerCatalog.Order
        local stickers = StickerCatalog.Stickers
        if not StickerCatalog.Ready or #order == 0 then
            panelTitle.Text = "Stickers (loading...)"
            task.delay(0.8, function()
                if S.panelOpen and panelTitle.Text:find("loading") then openStickersPanel() end
            end)
            return
        end
        -- favorites strip
        local favs = Settings.StickerFavs or {}
        if #favs > 0 then
            favRow.Visible = true
            panelScroll.Position = UDim2.new(0, 0, 0, 58)
            panelScroll.Size = UDim2.new(1, 0, 1, -62)
            for i, img in ipairs(favs) do
                local btn = New("ImageButton", {
                    Size = UDim2.new(0, 32, 0, 32), BackgroundTransparency = 0.85,
                    Image = tostring(img), ScaleType = Enum.ScaleType.Fit,
                    LayoutOrder = i, ZIndex = 7, Parent = favRow,
                }, { corner(6) })
                btn.MouseButton1Click:Connect(function()
                    local payload = stickerPayload(img)
                    if payload then send(payload); S.panelOpen = false; relayout() end
                end)
            end
        else
            favRow.Visible = false
            panelScroll.Position = UDim2.new(0, 0, 0, 22)
            panelScroll.Size = UDim2.new(1, 0, 1, -26)
        end
        for i = 1, #order do
            local key = order[i]
            local info = stickers[key]
            if type(info) == "table" and info.Image then
                local btn = New("ImageButton", {
                    Size = UDim2.new(0, 44, 0, 44), BackgroundTransparency = 0.88,
                    Image = tostring(info.Image), ScaleType = Enum.ScaleType.Fit,
                    LayoutOrder = i, ZIndex = 7, Parent = panelScroll,
                }, { corner(8) })
                btn.MouseButton1Click:Connect(function()
                    pushStickerFav(info.Image)
                    local payload = stickerPayload(info.Image)
                    if payload then send(payload); S.panelOpen = false; relayout() end
                end)
            end
        end
    end

    function openPrivatePanel()
        S.panelOpen = true
        panelTitle.Text = "Private — recent & online"
        panelScroll.Visible = false
        privateList.Visible = true
        favRow.Visible = false
        for _, c in ipairs(privateList:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        -- Recent DMs first
        local recent = Settings.RecentDMs or {}
        if #recent > 0 then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
                Text = "Recent", TextSize = 11, Font = Enum.Font.GothamBold,
                TextTransparency = 0.3, Bind = { TextColor3 = "text" }, Parent = privateList,
            })
            for _, e in ipairs(recent) do
                local b = New("TextButton", {
                    Size = UDim2.new(1, -4, 0, 30),
                    Text = "  " .. cleanName(e.name),
                    TextSize = 12, Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Bind = { BackgroundColor3 = "other", TextColor3 = "text" },
                    ZIndex = 7, Parent = privateList,
                }, { corner(8) })
                b.MouseButton1Click:Connect(function()
                    S.panelOpen = false
                    setRoom("private", tonumber(e.uid), e.name)
                    relayout()
                end)
            end
        end
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
            Text = "In this server", TextSize = 11, Font = Enum.Font.GothamBold,
            TextTransparency = 0.3, Bind = { TextColor3 = "text" }, Parent = privateList,
        })
        local any = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                any = true
                local label = cleanName(plr.DisplayName) .. "  @" .. cleanName(plr.Name)
                local b = New("TextButton", {
                    Size = UDim2.new(1, -4, 0, 30),
                    Text = "  " .. label,
                    TextSize = 12, Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Bind = { BackgroundColor3 = "other", TextColor3 = "text" },
                    ZIndex = 7, Parent = privateList,
                }, { corner(8) })
                b.MouseButton1Click:Connect(function()
                    S.panelOpen = false
                    setRoom("private", plr.UserId, plr.DisplayName or plr.Name)
                    relayout()
                end)
            end
        end
        if not any then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
                Text = "No other players in this server",
                TextSize = 12, Font = Enum.Font.Gotham, TextTransparency = 0.4,
                Bind = { TextColor3 = "text" }, Parent = privateList,
            })
        end
    end

    local function maskOnlineName(name)
        name = tostring(name or "?")
        -- strip control chars
        name = name:gsub("[%c%z]", "")
        local first2 = ""
        local count = 0
        for _, code in utf8Codes(name) do
            count = count + 1
            if count <= 2 then
                first2 = first2 .. utf8Char(code)
            end
        end
        if first2 == "" then first2 = "??" end
        local rest = math.max(3, math.min(8, math.max(0, count - 2)))
        if count <= 2 then rest = 3 end
        return first2 .. string.rep("*", rest)
    end

    function openOnlinePanel()
        S.panelOpen = true
        panelTitle.Text = "Online now"
        panelScroll.Visible = false
        privateList.Visible = true
        favRow.Visible = false
        for _, c in ipairs(privateList:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        -- live refresh presence then list (names masked: 2 chars + ***)
        task.spawn(function()
            local ok, body = call("GET", urlFor("presence"))
            if ok then
                local data = decode(body)
                if type(data) == "table" then
                    local newest, map = 0, {}
                    for _, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and v.t > newest then newest = v.t end
                    end
                    for uid, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and newest - v.t < 90000 then
                            map[tostring(uid)] = tostring(v.n or uid)
                        end
                    end
                    S.onlineMap = map
                    do
                        local n = 0
                        for _ in pairs(map) do n = n + 1 end
                        S.online = math.max(1, n)
                    end
                end
            end
            if not privateList.Parent then return end
            for _, c in ipairs(privateList:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
            end
            local count = 0
            for uid, name in pairs(S.onlineMap or {}) do
                count = count + 1
                New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
                    Text = "  ●  " .. maskOnlineName(name),
                    TextSize = 12, Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextColor3 = Color3.fromRGB(80, 200, 120), Parent = privateList,
                })
            end
            if count == 0 then
                New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
                    Text = "No presence data yet",
                    TextSize = 12, Font = Enum.Font.Gotham, TextTransparency = 0.4,
                    Bind = { TextColor3 = "text" }, Parent = privateList,
                })
            end
        end)
    end

    -------------------------------------------------------------- Side notifs
    local sideGui, sideContainer
    local function ensureSideGui()
        if sideGui and sideGui.Parent then return end
        local parent = nil
        pcall(function() if gethui then parent = gethui() end end)
        if not parent then parent = game:GetService("CoreGui") end
        sideGui = Instance.new("ScreenGui")
        sideGui.Name = "NeoChatSideNotifs"
        sideGui.IgnoreGuiInset = true
        sideGui.ResetOnSpawn = false
        sideGui.DisplayOrder = 120
        sideGui.Parent = parent
        sideContainer = Instance.new("Frame")
        sideContainer.AnchorPoint = Vector2.new(1, 0)
        sideContainer.Position = UDim2.new(1, -10, 0, 54)
        sideContainer.Size = UDim2.new(0, 230, 0, 0)
        sideContainer.AutomaticSize = Enum.AutomaticSize.Y
        sideContainer.BackgroundTransparency = 1
        sideContainer.Parent = sideGui
        local list = Instance.new("UIListLayout")
        list.SortOrder = Enum.SortOrder.LayoutOrder
        list.Padding = UDim.new(0, 6)
        list.HorizontalAlignment = Enum.HorizontalAlignment.Right
        list.Parent = sideContainer
    end
    local function showSideNotif(m)
        if not Settings.SideNotifs or isMuted() then return end
        ensureSideGui()
        local dur = tonumber(Settings.SideNotifDuration) or 3.2
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0, 220, 0, 0)
        card.AutomaticSize = Enum.AutomaticSize.Y
        card.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
        card.BackgroundTransparency = 0.38
        card.BorderSizePixel = 0
        card.Parent = sideContainer
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
        local p = Instance.new("UIPadding")
        p.PaddingTop = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)
        p.PaddingLeft = UDim.new(0, 8); p.PaddingRight = UDim.new(0, 8)
        p.Parent = card
        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, 0, 0, 14)
        nameL.BackgroundTransparency = 1
        nameL.Text = cleanName(m.dn or m.user or "Someone")
        nameL.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameL.TextSize = 12; nameL.Font = Enum.Font.GothamBold
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.Parent = card
        local msgL = Instance.new("TextLabel")
        msgL.Size = UDim2.new(1, 0, 0, 0)
        msgL.AutomaticSize = Enum.AutomaticSize.Y
        msgL.BackgroundTransparency = 1
        local preview = tostring(m.text or "")
        if parseSticker(preview) then preview = "[Sticker]" end
        msgL.Text = clipUtf8(preview, 68)
        msgL.TextColor3 = Color3.fromRGB(155, 155, 160)
        msgL.TextSize = 12; msgL.Font = Enum.Font.Gotham
        msgL.TextXAlignment = Enum.TextXAlignment.Left
        msgL.TextWrapped = true
        msgL.Parent = card
        card.Position = UDim2.new(0, 28, 0, 0)
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.delay(dur, function()
            if not card or not card.Parent then return end
            local tw = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
            tw:Play(); tw.Completed:Wait(); card:Destroy()
        end)
    end

    -------------------------------------------------------------- Badge
    local badge = New("Frame", {
        Name = "NeoBadge", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30, Parent = sideBtn,
    }, {
        corner(9), New("UISizeConstraint", { MinSize = Vector2.new(18, 18) }),
        New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.55, Thickness = 1 }),
        pad(5, 0, 5, 0),
    })
    local badgeScale = New("UIScale", { Scale = 1, Parent = badge })
    local badgeLbl = New("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1, Text = "0",
        TextColor3 = Color3.new(1, 1, 1), TextSize = 11,
        Font = Enum.Font.GothamBold, ZIndex = 31, Parent = badge,
    })
    local function unreadCount()
        local n = 0
        for _, c in pairs(S.unread) do n = n + (BADGE_MODE == "messages" and c or 1) end
        return n
    end
    local function updateBadge()
        local n = unreadCount()
        if n <= 0 then badge.Visible = false; S.lastBadge = 0; return end
        badgeLbl.Text = n > 99 and "99+" or tostring(n)
        badge.Visible = true
        if n ~= S.lastBadge then
            badgeScale.Scale = 1.35
            TweenService:Create(badgeScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end
        S.lastBadge = n
    end
    local function viewing()
        local closed = false
        pcall(function() closed = Window.Closed == true or Window.Destroyed == true end)
        return canvas and canvas.Visible and not closed
    end
    local function clearUnread()
        if next(S.unread) ~= nil then S.unread = {} end
        updateBadge()
    end

    local avatarCache = {}
    local function loadAvatar(uid, img)
        if avatarCache[uid] then img.Image = avatarCache[uid]; return end
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content then
                avatarCache[uid] = content
                if img.Parent then img.Image = content end
            end
        end)
    end

    local constraints = {}
    local function scale() return (WindUI.UIScaleObj and WindUI.UIScaleObj.Scale) or 1 end
    local function labelMax()
        local base = Settings.CompactMode and 160 or 120
        return math.max(base, scroll.AbsoluteSize.X / scale() - (Settings.CompactMode and 100 or 120))
    end
    local function newConstraint(parent)
        local c = New("UISizeConstraint", { MaxSize = Vector2.new(labelMax(), 100000), Parent = parent })
        constraints[#constraints + 1] = c
        return c
    end
    scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local m, keep = labelMax(), {}
        for _, c in ipairs(constraints) do
            if c.Parent then c.MaxSize = Vector2.new(m, 100000); keep[#keep + 1] = c end
        end
        constraints = keep
    end)

    local order = 0
    local function isNearBottom()
        return scroll.AbsoluteCanvasSize.Y - (scroll.CanvasPosition.Y + scroll.AbsoluteSize.Y) < 90
    end
    local function scrollDown()
        task.defer(function() scroll.CanvasPosition = Vector2.new(0, 1e6) end)
    end
    local function setStatus(ui, state)
        if not ui or not ui.time or not ui.own then return end
        local icon = (state == "pending" and " ...") or (state == "failed" and " !") or " OK"
        ui.time.Text = ui.timeText .. icon
    end
    local function mentionsMe(text)
        if not Settings.MentionsEnabled then return false end
        local t = tostring(text or ""):lower()
        local function hasFull(n)
            local pos = 1
            while true do
                local s, e = t:find(n, pos, true)
                if not s then return false end
                local before = s == 1 or t:sub(s-1, s-1):match("[%s%p]")
                local after  = e == #t or t:sub(e+1, e+1):match("[%s%p]")
                if before and after then return true end
                pos = e + 1
            end
        end
        return hasFull("@" .. ME_NAME:lower()) or hasFull("@" .. ME_DN:lower())
    end
    local function deleteMessage(key)
        if not ME_IS_OWNER or not key then return end
        task.spawn(function() call("DELETE", urlFor("chat/" .. S.room .. "/messages/" .. key)) end)
    end
    -- message UI registry so reacts update under the bubble (never as chat messages)
    local msgUi = {}
    local function formatReacts(reacts)
        local rtxt = {}
        if type(reacts) ~= "table" then return "" end
        for emoji, cnt in pairs(reacts) do
            local n = tonumber(cnt) or 0
            if n > 0 then rtxt[#rtxt + 1] = tostring(emoji) .. (n > 1 and ("×" .. n) or "") end
        end
        table.sort(rtxt)
        return table.concat(rtxt, "  ")
    end
    local function applyReactsToUi(ui, reacts)
        if not ui then return end
        ui.reacts = reacts
        local text = formatReacts(reacts)
        if text == "" then
            if ui.reactChip then ui.reactChip.Visible = false end
            if ui.reactLabel then ui.reactLabel.Text = "" end
            return
        end
        if ui.reactChip and ui.reactLabel then
            ui.reactLabel.Text = text
            ui.reactChip.Visible = true
        end
    end
    local function addReact(key, emoji)
        if not key then return end
        local ui = msgUi[tostring(key)]
        if ui then
            ui.reacts = ui.reacts or {}
            local cur = tonumber(ui.reacts[emoji]) or 0
            ui.reacts[emoji] = cur + 1
            applyReactsToUi(ui, ui.reacts)
        end
        task.spawn(function()
            call("PUT", urlFor("chat/" .. S.room .. "/messages/" .. tostring(key) .. "/reacts/" .. HttpService:UrlEncode(emoji)), encode(1))
        end)
    end

    -------------------------------------------------------------- Render
    local function render(m, own, state)
        if m.deleted then return end
        emptyLbl.Visible = false
        local nearBottom = isNearBottom()
        order = order + 1
        local ts = tonumber(type(m.ts) == "number" and m.ts or nil)
        local seconds = ts and math.floor(ts / 1000) or os.time()
        local timeStr = os.date("%I:%M %p", seconds)
        if timeStr:sub(1,1) == "0" then timeStr = timeStr:sub(2) end

        local ui = { own = own, timeText = timeStr, msg = m, key = m._k }
        local avSize = Settings.CompactMode and 22 or 28
        local stickSize = Settings.CompactMode and 72 or 96

        local row = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = order, Parent = scroll,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = own and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Bottom,
                Padding = UDim.new(0, 6),
            }),
        })
        row:SetAttribute("MsgText", tostring(m.text or ""))
        ui.row = row

        if Settings.MessageAnims then
            local sc = Instance.new("UIScale")
            sc.Scale = 0.93; sc.Parent = row
            TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end

        local swipeHost = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, LayoutOrder = own and 1 or 2, Parent = row,
        })
        local avatar = New("ImageLabel", {
            Size = UDim2.new(0, avSize, 0, avSize), LayoutOrder = own and 2 or 1,
            Bind = { BackgroundColor3 = "other" }, Parent = row,
        }, { corner(avSize/2) })
        loadAvatar(tonumber(m.uid) or 0, avatar)
        -- profile peek on avatar
        local avBtn = New("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", Parent = avatar, ZIndex = 2,
        })
        avBtn.MouseButton1Click:Connect(function() showProfile(m) end)

        local bubble = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            Bind = { BackgroundColor3 = own and "own" or "other" }, Parent = swipeHost,
        }, {
            corner(11), pad(9, 5, 9, 5),
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
        })
        if not own and mentionsMe(m.text) then
            New("UIStroke", { Color = Color3.fromRGB(255, 196, 0), Thickness = 1.4, Parent = bubble })
        end

        if m.reply and type(m.reply) == "table" then
            local qFrame = New("Frame", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.72,
                LayoutOrder = 0, Parent = bubble,
            }, {
                corner(5), pad(5, 3, 5, 3),
                New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1) }),
            })
            New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1, Text = cleanName(m.reply.dn or m.reply.user or "?"),
                TextSize = 10, Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(0, 170, 255), LayoutOrder = 1, Parent = qFrame,
            })
            local rt = tostring(m.reply.text or "")
            if rt:match("^%[%[STICKER:") then rt = "[Sticker]" end
            New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1, Text = clipUtf8(rt, 55),
                TextSize = 10, Font = Enum.Font.Gotham, TextTransparency = 0.3,
                Bind = { TextColor3 = "text" }, LayoutOrder = 2, Parent = qFrame,
            })
        end

        local function label(props)
            props.Size = UDim2.new(0, 0, 0, 0)
            props.AutomaticSize = Enum.AutomaticSize.XY
            props.BackgroundTransparency = 1
            props.TextWrapped = true
            props.RichText = true
            props.TextXAlignment = Enum.TextXAlignment.Left
            props.Parent = bubble
            local l = New("TextLabel", props)
            newConstraint(l)
            return l
        end
        local function textColor(props)
            props.Bind = { TextColor3 = own and "ownText" or "text" }
            return props
        end

        local uid = tonumber(m.uid) or 0
        if not own then
            local col = Color3.fromHSV((uid % 97) / 97, 0.5, 1):ToHex()
            local dn = cleanName(m.dn or m.user or "?")
            local un = cleanName(m.user or "")
            local who = (dn ~= un and un ~= "" and un ~= "?") and (esc(dn) .. ' <font transparency="0.5">@' .. esc(un) .. "</font>") or esc(dn)
            if isOwner(m.user) then who = who .. '  <font color="#FFD700">Owner</font>' end
            if m.ownerTag and m.ownerTag ~= "" then
                who = who .. '  <font color="#FFD700">' .. esc(tostring(m.ownerTag)) .. "</font>"
            end
            local nameRow = New("Frame", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1, LayoutOrder = 1, Parent = bubble,
            }, {
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 4),
                }),
            })
            if Settings.ShowScriptIcon and m.scriptImg and m.scriptImg ~= "" then
                New("ImageLabel", {
                    Size = UDim2.new(0, 13, 0, 13), BackgroundTransparency = 1,
                    Image = tostring(m.scriptImg), Parent = nameRow,
                }, { corner(3) })
            end
            if m.script and m.script ~= "" then
                who = who .. '  <font transparency="0.45" size="10">[' .. esc(tostring(m.script)) .. "]</font>"
            end
            New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1, RichText = true,
                Text = '<font color="#' .. col .. '">' .. who .. "</font>",
                TextSize = 11, Font = Enum.Font.GothamBold, Parent = nameRow,
            })
        end

        local frames, interval = parseSticker(m.text)
        if frames then
            local stickerImg = New("ImageLabel", {
                Size = UDim2.new(0, stickSize, 0, stickSize),
                BackgroundTransparency = 1, Image = frames[1],
                ScaleType = Enum.ScaleType.Fit, LayoutOrder = 2, Parent = bubble,
            }, { corner(8) })
            if #frames > 1 then
                task.spawn(function()
                    local i = 1
                    while stickerImg and stickerImg.Parent do
                        i = i % #frames + 1
                        stickerImg.Image = frames[i]
                        task.wait(interval or 0.4)
                    end
                end)
            end
        elseif m.t == "invite" then
            label(textColor({ Text = "<b>Server invite</b>", TextSize = 13, Font = Enum.Font.GothamMedium, LayoutOrder = 2 }))
            label(textColor({ Text = esc(m.game or "Roblox"), TextSize = 12, Font = Enum.Font.Gotham, LayoutOrder = 3 }))
            local here = tostring(m.job) == game.JobId
            local expired = (os.time() - seconds) > 900
            local btn = New("TextButton", {
                Size = UDim2.new(0, 120, 0, 26), LayoutOrder = 6, TextSize = 12,
                Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1), Parent = bubble,
                Text = here and "Here" or (expired and "Expired" or "Join"),
                BackgroundColor3 = (here or expired) and Color3.fromRGB(70, 70, 74) or Color3.fromRGB(51, 199, 89),
            }, { corner(7) })
            if not here and not expired then
                btn.MouseButton1Click:Connect(function()
                    btn.Text = "..."
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(tonumber(m.place), tostring(m.job), LocalPlayer)
                    end)
                end)
            end
        else
            local raw = tostring(m.text or "")
            if raw:match("^%[%[STICKER:") then
                New("ImageLabel", {
                    Size = UDim2.new(0, 64, 0, 64), BackgroundTransparency = 1,
                    Image = "", LayoutOrder = 2, Parent = bubble,
                }, { corner(8) })
            else
                label(textColor({ Text = esc(m.text), TextSize = Settings.CompactMode and 12 or 13, Font = Enum.Font.GothamMedium, LayoutOrder = 2 }))
            end
        end

        -- React chips: small bubble UNDER the message (never sent as chat text)
        do
            local chip = New("Frame", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0.4,
                LayoutOrder = 8, Parent = bubble,
                Visible = false,
            }, {
                corner(10), pad(6, 2, 6, 2),
            })
            local rlab = New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                Text = "",
                TextSize = 12, Font = Enum.Font.Gotham,
                TextColor3 = Color3.new(1, 1, 1),
                Parent = chip,
            })
            ui.reactChip = chip
            ui.reactLabel = rlab
            ui.reacts = type(m.reacts) == "table" and m.reacts or {}
            applyReactsToUi(ui, ui.reacts)
        end

        -- time + icon actions UNDER the bubble content
        local timeRow = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, LayoutOrder = 9, Parent = bubble,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
            }),
        })
        ui.time = New("TextLabel", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, Text = timeStr,
            TextSize = 10, Font = Enum.Font.Gotham, TextTransparency = 0.4,
            Bind = { TextColor3 = own and "ownText" or "text" }, Parent = timeRow,
        })
        setStatus(ui, state or "sent")

        local function iconAct(iconName, fallback, cb)
            local b = New("TextButton", {
                Size = UDim2.new(0, 20, 0, 16), BackgroundTransparency = 1,
                Text = "", AutoButtonColor = false, Parent = timeRow,
            })
            local asset = getIconImage(iconName)
            if asset then
                local img = New("ImageLabel", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.new(0, 13, 0, 13), BackgroundTransparency = 1,
                    Image = asset, ScaleType = Enum.ScaleType.Fit, Parent = b,
                })
                pcall(function() img.ImageColor3 = own and P.ownText or P.text end)
                img.ImageTransparency = 0.28
            else
                New("TextLabel", {
                    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                    Text = fallback, TextSize = 10, Font = Enum.Font.GothamBold,
                    TextTransparency = 0.3, Bind = { TextColor3 = own and "ownText" or "text" }, Parent = b,
                })
            end
            b.MouseButton1Click:Connect(cb)
            return b
        end
        if not frames then
            iconAct("copy", "C", function()
                pcall(function()
                    if setclipboard then setclipboard(tostring(m.text or ""))
                    elseif toclipboard then toclipboard(tostring(m.text or "")) end
                end)
            end)
        end
        iconAct("reply", "R", function() setReply(m) end)
        iconAct("heart", "H", function() addReact(m._k, "❤️") end)
        if ME_IS_OWNER and m._k then
            iconAct("trash-2", "X", function()
                deleteMessage(m._k)
                pcall(function() row:Destroy() end)
            end)
        end

        -- double-tap react + long-press menu
        local lastTap, pressStart = 0, nil
        bubble.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                pressStart = os.clock()
                local now = os.clock()
                if now - lastTap < 0.35 then
                    addReact(m._k, "❤️")
                    lastTap = 0
                else
                    lastTap = now
                end
            end
        end)
        bubble.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                if pressStart and (os.clock() - pressStart) > 0.45 then
                    showCtx(m, own, bubble)
                end
                pressStart = nil
            end
        end)

        -- swipe reply
        local dragStart, dragging = nil, false
        bubble.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = inp.Position
            end
        end)
        bubble.InputChanged:Connect(function(inp)
            if not dragging or not dragStart then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                local delta = inp.Position.X - dragStart.X
                local dir = own and -1 or 1
                bubble.Position = UDim2.new(0, math.clamp(delta * dir, 0, 64) * dir, 0, 0)
            end
        end)
        bubble.InputEnded:Connect(function(inp)
            if not dragging then return end
            dragging = false
            local delta = inp and (inp.Position.X - (dragStart and dragStart.X or 0)) or 0
            local dir = own and -1 or 1
            if delta * dir > 42 then setReply(m) end
            TweenService:Create(bubble, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()
            dragStart = nil
        end)

        S.shown = S.shown + 1
        if S.shown > 140 then
            for _, c in ipairs(scroll:GetChildren()) do
                if c:IsA("Frame") then c:Destroy(); S.shown = S.shown - 1; break end
            end
        end
        if own or nearBottom then scrollDown() end
        return ui
    end

    local function toast(m)
        if not TOAST or isMuted() or os.clock() - S.lastToast < 2.5 then return end
        S.lastToast = os.clock()
        local body = m.t == "invite" and "sent an invite" or clipUtf8(tostring(m.text or ""), 70)
        if parseSticker(tostring(m.text or "")) then body = "sent a sticker" end
        pcall(function()
            WindUI:Notify({ Title = cleanName(m.dn or m.user or "Chat"), Content = body, Duration = 2.6, Icon = "message-circle" })
        end)
    end
    local function registerUnread(m)
        if viewing() then return end
        if isMuted() then return end
        local k = tostring(m.uid)
        S.unread[k] = (S.unread[k] or 0) + 1
        if S.kind ~= "private" and tostring(S.room):sub(1, 3) == "dm_" then
            -- n/a
        end
        -- track dm unreads when message is for a dm room while viewing global
        if tostring(m._room or ""):sub(1, 3) == "dm_" or S.kind == "private" then
            S.dmUnread[k] = (S.dmUnread[k] or 0) + 1
            updateDMBadge()
        end
        updateBadge()
        toast(m)
        if mentionsMe(m.text) then showSideNotif(m) end
    end

    local function processMessage(m, isHistory)
        local key = m._k
        if S.seen[key] then
            -- already drawn: only refresh reacts / deleted under the same bubble
            local ui = msgUi[tostring(key)]
            if m.deleted and ui and ui.row then
                pcall(function() ui.row:Destroy() end)
                msgUi[tostring(key)] = nil
                return
            end
            if ui and m.reacts then
                applyReactsToUi(ui, m.reacts)
            end
            return
        end
        S.seen[key] = true
        if not S.lastKey or key > S.lastKey then S.lastKey = key end
        if m.deleted then return end
        if m.cid and S.pending[m.cid] then
            setStatus(S.pending[m.cid], "sent")
            S.pending[m.cid] = nil
            -- still register reacts if any
            local ui = msgUi[tostring(key)]
            if ui and m.reacts then applyReactsToUi(ui, m.reacts) end
            return
        end
        local own = tonumber(m.uid) == ME_ID
        local ui = render(m, own, "sent")
        if ui and key then
            msgUi[tostring(key)] = ui
            if m.reacts then applyReactsToUi(ui, m.reacts) end
        end
        if not isHistory and not own then registerUnread(m) end
    end

    local function pollOnce()
        local gen, room = S.gen, S.room
        -- always pull recent history so reacts/pins update on existing bubbles
        local q = "orderBy=%22%24key%22&limitToLast=" .. HISTORY
        local ok, body = call("GET", urlFor("chat/" .. room .. "/messages", q))
        if not ok then return false end
        if gen ~= S.gen then return true end
        local data = decode(body)
        local arr = {}
        if type(data) == "table" then
            for k, v in pairs(data) do
                if type(v) == "table" then v._k = k; arr[#arr + 1] = v end
            end
            table.sort(arr, function(a, b) return a._k < b._k end)
        end
        local history = not S.loaded
        for _, m in ipairs(arr) do processMessage(m, history) end
        S.loaded = true
        if #arr == 0 and S.shown == 0 then emptyLbl.Visible = true end
        -- pin
        local pok, pbody = call("GET", urlFor("chat/" .. room .. "/pin"))
        if pok then
            local pd = decode(pbody)
            if type(pd) == "table" and pd.key then
                S.pin = pd
            else
                S.pin = nil
            end
            refreshPinBar()
        end
        return true
    end

    function send(text, extra)
        text = clipUtf8(trim(text), MAXLEN)
        if text == "" and not extra then return false end
        if os.clock() - S.lastSend < COOLDOWN then
            pcall(function()
                WindUI:Notify({ Title = "Slow down", Content = "Wait a second", Duration = 1.6, Icon = "clock" })
            end)
            return false
        end
        S.lastSend = os.clock()
        local displayName = ME_DN
        if Settings.HideMyName and ME_IS_OWNER then displayName = "Hidden" end
        local cid = HttpService:GenerateGUID(false)
        local payload = {
            uid = ME_ID, user = ME_NAME, dn = displayName,
            text = text, cid = cid, t = "msg",
            ts = { [".sv"] = "timestamp" },
            script = SCRIPT_NAME, scriptImg = SCRIPT_IMG,
        }
        if ME_IS_OWNER and cfg.OwnerTag then payload.ownerTag = tostring(cfg.OwnerTag) end
        if S.replyTo then
            payload.reply = {
                uid = S.replyTo.uid, user = S.replyTo.user,
                dn = S.replyTo.dn, text = S.replyTo.text, key = S.replyTo.key,
            }
        end
        for k, v in pairs(extra or {}) do payload[k] = v end
        if payload.text == "" then payload.text = "invite" end
        local gen = S.gen
        local ui = render(payload, true, "pending")
        S.pending[cid] = ui
        clearReply()
        task.spawn(function()
            local ok, body = call("POST", urlFor("chat/" .. S.room .. "/messages"), encode(payload))
            if gen ~= S.gen then return end
            if ok then
                local d = decode(body)
                if type(d) == "table" and d.name then S.seen[d.name] = true end
                setStatus(ui, "sent")
            else
                setStatus(ui, "failed")
            end
            S.pending[cid] = nil
        end)
        return true
    end

    function sendInvite()
        local left = INVITE_COOLDOWN - (os.clock() - S.lastInvite)
        if left > 0 then
            pcall(function()
                WindUI:Notify({
                    Title = "Invite cooldown",
                    Content = string.format("Wait %d seconds", math.ceil(left)),
                    Duration = 2, Icon = "clock",
                })
            end)
            return
        end
        local info
        pcall(function() info = MarketplaceService:GetProductInfo(game.PlaceId) end)
        local ok = send(input.Text, {
            t = "invite", place = game.PlaceId, job = game.JobId,
            game = info and info.Name or "Roblox",
            pc = #Players:GetPlayers(), mx = Players.MaxPlayers,
        })
        if ok then S.lastInvite = os.clock(); input.Text = "" end
    end
    function doSend()
        if send(input.Text) then input.Text = "" end
    end

    local function refreshPills()
        for kind, b in pairs(pillBtns) do
            local active = kind == S.kind
            b.BackgroundTransparency = active and 0 or 1
            b.BackgroundColor3 = P.own
            b.TextColor3 = active and P.ownText or P.text
        end
        updateDMBadge()
    end
    local function updatePrivHeader()
        if S.kind ~= "private" then privHeader.Text = ""; return end
        local name = S.privateName or "Player"
        local typingTxt = S.typing and "  |  typing..." or ""
        privHeader.Text = "Chatting with " .. cleanName(name) .. typingTxt
    end

    function setRoom(kind, targetUid, targetName)
        if kind ~= "global" and kind ~= "private" then return end
        if kind == "private" and not targetUid and not S.privateTarget then
            openPrivatePanel(); relayout(); return
        end
        if kind == S.kind and S.loaded and (kind ~= "private" or targetUid == S.privateTarget) then return end
        S.kind = kind
        if kind == "private" then
            S.privateTarget = targetUid or S.privateTarget
            S.privateName = targetName or S.privateName or "Player"
            S.room = roomName("private", S.privateTarget)
            pushRecentDM(S.privateTarget, S.privateName)
            S.dmUnread = {}
            updateDMBadge()
        else
            S.privateTarget = nil; S.privateName = nil
            S.room = roomName("global")
        end
        S.gen = S.gen + 1
        S.lastKey, S.loaded, S.seen, S.pending, S.shown = nil, false, {}, {}, 0
        tableClear(msgUi)
        S.pin = nil
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        emptyLbl.Text = "Loading..."; emptyLbl.Visible = true
        clearReply(); hideCtx(); hideProfile()
        updatePrivHeader(); refreshPills(); relayout()
        task.spawn(function()
            pollOnce()
            emptyLbl.Text = "No messages yet"
            emptyLbl.Visible = S.shown == 0
        end)
    end

    pillBtns.global.MouseButton1Click:Connect(function() S.panelOpen = false; setRoom("global") end)
    pillBtns.private.MouseButton1Click:Connect(function() setRoom("private") end)
    refreshPills()
    onTheme[#onTheme + 1] = refreshPills

    sendBtn.MouseButton1Click:Connect(doSend)
    input.FocusLost:Connect(function(enter)
        if enter then doSend(); task.defer(function() input:CaptureFocus() end) end
    end)
    input:GetPropertyChangedSignal("Text"):Connect(function()
        if S.kind ~= "private" then return end
        if os.clock() - S.lastTypingPush < 2.5 then return end
        S.lastTypingPush = os.clock()
        task.spawn(function()
            call("PUT", urlFor("typing/" .. S.room .. "/" .. ME_ID), encode({ t = { [".sv"] = "timestamp" } }))
        end)
    end)

    -- close overlays on background click
    local function dismissOverlays()
        hideCtx()
        hideProfile()
        if quickReply.Visible then
            quickReply.Visible = false
            -- keep reply bar (quote) so user can still type; only close the quick menu
            relayout()
        end
    end

    scroll.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dismissOverlays()
        end
    end)

    -- global click-away for quick reply / menus
    UserInputService.InputBegan:Connect(function(inp, gp)
        if gp then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            -- delay one frame so button clicks on the menu itself still register
            task.defer(function()
                if not quickReply.Visible and not ctxMenu.Visible and not profileCard.Visible then return end
                -- if click was not on an overlay child, dismiss
                local pos = inp.Position
                local function contains(gui)
                    if not gui or not gui.Visible or not gui.Parent then return false end
                    local abs = gui.AbsolutePosition
                    local size = gui.AbsoluteSize
                    return pos.X >= abs.X and pos.X <= abs.X + size.X
                        and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
                end
                if contains(quickReply) or contains(ctxMenu) or contains(profileCard) or contains(replyBar) then
                    return
                end
                dismissOverlays()
            end)
        end
    end)

    task.spawn(function()
        task.wait(1.3)
        if Settings.FirstAskDone then return end
        if not Window or not Window.Dialog then return end
        Settings.FirstAskDone = true
        envGet().NeoChatSettings = Settings
        pcall(function()
            Window:Dialog({
                Title = "Chat notifications",
                Content = "Show a small transparent card on the right only when someone mentions you?",
                Buttons = {
                    { Title = "Yes", Variant = "Primary", Callback = function()
                        Settings.SideNotifs = true; envGet().NeoChatSettings = Settings
                    end },
                    { Title = "No", Variant = "Tertiary", Callback = function()
                        Settings.SideNotifs = false; envGet().NeoChatSettings = Settings
                    end },
                },
            })
        end)
    end)

    canvas:GetPropertyChangedSignal("Visible"):Connect(function()
        if viewing() then clearUnread(); scrollDown() end
    end)

    task.spawn(function()
        while S.alive and not (Window and Window.Destroyed) do
            local ok = pollOnce()
            S.fails = ok and 0 or math.min(S.fails + 1, 5)
            if viewing() then clearUnread() end
            task.wait(POLL * (1 + S.fails * 0.35))
        end
    end)

    local function renderTitle()
        local status = S.fails > 0 and '<font color="#ff5555">offline</font>'
            or ('<font color="#33C759">online</font> <font transparency="0.4">' .. S.online .. "</font>")
        local roomLabel = S.kind == "private" and "Private" or "Global"
        local muteTag = isMuted() and ' <font transparency="0.4">muted</font>' or ""
        title.Text = "Chat | " .. roomLabel .. "  " .. status .. muteTag
    end

    task.spawn(function()
        while S.alive and not (Window and Window.Destroyed) do
            call("PUT", urlFor("presence/" .. ME_ID), encode({ n = ME_NAME, t = { [".sv"] = "timestamp" } }))
            local ok, body = call("GET", urlFor("presence"))
            if ok then
                local data = decode(body)
                if type(data) == "table" then
                    local newest, n = 0, 0
                    local map = {}
                    for uid, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and v.t > newest then newest = v.t end
                    end
                    for uid, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and newest - v.t < 60000 then
                            n = n + 1
                            map[tostring(uid)] = v.n or tostring(uid)
                        end
                    end
                    S.online = math.max(n, 1)
                    S.onlineMap = map
                end
            end
            if S.kind == "private" and S.room then
                local tok, tbody = call("GET", urlFor("typing/" .. S.room))
                local someoneTyping = false
                if tok then
                    local td = decode(tbody)
                    if type(td) == "table" then
                        local now = os.time() * 1000
                        for uid, v in pairs(td) do
                            if tostring(uid) ~= tostring(ME_ID) and type(v) == "table" and tonumber(v.t) then
                                if now - v.t < 4000 then someoneTyping = true; break end
                            end
                        end
                    end
                end
                S.typing = someoneTyping
                updatePrivHeader()
            end
            renderTitle()
            for _ = 1, 12 do
                if not S.alive then return end
                task.wait(1)
                renderTitle()
            end
        end
    end)

    task.spawn(function()
        local last
        while S.alive and not (Window and Window.Destroyed) do
            local ok, name = pcall(function() return WindUI:GetCurrentTheme() end)
            if ok and name ~= last then last = name; applyTheme() end
            task.wait(0.8)
        end
    end)

    relayout()

    local Chat = { Tab = tab }
    function Chat:Send(text) return send(text) end
    function Chat:SendInvite() return sendInvite() end
    function Chat:SetRoom(kind, targetUid, targetName) return setRoom(kind, targetUid, targetName) end
    function Chat:Unread() return unreadCount() end
    function Chat:SetSideNotifs(on)
        Settings.SideNotifs = on == true; envGet().NeoChatSettings = Settings
    end
    function Chat:SetMentions(on)
        Settings.MentionsEnabled = on == true; envGet().NeoChatSettings = Settings
    end
    function Chat:SetCompact(on)
        Settings.CompactMode = on == true; envGet().NeoChatSettings = Settings
    end
    function Chat:SetAccent(name)
        if ACCENTS[name] ~= nil or name == "default" then
            Settings.ChatAccent = name; envGet().NeoChatSettings = Settings; applyTheme()
        end
    end
    function Chat:GetSettings() return Settings end
    function Chat:IsOwner() return ME_IS_OWNER end
    function Chat:Destroy()
        S.alive = false
        pcall(function() root:Destroy() end)
        pcall(function() badge:Destroy() end)
        pcall(function() if sideGui then sideGui:Destroy() end end)
    end

    envGet().NeoChatController = Chat
    envGet().NeoChatSettings = Settings
    return Chat
end

function NeoChat.AddChat(a, b, c)
    local Window, cfg
    if a == NeoChat then Window, cfg = b, c else Window, cfg = a, b end
    cfg = cfg or {}
    local WindUI = cfg.WindUI or envGet().WindUI or _G.WindUI or (shared and shared.WindUI)
    assert(WindUI, "NeoChat: WindUI not found (pass cfg.WindUI)")
    return NeoChat.Init(WindUI, Window, cfg)
end

return NeoChat
