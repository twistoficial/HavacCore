--[[
    HAVAC CORE v1.0.0 — Consolidado
    Author: Princesinho
    
    Load:    local HAVAC = loadstring(game:HttpGet("URL_DO_GIST"))()
    Usage:   HAVAC.showcase()        -- demonstrate every component
             HAVAC.example()         -- cheat-menu demo
             HAVAC.open() / HAVAC.close() / HAVAC.toggle()
             HAVAC.setTheme("Ember") -- Havac | Void | Ember | Frost
             HAVAC.setLocale("en")   -- pt-br | en | es
             HAVAC.panic()           -- emergency teardown
             HAVAC.unload()          -- full cleanup, safe to reload
]]

-- ============================================================================
-- BLOCK 1: FOUNDATION
-- ============================================================================

local VERSION = "1.0.0"
local HAVAC = {
    version = VERSION,
    _hooks  = { unload = {}, panic = {} },
    _errors = {},
}

-- ---- 1.1 CAPABILITY DETECTION ----
local Caps = {}
do
    local ok, genv = pcall(function()
        return (type(getgenv) == "function" and getgenv()) or _G
    end)
    Caps.genv = ok and genv or _G
    Caps.getgenv         = type(getgenv) == "function"
    Caps.gethui          = type(gethui) == "function"
    Caps.protect_gui     = type(protect_gui) == "function"
    Caps.syn             = type(syn) == "table"
    Caps.syn_protect_gui = Caps.syn and type(syn.protect_gui) == "function"
    Caps.writefile       = type(writefile) == "function"
    Caps.readfile        = type(readfile) == "function"
    Caps.isfile          = type(isfile) == "function"
    Caps.isfolder        = type(isfolder) == "function"
    Caps.makefolder      = type(makefolder) == "function"
    Caps.delfile         = type(delfile) == "function"
    Caps.listfiles       = type(listfiles) == "function"
    Caps.loadstring      = type(loadstring) == "function"
    Caps.identifyexecutor = type(identifyexecutor) == "function"
    Caps.getexecutorname  = type(getexecutorname) == "function"
    Caps.setclipboard     = type(setclipboard) == "function"
    Caps.toclipboard      = type(toclipboard) == "function"
    Caps.syn_clipboard    = Caps.syn and type(syn.write_clipboard) == "function"
    if Caps.setclipboard then Caps.clipboard = setclipboard
    elseif Caps.syn_clipboard then Caps.clipboard = syn.write_clipboard
    elseif Caps.toclipboard then Caps.clipboard = toclipboard end
    local name, version
    if Caps.identifyexecutor then
        local o, n, v = pcall(identifyexecutor)
        if o and type(n) == "string" and n ~= "" then name, version = n, v end
    end
    Caps.executorName    = name or "Unknown"
    Caps.executorVersion = version and tostring(version) or nil
    local missing = {}
    for _, k in ipairs({ "gethui", "writefile", "readfile", "isfile", "clipboard" }) do
        if not Caps[k] then missing[#missing + 1] = k end
    end
    Caps.missing = missing
end

-- ---- 1.2 SERVICES ----
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local LocalPlayer      = Players.LocalPlayer

local function logError(context, err)
    local line = ("[%s] %s: %s"):format(os.date("%H:%M:%S"), tostring(context), tostring(err))
    table.insert(HAVAC._errors, line)
    warn(line)
end

-- ---- 1.3 LOCALE (PT-BR default) ----
local Locale = {}
Locale.strings = {
    ["pt-br"] = {
        brand_name = "HAVAC CORE", brand_subtitle = "Núcleo Beta",
        nav_status = "Status", welcome_header = "Bem-vindo ao HAVAC CORE",
        welcome_subtitle = "Fundação instalada com sucesso.",
        hide_hint = "Ocultar com",
        footer_supported = "Executor compatível com esta interface.",
        footer_missing = "Faltando: %s. Alguns recursos podem não funcionar.",
        footer_unknown = "Executor não identificado. Recursos podem variar.",
        status_executor = "Executor", status_version = "Versão do HAVAC",
        status_caps = "Capacidades detectadas", status_errors = "Erros durante a inicialização",
        status_none = "Nenhum erro.",
        status_next = "Biblioteca completa carregada.",
        toggle_hint = "Pressione %s para mostrar ou ocultar.",
        panic_done = "Pânico acionado. Interface removida.",
        cap_present = "presente", cap_absent = "ausente",
        unload_done = "Biblioteca descarregada.",
    },
    ["en"] = {
        brand_name = "HAVAC CORE", brand_subtitle = "Core Beta",
        nav_status = "Status", welcome_header = "Welcome to HAVAC CORE",
        welcome_subtitle = "Foundation installed successfully.",
        hide_hint = "Hide with",
        footer_supported = "Executor compatible with this interface.",
        footer_missing = "Missing: %s. Some features may not work.",
        footer_unknown = "Executor not identified. Features may vary.",
        status_executor = "Executor", status_version = "HAVAC version",
        status_caps = "Detected capabilities", status_errors = "Errors during startup",
        status_none = "No errors.",
        status_next = "Full library loaded.",
        toggle_hint = "Press %s to show or hide.",
        panic_done = "Panic triggered. UI removed.",
        cap_present = "present", cap_absent = "absent",
        unload_done = "Library unloaded.",
    },
    ["es"] = {
        brand_name = "HAVAC CORE", brand_subtitle = "Núcleo Beta",
        nav_status = "Estado", welcome_header = "Bienvenido a HAVAC CORE",
        welcome_subtitle = "Fundación instalada correctamente.",
        hide_hint = "Ocultar con",
        footer_supported = "Ejecutor compatible con esta interfaz.",
        footer_missing = "Faltan: %s. Algunas funciones pueden fallar.",
        footer_unknown = "Ejecutor no identificado. Las funciones pueden variar.",
        status_executor = "Ejecutor", status_version = "Versión de HAVAC",
        status_caps = "Capacidades detectadas", status_errors = "Errores durante el arranque",
        status_none = "Sin errores.",
        status_next = "Biblioteca completa cargada.",
        toggle_hint = "Pulsa %s para mostrar u ocultar.",
        panic_done = "Pánico activado. Interfaz eliminada.",
        cap_present = "presente", cap_absent = "ausente",
        unload_done = "Biblioteca descargada.",
    },
}
Locale.current = "pt-br"
function Locale.T(key, ...)
    local t = Locale.strings[Locale.current] or Locale.strings["pt-br"]
    local s = t[key] or Locale.strings["pt-br"][key] or tostring(key)
    if select("#", ...) > 0 then
        local ok, f = pcall(string.format, s, ...)
        if ok then return f end
    end
    return s
end
Locale.targets = {}
function Locale.register(el, key, args)
    if not el or not key then return end
    table.insert(Locale.targets, { el = el, key = key, args = args or {} })
    el.Text = Locale.T(key, table.unpack(args or {}))
end
function Locale.reapply()
    for _, t in ipairs(Locale.targets) do
        if t.el and t.el.Parent then
            t.el.Text = Locale.T(t.key, table.unpack(t.args))
        end
    end
end

-- ---- 1.4 THEME ----
local Theme = {}
Theme.presets = {
    Havac = { label = "HAVAC",
        bg = { 8, 8, 10 }, surface = { 18, 18, 22 }, surfaceAlt = { 25, 24, 32 },
        primary = { 139, 92, 246 }, secondary = { 167, 139, 250 },
        text = { 245, 243, 255 }, muted = { 161, 161, 170 } },
    Void = { label = "Void",
        bg = { 4, 4, 8 }, surface = { 14, 10, 24 }, surfaceAlt = { 22, 16, 36 },
        primary = { 139, 92, 246 }, secondary = { 90, 60, 180 },
        text = { 230, 225, 245 }, muted = { 120, 110, 145 } },
    Ember = { label = "Ember",
        bg = { 10, 6, 4 }, surface = { 20, 14, 10 }, surfaceAlt = { 30, 20, 14 },
        primary = { 245, 130, 60 }, secondary = { 255, 170, 100 },
        text = { 250, 240, 230 }, muted = { 170, 145, 125 } },
    Frost = { label = "Frost",
        bg = { 4, 8, 12 }, surface = { 12, 18, 26 }, surfaceAlt = { 20, 28, 40 },
        primary = { 120, 200, 250 }, secondary = { 170, 220, 255 },
        text = { 235, 245, 255 }, muted = { 140, 160, 180 } },
}
local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function derivePalette(spec)
    local bg, sf, sa = c3(spec.bg), c3(spec.surface), c3(spec.surfaceAlt)
    local pr, se, tx, mu = c3(spec.primary), c3(spec.secondary), c3(spec.text), c3(spec.muted)
    local p = {
        BgDeep = bg, Surface = sf, SurfaceAlt = sa,
        Sidebar = bg:Lerp(sf, 0.55),
        Card = sf, CardAlt = sa,
        CardHover = sa:Lerp(tx, 0.08), CardHeader = sa:Lerp(tx, 0.05),
        Border = sf:Lerp(tx, 0.16), BorderLow = sf:Lerp(tx, 0.08),
        Text = tx, TextDim = mu, TextMute = mu:Lerp(bg, 0.5),
        Primary = pr, PrimaryDim = pr:Lerp(bg, 0.25),
        Secondary = se, Accent = pr, AccentDim = pr:Lerp(bg, 0.22),
        Success = Color3.fromRGB(110, 220, 130),
        Warning = Color3.fromRGB(240, 190, 110),
        Error = Color3.fromRGB(240, 110, 130),
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
Theme.active = "Havac"
Theme.activeSpec = Theme.presets.Havac
Theme.Palette = derivePalette(Theme.presets.Havac)
local T = setmetatable({}, { __index = function(_, k) return Theme.Palette[k] end })
Theme.derivePalette = derivePalette
function Theme.apply(name, root)
    local spec = Theme.presets[name]
    if not spec then return false end
    local old = Theme.Palette
    local new = derivePalette(spec)
    Theme.active, Theme.activeSpec, Theme.Palette = name, spec, new
    if not root then return true end
    local function id(c)
        return math.floor(c.R * 255 + 0.5) * 65536
             + math.floor(c.G * 255 + 0.5) * 256
             + math.floor(c.B * 255 + 0.5)
    end
    local map = {}
    for _, k in ipairs(old._order) do map[id(old[k])] = new[k] end
    local i = 0
    for _, d in ipairs(root:GetDescendants()) do
        i = i + 1
        if d:IsA("GuiObject") then
            local bg = map[id(d.BackgroundColor3)]
            if bg then d.BackgroundColor3 = bg end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local tc = map[id(d.TextColor3)]
                if tc then d.TextColor3 = tc end
            elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local ic = map[id(d.ImageColor3)]
                if ic then d.ImageColor3 = ic end
            end
        elseif d:IsA("UIStroke") then
            local sc = map[id(d.Color)]
            if sc then d.Color = sc end
        end
        if i % 1500 == 0 then task.wait() end
    end
    return true
end

-- ---- 1.5 ANIMATION ENGINE ----
local Anim = { reduce = false, _active = {} }
Anim.easings = {
    smooth = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
    snappy = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
    gentle = { Enum.EasingStyle.Sine,  Enum.EasingDirection.Out },
    soft   = { Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut },
    overshoot = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
    enter  = { Enum.EasingStyle.Quint, Enum.EasingDirection.In },
    linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.Out },
}
function Anim.tween(inst, props, duration, style, key)
    if not inst or not inst.Parent then return nil end
    duration = Anim.reduce and 0.01 or (duration or 0.2)
    local e = Anim.easings[style] or Anim.easings.smooth
    key = key or ("tween_" .. tostring(inst))
    if Anim._active[key] then pcall(function() Anim._active[key]:Cancel() end) end
    local tween = TweenService:Create(inst, TweenInfo.new(duration, e[1], e[2]), props)
    Anim._active[key] = tween
    tween:Play()
    tween.Completed:Connect(function()
        if Anim._active[key] == tween then Anim._active[key] = nil end
    end)
    return tween
end
function Anim.cancel(key)
    if Anim._active[key] then
        pcall(function() Anim._active[key]:Cancel() end)
        Anim._active[key] = nil
    end
end
function Anim.cancelAll()
    for k, t in pairs(Anim._active) do
        pcall(function() t:Cancel() end)
        Anim._active[k] = nil
    end
end

-- ---- 1.6 CONNECTION TRACKER ----
local Connections = {}
local function Track(conn)
    if conn then table.insert(Connections, conn) end
    return conn
end
HAVAC._Connections = Connections

-- ---- 1.7 PERSISTENCE ----
local Persistence = {}
local SCHEMA = {
    version = { type = "number", default = 1 },
    locale  = { type = "string", default = "pt-br", match = { "pt-br", "en", "es" } },
    theme   = { type = "string", default = "Havac", match = { "Havac", "Void", "Ember", "Frost" } },
    toggleKey = { type = "string", default = "RightControl" },
    panicKey  = { type = "string", default = "RightShift" },
    winX = { type = "number", default = 0 },
    winY = { type = "number", default = 0 },
    winW = { type = "number", default = 820 },
    winH = { type = "number", default = 560 },
    reduceEffects = { type = "boolean", default = false },
    islandX = { type = "number", default = 0.5 },
    islandY = { type = "number", default = 12 },
    floatBtnX = { type = "number", default = 12 },
    floatBtnY = { type = "number", default = 0.5 },
    floatBtnHasPos = { type = "boolean", default = false },
    uiScale = { type = "number", default = 100 },
    cornerRadius = { type = "number", default = 10 },
    defaultTheme = { type = "string", default = "" },
}
local CONFIG_FILE = "havac_core.json"
local memoryOnly = not (Caps.writefile and Caps.readfile and Caps.isfile and Caps.isfolder)
local function defaultConfig()
    local c = {}
    for k, s in pairs(SCHEMA) do c[k] = s.default end
    c.themes = {}
    return c
end
local function validateValue(key, value)
    local s = SCHEMA[key]
    if not s then return value end
    local t = type(value)
    if t ~= s.type then
        if s.type == "number" and (t == "string" or t == "userdata") then
            local n = tonumber(value)
            if n then return n end
        end
        return nil
    end
    if s.match then
        local found = false
        for _, m in ipairs(s.match) do if m == value then found = true break end end
        if not found then return nil end
    end
    return value
end
function Persistence.load()
    local cfg = defaultConfig()
    if memoryOnly then return cfg end
    local existsOk, isFile = pcall(isfile, CONFIG_FILE)
    if not existsOk or not isFile then return cfg end
    local ok, content = pcall(readfile, CONFIG_FILE)
    if not ok or type(content) ~= "string" or content == "" then return cfg end
    local decOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if not decOk or type(decoded) ~= "table" then return cfg end
    for k, v in pairs(decoded) do
        if SCHEMA[k] then
            local val = validateValue(k, v)
            if val ~= nil then cfg[k] = val end
        elseif k == "themes" and type(v) == "table" then
            cfg.themes = v
        end
    end
    return cfg
end
function Persistence.save(cfg)
    if memoryOnly then return false end
    local snap = {}
    for k in pairs(SCHEMA) do snap[k] = cfg[k] end
    snap.themes = cfg.themes
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(snap))
    end)
    return ok
end
Persistence.memoryOnly = memoryOnly

-- ---- 1.8 MOUNT GUI ----
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
    if Caps.syn_protect_gui then if try(CoreGui, syn.protect_gui) then return sg end end
    if Caps.protect_gui then if try(CoreGui, protect_gui) then return sg end end
    if try(CoreGui, nil) then return sg end
    local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if pg and try(pg, nil) then
        logError("mount", "fell back to PlayerGui")
        return sg
    end
    logError("mount", "no parent accepted the ScreenGui")
    return sg
end

-- ---- 1.9 HELPERS ----
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
        Color = color or T.BorderLow, Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent,
    })
end
local function Padding(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end
local function VList(parent, gap)
    return New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        HorizontalAlignment = Enum.HorizontalAlignment.Left, Parent = parent,
    })
end
local function HList(parent, gap, valign)
    return New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        VerticalAlignment = valign or Enum.VerticalAlignment.Center, Parent = parent,
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
local F = {
    Bold    = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    Medium  = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
    Regular = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
}

-- ---- 1.10 WINDOW SHELL ----
local Gui, Window, WindowScale, WindowStroke
local Sidebar, Content, Header, Footer, ResizeGrip, Dim
local windowOpen = false
local dragging, dragStart, dragOrigin
local resizing, resizeStart, resizeOrigin

local DEFAULT_W, DEFAULT_H = 820, 560
local SIDEBAR_W = 190
local MIN_W, MAX_W = 680, 1400
local MIN_H, MAX_H = 460, 900

local Config = Persistence.load()

