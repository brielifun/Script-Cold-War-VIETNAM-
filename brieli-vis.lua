-- =====================================================
--  brieli vis — CW [VIETNAM] v11 (Midnight-style visuals)
--  Правый Shift — меню
-- =====================================================

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

if _G.brieliVisUnload then pcall(_G.brieliVisUnload) end

-- ============== ФАЙЛЫ ==============
local CONFIG_FILE = "brieli_vis_cw.json"
local function fsWrite(n,c) if writefile then pcall(writefile,n,c) elseif write_file then pcall(write_file,n,c) end end
local function fsRead(n)
    if isfile then local ok,e=pcall(isfile,n) if ok and e then local ok2,d=pcall(readfile,n) if ok2 then return d end end
    elseif read_file then local ok,d=pcall(read_file,n) if ok and d then return d end end
    return nil
end

-- ============== CHECK ==============
local drawingOk = pcall(function() local t=Drawing.new("Text") t:Remove() return true end)
if not drawingOk then return warn("[brieli vis] Drawing API недоступен.") end

-- ============== STATE ==============
local state = {
    -- ESP Players (только враги)
    espEnabled   = false,
    showBox      = false,
    boxStyle     = "corner",     -- full / corner
    showOutline  = false,         -- двухпроходная обводка
    showName     = false,
    showDistance = false,
    showHealth   = false,
    showHeadDot  = false,
    showTracer   = false,
    showSkeleton = false,
    fadeDist     = false,         -- fade by distance
    pulseLowHp   = false,         -- мигание на низком HP

    espColor     = Color3.fromRGB(255,60,60),
    maxDist      = 1500,

    -- Vehicle ESP
    vehEnabled   = false,
    vehShowBox   = false,
    vehShowName  = false,
    vehShowDist  = false,
    vehColor     = Color3.fromRGB(255,180,60),
    vehMaxDist   = 2500,
    vehFolder    = "SpawnedVehicles",

    -- Aim
    aimEnabled    = false,
    aimFov        = 150,
    aimSmooth     = 0.25,
    aimVisible    = false,
    aimTeamCheck  = true,
    aimPart       = "Head",
    aimSmoothMode = "linear",

    -- Menu
    menuKey      = Enum.KeyCode.RightShift,

    -- Internal
    drawings    = {},
    vehDrawings = {},
    vehCache    = {},
    vehCacheTime = 0,
    connections = {},
    renderConn  = nil,
    unloaded    = false,
    currentTab  = "visuals",
    loadingConfig = false,
}

local function bind(c) table.insert(state.connections,c) return c end

-- ============== ПАЛИТРА ==============
local C = {
    bg=Color3.fromRGB(13,16,21), topbar=Color3.fromRGB(17,21,27),
    sidebar=Color3.fromRGB(17,21,27), panelBg=Color3.fromRGB(20,25,31),
    row=Color3.fromRGB(21,26,33), rowHover=Color3.fromRGB(28,34,43),
    tabActive=Color3.fromRGB(24,40,54), tabHover=Color3.fromRGB(22,28,36),
    accent=Color3.fromRGB(0,200,255), accentDim=Color3.fromRGB(0,130,170),
    text=Color3.fromRGB(220,228,240), textDim=Color3.fromRGB(115,128,145),
    textMute=Color3.fromRGB(80,92,105), track=Color3.fromRGB(38,46,58),
    border=Color3.fromRGB(28,34,43),
}

local function colorToTable(c) return {R=math.floor(c.R*255+.5),G=math.floor(c.G*255+.5),B=math.floor(c.B*255+.5)} end
local function colorFromTable(t) if not t or type(t)~="table" then return nil end return Color3.fromRGB(t.R or 255,t.G or 255,t.B or 255) end

-- ============== КОНФИГ ==============
local function buildConfig()
    return {
        espEnabled=state.espEnabled, showBox=state.showBox, boxStyle=state.boxStyle,
        showOutline=state.showOutline,
        showName=state.showName, showDistance=state.showDistance, showHealth=state.showHealth,
        showHeadDot=state.showHeadDot, showTracer=state.showTracer, showSkeleton=state.showSkeleton,
        fadeDist=state.fadeDist, pulseLowHp=state.pulseLowHp,
        espColor=colorToTable(state.espColor), maxDist=state.maxDist,
        vehEnabled=state.vehEnabled, vehShowBox=state.vehShowBox, vehShowName=state.vehShowName,
        vehShowDist=state.vehShowDist, vehColor=colorToTable(state.vehColor),
        vehMaxDist=state.vehMaxDist, vehFolder=state.vehFolder,
        aimEnabled=state.aimEnabled, aimFov=state.aimFov, aimSmooth=state.aimSmooth,
        aimVisible=state.aimVisible, aimTeamCheck=state.aimTeamCheck,
        aimPart=state.aimPart, aimSmoothMode=state.aimSmoothMode,
        menuKeyName=state.menuKey and state.menuKey.Name or "RightShift",
    }
end
local function saveConfig()
    local ok, enc = pcall(function() return HttpService:JSONEncode(buildConfig()) end)
    if ok and enc then fsWrite(CONFIG_FILE, enc) end
end
local function loadConfigTable()
    local d = fsRead(CONFIG_FILE)
    if not d or d == "" then return nil end
    local ok, dec = pcall(function() return HttpService:JSONDecode(d) end)
    if ok then return dec end
    return nil
end

-- ============== GUI ==============
local parentGui
pcall(function() parentGui=(gethui and gethui()) or game:GetService("CoreGui") end)
if not parentGui then parentGui = LocalPlayer:WaitForChild("PlayerGui") end

local function round(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 6) c.Parent=o return c end
local function attachHover(btn,t)
    t = t or 1.02
    local s = Instance.new("UIScale") s.Scale=1 s.Parent=btn
    btn.MouseEnter:Connect(function() TweenService:Create(s,TweenInfo.new(0.1),{Scale=t}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(s,TweenInfo.new(0.1),{Scale=1}):Play() end)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "brieli_vis_cw"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 2147483647
screenGui.Parent = parentGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0,600,0,460)
main.Position = UDim2.new(0.5,-300,0.5,-230)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui
round(main, 8)

local mainStroke = Instance.new("UIStroke") mainStroke.Color=C.border mainStroke.Thickness=1 mainStroke.Parent=main

