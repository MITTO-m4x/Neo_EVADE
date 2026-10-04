--[[
    NeoChat v4.0  -  Firebase chat for WindUI / Neo Hyper  (full rewrite)

    - Global room + private DMs (recent DM chips, unread badges, inbox)
    - Grouped bubbles, avatars, owner / script badges, timestamps
    - Replies, toggle reactions, copy, delete, pin (owners), retry failed
    - Stickers (+favorites), emoji picker, server invites with Join
    - @mentions (highlight + notification), search, online list, typing
    - Profile card, mute room, compact mode, accent colors, scale
    - Owner tools: pin / delete / mute user (client-side, see notes)
    Owners: v_orc, n_oqv
]]

local NeoChat = {
    DatabaseURL = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app",
    Version = "4.0.0",
    StickersURL = "https://raw.githubusercontent.com/Sephtis32/Yin-stickers/refs/heads/main/YinYang_Stickers.lua",
}

------------------------------------------------------------------ safe globals
local function envGet()
    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    if type(_G) == "table" then return _G end
    return shared or {}
end

local cr = cloneref or function(x) return x end
local Players            = cr(game:GetService("Players"))
local HttpService        = cr(game:GetService("HttpService"))
local TweenService       = cr(game:GetService("TweenService"))
local TeleportService    = cr(game:GetService("TeleportService"))
local MarketplaceService = cr(game:GetService("MarketplaceService"))
local UserInputService   = cr(game:GetService("UserInputService"))
local RunService         = cr(game:GetService("RunService"))
local LocalPlayer        = Players.LocalPlayer

local OWNERS = { ["v_orc"] = true, ["n_oqv"] = true }
local function isOwner(name)
    return OWNERS[tostring(name or ""):lower()] == true
end
local ME_IS_OWNER = isOwner(LocalPlayer.Name)

