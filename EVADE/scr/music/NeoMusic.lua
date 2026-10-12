--[=[
    NeoMusic.lua | Neo Hyper Premium Music & Lyrics
    By MITTO
    Place at: EVADE/scr/music/NeoMusic.lua

    GitHub BGM auto-discovery enabled. Scans repository tree, finds song folders,
    detects L.lua / Cover images / audio files, and reads L.lua metadata/lyrics.
    A GitHub audio file still is not a Roblox SoundId; audio playback requires a
    valid Roblox-approved asset ID (optionally stored as SoundId in L.lua metadata).
]=]
local NeoMusic = {}
NeoMusic.__index = NeoMusic

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Add songs here after uploading/authorizing their audio on Roblox.
-- Times are seconds from the beginning of the track. Keep L.lua in the same format.
local Catalog = {
    -- Example:
    -- ["Song_Name_1"] = {
    --   Title = "Song Name 1", Artist = "Artist", SoundId = "rbxassetid://1234567890",
    --   Cover = "https://raw.githubusercontent.com/OWNER/REPO/main/music/BGM/Song_Name_1/Cover.png",
    --   Lyrics = {{Time=0.02, Text="First line"}, {Time=3.13, Text="Second line"}},
    -- },
}

-- Automatic BGM discovery. No hard-coded song-folder names required.
local DEFAULT_API = "https://api.github.com/repos/MITTO-m4x/Neo_EVADE/git/trees/main?recursive=1"
local DEFAULT_RAW = "https://raw.githubusercontent.com/MITTO-m4x/Neo_EVADE/refs/heads/main/"
local DEFAULT_ROOT = "EVADE/scr/music/BGM/"

local function encodePath(path)
    return (path:gsub("([^%w%-%._~/])", function(ch)
        return string.format("%%%02X", string.byte(ch))
    end))
end

local function decodeLyricsPayload(source)
    if type(source) ~= "string" or source == "" then return nil end
    local compiler = loadstring or load
    if type(compiler) ~= "function" then return nil end
    local fn = compiler(source)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn)
    if not ok or type(value) ~= "table" then return nil end
    return value
end

