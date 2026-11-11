local env = (getgenv and getgenv()) or _G
if env.HookDash and env.HookDash.Stop then
    pcall(env.HookDash.Stop)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
while not player do
    task.wait()
    player = Players.LocalPlayer
end
local mouse = player:GetMouse()

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local GUI_URL = ""

local Config = {
    Enabled = true,
    PCMode = true,
    MobileMode = true,
    Distance = 35,
    Range = 2,
    Cooldown = 1,
    Delay = 0.11,
    Smoothness = 0.4,
    Prediction = 0.3,
    Reach = 6.5,
    Duration = 0.15,
    Show = true,
    Color = Color3.fromRGB(173, 216, 230),
    SelectKey = Enum.KeyCode.V,
    DashKey = Enum.KeyCode.C,
    FakeMobile = false,
    StartLocked = false,
    TapMaxMove = 12,
    TapMaxTime = 0.35,
    MaxSelfY = 442,
    MaxTargetY = 448,
    AimY = 438,
    Debug = false,
}

local function dbg(text)
    if Config.Debug then
        warn("[HookDash] " .. tostring(text))
    end
end

local reported = {}
local function safeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[name] then
        reported[name] = true
        dbg(name .. " error: " .. tostring(err))
    end
end

local ANIM_A = "rbxassetid://10480796021"
local ANIM_D = "rbxassetid://10480793962"

local target = nil
local canDash = true
local dashing = false
local canAnim = true
local lastTap = 0
local touchStarts = {}
local mobileGui = nil
local mobileBtn = nil
local lockBtn = nil
local buttonLocked = false
local menuGui = nil
local listeningKey = nil
local dashLV, dashAtt = nil, nil
local stopped = false
local Stop

local connections = {}
local function track(conn)
    connections[conn] = true
    return conn
end
local function drop(conn)
    if conn then
        conn:Disconnect()
        connections[conn] = nil
    end
end

local function getDummy()
    local live = Workspace:FindFirstChild("Live")
    return live and live:FindFirstChild("Weakest Dummy")
end

local function modelOf(t)
    if not t then
        return nil
    end
    if t:IsA("Model") then
        return t
    end
    return t.Character
end

local function rootOf(t)
    local m = modelOf(t)
    return m and m:FindFirstChild("HumanoidRootPart")
end

local function removeHighlight(model)
    if not model then
        return
    end
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("Highlight") and d.Name == "HookDashHighlight" then
            d:Destroy()
        end
    end
end

local function addHighlight(model)
    if not model or not Config.Show then
        return
    end
    local h = Instance.new("Highlight")
    h.Name = "HookDashHighlight"
    h.OutlineColor = Config.Color
    h.FillColor = Config.Color
    h.FillTransparency = 0.8
    h.OutlineTransparency = 0.3
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = model
end

local function refreshHighlight()
    if target then
        local m = modelOf(target)
        removeHighlight(m)
        addHighlight(m)
    end
end

local function clearTarget()
    if target then
        removeHighlight(modelOf(target))
        target = nil
    end
end

local function toggleTarget(t)
    if not t or t == target then
        clearTarget()
        dbg("target cleared")
        return
    end
    clearTarget()
    target = t
    addHighlight(modelOf(t))
    local m = modelOf(t)
    dbg("target: " .. tostring(m and m.Name))
end

local function pickNearestToMouse()
    local hitPos = mouse.Hit.Position
    local best, bestMag = nil, math.huge

    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= player then
            local hrp = rootOf(pl)
            if hrp then
                local mag = (hrp.Position - hitPos).Magnitude
                if mag < bestMag then
                    best, bestMag = pl, mag
                end
            end
        end
    end

    local dummy = getDummy()
    local dummyHRP = dummy and dummy:FindFirstChild("HumanoidRootPart")
    if dummyHRP and (dummyHRP.Position - hitPos).Magnitude < bestMag then
        best = dummy
    end

    toggleTarget(best)
end