local topbar = Instance.new("Frame")
topbar.Size = UDim2.new(1,0,0,42) topbar.BackgroundColor3=C.topbar topbar.BorderSizePixel=0 topbar.Parent=main
round(topbar, 8)
local topbarCover = Instance.new("Frame")
topbarCover.Size = UDim2.new(1,0,0,12) topbarCover.Position=UDim2.new(0,0,1,-12)
topbarCover.BackgroundColor3=C.topbar topbarCover.BorderSizePixel=0 topbarCover.Parent=topbar

local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0,8,0,8) logoDot.Position=UDim2.new(0,18,0.5,-4)
logoDot.BackgroundColor3=C.accent logoDot.BorderSizePixel=0 logoDot.Parent=topbar
round(logoDot, 4)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size=UDim2.new(0,300,1,0) titleLabel.Position=UDim2.new(0,36,0,0)
titleLabel.BackgroundTransparency=1 titleLabel.Text="brieli vis" titleLabel.TextColor3=C.text
titleLabel.TextXAlignment=Enum.TextXAlignment.Left titleLabel.Font=Enum.Font.GothamBold
titleLabel.TextSize=15 titleLabel.Parent=topbar

local titleSub = Instance.new("TextLabel")
titleSub.Size=UDim2.new(0,300,1,0) titleSub.Position=UDim2.new(0,118,0,0)
titleSub.BackgroundTransparency=1 titleSub.Text="· CW [VIETNAM]" titleSub.TextColor3=C.textMute
titleSub.TextXAlignment=Enum.TextXAlignment.Left titleSub.Font=Enum.Font.Gotham
titleSub.TextSize=12 titleSub.Parent=topbar

local topbarSep = Instance.new("Frame")
topbarSep.Size=UDim2.new(1,0,0,1) topbarSep.Position=UDim2.new(0,0,0,42)
topbarSep.BackgroundColor3=C.border topbarSep.BorderSizePixel=0 topbarSep.Parent=main

-- SIDEBAR
local sidebar = Instance.new("Frame")
sidebar.Size=UDim2.new(0,140,1,-43) sidebar.Position=UDim2.new(0,0,0,43)
sidebar.BackgroundColor3=C.sidebar sidebar.BorderSizePixel=0 sidebar.Parent=main
local sidebarSep = Instance.new("Frame")
sidebarSep.Size=UDim2.new(0,1,1,0) sidebarSep.Position=UDim2.new(1,-1,0,0)
sidebarSep.BackgroundColor3=C.border sidebarSep.BorderSizePixel=0 sidebarSep.Parent=sidebar

local sidebarList = Instance.new("Frame")
sidebarList.Size=UDim2.new(1,0,1,0) sidebarList.BackgroundTransparency=1 sidebarList.Parent=sidebar
local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding=UDim.new(0,2) sidebarLayout.SortOrder=Enum.SortOrder.LayoutOrder sidebarLayout.Parent=sidebarList
local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop=UDim.new(0,12) sidebarPad.PaddingLeft=UDim.new(0,8)
sidebarPad.PaddingRight=UDim.new(0,8) sidebarPad.Parent=sidebarList

-- CONTENT
local content = Instance.new("Frame")
content.Size=UDim2.new(1,-141,1,-43) content.Position=UDim2.new(0,141,0,43)
content.BackgroundColor3=C.bg content.BorderSizePixel=0 content.Parent=main

local tabHeader = Instance.new("Frame")
tabHeader.Size=UDim2.new(1,0,0,38) tabHeader.BackgroundColor3=C.bg
tabHeader.BorderSizePixel=0 tabHeader.ZIndex=2 tabHeader.Parent=content
local tabHeaderSep = Instance.new("Frame")
tabHeaderSep.Size=UDim2.new(1,0,0,1) tabHeaderSep.Position=UDim2.new(0,0,1,-1)
tabHeaderSep.BackgroundColor3=C.border tabHeaderSep.BorderSizePixel=0 tabHeaderSep.Parent=tabHeader
local tabHeaderLabel = Instance.new("TextLabel")
tabHeaderLabel.Size=UDim2.new(1,-24,1,0) tabHeaderLabel.Position=UDim2.new(0,20,0,0)
tabHeaderLabel.BackgroundTransparency=1 tabHeaderLabel.Text="Visuals"
tabHeaderLabel.TextColor3=C.text tabHeaderLabel.TextXAlignment=Enum.TextXAlignment.Left
tabHeaderLabel.Font=Enum.Font.GothamBold tabHeaderLabel.TextSize=13 tabHeaderLabel.Parent=tabHeader

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size=UDim2.new(1,0,1,-38) contentScroll.Position=UDim2.new(0,0,0,38)
contentScroll.BackgroundTransparency=1 contentScroll.BorderSizePixel=0
contentScroll.ScrollBarThickness=3 contentScroll.ScrollBarImageColor3=C.accentDim
contentScroll.CanvasSize=UDim2.new(0,0,0,0) contentScroll.Parent=content

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding=UDim.new(0,6) contentLayout.SortOrder=Enum.SortOrder.LayoutOrder contentLayout.Parent=contentScroll
local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop=UDim.new(0,12) contentPad.PaddingLeft=UDim.new(0,14)
contentPad.PaddingRight=UDim.new(0,14) contentPad.PaddingBottom=UDim.new(0,12) contentPad.Parent=contentScroll

contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    contentScroll.CanvasSize = UDim2.new(0,0,0,contentLayout.AbsoluteContentSize.Y + 24)
end)

-- TABS
local tabButtons = {}
local tabNames = {
    visuals = { label="Visuals", icon="◉" },
    aim     = { label="Aim",     icon="◎" },
    menu    = { label="Menu",    icon="☰" },
}

local function switchTab(tabId)
    state.currentTab = tabId
    for id, btn in pairs(tabButtons) do
        local act = (id==tabId)
        btn.BackgroundColor3 = act and C.tabActive or C.sidebar
        local n = btn:FindFirstChild("TabName")
        local i = btn:FindFirstChild("TabIcon")
        if n then n.TextColor3 = act and C.accent or C.textDim end
        if i then i.TextColor3 = act and C.accent or C.textMute end
    end
    tabHeaderLabel.Text = tabNames[tabId].label
    for _, ch in ipairs(contentScroll:GetChildren()) do
        if ch:IsA("GuiObject") then
            ch.Visible = (ch:GetAttribute("Tab") == tabId)
        end
    end
end