local function buildShell()
    Dim = New("Frame", {
        Name = "Dim", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, Visible = false, ZIndex = 1, Parent = Gui,
    })
    Window = New("Frame", {
        Name = "HAVACWindow", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H),
        BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, ZIndex = 3, Parent = Gui,
    })
    Corner(Window, 16)
    WindowStroke = Stroke(Window, T.Border, 1)
    WindowScale = New("UIScale", { Scale = 1, Parent = Window })

    Sidebar = New("Frame", {
        Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, 0),
        BackgroundColor3 = T.Sidebar, BackgroundTransparency = 1,
        BorderSizePixel = 0, Parent = Window,
    })
    New("Frame", {
        Name = "SidebarBorder", Position = UDim2.new(1, -1, 0, 0),
        Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0, Parent = Sidebar,
    })
    local brand = New("Frame", {
        Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = Sidebar,
    })
    Padding(brand, 16, 12, 18, 10)
    local brandTile = New("Frame", {
        Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = T.Primary,
        BorderSizePixel = 0, Parent = brand,
    })
    Corner(brandTile, 10)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "H",
        TextColor3 = T.BgDeep, FontFace = F.Bold, TextSize = 18, Parent = brandTile,
    })
    local brandTitle = New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 4), Size = UDim2.new(1, -44, 0, 16),
        BackgroundTransparency = 1, Text = "", TextColor3 = T.Text,
        FontFace = F.Bold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = brand,
    })
    Locale.register(brandTitle, "brand_name")
    local brandSub = New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 22), Size = UDim2.new(1, -44, 0, 14),
        BackgroundTransparency = 1, Text = "", TextColor3 = T.TextDim,
        FontFace = F.Regular, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = brand,
    })
    Locale.register(brandSub, "brand_subtitle")

    local navHolder = New("Frame", {
        Position = UDim2.new(0, 10, 0, 72),
        Size = UDim2.new(1, -20, 1, -160),
        BackgroundTransparency = 1, Parent = Sidebar,
    })
    local navBtn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Card,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = navHolder,
    })
    Corner(navBtn, 9)
    Stroke(navBtn, T.BorderLow, 1)
    New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 16), BackgroundColor3 = T.Accent,
        BorderSizePixel = 0, Parent = navBtn,
    })
    local navDot = New("Frame", {
        Position = UDim2.new(0, 16, 0.5, -4), Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = navBtn,
    })
    Corner(navDot, 4)
    local navLabel = New("TextLabel", {
        Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1, Text = "", TextColor3 = T.Text,
        FontFace = F.Medium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = navBtn,
    })
    Locale.register(navLabel, "nav_status")

    local userCard = New("Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.new(1, -20, 0, 60), BackgroundColor3 = T.Card,
        BorderSizePixel = 0, Parent = Sidebar,
    })
    Corner(userCard, 10)
    Stroke(userCard, T.BorderLow, 1)
    Padding(userCard, 10, 10, 10, 10)
    local avatarHolder = New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -17), Size = UDim2.new(0, 34, 0, 34),
        BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = userCard,
    })
    Corner(avatarHolder, 17)
    Stroke(avatarHolder, T.Border, 1)
    local avatarImg = New("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Image = "", Parent = avatarHolder,
    })
    Corner(avatarImg, 17)
    local onlineDot = New("Frame", {
        Position = UDim2.new(0, 25, 0, 25), Size = UDim2.new(0, 9, 0, 9),
        BackgroundColor3 = T.Success, BorderSizePixel = 0, Parent = userCard,
    })
    Corner(onlineDot, 5)
    Stroke(onlineDot, T.Card, 2)
    New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 4), Size = UDim2.new(1, -44, 0, 16),
        BackgroundTransparency = 1,
        Text = LocalPlayer and LocalPlayer.DisplayName or "Player",
        TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = userCard,
    })
    New("TextLabel", {
        Position = UDim2.new(0, 44, 0, 22), Size = UDim2.new(1, -44, 0, 14),
        BackgroundTransparency = 1,
        Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "",
        TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = userCard,
    })
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

    Content = New("Frame", {
        Name = "Content", Position = UDim2.new(0, SIDEBAR_W, 0, 0),
        Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
        BackgroundColor3 = T.BgDeep, BackgroundTransparency = 1,
        BorderSizePixel = 0, Parent = Window,
    })
    Header = New("Frame", {
        Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = Content,
    })
    Padding(Header, 24, 20, 18, 10)
    New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -6), Size = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = Header,
    })
    local headerTitle = New("TextLabel", {
        Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1, Text = "", TextColor3 = T.Text,
        FontFace = F.Bold, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, Parent = Header,
    })
    Locale.register(headerTitle, "welcome_header")

    local body = New("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 1, -94),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Border,
        ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = Content,
    })
    Padding(body, 24, 20, 4, 24)
    VList(body, 12)

    Footer = New("Frame", {
        Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = T.Sidebar, BorderSizePixel = 0, Parent = Content,
    })
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0, Parent = Footer,
    })
    Padding(Footer, 20, 16, 0, 0)
    local footerDot = New("Frame", {
        Position = UDim2.new(0, 0, 0.5, -4), Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = (Caps.executorName == "Unknown" or #Caps.missing > 0)
                            and T.Warning or T.Success,
        BorderSizePixel = 0, Parent = Footer,
    })
    Corner(footerDot, 4)
    New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1, Text = Caps.executorName,
        TextColor3 = T.Text, FontFace = F.Bold, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Footer,
    })
    local footerMsg = New("TextLabel", {
        Position = UDim2.new(0, 140, 0, 0), Size = UDim2.new(1, -320, 1, 0),
        BackgroundTransparency = 1, Text = "", TextColor3 = T.TextDim,
        FontFace = F.Regular, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Footer,
    })
    if #Caps.missing > 0 then
        footerMsg.Text = Locale.T("footer_missing", table.concat(Caps.missing, ", "))
    elseif Caps.executorName == "Unknown" then
        footerMsg.Text = Locale.T("footer_unknown")
    else
        footerMsg.Text = Locale.T("footer_supported")
    end
    local hideText = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -66, 0, 0),
        Size = UDim2.new(0, 90, 1, 0), BackgroundTransparency = 1,
        Text = "", TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = Footer,
    })
    Locale.register(hideText, "hide_hint")
    local keyPill = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 56, 0, 22), BackgroundColor3 = T.Card,
        BorderSizePixel = 0, Parent = Footer,
    })
    Corner(keyPill, 6)
    Stroke(keyPill, T.BorderLow, 1)
    local keyPillText = New("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = keyShort(Config.toggleKey or "RightControl"),
        TextColor3 = T.Text, FontFace = F.Medium, TextSize = 10, Parent = keyPill,
    })

    ResizeGrip = New("TextButton", {
        Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -3, 1, -3), Size = UDim2.new(0, 13, 0, 13),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
        ZIndex = 95, Parent = Window,
    })
    for _, d in ipairs({ {10,2}, {6,6}, {10,6}, {2,10}, {6,10}, {10,10} }) do
        New("Frame", {
            Position = UDim2.fromOffset(d[1] - 1, d[2] - 1),
            Size = UDim2.fromOffset(2, 2), BackgroundColor3 = T.TextMute,
            BorderSizePixel = 0, ZIndex = 96, Parent = ResizeGrip,
        })
    end

    return body, keyPillText, navHolder
end

local function buildStatusContent(body)
    local card = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = body,
    })
    Corner(card, 12)
    Stroke(card, T.BorderLow, 1)
    Padding(card, 20, 20, 18, 18)
    VList(card, 12)
    local function row(labelText, valueText, color)
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = card,
        })
        New("TextLabel", {
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0),
            BackgroundTransparency = 1, Text = labelText, TextColor3 = T.TextDim,
            FontFace = F.Regular, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
        })
        New("TextLabel", {
            Position = UDim2.new(0.45, 0, 0, 0), Size = UDim2.new(0.55, 0, 1, 0),
            BackgroundTransparency = 1, Text = valueText, TextColor3 = color or T.Text,
            FontFace = F.Medium, TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
        })
    end
    local welcome = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        Text = "", TextColor3 = T.Text, FontFace = F.Bold, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Locale.register(welcome, "welcome_header")
    local subtitle = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Text = "", TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Locale.register(subtitle, "welcome_subtitle")
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0, Parent = card,
    })
    local execLabel = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Text = "", TextColor3 = T.TextMute, FontFace = F.Bold, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Locale.register(execLabel, "status_executor")
    row(Locale.T("status_executor"),
        Caps.executorName .. (Caps.executorVersion and (" " .. Caps.executorVersion) or ""))
    row(Locale.T("status_version"), "v" .. VERSION)
    local capsTitle = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
        Text = "", TextColor3 = T.TextMute, FontFace = F.Bold, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Locale.register(capsTitle, "status_caps")
    for _, p in ipairs({
        { "gethui", Caps.gethui }, { "protect_gui", Caps.protect_gui },
        { "writefile", Caps.writefile }, { "readfile", Caps.readfile },
        { "isfile", Caps.isfile }, { "clipboard", Caps.clipboard ~= nil },
    }) do
        row(p[1], Locale.T(p[2] and "cap_present" or "cap_absent"),
            p[2] and T.Success or T.TextMute)
    end
    if #HAVAC._errors > 0 then
        New("Frame", {
            Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
            BorderSizePixel = 0, Parent = card,
        })
        local et = New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
            Text = "", TextColor3 = T.Error, FontFace = F.Bold, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
        })
        Locale.register(et, "status_errors")
        for _, line in ipairs(HAVAC._errors) do
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Text = line, TextWrapped = true,
                TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
            })
        end
    end
    New("Frame", {
        Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0, Parent = card,
    })
    local nextNote = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Text = "", TextWrapped = true,
        TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    Locale.register(nextNote, "status_next")
end

local function computeScale()
    local vp = Gui and Gui.AbsoluteSize or Vector2.new(1920, 1080)
    if vp.X <= 0 or vp.Y <= 0 then return 1 end
    local userScale = (Config and Config.uiScale or 100) / 100
    local sx = (vp.X - 40) / (Config and Config.winW or DEFAULT_W)
    local sy = (vp.Y - 40) / (Config and Config.winH or DEFAULT_H)
    return math.max(0.35, math.min(1, sx, sy) * userScale)
end

local function openWindow()
    if windowOpen or not Window then return end
    windowOpen = true
    Dim.Visible = true
    Dim.BackgroundTransparency = 1
    Anim.tween(Dim, { BackgroundTransparency = 0.55 }, 0.3, "gentle", "dim")
    local scale = computeScale()
    local x = Config and Config.winX or 0
    local y = Config and Config.winY or 0
    Window.Visible = true
    Window.Position = UDim2.new(0.5, x, 0.5, y + 26)
    Window.BackgroundTransparency = 1
    WindowStroke.Transparency = 1
    WindowScale.Scale = scale * 0.92
    Sidebar.BackgroundTransparency = 1
    Anim.tween(WindowScale, { Scale = scale }, 0.55, "overshoot", "win_scale")
    Anim.tween(Window, { Position = UDim2.new(0.5, x, 0.5, y) }, 0.55, "smooth", "win_pos")
    Anim.tween(Window, { BackgroundTransparency = 0 }, 0.3, "gentle", "win_bg")
    Anim.tween(WindowStroke, { Transparency = 0 }, 0.3, "gentle", "win_stroke")
    task.delay(0.05, function()
        if windowOpen and Sidebar then
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
    Anim.tween(WindowStroke, { Transparency = 1 }, 0.25, "gentle", "win_stroke")
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

local function hookDrag(handle)
    if not handle then return end
    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        dragStart = input.Position
        dragOrigin = Window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and dragging then
                dragging = false
                if Config then
                    Config.winX = Window.Position.X.Offset
                    Config.winY = Window.Position.Y.Offset
                    Persistence.save(Config)
                end
            end
        end)
    end)
end

local function hookResize()
    if not ResizeGrip then return end
    ResizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        resizing = true
        resizeStart = input.Position
        resizeOrigin = Window.Size
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and resizing then
                resizing = false
                if Config then
                    Config.winW = Window.Size.X.Offset
                    Config.winH = Window.Size.Y.Offset
                    Persistence.save(Config)
                end
            end
        end)
    end)
end

-- ---- 1.11 BOOT ----
if Config.locale and Locale.strings[Config.locale] then Locale.current = Config.locale end
if Config.theme and Theme.presets[Config.theme] then
    Theme.active = Config.theme
    Theme.activeSpec = Theme.presets[Config.theme]
    Theme.Palette = derivePalette(Theme.activeSpec)
end
Anim.reduce = Config.reduceEffects == true

Gui = mountGui("HAVAC_CORE_" .. tostring(math.random(1e6, 9e6)))

local body, keyPillText, navHolder
do
    local ok, err = pcall(function()
        body, keyPillText, navHolder = buildShell()
    end)
    if not ok then logError("shell", err) end
end

if body then
    local ok, err = pcall(buildStatusContent, body)
    if not ok then logError("status_content", err) end
end

hookDrag(Header)
hookResize()

if Window and Config then
    Window.Size = UDim2.new(0,
        math.clamp(tonumber(Config.winW) or DEFAULT_W, MIN_W, MAX_W), 0,
        math.clamp(tonumber(Config.winH) or DEFAULT_H, MIN_H, MAX_H))
    Window.Position = UDim2.new(0.5, Config.winX or 0, 0.5, Config.winY or 0)
end

Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if Config and input.KeyCode.Name == Config.toggleKey then toggleWindow() end
end))
Track(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Window.Position = UDim2.new(
            dragOrigin.X.Scale, dragOrigin.X.Offset + d.X,
            dragOrigin.Y.Scale, dragOrigin.Y.Offset + d.Y)
    end
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - resizeStart
        local sc = math.max(WindowScale.Scale, 0.01)
        local w = math.clamp(resizeOrigin.X.Offset + d.X / sc, MIN_W, MAX_W)
        local h = math.clamp(resizeOrigin.Y.Offset + d.Y / sc, MIN_H, MAX_H)
        Window.Size = UDim2.new(0, w, 0, h)
    end
end))
Track(Gui and Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if windowOpen then Anim.tween(WindowScale, { Scale = computeScale() }, 0.2, "gentle", "win_scale") end
end))

-- ---- 1.12 PANIC / UNLOAD / DIAG ----
local function cleanupInternal()
    Anim.cancelAll()
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    Connections = {}
    if Gui then pcall(function() Gui:Destroy() end); Gui = nil end
end

function HAVAC.panic()
    for _, fn in ipairs(HAVAC._hooks.panic) do pcall(fn) end
    cleanupInternal()
end
function HAVAC.unload()
    for _, fn in ipairs(HAVAC._hooks.unload) do pcall(fn) end
    cleanupInternal()
end
function HAVAC.onUnload(fn) table.insert(HAVAC._hooks.unload, fn) end
function HAVAC.onPanic(fn)  table.insert(HAVAC._hooks.panic,  fn) end
function HAVAC.setLocale(code)
    if not Locale.strings[code] then return false end
    Locale.current = code
    Locale.reapply()
    if Config then Config.locale = code; Persistence.save(Config) end
    return true
end
function HAVAC.getLocale() return Locale.current end
function HAVAC.setTheme(name)
    if not Theme.presets[name] then return false end
    Theme.apply(name, Gui)
    if Config then Config.theme = name; Persistence.save(Config) end
    return true
end
function HAVAC.getTheme() return Theme.active end
function HAVAC.open()   if Window then openWindow()  end end
function HAVAC.close()  if Window then closeWindow() end end
function HAVAC.toggle() toggleWindow() end
function HAVAC.copy(text)
    if not Caps.clipboard then return false end
    return pcall(Caps.clipboard, tostring(text))
