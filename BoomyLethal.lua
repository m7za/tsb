-- Boommy Lethal Core
local GUI_URL = "https://raw.githubusercontent.com/m7za/tsb/refs/heads/main/BoomyLethalGui.lua"

-- | Services | --
local userInputService = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local debrisService = game:GetService("Debris")

local localPlayer = game.Players.LocalPlayer
local localHumanoid = localPlayer.Character:FindFirstChild("Humanoid")

-- | State | --
local isScriptActive = true
local isNoclipping = false

local isDashing = false
local dashStartTime = 0
local camSmoothConnection = nil
local wasCameraAttached = false
local previousCameraSubject = nil

local settings = {
    enabled = true,
    lethalEnabled = true,
    lethalAnimationId = "rbxassetid://12296113986",
    lethalDashDelay = 1.64,
    lethalJumpDelay = 1.80,
    lethalJumpVelocity = 54,
    lethalAccuracy = 7,
    lethalCancelDelay = 0.389,
    lethalMode = "V1",
    cancelEnabled = true,
    noClipEnabled = true,
    dashRange = 7,
    camSmooth = true,
    camSmoothDelay = 0,
    camDuration = 1.5
}

-- | Camera Smooth | --
local function updateCamSmooth(isEnabled)
    if camSmoothConnection then
        camSmoothConnection:Disconnect()
        camSmoothConnection = nil
    end

    if not isEnabled then
        if wasCameraAttached then
            pcall(function()
                local character = localPlayer.Character
                local camera = workspace.CurrentCamera

                camera.CameraType = Enum.CameraType.Custom
                camera.CameraSubject = previousCameraSubject
                    or (character and character:FindFirstChildOfClass("Humanoid"))
            end)
            wasCameraAttached = false
        end
        return
    end

    camSmoothConnection = runService.RenderStepped:Connect(function()
        local character = localPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local camera = workspace.CurrentCamera
        if not rootPart or not camera then return end

        local elapsed = os.clock() - dashStartTime
        local isInSmoothWindow = isDashing
            and elapsed >= settings.camSmoothDelay
            and elapsed <= settings.camSmoothDelay + settings.camDuration

        if not isInSmoothWindow then
            if wasCameraAttached then
                pcall(function()
                    camera.CameraType = Enum.CameraType.Custom
                    camera.CameraSubject = previousCameraSubject
                        or character:FindFirstChildOfClass("Humanoid")
                end)
                wasCameraAttached = false
            end
            return
        end

        if not wasCameraAttached then
            previousCameraSubject = camera.CameraSubject
            wasCameraAttached = true
        end

        -- Attach makes the camera follow the character's rotation
        pcall(function()
            camera.CameraType = Enum.CameraType.Attach
            camera.CameraSubject = rootPart
        end)
    end)
end

local function onDashStart()
    isDashing = true
    dashStartTime = os.clock()
    updateCamSmooth(settings.camSmooth)
end

local function onDashEnd()
    isDashing = false
    updateCamSmooth(false)
end

-- | Dash Remote | --
local function fireDash()
    local character = localPlayer.Character
    if not character then return end

    local communicate = character:FindFirstChild("Communicate")
    if communicate then
        communicate:FireServer({
            Dash = Enum.KeyCode.W,
            Key = Enum.KeyCode.Q,
            Goal = "KeyPress"
        })
    end
end

-- | End Dash | --
local function endDash()
    isNoclipping = false

    if localPlayer.Character and localHumanoid then
        localHumanoid.AutoRotate = true
    end

    onDashEnd()
end

-- | Force Cancel | --
local function forceCancel()
    endDash()

    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("BodyVelocity")
            or child:IsA("LinearVelocity")
            or child:IsA("Attachment")
            or child:IsA("BodyAngularVelocity")
            or child:IsA("BodyGyro") then
            child:Destroy()
        end
    end

    rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
end

-- | Target Finder | --
local function getNearestTorso()
    local character = localPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {character}

    local nearbyParts = workspace:GetPartBoundsInRadius(
        character.HumanoidRootPart.Position,
        settings.dashRange,
        overlapParams
    )

    local nearestTorso = nil
    local nearestDistance = settings.dashRange

    for _, part in pairs(nearbyParts) do
        local model = part:FindFirstAncestorOfClass("Model")

        if model and model:FindFirstChild("Humanoid") and model ~= character then
            local torso = model:FindFirstChild("Torso")
                or model:FindFirstChild("UpperTorso")
                or model:FindFirstChild("HumanoidRootPart")

            if torso then
                local distance = (character.HumanoidRootPart.Position - torso.Position).Magnitude

                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestTorso = torso
                end
            end
        end
    end

    return nearestTorso
end