local function pickFromScreen(pos)
    local cam = Workspace.CurrentCamera
    local ray = cam:ScreenPointToRay(pos.X, pos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {player.Character}

    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if not hit then
        clearTarget()
        return
    end

    local model = hit.Instance:FindFirstAncestorOfClass("Model")
    local dummy = getDummy()
    local selected = model and (Players:GetPlayerFromCharacter(model) or (model == dummy and dummy or nil))
    if selected then
        toggleTarget(selected)
    end
end

local function fireDash()
    local char = player.Character
    local remote = char and char:FindFirstChild("Communicate")
    if remote then
        remote:FireServer({
            Dash = Enum.KeyCode.A,
            Key = Enum.KeyCode.Q,
            Goal = "KeyPress",
        })
    else
        dbg("character has no Communicate")
    end
end

local function leftClick()
    local char = player.Character
    local remote = char and char:FindFirstChild("Communicate")
    if not remote then
        dbg("no Communicate (M1)")
        return
    end
    remote:FireServer({Goal = "KeyRelease", Key = Enum.KeyCode.F})
    remote:FireServer({Mobile = true, Goal = "LeftClick"})
    remote:FireServer({Mobile = true, Goal = "LeftClickRelease"})
end

local function stopDash()
    if dashLV then
        dashLV.VectorVelocity = Vector3.zero
        dashLV:Destroy()
        dashLV = nil
    end
    if dashAtt then
        dashAtt:Destroy()
        dashAtt = nil
    end
end

local function setDashVelocity(hrp, goal, duration)
    if not dashAtt or not dashAtt.Parent then
        dashAtt = Instance.new("Attachment")
        dashAtt.Parent = hrp
    end
    if not dashLV or not dashLV.Parent then
        dashLV = Instance.new("LinearVelocity")
        dashLV.Attachment0 = dashAtt
        dashLV.MaxForce = math.huge
        dashLV.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        dashLV.RelativeTo = Enum.ActuatorRelativeTo.World
        dashLV.Parent = hrp
    end

    local flat = Vector3.new(goal.X, hrp.Position.Y, goal.Z)
    local v = (flat - hrp.Position) / math.max(duration, 0.01)
    dashLV.VectorVelocity = Vector3.new(v.X, 0, v.Z)
end

local function playAnim(id)
    if not canAnim then
        return
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    canAnim = false

    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    animator:LoadAnimation(anim):Play()
end

local function silentAim(t, sign)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local model = modelOf(t)
    local arm = model and model:FindFirstChild("Right Arm")
    if not (hrp and arm) then
        return
    end

    local dir = arm.Position - hrp.Position
    local rotated = CFrame.fromAxisAngle(Vector3.new(0, sign, 0), math.rad(140)) * dir
    local aimPoint = arm.Position + rotated
    local look = Vector3.new(aimPoint.X, hrp.Position.Y, aimPoint.Z)
    hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(hrp.Position, look), Config.Smoothness)
end

local function aimlock(t)
    local hrp = rootOf(t)
    local cam = Workspace.CurrentCamera
    if not hrp or not cam then
        return
    end
    local lookAt = Vector3.new(hrp.Position.X, Config.AimY, hrp.Position.Z)
    cam.CFrame = CFrame.new(cam.CFrame.Position, lookAt)
end

local function rightIsCloser(tHRP, hrp)
    local r = tHRP.CFrame.RightVector * Config.Range
    return (tHRP.Position + r - hrp.Position).Magnitude < (tHRP.Position - r - hrp.Position).Magnitude
end

