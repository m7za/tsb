return function(settings)
    local tweenService = game:GetService("TweenService")

    local isAdvancedOpen = false

    -- | Main Window | --
    local screenGui = Instance.new("ScreenGui", game.CoreGui)
    screenGui.Name = "Boomy_Lethal"

    local mainFrame = Instance.new("Frame", screenGui)
    mainFrame.Name = "Main"
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Size = UDim2.new(0, 240, 0, 80)
    mainFrame.Position = UDim2.new(0.5, -120, 0.2, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

    local backgroundGradient = Instance.new("UIGradient", mainFrame)
    backgroundGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 5, 5)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 30, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 5, 5))
    })

    local borderStroke = Instance.new("UIStroke", mainFrame)
    borderStroke.Thickness = 2.5

    local borderGradient = Instance.new("UIGradient", borderStroke)
    borderGradient.Color = ColorSequence.new(Color3.fromRGB(0, 120, 255))

    -- | Header | --
    local headerFrame = Instance.new("Frame", mainFrame)
    headerFrame.Size = UDim2.new(1, 0, 0, 80)
    headerFrame.BackgroundTransparency = 1

    local titleLabel = Instance.new("TextLabel", headerFrame)
    titleLabel.Size = UDim2.new(0.65, 0, 0.4, 0)
    titleLabel.Position = UDim2.new(0.08, 0, 0.15, 0)
    titleLabel.Text = "BOOMMY LETHAL"
    titleLabel.Font = Enum.Font.Michroma
    titleLabel.TextSize = 15
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.BackgroundTransparency = 1

    local toggleButton = Instance.new("TextButton", headerFrame)
    toggleButton.Size = UDim2.new(0, 50, 0, 26)
    toggleButton.Position = UDim2.new(0.72, 0, 0.18, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    toggleButton.Text = "ON"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 12
    Instance.new("UICorner", toggleButton)

    local advancedButton = Instance.new("TextButton", headerFrame)
    advancedButton.Size = UDim2.new(0, 100, 0, 20)
    advancedButton.Position = UDim2.new(0.08, 0, 0.55, 0)
    advancedButton.BackgroundTransparency = 1
    advancedButton.Text = "Advanced >"
    advancedButton.Font = Enum.Font.SourceSansBold
    advancedButton.TextSize = 14
    advancedButton.TextColor3 = Color3.fromRGB(0, 200, 255)
    advancedButton.TextXAlignment = Enum.TextXAlignment.Left

    -- | Advanced Panel | --
    local advancedFrame = Instance.new("Frame", mainFrame)
    advancedFrame.Size = UDim2.new(0.85, 0, 0, 280)
    advancedFrame.Position = UDim2.new(0.08, 0, 0, 80)
    advancedFrame.BackgroundTransparency = 1

    local advancedLayout = Instance.new("UIListLayout", advancedFrame)
    advancedLayout.Padding = UDim.new(0, 8)
    advancedLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local layoutOrderCounter = 0
    local function getNextLayoutOrder()
        layoutOrderCounter = layoutOrderCounter + 1
        return layoutOrderCounter
    end

    local accuracyLabel
    local accuracyInput

    local function createSettingRow(labelText, settingKey)
        local rowFrame = Instance.new("Frame", advancedFrame)
        rowFrame.Size = UDim2.new(1, 0, 0, 25)
        rowFrame.LayoutOrder = getNextLayoutOrder()
        rowFrame.BackgroundTransparency = 1

        local rowLabel = Instance.new("TextLabel", rowFrame)
        rowLabel.Size = UDim2.new(0.5, 0, 1, 0)
        rowLabel.Text = labelText
        rowLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        rowLabel.Font = Enum.Font.SourceSans
        rowLabel.TextSize = 13
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.BackgroundTransparency = 1

        local rowInput = Instance.new("TextBox", rowFrame)
        rowInput.Size = UDim2.new(0.4, 0, 1, 0)
        rowInput.Position = UDim2.new(0.6, 0, 0, 0)
        rowInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        rowInput.Text = tostring(settings[settingKey])
        rowInput.TextColor3 = Color3.fromRGB(0, 255, 255)
        rowInput.TextSize = 12
        Instance.new("UICorner", rowInput)

        if settingKey == "lethalAccuracy" then
            accuracyLabel = rowLabel
            accuracyInput = rowInput
        end

        rowInput.FocusLost:Connect(function()
            local number = tonumber(rowInput.Text)
            if number then
                settings[settingKey] = number
            end
        end)
    end

    createSettingRow("Delay:", "lethalDelay")
    createSettingRow("Velo:", "lethalJumpVelocity")
    createSettingRow("Accuracy:", "lethalAccuracy")
    createSettingRow("Cancel:", "lethalCancelDelay")

    local modeButton = Instance.new("TextButton", advancedFrame)
    modeButton.LayoutOrder = getNextLayoutOrder()
    modeButton.Size = UDim2.new(1, 0, 0, 28)
    modeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    modeButton.Text = "Mode: V1"
    modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    modeButton.Font = Enum.Font.SourceSansBold
    Instance.new("UICorner", modeButton)

    local camToggleButton = Instance.new("TextButton", advancedFrame)
    camToggleButton.LayoutOrder = getNextLayoutOrder()
    camToggleButton.Size = UDim2.new(1, 0, 0, 28)
    camToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    camToggleButton.Font = Enum.Font.SourceSansBold
    Instance.new("UICorner", camToggleButton)

    local function refreshCamToggle()
        camToggleButton.Text = "Cam Smooth: " .. (settings.camSmooth and "ON" or "OFF")
        camToggleButton.BackgroundColor3 = settings.camSmooth
            and Color3.fromRGB(0, 120, 255)
            or Color3.fromRGB(200, 50, 50)
    end

    refreshCamToggle()

    createSettingRow("Cam Delay:", "camSmoothDelay")
    createSettingRow("Cam Time:", "camDuration")

    -- | Events | --
    modeButton.MouseButton1Click:Connect(function()
        settings.lethalMode = (settings.lethalMode == "V1") and "V2" or "V1"
        modeButton.Text = "Mode: " .. settings.lethalMode

        if settings.lethalMode == "V2" then
            accuracyLabel.Text = "Flip Delay:"
            settings.lethalAccuracy = 0.25
        else
            accuracyLabel.Text = "Accuracy:"
            settings.lethalAccuracy = 15
        end

        accuracyInput.Text = tostring(settings.lethalAccuracy)
    end)

    advancedButton.MouseButton1Click:Connect(function()
        isAdvancedOpen = not isAdvancedOpen

        local targetSize = isAdvancedOpen and UDim2.new(0, 240, 0, 360) or UDim2.new(0, 240, 0, 80)
        advancedButton.Text = isAdvancedOpen and "Advanced v" or "Advanced >"

        tweenService:Create(
            mainFrame,
            TweenInfo.new(0.3, Enum.EasingStyle.Sine),
            {Size = targetSize}
        ):Play()
    end)

    toggleButton.MouseButton1Click:Connect(function()
        settings.enabled = not settings.enabled

        toggleButton.Text = settings.enabled and "ON" or "OFF"
        toggleButton.BackgroundColor3 = settings.enabled
            and Color3.fromRGB(0, 120, 255)
            or Color3.fromRGB(200, 50, 50)
    end)

    camToggleButton.MouseButton1Click:Connect(function()
        settings.camSmooth = not settings.camSmooth
        refreshCamToggle()
    end)

    return screenGui
end