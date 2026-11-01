-- NeoFloat external module (shared by Gen2 / Premium)
-- Load via: loadstring(game:HttpGet("https://raw.githubusercontent.com/MITTO-m4x/Neo_EVADE/main/EVADE/scr/ui/NeoFloat.lua"))()
-- Requires: Players, LocalPlayer as LP, CoreGui, RunService, UserInputService, TweenService already available or uses game services.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = select(2, pcall(game.GetService, game, "CoreGui")) or game:GetService("CoreGui")

if type(getgenv) ~= "function" then
    getgenv = function() return _G end
end

-- Tap helper if missing
if not getgenv().NeoTapOK then
    getgenv().NeoTapOK = function(container, input, pressT, lastT)
        local now = os.clock()
        local dur = now - pressT
        if dur > 0.45 or dur < 0.02 then return false end
        if now - lastT < 0.5 then return false end
        local ok = true
        pcall(function()
            local p = input.Position
            local a, sz = container.AbsolutePosition, container.AbsoluteSize
            local inset = game:GetService("GuiService"):GetGuiInset()
            local inX = p.X >= a.X - 30 and p.X <= a.X + sz.X + 30
            local inY = (p.Y >= a.Y - 30 and p.Y <= a.Y + sz.Y + 30)
                or (p.Y + inset.Y >= a.Y - 30 and p.Y + inset.Y <= a.Y + sz.Y + 30)
            ok = inX and inY
        end)
        return ok
    end
end


