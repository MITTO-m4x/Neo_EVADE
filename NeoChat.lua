--[[
    NeoChat v1.0  —  Firebase chat tab for WindUI  (Neo Hyper x Yin Yang)

    Usage (after you create the Window):

        local NeoChat = loadstring(game:HttpGet("<raw github url of NeoChat.lua>"))()
        local Chat = NeoChat:AddChat(Window)          -- that's it (creates the "Chat" tab)
        -- or with options / an existing tab:
        -- NeoChat:AddChat(Window, { Tab = Tabs.Chat, DatabaseURL = "https://...firebasedatabase.app" })

        -- advanced (same thing):  NeoChat.Init(WindUI, Window, {
            DatabaseURL = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app",
            -- all optional:
            Title = "Chat", Icon = "message-circle",
            BadgeMode = "senders",      -- "senders" = number of people who wrote | "messages" = number of messages
            Notifications = true,       -- toast when a message arrives while you're on another tab
            PollInterval = 1.6, History = 40, MaxLength = 200, Cooldown = 1.2,
        })

    Controller: Chat:Send(text) / Chat:SendInvite() / Chat:SetRoom("global"|"server") / Chat:Destroy()
]]

local NeoChat = {
    DatabaseURL = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app",
}

local cr = cloneref or function(x) return x end
local Players          = cr(game:GetService("Players"))
local HttpService      = cr(game:GetService("HttpService"))
local TweenService     = cr(game:GetService("TweenService"))
local TeleportService  = cr(game:GetService("TeleportService"))
local MarketplaceService = cr(game:GetService("MarketplaceService"))
local LocalPlayer      = Players.LocalPlayer

------------------------------------------------------------------ HTTP layer
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
    if ok then return r end
    return nil
end
local function encode(t) return HttpService:JSONEncode(t) end

