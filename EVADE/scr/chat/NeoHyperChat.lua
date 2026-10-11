-- NeoHyper_ChatGlobal_v1.lua (basado en YY_ChatGlobal_v13)
-- STANDALONE: GUI Tilt + Chat Global de Neo Hyper (misma GUI que el chat de Yin Yang).
-- Adaptado a partir de la pestaña Chat de Yi y del enfoque YY_TiltPrototype.
-- No depende de la libreria UI completa de Yi.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local TextService = game:GetService("TextService")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    NAME = "NeoHyper_ChatGlobal_Tilt",
    TILT_DEG = 10,
    DISTANCE_PC = 9.15,
    DISTANCE_MOBILE = 7.55,
    CANVAS_PC = Vector2.new(860, 593), -- v9: antes 1000x690; misma proporcion, todo ~16% mas grande
    CANVAS_MOBILE = Vector2.new(600, 711), -- v9: antes 700x830
    MAX_MESSAGES = 100,
    MAX_CHAR = 500,
    POLL_RATE = 10,
    FB_POLL_RATE = 3, -- antes 8: mas bajo para ver reacciones, borrados y privados rapido (mas requests)
    WATCH_RATE = 4, -- revisa global/inbox/privados en segundo plano para badges y avisos
}

-- v8: paleta oscura estilo Instagram/WhatsApp
local THEME = {
    BG = Color3.fromRGB(0, 0, 0),
    PANEL = Color3.fromRGB(18, 18, 18),
    PANEL2 = Color3.fromRGB(38, 38, 38),
    ACC = Color3.fromRGB(245, 245, 245),
    ACC2 = Color3.fromRGB(54, 54, 54),
    TXT = Color3.fromRGB(245, 245, 245),
    DIM = Color3.fromRGB(168, 168, 168),
    GOOD = Color3.fromRGB(88, 200, 110),
    DANGER = Color3.fromRGB(237, 73, 86),
}

local function mk(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    mk("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, obj)
end

local function stroke(obj, color, thickness, transparency)
    mk("UIStroke", {
        Color = color or THEME.ACC,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, obj)
end

-- Tablas compartidas: UI guarda widgets nuevos y Chat el estado/funciones nuevas
-- (agrupado para no acercarse al limite de 200 locals).
local UI = {}
local Chat = {}

-- v8: iconos que paso Nick (blancos; se tiñen con ImageColor3)
UI.ICON = {
    back = "rbxassetid://74796775741491", search = "rbxassetid://83258052038009",
    bell = "rbxassetid://89295019910511", bellOff = "rbxassetid://99202807344897",
    more = "rbxassetid://114906210968666", pin = "rbxassetid://86392028702497",
    pencil = "rbxassetid://104485628186988", crown = "rbxassetid://93104462877422",
    tick = "rbxassetid://134652733924299", alert = "rbxassetid://92336184304336",
    reply = "rbxassetid://140466985063077", copy = "rbxassetid://95657322010780",
    trash = "rbxassetid://133795804974827", dm = "rbxassetid://140466985063077",
    server = "rbxassetid://70960808418506", emoji = "rbxassetid://123610893406648",
    people = "rbxassetid://90819416372909",
    group = "rbxassetid://115075072418394",       -- foto del grupo (Chat Global) - Neo Hyper
    globalBg = "rbxassetid://99450347524598",     -- fondo del Chat Global - Neo Hyper
    ownerAvatar = "rbxassetid://74189877924111",  -- avatar de v_orc y n_oqv
    mousozaAvatar = "rbxassetid://127423980218258", -- v10: avatar de mousoza
}
UI.C = {
    blue = Color3.fromRGB(0, 149, 246),
    ownA = Color3.fromRGB(122, 64, 255),   -- burbuja propia: degradado violeta -> azul (Instagram)
    ownB = Color3.fromRGB(0, 132, 255),
    other = Color3.fromRGB(38, 38, 38),
    line = Color3.fromRGB(38, 38, 38),
    online = Color3.fromRGB(88, 200, 110),
    gold = Color3.fromRGB(255, 196, 0),
}

UI.icon = function(parent, id, size, color, props)
    local img = mk("ImageLabel", {
        Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Image = id,
        ImageColor3 = color or THEME.TXT, ScaleType = Enum.ScaleType.Fit,
    }, parent)
    for k, v in pairs(props or {}) do img[k] = v end
    return img
end

-- Boton redondo con icono centrado
UI.iconButton = function(parent, id, size, iconSize, props)
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(size, size), BackgroundColor3 = THEME.PANEL2,
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
    }, parent)
    corner(b, math.floor(size / 2))
    for k, v in pairs(props or {}) do b[k] = v end
    local img = UI.icon(b, id, iconSize or math.floor(size * 0.58), THEME.TXT, {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        ZIndex = b.ZIndex + 1,
    })
    return b, img
end

-- Anillo degradado tipo "historia" de Instagram alrededor de una foto
UI.storyRing = function(target, thickness)
    local s = mk("UIStroke", {Thickness = thickness or 2.5, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, target)
    mk("UIGradient", {
        Rotation = 45,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(254, 218, 117)),
            ColorSequenceKeypoint.new(0.35, Color3.fromRGB(250, 126, 30)),
            ColorSequenceKeypoint.new(0.65, Color3.fromRGB(214, 41, 118)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 47, 191)),
        }),
    }, s)
    return s
end

local function getRequest()
    return (syn and syn.request)
        or (http and http.request)
        or fluxus_request
        or http_request
        or request
        or function(opts)
            local method = string.upper(opts.Method or "GET")
            local ok, result = pcall(function()
                if method == "POST" then
                    return HttpService:PostAsync(opts.Url, opts.Body or "", Enum.HttpContentType.ApplicationJson)
                elseif method ~= "GET" then -- PUT, DELETE, PATCH
                    return HttpService:RequestAsync({
                        Url = opts.Url,
                        Method = method,
                        Headers = opts.Headers or { ["Content-Type"] = "application/json" },
                        Body = opts.Body or "",
                    }).Body
                else
                    return HttpService:GetAsync(opts.Url)
                end
            end)
            return {
                Success = ok,
                Body = ok and tostring(result or "") or "",
                StatusCode = ok and 200 or 0,
            }
        end
end

local request = getRequest()

-- Limpieza silenciosa de una ejecucion anterior.
pcall(function() RunService:UnbindFromRenderStep(CONFIG.NAME) end)
pcall(function()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local old = pg:FindFirstChild(CONFIG.NAME .. "_UI")
        if old then old:Destroy() end
    end
    local cam = workspace.CurrentCamera
    if cam then
        local oldPart = cam:FindFirstChild(CONFIG.NAME)
        if oldPart then oldPart:Destroy() end
    end
end)

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ScreenGui = mk("ScreenGui", {
    Name = CONFIG.NAME .. "_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 2147483000,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
}, PlayerGui)

local Camera = workspace.CurrentCamera
while not Camera do task.wait() Camera = workspace.CurrentCamera end

local Part = mk("Part", {
    Name = CONFIG.NAME,
    Anchored = true,
    CanCollide = false,
    CanTouch = false,
    CanQuery = false,
    Transparency = 1,
    CastShadow = false,
    Size = Vector3.new(6, 4, 0.05),
}, Camera)

local Surface = mk("SurfaceGui", {
    Name = CONFIG.NAME,
    Face = Enum.NormalId.Front,
    SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
    CanvasSize = CONFIG.CANVAS_PC,
    AlwaysOnTop = true,
    LightInfluence = 0,
    ResetOnSpawn = false,
    ClipsDescendants = true,
    Adornee = Part,
}, PlayerGui)

local Root = mk("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundColor3 = THEME.BG,
    BorderSizePixel = 0,
    Active = true,
}, Surface)
corner(Root, 22)
stroke(Root, UI.C.line, 1.5, 0) -- v8: borde fino en vez del blanco grueso
Root.ClipsDescendants = true

-- v8: fondo del Chat Global (solo visible dentro del global)
UI.ChatBg = mk("ImageLabel", {
    Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58),
    BackgroundTransparency = 1, Image = UI.ICON.globalBg, ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.1, Visible = false, ZIndex = 1, -- v9 FIX: con ZIndex 0 quedaba debajo del fondo negro de Root
}, Root)
-- velo oscuro para que las burbujas se lean sobre el fondo
mk("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 1,
}, UI.ChatBg)

-- ===== Header =====
local Header = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 58),
    BackgroundColor3 = THEME.BG,
    BorderSizePixel = 0,
    Active = true,
}, Root)
corner(Header, 22)
-- tapa las esquinas redondeadas de abajo + linea divisoria (como Instagram)
mk("Frame", {Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = THEME.BG, BorderSizePixel = 0}, Header)
mk("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = UI.C.line, BorderSizePixel = 0, ZIndex = 2}, Header)

UI.Title = mk("TextLabel", {
    Size = UDim2.new(1, -235, 0, 24),
    Position = UDim2.fromOffset(19, 8),
    BackgroundTransparency = 1,
    Text = "CHAT GLOBAL",
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamBold,
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, Header)

UI.Subtitle = mk("TextLabel", {
    Size = UDim2.new(1, -235, 0, 16),
    Position = UDim2.fromOffset(20, 33),
    BackgroundTransparency = 1,
    Text = "Neo Hyper • comunidad global",
    TextColor3 = THEME.DIM,
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 3,
}, Header)

local OnlinePill = mk("Frame", {
    Size = UDim2.fromOffset(92, 32),
    Position = UDim2.new(1, -140, 0, 13),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    ZIndex = 3,
}, Header)
corner(OnlinePill, 16)
UI.icon(OnlinePill, UI.ICON.people, 18, THEME.TXT, {Position = UDim2.fromOffset(10, 7), ZIndex = 4})

local OnlineDot = mk("Frame", {
    Size = UDim2.fromOffset(8, 8),
    Position = UDim2.fromOffset(23, 20),
    BackgroundColor3 = THEME.GOOD,
    BorderSizePixel = 0,
    ZIndex = 5,
}, OnlinePill)
corner(OnlineDot, 99)
stroke(OnlineDot, THEME.PANEL2, 1.5, 0)

local OnlineLabel = mk("TextLabel", {
    Size = UDim2.new(1, -38, 1, 0),
    Position = UDim2.fromOffset(34, 0),
    BackgroundTransparency = 1,
    Text = "0",
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 4,
}, OnlinePill)

local CloseButton = mk("TextButton", {
    Size = UDim2.fromOffset(32, 32),
    Position = UDim2.new(1, -42, 0, 13),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    ZIndex = 3,
}, Header)
corner(CloseButton, 16)

-- ===== Messages =====
local MessageScroll = mk("ScrollingFrame", {
    Size = UDim2.new(1, -28, 1, -164),
    Position = UDim2.fromOffset(14, 70),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = THEME.DIM,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
    Active = true,
}, Root)

local MessageLayout = mk("UIListLayout", {
    Padding = UDim.new(0, 4), -- v8: mas juntos, se agrupan por remitente como Instagram
    SortOrder = Enum.SortOrder.LayoutOrder,
}, MessageScroll)
mk("UIPadding", {
    PaddingLeft = UDim.new(0, 3),
    PaddingRight = UDim.new(0, 7),
    PaddingTop = UDim.new(0, 3),
    PaddingBottom = UDim.new(0, 6),
}, MessageScroll)

local EmptyLabel = mk("TextLabel", {
    Size = UDim2.new(1, -40, 0, 60),
    Position = UDim2.fromOffset(20, 245),
    BackgroundTransparency = 1,
    Text = "Conectando al Chat Global...",
    TextColor3 = THEME.DIM,
    Font = Enum.Font.GothamMedium,
    TextSize = 15,
    TextWrapped = true,
}, Root)

-- ===== Temporary local message actions (until backend support exists) =====
local messageRows = {}
local localReactions = {}
local localDeletedKeys = {}
local pendingReply = nil
local reactionPickerTargetKey = nil
local actionTarget = nil
local actionToken = 0
local renderMessage
local showStickerTab
local MessageBox
local StickerPanel

local ReactionBar = mk("Frame", {
    Size = UDim2.fromOffset(315, 50),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 120,
}, Root)
corner(ReactionBar, 25)
stroke(ReactionBar, UI.C.line, 1, 0)

local ReactionBarLayout = mk("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 3),
}, ReactionBar)

-- v8: fila del menu estilo Instagram (icono a la izquierda + texto grande)
local function makeActionButton(parent, text, width, iconId)
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(width, 46),
        BackgroundColor3 = THEME.PANEL2,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamMedium,
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true,
        ZIndex = 121,
    }, parent)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 52)}, b)
    if iconId then
        UI.icon(b, iconId, 22, THEME.TXT, {
            Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -36, 0.5, 0), ZIndex = 122,
        })
    end
    return b
end

local QuickReactionEmojis = {"❤️", "😂", "😮", "😢", "🙏", "👍"}
local QuickReactionButtons = {}
for _, emoji in ipairs(QuickReactionEmojis) do
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(40, 40),
        BackgroundTransparency = 1,
        Text = emoji,
        TextColor3 = Color3.fromRGB(255,255,255),
        Font = Enum.Font.Gotham,
        TextSize = 27,
        ZIndex = 121,
    }, ReactionBar)
    QuickReactionButtons[#QuickReactionButtons+1] = {button=b, emoji=emoji}
end
local ReactionMoreButton = mk("TextButton", {
    Size = UDim2.fromOffset(40, 40),
    BackgroundColor3 = THEME.PANEL2,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "+",
    TextColor3 = THEME.DIM,
    Font = Enum.Font.Gotham,
    TextSize = 34,
    ZIndex = 121,
}, ReactionBar)
corner(ReactionMoreButton, 20)

-- v8: velo oscuro detras del menu (tocar afuera lo cierra), como Instagram
UI.MenuDim = mk("TextButton", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
    BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 110,
}, Root)

local ActionMenu = mk("Frame", {
    Size = UDim2.fromOffset(230, 142),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 120,
}, Root)
corner(ActionMenu, 16)
-- cabecera con fecha y hora del mensaje
UI.MenuDate = mk("TextLabel", {
    Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 4), BackgroundTransparency = 1,
    Text = "", TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 121,
}, ActionMenu)
local ReplyAction = makeActionButton(ActionMenu, "Responder", 230, UI.ICON.reply)
ReplyAction.Position = UDim2.fromOffset(0, 38)
local CopyAction = makeActionButton(ActionMenu, "Copiar", 230, UI.ICON.copy)
CopyAction.Position = UDim2.fromOffset(0, 84)
local DeleteAction = makeActionButton(ActionMenu, "Eliminar", 230, UI.ICON.trash)
DeleteAction.Position = UDim2.fromOffset(0, 130)
DeleteAction.TextColor3 = THEME.DANGER
DeleteAction.Icon.ImageColor3 = THEME.DANGER
UI.PrivateAction = makeActionButton(ActionMenu, "Mensaje privado", 230, UI.ICON.dm)
UI.PinAction = makeActionButton(ActionMenu, "Fijar", 230, UI.ICON.pin)
UI.EditAction = makeActionButton(ActionMenu, "Editar", 230, UI.ICON.pencil) -- v12

-- v11: barra de respuesta estilo Instagram ("Respondiendo a X" + mensaje + X), sin iconos
local ReplyBanner = mk("Frame", {
    Size = UDim2.new(1, -28, 0, 60),
    Position = UDim2.new(0, 14, 1, -130),
    BackgroundColor3 = Color3.fromRGB(26, 26, 30),
    BackgroundTransparency = 0.04,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 65,
}, Root)
corner(ReplyBanner, 18)
stroke(ReplyBanner, UI.C.line, 1, 0)
UI.ReplyTitle = mk("TextLabel", {
    Size = UDim2.new(1, -70, 0, 20),
    Position = UDim2.fromOffset(18, 9),
    BackgroundTransparency = 1,
    Text = "",
    RichText = true,
    TextColor3 = THEME.DIM,
    Font = Enum.Font.GothamMedium,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 66,
}, ReplyBanner)
local ReplyLabel = mk("TextLabel", {
    Size = UDim2.new(1, -70, 0, 22),
    Position = UDim2.fromOffset(18, 30),
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamMedium,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 66,
}, ReplyBanner)
local ReplyCancel = mk("TextButton", {
    Size = UDim2.fromOffset(40, 40),
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    BackgroundTransparency = 1,
    Text = "×",
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamMedium,
    TextSize = 30,
    ZIndex = 66,
}, ReplyBanner)

local function hideMessageActions()
    actionTarget = nil
    actionToken += 1
    ReactionBar.Visible = false
    ActionMenu.Visible = false
    UI.MenuDim.Visible = false
end

-- "20 JUN, 7:35 P. M." como Instagram
UI.MONTHS = {"ENE", "FEB", "MAR", "ABR", "MAY", "JUN", "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"}
UI.fullDate = function(ts)
    local t = os.date("*t", tonumber(ts) or os.time())
    local h = t.hour % 12
    if h == 0 then h = 12 end
    return string.format("%d %s, %d:%02d %s", t.day, UI.MONTHS[t.month], h, t.min, t.hour < 12 and "A. M." or "P. M.")
end

local function showMessageActions(meta)
    if not meta or not meta.row or not meta.row.Parent then return end
    actionTarget = meta
    actionToken += 1
    local myToken = actionToken
    local rootPos = Root.AbsolutePosition
    local rowPos = meta.row.AbsolutePosition
    local rowSize = meta.row.AbsoluteSize
    local rootSize = Root.AbsoluteSize
    local isMine = tostring(meta.uid) == tostring(LocalPlayer.UserId)
    local canOwner = Chat.meIsOwner == true and meta.fbKey ~= nil
    DeleteAction.Visible = isMine or canOwner
    DeleteAction.Text = canOwner and "Eliminar para todos" or "Eliminar para mí"
    UI.PrivateAction.Visible = (not isMine) and Chat.kind == "global"
    UI.PinAction.Visible = canOwner
    UI.EditAction.Visible = isMine and meta.fbKey ~= nil and not meta.isSticker and meta.t ~= "invite" and not localDeletedKeys[meta.key]
    UI.MenuDate.Text = UI.fullDate(meta.ts)
    local menuH = 38
    for _, b in ipairs({ReplyAction, UI.EditAction, CopyAction, UI.PrivateAction, UI.PinAction, DeleteAction}) do
        if b.Visible then
            b.Position = UDim2.fromOffset(0, menuH)
            menuH += 46
        end
    end
    menuH += 6
    ActionMenu.Size = UDim2.fromOffset(230, menuH)
    -- Barra de reacciones arriba del mensaje; menu debajo, alineado al lado del remitente.
    local relX = rowPos.X - rootPos.X
    local relY = rowPos.Y - rootPos.Y
    local barX = isMine and (relX + rowSize.X - 315) or (relX + 50)
    local barY = math.clamp(relY - 58, 64, math.max(64, rootSize.Y - menuH - 70))
    barX = math.clamp(barX, 8, math.max(8, rootSize.X - 323))
    ReactionBar.Position = UDim2.fromOffset(barX, barY)
    local menuX = isMine and (relX + rowSize.X - 230) or (relX + 50)
    menuX = math.clamp(menuX, 8, math.max(8, rootSize.X - 238))
    local menuY = math.clamp(barY + 58, 64, math.max(64, rootSize.Y - menuH - 8))
    ActionMenu.Position = UDim2.fromOffset(menuX, menuY)
    UI.MenuDim.Visible = true
    ReactionBar.Visible = true
    ActionMenu.Visible = true
    task.delay(15, function()
        if actionToken == myToken then hideMessageActions() end
    end)
end

local function reactionText(meta)
    if not meta then return "" end
    local counts = localReactions[meta.key]
    if type(counts) ~= "table" then return "" end
    local parts = {}
    for _, emoji in ipairs(QuickReactionEmojis) do
        local n = tonumber(counts[emoji]) or 0
        if n > 0 then parts[#parts+1] = emoji .. " " .. tostring(n) end
    end
    for emoji, n in pairs(counts) do
        if n > 0 and not table.find(QuickReactionEmojis, emoji) then parts[#parts+1] = emoji .. " " .. tostring(n) end
    end
    return table.concat(parts, "  ")
end

local function refreshReactionChips(meta)
    if not meta or not meta.reactionWrap then return end
    local text = reactionText(meta)
    meta.reactionWrap.Text = text
    meta.reactionWrap.Visible = text ~= ""
end

local function addLocalReaction(meta, emoji)
    if not meta or not emoji or emoji == "" then return end
    local counts = localReactions[meta.key]
    if type(counts) ~= "table" then counts = {}; localReactions[meta.key] = counts end
    counts[emoji] = (tonumber(counts[emoji]) or 0) + 1
    refreshReactionChips(meta)
    if Chat.sendReaction then Chat.sendReaction(meta, emoji) end
    hideMessageActions()
end

local function copyMessage(meta)
    if not meta then return end
    local copyText = tostring(meta.text or "")
    local stickerBody = copyText:match("^%[%[STICKER:(.-)%]%]$")
    if stickerBody then copyText = stickerBody:match("([^|]+)") or stickerBody end
    if type(setclipboard) == "function" then
        pcall(function() setclipboard(copyText) end)
    end
    hideMessageActions()
end

local function setReplyTarget(meta)
    if not meta then return end
    local preview = tostring(meta.text or "")
    if preview:match("^%[%[STICKER:") then preview = "Sticker" end
    preview = preview:gsub("%s+", " "):sub(1, 70)
    -- Mismo formato que NeoChat: {uid,user,dn,text,key}; "name" se mantiene para el render local.
    local quoted = tostring(meta.text or "")
    if quoted:match("^%[%[STICKER:") then quoted = "[Sticker]" elseif meta.t == "invite" then quoted = "Invitación al servidor" end
    pendingReply = {
        uid = meta.uid, user = tostring(meta.name or "Unknown"), dn = tostring(meta.dn or meta.name or "Unknown"),
        text = Chat.clip and Chat.clip(quoted, 80) or quoted:sub(1, 80), key = meta.fbKey,
        name = tostring(meta.dn or meta.name or "Unknown"),
    }
    -- v11: "Respondiendo a <b>usuario</b>" + vista previa del mensaje (como Instagram)
    UI.ReplyTitle.Text = "Respondiendo a <b>" .. Chat.esc(tostring(meta.name or "Unknown")) .. "</b>"
    ReplyLabel.Text = (meta.isSticker and "Sticker") or (meta.t == "invite" and "Invitación al servidor") or preview
    ReplyBanner.Visible = true
    if Chat.refreshTypingPill then Chat.refreshTypingPill() Chat.refreshNewPill() end
    hideMessageActions()
    -- v12: en tactil abre la barra 2D (antes enfocaba el cuadro 3D -> pantalla blanca al responder)
    task.defer(function() Chat.focusBox(MessageBox, function() if Chat.sendText then Chat.sendText() end end) end)
end

local function cancelReply()
    pendingReply = nil
    Chat.editing = nil -- v12: cancelar tambien sale del modo edicion
    ReplyBanner.Visible = false
    if Chat.refreshTypingPill then Chat.refreshTypingPill() Chat.refreshNewPill() end
end

local function deleteLocalMessage(meta)
    if not meta then return end
    -- Owners: borrado real en Firebase (desaparece para todos).
    if Chat.meIsOwner and meta.fbKey then
        hideMessageActions()
        Chat.ownerDelete(meta)
        return
    end
    if tostring(meta.uid) ~= tostring(LocalPlayer.UserId) then return end
    localDeletedKeys[meta.key] = true
    localReactions[meta.key] = nil
    if meta.row and meta.row.Parent then meta.row:Destroy() end
    -- Antes usaba renderedKeys, que se declara mas abajo (aqui era nil y daba error).
    Chat.renderedKeys[meta.key] = nil
    hideMessageActions()
    task.defer(function() renderMessage(meta.name, meta.uid, meta.text, meta.ts, meta.id, nil, {order = meta.order, dn = meta.dn, fbKey = meta.fbKey}) end)
end

local function bindLongPress(row, meta)
    row.Active = false
    local LONG_PRESS_TIME = 1 -- v11: antes 2 segundos
    local MOVE_CANCEL_DISTANCE = 12
    local pressed = false
    local pressToken = 0
    local pressStart = nil
    local swipeStart, swipeLast = nil, nil -- deslizar de costado = responder
    local pressAt, lastTapAt = 0, 0 -- v12: doble toque = me gusta
    row.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pressAt = os.clock()
        pressed = true
        pressStart = Vector2.new(input.Position.X, input.Position.Y)
        swipeStart, swipeLast = pressStart, pressStart
        pressToken += 1
        local myToken = pressToken
        task.delay(LONG_PRESS_TIME, function()
            if pressed and pressToken == myToken and row.Parent then
                showMessageActions(meta)
            end
        end)
    end)
    row.InputChanged:Connect(function(input)
        if swipeStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            swipeLast = Vector2.new(input.Position.X, input.Position.Y)
        end
        if not pressed or not pressStart then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local now = Vector2.new(input.Position.X, input.Position.Y)
        if (now - pressStart).Magnitude > MOVE_CANCEL_DISTANCE then
            pressed = false
            pressStart = nil
            pressToken += 1
        end
    end)
    row.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressed = false
            pressStart = nil
            pressToken += 1
            if swipeStart and swipeLast then
                local d = swipeLast - swipeStart
                if math.abs(d.X) > 60 and math.abs(d.Y) < 30 and row.Parent then
                    setReplyTarget(meta)
                elseif d.Magnitude < 12 and os.clock() - pressAt < 0.3 then
                    -- toque corto: si es el segundo en menos de 0.35 s -> me gusta
                    if os.clock() - lastTapAt < 0.35 then
                        lastTapAt = 0
                        if Chat.doubleTapLike then Chat.doubleTapLike(meta) end
                    else
                        lastTapAt = os.clock()
                    end
                end
            end
            swipeStart, swipeLast = nil, nil
        end
    end)
end

for _, item in ipairs(QuickReactionButtons) do
    item.button.MouseButton1Click:Connect(function()
        if actionTarget then addLocalReaction(actionTarget, item.emoji) end
    end)
end
ReactionMoreButton.MouseButton1Click:Connect(function()
    if not actionTarget then return end
    reactionPickerTargetKey = actionTarget.key
    ReactionBar.Visible = false
    ActionMenu.Visible = false
    StickerPanel.Visible = true
    showStickerTab(false, true)
end)
ReplyAction.MouseButton1Click:Connect(function() setReplyTarget(actionTarget) end)
CopyAction.MouseButton1Click:Connect(function() copyMessage(actionTarget) end)
DeleteAction.MouseButton1Click:Connect(function() deleteLocalMessage(actionTarget) end)
UI.PrivateAction.MouseButton1Click:Connect(function()
    local m = actionTarget
    hideMessageActions()
    if m then Chat.openChat("private", m.uid, m.dn or m.name, m.name) end
end)
UI.EditAction.MouseButton1Click:Connect(function()
    local m = actionTarget
    hideMessageActions()
    if m then Chat.startEdit(m) end
end)
UI.PinAction.MouseButton1Click:Connect(function()
    local m = actionTarget
    hideMessageActions()
    if m then Chat.pinMessage(m) end
end)
ReplyCancel.MouseButton1Click:Connect(cancelReply)
UI.MenuDim.MouseButton1Click:Connect(hideMessageActions)

-- ===== Composer =====
-- v8: composer tipo Instagram (una sola "pildora" flotante)
local Composer = mk("Frame", {
    Size = UDim2.new(1, -28, 0, 52),
    Position = UDim2.new(0, 14, 1, -64),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    ZIndex = 5,
}, Root)
corner(Composer, 26)

UI.EmojiButton = UI.iconButton(Composer, UI.ICON.emoji, 40, 24, {
    Position = UDim2.fromOffset(6, 6), BackgroundTransparency = 0, BackgroundColor3 = UI.C.blue, ZIndex = 6,
})

local StickerButton = mk("ImageButton", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(1, -134, 0, 9),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Image = "rbxassetid://70677501354748",
    ImageColor3 = Color3.fromRGB(255,255,255),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 6,
}, Composer)

MessageBox = mk("TextBox", {
    Size = UDim2.new(1, -196, 0, 42),
    Position = UDim2.fromOffset(54, 5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Mensaje...",
    PlaceholderColor3 = THEME.DIM,
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamMedium,
    TextSize = 16,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    MultiLine = false, -- v10: igual que la libreria; multilinea abre el editor blanco de pantalla completa en Android
    ZIndex = 6,
}, Composer)
mk("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 11),
    PaddingBottom = UDim.new(0, 7),
}, MessageBox)

local SendButton = mk("ImageButton", {
    Size = UDim2.fromOffset(40, 40),
    Position = UDim2.new(1, -46, 0, 6),
    BackgroundColor3 = UI.C.blue,
    BorderSizePixel = 0,
    Image = "rbxassetid://132362297660069",
    ImageColor3 = Color3.fromRGB(255,255,255),
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 6,
}, Composer)
corner(SendButton, 20)
mk("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)}, SendButton)

-- Contador de caracteres: solo aparece cerca del limite
local CharLabel = mk("TextLabel", {
    Size = UDim2.fromOffset(70, 16),
    Position = UDim2.new(1, -84, 0, -20),
    BackgroundTransparency = 1,
    Text = "0/500",
    TextColor3 = THEME.DIM,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    Visible = false,
    ZIndex = 6,
}, Composer)

-- ===== Sticker panel =====
StickerPanel = mk("Frame", {
    Size = UDim2.new(1, -28, 0, 270),
    Position = UDim2.new(0, 14, 1, -344),
    BackgroundColor3 = THEME.PANEL,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 50,
}, Root)
corner(StickerPanel, 18)
stroke(StickerPanel, UI.C.line, 1, 0)

local StickerHeader = mk("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 51,
}, StickerPanel)

-- v8: pestañas tipo "chip"; la activa se pinta blanca con texto oscuro (antes blanco sobre blanco)
local function makeTab(text, x, width)
    local b = mk("TextButton", {
        Size = UDim2.fromOffset(width, 28),
        Position = UDim2.fromOffset(x, 6),
        BackgroundColor3 = THEME.PANEL2,
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        ZIndex = 52,
    }, StickerHeader)
    corner(b, 14)
    return b
end

local TabStickers = makeTab("STICKERS", 8, 82)
local TabMine = makeTab("MIS STICKERS", 96, 98)
local TabEmoji = makeTab("EMOJIS", 202, 74)
UI.TabFavs = makeTab("RECIENTES", 284, 84)

local PanelClose = mk("TextButton", {
    Size = UDim2.fromOffset(27, 27),
    Position = UDim2.new(1, -35, 0, 6),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    Text = "×",
    TextColor3 = THEME.DIM,
    Font = Enum.Font.GothamBold,
    TextSize = 18,
    ZIndex = 52,
}, StickerHeader)
corner(PanelClose, 7)