-- ===== STYLE =====
    -- NEO FLOAT STYLE: one shared look for every floating button.
    -- Follows the active theme and is controlled from Settings > Floating Buttons.
    -- ========================================================================
    do
        local G = getgenv()
        local S = G.NeoFloatStyle or {}
        G.NeoFloatStyle = S
        if S.follow == nil then S.follow = true end
        S.transparency = S.transparency or 0.1
        S.corner = S.corner or 0.2
        S.textSize = S.textSize or 14
        S.stroke = S.stroke or 2
        S.scale = S.scale or 1
        S.accent = S.accent or Color3.fromRGB(255, 255, 255)
        S.bg = S.bg or Color3.fromRGB(0, 0, 0)
        S.text = S.text or Color3.fromRGB(255, 255, 255)
        local reg = {}
        local function col(kind, on)
            if not S.follow then
                if kind == "bg" then return on and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(12, 12, 12) end
                if kind == "stroke" then return on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180) end
                return Color3.fromRGB(255, 255, 255)
            end
            local a, b, t = S.accent, S.bg, S.text
            if kind == "bg" then
                return on and b:Lerp(a, 0.22) or b:Lerp(Color3.new(0, 0, 0), 0.25)
            elseif kind == "stroke" then
                return on and a or a:Lerp(b, 0.55)
            end
            return t
        end
        G.NeoFC = col
        NeoFC = col
        local function applyOne(e)
            local c = e.container
            if not (c and c.Parent) then return false end
            local on = false
            pcall(function() on = (e.getOn and e.getOn()) and true or false end)
            c.BackgroundColor3 = col("bg", on)
            c.BackgroundTransparency = S.transparency
            if e.stroke then
                e.stroke.Color = col("stroke", on)
                e.stroke.Thickness = S.stroke
            end
            if e.label then
                e.label.TextColor3 = col("text", on)
                e.label.TextSize = S.textSize
            end
            local uc = c:FindFirstChildOfClass("UICorner")
            if uc then uc.CornerRadius = UDim.new(S.corner, 0) end
            local us = c:FindFirstChildOfClass("UIScale")
            if not us then
                us = Instance.new("UIScale")
                us.Parent = c
            end
            us.Scale = S.scale
            return true
        end
        G.NeoFloatRegister = function(container, stroke, label, getOn)
            local e = { container = container, stroke = stroke, label = label, getOn = getOn }
            reg[#reg + 1] = e
            applyOne(e)
        end
        G.NeoFloatRestyle = function()
            for i = #reg, 1, -1 do
                if not applyOne(reg[i]) then table.remove(reg, i) end
            end

-- ===== CORE =====
    getgenv().NeoFloatingButtonLocks = getgenv().NeoFloatingButtonLocks or {}
    getgenv().NeoFloatRegistry = getgenv().NeoFloatRegistry or {}
    local FloatingButtonLocks = getgenv().NeoFloatingButtonLocks
    local function SetFloatingButtonLock(guiName, locked)
        FloatingButtonLocks[guiName] = locked == true
        getgenv().NeoFloatingButtonLocks = FloatingButtonLocks
    end
    -- Unified lock check: works with both logical keys and obfuscated ScreenGui names
    local function IsFloatingLocked(guiOrName)
        if type(guiOrName) == "string" then
            return FloatingButtonLocks[guiOrName] == true
        end
        if typeof(guiOrName) == "Instance" then
            local logical = guiOrName:GetAttribute("NeoLogicalKey")
            if logical and FloatingButtonLocks[logical] == true then return true end
            -- also try common aliases
            if logical then
                local aliases = {
                    Fly = "FlyFloatingButton",
                    Carry = "CarryFloatingButton",
                    Revive = "ReviveFloatingButton",
                    AutoCrouch = "AutoCrouchFloating",
                }
                local alias = aliases[logical]
                if alias and FloatingButtonLocks[alias] == true then return true end
            end
            if FloatingButtonLocks[guiOrName.Name] == true then return true end
        end
        return false
    end
    getgenv().NeoIsFloatingLocked = IsFloatingLocked
    local function NeoObfName(n)
        n = n or (12 + math.random(0, 10))
        local alphabet = "0123456789abcdefABCDEF"
        local out = {}
        for i = 1, n do
            local idx = math.random(1, #alphabet)
            out[i] = alphabet:sub(idx, idx)
        end
        return table.concat(out)
    end
    local function NeoDestroyLegacyFloats()
        local names = {
            "FlyFloatingButton", "CarryFloatingButton", "ReviveFloatingButton",
            "FrontHopFloatingButton", "BackHopFloatingButton",
            "PathStudioFloat", "JoystickGui",
        }
        for _, n in ipairs(names) do
            pcall(function()
                local o = CoreGui:FindFirstChild(n)
                if o then o:Destroy() end
            end)
            pcall(function()
                local pg = LP and LP:FindFirstChild("PlayerGui")
                if pg then
                    local o = pg:FindFirstChild(n)
                    if o then o:Destroy() end
                end
            end)
        end
    end
    local function NeoMakeStealthGui(logicalKey)
        getgenv().NeoFloatRegistry = getgenv().NeoFloatRegistry or {}
        local reg = getgenv().NeoFloatRegistry
        if reg[logicalKey] then
            pcall(function() reg[logicalKey]:Destroy() end)
            reg[logicalKey] = nil
        end
        NeoDestroyLegacyFloats()
        local gui = Instance.new("ScreenGui")
        gui.Name = NeoObfName(14 + math.random(0, 8))
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = math.random(40, 250)
        gui.IgnoreGuiInset = true
        -- plant in random obscure host
        local planted = false
        local roll = math.random(1, 4)
        if roll == 1 then
            pcall(function()
                local host = Instance.new("Folder")
                host.Name = NeoObfName(16)
                host.Parent = CoreGui
                gui.Parent = host
                planted = gui.Parent ~= nil
            end)
        elseif roll == 2 then
            pcall(function()
                local pg = LP:WaitForChild("PlayerGui", 2)
                local host = Instance.new("Folder")
                host.Name = NeoObfName(18)
                host.Parent = pg
                gui.Parent = host
                planted = gui.Parent ~= nil
            end)
        elseif roll == 3 then
            pcall(function()
                gui.Parent = CoreGui
                planted = gui.Parent ~= nil
            end)
        else
            pcall(function()
                local pg = LP:WaitForChild("PlayerGui", 2)
                gui.Parent = pg
                planted = gui.Parent ~= nil
            end)
        end
        if not planted then
            pcall(function() gui.Parent = CoreGui end)
            if not gui.Parent and LP then
                pcall(function() gui.Parent = LP:WaitForChild("PlayerGui") end)
            end
        end
        reg[logicalKey] = gui
        pcall(function()
            gui:SetAttribute("NeoLogicalKey", tostring(logicalKey))
        end)
        -- first-time stealth notice
        do
            local FLAG = "Neo-EVADE/2"
            local seen = false
            pcall(function()
                if isfolder and not isfolder("Neo-EVADE") and makefolder then makefolder("Neo-EVADE") end
                if isfile and isfile(FLAG) then seen = true end
            end)
            if getgenv().NeoFloatStealthNotified then seen = true end
            if not seen then
                getgenv().NeoFloatStealthNotified = true
                pcall(function()
                    if writefile then writefile(FLAG, "1") end
                end)
                pcall(function()
                    local Win = Window or getgenv().Window
                    if Win and Win.Dialog then
                        Win:Dialog({
                            Title = "Floating UI",
                            Content = "Floating buttons are now encrypted.\nRandom name + hidden parent every spawn.\nThis message appears only once.",
                            Buttons = {
                                {
                                    Title = "Got it",
                                    Variant = "Primary",
                                    Callback = function() end,
                                },
                            },
                        })
                    end
                end)
            else
                getgenv().NeoFloatStealthNotified = true
            end
        end
        return gui
    end
    getgenv().NeoMakeStealthGui = NeoMakeStealthGui
    getgenv().NeoObfName = NeoObfName
    do
        local active = getgenv().NeoFloatInstances or {}
        getgenv().NeoFloatInstances = active
        local COL_ON_BG, COL_OFF_BG = Color3.fromRGB(0,0,0), Color3.fromRGB(12,12,12)
        local COL_ON_ST, COL_OFF_ST = Color3.fromRGB(255,255,255), Color3.fromRGB(180,180,180)
        local function paint(container, stroke, label, title, on, mode)
            mode = mode or "toggle"
            if container then container.BackgroundColor3 = NeoFC("bg", on) end
            if stroke then stroke.Color = NeoFC("stroke", on) end
            if label then
                if mode == "action" then label.Text = tostring(title or "")
                else label.Text = tostring(title or "") .. ": " .. (on and "ON" or "OFF") end
            end
        end
        local function destroyId(id)
            local entry = active[id]
            if not entry then return end
            pcall(function() if entry.gui and entry.gui.Parent then entry.gui:Destroy() end end)
            active[id] = nil
            if getgenv().NeoFloatRegistry then getgenv().NeoFloatRegistry[id] = nil end
        end
        local function create(opts)
            opts = opts or {}
            local id = tostring(opts.Id or "Float")
            local title = tostring(opts.Title or id):upper()
            local mode = opts.Mode or "toggle"
            local getState = opts.GetState or function() return false end
            local setState, onToggle, syncToggle = opts.SetState, opts.OnToggle, opts.SyncToggle
            local width, height = tonumber(opts.Width) or 160, tonumber(opts.Height) or 55
            local cam = workspace.CurrentCamera
            local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
            local startX = opts.OffsetX; if startX == nil then startX = (vp.X/2)-(width/2) end
            local startY = opts.OffsetY; if startY == nil then startY = (vp.Y/2)-(height/2) end
            destroyId(id)
            local screenGui = nil
            if type(getgenv().NeoMakeStealthGui) == "function" then screenGui = getgenv().NeoMakeStealthGui(id) end
            if not screenGui then
                screenGui = Instance.new("ScreenGui")
                screenGui.Name = (getgenv().NeoObfName and getgenv().NeoObfName(12)) or (id.."FloatingButton")
                screenGui.ResetOnSpawn = false
                pcall(function() screenGui.Parent = CoreGui end)
                if not screenGui.Parent and LP then screenGui.Parent = LP:WaitForChild("PlayerGui") end
            end
            pcall(function() screenGui:SetAttribute("NeoLogicalKey", id) end)
            local on = false; pcall(function() on = getState() == true end)
            local container = Instance.new("Frame")
            container.Name = "Container"
            container.Size = opts.Size or UDim2.new(0, width, 0, height)
            container.Position = UDim2.new(0, startX, 0, startY)
            container.BackgroundTransparency = 0.1
            container.Active = true
            container.Parent = screenGui
            Instance.new("UICorner", container).CornerRadius = UDim.new(0.2, 0)
            local stroke = Instance.new("UIStroke", container); stroke.Thickness = 2
            local label = Instance.new("TextLabel")
            label.Name = "Label"; label.Size = UDim2.new(1,0,1,0); label.BackgroundTransparency = 1
            label.TextColor3 = NeoFC("text", true); label.Font = Enum.Font.GothamBold; label.TextSize = 14
            label.Parent = container
            paint(container, stroke, label, title, on, mode)
            local clicker = Instance.new("TextButton")
            clicker.Name = "Clicker"; clicker.Size = UDim2.new(1,0,1,0); clicker.BackgroundTransparency = 1; clicker.Text = ""; clicker.Parent = container
            local dragging, hasMoved = false, false
            local lastToggleT, pressT = 0, 0
            local dragStart, startPos = Vector3.zero, UDim2.new()
            local inputChangedConn, inputEndedConn
            clicker.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
                dragging, hasMoved = true, false
                pressT = os.clock()
                dragStart, startPos = input.Position, container.Position
                if inputChangedConn then pcall(function() inputChangedConn:Disconnect() end) end
                if inputEndedConn then pcall(function() inputEndedConn:Disconnect() end) end
                inputChangedConn = UserInputService.InputChanged:Connect(function(moveInput)
                    if not dragging then return end
                    -- multi-touch: another finger (joystick, camera...) must never count as this button's drag
                    if moveInput ~= input and not (input.UserInputType == Enum.UserInputType.MouseButton1 and moveInput.UserInputType == Enum.UserInputType.MouseMovement) then return end
                    local delta = moveInput.Position - dragStart
                    local lockedNow = false
                    pcall(function()
                        if getgenv().NeoIsFloatingLocked then lockedNow = getgenv().NeoIsFloatingLocked(screenGui) or getgenv().NeoIsFloatingLocked(id) end
                        local locks = getgenv().NeoFloatingButtonLocks
                        if locks and (locks[id] or locks[id.."FloatingButton"]) then lockedNow = true end
                    end)
                    -- locked: finger jitter is normal, only a big deliberate slide cancels the tap
                    if delta.Magnitude > (lockedNow and 14 or 7) then
                        hasMoved = true
                        stroke.Color = NeoFC("stroke", true)
                        local locked = lockedNow
                        pcall(function()
                            if getgenv().NeoIsFloatingLocked then locked = getgenv().NeoIsFloatingLocked(screenGui) or getgenv().NeoIsFloatingLocked(id) end
                            local locks = getgenv().NeoFloatingButtonLocks
                            if locks and (locks[id] or locks[id.."FloatingButton"]) then locked = true end
                        end)
                        if not locked then
                            container.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
                        end
                    end
                end)
                local finished = false
                local altEnd
                local function onEnd()
                    if finished then return end
                    finished = true
                    if altEnd then pcall(function() altEnd:Disconnect() end) end
                    dragging = false
                    if inputChangedConn then pcall(function() inputChangedConn:Disconnect() end) end
                    if inputEndedConn then pcall(function() inputEndedConn:Disconnect() end) end
                    if not hasMoved and getgenv().NeoTapOK(container, input, pressT, lastToggleT) then
                        lastToggleT = os.clock()
                        if mode == "action" then
                            if type(setState) == "function" then pcall(setState, true) end
                            if type(onToggle) == "function" then pcall(onToggle, true) end
                            paint(container, stroke, label, title, false, mode)
                        else
                            local newState = not (getState() == true)
                            if type(setState) == "function" then pcall(setState, newState) end
                            if type(onToggle) == "function" then pcall(onToggle, newState) end
                            paint(container, stroke, label, title, newState, mode)
                            local st = syncToggle or (getgenv().NeoFloatToggles and getgenv().NeoFloatToggles[id])
                            if st then
                                getgenv().NeoFloatBusy = true
                                pcall(function()
                                    if type(st.SetValue) == "function" then st:SetValue(newState)
                                    elseif type(st.Set) == "function" then st:Set(newState) end
                                end)
                                getgenv().NeoFloatBusy = false
                            end
                        end
                    else
                        local cur = false; pcall(function() cur = getState() == true end)
                        paint(container, stroke, label, title, cur, mode)
                    end
                end
                inputEndedConn = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then onEnd() end
                end)
                -- second, independent end signal: a very fast tap can finish before Changed is connected
                altEnd = UserInputService.InputEnded:Connect(function(e) if e == input then onEnd() end end)
            end)
            active[id] = { gui = screenGui, container = container, stroke = stroke, label = label, title = title, getState = getState, mode = mode }
            pcall(function() getgenv().NeoFloatRegister(container, stroke, label, function() return mode ~= "action" and getState() == true end) end)
            return screenGui
        end
        getgenv().NeoFloat = {
            Create = create, Destroy = destroyId,
            SetVisual = function(id, on)
                local entry = active[id]; if not entry then return end
                if on == nil then pcall(function() on = entry.getState() == true end) end
                paint(entry.container, entry.stroke, entry.label, entry.title, on == true, entry.mode)
            end,
            Get = function(id) local e = active[id]; return e and e.gui or nil end,
            Instances = active,
            -- link a UI toggle to a floating button (both directions stay in sync)
            Bind = function(id, toggle)
                getgenv().NeoFloatToggles = getgenv().NeoFloatToggles or {}
                if toggle then getgenv().NeoFloatToggles[id] = toggle end
            end,
        }
        -- UI/keybind -> floating button: repaint whenever the real feature state changes
        task.spawn(function()
            while true do
                task.wait(0.25)
                for id, e in pairs(active) do
                    if not (e.gui and e.gui.Parent) then
                        active[id] = nil
                    elseif e.mode ~= "action" then
                        local cur = false
                        pcall(function() cur = e.getState() == true end)
                        if e.lastOn ~= cur then
                            e.lastOn = cur
                            paint(e.container, e.stroke, e.label, e.title, cur, e.mode)
                        end
                    end
                end
            end
        end)
    end
    local function AddFloatingLockToggle(section, title, flag, guiName)
        section:Toggle({
            Title = title or " Lock Floating Button",
            Flag = flag,
            Value = FloatingButtonLocks[guiName] == true,
            Callback = function(state)
                SetFloatingButtonLock(guiName, state)
            end
        })
    end
    getgenv().NeoSetFloatingButtonLock = SetFloatingButtonLock
    getgenv().NeoAddFloatingLockToggle = AddFloatingLockToggle

return getgenv().NeoFloat
