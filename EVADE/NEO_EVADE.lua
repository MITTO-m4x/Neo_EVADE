-- NEO Hyper Official Shutdown UI (Extended & Auto-Close Edition)
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")

-- تنظيف أي نسخة سابقة
if CoreGui:FindFirstChild("NEOHyperUltimateUI") then
    CoreGui.NEOHyperUltimateUI:Destroy()
end
if Lighting:FindFirstChild("NEOShutdownBlur") then
    Lighting.NEOShutdownBlur:Destroy()
end

-- إضافة تأثير ضبابية (Blur) للخلفية
local BlurEffect = Instance.new("BlurEffect")
BlurEffect.Name = "NEOShutdownBlur"
BlurEffect.Size = 0
BlurEffect.Parent = Lighting
TweenService:Create(BlurEffect, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 18}):Play()

-- إنشاء الواجهة الأساسية
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NEOHyperUltimateUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

pcall(function()
    ScreenGui.Parent = CoreGui
end)
if not ScreenGui.Parent then
    ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- خلفية معتمة
local Backdrop = Instance.new("Frame")
Backdrop.Size = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
Backdrop.BackgroundTransparency = 1
Backdrop.BorderSizePixel = 0
Backdrop.Parent = ScreenGui
TweenService:Create(Backdrop, TweenInfo.new(0.5), {BackgroundTransparency = 0.35}):Play()

-- الإطار الرئيسي الكبير
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 740, 0, 620)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(11, 11, 15)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 18)
MainCorner.Parent = MainFrame

-- إطار خارجي متوهج (Gradient Stroke)
local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 2.2
MainStroke.Color = Color3.fromRGB(220, 38, 38)
MainStroke.Parent = MainFrame

local StrokeGradient = Instance.new("UIGradient")
StrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(239, 68, 68)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(127, 29, 29)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(239, 68, 68))
})
StrokeGradient.Rotation = 45
StrokeGradient.Parent = MainStroke

-- الشريط العلوي (Top Header)
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 68)
TopBar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarLine = Instance.new("Frame")
TopBarLine.Size = UDim2.new(1, 0, 0, 2)
TopBarLine.Position = UDim2.new(0, 0, 1, -2)
TopBarLine.BackgroundColor3 = Color3.fromRGB(220, 38, 38)
TopBarLine.BorderSizePixel = 0
TopBarLine.Parent = TopBar

local StudioBadge = Instance.new("TextLabel")
StudioBadge.Size = UDim2.new(0, 140, 0, 28)
StudioBadge.Position = UDim2.new(0, 24, 0.5, -14)
StudioBadge.BackgroundColor3 = Color3.fromRGB(185, 28, 28)
StudioBadge.Text = "NEO STUDIO"
StudioBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
StudioBadge.Font = Enum.Font.GothamBlack
StudioBadge.TextSize = 13
StudioBadge.Parent = TopBar

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = StudioBadge

local HeaderSub = Instance.new("TextLabel")
HeaderSub.Size = UDim2.new(1, -260, 1, 0)
HeaderSub.Position = UDim2.new(0, 178, 0, 0)
HeaderSub.BackgroundTransparency = 1
HeaderSub.Text = "OFFICIAL SHUTDOWN ANNOUNCEMENT"
HeaderSub.TextColor3 = Color3.fromRGB(200, 200, 210)
HeaderSub.Font = Enum.Font.GothamBold
HeaderSub.TextSize = 14
HeaderSub.TextXAlignment = Enum.TextXAlignment.Left
HeaderSub.Parent = TopBar

-- عداد الثواني المتبقية
local TimerLabel = Instance.new("TextLabel")
TimerLabel.Size = UDim2.new(0, 90, 0, 32)
TimerLabel.Position = UDim2.new(1, -114, 0.5, -16)
TimerLabel.BackgroundColor3 = Color3.fromRGB(26, 26, 34)
TimerLabel.Text = "15s"
TimerLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
TimerLabel.Font = Enum.Font.GothamBold
TimerLabel.TextSize = 14
TimerLabel.Parent = TopBar