-- v8 FIX scroll: antes el CanvasSize se calculaba a mano con el panel oculto (quedaba en 0 y no
-- se podia deslizar). Ahora el canvas crece solo con el contenido. Los clones (Mis stickers,
-- Emojis, Recientes) heredan estas propiedades.
local StickerGrid = mk("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -48),
    Position = UDim2.fromOffset(8, 42),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = THEME.DIM,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ScrollingEnabled = true,
    Active = true,
    ZIndex = 51,
}, StickerPanel)
local StickerLayout = mk("UIGridLayout", {
    CellSize = UDim2.fromOffset(68, 68),
    CellPadding = UDim2.fromOffset(7, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, StickerGrid)
mk("UIPadding", {PaddingTop=UDim.new(0,3), PaddingLeft=UDim.new(0,3)}, StickerGrid)

local MineGrid = StickerGrid:Clone()
MineGrid.Name = "MineGrid"
MineGrid.Parent = StickerPanel
MineGrid.Visible = false
MineGrid:ClearAllChildren()
local MineLayout = mk("UIGridLayout", {
    CellSize = UDim2.fromOffset(68, 68),
    CellPadding = UDim2.fromOffset(7, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, MineGrid)
mk("UIPadding", {PaddingTop=UDim.new(0,3), PaddingLeft=UDim.new(0,3)}, MineGrid)

local EmojiGrid = StickerGrid:Clone()
EmojiGrid.Name = "EmojiGrid"
EmojiGrid.Parent = StickerPanel
EmojiGrid.Visible = false
EmojiGrid:ClearAllChildren()
local EmojiLayout = mk("UIGridLayout", {
    CellSize = UDim2.fromOffset(48, 48),
    CellPadding = UDim2.fromOffset(4, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, EmojiGrid)
mk("UIPadding", {PaddingTop=UDim.new(0,3), PaddingLeft=UDim.new(0,3)}, EmojiGrid)

-- Stickers usados recientemente (favoritos, maximo 8) — como NeoChat.
UI.FavGrid = StickerGrid:Clone()
UI.FavGrid.Name = "FavGrid"
UI.FavGrid.Parent = StickerPanel
UI.FavGrid.Visible = false
UI.FavGrid:ClearAllChildren()
UI.FavLayout = mk("UIGridLayout", {
    CellSize = UDim2.fromOffset(68, 68),
    CellPadding = UDim2.fromOffset(7, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, UI.FavGrid)
mk("UIPadding", {PaddingTop=UDim.new(0,3), PaddingLeft=UDim.new(0,3)}, UI.FavGrid)

local AddStickerInput = mk("TextBox", {
    Size = UDim2.new(1, -84, 0, 28),
    Position = UDim2.new(0, 8, 1, -36),
    BackgroundColor3 = THEME.PANEL2,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "ID o rbxassetid://...",
    PlaceholderColor3 = THEME.DIM,
    TextColor3 = THEME.TXT,
    Font = Enum.Font.GothamMedium,
    TextSize = 11,
    Visible = false,
    ZIndex = 55,
}, StickerPanel)
corner(AddStickerInput, 7)

local ConfirmAdd = mk("TextButton", {
    Size = UDim2.fromOffset(68, 28),
    Position = UDim2.new(1, -76, 1, -36),
    BackgroundColor3 = UI.C.blue,
    BorderSizePixel = 0,
    Text = "AGREGAR",
    TextColor3 = Color3.fromRGB(255,255,255),
    Font = Enum.Font.GothamBlack,
    TextSize = 10,
    Visible = false,
    ZIndex = 55,
}, StickerPanel)
corner(ConfirmAdd, 7)

-- ===== Sticker data: mismo repositorio usado por Yi =====
local STICKERS_URL = "https://raw.githubusercontent.com/Sephtis32/Yin-stickers/refs/heads/main/YinYang_Stickers.lua"
local StickerPalettes = {}
local StickerOrder = nil

local FALLBACK_STICKERS = {
    {"rbxassetid://135857695171095", "Sonrisa"},
    {"rbxassetid://138363247925206", "Llorar"},
    {"rbxassetid://76164124882568", "Amor"},
    {"rbxassetid://76164124882568", "Corazon"},
    {"rbxassetid://133861773375312", "Emoji"},
    {"rbxassetid://109165098870367", "Risa"},
    {"rbxassetid://89213081637073", "Sorpresa"},
    {"rbxassetid://80817302481160", "Triste"},
    {"rbxassetid://72815688632249", "Enojado"},
    {"rbxassetid://72602706593283", "Wink"},
    {"rbxassetid://129224642026377", "Cool"},
}

for _, item in ipairs(FALLBACK_STICKERS) do
    StickerPalettes[item[2]] = {Image=item[1], LabelES=item[2], LabelEN=item[2]}
end

local function normalizeFrames(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, id in ipairs(list) do
        if type(id) == "string" and id:match("^rbxassetid://%d+$") and #out < 3 then
            out[#out+1] = id
        end
    end
    return #out >= 2 and out or nil
end

local function intervalValue(v)
    local n = tonumber(v)
    if not n then return 0.5 end
    return math.clamp(n, 0.08, 5)
end

local function stickerParse(text)
    local body = tostring(text or ""):match("^%[%[STICKER:(.-)%]%]$")
    if not body then return nil end
    local frames, interval = {}, nil
    for token in body:gmatch("[^|]+") do
        if token:match("^rbxassetid://%d+$") then
            if #frames < 3 then frames[#frames+1] = token end
        elseif tonumber(token) and not interval then
            interval = intervalValue(token)
        else
            return nil
        end
    end
    if #frames < 1 then return nil end
    if #frames == 1 then return frames, nil end
    return frames, interval or 0.5
end

local function stickerBuild(assetId, frames, interval)
    local list = normalizeFrames(frames)
    if not list then return "[[STICKER:" .. tostring(assetId) .. "]]" end
    return "[[STICKER:" .. table.concat(list, "|") .. "|" .. tostring(intervalValue(interval)) .. "]]"
end

local function animateSticker(label, frames, interval)
    local list = normalizeFrames(frames)
    if not label or not label.Parent then return end
    if not list then
        label.Image = (type(frames) == "string" and frames) or label.Image
        return
    end
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync(list) end)
        local index = 1
        label.Image = list[index]
        while label.Parent do
            task.wait(intervalValue(interval))
            if not label.Parent then break end
            index = index % #list + 1
            label.Image = list[index]
        end
    end)
end

local function loadStickerRepo()
    local raw
    local ok, result = pcall(function()
        return request({Url=STICKERS_URL, Method="GET"})
    end)
    if ok and result and result.Success ~= false and type(result.Body) == "string" and #result.Body > 20 then
        raw = result.Body
    end
    if not raw then
        local ok2, body = pcall(function() return game:HttpGet(STICKERS_URL, true) end)
        if ok2 and type(body) == "string" and #body > 20 then raw = body end
    end
    if not raw or type(loadstring) ~= "function" then
        warn("[YY Chat] No se pudo descargar el repo de stickers (o falta loadstring); quedan los de respaldo")
        return
    end
    local parsed, data = pcall(function() return loadstring(raw)() end)
    if not parsed or type(data) ~= "table" or type(data.Stickers) ~= "table" then
        warn("[YY Chat] El repo de stickers no se pudo leer: " .. tostring(data))
        return
    end
    for name, sticker in pairs(data.Stickers) do
        if type(sticker) == "table" and type(sticker.Image) == "string" then
            StickerPalettes[name] = {
                Image = sticker.Image,
                Frames = normalizeFrames(sticker.Frames),
                Interval = sticker.Interval,
                LabelES = sticker.LabelES or name,
                LabelEN = sticker.LabelEN or name,
            }
        end
    end
    if type(data.Order) == "table" then StickerOrder = data.Order end
    -- v8 FIX: antes la grilla solo se rellenaba a los 1.5 s; si la descarga tardaba mas,
    -- quedaban los 11 de respaldo. Ahora se rellena cuando termina de verdad.
    Chat.stickersLoaded = true
    if Chat.onStickersLoaded then pcall(Chat.onStickersLoaded) end
end

task.spawn(loadStickerRepo)

-- ===== Data / backend (solo Firebase; el Railway se quito) =====
local FIREBASE = "https://neohyper-9a843-default-rtdb.europe-west1.firebasedatabase.app/"
local FIREBASE_ROOM = "global"
local SCRIPT_IMG = "rbxassetid://115075072418394"
local CID_PREFIX = "neo_"
local OWNER_ID = 9549448191

local chatMessages = {}
local renderedKeys = {}
local firebaseSeen = {}
local firebaseInitialLoad = true
local contentSeen = {}
local sending = false

-- Owners: tu UserId + los mismos nombres que NeoChat + mousoza.
Chat.OWNER_NAMES = { v_orc = true, n_oqv = true, mousoza = true }
Chat.isOwner = function(uid, user)
    if tonumber(uid) == OWNER_ID then return true end
    return Chat.OWNER_NAMES[string.lower(tostring(user or ""))] == true
end
Chat.meIsOwner = Chat.isOwner(LocalPlayer.UserId, LocalPlayer.Name)

-- Estado de la app tipo WhatsApp
Chat.renderedKeys = renderedKeys
Chat.view = "home"          -- "home" (lista de chats) o "chat"
Chat.kind = "global"        -- "global" o "private"
Chat.room = FIREBASE_ROOM   -- "global" o "dm_<uidMenor>_<uidMayor>" (mismo formato que NeoChat)
Chat.roomGen = 0
Chat.byFbKey = {}           -- clave Firebase -> meta del mensaje dibujado
Chat.pending = {}           -- cid -> meta (mensajes propios esperando confirmacion)
Chat.unread = {}            -- sala -> no leidos
Chat.previews = {}          -- sala -> ultimo mensaje {name,text,ts,uid}
Chat.lastSeenKey = {}       -- sala -> ultima clave vista (global)
Chat.notified = {}          -- claves ya contadas como no leidas
Chat.checkQueue = {}        -- salas privadas a revisar ya
Chat.reactHold = {}         -- meta.key -> os.clock() hasta el que se ignora el conteo del servidor
Chat.onlineMap = {}
Chat.onlineCount = 0
Chat.searchOpen = false
Chat.searchQuery = ""
Chat.lastInvite = -999
Chat.lastTypingPush = 0
Chat.inboxOk = true
Chat.order = 0
Chat.SETTINGS_FILE = "NeoHyper_ChatSettings.json"
Chat.settings = {
    SideNotifs = true, MentionsEnabled = true,
    MutedRooms = {}, StickerFavs = {}, RecentDMs = {}, DMLastSeen = {}, HiddenDMs = {},
}

Chat.loadSettings = function()
    if readfile and isfile then
        pcall(function()
            if isfile(Chat.SETTINGS_FILE) then
                local data = HttpService:JSONDecode(readfile(Chat.SETTINGS_FILE))
                if type(data) == "table" then
                    for k, v in pairs(data) do Chat.settings[k] = v end
                end
            end
        end)
    end
    for _, k in ipairs({"MutedRooms", "StickerFavs", "RecentDMs", "DMLastSeen", "HiddenDMs"}) do
        if type(Chat.settings[k]) ~= "table" then Chat.settings[k] = {} end
    end
end

Chat.saveSettings = function()
    if not writefile then return end
    pcall(function() writefile(Chat.SETTINGS_FILE, HttpService:JSONEncode(Chat.settings)) end)
end

Chat.loadSettings()

-- Llamada a Firebase REST. Devuelve ok, datos decodificados, codigo HTTP.
Chat.fbCall = function(method, path, body, query)
    local ok, res = pcall(function()
        return request({
            Url = FIREBASE .. path .. ".json" .. (query and ("?" .. query) or ""),
            Method = method,
            Headers = {["Content-Type"] = "application/json"},
            Body = body ~= nil and HttpService:JSONEncode(body) or nil,
        })
    end)
    if not ok or type(res) ~= "table" then return false, nil, 0 end
    local code = tonumber(res.StatusCode or res.Status) or 0
    local success = (res.Success == true) or (code >= 200 and code < 300)
    if code >= 400 then success = false end
    local data = nil
    if type(res.Body) == "string" and res.Body ~= "" then
        local okD, d = pcall(HttpService.JSONDecode, HttpService, res.Body)
        if okD then data = d end
    end
    return success, data, code
end

Chat.dmRoom = function(uid)
    local a, b = tonumber(LocalPlayer.UserId), tonumber(uid)
    if not b then return nil end
    if a > b then a, b = b, a end
    return "dm_" .. a .. "_" .. b
end

Chat.nextOrder = function()
    Chat.order += 1
    return Chat.order
end

Chat.clip = function(s, n)
    s = tostring(s or "")
    local okLen, len = pcall(utf8.len, s)
    if not okLen or not len then return s:sub(1, n) end
    if len <= n then return s end
    local cut = utf8.offset(s, n + 1)
    return (cut and s:sub(1, cut - 1) or s) .. "…"
end

Chat.esc = function(s)
    return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local open = true
local generation = 0
local REPLY_STORE_FILE = "NeoHyper_ChatReplies.json"
local storedReplies = {}

local function loadStoredReplies()
    if not (readfile and isfile) then return end
    pcall(function()
        if isfile(REPLY_STORE_FILE) then
            local data = HttpService:JSONDecode(readfile(REPLY_STORE_FILE))
            if type(data) == "table" then storedReplies = data end
        end
    end)
end

local function saveStoredReplies()
    if not writefile then return end
    pcall(function() writefile(REPLY_STORE_FILE, HttpService:JSONEncode(storedReplies)) end)
end

local function rememberReply(text, ts, reply)
    if type(reply) ~= "table" then return end
    storedReplies[#storedReplies + 1] = {
        uid = tostring(LocalPlayer.UserId),
        text = tostring(text or ""),
        ts = tonumber(ts) or os.time(),
        reply = reply,
    }
    while #storedReplies > CONFIG.MAX_MESSAGES do table.remove(storedReplies, 1) end
    saveStoredReplies()
end

local function findStoredReply(uid, text, ts)
    local targetTs = tonumber(ts) or os.time()
    local best, bestDelta
    for i = #storedReplies, 1, -1 do
        local item = storedReplies[i]
        if type(item) == "table" and tostring(item.uid) == tostring(uid) and tostring(item.text) == tostring(text) then
            local delta = math.abs((tonumber(item.ts) or 0) - targetTs)
            if delta <= 15 and (not bestDelta or delta < bestDelta) then
                best, bestDelta = item.reply, delta
            end
        end
    end
    return best
end

loadStoredReplies()

-- Roblox acepta estos tamaños para AvatarHeadShot; 80x80 produce el error de la captura.
local function avatar(userId)
    return ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(tonumber(userId) or 0)
end

local function scrollBottom()
    task.defer(function()
        pcall(function()
            MessageScroll.CanvasPosition = Vector2.new(0, math.max(0, MessageLayout.AbsoluteContentSize.Y + 1000))
        end)
    end)
end

local function sourceKey(name, uid, text, ts, id)
    if id then return "id:" .. tostring(id) end
    return table.concat({tostring(name), tostring(uid), tostring(text), tostring(math.floor((tonumber(ts) or os.time()) / 3))}, "|")
end

local function addHistory(name, uid, text, ts, id, reply)
    chatMessages[#chatMessages+1] = {
        name=tostring(name or "Unknown"), uid=tonumber(uid) or 0,
        text=tostring(text or ""), ts=tonumber(ts) or os.time(), id=id, reply=reply,
    }
    while #chatMessages > CONFIG.MAX_MESSAGES do table.remove(chatMessages, 1) end
end

local function playerNameColor(name, uid)
    -- Stable pseudo-random color per player, so their name keeps the same color.
    local seedText = tostring(uid or "") .. ":" .. tostring(name or "Unknown")
    local hash = 0
    for i = 1, #seedText do
        hash = (hash * 31 + string.byte(seedText, i)) % 2147483647
    end
    local palette = {
        Color3.fromRGB(255, 174, 96),
        Color3.fromRGB(111, 205, 255),
        Color3.fromRGB(255, 135, 166),
        Color3.fromRGB(174, 225, 132),
        Color3.fromRGB(202, 163, 255),
        Color3.fromRGB(255, 218, 112),
        Color3.fromRGB(105, 225, 204),
        Color3.fromRGB(255, 155, 105),
    }
    return palette[(hash % #palette) + 1]
end

-- v10: formato tipo Discord para los mensajes
--   # Titulo grande   ## Titulo   ### Subtitulo   -# texto chico gris
--   **negrita**  *cursiva*  __subrayado__  ~~tachado~~  `codigo`
-- El texto del usuario se escapa primero (no puede inyectar RichText).
Chat.MD_STYLES = {
    h1 = {size = 32, font = Enum.Font.GothamBlack},
    h2 = {size = 26, font = Enum.Font.GothamBlack},
    h3 = {size = 22, font = Enum.Font.GothamBold},
    sub = {size = 14, font = Enum.Font.GothamMedium, color = "#A8A8A8"},
}
Chat.mdInline = function(s)
    s = s:gsub("`([^`]+)`", '<font face="RobotoMono" color="#FFD59A">%1</font>')
    s = s:gsub("%*%*(.-)%*%*", '<font weight="Heavy">%1</font>') -- v11: mas grueso que <b>
    s = s:gsub("__(.-)__", "<u>%1</u>")
    s = s:gsub("~~(.-)~~", "<s>%1</s>")
    s = s:gsub("%*([^%*]+)%*", "<i>%1</i>")
    return s
end
Chat.mdStrip = function(s)
    return (s:gsub("`", ""):gsub("%*", ""):gsub("__", ""):gsub("~~", ""))
end
Chat.mdLine = function(line)
    local hashes, rest = line:match("^(#+)%s*([^#%s].*)$")
    if hashes and #hashes <= 3 then
        return (#hashes == 1 and "h1") or (#hashes == 2 and "h2") or "h3", rest
    end
    local sub = line:match("^%-#%s+(.+)$")
    if sub then return "sub", sub end
    return nil, line
end
-- Devuelve el texto RichText y su ancho/alto medidos linea por linea
Chat.formatMessage = function(text, baseSize, baseFont, maxWidth)
    local rich, w, h = {}, 0, 0
    for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        local style, body = Chat.mdLine(line)
        local st = style and Chat.MD_STYLES[style]
        local size = st and st.size or baseSize
        local font = st and st.font or baseFont
        local inner = Chat.mdInline(Chat.esc(body))
        if st then
            if style ~= "sub" then inner = "<b>" .. inner .. "</b>" end
            inner = '<font size="' .. size .. '"' .. (st.color and (' color="' .. st.color .. '"') or "") .. ">" .. inner .. "</font>"
        end
        rich[#rich + 1] = inner
        local plain = Chat.mdStrip(body)
        if plain == "" then plain = " " end
        local b = TextService:GetTextSize(plain, size, font, Vector2.new(maxWidth, 10000))
        local extra = (font ~= baseFont or inner:find("<b>", 1, true)) and 1.07 or 1
        w = math.max(w, b.X * extra)
        h += b.Y + (st and 4 or 0)
    end
    return table.concat(rich, "\n"), math.ceil(w) + 2, math.ceil(h)
end

-- v11: "+texto" -> mensaje arcoiris animado (tipo Discord/efecto). Devuelve el texto sin el "+".
Chat.rainbowBody = function(text)
    local body = tostring(text or ""):match("^%+%s*(.+)$")
    if body and body:match("%a") then return body end -- exige letras: "+1" queda normal
    return nil
end
Chat.RAINBOW = ColorSequence.new({
    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 70, 70)),
    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 165, 40)),
    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 235, 60)),
    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(70, 230, 110)),
    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(60, 170, 255)),
    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(170, 90, 255)),
    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 70, 70)),
})
-- El degradado se desplaza en bucle; dos copias seguidas del arcoiris hacen que el salto no se note.
Chat.applyRainbow = function(label)
    label.TextColor3 = Color3.new(1, 1, 1)
    local g = mk("UIGradient", {Color = Chat.RAINBOW, Rotation = 0, Offset = Vector2.new(-0.5, 0)}, label)
    task.spawn(function()
        local t = 0
        while label.Parent do
            t = (t + 0.02) % 1
            g.Offset = Vector2.new(t - 0.5, 0)
            task.wait(0.05)
        end
    end)
    return g
end

-- v10: efecto de los owners
-- Nombre blanco tipo neon con el mismo brillo animado que el titulo "Dara hub" de la libreria UI
-- (UIGradient de transparencia 0.65 -> 0 -> 0.65 desplazandose, 1.8 s, Sine, repite con 0.6 s de pausa).
Chat.ownerNameFx = function(label)
    mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.2, Transparency = 0.72, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual}, label)
    local grad = mk("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.65),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 0.65),
        }),
        Offset = Vector2.new(-1, 0),
    }, label)
    pcall(function()
        TweenService:Create(grad,
            TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.6),
            {Offset = Vector2.new(1, 0)}):Play()
    end)
end

-- Corona encima del circulo del avatar, inclinada al costado ("caida")
Chat.addCrown = function(avatarObj, size)
    local c = math.floor(size * 0.55)
    return UI.icon(avatarObj, UI.ICON.crown, c, UI.C.gold, {
        Name = "OwnerCrown", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -math.floor(c * 0.25), 0, math.floor(c * 0.1)),
        Rotation = 32, ZIndex = (avatarObj.ZIndex or 1) + 2,
    })
end