local function performDash()
    if not Config.Enabled then
        return
    end
    local t = target
    if not t then
        dbg("no target: tap a player first")
        return
    end
    if not canDash then
        dbg("cooldown")
        return
    end

    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local tHRP = rootOf(t)
    if not (hrp and hum and tHRP) then
        dbg("no character or target")
        return
    end

    if hrp.Position.Y > Config.MaxSelfY or tHRP.Position.Y > Config.MaxTargetY then
        dbg(string.format("height: you %.0f, target %.0f (limit %.0f / %.0f)",
            hrp.Position.Y, tHRP.Position.Y, Config.MaxSelfY, Config.MaxTargetY))
        return
    end
    local dist = (tHRP.Position - hrp.Position).Magnitude
    if dist > Config.Distance then
        dbg(string.format("too far: %.0f > %.0f", dist, Config.Distance))
        return
    end

    canDash = false
    dashing = true
    fireDash()
    dbg("dash sent")

    task.delay(Config.Duration, function()
        dashing = false
        stopDash()
        canAnim = true
        if stopped then
            return
        end

        local t0 = os.clock()
        local lockConn
        lockConn = track(RunService.Stepped:Connect(function()
            if os.clock() - t0 > 0.5 or target ~= t then
                drop(lockConn)
                return
            end
            aimlock(t)
        end))

        task.wait(Config.Cooldown)
        canDash = true
    end)

    task.delay(Config.Delay, function()
        if not stopped then
            leftClick()
        end
    end)

    local direction = (tHRP.Position - hrp.Position).Unit
    local forward = tHRP.CFrame.LookVector
    local flatDir = Vector3.new(direction.X, 0, direction.Z).Unit
    local jok = Vector3.new(flatDir.Z, 0, -flatDir.X)
    local jok2 = Vector3.new(-flatDir.Z, 0, flatDir.X)
    local des1 = ((tHRP.Position + jok * Config.Range) - hrp.Position).Unit
    local des70 = ((tHRP.Position + jok2 * Config.Range) - hrp.Position).Unit

    local facing = forward:Dot(direction)
    local sign
    if rightIsCloser(tHRP, hrp) == (facing < 0) then
        playAnim(ANIM_A)
        sign = -1
    else
        playAnim(ANIM_D)
        sign = 1
    end

    hum.AutoRotate = false

    local silentConn
    silentConn = track(RunService.Stepped:Connect(function()
        if not dashing then
            drop(silentConn)
            return
        end
        silentAim(t, sign)
    end))

    local loop
    loop = track(RunService.Heartbeat:Connect(function()
        if not dashing then
            drop(loop)
            return
        end

        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root or not tHRP.Parent then
            drop(loop)
            stopDash()
            return
        end

        local pred = tHRP.AssemblyLinearVelocity * Config.Prediction
        local goalA = tHRP.Position + jok * Config.Range + pred + des1 * Config.Reach
        local goalB = tHRP.Position + jok2 * Config.Range + pred + des70 * Config.Reach
        local goal = rightIsCloser(tHRP, root) and goalA or goalB

        setDashVelocity(root, goal, Config.Duration)
    end))
end

local function mountGui(gui)
    local getters = {}
    if type(gethui) == "function" then
        table.insert(getters, function()
            return gethui()
        end)
    end
    table.insert(getters, function()
        return game:GetService("CoreGui")
    end)
    table.insert(getters, function()
        return player:WaitForChild("PlayerGui", 10)
    end)

    for _, get in ipairs(getters) do
        local ok, parent = pcall(get)
        if ok and parent then
            local set = pcall(function()
                gui.Parent = parent
            end)
            if set and gui.Parent == parent then
                return true
            end
        end
    end
    return false
end

local function refreshLock()
    if mobileBtn then
        mobileBtn.Draggable = not buttonLocked
    end
    if lockBtn then
        lockBtn.Text = buttonLocked and "🔒" or "🔓"
    end
end

local function createMobileButton()
    if mobileGui then
        return
    end
    mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "HookDashUI"
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mobileGui.DisplayOrder = 999
    if not mountGui(mobileGui) then
        dbg("GUI: could not find a place for the button")
    end

    local btn = Instance.new("ImageButton")
    btn.Position = UDim2.new(0.9, 0, 0.8, 0)
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    btn.BackgroundTransparency = 0.3
    btn.Image = "rbxassetid://12443244342"
    btn.ImageColor3 = Color3.fromRGB(255, 0, 0)
    buttonLocked = Config.StartLocked
    btn.Active = true
    btn.Selectable = true
    btn.Parent = mobileGui
    mobileBtn = btn
    btn.MouseButton1Click:Connect(function()
        safeCall("Dash", performDash)
    end)

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local lock = Instance.new("TextButton")
    lock.Name = "Lock"
    lock.Size = UDim2.new(0, 22, 0, 22)
    lock.Position = UDim2.new(1, -22, 0, -26)
    lock.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
    lock.BackgroundTransparency = 0.3
    lock.TextColor3 = Color3.fromRGB(255, 255, 255)
    lock.TextSize = 12
    lock.Text = ""
    lock.Parent = btn
    lockBtn = lock

    local lockCorner = Instance.new("UICorner")
    lockCorner.CornerRadius = UDim.new(0, 6)
    lockCorner.Parent = lock

    lock.MouseButton1Click:Connect(function()
        buttonLocked = not buttonLocked
        refreshLock()
    end)

    refreshLock()
