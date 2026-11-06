--[[
    HAVAC CORE v1.0.0
    Block A — Foundation + Window Shell
    
    Autor: Princesinho
    Target: Roblox Executor 100% UNC
    
    Esse bloco entrega a fundação visual completa:
      * Detecção de capabilities
      * Mount GUI defensivo
      * Engine de animação com cancelamento por chave
      * Sistema de temas (Havac/Void/Ember/Frost)
      * Janela com abertura em 3 camadas + border glint
      * Sidebar com stagger animation
      * Search box + minimize button
      * Footer com clock + uptime
      * Panic 11-passos + Unload seguro
    
    Blocos seguintes adicionam componentes e sistemas avançados.
]]

-- ============================================================================
-- SECTION 1: CAPABILITY DETECTION (100% UNC)
-- ============================================================================

local HAVAC = { version = "1.0.0" }
HAVAC._errors = {}
HAVAC._hooks  = { unload = {}, panic = {} }
HAVAC._locale = "pt-br"
HAVAC._theme  = "Havac"
HAVAC._bootAt = tick()

local Caps = {}
do
    Caps.genv        = type(getgenv) == "function" and getgenv() or _G
    Caps.gethui      = type(gethui) == "function"
    Caps.protect_gui = type(protect_gui) == "function"
    Caps.syn         = type(syn) == "table"
    Caps.syn_protect = Caps.syn and type(syn.protect_gui) == "function"
    Caps.writefile   = type(writefile) == "function"
    Caps.readfile    = type(readfile) == "function"
    Caps.isfile      = type(isfile) == "function"
    Caps.identify    = type(identifyexecutor) == "function"

    Caps.clipboard = setclipboard or (Caps.syn and syn.write_clipboard) or toclipboard

    local name, version
    if Caps.identify then
        local ok, n, v = pcall(identifyexecutor)
        if ok and type(n) == "string" and n ~= "" then name, version = n, v end
    end
    Caps.executorName = name or "Unknown"
    Caps.executorVer  = version and tostring(version) or nil
end

local function logError(context, err)
    local line = ("[%s] %s: %s"):format(os.date("%H:%M:%S"), tostring(context), tostring(err))
    table.insert(HAVAC._errors, line)
    warn(line)
end

-- ============================================================================
-- SECTION 2: SERVICES
-- ============================================================================

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local LocalPlayer      = Players.LocalPlayer

-- ============================================================================
-- SECTION 3: FONT HELPERS (com fallback defensivo)
-- ============================================================================

local function makeFont(family, weight)
    local ok, f = pcall(function()
        return Font.new(family, weight)
    end)
    if ok and f then return f end
    -- Fallback para Enum (versões antigas do Roblox)
    if weight == Enum.FontWeight.Bold then return Enum.Font.GothamBold end
    if weight == Enum.FontWeight.Medium then return Enum.Font.GothamMedium end
    return Enum.Font.Gotham
end

