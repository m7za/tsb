local runService = game:GetService("RunService")
local players = game:GetService("Players")
local userInputService = game:GetService("UserInputService")
local tweenService = game:GetService("TweenService")
local starterGui = game:GetService("StarterGui")
local localPlayer = players.LocalPlayer

if _G.KontaTechCleanup then
    pcall(_G.KontaTechCleanup)
end

local sessionId = math.random(100000, 999999)
_G.KontaTechId = sessionId

local function isAlive()
    return _G.KontaTechId == sessionId
end

local settings = {
    Enabled = true,
    CooldownEnabled = true,
    Spin = false,
    DashDelay = 0.271,
    DashWait = 0.6,
    DashCooldown = 4.9,
    DashRetry = 0.06,
    UnderOffset = 0,
    ScanRadius = 35,
    StunDelay = 0,
    StunDuration = 0.9,
    SpinDelay = 0,
    SpinDuration = 1,
    SpinSpeed = 22,
}

local limits = {
    DashDelay = {0, 1},
    StunDelay = {0, 1},
    StunDuration = {0.01, 1},
    SpinDelay = {0, 1},
    SpinDuration = {0.01, 1},
    SpinSpeed = {2, 60},
}

local triggerAnimations = {
    ["10503381238"] = true,
}

local dashAnimations = {
    ["10479335397"] = true,
    ["10491993682"] = true,
    ["13380255751"] = true,
}

local uiConnections = {}
local charConnections = {}
local windowEnd = 0
local pendingTarget = nil
local dashPending = false
local techActive = false
local lastDashTime = -math.huge
local dashStarted = false
local stopTech = nil
local screenGui = nil

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function getAnimationId(animation)
    if not animation then
        return nil
    end
    return tostring(animation.AnimationId):match("%d+")
end

local function isValidTarget(model)
    if not model or not model.Parent then
        return false
    end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart")
    return humanoid ~= nil and root ~= nil and humanoid.Health > 0
end

local function findNearestTarget(character, rootPart)
    overlapParams.FilterDescendantsInstances = {character}
    local best = nil
    local bestDistance = math.huge
    local seen = {}
    for _, part in ipairs(workspace:GetPartBoundsInRadius(rootPart.Position, settings.ScanRadius, overlapParams)) do
        local model = part:FindFirstAncestorOfClass("Model")
        if model and model ~= character and not seen[model] then
            seen[model] = true
            if isValidTarget(model) then
                local distance = (model.HumanoidRootPart.Position - rootPart.Position).Magnitude
                if distance < bestDistance then
                    best = model
                    bestDistance = distance
                end
            end
        end
    end
    return best
end

local function fireDash(character)
    local communicate = character and character:FindFirstChild("Communicate")
    if not communicate then
        return
    end
    communicate:FireServer({
        Dash = Enum.KeyCode.W,
        Key = Enum.KeyCode.Q,
        Goal = "KeyPress",
    })
end