renderMessage = function(name, uid, text, ts, id, reply, info)
    -- info (opcional): dn, script, scriptImg, ownerTag, fbKey, reacts, t, place, job, game, pc, mx, state, order
    info = type(info) == "table" and info or {}
    local key = sourceKey(name, uid, text, ts, id)
    if renderedKeys[key] then return messageRows[key] end
    renderedKeys[key] = true

    local isMe = tostring(uid) == tostring(LocalPlayer.UserId)
    local wasDeleted = localDeletedKeys[key] == true
    local stickerFrames, stickerInterval = stickerParse(text)
    if wasDeleted then stickerFrames = nil end
    local isInvite = info.t == "invite" and not wasDeleted
    if isInvite then stickerFrames = nil end
    local tsNum = tonumber(ts) or os.time()
    local wasNearBottom = Chat.isNearBottom()
    local timeText = os.date("%H:%M", tsNum)
    if info.edited then timeText = "editado · " .. timeText end -- v12
    local senderColor = isMe and Color3.fromRGB(245, 245, 245) or playerNameColor(name, uid)
    local replyWho = reply and tostring(reply.dn or reply.name or reply.user or "Unknown") or nil
    local stampLabel = nil
    local statusHolder = nil
    local inGroupChat = Chat.kind ~= "private"

    -- v8: separador de fecha (como Instagram) y agrupacion de mensajes seguidos del mismo jugador
    local prev = Chat.lastGroup
    local reRender = info.order ~= nil
    if not reRender then
        local dayNow = os.date("%Y%j", tsNum)
        if not prev or prev.day ~= dayNow or tsNum - (prev.ts or 0) > 3600 then
            local sep = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = Chat.nextOrder(),
            }, MessageScroll)
            mk("TextLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = UI.sepText(tsNum),
                TextColor3 = THEME.DIM, Font = Enum.Font.GothamBold, TextSize = 12,
            }, sep)
            prev = nil
        end
    end
    local firstInGroup = reRender or not (prev and tostring(prev.uid) == tostring(uid) and tsNum - (prev.ts or 0) < 300)
    if reRender and info.firstInGroup == false then firstInGroup = false end -- v12: re-dibujo conserva el grupo
    if not reRender then
        Chat.lastGroup = {uid = uid, ts = tsNum, day = os.date("%Y%j", tsNum)}
    end

    local row = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = tonumber(info.order) or Chat.nextOrder(),
    }, MessageScroll)
    if firstInGroup then
        mk("UIPadding", {PaddingTop = UDim.new(0, 8)}, row)
    end

    -- Avatar solo en el primer mensaje del grupo (los owners v_orc/n_oqv usan su imagen especial).
    local avatarSize = 42 -- v9: antes 34
    if not isMe and firstInGroup then
        local avatar = mk("ImageLabel", {
            Name = "SenderAvatar",
            Size = UDim2.fromOffset(avatarSize, avatarSize),
            Position = UDim2.new(0, 0, 0, inGroupChat and 23 or 0),
            BackgroundColor3 = THEME.PANEL2,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Image = Chat.avatarFor(uid, name),
            ScaleType = Enum.ScaleType.Crop,
        }, row)
        corner(avatar, 21)
        if Chat.isOwner(uid, name) then
            Chat.addCrown(avatar, avatarSize)
        end
        -- Tocar el avatar abre el perfil (con boton de mensaje privado).
        local avatarBtn = mk("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
        }, avatar)
        avatarBtn.MouseButton1Click:Connect(function()
            Chat.showProfile({uid = uid, name = name, dn = info.dn, script = info.script, scriptImg = info.scriptImg})
        end)
    end

    local content = mk("Frame", {
        Size = isMe and UDim2.new(1, 0, 0, 0) or UDim2.new(0.8, -8, 0, 0),
        Position = isMe and UDim2.new(0, 0, 0, 0) or UDim2.new(0, avatarSize + 8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, row)

    local contentLayout = mk("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = isMe and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
    }, content)

    -- Nombre: solo en el grupo, solo para otros y solo en el primer mensaje del bloque.
    local owner = Chat.isOwner(uid, name)
    local nameLabel = nil
    if not isMe and inGroupChat and firstInGroup then
        local head = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, content)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
        }, head)
        -- v10: solo el usuario real (sin DisplayName) para ocupar menos espacio
        nameLabel = mk("TextLabel", {
            Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Text = tostring(name or "Unknown"),
            TextColor3 = owner and Color3.new(1, 1, 1) or senderColor,
            Font = owner and Enum.Font.GothamBlack or Enum.Font.GothamBold,
            TextSize = owner and 17 or 16,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }, head)
        if owner then
            Chat.ownerNameFx(nameLabel)
        end
        local tag = Chat.scriptTag(info.script)
        if tag then
            local chip = mk("TextLabel", {
                Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1, BorderSizePixel = 0, Text = tag,
                TextColor3 = THEME.DIM, Font = Enum.Font.GothamBold, TextSize = 13, LayoutOrder = 3,
            }, head)
        end
    end

    -- Hora + estado (doble tilde / alerta) en la esquina de la burbuja
    local function makeStamp(parent, onDark)
        local holder = mk("Frame", {
            Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6),
            BackgroundTransparency = 1, ZIndex = 3,
        }, parent)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
        }, holder)
        local lbl = mk("TextLabel", {
            Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
            Text = timeText, TextColor3 = onDark and THEME.DIM or Color3.fromRGB(225, 225, 255),
            Font = Enum.Font.GothamMedium, TextSize = 12, LayoutOrder = 1, ZIndex = 3,
        }, holder)
        if isMe then
            -- doble tilde = el mismo icono dos veces, encimado
            local ticks = mk("Frame", {
                Name = "Ticks", Size = UDim2.fromOffset(19, 14), BackgroundTransparency = 1, LayoutOrder = 2, Visible = false, ZIndex = 3,
            }, holder)
            UI.icon(ticks, UI.ICON.tick, 14, Color3.fromRGB(255, 255, 255), {ZIndex = 3})
            UI.icon(ticks, UI.ICON.tick, 14, Color3.fromRGB(255, 255, 255), {Position = UDim2.fromOffset(5, 0), ZIndex = 3})
            UI.icon(holder, UI.ICON.alert, 14, THEME.DANGER, {Name = "Alert", LayoutOrder = 3, Visible = false, ZIndex = 3})
        end
        return lbl, holder
    end

    if stickerFrames then
        -- Stickers sobre el fondo, sin burbuja (como Instagram/WhatsApp)
        local stickerWrap = mk("Frame", {
            Size = UDim2.fromOffset(150, reply and 196 or 150),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, content)

        if reply then
            local replyBox = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundColor3 = THEME.PANEL2,
                BackgroundTransparency = 0.1,
                BorderSizePixel = 0,
            }, stickerWrap)
            corner(replyBox, 12)
            mk("Frame", {Size = UDim2.fromOffset(3, 26), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = UI.C.blue, BorderSizePixel = 0}, replyBox)
            mk("TextLabel", {
                Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(17, 4), BackgroundTransparency = 1,
                Text = replyWho, TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            }, replyBox)
            mk("TextLabel", {
                Size = UDim2.new(1, -24, 0, 15), Position = UDim2.fromOffset(17, 21), BackgroundTransparency = 1,
                Text = tostring(reply.text or ""):match("^%[%[STICKER:") and "Sticker" or tostring(reply.text or ""),
                TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            }, replyBox)
        end

        local image = mk("ImageLabel", {
            Size = UDim2.fromOffset(140, 140),
            Position = UDim2.fromOffset(5, reply and 46 or 0),
            BackgroundTransparency = 1,
            Image = stickerFrames[1],
            ScaleType = Enum.ScaleType.Fit,
        }, stickerWrap)
        animateSticker(image, stickerFrames, stickerInterval)

        local chip = mk("Frame", {
            Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
            AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2,
        }, stickerWrap)
        corner(chip, 10)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, chip)
        stampLabel, statusHolder = makeStamp(chip, true)
        statusHolder.AnchorPoint = Vector2.new(0, 0.5)
        statusHolder.Position = UDim2.new(0, 0, 0.5, 0)
    elseif isInvite then
        -- v10: tarjeta de invitacion rediseñada (banner con la miniatura del juego, jugadores,
        -- cuenta regresiva de expiracion y boton grande). Mismo formato de datos que NeoChat.
        local here = tostring(info.job) == tostring(game.JobId)
        local EXPIRE = 900
        local placeId = tonumber(info.place)
        local cardW = 320
        local inviteCard = mk("Frame", {
            Size = UDim2.fromOffset(cardW, 300),
            BackgroundColor3 = Color3.fromRGB(24, 24, 28),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            LayoutOrder = 2,
        }, content)
        corner(inviteCard, 22)
        local cardStroke = mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.4, Transparency = 0.2}, inviteCard)
        mk("UIGradient", {Rotation = 35, Color = ColorSequence.new(UI.C.ownA, UI.C.ownB)}, cardStroke)

        -- Banner: degradado de respaldo + miniatura real del juego (GameThumbnail usa PlaceId)
        local banner = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
        }, inviteCard)
        mk("UIGradient", {Rotation = 30, Color = ColorSequence.new(Color3.fromRGB(88, 46, 200), Color3.fromRGB(0, 110, 230))}, banner)
        UI.icon(banner, UI.ICON.server, 56, Color3.new(1, 1, 1), {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ImageTransparency = 0.35,
        })
        if placeId then
            mk("ImageLabel", {
                Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop,
                Image = ("rbxthumb://type=GameThumbnail&id=%d&w=768&h=432"):format(placeId), ZIndex = 2,
            }, banner)
        end
        -- sombra inferior para que se lean las etiquetas
        local shade = mk("Frame", {
            Size = UDim2.new(1, 0, 0.6, 0), Position = UDim2.fromScale(0, 0.4), BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0, ZIndex = 3,
        }, banner)
        mk("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15)}),
        }, shade)
        -- chip "INVITACION"
        local chip = mk("Frame", {
            Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4,
        }, banner)
        corner(chip, 13)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10)}, chip)
        mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, chip)
        UI.icon(chip, UI.ICON.server, 14, Color3.new(1, 1, 1), {LayoutOrder = 1, ZIndex = 5})
        mk("TextLabel", {
            Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
            Text = "INVITACIÓN", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 11,
            LayoutOrder = 2, ZIndex = 5,
        }, chip)
        -- chip de jugadores
        if tonumber(info.pc) then
            local pchip = mk("Frame", {
                AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(0, 26),
                AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
                BorderSizePixel = 0, ZIndex = 4,
            }, banner)
            corner(pchip, 13)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10)}, pchip)
            mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, pchip)
            UI.icon(pchip, UI.ICON.people, 14, Color3.new(1, 1, 1), {LayoutOrder = 1, ZIndex = 5})
            mk("TextLabel", {
                Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
                Text = tostring(info.pc) .. "/" .. tostring(info.mx or "?"), TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamBold, TextSize = 12, LayoutOrder = 2, ZIndex = 5,
            }, pchip)
        end
        -- nombre del juego sobre la sombra
        mk("TextLabel", {
            Size = UDim2.new(1, -24, 0, 26), Position = UDim2.new(0, 12, 1, -34), BackgroundTransparency = 1,
            Text = tostring(info.game or "Roblox"), TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack,
            TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5,
        }, banner)

        -- Cuerpo
        mk("TextLabel", {
            Size = UDim2.new(1, -28, 0, 20), Position = UDim2.fromOffset(14, 160), BackgroundTransparency = 1,
            Text = isMe and "Invitaste a todos a tu servidor" or ("@" .. tostring(name) .. " te invita a su servidor"),
            TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        }, inviteCard)
        local statusDot = mk("Frame", {
            Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 191), BackgroundColor3 = UI.C.online, BorderSizePixel = 0,
        }, inviteCard)
        corner(statusDot, 4)
        local statusLbl = mk("TextLabel", {
            Size = UDim2.new(1, -40, 0, 18), Position = UDim2.fromOffset(28, 186), BackgroundTransparency = 1,
            Text = "", TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, inviteCard)
        -- v12 FIX: el UIGradient sobre el boton tambien teñia su texto (quedaba invisible).
        -- Ahora el degradado va en un fondo hijo y el texto en una etiqueta aparte, encima.
        local joinBtn = mk("TextButton", {
            Size = UDim2.new(1, -28, 0, 44), Position = UDim2.fromOffset(14, 216),
            BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2,
        }, inviteCard)
        local joinBg = mk("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2,
        }, joinBtn)
        corner(joinBg, 14)
        local joinGrad = mk("UIGradient", {Rotation = 0, Color = ColorSequence.new(UI.C.ownA, UI.C.ownB)}, joinBg)
        local joinText = mk("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
            TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 15, ZIndex = 4,
        }, joinBtn)
        local joining = false
        local function refreshInvite()
            if joining then return end
            local left = EXPIRE - (os.time() - tsNum)
            if here then
                statusDot.BackgroundColor3 = UI.C.online
                statusLbl.Text = "Ya estás en este servidor"
                joinText.Text = "Estás aquí"
                joinGrad.Enabled = false
                joinBg.BackgroundColor3 = THEME.PANEL2
                joinText.TextColor3 = UI.C.online
            elseif left <= 0 then
                statusDot.BackgroundColor3 = THEME.DIM
                statusLbl.Text = "La invitación expiró"
                joinText.Text = "Invitación expirada"
                joinGrad.Enabled = false
                joinBg.BackgroundColor3 = THEME.PANEL2
                joinText.TextColor3 = THEME.DIM
            else
                local mins = math.max(1, math.ceil(left / 60))
                statusDot.BackgroundColor3 = UI.C.online
                statusLbl.Text = "Activa · expira en " .. mins .. " min"
                joinText.Text = "Unirse al servidor"
                joinGrad.Enabled = true
                joinBg.BackgroundColor3 = Color3.new(1, 1, 1)
                joinText.TextColor3 = Color3.new(1, 1, 1)
            end
            return left > 0
        end
        refreshInvite()
        joinBtn.MouseButton1Click:Connect(function()
            if here or joining or (EXPIRE - (os.time() - tsNum)) <= 0 then return end
            joining = true
            joinText.Text = "Uniéndote..."
            pcall(function()
                game:GetService("TeleportService"):TeleportToPlaceInstance(placeId, tostring(info.job), LocalPlayer)
            end)
            task.delay(8, function()
                joining = false
                if joinBtn.Parent then refreshInvite() end
            end)
        end)
        -- cuenta regresiva en vivo mientras la tarjeta exista
        if not here then
            task.spawn(function()
                while inviteCard.Parent and refreshInvite() do
                    task.wait(20)
                end
            end)
        end
        stampLabel, statusHolder = makeStamp(inviteCard, true)
        statusHolder.Position = UDim2.new(1, -14, 1, -12)
    else
        local messageText = wasDeleted and "Este mensaje fue eliminado" or tostring(text or "")
        local maxBubbleWidth = math.max(170, math.floor((MessageScroll.AbsoluteSize.X * 0.72) - 8))
        local textMaxWidth = math.max(120, maxBubbleWidth - 28)
        -- v10: owners con letra mas gruesa; formato tipo Discord (# titulos, **negrita**, etc.)
        local ownerMsg = owner and not wasDeleted
        local baseFont = ownerMsg and Enum.Font.GothamBold or Enum.Font.GothamMedium
        local baseSize = ownerMsg and 20 or 19
        local richText, mdW, mdH
        if wasDeleted then
            local b = TextService:GetTextSize(messageText, baseSize, baseFont, Vector2.new(textMaxWidth, 10000))
            richText, mdW, mdH = Chat.esc(messageText), b.X, b.Y
        else
            local rainbowBody = Chat.rainbowBody(messageText)
            if rainbowBody then messageText = rainbowBody end
            richText, mdW, mdH = Chat.formatMessage(messageText, baseSize, baseFont, textMaxWidth)
        end
        local textBounds = Vector2.new(math.min(mdW, textMaxWidth), mdH)
        local replyWidth = 0
        if reply then
            local quotedText = tostring(reply.text or "")
            if quotedText:match("^%[%[STICKER:") then quotedText = "Sticker" end
            quotedText = quotedText:gsub("%s+", " ")
            local replyTextBounds = TextService:GetTextSize(quotedText, 12, Enum.Font.GothamMedium, Vector2.new(10000, 100))
            local replyNameBounds = TextService:GetTextSize(replyWho, 12, Enum.Font.GothamBold, Vector2.new(10000, 100))
            replyWidth = math.max(replyTextBounds.X, replyNameBounds.X) + 44
        end
        local stampW = (isMe and 78 or 50) + (info.edited and 62 or 0)
        local bubbleWidth = math.min(maxBubbleWidth, math.max(stampW + 28, math.ceil(math.max(textBounds.X + 30, replyWidth))))
        local wraps = textBounds.X > textMaxWidth
        local replyExtraHeight = reply and 50 or 0
        local bubbleHeight = math.max(48, math.ceil(textBounds.Y) + 38) + replyExtraHeight

        local bubble = mk("Frame", {
            Size = UDim2.fromOffset(bubbleWidth, bubbleHeight),
            BackgroundColor3 = isMe and Color3.new(1, 1, 1) or UI.C.other,
            BackgroundTransparency = wasDeleted and 1 or 0,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, content)
        corner(bubble, 20)
        if isMe and not wasDeleted then
            -- degradado violeta -> azul de Instagram
            mk("UIGradient", {
                Rotation = 0,
                Color = ColorSequence.new(UI.C.ownA, UI.C.ownB),
            }, bubble)
        end
        if wasDeleted then
            stroke(bubble, UI.C.line, 1, 0)
        end
        if ownerMsg then
            -- borde blanco tipo neon con el mismo brillo que el nombre
            local neon = mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.6, Transparency = 0.15}, bubble)
            local g = mk("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.75),
                    NumberSequenceKeypoint.new(0.5, 0),
                    NumberSequenceKeypoint.new(1, 0.75),
                }),
                Offset = Vector2.new(-1, 0),
            }, neon)
            pcall(function()
                TweenService:Create(g, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.6), {Offset = Vector2.new(1, 0)}):Play()
            end)
        end

        -- Mencion @tuNombre = borde dorado; respuesta a tu mensaje = borde azul (como NeoChat).
        if not isMe and not wasDeleted then
            if Chat.mentionsMe(text) then
                stroke(bubble, Color3.fromRGB(255, 196, 0), 1.5, 0.15)
            elseif Chat.isReplyToMe(reply) then
                stroke(bubble, Color3.fromRGB(80, 180, 255), 1.3, 0.2)
            end
        end

        if reply then
            local replyBox = mk("Frame", {
                Size = UDim2.new(1, -16, 0, 42),
                Position = UDim2.fromOffset(8, 8),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = isMe and 0.75 or 0.55,
                BorderSizePixel = 0,
            }, bubble)
            corner(replyBox, 12)
            mk("Frame", {
                Size = UDim2.fromOffset(3, 28),
                Position = UDim2.fromOffset(8, 7),
                BackgroundColor3 = isMe and Color3.new(1, 1, 1) or UI.C.blue,
                BorderSizePixel = 0,
            }, replyBox)
            local replyName = mk("TextLabel", {
                Size = UDim2.new(1, -26, 0, 17),
                Position = UDim2.fromOffset(17, 4),
                BackgroundTransparency = 1,
                Text = replyWho,
                TextColor3 = THEME.TXT,
                Font = Enum.Font.GothamBold,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, replyBox)
            local replyText = tostring(reply.text or "")
            if replyText:match("^%[%[STICKER:") then replyText = "Sticker" end
            replyText = replyText:gsub("%s+", " ")
            local replyPreviewMax = math.max(1, math.floor((bubbleWidth - 48) / 8))
            if #replyText > replyPreviewMax then replyText = replyText:sub(1, replyPreviewMax - 1) .. "…" end
            mk("TextLabel", {
                Size = UDim2.new(1, -26, 0, 16),
                Position = UDim2.fromOffset(17, 21),
                BackgroundTransparency = 1,
                Text = replyText,
                TextColor3 = isMe and Color3.fromRGB(225, 225, 255) or THEME.DIM,
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, replyBox)
        end

        local msgLabel = mk("TextLabel", {
            Size = UDim2.new(1, -28, 1, reply and -72 or -28),
            Position = UDim2.fromOffset(14, reply and 56 or 9),
            BackgroundTransparency = 1,
            Text = richText,
            RichText = true,
            TextColor3 = wasDeleted and THEME.DIM or THEME.TXT,
            Font = baseFont,
            TextSize = baseSize,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, bubble)
        if not wasDeleted and Chat.rainbowBody(text) then
            Chat.applyRainbow(msgLabel)
        end
        -- v12: vista previa de invitaciones de Discord
        local dcCode = (not wasDeleted) and Chat.discordCode(text) or nil
        if dcCode then Chat.discordCard(content, dcCode, isMe) end

        stampLabel, statusHolder = makeStamp(bubble, not isMe or wasDeleted)
    end

    local meta = {
        key=key, row=row, name=tostring(name or "Unknown"), uid=tonumber(uid) or 0,
        text=tostring(text or ""), ts=tonumber(ts) or os.time(), id=id, reply=reply,
        isSticker=stickerFrames ~= nil,
        fbKey=info.fbKey, dn=info.dn, script=info.script, scriptImg=info.scriptImg, t=info.t,
        order=row.LayoutOrder, firstInGroup=firstInGroup, edited=info.edited, state=info.state, stamp=stampLabel, statusHolder=statusHolder, timeText=timeText, isMe=isMe,
        searchText=string.lower(tostring(name or "") .. " " .. tostring(info.dn or "") .. " " .. ((stickerFrames or isInvite) and "" or tostring(text or ""))),
    }
    -- v8: reacciones en una pildora chica debajo de la burbuja (estilo Instagram)
    local reactionWrap = mk("TextLabel", {
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = THEME.PANEL2,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamMedium,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Visible = false,
        LayoutOrder = 4, -- v12: 3 queda para la tarjeta de Discord
    }, content)
    corner(reactionWrap, 13)
    stroke(reactionWrap, THEME.BG, 2, 0)
    mk("UIPadding", {
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 8),
    }, reactionWrap)
    meta.content=content
    meta.reactionWrap=reactionWrap
    messageRows[key]=meta
    if info.fbKey then Chat.byFbKey[info.fbKey] = meta end
    if type(info.reacts) == "table" then Chat.setReactCounts(key, info.reacts) end
    refreshReactionChips(meta)
    Chat.setStatus(meta, info.state)
    Chat.applySearch(meta)
    bindLongPress(row, meta)

    EmptyLabel.Visible = false
    -- v12: si estas leyendo arriba no te baja de golpe; aparece "N mensajes nuevos"
    if reRender then
        -- nada
    elseif isMe or firebaseInitialLoad or wasNearBottom then
        task.defer(scrollBottom)
    else
        Chat.newBelow = (Chat.newBelow or 0) + 1
        Chat.refreshNewPill()
    end
    return meta
end

local function processIncoming(name, uid, text, ts, id, reply, info)
    text = tostring(text or ""):sub(1, CONFIG.MAX_CHAR)
    if text == "" or not tonumber(uid) then return end
    if text:match("^%[%[SERVERINVITE:") or text:match("^%[%[ANUNCIO%]%]") then return end

    local dedupe = table.concat({tostring(uid), tostring(text), tostring(math.floor((tonumber(ts) or os.time()) / 4))}, "|")
    if contentSeen[dedupe] then return end
    contentSeen[dedupe] = true

    local key = sourceKey(name, uid, text, ts, id)
    if renderedKeys[key] then return messageRows[key] end
    reply = reply or findStoredReply(uid, text, ts)
    addHistory(name, uid, text, ts, id, reply)
    return renderMessage(name, uid, text, ts, id, reply, info)
end

-- Envia a la sala actual (global o privado). Dibuja el mensaje al instante como "pendiente"
-- y lo pasa a enviado (✓) o fallido (!) segun la respuesta de Firebase. Solo Firebase.
local function sendPayload(text, extra)
    local room, gen = Chat.room, Chat.roomGen
    local target = Chat.kind == "private" and Chat.target or nil
    local cid = CID_PREFIX .. tostring(LocalPlayer.UserId) .. "_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000,999999))
    local ts = os.time()
    local reply = pendingReply
    local payload = {
        uid=LocalPlayer.UserId, user=LocalPlayer.Name, dn=LocalPlayer.DisplayName,
        text=text, cid=cid, t="msg", ts={ [".sv"]="timestamp" },
        script="Neo", scriptImg=SCRIPT_IMG,
    }
    if type(reply) == "table" then
        payload.reply = {uid=reply.uid, user=reply.user, dn=reply.dn, text=reply.text, key=reply.key}
    end
    for k, v in pairs(extra or {}) do payload[k] = v end

    addHistory(LocalPlayer.Name, LocalPlayer.UserId, text, ts, cid, reply)
    local meta = renderMessage(LocalPlayer.Name, LocalPlayer.UserId, text, ts, cid, reply, {
        dn=LocalPlayer.DisplayName, t=payload.t, place=payload.place, job=payload.job,
        game=payload.game, pc=payload.pc, mx=payload.mx, state="pending",
    })
    rememberReply(text, ts, reply)
    cancelReply()
    if meta then Chat.pending[cid] = meta end
    task.spawn(function() Chat.fbCall("DELETE", "typing/" .. room .. "/" .. tostring(LocalPlayer.UserId)) end) -- v12
    Chat.setPreview(room, {dn=LocalPlayer.DisplayName, user=LocalPlayer.Name, uid=LocalPlayer.UserId, text=text, t=payload.t, ts=ts * 1000})

    task.spawn(function()
        local ok, data = Chat.fbCall("POST", "chat/" .. room .. "/messages", payload)
        if gen == Chat.roomGen and meta then
            if ok and type(data) == "table" and type(data.name) == "string" then
                firebaseSeen[data.name] = true
                meta.fbKey = data.name
                Chat.byFbKey[data.name] = meta
                Chat.pending[cid] = nil
                Chat.setStatus(meta, "sent")
            elseif not ok then
                Chat.pending[cid] = nil
                Chat.setStatus(meta, "failed")
            end
        end
        -- Privado: aviso en inbox/<uidDelOtro> para que le aparezca el chat aunque no lo haya abierto.
        if ok and target and Chat.inboxOk then
            local _, _, code = Chat.fbCall("PUT", "inbox/" .. tostring(target) .. "/" .. tostring(LocalPlayer.UserId), {
                uid=LocalPlayer.UserId, user=LocalPlayer.Name, dn=LocalPlayer.DisplayName,
                text=Chat.previewText(payload), ts={ [".sv"]="timestamp" }, room=room,
            })
            if code == 401 or code == 403 then Chat.inboxOk = false end
        end
    end)
end

local function sendText()
    if sending then return end
    local text = tostring(MessageBox.Text or ""):sub(1, CONFIG.MAX_CHAR)
    text = text:match("^%s*(.-)%s*$") or ""
    if text == "" then return end
    sending = true
    MessageBox.Text = ""
    if Chat.editing then
        -- v12: editar mensaje propio
        Chat.submitEdit(text)
    else
        sendPayload(text)
    end
    task.delay(0.2, function() sending = false end)
end
Chat.sendText = sendText

-- =====================================================================
-- ===== App tipo WhatsApp: privados, inicio, pin, menciones, avisos =====
-- =====================================================================

Chat.isViewing = function(room)
    return open and Chat.view == "chat" and Chat.room == room
end

-- ----- Reacciones reales (Firebase) -----
Chat.setReactCounts = function(key, reacts)
    if type(reacts) ~= "table" then localReactions[key] = nil return end
    local counts = {}
    for emoji, n in pairs(reacts) do
        local v = tonumber(n)
        if v and v > 0 then counts[tostring(emoji)] = math.floor(v) end
    end
    localReactions[key] = counts
end

Chat.applyServerReacts = function(meta, reacts)
    if not meta then return end
    local hold = Chat.reactHold[meta.key]
    if hold and os.clock() < hold then return end
    Chat.setReactCounts(meta.key, reacts)
    refreshReactionChips(meta)
end

Chat.sendReaction = function(meta, emoji)
    if not meta then return end
    Chat.reactHold[meta.key] = os.clock() + 6
    local room = Chat.room
    task.spawn(function()
        local t0 = os.clock()
        while not meta.fbKey and os.clock() - t0 < 6 do task.wait(0.3) end
        if not meta.fbKey then return end
        local path = "chat/" .. room .. "/messages/" .. meta.fbKey .. "/reacts/" .. HttpService:UrlEncode(emoji)
        local ok = Chat.fbCall("PUT", path, {[".sv"] = {increment = 1}})
        if not ok then
            -- Respaldo si Firebase no acepta "increment": leer y sumar 1.
            local okGet, current = Chat.fbCall("GET", path)
            Chat.fbCall("PUT", path, (okGet and tonumber(current) or 0) + 1)
        end
        Chat.reactHold[meta.key] = os.clock() + 1.5
    end)
end

-- ----- Estado del mensaje propio: ... pendiente, ✓ enviado, ! fallido -----
-- v8: pendiente = "hora ·", enviado = doble tilde, fallido = icono de alerta rojo
Chat.setStatus = function(meta, state)
    if not meta or not meta.isMe or not meta.stamp then return end
    local holder = meta.statusHolder
    local ticks = holder and holder:FindFirstChild("Ticks")
    local alert = holder and holder:FindFirstChild("Alert")
    meta.stamp.Text = tostring(meta.timeText or "") .. (state == "pending" and " ·" or "")
    if ticks then ticks.Visible = state ~= "pending" and state ~= "failed" end
    if alert then alert.Visible = state == "failed" end
    if state == "failed" then meta.stamp.TextColor3 = THEME.DANGER end
    meta.state = state or "sent"
end

-- Owners v_orc y n_oqv muestran su imagen especial en vez del avatar (mousoza no)
Chat.OWNER_AVATAR_NAMES = { v_orc = true, n_oqv = true }
Chat.avatarFor = function(uid, user)
    if string.lower(tostring(user or "")) == "mousoza" then return UI.ICON.mousozaAvatar end
    if Chat.OWNER_AVATAR_NAMES[string.lower(tostring(user or ""))] then return UI.ICON.ownerAvatar end
    return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(tonumber(uid) or 0)
end

-- Etiqueta del script de origen: Neo / Neo Hyper va sin etiqueta; el resto (ej. YinYang) lleva [YinYang]
Chat.scriptTag = function(script)
    script = tostring(script or "")
    local low = string.lower(script)
    if script == "" or low == "neo" or low == "neo hyper" or low == "neohyper" then return nil end
    return "[" .. script .. "]"
end

-- Tiempo relativo como Instagram: ahora, 5 min, 3 h, 2 d, 4 sem
UI.relTime = function(ts)
    ts = tonumber(ts)
    if not ts then return "" end
    local d = math.max(0, os.time() - math.floor(ts))
    if d < 60 then return "ahora" end
    if d < 3600 then return math.floor(d / 60) .. " min" end
    if d < 86400 then return math.floor(d / 3600) .. " h" end
    if d < 604800 then return math.floor(d / 86400) .. " d" end
    return math.floor(d / 604800) .. " sem"
end

-- Separador del chat: "Hoy 7:35 P. M.", "Ayer ...", o "20 JUN, 7:35 P. M."
UI.sepText = function(ts)
    local t = os.date("*t", ts)
    local now = os.date("*t")
    local h = t.hour % 12
    if h == 0 then h = 12 end
    local hour = string.format("%d:%02d %s", h, t.min, t.hour < 12 and "A. M." or "P. M.")
    if t.year == now.year and t.yday == now.yday then return "Hoy " .. hour end
    if t.year == now.year and t.yday == now.yday - 1 then return "Ayer " .. hour end
    return UI.fullDate(ts)
end

-- ----- Nombre: DisplayName + @usuario + tag + [script] -----
Chat.richName = function(name, info)
    local user = tostring(name or "Unknown")
    local dn = tostring(info.dn or "")
    local out
    if dn ~= "" and dn ~= user then
        out = Chat.esc(dn) .. ' <font transparency="0.45">@' .. Chat.esc(user) .. "</font>"
    else
        out = Chat.esc(user)
    end
    if type(info.ownerTag) == "string" and info.ownerTag ~= "" then
        out ..= '  <font color="#FFD700">' .. Chat.esc(info.ownerTag) .. "</font>"
    end
    -- v8: la etiqueta del script ([Neo]) ahora se dibuja aparte y solo si no es Yin Yang
    return out
end

-- ----- Menciones y respuestas a mi (misma logica que NeoChat) -----
Chat.mentionsMe = function(text)
    if not Chat.settings.MentionsEnabled then return false end
    local t = string.lower(tostring(text or ""))
    local function hasFull(n)
        if not n or n == "" or n == "@" then return false end
        local pos = 1
        while true do
            local s, e = string.find(t, n, pos, true)
            if not s then return false end
            local before = s == 1 or string.sub(t, s - 1, s - 1):match("[%s%p]") ~= nil
            local after = e == #t or string.sub(t, e + 1, e + 1):match("[%s%p]") ~= nil
            if before and after then return true end
            pos = e + 1
        end
    end
    return hasFull("@" .. string.lower(LocalPlayer.Name)) or hasFull("@" .. string.lower(LocalPlayer.DisplayName))
end

Chat.isReplyToMe = function(reply)
    if type(reply) ~= "table" then return false end
    if tonumber(reply.uid) == LocalPlayer.UserId then return true end
    local me1, me2 = string.lower(LocalPlayer.Name), string.lower(LocalPlayer.DisplayName)
    local ru = string.lower(tostring(reply.user or ""))
    local rd = string.lower(tostring(reply.dn or ""))
    if ru ~= "" and (ru == me1 or ru == me2) then return true end
    if rd ~= "" and (rd == me1 or rd == me2) then return true end
    return false
end

-- ----- Vista previa para la lista de chats -----
Chat.previewText = function(m)
    if type(m) ~= "table" then return "" end
    if m.t == "invite" then return "Invitación al servidor" end
    local text = tostring(m.text or "")
    if text:match("^%[%[STICKER:") then return "Sticker" end
    text = Chat.rainbowBody(text) or text
    local _, body = Chat.mdLine(text)
    text = Chat.mdStrip(body)
    text = text:gsub("%s+", " ")
    return Chat.clip(text, 60)
end

Chat.setPreview = function(room, m, onlyIfNewer)
    if not room or type(m) ~= "table" then return end
    local tsSec = tonumber(m.ts)
    tsSec = tsSec and (tsSec > 1e11 and tsSec / 1000 or tsSec) or os.time()
    local prev = Chat.previews[room]
    if onlyIfNewer and prev and (prev.ts or 0) >= tsSec then return end
    local kind = "text"
    if m.t == "invite" then kind = "invite" elseif tostring(m.text or ""):match("^%[%[STICKER:") then kind = "sticker" end
    Chat.previews[room] = {
        name = tostring(m.dn or m.user or "?"), uid = tonumber(m.uid),
        text = Chat.previewText(m), ts = tsSec, kind = kind,
    }
end

-- ----- Borrado / pin (owners) -----
Chat.removeRow = function(meta)
    if not meta then return end
    if meta.row and meta.row.Parent then meta.row:Destroy() end
    if messageRows[meta.key] == meta then messageRows[meta.key] = nil end
    if meta.fbKey and Chat.byFbKey[meta.fbKey] == meta then Chat.byFbKey[meta.fbKey] = nil end
    if actionTarget == meta then hideMessageActions() end
end

Chat.ownerDelete = function(meta)
    if not (Chat.meIsOwner and meta and meta.fbKey) then return end
    local room = Chat.room
    task.spawn(function()
        local ok, _, code = Chat.fbCall("DELETE", "chat/" .. room .. "/messages/" .. meta.fbKey)
        if ok then
            Chat.removeRow(meta)
        else
            Chat.flash("Firebase rechazó el borrado (código " .. tostring(code) .. ")")
        end
    end)
end

Chat.pinMessage = function(meta)
    if not (Chat.meIsOwner and meta and meta.fbKey) then return end
    local room = Chat.room
    local text = tostring(meta.text or "")
    if text:match("^%[%[STICKER:") then text = "[Sticker]" end
    local pin = {key = meta.fbKey, uid = meta.uid, user = meta.name, dn = meta.dn or meta.name, text = Chat.clip(text, 120)}
    task.spawn(function()
        local ok, _, code = Chat.fbCall("PUT", "chat/" .. room .. "/pin", pin)
        if ok then
            if room == Chat.room then
                Chat.pin = pin
                Chat.refreshPin()
            end
        else
            Chat.flash("No se pudo fijar (código " .. tostring(code) .. ")")
        end
    end)
end

-- ----- Busqueda -----
Chat.applySearch = function(meta)
    if not meta or not meta.row then return end
    local q = Chat.searchQuery
    meta.row.Visible = q == "" or string.find(meta.searchText or "", q, 1, true) ~= nil
end

Chat.applySearchAll = function()
    for _, meta in pairs(messageRows) do Chat.applySearch(meta) end
end

Chat.maskName = function(name)
    name = tostring(name or "?"):gsub("[%c%z]", "")
    local first = name:sub(1, 2)
    if first == "" then first = "??" end
    return first .. string.rep("*", math.clamp(#name - 2, 3, 8))
end

-- ----- Recientes de privados (se guardan en NeoHyper_ChatSettings.json) -----
Chat.rememberDM = function(uid, name, user, bump)
    uid = tonumber(uid)
    if not uid or uid == LocalPlayer.UserId then return end
    local list = Chat.settings.RecentDMs
    local found
    for i, e in ipairs(list) do
        if type(e) == "table" and tonumber(e.uid) == uid then found = i break end
    end
    local entry = found and list[found] or {uid = uid}
    local changed = not found
    if name and tostring(name) ~= "" and entry.name ~= tostring(name) then entry.name = tostring(name) changed = true end
    if user and tostring(user) ~= "" and entry.user ~= tostring(user) then entry.user = tostring(user) changed = true end
    entry.name = entry.name or entry.user or tostring(uid)
    if bump or not found then
        if found then table.remove(list, found) end
        table.insert(list, 1, entry)
        entry.ts = os.time()
        while #list > 12 do table.remove(list) end
        changed = true
    end
    if changed then Chat.saveSettings() end
end

-- ----- Widgets nuevos -----
do
    -- Header (v8 con iconos): volver, foto del chat, buscar, silenciar, mas opciones
    UI.BackButton = UI.iconButton(Header, UI.ICON.back, 34, 22, {Position = UDim2.fromOffset(8, 12), Visible = false, ZIndex = 3})
    UI.BackCount = mk("TextLabel", {
        Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.fromOffset(28, 4), BackgroundColor3 = UI.C.blue, BorderSizePixel = 0, Text = "",
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 11, Visible = false, ZIndex = 5,
    }, UI.BackButton)
    corner(UI.BackCount, 9)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5)}, UI.BackCount)
    UI.HeaderAvatar = mk("ImageLabel", {
        Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(52, 9),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Image = "",
        ScaleType = Enum.ScaleType.Crop, Visible = false, ZIndex = 3,
    }, Header)
    corner(UI.HeaderAvatar, 20)
    UI.HeaderRing = UI.storyRing(UI.HeaderAvatar, 2)
    UI.HeaderDot = mk("Frame", {
        Size = UDim2.fromOffset(11, 11), Position = UDim2.fromOffset(30, 30),
        BackgroundColor3 = UI.C.online, BorderSizePixel = 0, Visible = false, ZIndex = 4,
    }, UI.HeaderAvatar)
    corner(UI.HeaderDot, 6)
    stroke(UI.HeaderDot, THEME.BG, 2, 0)
    UI.SearchBtn = UI.iconButton(Header, UI.ICON.search, 34, 20, {Position = UDim2.new(1, -258, 0, 12), Visible = false, ZIndex = 3})
    local muteImg
    UI.MuteBtn, muteImg = UI.iconButton(Header, UI.ICON.bell, 34, 20, {Position = UDim2.new(1, -222, 0, 12), Visible = false, ZIndex = 3})
    UI.MuteIcon = muteImg
    UI.MoreBtn = UI.iconButton(Header, UI.ICON.more, 34, 20, {Position = UDim2.new(1, -186, 0, 12), Visible = false, ZIndex = 3})
    UI.PencilBtn = UI.iconButton(Header, UI.ICON.pencil, 34, 20, {Position = UDim2.new(1, -186, 0, 12), Visible = false, ZIndex = 3})
    UI.OnlineButton = mk("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 6,
    }, OnlinePill)

    -- Menu de "mas opciones" (tres puntos)
    UI.MoreMenu = mk("Frame", {
        Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -150, 0, 52),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Visible = false, ZIndex = 130,
    }, Root)
    corner(UI.MoreMenu, 14)
    mk("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, UI.MoreMenu)
    mk("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}, UI.MoreMenu)
    UI.MoreOnline = makeActionButton(UI.MoreMenu, "Ver conectados", 240, UI.ICON.people)
    UI.MoreMute = makeActionButton(UI.MoreMenu, "Silenciar", 240, UI.ICON.bellOff)
    UI.MoreHome = makeActionButton(UI.MoreMenu, "Volver a chats", 240, UI.ICON.back)
    UI.MoreDelete = makeActionButton(UI.MoreMenu, "Eliminar chat", 240, UI.ICON.trash)
    UI.MoreDelete.TextColor3 = THEME.DANGER
    UI.MoreDelete.Icon.ImageColor3 = THEME.DANGER
    for i, b in ipairs({UI.MoreOnline, UI.MoreMute, UI.MoreHome, UI.MoreDelete}) do
        b.LayoutOrder = i
        b.ZIndex = 131
    end

    -- Barra de mensaje fijado (estilo WhatsApp)
    UI.PinBar = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 40), Position = UDim2.fromOffset(14, 70),
        BackgroundColor3 = THEME.PANEL, BackgroundTransparency = 0.05, BorderSizePixel = 0, Visible = false, ZIndex = 60,
    }, Root)
    corner(UI.PinBar, 14)
    stroke(UI.PinBar, UI.C.line, 1, 0)
    UI.icon(UI.PinBar, UI.ICON.pin, 18, UI.C.gold, {Position = UDim2.fromOffset(12, 11), ZIndex = 61})
    UI.PinText = mk("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1, Text = "", TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamMedium, TextSize = 14, RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 61,
    }, UI.PinBar)
    UI.PinClose = mk("TextButton", {
        Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0, 6),
        BackgroundTransparency = 1, Text = "×", TextColor3 = THEME.DIM,
        Font = Enum.Font.GothamBold, TextSize = 22, Visible = Chat.meIsOwner, ZIndex = 61,
    }, UI.PinBar)

    -- Barra de busqueda dentro del chat (pildora)
    UI.SearchBar = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 36), Position = UDim2.fromOffset(14, 70),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Visible = false, ZIndex = 60,
    }, Root)
    corner(UI.SearchBar, 18)
    UI.icon(UI.SearchBar, UI.ICON.search, 16, THEME.DIM, {Position = UDim2.fromOffset(14, 10), ZIndex = 61})
    UI.SearchBox = mk("TextBox", {
        Size = UDim2.new(1, -54, 1, 0), Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1, Text = "", PlaceholderText = "Buscar en el chat",
        PlaceholderColor3 = THEME.DIM, TextColor3 = THEME.TXT, Font = Enum.Font.GothamMedium,
        TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 61,
    }, UI.SearchBar)

    -- Inicio: buscador tipo Instagram (filtra chats; si escribes un usuario, "Abrir" inicia un chat nuevo)
    UI.NewChatBar = mk("Frame", {
        Size = UDim2.new(1, -28, 0, 38), Position = UDim2.fromOffset(14, 68),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Visible = false,
    }, Root)
    corner(UI.NewChatBar, 19)
    UI.icon(UI.NewChatBar, UI.ICON.search, 16, THEME.DIM, {Position = UDim2.fromOffset(14, 11)})
    UI.NewChatBox = mk("TextBox", {
        Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(40, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        PlaceholderText = "Buscar o escribir un usuario", PlaceholderColor3 = THEME.DIM,
        TextColor3 = THEME.TXT, Font = Enum.Font.GothamMedium, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
    }, UI.NewChatBar)
    UI.NewChatGo = mk("TextButton", {
        Size = UDim2.fromOffset(70, 28), Position = UDim2.new(1, -76, 0, 5),
        BackgroundColor3 = UI.C.blue, BorderSizePixel = 0, Text = "Abrir",
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 13, Visible = false,
    }, UI.NewChatBar)
    corner(UI.NewChatGo, 14)
    UI.HomeList = mk("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -120), Position = UDim2.fromOffset(8, 114),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.DIM, AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
    }, Root)
    mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, UI.HomeList)
    mk("UIPadding", {PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10)}, UI.HomeList)

    -- Boton de invitacion en el composer (icono de servidor)
    UI.InviteButton = UI.iconButton(Composer, UI.ICON.server, 34, 22, {Position = UDim2.new(1, -94, 0, 9), ZIndex = 6})

    -- Tarjeta de perfil
    UI.Profile = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(310, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.PANEL, BorderSizePixel = 0, Visible = false, ZIndex = 140,
    }, Root)
    corner(UI.Profile, 22)
    stroke(UI.Profile, UI.C.line, 1, 0)
    mk("UIListLayout", {
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, UI.Profile)
    mk("UIPadding", {
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
    }, UI.Profile)

    -- Lista de conectados (nombres enmascarados, como NeoChat)
    UI.OnlinePanel = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 380), BackgroundColor3 = THEME.PANEL,
        BorderSizePixel = 0, Visible = false, ZIndex = 140,
    }, Root)
    corner(UI.OnlinePanel, 22)
    stroke(UI.OnlinePanel, UI.C.line, 1, 0)
    UI.OnlineTitle = mk("TextLabel", {
        Size = UDim2.new(1, -60, 0, 40), Position = UDim2.fromOffset(16, 4),
        BackgroundTransparency = 1, Text = "En línea", TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 141,
    }, UI.OnlinePanel)
    local onlineClose = mk("TextButton", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0, 8),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Text = "×",
        TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 20, ZIndex = 141,
    }, UI.OnlinePanel)
    corner(onlineClose, 8)
    onlineClose.MouseButton1Click:Connect(function() UI.OnlinePanel.Visible = false end)
    UI.OnlineList = mk("ScrollingFrame", {
        Size = UDim2.new(1, -24, 1, -56), Position = UDim2.fromOffset(12, 46),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 141,
    }, UI.OnlinePanel)
    mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, UI.OnlineList)

    -- Aviso corto dentro del chat
    UI.Flash = mk("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
        Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = THEME.PANEL, BorderSizePixel = 0, Text = "", TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamBold, TextSize = 14, Visible = false, ZIndex = 150,
    }, Root)
    corner(UI.Flash, 10)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, UI.Flash)

    -- Tarjetas laterales (menciones, respuestas y privados) en la ScreenGui
    UI.SideHolder = mk("Frame", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 60),
        Size = UDim2.fromOffset(270, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, ZIndex = 200,
    }, ScreenGui)
    mk("UIListLayout", {
        Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
    }, UI.SideHolder)
end

Chat.flashToken = 0
Chat.flash = function(text)
    Chat.flashToken += 1
    local tok = Chat.flashToken
    UI.Flash.Text = tostring(text)
    UI.Flash.Visible = true
    task.delay(2.4, function()
        if Chat.flashToken == tok then UI.Flash.Visible = false end
    end)
end

Chat.hideOverlays = function()
    UI.Profile.Visible = false
    UI.OnlinePanel.Visible = false
    if UI.Confirm then UI.Confirm.Visible = false end
end

Chat.showProfile = function(p)
    if type(p) ~= "table" then return end
    Chat.hideOverlays()
    hideMessageActions()
    for _, c in ipairs(UI.Profile:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local uid = tonumber(p.uid) or 0
    local function line(order, props)
        props.LayoutOrder = order
        props.BackgroundTransparency = 1
        props.ZIndex = 141
        props.Size = props.Size or UDim2.new(1, 0, 0, 20)
        props.TextXAlignment = Enum.TextXAlignment.Center
        props.TextTruncate = Enum.TextTruncate.AtEnd
        return mk("TextLabel", props, UI.Profile)
    end
    -- v8: foto grande con anillo tipo historia (owners con su imagen especial)
    local pic = mk("ImageLabel", {
        Size = UDim2.fromOffset(86, 86), BackgroundColor3 = THEME.PANEL2,
        BorderSizePixel = 0, Image = Chat.avatarFor(uid, p.name), ScaleType = Enum.ScaleType.Crop,
        LayoutOrder = 1, ZIndex = 141,
    }, UI.Profile)
    corner(pic, 43)
    UI.storyRing(pic, 3)
    if Chat.onlineMap[tostring(uid)] then
        local dot = mk("Frame", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(64, 64),
            BackgroundColor3 = UI.C.online, BorderSizePixel = 0, ZIndex = 142,
        }, pic)
        corner(dot, 9)
        stroke(dot, THEME.PANEL, 3, 0)
    end
    -- nombre + corona si es owner
    local nameRow = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 141,
    }, UI.Profile)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    }, nameRow)
    mk("TextLabel", {
        Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Text = tostring(p.dn or p.name or "?"), TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold,
        TextSize = 19, LayoutOrder = 1, ZIndex = 141,
    }, nameRow)
    if Chat.isOwner(uid, p.name) then
        UI.icon(nameRow, UI.ICON.crown, 18, UI.C.gold, {LayoutOrder = 2, ZIndex = 141})
    end
    line(3, {Text = "@" .. tostring(p.name or "?"), TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 14})
    local tag = Chat.scriptTag(p.script)
    local extra = {}
    if tag then extra[#extra + 1] = "Usa " .. tag end
    if Chat.onlineMap[tostring(uid)] then extra[#extra + 1] = "En línea" end
    if #extra > 0 then
        line(4, {Text = table.concat(extra, "  ·  "), TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 13})
    end
    mk("Frame", {Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 5}, UI.Profile)
    if uid ~= 0 and uid ~= LocalPlayer.UserId then
        local dm = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = UI.C.blue, BorderSizePixel = 0,
            Text = "Enviar mensaje", TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold, TextSize = 15, LayoutOrder = 7, ZIndex = 141,
        }, UI.Profile)
        corner(dm, 12)
        dm.MouseButton1Click:Connect(function()
            Chat.hideOverlays()
            Chat.openChat("private", uid, p.dn or p.name, p.name)
        end)
    end
    local close = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0,
        Text = "Cerrar", TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 14,
        LayoutOrder = 8, ZIndex = 141,
    }, UI.Profile)
    corner(close, 12)
    close.MouseButton1Click:Connect(Chat.hideOverlays)
    UI.Profile.Visible = true
end

Chat.showOnline = function()
    Chat.hideOverlays()
    hideMessageActions()
    for _, c in ipairs(UI.OnlineList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    local names = {}
    for _, n in pairs(Chat.onlineMap) do names[#names + 1] = Chat.maskName(n) end
    table.sort(names)
    UI.OnlineTitle.Text = "En línea con el script (" .. tostring(#names) .. ")"
    for i, n in ipairs(names) do
        local row = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 142,
        }, UI.OnlineList)
        local dot = mk("Frame", {
            Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(6, 12),
            BackgroundColor3 = UI.C.online, BorderSizePixel = 0, ZIndex = 143,
        }, row)
        corner(dot, 5)
        mk("TextLabel", {
            Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(26, 0), BackgroundTransparency = 1,
            Text = n, TextColor3 = THEME.TXT, Font = Enum.Font.GothamMedium, TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 143,
        }, row)
    end
    if #names == 0 then
        mk("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "Sin datos de presencia todavía",
            TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 14, ZIndex = 142,
        }, UI.OnlineList)
    end
    UI.OnlinePanel.Visible = true
end

Chat.refreshPresence = function()
    local ok, data = Chat.fbCall("GET", "presence")
    if not ok or type(data) ~= "table" then return end
    local newest = 0
    for _, v in pairs(data) do
        if type(v) == "table" and tonumber(v.t) and v.t > newest then newest = v.t end
    end
    local map, n = {}, 0
    for uid, v in pairs(data) do
        if type(v) == "table" and tonumber(v.t) and newest - v.t < 60000 then
            n += 1
            map[tostring(uid)] = tostring(v.n or uid)
        end
    end
    Chat.onlineMap = map
    Chat.fbOnline = math.max(n, 1)
    Chat.updateOnline()
end

-- v9: contador = Railway + Firebase, igual que la libreria UI de Yin Yang (FB.UpdateOnline).
-- Del Railway SOLO se lee el onlineCount; no se envia nada ni se muestran sus mensajes.
Chat.RAILWAY_URL = "https://yin-chat.up.railway.app"
Chat.rwOnline = 0
Chat.fbOnline = 0
Chat.rwLastId = 0
Chat.updateOnline = function()
    Chat.onlineCount = (Chat.rwOnline or 0) + (Chat.fbOnline or 0)
    OnlineLabel.Text = tostring(Chat.onlineCount)
    if Chat.view == "chat" then Chat.updateHeader() end
    if Chat.view == "home" then Chat.refreshHome() end
