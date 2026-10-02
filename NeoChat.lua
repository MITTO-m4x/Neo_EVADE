--[[
    NeoChat v2.2  —  Firebase chat for WindUI  (Neo Hyper)
    - WindUI / Lucide icons only on chrome (Footagesus Icons)
    - Stickers from Yin catalog (GitHub) instead of emoji panel
    - Invite cooldown 30s
    - Clean Private player list panel
    - Mentions-only side notifs | Owners v_orc / n_oqv
]]

local NeoChat = {
    DatabaseURL = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app",
    Version = "2.2",
    StickersURL = "https://raw.githubusercontent.com/Sephtis32/Yin-stickers/refs/heads/main/YinYang_Stickers.lua",
}

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

------------------------------------------------------------------ Icons (WindUI / Lucide)
local IconsLib = nil
pcall(function()
    IconsLib = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/main/Main-v2.lua"))()
    if IconsLib and IconsLib.SetIconsType then
        pcall(function() IconsLib.SetIconsType("lucide") end)
    end
end)

local function getIconImage(name)
    if not IconsLib then return nil end
    local ok, img = pcall(function()
        if IconsLib.GetIcon then return IconsLib.GetIcon(name) end
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

------------------------------------------------------------------ Stickers catalog
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

local function stickerPayload(imageOrFrames)
    if type(imageOrFrames) == "table" then
        -- animated: list of rbxassetid + interval
        local parts = {}
        for _, id in ipairs(imageOrFrames) do
            if type(id) == "string" then parts[#parts + 1] = id end
        end
        if #parts == 0 then return nil end
        return "[[STICKER:" .. table.concat(parts, "|") .. "]]"
    end
    local img = tostring(imageOrFrames or "")
    if img == "" then return nil end
    return "[[STICKER:" .. img .. "]]"
end

local function parseSticker(text)
    local body = tostring(text or ""):match("^%[%[STICKER:(.-)%]%]$")
    if not body then return nil end
    local frames = {}
    local interval = 0.4
    for part in body:gmatch("[^|]+") do
        part = trim(part)
        if part:match("^%d+%.%d+$") or part:match("^%d+$") then
            local n = tonumber(part)
            if n and n >= 0.1 and n <= 5 then interval = n end
        elseif part:find("rbxassetid://", 1, true) or part:match("^%d+$") then
            if not part:find("rbxassetid://", 1, true) then
                part = "rbxassetid://" .. part
            end
            frames[#frames + 1] = part
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
    }
    local s = getgenv().NeoChatSettings
    if type(s) ~= "table" then
        getgenv().NeoChatSettings = def
        return def
    end
    for k, v in pairs(def) do
        if s[k] == nil then s[k] = v end
    end
    return s
end

------------------------------------------------------------------ main
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
        seen = {}, pending = {}, unread = {}, lastSend = 0, lastToast = 0, fails = 0,
        online = 1, panelOpen = false, shown = 0, lastBadge = 0,
        replyTo = nil, privateTarget = nil, privateName = nil,
        typing = false, lastTypingPush = 0, lastInvite = 0,
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

    local Creator = WindUI and WindUI.Creator
    local function themeColor(tag, default)
        local ok, c = pcall(function() return Creator.GetThemeProperty(tag, WindUI.Theme) end)
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
            local ok, obj = pcall(Creator.New, class, props, children)
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

    -- Clean icon button (ImageLabel from Lucide via IconsLib)
    local function iconButton(parent, iconName, fallbackLetter, x, size, callback)
        size = size or 30
        local btn = New("TextButton", {
            Position = UDim2.new(0, x, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, size, 0, size),
            Text = "",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Parent = parent,
        })
        local img = New("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, size - 8, 0, size - 8),
            BackgroundTransparency = 1,
            ScaleType = Enum.ScaleType.Fit,
            Parent = btn,
        })
        local asset = getIconImage(iconName)
        if asset then
            img.Image = asset
            pcall(function() img.ImageColor3 = P.text end)
            painted[#painted + 1] = { img, "ImageColor3", "text" }
        else
            img:Destroy()
            New("TextLabel", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Text = fallbackLetter or "?",
                TextSize = 14,
                Font = Enum.Font.GothamBold,
                Bind = { TextColor3 = "text" },
                Parent = btn,
            })
        end
        if callback then btn.MouseButton1Click:Connect(callback) end
        return btn
    end

    local tab = cfg.Tab or Window:Tab({ Title = cfg.Title or "Chat", Icon = cfg.Icon or "message-circle" })
    local canvas = tab.UIElements.ContainerFrameCanvas
    local sideBtn = tab.UIElements.Main

    task.spawn(function()
        for _ = 1, 2 do
            task.wait(0.25)
            pcall(function()
                local dummy = Instance.new("Frame")
                dummy.Size = UDim2.new(0, 0, 0, 0)
                dummy.BackgroundTransparency = 1
                dummy.Parent = tab.UIElements.ContainerFrame
                tab.UIElements.ContainerFrame.Visible = false
            end)
        end
    end)

    local HEADER, INPUT_H, PANEL_H, REPLY_H, PRIV_H = 40, 48, 160, 34, 20
    local root = New("Frame", {
        Name = "NeoChat", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, Parent = canvas
    })

    local title = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.48, 0, 0, HEADER),
        BackgroundTransparency = 1, RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamBold, TextSize = 14,
        Text = "Chat", Bind = { TextColor3 = "text" }, Parent = root,
    })

    local pills = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0, HEADER / 2),
        Size = UDim2.new(0, 158, 0, 26),
        Bind = { BackgroundColor3 = "card" }, Parent = root,
    }, { corner(13) })

    local pillBtns = {}
    local function makePill(kind, text, x)
        local b = New("TextButton", {
            Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(0.5, -4, 1, -4),
            Text = text, TextSize = 12, Font = Enum.Font.GothamMedium,
            BackgroundTransparency = 1, AutoButtonColor = false,
            Bind = { TextColor3 = "text" }, Parent = pills,
        }, { corner(11) })
        pillBtns[kind] = b
        return b
    end
    makePill("global", "Global", 0)
    makePill("private", "Private", 0.5)

    local privHeader = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, HEADER - 2),
        Size = UDim2.new(1, -24, 0, PRIV_H),
        BackgroundTransparency = 1, Text = "",
        TextSize = 11, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.3, Bind = { TextColor3 = "text" },
        Visible = false, Parent = root,
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

    -- Stickers / Private-picker panel
    local panel = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 8, 1, -(INPUT_H)),
        Size = UDim2.new(1, -16, 0, PANEL_H - 8),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 5, Parent = root,
    }, { corner(12) })

    local panelTitle = New("TextLabel", {
        Position = UDim2.new(0, 10, 0, 4), Size = UDim2.new(1, -20, 0, 20),
        BackgroundTransparency = 1, Text = "Stickers",
        TextSize = 12, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text" }, Parent = panel,
    })

    local panelScroll = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 6, Parent = panel,
    }, {
        New("UIGridLayout", {
            CellSize = UDim2.new(0, 52, 0, 52),
            CellPadding = UDim2.new(0, 6, 0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        pad(8, 4, 8, 8),
    })

    -- Private list mode uses vertical list
    local privateList = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -30),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false, ZIndex = 6, Parent = panel,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
        pad(8, 4, 8, 8),
    })

    -------------------------------------------------------------- Reply bar
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

    -------------------------------------------------------------- Input row
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
        BackgroundTransparency = 1,
        PlaceholderText = "Type a message...",
        Text = "", ClearTextOnFocus = false, TextSize = 13,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text", PlaceholderColor3 = "placeholder" }, Parent = inputRow,
    })

    -- forward decls for callbacks
    local openStickersPanel, openPrivatePanel, sendInvite, doSend, send, setRoom, relayout

    local stickerBtn = iconButton(inputRow, "sticker", "S", 6, 30, function()
        if S.panelOpen and panelTitle.Text == "Stickers" then
            S.panelOpen = false
        else
            openStickersPanel()
        end
        relayout()
    end)

    local inviteBtn = iconButton(inputRow, "send", "I", 38, 30, function()
        sendInvite()
    end)

    function relayout()
        local extraTop = (S.kind == "private" and PRIV_H or 0)
        local bottom = INPUT_H + (S.panelOpen and PANEL_H or 0) + (S.replyTo and REPLY_H or 0)
        scroll.Position = UDim2.new(0, 0, 0, HEADER + extraTop)
        scroll.Size = UDim2.new(1, 0, 1, -(HEADER + extraTop + bottom))
        panel.Visible = S.panelOpen
        replyBar.Visible = S.replyTo ~= nil
        privHeader.Visible = S.kind == "private"
        if S.replyTo then
            replyBar.Position = UDim2.new(0, 8, 1, -(INPUT_H - 6 + (S.panelOpen and PANEL_H or 0)))
        end
        panel.Position = UDim2.new(0, 8, 1, -(INPUT_H + (S.replyTo and REPLY_H or 0)))
    end

    local function clearReply()
        S.replyTo = nil
        replyNameLbl.Text = ""
        replyTextLbl.Text = ""
        relayout()
    end

    local function setReply(m)
        if not m then return clearReply() end
        S.replyTo = {
            uid = m.uid, user = m.user or "?", dn = m.dn or m.user or "?",
            text = tostring(m.text or ""):sub(1, 80), key = m._k,
        }
        replyNameLbl.Text = cleanName(S.replyTo.dn)
        replyTextLbl.Text = S.replyTo.text
        relayout()
        pcall(function() input:CaptureFocus() end)
    end
    replyClose.MouseButton1Click:Connect(clearReply)

    -------------------------------------------------------------- Stickers panel builder
    function openStickersPanel()
        S.panelOpen = true
        panelTitle.Text = "Stickers"
        panelScroll.Visible = true
        privateList.Visible = false
        for _, c in ipairs(panelScroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then c:Destroy() end
        end
        local order = StickerCatalog.Order
        local stickers = StickerCatalog.Stickers
        if not StickerCatalog.Ready or #order == 0 then
            panelTitle.Text = "Stickers (loading...)"
            task.delay(0.8, function()
                if S.panelOpen and panelTitle.Text:find("loading") then
                    openStickersPanel()
                end
            end)
            return
        end
        local maxShow = math.min(80, #order)
        for i = 1, maxShow do
            local key = order[i]
            local info = stickers[key]
            if type(info) == "table" and info.Image then
                local btn = New("ImageButton", {
                    Size = UDim2.new(0, 52, 0, 52),
                    BackgroundTransparency = 0.85,
                    Image = tostring(info.Image),
                    ScaleType = Enum.ScaleType.Fit,
                    LayoutOrder = i,
                    ZIndex = 7,
                    Parent = panelScroll,
                }, { corner(8) })
                btn.MouseButton1Click:Connect(function()
                    local payload = stickerPayload(info.Image)
                    if payload then
                        send(payload)
                        S.panelOpen = false
                        relayout()
                    end
                end)
            end
        end
    end

    function openPrivatePanel()
        S.panelOpen = true
        panelTitle.Text = "Private — choose player"
        panelScroll.Visible = false
        privateList.Visible = true
        for _, c in ipairs(privateList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local any = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                any = true
                local label = cleanName(plr.DisplayName) .. "  @" .. cleanName(plr.Name)
                local b = New("TextButton", {
                    Size = UDim2.new(1, -4, 0, 32),
                    Text = "  " .. label,
                    TextSize = 13,
                    Font = Enum.Font.GothamMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Bind = { BackgroundColor3 = "other", TextColor3 = "text" },
                    ZIndex = 7,
                    Parent = privateList,
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
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Text = "No other players in this server",
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextTransparency = 0.4,
                Bind = { TextColor3 = "text" },
                Parent = privateList,
            })
        end
    end

    -------------------------------------------------------------- Side notifs (mention only)
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
        sideContainer.Name = "Container"
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
        if not Settings.SideNotifs then return end
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
        p.PaddingTop = UDim.new(0, 6)
        p.PaddingBottom = UDim.new(0, 6)
        p.PaddingLeft = UDim.new(0, 8)
        p.PaddingRight = UDim.new(0, 8)
        p.Parent = card
        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, 0, 0, 14)
        nameL.BackgroundTransparency = 1
        nameL.Text = cleanName(m.dn or m.user or "Someone")
        nameL.TextColor3 = Color3.fromRGB(220, 220, 220)
        nameL.TextSize = 12
        nameL.Font = Enum.Font.GothamBold
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
        msgL.TextSize = 12
        msgL.Font = Enum.Font.Gotham
        msgL.TextXAlignment = Enum.TextXAlignment.Left
        msgL.TextWrapped = true
        msgL.Parent = card
        card.Position = UDim2.new(0, 28, 0, 0)
        TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        task.delay(dur, function()
            if not card or not card.Parent then return end
            pcall(function() nameL.TextTransparency = 1; msgL.TextTransparency = 1 end)
            local tw = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                BackgroundTransparency = 1
            })
            tw:Play()
            tw.Completed:Wait()
            card:Destroy()
        end)
    end

    -------------------------------------------------------------- Badge
    local badge = New("Frame", {
        Name = "NeoBadge", AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30, Parent = sideBtn,
    }, {
        corner(9),
        New("UISizeConstraint", { MinSize = Vector2.new(18, 18) }),
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
        return canvas.Visible and not Window.Closed and not Window.Destroyed
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
    local function labelMax() return math.max(120, scroll.AbsoluteSize.X / scale() - 120) end
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
        local n1 = "@" .. ME_NAME:lower()
        local n2 = "@" .. ME_DN:lower()
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
        return hasFull(n1) or hasFull(n2)
    end

    local function deleteMessage(key)
        if not ME_IS_OWNER or not key then return end
        task.spawn(function()
            call("DELETE", urlFor("chat/" .. S.room .. "/messages/" .. key))
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
        ui.row = row

        if Settings.MessageAnims then
            local sc = Instance.new("UIScale")
            sc.Scale = 0.93
            sc.Parent = row
            TweenService:Create(sc, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
        end

        local swipeHost = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, LayoutOrder = own and 1 or 2, Parent = row,
        })

        local avatar = New("ImageLabel", {
            Size = UDim2.new(0, 28, 0, 28), LayoutOrder = own and 2 or 1,
            Bind = { BackgroundColor3 = "other" }, Parent = row,
        }, { corner(14) })
        loadAvatar(tonumber(m.uid) or 0, avatar)

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
            New("TextLabel", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                Text = clipUtf8(tostring(m.reply.text or ""), 55),
                TextSize = 10, Font = Enum.Font.Gotham,
                TextTransparency = 0.3, Bind = { TextColor3 = "text" },
                LayoutOrder = 2, Parent = qFrame,
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
            if isOwner(m.user) then
                who = who .. '  <font color="#FFD700">Owner</font>'
            end
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

        -- Sticker message?
        local frames, interval = parseSticker(m.text)
        if frames then
            local stickerImg = New("ImageLabel", {
                Size = UDim2.new(0, 96, 0, 96),
                BackgroundTransparency = 1,
                Image = frames[1],
                ScaleType = Enum.ScaleType.Fit,
                LayoutOrder = 2,
                Parent = bubble,
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
            label(textColor({ Text = esc(m.text), TextSize = 13, Font = Enum.Font.GothamMedium, LayoutOrder = 2 }))
        end

        if m.reacts and type(m.reacts) == "table" then
            local rtxt = {}
            for emoji, cnt in pairs(m.reacts) do
                if type(cnt) == "number" and cnt > 0 then
                    rtxt[#rtxt + 1] = emoji .. (cnt > 1 and (" " .. cnt) or "")
                end
            end
            if #rtxt > 0 then
                label(textColor({
                    Text = table.concat(rtxt, "  "),
                    TextSize = 12, Font = Enum.Font.Gotham, LayoutOrder = 8,
                    TextTransparency = 0.15,
                }))
            end
        end

        local timeRow = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, LayoutOrder = 9, Parent = bubble,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 7),
            }),
        })

        ui.time = New("TextLabel", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundTransparency = 1, Text = timeStr,
            TextSize = 10, Font = Enum.Font.Gotham, TextTransparency = 0.4,
            Bind = { TextColor3 = own and "ownText" or "text" }, Parent = timeRow,
        })
        setStatus(ui, state or "sent")

        local function actBtn(txt, cb)
            local b = New("TextButton", {
                Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1, Text = txt,
                TextSize = 10, Font = Enum.Font.Gotham, TextTransparency = 0.4,
                Bind = { TextColor3 = own and "ownText" or "text" }, Parent = timeRow,
            })
            b.MouseButton1Click:Connect(cb)
            return b
        end

        actBtn("Copy", function()
            local txt = tostring(m.text or "")
            pcall(function()
                if setclipboard then setclipboard(txt)
                elseif toclipboard then toclipboard(txt) end
            end)
            pcall(function()
                if WindUI and WindUI.Notify then
                    WindUI:Notify({ Title = "Copied", Content = "Message copied", Duration = 1.3, Icon = "copy" })
                end
            end)
        end)
        actBtn("Reply", function() setReply(m) end)
        actBtn("React", function()
            local emoji = REACT_SET[math.random(1, #REACT_SET)]
            task.spawn(function()
                local path = "chat/" .. S.room .. "/messages/" .. tostring(m._k) .. "/reacts/" .. HttpService:UrlEncode(emoji)
                call("PUT", urlFor(path), encode(1))
            end)
        end)
        if ME_IS_OWNER and m._k then
            actBtn("Del", function()
                deleteMessage(m._k)
                pcall(function() row:Destroy() end)
            end)
        end

        -- swipe to reply
        local dragStart, dragging = nil, false
        bubble.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = inp.Position
            end
        end)
        bubble.InputChanged:Connect(function(inp)
            if not dragging or not dragStart then return end
            if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
                local delta = inp.Position.X - dragStart.X
                local dir = own and -1 or 1
                local offset = math.clamp(delta * dir, 0, 64)
                bubble.Position = UDim2.new(0, offset * dir, 0, 0)
            end
        end)
        local function endDrag(inp)
            if not dragging then return end
            dragging = false
            local delta = inp and (inp.Position.X - (dragStart and dragStart.X or 0)) or 0
            local dir = own and -1 or 1
            if delta * dir > 42 then setReply(m) end
            TweenService:Create(bubble, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0, 0)
            }):Play()
            dragStart = nil
        end
        bubble.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                endDrag(inp)
            end
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
        if not TOAST or os.clock() - S.lastToast < 2.5 then return end
        S.lastToast = os.clock()
        local body = m.t == "invite" and "sent an invite" or clipUtf8(tostring(m.text or ""), 70)
        if parseSticker(tostring(m.text or "")) then body = "sent a sticker" end
        pcall(function()
            WindUI:Notify({ Title = cleanName(m.dn or m.user or "Chat"), Content = body, Duration = 2.6, Icon = "message-circle" })
        end)
    end

    local function registerUnread(m)
        if viewing() then return end
        local k = tostring(m.uid)
        S.unread[k] = (S.unread[k] or 0) + 1
        updateBadge()
        toast(m)
        if mentionsMe(m.text) then
            showSideNotif(m)
        end
    end

    local function processMessage(m, isHistory)
        local key = m._k
        if S.seen[key] then return end
        S.seen[key] = true
        if not S.lastKey or key > S.lastKey then S.lastKey = key end
        if m.deleted then return end
        if m.cid and S.pending[m.cid] then
            setStatus(S.pending[m.cid], "sent")
            S.pending[m.cid] = nil
            return
        end
        local own = tonumber(m.uid) == ME_ID
        render(m, own, "sent")
        if not isHistory and not own then
            registerUnread(m)
        end
    end

    local function pollOnce()
        local gen, room = S.gen, S.room
        local q = S.lastKey and ("orderBy=%22%24key%22&startAt=%22" .. S.lastKey .. "%22")
            or ("orderBy=%22%24key%22&limitToLast=" .. HISTORY)
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
        if Settings.HideMyName and ME_IS_OWNER then
            displayName = "Hidden"
        end
        local cid = HttpService:GenerateGUID(false)
        local payload = {
            uid = ME_ID, user = ME_NAME, dn = displayName,
            text = text, cid = cid, t = "msg",
            ts = { [".sv"] = "timestamp" },
            script = SCRIPT_NAME,
            scriptImg = SCRIPT_IMG,
        }
        if ME_IS_OWNER and cfg.OwnerTag then
            payload.ownerTag = tostring(cfg.OwnerTag)
        end
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
                    Duration = 2,
                    Icon = "clock",
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
        if ok then
            S.lastInvite = os.clock()
            input.Text = ""
        end
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
    end

    local function updatePrivHeader()
        if S.kind ~= "private" then
            privHeader.Text = ""
            return
        end
        local name = S.privateName or "Player"
        local typingTxt = S.typing and "  |  typing..." or ""
        privHeader.Text = "Chatting with " .. cleanName(name) .. typingTxt
    end

    function setRoom(kind, targetUid, targetName)
        if kind ~= "global" and kind ~= "private" then return end
        if kind == "private" and not targetUid and not S.privateTarget then
            openPrivatePanel()
            relayout()
            return
        end
        if kind == S.kind and S.loaded and (kind ~= "private" or targetUid == S.privateTarget) then return end
        S.kind = kind
        if kind == "private" then
            S.privateTarget = targetUid or S.privateTarget
            S.privateName = targetName or S.privateName or "Player"
            S.room = roomName("private", S.privateTarget)
        else
            S.privateTarget = nil
            S.privateName = nil
            S.room = roomName("global")
        end
        S.gen = S.gen + 1
        S.lastKey, S.loaded, S.seen, S.pending, S.shown = nil, false, {}, {}, 0
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        emptyLbl.Text = "Loading..."
        emptyLbl.Visible = true
        clearReply()
        updatePrivHeader()
        refreshPills()
        relayout()
        task.spawn(function()
            pollOnce()
            emptyLbl.Text = "No messages yet"
            emptyLbl.Visible = S.shown == 0
        end)
    end

    pillBtns.global.MouseButton1Click:Connect(function()
        S.panelOpen = false
        setRoom("global")
    end)
    pillBtns.private.MouseButton1Click:Connect(function()
        setRoom("private")
    end)
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

    task.spawn(function()
        task.wait(1.3)
        if Settings.FirstAskDone then return end
        if not Window or not Window.Dialog then return end
        Settings.FirstAskDone = true
        getgenv().NeoChatSettings = Settings
        pcall(function()
            Window:Dialog({
                Title = "Chat notifications",
                Content = "Show a small transparent card on the right only when someone mentions you?",
                Buttons = {
                    { Title = "Yes", Variant = "Primary", Callback = function()
                        Settings.SideNotifs = true
                        getgenv().NeoChatSettings = Settings
                    end },
                    { Title = "No", Variant = "Tertiary", Callback = function()
                        Settings.SideNotifs = false
                        getgenv().NeoChatSettings = Settings
                    end },
                },
            })
        end)
    end)

    canvas:GetPropertyChangedSignal("Visible"):Connect(function()
        if viewing() then clearUnread(); scrollDown() end
    end)

    task.spawn(function()
        while S.alive and not Window.Destroyed do
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
        title.Text = "Chat | " .. roomLabel .. "  " .. status
    end

    task.spawn(function()
        while S.alive and not Window.Destroyed do
            call("PUT", urlFor("presence/" .. ME_ID), encode({ n = ME_NAME, t = { [".sv"] = "timestamp" } }))
            local ok, body = call("GET", urlFor("presence"))
            if ok then
                local data = decode(body)
                if type(data) == "table" then
                    local newest, n = 0, 0
                    for _, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and v.t > newest then newest = v.t end
                    end
                    for _, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and newest - v.t < 60000 then n = n + 1 end
                    end
                    S.online = math.max(n, 1)
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
                                if now - v.t < 4000 then someoneTyping = true break end
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
        while S.alive and not Window.Destroyed do
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
        Settings.SideNotifs = on == true
        getgenv().NeoChatSettings = Settings
    end
    function Chat:SetMentions(on)
        Settings.MentionsEnabled = on == true
        getgenv().NeoChatSettings = Settings
    end
    function Chat:GetSettings() return Settings end
    function Chat:IsOwner() return ME_IS_OWNER end
    function Chat:Destroy()
        S.alive = false
        pcall(function() root:Destroy() end)
        pcall(function() badge:Destroy() end)
        pcall(function() if sideGui then sideGui:Destroy() end end)
    end

    getgenv().NeoChatController = Chat
    getgenv().NeoChatSettings = Settings
    return Chat
end

function NeoChat.AddChat(a, b, c)
    local Window, cfg
    if a == NeoChat then Window, cfg = b, c else Window, cfg = a, b end
    cfg = cfg or {}
    local WindUI = cfg.WindUI or (getgenv and getgenv().WindUI) or _G.WindUI
    assert(WindUI, "NeoChat: WindUI not found (pass cfg.WindUI)")
    return NeoChat.Init(WindUI, Window, cfg)
end

return NeoChat