local function startTech(character, humanoid, rootPart, target, track)
    if techActive then
        return
    end
    techActive = true

    local connections = {}
    local disabledParts = {}
    local finished = false
    local started = false
    local baseYaw = 0

    local function stop()
        if finished then
            return
        end
        finished = true
        for _, connection in ipairs(connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        if started then
            for _, part in ipairs(disabledParts) do
                if part.Parent then
                    part.CanCollide = true
                end
            end
            if humanoid.Parent then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
            end
            if rootPart.Parent then
                rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, baseYaw, 0)
                rootPart.AssemblyAngularVelocity = Vector3.zero
            end
        end
        techActive = false
        if stopTech == stop then
            stopTech = nil
        end
    end

    stopTech = stop
    table.insert(connections, track.Stopped:Connect(stop))

    if settings.StunDelay > 0 then
        task.wait(settings.StunDelay)
    end
    if finished then
        return
    end
    if not isAlive() or not settings.Enabled or humanoid.Health <= 0
        or not rootPart.Parent or not isValidTarget(target) then
        stop()
        return
    end

    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    local _, yaw = rootPart.CFrame:ToOrientation()
    baseYaw = yaw

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character, target}

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            disabledParts[#disabledParts + 1] = part
            part.CanCollide = false
        end
    end

    humanoid.PlatformStand = true
    humanoid.AutoRotate = false
    started = true

    local spinAngle = 0
    local startClock = os.clock()
    local lastElapsed = 0

    local function update()
        if finished or not rootPart.Parent or not targetRoot.Parent then
            return
        end
        local elapsed = os.clock() - startClock
        if settings.Spin then

            local spinFrom = math.max(lastElapsed, settings.SpinDelay)
            local spinTo = math.min(elapsed, settings.SpinDelay + settings.SpinDuration)
            if spinTo > spinFrom then
                spinAngle = spinAngle + settings.SpinSpeed * (spinTo - spinFrom)
            end
        end
        lastElapsed = elapsed
        local position = targetRoot.Position
        local height = position.Y - settings.UnderOffset
        local hit = workspace:Raycast(position, Vector3.new(0, -(settings.UnderOffset + 3), 0), rayParams)
        if hit then
            height = math.max(height, hit.Position.Y + 2)
        end
        rootPart.CFrame = CFrame.new(position.X, height, position.Z)
            * CFrame.Angles(0, baseYaw + spinAngle, 0)
            * CFrame.Angles(math.rad(90), 0, 0)
        rootPart.AssemblyLinearVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end

    table.insert(connections, runService.RenderStepped:Connect(update))
    table.insert(connections, runService.Heartbeat:Connect(function()
        if not isAlive() or humanoid.Health <= 0 or not isValidTarget(target) then
            stop()
        else
            task.defer(update)
        end
    end))
    task.delay(settings.StunDuration, stop)
    update()
end

local function onAnimation(character, humanoid, rootPart, track)
    if not isAlive() or not settings.Enabled then
        return
    end
    local animationId = getAnimationId(track.Animation)
    if not animationId then
        return
    end

    if triggerAnimations[animationId] then
        if dashPending or techActive then
            return
        end
        if settings.CooldownEnabled
            and not workspace:GetAttribute("NoDashCooldown")
            and os.clock() - lastDashTime < settings.DashCooldown then
            return
        end
        local target = findNearestTarget(character, rootPart)
        if not target then
            return
        end
        dashPending = true
        dashStarted = false
        pendingTarget = target
        windowEnd = os.clock() + settings.DashDelay + settings.DashWait
        task.wait(settings.DashDelay)
        local deadline = os.clock() + settings.DashWait
        while not dashStarted and os.clock() < deadline do
            if not isAlive() or not settings.Enabled or character ~= localPlayer.Character or humanoid.Health <= 0 then
                break
            end
            fireDash(character)
            task.wait(settings.DashRetry)
        end
        dashPending = false
        pendingTarget = nil
        return
    end

    if dashAnimations[animationId] then
        lastDashTime = os.clock()
        dashStarted = true
    end
    if dashAnimations[animationId] and not techActive and os.clock() <= windowEnd then
        windowEnd = 0
        local target = pendingTarget
        pendingTarget = nil
        if not isValidTarget(target) then
            target = findNearestTarget(character, rootPart)
        end
        if target then
            startTech(character, humanoid, rootPart, target, track)
        end
    end
end

local function onCharacter(character)
    for _, connection in ipairs(charConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(charConnections)
    if stopTech then
        pcall(stopTech)
    end
    dashPending = false
    windowEnd = 0
    pendingTarget = nil
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")
    if not isAlive() or character ~= localPlayer.Character then
        return
    end
    table.insert(charConnections, humanoid.AnimationPlayed:Connect(function(track)
        task.spawn(onAnimation, character, humanoid, rootPart, track)
    end))
end

local function cleanup()
    if stopTech then
        pcall(stopTech)
    end
    for _, connection in ipairs(uiConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    for _, connection in ipairs(charConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(uiConnections)
    table.clear(charConnections)
    if screenGui then
        pcall(function()
            screenGui:Destroy()
        end)
        screenGui = nil
    end
end
_G.KontaTechCleanup = cleanup

local httpService = game:GetService("HttpService")

local theme = {
    Bg = Color3.fromRGB(16, 16, 20),
    Surface = Color3.fromRGB(25, 25, 31),
    SurfaceHover = Color3.fromRGB(31, 31, 38),
    Stroke = Color3.fromRGB(42, 42, 52),
    Text = Color3.fromRGB(233, 233, 239),
    Muted = Color3.fromRGB(130, 130, 144),
    Accent = Color3.fromRGB(224, 62, 74),
    Danger = Color3.fromRGB(235, 87, 87),
    Off = Color3.fromRGB(52, 52, 62),
}

local function addCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = parent
end

local function addStroke(parent, color)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local windowWidth = 270
local headerHeight = 42
local tabHeight = 26
local contentTop = headerHeight + 1 + 8 + tabHeight + 6
local windowHeight = 350

screenGui = Instance.new("ScreenGui")
screenGui.Name = "KontaTech"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 50
screenGui.Parent = (function()
    if gethui then
        return gethui()
    end
    if pcall(function()
        return game:GetService("CoreGui").Name
    end) then
        return game:GetService("CoreGui")
    end
    return localPlayer:WaitForChild("PlayerGui")
end)()

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(windowWidth, windowHeight)
mainFrame.Position = UDim2.new(0, 24, 0.5, -math.floor(windowHeight / 2))
mainFrame.BackgroundColor3 = theme.Bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui
addCorner(mainFrame, 10)
addStroke(mainFrame, theme.Stroke)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, headerHeight)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(14, 0)
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = theme.Text
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.RichText = true
titleLabel.Text = 'Konta Tech  <font size="11" color="rgb(130,130,144)">by XeyZ</font>'
titleLabel.Parent = header

local function makeHeaderButton(text, offsetX)
    local button = Instance.new("TextButton")
    button.Size = UDim2.fromOffset(26, 26)
    button.Position = UDim2.new(1, offsetX, 0.5, -13)
    button.BackgroundTransparency = 1
    button.Text = text
    button.TextColor3 = theme.Muted
    button.Font = Enum.Font.GothamBold
    button.TextSize = 15
    button.AutoButtonColor = false
    button.Parent = header
    return button
end

local minimizeButton = makeHeaderButton("–", -64)
local closeButton = makeHeaderButton("×", -34)

local cooldownLabel = Instance.new("TextLabel")
cooldownLabel.BackgroundTransparency = 1
cooldownLabel.Position = UDim2.new(1, -112, 0, 0)
cooldownLabel.Size = UDim2.new(0, 46, 1, 0)
cooldownLabel.Font = Enum.Font.GothamBold
cooldownLabel.TextSize = 11
cooldownLabel.TextColor3 = theme.Muted
cooldownLabel.TextXAlignment = Enum.TextXAlignment.Right
cooldownLabel.Text = ""
cooldownLabel.Parent = header

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.fromOffset(10, headerHeight)
divider.BackgroundColor3 = theme.Stroke
divider.BorderSizePixel = 0
divider.Parent = mainFrame

local tabsHolder = Instance.new("Frame")
tabsHolder.BackgroundTransparency = 1
tabsHolder.Position = UDim2.fromOffset(10, headerHeight + 1 + 8)
tabsHolder.Size = UDim2.new(1, -20, 0, tabHeight)
tabsHolder.Parent = mainFrame

local tabButtons = {}

local function makeTab(key, text, scaleX, offsetX)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.5, -3, 1, 0)
    button.Position = UDim2.new(scaleX, offsetX, 0, 0)
    button.BackgroundColor3 = theme.Surface
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.Text = text
    button.TextColor3 = theme.Muted
    button.AutoButtonColor = false
    button.Parent = tabsHolder
    addCorner(button, 7)
    addStroke(button, theme.Stroke)
    tabButtons[key] = button
    return button
end

local settingsTab = makeTab("settings", "Settings", 0, 0)
local configsTab = makeTab("configs", "Configs", 0.5, 3)

local function makePage(scrolling)
    local page
    if scrolling then
        page = Instance.new("ScrollingFrame")
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = theme.Stroke
        page.VerticalScrollBarInset = Enum.ScrollBarInset.None
        page.ScrollingDirection = Enum.ScrollingDirection.Y
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.CanvasSize = UDim2.new()
    else
        page = Instance.new("Frame")
    end
    page.Position = UDim2.fromOffset(0, contentTop)
    page.Size = UDim2.new(1, 0, 1, -contentTop)
    page.BackgroundTransparency = 1
    page.Parent = mainFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 10)
    padding.Parent = page
    return page
end

local settingsPage = makePage(true)
local configsPage = makePage()
configsPage.Visible = false

local minimized = false
local currentTab = "settings"

local function switchTab(name)
    currentTab = name
    settingsPage.Visible = name == "settings" and not minimized
    configsPage.Visible = name == "configs" and not minimized
    for key, button in pairs(tabButtons) do
        local active = key == name
        button.TextColor3 = active and theme.Text or theme.Muted
        button.BackgroundColor3 = active and theme.SurfaceHover or theme.Surface
    end
end

table.insert(uiConnections, settingsTab.MouseButton1Click:Connect(function()
    switchTab("settings")
end))
table.insert(uiConnections, configsTab.MouseButton1Click:Connect(function()
    switchTab("configs")
end))

local refreshers = {}

local function makeToggle(label, getter, setter)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundColor3 = theme.Surface
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = settingsPage
    addCorner(row, 8)
    addStroke(row, theme.Stroke)

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(12, 0)
    text.Size = UDim2.new(1, -64, 1, 0)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 12
    text.TextColor3 = theme.Text
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Text = label
    text.TextTruncate = Enum.TextTruncate.AtEnd
    text.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(34, 18)
    track.Position = UDim2.new(1, -46, 0.5, -9)
    track.BorderSizePixel = 0
    track.Parent = row
    addCorner(track, 9)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 7)

    local function refresh(animate)
        local on = getter()
        local color = on and theme.Accent or theme.Off
        local position = on and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)
        if animate then
            local info = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            tweenService:Create(track, info, {BackgroundColor3 = color}):Play()
            tweenService:Create(knob, info, {Position = position}):Play()
        else
            track.BackgroundColor3 = color
            knob.Position = position
        end
    end

    refresh(false)
    table.insert(refreshers, function()
        refresh(false)
    end)
    table.insert(uiConnections, row.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh(true)
    end))
    table.insert(uiConnections, row.MouseEnter:Connect(function()
        row.BackgroundColor3 = theme.SurfaceHover
    end))
    table.insert(uiConnections, row.MouseLeave:Connect(function()
        row.BackgroundColor3 = theme.Surface
    end))