local TimerCorner = Instance.new("UICorner")
TimerCorner.CornerRadius = UDim.new(0, 8)
TimerCorner.Parent = TimerLabel

-- العنوان الرئيسي للإعلان
local MainHeadline = Instance.new("TextLabel")
MainHeadline.Size = UDim2.new(1, -48, 0, 56)
MainHeadline.Position = UDim2.new(0, 24, 0, 82)
MainHeadline.BackgroundTransparency = 1
MainHeadline.Text = "Neo Studio announces the official end of NEO Hyper, and this server will be shutting down soon."
MainHeadline.TextColor3 = Color3.fromRGB(255, 255, 255)
MainHeadline.Font = Enum.Font.GothamBold
MainHeadline.TextSize = 18
MainHeadline.TextWrapped = true
MainHeadline.TextXAlignment = Enum.TextXAlignment.Left
MainHeadline.Parent = MainFrame

-- قسم البطاقات (الفرق)
local TeamsContainer = Instance.new("Frame")
TeamsContainer.Size = UDim2.new(1, -48, 0, 235)
TeamsContainer.Position = UDim2.new(0, 24, 0, 150)
TeamsContainer.BackgroundTransparency = 1
TeamsContainer.Parent = MainFrame

-- دالة لإنشاء بطاقة فريق
local function CreateTeamCard(titleText, membersList, posScaleX, sizeScaleX)
    local Card = Instance.new("Frame")
    Card.Size = UDim2.new(sizeScaleX, -8, 1, 0)
    Card.Position = UDim2.new(posScaleX, posScaleX > 0 and 8 or 0, 0, 0)
    Card.BackgroundColor3 = Color3.fromRGB(17, 17, 23)
    Card.BorderSizePixel = 0
    Card.Parent = TeamsContainer

    local CardCorner = Instance.new("UICorner")
    CardCorner.CornerRadius = UDim.new(0, 12)
    CardCorner.Parent = Card

    local CardStroke = Instance.new("UIStroke")
    CardStroke.Color = Color3.fromRGB(45, 45, 58)
    CardStroke.Thickness = 1.2
    CardStroke.Parent = Card

    local CardTitle = Instance.new("TextLabel")
    CardTitle.Size = UDim2.new(1, -24, 0, 36)
    CardTitle.Position = UDim2.new(0, 14, 0, 8)
    CardTitle.BackgroundTransparency = 1
    CardTitle.Text = titleText
    CardTitle.TextColor3 = Color3.fromRGB(248, 113, 113)
    CardTitle.Font = Enum.Font.GothamBold
    CardTitle.TextSize = 15
    CardTitle.TextXAlignment = Enum.TextXAlignment.Left
    CardTitle.Parent = Card

    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, -28, 0, 1)
    Divider.Position = UDim2.new(0, 14, 0, 44)
    Divider.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    Divider.BorderSizePixel = 0
    Divider.Parent = Card

    local ListLabel = Instance.new("TextLabel")
    ListLabel.Size = UDim2.new(1, -28, 1, -56)
    ListLabel.Position = UDim2.new(0, 14, 0, 52)
    ListLabel.BackgroundTransparency = 1
    ListLabel.Text = membersList
    ListLabel.TextColor3 = Color3.fromRGB(225, 225, 232)
    ListLabel.Font = Enum.Font.GothamMedium
    ListLabel.TextSize = 14
    ListLabel.LineHeight = 1.32
    ListLabel.TextYAlignment = Enum.TextYAlignment.Top
    ListLabel.TextXAlignment = Enum.TextXAlignment.Left
    ListLabel.Parent = Card
end

-- بطاقة Neo Studio
CreateTeamCard(
    "NEO STUDIO TEAM",
    "• <@1366035739745321011>\n• Maya\n• Olivia\n• Amal\n• Malak\n• Layla\n• Manisa",
    0,
    0.5
)