------------------------------------------------------------------ string helpers
local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function esc(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
    return s
end
local function clipUtf8(s, max)
    s = tostring(s or "")
    if not (utf8 and utf8.len and utf8.offset) then return s:sub(1, max) end
    local len = utf8.len(s)
    if not len then return s:sub(1, max) end
    if len <= max then return s end
    return s:sub(1, (utf8.offset(s, max + 1) or (#s + 1)) - 1)
end
local function cleanName(s, max)
    s = tostring(s or "?"):gsub("[%c]", ""):gsub("%s+", " ")
    max = max or 22
    if #s > max then s = s:sub(1, max - 2) .. ".." end
    return s
end
local function hex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function fmtClock(ms)
    ms = tonumber(ms)
    if not ms then return "" end
    local ok, s = pcall(function() return os.date("%H:%M", math.floor(ms / 1000)) end)
    return ok and s or ""
end

------------------------------------------------------------------ HTTP
local rawRequest = (type(syn) == "table" and syn.request) or (type(http) == "table" and http.request)
    or http_request or (type(fluxus) == "table" and fluxus.request) or request
if type(rawRequest) ~= "function" then rawRequest = nil end
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
    if type(s) ~= "string" or s == "" then return nil end
    local ok, r = pcall(function() return HttpService:JSONDecode(s) end)
    if ok then return r end
    return nil
end
local function encode(t) return HttpService:JSONEncode(t) end

------------------------------------------------------------------ stickers
local StickerCatalog = { Order = {}, Stickers = {}, Ready = false }
local function loadStickers(url)
    task.spawn(function()
        local ok, raw = pcall(function() return game:HttpGet(url or NeoChat.StickersURL, true) end)
        if not ok or type(raw) ~= "string" or type(loadstring) ~= "function" then return end
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

------------------------------------------------------------------ settings
local CHAT_CFG_PATH = "Neo-EVADE/chat_settings.json"
local function saveSettingsDisk(tbl)
    pcall(function()
        if not (isfolder and writefile) then return end
        if not isfolder("Neo-EVADE") and makefolder then makefolder("Neo-EVADE") end
        writefile(CHAT_CFG_PATH, HttpService:JSONEncode(tbl))
    end)
end
local function loadSettings()
    local def = {
        SideNotifs = true, SideNotifDuration = 3.2, MentionsEnabled = true,
        HideMyName = false, CompactMode = false, ChatAccent = "orange",
        ChatScale = 1.0, Sound = false,
        MutedRooms = {}, StickerFavs = {}, RecentDMs = {}, DMSeen = {},
    }
    pcall(function()
        if isfile and isfile(CHAT_CFG_PATH) and readfile then
            local data = HttpService:JSONDecode(readfile(CHAT_CFG_PATH))
            if type(data) == "table" then
                for k, v in pairs(data) do def[k] = v end
            end
        end
    end)
    local g = envGet()
    local s = g.NeoChatSettings
    if type(s) ~= "table" then s = def end
    for k, v in pairs(def) do
        if s[k] == nil then s[k] = v end
    end
    for _, k in ipairs({ "MutedRooms", "StickerFavs", "RecentDMs", "DMSeen" }) do
        if type(s[k]) ~= "table" then s[k] = {} end
    end
    g.NeoChatSettings = s
    return s
end
local function persistSettings(tbl)
    envGet().NeoChatSettings = tbl
    saveSettingsDisk(tbl)
end

------------------------------------------------------------------ constants
local ACCENTS = {
    orange = Color3.fromRGB(255, 140, 40),
    purple = Color3.fromRGB(150, 90, 255),
    green  = Color3.fromRGB(70, 200, 110),
    red    = Color3.fromRGB(235, 70, 70),
    blue   = Color3.fromRGB(70, 150, 255),
    rose   = Color3.fromRGB(240, 100, 160),
}
local ACCENT_ORDER = { "orange", "purple", "green", "red", "blue", "rose" }
local QUICK_REACTS = { "❤️", "😂", "🔥", "👍", "😮", "😢" }
local EMOJIS = {
    "😀","😁","😂","🤣","😊","😍","😘","😎","🤔","😅","😭","😡",
    "🥺","😴","🤯","😈","💀","👻","🎃","🦇","🕷️","🕸️","🔥","💯",
    "👍","👎","👏","🙏","💪","🤝","👀","🧠","❤️","💔","💜","🧡",
    "✨","⭐","🎉","🎮","🏆","⚡","💥","🍀","🌙","☠️","😤","🥶",
}
local INVITE_COOLDOWN = 30

------------------------------------------------------------------ palette + UI helpers
local Settings = nil -- set in Init
local P = {}
local painted = {}

local function computePalette()
    local acc = ACCENTS[Settings and Settings.ChatAccent or "orange"] or ACCENTS.orange
    local bg = Color3.fromRGB(16, 13, 21)
    P = {
        bg = bg,
        card = Color3.fromRGB(27, 22, 36),
        card2 = Color3.fromRGB(38, 31, 50),
        other = Color3.fromRGB(37, 31, 48),
        line = Color3.fromRGB(58, 49, 74),
        text = Color3.fromRGB(244, 238, 232),
        muted = Color3.fromRGB(150, 142, 168),
        accent = acc,
        own = acc:Lerp(Color3.new(0, 0, 0), 0.38),
        ownText = Color3.new(1, 1, 1),
        accentSoft = acc:Lerp(bg, 0.78),
        danger = Color3.fromRGB(235, 80, 80),
        good = Color3.fromRGB(80, 210, 120),
        gold = Color3.fromRGB(255, 205, 70),
    }
end
computePalette()

local function paint(obj, prop, key)
    pcall(function() obj[prop] = P[key] end)
    painted[#painted + 1] = { obj, prop, key }
end
local function repaint()
    computePalette()
    local keep = {}
    for _, e in ipairs(painted) do
        if e[1] and e[1].Parent then
            pcall(function() e[1][e[2]] = P[e[3]] end)
            keep[#keep + 1] = e
        end
    end
    painted = keep
end

local function New(class, props, children)
    props = props or {}
    local o = Instance.new(class)
    pcall(function() o.BorderSizePixel = 0 end)
    local paints = props.Paint
    local parent = props.Parent
    for k, v in pairs(props) do
        if k ~= "Paint" and k ~= "Parent" then
            pcall(function() o[k] = v end)
        end
    end
    for _, c in ipairs(children or {}) do c.Parent = o end
    if paints then
        for prop, key in pairs(paints) do paint(o, prop, key) end
    end
    if parent then o.Parent = parent end
    return o
end
local function corner(r)
    return New("UICorner", { CornerRadius = (r and r >= 1 and r <= 1) and UDim.new(1, 0) or UDim.new(0, r or 8) })
end
local function pill() return New("UICorner", { CornerRadius = UDim.new(1, 0) }) end
local function pad(l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l),
        PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l),
    })
end
local function listLayout(dir, gap, props)
    local l = New("UIListLayout", {
        FillDirection = dir or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, gap or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    for k, v in pairs(props or {}) do pcall(function() l[k] = v end) end
    return l
end
local function nameColor(name)
    local h = 0
    name = tostring(name or "?")
    for i = 1, #name do h = (h * 31 + name:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.5, 1)
end
local function avatarUrl(uid)
    return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(uid or 0) .. "&w=150&h=150"
end

-- small text button used everywhere (paints with accent when `accent` is true)
local function textButton(parent, text, size, props, accent)
    local b = New("TextButton", {
        Size = size or UDim2.new(0, 60, 0, 26), Text = text, TextSize = 12,
        Font = Enum.Font.GothamMedium, AutoButtonColor = true,
        Paint = { BackgroundColor3 = accent and "accent" or "card2", TextColor3 = accent and "ownText" or "text" },
        Parent = parent,
    }, { corner(7) })
    for k, v in pairs(props or {}) do pcall(function() b[k] = v end) end
    return b
end

------------------------------------------------------------------ Init
function NeoChat.Init(WindUI, Window, cfg)
    cfg = cfg or {}
    cfg.DatabaseURL = cfg.DatabaseURL or NeoChat.DatabaseURL
    assert(type(cfg.DatabaseURL) == "string", "NeoChat: DatabaseURL is required")
    assert(Window, "NeoChat: Window is required")

    Settings = loadSettings()
    computePalette()
    loadStickers(cfg.StickersURL or NeoChat.StickersURL)

    local BASE = (cfg.DatabaseURL:gsub("/+$", ""))
    local MAXLEN = cfg.MaxLength or 240
    local POLL = cfg.PollInterval or 1.5
    local HISTORY = cfg.History or 50
    local COOLDOWN = cfg.Cooldown or 1.1
    local SCRIPT_NAME = tostring(cfg.ScriptName or "Neo")
    local SCRIPT_IMG = tostring(cfg.ScriptImage or "")
    local ME_ID, ME_NAME, ME_DN = LocalPlayer.UserId, LocalPlayer.Name, LocalPlayer.DisplayName

    -- all mutable state / widgets / functions live in three tables
    -- (avoids Lua's 200-local and 60-upvalue limits and forward-reference bugs)
    local S = {
        alive = true, kind = "global", room = "global", target = nil, targetName = nil,
        gen = 0, lastKey = nil, loaded = false, seen = {}, pending = {}, order = 0,
        lastSend = 0, lastText = "", lastTextAt = 0, lastInvite = 0, fails = 0, online = 1,
        panel = nil, replyTo = nil, search = "", stick = true, pollTick = 0,
        unread = {}, dmSeenTs = {}, toastTs = {}, onlineMap = {}, muted = {}, pin = nil,
        skew = 0, typingNames = {}, lastTypingPush = 0, lastGroupUid = nil, lastGroupTs = 0,
        lastMsgUi = nil, wake = false, connected = true, toasts = {}, msgUi = {},
    }
    local UI = {}
    local F = {}

    local function roomName(kind, targetUid)
        if kind == "private" and targetUid then
            local a, b = ME_ID, tonumber(targetUid) or 0
            if a > b then a, b = b, a end
            return "dm_" .. a .. "_" .. b
        end
        return (tostring(cfg.Room or "global"):gsub("[%.%$#%[%]/]", "_"))
    end
    S.room = roomName("global")

    local function urlFor(path, query)
        return BASE .. "/" .. path .. ".json" .. (query and ("?" .. query) or "")
    end
    local function serverNow() return os.time() * 1000 - S.skew end

    ---------------------------------------------------------------- tab + canvas
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
            if c then return c end
            if ue.ContainerFrame then return ue.ContainerFrame end
        end
        if t.ContainerFrameCanvas then return t.ContainerFrameCanvas end
        if t.Canvas then return t.Canvas end
        if t.Frame then return t.Frame end
        return nil
    end
    local canvas = resolveTabCanvas(tab)
    if not canvas then
        local host = nil
        pcall(function() host = Window.UIElements and Window.UIElements.Main end)
        canvas = Instance.new("Frame")
        canvas.Name = "NeoChatFallbackCanvas"
        canvas.BackgroundTransparency = 1
        canvas.Size = UDim2.fromScale(1, 1)
        local okCG, cg = pcall(function() return game:GetService("CoreGui") end)
        canvas.Parent = host or (okCG and cg) or LocalPlayer:WaitForChild("PlayerGui")
        warn("[NeoChat] tab canvas not found, using fallback canvas")
    end
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

    ---------------------------------------------------------------- layout constants
    local HEADER, CHIPS_H, PIN_H, SEARCH_H, INPUT_H, REPLY_H, TYPING_H, PANEL_H = 46, 34, 28, 32, 44, 30, 16, 190

    UI.root = New("Frame", {
        Name = "NeoChat", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        ClipsDescendants = true, Parent = canvas,
    })
    UI.scale = New("UIScale", { Scale = math.clamp(tonumber(Settings.ChatScale) or 1, 0.75, 1.4), Parent = UI.root })
    UI.bgFrame = New("Frame", { Size = UDim2.fromScale(1, 1), Paint = { BackgroundColor3 = "bg" }, Parent = UI.root }, { corner(10) })

    ---------------------------------------------------------------- header
    UI.header = New("Frame", { Size = UDim2.new(1, 0, 0, HEADER), BackgroundTransparency = 1, Parent = UI.root })
    UI.titleLbl = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 6), Size = UDim2.new(0.5, -14, 0, 20), BackgroundTransparency = 1,
        Text = "Neo Chat", TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        Paint = { TextColor3 = "text" }, Parent = UI.header,
    })
    UI.subLbl = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 25), Size = UDim2.new(0.5, -14, 0, 14), BackgroundTransparency = 1,
        Text = "connecting...", TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true, Paint = { TextColor3 = "muted" }, Parent = UI.header,
    })
    UI.headBtns = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(0, 180, 0, 30),
        BackgroundTransparency = 1, Parent = UI.header,
    }, { listLayout(Enum.FillDirection.Horizontal, 5, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }) })

    local function headBtn(symbol, order, onClick)
        local b = New("TextButton", {
            Size = UDim2.new(0, 30, 0, 30), Text = symbol, TextSize = 15, Font = Enum.Font.GothamBold,
            AutoButtonColor = true, LayoutOrder = order,
            Paint = { BackgroundColor3 = "card", TextColor3 = "text" }, Parent = UI.headBtns,
        }, { corner(8) })
        b.MouseButton1Click:Connect(onClick)
        return b
    end
    UI.btnSearch = headBtn("🔍", 1, function() F.toggleSearch() end)
    UI.btnOnline = headBtn("👥", 2, function() F.openPanel("online") end)
    UI.btnMute = headBtn("🔔", 3, function() F.toggleMute() end)
    UI.btnSettings = headBtn("⚙", 4, function() F.openPanel("settings") end)

    ---------------------------------------------------------------- chips (rooms)
    UI.chips = New("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, HEADER), Size = UDim2.new(1, -16, 0, CHIPS_H), BackgroundTransparency = 1,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X, Parent = UI.root,
    }, { listLayout(Enum.FillDirection.Horizontal, 6, { VerticalAlignment = Enum.VerticalAlignment.Center }) })

    ---------------------------------------------------------------- pin + search
    UI.pinBar = New("Frame", {
        Size = UDim2.new(1, -16, 0, PIN_H), Visible = false, Paint = { BackgroundColor3 = "card" }, Parent = UI.root,
    }, { corner(8) })
    New("Frame", { Size = UDim2.new(0, 3, 1, -8), Position = UDim2.new(0, 5, 0, 4), Paint = { BackgroundColor3 = "gold" }, Parent = UI.pinBar }, { corner(2) })
    UI.pinText = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1, Text = "",
        TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, RichText = true, Paint = { TextColor3 = "text" }, Parent = UI.pinBar,
    })
    UI.pinClose = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 22, 0, 22),
        Text = "✕", TextSize = 11, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Visible = false,
        Paint = { TextColor3 = "muted" }, Parent = UI.pinBar,
    })
    UI.pinClose.MouseButton1Click:Connect(function() F.unpin() end)

    UI.searchBar = New("Frame", {
        Size = UDim2.new(1, -16, 0, SEARCH_H), Visible = false, Paint = { BackgroundColor3 = "card" }, Parent = UI.root,
    }, { corner(8) })
    UI.searchBox = New("TextBox", {
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1,
        Text = "", PlaceholderText = "Search messages...", ClearTextOnFocus = false, TextSize = 12,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        Paint = { TextColor3 = "text", PlaceholderColor3 = "muted" }, Parent = UI.searchBar,
    })
    UI.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        S.search = UI.searchBox.Text:lower()
        F.applySearch()
    end)

    ---------------------------------------------------------------- message list
    UI.scroll = New("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 90), Size = UDim2.new(1, -16, 1, -200), BackgroundTransparency = 1,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Paint = { ScrollBarImageColor3 = "line" }, Parent = UI.root,
    }, { listLayout(Enum.FillDirection.Vertical, 2), pad(2, 4, 4, 4) })
    UI.emptyLbl = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.5, -30), BackgroundTransparency = 1,
        Text = "No messages yet.\nSay hi 👋", TextSize = 13, Font = Enum.Font.Gotham, Visible = false,
        Paint = { TextColor3 = "muted" }, Parent = UI.root,
    })
    UI.newPill = New("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 110, 0, 24), Text = "↓ New messages", TextSize = 11,
        Font = Enum.Font.GothamBold, Visible = false, ZIndex = 5,
        Paint = { BackgroundColor3 = "accent", TextColor3 = "ownText" }, Parent = UI.root,
    }, { pill() })
    UI.newPill.MouseButton1Click:Connect(function() F.scrollBottom(true) end)

    ---------------------------------------------------------------- typing / reply / input
    UI.typingLbl = New("TextLabel", {
        Size = UDim2.new(1, -24, 0, TYPING_H), BackgroundTransparency = 1, Text = "", TextSize = 11, Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Paint = { TextColor3 = "muted" }, Parent = UI.root,
    })
    UI.replyBar = New("Frame", {
        Size = UDim2.new(1, -16, 0, REPLY_H), Visible = false, Paint = { BackgroundColor3 = "card" }, Parent = UI.root,
    }, { corner(8) })
    New("Frame", { Size = UDim2.new(0, 3, 1, -8), Position = UDim2.new(0, 5, 0, 4), Paint = { BackgroundColor3 = "accent" }, Parent = UI.replyBar }, { corner(2) })
    UI.replyLbl = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1, Text = "",
        TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
        TextTruncate = Enum.TextTruncate.AtEnd, Paint = { TextColor3 = "muted" }, Parent = UI.replyBar,
    })
    UI.replyX = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 22, 0, 22),
        Text = "✕", TextSize = 11, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Paint = { TextColor3 = "muted" }, Parent = UI.replyBar,
    })
    UI.replyX.MouseButton1Click:Connect(function() F.clearReply() end)

    UI.inputRow = New("Frame", {
        Size = UDim2.new(1, -16, 0, INPUT_H), Paint = { BackgroundColor3 = "card" }, Parent = UI.root,
    }, { corner(12) })
    local function inputBtn(symbol, x, onClick)
        local b = New("TextButton", {
            Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(0, 30, 0, 30),
            Text = symbol, TextSize = 16, Font = Enum.Font.GothamBold, BackgroundTransparency = 1,
            Paint = { TextColor3 = "text" }, Parent = UI.inputRow,
        })
        b.MouseButton1Click:Connect(onClick)
        return b
    end
    UI.btnSticker = inputBtn("🎴", 4, function() F.openPanel("stickers") end)
    UI.btnEmoji = inputBtn("😊", 34, function() F.openPanel("emoji") end)
    UI.input = New("TextBox", {
        Position = UDim2.new(0, 68, 0, 0), Size = UDim2.new(1, -68 - 76, 1, 0), BackgroundTransparency = 1, Text = "",
        PlaceholderText = "Message...", ClearTextOnFocus = false, TextSize = 13, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true,
        Paint = { TextColor3 = "text", PlaceholderColor3 = "muted" }, Parent = UI.inputRow,
    })
    UI.btnInvite = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -42, 0.5, 0), Size = UDim2.new(0, 30, 0, 30),
        Text = "🎮", TextSize = 16, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Parent = UI.inputRow,
    })
    UI.btnInvite.MouseButton1Click:Connect(function() F.sendInvite() end)
    UI.btnSend = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 32, 0, 32),
        Text = "➤", TextSize = 14, Font = Enum.Font.GothamBold,
        Paint = { BackgroundColor3 = "accent", TextColor3 = "ownText" }, Parent = UI.inputRow,
    }, { pill() })
    UI.btnSend.MouseButton1Click:Connect(function() F.doSend() end)
    UI.input.FocusLost:Connect(function(enter)
        if enter then F.doSend() end
    end)
    UI.input:GetPropertyChangedSignal("Text"):Connect(function()
        if #UI.input.Text > MAXLEN * 4 then UI.input.Text = clipUtf8(UI.input.Text, MAXLEN) end
        F.pushTyping()
    end)

    ---------------------------------------------------------------- overlay panel (stickers / emoji / online / settings)
    UI.panel = New("Frame", {
        Size = UDim2.new(1, -16, 0, PANEL_H), Visible = false, ZIndex = 6, Paint = { BackgroundColor3 = "card" }, Parent = UI.root,
    }, { corner(12) })
    New("UIStroke", { Thickness = 1, Paint = { Color = "line" }, Parent = UI.panel })
    UI.panelTitle = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -50, 0, 20), BackgroundTransparency = 1, Text = "",
        TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
        Paint = { TextColor3 = "text" }, Parent = UI.panel,
    })
    UI.panelClose = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.new(0, 24, 0, 22),
        Text = "✕", TextSize = 12, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, ZIndex = 8,
        Paint = { TextColor3 = "muted" }, Parent = UI.panel,
    })
    UI.panelClose.MouseButton1Click:Connect(function() F.closePanel() end)
    UI.pages = {}
    for _, name in ipairs({ "stickers", "emoji", "online", "settings" }) do
        UI.pages[name] = New("Frame", {
            Position = UDim2.new(0, 8, 0, 28), Size = UDim2.new(1, -16, 1, -34), BackgroundTransparency = 1,
            Visible = false, ZIndex = 7, Parent = UI.panel,
        })
    end

    ---------------------------------------------------------------- overlays (menu / profile)
    UI.overlay = New("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "",
        AutoButtonColor = false, Visible = false, ZIndex = 20, Parent = UI.root,
    }, { corner(10) })
    UI.overlay.MouseButton1Click:Connect(function() F.closeOverlay() end)
    UI.overlayBody = New("Frame", {
        Size = UDim2.new(0, 220, 0, 100), Visible = false, ZIndex = 21, Active = true,
        Paint = { BackgroundColor3 = "card2" }, Parent = UI.root,
    }, { corner(12) })
    New("UIStroke", { Thickness = 1, Paint = { Color = "line" }, Parent = UI.overlayBody })

    F.listeners = {}

    ---------------------------------------------------------------- generic helpers
    local function notify(title, content, icon)
        pcall(function()
            WindUI:Notify({ Title = title, Content = content, Duration = 2.2, Icon = icon or "info" })
        end)
    end
    F.notify = notify

    function F.copy(text)
        text = tostring(text or "")
        local ok = false
        if setclipboard then ok = pcall(setclipboard, text)
        elseif toclipboard then ok = pcall(toclipboard, text) end
        notify(ok and "Copied" or "Copy unavailable", ok and "Copied to clipboard" or "Your executor has no clipboard", "copy")
    end

    local function mentionsMe(text)
        local l = tostring(text or ""):lower()
        if l:find("@" .. ME_NAME:lower(), 1, true) then return true end
        local dn = ME_DN:lower():gsub("[^%w_]", "")
        if dn ~= "" and l:find("@" .. dn, 1, true) then return true end
        return false
    end
    local function richText(text)
        local e = esc(text)
        local col = hex(P.accent)
        e = e:gsub("@([%w_]+)", function(n)
            return '<font color="' .. col .. '"><b>@' .. n .. "</b></font>"
        end)
        return e
    end

    function F.isVisible()
        if not S.alive or not UI.root or not UI.root.Parent then return false end
        local o = UI.root
        while o and o ~= game do
            if o:IsA("GuiObject") and not o.Visible then return false end
            if o:IsA("ScreenGui") and not o.Enabled then return false end
            o = o.Parent
        end
        return UI.root.AbsoluteSize.X > 10
    end

    ---------------------------------------------------------------- layout
    function F.relayout()
        local top = HEADER
        UI.chips.Position = UDim2.new(0, 8, 0, top)
        top = top + CHIPS_H + 2
        if UI.pinBar.Visible then
            UI.pinBar.Position = UDim2.new(0, 8, 0, top)
            top = top + PIN_H + 4
        end
        if UI.searchBar.Visible then
            UI.searchBar.Position = UDim2.new(0, 8, 0, top)
            top = top + SEARCH_H + 4
        end
        local bottom = 6
        UI.inputRow.Position = UDim2.new(0, 8, 1, -(bottom + INPUT_H))
        bottom = bottom + INPUT_H + 4
        if UI.replyBar.Visible then
            UI.replyBar.Position = UDim2.new(0, 8, 1, -(bottom + REPLY_H))
            bottom = bottom + REPLY_H + 4
        end
        if UI.typingLbl.Visible then
            UI.typingLbl.Position = UDim2.new(0, 14, 1, -(bottom + TYPING_H))
            bottom = bottom + TYPING_H + 2
        end
        if UI.panel.Visible then
            UI.panel.Position = UDim2.new(0, 8, 1, -(bottom + PANEL_H))
            bottom = bottom + PANEL_H + 4
        end
        UI.scroll.Position = UDim2.new(0, 8, 0, top)
        UI.scroll.Size = UDim2.new(1, -16, 1, -(top + bottom))
        UI.newPill.Position = UDim2.new(0.5, 0, 1, -(bottom + 4))
        F.updateConstraints()
    end

    S.constraints = {}
    function F.maxW()
        local w = UI.scroll.AbsoluteSize.X / math.max(0.1, UI.scale.Scale)
        return math.max(150, math.min(w * 0.84, w - 62))
    end
    function F.limit(obj, extra)
        local c = New("UISizeConstraint", { MaxSize = Vector2.new(F.maxW() - (extra or 0), 100000), Parent = obj })
        S.constraints[#S.constraints + 1] = { c, extra or 0 }
        return c
    end
    function F.updateConstraints()
        local keep = {}
        local w = F.maxW()
        for _, e in ipairs(S.constraints) do
            if e[1] and e[1].Parent then
                e[1].MaxSize = Vector2.new(w - e[2], 100000)
                keep[#keep + 1] = e
            end
        end
        S.constraints = keep
    end
    UI.scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() F.updateConstraints() end)

    function F.scrollBottom(force)
        task.defer(function()
            RunService.Heartbeat:Wait()
            if not S.alive or not UI.scroll.Parent then return end
            UI.scroll.CanvasPosition = Vector2.new(0, 1e6)
            S.stick = true
            UI.newPill.Visible = false
        end)
    end
    UI.scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local sc = math.max(0.1, UI.scale.Scale)
        local maxY = (UI.scroll.AbsoluteCanvasSize.Y - UI.scroll.AbsoluteSize.Y) / sc
        S.stick = (maxY - UI.scroll.CanvasPosition.Y) < 70
        if S.stick then UI.newPill.Visible = false end
    end)

    ---------------------------------------------------------------- reactions
    function F.applyReacts(ui, reacts)
        if not ui or not ui.reactRow then return end
        ui.m.reacts = reacts
        for _, c in ipairs(ui.reactRow:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local list = {}
        if type(reacts) == "table" then
            for emoji, v in pairs(reacts) do
                local count, mine = 0, false
                if type(v) == "table" then
                    for uidKey in pairs(v) do
                        count = count + 1
                        if tostring(uidKey) == tostring(ME_ID) then mine = true end
                    end
                else
                    count = tonumber(v) or 1
                end
                if count > 0 then list[#list + 1] = { emoji = emoji, count = count, mine = mine } end
            end
        end
        table.sort(list, function(a, b)
            if a.count ~= b.count then return a.count > b.count end
            return a.emoji < b.emoji
        end)
        ui.reactRow.Visible = #list > 0
        for i, r in ipairs(list) do
            local chip = New("TextButton", {
                Size = UDim2.new(0, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i,
                Text = " " .. r.emoji .. " " .. r.count .. " ", TextSize = 12, Font = Enum.Font.GothamMedium,
                AutoButtonColor = true, Parent = ui.reactRow,
                Paint = { BackgroundColor3 = r.mine and "accentSoft" or "card2", TextColor3 = "text" },
            }, { corner(10) })
            if r.mine then New("UIStroke", { Thickness = 1, Paint = { Color = "accent" }, Parent = chip }) end
            chip.MouseButton1Click:Connect(function() F.toggleReact(ui, r.emoji) end)
        end
    end

    function F.toggleReact(ui, emoji)
        if not ui or not ui.key then return end
        local reacts = type(ui.m.reacts) == "table" and ui.m.reacts or {}
        local entry = reacts[emoji]
        local mine = type(entry) == "table" and entry[tostring(ME_ID)] ~= nil
        local path = "chat/" .. S.room .. "/messages/" .. tostring(ui.key) .. "/reacts/"
            .. HttpService:UrlEncode(emoji) .. "/" .. tostring(ME_ID)
        if type(entry) ~= "table" then entry = {}; reacts[emoji] = entry end
        if mine then entry[tostring(ME_ID)] = nil else entry[tostring(ME_ID)] = true end
        F.applyReacts(ui, reacts)
        task.spawn(function()
            if mine then call("DELETE", urlFor(path)) else call("PUT", urlFor(path), encode(true)) end
        end)
    end

    ---------------------------------------------------------------- render a message
    local function setStatus(ui, status)
        ui.status = status
        if not ui.statusLbl then return end
        local muted = hex(P.muted)
        if status == "pending" then
            ui.statusLbl.Text = '<font color="' .. muted .. '">sending…</font>'
        elseif status == "failed" then
            ui.statusLbl.Text = '<font color="' .. hex(P.danger) .. '">failed — tap to retry</font>'
        else
            ui.statusLbl.Text = '<font color="' .. muted .. '">' .. fmtClock(ui.m.ts) .. "  ✓</font>"
        end
    end
    F.setStatus = setStatus

    function F.render(m, own, status)
        local uid = tonumber(m.uid) or 0
        local text = tostring(m.text or "")
        local frames, interval = parseSticker(text)
        local isInvite = m.t == "invite"
        local compact = Settings.CompactMode == true
        S.order = S.order + 1

        local grouped = (not isInvite) and S.lastGroupUid == uid and S.lastGroupType == (frames and "s" or "m")
            and (os.clock() - S.lastGroupAt) < 120
        S.lastGroupUid, S.lastGroupAt, S.lastGroupType = uid, os.clock(), (frames and "s" or "m")
        if isInvite then S.lastGroupUid = nil end

        local row = New("Frame", {
            Name = "Msg", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = S.order, Parent = UI.scroll,
        }, {
            listLayout(Enum.FillDirection.Horizontal, 6, {
                HorizontalAlignment = own and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Top,
            }),
        })
        row:SetAttribute("MsgText", (text .. " " .. tostring(m.dn or "") .. " " .. tostring(m.user or "")):lower())
        if not grouped then
            New("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, LayoutOrder = 0, Parent = nil })
        end

        local ui = { row = row, m = m, own = own, key = m._k, text = text }

        -- avatar column
        if not own and not compact then
            if grouped then
                New("Frame", { Size = UDim2.new(0, 34, 0, 1), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
            else
                local av = New("ImageButton", {
                    Size = UDim2.new(0, 34, 0, 34), LayoutOrder = 1, Image = avatarUrl(uid),
                    Paint = { BackgroundColor3 = "card2" }, AutoButtonColor = false, Parent = row,
                }, { pill() })
                av.MouseButton1Click:Connect(function() F.openProfile(m) end)
            end
        end

        -- bubble
        local bubble = New("TextButton", {
            Name = "Bubble", Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2,
            Text = "", AutoButtonColor = false, Parent = row,
            BackgroundTransparency = frames and 1 or 0,
            Paint = { BackgroundColor3 = own and "own" or "other" },
        }, {
            corner(frames and 4 or 11),
            pad(frames and 2 or 9, frames and 2 or 6, frames and 2 or 9, frames and 2 or 6),
            listLayout(Enum.FillDirection.Vertical, 3, {
                HorizontalAlignment = own and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
            }),
        })
        ui.bubble = bubble
        local order = 0
        local function nextOrder() order = order + 1; return order end

        -- head (others: name + badge + time)
        if not own and not grouped then
            local head = New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
                RichText = true, TextSize = 11, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = nextOrder(), Paint = { TextColor3 = "text" }, Parent = bubble,
                Text = '<b><font color="' .. hex(nameColor(m.user or m.dn)) .. '">' .. esc(cleanName(m.dn or m.user or "?", 20))
                    .. "</font></b>"
                    .. (isOwner(m.user) and (' <font color="' .. hex(P.gold) .. '"><b>OWNER</b></font>') or "")
                    .. '  <font color="' .. hex(P.muted) .. '">' .. fmtClock(m.ts) .. "</font>",
            })
            ui.head = head
        end

        -- reply quote
        if type(m.reply) == "table" then
            local q = New("Frame", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = nextOrder(),
                Paint = { BackgroundColor3 = "bg" }, BackgroundTransparency = 0.45, Parent = bubble,
            }, { corner(6), pad(7, 3, 7, 3) })
            New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
                RichText = true, TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
                Text = '<font color="' .. hex(P.accent) .. '"><b>↩ ' .. esc(cleanName(m.reply.dn or m.reply.user or "?", 16))
                    .. "</b></font>  " .. esc(clipUtf8(tostring(m.reply.text or ""):gsub("%[%[STICKER:.-%]%]", "[sticker]"), 60)),
                Paint = { TextColor3 = "muted" }, Parent = q,
            })
            F.limit(q, 20)
        end

        -- content
        if frames then
            local img = New("ImageLabel", {
                Size = UDim2.new(0, 92, 0, 92), BackgroundTransparency = 1, Image = frames[1],
                ScaleType = Enum.ScaleType.Fit, LayoutOrder = nextOrder(), Parent = bubble,
            })
            if #frames > 1 then
                task.spawn(function()
                    local i = 1
                    while S.alive and img.Parent do
                        task.wait(interval)
                        i = i % #frames + 1
                        img.Image = frames[i]
                    end
                end)
            end
        elseif isInvite then
            local card = New("Frame", {
                Size = UDim2.new(0, 190, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(),
                Paint = { BackgroundColor3 = "card" }, Parent = bubble,
            }, { corner(8), pad(8), listLayout(Enum.FillDirection.Vertical, 4) })
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = 1, RichText = true,
                Text = "🎮 <b>" .. esc(cleanName(m.game or "Roblox", 26)) .. "</b>", TextSize = 12, Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left, Paint = { TextColor3 = "text" }, Parent = card,
            })
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, LayoutOrder = 2,
                Text = (tonumber(m.pc) or "?") .. "/" .. (tonumber(m.mx) or "?") .. " players  •  by " .. cleanName(m.dn or m.user or "?", 14),
                TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
                Paint = { TextColor3 = "muted" }, Parent = card,
            })
            if text ~= "" and text ~= "invite" then
                New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3,
                    Text = text, TextSize = 12, Font = Enum.Font.Gotham, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
                    Paint = { TextColor3 = "text" }, Parent = card,
                })
            end
            local here = tostring(m.job) == tostring(game.JobId)
            local joinBtn = textButton(card, here and "You're here" or "Join", UDim2.new(1, 0, 0, 26), { LayoutOrder = 4 }, not here)
            joinBtn.MouseButton1Click:Connect(function()
                if here then return end
                local okTp, err = pcall(function()
                    TeleportService:TeleportToPlaceInstance(tonumber(m.place), tostring(m.job), LocalPlayer)
                end)
                if not okTp then notify("Join failed", tostring(err), "alert-triangle") end
            end)
        else
            local lbl = New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
                RichText = true, Text = richText(text), TextWrapped = true, TextSize = compact and 12 or 13,
                Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(),
                Paint = { TextColor3 = own and "ownText" or "text" }, Parent = bubble,
            })
            F.limit(lbl, 22)
        end

        -- reactions
        local reactRow = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
            Visible = false, LayoutOrder = nextOrder(), Parent = bubble,
        }, { listLayout(Enum.FillDirection.Horizontal, 4, { Wraps = true }) })
        F.limit(reactRow, 20)
        ui.reactRow = reactRow

        -- footer (own messages: time + status)
        if own then
            ui.statusLbl = New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
                RichText = true, TextSize = 10, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right,
                LayoutOrder = nextOrder(), Paint = { TextColor3 = "muted" }, Text = "", Parent = bubble,
            })
            setStatus(ui, status or "sent")
        end

        bubble.MouseButton1Click:Connect(function()
            if own and ui.status == "failed" then
                F.retry(ui)
            else
                F.openMenu(ui)
            end
        end)

        if m.reacts then F.applyReacts(ui, m.reacts) end
        if S.search ~= "" then
            row.Visible = tostring(row:GetAttribute("MsgText")):find(S.search, 1, true) ~= nil
        end
        S.lastMsgUi = ui
        UI.emptyLbl.Visible = false
        if S.stick then F.scrollBottom() else UI.newPill.Visible = not own end
        return ui
    end

    function F.applySearch()
        for _, c in ipairs(UI.scroll:GetChildren()) do
            if c:IsA("Frame") and c:GetAttribute("MsgText") ~= nil then
                c.Visible = S.search == "" or tostring(c:GetAttribute("MsgText")):find(S.search, 1, true) ~= nil
            end
        end
    end
    function F.toggleSearch()
        UI.searchBar.Visible = not UI.searchBar.Visible
        if not UI.searchBar.Visible then
            UI.searchBox.Text = ""
            S.search = ""
            F.applySearch()
        else
            pcall(function() UI.searchBox:CaptureFocus() end)
        end
        F.relayout()
    end

    ---------------------------------------------------------------- reply
    function F.setReply(ui)
        S.replyTo = {
            uid = ui.m.uid, user = ui.m.user, dn = ui.m.dn, key = ui.key,
            text = clipUtf8(tostring(ui.m.text or ""):gsub("%[%[STICKER:.-%]%]", "[sticker]"), 80),
        }
        UI.replyLbl.Text = '<font color="' .. hex(P.accent) .. '"><b>Replying to ' .. esc(cleanName(ui.m.dn or ui.m.user or "?", 18))
            .. "</b></font>  " .. esc(S.replyTo.text)
        UI.replyBar.Visible = true
        F.relayout()
        pcall(function() UI.input:CaptureFocus() end)
    end
    function F.clearReply()
        S.replyTo = nil
        UI.replyBar.Visible = false
        F.relayout()
    end

    ---------------------------------------------------------------- overlay (context menu / profile)
    function F.closeOverlay()
        UI.overlay.Visible = false
        UI.overlayBody.Visible = false
        for _, c in ipairs(UI.overlayBody:GetChildren()) do
            if not (c:IsA("UICorner") or c:IsA("UIStroke")) then c:Destroy() end
        end
    end
    local function overlayBegin(w)
        F.closeOverlay()
        UI.overlay.Visible = true
        UI.overlayBody.Visible = true
        UI.overlayBody.Size = UDim2.new(0, w, 0, 100)
    end
    local function overlayPlace(h, anchorY)
        local rootSize = UI.root.AbsoluteSize / math.max(0.1, UI.scale.Scale)
        local w = UI.overlayBody.Size.X.Offset
        local x = math.clamp((rootSize.X - w) / 2, 6, math.max(6, rootSize.X - w - 6))
        local y = anchorY or (rootSize.Y - h) / 2
        y = math.clamp(y, 6, math.max(6, rootSize.Y - h - 6))
        UI.overlayBody.Size = UDim2.new(0, w, 0, h)
        UI.overlayBody.Position = UDim2.new(0, x, 0, y)
    end
    local function menuItem(label, y, onClick, danger)
        local b = New("TextButton", {
            Position = UDim2.new(0, 6, 0, y), Size = UDim2.new(1, -12, 0, 28), Text = "  " .. label, TextSize = 12,
            Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = true, ZIndex = 22,
            BackgroundTransparency = 1, Parent = UI.overlayBody,
        }, { corner(7) })
        paint(b, "TextColor3", danger and "danger" or "text")
        b.MouseButton1Click:Connect(function()
            F.closeOverlay()
            onClick()
        end)
        return b
    end

    function F.openMenu(ui)
        local m = ui.m
        overlayBegin(230)
        local y = 6
        -- quick reactions
        if ui.key then
            local rr = New("Frame", {
                Position = UDim2.new(0, 6, 0, y), Size = UDim2.new(1, -12, 0, 32), BackgroundTransparency = 1, ZIndex = 22, Parent = UI.overlayBody,
            }, { listLayout(Enum.FillDirection.Horizontal, 2, { HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
            for i, e in ipairs(QUICK_REACTS) do
                local b = New("TextButton", {
                    Size = UDim2.new(0, 32, 0, 32), Text = e, TextSize = 18, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 23, Parent = rr,
                })
                b.MouseButton1Click:Connect(function()
                    F.closeOverlay()
                    F.toggleReact(ui, e)
                end)
            end
            y = y + 36
        end
        local isSticker = parseSticker(tostring(m.text or "")) ~= nil
        if ui.key then menuItem("↩  Reply", y, function() F.setReply(ui) end); y = y + 30 end
        if not isSticker and m.t ~= "invite" then
            menuItem("📋  Copy text", y, function() F.copy(m.text) end); y = y + 30
        end
        if not ui.own then
            menuItem("👤  Profile", y, function() F.openProfile(m) end); y = y + 30
            menuItem("@  Mention", y, function()
                UI.input.Text = UI.input.Text .. "@" .. tostring(m.user or "") .. " "
                pcall(function() UI.input:CaptureFocus() end)
            end); y = y + 30
        end
        if ME_IS_OWNER and ui.key and m.t ~= "invite" then
            menuItem("📌  Pin message", y, function() F.pin(ui) end); y = y + 30
        end
        if ui.key and (ui.own or ME_IS_OWNER) then
            menuItem("🗑  Delete", y, function() F.deleteMsg(ui) end, true); y = y + 30
        end
        overlayPlace(y + 6, nil)
    end

    function F.openProfile(m)
        local uid = tonumber(m.uid)
        if not uid then return end
        overlayBegin(240)
        local av = New("ImageLabel", {
            Position = UDim2.new(0.5, -32, 0, 12), Size = UDim2.new(0, 64, 0, 64), Image = avatarUrl(uid), ZIndex = 22,
            Paint = { BackgroundColor3 = "card" }, Parent = UI.overlayBody,
        }, { pill() })
        local owner = isOwner(m.user)
        New("TextLabel", {
            Position = UDim2.new(0, 8, 0, 80), Size = UDim2.new(1, -16, 0, 20), BackgroundTransparency = 1, RichText = true,
            Text = "<b>" .. esc(cleanName(m.dn or m.user, 24)) .. "</b>" .. (owner and (' <font color="' .. hex(P.gold) .. '"><b>OWNER</b></font>') or ""),
            TextSize = 14, Font = Enum.Font.Gotham, ZIndex = 22, Paint = { TextColor3 = "text" }, Parent = UI.overlayBody,
        })
        New("TextLabel", {
            Position = UDim2.new(0, 8, 0, 100), Size = UDim2.new(1, -16, 0, 16), BackgroundTransparency = 1,
            Text = "@" .. tostring(m.user or "?") .. (m.script and m.script ~= "" and ("  •  " .. tostring(m.script)) or ""),
            TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 22, Paint = { TextColor3 = "muted" }, Parent = UI.overlayBody,
        })
        local y = 124
        if uid ~= ME_ID then
            menuItem("✉  Send private message", y, function() F.openDM(uid, m.dn or m.user, m.user) end); y = y + 30
            menuItem("@  Mention", y, function()
                UI.input.Text = UI.input.Text .. "@" .. tostring(m.user or "") .. " "
                pcall(function() UI.input:CaptureFocus() end)
            end); y = y + 30
        end
        menuItem("📋  Copy username", y, function() F.copy(m.user) end); y = y + 30
        if ME_IS_OWNER and uid ~= ME_ID and not isOwner(m.user) then
            menuItem("🔇  Mute 10 min", y, function() F.muteUser(uid, 10 * 60) end, true); y = y + 30
            menuItem("🔇  Mute 1 hour", y, function() F.muteUser(uid, 3600) end, true); y = y + 30
            menuItem("🔊  Unmute", y, function() F.muteUser(uid, 0) end); y = y + 30
        end
        overlayPlace(y + 6, nil)
    end

    ---------------------------------------------------------------- title / chips / mute / pin
    function F.isRoomMuted() return Settings.MutedRooms[S.room] == true end

    function F.renderTitle()
        if S.kind == "global" then
            UI.titleLbl.Text = "Global Chat"
        else
            UI.titleLbl.Text = "✉ " .. cleanName(S.targetName or "Private", 18)
        end
        local dot = S.connected and hex(P.good) or hex(P.danger)
        local info
        if not S.connected then info = "reconnecting..."
        elseif S.kind == "global" then info = tostring(S.online) .. " online"
        else info = "private chat" end
        UI.subLbl.Text = '<font color="' .. dot .. '">●</font> ' .. info .. (F.isRoomMuted() and "  •  muted" or "")
        UI.btnMute.Text = F.isRoomMuted() and "🔕" or "🔔"
    end

    function F.toggleMute()
        Settings.MutedRooms[S.room] = (not F.isRoomMuted()) or nil
        persistSettings(Settings)
        F.renderTitle()
        notify(F.isRoomMuted() and "Room muted" or "Room unmuted", F.isRoomMuted() and "You'll only be alerted on @mentions" or "Notifications are back on", "bell")
    end

    function F.touchRecent(uid, name, user)
        uid = tonumber(uid)
        if not uid or uid == ME_ID then return end
        local list = Settings.RecentDMs
        for i, d in ipairs(list) do
            if tonumber(d.uid) == uid then
                if name and name ~= "" then d.name = name end
                if user and user ~= "" then d.user = user end
                return
            end
        end
        table.insert(list, 1, { uid = uid, name = name or tostring(uid), user = user or "" })
        while #list > 8 do table.remove(list) end
        F.refreshChips()
    end

    function F.refreshChips()
        for _, c in ipairs(UI.chips:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local function chip(label, active, order, onClick, badge)
            local b = New("TextButton", {
                Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, Text = label, TextSize = 12,
                Font = Enum.Font.GothamMedium, AutoButtonColor = true, LayoutOrder = order, Parent = UI.chips,
                Paint = { BackgroundColor3 = active and "accent" or "card", TextColor3 = active and "ownText" or "text" },
            }, { pill(), pad(11, 0, 11, 0) })
            if badge then
                New("Frame", {
                    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 1), Size = UDim2.new(0, 9, 0, 9),
                    Paint = { BackgroundColor3 = "danger" }, ZIndex = 3, Parent = b,
                }, { pill() })
            end
            b.MouseButton1Click:Connect(onClick)
        end
        chip("🌐 Global", S.kind == "global", 1, function() F.setRoom("global") end, false)
        for i, d in ipairs(Settings.RecentDMs) do
            local active = S.kind == "private" and tostring(S.target) == tostring(d.uid)
            chip("✉ " .. cleanName(d.name, 12), active, 1 + i, function()
                F.setRoom("private", d.uid, d.name, d.user)
            end, S.unread[tostring(d.uid)] == true)
        end
        if S.kind == "private" then
            chip("✕ Close DM", false, 50, function()
                local list = Settings.RecentDMs
                for i = #list, 1, -1 do
                    if tostring(list[i].uid) == tostring(S.target) then table.remove(list, i) end
                end
                persistSettings(Settings)
                F.setRoom("global")
            end, false)
        end
    end

    function F.refreshPin()
        if S.pin and S.pin.key then
            UI.pinBar.Visible = true
            UI.pinText.Text = "📌 <b>" .. esc(cleanName(S.pin.dn or S.pin.user or "?", 16)) .. "</b>: "
                .. esc((tostring(S.pin.text or ""):gsub("%[%[STICKER:.-%]%]", "[sticker]")))
            UI.pinClose.Visible = ME_IS_OWNER
        else
            UI.pinBar.Visible = false
        end
        F.relayout()
    end
    function F.pin(ui)
        if not ME_IS_OWNER or not ui.key then return end
        local pin = {
            key = ui.key, uid = ui.m.uid, dn = ui.m.dn, user = ui.m.user,
            text = clipUtf8((tostring(ui.m.text or ""):gsub("%[%[STICKER:.-%]%]", "[sticker]")), 120),
        }
        S.pin = pin
        F.refreshPin()
        local room = S.room
        task.spawn(function() call("PUT", urlFor("chat/" .. room .. "/pin"), encode(pin)) end)
    end
    function F.unpin()
        if not ME_IS_OWNER then return end
        S.pin = nil
        F.refreshPin()
        local room = S.room
        task.spawn(function() call("DELETE", urlFor("chat/" .. room .. "/pin")) end)
    end

    function F.deleteMsg(ui)
        if not ui.key then return end
        local key, room = ui.key, S.room
        S.msgUi[key] = nil
        pcall(function() ui.row:Destroy() end)
        task.spawn(function() call("DELETE", urlFor("chat/" .. room .. "/messages/" .. tostring(key))) end)
    end

    function F.muteUser(uid, seconds)
        if not ME_IS_OWNER then return end
        uid = tostring(uid)
        task.spawn(function()
            if seconds <= 0 then
                call("DELETE", urlFor("mod/muted/" .. uid))
                S.muted[uid] = nil
                notify("Unmuted", "User " .. uid .. " can chat again", "volume-2")
            else
                local untilMs = serverNow() + seconds * 1000
                call("PUT", urlFor("mod/muted/" .. uid), encode({ u = untilMs, by = ME_NAME }))
                S.muted[uid] = untilMs
                notify("Muted", "Muted for " .. math.floor(seconds / 60) .. " min", "volume-x")
            end
        end)
    end

    ---------------------------------------------------------------- rooms
    function F.reload()
        S.gen = S.gen + 1
        S.lastKey, S.loaded, S.seen, S.pending, S.msgUi = nil, false, {}, {}, {}
        S.lastGroupUid, S.lastMsgUi, S.pin, S.stick = nil, nil, nil, true
        for _, c in ipairs(UI.scroll:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        UI.emptyLbl.Visible = false
        UI.newPill.Visible = false
        F.clearReply()
        F.refreshPin()
        S.wake = true
    end

    function F.setRoom(kind, uid, name, user)
        if kind == "private" then
            uid = tonumber(uid)
            if not uid or uid == ME_ID then return end
            S.kind, S.target, S.targetName = "private", uid, name or tostring(uid)
            S.room = roomName("private", uid)
            F.touchRecent(uid, name, user)
            S.unread[tostring(uid)] = nil
            Settings.DMSeen[tostring(uid)] = S.dmSeenTs[tostring(uid)] or Settings.DMSeen[tostring(uid)] or 0
            persistSettings(Settings)
        else
            S.kind, S.target, S.targetName = "global", nil, nil
            S.room = roomName("global")
        end
        F.reload()
        F.refreshChips()
        F.renderTitle()
        F.closePanel()
        F.closeOverlay()
    end
    function F.openDM(uid, name, user) F.setRoom("private", uid, name, user) end

    ---------------------------------------------------------------- panels
    local function clearPage(page)
        for _, c in ipairs(page:GetChildren()) do c:Destroy() end
    end

    function F.closePanel()
        S.panel = nil
        UI.panel.Visible = false
        for _, p in pairs(UI.pages) do p.Visible = false end
        F.relayout()
    end

    function F.openPanel(name)
        if S.panel == name then F.closePanel() return end
        S.panel = name
        for k, p in pairs(UI.pages) do p.Visible = (k == name) end
        UI.panel.Visible = true
        local titles = { stickers = "Stickers", emoji = "Emoji", online = "Online", settings = "Settings" }
        UI.panelTitle.Text = titles[name] or name
        if name == "stickers" then F.buildStickers()
        elseif name == "emoji" then F.buildEmoji()
        elseif name == "online" then F.buildOnline(); task.spawn(function() pcall(F.refreshPresence) end)
        elseif name == "settings" then F.buildSettings() end
        F.relayout()
    end

    function F.pushFav(img)
        local favs = Settings.StickerFavs
        for i = #favs, 1, -1 do
            if favs[i] == img then table.remove(favs, i) end
        end
        table.insert(favs, 1, img)
        while #favs > 14 do table.remove(favs) end
        persistSettings(Settings)
    end

    local function stickerPreview(img)
        local frames = parseSticker(stickerPayload(img) or "")
        return frames and frames[1] or tostring(img)
    end

    function F.buildStickers()
        local page = UI.pages.stickers
        clearPage(page)
        if not StickerCatalog.Ready or #StickerCatalog.Order == 0 then
            New("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Loading stickers...", TextSize = 12,
                Font = Enum.Font.Gotham, ZIndex = 8, Paint = { TextColor3 = "muted" }, Parent = page,
            })
            task.spawn(function()
                for _ = 1, 24 do
                    task.wait(0.5)
                    if S.panel ~= "stickers" or not S.alive then return end
                    if StickerCatalog.Ready then F.buildStickers() return end
                end
            end)
            return
        end
        local favs = Settings.StickerFavs
        local gridTop = 0
        if #favs > 0 then
            local fr = New("ScrollingFrame", {
                Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, ScrollBarThickness = 0, ZIndex = 8,
                CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
                ScrollingDirection = Enum.ScrollingDirection.X, Parent = page,
            }, { listLayout(Enum.FillDirection.Horizontal, 6, { VerticalAlignment = Enum.VerticalAlignment.Center }) })
            for i, img in ipairs(favs) do
                local b = New("ImageButton", {
                    Size = UDim2.new(0, 38, 0, 38), Image = stickerPreview(img), ScaleType = Enum.ScaleType.Fit, LayoutOrder = i,
                    ZIndex = 9, Paint = { BackgroundColor3 = "card2" }, Parent = fr,
                }, { corner(8) })
                b.MouseButton1Click:Connect(function()
                    local payload = stickerPayload(img)
                    if payload and F.send(payload) then F.closePanel() end
                end)
            end
            gridTop = 48
        end
        local grid = New("ScrollingFrame", {
            Position = UDim2.new(0, 0, 0, gridTop), Size = UDim2.new(1, 0, 1, -gridTop), BackgroundTransparency = 1,
            ScrollBarThickness = 3, ZIndex = 8, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Paint = { ScrollBarImageColor3 = "line" }, Parent = page,
        }, { New("UIGridLayout", { CellSize = UDim2.new(0, 46, 0, 46), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
        for i, key in ipairs(StickerCatalog.Order) do
            local info = StickerCatalog.Stickers[key]
            if type(info) == "table" and info.Image then
                local b = New("ImageButton", {
                    Image = stickerPreview(info.Image), ScaleType = Enum.ScaleType.Fit, LayoutOrder = i, ZIndex = 9,
                    Paint = { BackgroundColor3 = "card2" }, Parent = grid,
                }, { corner(8) })
                b.MouseButton1Click:Connect(function()
                    local payload = stickerPayload(info.Image)
                    if payload and F.send(payload) then
                        F.pushFav(tostring(info.Image))
                        F.closePanel()
                    end
                end)
            end
        end
    end

    function F.buildEmoji()
        local page = UI.pages.emoji
        clearPage(page)
        local grid = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3, ZIndex = 8,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Paint = { ScrollBarImageColor3 = "line" }, Parent = page,
        }, { New("UIGridLayout", { CellSize = UDim2.new(0, 36, 0, 36), CellPadding = UDim2.new(0, 4, 0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
        for i, e in ipairs(EMOJIS) do
            local b = New("TextButton", {
                Text = e, TextSize = 20, BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 9, Parent = grid,
            })
            b.MouseButton1Click:Connect(function()
                UI.input.Text = UI.input.Text .. e
            end)
        end
    end

    function F.buildOnline()
        local page = UI.pages.online
        clearPage(page)
        local list = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3, ZIndex = 8,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Paint = { ScrollBarImageColor3 = "line" }, Parent = page,
        }, { listLayout(Enum.FillDirection.Vertical, 4) })
        local rows = {}
        for uid, v in pairs(S.onlineMap) do
            rows[#rows + 1] = { uid = tonumber(uid) or 0, n = tostring(v.n or "?"), dn = tostring(v.dn or v.n or "?"), s = tostring(v.s or "") }
        end
        table.sort(rows, function(a, b) return a.dn:lower() < b.dn:lower() end)
        if #rows == 0 then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Nobody else is online right now",
                TextSize = 12, Font = Enum.Font.Gotham, ZIndex = 9, Paint = { TextColor3 = "muted" }, Parent = list,
            })
        end
        for i, r in ipairs(rows) do
            local row = New("Frame", {
                Size = UDim2.new(1, -6, 0, 38), LayoutOrder = i, ZIndex = 8, Paint = { BackgroundColor3 = "card2" }, Parent = list,
            }, { corner(8) })
            New("ImageLabel", {
                Position = UDim2.new(0, 5, 0.5, -14), Size = UDim2.new(0, 28, 0, 28), Image = avatarUrl(r.uid), ZIndex = 9,
                Paint = { BackgroundColor3 = "card" }, Parent = row,
            }, { pill() })
            local nameBtn = New("TextButton", {
                Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, RichText = true,
                Text = "<b>" .. esc(cleanName(r.dn, 16)) .. "</b>" .. (isOwner(r.n) and (' <font color="' .. hex(P.gold) .. '">OWNER</font>') or "")
                    .. '\n<font color="' .. hex(P.muted) .. '">@' .. esc(r.n) .. "</font>",
                TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
                Paint = { TextColor3 = "text" }, Parent = row,
            })
            nameBtn.MouseButton1Click:Connect(function()
                F.openProfile({ uid = r.uid, user = r.n, dn = r.dn, script = r.s })
            end)
            if r.uid ~= ME_ID then
                local dm = textButton(row, "DM", UDim2.new(0, 44, 0, 24), {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), ZIndex = 9,
                }, true)
                dm.MouseButton1Click:Connect(function() F.openDM(r.uid, r.dn, r.n) end)
            end
        end
    end

    function F.buildSettings()
        local page = UI.pages.settings
        clearPage(page)
        local list = New("ScrollingFrame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScrollBarThickness = 3, ZIndex = 8,
            CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Paint = { ScrollBarImageColor3 = "line" }, Parent = page,
        }, { listLayout(Enum.FillDirection.Vertical, 5) })
        local order = 0
        local function nextOrder() order = order + 1; return order end

        local function toggleRow(label, get, set)
            local row = New("Frame", { Size = UDim2.new(1, -6, 0, 30), LayoutOrder = nextOrder(), ZIndex = 8, Paint = { BackgroundColor3 = "card2" }, Parent = list }, { corner(8) })
            New("TextLabel", {
                Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, Text = label,
                TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
                Paint = { TextColor3 = "text" }, Parent = row,
            })
            local btn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.new(0, 52, 0, 22),
                TextSize = 11, Font = Enum.Font.GothamBold, ZIndex = 9, Text = "", Parent = row,
            }, { pill() })
            local function sync()
                local on = get()
                btn.Text = on and "ON" or "OFF"
                btn.BackgroundColor3 = on and P.accent or P.card
                btn.TextColor3 = on and P.ownText or P.muted
            end
            sync()
            btn.MouseButton1Click:Connect(function()
                set(not get())
                sync()
            end)
        end
        toggleRow("Side notifications", function() return Settings.SideNotifs end, function(v) Settings.SideNotifs = v; persistSettings(Settings) end)
        toggleRow("@Mention alerts", function() return Settings.MentionsEnabled end, function(v) Settings.MentionsEnabled = v; persistSettings(Settings) end)
        toggleRow("Compact mode", function() return Settings.CompactMode end, function(v)
            Settings.CompactMode = v; persistSettings(Settings); F.reload()
        end)
        if ME_IS_OWNER then
            toggleRow("Hide my name (owner)", function() return Settings.HideMyName end, function(v) Settings.HideMyName = v; persistSettings(Settings) end)
        end

        -- accent swatches
        local accRow = New("Frame", { Size = UDim2.new(1, -6, 0, 34), LayoutOrder = nextOrder(), ZIndex = 8, Paint = { BackgroundColor3 = "card2" }, Parent = list }, { corner(8) })
        New("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 60, 1, 0), BackgroundTransparency = 1, Text = "Accent",
            TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            Paint = { TextColor3 = "text" }, Parent = accRow,
        })
        local sw = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.new(1, -80, 0, 24),
            BackgroundTransparency = 1, ZIndex = 9, Parent = accRow,
        }, { listLayout(Enum.FillDirection.Horizontal, 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center }) })
        for i, name in ipairs(ACCENT_ORDER) do
            local b = New("TextButton", {
                Size = UDim2.new(0, 22, 0, 22), Text = "", BackgroundColor3 = ACCENTS[name], LayoutOrder = i, ZIndex = 10, Parent = sw,
            }, { pill() })
            if Settings.ChatAccent == name then New("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = b }) end
            b.MouseButton1Click:Connect(function()
                F.setAccent(name)
                F.buildSettings()
            end)
        end

        -- scale
        local scRow = New("Frame", { Size = UDim2.new(1, -6, 0, 32), LayoutOrder = nextOrder(), ZIndex = 8, Paint = { BackgroundColor3 = "card2" }, Parent = list }, { corner(8) })
        New("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0, 80, 1, 0), BackgroundTransparency = 1, Text = "Chat size",
            TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9,
            Paint = { TextColor3 = "text" }, Parent = scRow,
        })
        local pctLbl = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), Size = UDim2.new(0, 46, 0, 22),
            BackgroundTransparency = 1, Text = math.floor(UI.scale.Scale * 100 + 0.5) .. "%", TextSize = 12,
            Font = Enum.Font.GothamBold, ZIndex = 9, Paint = { TextColor3 = "text" }, Parent = scRow,
        })
        local minus = textButton(scRow, "−", UDim2.new(0, 26, 0, 22), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -92, 0.5, 0), ZIndex = 9 }, false)
        local plus = textButton(scRow, "+", UDim2.new(0, 26, 0, 22), { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 9 }, false)
        minus.MouseButton1Click:Connect(function()
            F.setScale(UI.scale.Scale - 0.05)
            pctLbl.Text = math.floor(UI.scale.Scale * 100 + 0.5) .. "%"
        end)
        plus.MouseButton1Click:Connect(function()
            F.setScale(UI.scale.Scale + 0.05)
            pctLbl.Text = math.floor(UI.scale.Scale * 100 + 0.5) .. "%"
        end)

        local clr = textButton(list, "Clear DM list", UDim2.new(1, -6, 0, 28), { LayoutOrder = nextOrder(), ZIndex = 9 }, false)
        clr.MouseButton1Click:Connect(function()
            Settings.RecentDMs = {}
            persistSettings(Settings)
            if S.kind == "private" then F.setRoom("global") else F.refreshChips() end
        end)
    end

    function F.setAccent(name)
        if not ACCENTS[name] then return end
        Settings.ChatAccent = name
        persistSettings(Settings)
        repaint()
        F.refreshChips()
        F.renderTitle()
    end
    function F.setScale(sc)
        sc = math.clamp(tonumber(sc) or 1, 0.75, 1.4)
        UI.scale.Scale = sc
        Settings.ChatScale = sc
        envGet().NeoChatScale = sc
        persistSettings(Settings)
        F.relayout()
    end

    ---------------------------------------------------------------- toasts (side notifications)
    function F.ensureToastGui()
        if S.toastGui and S.toastGui.Parent then return end
        local parent
        pcall(function() if gethui then parent = gethui() end end)
        if not parent then
            local okCG, cg = pcall(function() return game:GetService("CoreGui") end)
            parent = (okCG and cg) or LocalPlayer:WaitForChild("PlayerGui")
        end
        local gui = Instance.new("ScreenGui")
        gui.Name = "NeoChatToasts"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        gui.DisplayOrder = 120
        gui.Parent = parent
        local holder = New("Frame", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12), Size = UDim2.new(0, 270, 1, -24),
            BackgroundTransparency = 1, Parent = gui,
        }, { listLayout(Enum.FillDirection.Vertical, 6, { HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
        S.toastGui, S.toastHolder = gui, holder
    end

    function F.toast(m, tag)
        if not S.alive then return end
        F.ensureToastGui()
        local kids = {}
        for _, c in ipairs(S.toastHolder:GetChildren()) do
            if c:IsA("Frame") then kids[#kids + 1] = c end
        end
        while #kids >= 3 do
            local old = table.remove(kids, 1)
            pcall(function() old:Destroy() end)
        end
        local text = tostring(m.text or "")
        if parseSticker(text) then text = "[sticker]" end
        if m.t == "invite" then text = "🎮 invited you to a server" end
        S.order = S.order + 1
        local card = New("Frame", {
            Size = UDim2.new(0, 270, 0, 52), LayoutOrder = S.order, BackgroundColor3 = P.card, BackgroundTransparency = 0.05,
            Parent = S.toastHolder,
        }, { corner(10) })
        New("UIStroke", { Thickness = 1, Color = P.accent, Parent = card })
        New("ImageLabel", {
            Position = UDim2.new(0, 8, 0.5, -16), Size = UDim2.new(0, 32, 0, 32), Image = avatarUrl(m.uid),
            BackgroundColor3 = P.card2, Parent = card,
        }, { pill() })
        New("TextLabel", {
            Position = UDim2.new(0, 48, 0, 6), Size = UDim2.new(1, -56, 0, 16), BackgroundTransparency = 1, RichText = true,
            Text = "<b>" .. esc(cleanName(m.dn or m.user or "?", 18)) .. "</b>" .. (tag and ('  <font color="' .. hex(P.accent) .. '">' .. esc(tag) .. "</font>") or ""),
            TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = P.text, Parent = card,
        })
        New("TextLabel", {
            Position = UDim2.new(0, 48, 0, 24), Size = UDim2.new(1, -56, 0, 22), BackgroundTransparency = 1, Text = clipUtf8(text, 70),
            TextSize = 11, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true, TextColor3 = P.muted, Parent = card,
        })
        task.delay(tonumber(Settings.SideNotifDuration) or 3.2, function()
            if card.Parent then
                pcall(function()
                    TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
                end)
                task.wait(0.3)
                pcall(function() card:Destroy() end)
            end
        end)
    end

    ---------------------------------------------------------------- sending
    function F.pushTyping()
        if UI.input.Text == "" then return end
        if os.clock() - S.lastTypingPush < 2.5 then return end
        S.lastTypingPush = os.clock()
        local room = S.room
        task.spawn(function()
            call("PUT", urlFor("typing/" .. room .. "/" .. ME_ID), encode({ t = { [".sv"] = "timestamp" }, n = ME_DN }))
        end)
    end

    function F.postMessage(ui, payload)
        local gen, room, kind, target = S.gen, S.room, S.kind, S.target
        task.spawn(function()
            local ok, body = call("POST", urlFor("chat/" .. room .. "/messages"), encode(payload))
            if gen ~= S.gen then return end
            if ok then
                local d = decode(body)
                if type(d) == "table" and d.name then
                    S.seen[d.name] = true
                    ui.key = d.name
                    ui.m._k = d.name
                    S.msgUi[d.name] = ui
                end
                if payload.cid then S.pending[payload.cid] = nil end
                F.setStatus(ui, "sent")
                if kind == "private" and target then
                    local preview = tostring(payload.text or "")
                    if parseSticker(preview) then preview = "[sticker]" end
                    call("PUT", urlFor("inbox/" .. tostring(target) .. "/" .. tostring(ME_ID)), encode({
                        uid = ME_ID, user = ME_NAME, dn = payload.dn, text = clipUtf8(preview, 60),
                        ts = { [".sv"] = "timestamp" },
                    }))
                end
            else
                F.setStatus(ui, "failed")
            end
        end)
    end

    function F.retry(ui)
        if not ui.payload then return end
        F.setStatus(ui, "pending")
        F.postMessage(ui, ui.payload)
    end

    function F.send(text, extra)
        text = clipUtf8(trim(text), MAXLEN)
        if text == "" and not extra then return false end
        local mutedUntil = S.muted[tostring(ME_ID)]
        if mutedUntil and mutedUntil > serverNow() and not ME_IS_OWNER then
            notify("You are muted", "About " .. math.ceil((mutedUntil - serverNow()) / 60000) .. " min left", "volume-x")
            return false
        end
        if os.clock() - S.lastSend < COOLDOWN then
            notify("Slow down", "Wait a second between messages", "clock")
            return false
        end
        if text ~= "" and text == S.lastText and os.clock() - S.lastTextAt < 6 and not extra then
            notify("Duplicate", "You just sent that", "copy")
            return false
        end
        S.lastSend, S.lastText, S.lastTextAt = os.clock(), text, os.clock()
        local displayName = ME_DN
        if Settings.HideMyName and ME_IS_OWNER then displayName = "Hidden" end
        local cid = HttpService:GenerateGUID(false)
        local payload = {
            uid = ME_ID, user = ME_NAME, dn = displayName, text = text, cid = cid, t = "msg",
            ts = { [".sv"] = "timestamp" }, script = SCRIPT_NAME, scriptImg = SCRIPT_IMG,
        }
        if S.replyTo then
            payload.reply = { uid = S.replyTo.uid, user = S.replyTo.user, dn = S.replyTo.dn, text = S.replyTo.text, key = S.replyTo.key }
        end
        for k, v in pairs(extra or {}) do payload[k] = v end
        if payload.text == "" then payload.text = "invite" end
        local shown = {}
        for k, v in pairs(payload) do shown[k] = v end
        shown.ts = serverNow()
        local ui = F.render(shown, true, "pending")
        ui.payload = payload
        S.pending[cid] = ui
        F.clearReply()
        F.scrollBottom(true)
        F.postMessage(ui, payload)
        return true
    end

    function F.doSend()
        if F.send(UI.input.Text) then UI.input.Text = "" end
    end

    function F.sendInvite()
        local left = INVITE_COOLDOWN - (os.clock() - S.lastInvite)
        if left > 0 then
            notify("Invite cooldown", "Wait " .. math.ceil(left) .. " seconds", "clock")
            return
        end
        local info
        pcall(function() info = MarketplaceService:GetProductInfo(game.PlaceId) end)
        local ok = F.send(UI.input.Text, {
            t = "invite", place = game.PlaceId, job = game.JobId, game = info and info.Name or "Roblox",
            pc = #Players:GetPlayers(), mx = Players.MaxPlayers,
        })
        if ok then S.lastInvite = os.clock(); UI.input.Text = "" end
    end

    ---------------------------------------------------------------- incoming messages
    S.unreadCount = 0
    function F.onIncoming(m)
        if tostring(m.text or "") == "" then return end
        local visible = F.isVisible()
        local roomMuted = F.isRoomMuted()
        local mention = mentionsMe(m.text)
        if visible then return end
        S.unreadCount = S.unreadCount + 1
        if mention and Settings.MentionsEnabled then
            F.toast(m, "mentioned you")
        elseif Settings.SideNotifs and not roomMuted then
            F.toast(m, S.kind == "private" and "DM" or nil)
        end
    end

    function F.process(m, isHistory)
        local key = m._k
        if not key then return end
        local sig = encode(m.reacts or {})
        local existing = S.msgUi[key]
        if S.seen[key] then
            if existing and existing.reactSig ~= sig then
                existing.reactSig = sig
                F.applyReacts(existing, m.reacts)
            end
            return
        end
        if not S.lastKey or key > S.lastKey then S.lastKey = key end
        if m.cid and S.pending[m.cid] then
            local ui = S.pending[m.cid]
            S.pending[m.cid] = nil
            S.seen[key] = true
            ui.key = key
            ui.m._k = key
            ui.m.ts = m.ts
            ui.reactSig = sig
            S.msgUi[key] = ui
            F.setStatus(ui, "sent")
            return
        end
        S.seen[key] = true
        local uid = tonumber(m.uid) or 0
        local until_ = S.muted[tostring(uid)]
        if until_ and until_ > serverNow() and uid ~= ME_ID and not isOwner(m.user) then return end
        local own = uid == ME_ID
        local ui = F.render(m, own, "sent")
        ui.key = key
        ui.reactSig = sig
        S.msgUi[key] = ui
        if not isHistory and not own then F.onIncoming(m) end
    end

    ---------------------------------------------------------------- polling
    function F.pollRoom(full)
        local gen, room = S.gen, S.room
        local q
        if S.lastKey and not full then
            q = "orderBy=%22%24key%22&startAt=%22" .. HttpService:UrlEncode(S.lastKey) .. "%22"
        else
            q = "orderBy=%22%24key%22&limitToLast=" .. HISTORY
        end
        local ok, body = call("GET", urlFor("chat/" .. room .. "/messages", q))
        if not ok then return false end
        if gen ~= S.gen then return true end
        local data = decode(body)
        local arr, fetched, minKey = {}, {}, nil
        if type(data) == "table" then
            for k, v in pairs(data) do
                if type(v) == "table" then
                    v._k = k
                    arr[#arr + 1] = v
                    fetched[k] = true
                    if not minKey or k < minKey then minKey = k end
                end
            end
            table.sort(arr, function(a, b) return a._k < b._k end)
        end
        local history = not S.loaded
        for _, m in ipairs(arr) do F.process(m, history) end
        if history then
            S.loaded = true
            if #arr == 0 then UI.emptyLbl.Visible = true end
            F.scrollBottom(true)
        end
        if full and minKey then
            -- remove messages deleted by others (only inside the fetched window)
            for k, ui in pairs(S.msgUi) do
                if k >= minKey and not fetched[k] and ui.status ~= "pending" then
                    S.msgUi[k] = nil
                    pcall(function() ui.row:Destroy() end)
                end
            end
        end
        if full then
            local pok, pbody = call("GET", urlFor("chat/" .. room .. "/pin"))
            if pok and gen == S.gen then
                local pd = decode(pbody)
                local newKey = type(pd) == "table" and pd.key or nil
                local oldKey = S.pin and S.pin.key or nil
                if newKey ~= oldKey then
                    S.pin = newKey and pd or nil
                    F.refreshPin()
                end
            end
        end
        return true
    end

    function F.pollTyping()
        local room = S.room
        local ok, body = call("GET", urlFor("typing/" .. room))
        if not ok or room ~= S.room then return end
        local names = {}
        local d = decode(body)
        if type(d) == "table" then
            local now = serverNow()
            for uid, v in pairs(d) do
                if tostring(uid) ~= tostring(ME_ID) and type(v) == "table" and tonumber(v.t) and now - v.t < 4500 then
                    names[#names + 1] = cleanName(v.n or "Someone", 14)
                end
            end
        end
        local was = UI.typingLbl.Visible
        if #names == 0 then
            UI.typingLbl.Visible = false
        else
            UI.typingLbl.Text = (#names == 1 and (names[1] .. " is typing…")) or (#names .. " people are typing…")
            UI.typingLbl.Visible = true
        end
        if was ~= UI.typingLbl.Visible then F.relayout() end
    end

    function F.refreshPresence()
        call("PUT", urlFor("presence/" .. ME_ID), encode({
            n = ME_NAME, dn = ME_DN, s = SCRIPT_NAME, t = { [".sv"] = "timestamp" },
        }))
        local ok, body = call("GET", urlFor("presence"))
        if not ok then return end
        local d = decode(body)
        if type(d) ~= "table" then return end
        local me = d[tostring(ME_ID)]
        if type(me) == "table" and tonumber(me.t) then
            S.skew = os.time() * 1000 - me.t
        end
        local now, map, count = serverNow(), {}, 0
        for uid, v in pairs(d) do
            if type(v) == "table" and tonumber(v.t) and now - v.t < 50000 then
                map[tostring(uid)] = v
                count = count + 1
            end
        end
        S.onlineMap = map
        S.online = math.max(1, count)
        F.renderTitle()
        if S.panel == "online" then F.buildOnline() end
    end

    function F.refreshMods()
        local ok, body = call("GET", urlFor("mod/muted"))
        if not ok then return end
        local d = decode(body)
        local map = {}
        if type(d) == "table" then
            for uid, v in pairs(d) do
                if type(v) == "table" and tonumber(v.u) then map[tostring(uid)] = tonumber(v.u) end
            end
        end
        S.muted = map
    end

    function F.pollInbox()
        local ok, body = call("GET", urlFor("inbox/" .. ME_ID))
        if not ok then return end
        local d = decode(body)
        local changed = false
        if type(d) == "table" then
            for suid, v in pairs(d) do
                if type(v) == "table" and tonumber(v.ts) then
                    local su = tostring(suid)
                    S.dmSeenTs[su] = v.ts
                    F.touchRecent(tonumber(suid), v.dn or v.user, v.user)
                    local viewing = S.kind == "private" and tostring(S.target) == su and F.isVisible()
                    if viewing then
                        if (Settings.DMSeen[su] or 0) < v.ts then Settings.DMSeen[su] = v.ts; changed = true end
                    elseif v.ts > (Settings.DMSeen[su] or 0) then
                        if not S.unread[su] then S.unread[su] = true; changed = true end
                        if S.inboxLoaded and (S.toastTs[su] or 0) < v.ts then
                            S.toastTs[su] = v.ts
                            if Settings.SideNotifs and not F.isVisible() then
                                F.toast({ uid = tonumber(suid), dn = v.dn, user = v.user, text = v.text }, "DM")
                            end
                        end
                        S.toastTs[su] = math.max(S.toastTs[su] or 0, v.ts)
                    end
                end
            end
        end
        S.inboxLoaded = true
        if changed then
            persistSettings(Settings)
            F.refreshChips()
        end
    end

    ---------------------------------------------------------------- main loop
    task.spawn(function()
        local tick, lastPresence, lastMods = 0, -100, -100
        F.renderTitle()
        F.refreshChips()
        F.relayout()
        while S.alive and not (Window and Window.Destroyed) do
            tick = tick + 1
            local visible = F.isVisible()
            local okCall, okRoom = pcall(F.pollRoom, tick % 6 == 0 or not S.loaded)
            local good = okCall and okRoom == true
            if good then S.fails = 0 else S.fails = S.fails + 1 end
            if good ~= S.connected then
                S.connected = good
                F.renderTitle()
            end
            if visible and tick % 2 == 0 then pcall(F.pollTyping) end
            if tick % 3 == 0 then pcall(F.pollInbox) end
            if os.clock() - lastPresence > 18 then
                lastPresence = os.clock()
                task.spawn(function() pcall(F.refreshPresence) end)
            end
            if os.clock() - lastMods > 15 then
                lastMods = os.clock()
                task.spawn(function() pcall(F.refreshMods) end)
            end
            if S.unreadCount > 0 and visible then S.unreadCount = 0 end
            local wait = visible and POLL or 3
            if S.fails > 0 then wait = math.min(12, wait + S.fails * 1.5) end
            local steps = math.ceil(wait / 0.25)
            for _ = 1, steps do
                task.wait(0.25)
                if S.wake or not S.alive then break end
            end
            S.wake = false
        end
        S.alive = false
    end)

    ---------------------------------------------------------------- public controller
    local Chat = { Tab = tab, Version = NeoChat.Version }
    function Chat:Send(text) return F.send(text) end
    function Chat:SendInvite() return F.sendInvite() end
    function Chat:SetRoom(kind, uid, name) return F.setRoom(kind, uid, name) end
    function Chat:Unread()
        local n = S.unreadCount
        for _ in pairs(S.unread) do n = n + 1 end
        return n
    end
    function Chat:SetScale(sc) F.setScale(sc) end
    function Chat:SetSideNotifs(on) Settings.SideNotifs = on == true; persistSettings(Settings) end
    function Chat:SetMentions(on) Settings.MentionsEnabled = on == true; persistSettings(Settings) end
    function Chat:SetCompact(on)
        Settings.CompactMode = on == true
        persistSettings(Settings)
        F.reload()
    end
    function Chat:SetAccent(name) F.setAccent(name) end
    function Chat:Destroy()
        S.alive = false
        pcall(function() UI.root:Destroy() end)
        pcall(function() if S.toastGui then S.toastGui:Destroy() end end)
    end

    envGet().NeoChatController = Chat
    envGet().NeoChatSettings = Settings
    envGet().NeoChatScale = UI.scale.Scale
    envGet().NeoChatSetScale = function(sc) F.setScale(sc) end
    return Chat
end

function NeoChat.AddChat(a, b, c)
    local Window, cfg
    if a == NeoChat then Window, cfg = b, c else Window, cfg = a, b end
    cfg = cfg or {}
    local WindUI = cfg.WindUI or envGet().WindUI or _G.WindUI or (type(shared) == "table" and shared.WindUI)
    assert(WindUI, "NeoChat: WindUI not found (pass cfg.WindUI)")
    return NeoChat.Init(WindUI, Window, cfg)
end

return NeoChat