end

local function makeSlider(label, minValue, maxValue, getter, setter, step, formatter)
    step = step or 1

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 46)
    row.BackgroundColor3 = theme.Surface
    row.BorderSizePixel = 0
    row.Parent = settingsPage
    addCorner(row, 8)
    addStroke(row, theme.Stroke)

    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Position = UDim2.fromOffset(12, 5)
    text.Size = UDim2.new(1, -90, 0, 20)
    text.Font = Enum.Font.GothamMedium
    text.TextSize = 12
    text.TextColor3 = theme.Text
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Text = label
    text.Parent = row

    local valueBox = Instance.new("TextBox")
    valueBox.BackgroundColor3 = theme.Bg
    valueBox.BorderSizePixel = 0
    valueBox.Position = UDim2.new(1, -74, 0, 5)
    valueBox.Size = UDim2.fromOffset(62, 20)
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextSize = 12
    valueBox.TextColor3 = theme.Muted
    valueBox.TextXAlignment = Enum.TextXAlignment.Center
    valueBox.ClearTextOnFocus = true
    valueBox.Parent = row
    addCorner(valueBox, 6)
    local valueStroke = addStroke(valueBox, theme.Stroke)

    local hitArea = Instance.new("TextButton")
    hitArea.Size = UDim2.new(1, -24, 0, 20)
    hitArea.Position = UDim2.fromOffset(12, 25)
    hitArea.BackgroundTransparency = 1
    hitArea.Text = ""
    hitArea.AutoButtonColor = false
    hitArea.Parent = row

    local rail = Instance.new("Frame")
    rail.Size = UDim2.new(1, 0, 0, 4)
    rail.Position = UDim2.new(0, 0, 0.5, -2)
    rail.BackgroundColor3 = theme.Off
    rail.BorderSizePixel = 0
    rail.Parent = hitArea
    addCorner(rail, 2)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = rail
    addCorner(fill, 2)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.fromRGB(245, 245, 248)
    knob.BorderSizePixel = 0
    knob.Parent = hitArea
    addCorner(knob, 7)

    local function refresh()
        local value = getter()
        local alpha = math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        valueBox.Text = (formatter and formatter(value)) or tostring(value)
    end

    refresh()
    table.insert(refreshers, refresh)

    table.insert(uiConnections, valueBox.Focused:Connect(function()
        valueStroke.Color = theme.Accent
        valueBox.TextColor3 = theme.Text
    end))
    table.insert(uiConnections, valueBox.FocusLost:Connect(function()
        valueStroke.Color = theme.Stroke
        valueBox.TextColor3 = theme.Muted
        local cleaned = valueBox.Text:gsub(",", "."):gsub("[^%d%.]", "")
        local number = tonumber(cleaned)
        if number then
            local snapped = minValue + math.floor((number - minValue) / step + 0.5) * step
            setter(math.clamp(math.floor(snapped * 1000 + 0.5) / 1000, minValue, maxValue))
        end
        refresh()
    end))

    local function updateFromInput(input)
        local width = hitArea.AbsoluteSize.X
        if width <= 0 then
            return
        end
        local alpha = math.clamp((input.Position.X - hitArea.AbsolutePosition.X) / width, 0, 1)
        local raw = minValue + (maxValue - minValue) * alpha
        local snapped = minValue + math.floor((raw - minValue) / step + 0.5) * step
        setter(math.clamp(math.floor(snapped * 1000 + 0.5) / 1000, minValue, maxValue))
        refresh()
    end

    local dragging = false
    table.insert(uiConnections, hitArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            settingsPage.ScrollingEnabled = false
            updateFromInput(input)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    settingsPage.ScrollingEnabled = true
                end
            end)
        end
    end))
    table.insert(uiConnections, userInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateFromInput(input)
        end
    end))
