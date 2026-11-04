-- | Magnet by Techinified | --

-- | Services | --
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local workspaceService = game:GetService("Workspace")

local hasVirtualInput, virtualInputManager = pcall(function()
    return game:GetService("VirtualInputManager")
end)
if not hasVirtualInput then
    virtualInputManager = nil
end

local localPlayer = players.LocalPlayer

-- | Re-execute cleanup | --
local env = (getgenv and getgenv()) or _G
if env.MagnetTechinifiedUnload then
    pcall(env.MagnetTechinifiedUnload)
end

-- | Constants | --
local DASH_ANIMATION_IDS = { "10479335397", "13380255751" }
local UPPERCUT_ANIMATION_ID = "10503381238"
local DASH_DETECT_OFFSET = 0.05
local MAGNET_RANGE = 6
local PULL_STRENGTH = 50
local PULL_SMOOTHNESS = 0.65
local NPC_REFRESH_RATE = 0.5
local CANCEL_RANGE = 2.2
local CANCEL_TIMEOUT = 1.5

-- | Settings | --
local settings = {
    enabled = true,
    dashDelay = 0.20, 
    magnetDelay = 0.24,
    magnetDuration = 0.20,
    cancelDelay = 0.55
}

-- | State | --
local character
local rootPart
local humanoid
local dashVelocity = nil
local screenGui = nil

local pullConnection = nil
local cancelConnection = nil
local animConnection = nil
local childAddedConnection = nil
local connections = {}

local sequenceId = 0
local dashPending = false
local magnetPending = false

local npcList = {}
local lastNpcUpdate = 0

-- | NPC Cache | --
local function updateNpcCache()
    npcList = {}
    if not rootPart then return end

    for _, model in ipairs(workspaceService:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
            local root = model.HumanoidRootPart
            if root ~= rootPart then
                table.insert(npcList, root)
            end
        end
    end
end

table.insert(connections, runService.Heartbeat:Connect(function()
    if os.clock() - lastNpcUpdate > NPC_REFRESH_RATE then
        lastNpcUpdate = os.clock()
        updateNpcCache()
    end
end))

-- | Target Finder | --
local function getClosestTarget()
    if not rootPart then return nil end

    local closestRoot = nil
    local shortestDistance = math.huge
    local myPosition = rootPart.Position

    for _, otherPlayer in ipairs(players:GetPlayers()) do
        if otherPlayer ~= localPlayer and otherPlayer.Character then
            local root = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local distance = (myPosition - root.Position).Magnitude
                if distance < shortestDistance and distance > 0.1 then
                    shortestDistance = distance
                    closestRoot = root
                end
            end
        end
    end

    for _, npcRoot in ipairs(npcList) do
        if npcRoot and npcRoot.Parent then
            local distance = (myPosition - npcRoot.Position).Magnitude
            if distance < shortestDistance and distance > 0.1 then
                shortestDistance = distance
                closestRoot = npcRoot
            end
        end
    end

    return closestRoot
end

-- | Abort Pending Actions | --
local function abortSequences()
    sequenceId = sequenceId + 1
    dashPending = false
    magnetPending = false

    if pullConnection then
        pullConnection:Disconnect()
        pullConnection = nil
    end

    if cancelConnection then
        cancelConnection:Disconnect()
        cancelConnection = nil
    end
end

-- | Force Cancel | --
local function forceCancel()
    if pullConnection then
        pullConnection:Disconnect()
        pullConnection = nil
    end

    if not rootPart or not rootPart.Parent then return end

    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("BodyVelocity")
            or child:IsA("LinearVelocity")
            or child:IsA("Attachment")
            or child:IsA("BodyAngularVelocity")
            or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end

    dashVelocity = nil
    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

-- | Cancel Watcher (counted from the dash) | --
local function startCancelWatcher()
    if cancelConnection then
        cancelConnection:Disconnect()
        cancelConnection = nil
    end

    local startTime = os.clock()
    local connection

    connection = runService.Heartbeat:Connect(function()
        local function stopWatcher()
            connection:Disconnect()
            if cancelConnection == connection then
                cancelConnection = nil
            end
        end

        local elapsed = os.clock() - startTime

        if not settings.enabled or not rootPart or not rootPart.Parent
            or elapsed > settings.cancelDelay + CANCEL_TIMEOUT then
            stopWatcher()
            return
        end

        if elapsed < settings.cancelDelay then return end

        local targetRoot = getClosestTarget()
        if not targetRoot then return end

        local horizontalDistance = (
            Vector2.new(rootPart.Position.X, rootPart.Position.Z)
            - Vector2.new(targetRoot.Position.X, targetRoot.Position.Z)
        ).Magnitude

        -- | Cancel when close enough to the target | --
        if horizontalDistance < CANCEL_RANGE then
            forceCancel()
            stopWatcher()
        end
    end)

    cancelConnection = connection
end

-- | Magnet Pull | --
local function startMagnetPull()
    if pullConnection then
        pullConnection:Disconnect()
        pullConnection = nil
    end

    local duration = settings.magnetDuration
    if duration <= 0 then return end

    local startTime = os.clock()
    local connection

    connection = runService.Heartbeat:Connect(function()
        local function finishPull()
            connection:Disconnect()
            if pullConnection == connection then
                pullConnection = nil
            end
        end

        if not rootPart or not rootPart.Parent then
            finishPull()
            return
        end

        if os.clock() - startTime >= duration then
            finishPull()
            return
        end

        local targetRoot = getClosestTarget()
        if not targetRoot then return end

        local currentPosition = rootPart.Position
        local targetHorizontal = Vector3.new(targetRoot.Position.X, currentPosition.Y, targetRoot.Position.Z)
        local direction = targetHorizontal - currentPosition

        if direction.Magnitude > 1 then
            local desiredVelocity = direction.Unit * PULL_STRENGTH
            local currentVelocity = rootPart.AssemblyLinearVelocity
            local newVelocity = currentVelocity:Lerp(desiredVelocity, PULL_SMOOTHNESS)

            rootPart.AssemblyLinearVelocity = Vector3.new(
                newVelocity.X * 0.85,
                currentVelocity.Y,
                newVelocity.Z * 0.85
            )
        end
    end)

    pullConnection = connection
end

-- | Magnet Teleport (delay is counted from the dash) | --
local function runMagnet(currentSequence)
    if not rootPart or not character then return end

    local targetRoot = getClosestTarget()
    if not targetRoot then return end

    local distance = (rootPart.Position - targetRoot.Position).Magnitude
    if distance > MAGNET_RANGE then return end

    task.wait(settings.magnetDelay)
    if currentSequence ~= sequenceId or not settings.enabled then return end
    if not rootPart or not rootPart.Parent then return end
    if not targetRoot.Parent then return end

    rootPart.CFrame = CFrame.new(targetRoot.Position + Vector3.new(0, 2, 0))

    if dashVelocity and dashVelocity.Parent then
        dashVelocity:Destroy()
    end
    dashVelocity = nil

    local velocity = rootPart.AssemblyLinearVelocity
    rootPart.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)

    startMagnetPull()