local function scanRepository(options, notify)
    local api = options.GitHubApi or DEFAULT_API
    local rawBase = options.RawBase or DEFAULT_RAW
    local rootPath = options.BGMRoot or DEFAULT_ROOT
    local ok, response = pcall(function() return game:HttpGet(api) end)
    if not ok then error("GitHub tree request failed: " .. tostring(response)) end
    local decoded = HttpService:JSONDecode(response)
    if type(decoded) ~= "table" or type(decoded.tree) ~= "table" then
        error("GitHub returned no repository tree")
    end
    local found = {}
    for _, item in ipairs(decoded.tree) do
        local path = item.path
        if item.type == "blob" and type(path) == "string" and path:sub(1, #rootPath) == rootPath then
            local relative = path:sub(#rootPath + 1)
            local folder, child = relative:match("^([^/]+)/(.+)$")
            if folder and child then
                local song = found[folder] or {Title=folder, Artist="Unknown artist", Files={}, Folder=folder}
                found[folder] = song
                song.Files[#song.Files + 1] = child
                local lower = child:lower()
                if lower == "l.lua" then song.LyricsURL = rawBase .. encodePath(path) end
                if lower == "cover.png" or lower == "cover.jpg" or lower == "cover.jpeg" or lower == "cover.webp" then
                    song.Cover = rawBase .. encodePath(path)
                end
                if lower:match("%.mp3$") or lower:match("%.ogg$") or lower:match("%.wav$") then
                    song.AudioURL = rawBase .. encodePath(path)
                end
            end
        end
    end
    local catalog = {}
    for folder, song in pairs(found) do
        if song.LyricsURL then
            local lyricOk, lyricSource = pcall(function() return game:HttpGet(song.LyricsURL) end)
            if lyricOk then
                local data = decodeLyricsPayload(lyricSource)
                if data then
                    song.Title = tostring(data.Title or data.title or folder)
                    song.Artist = tostring(data.Artist or data.artist or song.Artist)
                    song.SoundId = tostring(data.SoundId or data.SoundID or data.soundId or "")
                    local lyrics = data.Lyrics or data.lyrics or data.Lines or data.lines
                    if type(lyrics) == "string" then
                        song.Lyrics = lyrics
                    elseif type(lyrics) == "table" then
                        song.Lyrics = lyrics
                    elseif #data > 0 then
                        song.Lyrics = data
                    end
                else
                    -- A non-executable L.lua is still discovered, but cannot be parsed as metadata.
                    song.Lyrics = {}
                end
            else
                song.Lyrics = {}
            end
            catalog[folder] = song
        end
    end
    return catalog
end

local C = {
    bg = Color3.fromRGB(7,7,9), panel = Color3.fromRGB(15,15,18), panel2 = Color3.fromRGB(24,24,28),
    white = Color3.fromRGB(255,255,255), muted = Color3.fromRGB(145,145,153), line = Color3.fromRGB(54,54,62)
}
local function create(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props or {}) do pcall(function() o[k]=v end) end
    o.Parent = parent
    return o
end
local function round(obj, px) create("UICorner", {CornerRadius=UDim.new(0,px or 10)}, obj) end
local function stroke(obj, color, transparency)
    create("UIStroke", {Color=color or C.line, Transparency=transparency or 0, Thickness=1}, obj)
end
local function button(parent, text, size, pos)
    local b=create("TextButton",{Size=size,Position=pos,BackgroundColor3=C.panel2,BorderSizePixel=0,Text=text,TextColor3=C.white,TextSize=14,Font=Enum.Font.GothamMedium,AutoButtonColor=true},parent)
    round(b,9); return b
end
local function parseLyrics(raw)
    local out={}
    for stamp, lyric in tostring(raw or ""):gmatch("%[(%d%d?):(%d%d)%.(%d%d)%]%s*([^\r\n]+)") do
        local m,s,cs=stamp:match("(%d+):(%d+)")
        out[#out+1]={Time=(tonumber(m) or 0)*60+(tonumber(s) or 0)+(tonumber(cs) or 0)/100,Text=lyric}
    end
    table.sort(out,function(a,b) return a.Time<b.Time end)
    return out
end

function NeoMusic.Start(options)
    options=options or {}
    if NeoMusic._instance and NeoMusic._instance.Destroy then pcall(function() NeoMusic._instance:Destroy() end) end
    local self=setmetatable({},NeoMusic); NeoMusic._instance=self
    self.catalog=options.Catalog or Catalog; self.selected=nil; self.scanOptions=options; self.playing=false; self.connections={}; self.lyricScale=1
    local player=Players.LocalPlayer
    if not player then return self end
    local gui=create("ScreenGui",{Name="NeoMusicPremium",ResetOnSpawn=false,IgnoreGuiInset=true,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player:WaitForChild("PlayerGui"))
    self.gui=gui; gui.Enabled=false
    local root=create("Frame",{Name="Root",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.new(0,760,0,470),BackgroundColor3=C.bg,BorderSizePixel=0},gui); round(root,16); stroke(root,C.line,.1)
    local top=create("Frame",{Size=UDim2.new(1,0,0,58),BackgroundColor3=Color3.fromRGB(10,10,12),BorderSizePixel=0},root); round(top,16)
    create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,20,0,0),Size=UDim2.new(0,220,1,0),Text="NEO HYPER  /  MUSIC",TextColor3=C.white,TextSize=17,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},top)
    local close=button(top,"×",UDim2.new(0,38,0,34),UDim2.new(1,-50,0,12)); close.TextSize=22
    close.MouseButton1Click:Connect(function() gui.Enabled=false end)
    local search=create("TextBox",{PlaceholderText="Search your music library...",Text="",ClearTextOnFocus=false,Position=UDim2.new(0,18,0,72),Size=UDim2.new(0,218,0,38),BackgroundColor3=C.panel,TextColor3=C.white,PlaceholderColor3=C.muted,TextSize=14,Font=Enum.Font.Gotham,BorderSizePixel=0},root); round(search,9); stroke(search)
    local scanButton=button(root,"Scan BGM",UDim2.new(0,82,0,38),UDim2.new(0,244,0,72)); scanButton.TextSize=12
    local results=create("ScrollingFrame",{Position=UDim2.new(0,18,0,120),Size=UDim2.new(0,300,1,-140),BackgroundColor3=C.panel,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new()},root); round(results,10)
    create("UIListLayout",{Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},results); create("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},results)
    local title=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,338,0,78),Size=UDim2.new(1,-360,0,32),Text="Choose a song",TextColor3=C.white,TextSize=22,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left},root)
    local artist=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,340,0,110),Size=UDim2.new(1,-360,0,24),Text="Neo Hyper Premium Music",TextColor3=C.muted,TextSize=13,Font=Enum.Font.Gotham},root)
    local lyricPanel=create("Frame",{Position=UDim2.new(0,330,0,150),Size=UDim2.new(1,-350,0,210),BackgroundColor3=C.panel,BorderSizePixel=0,ClipsDescendants=true},root); round(lyricPanel,12); stroke(lyricPanel)
    local prev=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,12,0,24),Size=UDim2.new(1,-24,0,38),Text="",TextColor3=C.muted,TextTransparency=.25,TextSize=14,Font=Enum.Font.Gotham,TextWrapped=true},lyricPanel)
    local current=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,12,0,78),Size=UDim2.new(1,-24,0,58),Text="Lyrics appear here",TextColor3=C.white,TextSize=18,Font=Enum.Font.GothamBold,TextWrapped=true},lyricPanel)
    local nextline=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,12,0,145),Size=UDim2.new(1,-24,0,38),Text="",TextColor3=C.muted,TextTransparency=.25,TextSize=14,Font=Enum.Font.Gotham,TextWrapped=true},lyricPanel)
    local controls=create("Frame",{BackgroundTransparency=1,Position=UDim2.new(0,330,0,372),Size=UDim2.new(1,-350,0,48)},root)
    local play=button(controls,"▶  Play",UDim2.new(0,112,0,38),UDim2.new(0,0,0,0))
    local overlay=button(controls,"Lyrics Overlay: OFF",UDim2.new(0,178,0,38),UDim2.new(0,122,0,0))
    local smaller=button(controls,"A−",UDim2.new(0,42,0,38),UDim2.new(1,-92,0,0))
    local bigger=button(controls,"A+",UDim2.new(0,42,0,38),UDim2.new(1,-44,0,0))
    local sound=create("Sound",{Name="NeoMusicSound",Volume=.5,Looped=false},gui); self.sound=sound
    local hud=create("Frame",{Name="LyricsHUD",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,28),Size=UDim2.new(0,520,0,106),BackgroundColor3=C.bg,BackgroundTransparency=.14,Visible=false,Active=true},gui); round(hud,14); stroke(hud,C.line,.1)
    local hudPrev=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,15,0,8),Size=UDim2.new(1,-30,0,25),Text="",TextColor3=C.muted,TextTransparency=.15,TextSize=14,Font=Enum.Font.Gotham},hud)
    local hudCur=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,15,0,35),Size=UDim2.new(1,-30,0,36),Text="",TextColor3=C.white,TextSize=22,Font=Enum.Font.GothamBold,TextWrapped=true},hud)
    local hudNext=create("TextLabel",{BackgroundTransparency=1,Position=UDim2.new(0,15,0,72),Size=UDim2.new(1,-30,0,24),Text="",TextColor3=C.muted,TextTransparency=.15,TextSize=14,Font=Enum.Font.Gotham},hud)
    -- Drag the overlay with touch or mouse.
    local dragging, dragStart, startPos=false,nil,nil
    hud.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startPos=hud.Position end end)
    hud.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    table.insert(self.connections,UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-dragStart; hud.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y) end
    end))
    local function lyricsFor(song)
        if type(song.Lyrics)=="string" then return parseLyrics(song.Lyrics) end
        return type(song.Lyrics)=="table" and song.Lyrics or {}
    end
    local function drawLyrics()
        local song=self.selected; if not song then return end
        local lyrics=lyricsFor(song); local t=sound.TimePosition; local idx=0
        for i,line in ipairs(lyrics) do if tonumber(line.Time or line.time or 0)<=t then idx=i else break end end
        local a=lyrics[idx]; local b=lyrics[idx-1]; local c=lyrics[idx+1]
        prev.Text=b and tostring(b.Text or b.text or "") or ""
        current.Text=a and tostring(a.Text or a.text or "") or "♪  Instrumental / waiting for lyrics  ♪"
        nextline.Text=c and tostring(c.Text or c.text or "") or ""
        hudPrev.Text=prev.Text; hudCur.Text=current.Text; hudNext.Text=nextline.Text
        local glow=TweenService:Create(current,TweenInfo.new(.22),{TextTransparency=0,TextSize=18*self.lyricScale}); glow:Play()
        hudCur.TextSize=22*self.lyricScale
    end
    local function selectSong(key,song)
        self.selected=song; title.Text=tostring(song.Title or key); artist.Text=tostring(song.Artist or "Unknown artist")
        sound:Stop(); sound.SoundId=tostring(song.SoundId or ""); sound.TimePosition=0
        if sound.SoundId=="" then
            play.Text="Audio ID needed"; artist.Text="Set a valid Roblox SoundId in the catalog"; self.playing=false
        else play.Text="▶  Play"; self.playing=false end
        drawLyrics()
    end
    local function refresh(query)
        for _,child in ipairs(results:GetChildren()) do if child:IsA("TextButton") or child.Name=="EmptyState" then child:Destroy() end end
        local count=0; query=string.lower(query or "")
        for key,song in pairs(self.catalog) do
            local label=string.lower(tostring(song.Title or key).." "..tostring(song.Artist or ""))
            if query=="" or label:find(query,1,true) then
                count+=1; local row=button(results,tostring(song.Title or key).."\n"..tostring(song.Artist or "Unknown artist"),UDim2.new(1,-8,0,54),UDim2.new())
                row.TextXAlignment=Enum.TextXAlignment.Left; row.TextSize=13; row.TextWrapped=true; row.LayoutOrder=count
                row.MouseButton1Click:Connect(function() selectSong(key,song) end)
            end
        end
        if count==0 then local empty=create("TextLabel",{Name="EmptyState",BackgroundTransparency=1,Size=UDim2.new(1,-10,0,65),Text="No songs found.\nPress Scan BGM to discover GitHub folders.",TextColor3=C.muted,TextSize=13,Font=Enum.Font.Gotham,TextWrapped=true},results) end
        task.defer(function() local l=results:FindFirstChildOfClass("UIListLayout"); if l then results.CanvasSize=UDim2.new(0,0,0,l.AbsoluteContentSize.Y+16) end end)
    end
    local scanning=false
    scanButton.MouseButton1Click:Connect(function()
        if scanning then return end
        scanning=true; scanButton.Text="Scanning..."
        task.spawn(function()
            local ok, discovered=pcall(function() return scanRepository(self.scanOptions, options.Notify) end)
            if ok then
                for key,song in pairs(discovered) do self.catalog[key]=song end
                if options.Notify then pcall(options.Notify,"BGM scan complete: "..tostring((function() local n=0 for _ in pairs(discovered) do n+=1 end return n end)()).." song folders found") end
            else
                warn("[NeoMusic] BGM scan failed: "..tostring(discovered))
                if options.Notify then pcall(options.Notify,"BGM scan failed: "..tostring(discovered)) end
            end
            scanning=false; scanButton.Text="Scan BGM"; refresh(search.Text)
        end)
    end)
    search:GetPropertyChangedSignal("Text"):Connect(function() refresh(search.Text) end)
    play.MouseButton1Click:Connect(function()
        if not self.selected then return end
        if not sound.SoundId or sound.SoundId=="" then if options.Notify then pcall(options.Notify,"Add a valid Roblox SoundId to this song") end return end
        if self.playing then sound:Pause(); self.playing=false; play.Text="▶  Play" else sound:Play(); self.playing=true; play.Text="Ⅱ  Pause" end
    end)
    overlay.MouseButton1Click:Connect(function() hud.Visible=not hud.Visible; overlay.Text=hud.Visible and "Lyrics Overlay: ON" or "Lyrics Overlay: OFF" end)
    smaller.MouseButton1Click:Connect(function() self.lyricScale=math.max(.7,self.lyricScale-.1); drawLyrics() end)
    bigger.MouseButton1Click:Connect(function() self.lyricScale=math.min(1.5,self.lyricScale+.1); drawLyrics() end)
    table.insert(self.connections,RunService.Heartbeat:Connect(function() if self.playing and self.selected then drawLyrics() end end))
    refresh("")
    function self:Open() gui.Enabled=true end
    function self:Destroy() for _,c in ipairs(self.connections) do pcall(function() c:Disconnect() end) end; pcall(function() gui:Destroy() end); pcall(function() sound:Destroy() end) end
    return self
end

function NeoMusic.GetCatalog() return Catalog end
return NeoMusic