end
function HAVAC.diag()
    local lines = {}
    local function add(s) table.insert(lines, tostring(s)) end
    add("=== HAVAC CORE DIAGNOSTICS ===")
    add("Version: " .. VERSION)
    add("Time:    " .. os.date("%Y-%m-%d %H:%M:%S"))
    add("ID:      havac_core")
    add("")
    add("Executor: " .. Caps.executorName
        .. (Caps.executorVersion and (" " .. Caps.executorVersion) or ""))
    add("Locale:   " .. Locale.current)
    add("Theme:    " .. Theme.active)
    add("")
    add("Capabilities:")
    for _, k in ipairs({
        "gethui", "protect_gui", "syn_protect_gui", "writefile", "readfile",
        "isfile", "isfolder", "makefolder", "delfile", "listfiles",
        "identifyexecutor", "getgenv", "loadstring",
    }) do
        add(("  %-22s %s"):format(k, tostring(Caps[k] == true)))
    end
    add("  clipboard              " .. tostring(Caps.clipboard ~= nil))
    add("")
    add("Missing (recommended): " ..
        (#Caps.missing > 0 and table.concat(Caps.missing, ", ") or "none"))
    add("Persistence: " .. (Persistence.memoryOnly and "memory-only" or "file-based"))
    add("")
    add("Errors: " .. (#HAVAC._errors > 0 and (#HAVAC._errors .. " captured") or "none"))
    for _, e in ipairs(HAVAC._errors) do add("  " .. e) end
    add("")
    add("=== END ===")
    local text = table.concat(lines, "\n")
    print(text)
    return text
end

-- ---- 1.13 INTERNAL EXPOSURE ----
HAVAC._internal = {
    T = T, Anim = Anim, Locale = Locale, Caps = Caps, Theme = Theme,
    Gui = Gui, Window = Window, Sidebar = Sidebar, Content = Content,
    Header = Header, Footer = Footer,
    body = body, navHolder = navHolder,
    Persistence = Persistence, Config = Config,
    New = New, Corner = Corner, Stroke = Stroke, Padding = Padding,
    VList = VList, HList = HList, Track = Track,
    keyShort = keyShort, logError = logError, KEY_SHORT = KEY_SHORT,
    openWindow = openWindow, closeWindow = closeWindow, toggleWindow = toggleWindow,
    computeScale = computeScale, F = F,
    _Connections = Connections,
}

-- ============================================================================
-- END OF BLOCK 1
-- ============================================================================
-- [PARTE 2 VIRÁ AQUI — NÃO APAGUE ESTE COMENTÁRIO]

-- ============================================================================
-- BLOCK 2: COMPONENTS AND PAGES
-- ============================================================================

local function __block2(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 2 needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim, Locale, Caps = I.T, I.Anim, I.Locale, I.Caps
    local New, Corner, Stroke, Padding = I.New, I.Corner, I.Stroke, I.Padding
    local VList, HList, Track, keyShort = I.VList, I.HList, I.Track, I.keyShort
    local F, logError = I.F, I.logError
    local Window, Content, Footer, Sidebar = I.Window, I.Content, I.Footer, I.Sidebar
    local navHolder, body = I.navHolder, I.body

    if not Window or not Content or not body or not navHolder then
        error("HAVAC CORE Block 1 did not build the shell.", 2)
    end

    local function ripple(btn, color)
        local size = btn.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        local UIS = game:GetService("UserInputService")
        local GuiService = game:GetService("GuiService")
        local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
        local abs = btn.AbsolutePosition
        local host = New("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            BorderSizePixel = 0, ClipsDescendants = true,
            ZIndex = (btn.ZIndex or 1) + 1, Parent = btn,
        })
        Corner(host, 8)
        local dot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(
                math.clamp((m.X - abs.X) / size.X, 0, 1),
                math.clamp((m.Y - abs.Y) / size.Y, 0, 1)),
            Size = UDim2.fromScale(0, 0),
            BackgroundColor3 = color or Color3.new(1, 1, 1),
            BackgroundTransparency = 0.7, BorderSizePixel = 0,
            ZIndex = (btn.ZIndex or 1) + 2, Parent = host,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
        Anim.tween(dot, { Size = UDim2.fromScale(2.5, 2.5), BackgroundTransparency = 1 },
            0.55, "linear", "ripple_" .. tostring(host))
        task.delay(0.6, function() if host.Parent then host:Destroy() end end)
    end

    local function safe(cb, ...)
        if type(cb) ~= "function" then return end
        local ok, err = pcall(cb, ...)
        if not ok then logError("callback", err) end
    end

    local function Row(parent, labelText, desc)
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, desc and 44 or 32),
            BackgroundTransparency = 1, Parent = parent,
        })
        if labelText then
            New("TextLabel", {
                Position = UDim2.new(0, 0, 0, 0),
                Size = desc and UDim2.new(0.6, 0, 0, 22) or UDim2.new(0.55, 0, 1, 0),
                BackgroundTransparency = 1, Text = labelText, TextColor3 = T.Text,
                FontFace = F.Medium, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center, Parent = r,
            })
        end
        if desc then
            New("TextLabel", {
                Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(0.6, 0, 0, 16),
                BackgroundTransparency = 1, Text = desc, TextColor3 = T.TextDim,
                FontFace = F.Regular, TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center, Parent = r,
            })
        end
        return r
    end

    -- PAGE SYSTEM
    local Pages = {}
    local PageOrder = {}
    local ActivePageId = nil
    local PageSwitchSeq = 0

    local NavScroll = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        BorderSizePixel = 0, ScrollBarThickness = 2,
        ScrollBarImageColor3 = T.Border, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = navHolder,
    })
    Padding(NavScroll, 10, 10, 4, 4)
    VList(NavScroll, 4)

    local statusBtn
    for _, c in ipairs(navHolder:GetChildren()) do
        if c:IsA("TextButton") then statusBtn = c; break end
    end
    if statusBtn then
        statusBtn.Parent = NavScroll
        statusBtn.LayoutOrder = 0
    end

    local statusCard
    for _, c in ipairs(body:GetChildren()) do
        if c:IsA("Frame") then statusCard = c; break end
    end
    for _, c in ipairs(body:GetChildren()) do
        if c:IsA("UIListLayout") then c:Destroy() break end
    end
    local StatusPageFrame = New("Frame", {
        Name = "Page_status", Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Visible = false, Parent = body,
    })
    VList(StatusPageFrame, 12)
    if statusCard then statusCard.Parent = StatusPageFrame; statusCard.LayoutOrder = 1 end
    Pages["status"] = { frame = StatusPageFrame, title = "Status", navBtn = statusBtn }
    table.insert(PageOrder, "status")
    if statusBtn then
        statusBtn.MouseButton1Click:Connect(function() HAVAC.showPage("status") end)
    end

    local function createNavButton(title, pageId)
        local btn = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false,
            LayoutOrder = #PageOrder, Parent = NavScroll,
        })
        Corner(btn, 9)
        local dot = New("Frame", {
            Position = UDim2.new(0, 16, 0.5, -4), Size = UDim2.new(0, 8, 0, 8),
            BackgroundColor3 = T.TextDim, BorderSizePixel = 0, Parent = btn,
        })
        Corner(dot, 4)
        local bar = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 16), BackgroundColor3 = T.Accent,
            BorderSizePixel = 0, Parent = btn,
        })
        New("UICorner", { CornerRadius = UDim.new(0, 2), Parent = bar })
        New("TextLabel", {
            Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -40, 1, 0),
            BackgroundTransparency = 1, Text = title, TextColor3 = T.TextDim,
            FontFace = F.Medium, TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
        })
        btn.MouseEnter:Connect(function()
            if ActivePageId ~= pageId then
                Anim.tween(btn, { BackgroundTransparency = 0.75 }, 0.15, "gentle", "nav_" .. pageId)
                btn.BackgroundColor3 = T.Card
            end
        end)
        btn.MouseLeave:Connect(function()
            if ActivePageId ~= pageId then
                Anim.tween(btn, { BackgroundTransparency = 1 }, 0.15, "gentle", "nav_" .. pageId)
            end
        end)
        btn.MouseButton1Click:Connect(function()
            ripple(btn, T.Text)
            HAVAC.showPage(pageId)
        end)
        return btn
    end

    function HAVAC.showPage(id)
        local target = Pages[id]
        if not target or ActivePageId == id then return end
        PageSwitchSeq = PageSwitchSeq + 1
        local mySeq = PageSwitchSeq
        local oldId = ActivePageId
        local old = oldId and Pages[oldId] or nil
        for pid, p in pairs(Pages) do
            local isActive = (pid == id)
            if p.navBtn then
                Anim.tween(p.navBtn, { BackgroundTransparency = isActive and 0 or 1 }, 0.2, "gentle", "nav_" .. pid)
                if isActive then p.navBtn.BackgroundColor3 = T.Card end
                local lbl = p.navBtn:FindFirstChildWhichIsA("TextLabel")
                if lbl then
                    Anim.tween(lbl, { TextColor3 = isActive and T.Text or T.TextDim }, 0.2, "gentle", "navLbl_" .. pid)
                end
                for _, ch in ipairs(p.navBtn:GetChildren()) do
                    if ch:IsA("Frame") and ch.Size.Y.Offset == 16 and not ch:FindFirstChildWhichIsA("UICorner") then
                        -- skip
                    elseif ch:IsA("Frame") and ch.Size.Y.Offset == 16 then
                        Anim.tween(ch, { Size = UDim2.new(0, isActive and 3 or 0, 0, 16) }, 0.25, "smooth", "navBar_" .. pid)
                    elseif ch:IsA("Frame") and ch.Size.X.Offset == 8 then
                        Anim.tween(ch, { BackgroundColor3 = isActive and T.Accent or T.TextDim }, 0.2, "gentle", "navDot_" .. pid)
                    end
                end
            end
        end
        if old and old.frame then
            Anim.tween(old.frame, { BackgroundTransparency = 1 }, 0.1, "linear", "pageOut_" .. oldId)
            task.wait(0.1)
            if PageSwitchSeq ~= mySeq then return end
            old.frame.Visible = false
        end
        body.CanvasPosition = Vector2.new(0, 0)
        target.frame.Visible = true
        target.frame.BackgroundTransparency = 1
        Anim.tween(target.frame, { BackgroundTransparency = 1 }, 0.2, "gentle", "pageIn_" .. id)
        ActivePageId = id
    end

    function HAVAC.page(id, title)
        if type(id) ~= "string" or id == "" then error("HAVAC.page: invalid id", 2) end
        if Pages[id] then return Pages[id].frame end
        title = title or id
        local btn = createNavButton(title, id)
        local frame = New("Frame", {
            Name = "Page_" .. id, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
            Visible = false, Parent = body,
        })
        VList(frame, 12)
        Pages[id] = { frame = frame, title = title, navBtn = btn }
        table.insert(PageOrder, id)
        if ActivePageId == nil then HAVAC.showPage(id) end
        return frame
    end
    function HAVAC.getPage(id) return Pages[id] and Pages[id].frame end
    function HAVAC.pageExists(id) return Pages[id] ~= nil end
    if not ActivePageId then HAVAC.showPage("status") end

    I.ActivePage = function() return ActivePageId end
    I.Pages = Pages

    -- CARD
    function HAVAC.card(parent, title)
        local c = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.Card, BorderSizePixel = 0,
            ClipsDescendants = true, Parent = parent,
        })
        Corner(c, 12)
        local stroke = Stroke(c, T.BorderLow, 1)
        local header = New("Frame", {
            Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0, Parent = c,
        })
        Corner(header, 12)
        New("Frame", {
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0, Parent = header,
        })
        Padding(header, 18, 16, 0, 0)
        New("Frame", {
            Position = UDim2.new(0, 0, 0.5, -6), Size = UDim2.new(0, 12, 0, 12),
            BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = header,
        })
        New("TextLabel", {
            Position = UDim2.new(0, 22, 0, 0), Size = UDim2.new(1, -70, 1, 0),
            BackgroundTransparency = 1, Text = title or "Card",
            TextColor3 = T.Text, FontFace = F.Bold, TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center, Parent = header,
        })
        local chevron = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, Parent = header,
        })
        local chevIcon = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = T.TextDim,
            BorderSizePixel = 0, Rotation = 45, Parent = chevron,
        })
        Corner(chevIcon, 1)
        local separator = New("Frame", {
            Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
            BorderSizePixel = 0, Parent = c,
        })
        local contentBody = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Parent = c,
        })
        Padding(contentBody, 18, 18, 14, 16)
        VList(contentBody, 10)
        local collapsed, busy = false, false
        local function toggleCollapse()
            if busy then return end
            busy = true
            collapsed = not collapsed
            if collapsed then
                Anim.tween(chevIcon, { Rotation = -45 }, 0.25, "smooth", "chev_" .. tostring(c))
                local h = contentBody.AbsoluteSize.Y
                contentBody.AutomaticSize = Enum.AutomaticSize.None
                contentBody.Size = UDim2.new(1, 0, 0, h)
                Anim.tween(contentBody, { Size = UDim2.new(1, 0, 0, 0) }, 0.25, "smooth", "collapse_" .. tostring(c))
                separator.Visible = false
                task.wait(0.26)
                if collapsed then contentBody.Visible = false end
            else
                Anim.tween(chevIcon, { Rotation = 45 }, 0.25, "smooth", "chev_" .. tostring(c))
                contentBody.Visible = true
                separator.Visible = true
                contentBody.AutomaticSize = Enum.AutomaticSize.Y
                contentBody.Size = UDim2.new(1, 0, 0, 0)
            end
            busy = false
        end
        chevron.MouseButton1Click:Connect(function() ripple(chevron, T.Text); toggleCollapse() end)
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
               or input.UserInputType == Enum.UserInputType.Touch then
                ripple(header, T.Text); toggleCollapse()
            end
        end)
        c.MouseEnter:Connect(function()
            Anim.tween(stroke, { Color = T.Border }, 0.2, "gentle", "cs_" .. tostring(c))
        end)
        c.MouseLeave:Connect(function()
            Anim.tween(stroke, { Color = T.BorderLow }, 0.25, "gentle", "cs_" .. tostring(c))
        end)
        return contentBody
    end

    -- STATIC
    function HAVAC.section(parent, text)
        return New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
            Text = tostring(text):upper(), TextColor3 = T.TextMute,
            FontFace = F.Bold, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        })
    end
    function HAVAC.divider(parent)
        return New("Frame", {
            Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
            BorderSizePixel = 0, Parent = parent,
        })
    end
    function HAVAC.label(parent, text, opts)
        opts = opts or {}
        return New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = tostring(text),
            TextColor3 = opts.color or T.Text,
            FontFace = opts.bold and F.Bold or F.Regular,
            TextSize = opts.size or 12, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
        })
    end
    function HAVAC.paragraph(parent, text, opts)
        opts = opts or {}
        return New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = tostring(text),
            TextColor3 = opts.color or T.TextDim,
            FontFace = F.Regular, TextSize = opts.size or 11, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
        })
    end

    -- BUTTONS
    function HAVAC.button(parent, label, variant, cb)
        local primary = variant == "primary"
        local b = New("TextButton", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundColor3 = primary and T.Primary or T.CardAlt,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = parent,
        })
        Corner(b, 8)
        if not primary then Stroke(b, T.BorderLow, 1) end
        New("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = tostring(label), TextColor3 = primary and T.BgDeep or T.Text,
            FontFace = F.Medium, TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
        })
        b.MouseEnter:Connect(function()
            Anim.tween(b, { BackgroundColor3 = primary and T.AccentDim or T.CardHover },
                0.15, "gentle", "btnH_" .. tostring(b))
        end)
        b.MouseLeave:Connect(function()
            Anim.tween(b, { BackgroundColor3 = primary and T.Primary or T.CardAlt },
                0.15, "gentle", "btnH_" .. tostring(b))
        end)
        b.MouseButton1Click:Connect(function()
            ripple(b, primary and T.BgDeep or T.Text); safe(cb)
        end)
        return b
    end
    function HAVAC.buttonRow(parent, items)
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = parent,
        })
        HList(r, 8)
        local n = #items
        for _, it in ipairs(items) do
            local btn = New("TextButton", {
                Size = UDim2.new(1 / n, -(8 * (n - 1) / n), 1, 0),
                BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
                Text = tostring(it.label or ""), TextColor3 = T.Text,
                FontFace = F.Medium, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false, Parent = r,
            })
            Corner(btn, 8)
            Stroke(btn, T.BorderLow, 1)
            btn.MouseEnter:Connect(function()
                Anim.tween(btn, { BackgroundColor3 = T.CardHover }, 0.15, "gentle", "brH_" .. tostring(btn))
            end)
            btn.MouseLeave:Connect(function()
                Anim.tween(btn, { BackgroundColor3 = T.CardAlt }, 0.15, "gentle", "brH_" .. tostring(btn))
            end)
            local armed = 0
            local function disarm()
                armed = 0
                btn.Text = tostring(it.label or "")
                Anim.tween(btn, { TextColor3 = T.Text }, 0.15, "gentle", "brT_" .. tostring(btn))
            end
            btn.MouseButton1Click:Connect(function()
                ripple(btn, T.Text)
                if it.confirm and armed == 0 then
                    armed = os.clock()
                    local my = armed
                    btn.Text = "Confirm"
                    Anim.tween(btn, { TextColor3 = T.Error }, 0.15, "gentle", "brT_" .. tostring(btn))
                    task.delay(3, function() if armed == my then disarm() end end)
                    return
                end
                if it.confirm then disarm() end
                safe(it.cb)
            end)
        end
        return r
    end

    -- TOGGLE
    function HAVAC.toggle(parent, label, default, cb, opts)
        opts = opts or {}
        local r = Row(parent, label, opts.desc)
        local track = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 36, 0, 20),
            BackgroundColor3 = default and T.Primary or T.CardAlt,
            BorderSizePixel = 0, Parent = r,
        })
        Corner(track, 10)
        local knob = New("Frame", {
            Position = UDim2.new(0, default and 18 or 2, 0.5, -8),
            Size = UDim2.new(0, 16, 0, 16),
            BackgroundColor3 = default and T.BgDeep or T.TextDim,
            BorderSizePixel = 0, Parent = track,
        })
        Corner(knob, 8)
        local btn = New("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, Parent = r,
        })
        local state = default and true or false
        local function paint(animated)
            local tc = state and T.Primary or T.CardAlt
            local kc = state and T.BgDeep or T.TextDim
            local kp = UDim2.new(0, state and 18 or 2, 0.5, -8)
            if animated then
                Anim.tween(track, { BackgroundColor3 = tc }, 0.2, "gentle", "tgT_" .. tostring(track))
                Anim.tween(knob, { Position = kp, BackgroundColor3 = kc }, 0.3, "overshoot", "tgK_" .. tostring(knob))
            else
                track.BackgroundColor3 = tc; knob.Position = kp; knob.BackgroundColor3 = kc
            end
        end
        btn.MouseButton1Click:Connect(function()
            state = not state
            paint(true)
            safe(cb, state)
        end)
        return {
            Set = function(_, v, fire) state = v and true or false; paint(true); if fire then safe(cb, state) end end,
            Get = function() return state end,
        }
    end

    -- SLIDER
    function HAVAC.slider(parent, label, minV, maxV, default, cb, opts)
        opts = opts or {}
        local suffix = opts.suffix or ""
        local step = opts.step or 1
        local dec = #(tostring(step):match("%.(%d+)$") or "")
        local function snap(x)
            local v = math.clamp(minV + math.floor((x - minV) / step + 0.5) * step, minV, maxV)
            if dec == 0 then return math.floor(v + 0.5) end
            return tonumber(("%." .. dec .. "f"):format(v))
        end
        local function fmt(v)
            return (dec == 0 and tostring(v) or ("%." .. dec .. "f"):format(v)) .. suffix
        end
        local value = default
        local wrap = New("Frame", {
            Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = parent,
        })
        New("TextLabel", {
            Size = UDim2.new(0.6, 0, 0, 20), BackgroundTransparency = 1,
            Text = tostring(label), TextColor3 = T.Text, FontFace = F.Medium,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap,
        })
        local valBox = New("Frame", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 56, 0, 20), BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0, Parent = wrap,
        })
        Corner(valBox, 6)
        local valLbl = New("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = fmt(default), TextColor3 = T.Text, FontFace = F.Medium,
            TextSize = 11, Parent = valBox,
        })
        local track = New("Frame", {
            Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 4),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = wrap,
        })
        Corner(track, 2)
        local rel0 = math.clamp((default - minV) / (maxV - minV), 0, 1)
        local fill = New("Frame", {
            Size = UDim2.new(rel0, 0, 1, 0), BackgroundColor3 = T.Primary,
            BorderSizePixel = 0, Parent = track,
        })
        Corner(fill, 2)
        local knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(rel0, 0, 0.5, 0),
            Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = T.Text,
            BorderSizePixel = 0, Parent = track,
        })
        Corner(knob, 7)
        local hit = New("TextButton", {
            Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = wrap,
        })
        local function show(v)
            local rel = math.clamp((v - minV) / (maxV - minV), 0, 1)
            Anim.tween(fill, { Size = UDim2.new(rel, 0, 1, 0) }, 0.08, "linear", "slF_" .. tostring(fill))
            Anim.tween(knob, { Position = UDim2.new(rel, 0, 0.5, 0) }, 0.08, "linear", "slK_" .. tostring(knob))
            valLbl.Text = fmt(v)
        end
        local function setFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            local v = snap(minV + rel * (maxV - minV))
            if v == value then return end
            value = v
            show(v)
            safe(cb, v)
        end
        local moveConn, endConn
        local function stopSliding()
            if moveConn then moveConn:Disconnect(); moveConn = nil end
            if endConn then endConn:Disconnect(); endConn = nil end
            Anim.tween(knob, { Size = UDim2.new(0, 14, 0, 14) }, 0.1, "gentle", "slS_" .. tostring(knob))
        end
        hit.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
               or i.UserInputType == Enum.UserInputType.Touch then
                if moveConn then moveConn:Disconnect() end
                if endConn then endConn:Disconnect() end
                Anim.tween(knob, { Size = UDim2.new(0, 18, 0, 18) }, 0.1, "gentle", "slS_" .. tostring(knob))
                setFromX(i.Position.X)
                local UIS = game:GetService("UserInputService")
                moveConn = Track(UIS.InputChanged:Connect(function(m)
                    if m.UserInputType == Enum.UserInputType.MouseMovement
                       or m.UserInputType == Enum.UserInputType.Touch then
                        setFromX(m.Position.X)
                    end
                end))
                endConn = Track(UIS.InputEnded:Connect(function(e)
                    if e.UserInputType == Enum.UserInputType.MouseButton1
                       or e.UserInputType == Enum.UserInputType.Touch then stopSliding() end
                end))
            end
        end)
        return {
            Set = function(_, v, fire) value = v; show(v); if fire then safe(cb, v) end end,
            Get = function() return value end,
        }
    end

    -- DROPDOWN
    local overlayLayer = New("Frame", {
        Name = "HAVAC_OverlayLayer", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, ZIndex = 200, Parent = I.Gui,
    })
    local currentDrop = nil
    local catcher = New("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, Visible = false, ZIndex = 1, Parent = overlayLayer,
    })
    catcher.MouseButton1Click:Connect(function()
        if currentDrop then currentDrop.close() end
    end)

    function HAVAC.dropdown(parent, label, options, default, cb, opts)
        opts = opts or {}
        local hasLabel = label ~= nil and label ~= ""
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, hasLabel and 52 or 32),
            BackgroundTransparency = 1, Parent = parent,
        })
        if hasLabel then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                Text = tostring(label), TextColor3 = T.Text, FontFace = F.Medium,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
            })
        end
        local head = New("TextButton", {
            Position = UDim2.new(0, 0, 0, hasLabel and 20 or 0),
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.BgDeep,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = r,
        })
        Corner(head, 7)
        local headStroke = Stroke(head, T.BorderLow, 1)
        local headLbl = New("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -32, 1, 0),
            BackgroundTransparency = 1, Text = tostring(default or options[1] or ""),
            TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
        })
        local chevron = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = T.TextDim,
            BorderSizePixel = 0, Rotation = 45, Parent = head,
        })
        Corner(chevron, 1)
        local selected = default or options[1]
        local isOpen = false
        local list = New("ScrollingFrame", {
            Size = UDim2.new(0, 200, 0, math.min(#options, 6) * 24 + 8),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.TextDim,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ZIndex = 5, Parent = overlayLayer,
        })
        Corner(list, 8)
        Stroke(list, T.Border, 1)
        Padding(list, 4, 4, 4, 4)
        VList(list, 1)
        local function build()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for i, opt in ipairs(options) do
                local isSel = (opt == selected)
                local b = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.CardHover,
                    BackgroundTransparency = isSel and 0.6 or 1,
                    Text = tostring(opt), TextColor3 = isSel and T.Text or T.TextDim,
                    FontFace = isSel and F.Medium or F.Regular, TextSize = 11,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false, LayoutOrder = i, Parent = list,
                })
                Corner(b, 5)
                Padding(b, 10, 10, 0, 0)
                b.MouseButton1Click:Connect(function()
                    selected = opt
                    headLbl.Text = tostring(opt)
                    if currentDrop then currentDrop.close() end
                    build()
                    safe(cb, opt)
                end)
            end
        end
        build()
        local function close()
            if not isOpen then return end
            isOpen = false
            Anim.tween(list, { Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, 0, 0) },
                0.12, "linear", "ddC_" .. tostring(list))
            task.delay(0.13, function() list.Visible = false end)
            if currentDrop and currentDrop.list == list then
                currentDrop = nil
                catcher.Visible = false
            end
        end
        local function open()
            if currentDrop then currentDrop.close() end
            isOpen = true
            local sc = math.max(I.computeScale and I.computeScale() or 1, 0.01)
            local layerAbs = overlayLayer.AbsolutePosition
            local headAbs = head.AbsolutePosition
            local relX = (headAbs.X - layerAbs.X) / sc
            local relY = (headAbs.Y - layerAbs.Y) / sc + head.AbsoluteSize.Y / sc + 4
            local w = head.AbsoluteSize.X / sc
            list.Position = UDim2.new(0, relX, 0, relY)
            list.Size = UDim2.new(0, w, 0, 0)
            list.Visible = true
            local h = math.min(#options, 6) * 24 + 8
            Anim.tween(list, { Size = UDim2.new(0, w, 0, h) }, 0.2, "smooth", "ddO_" .. tostring(list))
            catcher.Visible = true
            currentDrop = { list = list, close = close }
        end
        head.MouseButton1Click:Connect(function()
            if isOpen then close() else open() end
        end)
        return {
            Set = function(_, v, fire) selected = v; headLbl.Text = tostring(v); build(); if fire then safe(cb, v) end end,
            Get = function() return selected end,
        }
    end

    -- INPUT
    function HAVAC.input(parent, label, placeholder, default, cb)
        local r = Row(parent, label)
        local box = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 150, 0, 26), BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0, Parent = r,
        })
        Corner(box, 7)
        local stroke = Stroke(box, T.BorderLow, 1)
        Padding(box, 10, 10, 0, 0)
        local tb = New("TextBox", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            PlaceholderText = placeholder or "", PlaceholderColor3 = T.TextDim,
            TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11,
            Text = default or "", TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
        })
        tb.Focused:Connect(function()
            Anim.tween(stroke, { Color = T.Accent }, 0.15, "gentle", "inS_" .. tostring(tb))
        end)
        tb.FocusLost:Connect(function()
            Anim.tween(stroke, { Color = T.BorderLow }, 0.15, "gentle", "inS_" .. tostring(tb))
            safe(cb, tb.Text)
        end)
        return tb
    end

    -- KEYBIND
    local listeningKey = false
    function HAVAC.keybind(parent, label, default, cb, opts)
        opts = opts or {}
        local allowNone = opts.allowNone ~= false
        local r = Row(parent, label)
        local pill = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 64, 0, 22), BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0, Text = keyShort(default or "None"),
            TextColor3 = T.Text, FontFace = F.Medium, TextSize = 10,
            AutoButtonColor = false, Parent = r,
        })
        Corner(pill, 6)
        local stroke = Stroke(pill, T.BorderLow, 1)
        local keyName = default or "None"
        pill.MouseButton1Click:Connect(function()
            if listeningKey then return end
            listeningKey = true
            pill.Text = "..."
            Anim.tween(stroke, { Color = T.Accent }, 0.12, "gentle", "kbS_" .. tostring(pill))
            local conn
            conn = Track(game:GetService("UserInputService").InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.Keyboard
                   and input.UserInputType ~= Enum.UserInputType.MouseButton2
                   and input.UserInputType ~= Enum.UserInputType.MouseButton3 then return end
                if conn then conn:Disconnect() end
                listeningKey = false
                local name
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    name = input.KeyCode.Name
                else
                    name = input.UserInputType.Name
                end
                if name == "Escape" then
                    name = allowNone and "None" or keyName
                end
                keyName = name
                pill.Text = keyShort(name)
                Anim.tween(stroke, { Color = T.BorderLow }, 0.15, "gentle", "kbS_" .. tostring(pill))
                safe(cb, name)
            end))
        end)
        return {
            Set = function(_, v, fire) keyName = v; pill.Text = keyShort(v); if fire then safe(cb, v) end end,
            Get = function() return keyName end,
        }
    end

    -- STATUS / PROGRESS
    function HAVAC.status(parent, label, value, opts)
        opts = opts or {}
        local r = Row(parent, label)
        return New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, opts.width or 150, 1, 0),
            BackgroundTransparency = 1, Text = tostring(value or ""),
            TextColor3 = opts.color or T.TextDim, FontFace = F.Medium, TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
        })
    end
    function HAVAC.progress(parent, label, opts)
        opts = opts or {}
        local wrap = New("Frame", {
            Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = parent,
        })
        New("TextLabel", {
            Size = UDim2.new(0.55, 0, 0, 20), BackgroundTransparency = 1,
            Text = tostring(label), TextColor3 = T.Text, FontFace = F.Medium,
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap,
        })
        local valLbl = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.45, 0, 0, 20), BackgroundTransparency = 1,
            Text = "-", TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 12,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Right, Parent = wrap,
        })
        local track = New("Frame", {
            Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 6),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = wrap,
        })
        Corner(track, 3)
        local fill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = opts.color or T.Primary,
            BorderSizePixel = 0, Parent = track,
        })
        Corner(fill, 3)
        return {
            Set = function(_, frac, text)
                Anim.tween(fill, { Size = UDim2.new(math.clamp(frac or 0, 0, 1), 0, 1, 0) },
                    0.2, "gentle", "pgF_" .. tostring(fill))
                if text then valLbl.Text = tostring(text) end
            end,
        }
    end

    -- NOTIFICATIONS
    local toastHolder = New("Frame", {
        Name = "HAVAC_Toasts", AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -18, 1, -18), Size = UDim2.new(0, 280, 0, 320),
        BackgroundTransparency = 1, ZIndex = 300, Parent = I.Gui,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
        Parent = toastHolder,
    })
    local toastSeq = 0
    local MAX_TOASTS = 4
    local function kindColor(kind)
        if kind == "ok" then return T.Success end
        if kind == "warn" then return T.Warning end
        if kind == "err" then return T.Error end
        return T.Accent
    end
    function HAVAC.notify(kind, title, bodyText, duration)
        toastSeq = toastSeq + 1
        local color = kindColor(kind or "info")
        duration = duration or 3
        local live = {}
        for _, c in ipairs(toastHolder:GetChildren()) do
            if c:IsA("Frame") and not c:GetAttribute("Leaving") then table.insert(live, c) end
        end
        table.sort(live, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
        while #live >= MAX_TOASTS do
            local old = table.remove(live, 1)
            old:SetAttribute("Leaving", true)
            Anim.tween(old, { BackgroundTransparency = 1 }, 0.2, "gentle", "tOld_" .. tostring(old))
            task.delay(0.22, function() if old.Parent then old:Destroy() end end)
        end
        local wrap = New("Frame", {
            Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
            ClipsDescendants = true, LayoutOrder = toastSeq, Parent = toastHolder,
        })
        local card = New("Frame", {
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 40, 1, 0),
            Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = T.BgDeep,
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ClipsDescendants = true, Parent = wrap,
        })
        Corner(card, 12)
        Stroke(card, T.BorderLow, 1)
        local stripe = New("Frame", {
            Position = UDim2.new(0, 0, 0, 10), Size = UDim2.new(0, 3, 0, 42),
            BackgroundColor3 = color, BorderSizePixel = 0, Parent = card,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = stripe })
        New("TextLabel", {
            Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -24, 0, 18),
            BackgroundTransparency = 1, Text = tostring(title or ""),
            TextColor3 = color, FontFace = F.Bold, TextSize = 13,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
        })
        if bodyText and bodyText ~= "" then
            New("TextLabel", {
                Position = UDim2.new(0, 14, 0, 28), Size = UDim2.new(1, -24, 0, 16),
                BackgroundTransparency = 1, Text = tostring(bodyText),
                TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
            })
        end
        local barTrack = New("Frame", {
            Position = UDim2.new(0, 14, 1, -8), Size = UDim2.new(1, -28, 0, 3),
            BackgroundColor3 = T.CardHover, BorderSizePixel = 0, Parent = card,
        })
        Corner(barTrack, 2)
        local barFill = New("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = color,
            BorderSizePixel = 0, Parent = barTrack,
        })
        Corner(barFill, 2)
        Anim.tween(wrap, { Size = UDim2.new(1, 0, 0, 62) }, 0.3, "smooth", "tW_" .. tostring(wrap))
        Anim.tween(card, { Position = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 0 },
            0.4, "smooth", "tC_" .. tostring(card))
        Anim.tween(barFill, { Size = UDim2.new(0, 0, 1, 0) }, duration, "linear", "tB_" .. tostring(barFill))
        task.delay(duration, function()
            if not wrap.Parent then return end
            wrap:SetAttribute("Leaving", true)
            Anim.tween(card, { Position = UDim2.new(0, 40, 1, 0), BackgroundTransparency = 1 },
                0.3, "enter", "tO_" .. tostring(card))
            task.delay(0.32, function() if wrap.Parent then wrap:Destroy() end end)
        end)
    end

    -- CONFIRM DIALOG
    function HAVAC.confirm(title, message)
        local result = nil
        local dim = New("Frame", {
            Name = "HAVAC_Confirm", Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, Visible = true, ZIndex = 400, Parent = I.Gui,
        })
        local box = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 20),
            Size = UDim2.new(0, 340, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = dim,
        })
        Corner(box, 14)
        Stroke(box, T.Border, 1)
        Padding(box, 22, 22, 20, 20)
        VList(box, 12)
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
            Text = tostring(title or "Confirm"), TextColor3 = T.Text,
            FontFace = F.Bold, TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
        })
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = tostring(message or ""),
            TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 12,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = box,
        })
        local btns = New("Frame", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = box,
        })
        HList(btns, 8)
        local function mkBtn(label, color, value)
            local b = New("TextButton", {
                Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = color,
                BorderSizePixel = 0, Text = label,
                TextColor3 = (color == T.Error or color == T.Primary) and T.BgDeep or T.Text,
                FontFace = F.Medium, TextSize = 12, AutoButtonColor = false, Parent = btns,
            })
            Corner(b, 8)
            b.MouseButton1Click:Connect(function() ripple(b, T.Text); result = value end)
            return b
        end
        mkBtn("Cancelar", T.CardAlt, false)
        mkBtn("Confirmar", T.Error, true)
        Anim.tween(dim, { BackgroundTransparency = 0.4 }, 0.2, "gentle", "cdD")
        Anim.tween(box, { Position = UDim2.new(0.5, 0, 0.5, 0) }, 0.35, "overshoot", "cdB")
        while result == nil do task.wait(0.05) end
        Anim.tween(dim, { BackgroundTransparency = 1 }, 0.2, "gentle", "cdD")
        Anim.tween(box, { Position = UDim2.new(0.5, 0, 0.5, 20) }, 0.2, "enter", "cdB")
        task.delay(0.22, function() if dim.Parent then dim:Destroy() end end)
        return result
    end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- BLOCK 2B: MULTIDROPDOWN + COLORPICKER
