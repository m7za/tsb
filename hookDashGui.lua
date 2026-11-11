local function toHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

local function fromHex(s)
    local clean = s:gsub("[#%s]", "")
    local r, g, b = clean:match("^(%x%x)(%x%x)(%x%x)$")
    if not r then
        return nil
    end
    return Color3.fromRGB(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16))
end

local function parseNumber(s)
    local clean = s:gsub(",", "."):gsub("%s", "")
    if clean:match("^%-?[%d%.]+$") then
        return tonumber(clean)
    end
    return nil
end

local function create_gui(settings, api)
    local tween_service = game:GetService("TweenService")
    local text_service = game:GetService("TextService")
    local user_input_service = game:GetService("UserInputService")
    local http_service = game:GetService("HttpService")

    local gui_name = "hook_dash_by_techinified"
    local window_width = 250
    local top_bar_height = 34
    local tab_bar_height = 34
    local header_height = top_bar_height + tab_bar_height
    local body_padding = 10
    local body_gap = 8
    local cell_height = 40
    local cell_gap = 6
    local gui_font = Enum.Font.Jura

    local gui_scale = 0.9
    local max_height_ratio = 0.75

    local config_folder = "techinified/hookdash"
    local config_path = config_folder .. "/configs"

    local number_fields = {
        {"Distance", "distance"},
        {"Range", "range"},
        {"Cooldown", "cooldown"},
        {"Delay", "delay"},
        {"Duration", "duration"},
        {"Smoothness", "smoothness"},
        {"Prediction", "prediction"},
        {"Reach", "reach"},
        {"MaxSelfY", "max self y"},
        {"MaxTargetY", "max target y"},
        {"AimY", "aim y"},
        {"TapMaxMove", "tap max move"},
        {"TapMaxTime", "tap max time"},
    }

    local config_items = {
        {key = "MobileMode", kind = "toggle"},
        {key = "PCMode", kind = "toggle"},
        {key = "Color", kind = "color"},
        {key = "SelectKey", kind = "key"},
        {key = "DashKey", kind = "key"},
    }
    for _, field in ipairs(number_fields) do
        table.insert(config_items, {key = field[1], kind = "number"})
    end

    local has_file_api = isfolder and makefolder and writefile and readfile
        and listfiles and isfile and delfile

    local theme = {
        danger = Color3.fromRGB(255, 85, 100),
        background = Color3.fromRGB(16, 16, 21),
        panel = Color3.fromRGB(24, 24, 31),
        outline = Color3.fromRGB(44, 44, 56),
        accent = Color3.fromRGB(122, 92, 255),
        text = Color3.fromRGB(235, 235, 242),
        muted = Color3.fromRGB(128, 128, 144),
        off = Color3.fromRGB(52, 52, 66),
        white = Color3.fromRGB(255, 255, 255)
    }

    local fast_tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local slow_tween = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function round(instance, radius)
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = instance
        return corner
    end

    local function outline(instance, color, thickness)
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = thickness or 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = instance
        return stroke
    end

    local function make_label(parent, text, size, color, font)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextSize = size
        label.TextColor3 = color
        label.Font = font or gui_font
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = parent
        return label
    end

    local screen_gui = Instance.new("ScreenGui")
    screen_gui.Name = gui_name
    screen_gui.ResetOnSpawn = false
    screen_gui.DisplayOrder = 1000
    if not api.mountGui(screen_gui) then
        error("could not mount the menu")
    end

    local main_frame = Instance.new("Frame")
    main_frame.Name = "main"
    main_frame.Active = true
    main_frame.Size = UDim2.new(0, window_width, 0, top_bar_height)
    main_frame.AnchorPoint = Vector2.new(0.5, 0)
    main_frame.Position = UDim2.new(0.5, 0, 0, 8)
    main_frame.BackgroundColor3 = theme.background
    main_frame.BorderSizePixel = 0
    main_frame.ClipsDescendants = true
    main_frame.Parent = screen_gui
    round(main_frame, 12)
    outline(main_frame, theme.outline, 1)

    local window_scale = Instance.new("UIScale")
    window_scale.Scale = gui_scale
    window_scale.Parent = main_frame

    local top_bar = Instance.new("Frame")
    top_bar.Name = "top_bar"
    top_bar.Size = UDim2.new(1, 0, 0, top_bar_height)
    top_bar.BackgroundTransparency = 1
    top_bar.Parent = main_frame

    local accent_dot = Instance.new("Frame")
    accent_dot.Size = UDim2.new(0, 8, 0, 8)
    accent_dot.Position = UDim2.new(0, 12, 0.5, -4)
    accent_dot.BackgroundColor3 = theme.accent
    accent_dot.BorderSizePixel = 0
    accent_dot.Parent = top_bar
    round(accent_dot, 4)

    local title_label = make_label(top_bar, 'Hook Dash <font color="#808090">by</font> Techinified', 12, theme.text, gui_font)
    title_label.RichText = true
    title_label.Size = UDim2.new(1, -90, 1, 0)
    title_label.Position = UDim2.new(0, 26, 0, 0)

    local tab_segment = Instance.new("Frame")
    tab_segment.Size = UDim2.new(1, -body_padding * 2, 0, 24)
    tab_segment.Position = UDim2.new(0, body_padding, 0, top_bar_height + 5)
    tab_segment.BackgroundColor3 = theme.panel
    tab_segment.BorderSizePixel = 0
    tab_segment.Parent = main_frame
    round(tab_segment, 7)
    outline(tab_segment, theme.outline, 1)

    local collapse_button = Instance.new("TextButton")
    collapse_button.AutoButtonColor = false
    collapse_button.Text = "-"
    collapse_button.Font = gui_font
    collapse_button.TextSize = 14
    collapse_button.TextColor3 = theme.muted
    collapse_button.BackgroundColor3 = theme.panel
    collapse_button.BorderSizePixel = 0
    collapse_button.Size = UDim2.new(0, 22, 0, 22)
    collapse_button.Position = UDim2.new(1, -58, 0.5, -11)
    collapse_button.Parent = top_bar
    round(collapse_button, 6)

    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1)
    divider.Position = UDim2.new(0, 0, 0, top_bar_height - 1)
    divider.BackgroundColor3 = theme.outline
    divider.BorderSizePixel = 0
    divider.Parent = main_frame

    local body = Instance.new("ScrollingFrame")
    body.Name = "body"
    body.Position = UDim2.new(0, 0, 0, header_height)
    body.Size = UDim2.new(1, 0, 1, -header_height)
    body.BackgroundTransparency = 1
    body.BorderSizePixel = 0
    body.ScrollBarThickness = 3
    body.ScrollBarImageColor3 = theme.off
    body.ScrollingDirection = Enum.ScrollingDirection.Y
    body.CanvasSize = UDim2.new(0, 0, 0, 0)
    body.AutomaticCanvasSize = Enum.AutomaticSize.Y
    body.Parent = main_frame

    local body_inset = Instance.new("UIPadding")
    body_inset.PaddingTop = UDim.new(0, body_padding)
    body_inset.PaddingBottom = UDim.new(0, body_padding)
    body_inset.PaddingLeft = UDim.new(0, body_padding)
    body_inset.PaddingRight = UDim.new(0, body_padding)
    body_inset.Parent = body

    local body_layout = Instance.new("UIListLayout")
    body_layout.Padding = UDim.new(0, body_gap)
    body_layout.SortOrder = Enum.SortOrder.LayoutOrder
    body_layout.Parent = body

    local layout_counter = 0
    local function next_order()
        layout_counter = layout_counter + 1
        return layout_counter
    end

    local is_collapsed = false
    local body_height = 0

    local function get_max_window_height()
        local camera = workspace.CurrentCamera
        local viewport_height = camera and camera.ViewportSize.Y or 720

        return math.max(160, viewport_height * max_height_ratio / gui_scale)
    end

    local function resize_window(animate)
        local full_height = header_height + body_height
        local target_height = is_collapsed and top_bar_height or math.min(full_height, get_max_window_height())
        local target_size = UDim2.new(0, window_width, 0, target_height)

        if animate then
            tween_service:Create(main_frame, slow_tween, {Size = target_size}):Play()
        else
            main_frame.Size = target_size
        end
    end

    local cell_count = #number_fields + 3
    local grid_rows = math.ceil(cell_count / 2)
    local grid_height = grid_rows * cell_height + (grid_rows - 1) * cell_gap
    local main_page_height = 34 * 3 + 12 + grid_height + body_gap * 4
    local config_page_height = cell_height + 28 + 12 + 84 + 12 + body_gap * 4

    body_height = math.max(main_page_height, config_page_height) + body_padding * 2
    resize_window(false)

    local current_camera = workspace.CurrentCamera
    if current_camera then
        local camera_connection = current_camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            resize_window(false)
        end)

        screen_gui.Destroying:Connect(function()
            camera_connection:Disconnect()
        end)
    end

    local refreshers = {}

    local function refresh_all()
        for _, refresh in ipairs(refreshers) do
            refresh()
        end
    end

    local function set_status(is_on)
        accent_dot.BackgroundColor3 = is_on and theme.accent or theme.off
    end

    local function make_switch(parent, setting_key, on_change)
        local track = Instance.new("TextButton")
        track.AutoButtonColor = false
        track.Text = ""
        track.Size = UDim2.new(0, 34, 0, 18)
        track.BorderSizePixel = 0
        track.Parent = parent
        round(track, 9)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.BackgroundColor3 = theme.white
        knob.BorderSizePixel = 0
        knob.Parent = track
        round(knob, 6)

        local function refresh(animate)
            local is_on = settings[setting_key] and true or false
            local track_color = is_on and theme.accent or theme.off
            local knob_position = is_on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)

            if animate then
                tween_service:Create(track, fast_tween, {BackgroundColor3 = track_color}):Play()
                tween_service:Create(knob, fast_tween, {Position = knob_position}):Play()
            else
                track.BackgroundColor3 = track_color
                knob.Position = knob_position
            end

            if on_change then
                on_change(is_on)
            end
        end

        track.MouseButton1Click:Connect(function()
            settings[setting_key] = not settings[setting_key]
            refresh(true)
        end)

        table.insert(refreshers, function()
            refresh(false)
        end)

        refresh(false)
        return track
    end

    local function create_section(parent, title)
        local header = Instance.new("Frame")
        header.LayoutOrder = next_order()
        header.Size = UDim2.new(1, 0, 0, 12)
        header.BackgroundTransparency = 1
        header.Parent = parent

        local text_width = text_service:GetTextSize(title, 11, gui_font, Vector2.new(200, 12)).X

        local section_label = make_label(header, title, 11, theme.muted, gui_font)
        section_label.Size = UDim2.new(0, text_width + 2, 1, 0)

        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0, 0.5)
        line.Position = UDim2.new(0, text_width + 10, 0.5, 0)
        line.Size = UDim2.new(1, -(text_width + 10), 0, 1)
        line.BackgroundColor3 = theme.outline
        line.BorderSizePixel = 0
        line.Parent = header
    end

    local function create_grid(parent, row_count, column_count)
        column_count = column_count or 2

        local grid = Instance.new("Frame")
        grid.LayoutOrder = next_order()
        grid.Size = UDim2.new(1, 0, 0, row_count * cell_height + (row_count - 1) * cell_gap)
        grid.BackgroundTransparency = 1
        grid.Parent = parent

        local slack = column_count > 2 and 1 or 0
        local cell_offset = -(math.ceil((column_count - 1) * cell_gap / column_count) + slack)

        local grid_layout = Instance.new("UIGridLayout")
        grid_layout.CellSize = UDim2.new(1 / column_count, cell_offset, 0, cell_height)
        grid_layout.CellPadding = UDim2.new(0, cell_gap, 0, cell_gap)
        grid_layout.SortOrder = Enum.SortOrder.LayoutOrder
        grid_layout.Parent = grid

        return grid
    end

    local function create_card(parent, label_text)
        local card = Instance.new("Frame")
        card.LayoutOrder = next_order()
        card.BackgroundColor3 = theme.panel
        card.BorderSizePixel = 0
        card.Parent = parent
        round(card, 8)
        local card_outline = outline(card, theme.outline, 1)

        local card_label = make_label(card, label_text, 11, theme.muted)
        card_label.Size = UDim2.new(1, -16, 0, 14)
        card_label.Position = UDim2.new(0, 8, 0, 4)

        return card, card_label, card_outline
    end

    local function create_cell(parent, label_text, initial_text)
        local card, card_label, card_outline = create_card(parent, label_text)
        card.BackgroundTransparency = 1

        local input = Instance.new("TextBox")
        input.BackgroundTransparency = 1
        input.Size = UDim2.new(1, -16, 0, 18)
        input.Position = UDim2.new(0, 8, 0, 19)
        input.Text = initial_text
        input.TextColor3 = theme.text
        input.PlaceholderColor3 = theme.off
        input.Font = gui_font
        input.TextSize = 14
        input.TextXAlignment = Enum.TextXAlignment.Left
        input.ClearTextOnFocus = false
        input.Parent = card

        input.Focused:Connect(function()
            tween_service:Create(card_outline, fast_tween, {Color = theme.accent}):Play()
        end)

        input.FocusLost:Connect(function()
            tween_service:Create(card_outline, fast_tween, {Color = theme.outline}):Play()
        end)

        return card_label, input, card
    end

    local function create_field(parent, label_text, setting_key)
        local cell_label, input = create_cell(parent, label_text, tostring(settings[setting_key]))

        input:GetPropertyChangedSignal("Text"):Connect(function()
            if not input:IsFocused() then
                return
            end
            local number = parseNumber(input.Text)
            if number then
                settings[setting_key] = math.max(0, number)
            end
        end)

        input.FocusLost:Connect(function()
            local number = parseNumber(input.Text)
            if number then
                settings[setting_key] = math.max(0, number)
            end
            input.Text = tostring(settings[setting_key])
        end)

        table.insert(refreshers, function()
            input.Text = tostring(settings[setting_key])
        end)

        return cell_label, input
    end

    local function create_color_field(parent, label_text, setting_key)
        local _, input, card = create_cell(parent, label_text, toHex(settings[setting_key]))
        input.Size = UDim2.new(1, -36, 0, 18)

        local swatch = Instance.new("Frame")
        swatch.AnchorPoint = Vector2.new(1, 0.5)
        swatch.Position = UDim2.new(1, -8, 0.5, 7)
        swatch.Size = UDim2.new(0, 12, 0, 12)
        swatch.BorderSizePixel = 0
        swatch.BackgroundColor3 = settings[setting_key]
        swatch.Parent = card
        round(swatch, 6)

        local function apply(color)
            settings[setting_key] = color
            swatch.BackgroundColor3 = color
            api.refreshHighlight()
        end

        input:GetPropertyChangedSignal("Text"):Connect(function()
            if not input:IsFocused() then
                return
            end
            local color = fromHex(input.Text)
            if color then
                apply(color)
            end
        end)

        input.FocusLost:Connect(function()
            local color = fromHex(input.Text)
            if color then
                apply(color)
            end
            input.Text = toHex(settings[setting_key])
        end)

        table.insert(refreshers, function()
            input.Text = toHex(settings[setting_key])
            swatch.BackgroundColor3 = settings[setting_key]
            api.refreshHighlight()
        end)

        return card
    end

    local listening_token = 0
    local key_connection = nil
    local listening_refresh = nil

    local function stop_listening()
        listening_token = listening_token + 1

        if key_connection then
            key_connection:Disconnect()
            key_connection = nil
        end

        if listening_refresh then
            listening_refresh()
            listening_refresh = nil
        end

        task.defer(function()
            if not key_connection then
                api.setListening(nil)
            end
        end)
    end

    local function create_key_field(parent, label_text, setting_key)
        local card = create_card(parent, label_text)
        card.BackgroundTransparency = 1

        local value_label = make_label(card, "", 14, theme.text, gui_font)
        value_label.Size = UDim2.new(1, -16, 0, 18)
        value_label.Position = UDim2.new(0, 8, 0, 19)

        local press_area = Instance.new("TextButton")
        press_area.AutoButtonColor = false
        press_area.Text = ""
        press_area.BackgroundTransparency = 1
        press_area.Size = UDim2.new(1, 0, 1, 0)
        press_area.Parent = card

        local function refresh()
            value_label.Text = settings[setting_key].Name
            value_label.TextColor3 = theme.text
        end

        press_area.MouseButton1Click:Connect(function()
            stop_listening()
            api.setListening(setting_key)
            listening_refresh = refresh
            value_label.Text = "press a key"
            value_label.TextColor3 = theme.accent

            local token = listening_token
            key_connection = user_input_service.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.Keyboard then
                    return
                end
                if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
                    settings[setting_key] = input.KeyCode
                end
                stop_listening()
            end)

            task.delay(6, function()
                if token == listening_token then
                    stop_listening()
                end
            end)
        end)

        table.insert(refreshers, refresh)
        refresh()
        return card
    end

    screen_gui.Destroying:Connect(function()
        stop_listening()
    end)

    local function make_button(parent, text, is_primary)
        local button = Instance.new("TextButton")
        button.LayoutOrder = next_order()
        button.AutoButtonColor = false
        button.Text = text
        button.Font = gui_font
        button.TextSize = 12
        button.TextColor3 = is_primary and theme.white or theme.text
        button.BackgroundColor3 = is_primary and theme.accent or theme.panel
        button.BorderSizePixel = 0
        button.Parent = parent
        round(button, 8)

        if not is_primary then
            outline(button, theme.outline, 1)
        end

        return button
    end

    local function create_button_row(parent, column_count)
        local row = Instance.new("Frame")
        row.LayoutOrder = next_order()
        row.Size = UDim2.new(1, 0, 0, 28)
        row.BackgroundTransparency = 1
        row.Parent = parent

        local slack = column_count > 2 and 1 or 0
        local cell_offset = -(math.ceil((column_count - 1) * cell_gap / column_count) + slack)

        local row_layout = Instance.new("UIGridLayout")
        row_layout.CellSize = UDim2.new(1 / column_count, cell_offset, 0, 28)
        row_layout.CellPadding = UDim2.new(0, cell_gap, 0, 0)
        row_layout.SortOrder = Enum.SortOrder.LayoutOrder
        row_layout.Parent = row

        return row
    end

    local function create_page()
        local page = Instance.new("Frame")
        page.LayoutOrder = next_order()
        page.Size = UDim2.new(1, 0, 0, 0)
        page.AutomaticSize = Enum.AutomaticSize.Y
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = body

        local page_layout = Instance.new("UIListLayout")
        page_layout.Padding = UDim.new(0, body_gap)
        page_layout.SortOrder = Enum.SortOrder.LayoutOrder
        page_layout.Parent = page

        return page
    end

    local main_page = create_page()
    local config_page = create_page()

    local pages = {main = main_page, configs = config_page}
    local tab_buttons = {}

    local function show_tab(tab_name)
        body.CanvasPosition = Vector2.new(0, 0)
        for name, page in pairs(pages) do
            page.Visible = name == tab_name
        end

        for name, button in pairs(tab_buttons) do
            local is_active = name == tab_name
            button.TextColor3 = is_active and theme.white or theme.muted
            tween_service:Create(button, fast_tween, {BackgroundTransparency = is_active and 0 or 1}):Play()
        end
    end

    for index, tab_name in ipairs({"main", "configs"}) do
        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.Text = tab_name
        button.Font = gui_font
        button.TextSize = 11
        button.TextColor3 = theme.muted
        button.BackgroundColor3 = theme.accent
        button.BackgroundTransparency = 1
        button.BorderSizePixel = 0
        button.Size = UDim2.new(0.5, -3, 1, -4)
        button.Position = UDim2.new((index - 1) * 0.5, index == 1 and 2 or 1, 0, 2)
        button.Parent = tab_segment
        round(button, 5)
        tab_buttons[tab_name] = button

        button.MouseButton1Click:Connect(function()
            show_tab(tab_name)
        end)
    end

    local function create_toggle_card(parent, label_text, setting_key, on_change)
        local card = Instance.new("Frame")
        card.LayoutOrder = next_order()
        card.Size = UDim2.new(1, 0, 0, 34)
        card.BackgroundColor3 = theme.panel
        card.BorderSizePixel = 0
        card.Parent = parent
        round(card, 8)
        outline(card, theme.outline, 1)

        local card_title = make_label(card, label_text, 15, theme.text, gui_font)
        card_title.Size = UDim2.new(1, -70, 1, 0)
        card_title.Position = UDim2.new(0, 12, 0, 0)

        local card_switch = make_switch(card, setting_key, on_change)
        card_switch.Position = UDim2.new(1, -46, 0.5, -9)

        return card
    end

    create_toggle_card(main_page, "enabled", "Enabled", function(is_on)
        set_status(is_on)
        if not is_on then
            api.clearTarget()
        end
    end)
    create_toggle_card(main_page, "mobile mode", "MobileMode", function()
        api.syncMobileButton()
    end)
    create_toggle_card(main_page, "pc mode", "PCMode")
    create_section(main_page, "settings")

    local settings_grid = create_grid(main_page, grid_rows, 2)
    for _, field in ipairs(number_fields) do
        create_field(settings_grid, field[2], field[1])
    end
    create_color_field(settings_grid, "color", "Color")
    create_key_field(settings_grid, "select key", "SelectKey")
    create_key_field(settings_grid, "dash key", "DashKey")

    local name_grid = create_grid(config_page, 1, 1)
    local _, name_input = create_cell(name_grid, "config name", "")
    name_input.PlaceholderText = "type a name"

    local button_row = create_button_row(config_page, 3)
    local save_button = make_button(button_row, "save", true)
    local load_button = make_button(button_row, "load", false)
    local delete_button = make_button(button_row, "delete", false)

    create_section(config_page, "saved")

    local config_list = Instance.new("ScrollingFrame")
    config_list.LayoutOrder = next_order()
    config_list.Size = UDim2.new(1, 0, 0, 84)
    config_list.BackgroundColor3 = theme.panel
    config_list.BorderSizePixel = 0
    config_list.ScrollBarThickness = 3
    config_list.ScrollBarImageColor3 = theme.off
    config_list.CanvasSize = UDim2.new(0, 0, 0, 0)
    config_list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    config_list.Parent = config_page
    round(config_list, 8)
    outline(config_list, theme.outline, 1)

    local list_inset = Instance.new("UIPadding")
    list_inset.PaddingTop = UDim.new(0, 4)
    list_inset.PaddingBottom = UDim.new(0, 4)
    list_inset.PaddingLeft = UDim.new(0, 4)
    list_inset.PaddingRight = UDim.new(0, 6)
    list_inset.Parent = config_list

    local list_layout = Instance.new("UIListLayout")
    list_layout.Padding = UDim.new(0, 2)
    list_layout.SortOrder = Enum.SortOrder.LayoutOrder
    list_layout.Parent = config_list

    local message_label = make_label(config_page, "", 11, theme.muted)
    message_label.LayoutOrder = next_order()
    message_label.Size = UDim2.new(1, 0, 0, 12)

    local message_token = 0

    local function notify(text, is_error)
        message_token = message_token + 1
        local token = message_token

        message_label.Text = text
        message_label.TextColor3 = is_error and theme.accent or theme.muted

        task.delay(3, function()
            if token == message_token then
                message_label.Text = ""
            end
        end)
    end

    local function clean_name(raw)
        local name = string.gsub(raw, "[^%w_%-%s]", "")
        name = string.gsub(name, "^%s+", "")
        name = string.gsub(name, "%s+$", "")
        return name
    end

    local function ensure_folders()
        for _, folder in ipairs({"techinified", config_folder, config_path}) do
            if not isfolder(folder) then
                makefolder(folder)
            end
        end
    end

    local function get_config_names()
        local names = {}
        if not has_file_api then
            return names
        end

        ensure_folders()

        for _, file_path in ipairs(listfiles(config_path)) do
            local file_name = string.match(file_path, "([^/\\]+)%.json$")
            if file_name then
                table.insert(names, file_name)
            end
        end

        table.sort(names)
        return names
    end

    local function encode_value(item)
        local value = settings[item.key]
        if item.kind == "color" then
            return toHex(value)
        elseif item.kind == "key" then
            return value.Name
        end
        return value
    end

    local function decode_value(item, raw)
        if item.kind == "number" then
            if type(raw) == "number" then
                return math.max(0, raw)
            end
        elseif item.kind == "toggle" then
            if type(raw) == "boolean" then
                return raw
            end
        elseif item.kind == "color" then
            if type(raw) == "string" then
                return fromHex(raw)
            end
        elseif item.kind == "key" then
            if type(raw) == "string" then
                local ok, key_code = pcall(function()
                    return Enum.KeyCode[raw]
                end)
                if ok and key_code then
                    return key_code
                end
            end
        end
        return nil
    end

    local refresh_list

    function refresh_list()
        for _, child in ipairs(config_list:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end

        local success, names = pcall(get_config_names)
        if not success then
            names = {}
        end

        if #names == 0 then
            local empty_label = make_label(config_list, "  no configs yet", 12, theme.muted)
            empty_label.Size = UDim2.new(1, 0, 0, 24)
            return
        end

        local selected_name = clean_name(name_input.Text)

        for index, config_name in ipairs(names) do
            local is_selected = config_name == selected_name

            local item = Instance.new("TextButton")
            item.LayoutOrder = index
            item.AutoButtonColor = false
            item.Size = UDim2.new(1, 0, 0, 24)
            item.BackgroundColor3 = theme.off
            item.BackgroundTransparency = is_selected and 0 or 1
            item.BorderSizePixel = 0
            item.Text = "  " .. config_name
            item.TextXAlignment = Enum.TextXAlignment.Left
            item.Font = gui_font
            item.TextSize = 12
            item.TextColor3 = is_selected and theme.text or theme.muted
            item.Parent = config_list
            round(item, 6)

            item.MouseButton1Click:Connect(function()
                name_input.Text = config_name
                refresh_list()
            end)
        end
    end

    local function save_config()
        if not has_file_api then
            notify("file functions not supported", true)
            return
        end

        local name = clean_name(name_input.Text)
        if name == "" then
            notify("type a name first", true)
            return
        end

        local data = {}
        for _, item in ipairs(config_items) do
            data[item.key] = encode_value(item)
        end

        local success = pcall(function()
            ensure_folders()
            writefile(config_path .. "/" .. name .. ".json", http_service:JSONEncode(data))
        end)

        if success then
            notify("saved " .. name)
            refresh_list()
        else
            notify("save failed", true)
        end
    end

    local function load_config()
        if not has_file_api then
            notify("file functions not supported", true)
            return
        end

        local name = clean_name(name_input.Text)
        if name == "" then
            notify("type or pick a name", true)
            return
        end

        local file_path = config_path .. "/" .. name .. ".json"
        if not isfile(file_path) then
            notify("config not found", true)
            return
        end

        local success, data = pcall(function()
            return http_service:JSONDecode(readfile(file_path))
        end)

        if not success or type(data) ~= "table" then
            notify("config is broken", true)
            return
        end

        for _, item in ipairs(config_items) do
            local raw = data[item.key]
            if raw ~= nil then
                local value = decode_value(item, raw)
                if value ~= nil then
                    settings[item.key] = value
                end
            end
        end

        refresh_all()
        notify("loaded " .. name)
    end

    local function delete_config()
        if not has_file_api then
            notify("file functions not supported", true)
            return
        end

        local name = clean_name(name_input.Text)
        local file_path = config_path .. "/" .. name .. ".json"

        if name == "" or not isfile(file_path) then
            notify("config not found", true)
            return
        end

        delfile(file_path)
        name_input.Text = ""
        notify("deleted " .. name)
        refresh_list()
    end

    save_button.MouseButton1Click:Connect(save_config)
    load_button.MouseButton1Click:Connect(load_config)
    delete_button.MouseButton1Click:Connect(delete_config)
    name_input.FocusLost:Connect(refresh_list)

    if not has_file_api then
        message_label.Text = "file functions not supported"
        message_label.TextColor3 = theme.accent
    end

    refresh_list()
    show_tab("main")

    collapse_button.MouseButton1Click:Connect(function()
        is_collapsed = not is_collapsed
        tab_segment.Visible = not is_collapsed
        collapse_button.Text = is_collapsed and "+" or "-"
        resize_window(true)
    end)

    local confirm_text = "Are you sure you wanna delete the script?"
    local confirm_hint = "click x again to confirm"
    local confirm_timeout = 3

    local close_button = Instance.new("TextButton")
    close_button.AutoButtonColor = false
    close_button.Text = "x"
    close_button.Font = gui_font
    close_button.TextSize = 13
    close_button.TextColor3 = theme.muted
    close_button.BackgroundColor3 = theme.panel
    close_button.BorderSizePixel = 0
    close_button.Size = UDim2.new(0, 22, 0, 22)
    close_button.Position = UDim2.new(1, -32, 0.5, -11)
    close_button.Parent = top_bar
    round(close_button, 6)

    local toast_width = text_service:GetTextSize(confirm_text, 12, gui_font, Vector2.new(1000, 16)).X + 28
    local toast_shown = UDim2.new(0.5, 0, 1, -24)
    local toast_hidden = UDim2.new(0.5, 0, 1, 80)

    local toast = Instance.new("Frame")
    toast.AnchorPoint = Vector2.new(0.5, 1)
    toast.Position = toast_hidden
    toast.Size = UDim2.new(0, toast_width, 0, 46)
    toast.BackgroundColor3 = theme.background
    toast.BorderSizePixel = 0
    toast.Parent = screen_gui
    round(toast, 10)
    outline(toast, theme.danger, 1)

    local toast_title = make_label(toast, confirm_text, 12, theme.text, gui_font)
    toast_title.Size = UDim2.new(1, -28, 0, 16)
    toast_title.Position = UDim2.new(0, 14, 0, 7)

    local toast_hint = make_label(toast, confirm_hint, 11, theme.muted)
    toast_hint.Size = UDim2.new(1, -28, 0, 14)
    toast_hint.Position = UDim2.new(0, 14, 0, 25)

    local is_confirming = false
    local confirm_token = 0

    local function set_confirming(state)
        is_confirming = state

        tween_service:Create(close_button, fast_tween, {
            BackgroundColor3 = state and theme.danger or theme.panel,
            TextColor3 = state and theme.white or theme.muted
        }):Play()

        tween_service:Create(toast, slow_tween, {
            Position = state and toast_shown or toast_hidden
        }):Play()
    end

    close_button.MouseButton1Click:Connect(function()
        confirm_token = confirm_token + 1

        if is_confirming then
            if api.onClose then
                pcall(api.onClose)
            end
            screen_gui:Destroy()
            return
        end

        set_confirming(true)

        local token = confirm_token
        task.delay(confirm_timeout, function()
            if token == confirm_token and is_confirming then
                set_confirming(false)
            end
        end)
    end)

    local is_dragging = false
    local drag_start = Vector2.new(0, 0)
    local start_position = main_frame.Position

    top_bar.InputBegan:Connect(function(input)
        local input_type = input.UserInputType
        if input_type == Enum.UserInputType.MouseButton1 or input_type == Enum.UserInputType.Touch then
            is_dragging = true
            drag_start = Vector2.new(input.Position.X, input.Position.Y)
            start_position = main_frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    is_dragging = false
                end
            end)
        end
    end)

    local drag_connection = user_input_service.InputChanged:Connect(function(input)
        if not is_dragging then
            return
        end

        local input_type = input.UserInputType
        if input_type == Enum.UserInputType.MouseMovement or input_type == Enum.UserInputType.Touch then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - drag_start

            main_frame.Position = UDim2.new(
                start_position.X.Scale,
                start_position.X.Offset + delta.X,
                start_position.Y.Scale,
                start_position.Y.Offset + delta.Y
            )
        end
    end)

    screen_gui.Destroying:Connect(function()
        drag_connection:Disconnect()
    end)

    return screen_gui
end

return create_gui