end

local function onDash()
    if not settings.enabled or magnetPending then return end

    magnetPending = true
    local currentSequence = sequenceId

    startCancelWatcher()
    runMagnet(currentSequence)

    if currentSequence == sequenceId then
        magnetPending = false
    end
end

-- | Dash Remote | --
local function fireDash()
    if not character or not rootPart then return end

    local communicate = character:FindFirstChild("Communicate")
    if communicate and communicate:IsA("RemoteEvent") then
        pcall(function()
            communicate:FireServer({
                Dash = Enum.KeyCode.W,
                Key = Enum.KeyCode.Q,
                Goal = "KeyPress"
            })
        end)
    elseif virtualInputManager then
        pcall(function()
            virtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
            task.wait(0.03)
            virtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        end)
    end
end

-- | Uppercut Detected: wait the dash delay, then dash | --
local function onUppercut()
    if not settings.enabled or dashPending then return end

    dashPending = true
    local currentSequence = sequenceId

    task.wait(settings.dashDelay)
    if currentSequence ~= sequenceId then return end

    dashPending = false
    if settings.enabled then
        fireDash()
    end
end

-- | Animation Detectors | --
local function isDashAnimation(animationId)
    for _, dashId in ipairs(DASH_ANIMATION_IDS) do
        if animationId:find(dashId, 1, true) then
            return true
        end
    end
    return false
end

local function isUppercutAnimation(animationTrack)
    local animation = animationTrack.Animation
    if not animation then return false end

    return animation.AnimationId:find(UPPERCUT_ANIMATION_ID, 1, true) ~= nil
end

-- | Core Logic | --
local function setupCharacter(newCharacter)
    character = newCharacter
    rootPart = newCharacter:WaitForChild("HumanoidRootPart", 10)
    humanoid = newCharacter:WaitForChild("Humanoid", 10)
    dashVelocity = nil
    abortSequences()

    if animConnection then
        animConnection:Disconnect()
        animConnection = nil
    end

    if childAddedConnection then
        childAddedConnection:Disconnect()
        childAddedConnection = nil
    end

    if not rootPart or not humanoid then return end

    childAddedConnection = rootPart.ChildAdded:Connect(function(child)
        if child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            dashVelocity = child
        end
    end)

    animConnection = humanoid.AnimationPlayed:Connect(function(animationTrack)
        local animation = animationTrack.Animation
        if not animation then return end

        local animationId = animation.AnimationId

        if isUppercutAnimation(animationTrack) then
            onUppercut()
        elseif isDashAnimation(animationId) then
            local currentSequence = sequenceId
            task.wait(DASH_DETECT_OFFSET)
            if currentSequence ~= sequenceId then return end
            onDash()
        end
    end)
end

-- | Unload | --
local function unload()
    abortSequences()

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)

    if animConnection then
        animConnection:Disconnect()
        animConnection = nil
    end

    if childAddedConnection then
        childAddedConnection:Disconnect()
        childAddedConnection = nil
    end

    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end

    env.MagnetTechinifiedUnload = nil
end

env.MagnetTechinifiedUnload = unload

-- | Init | --
if localPlayer.Character then
    task.spawn(setupCharacter, localPlayer.Character)
end

table.insert(connections, localPlayer.CharacterAdded:Connect(setupCharacter))

-- | Load GUI | --
local ui_url = "https://raw.githubusercontent.com/m7za/tsb/refs/heads/main/MagnetGui.lua"
local success, result = pcall(function()
    local buildGui = loadstring(game:HttpGet(ui_url))()
    return buildGui(settings)
end)

if success then
    screenGui = result
else
    warn("Magnet GUI failed to load: " .. tostring(result))
end