end
Chat.refreshRailwayOnline = function()
    local ok, response = pcall(function()
        return request({Url = Chat.RAILWAY_URL .. "/api/chat/messages?after=" .. tostring(Chat.rwLastId), Method = "GET"})
    end)
    local data = nil
    if ok and type(response) == "table" and type(response.Body) == "string" and response.Body ~= "" then
        local okD, d = pcall(HttpService.JSONDecode, HttpService, response.Body)
        if okD and type(d) == "table" then data = d end
    end
    if data and type(data.messages) == "table" then
        for _, msg in ipairs(data.messages) do
            if type(msg) == "table" and type(msg.id) == "number" and msg.id > Chat.rwLastId then Chat.rwLastId = msg.id end
        end
        if data.onlineCount then
            Chat.rwOnline = tonumber(data.onlineCount) or 0
        else
            -- mismo respaldo que la libreria: jugadores distintos en la respuesta
            local ids, count = {}, 0
            for _, msg in ipairs(data.messages) do
                if type(msg) == "table" and msg.playerId and not ids[tostring(msg.playerId)] then
                    ids[tostring(msg.playerId)] = true
                    count += 1
                end
            end
            Chat.rwOnline = count
        end
    else
        Chat.rwOnline = 0
    end
    Chat.updateOnline()
end

-- ----- Avisos laterales y badge -----
-- v8: tarjeta tipo notificacion de Instagram (foto + nombre + mensaje)
Chat.sideNotif = function(msg, room)
    local isDM = string.sub(room, 1, 3) == "dm_"
    local card = mk("TextButton", {
        Size = UDim2.fromOffset(280, 64),
        BackgroundColor3 = THEME.PANEL2, BackgroundTransparency = 0.04,
        BorderSizePixel = 0, Text = "", AutoButtonColor = true, ZIndex = 201, LayoutOrder = Chat.nextOrder(),
    }, UI.SideHolder)
    corner(card, 18)
    stroke(card, UI.C.line, 1, 0)
    local pic = mk("ImageLabel", {
        Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(11, 11), BackgroundColor3 = THEME.PANEL,
        BorderSizePixel = 0, Image = isDM and Chat.avatarFor(msg.uid, msg.user) or UI.ICON.group,
        ScaleType = Enum.ScaleType.Crop, ZIndex = 202,
    }, card)
    corner(pic, 21)
    mk("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(62, 12), BackgroundTransparency = 1,
        Text = isDM and tostring(msg.dn or msg.user or "Alguien") or ("Chat Global · " .. tostring(msg.dn or msg.user or "Alguien")),
        TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 202,
    }, card)
    mk("TextLabel", {
        Size = UDim2.new(1, -70, 0, 18), Position = UDim2.fromOffset(62, 32), BackgroundTransparency = 1,
        Text = Chat.previewText(msg), TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 202,
    }, card)
    card.MouseButton1Click:Connect(function()
        card:Destroy()
        Chat.openFromNotif(room, msg)
    end)
    task.delay(4, function()
        if card.Parent then card:Destroy() end
    end)
end

Chat.updateBadge = function()
    local total = 0
    for room, n in pairs(Chat.unread) do
        if not Chat.isViewing(room) then total += n end
    end
    if UI.ReopenBadge then
        UI.ReopenBadge.Visible = total > 0
        UI.ReopenBadge.Text = total > 99 and "99+" or tostring(total)
        -- v11: pequeño rebote cuando sube el numero (como WhatsApp)
        if total > (Chat.lastBadgeTotal or 0) and UI.ReopenBadgeScale then
            UI.ReopenBadgeScale.Scale = 1.35
            pcall(function()
                TweenService:Create(UI.ReopenBadgeScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
            end)
        end
    end
    Chat.lastBadgeTotal = total
    if Chat.view == "chat" then Chat.updateHeader() end
end

Chat.onNewMessage = function(room, msg, viewingNow, quiet)
    if type(msg) ~= "table" or tonumber(msg.uid) == LocalPlayer.UserId then return end
    if viewingNow then return end
    if Chat.settings.MutedRooms[room] then return end
    Chat.unread[room] = (Chat.unread[room] or 0) + 1
    local isDM = string.sub(room, 1, 3) == "dm_"
    if not quiet and Chat.settings.SideNotifs and (isDM or Chat.mentionsMe(msg.text) or Chat.isReplyToMe(msg.reply)) then
        Chat.sideNotif(msg, room)
    end
    Chat.updateBadge()
    if Chat.view == "home" then Chat.refreshHome() end
end

-- ----- Layout del chat y header -----
Chat.relayout = function()
    local inChat = Chat.view == "chat"
    local y = 68
    if not inChat then UI.PinBar.Visible = false end
    if UI.PinBar.Visible then
        UI.PinBar.Position = UDim2.fromOffset(14, y)
        y += 46
    end
    UI.SearchBar.Visible = inChat and Chat.searchOpen
    if UI.SearchBar.Visible then
        UI.SearchBar.Position = UDim2.fromOffset(14, y)
        y += 42
    end
    MessageScroll.Position = UDim2.fromOffset(14, y)
    MessageScroll.Size = UDim2.new(1, -28, 1, -(y + 72))
end

Chat.refreshPin = function()
    local pin = Chat.pin
    if Chat.view == "chat" and type(pin) == "table" and pin.text then
        local t = tostring(pin.text)
        if t:match("^%[%[STICKER:") then t = "Sticker" end
        UI.PinText.Text = "<b>" .. Chat.esc(tostring(pin.dn or pin.user or "")) .. "</b>  " .. Chat.esc(t)
        UI.PinBar.Visible = true
    else
        UI.PinBar.Visible = false
    end
    Chat.relayout()
end

Chat.updateHeader = function()
    local inChat = Chat.view == "chat"
    UI.BackButton.Visible = inChat
    UI.HeaderAvatar.Visible = inChat
    UI.SearchBtn.Visible = inChat
    UI.MuteBtn.Visible = inChat
    UI.MoreBtn.Visible = inChat
    UI.PencilBtn.Visible = not inChat
    UI.ChatBg.Visible = inChat and Chat.kind == "global"
    UI.Title.TextTruncate = Enum.TextTruncate.AtEnd
    UI.Subtitle.TextTruncate = Enum.TextTruncate.AtEnd
    if not inChat then
        UI.Title.Position = UDim2.fromOffset(20, 7)
        UI.Title.Size = UDim2.new(1, -240, 0, 26)
        UI.Title.TextSize = 22
        UI.Subtitle.Position = UDim2.fromOffset(20, 33)
        UI.Subtitle.Size = UDim2.new(1, -240, 0, 16)
        UI.Title.Text = "Chats"
        UI.Subtitle.Text = "Neo Hyper"
        return
    end
    UI.Title.TextSize = 19
    UI.Title.Position = UDim2.fromOffset(102, 8)
    UI.Title.Size = UDim2.new(1, -372, 0, 22)
    UI.Subtitle.Position = UDim2.fromOffset(102, 31)
    UI.Subtitle.Size = UDim2.new(1, -372, 0, 16)
    local muted = Chat.settings.MutedRooms[Chat.room] == true
    UI.MuteIcon.Image = muted and UI.ICON.bellOff or UI.ICON.bell
    UI.MoreMute.Text = muted and "Activar notificaciones" or "Silenciar"
    UI.MoreMute.Icon.Image = muted and UI.ICON.bell or UI.ICON.bellOff
    UI.MoreDelete.Visible = Chat.kind == "private"
    if Chat.kind == "global" then
        UI.HeaderAvatar.Image = UI.ICON.group
        UI.HeaderRing.Enabled = true
        UI.HeaderDot.Visible = false
        UI.Title.Text = "Chat Global"
        -- v12: si alguien escribe en el grupo se muestra en el subtitulo (como WhatsApp)
        UI.Subtitle.Text = (Chat.typing and Chat.typingNames and #Chat.typingNames > 0) and Chat.typingText(Chat.typingNames)
            or (tostring(Chat.onlineCount or 0) .. " en línea · Neo Hyper")
    else
        UI.HeaderAvatar.Image = Chat.avatarFor(Chat.target, Chat.targetUser)
        UI.HeaderRing.Enabled = false
        local online = Chat.onlineMap[tostring(Chat.target)] ~= nil
        UI.HeaderDot.Visible = online
        UI.Title.Text = tostring(Chat.targetName or "Jugador")
        if Chat.typing then
            UI.Subtitle.Text = "escribiendo..."
        elseif online then
            UI.Subtitle.Text = "En línea"
        else
            UI.Subtitle.Text = Chat.targetUser and ("@" .. Chat.targetUser) or "Privado"
        end
    end
    local others = 0
    for room, n in pairs(Chat.unread) do
        if room ~= Chat.room then others += n end
    end
    UI.BackCount.Visible = others > 0
    UI.BackCount.Text = others > 99 and "99+" or tostring(others)
end

Chat.applyView = function()
    local inChat = Chat.view == "chat"
    UI.HomeList.Visible = not inChat
    UI.NewChatBar.Visible = not inChat
    MessageScroll.Visible = inChat
    Composer.Visible = inChat
    UI.MoreMenu.Visible = false
    if not inChat then
        EmptyLabel.Visible = false
        ReplyBanner.Visible = false
        StickerPanel.Visible = false
    end
    Chat.refreshPin()
    Chat.updateHeader()
end

-- ----- Pantalla de inicio (lista de chats estilo Instagram) -----
Chat.homeSection = function(order, text)
    local l = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = text,
        TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Bottom, LayoutOrder = order,
    }, UI.HomeList)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 4)}, l)
end

-- Foto redonda con punto verde de "en linea" opcional
Chat.homeAvatar = function(parent, image, size, x, y, online, ring)
    local pic = mk("ImageLabel", {
        Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(x, y),
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0,
        Image = image or "", ScaleType = Enum.ScaleType.Crop, ZIndex = 2,
    }, parent)
    corner(pic, math.floor(size / 2))
    if ring then UI.storyRing(pic, 2.5) end
    if online then
        local d = math.floor(size * 0.26)
        local dot = mk("Frame", {
            Size = UDim2.fromOffset(d, d), Position = UDim2.fromOffset(size - d + 1, size - d + 1),
            BackgroundColor3 = UI.C.online, BorderSizePixel = 0, ZIndex = 3,
        }, pic)
        corner(dot, math.floor(d / 2))
        stroke(dot, THEME.BG, 3, 0)
    end
    return pic
end

Chat.homeRow = function(order, e)
    local unread = tonumber(e.unread) or 0
    if e.pinned then
        -- Grupo fijado: tarjeta destacada arriba de todo
        local card = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = THEME.PANEL, BorderSizePixel = 0,
            Text = "", AutoButtonColor = true, LayoutOrder = order,
        }, UI.HomeList)
        corner(card, 20)
        stroke(card, UI.C.line, 1, 0)
        mk("UIGradient", {
            Rotation = 0,
            Color = ColorSequence.new(Color3.fromRGB(40, 28, 64), Color3.fromRGB(18, 18, 18)),
        }, card)
        Chat.homeAvatar(card, e.image, 60, 13, 13, false, true)
        local titleRow = mk("Frame", {
            Size = UDim2.new(1, -170, 0, 22), Position = UDim2.fromOffset(88, 16), BackgroundTransparency = 1, ZIndex = 2,
        }, card)
        mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
        }, titleRow)
        mk("TextLabel", {
            Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
            Text = e.title, TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 17, LayoutOrder = 1, ZIndex = 2,
        }, titleRow)
        UI.icon(titleRow, UI.ICON.pin, 14, UI.C.gold, {LayoutOrder = 2, ZIndex = 2})
        if e.muted then UI.icon(titleRow, UI.ICON.bellOff, 14, THEME.DIM, {LayoutOrder = 3, ZIndex = 2}) end
        mk("TextLabel", {
            Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(88, 40), BackgroundTransparency = 1,
            Text = e.sub or "", TextColor3 = unread > 0 and THEME.TXT or THEME.DIM,
            Font = unread > 0 and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
        }, card)
        mk("TextLabel", {
            Size = UDim2.new(1, -110, 0, 16), Position = UDim2.fromOffset(88, 59), BackgroundTransparency = 1,
            Text = e.extra or "", TextColor3 = UI.C.online, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2,
        }, card)
        if unread > 0 then
            local b = mk("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0),
                Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = UI.C.blue, BorderSizePixel = 0,
                Text = unread > 99 and "99+" or tostring(unread), TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 3,
            }, card)
            corner(b, 12)
            mk("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, b)
            mk("UISizeConstraint", {MinSize = Vector2.new(24, 24)}, b)
        end
        if e.onClick then card.MouseButton1Click:Connect(e.onClick) end
        return
    end
    -- Fila normal: foto + nombre + "mensaje · tiempo" (como Instagram)
    local btn = mk("TextButton", {
        Size = UDim2.new(1, 0, 0, 80), BackgroundColor3 = THEME.PANEL, BackgroundTransparency = 1,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = order,
    }, UI.HomeList)
    corner(btn, 14)
    btn.MouseEnter:Connect(function() btn.BackgroundTransparency = 0.4 end)
    btn.MouseLeave:Connect(function() btn.BackgroundTransparency = 1 end)
    Chat.homeAvatar(btn, e.image, 64, 8, 8, e.online, false)
    mk("TextLabel", {
        Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(86, 17),
        BackgroundTransparency = 1, Text = e.title or "", TextColor3 = THEME.TXT,
        Font = unread > 0 and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 19,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
    }, btn)
    local sub = e.sub or ""
    if e.time and e.time ~= "" then sub = sub .. " · " .. e.time end
    mk("TextLabel", {
        Size = UDim2.new(1, -150, 0, 20), Position = UDim2.fromOffset(86, 42),
        BackgroundTransparency = 1, Text = sub, TextColor3 = unread > 0 and THEME.TXT or THEME.DIM,
        Font = unread > 0 and Enum.Font.GothamBold or Enum.Font.GothamMedium, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2,
    }, btn)
    if e.muted then
        UI.icon(btn, UI.ICON.bellOff, 16, THEME.DIM, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, unread > 0 and -48 or -16, 0.5, 0), ZIndex = 2})
    end
    if unread > 0 then
        local b = mk("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = UI.C.blue, BorderSizePixel = 0,
            Text = unread > 99 and "99+" or tostring(unread), TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold, TextSize = 12, ZIndex = 3,
        }, btn)
        corner(b, 11)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)}, b)
        mk("UISizeConstraint", {MinSize = Vector2.new(22, 22)}, b)
    elseif e.action then
        -- accion a la derecha (ej. "Abrir") para jugadores sin chat todavia
        local a = mk("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, Text = e.action,
            TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 13, ZIndex = 3,
        }, btn)
        corner(a, 10)
        mk("UIPadding", {PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)}, a)
    end
    if e.onDelete then
        -- v9: boton de opciones (tres puntos) para eliminar el chat
        local opt = UI.iconButton(btn, UI.ICON.more, 30, 18, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, unread > 0 and -50 or -10, 0.5, 0), ZIndex = 4,
        })
        opt.MouseButton1Click:Connect(e.onDelete)
        -- mantener presionada la fila tambien abre "eliminar chat"
        local holdToken = 0
        btn.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            holdToken += 1
            local my = holdToken
            task.delay(0.7, function()
                if holdToken == my and btn.Parent then
                    btn:SetAttribute("SkipClick", true)
                    e.onDelete()
                end
            end)
        end)
        btn.InputEnded:Connect(function() holdToken += 1 end)
    end
    if e.onClick then
        btn.MouseButton1Click:Connect(function()
            if btn:GetAttribute("SkipClick") then btn:SetAttribute("SkipClick", nil) return end
            e.onClick()
        end)
    end
end

-- Texto de vista previa como Instagram ("Tú: hola", "Envió un sticker", ...)
Chat.previewLine = function(p, isGroup)
    if not p then return nil end
    local mine = tonumber(p.uid) == LocalPlayer.UserId
    if p.kind == "sticker" then return mine and "Enviaste un sticker" or ((isGroup and (p.name .. " envió") or "Envió") .. " un sticker") end
    if p.kind == "invite" then return mine and "Enviaste una invitación" or ((isGroup and (p.name .. " envió") or "Envió") .. " una invitación") end
    if mine then return "Tú: " .. p.text end
    return isGroup and (p.name .. ": " .. p.text) or p.text
end

Chat.refreshHome = function(force)
    if Chat.view ~= "home" then return end
    local filter = string.lower(Chat.homeFilter or "")
    local items, sig = {}, {}
    local function matches(e)
        if filter == "" or e.section then return true end
        return string.find(string.lower(tostring(e.title) .. " " .. tostring(e.search or "")), filter, 1, true) ~= nil
    end
    local function add(e)
        if not matches(e) then return end
        items[#items + 1] = e
        sig[#sig + 1] = table.concat({tostring(e.section), tostring(e.title), tostring(e.sub), tostring(e.time), tostring(e.unread), tostring(e.online), tostring(e.muted), tostring(e.extra)}, "|")
    end
    local muted = Chat.settings.MutedRooms
    local g = FIREBASE_ROOM
    local gp = Chat.previews[g]
    -- 1) Grupo fijado
    add({
        pinned = true, title = "Chat Global", search = "global grupo neo hyper",
        sub = Chat.previewLine(gp, true) or "Comunidad Neo Hyper · todos los scripts",
        extra = tostring(Chat.onlineCount or 0) .. " en línea" .. (gp and ("  ·  " .. UI.relTime(gp.ts)) or ""),
        unread = Chat.unread[g] or 0, image = UI.ICON.group, muted = muted[g] == true,
        onClick = function() Chat.openChat("global") end,
    })
    -- 2) Privados recientes (ordenados por ultimo mensaje)
    local dms = {}
    for _, e in ipairs(Chat.settings.RecentDMs) do
        local uid = type(e) == "table" and tonumber(e.uid)
        if uid then
            local room = Chat.dmRoom(uid)
            local p = Chat.previews[room]
            dms[#dms + 1] = {e = e, uid = uid, room = room, p = p, sortTs = (p and p.ts) or tonumber(e.ts) or 0}
        end
    end
    table.sort(dms, function(a, b) return a.sortTs > b.sortTs end)
    local shown = {}
    local dmItems = {}
    for _, d in ipairs(dms) do
        shown[d.uid] = true
        dmItems[#dmItems + 1] = {
            title = tostring(d.e.name or d.e.user or d.uid), search = tostring(d.e.user or ""),
            sub = Chat.previewLine(d.p, false) or (d.e.user and ("@" .. d.e.user) or "Toca para chatear"),
            time = d.p and UI.relTime(d.p.ts) or nil, unread = Chat.unread[d.room] or 0,
            image = Chat.avatarFor(d.uid, d.e.user), muted = muted[d.room] == true,
            online = Chat.onlineMap[tostring(d.uid)] ~= nil,
            onClick = function() Chat.openChat("private", d.uid, d.e.name, d.e.user) end,
            onDelete = function() Chat.askDeleteChat(d.uid, tostring(d.e.name or d.e.user or d.uid)) end,
        }
    end
    if #dmItems > 0 then add({section = "Mensajes"}) end
    for _, e in ipairs(dmItems) do add(e) end
    -- 3) Jugadores del servidor actual
    local others = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and not shown[plr.UserId] then others[#others + 1] = plr end
    end
    if #others > 0 then add({section = "En este servidor"}) end
    for _, plr in ipairs(others) do
        local online = Chat.onlineMap[tostring(plr.UserId)] ~= nil
        add({
            title = plr.DisplayName, search = plr.Name,
            sub = "@" .. plr.Name .. (online and " · usa el chat" or ""),
            image = Chat.avatarFor(plr.UserId, plr.Name), online = online, action = "Escribir",
            onClick = function() Chat.openChat("private", plr.UserId, plr.DisplayName, plr.Name) end,
        })
    end
    -- 4) Busqueda sin resultados de privados: ofrecer abrir chat con ese usuario
    if filter ~= "" then
        add({
            title = "Escribir a @" .. (Chat.homeFilter or ""), search = filter,
            sub = "Abrir un chat privado nuevo", image = UI.ICON.pencil, action = "Abrir",
            onClick = function() Chat.startChatByName() end,
        })
    end
    -- quitar titulos de seccion que quedaron vacios por el filtro
    local clean = {}
    for i, e in ipairs(items) do
        if e.section then
            local nxt = items[i + 1]
            if nxt and not nxt.section and not nxt.pinned then clean[#clean + 1] = e end
        else
            clean[#clean + 1] = e
        end
    end
    local s = table.concat(sig, "\n")
    if not force and s == Chat.homeSig then return end
    Chat.homeSig = s
    for _, c in ipairs(UI.HomeList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
    for i, e in ipairs(clean) do
        if e.section then Chat.homeSection(i, e.section) else Chat.homeRow(i, e) end
    end
end

-- ----- v9: eliminar chat privado (solo de tu lista, como WhatsApp) -----
do
    UI.Confirm = mk("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 160,
    }, Root)
    local box = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(330, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0, ZIndex = 161,
    }, UI.Confirm)
    corner(box, 20)
    mk("UIListLayout", {Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder}, box)
    UI.ConfirmTitle = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = "", TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 18, TextWrapped = true,
        LayoutOrder = 1, ZIndex = 162,
    }, box)
    mk("UIPadding", {PaddingTop = UDim.new(0, 22), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18)}, UI.ConfirmTitle)
    UI.ConfirmBody = mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = "", TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 14, TextWrapped = true,
        LayoutOrder = 2, ZIndex = 162,
    }, box)
    mk("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18)}, UI.ConfirmBody)
    local function sheetButton(text, color, order)
        mk("Frame", {Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = UI.C.line, BorderSizePixel = 0, LayoutOrder = order - 1, ZIndex = 162}, box)
        return mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Text = text, TextColor3 = color,
            Font = Enum.Font.GothamBold, TextSize = 16, LayoutOrder = order, ZIndex = 162,
        }, box)
    end
    UI.ConfirmOk = sheetButton("Eliminar", THEME.DANGER, 4)
    UI.ConfirmCancel = sheetButton("Cancelar", THEME.TXT, 6)
    UI.ConfirmCancel.MouseButton1Click:Connect(function() UI.Confirm.Visible = false end)
    UI.Confirm.MouseButton1Click:Connect(function() UI.Confirm.Visible = false end)
    UI.ConfirmOk.MouseButton1Click:Connect(function()
        UI.Confirm.Visible = false
        local fn = Chat.confirmAction
        Chat.confirmAction = nil
        if fn then fn() end
    end)
end

Chat.askDeleteChat = function(uid, name)
    uid = tonumber(uid)
    if not uid then return end
    UI.ConfirmTitle.Text = "¿Eliminar el chat con " .. tostring(name) .. "?"
    UI.ConfirmBody.Text = "Se quita de tu lista de chats. Si te vuelve a escribir, el chat aparecerá de nuevo."
    Chat.confirmAction = function() Chat.deleteChat(uid) end
    UI.Confirm.Visible = true
end

Chat.deleteChat = function(uid)
    uid = tonumber(uid)
    if not uid then return end
    local room = Chat.dmRoom(uid)
    local list = Chat.settings.RecentDMs
    for i = #list, 1, -1 do
        if type(list[i]) == "table" and tonumber(list[i].uid) == uid then table.remove(list, i) end
    end
    -- lo ultimo que ya existia queda como "visto", asi no vuelve a contar como no leido
    local prev = Chat.previews[room]
    local lastMs = math.max(tonumber(Chat.settings.DMLastSeen[room]) or 0, prev and math.floor((prev.ts or 0) * 1000) or 0)
    Chat.settings.DMLastSeen[room] = lastMs
    Chat.settings.HiddenDMs[tostring(uid)] = lastMs
    Chat.previews[room] = nil
    Chat.unread[room] = nil
    Chat.saveSettings()
    if Chat.view == "chat" and Chat.room == room then
        Chat.goHome()
    else
        Chat.updateBadge()
        Chat.refreshHome(true)
    end
    Chat.flash("Chat eliminado")
end