local F = {
    Bold    = makeFont("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    Medium  = makeFont("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
    Regular = makeFont("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
}

-- ============================================================================
-- SECTION 4: THEME SYSTEM
-- ============================================================================

local Theme = {}
Theme.presets = {
    Havac = {
        bg = { 8, 8, 10 }, surface = { 18, 18, 22 }, surfaceAlt = { 25, 24, 32 },
        primary = { 139, 92, 246 }, secondary = { 167, 139, 250 },
        text = { 245, 243, 255 }, muted = { 161, 161, 170 },
    },
    Void = {
        bg = { 4, 4, 8 }, surface = { 14, 10, 24 }, surfaceAlt = { 22, 16, 36 },
        primary = { 120, 80, 200 }, secondary = { 90, 60, 160 },
        text = { 230, 225, 245 }, muted = { 120, 110, 145 },
    },
    Ember = {
        bg = { 10, 6, 4 }, surface = { 20, 14, 10 }, surfaceAlt = { 30, 20, 14 },
        primary = { 245, 130, 60 }, secondary = { 255, 170, 100 },
        text = { 250, 240, 230 }, muted = { 170, 145, 125 },
    },
    Frost = {
        bg = { 4, 8, 12 }, surface = { 12, 18, 26 }, surfaceAlt = { 20, 28, 40 },
        primary = { 120, 200, 250 }, secondary = { 170, 220, 255 },
        text = { 235, 245, 255 }, muted = { 140, 160, 180 },
    },
}

local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end

local function derivePalette(spec)
    local bg, sf, sa = c3(spec.bg), c3(spec.surface), c3(spec.surfaceAlt)
    local pr, se, tx, mu = c3(spec.primary), c3(spec.secondary), c3(spec.text), c3(spec.muted)
    local p = {
        BgDeep     = bg,
        Surface    = sf,
        SurfaceAlt = sa,
        Sidebar    = bg:Lerp(sf, 0.55),
        Card       = sf,
        CardAlt    = sa,
        CardHover  = sa:Lerp(tx, 0.08),
        CardHeader = sa:Lerp(tx, 0.05),
        Border     = sf:Lerp(tx, 0.16),
        BorderLow  = sf:Lerp(tx, 0.08),
        Text       = tx,
        TextDim    = mu,
        TextMute   = mu:Lerp(bg, 0.5),
        Primary    = pr,
        PrimaryDim = pr:Lerp(bg, 0.25),
        Secondary  = se,
        Accent     = pr,
        AccentDim  = pr:Lerp(bg, 0.22),
        Success    = Color3.fromRGB(110, 220, 130),
        Warning    = Color3.fromRGB(240, 190, 110),
        Error      = Color3.fromRGB(240, 110, 130),
    }
    local order = { "BgDeep","Surface","SurfaceAlt","Sidebar","Card","CardAlt",
        "CardHover","CardHeader","Border","BorderLow","Text","TextDim","TextMute",
        "Primary","PrimaryDim","Secondary","Accent","AccentDim","Success","Warning","Error" }
    local seen = {}
    for _, k in ipairs(order) do
        local c = p[k]
        local r = math.floor(c.R * 255 + 0.5)
        local g = math.floor(c.G * 255 + 0.5)
        local b = math.floor(c.B * 255 + 0.5)
        while seen[r * 65536 + g * 256 + b] do
            b = (b + 1) % 256
            if b == 0 then g = (g + 1) % 256 end
            if b == 0 and g == 0 then r = (r + 1) % 256 end
        end
        seen[r * 65536 + g * 256 + b] = true
        p[k] = Color3.fromRGB(r, g, b)
    end
    p._order = order
    return p
end

Theme.active     = "Havac"
Theme.activeSpec = Theme.presets.Havac
Theme.Palette    = derivePalette(Theme.presets.Havac)

local T = setmetatable({}, { __index = function(_, k) return Theme.Palette[k] end })

function Theme.apply(name, root)
    local spec = Theme.presets[name]
    if not spec then return false end
    local oldPalette = Theme.Palette
    local newPalette = derivePalette(spec)
    Theme.active, Theme.activeSpec, Theme.Palette = name, spec, newPalette

    if not root then return true end

    local function id(c)
        return math.floor(c.R * 255 + 0.5) * 65536
             + math.floor(c.G * 255 + 0.5) * 256
             + math.floor(c.B * 255 + 0.5)
    end
    local map = {}
    for _, k in ipairs(oldPalette._order) do map[id(oldPalette[k])] = newPalette[k] end

    local i = 0
    for _, d in ipairs(root:GetDescendants()) do
        i = i + 1
        if d:IsA("GuiObject") then
            local bg = map[id(d.BackgroundColor3)]
            if bg then d.BackgroundColor3 = bg end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local tc = map[id(d.TextColor3)]
                if tc then d.TextColor3 = tc end
            end
        elseif d:IsA("UIStroke") then
            local sc = map[id(d.Color)]
            if sc then d.Color = sc end
        end
        if i % 1500 == 0 then task.wait() end
    end
    return true
end

-- ============================================================================
-- SECTION 5: ANIMATION ENGINE
-- ============================================================================

local Anim = { _active = {}, reduce = false }

Anim.easings = {
    smooth    = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
    gentle    = { Enum.EasingStyle.Sine,  Enum.EasingDirection.Out },
    soft      = { Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut },
    overshoot = { Enum.EasingStyle.Back,  Enum.EasingDirection.Out },
    enter     = { Enum.EasingStyle.Quint, Enum.EasingDirection.In  },
    linear    = { Enum.EasingStyle.Linear, Enum.EasingDirection.Out },
}

function Anim.tween(inst, props, duration, style, key)
    if not inst or not inst.Parent then return nil end
    duration = Anim.reduce and 0.01 or (duration or 0.2)
    local e = Anim.easings[style] or Anim.easings.smooth
    key = key or ("tween_" .. tostring(inst))

    if Anim._active[key] then
        pcall(function() Anim._active[key]:Cancel() end)
    end

    local tween = TweenService:Create(inst, TweenInfo.new(duration, e[1], e[2]), props)
    Anim._active[key] = tween
    tween:Play()
    tween.Completed:Connect(function()
        if Anim._active[key] == tween then Anim._active[key] = nil end
    end)
    return tween
end

function Anim.cancelAll()
    for k, tween in pairs(Anim._active) do
        pcall(function() tween:Cancel() end)
        Anim._active[k] = nil
    end
end

-- ============================================================================
-- SECTION 6: CONNECTION TRACKER
-- ============================================================================

local Connections = {}
local function Track(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end

-- ============================================================================
-- SECTION 7: LOCALE
-- ============================================================================

local Locale = {}
Locale.strings = {
    ["pt-br"] = {
        brand_name           = "HAVAC CORE",
        brand_sub            = "Core Premium",
        nav_home             = "Início",
        nav_settings         = "Configurações",
        hide_with            = "Ocultar com",
        search_placeholder   = "Buscar  (Ctrl+F)",
        welcome_header       = "Bem-vindo ao HAVAC CORE",
        welcome_sub          = "Fundação premium carregada.",
        status_executor      = "Executor",
        status_version       = "Versão",
        status_caps          = "Capacidades",
        status_next          = "Bloco A concluído. Componentes, Dynamic Island e Settings chegam nos próximos blocos.",
        status_no_errors     = "Nenhum erro capturado.",
        status_has_errors    = "Erros capturados",
        status_locale        = "Locale",
        status_theme         = "Tema",
        status_uptime        = "Sessão",
        footer_supported     = "Executor compatível.",
        footer_missing       = "Faltando: %s",
        footer_unknown       = "Executor não identificado.",
        cap_yes              = "presente",
        cap_no               = "ausente",
        no_config_file       = "Sem writefile (config não persiste)",
        with_config_file     = "Config persiste em disco",
    },
    ["en"] = {
        brand_name           = "HAVAC CORE",
        brand_sub            = "Premium Core",
        nav_home             = "Home",
        nav_settings         = "Settings",
        hide_with            = "Hide with",
        search_placeholder   = "Search  (Ctrl+F)",
        welcome_header       = "Welcome to HAVAC CORE",
        welcome_sub          = "Premium foundation loaded.",
        status_executor      = "Executor",
        status_version       = "Version",
        status_caps          = "Capabilities",
        status_next          = "Block A done. Components, Dynamic Island and Settings arrive next.",
        status_no_errors     = "No errors captured.",
        status_has_errors    = "Errors captured",
        status_locale        = "Locale",
        status_theme         = "Theme",
        status_uptime        = "Session",
        footer_supported     = "Compatible executor.",
        footer_missing       = "Missing: %s",
        footer_unknown       = "Executor not identified.",
        cap_yes              = "present",
        cap_no               = "absent",
        no_config_file       = "No writefile (config won't persist)",
        with_config_file     = "Config persists to disk",
    },
}

function Locale.T(key, ...)
    local t = Locale.strings[HAVAC._locale] or Locale.strings["pt-br"]
    local s = t[key] or Locale.strings["pt-br"][key] or tostring(key)
    if select("#", ...) > 0 then
        local ok, f = pcall(string.format, s, ...)
        if ok then return f end
    end
    return s
end

-- ============================================================================
-- SECTION 8: MOUNT GUI (cascata defensiva)
-- ============================================================================

local function mountGui(name)
    local sg = Instance.new("ScreenGui")
    sg.Name = name
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999

    local function try(parent, protect)
        if not parent then return false end
        local ok = pcall(function() sg.Parent = parent end)
        if not ok or not sg.Parent then return false end
        if protect then pcall(protect, sg) end
        return sg.Parent ~= nil
    end

    if Caps.gethui then
        local ok, hui = pcall(gethui)
        if ok and hui and try(hui, nil) then return sg end
    end
    if Caps.syn_protect then
        if try(CoreGui, syn.protect_gui) then return sg end
    end
    if Caps.protect_gui then
        if try(CoreGui, protect_gui) then return sg end
    end
    if try(CoreGui, nil) then return sg end

    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg and try(pg, nil) then
        logError("mount", "caiu para PlayerGui")
        return sg
    end
    logError("mount", "nenhum parent aceitou a ScreenGui")
    return sg
end

-- ============================================================================
-- SECTION 9: HELPER FUNCTIONS
-- ============================================================================

local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then inst[k] = v end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

local function Stroke(parent, color, thickness)
    return New("UIStroke", {
        Color = color or T.BorderLow,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function Padding(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft   = UDim.new(0, l or 0),
        PaddingRight  = UDim.new(0, r or 0),
        PaddingTop    = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function VList(parent, gap)
    return New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Parent = parent,
    })
end

local function HList(parent, gap, valign)
    return New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        VerticalAlignment = valign or Enum.VerticalAlignment.Center,
        Parent = parent,
    })
end

local KEY_SHORT = {
    RightControl = "RCtrl", LeftControl = "LCtrl",
    RightShift = "RShift", LeftShift = "LShift",
    RightAlt = "RAlt", LeftAlt = "LAlt",
    Return = "Enter", Backspace = "Bksp", Escape = "Esc",
    Insert = "Ins", Delete = "Del",
    PageUp = "PgUp", PageDown = "PgDn",
    Backquote = "`", None = "None",
    MouseButton2 = "RMB", MouseButton3 = "MMB",
}
local function keyShort(name) return KEY_SHORT[name] or tostring(name) end

-- ============================================================================
-- SECTION 10: WINDOW SHELL
-- ============================================================================

local Gui, Window, WindowScale, WindowStroke, WindowGlint
local Sidebar, Content, Header, Body, Footer, ResizeGrip, Dim
local windowOpen = false

local DEFAULT_W, DEFAULT_H = 820, 560
local SIDEBAR_W = 190
local MIN_W, MAX_W = 680, 1400
local MIN_H, MAX_H = 460, 900

local Config = { winX = 0, winY = 0, winW = DEFAULT_W, winH = DEFAULT_H }

local function buildShell()
    -- Dim (fundo escuro)
    Dim = New("Frame", {
        Name = "Dim",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 1,
        Parent = Gui,
    })

    -- Window principal
    Window = New("Frame", {
        Name = "HAVACWindow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H),
        BackgroundColor3 = T.BgDeep,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 3,
        Parent = Gui,
    })
        Corner(Window, 16)

    -- Border separado (não sofre do bug ClipsDescendants + UICorner)
    local WindowBorder = New("Frame", {
        Name = "HAVAC_Border",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 50,
        Parent = Gui,
    })
    Corner(WindowBorder, 16)
    WindowStroke = Stroke(WindowBorder, Color3.new(1, 1, 1), 1)
    WindowGlint = New("UIGradient", { Parent = WindowStroke })
    WindowGlint.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T.Border),
        ColorSequenceKeypoint.new(0.4, T.Border),
        ColorSequenceKeypoint.new(0.5, T.Accent),
        ColorSequenceKeypoint.new(0.6, T.Border),
        ColorSequenceKeypoint.new(1, T.Border),
    })
    local WindowBorderScale = New("UIScale", { Scale = 1, Parent = WindowBorder })
    HAVAC._border = WindowBorder
    HAVAC._borderScale = WindowBorderScale

    -- Sincroniza border com window + gira glint
    Track(RunService.RenderStepped:Connect(function()
        if not Window.Visible then
            if WindowBorder.Visible then WindowBorder.Visible = false end
            return
        end
        if not WindowBorder.Visible then WindowBorder.Visible = true end
        WindowBorder.Position = Window.Position
        WindowBorder.Size = Window.Size
        WindowBorderScale.Scale = WindowScale.Scale
        WindowGlint.Rotation = (os.clock() * 35) % 360
    end))

    WindowScale = New("UIScale", { Scale = 1, Parent = Window })

    -- SIDEBAR
    Sidebar = New("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = T.Sidebar,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = Window,
    })
    -- Divisória vertical
    New("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })

    -- Brand
    local brand = New("Frame", {
        Size = UDim2.new(1, 0, 0, 68),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })
    Padding(brand, 16, 12, 18, 12)

    local brandTile = New("Frame", {
        Size = UDim2.new(0, 34, 0, 34),
        BackgroundColor3 = T.Primary,
        BorderSizePixel = 0,
        Parent = brand,
    })
    Corner(brandTile, 10)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "H",
        TextColor3 = T.BgDeep,
        FontFace = F.Bold,
        TextSize = 18,
        Parent = brandTile,
    })

    local brandName = New("TextLabel", {
        Position = UDim2.new(0, 46, 0, 6),
        Size = UDim2.new(1, -46, 0, 16),
        BackgroundTransparency = 1,
        Text = Locale.T("brand_name"),
        TextColor3 = T.Text,
        FontFace = F.Bold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = brand,
    })

    local brandSub = New("TextLabel", {
        Position = UDim2.new(0, 46, 0, 24),
        Size = UDim2.new(1, -46, 0, 14),
        BackgroundTransparency = 1,
        Text = Locale.T("brand_sub"),
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = brand,
    })

    -- Nav holder
    local navHolder = New("Frame", {
        Position = UDim2.new(0, 10, 0, 76),
        Size = UDim2.new(1, -20, 1, -176),
        BackgroundTransparency = 1,
        Parent = Sidebar,
    })
    VList(navHolder, 4)

    -- Nav items (2 iniciais, mais virão do Bloco B)
    local function createNavItem(text, order)
        local btn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = T.Card,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            LayoutOrder = order,
            Parent = navHolder,
        })
        Corner(btn, 9)

        -- Accent bar (à esquerda, oculta por padrão)
        local accentBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 16),
            BackgroundColor3 = T.Accent,
            BorderSizePixel = 0,
            Parent = btn,
        })
        Corner(accentBar, 2)

        -- Ícone (ponto)
        local dot = New("Frame", {
            Position = UDim2.new(0, 16, 0.5, -4),
            Size = UDim2.new(0, 8, 0, 8),
            BackgroundColor3 = T.TextDim,
            BorderSizePixel = 0,
            Parent = btn,
        })
        Corner(dot, 4)

        -- Label
        local label = New("TextLabel", {
            Position = UDim2.new(0, 34, 0, 0),
            Size = UDim2.new(1, -40, 1, 0),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = T.TextDim,
            FontFace = F.Medium,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = btn,
        })

        btn.MouseEnter:Connect(function()
            Anim.tween(btn, { BackgroundTransparency = 0.75 }, 0.15, "gentle", "nav_" .. tostring(btn))
        end)
        btn.MouseLeave:Connect(function()
            Anim.tween(btn, { BackgroundTransparency = 1 }, 0.15, "gentle", "nav_" .. tostring(btn))
        end)

        return { btn = btn, accent = accentBar, dot = dot, label = label }
    end

    local navHome     = createNavItem(Locale.T("nav_home"), 1)
    local navSettings = createNavItem(Locale.T("nav_settings"), 2)

    -- Item ativo (Home)
    navHome.accent.Size = UDim2.new(0, 3, 0, 16)
    navHome.btn.BackgroundTransparency = 0
    navHome.dot.BackgroundColor3 = T.Accent
    navHome.label.TextColor3 = T.Text

    -- User card (embaixo)
    local userCard = New("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -12),
        Size = UDim2.new(1, -20, 0, 60),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Parent = Sidebar,
    })
    Corner(userCard, 10)
    Stroke(userCard, T.BorderLow, 1)
    Padding(userCard, 10, 10, 10, 10)

    local avatarHolder = New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -17),
        Size = UDim2.new(0, 34, 0, 34),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Parent = userCard,
    })
    Corner(avatarHolder, 17)
    Stroke(avatarHolder, T.Border, 1)

    local avatarImg = New("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = "",
        Parent = avatarHolder,
    })
    Corner(avatarImg, 17)

    -- Online dot pulsante
    local onlineDot = New("Frame", {
        Position = UDim2.new(0, 25, 0, 25),
        Size = UDim2.new(0, 9, 0, 9),
        BackgroundColor3 = T.Success,
        BorderSizePixel = 0,
        Parent = userCard,
    })
    Corner(onlineDot, 5)
    Stroke(onlineDot, T.Card, 2)
    -- Anel pulsante
    do
        local ring = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = T.Success,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Parent = onlineDot,
        })
        Corner(ring, 100)
        TweenService:Create(ring,
            TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
            { Size = UDim2.new(2.6, 0, 2.6, 0), BackgroundTransparency = 1 }):Play()
    end

    -- Nome e handle
    New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 4),
        Size = UDim2.new(1, -60, 0, 16),
        BackgroundTransparency = 1,
        Text = LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or "Player",
        TextColor3 = T.Text,
        FontFace = F.Medium,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = userCard,
    })
    New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 22),
        Size = UDim2.new(1, -60, 0, 14),
        BackgroundTransparency = 1,
        Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "",
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = userCard,
    })

    -- Chevron (desliza no hover)
    local chevron = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Text = "›",
        TextColor3 = T.TextDim,
        FontFace = F.Medium,
        TextSize = 16,
        Parent = userCard,
    })
    userCard.MouseEnter:Connect(function()
        Anim.tween(userCard, { BackgroundColor3 = T.CardHover }, 0.15, "gentle", "uc")
        Anim.tween(chevron, { Position = UDim2.new(1, -1, 0.5, 0) }, 0.15, "gentle", "chev")
    end)
    userCard.MouseLeave:Connect(function()
        Anim.tween(userCard, { BackgroundColor3 = T.Card }, 0.15, "gentle", "uc")
        Anim.tween(chevron, { Position = UDim2.new(1, -4, 0.5, 0) }, 0.15, "gentle", "chev")
    end)

    -- Carrega avatar async
    task.spawn(function()
        if not LocalPlayer then return end
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and type(url) == "string" and url ~= "" then
            if avatarImg.Parent then avatarImg.Image = url end
        end
    end)

    -- CONTENT (header + body + footer)
    Content = New("Frame", {
        Name = "Content",
        Position = UDim2.new(0, SIDEBAR_W, 0, 0),
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        BackgroundColor3 = T.BgDeep,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = Window,
    })

    -- HEADER
    Header = New("Frame", {
        Size = UDim2.new(1, 0, 0, 64),
        BackgroundTransparency = 1,
        Parent = Content,
    })
    Padding(Header, 24, 20, 18, 10)

    local headerDot = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = Header,
    })
    Corner(headerDot, 3)

    local headerTitle = New("TextLabel", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 24, 0.5, 0),
        Size = UDim2.new(0.6, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = Locale.T("welcome_header"),
        TextColor3 = T.Text,
        FontFace = F.Bold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Header,
    })

    -- Search box (expande no focus)
    local searchBox = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -48, 0.5, 0),
        Size = UDim2.new(0, 190, 0, 32),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Parent = Header,
    })
    Corner(searchBox, 9)
    local searchStroke = Stroke(searchBox, T.BorderLow, 1)
    local searchIcon = New("TextLabel", {
        Position = UDim2.new(0, 12, 0.5, -7),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Text = "🔍",
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 11,
        Parent = searchBox,
    })
    local searchInput = New("TextBox", {
        Position = UDim2.new(0, 34, 0, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        PlaceholderText = Locale.T("search_placeholder"),
        PlaceholderColor3 = T.TextDim,
        TextColor3 = T.Text,
        FontFace = F.Regular,
        TextSize = 12,
        Text = "",
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = searchBox,
    })
    searchInput.Focused:Connect(function()
        Anim.tween(searchBox, { Size = UDim2.new(0, 230, 0, 32) }, 0.3, "smooth", "sb")
        Anim.tween(searchStroke, { Color = T.Accent }, 0.15, "gentle", "sbs")
        Anim.tween(searchIcon, { TextColor3 = T.Text }, 0.15, "gentle", "sbi")
    end)
    searchInput.FocusLost:Connect(function()
        Anim.tween(searchBox, { Size = UDim2.new(0, 190, 0, 32) }, 0.3, "smooth", "sb")
        Anim.tween(searchStroke, { Color = T.BorderLow }, 0.2, "gentle", "sbs")
        Anim.tween(searchIcon, { TextColor3 = T.TextDim }, 0.2, "gentle", "sbi")
    end)

    -- Minimize button (ícone rotaciona no hover)
    local minBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = Header,
    })
    Corner(minBtn, 9)
    Stroke(minBtn, T.BorderLow, 1)
    local minIcon = New("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = T.TextDim,
        FontFace = F.Bold,
        TextSize = 14,
        Parent = minBtn,
    })
    minBtn.MouseEnter:Connect(function()
        Anim.tween(minBtn, { BackgroundColor3 = T.CardHover }, 0.15, "gentle", "mb")
        Anim.tween(minIcon, { TextColor3 = T.Text, Rotation = 90 }, 0.3, "smooth", "mi")
    end)
    minBtn.MouseLeave:Connect(function()
        Anim.tween(minBtn, { BackgroundColor3 = T.Card }, 0.15, "gentle", "mb")
        Anim.tween(minIcon, { TextColor3 = T.TextDim, Rotation = 0 }, 0.3, "smooth", "mi")
    end)

    -- BODY
    Body = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 64),
        Size = UDim2.new(1, 0, 1, -94),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = Content,
    })
    Padding(Body, 24, 20, 4, 24)
    VList(Body, 14)

    -- FOOTER (com clock + uptime + status)
    Footer = New("Frame", {
        Position = UDim2.new(0, 0, 1, -30),
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        Parent = Content,
    })
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = Footer,
    })
    Padding(Footer, 20, 16, 0, 0)

    -- Status dot (verde = compatível)
    local footerDot = New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -4),
        Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = T.Success,
        BorderSizePixel = 0,
        Parent = Footer,
    })
    Corner(footerDot, 4)

    New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0, 100, 1, 0),
        BackgroundTransparency = 1,
        Text = Caps.executorName,
        TextColor3 = T.Text,
        FontFace = F.Bold,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Footer,
    })

    local footerMsg = New("TextLabel", {
        Position = UDim2.new(0, 120, 0, 0),
        Size = UDim2.new(1, -400, 1, 0),
        BackgroundTransparency = 1,
        Text = Locale.T("footer_supported"),
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Footer,
    })

    -- Clock + uptime (à direita, antes do hide pill)
    local clockLbl = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -140, 0, 0),
        Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Footer,
    })

    -- "Ocultar com" + key pill
    New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -66, 0, 0),
        Size = UDim2.new(0, 90, 1, 0),
        BackgroundTransparency = 1,
        Text = Locale.T("hide_with"),
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = Footer,
    })
    local keyPill = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 56, 0, 22),
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Parent = Footer,
    })
    Corner(keyPill, 6)
    Stroke(keyPill, T.BorderLow, 1)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "RCtrl",
        TextColor3 = T.Text,
        FontFace = F.Medium,
        TextSize = 10,
        Parent = keyPill,
    })

    -- Atualiza clock a cada segundo
    Track(task.spawn(function()
        while Gui and Gui.Parent do
            local uptime = math.floor(tick() - HAVAC._bootAt)
            local uptime_str = uptime < 60 and (uptime .. "s")
                or uptime < 3600 and (math.floor(uptime/60) .. "m")
                or (math.floor(uptime/3600) .. "h")
            clockLbl.Text = os.date("%H:%M") .. "  ·  " .. uptime_str
            task.wait(1)
        end
    end))

    -- RESIZE GRIP
    ResizeGrip = New("TextButton", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 95,
        Parent = Window,
    })
    local gripDots = {}
    for _, d in ipairs({ {10,2}, {6,6}, {10,6}, {2,10}, {6,10}, {10,10} }) do
        local dot = New("Frame", {
            Position = UDim2.fromOffset(d[1] - 1, d[2] - 1),
            Size = UDim2.fromOffset(2, 2),
            BackgroundColor3 = T.TextMute,
            BorderSizePixel = 0,
            ZIndex = 96,
            Parent = ResizeGrip,
        })
        gripDots[#gripDots + 1] = dot
    end

    return {
        nav = { home = navHome, settings = navSettings },
        search = { box = searchBox, input = searchInput },
        minBtn = minBtn,
        clock = clockLbl,
    }
end

-- ============================================================================
-- SECTION 11: STATUS CARD (para o corpo não ficar vazio)
-- ============================================================================

local function buildStatusCard()
    local card = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        Parent = Body,
    })
    Corner(card, 14)
    Stroke(card, T.BorderLow, 1)
    Padding(card, 24, 24, 22, 22)
    VList(card, 14)

    -- Header com barra de gradiente
    local header = New("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = card,
    })
    local accentBar = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 20),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = header,
    })
    Corner(accentBar, 2)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.Accent),
            ColorSequenceKeypoint.new(1, T.Secondary),
        }),
        Rotation = 90,
        Parent = accentBar,
    })
    New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -16, 1, 0),
        BackgroundTransparency = 1,
        Text = Locale.T("welcome_header"),
        TextColor3 = T.Text,
        FontFace = F.Bold,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = header,
    })

    -- Subtitle
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = Locale.T("welcome_sub"),
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    -- Divider
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = card,
    })

    -- Section label
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = Locale.T("status_executor"):upper(),
        TextColor3 = T.TextMute,
        FontFace = F.Bold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    -- Rows de informação
    local function infoRow(label, value, valueColor)
        local row = New("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Parent = card,
        })
        New("TextLabel", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0.4, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = T.TextDim,
            FontFace = F.Regular,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
        New("TextLabel", {
            Position = UDim2.new(0.4, 0, 0, 0),
            Size = UDim2.new(0.6, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = value,
            TextColor3 = valueColor or T.Text,
            FontFace = F.Medium,
            TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = row,
        })
    end

    infoRow("Executor", Caps.executorName .. (Caps.executorVer and (" v" .. Caps.executorVer) or ""))
    infoRow(Locale.T("status_version"), HAVAC.version)
    infoRow(Locale.T("status_locale"), HAVAC._locale:upper())
    infoRow(Locale.T("status_theme"), HAVAC._theme)

    -- Divider
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = card,
    })

    -- Capabilities
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = Locale.T("status_caps"):upper(),
        TextColor3 = T.TextMute,
        FontFace = F.Bold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    for _, p in ipairs({
        { "gethui", Caps.gethui },
        { "protect_gui", Caps.protect_gui },
        { "writefile", Caps.writefile },
        { "readfile", Caps.readfile },
        { "clipboard", Caps.clipboard ~= nil },
        { "identifyexecutor", Caps.identify },
    }) do
        infoRow(p[1], Locale.T(p[2] and "cap_yes" or "cap_no"),
            p[2] and T.Success or T.TextMute)
    end

    -- Divider
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = card,
    })

    -- Next block note
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = Locale.T("status_next"),
        TextColor3 = T.TextDim,
        FontFace = F.Regular,
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })

    -- Config persistence status
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = Caps.writefile and Locale.T("with_config_file") or Locale.T("no_config_file"),
        TextColor3 = Caps.writefile and T.Success or T.TextMute,
        FontFace = F.Regular,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })

    return card