-- بطاقة Developers of (it's it is bypass)
CreateTeamCard(
    "DEVELOPERS OF (IT'S IT IS BYPASS)",
    "• Elena\n• Sofia\n• Chloe\n• Nora\n• Mila",
    0.5,
    0.5
)

-- صندوق الرسالة المؤثرة في الأسفل
local EmotionalBox = Instance.new("Frame")
EmotionalBox.Size = UDim2.new(1, -48, 0, 185)
EmotionalBox.Position = UDim2.new(0, 24, 0, 400)
EmotionalBox.BackgroundColor3 = Color3.fromRGB(20, 14, 18)
EmotionalBox.BorderSizePixel = 0
EmotionalBox.Parent = MainFrame

local EmoCorner = Instance.new("UICorner")
EmoCorner.CornerRadius = UDim.new(0, 12)
EmoCorner.Parent = EmotionalBox

local EmoStroke = Instance.new("UIStroke")
EmoStroke.Color = Color3.fromRGB(153, 27, 27)
EmoStroke.Thickness = 1.3
EmoStroke.Parent = EmotionalBox

local EmotionalText = Instance.new("TextLabel")
EmotionalText.Size = UDim2.new(1, -28, 1, -20)
EmotionalText.Position = UDim2.new(0, 14, 0, 10)
EmotionalText.BackgroundTransparency = 1
EmotionalText.RichText = true
EmotionalText.TextWrapped = true
EmotionalText.TextYAlignment = Enum.TextYAlignment.Center
EmotionalText.TextXAlignment = Enum.TextXAlignment.Left
EmotionalText.Font = Enum.Font.GothamMedium
EmotionalText.TextSize = 13.5
EmotionalText.LineHeight = 1.28
EmotionalText.TextColor3 = Color3.fromRGB(235, 235, 240)
EmotionalText.Text = [[<b>Honestly, it's hard to put into words how much your support and loyalty meant to us. Every late night, every message, and every moment you spent with us built something we will never forget. You weren't just members—you were the heart of this journey. Even though this chapter closes today, the memories stay with us forever. And if we ever return with a new project, we promise it will be far greater than anything before.</b>

Thank you for everything, truly.  —  <b><font color="#EF4444">With love, Neo Studio</font></b>]]
EmotionalText.Parent = EmotionalBox

-- شريط التقدم السفلي (15 ثانية)
local ProgressBg = Instance.new("Frame")
ProgressBg.Size = UDim2.new(1, 0, 0, 6)
ProgressBg.Position = UDim2.new(0, 0, 1, -6)
ProgressBg.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
ProgressBg.BorderSizePixel = 0
ProgressBg.Parent = MainFrame

local ProgressFill = Instance.new("Frame")
ProgressFill.Size = UDim2.new(1, 0, 1, 0)
ProgressFill.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
ProgressFill.BorderSizePixel = 0
ProgressFill.Parent = ProgressBg

-- أنيميشن الظهور (Pop-in)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(MainFrame, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 740, 0, 620)
}):Play()

-- تحريك شريط الـ 15 ثانية
TweenService:Create(ProgressFill, TweenInfo.new(15, Enum.EasingStyle.Linear), {
    Size = UDim2.new(0, 0, 1, 0)
}):Play()

-- العد التنازلي والإغلاق التلقائي بعد 15 ثانية
task.spawn(function()
    for i = 15, 1, -1 do
        TimerLabel.Text = i .. "s"
        task.wait(1)
    end
    TimerLabel.Text = "0s"

    -- أنيميشن الاختفاء الناعم
    local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    })
    TweenService:Create(Backdrop, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    TweenService:Create(BlurEffect, TweenInfo.new(0.4), {Size = 0}):Play()
    
    closeTween:Play()
    closeTween.Completed:Connect(function()
        ScreenGui:Destroy()
        BlurEffect:Destroy()
    end)
end)
