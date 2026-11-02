-- ============================================================================
-- NeoFloat.lua  |  Neo Hyper floating buttons (external module)
-- Upload this file to GitHub and point NEO_FLOAT_URL (in the main script) at its RAW link.
-- The main script downloads it the first time a floating button is created, not before.
-- ============================================================================
if getgenv().NeoFloatReady then return end
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Window = getgenv().Window or _G.Window
local FloatingButtonLocks = getgenv().NeoFloatingButtonLocks or {}
local IsFloatingLocked = getgenv().NeoIsFloatingLocked or function() return false end

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

getgenv().NeoFloatReady = true