-- ============================================================================

local function __block2b(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 2B needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim = I.T, I.Anim
    local New, Corner, Stroke = I.New, I.Corner, I.Stroke
    local Padding = I.Padding
    local VList, HList, Track = I.VList, I.HList, I.Track
    local F, logError, Gui = I.F, I.logError, I.Gui
    if not Gui then
        error("HAVAC CORE Block 2B: Gui missing.", 2)
    end

    local function ripple(btn, color)
        local size = btn.AbsoluteSize
        if size.X <= 0 or size.Y <= 0 then return end
        local UIS = game:GetService("UserInputService")
        local GuiService = game:GetService("GuiService")
        local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
        local abs = btn.AbsolutePosition
        local host = New("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            BorderSizePixel = 0, ClipsDescendants = true,
            ZIndex = (btn.ZIndex or 1) + 1, Parent = btn,
        })
        Corner(host, 8)
        local dot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(
                math.clamp((m.X - abs.X) / size.X, 0, 1),
                math.clamp((m.Y - abs.Y) / size.Y, 0, 1)),
            Size = UDim2.fromScale(0, 0),
            BackgroundColor3 = color or Color3.new(1, 1, 1),
            BackgroundTransparency = 0.7, BorderSizePixel = 0,
            ZIndex = (btn.ZIndex or 1) + 2, Parent = host,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
        Anim.tween(dot, { Size = UDim2.fromScale(2.5, 2.5), BackgroundTransparency = 1 },
            0.55, "linear", "ripple_" .. tostring(host))
        task.delay(0.6, function() if host.Parent then host:Destroy() end end)
    end

    local function safe(cb, ...)
        if type(cb) ~= "function" then return end
        local ok, err = pcall(cb, ...)
        if not ok then logError("callback", err) end
    end

    local function Row(parent, labelText)
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = parent,
        })
        if labelText then
            New("TextLabel", {
                Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1,
                Text = tostring(labelText), TextColor3 = T.Text,
                FontFace = F.Medium, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center, Parent = r,
            })
        end
        return r
    end

    local function hex(c)
        return ("#%02X%02X%02X"):format(
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5))
    end
    local function parseHex(s)
        s = tostring(s or ""):gsub("[#%s]", "")
        if #s == 6 and s:match("^%x+$") then
            return Color3.fromRGB(
                tonumber(s:sub(1, 2), 16),
                tonumber(s:sub(3, 4), 16),
                tonumber(s:sub(5, 6), 16))
        end
        return nil
    end

    local Overlay2B = New("Frame", {
        Name = "HAVAC_Overlay2B", Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, ZIndex = 201, Parent = Gui,
    })
    local currentPop = nil
    local catcher = New("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, Visible = false, ZIndex = 1, Parent = Overlay2B,
    })
    catcher.MouseButton1Click:Connect(function()
        if currentPop then currentPop.close() end
    end)

    -- MULTIDROPDOWN
    function HAVAC.multiDropdown(parent, label, options, defaultList, cb, opts)
        opts = opts or {}
        local hasLabel = label ~= nil and label ~= ""
        local r = New("Frame", {
            Size = UDim2.new(1, 0, 0, hasLabel and 52 or 32),
            BackgroundTransparency = 1, Parent = parent,
        })
        if hasLabel then
            New("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
                Text = tostring(label), TextColor3 = T.Text, FontFace = F.Medium,
                TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
            })
        end
        local head = New("TextButton", {
            Position = UDim2.new(0, 0, 0, hasLabel and 20 or 0),
            Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.BgDeep,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = r,
        })
        Corner(head, 7)
        local headStroke = Stroke(head, T.BorderLow, 1)
        local headLbl = New("TextLabel", {
            Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -32, 1, 0),
            BackgroundTransparency = 1, Text = "",
            TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
        })
        local chevron = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = T.TextDim,
            BorderSizePixel = 0, Rotation = 45, Parent = head,
        })
        Corner(chevron, 1)
        local picked = {}
        for _, v in ipairs(defaultList or {}) do picked[v] = true end
        local function getList()
            local out = {}
            for _, o in ipairs(options) do
                if picked[o] then out[#out + 1] = o end
            end
            return out
        end
        local function headText()
            local v = getList()
            if #v == 0 then return "Nenhum" end
            if #v == 1 then return v[1] end
            if #v == 2 then return v[1] .. ", " .. v[2] end
            return v[1] .. ", " .. v[2] .. "  +" .. (#v - 2)
        end
        headLbl.Text = headText()
        local isOpen = false
        local list = New("ScrollingFrame", {
            Size = UDim2.new(0, 200, 0, math.min(#options, 6) * 26 + 8),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3, ScrollBarImageColor3 = T.TextDim,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = false, ZIndex = 5, Parent = Overlay2B,
        })
        Corner(list, 8)
        Stroke(list, T.Border, 1)
        Padding(list, 4, 4, 4, 4)
        VList(list, 1)
        local function build()
            for _, c in ipairs(list:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for i, opt in ipairs(options) do
                local isSel = picked[opt] and true or false
                local b = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = T.CardHover,
                    BackgroundTransparency = isSel and 0.65 or 1,
                    Text = tostring(opt), TextColor3 = isSel and T.Text or T.TextDim,
                    FontFace = isSel and F.Medium or F.Regular, TextSize = 11,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false, LayoutOrder = i, Parent = list,
                })
                Corner(b, 5)
                Padding(b, 10, 32, 0, 0)
                local box = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.new(0, 14, 0, 14),
                    BackgroundColor3 = isSel and T.Primary or T.BgDeep,
                    BorderSizePixel = 0, Parent = b,
                })
                Corner(box, 3)
                Stroke(box, isSel and T.Primary or T.BorderLow, 1)
                if isSel then
                    New("TextLabel", {
                        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                        Text = "✓", TextColor3 = T.BgDeep, FontFace = F.Bold,
                        TextSize = 10, Parent = box,
                    })
                end
                b.MouseButton1Click:Connect(function()
                    picked[opt] = (not picked[opt]) or nil
                    headLbl.Text = headText()
                    build()
                    safe(cb, getList())
                end)
            end
        end
        build()
        local function close()
            if not isOpen then return end
            isOpen = false
            Anim.tween(list, { Size = UDim2.new(list.Size.X.Scale, list.Size.X.Offset, 0, 0) },
                0.12, "linear", "mdC_" .. tostring(list))
            task.delay(0.13, function() list.Visible = false end)
            Anim.tween(chevron, { Rotation = 45 }, 0.18, "gentle", "mdCh_" .. tostring(chevron))
            Anim.tween(headStroke, { Color = T.BorderLow }, 0.18, "gentle", "mdS_" .. tostring(head))
            if currentPop and currentPop.list == list then
                currentPop = nil
                catcher.Visible = false
            end
        end
        local function open()
            if currentPop then currentPop.close() end
            isOpen = true
            local sc = math.max(I.computeScale and I.computeScale() or 1, 0.01)
            local layerAbs = Overlay2B.AbsolutePosition
            local headAbs = head.AbsolutePosition
            local relX = (headAbs.X - layerAbs.X) / sc
            local relY = (headAbs.Y - layerAbs.Y) / sc + head.AbsoluteSize.Y / sc + 4
            local w = head.AbsoluteSize.X / sc
            local finalH = math.min(#options, 6) * 26 + 8
            local maxY = (Overlay2B.AbsoluteSize.Y / sc) - 8
            if relY + finalH > maxY then
                relY = (headAbs.Y - layerAbs.Y) / sc - finalH - 4
            end
            list.Position = UDim2.new(0, relX, 0, relY)
            list.Size = UDim2.new(0, w, 0, 0)
            list.Visible = true
            Anim.tween(list, { Size = UDim2.new(0, w, 0, finalH) }, 0.2, "smooth", "mdO_" .. tostring(list))
            Anim.tween(chevron, { Rotation = -135 }, 0.2, "smooth", "mdCh_" .. tostring(chevron))
            Anim.tween(headStroke, { Color = T.Accent }, 0.15, "gentle", "mdS_" .. tostring(head))
            catcher.Visible = true
            currentPop = { list = list, close = close }
        end
        head.MouseButton1Click:Connect(function()
            if isOpen then close() else open() end
        end)
        return {
            Set = function(_, v, fire)
                picked = {}
                for _, o in ipairs(v or {}) do picked[o] = true end
                headLbl.Text = headText()
                build()
                if fire then safe(cb, getList()) end
            end,
            Get = function() return getList() end,
        }
    end

    -- COLORPICKER
    function HAVAC.colorPicker(parent, label, defaultColor, cb)
        local c0 = typeof(defaultColor) == "Color3" and defaultColor or Color3.new(1, 1, 1)
        local h0, s0, v0 = c0:ToHSV()
        local h, s, v = h0, s0, v0
        local r = Row(parent, label)
        local hexLbl = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0),
            Size = UDim2.new(0, 60, 1, 0), BackgroundTransparency = 1,
            Text = hex(c0), TextColor3 = T.TextDim, FontFace = F.Medium,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
        })
        local swatch = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 40, 0, 22), BackgroundColor3 = c0,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = r,
        })
        Corner(swatch, 6)
        local swStroke = Stroke(swatch, T.Border, 1)
        local pop = New("Frame", {
            Size = UDim2.new(0, 220, 0, 196),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
            Visible = false, ZIndex = 5, Parent = Overlay2B,
        })
        Corner(pop, 10)
        Stroke(pop, T.Border, 1)
        local sv = New("Frame", {
            Position = UDim2.new(0, 10, 0, 10),
            Size = UDim2.new(0, 200, 0, 120),
            BackgroundColor3 = Color3.fromHSV(h, 1, 1),
            BorderSizePixel = 0, Parent = pop,
        })
        Corner(sv, 6)
        local white = New("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 1, Parent = sv,
        })
        Corner(white, 6)
        New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
        local black = New("Frame", {
            Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0, ZIndex = 2, Parent = sv,
        })
        Corner(black, 6)
        New("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
        local svDot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1,
            BorderSizePixel = 0, ZIndex = 4, Parent = sv,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = svDot })
        New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svDot })
        local svHit = New("TextButton", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, ZIndex = 5, Parent = sv,
        })
        local hue = New("Frame", {
            Position = UDim2.new(0, 10, 0, 140),
            Size = UDim2.new(0, 200, 0, 12),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, Parent = pop,
        })
        Corner(hue, 6)
        local keys = {}
        for i = 0, 6 do
            keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1))
        end
        New("UIGradient", { Color = ColorSequence.new(keys), Parent = hue })
        local hueDot = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(h, 0, 0.5, 0),
            Size = UDim2.new(0, 6, 0, 18), BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0, ZIndex = 4, Parent = hue,
        })
        Corner(hueDot, 3)
        New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1, Parent = hueDot })
        local hueHit = New("TextButton", {
            Position = UDim2.new(0, 0, 0, -4),
            Size = UDim2.new(1, 0, 1, 8),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
            ZIndex = 5, Parent = hue,
        })
        local preview = New("Frame", {
            Position = UDim2.new(0, 10, 0, 162),
            Size = UDim2.new(0, 26, 0, 24),
            BackgroundColor3 = c0, BorderSizePixel = 0, Parent = pop,
        })
        Corner(preview, 6)
        Stroke(preview, T.Border, 1)
        local hexBox = New("TextBox", {
            Position = UDim2.new(0, 42, 0, 162),
            Size = UDim2.new(0, 168, 0, 24),
            BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
            Text = hex(c0), ClearTextOnFocus = false,
            TextColor3 = T.Text, FontFace = F.Medium, TextSize = 11,
            PlaceholderText = "#RRGGBB", Parent = pop,
        })
        Corner(hexBox, 6)
        local hexStroke = Stroke(hexBox, T.BorderLow, 1)
        local function paint()
            local cc = Color3.fromHSV(h, s, v)
            sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
            svDot.Position = UDim2.new(s, 0, 1 - v, 0)
            hueDot.Position = UDim2.new(h, 0, 0.5, 0)
            preview.BackgroundColor3 = cc
            swatch.BackgroundColor3 = cc
            hexLbl.Text = hex(cc)
            if not hexBox:IsFocused() then hexBox.Text = hex(cc) end
        end
        local function commit()
            paint()
            safe(cb, Color3.fromHSV(h, s, v))
        end
        paint()
        local function pointer(input)
            if input and input.UserInputType == Enum.UserInputType.Touch then
                return Vector2.new(input.Position.X, input.Position.Y)
            end
            return game:GetService("UserInputService"):GetMouseLocation()
                - game:GetService("GuiService"):GetGuiInset()
        end
        local mode = nil
        local function applyAt(input)
            local pt = pointer(input)
            local box = (mode == "sv") and sv or hue
            local ap, as = box.AbsolutePosition, box.AbsoluteSize
            local rx = math.clamp((pt.X - ap.X) / math.max(as.X, 1), 0, 1)
            if mode == "sv" then
                s = rx
                v = 1 - math.clamp((pt.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
            else
                h = math.min(rx, 0.999)
            end
            commit()
        end
        local function grab(which)
            return function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                   and input.UserInputType ~= Enum.UserInputType.Touch then return end
                mode = which
                applyAt(input)
            end
        end
        svHit.InputBegan:Connect(grab("sv"))
        hueHit.InputBegan:Connect(grab("hue"))
        local UIS = game:GetService("UserInputService")
        Track(UIS.InputChanged:Connect(function(input)
            if mode and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                applyAt(input)
            end
        end))
        Track(UIS.InputEnded:Connect(function(input)
            if mode and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch) then
                mode = nil
            end
        end))
        hexBox.Focused:Connect(function()
            Anim.tween(hexStroke, { Color = T.Accent }, 0.12, "gentle", "cpHx")
        end)
        hexBox.FocusLost:Connect(function()
            Anim.tween(hexStroke, { Color = T.BorderLow }, 0.15, "gentle", "cpHx")
            local c = parseHex(hexBox.Text)
            if c then
                h, s, v = c:ToHSV()
                commit()
            else
                hexBox.Text = hex(Color3.fromHSV(h, s, v))
            end
        end)
        local isOpen = false
        local function close()
            if not isOpen then return end
            isOpen = false
            mode = nil
            Anim.tween(pop, { Size = UDim2.new(0, 220, 0, 0) }, 0.13, "linear", "cpClose")
            task.delay(0.14, function() pop.Visible = false end)
            if currentPop and currentPop.list == pop then
                currentPop = nil
                catcher.Visible = false
            end
        end
        local function open()
            if currentPop then currentPop.close() end
            isOpen = true
            local sc = math.max(I.computeScale and I.computeScale() or 1, 0.01)
            local layerAbs = Overlay2B.AbsolutePosition
            local swAbs = swatch.AbsolutePosition
            local relX = (swAbs.X - layerAbs.X) / sc + swatch.AbsoluteSize.X / sc - 220
            local relY = (swAbs.Y - layerAbs.Y) / sc + swatch.AbsoluteSize.Y / sc + 6
            local maxX = (Overlay2B.AbsoluteSize.X / sc) - 228
            if relX > maxX then relX = maxX end
            if relX < 4 then relX = 4 end
            local maxY = (Overlay2B.AbsoluteSize.Y / sc) - 204
            if relY > maxY then
                relY = (swAbs.Y - layerAbs.Y) / sc - 196 - 6
            end
            pop.Position = UDim2.new(0, relX, 0, relY)
            pop.Size = UDim2.new(0, 220, 0, 0)
            pop.Visible = true
            paint()
            Anim.tween(pop, { Size = UDim2.new(0, 220, 0, 196) }, 0.22, "smooth", "cpOpen")
            catcher.Visible = true
            currentPop = { list = pop, close = close }
        end
        swatch.MouseButton1Click:Connect(function()
            if isOpen then close() else open() end
        end)
        return {
            Set = function(_, color, fire)
                if typeof(color) ~= "Color3" then return end
                h, s, v = color:ToHSV()
                paint()
                if fire then safe(cb, color) end
            end,
            Get = function() return Color3.fromHSV(h, s, v) end,
        }
    end

    function HAVAC.bindColor(parent, label, key, cb)
        local Config = I.Config
        if type(Config) ~= "table" then
            error("HAVAC.bindColor: I.Config not exposed by Block 1", 2)
        end
        if not parseHex(Config[key] or "") then
            Config[key] = "#FFFFFF"
        end
        local picker = HAVAC.colorPicker(parent, label, parseHex(Config[key]), function(c)
            Config[key] = hex(c)
            if I.Persistence and I.Persistence.save then I.Persistence.save(Config) end
            if cb then safe(cb, c) end
        end)
        return picker
    end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- END OF BLOCK 2 + BLOCK 2B
-- ============================================================================
-- [PARTE 3 VIRÁ AQUI — NÃO APAGUE ESTE COMENTÁRIO]

-- ============================================================================
-- BLOCK 3: DYNAMIC ISLAND
-- ============================================================================

local function __block3(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 3 needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim = I.T, I.Anim
    local New, Corner, Stroke = I.New, I.Corner, I.Stroke
    local Padding = I.Padding
    local HList, Track = I.HList, I.Track
    local F, logError, Gui = I.F, I.logError, I.Gui
    local Config = I.Config
    if not Gui then error("HAVAC CORE Block 3: Gui missing.", 2) end

    local Players     = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local Stats       = game:GetService("Stats")
    local RunService  = game:GetService("RunService")
    local TweenService= game:GetService("TweenService")
    local UIS         = game:GetService("UserInputService")

    local liveFps, livePing, sessionStart = 60, 0, tick()
    local activeFeatures = {}

    do
        local fc, ls = 0, tick()
        Track(RunService.RenderStepped:Connect(function()
            fc = fc + 1
            local now = tick()
            if now - ls >= 1 then
                liveFps = math.floor(fc / (now - ls) + 0.5)
                fc, ls = 0, now
            end
        end))
    end

    task.spawn(function()
        while Gui and Gui.Parent do
            local ok, ping = pcall(function()
                return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            if ok and type(ping) == "number" then livePing = ping end
            task.wait(1)
        end
    end)

    local function sessionText()
        local s = math.floor(tick() - sessionStart)
        if s < 60 then return s .. "s" end
        if s < 3600 then return math.floor(s / 60) .. "m " .. (s % 60) .. "s" end
        return math.floor(s / 3600) .. "h " .. math.floor((s % 3600) / 60) .. "m"
    end
    local function fpsColor(f)
        if f >= 50 then return T.Success end
        if f >= 30 then return T.Warning end
        return T.Error
    end
    local function pingColor(p)
        if p <= 100 then return T.Success end
        if p <= 200 then return T.Warning end
        return T.Error
    end
    local function currentPage()
        if type(I.ActivePage) == "function" then
            local ok, id = pcall(I.ActivePage)
            if ok and id and I.Pages and I.Pages[id] and I.Pages[id].title then
                return I.Pages[id].title
            end
        end
        return "Status"
    end
    local function activeCount()
        local n = 0
        for _ in pairs(activeFeatures) do n = n + 1 end
        return n
    end
    local function activeListSorted(limit)
        local list = {}
        for name in pairs(activeFeatures) do list[#list + 1] = name end
        table.sort(list)
        if limit and #list > limit then
            local out = {}
            for i = 1, limit do out[i] = list[i] end
            return out, #list - limit
        end
        return list, 0
    end

    local ISL_H, ISL_COMPACT_W, ISL_EXPANDED_W, ISL_EXPANDED_H = 38, 236, 372, 250

    local Island = New("Frame", {
        Name = "HAVAC_Island", AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, -80),
        Size = UDim2.new(0, ISL_COMPACT_W, 0, ISL_H),
        BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false, ZIndex = 150, Parent = Gui,
    })
    local islandCorner = Corner(Island, ISL_H / 2)
    local islandStroke = Stroke(Island, T.Border, 1)

    local Pill = New("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, ISL_H), BackgroundTransparency = 1,
        ZIndex = 151, Parent = Island,
    })

    local logoHolder = New("Frame", {
        Position = UDim2.new(0, 5, 0.5, -14), Size = UDim2.new(0, 28, 0, 28),
        BackgroundColor3 = T.Primary, BorderSizePixel = 0, Parent = Pill,
    })
    Corner(logoHolder, 14)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "H", TextColor3 = T.BgDeep, FontFace = F.Bold, TextSize = 15, Parent = logoHolder,
    })

    local runDot = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.new(0, 9, 0, 9), BackgroundColor3 = T.Success,
        BorderSizePixel = 0, Visible = false, ZIndex = 3, Parent = logoHolder,
    })
    Corner(runDot, 5)
    Stroke(runDot, T.BgDeep, 2)
    do
        local ring = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.Success,
            BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = runDot,
        })
        New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
        TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
            { Size = UDim2.new(2.2, 0, 2.2, 0), BackgroundTransparency = 1 }):Play()
    end

    local pillText = New("TextLabel", {
        Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -88, 1, 0),
        BackgroundTransparency = 1, Text = "HAVAC CORE", TextColor3 = T.Text,
        FontFace = F.Medium, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = Pill,
    })

    local pillBars = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 14), BackgroundTransparency = 1, Parent = Pill,
    })
    HList(pillBars, 2, Enum.VerticalAlignment.Bottom)
    local barRefs = {}
    for _, h in ipairs({ 5, 7, 10, 13 }) do
        local bar = New("Frame", {
            Size = UDim2.new(0, 3, 0, h), BackgroundColor3 = T.Text,
            BorderSizePixel = 0, Parent = pillBars,
        })
        Corner(bar, 1)
        bar:SetAttribute("H", h)
        barRefs[#barRefs + 1] = bar
    end

    local hit = New("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 160, Parent = Island,
    })

    local Card = New("CanvasGroup", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        GroupTransparency = 1, Visible = false, ZIndex = 152, Parent = Island,
    })
    Padding(Card, 18, 18, 16, 14)

    local rowRefs = {}
    local function cardRow(y, h)
        local r = New("CanvasGroup", {
            Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, h),
            BackgroundTransparency = 1, Parent = Card,
        })
        rowRefs[#rowRefs + 1] = { frame = r, y = y }
        return r
    end

    local header = cardRow(0, 48)
    local avWrap = New("Frame", {
        Size = UDim2.new(0, 46, 0, 46), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, Parent = header,
    })
    Corner(avWrap, 12)
    local avStroke = Stroke(avWrap, T.Accent, 1.5)
    avStroke.Transparency = 0.35
    local avImg = New("ImageLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Image = "", ScaleType = Enum.ScaleType.Crop, Parent = avWrap,
    })
    Corner(avImg, 12)
    task.spawn(function()
        if not LocalPlayer then return end
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and type(url) == "string" and url ~= "" then
            if avImg.Parent then avImg.Image = url end
        end
    end)
    local onDot = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.new(0, 10, 0, 10), BackgroundColor3 = T.Success,
        BorderSizePixel = 0, ZIndex = 3, Parent = avWrap,
    })
    Corner(onDot, 5)
    Stroke(onDot, T.BgDeep, 2)

    local islName = New("TextLabel", {
        Position = UDim2.new(0, 58, 0, 4), Size = UDim2.new(1, -170, 0, 20),
        BackgroundTransparency = 1,
        Text = LocalPlayer and (LocalPlayer.DisplayName or LocalPlayer.Name) or "Player",
        TextColor3 = T.Text, FontFace = F.Bold, TextSize = 15,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })
    local islHandle = New("TextLabel", {
        Position = UDim2.new(0, 58, 0, 26), Size = UDim2.new(1, -170, 0, 14),
        BackgroundTransparency = 1,
        Text = LocalPlayer and ("@" .. LocalPlayer.Name) or "",
        TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
    })
    local islSession = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4),
        Size = UDim2.new(0, 100, 0, 20), BackgroundTransparency = 1,
        Text = "0s", TextColor3 = T.Text, FontFace = F.Bold, TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
    })
    New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 26),
        Size = UDim2.new(0, 100, 0, 12), BackgroundTransparency = 1,
        Text = "sessao", TextColor3 = T.TextDim, FontFace = F.Regular,
        TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
    })

    local div = cardRow(58, 1)
    local divLine = New("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Border,
        BorderSizePixel = 0, Parent = div,
    })
    New("UIGradient", {
        Parent = divLine,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
    })

    local statsRow = cardRow(68, 50)
    local function statCol(xPct, label)
        local col = New("Frame", {
            Position = UDim2.new(xPct, xPct > 0 and 8 or 0, 0, 0),
            Size = UDim2.new(0.5, -8, 1, 0), BackgroundTransparency = 1, Parent = statsRow,
        })
        local valLbl = New("TextLabel", {
            Size = UDim2.new(0, 100, 0, 24), BackgroundTransparency = 1,
            Text = "-", RichText = true, TextColor3 = T.Text, FontFace = F.Bold,
            TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = col,
        })
        New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6),
            Size = UDim2.new(0, 70, 0, 12), BackgroundTransparency = 1,
            Text = label, TextColor3 = T.TextDim, FontFace = F.Medium,
            TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, Parent = col,
        })
        local track = New("Frame", {
            Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, 0, 0, 5),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = col,
        })
        Corner(track, 3)
        local fill = New("Frame", {
            Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Success,
            BorderSizePixel = 0, Parent = track,
        })
        Corner(fill, 3)
        return { val = valLbl, fill = fill }
    end
    local fpsStat = statCol(0, "FPS")
    local pingStat = statCol(0.5, "PING")

    local chipsRow = cardRow(128, 26)
    HList(chipsRow, 6)
    local function chip(label, order)
        local c = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 24),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, LayoutOrder = order, Parent = chipsRow,
        })
        Corner(c, 12)
        Padding(c, 9, 10, 0, 0)
        HList(c, 5)
        New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1, Text = label, TextColor3 = T.TextDim,
            FontFace = F.Regular, TextSize = 10, LayoutOrder = 1, Parent = c,
        })
        local v = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1, Text = "-", TextColor3 = T.Text,
            FontFace = F.Bold, TextSize = 10, LayoutOrder = 2, Parent = c,
        })
        return v
    end
    local playersChip = chip("Players", 1)
    local runningChip = chip("Ativos", 2)
    local pageChip    = chip("Tab", 3)

    local statusRow = cardRow(164, 16)
    local statusDot = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1, 0.5, 0),
        Size = UDim2.new(0, 6, 0, 6), BackgroundColor3 = T.TextMute,
        BorderSizePixel = 0, Parent = statusRow,
    })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = statusDot })
    local statusLbl = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -12, 1, 0),
        BackgroundTransparency = 1, Text = "Nada ativo", TextColor3 = T.TextDim,
        FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = statusRow,
    })

    local footerRow = cardRow(190, 20)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "Clique para abrir  ·  Arraste para mover",
        TextColor3 = T.TextMute, FontFace = F.Regular, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = footerRow,
    })

    local expanded, shown, hovering, isDragging, didMove = false, false, false, false, false

    local function paintFPS()
        local f = liveFps
        local color = fpsColor(f)
        fpsStat.val.Text = ('%d  <font color="rgb(160,160,170)" size="11">fps</font>'):format(f)
        Anim.tween(fpsStat.fill, {
            Size = UDim2.new(math.clamp(f / 60, 0.04, 1), 0, 1, 0),
            BackgroundColor3 = color,
        }, 0.3, "gentle", "islFps")
    end
    local function paintPing()
        local p = livePing
        local color = pingColor(p)
        pingStat.val.Text = ('%d  <font color="rgb(160,160,170)" size="11">ms</font>'):format(p)
        Anim.tween(pingStat.fill, {
            Size = UDim2.new(math.clamp(1 - p / 300, 0.04, 1), 0, 1, 0),
            BackgroundColor3 = color,
        }, 0.3, "gentle", "islPing")
    end
    local function paintChips()
        playersChip.Text = ("%d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers)
        local n = activeCount()
        runningChip.Text = tostring(n)
        runningChip.TextColor3 = n > 0 and T.Accent or T.Text
        pageChip.Text = currentPage()
    end
    local function paintStatus()
        local n = activeCount()
        if n == 0 then
            statusLbl.Text = "Nada ativo"
            statusLbl.TextColor3 = T.TextDim
            statusDot.BackgroundColor3 = T.TextMute
        else
            local list, extra = activeListSorted(3)
            local text = "Ativo: " .. table.concat(list, "  ·  ")
            if extra > 0 then text = text .. "  +" .. extra end
            statusLbl.Text = text
            statusLbl.TextColor3 = T.Text
            statusDot.BackgroundColor3 = T.Success
        end
    end
    local function paintSession() islSession.Text = sessionText() end
    local function paintBars()
        local lit = livePing <= 90 and 4
                 or (livePing <= 150 and 3)
                 or (livePing <= 250 and 2)
                 or 1
        local col = livePing > 400 and T.Error
                 or (livePing > 220 and T.Warning)
                 or T.Text
        for i, bar in ipairs(barRefs) do
            Anim.tween(bar, { BackgroundColor3 = (i <= lit) and col or T.CardHover },
                0.25, "gentle", "islBar" .. i)
        end
    end
    local function paintRunDot()
        local on = activeCount() > 0
        if on == runDot.Visible then return end
        runDot.Visible = on
        if on then
            runDot.Size = UDim2.new(0, 2, 0, 2)
            Anim.tween(runDot, { Size = UDim2.new(0, 9, 0, 9) }, 0.45, "overshoot", "islRunDot")
        end
    end
    local function pillTextFor() return "HAVAC  ·  " .. currentPage() end
    local function refreshAll()
        paintFPS(); paintPing(); paintChips(); paintStatus()
        paintSession(); paintBars(); paintRunDot()
    end

    local function setExpanded(on)
        if on == expanded then return end
        expanded = on
        if on then
            for _, r in ipairs(rowRefs) do
                r.frame.Position = UDim2.new(0, 0, 0, r.y + 12)
                r.frame.GroupTransparency = 1
            end
            refreshAll()
            Card.Visible = true
            Anim.tween(Island, {
                Size = UDim2.new(0, ISL_EXPANDED_W + 8, 0, ISL_EXPANDED_H + 8),
            }, 0.32, "smooth", "islExpand")
            task.delay(0.3, function()
                if expanded then
                    Anim.tween(Island, {
                        Size = UDim2.new(0, ISL_EXPANDED_W, 0, ISL_EXPANDED_H),
                    }, 0.35, "gentle", "islExpand2")
                end
            end)
            Anim.tween(islandCorner, { CornerRadius = UDim.new(0, 24) }, 0.4, "smooth", "islCorner")
            Anim.tween(Pill, { GroupTransparency = 1 }, 0.12, "linear", "islPill")
            Anim.tween(islandStroke, { Color = T.Accent }, 0.2, "gentle", "islStroke")
            task.delay(0.3, function()
                if expanded then
                    Anim.tween(islandStroke, { Color = T.Border }, 0.6, "gentle", "islStroke")
                end
            end)
            task.delay(0.08, function()
                if not expanded then return end
                Anim.tween(Card, { GroupTransparency = 0 }, 0.2, "gentle", "islCard")
                for i, r in ipairs(rowRefs) do
                    task.delay((i - 1) * 0.04, function()
                        if not expanded then return end
                        Anim.tween(r.frame, {
                            Position = UDim2.new(0, 0, 0, r.y),
                            GroupTransparency = 0,
                        }, 0.4, "smooth", "islRow" .. i)
                    end)
                end
            end)
        else
            Anim.tween(Card, { GroupTransparency = 1 }, 0.12, "linear", "islCard")
            Anim.tween(Island, {
                Size = UDim2.new(0, ISL_COMPACT_W - 16, 0, ISL_H - 4),
            }, 0.28, "smooth", "islCollapse")
            task.delay(0.28, function()
                if not expanded then
                    Anim.tween(Island, {
                        Size = UDim2.new(0, ISL_COMPACT_W, 0, ISL_H),
                    }, 0.4, "overshoot", "islCollapse2")
                end
            end)
            Anim.tween(islandCorner, { CornerRadius = UDim.new(1, 0) }, 0.35, "smooth", "islCorner")
            task.delay(0.1, function()
                if not expanded then
                    Anim.tween(Pill, { GroupTransparency = 0 }, 0.2, "gentle", "islPill")
                end
            end)
            task.delay(0.22, function()
                if not expanded then Card.Visible = false end
            end)
        end
    end

    local function showIsland()
        if shown then return end
        shown = true
        expanded = false
        Island.Visible = true
        pillText.Text = pillTextFor()
        Island.Size = UDim2.new(0, ISL_COMPACT_W, 0, ISL_H)
        islandCorner.CornerRadius = UDim.new(1, 0)
        Pill.GroupTransparency = 0
        Card.Visible = false
        Card.GroupTransparency = 1
        local x = (Config and Config.islandX) or 0.5
        local y = (Config and Config.islandY) or 12
        Island.Position = UDim2.new(x, 0, 0, -80)
        Anim.tween(Island, { Position = UDim2.new(x, 0, 0, y) }, 0.5, "overshoot", "islShow")
        for i, bar in ipairs(barRefs) do
            bar.Size = UDim2.new(0, 3, 0, 2)
            task.delay(0.3 + i * 0.06, function()
                if shown then
                    Anim.tween(bar, {
                        Size = UDim2.new(0, 3, 0, bar:GetAttribute("H") or 10),
                    }, 0.4, "overshoot", "islBar" .. i)
                end
            end)
        end
        refreshAll()
    end
    local function hideIsland()
        if not shown then return end
        shown = false
        hovering = false
        Anim.tween(Island, {
            Position = UDim2.new(Island.Position.X.Scale, 0, 0, -ISL_EXPANDED_H - 30),
        }, 0.3, "enter", "islHide")
        task.delay(0.32, function()
            if not shown then
                Island.Visible = false
                expanded = false
            end
        end)
    end

    task.spawn(function()
        while Gui and Gui.Parent do
            if shown then
                paintSession(); paintChips(); paintStatus(); paintRunDot()
                if expanded then paintFPS(); paintPing(); paintBars() end
                if not expanded then
                    local t = pillTextFor()
                    if pillText.Text ~= t then pillText.Text = t end
                end
            end
            task.wait(0.5)
        end
    end)

    local dragFrom = nil
    local islandStartX, islandStartY = 0, 0

    hit.MouseEnter:Connect(function()
        hovering = true
        if isDragging then return end
        setExpanded(true)
    end)
    hit.MouseLeave:Connect(function()
        hovering = false
        task.delay(0.2, function()
            if not hovering and not isDragging then setExpanded(false) end
        end)
    end)
    hit.InputBegan:Connect(function(input)
        if not shown then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        isDragging = true
        didMove = false
        dragFrom = input.Position
        local vp = Gui.AbsoluteSize
        islandStartX = Island.Position.X.Scale * vp.X + Island.Position.X.Offset
        islandStartY = Island.Position.Y.Offset
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and isDragging then
                isDragging = false
                if didMove then
                    if Config then
                        Config.islandX = Island.Position.X.Scale
                        Config.islandY = Island.Position.Y.Offset
                        if I.Persistence and I.Persistence.save then I.Persistence.save(Config) end
                    end
                else
                    if HAVAC.open then HAVAC.open() end
                end
            end
        end)
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if not isDragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragFrom
        if not didMove and d.Magnitude > 6 then
            didMove = true
            setExpanded(false)
        end
        if didMove then
            local vp = Gui.AbsoluteSize
            local halfW = (expanded and ISL_EXPANDED_W or ISL_COMPACT_W) / 2 + 8
            local nx = math.clamp(islandStartX + d.X, halfW, math.max(halfW, vp.X - halfW))
            local ny = math.clamp(islandStartY + d.Y, 4, math.max(4, vp.Y - ISL_H - 4))
            Island.Position = UDim2.new(nx / vp.X, 0, 0, ny)
        end
    end))

    local flashSeq = 0
    local function flash(title, bodyText, color)
        if not shown or expanded then return end
        flashSeq = flashSeq + 1
        local my = flashSeq
        pillText.Text = tostring(title or "")
            .. (bodyText and bodyText ~= "" and ("  ·  " .. tostring(bodyText)) or "")
        Anim.tween(logoHolder, { BackgroundColor3 = color or T.Accent }, 0.2, "gentle", "islFlashLogo")
        Anim.tween(islandStroke, { Color = color or T.Accent }, 0.2, "gentle", "islFlashStroke")
        task.delay(2.2, function()
            if flashSeq ~= my then return end
            Anim.tween(logoHolder, { BackgroundColor3 = T.Primary }, 0.4, "gentle", "islFlashLogo")
            Anim.tween(islandStroke, { Color = T.Border }, 0.5, "gentle", "islFlashStroke")
            if shown and not expanded then pillText.Text = pillTextFor() end
        end)
    end

    if type(HAVAC.notify) == "function" then
        local origNotify = HAVAC.notify
        HAVAC.notify = function(kind, title, bodyText, duration)
            origNotify(kind, title, bodyText, duration)
            local col = kind == "ok" and T.Success
                     or (kind == "warn" and T.Warning)
                     or (kind == "err" and T.Error)
                     or T.Accent
            flash(title, bodyText, col)
        end
    end

    if I.Window then
        I.Window:GetPropertyChangedSignal("Visible"):Connect(function()
            if I.Window.Visible then
                hideIsland()
            else
                task.delay(0.2, function()
                    if not I.Window.Visible then showIsland() end
                end)
            end
        end)
        if I.Window.Visible then
            shown = false
        else
            task.delay(1.2, function()
                if I.Window and not I.Window.Visible then showIsland() end
            end)
        end
    end

    HAVAC.island = {
        Show = showIsland,
        Hide = hideIsland,
        Flash = function(t, b, c) flash(t, b, c) end,
        SetFeature = function(name, active)
            if type(name) ~= "string" or name == "" then return end
            if active then activeFeatures[name] = true
            else activeFeatures[name] = nil end
            if shown then paintChips(); paintStatus(); paintRunDot() end
        end,
        ClearFeatures = function()
            for k in pairs(activeFeatures) do activeFeatures[k] = nil end
            if shown then paintChips(); paintStatus(); paintRunDot() end
        end,
        IsShown = function() return shown end,
        IsExpanded = function() return expanded end,
    }
    function HAVAC.setFeature(name, active) HAVAC.island.SetFeature(name, active) end
    function HAVAC.clearFeatures() HAVAC.island.ClearFeatures() end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- BLOCK 4: PANIC + MOBILE