end

-- ============================================================================
-- SECTION 12: WINDOW OPEN/CLOSE ANIMATION
-- ============================================================================

local function computeScale()
    local vp = Gui and Gui.AbsoluteSize or Vector2.new(1920, 1080)
    if vp.X <= 0 or vp.Y <= 0 then return 1 end
    local sx = (vp.X - 40) / (Config.winW or DEFAULT_W)
    local sy = (vp.Y - 40) / (Config.winH or DEFAULT_H)
    return math.max(0.35, math.min(1, sx, sy))
end

local function openWindow()
    if windowOpen or not Window then return end
    windowOpen = true

    Dim.Visible = true
    Dim.BackgroundTransparency = 1
    Anim.tween(Dim, { BackgroundTransparency = 0.55 }, 0.3, "gentle", "dim")

    local scale = computeScale()
    local x = Config.winX or 0
    local y = Config.winY or 0

    Window.Visible = true
    Window.Position = UDim2.new(0.5, x, 0.5, y + 26)
    Window.BackgroundTransparency = 1
    WindowStroke.Transparency = 1
    WindowScale.Scale = scale * 0.92
    Sidebar.BackgroundTransparency = 1

    -- 3 camadas simultâneas: scale + slide + fade
    Anim.tween(WindowScale, { Scale = scale }, 0.55, "overshoot", "win_scale")
    Anim.tween(Window, { Position = UDim2.new(0.5, x, 0.5, y) }, 0.55, "smooth", "win_pos")
    Anim.tween(Window, { BackgroundTransparency = 0 }, 0.3, "gentle", "win_bg")
    Anim.tween(WindowStroke, { Transparency = 0 }, 0.3, "gentle", "win_stroke")
    task.delay(0.05, function()
        if windowOpen then
            Anim.tween(Sidebar, { BackgroundTransparency = 0 }, 0.35, "gentle", "sb_bg")
        end
    end)