for id, info in pairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,34) btn.BackgroundColor3=C.sidebar
    btn.BorderSizePixel=0 btn.AutoButtonColor=false btn.Text=""
    btn.Parent=sidebarList
    round(btn, 5)
    attachHover(btn, 1.02)
    local icon = Instance.new("TextLabel")
    icon.Name="TabIcon" icon.Size=UDim2.new(0,22,1,0) icon.Position=UDim2.new(0,10,0,0)
    icon.BackgroundTransparency=1 icon.Text=info.icon icon.TextColor3=C.textMute
    icon.Font=Enum.Font.GothamBold icon.TextSize=14 icon.TextXAlignment=Enum.TextXAlignment.Left
    icon.Parent=btn
    local n = Instance.new("TextLabel")
    n.Name="TabName" n.Size=UDim2.new(1,-40,1,0) n.Position=UDim2.new(0,36,0,0)
    n.BackgroundTransparency=1 n.Text=info.label n.TextColor3=C.textDim
    n.TextXAlignment=Enum.TextXAlignment.Left n.Font=Enum.Font.GothamMedium
    n.TextSize=12 n.Parent=btn
    btn.MouseEnter:Connect(function()
        if state.currentTab ~= id then btn.BackgroundColor3 = C.tabHover n.TextColor3 = C.text end
    end)
    btn.MouseLeave:Connect(function()
        if state.currentTab ~= id then btn.BackgroundColor3 = C.sidebar n.TextColor3 = C.textDim end
    end)
    btn.MouseButton1Click:Connect(function() switchTab(id) end)
    tabButtons[id] = btn
end

-- HELPERS
local function makeToggle(text, defaultOn, tabId, callback)
    local row = Instance.new("TextButton")
    row.Size=UDim2.new(1,0,0,34) row.BackgroundColor3=C.row
    row.BorderSizePixel=0 row.AutoButtonColor=false row.Text=""
    row.Parent=contentScroll
    row:SetAttribute("Tab", tabId)
    round(row, 5)
    attachHover(row, 1.02)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-70,1,0) l.Position=UDim2.new(0,14,0,0)
    l.BackgroundTransparency=1 l.Text=text l.TextColor3=C.text
    l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamMedium
    l.TextSize=12 l.Parent=row
    local track = Instance.new("Frame")
    track.Size=UDim2.new(0,34,0,18) track.Position=UDim2.new(1,-48,0.5,-9)
    track.BackgroundColor3=defaultOn and C.accent or C.track
    track.BorderSizePixel=0 track.Parent=row
    round(track, 9)
    local knob = Instance.new("Frame")
    knob.Size=UDim2.new(0,12,0,12)
    knob.Position=defaultOn and UDim2.new(1,-15,0.5,-6) or UDim2.new(0,3,0.5,-6)
    knob.BackgroundColor3=Color3.fromRGB(255,255,255) knob.BorderSizePixel=0 knob.Parent=track
    round(knob, 6)
    local st = defaultOn
    row.MouseEnter:Connect(function() row.BackgroundColor3=C.rowHover end)
    row.MouseLeave:Connect(function() row.BackgroundColor3=C.row end)
    row.MouseButton1Click:Connect(function()
        st = not st
        TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3=st and C.accent or C.track}):Play()
        if st then
            knob:TweenPosition(UDim2.new(1,-15,0.5,-6),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.15,true)
        else
            knob:TweenPosition(UDim2.new(0,3,0.5,-6),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.15,true)
        end
        callback(st)
    end)
    return row
end

local function makeColorButton(text, initialColor, tabId, callback)
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,34) btn.BackgroundColor3=C.row
    btn.BorderSizePixel=0 btn.AutoButtonColor=false btn.Text=""
    btn.Parent=contentScroll
    btn:SetAttribute("Tab", tabId)
    round(btn, 5)
    attachHover(btn, 1.02)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-70,1,0) l.Position=UDim2.new(0,14,0,0)
    l.BackgroundTransparency=1 l.Text=text l.TextColor3=C.text
    l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamMedium
    l.TextSize=12 l.Parent=btn
    local sw = Instance.new("Frame")
    sw.Size=UDim2.new(0,22,0,22) sw.Position=UDim2.new(1,-36,0.5,-11)
    sw.BackgroundColor3=initialColor sw.BorderSizePixel=0 sw.Parent=btn
    round(sw, 4)
    local presets = {
        Color3.fromRGB(255,60,60), Color3.fromRGB(255,200,0),
        Color3.fromRGB(80,220,120), Color3.fromRGB(0,170,255),
        Color3.fromRGB(255,0,255), Color3.fromRGB(255,255,255),
    }
    local idx = 1
    for i, c in ipairs(presets) do if c == initialColor then idx = i break end end
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=C.rowHover end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.row end)
    btn.MouseButton1Click:Connect(function()
        idx = idx % #presets + 1
        sw.BackgroundColor3 = presets[idx]
        callback(presets[idx])
    end)
    return btn
end