-- ============================================================================

local function __block4(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 4 needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim, = I.T, I.Anim
    local New, Corner, Stroke = I.New, I.Corner, I.Stroke
    local Padding = I.Padding
    local Track = I.Track
    local F, logError, Gui = I.F, I.logError, I.Gui
    local Config = I.Config
    if not Gui then error("HAVAC CORE Block 4: Gui missing.", 2) end

    local UIS = game:GetService("UserInputService")
    local GuiService = game:GetService("GuiService")

    local function sweepNamedGuis()
        local parents = { Gui }
        local ok, hui = pcall(function()
            return type(gethui) == "function" and gethui() or nil
        end)
        if ok and hui then table.insert(parents, hui) end
        table.insert(parents, game:GetService("CoreGui"))
        local pg = game:GetService("Players").LocalPlayer
        if pg then
            local pgui = pg:FindFirstChild("PlayerGui")
            if pgui then table.insert(parents, pgui) end
        end
        for _, p in ipairs(parents) do
            if p then
                for _, c in ipairs(p:GetChildren()) do
                    if c:IsA("ScreenGui") and tostring(c.Name):sub(1, #"HAVAC_CORE") == "HAVAC_CORE" then
                        pcall(function() c:Destroy() end)
                    end
                end
            end
        end
    end

    local function clearOverrides()
        HAVAC.notify = function() end
    end

    local panicRan = false
    local function runPanic()
        if panicRan then return end
        panicRan = true
        for _, fn in ipairs(HAVAC._hooks.panic) do pcall(fn) end
        if Anim and Anim.cancelAll then pcall(function() Anim.cancelAll() end) end
        local list = I._Connections
        if type(list) == "table" then
            for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
        end
        if Gui then
            pcall(function()
                for _, child in ipairs(Gui:GetChildren()) do
                    pcall(function() child:Destroy() end)
                end
            end)
        end
        pcall(function() if Gui then Gui:Destroy() end end)
        sweepNamedGuis()
        clearOverrides()
        if HAVAC.island then
            HAVAC.island = {
                Show = function() end, Hide = function() end, Flash = function() end,
                SetFeature = function() end, ClearFeatures = function() end,
                IsShown = function() return false end,
                IsExpanded = function() return false end,
            }
        end
        if HAVAC.mobile then
            HAVAC.mobile = {
                show = function() end, hide = function() end,
                setSequence = function() end,
                enableGesture = function() end, disableGesture = function() end,
            }
        end
        I.Gui = nil
        print("[HAVAC CORE] panic: UI removed.")
    end

    HAVAC.panic = runPanic

    local function keyNameOf(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            return input.KeyCode.Name
        end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MouseButton2" end
        if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MouseButton3" end
        return nil
    end

    local panicKey = (Config and Config.panicKey) or "RightShift"
    local function setPanicKey(name)
        if type(name) ~= "string" then return false end
        panicKey = name
        if Config then
            Config.panicKey = name
            if I.Persistence and I.Persistence.save then pcall(I.Persistence.save, Config) end
        end
        return true
    end
    HAVAC.setPanicKey = setPanicKey
    HAVAC.getPanicKey = function() return panicKey end

    Track(UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if panicKey == "None" then return end
        local n = keyNameOf(input)
        if not n then return end
        if n == panicKey then pcall(runPanic) end
    end))

    local isTouch = UIS.TouchEnabled and true or false

    local function safeInsets()
        local inset = Vector2.new(0, 0)
        pcall(function() inset = GuiService:GetGuiInset() end)
        local topSafe = math.max(inset.Y + 8, 20)
        local bottomSafe = 20
        return topSafe, bottomSafe, Gui.AbsoluteSize
    end

    local FloatBtn = New("TextButton", {
        Name = "HAVAC_FloatBtn", AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(0, 46, 0, 46),
        BackgroundColor3 = T.BgDeep, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Visible = false, ZIndex = 180, Parent = Gui,
    })
    Corner(FloatBtn, 23)
    local floatStroke = Stroke(FloatBtn, T.Border, 1)
    local floatLabel = New("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "H", TextColor3 = T.Text, FontFace = F.Bold, TextSize = 20, Parent = FloatBtn,
    })

    local floatDragging, floatDidMove, floatDragFrom = false, false, nil
    local floatStartPos = UDim2.new(0, 12, 0.5, 0)

    FloatBtn.MouseEnter:Connect(function()
        if floatDragging then return end
        Anim.tween(FloatBtn, { Size = UDim2.new(0, 50, 0, 50) }, 0.15, "gentle", "fbSize")
        Anim.tween(floatStroke, { Color = T.Accent }, 0.15, "gentle", "fbStroke")
    end)
    FloatBtn.MouseLeave:Connect(function()
        if floatDragging then return end
        Anim.tween(FloatBtn, { Size = UDim2.new(0, 46, 0, 46) }, 0.15, "gentle", "fbSize")
        Anim.tween(floatStroke, { Color = T.Border }, 0.15, "gentle", "fbStroke")
    end)
    FloatBtn.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        floatDragging = true
        floatDidMove = false
        floatDragFrom = input.Position
        floatStartPos = FloatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and floatDragging then
                floatDragging = false
                if floatDidMove then
                    if Config then
                        Config.floatBtnX = FloatBtn.Position.X.Offset
                        Config.floatBtnY = FloatBtn.Position.Y.Scale
                        Config.floatBtnHasPos = true
                        if I.Persistence and I.Persistence.save then pcall(I.Persistence.save, Config) end
                    end
                else
                    if HAVAC.toggle then HAVAC.toggle() end
                end
            end
        end)
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if not floatDragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
           and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - floatDragFrom
        if not floatDidMove and d.Magnitude > 6 then
            floatDidMove = true
            Anim.tween(FloatBtn, { Size = UDim2.new(0, 46, 0, 46) }, 0.1, "linear", "fbSize")
        end
        if floatDidMove then
            local topSafe, bottomSafe, vp = safeInsets()
            local nx = math.clamp(floatStartPos.X.Offset + d.X, 4, math.max(4, vp.X - 54))
            local ny = math.clamp(floatStartPos.Y.Scale * vp.Y + d.Y, topSafe, math.max(topSafe, vp.Y - bottomSafe - 46))
            FloatBtn.Position = UDim2.new(0, nx, 0, ny)
            FloatBtn.AnchorPoint = Vector2.new(0, 0)
        end
    end))

    local mobileShown = false
    local function showFloat()
        if mobileShown then return end
        mobileShown = true
        local topSafe, bottomSafe, vp = safeInsets()
        local sx, sy = 12, vp.Y / 2
        if Config and Config.floatBtnHasPos and tonumber(Config.floatBtnX) and tonumber(Config.floatBtnY) then
            sx = math.clamp(tonumber(Config.floatBtnX), 4, math.max(4, vp.X - 54))
            sy = math.clamp(tonumber(Config.floatBtnY), topSafe, math.max(topSafe, vp.Y - bottomSafe - 46))
            FloatBtn.AnchorPoint = Vector2.new(0, 0)
        end
        FloatBtn.Position = UDim2.new(0, sx, 0, sy)
        FloatBtn.Visible = true
        FloatBtn.Size = UDim2.new(0, 20, 0, 20)
        floatLabel.TextTransparency = 1
        Anim.tween(FloatBtn, { Size = UDim2.new(0, 46, 0, 46) }, 0.4, "overshoot", "fbShow")
        task.delay(0.15, function()
            if mobileShown then
                Anim.tween(floatLabel, { TextTransparency = 0 }, 0.2, "gentle", "fbShowLabel")
            end
        end)
    end
    local function hideFloat()
        if not mobileShown then return end
        mobileShown = false
        Anim.tween(FloatBtn, { Size = UDim2.new(0, 12, 0, 12) }, 0.2, "enter", "fbHide")
        Anim.tween(floatLabel, { TextTransparency = 1 }, 0.15, "linear", "fbHideLabel")
        task.delay(0.22, function()
            if not mobileShown then FloatBtn.Visible = false end
        end)
    end

    local seqCount, seqWindow, seqEnabled = 3, 1.2, true
    local seqTimes = {}
    local function resetSeq() seqTimes = {} end
    local function onTap()
        if not seqEnabled or mobileShown then return end
        local now = tick()
        local fresh = {}
        for _, t in ipairs(seqTimes) do
            if now - t <= seqWindow then fresh[#fresh + 1] = t end
        end
        fresh[#fresh + 1] = now
        seqTimes = fresh
        if #seqTimes >= seqCount then
            resetSeq()
            if HAVAC.open then pcall(HAVAC.open) end
            showFloat()
        end
    end
    Track(UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        onTap()
    end))

    local gestureEnabled = false
    local function enableGesture()
        if gestureEnabled then return end
        gestureEnabled = true
        if not I.Content then return end
        local h
        for _, c in ipairs(I.Content:GetChildren()) do
            if c:IsA("Frame") and c.AbsoluteSize.Y <= 80 then h = c break end
        end
        if not h then return end
        local fromY = nil
        h.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            fromY = input.Position.Y
        end)
        h.InputEnded:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            if fromY and input.Position.Y - fromY > 80 then
                if HAVAC.close then pcall(HAVAC.close) end
                task.delay(0.3, function() if not mobileShown and isTouch then showFloat() end end)
            end
            fromY = nil
        end)
    end
    local function disableGesture() gestureEnabled = false end

    HAVAC.mobile = {
        show = showFloat, hide = hideFloat,
        isEnabled = function() return mobileShown end,
        isTouch = function() return isTouch end,
        setSequence = function(n, w)
            seqCount = math.max(2, math.min(6, tonumber(n) or 3))
            seqWindow = math.max(0.4, math.min(3, tonumber(w) or 1.2))
            resetSeq()
        end,
        enableGesture = enableGesture,
        disableGesture = disableGesture,
    }

    if isTouch then
        task.delay(0.6, function()
            if HAVAC.mobile and HAVAC.mobile.show then showFloat() end
        end)
        task.delay(1.0, function() pcall(enableGesture) end)
    end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- BLOCK 5: SETTINGS + SEARCH + THEMES UI