end

local function closeWindow()
    if not windowOpen or not Window then return end
    windowOpen = false
    local s = WindowScale.Scale

    Anim.tween(WindowScale, { Scale = s * 0.95 }, 0.25, "enter", "win_scale")
    Anim.tween(Window, { BackgroundTransparency = 1 }, 0.25, "gentle", "win_bg")
    Anim.tween(Dim, { BackgroundTransparency = 1 }, 0.25, "gentle", "dim")

    task.delay(0.26, function()
        if not windowOpen and Window then
            Window.Visible = false
            Dim.Visible = false
        end
    end)
end

local function toggleWindow()
    if windowOpen then closeWindow() else openWindow() end
end

-- ============================================================================
-- SECTION 13: DRAG + RESIZE
-- ============================================================================

local function hookDrag(handle)
    if not handle then return end
    local dragging, dragStart, dragOrigin, ghost

    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end

        dragging = true
        dragStart = input.Position
        dragOrigin = Window.Position

        -- Ghost (outline branco tracejado)
        ghost = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = Window.Position,
            Size = UDim2.fromOffset(Window.AbsoluteSize.X, Window.AbsoluteSize.Y),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.94,
            BorderSizePixel = 0,
            ZIndex = 80,
            Parent = Gui,
        })
        Corner(ghost, 16)
        New("UIStroke", {
            Color = Color3.new(1, 1, 1),
            Thickness = 2,
            Transparency = 0.12,
            Parent = ghost,
        })

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and dragging then
                dragging = false
                if ghost then
                    local g = ghost; ghost = nil
                    Anim.tween(Window, { Position = g.Position }, 0.22, "smooth", "drag_end")
                    g:Destroy()
                    Config.winX = Window.Position.X.Offset
                    Config.winY = Window.Position.Y.Offset
                end
            end
        end)
    end)

    Track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            local pos = UDim2.new(
                dragOrigin.X.Scale, dragOrigin.X.Offset + d.X,
                dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y
            )
            if ghost then ghost.Position = pos else Window.Position = pos end
        end
    end))