local function makeSlider(text, minV, maxV, defaultV, tabId, callback, step)
    step = step or 1
    local frame = Instance.new("Frame")
    frame.Size=UDim2.new(1,0,0,52) frame.BackgroundColor3=C.row
    frame.BorderSizePixel=0 frame.Parent=contentScroll
    frame:SetAttribute("Tab", tabId)
    round(frame, 5)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-90,0,20) l.Position=UDim2.new(0,14,0,6)
    l.BackgroundTransparency=1 l.Text=text l.TextColor3=C.text
    l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamMedium
    l.TextSize=12 l.Parent=frame
    local vl = Instance.new("TextLabel")
    vl.Size=UDim2.new(0,60,0,20) vl.Position=UDim2.new(1,-74,0,6)
    vl.BackgroundTransparency=1 vl.Text=tostring(defaultV) vl.TextColor3=C.accent
    vl.TextXAlignment=Enum.TextXAlignment.Right vl.Font=Enum.Font.GothamBold
    vl.TextSize=12 vl.Parent=frame
    local track = Instance.new("TextButton")
    track.Size=UDim2.new(1,-28,0,6) track.Position=UDim2.new(0,14,0,34)
    track.BackgroundColor3=C.track track.BorderSizePixel=0
    track.AutoButtonColor=false track.Text="" track.Parent=frame
    round(track, 3)
    local fill = Instance.new("Frame")
    fill.Size=UDim2.new((defaultV-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3=C.accent fill.BorderSizePixel=0 fill.Parent=track
    round(fill, 3)
    local handle = Instance.new("Frame")
    handle.Size=UDim2.new(0,12,0,12)
    handle.Position=UDim2.new((defaultV-minV)/(maxV-minV),-6,0.5,-6)
    handle.BackgroundColor3=Color3.fromRGB(255,255,255) handle.BorderSizePixel=0
    handle.ZIndex=2 handle.Parent=track
    round(handle, 6)
    local drag = false
    local function upd(input)
        local rx = math.clamp((input.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local v = minV + (maxV-minV)*rx
        if step >= 1 then v = math.floor(v/step+0.5)*step end
        fill.Size = UDim2.new(rx,0,1,0)
        handle.Position = UDim2.new(rx,-6,0.5,-6)
        vl.Text = step >= 1 and tostring(math.floor(v+0.5)) or string.format("%.2f",v)
        callback(v)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true main.Active = false upd(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            upd(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if drag then drag = false main.Active = true end
        end
    end)
    return frame
end

local function makeSection(text, tabId)
    local wrap = Instance.new("Frame")
    wrap.Size=UDim2.new(1,0,0,26) wrap.BackgroundTransparency=1 wrap.Parent=contentScroll
    wrap:SetAttribute("Tab", tabId)
    local bar = Instance.new("Frame")
    bar.Size=UDim2.new(0,3,0,12) bar.Position=UDim2.new(0,2,0.5,-6)
    bar.BackgroundColor3=C.accent bar.BorderSizePixel=0 bar.Parent=wrap
    round(bar, 2)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-20,1,0) l.Position=UDim2.new(0,14,0,0)
    l.BackgroundTransparency=1 l.Text=text l.TextColor3=C.text
    l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamBold
    l.TextSize=12 l.Parent=wrap
    return wrap
end

local function makeCycle(text, values, defaultVal, tabId, callback)
    local btn = Instance.new("TextButton")
    btn.Size=UDim2.new(1,0,0,34) btn.BackgroundColor3=C.row
    btn.BorderSizePixel=0 btn.AutoButtonColor=false btn.Text=""
    btn.Parent=contentScroll
    btn:SetAttribute("Tab", tabId)
    round(btn, 5)
    attachHover(btn, 1.02)
    local l = Instance.new("TextLabel")
    l.Size=UDim2.new(1,-120,1,0) l.Position=UDim2.new(0,14,0,0)
    l.BackgroundTransparency=1 l.Text=text l.TextColor3=C.text
    l.TextXAlignment=Enum.TextXAlignment.Left l.Font=Enum.Font.GothamMedium
    l.TextSize=12 l.Parent=btn
    local vL = Instance.new("TextLabel")
    vL.Size=UDim2.new(0,100,1,0) vL.Position=UDim2.new(1,-114,0,0)
    vL.BackgroundTransparency=1 vL.Text=tostring(defaultVal) vL.TextColor3=C.accent
    vL.TextXAlignment=Enum.TextXAlignment.Right vL.Font=Enum.Font.GothamBold
    vL.TextSize=12 vL.Parent=btn
    local current = defaultVal
    btn.MouseEnter:Connect(function() btn.BackgroundColor3=C.rowHover end)
    btn.MouseLeave:Connect(function() btn.BackgroundColor3=C.row end)
    btn.MouseButton1Click:Connect(function()
        local i
        for j, v in ipairs(values) do if v == current then i = j break end end
        i = (i or 0) % #values + 1
        current = values[i]
        vL.Text = tostring(current)
        callback(current)
    end)
    return btn
end

-- ============== ИГРОВАЯ ЛОГИКА ==============
local function getPlayerTeam(player)
    if player.Team and player.Team.Name ~= "" then return player.Team.Name end
    if player.TeamColor then return player.TeamColor.Name end
    local char = player.Character
    if char then
        local t = char:GetAttribute("Team") or char:GetAttribute("TeamName")
        if t then return tostring(t) end
    end
    local t = player:GetAttribute("Team") or player:GetAttribute("TeamName")
    if t then return tostring(t) end
    return nil
end
local function getMyTeam() return getPlayerTeam(LocalPlayer) end

local function isEnemy(player)
    if player == LocalPlayer then return false end
    local my = getMyTeam()
    local their = getPlayerTeam(player)
    if not my or not their then return true end
    return my ~= their
end

-- ============== AIM ==============
local fovCircle = nil

local function createFovCircle()
    if fovCircle then return end
    local ok, circle = pcall(Drawing.new, "Circle")
    if ok and circle then
        circle.Thickness = 1
        circle.NumSides = 60
        circle.Radius = state.aimFov
        circle.Filled = false
        circle.Color = Color3.fromRGB(255,255,255)
        circle.Transparency = 0.5
        circle.Visible = false
        fovCircle = circle
    end
end

local function isVisible(targetPart)
    if not state.aimVisible then return true end
    local cam = Workspace.CurrentCamera
    if not cam then return false end
    local char = LocalPlayer.Character
    if not char then return false end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances = { char, targetPart.Parent }
    local origin = cam.CFrame.Position
    local delta = targetPart.Position - origin
    local hit = Workspace:Raycast(origin, delta, rp)
    return hit == nil
end

local function getAimPart(char)
    if state.aimPart == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    elseif state.aimPart == "HumanoidRootPart" then
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
    elseif state.aimPart == "UpperTorso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    else
        local cam = Workspace.CurrentCamera
        if not cam then return char:FindFirstChild("Head") end
        local parts = {
            char:FindFirstChild("Head"),
            char:FindFirstChild("UpperTorso"),
            char:FindFirstChild("Torso"),
            char:FindFirstChild("HumanoidRootPart"),
        }
        local best, bestD = nil, math.huge
        for _, p in ipairs(parts) do
            if p then
                local d = (p.Position - cam.CFrame.Position).Magnitude
                if d < bestD then bestD = d best = p end
            end
        end
        return best or char:FindFirstChild("HumanoidRootPart")
    end
end

local function findTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local best, bestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isEnemy(player) then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = getAimPart(char)
        if not part then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local dist3d = root and (root.Position - cam.CFrame.Position).Magnitude or 0
        if dist3d > state.maxDist then continue end
        local sp, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        local d2d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
        if d2d > state.aimFov then continue end
        if d2d < bestDist then
            if state.aimVisible and not isVisible(part) then continue end
            bestDist = d2d
            best = part
        end
    end
    return best
end

local function aimTick()
    if not state.aimEnabled then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local target = findTarget()
    if not target then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local currentCF = cam.CFrame
    local lookCF = CFrame.lookAt(currentCF.Position, target.Position)
    if state.aimSmoothMode == "instant" then
        cam.CFrame = lookCF
    elseif state.aimSmoothMode == "linear" then
        cam.CFrame = currentCF:Lerp(lookCF, state.aimSmooth)
    else
        local t = 1 - (1 - state.aimSmooth) * 0.5
        cam.CFrame = currentCF:Lerp(lookCF, t)
    end
end

-- ============== DRAWING HELPERS ==============
local function col3(c) return Color3.new(c.R, c.G, c.B) end

-- Полный набор объектов для "красивой" отрисовки одного игрока
local function mkPlayerDrawings()
    local d = {
        -- Внешний бокс (обводка)
        outline = Drawing.new("Square"),
        -- Внутренний бокс (цветной)
        box     = Drawing.new("Square"),
        -- 8 линий для corner box
        c = {},
        -- Ник (двухпроходный)
        nameSh   = Drawing.new("Text"),
        name     = Drawing.new("Text"),
        -- Дистанция
        distSh   = Drawing.new("Text"),
        dist     = Drawing.new("Text"),
        -- HP bar
        hpBorder = Drawing.new("Square"),
        hpBg     = Drawing.new("Square"),
        hpFill   = Drawing.new("Square"),
        -- Head dot (двухпроходный)
        hdOutline = Drawing.new("Circle"),
        hdFill    = Drawing.new("Circle"),
        -- Tracer (двухпроходный)
        trOutline = Drawing.new("Line"),
        trFill    = Drawing.new("Line"),
        -- Skeleton
        skel      = {},
    }
    for i = 1, 8 do
        d.c[i] = Drawing.new("Line")
    end
    for i = 1, 14 do
        d.skel[i] = Drawing.new("Line")
    end
    return d
end

local function mkVehDrawings()
    return {
        outline = Drawing.new("Square"),
        box     = Drawing.new("Square"),
        nameSh  = Drawing.new("Text"),
        name    = Drawing.new("Text"),
        distSh  = Drawing.new("Text"),
        dist    = Drawing.new("Text"),
    }
end

local function destroyDrawings(d)
    if not d then return end
    for k, o in pairs(d) do
        if type(o) == "table" then
            for _, oo in pairs(o) do pcall(function() oo:Remove() end) end
        else
            pcall(function() o:Remove() end)
        end
    end
end

local function hideDrawings(d)
    if not d then return end
    for k, o in pairs(d) do
        if type(o) == "table" then
            for _, oo in pairs(o) do
                if oo and oo.Visible ~= nil and oo.Visible then oo.Visible = false end
            end
        else
            if o and o.Visible ~= nil and o.Visible then o.Visible = false end
        end
    end
end

-- ============== FADE BY DISTANCE ==============
-- Вычисляет прозрачность в зависимости от расстояния
local function getFadeAlpha(dist, maxDist)
    if not state.fadeDist then return 1 end
    local t = math.clamp(dist / maxDist, 0, 1)
    -- Близко (0) = 1, далеко (1) = 0.35
    return 1 - t * 0.65
end

-- ============== PULSE LOW HP ==============
-- Возвращает модифицированный цвет для мигания
local function pulseColor(baseColor, hp, now)
    if not state.pulseLowHp or hp > 0.3 then return baseColor end
    local pulse = (math.sin(now * 8) + 1) / 2 -- 0..1
    -- Микс между базовым и белым
    return baseColor:Lerp(Color3.new(1,1,1), pulse * 0.5)
end

-- ============== VEHICLE CACHE ==============
local function refreshVehicleCache()
    state.vehCache = {}
    local folder = Workspace:FindFirstChild(state.vehFolder)
    if not folder then
        for _, d in ipairs(Workspace:GetChildren()) do
            local n = d.Name:lower()
            if n:find("vehicle") or n:find("car") or n:find("tank") then
                folder = d break
            end
        end
    end
    if not folder then return end
    for _, v in ipairs(folder:GetChildren()) do
        if v:IsA("Model") then
            local pp = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart", true)
            if pp then state.vehCache[v] = pp end
        end
    end
end

-- ============== SKELETON BONES ==============
local R15_BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

-- ============== RENDER ==============
local RENDER_INTERVAL = 1/30
local lastRender = 0

local renderConn = RunService.RenderStepped:Connect(function()
    if state.unloaded then return end
    local now = tick()

    pcall(aimTick)

    createFovCircle()
    if fovCircle then
        if state.aimEnabled then
            local cam = Workspace.CurrentCamera
            fovCircle.Position = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
            fovCircle.Radius = state.aimFov
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end

    if now - lastRender < RENDER_INTERVAL then return end
    lastRender = now

    local cam = Workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector
    local vpSize = cam.ViewportSize

    if state.vehEnabled and now - state.vehCacheTime > 1 then
        state.vehCacheTime = now
        pcall(refreshVehicleCache)
    end

    -- === PLAYER ESP (только враги) ===
    if not state.espEnabled then
        for _, d in pairs(state.drawings) do hideDrawings(d) end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer or not isEnemy(player) then
                local d = state.drawings[player]
                if d then hideDrawings(d) end
                continue
            end
            local char = player.Character
            if not char then
                local d = state.drawings[player]
                if d then hideDrawings(d) end
                continue
            end
            local head = char:FindFirstChild("Head")
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not head or not root or not hum or hum.Health <= 0 then
                local d = state.drawings[player]
                if d then hideDrawings(d) end
                continue
            end

            local toT = root.Position - camPos
            local dist3d = toT.Magnitude
            if toT:Dot(camLook) < 0 or dist3d > state.maxDist then
                local d = state.drawings[player]
                if d then hideDrawings(d) end
                continue
            end

            local sp = cam:WorldToViewportPoint(root.Position)
            if sp.X < -200 or sp.X > vpSize.X+200 or sp.Y < -200 or sp.Y > vpSize.Y+200 then
                local d = state.drawings[player]
                if d then hideDrawings(d) end
                continue
            end

            local d = state.drawings[player]
            if not d then
                d = mkPlayerDrawings()
                state.drawings[player] = d
            end

            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local fade = getFadeAlpha(dist3d, state.maxDist)
            local baseCol = pulseColor(state.espColor, hp, now)
            local col = col3(baseCol)

            -- Работаем с коробкой
            local headSp = cam:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            local footSp = cam:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
            local boxH = math.abs(footSp.Y - headSp.Y)
            local boxW = boxH * 0.55
            local boxX = headSp.X - boxW/2
            local boxY = headSp.Y

            -- Скрываем всё заранее
            d.box.Visible = false
            d.outline.Visible = false
            for i = 1, 8 do d.c[i].Visible = false end

            -- Полный бокс или corner box
            if state.showBox then
                if state.boxStyle == "full" then
                    -- Outline
                    if state.showOutline then
                        d.outline.Visible = true
                        d.outline.Color = Color3.new(0,0,0)
                        d.outline.Thickness = 3
                        d.outline.Filled = false
                        d.outline.Transparency = fade
                        d.outline.Size = Vector2.new(boxW, boxH)
                        d.outline.Position = Vector2.new(boxX, boxY)
                    end
                    d.box.Visible = true
                    d.box.Color = col
                    d.box.Thickness = 1
                    d.box.Filled = false
                    d.box.Transparency = fade
                    d.box.Size = Vector2.new(boxW, boxH)
                    d.box.Position = Vector2.new(boxX, boxY)
                else -- corner
                    local cornerLen = math.clamp(math.min(boxW, boxH) * 0.22, 4, 20)
                    local x1, y1 = boxX, boxY
                    local x2, y2 = boxX + boxW, boxY + boxH
                    -- Отступ
                    local ofs = state.showOutline and 1 or 0
                    -- 8 линий
                    local lines = {
                        {Vector2.new(x1, y1), Vector2.new(x1 + cornerLen, y1)},
                        {Vector2.new(x1, y1), Vector2.new(x1, y1 + cornerLen)},
                        {Vector2.new(x2, y1), Vector2.new(x2 - cornerLen, y1)},
                        {Vector2.new(x2, y1), Vector2.new(x2, y1 + cornerLen)},
                        {Vector2.new(x1, y2), Vector2.new(x1 + cornerLen, y2)},
                        {Vector2.new(x1, y2), Vector2.new(x1, y2 - cornerLen)},
                        {Vector2.new(x2, y2), Vector2.new(x2 - cornerLen, y2)},
                        {Vector2.new(x2, y2), Vector2.new(x2, y2 - cornerLen)},
                    }
                    for i, ln in ipairs(lines) do
                        local line = d.c[i]
                        line.Visible = true
                        line.From = ln[1]
                        line.To = ln[2]
                        line.Color = col
                        line.Thickness = 1.5
                        line.Transparency = fade
                    end
                end
            end

            -- Ник с двухпроходным текстом (тень + цветной)
            if state.showName then
                d.nameSh.Visible = true
                d.nameSh.Text = player.Name
                d.nameSh.Color = Color3.new(0,0,0)
                d.nameSh.Size = 13
                d.nameSh.Center = true
                d.nameSh.Outline = false
                d.nameSh.Transparency = fade
                d.nameSh.Position = Vector2.new(headSp.X + 1, boxY - 16 + 1)

                d.name.Visible = true
                d.name.Text = player.Name
                d.name.Color = col
                d.name.Size = 13
                d.name.Center = true
                d.name.Outline = false
                d.name.Transparency = fade
                d.name.Position = Vector2.new(headSp.X, boxY - 16)
            else
                d.nameSh.Visible = false
                d.name.Visible = false
            end

            -- Дистанция
            if state.showDistance then
                local txt = string.format("[%d]", math.floor(dist3d))
                d.distSh.Visible = true
                d.distSh.Text = txt
                d.distSh.Color = Color3.new(0,0,0)
                d.distSh.Size = 12
                d.distSh.Center = true
                d.distSh.Transparency = fade
                d.distSh.Position = Vector2.new(headSp.X + 1, boxY + boxH + 3 + 1)

                d.dist.Visible = true
                d.dist.Text = txt
                d.dist.Color = Color3.fromRGB(220,220,220)
                d.dist.Size = 12
                d.dist.Center = true
                d.dist.Transparency = fade
                d.dist.Position = Vector2.new(headSp.X, boxY + boxH + 3)
            else
                d.distSh.Visible = false
                d.dist.Visible = false
            end

            -- HP bar — вертикальный слева от бокса
            if state.showHealth then
                local barW = 3
                local barH = boxH
                local barX = boxX - barW - 4
                local barY = boxY

                -- Чёрный фон (border)
                d.hpBorder.Visible = true
                d.hpBorder.Filled = true
                d.hpBorder.Color = Color3.new(0,0,0)
                d.hpBorder.Size = Vector2.new(barW + 2, barH + 2)
                d.hpBorder.Position = Vector2.new(barX - 1, barY - 1)
                d.hpBorder.Transparency = 1 - fade * 0.6

                -- Тёмный фон
                d.hpBg.Visible = true
                d.hpBg.Filled = true
                d.hpBg.Color = Color3.fromRGB(25,25,25)
                d.hpBg.Size = Vector2.new(barW, barH)
                d.hpBg.Position = Vector2.new(barX, barY)
                d.hpBg.Transparency = 1 - fade * 0.85

                -- Заполнение снизу вверх
                local fillH = barH * hp
                local hpCol
                if hp > 0.6 then hpCol = Color3.fromRGB(60,220,100)
                elseif hp > 0.3 then hpCol = Color3.fromRGB(255,200,0)
                else hpCol = Color3.fromRGB(220,60,60) end

                d.hpFill.Visible = true
                d.hpFill.Filled = true
                d.hpFill.Color = hpCol
                d.hpFill.Size = Vector2.new(barW, fillH)
                d.hpFill.Position = Vector2.new(barX, barY + barH - fillH)
                d.hpFill.Transparency = fade
            else
                d.hpBorder.Visible = false
                d.hpBg.Visible = false
                d.hpFill.Visible = false
            end

            -- Head dot с двухпроходным контуром
            if state.showHeadDot then
                local hp3d = head.Position + Vector3.new(0, 0.3, 0)
                local hdSp = cam:WorldToViewportPoint(hp3d)

                d.hdOutline.Visible = true
                d.hdOutline.Position = Vector2.new(hdSp.X, hdSp.Y)
                d.hdOutline.Radius = 6
                d.hdOutline.Color = Color3.new(0,0,0)
                d.hdOutline.Filled = true
                d.hdOutline.Transparency = 1 - fade * 0.5
                d.hdOutline.NumSides = 24
                d.hdOutline.Thickness = 1

                d.hdFill.Visible = true
                d.hdFill.Position = Vector2.new(hdSp.X, hdSp.Y)
                d.hdFill.Radius = 3
                d.hdFill.Color = col
                d.hdFill.Filled = true
                d.hdFill.Transparency = fade
                d.hdFill.NumSides = 24
            else
                d.hdOutline.Visible = false
                d.hdFill.Visible = false
            end

            -- Tracer с двухпроходным
            if state.showTracer then
                local fromP = Vector2.new(vpSize.X / 2, vpSize.Y)
                local toP = Vector2.new(headSp.X, headSp.Y)

                d.trOutline.Visible = true
                d.trOutline.Color = Color3.new(0,0,0)
                d.trOutline.Thickness = 3
                d.trOutline.From = fromP
                d.trOutline.To = toP
                d.trOutline.Transparency = 1 - fade * 0.5

                d.trFill.Visible = true
                d.trFill.Color = col
                d.trFill.Thickness = 1.5
                d.trFill.From = fromP
                d.trFill.To = toP
                d.trFill.Transparency = fade
            else
                d.trOutline.Visible = false
                d.trFill.Visible = false
            end

            -- Skeleton
            if state.showSkeleton then
                local bones = char:FindFirstChild("UpperTorso") and R15_BONES
                    or (char:FindFirstChild("Torso") and R6_BONES or nil)
                if bones then
                    for i, bone in ipairs(bones) do
                        local line = d.skel[i]
                        if line then
                            local p1 = char:FindFirstChild(bone[1])
                            local p2 = char:FindFirstChild(bone[2])
                            if p1 and p2 then
                                local s1, o1 = cam:WorldToViewportPoint(p1.Position)
                                local s2, o2 = cam:WorldToViewportPoint(p2.Position)
                                if o1 and o2 then
                                    line.From = Vector2.new(s1.X, s1.Y)
                                    line.To = Vector2.new(s2.X, s2.Y)
                                    line.Color = col
                                    line.Thickness = 1.5
                                    line.Transparency = fade
                                    line.Visible = true
                                else line.Visible = false end
                            else line.Visible = false end
                        end
                    end
                    for i = #bones + 1, 14 do
                        if d.skel[i] then d.skel[i].Visible = false end
                    end
                else
                    for i = 1, 14 do if d.skel[i] then d.skel[i].Visible = false end end
                end
            else
                for i = 1, 14 do if d.skel[i] then d.skel[i].Visible = false end end
            end
        end
    end

    -- === VEHICLE ESP ===
    if not state.vehEnabled then
        for _, d in pairs(state.vehDrawings) do hideDrawings(d) end
    else
        for model, pp in pairs(state.vehCache) do
            if not model or not model.Parent or not pp or not pp.Parent then
                local d = state.vehDrawings[model]
                if d then hideDrawings(d) end
                continue
            end
            local pos = pp.Position
            local toV = pos - camPos
            local dist3d = toV.Magnitude
            if toV:Dot(camLook) < 0 or dist3d > state.vehMaxDist then
                local d = state.vehDrawings[model]
                if d then hideDrawings(d) end
                continue
            end
            local sp = cam:WorldToViewportPoint(pos)
            if sp.X < -400 or sp.X > vpSize.X+400 or sp.Y < -400 or sp.Y > vpSize.Y+400 then
                local d = state.vehDrawings[model]
                if d then hideDrawings(d) end
                continue
            end

            local d = state.vehDrawings[model]
            if not d then
                d = mkVehDrawings()
                state.vehDrawings[model] = d
            end

            local fade = getFadeAlpha(dist3d, state.vehMaxDist)
            local col = col3(state.vehColor)

            local sz = pp.Size
            local top = cam:WorldToViewportPoint(pos + Vector3.new(0, sz.Y/2 + 1, 0))
            local bot = cam:WorldToViewportPoint(pos - Vector3.new(0, sz.Y/2 + 1, 0))
            local boxH = math.abs(bot.Y - top.Y)
            local boxW = boxH * 1.2
            local boxX = top.X - boxW/2
            local boxY = top.Y

            if state.vehShowBox then
                d.outline.Visible = true
                d.outline.Color = Color3.new(0,0,0)
                d.outline.Thickness = 3
                d.outline.Filled = false
                d.outline.Transparency = 1 - fade * 0.5
                d.outline.Size = Vector2.new(boxW, boxH)
                d.outline.Position = Vector2.new(boxX, boxY)

                d.box.Visible = true
                d.box.Color = col
                d.box.Thickness = 1.5
                d.box.Filled = false
                d.box.Transparency = fade
                d.box.Size = Vector2.new(boxW, boxH)
                d.box.Position = Vector2.new(boxX, boxY)
            else
                d.outline.Visible = false
                d.box.Visible = false
            end

            if state.vehShowName then
                d.nameSh.Visible = true
                d.nameSh.Text = model.Name
                d.nameSh.Color = Color3.new(0,0,0)
                d.nameSh.Size = 13
                d.nameSh.Center = true
                d.nameSh.Transparency = fade
                d.nameSh.Position = Vector2.new(top.X + 1, boxY - 16 + 1)

                d.name.Visible = true
                d.name.Text = model.Name
                d.name.Color = col
                d.name.Size = 13
                d.name.Center = true
                d.name.Transparency = fade
                d.name.Position = Vector2.new(top.X, boxY - 16)
            else
                d.nameSh.Visible = false
                d.name.Visible = false
            end

            if state.vehShowDist then
                local txt = string.format("[%d]", math.floor(dist3d))
                d.distSh.Visible = true
                d.distSh.Text = txt
                d.distSh.Color = Color3.new(0,0,0)
                d.distSh.Size = 12
                d.distSh.Center = true
                d.distSh.Transparency = fade
                d.distSh.Position = Vector2.new(top.X + 1, boxY + boxH + 3 + 1)

                d.dist.Visible = true
                d.dist.Text = txt
                d.dist.Color = Color3.fromRGB(220,220,220)
                d.dist.Size = 12
                d.dist.Center = true
                d.dist.Transparency = fade
                d.dist.Position = Vector2.new(top.X, boxY + boxH + 3)
            else
                d.distSh.Visible = false
                d.dist.Visible = false
            end
        end
    end
end)

-- ============== UI ==============
-- VISUALS - PLAYERS
makeSection("ESP ИГРОКОВ (только враги)", "visuals")
makeToggle("ESP вкл", false, "visuals", function(on) state.espEnabled = on end)
makeToggle("Рамка", false, "visuals", function(on) state.showBox = on end)
makeCycle("Стиль рамки", {"corner","full"}, state.boxStyle, "visuals", function(v) state.boxStyle = v end)
makeToggle("Обводка (двухпроходная)", false, "visuals", function(on) state.showOutline = on end)
makeToggle("Ник", false, "visuals", function(on) state.showName = on end)
makeToggle("Дистанция", false, "visuals", function(on) state.showDistance = on end)
makeToggle("Полоса HP", false, "visuals", function(on) state.showHealth = on end)
makeToggle("Точка на голове", false, "visuals", function(on) state.showHeadDot = on end)
makeToggle("Трейсер", false, "visuals", function(on) state.showTracer = on end)
makeToggle("Скелет", false, "visuals", function(on) state.showSkeleton = on end)

makeSection("СТИЛЬ", "visuals")
makeToggle("Fade по дистанции", false, "visuals", function(on) state.fadeDist = on end)
makeToggle("Пульс при низком HP", false, "visuals", function(on) state.pulseLowHp = on end)
makeColorButton("Цвет", Color3.fromRGB(255,60,60), "visuals", function(c) state.espColor = c end)
makeSlider("Макс. дистанция", 100, 5000, 1500, "visuals", function(v) state.maxDist = v end, 50)

-- VISUALS - VEHICLES
makeSection("ESP ТЕХНИКИ", "visuals")
makeToggle("ESP техники", false, "visuals", function(on) state.vehEnabled = on end)
makeToggle("Рамка", false, "visuals", function(on) state.vehShowBox = on end)
makeToggle("Название", false, "visuals", function(on) state.vehShowName = on end)
makeToggle("Дистанция", false, "visuals", function(on) state.vehShowDist = on end)
makeColorButton("Цвет", Color3.fromRGB(255,180,60), "visuals", function(c) state.vehColor = c end)
makeSlider("Макс. дистанция", 100, 8000, 2500, "visuals", function(v) state.vehMaxDist = v end, 100)

-- AIM
makeSection("AIM", "aim")
makeToggle("Aim вкл (ПКМ)", false, "aim", function(on) state.aimEnabled = on end)
makeSection("КУДА ЦЕЛИТЬСЯ", "aim")
makeCycle("Часть тела", {"Head","UpperTorso","HumanoidRootPart","Closest"}, state.aimPart, "aim", function(v) state.aimPart = v end)
makeSection("КАК ЦЕЛИТЬСЯ", "aim")
makeCycle("Тип", {"linear","smooth","instant"}, state.aimSmoothMode, "aim", function(v) state.aimSmoothMode = v end)
makeSection("НАСТРОЙКИ", "aim")
makeSlider("FOV", 20, 500, 150, "aim", function(v) state.aimFov = v end, 10)
makeSlider("Плавность (0.05–1)", 0.05, 1, 0.25, "aim", function(v) state.aimSmooth = v end, 0.05)
makeToggle("Проверять видимость", false, "aim", function(on) state.aimVisible = on end)
makeToggle("Только враги", true, "aim", function(on) state.aimTeamCheck = on end)

-- MENU
makeSection("КЛАВИША МЕНЮ", "menu")
local keybindBtn = Instance.new("TextButton")
keybindBtn.Size=UDim2.new(1,0,0,34) keybindBtn.BackgroundColor3=C.row
keybindBtn.BorderSizePixel=0 keybindBtn.AutoButtonColor=false
keybindBtn.Text="  Изменить ("..state.menuKey.Name..")" keybindBtn.TextColor3=C.text
keybindBtn.TextXAlignment=Enum.TextXAlignment.Left keybindBtn.Font=Enum.Font.GothamMedium
keybindBtn.TextSize=12 keybindBtn.Parent=contentScroll
keybindBtn:SetAttribute("Tab","menu")
round(keybindBtn, 5)
attachHover(keybindBtn, 1.02)
keybindBtn.MouseEnter:Connect(function() keybindBtn.BackgroundColor3=C.rowHover end)
keybindBtn.MouseLeave:Connect(function() keybindBtn.BackgroundColor3=C.row end)
local listening = false
keybindBtn.MouseButton1Click:Connect(function()
    if listening then return end
    listening = true
    keybindBtn.Text = "  Нажмите..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            state.menuKey = input.KeyCode
            keybindBtn.Text = "  Изменить ("..input.KeyCode.Name..")"
            listening = false
            conn:Disconnect()
        end
    end)
end)

local unloadBtn = Instance.new("TextButton")
unloadBtn.Size=UDim2.new(0,120,0,28)
unloadBtn.Position=UDim2.new(1,-14,1,-14)
unloadBtn.AnchorPoint=Vector2.new(1,1)
unloadBtn.BackgroundColor3=Color3.fromRGB(140,35,35)
unloadBtn.BorderSizePixel=0 unloadBtn.AutoButtonColor=false
unloadBtn.Text="Выгрузить" unloadBtn.TextColor3=Color3.fromRGB(255,220,220)
unloadBtn.Font=Enum.Font.GothamMedium unloadBtn.TextSize=12 unloadBtn.Parent=main
round(unloadBtn, 5)

-- UNLOAD
local function unload()
    if state.unloaded then return end
    state.unloaded = true
    pcall(saveConfig)
    for _, c in ipairs(state.connections) do pcall(function() c:Disconnect() end) end
    state.connections = {}
    if renderConn then renderConn:Disconnect() end
    for _, d in pairs(state.drawings) do destroyDrawings(d) end
    state.drawings = {}
    for _, d in pairs(state.vehDrawings) do destroyDrawings(d) end
    state.vehDrawings = {}
    if fovCircle then pcall(function() fovCircle:Remove() end) end
    if screenGui then pcall(function() screenGui:Destroy() end) end
    _G.brieliVisUnload = nil
    print("[brieli vis] выгружен")
end
unloadBtn.MouseButton1Click:Connect(unload)
_G.brieliVisUnload = unload

bind(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == state.menuKey then main.Visible = not main.Visible end
end))

-- START
local loadedCfg = loadConfigTable()
if loadedCfg then
    task.spawn(function()
        task.wait(0.3)
        for k, v in pairs(loadedCfg) do
            if k == "espColor" then
                local c = colorFromTable(v); if c then state.espColor = c end
            elseif k == "vehColor" then
                local c = colorFromTable(v); if c then state.vehColor = c end
            elseif k == "menuKeyName" then
                local ok, key = pcall(function() return Enum.KeyCode[v] end)
                if ok and key then state.menuKey = key end
            elseif type(state[k]) ~= "nil" and type(v) == type(state[k]) then
                state[k] = v
            end
        end
    end)
end

switchTab("visuals")

task.spawn(function()
    while not state.unloaded do
        task.wait(5)
        if not state.unloaded then pcall(saveConfig) end
    end
end)

print("[brieli vis] v11 Midnight-style загружен. Правый Shift — меню.")