-- ============================================================================

local function __block5(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 5 needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim, Locale, Caps = I.T, I.Anim, I.Locale, I.Caps
    local New, Corner, Stroke = I.New, I.Corner, I.Stroke
    local Padding = I.Padding
    local VList, HList = I.VList, I.HList
    local Track = I.Track
    local F, logError, Gui = I.F, I.logError, I.Gui
    local Config = I.Config
    if not Gui or not I.Window or not I.Content then
        error("HAVAC CORE Block 5: shell missing.", 2)
    end

    local HttpService = game:GetService("HttpService")
    local UIS = game:GetService("UserInputService")

    local function safe(cb, ...)
        if type(cb) ~= "function" then return end
        local ok, err = pcall(cb, ...)
        if not ok then logError("callback", err) end
    end
    local function hexStr(c)
        return ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
    end
    local function parseHexStr(s)
        s = tostring(s or ""):gsub("[#%s]", "")
        if #s == 6 and s:match("^%x+$") then
            return Color3.fromRGB(tonumber(s:sub(1,2),16), tonumber(s:sub(3,4),16), tonumber(s:sub(5,6),16))
        end
        return nil
    end
    local function notify(...)
        if type(HAVAC.notify) == "function" then pcall(HAVAC.notify, ...) end
    end
    local function cleanName(n)
        n = tostring(n or ""):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return n:sub(1, 32)
    end

    local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local function b64enc(data)
        local bits = data:gsub(".", function(x)
            local r, b = "", x:byte()
            for i = 8, 1, -1 do r = r .. ((b % 2 ^ i - b % 2 ^ (i - 1) > 0) and "1" or "0") end
            return r
        end)
        local out = (bits .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
            if #x < 6 then return "" end
            local c = 0
            for i = 1, 6 do c = c + (x:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
            return B64:sub(c + 1, c + 1)
        end)
        return out .. ({ "", "==", "=" })[#data % 3 + 1]
    end
    local function b64dec(data)
        data = data:gsub("[^" .. B64:gsub("%p", "%%%0") .. "=]", "")
        local bits = data:gsub(".", function(x)
            if x == "=" then return "" end
            local r, f = "", (B64:find(x, 1, true) - 1)
            for i = 6, 1, -1 do r = r .. ((f % 2 ^ i - f % 2 ^ (i - 1) > 0) and "1" or "0") end
            return r
        end)
        return (bits:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
            if #x ~= 8 then return "" end
            local c = 0
            for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
            return string.char(c)
        end))
    end

    local requiredComponents = { "page", "card", "section", "label", "paragraph",
                                 "button", "buttonRow", "toggle", "slider", "dropdown",
                                 "input", "notify", "confirm", "showPage" }
    local missing = {}
    for _, name in ipairs(requiredComponents) do
        if type(HAVAC[name]) ~= "function" then missing[#missing + 1] = name end
    end
    if #missing > 0 then
        error("HAVAC CORE Block 5 requires Block 2. Missing: " .. table.concat(missing, ", "), 2)
    end
    local hasColorPicker = type(HAVAC.colorPicker) == "function"

    local PRESET_ORDER = { "Havac", "Void", "Ember", "Frost" }
    local PRESET_LABELS = { Havac = "HAVAC", Void = "Void", Ember = "Ember", Frost = "Frost" }

    if type(Config.themes) ~= "table" then Config.themes = {} end
    if type(Config.defaultTheme) ~= "string" then Config.defaultTheme = "" end

    local function saveConfig()
        if I.Persistence and I.Persistence.save then pcall(I.Persistence.save, Config) end
    end

    local function currentSpec()
        if I.Theme and I.Theme.activeSpec then return I.Theme.activeSpec end
        return nil
    end

    local settingsPage = HAVAC.page("settings", "Settings")
    local cols = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = settingsPage,
    })
    HList(cols, 14, Enum.VerticalAlignment.Top)
    local leftCol = New("Frame", {
        Size = UDim2.new(0.5, -7, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = cols,
    })
    VList(leftCol, 14)
    local rightCol = New("Frame", {
        Size = UDim2.new(0.5, -7, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = cols,
    })
    VList(rightCol, 14)

    -- Language card
    local langCard = HAVAC.card(leftCol, "Language")
    HAVAC.label(langCard, "Idioma / Language / Idioma", { bold = true, size = 12 })
    local localeOptions = { "Português (BR)", "English", "Español" }
    local localeCodes = { ["Português (BR)"] = "pt-br", ["English"] = "en", ["Español"] = "es" }
    local function currentLocaleLabel()
        local cur = HAVAC.getLocale and HAVAC.getLocale() or "pt-br"
        for label, code in pairs(localeCodes) do
            if code == cur then return label end
        end
        return "Português (BR)"
    end
    HAVAC.dropdown(langCard, "Idioma", localeOptions, currentLocaleLabel(), function(v)
        local code = localeCodes[v] or "pt-br"
        if HAVAC.setLocale then HAVAC.setLocale(code) end
        notify("ok", "Idioma", v)
    end)

    -- Menu card
    local menuCard = HAVAC.card(leftCol, "Menu")
    HAVAC.section(menuCard, "TECLA DE TOGGLE")
    local keyDisplay = HAVAC.label(menuCard,
        "Atual: " .. ((Config and Config.toggleKey) or "RightControl"),
        { size = 11, color = T.TextDim })
    HAVAC.keybind(menuCard, "Toggle key", (Config and Config.toggleKey) or "RightControl", function(name)
        if Config then Config.toggleKey = name; saveConfig() end
        if keyDisplay then keyDisplay.Text = "Atual: " .. name end
    end, { allowNone = false })

    HAVAC.divider(menuCard)
    HAVAC.section(menuCard, "EFEITOS")
    HAVAC.toggle(menuCard, "Reduzir animações", (Config and Config.reduceEffects) or false, function(on)
        if Config then Config.reduceEffects = on; saveConfig() end
        if Anim then Anim.reduce = on end
    end)

    -- Configs card
    local configCard = HAVAC.card(leftCol, "Configs")
    HAVAC.label(configCard,
        Caps and Caps.writefile and "Salvo em disco (havac_core.json)."
        or "Memória apenas neste executor (sem writefile).",
        { size = 10, color = T.TextDim })
    HAVAC.section(configCard, "AÇÕES")
    HAVAC.buttonRow(configCard, {
        { label = "Salvar", cb = function()
            saveConfig(); notify("ok", "Config", "Salvo.")
        end },
        { label = "Recarregar", cb = function()
            if I.Persistence and I.Persistence.load then
                local ok, newCfg = pcall(I.Persistence.load)
                if ok and type(newCfg) == "table" and Config then
                    for k, v in pairs(newCfg) do Config[k] = v end
                    notify("ok", "Config", "Recarregado.")
                else
                    notify("warn", "Config", "Nada a recarregar.")
                end
            end
        end },
    })
    HAVAC.section(configCard, "COMPARTILHAR")
    HAVAC.input(configCard, "Nome do código", "meu_hub", "", function() end)
    HAVAC.button(configCard, "Copiar código (base64)", nil, function()
        if not (Config and HttpService) then return end
        local snap = {}
        for k, v in pairs(Config) do if type(v) ~= "table" then snap[k] = v end end
        local ok, encoded = pcall(function() return b64enc(HttpService:JSONEncode(snap)) end)
        if ok and encoded then
            local copied = HAVAC.copy and HAVAC.copy(encoded) or false
            notify(copied and "ok" or "warn", "Código",
                copied and ("Copiado (" .. #encoded .. " chars)") or "Clipboard indisponível.")
        end
    end)
    local importBox = HAVAC.input(configCard, "Colar código", "cole o código aqui", "", function() end)
    HAVAC.button(configCard, "Importar código", "primary", function()
        if not (importBox and HttpService) then return end
        local txt = importBox.Text or ""
        if txt == "" then notify("warn", "Importar", "Campo vazio."); return end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(b64dec(txt)) end)
        if ok and type(decoded) == "table" then
            for k, v in pairs(decoded) do Config[k] = v end
            saveConfig(); notify("ok", "Importar", "Config aplicado.")
        else
            notify("err", "Importar", "Código inválido.")
        end
    end)

    -- Appearance card
    local appCard = HAVAC.card(rightCol, "Appearance")
    HAVAC.section(appCard, "TEMA")
    local function activeThemeLabel()
        local act = I.Theme and I.Theme.active or "Havac"
        return PRESET_LABELS[act] or (PRESET_LABELS[Config.preset or "Havac"] or act)
    end
    local presetOpts = {}
    for _, k in ipairs(PRESET_ORDER) do presetOpts[#presetOpts + 1] = PRESET_LABELS[k] end
    HAVAC.dropdown(appCard, "Preset", presetOpts, activeThemeLabel(), function(label)
        for k, v in pairs(PRESET_LABELS) do
            if v == label then
                if HAVAC.setTheme then HAVAC.setTheme(k) end
                if Config then Config.preset = k; saveConfig() end
                notify("info", "Tema", v)
                return
            end
        end
    end)
    HAVAC.section(appCard, "TAMANHO E ESPAÇAMENTO")
    HAVAC.slider(appCard, "Escala da UI", 60, 140,
        (Config and Config.uiScale) or 100, function(v)
            if Config then Config.uiScale = v; saveConfig() end
        end, { suffix = "%" })
    HAVAC.slider(appCard, "Raio dos cantos", 2, 20,
        (Config and Config.cornerRadius) or 10, function(v)
            if Config then Config.cornerRadius = v; saveConfig() end
        end, { suffix = " px" })

    -- Themes card
    local themesCard = HAVAC.card(rightCol, "Themes")
    HAVAC.label(themesCard,
        hasColorPicker and "Clique numa cor para editar." or "Digite #RRGGBB.",
        { size = 10, color = T.TextDim })

    local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
    local function specToColors(spec)
        if not spec then return end
        return {
            bg = spec.bg, surface = spec.surface, surfaceAlt = spec.surfaceAlt,
            primary = spec.primary, secondary = spec.secondary,
            text = spec.text, muted = spec.muted,
        }
    end
    local draftSpec = specToColors(currentSpec() or {
        bg = {8,8,10}, surface = {18,18,22}, surfaceAlt = {25,24,32},
        primary = {139,92,246}, secondary = {167,139,250},
        text = {245,243,255}, muted = {161,161,170},
    })

    local colorRows = {}
    local function colorRow(label, key)
        if hasColorPicker then
            local picker = HAVAC.colorPicker(themesCard, label, c3(draftSpec[key]), function(color)
                draftSpec[key] = {
                    math.floor(color.R * 255 + 0.5),
                    math.floor(color.G * 255 + 0.5),
                    math.floor(color.B * 255 + 0.5),
                }
            end)
            colorRows[key] = picker
        else
            local row = New("Frame", {
                Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = themesCard,
            })
            New("TextLabel", {
                Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
                Text = label, TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
            })
            local hexInput = New("TextBox", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 80, 0, 24), BackgroundColor3 = T.CardAlt,
                BorderSizePixel = 0, Text = hexStr(c3(draftSpec[key])),
                TextColor3 = T.Text, FontFace = F.Medium, TextSize = 11,
                ClearTextOnFocus = false, Parent = row,
            })
            Corner(hexInput, 6)
            hexInput.FocusLost:Connect(function()
                local p = parseHexStr(hexInput.Text)
                if p then
                    draftSpec[key] = {
                        math.floor(p.R * 255 + 0.5),
                        math.floor(p.G * 255 + 0.5),
                        math.floor(p.B * 255 + 0.5),
                    }
                else
                    hexInput.Text = hexStr(c3(draftSpec[key]))
                end
            end)
            colorRows[key] = {
                Set = function(_, color)
                    draftSpec[key] = {
                        math.floor(color.R * 255 + 0.5),
                        math.floor(color.G * 255 + 0.5),
                        math.floor(color.B * 255 + 0.5),
                    }
                    hexInput.Text = hexStr(color)
                end,
                Get = function() return c3(draftSpec[key]) end,
            }
        end
    end
    colorRow("Background", "bg")
    colorRow("Surface", "surface")
    colorRow("Surface Alt", "surfaceAlt")
    colorRow("Primary", "primary")
    colorRow("Secondary", "secondary")
    colorRow("Text", "text")
    colorRow("Muted", "muted")

    HAVAC.buttonRow(themesCard, {
        { label = "Aplicar", cb = function()
            if not I.Theme or not I.Theme.presets then
                notify("err", "Tema", "Sistema de tema indisponível."); return
            end
            local tempName = "__draft_" .. tostring(os.clock())
            I.Theme.presets[tempName] = {
                label = "Draft",
                bg = draftSpec.bg, surface = draftSpec.surface, surfaceAlt = draftSpec.surfaceAlt,
                primary = draftSpec.primary, secondary = draftSpec.secondary,
                text = draftSpec.text, muted = draftSpec.muted,
            }
            if I.Theme.apply then pcall(I.Theme.apply, tempName, Gui) end
            notify("ok", "Tema", "Aplicado.")
        end },
        { label = "Salvar como tema", cb = function()
            local name = cleanName(importBox and importBox.Text or "")
            if name == "" then notify("warn", "Tema", "Digite um nome no campo 'Nome do código' antes."); return end
            Config.themes[name] = draftSpec
            saveConfig()
            notify("ok", "Tema", "Salvo como '" .. name .. "'.")
        end },
    })

    if next(Config.themes) then
        HAVAC.divider(themesCard)
        HAVAC.section(themesCard, "TEMAS SALVOS")
        for themeName, spec in pairs(Config.themes) do
            local row = New("Frame", {
                Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = themesCard,
            })
            New("TextLabel", {
                Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1,
                Text = themeName, TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left, Parent = row,
            })
            local loadBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -40, 0.5, 0),
                Size = UDim2.new(0, 34, 0, 22), BackgroundColor3 = T.CardAlt,
                BorderSizePixel = 0, Text = "▶", TextColor3 = T.Text,
                FontFace = F.Medium, TextSize = 11, AutoButtonColor = false, Parent = row,
            })
            Corner(loadBtn, 5)
            local delBtn = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.new(0, 34, 0, 22), BackgroundColor3 = T.CardAlt,
                BorderSizePixel = 0, Text = "✕", TextColor3 = T.Error,
                FontFace = F.Medium, TextSize = 11, AutoButtonColor = false, Parent = row,
            })
            Corner(delBtn, 5)
            loadBtn.MouseButton1Click:Connect(function()
                if not I.Theme or not I.Theme.presets then return end
                local tempName = "__load_" .. tostring(os.clock())
                I.Theme.presets[tempName] = {
                    label = themeName,
                    bg = spec.bg, surface = spec.surface, surfaceAlt = spec.surfaceAlt,
                    primary = spec.primary, secondary = spec.secondary,
                    text = spec.text, muted = spec.muted,
                }
                if I.Theme.apply then pcall(I.Theme.apply, tempName, Gui) end
                draftSpec = specToColors(spec)
                for key, row in pairs(colorRows) do
                    if row.Set then pcall(row.Set, row, c3(draftSpec[key])) end
                end
                notify("info", "Tema", "Carregado '" .. themeName .. "'.")
            end)
            delBtn.MouseButton1Click:Connect(function()
                local ok = HAVAC.confirm and HAVAC.confirm("Excluir tema", "Remover '" .. themeName .. "'?")
                if ok then
                    Config.themes[themeName] = nil
                    saveConfig()
                    notify("info", "Tema", "Excluído '" .. themeName .. "'.")
                end
            end)
        end
    end

    -- Panic card
    local panicCard = HAVAC.card(rightCol, "Panic")
    HAVAC.label(panicCard, "Atual: " .. ((Config and Config.panicKey) or "RightShift"),
        { size = 11, color = T.TextDim })
    HAVAC.keybind(panicCard, "Panic key", (Config and Config.panicKey) or "RightShift", function(name)
        if HAVAC.setPanicKey then pcall(HAVAC.setPanicKey, name) end
        if Config then Config.panicKey = name; saveConfig() end
    end, { allowNone = true })
    HAVAC.button(panicCard, "Panic agora (destruir UI)", nil, function()
        local ok = HAVAC.confirm and HAVAC.confirm("Panic", "Destruir toda a interface?")
        if ok and HAVAC.panic then pcall(HAVAC.panic) end
    end, "primary")

    -- SEARCH
    local Header = I.Header
    if Header then
        local searchBox = New("Frame", {
            Name = "HAVAC_SearchBox", AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 180, 0, 30),
            BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = Header,
        })
        Corner(searchBox, 8)
        local searchStroke = Stroke(searchBox, T.BorderLow, 1)
        Padding(searchBox, 10, 10, 0, 0)
        New("TextLabel", {
            Size = UDim2.new(0, 14, 1, 0), BackgroundTransparency = 1,
            Text = "🔍", TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = searchBox,
        })
        local searchInput = New("TextBox", {
            Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -20, 1, 0),
            BackgroundTransparency = 1, PlaceholderText = "Buscar...",
            PlaceholderColor3 = T.TextDim, TextColor3 = T.Text,
            FontFace = F.Regular, TextSize = 11, Text = "",
            ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
            Parent = searchBox,
        })

        local resultsPanel = New("Frame", {
            Name = "HAVAC_SearchResults", AnchorPoint = Vector2.new(1, 0),
            Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.Card, BorderSizePixel = 0, Visible = false,
            ZIndex = 60, Parent = Gui,
        })
        Corner(resultsPanel, 8)
        Stroke(resultsPanel, T.Border, 1)
        Padding(resultsPanel, 6, 6, 6, 6)
        VList(resultsPanel, 2)

        local function buildIndex()
            local entries = {}
            local function addEntry(label, page, inst)
                if not label or label == "" then return end
                entries[#entries + 1] = { label = tostring(label), page = page, inst = inst }
            end
            if type(I.Pages) == "table" then
                for id, info in pairs(I.Pages) do
                    addEntry(info.title or id, id, nil)
                end
                for id, info in pairs(I.Pages) do
                    if info.frame then
                        for _, desc in ipairs(info.frame:GetDescendants()) do
                            if desc:IsA("TextLabel") then
                                local txt = desc.Text
                                if txt and txt ~= "" and #txt < 60 and not txt:match("^[%s%d%.]+$") then
                                    addEntry(txt, id, desc)
                                end
                            end
                        end
                    end
                end
            end
            return entries
        end
        local searchIndex = buildIndex()
        task.spawn(function()
            while Gui and Gui.Parent do
                task.wait(5)
                searchIndex = buildIndex()
            end
        end)

        local function escape(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

        local function rebuildResults(query)
            for _, c in ipairs(resultsPanel:GetChildren()) do
                if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
            end
            if query == "" then resultsPanel.Visible = false return end
            local q = query:lower()
            local seen, matches = {}, {}
            for _, entry in ipairs(searchIndex) do
                local lower = entry.label:lower()
                if lower:find(q, 1, true) then
                    local key = entry.page .. "|" .. entry.label
                    if not seen[key] then
                        seen[key] = true
                        local rank = (lower:sub(1, #q) == q) and 1 or 2
                        matches[#matches + 1] = { entry = entry, rank = rank }
                    end
                end
            end
            table.sort(matches, function(a, b)
                if a.rank ~= b.rank then return a.rank < b.rank end
                return a.entry.label < b.entry.label
            end)
            local shown = 0
            for _, m in ipairs(matches) do
                if shown >= 8 then break end
                shown = shown + 1
                local btn = New("TextButton", {
                    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.Card,
                    BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
                    AutoButtonColor = false, LayoutOrder = shown, Parent = resultsPanel,
                })
                Corner(btn, 6)
                local lower = m.entry.label:lower()
                local s = lower:find(q, 1, true)
                local highlighted
                if s then
                    highlighted = escape(m.entry.label:sub(1, s - 1))
                        .. '<font color="' .. hexStr(T.Accent) .. '"><b>'
                        .. escape(m.entry.label:sub(s, s + #q - 1))
                        .. "</b></font>"
                        .. escape(m.entry.label:sub(s + #q))
                else
                    highlighted = escape(m.entry.label)
                end
                New("TextLabel", {
                    Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                    BackgroundTransparency = 1, Text = highlighted, RichText = true,
                    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
                })
                btn.MouseButton1Click:Connect(function()
                    resultsPanel.Visible = false
                    searchInput.Text = ""
                    if m.entry.page then pcall(HAVAC.showPage, m.entry.page) end
                    if m.entry.inst and m.entry.inst.Parent then
                        task.delay(0.4, function()
                            local flashF = New("Frame", {
                                Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.Accent,
                                BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 20,
                                Parent = m.entry.inst,
                            })
                            Corner(flashF, 6)
                            Anim.tween(flashF, { BackgroundTransparency = 1 }, 1.2, "gentle", "searchFlash")
                            task.delay(1.3, function() if flashF.Parent then flashF:Destroy() end end)
                        end)
                    end
                end)
            end
            if shown == 0 then
                New("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
                    Text = "Nada encontrado", TextColor3 = T.TextDim,
                    FontFace = F.Regular, TextSize = 11, Parent = resultsPanel,
                })
            end
            local sc = math.max(I.computeScale and I.computeScale() or 1, 0.01)
            local abs = searchBox.AbsolutePosition
            local size = searchBox.AbsoluteSize
            resultsPanel.Position = UDim2.new(0, abs.X + size.X - 260 / sc, 0, abs.Y + size.Y + 6)
            resultsPanel.Size = UDim2.new(0, 260, 0, 0)
            resultsPanel.Visible = true
        end

        searchInput:GetPropertyChangedSignal("Text"):Connect(function()
            rebuildResults((searchInput.Text or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""))
        end)
        searchInput.Focused:Connect(function()
            Anim.tween(searchStroke, { Color = T.Accent }, 0.15, "gentle", "searchFocus")
        end)
        searchInput.FocusLost:Connect(function()
            Anim.tween(searchStroke, { Color = T.BorderLow }, 0.15, "gentle", "searchFocus")
            task.delay(0.2, function()
                if not searchInput:IsFocused() then resultsPanel.Visible = false end
            end)
        end)
        Track(UIS.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.Escape and searchInput:IsFocused() then
                searchInput.Text = ""
                searchInput:ReleaseFocus()
                resultsPanel.Visible = false
            end
        end))

        I._searchInput = searchInput
    end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- BLOCK 6: SHOWCASE + EXAMPLE + UNLOAD
-- ============================================================================

local function __block6(HAVAC)
    if not HAVAC or not HAVAC._internal then
        error("HAVAC CORE Block 6 needs Block 1's _internal.", 2)
    end
    local I = HAVAC._internal
    local T, Anim, Locale, Caps = I.T, I.Anim, I.Locale, I.Caps
    local New, Corner, Stroke = I.New, I.Corner, I.Stroke
    local Padding = I.Padding
    local VList, HList = I.VList, I.HList
    local Track = I.Track
    local F, logError, Gui = I.F, I.logError, I.Gui
    local Config = I.Config
    if not Gui then error("HAVAC CORE Block 6: Gui missing.", 2) end

    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    local function safe(cb, ...)
        if type(cb) ~= "function" then return end
        local ok, err = pcall(cb, ...)
        if not ok then logError("callback", err) end
    end
    local function notify(...)
        if type(HAVAC.notify) == "function" then pcall(HAVAC.notify, ...) end
    end

    local function sweepOrphans()
        local parents = { game:GetService("CoreGui") }
        local ok, hui = pcall(function()
            return type(gethui) == "function" and gethui() or nil
        end)
        if ok and hui then table.insert(parents, hui) end
        local pg = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
        for _, parent in ipairs(parents) do
            if parent then
                for _, c in ipairs(parent:GetChildren()) do
                    if c:IsA("ScreenGui") and type(c.Name) == "string"
                       and c.Name:sub(1, 10) == "HAVAC_CORE" and c ~= Gui then
                        pcall(function() c:Destroy() end)
                    end
                end
            end
        end
    end
    sweepOrphans()

    function HAVAC.showcase()
        if HAVAC.pageExists and HAVAC.pageExists("showcase") then
            HAVAC.showPage("showcase")
            notify("info", "Showcase", "Página já existe. Mostrando.")
            return
        end
        local page = HAVAC.page("showcase", "Showcase")

        local intro = HAVAC.card(page, "Introdução")
        HAVAC.label(intro, "HAVAC CORE — Showcase completo", { bold = true, size = 14 })
        HAVAC.paragraph(intro,
            "Esta página demonstra todos os componentes. Verifique o console para logs de callback.")
        HAVAC.divider(intro)
        HAVAC.section(intro, "TEXTO")
        HAVAC.label(intro, "Label padrão — 12px")
        HAVAC.label(intro, "Label em negrito", { bold = true })
        HAVAC.paragraph(intro,
            "Paragraph — texto longo que quebra em múltiplas linhas automaticamente.")
        HAVAC.section(intro, "STATUS")
        HAVAC.status(intro, "Versão", "v" .. tostring(HAVAC.version))
        HAVAC.status(intro, "Executor", Caps.executorName)
        HAVAC.status(intro, "Locale", HAVAC.getLocale and HAVAC.getLocale() or "pt-br")
        HAVAC.status(intro, "Tema", HAVAC.getTheme and HAVAC.getTheme() or "Havac")
        HAVAC.status(intro, "Status", "Ativo", { color = T.Success })

        local buttons = HAVAC.card(page, "Botões")
        HAVAC.section(buttons, "SIMPLES")
        HAVAC.button(buttons, "Primário", "primary", function() notify("ok", "Primário", "OK") end)
        HAVAC.button(buttons, "Secundário", nil, function() notify("info", "Secundário", "OK") end)
        HAVAC.section(buttons, "LINHA")
        HAVAC.buttonRow(buttons, {
            { label = "A", cb = function() notify("ok", "A", "OK") end },
            { label = "B", cb = function() notify("ok", "B", "OK") end },
        })
        HAVAC.section(buttons, "CONFIRMAÇÃO")
        HAVAC.buttonRow(buttons, {
            { label = "Destrutivo", cb = function() notify("err", "Destrutivo", "OK") end, confirm = true },
            { label = "Seguro", cb = function() notify("ok", "Seguro", "OK") end },
        })
        HAVAC.button(buttons, "Abrir dialog", nil, function()
            task.spawn(function()
                local ok = HAVAC.confirm and HAVAC.confirm("Confirmar", "Teste.")
                notify(ok and "ok" or "info", "Confirm", ok and "Sim" or "Não")
            end)
        end)

        local inputs = HAVAC.card(page, "Inputs")
        HAVAC.section(inputs, "TOGGLE")
        HAVAC.toggle(inputs, "Toggle A", false, function(on) print("[showcase] toggle:", on) end)
        HAVAC.toggle(inputs, "Toggle B (on)", true, function(on) print("[showcase] toggle:", on) end)
        HAVAC.section(inputs, "SLIDER")
        HAVAC.slider(inputs, "Inteiro (0-100)", 0, 100, 50, function(v) print("[showcase]", v) end, { suffix = "%" })
        HAVAC.slider(inputs, "Decimal (0.1-2.0)", 0.1, 2.0, 1.0, function(v) print("[showcase]", v) end, { step = 0.1, suffix = "x" })
        HAVAC.section(inputs, "INPUT")
        HAVAC.input(inputs, "Nome", "digite...", "", function(v) print("[showcase] input:", v) end)
        HAVAC.section(inputs, "KEYBIND")
        HAVAC.keybind(inputs, "Tecla", "E", function(k) print("[showcase] key:", k) end)

        local dds = HAVAC.card(page, "Dropdowns")
        HAVAC.dropdown(dds, "Simples", { "A", "B", "C", "D", "E" }, "A", function(v) print("[showcase] dd:", v) end)
        if type(HAVAC.multiDropdown) == "function" then
            HAVAC.multiDropdown(dds, "Múltiplo", { "Maçã", "Banana", "Cereja", "Damasco", "Figo" },
                { "Maçã", "Cereja" }, function(list) print("[showcase] multi:", table.concat(list, ", ")) end)
        end

        local colors = HAVAC.card(page, "Cores")
        if type(HAVAC.colorPicker) == "function" then
            HAVAC.colorPicker(colors, "Cor 1", Color3.fromRGB(139, 92, 246), function(c) print("[showcase] c1:", c) end)
            HAVAC.colorPicker(colors, "Cor 2", Color3.fromRGB(240, 110, 130), function(c) print("[showcase] c2:", c) end)
        end

        local fb = HAVAC.card(page, "Feedback")
        local prog = HAVAC.progress(fb, "Auto-progresso")
        task.spawn(function()
            while prog and prog.Set do
                for i = 1, 20 do
                    prog:Set(i / 20, (i * 5) .. "%")
                    task.wait(0.2)
                end
                task.wait(0.5)
                if not prog.Set then break end
            end
        end)
        HAVAC.section(fb, "NOTIFICAÇÕES")
        HAVAC.button(fb, "OK", nil, function() notify("ok", "OK", "Sucesso") end)
        HAVAC.button(fb, "WARN", nil, function() notify("warn", "WARN", "Aviso") end)
        HAVAC.button(fb, "ERR", nil, function() notify("err", "ERR", "Erro") end)
        HAVAC.button(fb, "INFO", nil, function() notify("info", "INFO", "Informação") end)
        HAVAC.button(fb, "Todas de uma vez", "primary", function()
            notify("ok", "1", "ok"); task.wait(0.1)
            notify("warn", "2", "warn"); task.wait(0.1)
            notify("err", "3", "err"); task.wait(0.1)
            notify("info", "4", "info")
        end)

        local look = HAVAC.card(page, "Aparência")
        HAVAC.section(look, "TEMAS")
        HAVAC.buttonRow(look, {
            { label = "Havac", cb = function() if HAVAC.setTheme then HAVAC.setTheme("Havac") end end },
            { label = "Void",  cb = function() if HAVAC.setTheme then HAVAC.setTheme("Void") end end },
        })
        HAVAC.buttonRow(look, {
            { label = "Ember", cb = function() if HAVAC.setTheme then HAVAC.setTheme("Ember") end end },
            { label = "Frost", cb = function() if HAVAC.setTheme then HAVAC.setTheme("Frost") end end },
        })
        HAVAC.section(look, "IDIOMAS")
        HAVAC.buttonRow(look, {
            { label = "PT-BR", cb = function() if HAVAC.setLocale then HAVAC.setLocale("pt-br") end end },
            { label = "EN",    cb = function() if HAVAC.setLocale then HAVAC.setLocale("en") end end },
        })
        HAVAC.buttonRow(look, {
            { label = "ES", cb = function() if HAVAC.setLocale then HAVAC.setLocale("es") end end },
            { label = "PT", cb = function() if HAVAC.setLocale then HAVAC.setLocale("pt-br") end end },
        })

        local danger = HAVAC.card(page, "Perigo")
        HAVAC.paragraph(danger, "Botões destrutivos — use com cuidado.")
        HAVAC.button(danger, "Unload (limpeza total)", nil, function()
            local ok = HAVAC.confirm and HAVAC.confirm("Unload", "Remover tudo?")
            if ok and HAVAC.unload then pcall(HAVAC.unload) end
        end)
        HAVAC.button(danger, "Panic (emergência)", "primary", function()
            local ok = HAVAC.confirm and HAVAC.confirm("Panic", "Acionar panic?")
            if ok and HAVAC.panic then pcall(HAVAC.panic) end
        end)

        HAVAC.showPage("showcase")
        notify("ok", "Showcase", "Criado.")
    end

    function HAVAC.example()
        if HAVAC.pageExists and HAVAC.pageExists("example") then
            HAVAC.showPage("example")
            notify("info", "Example", "Já existe.")
            return
        end
        local state = {
            aimbot = false, aimFov = 120, aimPart = "Head",
            esp = false, espColor = Color3.fromRGB(255, 60, 60),
            speed = 16, jump = 50,
        }
        local combat = HAVAC.page("combat", "Combat")
        local cc = HAVAC.card(combat, "Aimbot")
        HAVAC.toggle(cc, "Aimbot", state.aimbot, function(on)
            state.aimbot = on
            HAVAC.setFeature("Aimbot", on)
            notify(on and "ok" or "info", "Aimbot", on and "Ativado" or "Desativado")
        end)
        HAVAC.slider(cc, "FOV", 30, 500, state.aimFov, function(v) state.aimFov = v end, { suffix = " px", step = 5 })
        HAVAC.dropdown(cc, "Target", { "Head", "Torso", "LeftArm", "RightArm" }, state.aimPart,
            function(v) state.aimPart = v end)

        local visual = HAVAC.page("visual", "Visual")
        local espCard = HAVAC.card(visual, "ESP")
        HAVAC.toggle(espCard, "ESP Enable", state.esp, function(on)
            state.esp = on
            HAVAC.setFeature("ESP", on)
            notify(on and "ok" or "info", "ESP", on and "Ativado" or "Desativado")
        end)
        if type(HAVAC.colorPicker) == "function" then
            HAVAC.colorPicker(espCard, "Cor", state.espColor, function(c) state.espColor = c end)
        end

        local move = HAVAC.page("movement", "Movement")
        local speedCard = HAVAC.card(move, "Speed / Jump")
        HAVAC.slider(speedCard, "WalkSpeed", 16, 200, state.speed, function(v)
            state.speed = v
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = v end
            end
        end, { suffix = "" })
        HAVAC.slider(speedCard, "JumpPower", 50, 500, state.jump, function(v)
            state.jump = v
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.JumpPower = v end
            end
        end, { suffix = "" })
        HAVAC.button(speedCard, "Resetar", nil, function()
            state.speed, state.jump = 16, 50
            local char = LocalPlayer and LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
            end
            notify("info", "Reset", "16 / 50")
        end)

        HAVAC.showPage("combat")
        notify("ok", "Example", "Menu de exemplo carregado.")
    end

    local unloadedFlag = false
    function HAVAC.unload()
        if unloadedFlag then return end
        unloadedFlag = true
        for _, fn in ipairs(HAVAC._hooks and HAVAC._hooks.unload or {}) do pcall(fn) end
        if Anim and Anim.cancelAll then pcall(function() Anim.cancelAll() end) end
        if Gui then pcall(function() Gui:Destroy() end) end
        sweepOrphans()
        HAVAC.notify = function() end
        HAVAC.showPage = function() end
        HAVAC.pageExists = function() return false end
        HAVAC.open = function() end
        HAVAC.close = function() end
        HAVAC.toggle = function() end
        HAVAC.showcase = function() end
        HAVAC.example = function() end
        HAVAC.confirm = function() return false end
        print("[HAVAC CORE] unload: UI removed. Re-execute for fresh instance.")
    end

    HAVAC.version = "1.0.0"
    return HAVAC
end

-- ============================================================================
-- WIRING — CHAIN ALL BLOCKS
-- ============================================================================

HAVAC = __block2(HAVAC)
HAVAC = __block2b(HAVAC)
HAVAC = __block3(HAVAC)
HAVAC = __block4(HAVAC)
HAVAC = __block5(HAVAC)
HAVAC = __block6(HAVAC)

-- expose globally (Xeno paste mode)
_G.HAVAC = HAVAC

-- auto-open the window after a short delay
task.delay(0.5, function()
    if HAVAC.open then pcall(HAVAC.open) end
end)

-- startup log
task.delay(1.2, function()
    print(("[HAVAC CORE v%s] Pronto. Use HAVAC.showcase() ou HAVAC.example()."):format(HAVAC.version))
end)

-- auto-showcase if user hasn't created pages
task.delay(1.6, function()
    local pages = HAVAC._internal and HAVAC._internal.Pages
    local pageCount = 0
    if type(pages) == "table" then
        for _ in pairs(pages) do pageCount = pageCount + 1 end
    end
    if pageCount <= 1 then pcall(HAVAC.showcase) end
end)

return HAVAC