end

local function destroyMobileButton()
    if mobileGui then
        mobileGui:Destroy()
        mobileGui = nil
    end
    mobileBtn = nil
    lockBtn = nil
end

local function syncMobileButton()
    if stopped then
        return
    end
    if Config.MobileMode then
        local ok, err = pcall(createMobileButton)
        dbg(ok and "GUI ready" or ("GUI error: " .. tostring(err)))
    else
        destroyMobileButton()
    end
end

track(Players.PlayerRemoving:Connect(function(pl)
    if target == pl then
        clearTarget()
    end
end))

track(RunService.Heartbeat:Connect(function()
    if not target then
        return
    end
    local model = modelOf(target)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then
        clearTarget()
    end
end))

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if listeningKey then
        return
    end

    if gameProcessed or not Config.Enabled then
        return
    end

    if input.UserInputType == Enum.UserInputType.Touch then
        if Config.MobileMode then
            touchStarts[input] = {
                pos = Vector2.new(input.Position.X, input.Position.Y),
                time = os.clock(),
            }
        end
    elseif input.UserInputType == Enum.UserInputType.Keyboard then
        if not Config.PCMode then
            return
        end
        if input.KeyCode == Config.SelectKey then
            safeCall("Select", pickNearestToMouse)
        elseif input.KeyCode == Config.DashKey then
            safeCall("Dash", performDash)
        end
    end
end))

track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    local start = touchStarts[input]
    touchStarts[input] = nil
    if not start or not Config.Enabled or not Config.MobileMode then
        return
    end

    local endPos = Vector2.new(input.Position.X, input.Position.Y)
    if (endPos - start.pos).Magnitude <= Config.TapMaxMove
        and os.clock() - start.time <= Config.TapMaxTime then
        safeCall("Select", pickFromScreen, endPos)
    end
end))

track(mouse.Button1Down:Connect(function()
    if not (Config.FakeMobile and Config.Enabled) then
        return
    end
    if os.clock() - lastTap < 0.3 then
        safeCall("Select", pickFromScreen, Vector2.new(mouse.X, mouse.Y))
    end
    lastTap = os.clock()
end))

dbg("loaded")
syncMobileButton()

local guiApi = {
    mountGui = mountGui,
    clearTarget = clearTarget,
    refreshHighlight = refreshHighlight,
    syncMobileButton = syncMobileButton,
    setListening = function(key)
        listeningKey = key
    end,
    onClose = function()
        Stop()
    end,
}

local function loadGui()
    if GUI_URL == "" then
        warn("[HookDash] GUI_URL is empty: set the raw hookDashGui link")
        return
    end

    local loaded, factory = pcall(function()
        return loadstring(game:HttpGet(GUI_URL))()
    end)
    if not loaded or type(factory) ~= "function" then
        warn("[HookDash] gui load failed: " .. tostring(factory))
        return
    end

    local built, result = pcall(factory, Config, guiApi)
    if built then
        menuGui = result
    else
        warn("[HookDash] gui error: " .. tostring(result))
    end
end

loadGui()

function Stop()
    stopped = true
    dashing = false
    listeningKey = nil
    for conn in pairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    touchStarts = {}
    clearTarget()
    stopDash()

    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.AutoRotate = true
    end
    destroyMobileButton()
    if menuGui then
        menuGui:Destroy()
        menuGui = nil
    end
    if env.HookDash and env.HookDash.Stop == Stop then
        env.HookDash = nil
    end
end

env.HookDash = {Config = Config, Stop = Stop}