-- | Core Logic | --
local function setupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    humanoid.AnimationPlayed:Connect(function(animationTrack)
        if not isScriptActive or not settings.enabled then return end
        if animationTrack.Animation.AnimationId ~= settings.lethalAnimationId then return end
        if not settings.lethalEnabled then return end

        local targetTorso = getNearestTorso()
        if not targetTorso then
            endDash()
            return
        end

        -- both delays count from the moment the animation starts
        local dashDelay = settings.lethalDashDelay
        local jumpDelay = settings.lethalJumpDelay

        -- jump runs on its own timer
        task.delay(jumpDelay, function()
            if not isScriptActive or not settings.enabled then return end
            if not rootPart.Parent then return end

            local currentVelocity = rootPart.AssemblyLinearVelocity
            rootPart.AssemblyLinearVelocity = Vector3.new(currentVelocity.X, settings.lethalJumpVelocity, currentVelocity.Z)

            local bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.Velocity = Vector3.new(0, settings.lethalJumpVelocity, 0)
            bodyVelocity.MaxForce = Vector3.new(0, 1e8, 0)
            bodyVelocity.P = 1500
            bodyVelocity.Parent = rootPart
            debrisService:AddItem(bodyVelocity, 0.1)
        end)

        -- dash after its own delay
        task.wait(dashDelay)
        if not isScriptActive then return end

        isNoclipping = true
        onDashStart()
        fireDash()

        local startTime = tick()
        local hasFlipped = false
        local currentMode = settings.lethalMode

        local forwardDirection = (targetTorso.Position - rootPart.Position).Unit
        local sideVector = Vector3.new(-forwardDirection.Z, 0, forwardDirection.X)

        local angularVelocity = nil
        if currentMode == "V1" then
            angularVelocity = Instance.new("BodyAngularVelocity", rootPart)
            angularVelocity.MaxTorque = Vector3.new(0, 1000000, 0)
            angularVelocity.P = 15000
        end

        local connection
        connection = runService.Heartbeat:Connect(function()
            if not isScriptActive then
                if angularVelocity then angularVelocity:Destroy() end
                endDash()
                connection:Disconnect()
                return
            end

            local elapsed = tick() - startTime
            humanoid.AutoRotate = false

            if currentMode == "V1" then
                -- Spiral around the target
                local angle = (elapsed / 0.45) * (math.pi / 1.5)
                local radius = settings.lethalAccuracy * (1 - math.clamp(elapsed / 0.45, 0, 1))

                local lookTarget = targetTorso.Position
                    + (sideVector * math.cos(angle) + forwardDirection * math.sin(angle)) * radius

                local lookAtCFrame = CFrame.lookAt(
                    rootPart.Position,
                    Vector3.new(lookTarget.X, rootPart.Position.Y, lookTarget.Z)
                )

                local relativeCFrame = rootPart.CFrame:Inverse() * lookAtCFrame
                local _, yaw, _ = relativeCFrame:ToEulerAnglesXYZ()

                if angularVelocity and angularVelocity.Parent then
                    angularVelocity.AngularVelocity = Vector3.new(0, yaw * 30, 0)
                end
            elseif elapsed >= settings.lethalAccuracy and not hasFlipped then
                -- Flip 180 degrees once
                rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.pi, 0)
                hasFlipped = true
            end

            local horizontalDistance = (
                Vector2.new(rootPart.Position.X, rootPart.Position.Z)
                - Vector2.new(targetTorso.Position.X, targetTorso.Position.Z)
            ).Magnitude

            -- Cancel when close enough to the target
            if settings.cancelEnabled and elapsed > settings.lethalCancelDelay and horizontalDistance < 2.2 then
                if angularVelocity then angularVelocity:Destroy() end
                forceCancel()
                connection:Disconnect()
                return
            end

            -- Safety stop
            if not settings.enabled or elapsed > 1.5 or not targetTorso.Parent then
                if angularVelocity then angularVelocity:Destroy() end
                endDash()
                connection:Disconnect()
                return
            end
        end)
    end)
end

-- | Noclip Loop | --
runService.Stepped:Connect(function()
    if not (isNoclipping and localPlayer.Character and settings.noClipEnabled) then return end

    for _, descendant in pairs(localPlayer.Character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
        end
    end
end)

-- | Init | --
if localPlayer.Character then
    setupCharacter(localPlayer.Character)
end

localPlayer.CharacterAdded:Connect(setupCharacter)

-- | Load GUI | --
local success, result = pcall(function()
    local buildGui = loadstring(game:HttpGet(GUI_URL))()
    return buildGui(settings)
end)

if not success then
    warn("Boommy Lethal GUI failed to load: " .. tostring(result))
end