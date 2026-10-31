-- | Services | --
local Lighting = game:GetService("Lighting")
local player = game:GetService("Players").LocalPlayer
local terrain = workspace.Terrain

-- | Hide Effect | --
local function hideEffect(v)
    if v:IsA("Trail") or v:IsA("ParticleEmitter") then
        v.Transparency = NumberSequence.new(1)
    end
end

local function hookCharacter(character)
    for _, v in ipairs(character:GetDescendants()) do
        hideEffect(v)
    end
    character.DescendantAdded:Connect(hideEffect)
end

if player.Character then
    hookCharacter(player.Character)
end
player.CharacterAdded:Connect(hookCharacter)

-- | Custom Atmosphere | --
local function flattenSky(sky)
    sky.SunAngularSize = 0
    sky.MoonAngularSize = 0
    sky.SunTextureId = ""
    sky.MoonTextureId = ""
end

local function flattenAtmosphere(atmosphere)
    atmosphere.Density = 0
    atmosphere.Haze = 0
    atmosphere.Glare = 0
end

Lighting.ClockTime = 12
Lighting.GlobalShadows = false
Lighting.Brightness = 0.8
Lighting.ExposureCompensation = -0.2
Lighting.FogStart = 9e9
Lighting.FogEnd = 9e9

for _, v in ipairs(Lighting:GetChildren()) do
    if v:IsA("Sky") then
        v:Destroy()
    elseif v:IsA("PostEffect") then
        v.Enabled = false
    elseif v:IsA("Atmosphere") then
        flattenAtmosphere(v)
    end
end

-- | Gray & Clean Sky | --
local sky = Instance.new("Sky")
sky.SkyboxBk = "rbxassetid://92959017845968"
sky.SkyboxFt = "rbxassetid://129304841254693"
sky.SkyboxLf = "rbxassetid://129249062260004"
sky.SkyboxRt = "rbxassetid://117319232583147"
sky.SkyboxUp = "rbxassetid://121193772599100"
sky.SkyboxDn = "rbxassetid://115022734343595"
flattenSky(sky)
sky.Parent = Lighting

Lighting.ChildAdded:Connect(function(v)
    if v:IsA("Sky") then
        task.wait()
        flattenSky(v)
    elseif v:IsA("Atmosphere") then
        flattenAtmosphere(v)
    end
end)

-- | Hide Clouds | --
local function hideClouds(v)
    if v:IsA("Clouds") then
        v.Enabled = false
    end
end

for _, v in ipairs(terrain:GetChildren()) do
    hideClouds(v)
end
terrain.ChildAdded:Connect(hideClouds)

workspace.DescendantAdded:Connect(function(v)
    if v:IsA("Smoke") then
        v:Destroy()
    elseif v:IsA("ParticleEmitter") then
        local model = v:FindFirstAncestorOfClass("Model")
        local class = model and model:FindFirstChild("Class")
        if not (class and class.Value == "Hero Hunter") then
            v:Destroy()
        end
    end
end)

-- | Delete Trees | --
local trees = workspace:WaitForChild("Map"):WaitForChild("Trees")

trees:ClearAllChildren()
trees.ChildAdded:Connect(function(v)
    v:Destroy()
end)

-- | Rendering | --
pcall(function()
    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
end)