end

local function hookResize()
    if not ResizeGrip then return end
    local resizing, resizeStart, resizeOrigin

    local function tint(c)
        for _, dot in ipairs(ResizeGrip:GetChildren()) do
            if dot:IsA("Frame") then
                Anim.tween(dot, { BackgroundColor3 = c }, 0.15, "gentle", "grip_" .. tostring(dot))
            end
        end
    end

    ResizeGrip.MouseEnter:Connect(function()
        if not resizing then tint(T.Text) end
    end)
    ResizeGrip.MouseLeave:Connect(function()
        if not resizing then tint(T.TextMute) end
    end)

    ResizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        resizing = true
        resizeStart = input.Position
        resizeOrigin = Window.Size
        tint(T.Accent)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and resizing then
                resizing = false
                tint(T.TextMute)
                Config.winW = Window.Size.X.Offset
                Config.winH = Window.Size.Y.Offset
            end
        end)
    end)

    Track(UserInputService.InputChanged:Connect(function(input)
        if not resizing then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - resizeStart
        local sc = math.max(WindowScale.Scale, 0.01)
        local w = math.clamp(resizeOrigin.X.Offset + d.X / sc, MIN_W, MAX_W)
        local h = math.clamp(resizeOrigin.Y.Offset + d.Y / sc, MIN_H, MAX_H)
        Window.Size = UDim2.new(0, w, 0, h)
    end))