------------------------------------------------------------------ helpers
local function esc(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    return s
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function clipUtf8(s, max)
    local len = utf8.len(s)
    if not len then return s:sub(1, max) end
    if len <= max then return s end
    return s:sub(1, (utf8.offset(s, max + 1) or (#s + 1)) - 1)
end

local EMOJI = {
    { "😀", "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😍 🥰 😘 😋 😜 🤪 😎 🤩 🥳 😏 😒 😞 😔 😢 😭 😤 😡 🤬 🤯 😳 🥵 🥶 😱 🤔 🤫 🙄 😴 🤤 😈 💀 👻 🤡" },
    { "👍", "👍 👎 👏 🙌 🙏 💪 🤝 ✌️ 🤞 🤟 🤘 👌 👋 🤙 ☝️ 👊 ✊ 🫡 🫶 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 💖 💯 🔥 ✨ ⭐ 🌟 ⚡ 💥 🎉 🎊" },
    { "🎮", "🎮 🕹️ 👾 🏆 🥇 🎯 ⚔️ 🛡️ 🏹 💣 🔫 🚀 🛸 🏎️ ✈️ 🏠 🧱 🔨 💎 👑 💰 🎁 🎲 🧩 🪄" },
    { "🐶", "🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐸 🐵 🐧 🐦 🦄 🐝 🦋 🐢 🐍 🐙 🦈 🐬 🐳 🌹 🌸 🌈 ☀️ 🌙 ❄️" },
    { "🍔", "🍔 🍟 🍕 🌭 🍿 🍩 🍪 🎂 🍫 🍭 🍎 🍌 🍉 🍓 🥤 ☕ 🍺 🥪 🌮 🍣" },
}

------------------------------------------------------------------ main
function NeoChat.Init(WindUI, Window, cfg)
    cfg = cfg or {}
    cfg.DatabaseURL = cfg.DatabaseURL or NeoChat.DatabaseURL
    assert(type(cfg.DatabaseURL) == "string", "NeoChat: DatabaseURL is required")
    assert(Window, "NeoChat: Window is required")

    local BASE       = (cfg.DatabaseURL:gsub("/+$", ""))
    local MAXLEN     = cfg.MaxLength or 200
    local POLL       = cfg.PollInterval or 1.6
    local HISTORY    = cfg.History or 40
    local COOLDOWN   = cfg.Cooldown or 1.2
    local BADGE_MODE = cfg.BadgeMode or "senders"
    local TOAST      = cfg.Notifications ~= false
    local ME_ID, ME_NAME, ME_DN = LocalPlayer.UserId, LocalPlayer.Name, LocalPlayer.DisplayName

    local S = {
        alive = true, kind = "global", room = nil, gen = 0, lastKey = nil, loaded = false,
        seen = {}, pending = {}, unread = {}, lastSend = 0, lastToast = 0, fails = 0,
        online = 1, emojiOpen = false, shown = 0, lastBadge = 0,
    }

    local function roomName(kind)
        if kind == "server" then
            local id = game.JobId ~= "" and game.JobId or "studio"
            return "srv_" .. (id:gsub("[^%w_%-]", "_"))
        end
        return (tostring(cfg.Room or "global"):gsub("[%.%$#%[%]/]", "_"))
    end
    S.room = roomName("global")

    local function urlFor(path, query)
        return BASE .. "/" .. path .. ".json" .. (query and ("?" .. query) or "")
    end

    -------------------------------------------------------------- UI builders (theme aware)
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
        return New("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
            PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) })
    end

    -------------------------------------------------------------- tab + page
    local tab = cfg.Tab or Window:Tab({ Title = cfg.Title or "Chat", Icon = cfg.Icon or "message-circle" })
    local canvas = tab.UIElements.ContainerFrameCanvas
    local sideBtn = tab.UIElements.Main

    -- WindUI shows an "empty tab" page until something is added to its list; add a dummy child, then hide the list.
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

    local HEADER, INPUT_H, EMOJI_H = 40, 56, 140
    local root = New("Frame", { Name = "NeoChat", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = canvas })

    -- header
    local title = New("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0.55, 0, 0, HEADER), BackgroundTransparency = 1,
        RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold, TextSize = 15,
        Text = "Chat", Bind = { TextColor3 = "text" }, Parent = root,
    })
    local pills = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0, HEADER / 2), Size = UDim2.new(0, 160, 0, 26),
        Bind = { BackgroundColor3 = "card" }, Parent = root,
    }, { corner(13) })
    local pillBtns = {}
    local function makePill(kind, text, x)
        local b = New("TextButton", {
            Position = UDim2.new(x, 2, 0, 2), Size = UDim2.new(0.5, -4, 1, -4), Text = text, TextSize = 12,
            Font = Enum.Font.GothamMedium, BackgroundTransparency = 1, AutoButtonColor = false,
            Bind = { TextColor3 = "text" }, Parent = pills,
        }, { corner(11) })
        pillBtns[kind] = b
        return b
    end
    makePill("global", "🌍 Global", 0)
    makePill("server", "🖥 Server", 0.5)

    -- messages
    local scroll = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, HEADER), Size = UDim2.new(1, 0, 1, -(HEADER + INPUT_H)),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = root,
    }, {
        New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
        pad(10, 6, 10, 6),
    })
    local emptyLbl = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.8, 0, 0, 40),
        BackgroundTransparency = 1, Text = "No messages yet — say hi 👋", TextSize = 14, Font = Enum.Font.Gotham,
        TextTransparency = 0.4, Bind = { TextColor3 = "text" },
        Visible = false, Parent = root,
    })

    -- emoji panel
    local emojiPanel = New("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -(INPUT_H)), Size = UDim2.new(1, -16, 0, EMOJI_H - 8),
        Bind = { BackgroundColor3 = "card" },
        Visible = false, ZIndex = 5, Parent = root,
    }, { corner(12) })
    local catBar = New("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 6, Parent = emojiPanel }, {
        New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
        pad(6, 2, 6, 0),
    })
    local grid = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 6, Parent = emojiPanel,
    }, {
        New("UIGridLayout", { CellSize = UDim2.new(0, 34, 0, 34), CellPadding = UDim2.new(0, 4, 0, 4) }),
        pad(8, 4, 8, 4),
    })

    -- input row
    local inputRow = New("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -8), Size = UDim2.new(1, -16, 0, 40),
        Bind = { BackgroundColor3 = "card" }, Parent = root,
    }, { corner(12) })
    local function iconBtn(text, x)
        return New("TextButton", {
            Position = UDim2.new(0, x, 0, 4), Size = UDim2.new(0, 32, 0, 32), Text = text, TextSize = 18,
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, Parent = inputRow,
        })
    end
    local emojiBtn  = iconBtn("😊", 4)
    local inviteBtn = iconBtn("📨", 38)
    local sendBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 60, 0, 32),
        Text = "Send", TextSize = 13, Font = Enum.Font.GothamBold,
        Bind = { BackgroundColor3 = "own", TextColor3 = "ownText" }, Parent = inputRow,
    }, { corner(9) })
    local input = New("TextBox", {
        Position = UDim2.new(0, 76, 0, 0), Size = UDim2.new(1, -76 - 68, 1, 0), BackgroundTransparency = 1,
        PlaceholderText = "اكتب رسالة…  Type a message…", Text = "", ClearTextOnFocus = false, TextSize = 14,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        Bind = { TextColor3 = "text", PlaceholderColor3 = "placeholder" }, Parent = inputRow,
    })

    local function relayout()
        local bottom = INPUT_H + (S.emojiOpen and EMOJI_H or 0)
        scroll.Size = UDim2.new(1, 0, 1, -(HEADER + bottom))
        emojiPanel.Visible = S.emojiOpen
    end

    -------------------------------------------------------------- unread badge on the sidebar tab
    local badge = New("Frame", {
        Name = "NeoBadge", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0),
        Visible = false, ZIndex = 30, Parent = sideBtn,
    }, {
        corner(9),
        New("UISizeConstraint", { MinSize = Vector2.new(18, 18) }),
        New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.55, Thickness = 1 }),
        pad(5, 0, 5, 0),
    })
    local badgeScale = New("UIScale", { Scale = 1, Parent = badge })
    local badgeLbl = New("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = "0",
        TextColor3 = Color3.new(1, 1, 1), TextSize = 11, Font = Enum.Font.GothamBold, ZIndex = 31, Parent = badge,
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
            badgeScale.Scale = 1.4
            TweenService:Create(badgeScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

    -------------------------------------------------------------- avatars + labels
    local avatarCache = {}
    local function loadAvatar(uid, img)
        if avatarCache[uid] then img.Image = avatarCache[uid]; return end
        task.spawn(function()
            local ok, content = pcall(function()
                return (Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100))
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
        local icon = (state == "pending" and "  🕓") or (state == "failed" and '  <font color="#ff5555">✗ failed</font>') or "  ✓"
        ui.time.Text = ui.timeText .. icon
    end

    local function mentionsMe(text)
        local t = tostring(text or ""):lower()
        return t:find("@" .. ME_NAME:lower(), 1, true) ~= nil or t:find("@" .. ME_DN:lower(), 1, true) ~= nil
    end

    -------------------------------------------------------------- render one message
    local function render(m, own, state)
        emptyLbl.Visible = false
        local nearBottom = isNearBottom()
        order = order + 1
        local ts = tonumber(type(m.ts) == "number" and m.ts or nil)
        local seconds = ts and math.floor(ts / 1000) or os.time()
        local ui = { own = own, timeText = os.date("%H:%M", seconds) }

        local row = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            LayoutOrder = order, Parent = scroll,
        }, {
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = own and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
                VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6),
            }),
        })
        ui.row = row

        local avatar = New("ImageLabel", {
            Size = UDim2.new(0, 30, 0, 30), LayoutOrder = own and 2 or 1,
            Bind = { BackgroundColor3 = "other" },
            Parent = row,
        }, { corner(15) })
        loadAvatar(tonumber(m.uid) or 0, avatar)

        local bubble = New("Frame", {
            Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = own and 1 or 2,
            Bind = { BackgroundColor3 = own and "own" or "other" }, Parent = row,
        }, {
            corner(12), pad(10, 6, 10, 6),
            New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }),
        })
        if not own and mentionsMe(m.text) then
            New("UIStroke", { Color = Color3.fromRGB(255, 196, 0), Thickness = 1.5, Parent = bubble })
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
            local dn = tostring(m.dn or m.user or "?")
            local un = tostring(m.user or "")
            local who = (dn ~= un and un ~= "") and (esc(dn) .. ' <font transparency="0.5">@' .. esc(un) .. "</font>") or esc(dn)
            label({ Text = '<font color="#' .. col .. '">' .. who .. "</font>", TextSize = 12, Font = Enum.Font.GothamBold, LayoutOrder = 1 })
        end

        if m.t == "invite" then
            label(textColor({ Text = "📨 <b>Server invite</b>", TextSize = 14, Font = Enum.Font.GothamMedium, LayoutOrder = 2 }))
            label(textColor({ Text = esc(m.game or "Roblox"), TextSize = 13, Font = Enum.Font.Gotham, LayoutOrder = 3 }))
            label(textColor({ Text = "👥 " .. tostring(m.pc or "?") .. "/" .. tostring(m.mx or "?"), TextSize = 12,
                Font = Enum.Font.Gotham, TextTransparency = 0.3, LayoutOrder = 4 }))
            if m.text and m.text ~= "" and m.text ~= "📨" then
                label(textColor({ Text = esc(m.text), TextSize = 14, Font = Enum.Font.GothamMedium, LayoutOrder = 5 }))
            end
            local here = tostring(m.job) == game.JobId
            local expired = (os.time() - seconds) > 900
            local btn = New("TextButton", {
                Size = UDim2.new(0, 130, 0, 28), LayoutOrder = 6, TextSize = 13, Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1), Parent = bubble,
                Text = here and "You're here ✓" or (expired and "Expired" or "Join ▶"),
                BackgroundColor3 = (here or expired) and Color3.fromRGB(80, 80, 84) or Color3.fromRGB(51, 199, 89),
            }, { corner(8) })
            if here or expired then
                btn.Active = false; btn.AutoButtonColor = false
            else
                btn.MouseButton1Click:Connect(function()
                    btn.Text = "Joining…"
                    local ok = pcall(function()
                        TeleportService:TeleportToPlaceInstance(tonumber(m.place), tostring(m.job), LocalPlayer)
                    end)
                    if not ok then btn.Text = "Failed ✗" end
                end)
            end
        else
            label(textColor({ Text = esc(m.text), TextSize = 14, Font = Enum.Font.GothamMedium, LayoutOrder = 2 }))
        end

        ui.time = label(textColor({ Text = ui.timeText, TextSize = 10, Font = Enum.Font.Gotham, TextTransparency = 0.35,
            LayoutOrder = 9 }))
        setStatus(ui, state or "sent")

        S.shown = S.shown + 1
        if S.shown > 150 then
            for _, c in ipairs(scroll:GetChildren()) do
                if c:IsA("Frame") then c:Destroy(); S.shown = S.shown - 1; break end
            end
        end
        if own or nearBottom then scrollDown() end
        return ui
    end

    -------------------------------------------------------------- toast + unread
    local function toast(m)
        if not TOAST or os.clock() - S.lastToast < 2.5 then return end
        S.lastToast = os.clock()
        local body = m.t == "invite" and "📨 sent you a server invite" or clipUtf8(tostring(m.text or ""), 70)
        pcall(function()
            WindUI:Notify({ Title = tostring(m.dn or m.user or "Chat"), Content = body, Duration = 3, Icon = "message-circle" })
        end)
    end
    local function registerUnread(m)
        if viewing() then return end
        local k = tostring(m.uid)
        S.unread[k] = (S.unread[k] or 0) + 1
        updateBadge()
        toast(m)
    end

    -------------------------------------------------------------- receive (polling)
    local function processMessage(m, isHistory)
        local key = m._k
        if S.seen[key] then return end
        S.seen[key] = true
        if not S.lastKey or key > S.lastKey then S.lastKey = key end

        if m.cid and S.pending[m.cid] then          -- our own optimistic bubble
            setStatus(S.pending[m.cid], "sent")
            S.pending[m.cid] = nil
            return
        end
        local own = tonumber(m.uid) == ME_ID
        render(m, own, "sent")
        if not isHistory and not own then registerUnread(m) end
    end

    local function pollOnce()
        local gen, room = S.gen, S.room
        local q = S.lastKey and ("orderBy=%22%24key%22&startAt=%22" .. S.lastKey .. "%22")
            or ("orderBy=%22%24key%22&limitToLast=" .. HISTORY)
        local ok, body = call("GET", urlFor("chat/" .. room .. "/messages", q))
        if not ok then return false end
        if gen ~= S.gen then return true end         -- room changed while waiting
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

    -------------------------------------------------------------- send
    local function send(text, extra)
        text = clipUtf8(trim(text), MAXLEN)
        if text == "" and not extra then return false end
        if os.clock() - S.lastSend < COOLDOWN then
            pcall(function() WindUI:Notify({ Title = "Slow down", Content = "Wait a second between messages", Duration = 2 }) end)
            return false
        end
        S.lastSend = os.clock()

        local cid = HttpService:GenerateGUID(false)
        local payload = { uid = ME_ID, user = ME_NAME, dn = ME_DN, text = text, cid = cid, t = "msg", ts = { [".sv"] = "timestamp" } }
        for k, v in pairs(extra or {}) do payload[k] = v end
        if payload.text == "" then payload.text = "📨" end

        local gen = S.gen
        local ui = render(payload, true, "pending")
        S.pending[cid] = ui
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

    local function sendInvite()
        local info
        pcall(function() info = MarketplaceService:GetProductInfo(game.PlaceId) end)
        local ok = send(input.Text, {
            t = "invite", place = game.PlaceId, job = game.JobId, game = info and info.Name or "Roblox",
            pc = #Players:GetPlayers(), mx = Players.MaxPlayers,
        })
        if ok then input.Text = "" end
    end

    local function doSend()
        if send(input.Text) then input.Text = "" end
    end

    -------------------------------------------------------------- rooms
    local function refreshPills()
        for kind, b in pairs(pillBtns) do
            local active = kind == S.kind
            b.BackgroundTransparency = active and 0 or 1
            b.BackgroundColor3 = P.own
            b.TextColor3 = active and P.ownText or P.text
        end
    end
    local function setRoom(kind)
        if kind ~= "global" and kind ~= "server" then return end
        if kind == S.kind and S.loaded then return end
        S.kind, S.room = kind, roomName(kind)
        S.gen = S.gen + 1
        S.lastKey, S.loaded, S.seen, S.pending, S.shown = nil, false, {}, {}, 0
        for _, c in ipairs(scroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        emptyLbl.Text = "Loading…"; emptyLbl.Visible = true
        refreshPills()
        task.spawn(function()
            pollOnce()
            emptyLbl.Text = "No messages yet — say hi 👋"
            emptyLbl.Visible = S.shown == 0
        end)
    end
    pillBtns.global.MouseButton1Click:Connect(function() setRoom("global") end)
    pillBtns.server.MouseButton1Click:Connect(function() setRoom("server") end)
    refreshPills()
    onTheme[#onTheme + 1] = refreshPills

    -------------------------------------------------------------- emoji panel wiring
    local catBtns = {}
    local function showCategory(idx)
        for i, b in ipairs(catBtns) do b.BackgroundTransparency = (i == idx) and 0.7 or 1 end
        for _, c in ipairs(grid:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        for e in EMOJI[idx][2]:gmatch("%S+") do
            local b = New("TextButton", {
                Text = e, TextSize = 22, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                ZIndex = 7, Parent = grid,
            })
            b.MouseButton1Click:Connect(function() input.Text = input.Text .. e end)
        end
    end
    for i, cat in ipairs(EMOJI) do
        local b = New("TextButton", {
            Size = UDim2.new(0, 30, 0, 26), Text = cat[1], TextSize = 16, Font = Enum.Font.Gotham, LayoutOrder = i,
            Bind = { BackgroundColor3 = "text", TextColor3 = "text" }, BackgroundTransparency = 1,
            ZIndex = 7, Parent = catBar,
        }, { corner(7) })
        catBtns[i] = b
        b.MouseButton1Click:Connect(function() showCategory(i) end)
    end
    showCategory(1)
    emojiBtn.MouseButton1Click:Connect(function() S.emojiOpen = not S.emojiOpen; relayout() end)
    inviteBtn.MouseButton1Click:Connect(sendInvite)
    sendBtn.MouseButton1Click:Connect(doSend)
    input.FocusLost:Connect(function(enter)
        if enter then doSend(); task.defer(function() input:CaptureFocus() end) end
    end)

    -------------------------------------------------------------- unread clearing
    canvas:GetPropertyChangedSignal("Visible"):Connect(function()
        if viewing() then clearUnread(); scrollDown() end
    end)

    -------------------------------------------------------------- loops
    task.spawn(function()                                   -- messages
        while S.alive and not Window.Destroyed do
            local ok = pollOnce()
            S.fails = ok and 0 or math.min(S.fails + 1, 5)
            if viewing() then clearUnread() end
            task.wait(POLL * (1 + S.fails))
        end
    end)

    local function renderTitle()
        local status = S.fails > 0 and '<font color="#ff5555">● offline</font>'
            or ('<font color="#33C759">●</font> <font transparency="0.4">' .. S.online .. " online</font>")
        title.Text = "💬 Chat   " .. status
    end
    task.spawn(function()                                   -- presence / online counter
        while S.alive and not Window.Destroyed do
            call("PUT", urlFor("presence/" .. ME_ID), encode({ n = ME_NAME, t = { [".sv"] = "timestamp" } }))
            local ok, body = call("GET", urlFor("presence"))
            if ok then
                local data = decode(body)
                if type(data) == "table" then
                    local newest = 0
                    for _, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and v.t > newest then newest = v.t end
                    end
                    local n = 0
                    for _, v in pairs(data) do
                        if type(v) == "table" and tonumber(v.t) and newest - v.t < 60000 then n = n + 1 end
                    end
                    S.online = math.max(n, 1)
                end
            end
            renderTitle()
            for _ = 1, 20 do                                -- 20s, but refresh the header status every second
                if not S.alive then return end
                task.wait(1)
                renderTitle()
            end
        end
    end)

    task.spawn(function()                                   -- follow theme changes
        local last
        while S.alive and not Window.Destroyed do
            local ok, name = pcall(function() return WindUI:GetCurrentTheme() end)
            if ok and name ~= last then last = name; applyTheme() end
            task.wait(0.7)
        end
    end)

    relayout()

    -------------------------------------------------------------- controller
    local Chat = { Tab = tab }
    function Chat:Send(text) return send(text) end
    function Chat:SendInvite() return sendInvite() end
    function Chat:SetRoom(kind) return setRoom(kind) end
    function Chat:Unread() return unreadCount() end
    function Chat:Destroy()
        S.alive = false
        pcall(function() root:Destroy() end)
        pcall(function() badge:Destroy() end)
    end
    return Chat
end

-- Simple entry point:  NeoChat:AddChat(Window, { Tab = optionalExistingTab })
function NeoChat.AddChat(a, b, c)
    local Window, cfg
    if a == NeoChat then Window, cfg = b, c else Window, cfg = a, b end
    cfg = cfg or {}
    local WindUI = cfg.WindUI or (getgenv and getgenv().WindUI) or _G.WindUI
    assert(WindUI, "NeoChat: WindUI not found (pass cfg.WindUI)")
    return NeoChat.Init(WindUI, Window, cfg)
end

return NeoChat