-- ----- Abrir chats / volver -----
Chat.openChat = function(kind, uid, name, user)
    hideMessageActions()
    cancelReply()
    StickerPanel.Visible = false
    reactionPickerTargetKey = nil
    Chat.hideOverlays()
    if kind == "private" then
        uid = tonumber(uid)
        if not uid or uid == LocalPlayer.UserId then return end
        Chat.kind = "private"
        Chat.room = Chat.dmRoom(uid)
        Chat.target = uid
        Chat.targetName = tostring(name or user or uid)
        Chat.targetUser = user and tostring(user) or nil
        Chat.rememberDM(uid, Chat.targetName, Chat.targetUser, true)
        Chat.settings.HiddenDMs[tostring(uid)] = nil
    else
        Chat.kind = "global"
        Chat.room = FIREBASE_ROOM
        Chat.target, Chat.targetName, Chat.targetUser = nil, nil, nil
    end
    Chat.roomGen += 1
    for _, child in ipairs(MessageScroll:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    table.clear(renderedKeys)
    table.clear(firebaseSeen)
    table.clear(contentSeen)
    table.clear(messageRows)
    table.clear(localReactions)
    table.clear(chatMessages)
    table.clear(Chat.byFbKey)
    table.clear(Chat.pending)
    firebaseInitialLoad = true
    Chat.lastGroup = nil -- v8: reinicia agrupacion y separadores de fecha
    Chat.pin = nil
    Chat.typing = false
    Chat.typingNames = {} -- v12
    Chat.typingKey = ""
    Chat.newBelow = 0
    Chat.refreshTypingPill()
    Chat.refreshNewPill()
    Chat.searchOpen = false
    Chat.searchQuery = ""
    UI.SearchBox.Text = ""
    Chat.unread[Chat.room] = 0
    Chat.view = "chat"
    EmptyLabel.Text = "Cargando chat..."
    EmptyLabel.Visible = true
    Chat.applyView()
    Chat.updateBadge()
    Chat.pollNow = true
end

Chat.goHome = function()
    hideMessageActions()
    cancelReply()
    StickerPanel.Visible = false
    reactionPickerTargetKey = nil
    Chat.hideOverlays()
    Chat.view = "home"
    Chat.roomGen += 1
    Chat.typing = false
    Chat.typingNames = {} -- v12
    Chat.newBelow = 0
    Chat.refreshTypingPill()
    Chat.refreshNewPill()
    Chat.saveSettings()
    Chat.applyView()
    Chat.refreshHome(true)
    Chat.updateBadge()
end

Chat.openFromNotif = function(room, msg)
    open = true
    Surface.Enabled = true
    if UI.Reopen then UI.Reopen.Visible = false end
    if room == FIREBASE_ROOM then
        Chat.openChat("global")
    else
        local uid = tonumber(msg.uid)
        if not uid or uid == LocalPlayer.UserId then return end
        Chat.openChat("private", uid, msg.dn or msg.user, msg.user)
    end
end

Chat.startChatByName = function()
    local raw = tostring(UI.NewChatBox.Text or ""):match("^%s*@?(.-)%s*$") or ""
    if raw == "" then return end
    UI.NewChatGo.Text = "..."
    task.spawn(function()
        local okId, uid = pcall(function() return Players:GetUserIdFromNameAsync(raw) end)
        UI.NewChatGo.Text = "Abrir"
        if not okId or not tonumber(uid) then Chat.flash("No encontré a ese usuario") return end
        if tonumber(uid) == LocalPlayer.UserId then Chat.flash("Ese eres tú") return end
        local okName, realName = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
        local user = (okName and realName) or raw
        UI.NewChatBox.Text = ""
        Chat.openChat("private", uid, user, user)
    end)
end

Chat.sendInvite = function()
    if Chat.view ~= "chat" then return end
    local left = 30 - (os.clock() - Chat.lastInvite)
    if left > 0 then
        Chat.flash("Espera " .. tostring(math.ceil(left)) .. "s para otra invitación")
        return
    end
    Chat.lastInvite = os.clock()
    task.spawn(function()
        local productInfo
        pcall(function() productInfo = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
        sendPayload("invite", {
            t = "invite", place = game.PlaceId, job = game.JobId,
            game = productInfo and productInfo.Name or "Roblox",
            pc = #Players:GetPlayers(), mx = Players.MaxPlayers,
        })
    end)
end

-- ----- Procesar mensajes de la sala abierta -----
Chat.handleRoomData = function(data, room)
    local keys = {}
    for k, v in pairs(data) do
        if type(v) == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    local history = firebaseInitialLoad
    local viewingNow = Chat.isViewing(room)
    local isDM = string.sub(room, 1, 3) == "dm_"
    local maxTs = 0
    for _, k in ipairs(keys) do
        local msg = data[k]
        local tsMs = tonumber(msg.ts)
        if tsMs and tsMs > maxTs then maxTs = tsMs end
        if firebaseSeen[k] then
            -- Ya dibujado: solo actualizar reacciones o quitarlo si viene marcado como borrado.
            local meta = Chat.byFbKey[k]
            if meta then
                if msg.deleted then
                    Chat.removeRow(meta)
                elseif type(msg.text) == "string" and msg.text ~= meta.text and not localDeletedKeys[meta.key] then
                    -- v12: mensaje editado por su autor
                    Chat.rerender(meta, msg.text, true)
                    Chat.applyServerReacts(Chat.byFbKey[k], msg.reacts)
                else
                    Chat.applyServerReacts(meta, msg.reacts)
                end
            end
        else
            firebaseSeen[k] = true
            local pendingMeta = msg.cid and Chat.pending[msg.cid]
            if pendingMeta then
                Chat.pending[msg.cid] = nil
                pendingMeta.fbKey = k
                Chat.byFbKey[k] = pendingMeta
                Chat.setStatus(pendingMeta, "sent")
                Chat.applyServerReacts(pendingMeta, msg.reacts)
            elseif not msg.deleted and (msg.t == "msg" or msg.t == "invite") and type(msg.text) == "string"
                and type(msg.user) == "string" and tonumber(msg.uid) then
                local ts = tonumber(msg.ts)
                ts = ts and math.floor(ts / 1000) or os.time()
                -- En el global, la primera carga ignora stickers viejos (comportamiento original).
                if not (history and not isDM and stickerParse(msg.text)) then
                    processIncoming(msg.user, msg.uid, msg.text, ts, msg.cid or k, type(msg.reply) == "table" and msg.reply or nil, {
                        dn = msg.dn, script = msg.script, scriptImg = msg.scriptImg, ownerTag = msg.ownerTag,
                        fbKey = k, reacts = msg.reacts, t = msg.t, place = msg.place, job = msg.job, edited = msg.edited == true,
                        game = msg.game, pc = msg.pc, mx = msg.mx,
                    })
                end
                if not history then
                    Chat.notified[k] = true
                    Chat.onNewMessage(room, msg, viewingNow)
                end
            end
        end
    end
    -- NeoChat borra el nodo entero: si una clave dibujada ya no esta dentro del rango recibido, se borro.
    -- (Solo entre la primera y la ultima clave recibida: un mensaje propio recien enviado puede ser
    -- mas nuevo que esta respuesta y no debe tomarse como borrado.)
    local minKey, maxKey = keys[1], keys[#keys]
    if minKey then
        local gone = {}
        for k, meta in pairs(Chat.byFbKey) do
            if k >= minKey and k <= maxKey and data[k] == nil then gone[#gone + 1] = meta end
        end
        for _, meta in ipairs(gone) do Chat.removeRow(meta) end
    end
    if keys[#keys] then Chat.setPreview(room, data[keys[#keys]]) end
    if viewingNow and keys[#keys] then
        Chat.lastSeenKey[room] = keys[#keys]
        if isDM and maxTs > (tonumber(Chat.settings.DMLastSeen[room]) or 0) then
            Chat.settings.DMLastSeen[room] = maxTs
            Chat.dirty = true
        end
    end
end

-- ----- Revisar salas que no estan abiertas (badges y avisos) -----
Chat.scanRoom = function(room, data, isDM)
    local keys = {}
    for k, v in pairs(data) do
        if type(v) == "table" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    if #keys == 0 then return end
    Chat.setPreview(room, data[keys[#keys]])
    local fresh = {}
    if isDM then
        local seen = tonumber(Chat.settings.DMLastSeen[room]) or 0
        for _, k in ipairs(keys) do
            local m = data[k]
            if not Chat.notified[k] and (tonumber(m.ts) or 0) > seen and tonumber(m.uid) ~= LocalPlayer.UserId
                and (m.t == "msg" or m.t == "invite") then
                Chat.notified[k] = true
                fresh[#fresh + 1] = m
            end
        end
    else
        local base = Chat.lastSeenKey[room]
        if not base then
            Chat.lastSeenKey[room] = keys[#keys]
            return
        end
        for _, k in ipairs(keys) do
            local m = data[k]
            if k > base and not Chat.notified[k] and (m.t == "msg" or m.t == "invite") then
                Chat.notified[k] = true
                fresh[#fresh + 1] = m
            end
        end
    end
    -- Cuenta todos como no leidos, pero en privados solo muestra 1 tarjeta (la del ultimo).
    for i, m in ipairs(fresh) do
        local quiet = isDM and i < #fresh
        Chat.onNewMessage(room, m, false, quiet)
    end
end

Chat.watchTick = function(rr)
    local function isOpenRoom(room) return Chat.view == "chat" and Chat.room == room end
    -- 1) Global (si no esta abierto)
    if not isOpenRoom(FIREBASE_ROOM) then
        local ok, data = Chat.fbCall("GET", "chat/" .. FIREBASE_ROOM .. "/messages", nil, "orderBy=%22$key%22&limitToLast=20")
        if ok and type(data) == "table" then Chat.scanRoom(FIREBASE_ROOM, data, false) end
    end
    -- 2) Inbox: quien me escribio por privado
    if Chat.inboxOk then
        local ok, data, code = Chat.fbCall("GET", "inbox/" .. tostring(LocalPlayer.UserId))
        if code == 401 or code == 403 then
            Chat.inboxOk = false
        elseif ok and type(data) == "table" then
            for sender, e in pairs(data) do
                local uid = type(e) == "table" and (tonumber(e.uid) or tonumber(sender))
                local hiddenAt = uid and tonumber(Chat.settings.HiddenDMs[tostring(uid)])
                if hiddenAt and (tonumber(e.ts) or 0) > hiddenAt then
                    -- v9: chat eliminado pero llego un mensaje nuevo -> vuelve a aparecer (como WhatsApp)
                    Chat.settings.HiddenDMs[tostring(uid)] = nil
                    hiddenAt = nil
                    Chat.dirty = true
                end
                if uid and uid ~= LocalPlayer.UserId and not hiddenAt then
                    local room = Chat.dmRoom(uid)
                    local ets = tonumber(e.ts) or 0
                    Chat.rememberDM(uid, e.dn or e.user, e.user, false)
                    Chat.setPreview(room, {dn = e.dn, user = e.user, uid = uid, text = e.text, ts = ets}, true)
                    if ets > (tonumber(Chat.settings.DMLastSeen[room]) or 0) and not isOpenRoom(room) then
                        Chat.checkQueue[room] = true
                    end
                end
            end
        end
    end
    -- 3) Privados: los marcados por el inbox + 2 recientes por vuelta
    local toCheck = {}
    for room in pairs(Chat.checkQueue) do toCheck[#toCheck + 1] = room end
    table.clear(Chat.checkQueue)
    local list = Chat.settings.RecentDMs
    if #list > 0 then
        for i = 0, 1 do
            local e = list[((rr * 2 + i) % #list) + 1]
            local room = type(e) == "table" and Chat.dmRoom(e.uid)
            if room and not table.find(toCheck, room) then toCheck[#toCheck + 1] = room end
        end
    end
    for _, room in ipairs(toCheck) do
        if not isOpenRoom(room) then
            local ok, data = Chat.fbCall("GET", "chat/" .. room .. "/messages", nil, "orderBy=%22$key%22&limitToLast=10")
            if ok and type(data) == "table" then Chat.scanRoom(room, data, true) end
        end
    end
    Chat.updateBadge()
    if Chat.view == "home" then Chat.refreshHome() end
end

-- ----- Conexiones de los widgets nuevos -----
UI.BackButton.MouseButton1Click:Connect(function() Chat.goHome() end)
UI.SearchBtn.MouseButton1Click:Connect(function()
    Chat.searchOpen = not Chat.searchOpen
    if not Chat.searchOpen then UI.SearchBox.Text = "" end
    Chat.relayout()
    if Chat.searchOpen then task.defer(function() Chat.focusBox(UI.SearchBox, nil) end) end
end)
UI.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    Chat.searchQuery = string.lower(UI.SearchBox.Text or "")
    Chat.applySearchAll()
end)
Chat.toggleMute = function()
    local room = Chat.room
    local muted = not Chat.settings.MutedRooms[room]
    Chat.settings.MutedRooms[room] = muted or nil
    Chat.saveSettings()
    Chat.updateHeader()
    Chat.flash(muted and "Chat silenciado" or "Notificaciones activadas")
end
UI.MuteBtn.MouseButton1Click:Connect(function() Chat.toggleMute() end)
UI.OnlineButton.MouseButton1Click:Connect(function() Chat.showOnline() end)
UI.PinClose.MouseButton1Click:Connect(function()
    if not Chat.meIsOwner then return end
    local room = Chat.room
    Chat.pin = nil
    Chat.refreshPin()
    task.spawn(function() Chat.fbCall("DELETE", "chat/" .. room .. "/pin") end)
end)
UI.NewChatGo.MouseButton1Click:Connect(function() Chat.startChatByName() end)
UI.NewChatBox.FocusLost:Connect(function(enterPressed) if enterPressed then Chat.startChatByName() end end)
UI.InviteButton.MouseButton1Click:Connect(function() Chat.sendInvite() end)
MessageBox:GetPropertyChangedSignal("Text"):Connect(function()
    -- "escribiendo..." en privados y (v12) tambien en el global; mismo nodo typing/<sala>/<uid> que NeoChat
    -- (se agrega "n" = usuario para poder mostrar quien escribe en el grupo)
    if Chat.view ~= "chat" or MessageBox.Text == "" or Chat.editing then return end
    if os.clock() - Chat.lastTypingPush < 2.5 then return end
    Chat.lastTypingPush = os.clock()
    local room = Chat.room
    task.spawn(function()
        Chat.fbCall("PUT", "typing/" .. room .. "/" .. tostring(LocalPlayer.UserId), {t = {[".sv"] = "timestamp"}, n = LocalPlayer.Name})
    end)
end)
Players.PlayerAdded:Connect(function() if Chat.view == "home" then Chat.refreshHome() end end)
Players.PlayerRemoving:Connect(function() if Chat.view == "home" then task.defer(Chat.refreshHome) end end)

-- ----- v11 FIX pantalla blanca al escribir (celular) -----
-- Los TextBox dentro de la SurfaceGui (pantalla 3D) abren en Android el editor blanco de pantalla
-- completa; los de ScreenGui (chat de Roblox, libreria UI) no. En pantallas tactiles, tocar un
-- cuadro de texto del chat abre esta barra 2D arriba de todo (visible sobre el teclado) y lo que
-- se escribe se copia al cuadro real del chat.
do
    -- v12: barra compacta (una sola pildora fina y semitransparente)
    UI.Proxy = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
        Size = UDim2.new(0.62, 0, 0, 50),
        BackgroundColor3 = Color3.fromRGB(16, 16, 20), BackgroundTransparency = 0.06,
        BorderSizePixel = 0, Visible = false, ZIndex = 300,
    }, ScreenGui)
    mk("UISizeConstraint", {MinSize = Vector2.new(320, 50), MaxSize = Vector2.new(640, 50)}, UI.Proxy)
    corner(UI.Proxy, 25)
    local ps = mk("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.2, Transparency = 0.35}, UI.Proxy)
    mk("UIGradient", {Rotation = 0, Color = ColorSequence.new(UI.C.ownA, UI.C.ownB)}, ps)
    -- contexto a la izquierda: "Global", "↩ Nick", "@Nick", "Editando"
    UI.ProxyHint = mk("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.fromOffset(60, 32), BackgroundColor3 = THEME.PANEL2, BorderSizePixel = 0,
        Text = "", TextColor3 = THEME.TXT, Font = Enum.Font.GothamBold, TextSize = 13,
        TextTruncate = Enum.TextTruncate.AtEnd, Visible = false, ZIndex = 301,
    }, UI.Proxy)
    corner(UI.ProxyHint, 16)
    UI.ProxyBox = mk("TextBox", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
        Size = UDim2.new(1, -66, 0, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
        Text = "", PlaceholderText = "Mensaje...", PlaceholderColor3 = THEME.DIM, TextColor3 = THEME.TXT,
        Font = Enum.Font.GothamMedium, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false, ZIndex = 302,
    }, UI.Proxy)
    UI.ProxySend = mk("ImageButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(38, 38), BackgroundColor3 = UI.C.blue,
        BorderSizePixel = 0, Image = "rbxassetid://132362297660069", ScaleType = Enum.ScaleType.Fit, ZIndex = 302,
    }, UI.Proxy)
    corner(UI.ProxySend, 19)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9)}, UI.ProxySend)
end

Chat.proxy = {}
Chat.closeProxy = function()
    UI.Proxy.Visible = false
    Chat.proxy.target = nil
    Chat.proxy.submit = nil
end
-- Coloca la etiqueta de contexto y ajusta el ancho del cuadro de texto
Chat.layoutProxy = function(hint, hasSend)
    local left = 14
    if hint then
        local w = TextService:GetTextSize(hint, 13, Enum.Font.GothamBold, Vector2.new(400, 40)).X + 22
        w = math.clamp(w, 52, 150)
        UI.ProxyHint.Text = hint
        UI.ProxyHint.Size = UDim2.fromOffset(w, 32)
        UI.ProxyHint.Visible = true
        left = 8 + w + 8
    else
        UI.ProxyHint.Visible = false
    end
    UI.ProxySend.Visible = hasSend
    UI.ProxyBox.Position = UDim2.new(0, left, 0.5, 0)
    UI.ProxyBox.Size = UDim2.new(1, -(left + (hasSend and 52 or 14)), 0, 36)
end
Chat.openProxy = function(target, submit)
    Chat.proxy.target = target
    Chat.proxy.submit = submit
    Chat.proxy.token = (Chat.proxy.token or 0) + 1
    UI.ProxyBox.PlaceholderText = target.PlaceholderText ~= "" and target.PlaceholderText or "Escribir..."
    UI.ProxyBox.Text = target.Text
    local hint = nil
    if target == MessageBox then
        if Chat.editing then
            hint = "Editando"
        elseif pendingReply then
            hint = "↩ " .. tostring(pendingReply.user or pendingReply.name or "")
        elseif Chat.kind == "private" then
            hint = "@" .. tostring(Chat.targetUser or Chat.targetName or "")
        else
            hint = "Global"
        end
    end
    Chat.layoutProxy(hint, submit ~= nil)
    UI.Proxy.Visible = true
    task.defer(function() pcall(function() UI.ProxyBox:CaptureFocus() end) end)
end
-- Enfoca un cuadro de texto del chat: en tactil por la barra 2D, en PC directo
Chat.focusBox = function(box, submit)
    if Chat.useProxy and Chat.useProxy() then
        Chat.openProxy(box, submit)
    else
        pcall(function() box:CaptureFocus() end)
    end
end
Chat.submitProxy = function()
    local submit = Chat.proxy.submit
    if submit then submit() end
    if Chat.proxy.target == MessageBox then
        -- sigue escribiendo como en WhatsApp: la barra queda abierta y vacia
        UI.ProxyBox.Text = ""
        task.defer(function() pcall(function() UI.ProxyBox:CaptureFocus() end) end)
    else
        Chat.closeProxy()
    end
end
UI.ProxyBox:GetPropertyChangedSignal("Text"):Connect(function()
    local target = Chat.proxy.target
    if not target then return end
    local t = UI.ProxyBox.Text
    if target == MessageBox and #t > CONFIG.MAX_CHAR then
        t = t:sub(1, CONFIG.MAX_CHAR)
        UI.ProxyBox.Text = t
    end
    if target.Text ~= t then target.Text = t end
end)
UI.ProxyBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then
        Chat.submitProxy()
        return
    end
    -- se toco afuera: cerrar (con un respiro para que el boton enviar alcance a registrar el toque)
    local my = Chat.proxy.token
    task.delay(0.25, function()
        if Chat.proxy.token == my and not UI.ProxyBox:IsFocused() then Chat.closeProxy() end
    end)
end)
UI.ProxySend.MouseButton1Click:Connect(function()
    Chat.proxy.token = (Chat.proxy.token or 0) + 1
    Chat.submitProxy()
end)

-- Capa invisible sobre cada cuadro de texto del chat: en tactil abre la barra 2D en vez del TextBox 3D
Chat.useProxy = function()
    local ok, touch = pcall(function() return UserInputService.TouchEnabled end)
    return ok and touch == true
end
Chat.bindProxy = function(box, submit)
    local catcher = mk("TextButton", {
        Name = "ProxyCatcher", BackgroundTransparency = 1, Text = "",
        AnchorPoint = box.AnchorPoint, Position = box.Position, Size = box.Size,
        ZIndex = (box.ZIndex or 1) + 5, Visible = Chat.useProxy(),
    }, box.Parent)
    box:GetPropertyChangedSignal("Visible"):Connect(function() catcher.Visible = box.Visible and Chat.useProxy() end)
    box:GetPropertyChangedSignal("Position"):Connect(function() catcher.Position = box.Position end)
    box:GetPropertyChangedSignal("Size"):Connect(function() catcher.Size = box.Size end)
    catcher.MouseButton1Click:Connect(function() Chat.openProxy(box, submit) end)
    return catcher
end
Chat.bindProxy(MessageBox, function() sendText() end)
Chat.bindProxy(UI.SearchBox, nil)
Chat.bindProxy(UI.NewChatBox, function() Chat.startChatByName() end)
Chat.bindProxy(AddStickerInput, nil)

-- =====================================================================
-- ===== v12: editar, escribiendo..., mensajes nuevos, doble toque, Discord, superposiciones =====
-- =====================================================================

-- Hora del servidor estimada (corrige el reloj del celular con la respuesta de presence)
Chat.serverNowMs = function()
    return os.time() * 1000 + (Chat.clockSkew or 0)
end

-- ----- Editar mensaje propio -----
Chat.rerender = function(meta, newText, edited)
    if not meta or not meta.row then return meta end
    local reacts = localReactions[meta.key]
    meta.row:Destroy()
    renderedKeys[meta.key] = nil
    messageRows[meta.key] = nil
    local nm = renderMessage(meta.name, meta.uid, newText, meta.ts, meta.id, meta.reply, {
        order = meta.order, firstInGroup = meta.firstInGroup, dn = meta.dn, fbKey = meta.fbKey,
        script = meta.script, scriptImg = meta.scriptImg, t = meta.t, edited = edited, state = meta.state,
    })
    if nm and reacts then
        localReactions[nm.key] = reacts
        refreshReactionChips(nm)
    end
    return nm
end

Chat.startEdit = function(meta)
    if not meta or not meta.fbKey then return end
    cancelReply()
    Chat.editing = meta
    UI.ReplyTitle.Text = "<b>Editando mensaje</b>"
    ReplyLabel.Text = tostring(meta.text or "")
    ReplyBanner.Visible = true
    MessageBox.Text = tostring(meta.text or "")
    Chat.refreshTypingPill()
    Chat.focusBox(MessageBox, function() sendText() end)
end

Chat.submitEdit = function(newText)
    local meta = Chat.editing
    cancelReply()
    if not meta or not meta.fbKey or newText == meta.text then return end
    local room, old, oldEdited = Chat.room, meta.text, meta.edited
    Chat.rerender(meta, newText, true) -- se ve al instante
    task.spawn(function()
        local ok, _, code = Chat.fbCall("PATCH", "chat/" .. room .. "/messages/" .. meta.fbKey, {text = newText, edited = true})
        if not ok then
            Chat.flash("No se pudo editar (código " .. tostring(code) .. ")")
            local cur = Chat.byFbKey[meta.fbKey]
            if cur and room == Chat.room then Chat.rerender(cur, old, oldEdited) end
        end
    end)
end

-- ----- "escribiendo..." -----
Chat.typingText = function(names)
    names = names or {}
    if #names == 0 then return "" end
    if Chat.kind == "private" then return "escribiendo..." end
    if #names == 1 then return names[1] .. " está escribiendo..." end
    if #names == 2 then return names[1] .. " y " .. names[2] .. " están escribiendo..." end
    return #names .. " personas están escribiendo..."
end

do
    UI.TypingPill = mk("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -72),
        Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = THEME.PANEL2, BackgroundTransparency = 0.05, BorderSizePixel = 0,
        Visible = false, ZIndex = 70,
    }, Root)
    corner(UI.TypingPill, 15)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 14)}, UI.TypingPill)
    mk("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, UI.TypingPill)
    local dots = mk("Frame", {Size = UDim2.fromOffset(26, 10), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 71}, UI.TypingPill)
    UI.TypingDots = {}
    for i = 1, 3 do
        local d = mk("Frame", {
            Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset((i - 1) * 9, 2),
            BackgroundColor3 = THEME.TXT, BorderSizePixel = 0, ZIndex = 72,
        }, dots)
        corner(d, 3)
        UI.TypingDots[i] = d
    end
    UI.TypingLabel = mk("TextLabel", {
        Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Text = "", TextColor3 = THEME.DIM, Font = Enum.Font.GothamMedium, TextSize = 14, LayoutOrder = 2, ZIndex = 71,
    }, UI.TypingPill)
    -- animacion de los puntitos (solo trabaja mientras la pildora se ve)
    task.spawn(function()
        local t = 0
        while ScreenGui.Parent do
            if UI.TypingPill.Visible then
                t += 1
                for i, d in ipairs(UI.TypingDots) do
                    local up = ((t + (3 - i)) % 3) == 0
                    d.Position = UDim2.fromOffset((i - 1) * 9, up and 0 or 3)
                    d.BackgroundTransparency = up and 0 or 0.55
                end
            end
            task.wait(0.18)
        end
    end)
end

Chat.refreshTypingPill = function()
    local names = Chat.typingNames or {}
    local show = Chat.view == "chat" and #names > 0 and not Chat.editing
    UI.TypingPill.Visible = show
    if show then
        UI.TypingLabel.Text = Chat.kind == "private" and (tostring(Chat.targetUser or Chat.targetName or "") .. " está escribiendo...") or Chat.typingText(names)
        UI.TypingPill.Position = UDim2.new(0, 16, 1, ReplyBanner.Visible and -136 or -72)
    end
end

-- ----- "N mensajes nuevos" cuando estas leyendo arriba -----
Chat.isNearBottom = function()
    local ok, near = pcall(function()
        local win = MessageScroll.AbsoluteWindowSize or MessageScroll.AbsoluteSize
        return MessageScroll.CanvasPosition.Y + win.Y >= MessageScroll.AbsoluteCanvasSize.Y - 140
    end)
    return (not ok) or near == true
end

do
    UI.NewPill = mk("TextButton", {
        AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76),
        Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = UI.C.blue, BorderSizePixel = 0, Text = "", AutoButtonColor = true,
        Visible = false, ZIndex = 75,
    }, Root)
    corner(UI.NewPill, 18)
    mk("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}, UI.NewPill)
    UI.NewPillLabel = mk("TextLabel", {
        Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Text = "", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 76,
    }, UI.NewPill)
end

Chat.refreshNewPill = function()
    local n = Chat.newBelow or 0
    UI.NewPill.Visible = Chat.view == "chat" and n > 0
    if n > 0 then
        UI.NewPillLabel.Text = "↓  " .. (n == 1 and "1 mensaje nuevo" or (n .. " mensajes nuevos"))
        UI.NewPill.Position = UDim2.new(0.5, 0, 1, ReplyBanner.Visible and -140 or -76)
    end
end
UI.NewPill.MouseButton1Click:Connect(function()
    Chat.newBelow = 0
    Chat.refreshNewPill()
    scrollBottom()
end)
MessageScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if (Chat.newBelow or 0) > 0 and Chat.isNearBottom() then
        Chat.newBelow = 0
        Chat.refreshNewPill()
    end
end)

-- ----- Doble toque = me gusta (como Instagram) -----
Chat.likedByMe = {}
Chat.heartPop = function(meta)
    local host = meta.content or meta.row
    if not host or not host.Parent then return end
    local heart = mk("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(meta.isMe and 1 or 0, meta.isMe and -60 or 60, 0.5, 0),
        Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, Text = "❤️",
        TextSize = 54, Font = Enum.Font.GothamBold, ZIndex = 20,
    }, meta.row)
    local sc = mk("UIScale", {Scale = 0.2}, heart)
    pcall(function()
        TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.15}):Play()
    end)
    task.delay(0.55, function()
        pcall(function()
            TweenService:Create(heart, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(sc, TweenInfo.new(0.3), {Scale = 0.6}):Play()
        end)
        task.delay(0.35, function() if heart.Parent then heart:Destroy() end end)
    end)
end
Chat.doubleTapLike = function(meta)
    if not meta or not meta.row or not meta.row.Parent or localDeletedKeys[meta.key] then return end
    Chat.heartPop(meta)
    if Chat.likedByMe[meta.key] then return end -- un solo like tuyo por mensaje
    Chat.likedByMe[meta.key] = true
    addLocalReaction(meta, "❤️")
end

-- ----- Invitaciones de Discord -----
Chat.discordCache = {}
Chat.discordWait = {}
Chat.discordCode = function(text)
    text = tostring(text or "")
    return text:match("discord%.gg/([%w%-]+)") or text:match("discord%.com/invite/([%w%-]+)")
        or text:match("discordapp%.com/invite/([%w%-]+)")
end
-- API publica de Discord: GET /invites/{code}?with_counts=true (nombre, icono, miembros, en linea)
Chat.fetchDiscord = function(code, cb)
    local cached = Chat.discordCache[code]
    if cached == "pending" then table.insert(Chat.discordWait[code], cb) return end
    if cached ~= nil then cb(cached) return end
    Chat.discordCache[code] = "pending"
    Chat.discordWait[code] = {cb}
    task.spawn(function()
        local data = false
        pcall(function()
            local res = request({Url = "https://discord.com/api/v10/invites/" .. code .. "?with_counts=true", Method = "GET"})
            local okD, d = pcall(HttpService.JSONDecode, HttpService, res and res.Body or "")
            if okD and type(d) == "table" and type(d.guild) == "table" then
                data = {
                    name = tostring(d.guild.name or "Servidor de Discord"), id = tostring(d.guild.id or ""),
                    icon = d.guild.icon, members = tonumber(d.approximate_member_count),
                    online = tonumber(d.approximate_presence_count),
                }
                -- icono: se descarga y se usa como asset local (necesita writefile + getcustomasset)
                local gca = getcustomasset or getsynasset
                if type(d.guild.icon) == "string" and writefile and gca then
                    pcall(function()
                        local r = request({Url = ("https://cdn.discordapp.com/icons/%s/%s.png?size=128"):format(data.id, d.guild.icon), Method = "GET"})
                        if r and type(r.Body) == "string" and #r.Body > 100 then
                            local fname = "NeoChat_dc_" .. data.id .. ".png"
                            writefile(fname, r.Body)
                            data.iconAsset = gca(fname)
                        end
                    end)
                end
            end
        end)
        Chat.discordCache[code] = data
        for _, f in ipairs(Chat.discordWait[code] or {}) do pcall(f, data) end
        Chat.discordWait[code] = nil
    end)
end

Chat.discordCard = function(parent, code, isMe)
    local BLURPLE = Color3.fromRGB(88, 101, 242)
    local card = mk("Frame", {
        Size = UDim2.fromOffset(310, 142), BackgroundColor3 = Color3.fromRGB(43, 45, 49),
        BorderSizePixel = 0, LayoutOrder = 3,
    }, parent)
    corner(card, 16)
    stroke(card, BLURPLE, 1.2, 0.35)
    mk("TextLabel", {
        Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(14, 10), BackgroundTransparency = 1,
        Text = isMe and "INVITASTE A UN SERVIDOR DE DISCORD" or "TE INVITARON A UN SERVIDOR DE DISCORD",
        TextColor3 = Color3.fromRGB(181, 186, 193), Font = Enum.Font.GothamBlack, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    local iconBox = mk("Frame", {
        Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(14, 34),
        BackgroundColor3 = BLURPLE, BorderSizePixel = 0,
    }, card)
    corner(iconBox, 16)
    local initials = mk("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 18,
    }, iconBox)
    local iconImg = mk("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop, ZIndex = 2,
    }, iconBox)
    corner(iconImg, 16)
    local nameLbl = mk("TextLabel", {
        Size = UDim2.new(1, -96, 0, 22), Position = UDim2.fromOffset(80, 36), BackgroundTransparency = 1,
        Text = "Cargando...", TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    local statsLbl = mk("TextLabel", {
        Size = UDim2.new(1, -96, 0, 18), Position = UDim2.fromOffset(80, 62), BackgroundTransparency = 1,
        Text = "discord.gg/" .. code, RichText = true, TextColor3 = Color3.fromRGB(181, 186, 193),
        Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, card)
    local join = mk("TextButton", {
        Size = UDim2.new(1, -28, 0, 36), Position = UDim2.fromOffset(14, 96),
        BackgroundColor3 = Color3.fromRGB(36, 128, 70), BorderSizePixel = 0, Text = "Unirse (copiar link)",
        TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBold, TextSize = 14, AutoButtonColor = true,
    }, card)
    corner(join, 8)
    join.MouseButton1Click:Connect(function()
        local link = "https://discord.gg/" .. code
        local copied = pcall(function()
            if setclipboard then setclipboard(link) elseif toclipboard then toclipboard(link) else error("sin portapapeles") end
        end)
        Chat.flash(copied and "Link de Discord copiado · pegalo en Discord o en tu navegador" or link)
    end)
    Chat.fetchDiscord(code, function(d)
        if not card.Parent then return end
        if not d then
            nameLbl.Text = "Invitación no válida o expirada"
            nameLbl.TextColor3 = Color3.fromRGB(181, 186, 193)
            initials.Text = "?"
            join.BackgroundColor3 = THEME.PANEL2
            return
        end
        nameLbl.Text = d.name
        local ini = ""
        for w in d.name:gmatch("%S+") do
            if #ini < 2 then ini = ini .. w:sub(1, 1):upper() end
        end
        initials.Text = ini
        if d.iconAsset then iconImg.Image = d.iconAsset end
        local parts = {}
        if d.online then parts[#parts + 1] = '<font color="#23A55A">●</font> ' .. d.online .. " en línea" end
        if d.members then parts[#parts + 1] = '<font color="#80848E">●</font> ' .. d.members .. " miembros" end
        if #parts > 0 then statsLbl.Text = table.concat(parts, "   ") end
    end)
    return card
end

-- ----- Que ningun boton de otros juegos quede encima del chat -----
-- La pantalla 3D (SurfaceGui) siempre se dibuja debajo de las ScreenGui del juego. Mientras el chat
-- esta abierto, se ocultan solo los elementos del juego que se superponen con el chat y se
-- restauran cuando dejan de superponerse o se cierra el chat. (CoreGui de Roblox no se puede tocar.)
Chat.overlap = {hidden = {}}
Chat.chatScreenRect = function()
    local cam = workspace.CurrentCamera
    if not cam or not Part then return nil end
    local x1, y1, x2, y2 = math.huge, math.huge, -math.huge, -math.huge
    for _, sx in ipairs({-0.5, 0.5}) do
        for _, sy in ipairs({-0.5, 0.5}) do
            local wp = (Part.CFrame * CFrame.new(Part.Size.X * sx, Part.Size.Y * sy, 0)).Position
            local v = cam:WorldToViewportPoint(wp)
            x1, y1 = math.min(x1, v.X), math.min(y1, v.Y)
            x2, y2 = math.max(x2, v.X), math.max(y2, v.Y)
        end
    end
    return x1, y1, x2, y2
end
Chat.restoreOverlaps = function()
    for obj in pairs(Chat.overlap.hidden) do
        if obj.Parent and obj.Visible == false then obj.Visible = true end
    end
    table.clear(Chat.overlap.hidden)
end
Chat.OVERLAP_SKIP = {TouchGui = true, Freecam = true}
Chat.scanOverlaps = function()
    if not open or not Surface.Enabled then Chat.restoreOverlaps() return end
    local x1, y1, x2, y2 = Chat.chatScreenRect()
    if not x1 then return end
    local inset = 0
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset().Y end)
    local vp = workspace.CurrentCamera.ViewportSize
    local still = {}
    local function check(obj, depth, offsetY)
        if not obj:IsA("GuiObject") then return end
        if not obj.Visible and not Chat.overlap.hidden[obj] then return end
        local p, sz = obj.AbsolutePosition, obj.AbsoluteSize
        local ox1, oy1 = p.X, p.Y + offsetY
        if not (ox1 < x2 and ox1 + sz.X > x1 and oy1 < y2 and oy1 + sz.Y > y1) then return end
        local big = sz.X * sz.Y > vp.X * vp.Y * 0.35
        if big then
            -- contenedor grande (HUD a pantalla completa): se revisan sus hijos, nunca se oculta entero
            if depth < 4 then
                for _, c in ipairs(obj:GetChildren()) do check(c, depth + 1, offsetY) end
            end
            return
        end
        still[obj] = true
        if obj.Visible then
            obj.Visible = false
            Chat.overlap.hidden[obj] = true
        end
    end
    for _, sg in ipairs(PlayerGui:GetChildren()) do
        if sg:IsA("ScreenGui") and sg ~= ScreenGui and sg.Enabled and not Chat.OVERLAP_SKIP[sg.Name] then
            local offsetY = sg.IgnoreGuiInset and 0 or inset
            for _, c in ipairs(sg:GetChildren()) do check(c, 0, offsetY) end
        end
    end
    for obj in pairs(Chat.overlap.hidden) do
        if not still[obj] then
            if obj.Parent and obj.Visible == false then obj.Visible = true end
            Chat.overlap.hidden[obj] = nil
        end
    end
end
task.spawn(function()
    while ScreenGui.Parent do
        pcall(Chat.scanOverlaps)
        task.wait(0.4)
    end
    pcall(Chat.restoreOverlaps)
end)

-- ----- v8: conexiones del rediseño -----
UI.EmojiButton.MouseButton1Click:Connect(function()
    reactionPickerTargetKey = nil
    StickerPanel.Visible = not (StickerPanel.Visible and EmojiGrid.Visible)
    if StickerPanel.Visible then showStickerTab(false, true) end
end)
UI.MoreBtn.MouseButton1Click:Connect(function()
    UI.MoreMenu.Visible = not UI.MoreMenu.Visible
end)
UI.MoreOnline.MouseButton1Click:Connect(function()
    UI.MoreMenu.Visible = false
    Chat.showOnline()
end)
UI.MoreMute.MouseButton1Click:Connect(function()
    UI.MoreMenu.Visible = false
    Chat.toggleMute()
end)
UI.MoreDelete.MouseButton1Click:Connect(function()
    UI.MoreMenu.Visible = false
    if Chat.kind == "private" and Chat.target then
        Chat.askDeleteChat(Chat.target, tostring(Chat.targetName or Chat.target))
    end
end)
UI.MoreHome.MouseButton1Click:Connect(function()
    UI.MoreMenu.Visible = false
    Chat.goHome()
end)
UI.PencilBtn.MouseButton1Click:Connect(function()
    Chat.focusBox(UI.NewChatBox, function() Chat.startChatByName() end)
end)
-- Buscador del inicio: filtra la lista mientras escribes
UI.NewChatBox:GetPropertyChangedSignal("Text"):Connect(function()
    local t = tostring(UI.NewChatBox.Text or ""):match("^%s*@?(.-)%s*$") or ""
    Chat.homeFilter = t
    UI.NewChatGo.Visible = t ~= ""
    Chat.refreshHome()
end)
-- Contador de caracteres solo cerca del limite
MessageBox:GetPropertyChangedSignal("Text"):Connect(function()
    CharLabel.Visible = #MessageBox.Text > CONFIG.MAX_CHAR - 100
end)

-- ===== Emoji data =====
local EMOJI_LIST = {
    "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
    "😇", "🥰", "😍", "🤩", "😘", "😗", "☺️", "😚", "😙", "🥲", "😋", "😛",
    "😜", "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑",
    "😶", "😶‍🌫️", "😏", "😒", "🙄", "😬", "😮‍💨", "🤥", "😌", "😔", "😪", "🤤",
    "😴", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "🥴", "😵", "😵‍💫",
    "🤯", "🤠", "🥳", "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "☹️", "😮",
    "😯", "😲", "😳", "🥺", "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱",
    "😖", "😣", "😞", "😓", "😩", "😫", "🥱", "😤", "😡", "😠", "🤬", "😈",
    "👿", "💀", "☠️", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖", "😺",
    "😸", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "🙈", "🙉", "🙊", "💋",
    "💌", "💘", "💝", "💖", "💗", "💓", "💞", "💕", "💟", "❣️", "💔", "❤️‍🔥",
    "❤️‍🩹", "❤️", "🧡", "💛", "💚", "💙", "💜", "🤎", "🖤", "🤍", "💯", "💢",
    "💥", "💫", "💦", "💨", "🕳️", "💣", "💬", "👁️‍🗨️", "🗨️", "🗯️", "💭", "💤",
    "👋", "👋🏻", "👋🏼", "👋🏽", "👋🏾", "👋🏿", "🤚", "🤚🏻", "🤚🏼", "🤚🏽", "🤚🏾", "🤚🏿",
    "🖐️", "🖐🏻", "🖐🏼", "🖐🏽", "🖐🏾", "🖐🏿", "✋", "✋🏻", "✋🏼", "✋🏽", "✋🏾", "✋🏿",
    "🖖", "🖖🏻", "🖖🏼", "🖖🏽", "🖖🏾", "🖖🏿", "👌", "👌🏻", "👌🏼", "👌🏽", "👌🏾", "👌🏿",
    "🤌", "🤌🏻", "🤌🏼", "🤌🏽", "🤌🏾", "🤌🏿", "🤏", "🤏🏻", "🤏🏼", "🤏🏽", "🤏🏾", "🤏🏿",
    "✌️", "✌🏻", "✌🏼", "✌🏽", "✌🏾", "✌🏿", "🤞", "🤞🏻", "🤞🏼", "🤞🏽", "🤞🏾", "🤞🏿",
    "🤟", "🤟🏻", "🤟🏼", "🤟🏽", "🤟🏾", "🤟🏿", "🤘", "🤘🏻", "🤘🏼", "🤘🏽", "🤘🏾", "🤘🏿",
    "🤙", "🤙🏻", "🤙🏼", "🤙🏽", "🤙🏾", "🤙🏿", "👈", "👈🏻", "👈🏼", "👈🏽", "👈🏾", "👈🏿",
    "👉", "👉🏻", "👉🏼", "👉🏽", "👉🏾", "👉🏿", "👆", "👆🏻", "👆🏼", "👆🏽", "👆🏾", "👆🏿",
    "🖕", "🖕🏻", "🖕🏼", "🖕🏽", "🖕🏾", "🖕🏿", "👇", "👇🏻", "👇🏼", "👇🏽", "👇🏾", "👇🏿",
    "☝️", "☝🏻", "☝🏼", "☝🏽", "☝🏾", "☝🏿", "👍", "👍🏻", "👍🏼", "👍🏽", "👍🏾", "👍🏿",
    "👎", "👎🏻", "👎🏼", "👎🏽", "👎🏾", "👎🏿", "✊", "✊🏻", "✊🏼", "✊🏽", "✊🏾", "✊🏿",
    "👊", "👊🏻", "👊🏼", "👊🏽", "👊🏾", "👊🏿", "🤛", "🤛🏻", "🤛🏼", "🤛🏽", "🤛🏾", "🤛🏿",
    "🤜", "🤜🏻", "🤜🏼", "🤜🏽", "🤜🏾", "🤜🏿", "👏", "👏🏻", "👏🏼", "👏🏽", "👏🏾", "👏🏿",
    "🙌", "🙌🏻", "🙌🏼", "🙌🏽", "🙌🏾", "🙌🏿", "👐", "👐🏻", "👐🏼", "👐🏽", "👐🏾", "👐🏿",
    "🤲", "🤲🏻", "🤲🏼", "🤲🏽", "🤲🏾", "🤲🏿", "🤝", "🙏", "🙏🏻", "🙏🏼", "🙏🏽", "🙏🏾",
    "🙏🏿", "✍️", "✍🏻", "✍🏼", "✍🏽", "✍🏾", "✍🏿", "💅", "💅🏻", "💅🏼", "💅🏽", "💅🏾",
    "💅🏿", "🤳", "🤳🏻", "🤳🏼", "🤳🏽", "🤳🏾", "🤳🏿", "💪", "💪🏻", "💪🏼", "💪🏽", "💪🏾",
    "💪🏿", "🦾", "🦿", "🦵", "🦵🏻", "🦵🏼", "🦵🏽", "🦵🏾", "🦵🏿", "🦶", "🦶🏻", "🦶🏼",
    "🦶🏽", "🦶🏾", "🦶🏿", "👂", "👂🏻", "👂🏼", "👂🏽", "👂🏾", "👂🏿", "🦻", "🦻🏻", "🦻🏼",
    "🦻🏽", "🦻🏾", "🦻🏿", "👃", "👃🏻", "👃🏼", "👃🏽", "👃🏾", "👃🏿", "🧠", "🫀", "🫁",
    "🦷", "🦴", "👀", "👁️", "👅", "👄", "👶", "👶🏻", "👶🏼", "👶🏽", "👶🏾", "👶🏿",
    "🧒", "🧒🏻", "🧒🏼", "🧒🏽", "🧒🏾", "🧒🏿", "👦", "👦🏻", "👦🏼", "👦🏽", "👦🏾", "👦🏿",
    "👧", "👧🏻", "👧🏼", "👧🏽", "👧🏾", "👧🏿", "🧑", "🧑🏻", "🧑🏼", "🧑🏽", "🧑🏾", "🧑🏿",
    "👱", "👱🏻", "👱🏼", "👱🏽", "👱🏾", "👱🏿", "👨", "👨🏻", "👨🏼", "👨🏽", "👨🏾", "👨🏿",
    "🧔", "🧔🏻", "🧔🏼", "🧔🏽", "🧔🏾", "🧔🏿", "🧔‍♂️", "🧔🏻‍♂️", "🧔🏼‍♂️", "🧔🏽‍♂️", "🧔🏾‍♂️", "🧔🏿‍♂️",
    "🧔‍♀️", "🧔🏻‍♀️", "🧔🏼‍♀️", "🧔🏽‍♀️", "🧔🏾‍♀️", "🧔🏿‍♀️", "👨‍🦰", "👨🏻‍🦰", "👨🏼‍🦰", "👨🏽‍🦰", "👨🏾‍🦰", "👨🏿‍🦰",
    "👨‍🦱", "👨🏻‍🦱", "👨🏼‍🦱", "👨🏽‍🦱", "👨🏾‍🦱", "👨🏿‍🦱", "👨‍🦳", "👨🏻‍🦳", "👨🏼‍🦳", "👨🏽‍🦳", "👨🏾‍🦳", "👨🏿‍🦳",
    "👨‍🦲", "👨🏻‍🦲", "👨🏼‍🦲", "👨🏽‍🦲", "👨🏾‍🦲", "👨🏿‍🦲", "👩", "👩🏻", "👩🏼", "👩🏽", "👩🏾", "👩🏿",
    "👩‍🦰", "👩🏻‍🦰", "👩🏼‍🦰", "👩🏽‍🦰", "👩🏾‍🦰", "👩🏿‍🦰", "🧑‍🦰", "🧑🏻‍🦰", "🧑🏼‍🦰", "🧑🏽‍🦰", "🧑🏾‍🦰", "🧑🏿‍🦰",
    "👩‍🦱", "👩🏻‍🦱", "👩🏼‍🦱", "👩🏽‍🦱", "👩🏾‍🦱", "👩🏿‍🦱", "🧑‍🦱", "🧑🏻‍🦱", "🧑🏼‍🦱", "🧑🏽‍🦱", "🧑🏾‍🦱", "🧑🏿‍🦱",
    "👩‍🦳", "👩🏻‍🦳", "👩🏼‍🦳", "👩🏽‍🦳", "👩🏾‍🦳", "👩🏿‍🦳", "🧑‍🦳", "🧑🏻‍🦳", "🧑🏼‍🦳", "🧑🏽‍🦳", "🧑🏾‍🦳", "🧑🏿‍🦳",
    "👩‍🦲", "👩🏻‍🦲", "👩🏼‍🦲", "👩🏽‍🦲", "👩🏾‍🦲", "👩🏿‍🦲", "🧑‍🦲", "🧑🏻‍🦲", "🧑🏼‍🦲", "🧑🏽‍🦲", "🧑🏾‍🦲", "🧑🏿‍🦲",
    "👱‍♀️", "👱🏻‍♀️", "👱🏼‍♀️", "👱🏽‍♀️", "👱🏾‍♀️", "👱🏿‍♀️", "👱‍♂️", "👱🏻‍♂️", "👱🏼‍♂️", "👱🏽‍♂️", "👱🏾‍♂️", "👱🏿‍♂️",
    "🧓", "🧓🏻", "🧓🏼", "🧓🏽", "🧓🏾", "🧓🏿", "👴", "👴🏻", "👴🏼", "👴🏽", "👴🏾", "👴🏿",
    "👵", "👵🏻", "👵🏼", "👵🏽", "👵🏾", "👵🏿", "🙍", "🙍🏻", "🙍🏼", "🙍🏽", "🙍🏾", "🙍🏿",
    "🙍‍♂️", "🙍🏻‍♂️", "🙍🏼‍♂️", "🙍🏽‍♂️", "🙍🏾‍♂️", "🙍🏿‍♂️", "🙍‍♀️", "🙍🏻‍♀️", "🙍🏼‍♀️", "🙍🏽‍♀️", "🙍🏾‍♀️", "🙍🏿‍♀️",
    "🙎", "🙎🏻", "🙎🏼", "🙎🏽", "🙎🏾", "🙎🏿", "🙎‍♂️", "🙎🏻‍♂️", "🙎🏼‍♂️", "🙎🏽‍♂️", "🙎🏾‍♂️", "🙎🏿‍♂️",
    "🙎‍♀️", "🙎🏻‍♀️", "🙎🏼‍♀️", "🙎🏽‍♀️", "🙎🏾‍♀️", "🙎🏿‍♀️", "🙅", "🙅🏻", "🙅🏼", "🙅🏽", "🙅🏾", "🙅🏿",
    "🙅‍♂️", "🙅🏻‍♂️", "🙅🏼‍♂️", "🙅🏽‍♂️", "🙅🏾‍♂️", "🙅🏿‍♂️", "🙅‍♀️", "🙅🏻‍♀️", "🙅🏼‍♀️", "🙅🏽‍♀️", "🙅🏾‍♀️", "🙅🏿‍♀️",
    "🙆", "🙆🏻", "🙆🏼", "🙆🏽", "🙆🏾", "🙆🏿", "🙆‍♂️", "🙆🏻‍♂️", "🙆🏼‍♂️", "🙆🏽‍♂️", "🙆🏾‍♂️", "🙆🏿‍♂️",
    "🙆‍♀️", "🙆🏻‍♀️", "🙆🏼‍♀️", "🙆🏽‍♀️", "🙆🏾‍♀️", "🙆🏿‍♀️", "💁", "💁🏻", "💁🏼", "💁🏽", "💁🏾", "💁🏿",
    "💁‍♂️", "💁🏻‍♂️", "💁🏼‍♂️", "💁🏽‍♂️", "💁🏾‍♂️", "💁🏿‍♂️", "💁‍♀️", "💁🏻‍♀️", "💁🏼‍♀️", "💁🏽‍♀️", "💁🏾‍♀️", "💁🏿‍♀️",
    "🙋", "🙋🏻", "🙋🏼", "🙋🏽", "🙋🏾", "🙋🏿", "🙋‍♂️", "🙋🏻‍♂️", "🙋🏼‍♂️", "🙋🏽‍♂️", "🙋🏾‍♂️", "🙋🏿‍♂️",
    "🙋‍♀️", "🙋🏻‍♀️", "🙋🏼‍♀️", "🙋🏽‍♀️", "🙋🏾‍♀️", "🙋🏿‍♀️", "🧏", "🧏🏻", "🧏🏼", "🧏🏽", "🧏🏾", "🧏🏿",
    "🧏‍♂️", "🧏🏻‍♂️", "🧏🏼‍♂️", "🧏🏽‍♂️", "🧏🏾‍♂️", "🧏🏿‍♂️", "🧏‍♀️", "🧏🏻‍♀️", "🧏🏼‍♀️", "🧏🏽‍♀️", "🧏🏾‍♀️", "🧏🏿‍♀️",
    "🙇", "🙇🏻", "🙇🏼", "🙇🏽", "🙇🏾", "🙇🏿", "🙇‍♂️", "🙇🏻‍♂️", "🙇🏼‍♂️", "🙇🏽‍♂️", "🙇🏾‍♂️", "🙇🏿‍♂️",
    "🙇‍♀️", "🙇🏻‍♀️", "🙇🏼‍♀️", "🙇🏽‍♀️", "🙇🏾‍♀️", "🙇🏿‍♀️", "🤦", "🤦🏻", "🤦🏼", "🤦🏽", "🤦🏾", "🤦🏿",
    "🤦‍♂️", "🤦🏻‍♂️", "🤦🏼‍♂️", "🤦🏽‍♂️", "🤦🏾‍♂️", "🤦🏿‍♂️", "🤦‍♀️", "🤦🏻‍♀️", "🤦🏼‍♀️", "🤦🏽‍♀️", "🤦🏾‍♀️", "🤦🏿‍♀️",
    "🤷", "🤷🏻", "🤷🏼", "🤷🏽", "🤷🏾", "🤷🏿", "🤷‍♂️", "🤷🏻‍♂️", "🤷🏼‍♂️", "🤷🏽‍♂️", "🤷🏾‍♂️", "🤷🏿‍♂️",
    "🤷‍♀️", "🤷🏻‍♀️", "🤷🏼‍♀️", "🤷🏽‍♀️", "🤷🏾‍♀️", "🤷🏿‍♀️", "🧑‍⚕️", "🧑🏻‍⚕️", "🧑🏼‍⚕️", "🧑🏽‍⚕️", "🧑🏾‍⚕️", "🧑🏿‍⚕️",
    "👨‍⚕️", "👨🏻‍⚕️", "👨🏼‍⚕️", "👨🏽‍⚕️", "👨🏾‍⚕️", "👨🏿‍⚕️", "👩‍⚕️", "👩🏻‍⚕️", "👩🏼‍⚕️", "👩🏽‍⚕️", "👩🏾‍⚕️", "👩🏿‍⚕️",
    "🧑‍🎓", "🧑🏻‍🎓", "🧑🏼‍🎓", "🧑🏽‍🎓", "🧑🏾‍🎓", "🧑🏿‍🎓", "👨‍🎓", "👨🏻‍🎓", "👨🏼‍🎓", "👨🏽‍🎓", "👨🏾‍🎓", "👨🏿‍🎓",
    "👩‍🎓", "👩🏻‍🎓", "👩🏼‍🎓", "👩🏽‍🎓", "👩🏾‍🎓", "👩🏿‍🎓", "🧑‍🏫", "🧑🏻‍🏫", "🧑🏼‍🏫", "🧑🏽‍🏫", "🧑🏾‍🏫", "🧑🏿‍🏫",
    "👨‍🏫", "👨🏻‍🏫", "👨🏼‍🏫", "👨🏽‍🏫", "👨🏾‍🏫", "👨🏿‍🏫", "👩‍🏫", "👩🏻‍🏫", "👩🏼‍🏫", "👩🏽‍🏫", "👩🏾‍🏫", "👩🏿‍🏫",
    "🧑‍⚖️", "🧑🏻‍⚖️", "🧑🏼‍⚖️", "🧑🏽‍⚖️", "🧑🏾‍⚖️", "🧑🏿‍⚖️", "👨‍⚖️", "👨🏻‍⚖️", "👨🏼‍⚖️", "👨🏽‍⚖️", "👨🏾‍⚖️", "👨🏿‍⚖️",
    "👩‍⚖️", "👩🏻‍⚖️", "👩🏼‍⚖️", "👩🏽‍⚖️", "👩🏾‍⚖️", "👩🏿‍⚖️", "🧑‍🌾", "🧑🏻‍🌾", "🧑🏼‍🌾", "🧑🏽‍🌾", "🧑🏾‍🌾", "🧑🏿‍🌾",
    "👨‍🌾", "👨🏻‍🌾", "👨🏼‍🌾", "👨🏽‍🌾", "👨🏾‍🌾", "👨🏿‍🌾", "👩‍🌾", "👩🏻‍🌾", "👩🏼‍🌾", "👩🏽‍🌾", "👩🏾‍🌾", "👩🏿‍🌾",
    "🧑‍🍳", "🧑🏻‍🍳", "🧑🏼‍🍳", "🧑🏽‍🍳", "🧑🏾‍🍳", "🧑🏿‍🍳", "👨‍🍳", "👨🏻‍🍳", "👨🏼‍🍳", "👨🏽‍🍳", "👨🏾‍🍳", "👨🏿‍🍳",
    "👩‍🍳", "👩🏻‍🍳", "👩🏼‍🍳", "👩🏽‍🍳", "👩🏾‍🍳", "👩🏿‍🍳", "🧑‍🔧", "🧑🏻‍🔧", "🧑🏼‍🔧", "🧑🏽‍🔧", "🧑🏾‍🔧", "🧑🏿‍🔧",
    "👨‍🔧", "👨🏻‍🔧", "👨🏼‍🔧", "👨🏽‍🔧", "👨🏾‍🔧", "👨🏿‍🔧", "👩‍🔧", "👩🏻‍🔧", "👩🏼‍🔧", "👩🏽‍🔧", "👩🏾‍🔧", "👩🏿‍🔧",
    "🧑‍🏭", "🧑🏻‍🏭", "🧑🏼‍🏭", "🧑🏽‍🏭", "🧑🏾‍🏭", "🧑🏿‍🏭", "👨‍🏭", "👨🏻‍🏭", "👨🏼‍🏭", "👨🏽‍🏭", "👨🏾‍🏭", "👨🏿‍🏭",
    "👩‍🏭", "👩🏻‍🏭", "👩🏼‍🏭", "👩🏽‍🏭", "👩🏾‍🏭", "👩🏿‍🏭", "🧑‍💼", "🧑🏻‍💼", "🧑🏼‍💼", "🧑🏽‍💼", "🧑🏾‍💼", "🧑🏿‍💼",
    "👨‍💼", "👨🏻‍💼", "👨🏼‍💼", "👨🏽‍💼", "👨🏾‍💼", "👨🏿‍💼", "👩‍💼", "👩🏻‍💼", "👩🏼‍💼", "👩🏽‍💼", "👩🏾‍💼", "👩🏿‍💼",
    "🧑‍🔬", "🧑🏻‍🔬", "🧑🏼‍🔬", "🧑🏽‍🔬", "🧑🏾‍🔬", "🧑🏿‍🔬", "👨‍🔬", "👨🏻‍🔬", "👨🏼‍🔬", "👨🏽‍🔬", "👨🏾‍🔬", "👨🏿‍🔬",
    "👩‍🔬", "👩🏻‍🔬", "👩🏼‍🔬", "👩🏽‍🔬", "👩🏾‍🔬", "👩🏿‍🔬", "🧑‍💻", "🧑🏻‍💻", "🧑🏼‍💻", "🧑🏽‍💻", "🧑🏾‍💻", "🧑🏿‍💻",
    "👨‍💻", "👨🏻‍💻", "👨🏼‍💻", "👨🏽‍💻", "👨🏾‍💻", "👨🏿‍💻", "👩‍💻", "👩🏻‍💻", "👩🏼‍💻", "👩🏽‍💻", "👩🏾‍💻", "👩🏿‍💻",
    "🧑‍🎤", "🧑🏻‍🎤", "🧑🏼‍🎤", "🧑🏽‍🎤", "🧑🏾‍🎤", "🧑🏿‍🎤", "👨‍🎤", "👨🏻‍🎤", "👨🏼‍🎤", "👨🏽‍🎤", "👨🏾‍🎤", "👨🏿‍🎤",
    "👩‍🎤", "👩🏻‍🎤", "👩🏼‍🎤", "👩🏽‍🎤", "👩🏾‍🎤", "👩🏿‍🎤", "🧑‍🎨", "🧑🏻‍🎨", "🧑🏼‍🎨", "🧑🏽‍🎨", "🧑🏾‍🎨", "🧑🏿‍🎨",
    "👨‍🎨", "👨🏻‍🎨", "👨🏼‍🎨", "👨🏽‍🎨", "👨🏾‍🎨", "👨🏿‍🎨", "👩‍🎨", "👩🏻‍🎨", "👩🏼‍🎨", "👩🏽‍🎨", "👩🏾‍🎨", "👩🏿‍🎨",
    "🧑‍✈️", "🧑🏻‍✈️", "🧑🏼‍✈️", "🧑🏽‍✈️", "🧑🏾‍✈️", "🧑🏿‍✈️", "👨‍✈️", "👨🏻‍✈️", "👨🏼‍✈️", "👨🏽‍✈️", "👨🏾‍✈️", "👨🏿‍✈️",
    "👩‍✈️", "👩🏻‍✈️", "👩🏼‍✈️", "👩🏽‍✈️", "👩🏾‍✈️", "👩🏿‍✈️", "🧑‍🚀", "🧑🏻‍🚀", "🧑🏼‍🚀", "🧑🏽‍🚀", "🧑🏾‍🚀", "🧑🏿‍🚀",
    "👨‍🚀", "👨🏻‍🚀", "👨🏼‍🚀", "👨🏽‍🚀", "👨🏾‍🚀", "👨🏿‍🚀", "👩‍🚀", "👩🏻‍🚀", "👩🏼‍🚀", "👩🏽‍🚀", "👩🏾‍🚀", "👩🏿‍🚀",
    "🧑‍🚒", "🧑🏻‍🚒", "🧑🏼‍🚒", "🧑🏽‍🚒", "🧑🏾‍🚒", "🧑🏿‍🚒", "👨‍🚒", "👨🏻‍🚒", "👨🏼‍🚒", "👨🏽‍🚒", "👨🏾‍🚒", "👨🏿‍🚒",
    "👩‍🚒", "👩🏻‍🚒", "👩🏼‍🚒", "👩🏽‍🚒", "👩🏾‍🚒", "👩🏿‍🚒", "👮", "👮🏻", "👮🏼", "👮🏽", "👮🏾", "👮🏿",
    "👮‍♂️", "👮🏻‍♂️", "👮🏼‍♂️", "👮🏽‍♂️", "👮🏾‍♂️", "👮🏿‍♂️", "👮‍♀️", "👮🏻‍♀️", "👮🏼‍♀️", "👮🏽‍♀️", "👮🏾‍♀️", "👮🏿‍♀️",
    "🕵️", "🕵🏻", "🕵🏼", "🕵🏽", "🕵🏾", "🕵🏿", "🕵️‍♂️", "🕵🏻‍♂️", "🕵🏼‍♂️", "🕵🏽‍♂️", "🕵🏾‍♂️", "🕵🏿‍♂️",
    "🕵️‍♀️", "🕵🏻‍♀️", "🕵🏼‍♀️", "🕵🏽‍♀️", "🕵🏾‍♀️", "🕵🏿‍♀️", "💂", "💂🏻", "💂🏼", "💂🏽", "💂🏾", "💂🏿",
    "💂‍♂️", "💂🏻‍♂️", "💂🏼‍♂️", "💂🏽‍♂️", "💂🏾‍♂️", "💂🏿‍♂️", "💂‍♀️", "💂🏻‍♀️", "💂🏼‍♀️", "💂🏽‍♀️", "💂🏾‍♀️", "💂🏿‍♀️",
    "🥷", "🥷🏻", "🥷🏼", "🥷🏽", "🥷🏾", "🥷🏿", "👷", "👷🏻", "👷🏼", "👷🏽", "👷🏾", "👷🏿",
    "👷‍♂️", "👷🏻‍♂️", "👷🏼‍♂️", "👷🏽‍♂️", "👷🏾‍♂️", "👷🏿‍♂️", "👷‍♀️", "👷🏻‍♀️", "👷🏼‍♀️", "👷🏽‍♀️", "👷🏾‍♀️", "👷🏿‍♀️",
    "🤴", "🤴🏻", "🤴🏼", "🤴🏽", "🤴🏾", "🤴🏿", "👸", "👸🏻", "👸🏼", "👸🏽", "👸🏾", "👸🏿",
    "👳", "👳🏻", "👳🏼", "👳🏽", "👳🏾", "👳🏿", "👳‍♂️", "👳🏻‍♂️", "👳🏼‍♂️", "👳🏽‍♂️", "👳🏾‍♂️", "👳🏿‍♂️",
    "👳‍♀️", "👳🏻‍♀️", "👳🏼‍♀️", "👳🏽‍♀️", "👳🏾‍♀️", "👳🏿‍♀️", "👲", "👲🏻", "👲🏼", "👲🏽", "👲🏾", "👲🏿",
    "🧕", "🧕🏻", "🧕🏼", "🧕🏽", "🧕🏾", "🧕🏿", "🤵", "🤵🏻", "🤵🏼", "🤵🏽", "🤵🏾", "🤵🏿",
    "🤵‍♂️", "🤵🏻‍♂️", "🤵🏼‍♂️", "🤵🏽‍♂️", "🤵🏾‍♂️", "🤵🏿‍♂️", "🤵‍♀️", "🤵🏻‍♀️", "🤵🏼‍♀️", "🤵🏽‍♀️", "🤵🏾‍♀️", "🤵🏿‍♀️",
    "👰", "👰🏻", "👰🏼", "👰🏽", "👰🏾", "👰🏿", "👰‍♂️", "👰🏻‍♂️", "👰🏼‍♂️", "👰🏽‍♂️", "👰🏾‍♂️", "👰🏿‍♂️",
    "👰‍♀️", "👰🏻‍♀️", "👰🏼‍♀️", "👰🏽‍♀️", "👰🏾‍♀️", "👰🏿‍♀️", "🤰", "🤰🏻", "🤰🏼", "🤰🏽", "🤰🏾", "🤰🏿",
    "🤱", "🤱🏻", "🤱🏼", "🤱🏽", "🤱🏾", "🤱🏿", "👩‍🍼", "👩🏻‍🍼", "👩🏼‍🍼", "👩🏽‍🍼", "👩🏾‍🍼", "👩🏿‍🍼",
    "👨‍🍼", "👨🏻‍🍼", "👨🏼‍🍼", "👨🏽‍🍼", "👨🏾‍🍼", "👨🏿‍🍼", "🧑‍🍼", "🧑🏻‍🍼", "🧑🏼‍🍼", "🧑🏽‍🍼", "🧑🏾‍🍼", "🧑🏿‍🍼",
    "👼", "👼🏻", "👼🏼", "👼🏽", "👼🏾", "👼🏿", "🎅", "🎅🏻", "🎅🏼", "🎅🏽", "🎅🏾", "🎅🏿",
    "🤶", "🤶🏻", "🤶🏼", "🤶🏽", "🤶🏾", "🤶🏿", "🧑‍🎄", "🧑🏻‍🎄", "🧑🏼‍🎄", "🧑🏽‍🎄", "🧑🏾‍🎄", "🧑🏿‍🎄",
    "🦸", "🦸🏻", "🦸🏼", "🦸🏽", "🦸🏾", "🦸🏿", "🦸‍♂️", "🦸🏻‍♂️", "🦸🏼‍♂️", "🦸🏽‍♂️", "🦸🏾‍♂️", "🦸🏿‍♂️",
    "🦸‍♀️", "🦸🏻‍♀️", "🦸🏼‍♀️", "🦸🏽‍♀️", "🦸🏾‍♀️", "🦸🏿‍♀️", "🦹", "🦹🏻", "🦹🏼", "🦹🏽", "🦹🏾", "🦹🏿",
    "🦹‍♂️", "🦹🏻‍♂️", "🦹🏼‍♂️", "🦹🏽‍♂️", "🦹🏾‍♂️", "🦹🏿‍♂️", "🦹‍♀️", "🦹🏻‍♀️", "🦹🏼‍♀️", "🦹🏽‍♀️", "🦹🏾‍♀️", "🦹🏿‍♀️",
    "🧙", "🧙🏻", "🧙🏼", "🧙🏽", "🧙🏾", "🧙🏿", "🧙‍♂️", "🧙🏻‍♂️", "🧙🏼‍♂️", "🧙🏽‍♂️", "🧙🏾‍♂️", "🧙🏿‍♂️",
    "🧙‍♀️", "🧙🏻‍♀️", "🧙🏼‍♀️", "🧙🏽‍♀️", "🧙🏾‍♀️", "🧙🏿‍♀️", "🧚", "🧚🏻", "🧚🏼", "🧚🏽", "🧚🏾", "🧚🏿",
    "🧚‍♂️", "🧚🏻‍♂️", "🧚🏼‍♂️", "🧚🏽‍♂️", "🧚🏾‍♂️", "🧚🏿‍♂️", "🧚‍♀️", "🧚🏻‍♀️", "🧚🏼‍♀️", "🧚🏽‍♀️", "🧚🏾‍♀️", "🧚🏿‍♀️",
    "🧛", "🧛🏻", "🧛🏼", "🧛🏽", "🧛🏾", "🧛🏿", "🧛‍♂️", "🧛🏻‍♂️", "🧛🏼‍♂️", "🧛🏽‍♂️", "🧛🏾‍♂️", "🧛🏿‍♂️",
    "🧛‍♀️", "🧛🏻‍♀️", "🧛🏼‍♀️", "🧛🏽‍♀️", "🧛🏾‍♀️", "🧛🏿‍♀️", "🧜", "🧜🏻", "🧜🏼", "🧜🏽", "🧜🏾", "🧜🏿",
    "🧜‍♂️", "🧜🏻‍♂️", "🧜🏼‍♂️", "🧜🏽‍♂️", "🧜🏾‍♂️", "🧜🏿‍♂️", "🧜‍♀️", "🧜🏻‍♀️", "🧜🏼‍♀️", "🧜🏽‍♀️", "🧜🏾‍♀️", "🧜🏿‍♀️",
    "🧝", "🧝🏻", "🧝🏼", "🧝🏽", "🧝🏾", "🧝🏿", "🧝‍♂️", "🧝🏻‍♂️", "🧝🏼‍♂️", "🧝🏽‍♂️", "🧝🏾‍♂️", "🧝🏿‍♂️",
    "🧝‍♀️", "🧝🏻‍♀️", "🧝🏼‍♀️", "🧝🏽‍♀️", "🧝🏾‍♀️", "🧝🏿‍♀️", "🧞", "🧞‍♂️", "🧞‍♀️", "🧟", "🧟‍♂️", "🧟‍♀️",
    "💆", "💆🏻", "💆🏼", "💆🏽", "💆🏾", "💆🏿", "💆‍♂️", "💆🏻‍♂️", "💆🏼‍♂️", "💆🏽‍♂️", "💆🏾‍♂️", "💆🏿‍♂️",
    "💆‍♀️", "💆🏻‍♀️", "💆🏼‍♀️", "💆🏽‍♀️", "💆🏾‍♀️", "💆🏿‍♀️", "💇", "💇🏻", "💇🏼", "💇🏽", "💇🏾", "💇🏿",
    "💇‍♂️", "💇🏻‍♂️", "💇🏼‍♂️", "💇🏽‍♂️", "💇🏾‍♂️", "💇🏿‍♂️", "💇‍♀️", "💇🏻‍♀️", "💇🏼‍♀️", "💇🏽‍♀️", "💇🏾‍♀️", "💇🏿‍♀️",
    "🚶", "🚶🏻", "🚶🏼", "🚶🏽", "🚶🏾", "🚶🏿", "🚶‍♂️", "🚶🏻‍♂️", "🚶🏼‍♂️", "🚶🏽‍♂️", "🚶🏾‍♂️", "🚶🏿‍♂️",
    "🚶‍♀️", "🚶🏻‍♀️", "🚶🏼‍♀️", "🚶🏽‍♀️", "🚶🏾‍♀️", "🚶🏿‍♀️", "🧍", "🧍🏻", "🧍🏼", "🧍🏽", "🧍🏾", "🧍🏿",
    "🧍‍♂️", "🧍🏻‍♂️", "🧍🏼‍♂️", "🧍🏽‍♂️", "🧍🏾‍♂️", "🧍🏿‍♂️", "🧍‍♀️", "🧍🏻‍♀️", "🧍🏼‍♀️", "🧍🏽‍♀️", "🧍🏾‍♀️", "🧍🏿‍♀️",
    "🧎", "🧎🏻", "🧎🏼", "🧎🏽", "🧎🏾", "🧎🏿", "🧎‍♂️", "🧎🏻‍♂️", "🧎🏼‍♂️", "🧎🏽‍♂️", "🧎🏾‍♂️", "🧎🏿‍♂️",
    "🧎‍♀️", "🧎🏻‍♀️", "🧎🏼‍♀️", "🧎🏽‍♀️", "🧎🏾‍♀️", "🧎🏿‍♀️", "🧑‍🦯", "🧑🏻‍🦯", "🧑🏼‍🦯", "🧑🏽‍🦯", "🧑🏾‍🦯", "🧑🏿‍🦯",
    "👨‍🦯", "👨🏻‍🦯", "👨🏼‍🦯", "👨🏽‍🦯", "👨🏾‍🦯", "👨🏿‍🦯", "👩‍🦯", "👩🏻‍🦯", "👩🏼‍🦯", "👩🏽‍🦯", "👩🏾‍🦯", "👩🏿‍🦯",
    "🧑‍🦼", "🧑🏻‍🦼", "🧑🏼‍🦼", "🧑🏽‍🦼", "🧑🏾‍🦼", "🧑🏿‍🦼", "👨‍🦼", "👨🏻‍🦼", "👨🏼‍🦼", "👨🏽‍🦼", "👨🏾‍🦼", "👨🏿‍🦼",
    "👩‍🦼", "👩🏻‍🦼", "👩🏼‍🦼", "👩🏽‍🦼", "👩🏾‍🦼", "👩🏿‍🦼", "🧑‍🦽", "🧑🏻‍🦽", "🧑🏼‍🦽", "🧑🏽‍🦽", "🧑🏾‍🦽", "🧑🏿‍🦽",
    "👨‍🦽", "👨🏻‍🦽", "👨🏼‍🦽", "👨🏽‍🦽", "👨🏾‍🦽", "👨🏿‍🦽", "👩‍🦽", "👩🏻‍🦽", "👩🏼‍🦽", "👩🏽‍🦽", "👩🏾‍🦽", "👩🏿‍🦽",
    "🏃", "🏃🏻", "🏃🏼", "🏃🏽", "🏃🏾", "🏃🏿", "🏃‍♂️", "🏃🏻‍♂️", "🏃🏼‍♂️", "🏃🏽‍♂️", "🏃🏾‍♂️", "🏃🏿‍♂️",
    "🏃‍♀️", "🏃🏻‍♀️", "🏃🏼‍♀️", "🏃🏽‍♀️", "🏃🏾‍♀️", "🏃🏿‍♀️", "💃", "💃🏻", "💃🏼", "💃🏽", "💃🏾", "💃🏿",
    "🕺", "🕺🏻", "🕺🏼", "🕺🏽", "🕺🏾", "🕺🏿", "🕴️", "🕴🏻", "🕴🏼", "🕴🏽", "🕴🏾", "🕴🏿",
    "👯", "👯‍♂️", "👯‍♀️", "🧖", "🧖🏻", "🧖🏼", "🧖🏽", "🧖🏾", "🧖🏿", "🧖‍♂️", "🧖🏻‍♂️", "🧖🏼‍♂️",
    "🧖🏽‍♂️", "🧖🏾‍♂️", "🧖🏿‍♂️", "🧖‍♀️", "🧖🏻‍♀️", "🧖🏼‍♀️", "🧖🏽‍♀️", "🧖🏾‍♀️", "🧖🏿‍♀️", "🧗", "🧗🏻", "🧗🏼",
    "🧗🏽", "🧗🏾", "🧗🏿", "🧗‍♂️", "🧗🏻‍♂️", "🧗🏼‍♂️", "🧗🏽‍♂️", "🧗🏾‍♂️", "🧗🏿‍♂️", "🧗‍♀️", "🧗🏻‍♀️", "🧗🏼‍♀️",
    "🧗🏽‍♀️", "🧗🏾‍♀️", "🧗🏿‍♀️", "🤺", "🏇", "🏇🏻", "🏇🏼", "🏇🏽", "🏇🏾", "🏇🏿", "⛷️", "🏂",
    "🏂🏻", "🏂🏼", "🏂🏽", "🏂🏾", "🏂🏿", "🏌️", "🏌🏻", "🏌🏼", "🏌🏽", "🏌🏾", "🏌🏿", "🏌️‍♂️",
    "🏌🏻‍♂️", "🏌🏼‍♂️", "🏌🏽‍♂️", "🏌🏾‍♂️", "🏌🏿‍♂️", "🏌️‍♀️", "🏌🏻‍♀️", "🏌🏼‍♀️", "🏌🏽‍♀️", "🏌🏾‍♀️", "🏌🏿‍♀️", "🏄",
    "🏄🏻", "🏄🏼", "🏄🏽", "🏄🏾", "🏄🏿", "🏄‍♂️", "🏄🏻‍♂️", "🏄🏼‍♂️", "🏄🏽‍♂️", "🏄🏾‍♂️", "🏄🏿‍♂️", "🏄‍♀️",
    "🏄🏻‍♀️", "🏄🏼‍♀️", "🏄🏽‍♀️", "🏄🏾‍♀️", "🏄🏿‍♀️", "🚣", "🚣🏻", "🚣🏼", "🚣🏽", "🚣🏾", "🚣🏿", "🚣‍♂️",
    "🚣🏻‍♂️", "🚣🏼‍♂️", "🚣🏽‍♂️", "🚣🏾‍♂️", "🚣🏿‍♂️", "🚣‍♀️", "🚣🏻‍♀️", "🚣🏼‍♀️", "🚣🏽‍♀️", "🚣🏾‍♀️", "🚣🏿‍♀️", "🏊",
    "🏊🏻", "🏊🏼", "🏊🏽", "🏊🏾", "🏊🏿", "🏊‍♂️", "🏊🏻‍♂️", "🏊🏼‍♂️", "🏊🏽‍♂️", "🏊🏾‍♂️", "🏊🏿‍♂️", "🏊‍♀️",
    "🏊🏻‍♀️", "🏊🏼‍♀️", "🏊🏽‍♀️", "🏊🏾‍♀️", "🏊🏿‍♀️", "⛹️", "⛹🏻", "⛹🏼", "⛹🏽", "⛹🏾", "⛹🏿", "⛹️‍♂️",
    "⛹🏻‍♂️", "⛹🏼‍♂️", "⛹🏽‍♂️", "⛹🏾‍♂️", "⛹🏿‍♂️", "⛹️‍♀️", "⛹🏻‍♀️", "⛹🏼‍♀️", "⛹🏽‍♀️", "⛹🏾‍♀️", "⛹🏿‍♀️", "🏋️",
    "🏋🏻", "🏋🏼", "🏋🏽", "🏋🏾", "🏋🏿", "🏋️‍♂️", "🏋🏻‍♂️", "🏋🏼‍♂️", "🏋🏽‍♂️", "🏋🏾‍♂️", "🏋🏿‍♂️", "🏋️‍♀️",
    "🏋🏻‍♀️", "🏋🏼‍♀️", "🏋🏽‍♀️", "🏋🏾‍♀️", "🏋🏿‍♀️", "🚴", "🚴🏻", "🚴🏼", "🚴🏽", "🚴🏾", "🚴🏿", "🚴‍♂️",
    "🚴🏻‍♂️", "🚴🏼‍♂️", "🚴🏽‍♂️", "🚴🏾‍♂️", "🚴🏿‍♂️", "🚴‍♀️", "🚴🏻‍♀️", "🚴🏼‍♀️", "🚴🏽‍♀️", "🚴🏾‍♀️", "🚴🏿‍♀️", "🚵",
    "🚵🏻", "🚵🏼", "🚵🏽", "🚵🏾", "🚵🏿", "🚵‍♂️", "🚵🏻‍♂️", "🚵🏼‍♂️", "🚵🏽‍♂️", "🚵🏾‍♂️", "🚵🏿‍♂️", "🚵‍♀️",
    "🚵🏻‍♀️", "🚵🏼‍♀️", "🚵🏽‍♀️", "🚵🏾‍♀️", "🚵🏿‍♀️", "🤸", "🤸🏻", "🤸🏼", "🤸🏽", "🤸🏾", "🤸🏿", "🤸‍♂️",
    "🤸🏻‍♂️", "🤸🏼‍♂️", "🤸🏽‍♂️", "🤸🏾‍♂️", "🤸🏿‍♂️", "🤸‍♀️", "🤸🏻‍♀️", "🤸🏼‍♀️", "🤸🏽‍♀️", "🤸🏾‍♀️", "🤸🏿‍♀️", "🤼",
    "🤼‍♂️", "🤼‍♀️", "🤽", "🤽🏻", "🤽🏼", "🤽🏽", "🤽🏾", "🤽🏿", "🤽‍♂️", "🤽🏻‍♂️", "🤽🏼‍♂️", "🤽🏽‍♂️",
    "🤽🏾‍♂️", "🤽🏿‍♂️", "🤽‍♀️", "🤽🏻‍♀️", "🤽🏼‍♀️", "🤽🏽‍♀️", "🤽🏾‍♀️", "🤽🏿‍♀️", "🤾", "🤾🏻", "🤾🏼", "🤾🏽",
    "🤾🏾", "🤾🏿", "🤾‍♂️", "🤾🏻‍♂️", "🤾🏼‍♂️", "🤾🏽‍♂️", "🤾🏾‍♂️", "🤾🏿‍♂️", "🤾‍♀️", "🤾🏻‍♀️", "🤾🏼‍♀️", "🤾🏽‍♀️",
    "🤾🏾‍♀️", "🤾🏿‍♀️", "🤹", "🤹🏻", "🤹🏼", "🤹🏽", "🤹🏾", "🤹🏿", "🤹‍♂️", "🤹🏻‍♂️", "🤹🏼‍♂️", "🤹🏽‍♂️",
    "🤹🏾‍♂️", "🤹🏿‍♂️", "🤹‍♀️", "🤹🏻‍♀️", "🤹🏼‍♀️", "🤹🏽‍♀️", "🤹🏾‍♀️", "🤹🏿‍♀️", "🧘", "🧘🏻", "🧘🏼", "🧘🏽",
    "🧘🏾", "🧘🏿", "🧘‍♂️", "🧘🏻‍♂️", "🧘🏼‍♂️", "🧘🏽‍♂️", "🧘🏾‍♂️", "🧘🏿‍♂️", "🧘‍♀️", "🧘🏻‍♀️", "🧘🏼‍♀️", "🧘🏽‍♀️",
    "🧘🏾‍♀️", "🧘🏿‍♀️", "🛀", "🛀🏻", "🛀🏼", "🛀🏽", "🛀🏾", "🛀🏿", "🛌", "🛌🏻", "🛌🏼", "🛌🏽",
    "🛌🏾", "🛌🏿", "🧑‍🤝‍🧑", "🧑🏻‍🤝‍🧑🏻", "🧑🏻‍🤝‍🧑🏼", "🧑🏻‍🤝‍🧑🏽", "🧑🏻‍🤝‍🧑🏾", "🧑🏻‍🤝‍🧑🏿", "🧑🏼‍🤝‍🧑🏻", "🧑🏼‍🤝‍🧑🏼", "🧑🏼‍🤝‍🧑🏽", "🧑🏼‍🤝‍🧑🏾",
    "🧑🏼‍🤝‍🧑🏿", "🧑🏽‍🤝‍🧑🏻", "🧑🏽‍🤝‍🧑🏼", "🧑🏽‍🤝‍🧑🏽", "🧑🏽‍🤝‍🧑🏾", "🧑🏽‍🤝‍🧑🏿", "🧑🏾‍🤝‍🧑🏻", "🧑🏾‍🤝‍🧑🏼", "🧑🏾‍🤝‍🧑🏽", "🧑🏾‍🤝‍🧑🏾", "🧑🏾‍🤝‍🧑🏿", "🧑🏿‍🤝‍🧑🏻",
    "🧑🏿‍🤝‍🧑🏼", "🧑🏿‍🤝‍🧑🏽", "🧑🏿‍🤝‍🧑🏾", "🧑🏿‍🤝‍🧑🏿", "👭", "👭🏻", "👩🏻‍🤝‍👩🏼", "👩🏻‍🤝‍👩🏽", "👩🏻‍🤝‍👩🏾", "👩🏻‍🤝‍👩🏿", "👩🏼‍🤝‍👩🏻", "👭🏼",
    "👩🏼‍🤝‍👩🏽", "👩🏼‍🤝‍👩🏾", "👩🏼‍🤝‍👩🏿", "👩🏽‍🤝‍👩🏻", "👩🏽‍🤝‍👩🏼", "👭🏽", "👩🏽‍🤝‍👩🏾", "👩🏽‍🤝‍👩🏿", "👩🏾‍🤝‍👩🏻", "👩🏾‍🤝‍👩🏼", "👩🏾‍🤝‍👩🏽", "👭🏾",
    "👩🏾‍🤝‍👩🏿", "👩🏿‍🤝‍👩🏻", "👩🏿‍🤝‍👩🏼", "👩🏿‍🤝‍👩🏽", "👩🏿‍🤝‍👩🏾", "👭🏿", "👫", "👫🏻", "👩🏻‍🤝‍👨🏼", "👩🏻‍🤝‍👨🏽", "👩🏻‍🤝‍👨🏾", "👩🏻‍🤝‍👨🏿",
    "👩🏼‍🤝‍👨🏻", "👫🏼", "👩🏼‍🤝‍👨🏽", "👩🏼‍🤝‍👨🏾", "👩🏼‍🤝‍👨🏿", "👩🏽‍🤝‍👨🏻", "👩🏽‍🤝‍👨🏼", "👫🏽", "👩🏽‍🤝‍👨🏾", "👩🏽‍🤝‍👨🏿", "👩🏾‍🤝‍👨🏻", "👩🏾‍🤝‍👨🏼",
    "👩🏾‍🤝‍👨🏽", "👫🏾", "👩🏾‍🤝‍👨🏿", "👩🏿‍🤝‍👨🏻", "👩🏿‍🤝‍👨🏼", "👩🏿‍🤝‍👨🏽", "👩🏿‍🤝‍👨🏾", "👫🏿", "👬", "👬🏻", "👨🏻‍🤝‍👨🏼", "👨🏻‍🤝‍👨🏽",
    "👨🏻‍🤝‍👨🏾", "👨🏻‍🤝‍👨🏿", "👨🏼‍🤝‍👨🏻", "👬🏼", "👨🏼‍🤝‍👨🏽", "👨🏼‍🤝‍👨🏾", "👨🏼‍🤝‍👨🏿", "👨🏽‍🤝‍👨🏻", "👨🏽‍🤝‍👨🏼", "👬🏽", "👨🏽‍🤝‍👨🏾", "👨🏽‍🤝‍👨🏿",
    "👨🏾‍🤝‍👨🏻", "👨🏾‍🤝‍👨🏼", "👨🏾‍🤝‍👨🏽", "👬🏾", "👨🏾‍🤝‍👨🏿", "👨🏿‍🤝‍👨🏻", "👨🏿‍🤝‍👨🏼", "👨🏿‍🤝‍👨🏽", "👨🏿‍🤝‍👨🏾", "👬🏿", "💏", "💏🏻",
    "💏🏼", "💏🏽", "💏🏾", "💏🏿", "🧑🏻‍❤️‍💋‍🧑🏼", "🧑🏻‍❤️‍💋‍🧑🏽", "🧑🏻‍❤️‍💋‍🧑🏾", "🧑🏻‍❤️‍💋‍🧑🏿", "🧑🏼‍❤️‍💋‍🧑🏻", "🧑🏼‍❤️‍💋‍🧑🏽", "🧑🏼‍❤️‍💋‍🧑🏾", "🧑🏼‍❤️‍💋‍🧑🏿",
    "🧑🏽‍❤️‍💋‍🧑🏻", "🧑🏽‍❤️‍💋‍🧑🏼", "🧑🏽‍❤️‍💋‍🧑🏾", "🧑🏽‍❤️‍💋‍🧑🏿", "🧑🏾‍❤️‍💋‍🧑🏻", "🧑🏾‍❤️‍💋‍🧑🏼", "🧑🏾‍❤️‍💋‍🧑🏽", "🧑🏾‍❤️‍💋‍🧑🏿", "🧑🏿‍❤️‍💋‍🧑🏻", "🧑🏿‍❤️‍💋‍🧑🏼", "🧑🏿‍❤️‍💋‍🧑🏽", "🧑🏿‍❤️‍💋‍🧑🏾",
    "👩‍❤️‍💋‍👨", "👩🏻‍❤️‍💋‍👨🏻", "👩🏻‍❤️‍💋‍👨🏼", "👩🏻‍❤️‍💋‍👨🏽", "👩🏻‍❤️‍💋‍👨🏾", "👩🏻‍❤️‍💋‍👨🏿", "👩🏼‍❤️‍💋‍👨🏻", "👩🏼‍❤️‍💋‍👨🏼", "👩🏼‍❤️‍💋‍👨🏽", "👩🏼‍❤️‍💋‍👨🏾", "👩🏼‍❤️‍💋‍👨🏿", "👩🏽‍❤️‍💋‍👨🏻",
    "👩🏽‍❤️‍💋‍👨🏼", "👩🏽‍❤️‍💋‍👨🏽", "👩🏽‍❤️‍💋‍👨🏾", "👩🏽‍❤️‍💋‍👨🏿", "👩🏾‍❤️‍💋‍👨🏻", "👩🏾‍❤️‍💋‍👨🏼", "👩🏾‍❤️‍💋‍👨🏽", "👩🏾‍❤️‍💋‍👨🏾", "👩🏾‍❤️‍💋‍👨🏿", "👩🏿‍❤️‍💋‍👨🏻", "👩🏿‍❤️‍💋‍👨🏼", "👩🏿‍❤️‍💋‍👨🏽",
    "👩🏿‍❤️‍💋‍👨🏾", "👩🏿‍❤️‍💋‍👨🏿", "👨‍❤️‍💋‍👨", "👨🏻‍❤️‍💋‍👨🏻", "👨🏻‍❤️‍💋‍👨🏼", "👨🏻‍❤️‍💋‍👨🏽", "👨🏻‍❤️‍💋‍👨🏾", "👨🏻‍❤️‍💋‍👨🏿", "👨🏼‍❤️‍💋‍👨🏻", "👨🏼‍❤️‍💋‍👨🏼", "👨🏼‍❤️‍💋‍👨🏽", "👨🏼‍❤️‍💋‍👨🏾",
    "👨🏼‍❤️‍💋‍👨🏿", "👨🏽‍❤️‍💋‍👨🏻", "👨🏽‍❤️‍💋‍👨🏼", "👨🏽‍❤️‍💋‍👨🏽", "👨🏽‍❤️‍💋‍👨🏾", "👨🏽‍❤️‍💋‍👨🏿", "👨🏾‍❤️‍💋‍👨🏻", "👨🏾‍❤️‍💋‍👨🏼", "👨🏾‍❤️‍💋‍👨🏽", "👨🏾‍❤️‍💋‍👨🏾", "👨🏾‍❤️‍💋‍👨🏿", "👨🏿‍❤️‍💋‍👨🏻",
    "👨🏿‍❤️‍💋‍👨🏼", "👨🏿‍❤️‍💋‍👨🏽", "👨🏿‍❤️‍💋‍👨🏾", "👨🏿‍❤️‍💋‍👨🏿", "👩‍❤️‍💋‍👩", "👩🏻‍❤️‍💋‍👩🏻", "👩🏻‍❤️‍💋‍👩🏼", "👩🏻‍❤️‍💋‍👩🏽", "👩🏻‍❤️‍💋‍👩🏾", "👩🏻‍❤️‍💋‍👩🏿", "👩🏼‍❤️‍💋‍👩🏻", "👩🏼‍❤️‍💋‍👩🏼",
    "👩🏼‍❤️‍💋‍👩🏽", "👩🏼‍❤️‍💋‍👩🏾", "👩🏼‍❤️‍💋‍👩🏿", "👩🏽‍❤️‍💋‍👩🏻", "👩🏽‍❤️‍💋‍👩🏼", "👩🏽‍❤️‍💋‍👩🏽", "👩🏽‍❤️‍💋‍👩🏾", "👩🏽‍❤️‍💋‍👩🏿", "👩🏾‍❤️‍💋‍👩🏻", "👩🏾‍❤️‍💋‍👩🏼", "👩🏾‍❤️‍💋‍👩🏽", "👩🏾‍❤️‍💋‍👩🏾",
    "👩🏾‍❤️‍💋‍👩🏿", "👩🏿‍❤️‍💋‍👩🏻", "👩🏿‍❤️‍💋‍👩🏼", "👩🏿‍❤️‍💋‍👩🏽", "👩🏿‍❤️‍💋‍👩🏾", "👩🏿‍❤️‍💋‍👩🏿", "💑", "💑🏻", "💑🏼", "💑🏽", "💑🏾", "💑🏿",
    "🧑🏻‍❤️‍🧑🏼", "🧑🏻‍❤️‍🧑🏽", "🧑🏻‍❤️‍🧑🏾", "🧑🏻‍❤️‍🧑🏿", "🧑🏼‍❤️‍🧑🏻", "🧑🏼‍❤️‍🧑🏽", "🧑🏼‍❤️‍🧑🏾", "🧑🏼‍❤️‍🧑🏿", "🧑🏽‍❤️‍🧑🏻", "🧑🏽‍❤️‍🧑🏼", "🧑🏽‍❤️‍🧑🏾", "🧑🏽‍❤️‍🧑🏿",
    "🧑🏾‍❤️‍🧑🏻", "🧑🏾‍❤️‍🧑🏼", "🧑🏾‍❤️‍🧑🏽", "🧑🏾‍❤️‍🧑🏿", "🧑🏿‍❤️‍🧑🏻", "🧑🏿‍❤️‍🧑🏼", "🧑🏿‍❤️‍🧑🏽", "🧑🏿‍❤️‍🧑🏾", "👩‍❤️‍👨", "👩🏻‍❤️‍👨🏻", "👩🏻‍❤️‍👨🏼", "👩🏻‍❤️‍👨🏽",
    "👩🏻‍❤️‍👨🏾", "👩🏻‍❤️‍👨🏿", "👩🏼‍❤️‍👨🏻", "👩🏼‍❤️‍👨🏼", "👩🏼‍❤️‍👨🏽", "👩🏼‍❤️‍👨🏾", "👩🏼‍❤️‍👨🏿", "👩🏽‍❤️‍👨🏻", "👩🏽‍❤️‍👨🏼", "👩🏽‍❤️‍👨🏽", "👩🏽‍❤️‍👨🏾", "👩🏽‍❤️‍👨🏿",
    "👩🏾‍❤️‍👨🏻", "👩🏾‍❤️‍👨🏼", "👩🏾‍❤️‍👨🏽", "👩🏾‍❤️‍👨🏾", "👩🏾‍❤️‍👨🏿", "👩🏿‍❤️‍👨🏻", "👩🏿‍❤️‍👨🏼", "👩🏿‍❤️‍👨🏽", "👩🏿‍❤️‍👨🏾", "👩🏿‍❤️‍👨🏿", "👨‍❤️‍👨", "👨🏻‍❤️‍👨🏻",
    "👨🏻‍❤️‍👨🏼", "👨🏻‍❤️‍👨🏽", "👨🏻‍❤️‍👨🏾", "👨🏻‍❤️‍👨🏿", "👨🏼‍❤️‍👨🏻", "👨🏼‍❤️‍👨🏼", "👨🏼‍❤️‍👨🏽", "👨🏼‍❤️‍👨🏾", "👨🏼‍❤️‍👨🏿", "👨🏽‍❤️‍👨🏻", "👨🏽‍❤️‍👨🏼", "👨🏽‍❤️‍👨🏽",
    "👨🏽‍❤️‍👨🏾", "👨🏽‍❤️‍👨🏿", "👨🏾‍❤️‍👨🏻", "👨🏾‍❤️‍👨🏼", "👨🏾‍❤️‍👨🏽", "👨🏾‍❤️‍👨🏾", "👨🏾‍❤️‍👨🏿", "👨🏿‍❤️‍👨🏻", "👨🏿‍❤️‍👨🏼", "👨🏿‍❤️‍👨🏽", "👨🏿‍❤️‍👨🏾", "👨🏿‍❤️‍👨🏿",
    "👩‍❤️‍👩", "👩🏻‍❤️‍👩🏻", "👩🏻‍❤️‍👩🏼", "👩🏻‍❤️‍👩🏽", "👩🏻‍❤️‍👩🏾", "👩🏻‍❤️‍👩🏿", "👩🏼‍❤️‍👩🏻", "👩🏼‍❤️‍👩🏼", "👩🏼‍❤️‍👩🏽", "👩🏼‍❤️‍👩🏾", "👩🏼‍❤️‍👩🏿", "👩🏽‍❤️‍👩🏻",
    "👩🏽‍❤️‍👩🏼", "👩🏽‍❤️‍👩🏽", "👩🏽‍❤️‍👩🏾", "👩🏽‍❤️‍👩🏿", "👩🏾‍❤️‍👩🏻", "👩🏾‍❤️‍👩🏼", "👩🏾‍❤️‍👩🏽", "👩🏾‍❤️‍👩🏾", "👩🏾‍❤️‍👩🏿", "👩🏿‍❤️‍👩🏻", "👩🏿‍❤️‍👩🏼", "👩🏿‍❤️‍👩🏽",
    "👩🏿‍❤️‍👩🏾", "👩🏿‍❤️‍👩🏿", "👪", "👨‍👩‍👦", "👨‍👩‍👧", "👨‍👩‍👧‍👦", "👨‍👩‍👦‍👦", "👨‍👩‍👧‍👧", "👨‍👨‍👦", "👨‍👨‍👧", "👨‍👨‍👧‍👦", "👨‍👨‍👦‍👦",
    "👨‍👨‍👧‍👧", "👩‍👩‍👦", "👩‍👩‍👧", "👩‍👩‍👧‍👦", "👩‍👩‍👦‍👦", "👩‍👩‍👧‍👧", "👨‍👦", "👨‍👦‍👦", "👨‍👧", "👨‍👧‍👦", "👨‍👧‍👧", "👩‍👦",
    "👩‍👦‍👦", "👩‍👧", "👩‍👧‍👦", "👩‍👧‍👧", "🗣️", "👤", "👥", "🫂", "👣", "🏻", "🏼", "🏽",
    "🏾", "🏿", "🦰", "🦱", "🦳", "🦲", "🐵", "🐒", "🦍", "🦧", "🐶", "🐕",
    "🦮", "🐕‍🦺", "🐩", "🐺", "🦊", "🦝", "🐱", "🐈", "🐈‍⬛", "🦁", "🐯", "🐅",
    "🐆", "🐴", "🐎", "🦄", "🦓", "🦌", "🦬", "🐮", "🐂", "🐃", "🐄", "🐷",
    "🐖", "🐗", "🐽", "🐏", "🐑", "🐐", "🐪", "🐫", "🦙", "🦒", "🐘", "🦣",
    "🦏", "🦛", "🐭", "🐁", "🐀", "🐹", "🐰", "🐇", "🐿️", "🦫", "🦔", "🦇",
    "🐻", "🐻‍❄️", "🐨", "🐼", "🦥", "🦦", "🦨", "🦘", "🦡", "🐾", "🦃", "🐔",
    "🐓", "🐣", "🐤", "🐥", "🐦", "🐧", "🕊️", "🦅", "🦆", "🦢", "🦉", "🦤",
    "🪶", "🦩", "🦚", "🦜", "🐸", "🐊", "🐢", "🦎", "🐍", "🐲", "🐉", "🦕",
    "🦖", "🐳", "🐋", "🐬", "🦭", "🐟", "🐠", "🐡", "🦈", "🐙", "🐚", "🐌",
    "🦋", "🐛", "🐜", "🐝", "🪲", "🐞", "🦗", "🪳", "🕷️", "🕸️", "🦂", "🦟",
    "🪰", "🪱", "🦠", "💐", "🌸", "💮", "🏵️", "🌹", "🥀", "🌺", "🌻", "🌼",
    "🌷", "🌱", "🪴", "🌲", "🌳", "🌴", "🌵", "🌾", "🌿", "☘️", "🍀", "🍁",
    "🍂", "🍃", "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍", "🥭", "🍎", "🍏",
    "🍐", "🍑", "🍒", "🍓", "🫐", "🥝", "🍅", "🫒", "🥥", "🥑", "🍆", "🥔",
    "🥕", "🌽", "🌶️", "🫑", "🥒", "🥬", "🥦", "🧄", "🧅", "🍄", "🥜", "🌰",
    "🍞", "🥐", "🥖", "🫓", "🥨", "🥯", "🥞", "🧇", "🧀", "🍖", "🍗", "🥩",
    "🥓", "🍔", "🍟", "🍕", "🌭", "🥪", "🌮", "🌯", "🫔", "🥙", "🧆", "🥚",
    "🍳", "🥘", "🍲", "🫕", "🥣", "🥗", "🍿", "🧈", "🧂", "🥫", "🍱", "🍘",
    "🍙", "🍚", "🍛", "🍜", "🍝", "🍠", "🍢", "🍣", "🍤", "🍥", "🥮", "🍡",
    "🥟", "🥠", "🥡", "🦀", "🦞", "🦐", "🦑", "🦪", "🍦", "🍧", "🍨", "🍩",
    "🍪", "🎂", "🍰", "🧁", "🥧", "🍫", "🍬", "🍭", "🍮", "🍯", "🍼", "🥛",
    "☕", "🫖", "🍵", "🍶", "🍾", "🍷", "🍸", "🍹", "🍺", "🍻", "🥂", "🥃",
    "🥤", "🧋", "🧃", "🧉", "🧊", "🥢", "🍽️", "🍴", "🥄", "🔪", "🏺", "🌍",
    "🌎", "🌏", "🌐", "🗺️", "🗾", "🧭", "🏔️", "⛰️", "🌋", "🗻", "🏕️", "🏖️",
    "🏜️", "🏝️", "🏞️", "🏟️", "🏛️", "🏗️", "🧱", "🪨", "🪵", "🛖", "🏘️", "🏚️",
    "🏠", "🏡", "🏢", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩", "🏪", "🏫", "🏬",
    "🏭", "🏯", "🏰", "💒", "🗼", "🗽", "⛪", "🕌", "🛕", "🕍", "⛩️", "🕋",
    "⛲", "⛺", "🌁", "🌃", "🏙️", "🌄", "🌅", "🌆", "🌇", "🌉", "♨️", "🎠",
    "🎡", "🎢", "💈", "🎪", "🚂", "🚃", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉",
    "🚊", "🚝", "🚞", "🚋", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒", "🚓", "🚔",
    "🚕", "🚖", "🚗", "🚘", "🚙", "🛻", "🚚", "🚛", "🚜", "🏎️", "🏍️", "🛵",
    "🦽", "🦼", "🛺", "🚲", "🛴", "🛹", "🛼", "🚏", "🛣️", "🛤️", "🛢️", "⛽",
    "🚨", "🚥", "🚦", "🛑", "🚧", "⚓", "⛵", "🛶", "🚤", "🛳️", "⛴️", "🛥️",
    "🚢", "✈️", "🛩️", "🛫", "🛬", "🪂", "💺", "🚁", "🚟", "🚠", "🚡", "🛰️",
    "🚀", "🛸", "🛎️", "🧳", "⌛", "⏳", "⌚", "⏰", "⏱️", "⏲️", "🕰️", "🕛",
    "🕧", "🕐", "🕜", "🕑", "🕝", "🕒", "🕞", "🕓", "🕟", "🕔", "🕠", "🕕",
    "🕡", "🕖", "🕢", "🕗", "🕣", "🕘", "🕤", "🕙", "🕥", "🕚", "🕦", "🌑",
    "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌙", "🌚", "🌛", "🌜", "🌡️",
    "☀️", "🌝", "🌞", "🪐", "⭐", "🌟", "🌠", "🌌", "☁️", "⛅", "⛈️", "🌤️",
    "🌥️", "🌦️", "🌧️", "🌨️", "🌩️", "🌪️", "🌫️", "🌬️", "🌀", "🌈", "🌂", "☂️",
    "☔", "⛱️", "⚡", "❄️", "☃️", "⛄", "☄️", "🔥", "💧", "🌊", "🎃", "🎄",
    "🎆", "🎇", "🧨", "✨", "🎈", "🎉", "🎊", "🎋", "🎍", "🎎", "🎏", "🎐",
    "🎑", "🧧", "🎀", "🎁", "🎗️", "🎟️", "🎫", "🎖️", "🏆", "🏅", "🥇", "🥈",
    "🥉", "⚽", "⚾", "🥎", "🏀", "🏐", "🏈", "🏉", "🎾", "🥏", "🎳", "🏏",
    "🏑", "🏒", "🥍", "🏓", "🏸", "🥊", "🥋", "🥅", "⛳", "⛸️", "🎣", "🤿",
    "🎽", "🎿", "🛷", "🥌", "🎯", "🪀", "🪁", "🎱", "🔮", "🪄", "🧿", "🎮",
    "🕹️", "🎰", "🎲", "🧩", "🧸", "🪅", "🪆", "♠️", "♥️", "♦️", "♣️", "♟️",
    "🃏", "🀄", "🎴", "🎭", "🖼️", "🎨", "🧵", "🪡", "🧶", "🪢", "👓", "🕶️",
    "🥽", "🥼", "🦺", "👔", "👕", "👖", "🧣", "🧤", "🧥", "🧦", "👗", "👘",
    "🥻", "🩱", "🩲", "🩳", "👙", "👚", "👛", "👜", "👝", "🛍️", "🎒", "🩴",
    "👞", "👟", "🥾", "🥿", "👠", "👡", "🩰", "👢", "👑", "👒", "🎩", "🎓",
    "🧢", "🪖", "⛑️", "📿", "💄", "💍", "💎", "🔇", "🔈", "🔉", "🔊", "📢",
    "📣", "📯", "🔔", "🔕", "🎼", "🎵", "🎶", "🎙️", "🎚️", "🎛️", "🎤", "🎧",
    "📻", "🎷", "🪗", "🎸", "🎹", "🎺", "🎻", "🪕", "🥁", "🪘", "📱", "📲",
    "☎️", "📞", "📟", "📠", "🔋", "🔌", "💻", "🖥️", "🖨️", "⌨️", "🖱️", "🖲️",
    "💽", "💾", "💿", "📀", "🧮", "🎥", "🎞️", "📽️", "🎬", "📺", "📷", "📸",
    "📹", "📼", "🔍", "🔎", "🕯️", "💡", "🔦", "🏮", "🪔", "📔", "📕", "📖",
    "📗", "📘", "📙", "📚", "📓", "📒", "📃", "📜", "📄", "📰", "🗞️", "📑",
    "🔖", "🏷️", "💰", "🪙", "💴", "💵", "💶", "💷", "💸", "💳", "🧾", "💹",
    "✉️", "📧", "📨", "📩", "📤", "📥", "📦", "📫", "📪", "📬", "📭", "📮",
    "🗳️", "✏️", "✒️", "🖋️", "🖊️", "🖌️", "🖍️", "📝", "💼", "📁", "📂", "🗂️",
    "📅", "📆", "🗒️", "🗓️", "📇", "📈", "📉", "📊", "📋", "📌", "📍", "📎",
    "🖇️", "📏", "📐", "✂️", "🗃️", "🗄️", "🗑️", "🔒", "🔓", "🔏", "🔐", "🔑",
    "🗝️", "🔨", "🪓", "⛏️", "⚒️", "🛠️", "🗡️", "⚔️", "🔫", "🪃", "🏹", "🛡️",
    "🪚", "🔧", "🪛", "🔩", "⚙️", "🗜️", "⚖️", "🦯", "🔗", "⛓️", "🪝", "🧰",
    "🧲", "🪜", "⚗️", "🧪", "🧫", "🧬", "🔬", "🔭", "📡", "💉", "🩸", "💊",
    "🩹", "🩺", "🚪", "🛗", "🪞", "🪟", "🛏️", "🛋️", "🪑", "🚽", "🪠", "🚿",
    "🛁", "🪤", "🪒", "🧴", "🧷", "🧹", "🧺", "🧻", "🪣", "🧼", "🪥", "🧽",
    "🧯", "🛒", "🚬", "⚰️", "🪦", "⚱️", "🗿", "🪧", "🏧", "🚮", "🚰", "♿",
    "🚹", "🚺", "🚻", "🚼", "🚾", "🛂", "🛃", "🛄", "🛅", "⚠️", "🚸", "⛔",
    "🚫", "🚳", "🚭", "🚯", "🚱", "🚷", "📵", "🔞", "☢️", "☣️", "⬆️", "↗️",
    "➡️", "↘️", "⬇️", "↙️", "⬅️", "↖️", "↕️", "↔️", "↩️", "↪️", "⤴️", "⤵️",
    "🔃", "🔄", "🔙", "🔚", "🔛", "🔜", "🔝", "🛐", "⚛️", "🕉️", "✡️", "☸️",
    "☯️", "✝️", "☦️", "☪️", "☮️", "🕎", "🔯", "♈", "♉", "♊", "♋", "♌",
    "♍", "♎", "♏", "♐", "♑", "♒", "♓", "⛎", "🔀", "🔁", "🔂", "▶️",
    "⏩", "⏭️", "⏯️", "◀️", "⏪", "⏮️", "🔼", "⏫", "🔽", "⏬", "⏸️", "⏹️",
    "⏺️", "⏏️", "🎦", "🔅", "🔆", "📶", "📳", "📴", "♀️", "♂️", "⚧️", "✖️",
    "➕", "➖", "➗", "♾️", "‼️", "⁉️", "❓", "❔", "❕", "❗", "〰️", "💱",
    "💲", "⚕️", "♻️", "⚜️", "🔱", "📛", "🔰", "⭕", "✅", "☑️", "✔️", "❌",
    "❎", "➰", "➿", "〽️", "✳️", "✴️", "❇️", "©️", "®️", "™️", "#️⃣", "*️⃣",
    "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟", "🔠",
    "🔡", "🔢", "🔣", "🔤", "🅰️", "🆎", "🅱️", "🆑", "🆒", "🆓", "ℹ️", "🆔",
    "Ⓜ️", "🆕", "🆖", "🅾️", "🆗", "🅿️", "🆘", "🆙", "🆚", "🈁", "🈂️", "🈷️",
    "🈶", "🈯", "🉐", "🈹", "🈚", "🈲", "🉑", "🈸", "🈴", "🈳", "㊗️", "㊙️",
    "🈺", "🈵", "🔴", "🟠", "🟡", "🟢", "🔵", "🟣", "🟤", "⚫", "⚪", "🟥",
    "🟧", "🟨", "🟩", "🟦", "🟪", "🟫", "⬛", "⬜", "◼️", "◻️", "◾", "◽",
    "▪️", "▫️", "🔶", "🔷", "🔸", "🔹", "🔺", "🔻", "💠", "🔘", "🔳", "🔲",
    "🏁", "🚩", "🎌", "🏴", "🏳️", "🏳️‍🌈", "🏳️‍⚧️", "🏴‍☠️", "🇦🇨", "🇦🇩", "🇦🇪", "🇦🇫",
    "🇦🇬", "🇦🇮", "🇦🇱", "🇦🇲", "🇦🇴", "🇦🇶", "🇦🇷", "🇦🇸", "🇦🇹", "🇦🇺", "🇦🇼", "🇦🇽",
    "🇦🇿", "🇧🇦", "🇧🇧", "🇧🇩", "🇧🇪", "🇧🇫", "🇧🇬", "🇧🇭", "🇧🇮", "🇧🇯", "🇧🇱", "🇧🇲",
    "🇧🇳", "🇧🇴", "🇧🇶", "🇧🇷", "🇧🇸", "🇧🇹", "🇧🇻", "🇧🇼", "🇧🇾", "🇧🇿", "🇨🇦", "🇨🇨",
    "🇨🇩", "🇨🇫", "🇨🇬", "🇨🇭", "🇨🇮", "🇨🇰", "🇨🇱", "🇨🇲", "🇨🇳", "🇨🇴", "🇨🇵", "🇨🇷",
    "🇨🇺", "🇨🇻", "🇨🇼", "🇨🇽", "🇨🇾", "🇨🇿", "🇩🇪", "🇩🇬", "🇩🇯", "🇩🇰", "🇩🇲", "🇩🇴",
    "🇩🇿", "🇪🇦", "🇪🇨", "🇪🇪", "🇪🇬", "🇪🇭", "🇪🇷", "🇪🇸", "🇪🇹", "🇪🇺", "🇫🇮", "🇫🇯",
    "🇫🇰", "🇫🇲", "🇫🇴", "🇫🇷", "🇬🇦", "🇬🇧", "🇬🇩", "🇬🇪", "🇬🇫", "🇬🇬", "🇬🇭", "🇬🇮",
    "🇬🇱", "🇬🇲", "🇬🇳", "🇬🇵", "🇬🇶", "🇬🇷", "🇬🇸", "🇬🇹", "🇬🇺", "🇬🇼", "🇬🇾", "🇭🇰",
    "🇭🇲", "🇭🇳", "🇭🇷", "🇭🇹", "🇭🇺", "🇮🇨", "🇮🇩", "🇮🇪", "🇮🇱", "🇮🇲", "🇮🇳", "🇮🇴",
    "🇮🇶", "🇮🇷", "🇮🇸", "🇮🇹", "🇯🇪", "🇯🇲", "🇯🇴", "🇯🇵", "🇰🇪", "🇰🇬", "🇰🇭", "🇰🇮",
    "🇰🇲", "🇰🇳", "🇰🇵", "🇰🇷", "🇰🇼", "🇰🇾", "🇰🇿", "🇱🇦", "🇱🇧", "🇱🇨", "🇱🇮", "🇱🇰",
    "🇱🇷", "🇱🇸", "🇱🇹", "🇱🇺", "🇱🇻", "🇱🇾", "🇲🇦", "🇲🇨", "🇲🇩", "🇲🇪", "🇲🇫", "🇲🇬",
    "🇲🇭", "🇲🇰", "🇲🇱", "🇲🇲", "🇲🇳", "🇲🇴", "🇲🇵", "🇲🇶", "🇲🇷", "🇲🇸", "🇲🇹", "🇲🇺",
    "🇲🇻", "🇲🇼", "🇲🇽", "🇲🇾", "🇲🇿", "🇳🇦", "🇳🇨", "🇳🇪", "🇳🇫", "🇳🇬", "🇳🇮", "🇳🇱",
    "🇳🇴", "🇳🇵", "🇳🇷", "🇳🇺", "🇳🇿", "🇴🇲", "🇵🇦", "🇵🇪", "🇵🇫", "🇵🇬", "🇵🇭", "🇵🇰",
    "🇵🇱", "🇵🇲", "🇵🇳", "🇵🇷", "🇵🇸", "🇵🇹", "🇵🇼", "🇵🇾", "🇶🇦", "🇷🇪", "🇷🇴", "🇷🇸",
    "🇷🇺", "🇷🇼", "🇸🇦", "🇸🇧", "🇸🇨", "🇸🇩", "🇸🇪", "🇸🇬", "🇸🇭", "🇸🇮", "🇸🇯", "🇸🇰",
    "🇸🇱", "🇸🇲", "🇸🇳", "🇸🇴", "🇸🇷", "🇸🇸", "🇸🇹", "🇸🇻", "🇸🇽", "🇸🇾", "🇸🇿", "🇹🇦",
    "🇹🇨", "🇹🇩", "🇹🇫", "🇹🇬", "🇹🇭", "🇹🇯", "🇹🇰", "🇹🇱", "🇹🇲", "🇹🇳", "🇹🇴", "🇹🇷",
    "🇹🇹", "🇹🇻", "🇹🇼", "🇹🇿", "🇺🇦", "🇺🇬", "🇺🇲", "🇺🇳", "🇺🇸", "🇺🇾", "🇺🇿", "🇻🇦",
    "🇻🇨", "🇻🇪", "🇻🇬", "🇻🇮", "🇻🇳", "🇻🇺", "🇼🇫", "🇼🇸", "🇽🇰", "🇾🇪", "🇾🇹", "🇿🇦",
    "🇿🇲", "🇿🇼", "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "🏴󠁧󠁢󠁳󠁣󠁴󠁿", "🏴󠁧󠁢󠁷󠁬󠁳󠁿", "🛜", "🛝", "🛞", "🛟", "🟰", "🥹", "🧌",
    "🩵", "🩶", "🩷", "🩻", "🩼", "🪇", "🪈", "🪉", "🪏", "🪩", "🪪", "🪫",
    "🪬", "🪭", "🪮", "🪯", "🪷", "🪸", "🪹", "🪺", "🪻", "🪼", "🪽", "🪾",
    "🪿", "🫃", "🫄", "🫅", "🫆", "🫎", "🫏", "🫗", "🫘", "🫙", "🫚", "🫛",
    "🫜", "🫟", "🫠", "🫡", "🫢", "🫣", "🫤", "🫥", "🫦", "🫧", "🫨", "🫩",
    "🫰", "🫱", "🫲", "🫳", "🫴", "🫵", "🫶", "🫷", "🫸", "🇦🇦", "🇦🇧", "🇦🇭",
    "🇦🇯", "🇦🇰", "🇦🇳", "🇦🇵", "🇦🇻", "🇦🇾", "🇧🇨", "🇧🇰", "🇧🇵", "🇧🇺", "🇧🇽", "🇨🇧",
    "🇨🇪", "🇨🇯", "🇨🇶", "🇨🇸", "🇨🇹", "🇩🇦", "🇩🇧", "🇩🇨", "🇩🇩", "🇩🇫", "🇩🇭", "🇩🇮",
    "🇩🇱", "🇩🇳", "🇩🇵", "🇩🇶", "🇩🇷", "🇩🇸", "🇩🇹", "🇩🇺", "🇩🇻", "🇩🇼", "🇩🇽", "🇩🇾",
    "🇪🇧", "🇪🇩", "🇪🇫", "🇪🇮", "🇪🇯", "🇪🇰", "🇪🇱", "🇪🇲", "🇪🇳", "🇪🇴", "🇪🇵", "🇪🇶",
    "🇪🇻", "🇪🇼", "🇪🇽", "🇪🇾", "🇪🇿", "🇫🇦", "🇫🇧", "🇫🇨", "🇫🇩", "🇫🇪", "🇫🇫", "🇫🇬",
    "🇫🇭", "🇫🇱", "🇫🇳", "🇫🇵", "🇫🇶", "🇫🇸", "🇫🇹", "🇫🇺", "🇫🇻", "🇫🇼", "🇫🇽", "🇫🇾",
    "🇫🇿", "🇬🇨", "🇬🇯", "🇬🇰", "🇬🇴", "🇬🇻", "🇬🇽", "🇬🇿", "🇭🇦", "🇭🇧", "🇭🇨", "🇭🇩",
    "🇭🇪", "🇭🇫", "🇭🇬", "🇭🇭", "🇭🇮", "🇭🇯", "🇭🇱", "🇭🇴", "🇭🇵", "🇭🇶", "🇭🇸", "🇭🇻",
    "🇭🇼", "🇭🇽", "🇭🇾", "🇭🇿", "🇮🇦", "🇮🇧", "🇮🇫", "🇮🇬", "🇮🇭", "🇮🇮", "🇮🇯", "🇮🇰",
    "🇮🇵", "🇮🇺", "🇮🇻", "🇮🇼", "🇮🇽", "🇮🇾", "🇮🇿", "🇯🇦", "🇯🇧", "🇯🇨", "🇯🇩", "🇯🇫",
    "🇯🇬", "🇯🇭", "🇯🇮", "🇯🇯", "🇯🇰", "🇯🇱", "🇯🇳", "🇯🇶", "🇯🇷", "🇯🇸", "🇯🇹", "🇯🇺",
    "🇯🇻", "🇯🇼", "🇯🇽", "🇯🇾", "🇯🇿", "🇰🇦", "🇰🇧", "🇰🇨", "🇰🇩", "🇰🇫", "🇰🇯", "🇰🇰",
    "🇰🇱", "🇰🇴", "🇰🇶", "🇰🇸", "🇰🇹", "🇰🇺", "🇰🇻", "🇰🇽", "🇱🇩", "🇱🇪", "🇱🇫", "🇱🇬",
    "🇱🇭", "🇱🇯", "🇱🇱", "🇱🇲", "🇱🇳", "🇱🇴", "🇱🇵", "🇱🇶", "🇱🇼", "🇱🇽", "🇱🇿", "🇲🇧",
    "🇲🇮", "🇲🇯", "🇳🇧", "🇳🇩", "🇳🇭", "🇳🇯", "🇳🇰", "🇳🇲", "🇳🇳", "🇳🇶", "🇳🇸", "🇳🇹",
    "🇳🇻", "🇳🇼", "🇳🇽", "🇳🇾", "🇴🇦", "🇴🇧", "🇴🇨", "🇴🇩", "🇴🇪", "🇴🇫", "🇴🇬", "🇴🇭",
    "🇴🇮", "🇴🇯", "🇴🇰", "🇴🇱", "🇴🇳", "🇴🇴", "🇴🇵", "🇴🇶", "🇴🇷", "🇴🇸", "🇴🇹", "🇴🇺",
    "🇴🇻", "🇴🇼", "🇴🇽", "🇴🇾", "🇴🇿", "🇵🇧", "🇵🇨", "🇵🇩", "🇵🇮", "🇵🇯", "🇵🇴", "🇵🇵",
    "🇵🇶", "🇵🇺", "🇵🇻", "🇵🇽", "🇵🇿", "🇶🇧", "🇶🇨", "🇶🇩", "🇶🇪", "🇶🇫", "🇶🇬", "🇶🇭",
    "🇶🇮", "🇶🇯", "🇶🇰", "🇶🇱", "🇶🇲", "🇶🇳", "🇶🇴", "🇶🇵", "🇶🇶", "🇶🇷", "🇶🇸", "🇶🇹",
    "🇶🇺", "🇶🇻", "🇶🇼", "🇶🇽", "🇶🇾", "🇶🇿", "🇷🇦", "🇷🇧", "🇷🇨", "🇷🇩", "🇷🇫", "🇷🇬",
    "🇷🇭", "🇷🇮", "🇷🇯", "🇷🇰", "🇷🇱", "🇷🇲", "🇷🇳", "🇷🇵", "🇷🇶", "🇷🇷", "🇷🇹", "🇷🇻",
    "🇷🇽", "🇷🇾", "🇷🇿", "🇸🇫", "🇸🇵", "🇸🇶", "🇸🇺", "🇸🇼", "🇹🇧", "🇹🇪", "🇹🇮", "🇹🇵",
    "🇹🇶", "🇹🇸", "🇹🇺", "🇹🇽", "🇹🇾", "🇺🇧", "🇺🇨", "🇺🇩", "🇺🇪", "🇺🇫", "🇺🇭", "🇺🇮",
    "🇺🇯", "🇺🇰", "🇺🇱", "🇺🇴", "🇺🇵", "🇺🇶", "🇺🇷", "🇺🇹", "🇺🇺", "🇺🇻", "🇺🇼", "🇺🇽",
    "🇻🇧", "🇻🇩", "🇻🇫", "🇻🇭", "🇻🇯", "🇻🇰", "🇻🇱", "🇻🇲", "🇻🇴", "🇻🇵", "🇻🇶", "🇻🇷",
    "🇻🇸", "🇻🇹", "🇻🇻", "🇻🇼", "🇻🇽", "🇻🇾", "🇻🇿", "🇼🇦", "🇼🇧", "🇼🇨", "🇼🇩", "🇼🇪",
    "🇼🇬", "🇼🇭", "🇼🇮", "🇼🇯", "🇼🇰", "🇼🇱", "🇼🇲", "🇼🇳", "🇼🇴", "🇼🇵", "🇼🇶", "🇼🇷",
    "🇼🇹", "🇼🇺", "🇼🇻", "🇼🇼", "🇼🇽", "🇼🇾", "🇼🇿", "🇽🇦", "🇽🇧", "🇽🇨", "🇽🇩", "🇽🇪",
    "🇽🇫", "🇽🇬", "🇽🇭", "🇽🇮", "🇽🇯", "🇽🇱", "🇽🇲", "🇽🇳", "🇽🇴", "🇽🇵", "🇽🇶", "🇽🇷",
    "🇽🇸", "🇽🇹", "🇽🇺", "🇽🇻", "🇽🇼", "🇽🇽", "🇽🇾", "🇽🇿", "🇾🇦", "🇾🇧", "🇾🇨", "🇾🇩",
    "🇾🇫", "🇾🇬", "🇾🇭", "🇾🇮", "🇾🇯", "🇾🇰", "🇾🇱", "🇾🇲", "🇾🇳", "🇾🇴", "🇾🇵", "🇾🇶",
    "🇾🇷", "🇾🇸", "🇾🇺", "🇾🇻", "🇾🇼", "🇾🇽", "🇾🇾", "🇾🇿", "🇿🇧", "🇿🇨", "🇿🇩", "🇿🇪",
    "🇿🇫", "🇿🇬", "🇿🇭", "🇿🇮", "🇿🇯", "🇿🇰", "🇿🇱", "🇿🇳", "🇿🇴", "🇿🇵", "🇿🇶", "🇿🇷",
    "🇿🇸", "🇿🇹", "🇿🇺", "🇿🇻", "🇿🇽", "🇿🇾", "🇿🇿", "👪🏻", "👪🏼", "👪🏽", "👪🏾", "👪🏿",
    "👯🏻", "👯🏼", "👯🏽", "👯🏾", "👯🏿", "🤝🏻", "🤝🏼", "🤝🏽", "🤝🏾", "🤝🏿", "🤼🏻", "🤼🏼",
    "🤼🏽", "🤼🏾", "🤼🏿", "🫃🏻", "🫃🏼", "🫃🏽", "🫃🏾", "🫃🏿", "🫄🏻", "🫄🏼", "🫄🏽", "🫄🏾",
    "🫄🏿", "🫅🏻", "🫅🏼", "🫅🏽", "🫅🏾", "🫅🏿", "🫰🏻", "🫰🏼", "🫰🏽", "🫰🏾", "🫰🏿", "🫱🏻",
    "🫱🏼", "🫱🏽", "🫱🏾", "🫱🏿", "🫲🏻", "🫲🏼", "🫲🏽", "🫲🏾", "🫲🏿", "🫳🏻", "🫳🏼", "🫳🏽",
    "🫳🏾", "🫳🏿", "🫴🏻", "🫴🏼", "🫴🏽", "🫴🏾", "🫴🏿", "🫵🏻", "🫵🏼", "🫵🏽", "🫵🏾", "🫵🏿",
    "🫶🏻", "🫶🏼", "🫶🏽", "🫶🏾", "🫶🏿", "🫷🏻", "🫷🏼", "🫷🏽", "🫷🏾", "🫷🏿", "🫸🏻", "🫸🏼",
    "🫸🏽", "🫸🏾", "🫸🏿",
}

-- ===== Sticker UI behavior =====
local customStickers = {}
local function readCustomStickers()
    if not (readfile and isfile) then return end
    pcall(function()
        if isfile("NeoHyper_CustomStickers.json") then
            local data = HttpService:JSONDecode(readfile("NeoHyper_CustomStickers.json"))
            if type(data) == "table" then customStickers = data end
        end
    end)
end
local function saveCustomStickers()
    if not writefile then return end
    pcall(function() writefile("NeoHyper_CustomStickers.json", HttpService:JSONEncode(customStickers)) end)
end
readCustomStickers()

-- Recientes: ultimos 8 stickers enviados (se guardan en NeoHyper_ChatSettings.json)
Chat.pushFav = function(assetId, frames, interval)
    if type(assetId) ~= "string" or assetId == "" then return end
    local out = {{id = assetId, frames = normalizeFrames(frames), interval = interval}}
    for _, f in ipairs(Chat.settings.StickerFavs) do
        if type(f) == "table" and f.id ~= assetId then out[#out + 1] = f end
        if #out >= 8 then break end
    end
    Chat.settings.StickerFavs = out
    Chat.saveSettings()
end

local function sendSticker(assetId, frames, interval)
    local msg = stickerBuild(assetId, frames, interval)
    sendPayload(msg)
    Chat.pushFav(assetId, frames, interval)
    StickerPanel.Visible = false
end

local function sendEmoji(emoji)
    local msg = tostring(emoji or "")
    if msg == "" then return end
    if reactionPickerTargetKey then
        local meta = messageRows[reactionPickerTargetKey]
        reactionPickerTargetKey = nil
        if meta then addLocalReaction(meta, msg) end
        StickerPanel.Visible = false
        return
    end
    sendPayload(msg)
end

local function refreshGrid(grid, layout)
    -- v8: el canvas ya es automatico (AutomaticCanvasSize); se deja en 0 para no pisarlo.
    pcall(function() grid.CanvasSize = UDim2.new() end)
end

local function createStickerButton(parent, assetId, isCustom, frames, interval)
    local btn = mk("ImageButton", {
        Size=UDim2.fromOffset(62,62),
        BackgroundColor3=THEME.PANEL,
        BackgroundTransparency=0.2,
        BorderSizePixel=0,
        Image=assetId,
        ScaleType=Enum.ScaleType.Fit,
        ZIndex=53,
    }, parent)
    corner(btn, 8)
    stroke(btn, THEME.ACC2, 1, 0.65)
    if frames then animateSticker(btn, frames, interval) end
    btn.MouseButton1Click:Connect(function() sendSticker(assetId, frames, interval) end)

    if isCustom then
        local del = mk("TextButton", {
            Size=UDim2.fromOffset(17,17), Position=UDim2.new(1,-19,0,2),
            BackgroundColor3=THEME.DANGER, BorderSizePixel=0, Text="×",
            TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=11, ZIndex=54,
        }, btn)
        corner(del, 4)
        del.MouseButton1Click:Connect(function()
            for i,s in ipairs(customStickers) do
                if s.id == assetId then table.remove(customStickers,i) break end
            end
            saveCustomStickers()
            btn:Destroy()
        end)
    end
    return btn
end

local function populateStickers()
    for _, child in ipairs(StickerGrid:GetChildren()) do
        if child:IsA("ImageButton") then child:Destroy() end
    end
    local order = StickerOrder or {"Sonrisa","Llorar","Amor","Corazon","Emoji","Risa","Sorpresa","Triste","Enojado","Wink","Cool"}
    for _, name in ipairs(order) do
        local s = StickerPalettes[name]
        if s and s.Image then createStickerButton(StickerGrid, s.Image, false, normalizeFrames(s.Frames), s.Interval) end
    end
    refreshGrid(StickerGrid, StickerLayout)
end

Chat.populateFavs = function()
    for _, child in ipairs(UI.FavGrid:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    local any = false
    for i, f in ipairs(Chat.settings.StickerFavs) do
        if type(f) == "table" and type(f.id) == "string" then
            any = true
            local btn = createStickerButton(UI.FavGrid, f.id, false, normalizeFrames(f.frames), f.interval)
            btn.LayoutOrder = i
        end
    end
    if not any then
        mk("TextLabel", {
            Size = UDim2.fromOffset(240, 40), BackgroundTransparency = 1,
            Text = "Aún no enviaste stickers", TextColor3 = THEME.DIM,
            Font = Enum.Font.GothamMedium, TextSize = 12, TextWrapped = true, ZIndex = 53,
        }, UI.FavGrid)
    end
    refreshGrid(UI.FavGrid, UI.FavLayout)
end

local function createEmojiButton(parent, emoji)
    local btn = mk("TextButton", {
        Size=UDim2.fromOffset(44,44),
        BackgroundColor3=THEME.PANEL,
        BackgroundTransparency=0.35,
        BorderSizePixel=0,
        Text=emoji,
        TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.Gotham,
        TextSize=28,
        AutoButtonColor=true,
        ZIndex=53,
    }, parent)
    corner(btn, 8)
    btn.MouseButton1Click:Connect(function() sendEmoji(emoji) end)
    return btn
end

local EMOJI_BATCH_SIZE = 120
local emojiNextIndex = 1
local emojiLoading = false

local function loadNextEmojiBatch()
    if emojiLoading or emojiNextIndex > #EMOJI_LIST then return end
    emojiLoading = true
    local lastIndex = math.min(emojiNextIndex + EMOJI_BATCH_SIZE - 1, #EMOJI_LIST)
    for i = emojiNextIndex, lastIndex do
        createEmojiButton(EmojiGrid, EMOJI_LIST[i])
    end
    emojiNextIndex = lastIndex + 1
    refreshGrid(EmojiGrid, EmojiLayout)
    emojiLoading = false
end

local function populateEmojis()
    for _, child in ipairs(EmojiGrid:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    emojiNextIndex = 1
    loadNextEmojiBatch()
end

EmojiGrid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    local bottom = EmojiGrid.CanvasPosition.Y + EmojiGrid.AbsoluteSize.Y
    if bottom >= EmojiGrid.AbsoluteCanvasSize.Y - 180 then
        loadNextEmojiBatch()
    end
end)

for _, s in ipairs(customStickers) do
    if type(s) == "table" and type(s.id) == "string" then
        createStickerButton(MineGrid, s.id, true)
    end
end

-- Add button lives inside the custom grid.
local AddStickerBtn = mk("TextButton", {
    Size=UDim2.fromOffset(62,62), BackgroundColor3=THEME.PANEL, BackgroundTransparency=0.2,
    BorderSizePixel=0, Text="+", TextColor3=THEME.DIM, Font=Enum.Font.GothamBold, TextSize=26, ZIndex=53,
    LayoutOrder=9999,
}, MineGrid)
corner(AddStickerBtn, 8)
stroke(AddStickerBtn, THEME.ACC2, 1, 0.45)

showStickerTab = function(mine, emoji, favs)
    favs = favs == true
    StickerGrid.Visible = not mine and not emoji and not favs
    MineGrid.Visible = mine
    EmojiGrid.Visible = emoji == true
    UI.FavGrid.Visible = favs
    AddStickerInput.Visible = mine and AddStickerInput.Visible or false
    ConfirmAdd.Visible = mine and ConfirmAdd.Visible or false
    TabStickers.BackgroundColor3 = (not mine and not emoji and not favs) and THEME.ACC or THEME.PANEL2
    TabMine.BackgroundColor3 = mine and THEME.ACC or THEME.PANEL2
    TabEmoji.BackgroundColor3 = (emoji == true) and THEME.ACC or THEME.PANEL2
    UI.TabFavs.BackgroundColor3 = favs and THEME.ACC or THEME.PANEL2
    -- v8 FIX: texto oscuro en la pestaña activa (antes blanco sobre blanco, no se leia)
    for _, tab in ipairs({TabStickers, TabMine, TabEmoji, UI.TabFavs}) do
        tab.TextColor3 = tab.BackgroundColor3 == THEME.ACC and Color3.fromRGB(10, 10, 10) or THEME.TXT
    end
    if favs then Chat.populateFavs() end
end

TabStickers.MouseButton1Click:Connect(function() showStickerTab(false) end)
TabMine.MouseButton1Click:Connect(function() showStickerTab(true) end)
TabEmoji.MouseButton1Click:Connect(function() showStickerTab(false, true) end)
UI.TabFavs.MouseButton1Click:Connect(function() showStickerTab(false, false, true) end)
PanelClose.MouseButton1Click:Connect(function() StickerPanel.Visible=false reactionPickerTargetKey=nil end)

AddStickerBtn.MouseButton1Click:Connect(function()
    AddStickerInput.Visible = not AddStickerInput.Visible
    ConfirmAdd.Visible = AddStickerInput.Visible
end)

ConfirmAdd.MouseButton1Click:Connect(function()
    local id = tostring(AddStickerInput.Text or ""):match("^%s*(.-)%s*$") or ""
    if id == "" then return end
    if not id:match("^rbxassetid://%d+$") then
        local digits = id:match("(%d+)")
        if not digits then return end
        id = "rbxassetid://" .. digits
    end
    customStickers[#customStickers+1] = {id=id, name="Custom"}
    saveCustomStickers()
    createStickerButton(MineGrid, id, true)
    refreshGrid(MineGrid, MineLayout)
    AddStickerInput.Text=""
    AddStickerInput.Visible=false
    ConfirmAdd.Visible=false
end)

StickerButton.MouseButton1Click:Connect(function()
    reactionPickerTargetKey = nil
    StickerPanel.Visible = not StickerPanel.Visible
    if StickerPanel.Visible then showStickerTab(false) end
end)

-- ===== Polling Firebase: sala abierta (global o privado) =====
-- (El polling del Railway se quito: ahora todo es Firebase.)
task.spawn(function()
    local myGen = generation
    local tick, lastRgen = 0, -1
    while generation == myGen and ScreenGui.Parent do
        Chat.pollNow = false
        if Chat.view == "chat" then
            local room, rgen = Chat.room, Chat.roomGen
            if rgen ~= lastRgen then tick, lastRgen = 0, rgen end
            tick += 1
            local ok, data = Chat.fbCall("GET", "chat/" .. room .. "/messages", nil, "orderBy=%22$key%22&limitToLast=40")
            if ok and rgen == Chat.roomGen then
                Chat.handleRoomData(type(data) == "table" and data or {}, room)
                if firebaseInitialLoad then
                    firebaseInitialLoad = false
                    if next(messageRows) == nil then
                        EmptyLabel.Text = "Aún no hay mensajes. ¡Escribe el primero!"
                        EmptyLabel.Visible = true
                    end
                end
            end
            -- Mensaje fijado (cada 2 vueltas)
            if tick % 2 == 1 and rgen == Chat.roomGen then
                local pok, pd = Chat.fbCall("GET", "chat/" .. room .. "/pin")
                if pok and rgen == Chat.roomGen then
                    Chat.pin = (type(pd) == "table" and pd.key) and pd or nil
                    Chat.refreshPin()
                end
            end
            -- "escribiendo..." en privados y (v12) en el global, con nombres (como grupos de WhatsApp)
            if rgen == Chat.roomGen then
                local tok, td = Chat.fbCall("GET", "typing/" .. room)
                if tok and rgen == Chat.roomGen then
                    local names = {}
                    if type(td) == "table" then
                        local now = Chat.serverNowMs()
                        for tuid, v in pairs(td) do
                            if tostring(tuid) ~= tostring(LocalPlayer.UserId) and type(v) == "table"
                                and tonumber(v.t) and math.abs(now - v.t) < 5000 then
                                names[#names + 1] = tostring(v.n or (Chat.kind == "private" and Chat.targetUser) or "Alguien")
                            end
                        end
                    end
                    table.sort(names)
                    local typing = #names > 0
                    local key = table.concat(names, ",")
                    if typing ~= Chat.typing or key ~= Chat.typingKey then
                        Chat.typing = typing
                        Chat.typingKey = key
                        Chat.typingNames = names
                        Chat.updateHeader()
                        Chat.refreshTypingPill()
                    end
                end
            end
        end
        local waited = 0
        while waited < CONFIG.FB_POLL_RATE and not Chat.pollNow do
            task.wait(0.25)
            waited += 0.25
        end
    end
end)

-- ===== Segundo plano: global, inbox y privados (badges, vista previa, avisos) =====
task.spawn(function()
    local myGen = generation
    local rr = 0
    task.wait(1)
    while generation == myGen and ScreenGui.Parent do
        local okTick, err = pcall(Chat.watchTick, rr)
        if not okTick then warn("[YY Chat] watchTick: " .. tostring(err)) end
        rr += 1
        if Chat.dirty then
            Chat.dirty = false
            Chat.saveSettings()
        end
        task.wait(CONFIG.WATCH_RATE)
    end
end)

-- ===== Presence =====
task.spawn(function()
    local myGen = generation
    while generation == myGen and ScreenGui.Parent do
        pcall(function()
            local res = request({
                Url=FIREBASE .. "presence/" .. tostring(LocalPlayer.UserId) .. ".json",
                Method="PUT",
                Headers={["Content-Type"]="application/json"},
                Body=HttpService:JSONEncode({n=LocalPlayer.Name,t={ [".sv"]="timestamp" }}),
            })
            -- v12: Firebase devuelve la hora real del servidor -> desfase del reloj del celular
            local okD, d = pcall(HttpService.JSONDecode, HttpService, res and res.Body or "")
            if okD and type(d) == "table" and tonumber(d.t) then
                Chat.clockSkew = tonumber(d.t) - os.time() * 1000
            end
        end)
        -- Contador online = presence de Firebase + onlineCount del Railway (como la libreria)
        pcall(Chat.refreshPresence)
        task.spawn(function() pcall(Chat.refreshRailwayOnline) end)
        task.wait(20)
    end
end)

-- ===== Input =====
MessageBox:GetPropertyChangedSignal("Text"):Connect(function()
    if #MessageBox.Text > CONFIG.MAX_CHAR then MessageBox.Text=MessageBox.Text:sub(1,CONFIG.MAX_CHAR) end
    CharLabel.Text=tostring(#MessageBox.Text) .. "/" .. tostring(CONFIG.MAX_CHAR)
end)
SendButton.MouseButton1Click:Connect(sendText)
MessageBox.FocusLost:Connect(function(enterPressed) if enterPressed then sendText() end end)

-- v8: boton para reabrir = foto redonda del grupo con anillo tipo historia (antes "CHAT" blanco sobre blanco)
local Reopen = mk("TextButton", {
    -- v11: mucho mas arriba (debajo del icono de Yin Yang, lado derecho)
    Size=UDim2.fromOffset(62,62), AnchorPoint=Vector2.new(1,0), Position=UDim2.new(1,-16,0.2,0), -- v13: antes 0.3
    BackgroundColor3=THEME.BG, BorderSizePixel=0, Text="",
    AutoButtonColor=true, Visible=false, ZIndex=100,
}, ScreenGui)
corner(Reopen,30)
UI.storyRing(Reopen, 3)
UI.ReopenImg = mk("ImageLabel", {
    Size=UDim2.new(1,-8,1,-8), Position=UDim2.fromOffset(4,4), BackgroundTransparency=1,
    Image=UI.ICON.group, ScaleType=Enum.ScaleType.Crop, ZIndex=101,
}, Reopen)
corner(UI.ReopenImg,26)
UI.Reopen = Reopen
-- Badge de no leidos sobre el boton CHAT
UI.ReopenBadge = mk("TextLabel", {
    AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(1,-6,0,6),
    Size=UDim2.fromOffset(0,24), AutomaticSize=Enum.AutomaticSize.X,
    BackgroundColor3=Color3.fromRGB(37,211,102), BorderSizePixel=0, Text="0", -- v11: verde WhatsApp
    TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBlack, TextSize=13,
    Visible=false, ZIndex=103,
}, Reopen)
corner(UI.ReopenBadge,12)
stroke(UI.ReopenBadge, THEME.BG, 2, 0)
mk("UIPadding", {PaddingLeft=UDim.new(0,7), PaddingRight=UDim.new(0,7)}, UI.ReopenBadge)
mk("UISizeConstraint", {MinSize=Vector2.new(24,24)}, UI.ReopenBadge)
UI.ReopenBadgeScale = mk("UIScale", {Scale=1}, UI.ReopenBadge)
-- Antes el boton CHAT nunca se mostraba al cerrar; ahora aparece (y lleva el badge).
CloseButton.MouseButton1Click:Connect(function()
    open=false Surface.Enabled=false StickerPanel.Visible=false
    Chat.hideOverlays()
    Reopen.Visible=true
    Chat.updateBadge()
end)
Reopen.MouseButton1Click:Connect(function()
    open=true Surface.Enabled=true Reopen.Visible=false scrollBottom()
    if Chat.view == "chat" then Chat.unread[Chat.room] = 0 end
    Chat.updateBadge()
    if Chat.view == "home" then Chat.refreshHome(true) end
end)

-- ===== Tilt / responsive =====
local panelOffset=Vector2.new(0,0)
local dragInput=nil
local dragLast=nil
local dragging=false

local function pointerPos(input)
    if input and input.Position then return Vector2.new(input.Position.X,input.Position.Y) end
    return UserInputService:GetMouseLocation()
end

-- v10 FIX arrastre: antes (1) cualquier dedo que se moviera (joystick/camara) movia el panel y
-- (2) el primer punto salia del header de la SurfaceGui y los siguientes de UserInputService,
-- que pueden estar en coordenadas distintas -> el primer movimiento daba un salto.
-- Ahora: solo cuenta el mismo toque que empezo el arrastre, el primer punto se toma del propio
-- UserInputService, y se descartan saltos imposibles de un frame.
Chat.drag = {touchT = 0}
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        Chat.drag.lastTouch = input
        Chat.drag.touchT = os.clock()
    end
end)
Header.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
        dragging=true dragInput=input dragLast=nil
        Chat.drag.startT = os.clock()
        Chat.drag.alt = nil
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end
    if dragInput.UserInputType == Enum.UserInputType.Touch then
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        if input ~= dragInput then
            -- mismo dedo visto por UserInputService (empezo casi al mismo tiempo que el toque al header)
            if Chat.drag.alt == nil and Chat.drag.lastTouch and math.abs(Chat.drag.touchT - (Chat.drag.startT or 0)) < 0.15 then
                Chat.drag.alt = Chat.drag.lastTouch
            end
            if input ~= Chat.drag.alt then return end
        end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local now=pointerPos(input)
    if not dragLast then dragLast=now return end
    local d=now-dragLast
    dragLast=now
    if d.Magnitude > 150 then return end
    local vp=Camera.ViewportSize
    local aspect=vp.Y>0 and vp.X/vp.Y or 1.6
    local distance=aspect<0.92 and CONFIG.DISTANCE_MOBILE or CONFIG.DISTANCE_PC
    local fov=math.rad(Camera.FieldOfView)
    local visibleH=2*distance*math.tan(fov/2)
    local spp=visibleH/math.max(vp.Y,1)
    panelOffset += Vector2.new(d.X*spp,-d.Y*spp)
end)
UserInputService.InputEnded:Connect(function(input)
    if not dragInput then return end
    local isDragTouch = input == dragInput or (Chat.drag.alt ~= nil and input == Chat.drag.alt)
    local mouseUp = dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1
    -- v10: soltar OTRO dedo (joystick) ya no corta ni descontrola el arrastre
    local strayTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.Touch and not isDragTouch and Chat.drag.alt ~= nil
    if isDragTouch or mouseUp or (input.UserInputType == Enum.UserInputType.Touch and not strayTouch) then
        dragging=false dragInput=nil dragLast=nil Chat.drag.alt=nil
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if ReactionBar.Visible or ActionMenu.Visible then
        hideMessageActions()
    end
end)

local function 
-- Neo Hyper bridge for WindUI tab
pcall(function()
    getgenv().NeoHyperChatLoaded = true
    getgenv().NeoHyperChat_SetOpen = function(v)
        open = v and true or false
        if Surface then Surface.Enabled = open end
        if UI and UI.Reopen then UI.Reopen.Visible = not open end
        if open and Chat and Chat.updateBadge then pcall(Chat.updateBadge) end
    end
end)

updateGeometry()
    Camera=workspace.CurrentCamera or Camera
    if not Camera then return end
    if Part.Parent~=Camera then Part.Parent=Camera end
    local vp=Camera.ViewportSize
    local aspect=vp.Y>0 and vp.X/vp.Y or 1.6
    local portrait=aspect<0.92
    local canvas=portrait and CONFIG.CANVAS_MOBILE or CONFIG.CANVAS_PC
    Surface.CanvasSize=canvas
    local distance=portrait and CONFIG.DISTANCE_MOBILE or CONFIG.DISTANCE_PC
    local fov=math.rad(Camera.FieldOfView)
    local visibleH=2*distance*math.tan(fov/2)
    local horizontalFov=2*math.atan(math.tan(fov/2)*math.max(aspect,0.1))
    local visibleW=2*distance*math.tan(horizontalFov/2)
    local canvasAspect=canvas.X/canvas.Y
    local targetH=visibleH*(portrait and 0.76 or 0.70)
    local targetW=targetH*canvasAspect
    if targetW>visibleW*0.86 then targetW=visibleW*0.86 targetH=targetW/canvasAspect end
    if targetH>visibleH*0.88 then targetH=visibleH*0.88 targetW=targetH*canvasAspect end
    Part.Size=Vector3.new(targetW,targetH,0.05)
    local maxX=math.max(0,(visibleW-targetW)*0.40)
    local maxY=math.max(0,(visibleH-targetH)*0.40)
    panelOffset=Vector2.new(math.clamp(panelOffset.X,-maxX,maxX),math.clamp(panelOffset.Y,-maxY,maxY))
    Part.CFrame=Camera.CFrame
        * CFrame.new(panelOffset.X,panelOffset.Y,-distance)
        * CFrame.Angles(-math.rad(CONFIG.TILT_DEG),0,0)
        * CFrame.Angles(0,math.pi,0)
end

RunService:BindToRenderStep(CONFIG.NAME,Enum.RenderPriority.Camera.Value+1,updateGeometry)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2)
    if ScreenGui.Parent then Camera=workspace.CurrentCamera or Camera end
end)

-- Repo primero con fallback embebido; si descarga despues de abrir, reconstruimos la cuadricula.
populateStickers()
populateEmojis()
task.delay(1.5,function()
    if ScreenGui.Parent then populateStickers() end
end)
-- v8: rellenar en cuanto termina la descarga (y si ya termino antes, ahora mismo)
Chat.onStickersLoaded = function()
    if ScreenGui.Parent then populateStickers() end
end
if Chat.stickersLoaded then Chat.onStickersLoaded() end

ScreenGui.AncestryChanged:Connect(function(_,parent)
    if not parent then pcall(function() RunService:UnbindFromRenderStep(CONFIG.NAME) end) end
end)

-- Arranca en la lista de chats (tipo WhatsApp): Chat Global + privados + jugadores del server.
Chat.applyView()
Chat.refreshHome(true)
task.spawn(function() pcall(Chat.refreshPresence) end)

updateGeometry()