end

makeToggle("Konta Tech", function()
    return settings.Enabled
end, function(value)
    settings.Enabled = value
    if not value then
        dashPending = false
        windowEnd = 0
        if stopTech then
            pcall(stopTech)
        end
    end
end)

makeToggle("Dash Cooldown", function()
    return settings.CooldownEnabled
end, function(value)
    settings.CooldownEnabled = value
end)

local function addSecondsSlider(label, key, step, decimals)
    local range = limits[key]
    local format = "%." .. decimals .. "fs"
    makeSlider(label, range[1], range[2], function()
        return settings[key]
    end, function(value)
        settings[key] = value
    end, step, function(value)
        return string.format(format, value)
    end)
end

addSecondsSlider("Dash Delay", "DashDelay", 0.001, 3)
addSecondsSlider("Stun Delay", "StunDelay", 0.01, 2)
addSecondsSlider("Stun Duration", "StunDuration", 0.01, 2)

makeToggle("Spin During Konta Tech", function()
    return settings.Spin
end, function(value)
    settings.Spin = value
end)

addSecondsSlider("Spin Delay", "SpinDelay", 0.01, 2)
addSecondsSlider("Spin Duration", "SpinDuration", 0.01, 2)

makeSlider("Spin Speed", limits.SpinSpeed[1], limits.SpinSpeed[2], function()
    return settings.SpinSpeed
end, function(value)
    settings.SpinSpeed = value
end)