end

-- ============================================================================
-- SECTION 14: PANIC / UNLOAD
-- ============================================================================

local function sweepOrphans()
    local parents = { game:GetService("CoreGui") }
    local ok, hui = pcall(function()
        return type(gethui) == "function" and gethui() or nil
    end)
    if ok and hui then table.insert(parents, hui) end
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(parents, pg) end
    for _, p in ipairs(parents) do
        if p then
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("ScreenGui") and type(c.Name) == "string"
                   and c.Name:sub(1, 10) == "HAVAC_CORE" and c ~= Gui then
                    pcall(function() c:Destroy() end)
                end
            end
        end
    end
end

function HAVAC.onPanic(fn)  table.insert(HAVAC._hooks.panic,  fn) end
function HAVAC.onUnload(fn) table.insert(HAVAC._hooks.unload, fn) end

function HAVAC.panic()
    for _, fn in ipairs(HAVAC._hooks.panic) do pcall(fn) end
    Anim.cancelAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    if Gui then pcall(function() Gui:Destroy() end); Gui = nil end
    sweepOrphans()
end

function HAVAC.unload()
    for _, fn in ipairs(HAVAC._hooks.unload) do pcall(fn) end
    HAVAC.panic()
end

-- ============================================================================
-- SECTION 15: PUBLIC API
-- ============================================================================

function HAVAC.open()   if Window then openWindow()  end end
function HAVAC.close()  if Window then closeWindow() end end
function HAVAC.toggle() toggleWindow() end

function HAVAC.setLocale(code)
    if not Locale.strings[code] then return false end
    HAVAC._locale = code
    return true
end

function HAVAC.getLocale() return HAVAC._locale end

function HAVAC.setTheme(name)
    if not Theme.presets[name] then return false end
    HAVAC._theme = name
    Theme.apply(name, Gui)
    return true
end

function HAVAC.getTheme() return HAVAC._theme end

function HAVAC.diag()
    local lines = {
        "=== HAVAC CORE DIAGNOSTICS ===",
        "Version: " .. HAVAC.version,
        "Time:    " .. os.date("%Y-%m-%d %H:%M:%S"),
        "Uptime:  " .. math.floor(tick() - HAVAC._bootAt) .. "s",
        "",
        "Executor: " .. Caps.executorName .. (Caps.executorVer and (" v" .. Caps.executorVer) or ""),
        "Locale:   " .. HAVAC._locale,
        "Theme:    " .. HAVAC._theme,
        "",
        "Capabilities:",
        ("  gethui              %s"):format(tostring(Caps.gethui)),
        ("  protect_gui         %s"):format(tostring(Caps.protect_gui)),
        ("  writefile           %s"):format(tostring(Caps.writefile)),
        ("  readfile            %s"):format(tostring(Caps.readfile)),
        ("  clipboard           %s"):format(tostring(Caps.clipboard ~= nil)),
        ("  identifyexecutor    %s"):format(tostring(Caps.identify)),
        "",
        "Gui:      " .. tostring(Gui and Gui.Parent and Gui.Parent.Name or "nil"),
        "Window:   " .. tostring(Window and Window.Visible or "nil"),
        "",
        "Errors:   " .. (#HAVAC._errors > 0 and (#HAVAC._errors .. " captured") or "none"),
    }
    for _, e in ipairs(HAVAC._errors) do table.insert(lines, "  " .. e) end
    table.insert(lines, "")
    table.insert(lines, "=== END ===")
    local text = table.concat(lines, "\n")
    print(text)
    return text
end

-- ============================================================================
-- SECTION 16: BOOT
-- ============================================================================

Gui = mountGui("HAVAC_CORE_" .. tostring(math.random(1e6, 9e6)))

local buildOk, buildErr = pcall(function()
    local refs = buildShell()

    -- Hooks
    hookDrag(refs.nav.home.btn)  -- arrastar pelo brand também
    hookResize()

    -- Minimize
    refs.minBtn.MouseButton1Click:Connect(closeWindow)

    -- Build status card
    buildStatusCard()

    -- Stagger animation: itens da sidebar entram da esquerda
    for i, item in ipairs({ refs.nav.home, refs.nav.settings }) do
        item.label.Position = UDim2.new(0, 56, 0, 0)
        item.label.TextTransparency = 1
        task.delay(0.15 + i * 0.06, function()
            Anim.tween(item.label, { Position = UDim2.new(0, 34, 0, 0), TextTransparency = 0 }, 0.45, "smooth", "stagger_" .. i)
        end)
    end
end)
if not buildOk then
    logError("shell", buildErr)
end

-- Auto open
task.delay(0.35, function()
    if Window then openWindow() end
end)

-- Log de boot
task.delay(1.2, function()
    print(("[HAVAC CORE v%s] Bloco A carregado. Executor: %s"):format(HAVAC.version, Caps.executorName))
end)

HAVAC._internal = {
    Gui = Gui, Window = Window, Sidebar = Sidebar, Content = Content,
    Body = Body, Header = Header, Footer = Footer,
    T = T, F = F, Anim = Anim, Track = Track, Theme = Theme,
    New = New, Corner = Corner, Stroke = Stroke, Padding = Padding,
    VList = VList, HList = HList, keyShort = keyShort,
    Locale = Locale, Caps = Caps,
    c3 = c3, derivePalette = derivePalette,
}
_G.HAVAC = HAVAC
return HAVAC