local maxSlots = 5
local namesFile = "KontaTech_ConfigNames.json"

local schema = {
    {key = "Enabled", kind = "boolean"},
    {key = "CooldownEnabled", kind = "boolean"},
    {key = "Spin", kind = "boolean"},
}
for _, key in ipairs({"DashDelay", "StunDelay", "StunDuration", "SpinDelay", "SpinDuration", "SpinSpeed"}) do
    schema[#schema + 1] = {key = key, kind = "number", min = limits[key][1], max = limits[key][2]}
end

local function slotFile(slot)
    return "KontaTech_Config" .. slot .. ".json"
end

local function readSlot(slot)
    local ok, data = pcall(function()
        return httpService:JSONDecode(readfile(slotFile(slot)))
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local customNames = {}
do
    local ok, data = pcall(function()
        return httpService:JSONDecode(readfile(namesFile))
    end)
    if ok and type(data) == "table" then
        for slot = 1, maxSlots do
            local name = data[tostring(slot)]
            if type(name) == "string" and name ~= "" then
                customNames[slot] = name
            end
        end
    end
end

local function saveNames()
    local out = {}
    for slot = 1, maxSlots do
        if customNames[slot] then
            out[tostring(slot)] = customNames[slot]
        end
    end
    pcall(function()
        writefile(namesFile, httpService:JSONEncode(out))
    end)
end

local function commitName(slot, text)
    local trimmed = tostring(text):match("^%s*(.-)%s*$")
    local default = "Config " .. slot
    if trimmed == "" or trimmed == default then
        customNames[slot] = nil
        trimmed = default
    else
        customNames[slot] = trimmed
    end
    saveNames()
    return trimmed
end

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 16)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = theme.Accent
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 10
statusLabel.LayoutOrder = 100
statusLabel.Parent = configsPage

local statusToken = 0
local function showStatus(text)
    statusToken = statusToken + 1
    local token = statusToken
    statusLabel.Text = text
    task.delay(2, function()
        if token == statusToken and statusLabel.Parent then
            statusLabel.Text = ""
        end
    end)
end

local function refreshWidgets()
    for _, refresh in ipairs(refreshers) do
        refresh()
    end
end

local function applyConfig(data)
    local applied = 0
    for _, entry in ipairs(schema) do
        local value = data[entry.key]
        if entry.kind == "boolean" then
            if type(value) == "string" then
                local lowered = value:lower()
                if lowered == "true" then
                    value = true
                elseif lowered == "false" then
                    value = false
                end
            end
            if type(value) == "boolean" then
                settings[entry.key] = value
                applied = applied + 1
            end
        elseif entry.kind == "number" then
            if type(value) == "string" then
                value = tonumber(value)
            end
            if type(value) == "number" then
                settings[entry.key] = math.clamp(value, entry.min, entry.max)
                applied = applied + 1
            end
        end
    end
    if not settings.Enabled then
        dashPending = false
        windowEnd = 0
        if stopTech then
            pcall(stopTech)
        end
    end
    refreshWidgets()
    return applied
end

local pasteRow = Instance.new("Frame")
pasteRow.Size = UDim2.new(1, 0, 0, 30)
pasteRow.BackgroundTransparency = 1
pasteRow.LayoutOrder = 50
pasteRow.Parent = configsPage

local pasteBox = Instance.new("TextBox")
pasteBox.Size = UDim2.new(1, -92, 1, 0)
pasteBox.BackgroundColor3 = theme.Surface
pasteBox.TextColor3 = theme.Text
pasteBox.PlaceholderColor3 = theme.Muted
pasteBox.PlaceholderText = "Paste config here"
pasteBox.Text = ""
pasteBox.Font = Enum.Font.GothamMedium
pasteBox.TextSize = 10
pasteBox.TextXAlignment = Enum.TextXAlignment.Left
pasteBox.ClearTextOnFocus = false
pasteBox.TextTruncate = Enum.TextTruncate.AtEnd
pasteBox.Parent = pasteRow
addCorner(pasteBox, 7)
local pasteStroke = addStroke(pasteBox, theme.Stroke)

local pastePadding = Instance.new("UIPadding")
pastePadding.PaddingLeft = UDim.new(0, 10)
pastePadding.PaddingRight = UDim.new(0, 6)
pastePadding.Parent = pasteBox

table.insert(uiConnections, pasteBox.Focused:Connect(function()
    pasteStroke.Color = theme.Accent
end))
table.insert(uiConnections, pasteBox.FocusLost:Connect(function()
    pasteStroke.Color = theme.Stroke
end))

local tryButton = Instance.new("TextButton")
tryButton.Size = UDim2.new(0, 86, 1, 0)
tryButton.Position = UDim2.new(1, -86, 0, 0)
tryButton.BackgroundColor3 = theme.Surface
tryButton.TextColor3 = theme.Accent
tryButton.Font = Enum.Font.GothamBold
tryButton.TextSize = 10
tryButton.Text = "Try Config"
tryButton.AutoButtonColor = false
tryButton.Parent = pasteRow
addCorner(tryButton, 7)
addStroke(tryButton, theme.Stroke)

table.insert(uiConnections, tryButton.MouseEnter:Connect(function()
    tryButton.BackgroundColor3 = theme.SurfaceHover
end))
table.insert(uiConnections, tryButton.MouseLeave:Connect(function()
    tryButton.BackgroundColor3 = theme.Surface
end))
table.insert(uiConnections, tryButton.MouseButton1Click:Connect(function()
    local text = tostring(pasteBox.Text)
    text = text:gsub("“", '"'):gsub("”", '"'):gsub("‘", "'"):gsub("’", "'")
    text = text:match("^%s*(.-)%s*$")
    if text == "" then
        showStatus("Paste a config first")
        return
    end
    if text:sub(1, 1) ~= "{" then
        text = "{" .. text .. "}"
    end
    local ok, data = pcall(function()
        return httpService:JSONDecode(text)
    end)
    if not ok or type(data) ~= "table" then
        showStatus("Invalid config")
        return
    end
    if applyConfig(data) == 0 then
        showStatus("Nothing to apply")
        return
    end
    local name = (type(data.ConfigName) == "string" and data.ConfigName ~= "" and data.ConfigName) or "Config"
    showStatus(name .. " applied")
end))

for slot = 1, maxSlots do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder = slot
    row.Parent = configsPage

    local nameBox = Instance.new("TextBox")
    nameBox.Size = UDim2.new(1, -136, 1, 0)
    nameBox.BackgroundColor3 = theme.Surface
    nameBox.TextColor3 = theme.Text
    nameBox.PlaceholderColor3 = theme.Muted
    nameBox.Font = Enum.Font.GothamMedium
    nameBox.TextSize = 10
    nameBox.TextXAlignment = Enum.TextXAlignment.Left
    nameBox.ClearTextOnFocus = false
    nameBox.TextTruncate = Enum.TextTruncate.AtEnd
    nameBox.PlaceholderText = "Config " .. slot
    nameBox.Text = "Config " .. slot
    nameBox.Parent = row
    addCorner(nameBox, 7)
    local nameStroke = addStroke(nameBox, theme.Stroke)

    local namePadding = Instance.new("UIPadding")
    namePadding.PaddingLeft = UDim.new(0, 10)
    namePadding.PaddingRight = UDim.new(0, 6)
    namePadding.Parent = nameBox

    table.insert(uiConnections, nameBox.Focused:Connect(function()
        nameStroke.Color = theme.Accent
    end))
    table.insert(uiConnections, nameBox.FocusLost:Connect(function()
        nameStroke.Color = theme.Stroke
        nameBox.Text = commitName(slot, nameBox.Text)
    end))
    table.insert(uiConnections, nameBox:GetPropertyChangedSignal("Text"):Connect(function()
        if not nameBox:IsFocused() then
            return
        end
        local trimmed = tostring(nameBox.Text):match("^%s*(.-)%s*$")
        if trimmed == "" or trimmed == "Config " .. slot then
            customNames[slot] = nil
        else
            customNames[slot] = trimmed
        end
        saveNames()
    end))

    if customNames[slot] then
        nameBox.Text = customNames[slot]
    else
        local data = readSlot(slot)
        if data and type(data.ConfigName) == "string" and data.ConfigName ~= "" then
            nameBox.Text = data.ConfigName
            customNames[slot] = data.ConfigName
        end
    end

    local function makeSlotButton(text, offsetX, color)
        local button = Instance.new("TextButton")
        button.Text = text
        button.Size = UDim2.new(0, 42, 1, 0)
        button.Position = UDim2.new(1, offsetX, 0, 0)
        button.BackgroundColor3 = theme.Surface
        button.TextColor3 = color
        button.Font = Enum.Font.GothamBold
        button.TextSize = 10
        button.AutoButtonColor = false
        button.Parent = row
        addCorner(button, 7)
        addStroke(button, theme.Stroke)
        table.insert(uiConnections, button.MouseEnter:Connect(function()
            button.BackgroundColor3 = theme.SurfaceHover
        end))
        table.insert(uiConnections, button.MouseLeave:Connect(function()
            button.BackgroundColor3 = theme.Surface
        end))
        return button
    end

    local saveButton = makeSlotButton("Save", -130, theme.Accent)
    local loadButton = makeSlotButton("Load", -86, theme.Text)
    local deleteButton = makeSlotButton("Delete", -42, theme.Danger)

    table.insert(uiConnections, saveButton.MouseButton1Click:Connect(function()
        local name = commitName(slot, nameBox.Text)
        nameBox.Text = name
        local data = {ConfigName = name}
        for _, entry in ipairs(schema) do
            data[entry.key] = settings[entry.key]
        end
        local ok = pcall(function()
            writefile(slotFile(slot), httpService:JSONEncode(data))
        end)
        showStatus(ok and "Config saved" or "Save failed")
    end))

    table.insert(uiConnections, loadButton.MouseButton1Click:Connect(function()
        local data = readSlot(slot)
        if not data then
            showStatus("No saved config")
            return
        end
        applyConfig(data)
        if not customNames[slot] and type(data.ConfigName) == "string" and data.ConfigName ~= "" then
            customNames[slot] = data.ConfigName
            nameBox.Text = data.ConfigName
            saveNames()
        end
        showStatus("Config loaded")
    end))

    local deleteToken = 0
    local deleteArmed = false
    table.insert(uiConnections, deleteButton.MouseButton1Click:Connect(function()
        if not deleteArmed then
            deleteArmed = true
            deleteToken = deleteToken + 1
            local token = deleteToken
            deleteButton.Text = "Sure?"
            task.delay(2, function()
                if token == deleteToken and deleteArmed and deleteButton.Parent then
                    deleteArmed = false
                    deleteButton.Text = "Delete"
                end
            end)
            return
        end
        deleteArmed = false
        deleteToken = deleteToken + 1
        deleteButton.Text = "Delete"
        local hasFile = readSlot(slot) ~= nil
        local hasName = customNames[slot] ~= nil
        if not hasFile and not hasName then
            showStatus("No saved config")
            return
        end
        local ok = true
        if hasFile then
            ok = pcall(function()
                delfile(slotFile(slot))
            end)
        end
        if ok then
            customNames[slot] = nil
            saveNames()
            nameBox.Text = "Config " .. slot
            showStatus("Config deleted")
        else
            showStatus("Delete failed")
        end
    end))
end

switchTab("settings")

table.insert(uiConnections, runService.Heartbeat:Connect(function()
    local remaining = settings.DashCooldown - (os.clock() - lastDashTime)
    if settings.CooldownEnabled and remaining > 0 and not workspace:GetAttribute("NoDashCooldown") then
        cooldownLabel.Text = string.format("%.1fs", remaining)
    elseif cooldownLabel.Text ~= "" then
        cooldownLabel.Text = ""
    end
end))

table.insert(uiConnections, minimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    tabsHolder.Visible = not minimized
    divider.Visible = not minimized
    switchTab(currentTab)
    minimizeButton.Text = minimized and "+" or "–"
    local info = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    tweenService:Create(mainFrame, info, {
        Size = UDim2.fromOffset(windowWidth, minimized and headerHeight or windowHeight),
    }):Play()
end))

local lastCloseTap = 0
table.insert(uiConnections, closeButton.MouseButton1Click:Connect(function()
    local now = os.clock()
    if now - lastCloseTap < 2 then
        cleanup()
        return
    end
    lastCloseTap = now
    closeButton.TextColor3 = theme.Accent
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title = "Konta Tech",
            Text = "Tap close again to close the UI",
            Duration = 2,
        })
    end)
    task.delay(2, function()
        if closeButton.Parent and os.clock() - lastCloseTap >= 2 then
            closeButton.TextColor3 = theme.Muted
        end
    end)
end))

local windowDragging = false
local dragStart = nil
local dragOrigin = nil
table.insert(uiConnections, header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        windowDragging = true
        dragStart = input.Position
        dragOrigin = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                windowDragging = false
            end
        end)
    end
end))
table.insert(uiConnections, userInputService.InputChanged:Connect(function(input)
    if not windowDragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset + delta.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset + delta.Y
        )
    end
end))

table.insert(uiConnections, localPlayer.CharacterAdded:Connect(function(character)
    task.spawn(onCharacter, character)
end))
if localPlayer.Character then
    task.spawn(onCharacter, localPlayer.Character)
end