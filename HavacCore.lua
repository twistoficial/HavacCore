

local function build(opts)
opts = opts or {}
local ID = (tostring(opts.id or "app"):gsub("[^%w_]", "")):lower()
if ID == "" then ID = "app" end
local BRAND = tostring(opts.title or "Okuma")
local PFX, CLEAN = "OkumaLib_" .. ID .. "_", "OkumaLib_" .. ID .. "_Cleanup"
local DISCORD = type(opts.discord) == "string" and opts.discord ~= "" and opts.discord or nil

local genv = (type(getgenv) == "function" and getgenv()) or _G

-- ============================================================================
-- UI  -  the one table game scripts talk to (everything else in this file is internal).
-- Filled in as the file goes on; the full reference is the "PROGRAMMER API" section below.
-- ============================================================================
local UI = { version = 4, logs = {}, _cleanups = {}, _volatile = {}, _guard = {}, _bound = {}, _hotkeys = {} }
function UI.log(level, msg)
    local line = ("[%8.1f] %-5s %s"):format(os.clock(), tostring(level), tostring(msg))
    UI.logs[#UI.logs + 1] = line
    if #UI.logs > 400 then table.remove(UI.logs, 1) end
    if UI._logHook then pcall(UI._logHook, level, line) end
end

-- kill any previous instance: its connections + every leftover ScreenGui
pcall(function()
    if genv[CLEAN] then genv[CLEAN]() end
end)
pcall(function()
    local roots = { game:GetService("CoreGui"), game:GetService("Lighting") }   -- Lighting: the blur behind the window
    if type(gethui) == "function" then table.insert(roots, gethui()) end
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(roots, pg) end
    for _, root in ipairs(roots) do
        for _, c in ipairs(root:GetChildren()) do
            if c.Name:sub(1, #PFX) == PFX then c:Destroy() end
        end
    end
end)

-- ============================================================================
-- ICON ASSET IDS   (set to "" to use the Lucide fallback)
-- ============================================================================
local ICONS = {
    logo          = opts.logo or "",
    home          = "rbxassetid://13060262582",
    shield        = "rbxassetid://13780781482",
    wind          = "rbxassetid://17514296908",
    target        = "rbxassetid://107058246184363",
    zap           = "rbxassetid://117079418447477",
    wrench        = "rbxassetid://74185647224574",
    settings      = "rbxassetid://13300915335",
    search        = "rbxassetid://132302594577680",
    minimize      = "rbxassetid://130317465465959",
    expand        = "",
    play          = "rbxassetid://8517323802",
    rejoin        = "rbxassetid://123793179318056",
    shuffle       = "rbxassetid://71866957367213",
    lowest        = "rbxassetid://71866957367213",
    copy          = "rbxassetid://85360060654230",
    discord       = "rbxassetid://18505728250",
    globe         = "rbxassetid://121176334529781",
    checklist     = "rbxassetid://13289068631",
    chevron_right = "rbxassetid://89820329941528",
    overview      = "",
    beta_badge    = "",
    tag           = "",
    user_person   = "",
    folder        = "",
    chevron_down  = "",
    unload        = "",
    volt          = "",
}

local LUCIDE_FALLBACK = {
    logo         = "diamond",
    expand       = "expand",
    overview     = "layout-dashboard",
    beta_badge   = "flask-conical",
    tag          = "tag",
    user_person  = "user",
    lowest       = "trending-down",
    folder       = "folder",
    chevron_down = "chevron-down",
    unload       = "power",
    volt         = "zap",
}

local LucideAtlas, lucideDone = nil, (opts.lucide == false)
if not lucideDone then
    task.spawn(function()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/refs/heads/main/icons.lua"))()
        end)
        if ok and type(result) == "table" then LucideAtlas = result end
        lucideDone = true
    end)
    task.delay(15, function() lucideDone = true end)   -- a request that never answers must not keep the sweep waiting
end

-- ============================================================================
-- SERVICES
-- ============================================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local Stats            = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")
local ContentProvider  = game:GetService("ContentProvider")
local LocalPlayer      = Players.LocalPlayer

-- ============================================================================
-- THEME
-- Every colour comes from five base colours, so a theme is just five values. The palette
-- keeps every derived colour unique, which lets a live theme change find each one again.
-- ============================================================================
local PALETTES = {
    Mono   = { accent = { 236, 236, 240 }, background = { 16, 16, 17 },  surface = { 25, 25, 26 },  text = { 236, 236, 240 }, muted = { 140, 140, 150 } },
    Plum   = { accent = { 198, 150, 255 }, background = { 18, 14, 24 },  surface = { 28, 22, 38 },  text = { 240, 233, 248 }, muted = { 152, 138, 170 } },
    Ocean  = { accent = { 110, 190, 255 }, background = { 11, 16, 24 },  surface = { 19, 28, 40 },  text = { 230, 241, 252 }, muted = { 128, 150, 172 } },
    Ember  = { accent = { 255, 150, 92 },  background = { 20, 14, 12 },  surface = { 32, 23, 20 },  text = { 247, 237, 231 }, muted = { 162, 141, 131 } },
    Forest = { accent = { 120, 222, 152 }, background = { 11, 18, 14 },  surface = { 19, 30, 24 },  text = { 232, 247, 238 }, muted = { 129, 157, 140 } },
}
local PALETTE_NAMES = { "Mono", "Plum", "Ocean", "Ember", "Forest" }
local DERIVED_KEYS = { "BgDeep", "Sidebar", "Card", "CardAlt", "CardHover", "CardHeader", "Border", "BorderLow", "Text",
    "TextDim", "TextMute", "Accent", "AccentDim", "AccentOn", "Success", "Warning", "Error", "Toggle_On", "Toggle_Off" }
local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function derive(p)
    local bg, sf, tx, mu, ac = c3(p.background), c3(p.surface), c3(p.text), c3(p.muted), c3(p.accent)
    local d = {
        BgDeep = bg, Sidebar = bg:Lerp(sf, 0.45), Card = sf,
        CardAlt = sf:Lerp(tx, 0.075), CardHover = sf:Lerp(tx, 0.125), CardHeader = sf:Lerp(tx, 0.045),
        Border = sf:Lerp(tx, 0.18), BorderLow = sf:Lerp(tx, 0.10),
        Text = tx, TextDim = mu, TextMute = mu:Lerp(bg, 0.45),
        Accent = ac, AccentDim = ac:Lerp(bg, 0.22), AccentOn = ac,
        Success = Color3.fromRGB(110, 220, 130), Warning = Color3.fromRGB(240, 190, 110), Error = Color3.fromRGB(240, 110, 130),
        Toggle_On = ac, Toggle_Off = sf:Lerp(tx, 0.115),
    }
    local seen = {}
    for _, k in ipairs(DERIVED_KEYS) do
        local c = d[k]
        local r, g, b = math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)
        while seen[r * 65536 + g * 256 + b] do
            b = b + 1
            if b > 255 then b = 0; g = (g + 1) % 256 end
        end
        seen[r * 65536 + g * 256 + b] = true
        d[k] = Color3.fromRGB(r, g, b)
    end
    return d
end
local T = derive(PALETTES.Mono)
local F = {
    Bold    = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    Medium  = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
    Regular = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
}

-- ============================================================================
-- HELPERS
-- ============================================================================
local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do if k ~= "Parent" then inst[k] = v end end
    if children then for _, c in ipairs(children) do c.Parent = inst end end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end
local function Corner(p, r)   return New("UICorner", { CornerRadius = UDim.new(0, r or 8), Parent = p }) end
local function Stroke(p, c, t)
    return New("UIStroke", { Color = c or T.BorderLow, Thickness = t or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
end
local function Padding(p, l, r, t, b)
    return New("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = p })
end
local function VList(p, gap, hAlign)
    return New("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0), HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left, Parent = p })
end
local function HList(p, gap, vAlign)
    return New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0), VerticalAlignment = vAlign or Enum.VerticalAlignment.Center, Parent = p })
end
local function Tween(obj, props, dur, style)
    local tw = TweenService:Create(obj, TweenInfo.new(dur or 0.18, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play(); return tw
end
-- click ripple: a soft circle grows from the pointer and fades. It lives in a rounded CanvasGroup made for this
-- click (a CanvasGroup clips to its corner, a plain frame would clip square) and is gone after 0.6 s
local function Ripple(btn, color)
    local abs, size = btn.AbsolutePosition, btn.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return end
    -- AbsolutePosition starts below the top bar, GetMouseLocation at the top of the screen
    local m = UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
    local host = New("CanvasGroup", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = btn })
    local rc = btn:FindFirstChildOfClass("UICorner")
    New("UICorner", { CornerRadius = rc and rc.CornerRadius or UDim.new(0, 8), Parent = host })
    local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.clamp((m.X - abs.X) / size.X, 0, 1), math.clamp((m.Y - abs.Y) / size.Y, 0, 1)),
        Size = UDim2.fromScale(0, 0), BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = 0.8,
        BorderSizePixel = 0, Parent = host })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
    New("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = dot })
    local w = 2.4 * math.max(1, size.Y / size.X)
    Tween(dot, { Size = UDim2.fromScale(w, w), BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quad)
    task.delay(0.6, function() host:Destroy() end)
end

local function resolveIconUrl(assetId)
    if not assetId or assetId == "" then return nil end
    local numeric = tostring(assetId):match("%d+")
    if not numeric then return nil end
    return "rbxthumb://type=Asset&id=" .. numeric .. "&w=150&h=150"
end

local PRESERVE_COLOR = { discord = true, logo = true }

task.spawn(function()
    local list = {}
    for _, id in pairs(ICONS) do
        local url = resolveIconUrl(id)
        if url then table.insert(list, url) end
    end
    pcall(function() ContentProvider:PreloadAsync(list) end)
end)

local function makeLucideIcon(parent, lucideName, size, color, preserveColor)
    if not LucideAtlas then return nil end
    local atlas = LucideAtlas["48px"] or LucideAtlas["24px"] or LucideAtlas
    if not atlas then return nil end
    local entry = atlas[lucideName]
    if not entry then return nil end
    local props = {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, size, 0, size),
        Image = "rbxassetid://" .. tostring(entry[1]),
        ImageRectSize   = Vector2.new(entry[2][1], entry[2][2]),
        ImageRectOffset = Vector2.new(entry[3][1], entry[3][2]),
        ScaleType = Enum.ScaleType.Fit,
        Parent = parent,
    }
    if not preserveColor then props.ImageColor3 = color end
    local img = New("ImageLabel", props)
    New("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = img })
    return img
end

local function MakeIcon(parent, name, size, color)
    size = size or 18
    color = color or T.Text
    local preserve = PRESERVE_COLOR[name] == true

    local url = resolveIconUrl(ICONS[name])
    if url then
        local props = {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, size, 0, size),
            Image = url,
            ScaleType = Enum.ScaleType.Fit, Parent = parent,
        }
        if not preserve then props.ImageColor3 = color end
        local img = New("ImageLabel", props)
        New("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = img })
        return img
    end

    local lucideName = LUCIDE_FALLBACK[name] or name
    local lucide = makeLucideIcon(parent, lucideName, size, color, preserve)
    if lucide then return lucide end

    local placeholder = New("Frame", {
        BackgroundTransparency = 1, Size = UDim2.new(0, size, 0, size), Parent = parent,
    })
    placeholder:SetAttribute("OkumaIconPending", name)
    placeholder:SetAttribute("OkumaIconSize",   size)
    placeholder:SetAttribute("OkumaIconColorR", color.R)
    placeholder:SetAttribute("OkumaIconColorG", color.G)
    placeholder:SetAttribute("OkumaIconColorB", color.B)
    return placeholder
end

local function sweepIconPlaceholders(root)
    if not LucideAtlas or not root then return end
    for _, d in ipairs(root:GetDescendants()) do
        local pending = d:GetAttribute("OkumaIconPending")
        if pending and d:IsA("Frame") then
            local sz    = d:GetAttribute("OkumaIconSize") or 18
            local color = Color3.new(
                d:GetAttribute("OkumaIconColorR") or 1,
                d:GetAttribute("OkumaIconColorG") or 1,
                d:GetAttribute("OkumaIconColorB") or 1)
            local parent = d.Parent
            local lucideName = LUCIDE_FALLBACK[pending] or pending
            local newIcon = makeLucideIcon(parent, lucideName, sz, color, PRESERVE_COLOR[pending] == true)
            if newIcon then
                newIcon.Position    = d.Position
                newIcon.AnchorPoint = d.AnchorPoint
                newIcon.LayoutOrder = d.LayoutOrder
                newIcon.ZIndex      = d.ZIndex
                d:Destroy()
            end
        end
    end
end

-- ============================================================================
-- MOUNT GUI
-- ============================================================================
local function MountGui()
    local sg = New("ScreenGui", {
        Name = PFX .. tostring(math.random(1e6, 9e6)),
        ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    local ok = pcall(function()
        if type(gethui) == "function" then sg.Parent = gethui(); return end
        if syn and type(syn.protect_gui) == "function" then syn.protect_gui(sg); sg.Parent = CoreGui; return end
        if type(protect_gui) == "function" then protect_gui(sg); sg.Parent = CoreGui; return end
        sg.Parent = CoreGui
    end)
    if not ok or not sg.Parent then sg.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    return sg
end
local gui = MountGui()

task.spawn(function()
    while not LucideAtlas and not lucideDone and gui.Parent do task.wait(0.2) end
    if LucideAtlas and gui.Parent then sweepIconPlaceholders(gui) end
end)

-- ============================================================================
-- CONFIG PERSISTENCE
-- ============================================================================
local CONFIG_FILE = "okuma_" .. ID .. ".json"
local Config = {
    toggleKey   = "RightControl",
    antiAfk     = true,
    minimizeOnStart = false,
    toggleButton = "Mobile only",
    preset      = "Mono",
    notifs      = true,
    hideName    = false,
    hideAvatar  = false,
    uiScale     = 100,
    adaptive    = true,
    cornerRadius = 10,
    density     = "Default",
    dim         = true,
    blur        = true,
    transparent = false,
    dragStyle   = "Outline",
    island      = "Show on Hover",
    weather     = "None",
    weatherMode = "Screen",
    bgMode      = "None",
    bgImage     = "",
    bgOpacity   = 65,
    autoReconnect = false,
    reconnectDelay = 5,
    disable3d   = false,
    panicKey    = "None",
    autoLoad    = "",
    defaultTheme = "",
    themes      = {},
    islandX     = 0.5,
    islandY     = 12,
        local Config = {
    toggleKey   = "RightControl",
    -- ... (deixe o resto como está) ...
    islandX     = 0.5,
    islandY     = 12,
    
    -- ADICIONE ESTAS LINHAS AQUI:
    brandLayout    = (opts.brand and opts.brand.layout) or "row",
    brandLogoSize  = (opts.brand and opts.brand.logoSize) or 32,
    brandHeight    = (opts.brand and opts.brand.height) or 60,
    brandTitleSize = (opts.brand and opts.brand.titleSize) or 14,
    brandSubtitle  = (opts.brand and opts.brand.subtitle) or "Beta",
}
}
local HttpService = game:GetService("HttpService")
-- writes are gathered: a slider being dragged asks to save on every step, the file is written once 0.4 s after
-- the last ask. SaveConfig(true) writes right away (unload); after unload nothing is written any more.
local function SaveConfig(now)
    if not now then
        if UI._saveQueued then return end
        UI._saveQueued = true
        task.delay(0.4, function()
            UI._saveQueued = false
            if not UI._saveDead then SaveConfig(true) end
        end)
        return
    end
    if type(writefile) ~= "function" then return end
    local snap = {}
    -- keys a game script marked volatile (UI.volatile) are never written to disk
    for k, v in pairs(Config) do if not UI._volatile[k] then snap[k] = v end end
    -- a value JSON cannot hold (inf, NaN, an Instance...) makes the whole write fail: say so in the log
    local ok, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(snap)) end)
    if not ok then UI.log("error", "settings not saved: " .. tostring(err)) end
end
local function LoadConfig()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then return end
    local existsOk, exists = pcall(isfile, CONFIG_FILE)
    if not existsOk or not exists then return end
    local readOk, content = pcall(readfile, CONFIG_FILE)
    if not readOk or not content or content == "" then return end
    local decOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
    if decOk and type(decoded) == "table" then
        for k, v in pairs(decoded) do Config[k] = v end
    end
end
if type(opts.config) == "table" then for k, v in pairs(opts.config) do Config[k] = v end end
LoadConfig()

-- settings saved by the older UI may hold a theme preset picked in passing: start from the default look once
if Config.themeVersion ~= 4 then
    Config.preset = "Mono"; Config.customPal = nil; Config.themeVersion = 4
end

-- the window is moved with the outline frame by default (one-time switch for older saved settings)
if Config.uiVersion ~= 5 then Config.dragStyle = "Outline"; Config.uiVersion = 5 end

-- the palette the saved settings ask for (a default theme wins over the preset)
if Config.defaultTheme ~= "" and type(Config.themes) == "table" and type(Config.themes[Config.defaultTheme]) == "table" then
    Config.customPal = Config.themes[Config.defaultTheme]
end
local function paletteSpec()
    if type(Config.customPal) == "table" then return Config.customPal end
    return PALETTES[Config.preset] or PALETTES.Mono
end
for k, v in pairs(derive(paletteSpec())) do T[k] = v end

-- the pieces of the UI that change settings register themselves here, so loading a config can refresh them
local Apply = {}
local Ctl = {}

-- base64 (config sharing codes)
local b64enc, b64dec
do
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function b64enc(data)
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
function b64dec(data)
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
end

-- every long-lived connection goes through Track() so Unload / re-execute can kill them all
local Connections = {}
local function Track(conn)
    table.insert(Connections, conn)
    return conn
end

-- ============================================================================
-- NOTIFICATIONS (toast)
-- ============================================================================
local Notify
do
-- ZIndex 100: in Sibling mode the holder must outrank the window or toasts render underneath it
local toastHolder = New("Frame", {
    Name = "Toasts",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -18, 1, -18),
    Size = UDim2.new(0, 250, 0, 320),
    BackgroundTransparency = 1, ZIndex = 100, Parent = gui,
})
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6), Parent = toastHolder,
})

local toastSeq = 0
local MAX_TOASTS = 4

-- Ouroboros-style toast: square icon badge, title + subtitle, X close, progress bar at the bottom.
-- opts.color picks the badge tint (defaults to Success-green, like their "Copied" toast).
-- opts.icon is a Lucide name; defaults to "check" / "x" based on color.
function Notify(opts)
    if not Config.notifs then return end
    opts = opts or {}
    toastSeq = toastSeq + 1
    local accent  = opts.color or T.Success
    if UI._islandFlash then UI._islandFlash(opts.title, opts.body, accent) end
    local hasBody = opts.body ~= nil and opts.body ~= ""
    local duration = opts.duration or 2.6
    local iconName = opts.icon or ((accent == T.Error) and "x" or (accent == T.Warning) and "alert-triangle" or "check")
    local height = 64

    -- never let toasts pile up: the oldest ones leave (with their own exit animation) to make room
    UI._toastDismiss = UI._toastDismiss or setmetatable({}, { __mode = "k" })
    local live = {}
    for _, c in ipairs(toastHolder:GetChildren()) do
        if c:IsA("Frame") and not c:GetAttribute("Leaving") then table.insert(live, c) end
    end
    table.sort(live, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #live >= MAX_TOASTS do
        local old = table.remove(live, 1)
        local leave = UI._toastDismiss[old]
        if leave then leave() else old:Destroy() end
    end

    -- the slot opens from 0 height so the toasts above glide up instead of jumping; the card sits at its bottom
    local wrap = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ClipsDescendants = true,
        LayoutOrder = toastSeq, Parent = toastHolder,
    })
    local card = New("CanvasGroup", {
        AnchorPoint = Vector2.new(0, 1), Size = UDim2.new(1, 0, 0, height), Position = UDim2.new(0, 40, 1, 0),
        BackgroundColor3 = T.Card, BorderSizePixel = 0,
        GroupTransparency = 1, ClipsDescendants = true, Parent = wrap,
    })
    Corner(card, 12); Stroke(card, T.BorderLow, 1)
    card.BackgroundColor3 = T.BgDeep

    -- plain tinted icon (no badge box), title takes the accent color — like their "Copied" toast
    -- it pops in a beat after the card, from small and turned
    local badgeIcon = MakeIcon(card, iconName, 20, accent)
    badgeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    badgeIcon.Position = UDim2.new(0, 26, 0, 21)
    badgeIcon.Size = UDim2.new(0, 6, 0, 6); badgeIcon.Rotation = -40
    task.delay(0.14, function() Tween(badgeIcon, { Size = UDim2.new(0, 20, 0, 20), Rotation = 0 }, 0.5, Enum.EasingStyle.Back) end)

    New("TextLabel", {
        Position = UDim2.new(0, 46, 0, 9), Size = UDim2.new(1, -76, 0, 16),
        BackgroundTransparency = 1, Text = opts.title or BRAND, TextColor3 = accent,
        FontFace = F.Bold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
    })
    if hasBody then
        New("TextLabel", {
            Position = UDim2.new(0, 46, 0, 28), Size = UDim2.new(1, -76, 0, 14),
            BackgroundTransparency = 1, Text = opts.body, TextColor3 = T.TextDim,
            FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = card,
        })
    end

    -- close (X) button
    local closeBtn = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.new(0, 18, 0, 18), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, Parent = card,
    })
    local closeIcon = MakeIcon(closeBtn, "x", 13, T.TextDim)
    closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    closeIcon.Position = UDim2.new(0.5, 0, 0.5, 0)

    -- progress bar: thin, inset from the edges, filled in the toast's colour on a dark track (drains over `duration`)
    local barTrack = New("Frame", {
        Position = UDim2.new(0, 16, 1, -10), Size = UDim2.new(1, -32, 0, 3),
        BackgroundColor3 = T.CardHover, BorderSizePixel = 0, Parent = card,
    })
    Corner(barTrack, 2)
    local barFill = New("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = accent,
        BorderSizePixel = 0, Parent = barTrack,
    })
    Corner(barFill, 2)
    New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), Parent = barFill })

    local dismissed = false
    local function dismiss()
        if dismissed or not wrap.Parent then return end
        dismissed = true
        wrap:SetAttribute("Leaving", true)
        Tween(card, { Position = UDim2.new(0, 40, 1, 0), GroupTransparency = 1 }, 0.3, Enum.EasingStyle.Quint)
        -- then the empty slot closes, so the stack slides down into it
        task.delay(0.2, function() if wrap.Parent then wrap.ClipsDescendants = true; Tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, 0.28, Enum.EasingStyle.Quint) end end)
        task.delay(0.5, function() if wrap.Parent then wrap:Destroy() end end)
    end
    closeBtn.MouseButton1Click:Connect(dismiss)
    UI._toastDismiss[wrap] = dismiss

    Tween(wrap, { Size = UDim2.new(1, 0, 0, height) }, 0.3, Enum.EasingStyle.Quint)
    -- the clip is only for the opening: once open, the card's outline (drawn just outside it) must show
    task.delay(0.44, function() if not dismissed then wrap.ClipsDescendants = false end end)
    Tween(card, { Position = UDim2.new(0, 0, 1, 0), GroupTransparency = 0 }, 0.42, Enum.EasingStyle.Quint)
    -- a corner radius set in Appearance reaches new toasts too
    if (Config.cornerRadius or 10) ~= 10 and Apply.radius then task.defer(Apply.radius, card) end

    -- the time runs out only while the mouse is not on the toast: hovering it pauses the bar so it can be read
    local remaining, hovering = duration, false
    local drain
    local function runBar()
        drain = Tween(barFill, { Size = UDim2.new(0, 0, 1, 0) }, remaining, Enum.EasingStyle.Linear)
    end
    card.MouseEnter:Connect(function() hovering = true; if drain then drain:Pause() end end)
    card.MouseLeave:Connect(function() hovering = false; if not dismissed and remaining > 0 then runBar() end end)
    runBar()
    task.spawn(function()
        while remaining > 0 and not dismissed and wrap.Parent do
            local dt = task.wait(0.05)
            if not hovering then remaining = remaining - dt end
        end
        dismiss()
    end)
end
end

-- clipboard helper
local function Copy(text)
    local fn = setclipboard or (syn and syn.write_clipboard) or (toclipboard)
    if type(fn) == "function" then pcall(fn, text); return true end
    return false
end

-- ============================================================================
-- WINDOW
-- ============================================================================
local WINDOW_W, WINDOW_H = 820, 560
local SIDEBAR_W = 190

-- the screen is dimmed behind the window while it is open
local dim = New("Frame", { Name = "Dim", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 1, Parent = gui })
local window = New("Frame", {
    Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5),
    -- the size it was resized to last time (the grip in the bottom-right corner), within 680x460 .. 1400x900
    Size = UDim2.new(0, math.clamp(tonumber(Config.winW) or WINDOW_W, 680, 1400), 0, math.clamp(tonumber(Config.winH) or WINDOW_H, 460, 900)),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = T.BgDeep, BorderSizePixel = 0, Parent = gui, ClipsDescendants = true, Visible = false, ZIndex = 3,
})
Corner(window, 16)
local windowStroke = Stroke(window, T.Border, 1)
local windowScale = New("UIScale", { Scale = 1, Parent = window })
-- a slow accent glint running round the window's outline. The outline itself is white and the gradient carries
-- the colours (Border with an Accent band), so a theme change repaints the gradient.
do
    windowStroke.Color = Color3.new(1, 1, 1)
    local grad = New("UIGradient", { Parent = windowStroke })
    function UI._paintBorder()
        grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.Border), ColorSequenceKeypoint.new(0.38, T.Border),
            ColorSequenceKeypoint.new(0.5, T.Accent), ColorSequenceKeypoint.new(0.62, T.Border),
            ColorSequenceKeypoint.new(1, T.Border),
        })
    end
    UI._paintBorder()
    Track(RunService.RenderStepped:Connect(function()
        if not window.Visible then return end
        grad.Rotation = (os.clock() * 40) % 360
    end))
end
local bgParts = {}   -- the sidebar / footer background panels (they fade and turn translucent with the window)

local hookDrag
do
local dragging, dragStart, startPos, ghost
function hookDrag(host)
    host.Active = true
    host.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = window.Position
            if Config.dragStyle == "Outline" then
                ghost = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5), Position = window.Position,
                    Size = UDim2.fromOffset(window.AbsoluteSize.X, window.AbsoluteSize.Y),
                    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 80, Parent = gui,
                })
                -- a see-through frame with a thin white outline and an L at each corner, like a selection box
                ghost.BackgroundColor3 = Color3.fromRGB(255, 255, 255); ghost.BackgroundTransparency = 0.94
                Corner(ghost, math.floor(16 * windowScale.Scale))
                New("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.12, Parent = ghost })
                for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
                    local ax, ay = c[1], c[2]
                    local ox, oy = (ax == 0) and 10 or -10, (ay == 0) and 10 or -10
                    local function bar(w, h)
                        New("Frame", { AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, ox, ay, oy),
                            Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = ghost })
                    end
                    bar(16, 2); bar(2, 16)
                end
            end
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and dragging then
                    dragging = false
                    local final = window.Position
                    if ghost then
                        local g = ghost; ghost = nil
                        final = g.Position
                        Tween(window, { Position = g.Position }, 0.22, Enum.EasingStyle.Quint)
                        g:Destroy()
                    end
                    -- the window opens here next time (offsets from the middle of the screen)
                    Config.winX, Config.winY = final.X.Offset, final.Y.Offset
                    SaveConfig()
                end
            end)
        end
    end)
end
Track(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        local pos = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        if ghost then ghost.Position = pos else window.Position = pos end
    end
end))
end

-- ============================================================================
-- SIDEBAR
-- ============================================================================
-- a coloured panel with rounded corners only where it touches the edge of the window; the
-- corners that meet another panel are patched square. Used for the sidebar and footer backgrounds.
local function Panel(parent, pos, size, color, tl, tr, bl, br)
    local base = New("Frame", { Position = pos, Size = size, BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent })
    Corner(base, 16)
    bgParts[#bgParts + 1] = base
    -- a patch is at most half the panel tall: in the 30 px footer a 24 px one reached down over the rounded corner below it
    local function patch(ax, ay)
        local f = New("Frame", { AnchorPoint = Vector2.new(ax, ay), Position = UDim2.new(ax, 0, ay, 0),
            Size = UDim2.new(0, 24, 0.5, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = base })
        bgParts[#bgParts + 1] = f
    end
    if not tl then patch(0, 0) end
    if not tr then patch(1, 0) end
    if not bl then patch(0, 1) end
    if not br then patch(1, 1) end
    return base
end
Panel(window, UDim2.new(0, 0, 0, 0), UDim2.new(0, SIDEBAR_W, 1, 0), T.Sidebar, true, false, true, false)
Panel(window, UDim2.new(0, SIDEBAR_W, 1, -30), UDim2.new(1, -SIDEBAR_W, 0, 30), T.Sidebar, false, false, false, true)

local sidebar = New("CanvasGroup", {
    Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, 0),
    BackgroundColor3 = T.Sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = window,
})
New("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = T.BorderLow, BorderSizePixel = 0, Parent = sidebar })

-- ============================================================================
-- BRAND DINÂMICO (Editável via UI.setBrand)
-- ============================================================================
local brandContainer = New("Frame", { Size = UDim2.new(1, 0, 0, Config.brandHeight), BackgroundTransparency = 1, Parent = sidebar })
Padding(brandContainer, 16, 12, 16, 10); hookDrag(brandContainer)

local brandIconHolder = New("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Parent = brandContainer })
local brandIcon = MakeIcon(brandIconHolder, "logo", Config.brandLogoSize, T.Text); Corner(brandIcon, math.floor(Config.brandLogoSize * 0.3))
brandIcon.Size = UDim2.new(1, 0, 1, 0)

local brandTitle = New("TextLabel", { BackgroundTransparency = 1, Text = BRAND, TextColor3 = T.Text,
    FontFace = F.Bold, TextSize = Config.brandTitleSize, TextXAlignment = Enum.TextXAlignment.Left, Parent = brandContainer })
local brandSub = New("TextLabel", { BackgroundTransparency = 1, Text = Config.brandSubtitle, TextColor3 = T.TextDim,
    FontFace = F.Regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = brandContainer })

brandContainer.MouseEnter:Connect(function()
    local g = brandIconHolder:FindFirstChildWhichIsA("ImageLabel")
    if not g then return end
    Tween(g, { Rotation = -12, Size = UDim2.new(1.1, 0, 1.1, 0) }, 0.12, Enum.EasingStyle.Quad)
    task.delay(0.12, function() Tween(g, { Rotation = 0, Size = UDim2.new(1, 0, 1, 0) }, 0.6, Enum.EasingStyle.Elastic) end)
end)

function Apply.brand()
    local layout = Config.brandLayout or "row"
    local size = Config.brandLogoSize or 32
    local h = Config.brandHeight or 60

    brandContainer.Size = UDim2.new(1, 0, 0, h)
    
    brandIconHolder.Size = UDim2.new(0, size, 0, size)
    brandTitle.Text = BRAND
    brandTitle.TextSize = Config.brandTitleSize
    brandSub.Text = Config.brandSubtitle

    if layout == "row" then
        brandIconHolder.AnchorPoint = Vector2.new(0, 0.5)
        brandIconHolder.Position = UDim2.new(0, 0, 0.5, 0)

        brandTitle.Visible = true
        brandTitle.Position = UDim2.new(0, size + 12, 0, 4)
        brandTitle.Size = UDim2.new(1, -(size + 12), 0, 16)
        brandTitle.TextXAlignment = Enum.TextXAlignment.Left

        brandSub.Visible = Config.brandSubtitle ~= ""
        brandSub.Position = UDim2.new(0, size + 12, 0, 22)
        brandSub.Size = UDim2.new(1, -(size + 12), 0, 12)
        brandSub.TextXAlignment = Enum.TextXAlignment.Left

    elseif layout == "column" then
        brandIconHolder.AnchorPoint = Vector2.new(0.5, 0)
        brandIconHolder.Position = UDim2.new(0.5, 0, 0, 0)

        brandTitle.Visible = true
        brandTitle.Position = UDim2.new(0, 0, 0, size + 6)
        brandTitle.Size = UDim2.new(1, 0, 0, 16)
        brandTitle.TextXAlignment = Enum.TextXAlignment.Center

        brandSub.Visible = Config.brandSubtitle ~= ""
        brandSub.Position = UDim2.new(0, 0, 0, size + 24)
        brandSub.Size = UDim2.new(1, 0, 0, 12)
        brandSub.TextXAlignment = Enum.TextXAlignment.Center

    elseif layout == "icon-only" then
        brandIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
        brandIconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
        brandTitle.Visible = false
        brandSub.Visible = false

    elseif layout == "banner" then
        brandIconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
        brandIconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
        brandIconHolder.Size = UDim2.new(0, h, 0, h)

        brandTitle.Visible = true
        brandTitle.Position = UDim2.new(0, 0, 0.5, -8)
        brandTitle.Size = UDim2.new(1, 0, 0, 16)
        brandTitle.TextXAlignment = Enum.TextXAlignment.Center

        brandSub.Visible = Config.brandSubtitle ~= ""
        brandSub.Position = UDim2.new(0, 0, 0.5, 8)
        brandSub.Size = UDim2.new(1, 0, 0, 12)
        brandSub.TextXAlignment = Enum.TextXAlignment.Center
    end
end
Apply.brand()
-- the sidebar list scrolls when a game has more pages than fit; with few pages it looks exactly as before
local navHolder = New("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, Config.brandHeight + 12), Size = UDim2.new(1, 0, 1, -(Config.brandHeight + 88)),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Border,
    ScrollBarImageTransparency = 0.4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, Parent = sidebar,
})
Padding(navHolder, 10, 10, 4, 4)
-- the active entry's background: one frame that glides between the entries. It lives in the scrolled area (so it
-- scrolls and clips with them) but outside the list layout, made first so it draws under the entries. Its spot
-- comes from the rows (38 per visible entry above), not AbsolutePosition, so it is right while hidden or scaled.
local navHL = New("Frame", { Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Card,
    BorderSizePixel = 0, Visible = false, Parent = navHolder })
Corner(navHL, 9); Stroke(navHL, T.BorderLow, 1)
-- a short accent bar on the highlight's left edge; it stretches while the highlight travels
UI._navBar = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 3, 0, 16),
    BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = navHL })
Corner(UI._navBar, 2)
local navList = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = navHolder })
VList(navList, 2)

local navRefs = {}
local pages = {}
local activePageId = nil

local function AddNavItem(id, title, iconName)
    -- navRefs is keyed by id, so #navRefs is always 0: count the entries ourselves
    UI._navN = (UI._navN or 0) + 1
    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, LayoutOrder = UI._navN, Parent = navList,
    })
    Corner(btn, 9)

    local iconObj = MakeIcon(btn, iconName, 18, T.TextDim)
    iconObj.Position = UDim2.new(0, 14, 0.5, -9)

    local labelObj = New("TextLabel", {
        Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -48, 1, 0),
        BackgroundTransparency = 1, Text = title, TextColor3 = T.TextDim,
        FontFace = F.Medium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = btn,
    })

    -- hovered: the icon and label lean a few pixels right (the icon is looked up live, it may have been swapped)
    local function lean(on)
        local ic = btn:FindFirstChildWhichIsA("ImageLabel")
        if ic then Tween(ic, { Position = UDim2.new(0, on and 17 or 14, 0.5, -9) }, 0.22, Enum.EasingStyle.Quint) end
        Tween(labelObj, { Position = UDim2.new(0, on and 46 or 42, 0, 0) }, 0.22, Enum.EasingStyle.Quint)
    end
    btn.MouseEnter:Connect(function()
        lean(true)
        if activePageId ~= id then
            Tween(btn, { BackgroundTransparency = 0.72 }, 0.15)
            btn.BackgroundColor3 = T.Card
        end
    end)
    btn.MouseLeave:Connect(function()
        lean(false)
        if activePageId ~= id then
            Tween(btn, { BackgroundTransparency = 1 }, 0.15)
        end
    end)
    btn.MouseButton1Click:Connect(function() Ripple(btn, T.Text); UI._selectPage(id) end)

    navRefs[id] = { button = btn, iconObj = iconObj, labelObj = labelObj }
end

local function placeNavHL(id, animated)
    local ref = id and navRefs[id]
    if not ref or not ref.button.Visible then navHL.Visible = false; return end
    local n = 0
    for _, r in pairs(navRefs) do
        if r.button.Visible and r.button.LayoutOrder < ref.button.LayoutOrder then n = n + 1 end
    end
    local pos = UDim2.new(0, 0, 0, n * 38)
    if animated and navHL.Visible and navHL.Position ~= pos then
        Tween(navHL, { Position = pos }, 0.36, Enum.EasingStyle.Quint)
        local bar = UI._navBar
        Tween(bar, { Size = UDim2.new(0, 3, 0, 28) }, 0.14, Enum.EasingStyle.Quad)
        task.delay(0.16, function() Tween(bar, { Size = UDim2.new(0, 3, 0, 16) }, 0.4, Enum.EasingStyle.Back) end)
    else
        navHL.Position = pos
    end
    navHL.Visible = true
    -- keep the active entry in view when the list scrolls
    local top, view = n * 38, navHolder.AbsoluteWindowSize.Y / math.max(windowScale.Scale, 0.01)
    if view > 0 then
        local y = navHolder.CanvasPosition.Y
        if top < y then y = top elseif top + 36 > y + view then y = top + 36 - view + 8 end
        navHolder.CanvasPosition = Vector2.new(0, math.max(0, y))
    end
end

-- the game's pages are added by UI.page() further down; Settings is added after them so it stays last
AddNavItem("home",     "Home",       "home")

-- user card
local userCard = New("TextButton", {
    AutoButtonColor = false, Text = "",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 60),
    BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = sidebar,
})
Corner(userCard, 10); Stroke(userCard, T.BorderLow, 1); Padding(userCard, 10, 10, 10, 10)

local avatarImg, userSil
do
local avatarHolder = New("Frame", {
    Position = UDim2.new(0, 0, 0.5, -16), Size = UDim2.new(0, 34, 0, 34),
    BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = userCard,
})
Corner(avatarHolder, 17); Stroke(avatarHolder, T.Border, 1)
avatarImg = New("ImageLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "", Parent = avatarHolder,
})
Corner(avatarImg, 17)
function UI._silhouette(parent)
    local box = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = parent })
    local head = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.2, 0),
        Size = UDim2.new(0.32, 0, 0.32, 0), BackgroundColor3 = T.TextMute, BorderSizePixel = 0, Parent = box })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = head })
    local body = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.56, 0),
        Size = UDim2.new(0.58, 0, 0.34, 0), BackgroundColor3 = T.TextMute, BorderSizePixel = 0, Parent = box })
    New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = body })
    return box
end
userSil = UI._silhouette(avatarHolder)
-- the thumbnail request waits on the web: in its own thread so the UI does not wait for it
task.spawn(pcall, function()
    avatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
local dot = New("Frame", { Position = UDim2.new(0, 25, 0, 25), Size = UDim2.new(0, 9, 0, 9),
    BackgroundColor3 = T.Success, BorderSizePixel = 0, Parent = userCard })
Corner(dot, 5)
Stroke(dot, T.Card, 2)
-- the online dot breathes: a ring of its colour grows out of it and fades, over and over
do
    local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Success, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = dot })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
        { Size = UDim2.new(2.6, 0, 2.6, 0), BackgroundTransparency = 1 }):Play()
end
end

local userNameLbl = New("TextLabel", {
    Position = UDim2.new(0, 44, 0, 4), Size = UDim2.new(1, -72, 0, 14),
    BackgroundTransparency = 1, Text = LocalPlayer.DisplayName or LocalPlayer.Name,
    TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = userCard,
})
local userHandleLbl = New("TextLabel", {
    Position = UDim2.new(0, 44, 0, 22), Size = UDim2.new(1, -72, 0, 12),
    BackgroundTransparency = 1, Text = ("@%s"):format(LocalPlayer.Name),
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = userCard,
})
do
local userChevron = MakeIcon(userCard, "chevron_right", 14, T.TextDim)
userChevron.AnchorPoint = Vector2.new(1, 0.5)
userChevron.Position = UDim2.new(1, -4, 0.5, 0)
userCard.MouseEnter:Connect(function()
    Tween(userCard, { BackgroundColor3 = T.CardHover }, 0.15)
    Tween(userChevron, { Position = UDim2.new(1, -1, 0.5, 0) }, 0.15)
end)
userCard.MouseLeave:Connect(function()
    Tween(userCard, { BackgroundColor3 = T.Card }, 0.15)
    Tween(userChevron, { Position = UDim2.new(1, -4, 0.5, 0) }, 0.15)
end)
end
userCard.MouseButton1Click:Connect(function() UI._selectPage("home") end)

-- ============================================================================
-- CONTENT
-- ============================================================================
local content = New("CanvasGroup", {
    Name = "Content", Position = UDim2.new(0, SIDEBAR_W, 0, 0),
    Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
    BackgroundColor3 = T.BgDeep, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = window,
})

local header = New("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, Parent = content })
Padding(header, 24, 20, 18, 10); hookDrag(header)

local headerIcon = MakeIcon(header, "home", 24, T.Text)
headerIcon.Position = UDim2.new(0, 0, 0.5, -12)

local headerTitle = New("TextLabel", {
    Position = UDim2.new(0, 36, 0, 0), Size = UDim2.new(0.6, 0, 1, 0),
    BackgroundTransparency = 1, Text = "Welcome to " .. BRAND .. "!", TextColor3 = T.Text,
    FontFace = F.Bold, TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Parent = header,
})

local searchBox = New("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -48, 0.5, -16), Size = UDim2.new(0, 200, 0, 32),
    BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = header,
})
Corner(searchBox, 9)
local searchStroke = Stroke(searchBox, T.BorderLow, 1)
MakeIcon(searchBox, "search", 14, T.TextDim).Position = UDim2.new(0, 12, 0.5, -7)
local searchInput = New("TextBox", {
    Position = UDim2.new(0, 34, 0, 0), Size = UDim2.new(1, -40, 1, 0),
    BackgroundTransparency = 1, PlaceholderText = "Search",
    PlaceholderColor3 = T.TextDim, TextColor3 = T.Text, FontFace = F.Regular,
    TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = searchBox,
})
-- live nav filter (defined after navRefs exist; see wiring near the bottom)

local minBtn = New("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0.5, -16), Size = UDim2.new(0, 32, 0, 32),
    BackgroundColor3 = T.Card, BorderSizePixel = 0, Text = "",
    AutoButtonColor = false, Parent = header,
})
Corner(minBtn, 9); Stroke(minBtn, T.BorderLow, 1)
do
    local minIcon = MakeIcon(minBtn, "minimize", 14, T.TextDim)
    minIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    minIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
end
minBtn.MouseEnter:Connect(function()
    Tween(minBtn, { BackgroundColor3 = T.CardHover }, 0.15)
    local i = minBtn:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.Text, Rotation = 90 }, 0.3, Enum.EasingStyle.Quint) end
end)
minBtn.MouseLeave:Connect(function()
    Tween(minBtn, { BackgroundColor3 = T.Card }, 0.15)
    local i = minBtn:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.TextDim, Rotation = 0 }, 0.3, Enum.EasingStyle.Quint) end
end)
-- the search box widens and its outline lights up while you type in it
searchInput.Focused:Connect(function()
    Tween(searchBox, { Size = UDim2.new(0, 236, 0, 32) }, 0.32, Enum.EasingStyle.Quint)
    Tween(searchStroke, { Color = T.Accent }, 0.15)
    local i = searchBox:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.Text }, 0.15) end
end)
searchInput.FocusLost:Connect(function()
    Tween(searchBox, { Size = UDim2.new(0, 200, 0, 32) }, 0.32, Enum.EasingStyle.Quint)
    Tween(searchStroke, { Color = T.BorderLow }, 0.2)
    local i = searchBox:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.TextDim }, 0.2) end
end)

-- body (scrolling)
local body = New("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 64), Size = UDim2.new(1, 0, 1, -94),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = T.Border,
    ScrollBarImageTransparency = 0.5,
    CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, Parent = content,
})
Padding(body, 24, 20, 4, 24); VList(body, 14)

-- footer
local footer = New("Frame", {
    Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 30),
    BackgroundColor3 = T.Sidebar, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = content,
})
New("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow, BorderSizePixel = 0, Parent = footer })
Padding(footer, 20, 16, 0, 0)

-- which executor runs us (identifyexecutor and friends, then the markers older ones leave behind), and which of
-- the functions the UI relies on it lacks. Games can read UI.executor = { name, version, missing = {...} }.
UI.executor = { name = "Unknown", missing = {} }
do
    local name, version
    local probes = { identifyexecutor, getexecutorname, whatexecutor }
    for i = 1, 3 do
        local f = probes[i]
        if type(f) == "function" then
            local ok, n, v = pcall(f)
            if ok and type(n) == "string" and n ~= "" then name = n; version = v ~= nil and tostring(v) or nil; break end
        end
    end
    if not name then
        if type(syn) == "table" then name = "Synapse X"
        elseif KRNL_LOADED then name = "KRNL"
        elseif type(fluxus) == "table" then name = "Fluxus"
        elseif type(is_sirhurt_closure) == "function" then name = "SirHurt" end
    end
    local need = { writefile = writefile, readfile = readfile, isfile = isfile, listfiles = listfiles, makefolder = makefolder,
        setclipboard = setclipboard or toclipboard or (syn and syn.write_clipboard), gethui = gethui }
    local missing = {}
    for _, n in ipairs({ "writefile", "readfile", "isfile", "listfiles", "makefolder", "setclipboard", "gethui" }) do
        if type(need[n]) ~= "function" then missing[#missing + 1] = n end
    end
    UI.executor.name, UI.executor.version, UI.executor.missing = name or "Unknown", version, missing
    if not name then
        UI._footerDefault = "Executor not identified; some features may not work."
    elseif #missing > 0 then
        UI._footerDefault = "Missing " .. table.concat(missing, ", ") .. "; some features may not work."
    else
        UI._footerDefault = "Your executor is supported and fully compatible."
    end
end

do
local footerDot = New("Frame", { Position = UDim2.new(0, 0, 0.5, -4), Size = UDim2.new(0, 8, 0, 8),
    BackgroundColor3 = (UI.executor.name == "Unknown" or #UI.executor.missing > 0) and T.Warning or T.Success,
    BorderSizePixel = 0, Parent = footer })
Corner(footerDot, 4)
local execLbl = New("TextLabel", { Position = UDim2.new(0, 16, 0, 0), Size = UDim2.new(0, 46, 1, 0),
    BackgroundTransparency = 1, Text = UI.executor.name, TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd,
    FontFace = F.Bold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = footer })
UI._footer = New("TextLabel", { Position = UDim2.new(0, 62, 0, 0), Size = UDim2.new(1, -220, 1, 0),
    BackgroundTransparency = 1, Text = UI._footerDefault,
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = footer })
-- a long executor name pushes the message right (a short one like "Volt" keeps the old 46 px slot)
execLbl:GetPropertyChangedSignal("TextBounds"):Connect(function()
    local w = math.clamp(math.ceil(execLbl.TextBounds.X) + 12, 46, 130)
    execLbl.Size = UDim2.new(0, w, 1, 0)
    UI._footer.Position = UDim2.new(0, 16 + w, 0, 0)
    UI._footer.Size = UDim2.new(1, -174 - w, 1, 0)
end)
end
New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -62, 0, 0),
    Size = UDim2.new(0, 70, 1, 0), BackgroundTransparency = 1,
    Text = "Hide with", TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = footer })
local hidePill = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.new(0, 54, 0, 22), BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = footer })
Corner(hidePill, 6); Stroke(hidePill, T.BorderLow, 1)
local hidePillLabel = New("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Text = "RCtrl", TextColor3 = T.Text, FontFace = F.Medium, TextSize = 10, Parent = hidePill })

-- resize grip: a little triangle of dots in the bottom-right corner. Dragging it grows the window right and down
-- (the top-left corner stays put); the size is saved and comes back next run.
do
    local grip = New("TextButton", { Name = "ResizeGrip", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
        Size = UDim2.new(0, 13, 0, 13), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 95, Parent = window })
    local dots = {}
    for _, d in ipairs({ { 10, 2 }, { 6, 6 }, { 10, 6 }, { 2, 10 }, { 6, 10 }, { 10, 10 } }) do
        local f = New("Frame", { Position = UDim2.fromOffset(d[1] - 1, d[2] - 1), Size = UDim2.fromOffset(2, 2), BackgroundColor3 = T.TextMute,
            BorderSizePixel = 0, ZIndex = 96, Parent = grip })
        dots[#dots + 1] = f
    end
    local function tint(c) for _, f in ipairs(dots) do Tween(f, { BackgroundColor3 = c }, 0.15) end end
    local from, size0, pos0, sizing
    grip.MouseEnter:Connect(function() tint(T.Text) end)
    grip.MouseLeave:Connect(function() if not sizing then tint(T.TextMute) end end)
    grip.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        sizing = true; from = input.Position; size0 = window.Size; pos0 = window.Position
        tint(T.Accent)
        input.Changed:Connect(function()
            if input.UserInputState ~= Enum.UserInputState.End or not sizing then return end
            sizing = false; tint(T.TextMute)
            Config.winW, Config.winH = window.Size.X.Offset, window.Size.Y.Offset
            Config.winX, Config.winY = window.Position.X.Offset, window.Position.Y.Offset
            SaveConfig()
            Apply.scale()
        end)
    end)
    Track(UserInputService.InputChanged:Connect(function(input)
        if not sizing or (input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch) then return end
        local sc = math.max(windowScale.Scale, 0.01)
        local d = (input.Position - from) / sc
        local w = math.clamp(size0.X.Offset + d.X, 680, 1400)
        local h = math.clamp(size0.Y.Offset + d.Y, 460, 900)
        window.Size = UDim2.new(0, w, 0, h)
        -- the window is anchored at its middle: move the middle by half the growth so the top-left stays
        local dw, dh = (w - size0.X.Offset) * sc / 2, (h - size0.Y.Offset) * sc / 2
        window.Position = UDim2.new(pos0.X.Scale, pos0.X.Offset + dw, pos0.Y.Scale, pos0.Y.Offset + dh)
    end))
end

-- ============================================================================
-- SHARED LIVE STATE (read by the island, the home page and the settings)
-- ============================================================================
local liveFps, livePing, sessionStart = 60, 0, tick()
local ToggleRegistry = {}
local KEY_SHORT = { RightControl = "RCtrl", LeftControl = "LCtrl", RightShift = "RShift", LeftShift = "LShift",
    RightAlt = "RAlt", LeftAlt = "LAlt", Return = "Enter", Backspace = "Bksp", Escape = "Esc", Insert = "Ins",
    Delete = "Del", PageUp = "PgUp", PageDown = "PgDn", Backquote = "`", None = "None", MouseButton2 = "RMB", MouseButton3 = "MMB" }
local function keyShort(n) return KEY_SHORT[n] or tostring(n) end
local function shownName()
    if Config.hideName then return "Hidden" end
    local d = LocalPlayer.DisplayName
    return (d and d ~= "") and d or LocalPlayer.Name
end
local function shownHandle()
    if Config.hideName then return "@hidden" end
    return "@" .. LocalPlayer.Name
end
local function sessionText()
    local s = math.floor(tick() - sessionStart)
    if s < 60 then return s .. "s"
    elseif s < 3600 then return math.floor(s / 60) .. "m " .. (s % 60) .. "s" end
    return math.floor(s / 3600) .. "h " .. math.floor((s % 3600) / 60) .. "m"
end
-- the features that are switched on right now (every toggle outside Home and Settings)
local function activeFeatures()
    local out = {}
    for _, t in ipairs(ToggleRegistry) do
        local row = t.row
        if row and row.Parent and t.get() and t.label and not t.system and not t.option then
            out[#out + 1] = t.label
        end
    end
    return out
end
local function currentTabTitle()
    local pg = activePageId and pages[activePageId]
    return pg and pg.title or "Home"
end

-- ============================================================================
-- DYNAMIC ISLAND
-- A small pill at the top of the screen while the window is closed. Hovering it opens a
-- live card, clicking it (or pressing the toggle key) opens the window in the middle.
-- ============================================================================
local island, islandCorner, pill, pillText, islCard, islHint, islName, islHandle, islAvatar, setPillText
local setIslandExpanded, showIsland, hideIsland, updateIslandBars, updateIslandCard, fpsColor, pingColor
local islandExpanded, islandHovering, islandShown = false, false, false
local openWindow, closeWindow, toggleWindow     -- defined with the window animation below
;(function()
local ISL_W, ISL_H = 236, 38
local ISL_BW, ISL_BH = 372, 236

island = New("Frame", {
    Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80),
    Size = UDim2.new(0, ISL_W, 0, ISL_H), BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = false, ZIndex = 60, Parent = gui,
})
islandCorner = Corner(island, ISL_H / 2)
Stroke(island, T.Border, 1)

-- compact content
pill = New("CanvasGroup", { Size = UDim2.new(1, 0, 0, ISL_H), BackgroundTransparency = 1, ZIndex = 61, Parent = island })
local pillLogoHolder = New("Frame", { Position = UDim2.new(0, 5, 0.5, -14), Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = pill })
Corner(pillLogoHolder, 14)
local pillLogo = MakeIcon(pillLogoHolder, "logo", 28, T.Text); Corner(pillLogo, 14)
-- a green dot pops onto the logo while a feature runs, with a ring breathing out of it
local pillRun = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.new(0, 9, 0, 9),
    BackgroundColor3 = T.Success, BorderSizePixel = 0, Visible = false, ZIndex = 3, Parent = pillLogoHolder })
Corner(pillRun, 5); Stroke(pillRun, T.BgDeep, 2)
do
    local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Success, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = pillRun })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
        { Size = UDim2.new(2.2, 0, 2.2, 0), BackgroundTransparency = 1 }):Play()
end
-- a notice on the pill: it stretches to the title, the logo and the outline take the notice's colour, a dot pops,
-- and after 2.2 s it goes back to what it showed (newer notices restart the timer)
local flashSeq = 0
function UI._islandFlash(title, body, color)
    if not islandShown or islandExpanded or not title then return end
    flashSeq = flashSeq + 1
    local my = flashSeq
    UI._islFlashing = true
    setPillText(tostring(title) .. ((body and body ~= "") and ("  ·  " .. tostring(body)) or ""))
    local ist = island:FindFirstChildOfClass("UIStroke")
    Tween(pillLogoHolder, { BackgroundColor3 = color }, 0.2)
    if ist then Tween(ist, { Color = color }, 0.2) end
    local lsc = pillLogoHolder:FindFirstChildOfClass("UIScale") or New("UIScale", { Scale = 1, Parent = pillLogoHolder })
    lsc.Scale = 0.6
    Tween(lsc, { Scale = 1 }, 0.5, Enum.EasingStyle.Back)
    task.delay(2.2, function()
        if flashSeq ~= my then return end
        UI._islFlashing = false
        Tween(pillLogoHolder, { BackgroundColor3 = T.CardAlt }, 0.4)
        if ist then Tween(ist, { Color = T.Border }, 0.5) end
        if islandShown and not islandExpanded then setPillText(UI._customIsl or (BRAND .. " · " .. currentTabTitle())) end
    end)
end
-- called twice a second by the live loop while the pill shows
function UI._pillTick()
    local on = #activeFeatures() > 0
    if on == pillRun.Visible then return end
    pillRun.Visible = on
    if on then pillRun.Size = UDim2.new(0, 2, 0, 2); Tween(pillRun, { Size = UDim2.new(0, 9, 0, 9) }, 0.45, Enum.EasingStyle.Back) end
end
pillLogo.AnchorPoint = Vector2.new(0.5, 0.5); pillLogo.Position = UDim2.new(0.5, 0, 0.5, 0)
pillText = New("TextLabel", { Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -88, 1, 0),
    BackgroundTransparency = 1, Text = BRAND, TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
    TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = pill })
-- new pill text fades out the old one and fades in (the same text again does nothing)
local pillSeq = 0
-- the pill is as wide as its text needs (200..360), so a game's longer island text is not cut; it springs to it
local TextService = game:GetService("TextService")
UI._pillW = ISL_W
local function pillWidth(text)
    local w = TextService:GetTextSize(tostring(text), 12, Enum.Font.GothamMedium, Vector2.new(1000, 20)).X
    return math.clamp(math.ceil(w) + 96, 200, 360)
end
local function fitPill(text)
    UI._pillW = pillWidth(text)
    if islandExpanded or not islandShown then return end
    Tween(island, { Size = UDim2.new(0, UI._pillW, 0, ISL_H) }, 0.5, Enum.EasingStyle.Back)
end
function setPillText(text)
    if text == pillText.Text and pillSeq == 0 then return end
    if text == pillText:GetAttribute("Next") then return end
    pillSeq = pillSeq + 1
    local my = pillSeq
    pillText:SetAttribute("Next", text)
    Tween(pillText, { TextTransparency = 1, Position = UDim2.new(0, 42, 0, -6) }, 0.12)
    task.delay(0.12, function()
        if my ~= pillSeq then return end
        pillText.Text = text
        pillText:SetAttribute("Next", nil)
        fitPill(text)
        pillText.Position = UDim2.new(0, 42, 0, 6)
        Tween(pillText, { TextTransparency = 0, Position = UDim2.new(0, 42, 0, 0) }, 0.3, Enum.EasingStyle.Quint)
        pillSeq = 0
    end)
end
local pillBars = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.new(0, 20, 0, 14), BackgroundTransparency = 1, Parent = pill })
HList(pillBars, 2, Enum.VerticalAlignment.Bottom)
local pillBarList = {}
for _, h in ipairs({ 5, 7, 10, 13 }) do
    local bar = New("Frame", { Size = UDim2.new(0, 3, 0, h), BackgroundColor3 = T.Text, BorderSizePixel = 0, Parent = pillBars })
    Corner(bar, 1); bar:SetAttribute("H", h); pillBarList[#pillBarList + 1] = bar
end

-- hover card: rows that rise in one after another when it opens; numbers count and bars fill from zero
local sheen = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    Visible = false, ZIndex = 60, Parent = island })
Corner(sheen, 24)
do
    local g = New("UIGradient", { Rotation = 20, Offset = Vector2.new(-1, 0), Parent = sheen,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1),
            NumberSequenceKeypoint.new(0.5, 0.93), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) })
    TweenService:Create(g, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 3.5), { Offset = Vector2.new(1, 0) }):Play()
end
islCard = New("CanvasGroup", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    GroupTransparency = 1, Visible = false, ZIndex = 61, Parent = island })
Padding(islCard, 18, 18, 16, 14)
local islRows = {}
local function islRow(y, h)
    local r = New("CanvasGroup", { Position = UDim2.new(0, 0, 0, y), Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, Parent = islCard })
    islRows[#islRows + 1] = { f = r, y = y }
    return r
end
local function dimHex()
    local c = T.TextDim
    return ("rgb(%d,%d,%d)"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- header: avatar with an accent ring and a breathing online dot, name, session time
local head = islRow(0, 48)
local avWrap = New("Frame", { Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 46, 0, 46), BackgroundTransparency = 1, Parent = head })
islAvatar = New("ImageLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
    Image = "", ScaleType = Enum.ScaleType.Crop, Parent = avWrap })
Corner(islAvatar, 12)
local avStroke = Stroke(islAvatar, T.Accent, 1.5)
avStroke.Transparency = 0.35
task.spawn(pcall, function()
    islAvatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
end)
local avScale = New("UIScale", { Scale = 1, Parent = avWrap })
local onDot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -3, 1, -3), Size = UDim2.new(0, 10, 0, 10),
    BackgroundColor3 = T.Success, BorderSizePixel = 0, ZIndex = 3, Parent = avWrap })
Corner(onDot, 5); Stroke(onDot, T.BgDeep, 2)
do
    local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Success, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = onDot })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    TweenService:Create(ring, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1),
        { Size = UDim2.new(2.6, 0, 2.6, 0), BackgroundTransparency = 1 }):Play()
end
islName = New("TextLabel", { Position = UDim2.new(0, 60, 0, 5), Size = UDim2.new(1, -180, 0, 20), BackgroundTransparency = 1,
    Text = shownName(), TextColor3 = T.Text, FontFace = F.Bold, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = head })
islHandle = New("TextLabel", { Position = UDim2.new(0, 60, 0, 27), Size = UDim2.new(1, -180, 0, 14), BackgroundTransparency = 1,
    Text = shownHandle(), TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = head })
local islSession = New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 5), Size = UDim2.new(0, 110, 0, 20),
    BackgroundTransparency = 1, Text = "0s", TextColor3 = T.Text, FontFace = F.Bold, TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Right, Parent = head })
local sessCap = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 27), Size = UDim2.new(0, 110, 0, 14),
    BackgroundTransparency = 1, Parent = head })
local sessList = HList(sessCap, 5)
sessList.HorizontalAlignment = Enum.HorizontalAlignment.Right
local sessIc = MakeIcon(sessCap, "clock", 10, T.TextDim); sessIc.LayoutOrder = 1
New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = "session",
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 10, LayoutOrder = 2, Parent = sessCap })

-- a hairline that fades out at both ends
local div = islRow(58, 1)
do
    local line = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = T.Border, BorderSizePixel = 0, Parent = div })
    UI._islLine = line
    New("UIGradient", { Parent = line, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) }) })
end

-- stats: the number counts toward the live value, the bar is a gradient with a soft glow at its end
local stats = islRow(68, 50)
local function islStat(x, name, unit)
    local col = New("Frame", { Position = UDim2.new(0, x, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), BackgroundTransparency = 1, Parent = stats })
    if x > 0 then col.Position = UDim2.new(0.5, 10, 0, 0) end
    local val = New("TextLabel", { Size = UDim2.new(0, 100, 0, 26), BackgroundTransparency = 1, Text = "-", RichText = true,
        TextColor3 = T.Text, FontFace = F.Bold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Parent = col })
    New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 8), Size = UDim2.new(0, 70, 0, 14),
        BackgroundTransparency = 1, Text = name, TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = col })
    local track = New("Frame", { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, Parent = col })
    Corner(track, 3)
    local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.Success, BorderSizePixel = 0, Parent = track })
    Corner(fill, 3)
    New("UIGradient", { Parent = fill, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }) })
    local glow = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 11, 0, 11),
        BackgroundColor3 = T.Success, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = fill })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
    local num = New("NumberValue", { Value = 0, Parent = col })
    num.Changed:Connect(function(v)
        val.Text = ('%d <font color="%s" size="12">%s</font>'):format(math.floor(v + 0.5), dimHex(), unit)
    end)
    local s = { num = num, fill = fill, glow = glow }
    function s.set(v, frac, color, dur)
        Tween(num, { Value = v }, dur or 0.4, Enum.EasingStyle.Quad)
        Tween(fill, { Size = UDim2.new(frac, 0, 1, 0), BackgroundColor3 = color }, dur or 0.4, Enum.EasingStyle.Quint)
        Tween(glow, { BackgroundColor3 = color }, dur or 0.4)
    end
    function s.reset() num.Value = 0; fill.Size = UDim2.new(0, 0, 1, 0) end
    return s
end
local islFps = islStat(0, "FRAME RATE", "fps")
local islPing = islStat(1, "PING", "ms")

-- chips: icon, label, value; "Running" turns accent while something runs
local chipsRow = islRow(128, 26)
HList(chipsRow, 8)
local function islChip(label, iconName, order)
    local c = New("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 26), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, LayoutOrder = order, Parent = chipsRow })
    Corner(c, 13); Padding(c, 10, 11, 0, 0); HList(c, 6)
    local st = Stroke(c, T.BorderLow, 1)
    UI._islChipScales = UI._islChipScales or {}
    UI._islChipScales[order] = New("UIScale", { Scale = 1, Parent = c })
    local ic = MakeIcon(c, iconName, 12, T.TextDim); ic.LayoutOrder = 1
    New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, LayoutOrder = 2, Parent = c })
    local v = New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1,
        Text = "-", TextColor3 = T.Text, FontFace = F.Bold, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 3, Parent = c })
    return v, st
end
local islPlayers = islChip("Players", "users", 1)
local islRunning, runStroke = islChip("Running", "activity", 2)
local islTab = islChip("Tab", "layout-dashboard", 3)
islTab.AutomaticSize = Enum.AutomaticSize.None
local tabW = New("UISizeConstraint", { MaxSize = Vector2.new(96, 26), Parent = islTab })
islTab:GetPropertyChangedSignal("Text"):Connect(function()
    local w = game:GetService("TextService"):GetTextSize(islTab.Text, 11, Enum.Font.GothamBold, Vector2.new(1000, 26)).X
    islTab.Size = UDim2.new(0, math.min(w + 2, tabW.MaxSize.X), 1, 0)
end)

-- status: a dot that breathes while features run
local statusRow = islRow(166, 16)
local stDot = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 1, 0.5, 0), Size = UDim2.new(0, 6, 0, 6),
    BackgroundColor3 = T.TextMute, BorderSizePixel = 0, Parent = statusRow })
New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = stDot })
local stPulse = TweenService:Create(stDot, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.7 })
local islStatus = New("TextLabel", { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -14, 1, 0), BackgroundTransparency = 1,
    Text = "Nothing running", TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = statusRow })

-- footer: "Click or press [key] to open". islHint keeps the sentence other code writes; the keycap shows its key.
local foot = islRow(188, 18)
HList(foot, 5)
islHint = New("TextLabel", { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Text = "Click or press RCtrl to open",
    TextTransparency = 1, Visible = false, Parent = islCard })
local function footText(t, order)
    return New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = t,
        TextColor3 = T.TextMute, FontFace = F.Regular, TextSize = 10, LayoutOrder = order, Parent = foot })
end
footText("Click or press", 1)
local keycap = New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 18), BackgroundColor3 = T.CardAlt,
    BorderSizePixel = 0, Text = "RCtrl", TextColor3 = T.Text, FontFace = F.Medium, TextSize = 10, LayoutOrder = 2, Parent = foot })
Corner(keycap, 5); Padding(keycap, 6, 6, 0, 0)
do
    local kStroke = Stroke(keycap, T.Border, 1)
    local kScale = New("UIScale", { Scale = 1, Parent = keycap })
    task.spawn(function()
        while gui.Parent do
            task.wait(2.8)
            if islandExpanded then
                Tween(kScale, { Scale = 0.88 }, 0.08, Enum.EasingStyle.Quad)
                Tween(kStroke, { Color = T.Accent }, 0.08); Tween(keycap, { BackgroundColor3 = T.CardHover }, 0.08)
                task.wait(0.12)
                Tween(kScale, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
                Tween(kStroke, { Color = T.Border }, 0.4); Tween(keycap, { BackgroundColor3 = T.CardAlt }, 0.4)
            end
        end
    end)
end
footText("to open  ·  hold to move", 3)
local function syncHint() keycap.Text = islHint.Text:match("press (.-) to open") or "?" end
islHint:GetPropertyChangedSignal("Text"):Connect(syncHint)
syncHint()

local islandHit = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    ZIndex = 70, Parent = island })

function pingColor(p) return p <= 100 and T.Success or (p <= 200 and T.Warning or T.Error) end
function fpsColor(f) return f >= 50 and T.Success or (f >= 30 and T.Warning or T.Error) end
function updateIslandBars()
    local lit = livePing <= 0 and 4 or (livePing <= 90 and 4 or (livePing <= 150 and 3 or (livePing <= 250 and 2 or 1)))
    for i, bar in ipairs(pillBarList) do
        local lit_c = livePing > 400 and T.Error or (livePing > 220 and T.Warning or T.Text)
        Tween(bar, { BackgroundColor3 = (i <= lit) and lit_c or T.CardHover }, 0.25)
    end
end
local wasRunning = nil
function updateIslandCard(dur)
    islName.Text = shownName(); islHandle.Text = shownHandle()
    islSession.Text = sessionText()
    islFps.set(liveFps, math.clamp(liveFps / 60, 0.04, 1), fpsColor(liveFps), dur)
    islPing.set(livePing, math.clamp(1 - livePing / 300, 0.04, 1), pingColor(livePing), dur)
    islPlayers.Text = ("%d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers)
    local act = activeFeatures()
    islRunning.Text = tostring(#act)
    islTab.Text = currentTabTitle()
    local running = #act > 0
    if running then
        local shown = {}
        for i = 1, math.min(3, #act) do shown[i] = act[i] end
        islStatus.Text = "Running " .. table.concat(shown, "  ·  ") .. (#act > 3 and ("  +" .. (#act - 3)) or "")
    else
        islStatus.Text = "Nothing running"
    end
    if running ~= wasRunning then
        wasRunning = running
        Tween(runStroke, { Color = running and T.Accent or T.BorderLow }, 0.25)
        Tween(islRunning, { TextColor3 = running and T.Accent or T.Text }, 0.25)
        Tween(stDot, { BackgroundColor3 = running and T.Success or T.TextMute }, 0.25)
        Tween(islStatus, { TextColor3 = running and T.Text or T.TextDim }, 0.25)
        if running then stPulse:Play() else stPulse:Cancel(); stDot.BackgroundTransparency = 0 end
    end
end

function setIslandExpanded(on)
    if on == islandExpanded then return end
    islandExpanded = on
    if on then
        -- numbers and bars start from zero, rows wait below their spot, the avatar starts small
        islFps.reset(); islPing.reset()
        for _, r in ipairs(islRows) do r.f.Position = UDim2.new(0, 0, 0, r.y + 12); r.f.GroupTransparency = 1 end
        avScale.Scale = 0.6
        updateIslandCard(0.9)
        islCard.Visible = true
        Tween(island, { Size = UDim2.new(0, ISL_BW + 10, 0, ISL_BH + 8) }, 0.32, Enum.EasingStyle.Quint)
        task.delay(0.32, function() if islandExpanded then Tween(island, { Size = UDim2.new(0, ISL_BW, 0, ISL_BH) }, 0.4, Enum.EasingStyle.Sine) end end)
        Tween(islandCorner, { CornerRadius = UDim.new(0, 24) }, 0.5, Enum.EasingStyle.Quint)
        Tween(pill, { GroupTransparency = 1 }, 0.14)
        local ist = island:FindFirstChildOfClass("UIStroke")
        if ist then
            Tween(ist, { Color = T.Accent }, 0.2)
            task.delay(0.3, function() Tween(ist, { Color = T.Border }, 0.7) end)
        end
        UI._islLine.Size = UDim2.new(0, 0, 1, 0)
        for _, sc in pairs(UI._islChipScales or {}) do sc.Scale = 0.75 end
        task.delay(0.5, function() if islandExpanded then sheen.Visible = true end end)
        task.delay(0.1, function()
            if not islandExpanded then return end
            Tween(islCard, { GroupTransparency = 0 }, 0.2)
            task.delay(0.12, function() Tween(UI._islLine, { Size = UDim2.new(1, 0, 1, 0) }, 0.6, Enum.EasingStyle.Quint) end)
            for i, sc in pairs(UI._islChipScales or {}) do
                task.delay(0.2 + i * 0.06, function() if islandExpanded then Tween(sc, { Scale = 1 }, 0.45, Enum.EasingStyle.Back) end end)
            end
            Tween(avScale, { Scale = 1 }, 0.55, Enum.EasingStyle.Back)
            for i, r in ipairs(islRows) do
                task.delay((i - 1) * 0.045, function()
                    if not islandExpanded then return end
                    Tween(r.f, { Position = UDim2.new(0, 0, 0, r.y), GroupTransparency = 0 }, 0.45, Enum.EasingStyle.Quint)
                end)
            end
        end)
    else
        sheen.Visible = false
        Tween(islCard, { GroupTransparency = 1 }, 0.12)
        Tween(island, { Size = UDim2.new(0, UI._pillW - 16, 0, ISL_H - 4) }, 0.3, Enum.EasingStyle.Quint)
        task.delay(0.3, function() if not islandExpanded then Tween(island, { Size = UDim2.new(0, UI._pillW, 0, ISL_H) }, 0.45, Enum.EasingStyle.Back) end end)
        Tween(islandCorner, { CornerRadius = UDim.new(0, ISL_H / 2) }, 0.38, Enum.EasingStyle.Quint)
        task.delay(0.14, function() if not islandExpanded then Tween(pill, { GroupTransparency = 0 }, 0.24) end end)
        task.delay(0.22, function() if not islandExpanded then islCard.Visible = false end end)
    end
end
function showIsland()
    if Config.island == "Hidden" or islandShown then return end
    islandShown = true
    islandExpanded = false
    island.Visible = true
    pillText.Text = UI._customIsl or (BRAND .. " · " .. currentTabTitle())
    UI._pillW = pillWidth(pillText.Text)
    island.Size = UDim2.new(0, UI._pillW, 0, ISL_H)
    islandCorner.CornerRadius = UDim.new(0, ISL_H / 2)
    pill.GroupTransparency = 0; islCard.Visible = false; islCard.GroupTransparency = 1
    island.Position = UDim2.new(Config.islandX or 0.5, 0, 0, -80)
    Tween(island, { Position = UDim2.new(Config.islandX or 0.5, 0, 0, Config.islandY or 12) }, 0.55, Enum.EasingStyle.Back)
    for i, bar in ipairs(pillBarList) do
        bar.Size = UDim2.new(0, 3, 0, 2)
        task.delay(0.3 + i * 0.07, function() Tween(bar, { Size = UDim2.new(0, 3, 0, bar:GetAttribute("H") or 10) }, 0.4, Enum.EasingStyle.Back) end)
    end
    if UI._pillTick then UI._pillTick() end
end
function hideIsland()
    if not islandShown then return end
    islandShown = false; islandHovering = false
    Tween(island, { Position = UDim2.new(island.Position.X.Scale, 0, 0, -ISL_BH - 30) }, 0.32, Enum.EasingStyle.Quint)
    task.delay(0.34, function() if not islandShown then island.Visible = false; islandExpanded = false end end)
end
local islDragging, islMoved, islFrom, islStartAbs = false, false, nil, nil
local islPress = 0          -- counts presses, so a hold timer from an old press does nothing
local HOLD = 0.2            -- held this long: the press moves the pill instead of opening the window
local islStroke = island:FindFirstChildOfClass("UIStroke")
islandHit.MouseEnter:Connect(function()
    islandHovering = true
    if islDragging then return end
    if Config.island == "Show on Hover" then setIslandExpanded(true) end
end)
islandHit.MouseLeave:Connect(function()
    islandHovering = false
    task.delay(0.2, function() if not islandHovering and not islDragging then setIslandExpanded(false) end end)
end)
-- move mode: the pill folds back to its small size and its outline lights up while it follows the pointer
local function grab()
    if islMoved then return end
    islMoved = true
    setIslandExpanded(false)
    if islStroke then Tween(islStroke, { Color = T.Accent, Thickness = 2 }, 0.15) end
end
local function letGo()
    if islStroke then Tween(islStroke, { Color = T.Border, Thickness = 1 }, 0.25) end
end
-- a quick click opens the window; holding (or dragging right away) moves the pill instead, and the spot is
-- remembered
islandHit.InputBegan:Connect(function(input)
    if not islandShown or not island.Visible then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local p, s = island.AbsolutePosition, island.AbsoluteSize
        local ip = input.Position
        if ip.X < p.X or ip.X > p.X + s.X or ip.Y < p.Y or ip.Y > p.Y + s.Y + 36 then return end
        islDragging = true; islMoved = false; islFrom = input.Position
        islPress = islPress + 1
        local my = islPress
        local vp = gui.AbsoluteSize
        islStartAbs = Vector2.new(island.Position.X.Scale * vp.X + island.Position.X.Offset, island.Position.Y.Offset)
        task.delay(HOLD, function() if islDragging and islPress == my then grab() end end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End and islDragging and islPress == my then
                islDragging = false
                if not islMoved then
                    local q = input.Position
                    local p, s = island.AbsolutePosition, island.AbsoluteSize
                    if islandShown and q.X >= p.X and q.X <= p.X + s.X and q.Y >= p.Y and q.Y <= p.Y + s.Y + 36 and openWindow then openWindow() end
                else
                    letGo()
                    Config.islandX = island.Position.X.Scale; Config.islandY = island.Position.Y.Offset
                    SaveConfig()
                end
            end
        end)
    end
end)
Track(UserInputService.InputChanged:Connect(function(input)
    if islDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - islFrom
        if not islMoved and d.Magnitude > 5 then grab() end
        if islMoved then
            local vp = gui.AbsoluteSize
            local halfW = (islandExpanded and ISL_BW or UI._pillW) / 2 + 6
            local x = math.clamp(islStartAbs.X + d.X, halfW, math.max(halfW, vp.X - halfW))
            local y = math.clamp(islStartAbs.Y + d.Y, 4, math.max(4, vp.Y - ISL_H - 4))
            island.Position = UDim2.new(x / vp.X, 0, 0, y)
        end
    end
end))

end)()

-- ============================================================================
-- OVERLAY LAYER  (dropdown lists live here)
-- In Sibling ZIndex mode a list parented inside its row renders UNDER every row below it.
-- Parenting it to a top-level layer and positioning it by AbsolutePosition fixes that.
-- ============================================================================
local overlay = New("Frame", {
    Name = "Overlay", Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1, ZIndex = 100, Parent = window,
})
local dropCatcher = New("TextButton", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
    AutoButtonColor = false, Visible = false, ZIndex = 1, Parent = overlay,
})
local currentDrop = nil
local function closeOpenDrop()
    if currentDrop then currentDrop.close() end
end
dropCatcher.MouseButton1Click:Connect(closeOpenDrop)
-- the same thing at screen level, for dropdowns in a card popped out of the window (the overlay above hides with it)
local floatOverlay = New("Frame", { Name = "FloatOverlay", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    ZIndex = 110, Parent = gui })
local floatScale = New("UIScale", { Scale = 1, Parent = floatOverlay })
local floatCatcher = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
    AutoButtonColor = false, Visible = false, ZIndex = 1, Parent = floatOverlay })
floatCatcher.MouseButton1Click:Connect(closeOpenDrop)

-- ============================================================================
-- OPEN / CLOSE the window, and every appearance setting that acts on it
-- ============================================================================
local windowOpen = false
local booting = true
local function targetWindowBG() return Config.transparent and 0.22 or 0 end
local function panelTarget()
    if window:GetAttribute("HasBgImage") then return 0.45 end
    return Config.transparent and 0.3 or 0
end
local function computeScale()
    local s = (Config.uiScale or 100) / 100
    if Config.adaptive then
        local vp = gui.AbsoluteSize
        if vp.X > 0 and vp.Y > 0 then
            s = s * math.min(1, (vp.X - 24) / window.Size.X.Offset, (vp.Y - 24) / window.Size.Y.Offset)
        end
    end
    return math.max(0.35, s)
end

;(function()
-- background picture behind the pages
local bgImage = New("ImageLabel", { Name = "Background", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    Image = "", ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, ZIndex = 0, Parent = window })
-- weather: falling particles, either over the whole screen or inside the window
local weatherLayer = New("Frame", { Name = "Weather", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true, Visible = false, ZIndex = 2, Parent = gui })
local particles = {}
local weatherKind = "None"
local function clearParticles()
    for _, p in ipairs(particles) do pcall(function() p.f:Destroy() end) end
    particles = {}
end
local function buildParticles(kind)
    clearParticles()
    if kind == "None" then return end
    local n = (kind == "Snow") and 46 or 64
    for _ = 1, n do
        local f = New("Frame", { BorderSizePixel = 0, Parent = weatherLayer })
        if kind == "Snow" then
            local sz = math.random(2, 5)
            f.Size = UDim2.fromOffset(sz, sz); f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            f.BackgroundTransparency = math.random(25, 60) / 100
            Corner(f, sz)
        else
            f.Size = UDim2.fromOffset(1, math.random(10, 18)); f.BackgroundColor3 = Color3.fromRGB(190, 212, 242)
            f.BackgroundTransparency = math.random(45, 70) / 100; f.Rotation = 12
        end
        particles[#particles + 1] = { f = f, x = math.random(), y = math.random(),
            speed = (kind == "Snow") and (0.05 + math.random() * 0.07) or (0.55 + math.random() * 0.35),
            sway = 0.6 + math.random() * 1.2, phase = math.random() * 6.28 }
    end
end
Track(RunService.RenderStepped:Connect(function(dt)
    if weatherKind == "None" or not weatherLayer.Visible then return end
    local t = os.clock()
    for _, p in ipairs(particles) do
        p.y = p.y + p.speed * dt
        if p.y > 1.05 then p.y = -0.05; p.x = math.random() end
        local x = p.x
        if weatherKind == "Snow" then x = x + math.sin(t * p.sway + p.phase) * 0.012 else x = x - p.y * 0.05 end
        p.f.Position = UDim2.new(x, 0, p.y, 0)
    end
end))

function Apply.weather()
    if not gui.Parent then return end   -- this instance was already unloaded (a re-run destroyed its gui)
    local kind = Config.weather or "None"
    if kind ~= weatherKind then weatherKind = kind; buildParticles(kind) end
    if Config.weatherMode == "Window" then
        weatherLayer.Parent = window; weatherLayer.ZIndex = 40
    else
        weatherLayer.Parent = gui; weatherLayer.ZIndex = 2
    end
    weatherLayer.Visible = (kind ~= "None") and windowOpen
end
function Apply.scale()
    if windowOpen then Tween(windowScale, { Scale = computeScale() }, 0.2, Enum.EasingStyle.Quint) end
end
function Apply.dim()
    if windowOpen and Config.dim then
        dim.Visible = true; Tween(dim, { BackgroundTransparency = 0.55 }, 0.3)
    else
        Tween(dim, { BackgroundTransparency = 1 }, 0.25)
        task.delay(0.27, function() if not (windowOpen and Config.dim) then dim.Visible = false end end)
    end
end
-- the game behind the open window is blurred (a BlurEffect in Lighting, made on first use, gone on unload)
function Apply.blur()
    local want = windowOpen and Config.blur and true or false
    local fx = UI._blur
    if want and not (fx and fx.Parent) then
        local ok, made = pcall(function()
            local b = Instance.new("BlurEffect")
            b.Name = PFX .. "Blur"; b.Size = 0
            b.Parent = game:GetService("Lighting")
            return b
        end)
        if not ok then return end
        fx = made; UI._blur = made
    end
    if not (fx and fx.Parent) then return end
    Tween(fx, { Size = want and 14 or 0 }, want and 0.45 or 0.25, Enum.EasingStyle.Quad)
end
UI._cleanups[#UI._cleanups + 1] = function() if UI._blur then pcall(function() UI._blur:Destroy() end) end end
function Apply.transparent()
    if windowOpen then
        window.BackgroundTransparency = targetWindowBG()
        for _, p in ipairs(bgParts) do p.BackgroundTransparency = panelTarget() end    end
end
function Apply.background()
    local mode, ref = Config.bgMode, tostring(Config.bgImage or "")
    if mode ~= "Image" or ref == "" then
        bgImage.Image = ""; bgImage.ImageTransparency = 1
        window:SetAttribute("HasBgImage", false)
        Apply.transparent()
        return
    end
    local function show(url)
        bgImage.Image = url
        window:SetAttribute("HasBgImage", true)
        bgImage.ImageTransparency = 1 - math.clamp((Config.bgOpacity or 65) / 100, 0.05, 1)
        Apply.transparent()
    end
    local num = ref:match("^%d+$") or ref:match("rbxassetid://(%d+)") or ref:match("rbxthumb.-id=(%d+)")
    if num then
        show("rbxassetid://" .. num)
    elseif ref:match("^https?://") and type(getcustomasset) == "function" and type(writefile) == "function" then
        task.spawn(function()
            local ok, data = pcall(function() return game:HttpGet(ref) end)
            if ok and type(data) == "string" and #data > 100 then
                pcall(function()
                    if not isfolder("Okuma") then makefolder("Okuma") end
                    writefile("Okuma/background.img", data)
                    show(getcustomasset("Okuma/background.img"))
                end)
            end
        end)
    end
end
function Apply.opacity()
    if bgImage.Image ~= "" then bgImage.ImageTransparency = 1 - math.clamp((Config.bgOpacity or 65) / 100, 0.05, 1) end
end
-- every corner on screen (window, popped-out cards, toasts, tooltip), or just the ones under root (a new toast).
-- The island is left out: it animates its own corner between pill and card.
function Apply.radius(root)
    local f = (Config.cornerRadius or 10) / 10
    local winSc = math.max(windowScale.Scale, 0.01)
    local list = (root or gui):GetDescendants()
    if root then list[#list + 1] = root end
    for _, d in ipairs(list) do
        if d:IsA("UICorner") and d.CornerRadius.Scale == 0 and not d:IsDescendantOf(island) then   -- proportional corners (circles, silhouettes) stay as they are
            local base = d:GetAttribute("BaseR")
            if base == nil then base = d.CornerRadius.Offset; d:SetAttribute("BaseR", base) end
            local p = d.Parent
            local circle, known = false, true
            if p and p:IsA("GuiObject") then
                -- sizes are compared unscaled: inside the window divide by its scale, toasts are not scaled
                local s = p.AbsoluteSize / (p:IsDescendantOf(window) and winSc or 1)
                if s.X > 0 and s.Y > 0 then circle = base * 2 >= math.min(s.X, s.Y) - 1 else known = false end
            end
            if known and not circle then d.CornerRadius = UDim.new(0, math.floor(base * f + 0.5)) end
        end
    end
end
function Apply.density()
    local f = ({ Compact = 0.7, Default = 1, Comfortable = 1.3 })[Config.density] or 1
    for _, d in ipairs(body:GetDescendants()) do
        if d:IsA("UIListLayout") then
            local base = d:GetAttribute("BasePad")
            if base == nil then base = d.Padding.Offset; d:SetAttribute("BasePad", base) end
            d.Padding = UDim.new(0, math.floor(base * f + 0.5))
        end
    end
end
function Apply.render3d()
    pcall(function() RunService:Set3dRenderingEnabled(not Config.disable3d) end)
end
function Apply.island()
    if Config.island == "Hidden" then
        hideIsland()
    elseif not windowOpen and not booting then
        showIsland()
    end
    if Config.island ~= "Show on Hover" and islandExpanded then setIslandExpanded(false) end
end
local floatBtn = New("TextButton", { Name = "FloatToggle", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0),
    Size = UDim2.new(0, 46, 0, 46), BackgroundColor3 = T.BgDeep, Text = "", AutoButtonColor = false, Visible = false,
    ZIndex = 65, Parent = gui })
Corner(floatBtn, 23); Stroke(floatBtn, T.Border, 1)
do
    local ic = MakeIcon(floatBtn, "logo", 40, T.Text); Corner(ic, 20)
    ic.AnchorPoint = Vector2.new(0.5, 0.5); ic.Position = UDim2.new(0.5, 0, 0.5, 0)
end
function Apply.toggleButton()
    local mode = Config.toggleButton
    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    floatBtn.Visible = (mode == "Always") or (mode == "Mobile only" and mobile)
end

-- live theme: every colour that matches an old palette entry is swapped for the new one
function Apply.theme(spec)
    local old = {}
    for _, k in ipairs(DERIVED_KEYS) do old[k] = T[k] end
    local new = derive(spec)
    local function id(c) return math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5) end
    local map = {}
    for _, k in ipairs(DERIVED_KEYS) do map[id(old[k])] = new[k] end
    for k, v in pairs(new) do T[k] = v end
    local function remap(c) return map[id(c)] end
    for i, d in ipairs(gui:GetDescendants()) do
        if d:IsA("GuiObject") then
            local n = remap(d.BackgroundColor3); if n then d.BackgroundColor3 = n end
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local t = remap(d.TextColor3); if t then d.TextColor3 = t end
                if d:IsA("TextBox") then local p = remap(d.PlaceholderColor3); if p then d.PlaceholderColor3 = p end end
            elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
                local m = remap(d.ImageColor3); if m then d.ImageColor3 = m end
            elseif d:IsA("ScrollingFrame") then
                local s = remap(d.ScrollBarImageColor3); if s then d.ScrollBarImageColor3 = s end
            end
        elseif d:IsA("UIStroke") then
            local n = remap(d.Color); if n then d.Color = n end
        end
        if i % 1500 == 0 then task.wait() end
    end
    if UI._paintBorder then UI._paintBorder() end
    for _, fn in ipairs(UI._onTheme or {}) do pcall(fn) end
end

function Apply.all()
    Apply.scale(); Apply.radius(); Apply.density(); Apply.background(); Apply.transparent()
    Apply.weather(); Apply.dim(); Apply.blur(); Apply.render3d(); Apply.island(); Apply.toggleButton()
end

floatBtn.MouseButton1Click:Connect(function() toggleWindow() end)
end)()

-- the cards of a page come in one after another: each one's content rises 10 px while it fades in (the padding
-- moves from bottom to top and back, so the card's height never changes and nothing below it jumps)
function UI._staggerCards(frame)
    local k = 0
    for _, cd in ipairs(UI._cards or {}) do
        if cd.c:IsDescendantOf(frame) and not cd.closed() then
            k = k + 1
            local my = (cd.seq or 0) + 1
            cd.seq = my
            if cd.body then cd.body.GroupTransparency = 1 end
            cd.pad.PaddingTop = UDim.new(0, cd.top + 10); cd.pad.PaddingBottom = UDim.new(0, cd.bot - 10)
            task.delay(math.min(k, 8) * 0.05, function()
                if cd.seq ~= my then return end
                if cd.closed() then cd.pad.PaddingTop = UDim.new(0, cd.top); cd.pad.PaddingBottom = UDim.new(0, cd.bot); return end
                if cd.body then Tween(cd.body, { GroupTransparency = 0 }, 0.3, Enum.EasingStyle.Quad) end
                Tween(cd.pad, { PaddingTop = UDim.new(0, cd.top), PaddingBottom = UDim.new(0, cd.bot) }, 0.5, Enum.EasingStyle.Quint)
            end)
        end
    end
end

openWindow = function()
    if windowOpen then return end
    windowOpen = true
    hideIsland()
    closeOpenDrop()
    local s = computeScale()
    -- grows and rises into place: where it was last dragged to, kept on screen (or the middle)
    local wx, wy = tonumber(Config.winX) or 0, tonumber(Config.winY) or 0
    local vp = gui.AbsoluteSize
    if vp.X > 0 and vp.Y > 0 then
        local hx, hy = math.max(0, vp.X / 2 - 120), math.max(0, vp.Y / 2 - 80)
        wx, wy = math.clamp(wx, -hx, hx), math.clamp(wy, -hy, hy)
    end
    window.Position = UDim2.new(0.5, wx, 0.5, wy + 22)
    TweenService:Create(window, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, wx, 0.5, wy) }):Play()
    windowScale.Scale = s * 0.92
    window.BackgroundTransparency = 1; windowStroke.Transparency = 1
    sidebar.GroupTransparency = 1; content.GroupTransparency = 1
    for _, p in ipairs(bgParts) do p.BackgroundTransparency = 1 end
    window.Visible = true
    for _, p in ipairs(bgParts) do
        TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { BackgroundTransparency = panelTarget() }):Play()
    end
    TweenService:Create(windowScale, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = s }):Play()
    TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { BackgroundTransparency = targetWindowBG() }):Play()
    TweenService:Create(windowStroke, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
    TweenService:Create(sidebar, TweenInfo.new(0.36, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play()
    task.delay(0.07, function()
        if windowOpen then TweenService:Create(content, TweenInfo.new(0.36, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play() end
    end)
    -- the sidebar entries slide in from the left one after another, and the open page's cards rise in
    local navs = {}
    for _, r in pairs(navRefs) do if r.button.Visible then navs[#navs + 1] = r end end
    table.sort(navs, function(a, b) return a.button.LayoutOrder < b.button.LayoutOrder end)
    for k, r in ipairs(navs) do
        r.labelObj.Position = UDim2.new(0, 56, 0, 0); r.labelObj.TextTransparency = 1
        task.delay(0.06 + k * 0.035, function()
            if windowOpen then Tween(r.labelObj, { Position = UDim2.new(0, 42, 0, 0), TextTransparency = 0 }, 0.45, Enum.EasingStyle.Quint)
            else r.labelObj.Position = UDim2.new(0, 42, 0, 0); r.labelObj.TextTransparency = 0 end
        end)
    end
    local pg = activePageId and pages[activePageId]
    if pg then UI._staggerCards(pg.frame) end
    Apply.dim(); Apply.blur(); Apply.weather()
    if (Config.cornerRadius or 10) ~= 10 then task.delay(0.15, Apply.radius) end
end
closeWindow = function()
    if not windowOpen then return end
    windowOpen = false
    closeOpenDrop()
    local s = windowScale.Scale
    local p = window.Position
    TweenService:Create(windowScale, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Scale = s * 0.94 }):Play()
    TweenService:Create(window, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
        { Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + 12) }):Play()
    TweenService:Create(sidebar, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { GroupTransparency = 1 }):Play()
    TweenService:Create(content, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { GroupTransparency = 1 }):Play()
    TweenService:Create(window, TweenInfo.new(0.26, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(windowStroke, TweenInfo.new(0.26, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
    for _, p in ipairs(bgParts) do
        TweenService:Create(p, TweenInfo.new(0.26, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
    end
    Apply.dim(); Apply.blur(); Apply.weather()
    task.delay(0.3, function()
        if not windowOpen then
            window.Visible = false
            if Config.island ~= "Hidden" then showIsland() end
        end
    end)
end
toggleWindow = function() if windowOpen then closeWindow() else openWindow() end end
local function setMinimized(state) if state then closeWindow() else openWindow() end end
minBtn.MouseButton1Click:Connect(closeWindow)
Track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() Apply.scale() end))

-- ============================================================================
-- PAGES  (with fade transition)
-- ============================================================================
local function MakePage(id, title, iconName)
    -- a plain Frame: a CanvasGroup this tall is rendered through a size-limited texture and looks low resolution
    local frame = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = body,
    })
    VList(frame, 14)
    -- top padding the page switch animates (the page rises into place); 0 at rest, so nothing moves
    local pad = Padding(frame, 0, 0, 0, 0)
    pages[id] = { frame = frame, title = title, iconName = iconName, pad = pad }
    return frame
end

-- close any open dropdown when the page scrolls
body:GetPropertyChangedSignal("CanvasPosition"):Connect(function() closeOpenDrop() end)

local pageSwitchDebounce = false
UI._selectPage = function(id)
    if pageSwitchDebounce then return end
    local newPage = pages[id]
    if not newPage then return end
    if activePageId == id then return end
    pageSwitchDebounce = true
    -- the page you were on opens first next run
    if not booting and Config.lastPage ~= id then Config.lastPage = id; SaveConfig() end

    local oldPage = activePageId and pages[activePageId] or nil

    -- update nav visuals
    for pid, ref in pairs(navRefs) do
        local isActive = (pid == id)
        -- look the icon up live: it may have been swapped from a placeholder to a real ImageLabel
        local icon = ref.button:FindFirstChildWhichIsA("ImageLabel")
        local col = isActive and T.Text or T.TextDim
        -- the active background is navHL; a hover tint on the entry itself fades out
        Tween(ref.button, { BackgroundTransparency = 1 }, 0.18)
        Tween(ref.labelObj, { TextColor3 = col }, 0.24)
        if icon then Tween(icon, { ImageColor3 = isActive and T.Accent or T.TextDim }, 0.24) end
    end
    placeNavHL(id, true)

    -- update header: the title slides in from a few pixels right while it fades in
    headerTitle.Text = newPage.title
    headerTitle.TextTransparency = 1
    headerTitle.Position = UDim2.new(0, 44, 0, 0)
    Tween(headerTitle, { TextTransparency = 0, Position = UDim2.new(0, 36, 0, 0) }, 0.34, Enum.EasingStyle.Quint)
    if headerIcon and headerIcon.Parent then headerIcon:Destroy() end
    -- the new page icon pops in from small, turned a little
    headerIcon = MakeIcon(header, newPage.iconName, 24, T.Text)
    headerIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    headerIcon.Position = UDim2.new(0, 12, 0.5, 0)
    headerIcon.Size = UDim2.new(0, 10, 0, 10)
    headerIcon.Rotation = -25
    Tween(headerIcon, { Size = UDim2.new(0, 24, 0, 24), Rotation = 0 }, 0.45, Enum.EasingStyle.Back)

    -- fade + rise transition (one tween per page, never leaves the debounce stuck)
    closeOpenDrop()
    local ok, err = pcall(function()
        if oldPage then oldPage.frame.Visible = false end
        body.CanvasPosition = Vector2.new(0, 0)
        newPage.pad.PaddingTop = UDim.new(0, 14)
        newPage.frame.Visible = true
        TweenService:Create(newPage.pad, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            { PaddingTop = UDim.new(0, 0) }):Play()
        -- the open cards' contents come in one after another (headers are there at once); 8 cards at most wait
        UI._staggerCards(newPage.frame)
        task.wait(0.1)
    end)
    activePageId = id
    pageSwitchDebounce = false
end

-- ============================================================================
-- COMPONENTS
-- ============================================================================

local SearchIndex = {}
local function indexItem(label, inst)
    if label and label ~= "" and inst then SearchIndex[#SearchIndex + 1] = { label = tostring(label), inst = inst } end
end

-- every component callback goes through here: an error is logged in full and shown once as a toast
-- (a slider that errors on every drag step must not bury the screen in toasts)
local function safe(cb, ...)
    if not cb then return end
    local ok, err = pcall(cb, ...)
    if ok then return end
    UI.log("error", err)
    if os.clock() - (UI._guard.errToast or -99) > 2 then
        UI._guard.errToast = os.clock()
        Notify({ title = "Something went wrong", body = tostring(err):sub(1, 90), color = T.Error, icon = "x", duration = 5 })
    end
end

-- plain card: no header, children added directly
local function Card(parent)
    local c = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent,
    })
    Corner(c, 12); Stroke(c, T.BorderLow, 1); VList(c, 12)
    local pad = Padding(c, 20, 20, 18, 18)
    -- the page switch lets its content rise in with the others (a plain card has no body to fade)
    UI._cards = UI._cards or {}
    UI._cards[#UI._cards + 1] = { c = c, pad = pad, top = 18, bot = 18, closed = function() return false end }
    return c
end

-- Ouroboros-style card: title header with 2 action icons (folder + chevron) and separator
-- Returns the content body (children go here)
local function TitledCard(parent, title, iconName)
    local c = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card, BorderSizePixel = 0, Parent = parent,
    })
    Corner(c, 12); Stroke(c, T.BorderLow, 1); VList(c, 0)
    c.ClipsDescendants = true
    indexItem(title, c)

    local hdr = New("Frame", {
        Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = c,
    })
    hdr.BackgroundTransparency = 0
    hdr.BackgroundColor3 = T.CardHeader
    Padding(hdr, 18, 14, 0, 0)
    -- the header strip has its own background, and clipping in Roblox is rectangular: rounded like the card it
    -- covers the card's top corners properly. Its lower half is squared off again where it meets the body
    -- (hidden while the card is collapsed, so a header-only card is round all around). The patch is made
    -- before the header's icon and title so it draws under them, and reaches past the header's padding.
    Corner(hdr, 12)
    local hdrPatch = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, -18, 1, 0),
        Size = UDim2.new(1, 32, 0.5, 0), BackgroundColor3 = T.CardHeader, BorderSizePixel = 0, Parent = hdr })

    local titleIcon = MakeIcon(hdr, iconName or "overview", 16, T.TextDim)
    titleIcon.AnchorPoint = Vector2.new(0, 0.5)
    titleIcon.Position = UDim2.new(0, 0, 0.5, 0)

    New("TextLabel", {
        Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -96, 1, 0),
        BackgroundTransparency = 1, Text = title, TextColor3 = T.Text,
        FontFace = F.Bold, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Parent = hdr,
    })

    local actions = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 60, 0, 24), BackgroundTransparency = 1, Parent = hdr,
    })
    HList(actions, 4, Enum.VerticalAlignment.Center)

    local function tinyIconBtn(iconName)
        local b = New("TextButton", {
            Size = UDim2.new(0, 26, 0, 22), BackgroundTransparency = 1,
            BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = actions,
        })
        local ic = MakeIcon(b, iconName, 14, T.TextDim)
        ic.AnchorPoint = Vector2.new(0.5, 0.5)
        ic.Position = UDim2.new(0.5, 0, 0.5, 0)
        -- the icon can be swapped (placeholder -> Lucide) after creation, so look it up live
        local function currentIcon() return b:FindFirstChildWhichIsA("ImageLabel") end
        b.MouseEnter:Connect(function()
            local i = currentIcon(); if i then Tween(i, { ImageColor3 = T.Text }, 0.12) end
        end)
        b.MouseLeave:Connect(function()
            local i = currentIcon(); if i then Tween(i, { ImageColor3 = T.TextDim }, 0.12) end
        end)
        return b, ic
    end
    local folderBtn = tinyIconBtn("picture-in-picture-2")
    local chevronBtn, chevronIc = tinyIconBtn("chevron_down")

    -- the card's identity across runs (title + how many cards had that title before): its collapsed and
    -- popped-out state are saved under it
    UI._cardSeen = UI._cardSeen or {}
    UI._cardSeen[title] = (UI._cardSeen[title] or 0) + 1
    local cardKey = tostring(title) .. "#" .. UI._cardSeen[title]
    if type(Config.cardsClosed) ~= "table" then Config.cardsClosed = {} end
    if type(Config.cardsPopped) ~= "table" then Config.cardsPopped = {} end

    -- picture-in-picture: the card pops out of the window into a floating frame at the same spot, stays on screen
    -- while the window is closed and is dragged by its header; clicking again puts it back where it was.
    -- Where it floats is saved, so it comes back popped out in the same place next run.
    local popHost, popDrag, dockParent
    local function savePop()
        if popHost then
            Config.cardsPopped[cardKey] = { x = popHost.Position.X.Offset, y = popHost.Position.Y.Offset, w = popHost.Size.X.Offset }
        else
            Config.cardsPopped[cardKey] = nil
        end
        SaveConfig()
    end
    local function popOut(x, y, w, sc)
        dockParent = c.Parent
        if not dockParent or popHost then return end
        -- pin the current order: equal LayoutOrders keep insertion order, which a re-parent would lose
        for i, ch in ipairs(dockParent:GetChildren()) do
            if ch:IsA("GuiObject") and ch.LayoutOrder == 0 then ch.LayoutOrder = i end
        end
        popHost = New("Frame", { Name = "PoppedCard", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 0),
            AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 50, Parent = gui })
        local popScale = New("UIScale", { Scale = sc * 0.96, Parent = popHost })
        c.Parent = popHost
        Tween(popScale, { Scale = sc }, 0.3, Enum.EasingStyle.Quint)
        hdr.Active = true
        local dragFrom, hostFrom
        popDrag = { hdr.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            dragFrom, hostFrom = input.Position, popHost.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End and dragFrom then dragFrom = nil; savePop() end
            end)
        end), Track(UserInputService.InputChanged:Connect(function(input)
            if not dragFrom or not popHost then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local d = input.Position - dragFrom
            popHost.Position = UDim2.fromOffset(hostFrom.X.Offset + d.X, hostFrom.Y.Offset + d.Y)
        end)),
        -- it keeps the window's size: UI Scale / Adaptive Size changes reach it (and a card restored at load,
        -- popped before the window ever opened, takes the real scale once it does)
        Track(windowScale:GetPropertyChangedSignal("Scale"):Connect(function()
            -- the scale the window settles at, not the one its open / close animation passes through
            if popHost and windowOpen then popScale.Scale = computeScale() end
        end)) }
    end
    local function dock()
        if not popHost then return end
        for _, conn in ipairs(popDrag) do pcall(function() conn:Disconnect() end) end
        popDrag = nil
        hdr.Active = false
        c.Parent = dockParent
        popHost:Destroy(); popHost = nil
    end
    folderBtn.MouseButton1Click:Connect(function()
        if popHost then
            dock()
        else
            local sc = math.max(windowScale.Scale, 0.01)
            local abs = c.AbsolutePosition
            popOut(abs.X, abs.Y, c.AbsoluteSize.X / sc, sc)
        end
        savePop()
    end)
    -- popped out last run: float again where it was, once the card sits in its page (and kept on screen)
    local saved = Config.cardsPopped[cardKey]
    if type(saved) == "table" and tonumber(saved.x) and tonumber(saved.y) and tonumber(saved.w) then
        task.defer(function()
            if not c.Parent then return end
            local vp = gui.AbsoluteSize
            local x = math.clamp(saved.x, 0, math.max(0, vp.X - 120))
            local y = math.clamp(saved.y, 0, math.max(0, vp.Y - 60))
            popOut(x, y, saved.w, math.max(windowScale.Scale, 0.01))
        end)
    end

    -- the outline brightens a little under the mouse
    local cardStroke = c:FindFirstChildOfClass("UIStroke")
    -- and the header icon lights up with it
    if cardStroke then
        c.MouseEnter:Connect(function()
            Tween(cardStroke, { Color = T.Border }, 0.2)
            local i = hdr:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.Accent }, 0.2) end
        end)
        c.MouseLeave:Connect(function()
            Tween(cardStroke, { Color = T.BorderLow }, 0.25)
            local i = hdr:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { ImageColor3 = T.TextDim }, 0.25) end
        end)
    end

    local separator = New("Frame", { Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0, Parent = c })

    -- CanvasGroup so the body can fade while its height animates
    local bodyFrame = New("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = c,
    })
    local bodyPad = Padding(bodyFrame, 18, 18, 14, 16)
    local bodyList = VList(bodyFrame, 10)

    -- animated collapse / expand; the state is remembered per card (cardKey, above)
    -- the open height from the layout (works while hidden, and in unscaled offsets like Size wants)
    local function openHeight() return bodyList.AbsoluteContentSize.Y / math.max(windowScale.Scale, 0.01) + 30 end
    local collapsed, busy = false, false
    local COLLAPSE_INFO = TweenInfo.new(0.38, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local function setCollapsed(on, animated)
        collapsed = on
        local chev = chevronBtn:FindFirstChildWhichIsA("ImageLabel") or chevronIc
        if collapsed then
            bodyFrame.AutomaticSize = Enum.AutomaticSize.None
            if animated then
                bodyFrame.Size = UDim2.new(1, 0, 0, openHeight())
                Tween(chev, { Rotation = -90 }, 0.3, Enum.EasingStyle.Quint)
                TweenService:Create(bodyFrame, COLLAPSE_INFO, { Size = UDim2.new(1, 0, 0, 0), GroupTransparency = 1 }):Play()
                task.wait(0.38)
                if not collapsed then return end
            else
                chev.Rotation = -90; bodyFrame.GroupTransparency = 1
            end
            bodyFrame.Visible = false
            separator.Visible = false
            hdrPatch.Visible = false
        else
            separator.Visible = true
            hdrPatch.Visible = true
            bodyFrame.AutomaticSize = Enum.AutomaticSize.None
            bodyFrame.Size = UDim2.new(1, 0, 0, 0)
            bodyFrame.GroupTransparency = 1
            bodyFrame.Visible = true
            -- a body that was hidden since load has no layout yet: give it one frame (0 tall, see-through) to measure
            task.wait()
            if collapsed then return end
            Tween(chev, { Rotation = 0 }, 0.3, Enum.EasingStyle.Quint)
            TweenService:Create(bodyFrame, COLLAPSE_INFO, { Size = UDim2.new(1, 0, 0, openHeight()), GroupTransparency = 0 }):Play()
            task.wait(0.38)
            if collapsed then return end
            bodyFrame.AutomaticSize = Enum.AutomaticSize.Y
            bodyFrame.Size = UDim2.new(1, 0, 0, 0)
        end
    end
    if Config.cardsClosed[cardKey] then task.defer(setCollapsed, true, false) end
    -- known to the page switch, which fades the bodies of a page's open cards in one after another
    UI._cards = UI._cards or {}
    UI._cards[#UI._cards + 1] = { c = c, body = bodyFrame, pad = bodyPad, top = 14, bot = 16, closed = function() return collapsed end }
    chevronBtn.MouseButton1Click:Connect(function()
        if busy then return end
        busy = true
        Config.cardsClosed[cardKey] = (not collapsed) or nil
        SaveConfig()
        setCollapsed(not collapsed, true)
        busy = false
    end)

    return bodyFrame
end

-- tooltip: AttachTip(inst, text) shows a small card next to the mouse after a short hover (one shared card)
local AttachTip
do
    local TextService = game:GetService("TextService")
    local tip = New("CanvasGroup", { Name = "Tooltip", BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false, ZIndex = 120, Parent = gui })
    Corner(tip, 8); Stroke(tip, T.Border, 1)
    local tipScale = New("UIScale", { Scale = 1, Parent = tip })
    local tipLbl = New("TextLabel", { Position = UDim2.fromOffset(10, 7), BackgroundTransparency = 1, Text = "", TextWrapped = true,
        TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 121, Parent = tip })
    local owner, seq = nil, 0
    local function follow()
        local m, vp = UserInputService:GetMouseLocation(), gui.AbsoluteSize
        local s = tip.AbsoluteSize
        tip.Position = UDim2.fromOffset(math.clamp(m.X + 14, 4, math.max(4, vp.X - s.X - 4)), math.clamp(m.Y + 18, 4, math.max(4, vp.Y - s.Y - 4)))
    end
    Track(UserInputService.InputChanged:Connect(function(input)
        if owner and input.UserInputType == Enum.UserInputType.MouseMovement then follow() end
    end))
    local function hide(inst)
        if owner ~= inst then return end
        owner = nil; seq = seq + 1
        local my = seq
        Tween(tip, { GroupTransparency = 1 }, 0.1)
        task.delay(0.11, function() if seq == my then tip.Visible = false end end)
    end
    function AttachTip(inst, text)
        if not text or text == "" then return end
        inst.MouseEnter:Connect(function()
            if owner == inst then return end
            owner = inst; seq = seq + 1
            local my = seq
            task.delay(0.4, function()
                if seq ~= my or owner ~= inst or not inst.Visible then return end
                local sz = TextService:GetTextSize(text, 11, Enum.Font.Gotham, Vector2.new(240, 1000))
                tipLbl.Text = text
                tipLbl.Size = UDim2.fromOffset(sz.X + 2, sz.Y + 2)
                tip.Size = UDim2.fromOffset(sz.X + 22, sz.Y + 16)
                tip.Visible = true; follow()
                tipScale.Scale = 0.92
                Tween(tip, { GroupTransparency = 0 }, 0.16)
                Tween(tipScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
            end)
        end)
        inst.MouseLeave:Connect(function() hide(inst) end)
        inst.AncestryChanged:Connect(function() if not inst.Parent then hide(inst) end end)
    end
end

-- Row: label on left, control on right
-- desc (optional): a small grey line under the label; without it the row looks exactly as before. Hovering the row
-- shows the full desc (it is cut off when long), or tip when given.
local function Row(parent, labelText, desc, tip)
    local r = New("Frame", { Size = UDim2.new(1, 0, 0, desc and 44 or 32), BackgroundTransparency = 1, Parent = parent })
    indexItem(labelText, r)
    AttachTip(r, tip or desc)
    if labelText then
        New("TextLabel", {
            Position = UDim2.new(0, 0, 0, 0), Size = desc and UDim2.new(0.62, 0, 0, 24) or UDim2.new(0.55, 0, 1, 0),
            BackgroundTransparency = 1, Text = labelText, TextColor3 = T.Text,
            FontFace = F.Medium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Parent = r,
        })
    end
    if desc then
        New("TextLabel", {
            Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(0.62, 0, 0, 16),
            BackgroundTransparency = 1, Text = desc, TextColor3 = T.TextDim,
            FontFace = F.Regular, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Parent = r,
        })
    end
    return r
end

-- a key pill: clicking it waits for the next key (Esc clears it when "allowNone" is on, otherwise keeps the old key)
-- w, h, x: size and right offset (default 64 x 22 at the right edge, the keybind row look)
local listeningKey = false
-- mouse = true: the right and middle mouse buttons can be picked too ("MouseButton2" / "MouseButton3"; Roblox does not
-- report the side buttons). Off by default: a game that reads the key as Enum.KeyCode[name] would break on those names.
local function KeyPill(parent, keyName, onSet, allowNone, w, h, x, mouse)
    local pill = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x or 0, 0.5, 0),
        Size = UDim2.new(0, w or 64, 0, h or 22), BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
        Text = keyShort(keyName), TextColor3 = T.Text, FontFace = F.Medium, TextSize = 10, AutoButtonColor = false, Parent = parent,
    })
    Corner(pill, 6)
    local stroke = Stroke(pill, T.BorderLow, 1)
    local api = { pill = pill }
    function api:Set(name, fire) keyName = name; pill.Text = keyShort(name); if fire then safe(onSet, name) end end
    function api:Get() return keyName end
    pill.MouseEnter:Connect(function() Tween(pill, { BackgroundColor3 = T.CardHover }, 0.12) end)
    pill.MouseLeave:Connect(function() if not listeningKey then Tween(pill, { BackgroundColor3 = T.CardAlt }, 0.12) end end)
    pill.MouseButton1Click:Connect(function()
        if listeningKey then return end
        listeningKey = true
        pill.Text = "press a key"; Tween(stroke, { Color = T.Accent }, 0.12)
        -- the outline breathes while it waits
        local pulse = TweenService:Create(stroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 })
        pulse:Play()
        local c
        c = UserInputService.InputBegan:Connect(function(input)
            local ut = input.UserInputType
            local isMouse = mouse and (ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3)
            if ut ~= Enum.UserInputType.Keyboard and not isMouse then return end
            c:Disconnect()
            pulse:Cancel(); stroke.Transparency = 0
            local name = isMouse and ut.Name or input.KeyCode.Name
            if name == "Escape" then name = allowNone and "None" or keyName end
            api:Set(name)
            Tween(stroke, { Color = T.BorderLow }, 0.15); Tween(pill, { BackgroundColor3 = T.CardAlt }, 0.15)
            task.delay(0.1, function() listeningKey = false end)
            safe(onSet, name)
        end)
        Track(c)
    end)
    return api
end

-- opts.desc: grey line under the label. opts.hotkey: name of a config key that holds a key name; adds a key pill
-- left of the switch, and pressing that key anywhere flips the toggle (the callback runs as on a click)
local function Toggle(parent, labelText, default, cb, opts)
    local r = Row(parent, labelText, opts and opts.desc, opts and opts.tip)
    local track = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 36, 0, 20),
        BackgroundColor3 = default and T.Toggle_On or T.Toggle_Off,
        BorderSizePixel = 0, Parent = r,
    })
    Corner(track, 10)
    local knob = New("Frame", {
        Position = UDim2.new(0, default and 18 or 2, 0.5, -8),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = default and T.BgDeep or T.TextDim, BorderSizePixel = 0, Parent = track,
    })
    Corner(knob, 8)
    local btn = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, Parent = r })
    local state = default and true or false
    local hovered, pressed = false, false
    -- the knob is 16 wide, 18 under the mouse and 22 while pressed (it stretches toward the middle, the edge it
    -- rests against stays put); off and hovered, the track lightens a little
    local function knobW() return pressed and 22 or (hovered and 18 or 16) end
    local function knobPos() return UDim2.new(0, state and (34 - knobW()) or 2, 0.5, -8) end
    local function paint(animated)
        local tc = state and T.Toggle_On or (hovered and T.CardHover or T.Toggle_Off)
        local kc = state and T.BgDeep or T.TextDim
        local sz = UDim2.new(0, knobW(), 0, 16)
        if animated then
            Tween(track, { BackgroundColor3 = tc }, 0.2)
            Tween(knob, { Position = knobPos(), Size = sz, BackgroundColor3 = kc }, 0.3, Enum.EasingStyle.Back)
        else
            track.BackgroundColor3 = tc; knob.BackgroundColor3 = kc; knob.Position = knobPos(); knob.Size = sz
        end
    end
    local function squish()
        Tween(knob, { Position = knobPos(), Size = UDim2.new(0, knobW(), 0, 16) }, 0.14, Enum.EasingStyle.Quad)
    end
    btn.MouseEnter:Connect(function() hovered = true; squish(); if not state then Tween(track, { BackgroundColor3 = T.CardHover }, 0.15) end end)
    btn.MouseLeave:Connect(function() hovered = false; pressed = false; squish(); if not state then Tween(track, { BackgroundColor3 = T.Toggle_Off }, 0.15) end end)
    btn.MouseButton1Down:Connect(function() pressed = true; squish() end)
    local function flip()
        state = not state
        pressed = false
        paint(true)
        -- turning on, an accent ring leaves the knob
        if state then
            local ring = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 26, 0.5, 0), Size = UDim2.new(0, 16, 0, 16),
                BackgroundColor3 = T.Accent, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 0, Parent = track })
            New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
            Tween(ring, { Size = UDim2.new(0, 38, 0, 38), BackgroundTransparency = 1 }, 0.5, Enum.EasingStyle.Quad)
            task.delay(0.52, function() ring:Destroy() end)
        end
        safe(cb, state)
    end
    btn.MouseButton1Click:Connect(flip)
    AttachTip(btn, opts and (opts.tip or opts.desc))   -- btn covers the row, so it gets the hover too
    -- created after btn so the pill sits on top of it and takes its own clicks
    if opts and opts.hotkey then
        local hk = opts.hotkey
        if Config[hk] == nil then Config[hk] = "None" end
        -- the shell fires these itself, so mouse buttons are allowed; opts.hold: on while the key is held, off on release
        local keyPill = KeyPill(r, Config[hk], function(name) Config[hk] = name; SaveConfig() end, true, 48, 20, -44, true)
        UI._hotkeys[#UI._hotkeys + 1] = { key = hk, fire = flip, row = r, hold = opts.hold,
            set = function(v) if state ~= v then flip() end end }
        UI._bound[#UI._bound + 1] = { key = hk, ctl = keyPill }
    end
    -- opts.option = true: a setting of another feature, so it is not listed as "running" on the island
    -- whether it belongs to Settings / Home is decided now, while it still sits in its page (a card popped out later
    -- is outside every page, and its settings toggles must not start counting as running features)
    local system = (pages.settings and r:IsDescendantOf(pages.settings.frame)) or (pages.home and r:IsDescendantOf(pages.home.frame))
    ToggleRegistry[#ToggleRegistry + 1] = { label = labelText, row = r, get = function() return state end,
        option = opts and opts.option, system = system and true or false }
    -- animated on purpose: a click starts a tween toward "on", and a plain paint would lose to it when a
    -- callback turns the toggle back off right away (the knob stayed on while the state was off)
    -- Set(v, true) also runs the callback, as a click would
    return { Set = function(_, v, fire) state = v and true or false; paint(true); if fire then safe(cb, state) end end,
             Get = function() return state end }
end

-- opts.multi: several options can be on at once (default / Set / Get / cb use a list, in option order)
-- opts.search: a filter box on top of the list (on by itself past 8 options); it takes focus when the list opens
local function Dropdown(parent, labelText, options, default, cb, opts)
    opts = opts or {}
    local multi = opts.multi and true or false
    -- stacked like Ouroboros: label on top, full-width select underneath
    local hasLabel = labelText ~= nil and labelText ~= ""
    local r = New("Frame", {
        Size = UDim2.new(1, 0, 0, hasLabel and 54 or 32), BackgroundTransparency = 1, Parent = parent,
    })
    if hasLabel then indexItem(labelText, r) end
    if hasLabel then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = labelText,
            TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = r,
        })
    end
    local head = New("TextButton", {
        Position = UDim2.new(0, 0, 0, hasLabel and 22 or 0),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = T.BgDeep, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Parent = r,
    })
    Corner(head, 7)
    local headStroke = Stroke(head, T.BorderLow, 1)
    local headLbl = New("TextLabel", {
        Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -30, 1, 0),
        BackgroundTransparency = 1, Text = "",
        TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = head,
    })
    local chevron = MakeIcon(head, "chevron_down", 12, T.TextDim)
    chevron.AnchorPoint = Vector2.new(1, 0.5)
    chevron.Position = UDim2.new(1, -8, 0.5, 0)

    local selected, picked = nil, {}
    local function setValue(v)
        if multi then
            picked = {}
            for _, o in ipairs(type(v) == "table" and v or {}) do picked[o] = true end
        else
            selected = v
        end
    end
    setValue(default)
    if not multi and selected == nil then selected = options[1] end
    local function value()
        if not multi then return selected end
        local out = {}
        for _, o in ipairs(options) do if picked[o] then out[#out + 1] = o end end
        return out
    end
    local function headText()
        if not multi then return tostring(selected or "") end
        local v = value()
        if #v == 0 then return "None" end
        if #v <= 2 then return table.concat(v, ", ") end
        return v[1] .. ", " .. v[2] .. "  +" .. (#v - 2)
    end
    headLbl.Text = headText()

    local query = ""
    local function searching() return opts.search or #options > 8 end
    local function matches(opt) return query == "" or tostring(opt):lower():find(query, 1, true) ~= nil end
    local function lh()
        local n = 0
        for _, o in ipairs(options) do if matches(o) then n = n + 1 end end
        return math.min(math.max(n, 1), 6) * 23 + 8 + (searching() and 31 or 0)
    end
    -- parented to the overlay layer, NOT to the row (see OVERLAY LAYER note)
    local list = New("ScrollingFrame", {
        Size = UDim2.new(0, 150, 0, lh()),
        BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.TextDim, ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false, ZIndex = 5, Parent = overlay,
    })
    Corner(list, 8); Stroke(list, T.Border, 1); Padding(list, 4, 4, 4, 4); VList(list, 1)

    -- the filter box sits first in the list (LayoutOrder 0, the options count from 1)
    local searchFrame = New("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
        LayoutOrder = 0, Visible = false, ZIndex = 6, Parent = list })
    Corner(searchFrame, 6)
    local searchStroke = Stroke(searchFrame, T.BorderLow, 1)
    local sIc = MakeIcon(searchFrame, "search", 11, T.TextDim)
    sIc.Position = UDim2.new(0, 8, 0.5, -5); sIc.ZIndex = 7
    local searchTb = New("TextBox", { Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -32, 1, 0), BackgroundTransparency = 1,
        Text = "", PlaceholderText = "Search...", PlaceholderColor3 = T.TextMute, TextColor3 = T.Text, FontFace = F.Regular,
        TextSize = 11, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = searchFrame })
    searchTb.Focused:Connect(function() Tween(searchStroke, { Color = T.Accent }, 0.12) end)
    searchTb.FocusLost:Connect(function() Tween(searchStroke, { Color = T.BorderLow }, 0.15) end)
    local emptyLbl = New("TextLabel", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "No match",
        TextColor3 = T.TextMute, FontFace = F.Regular, TextSize = 11, LayoutOrder = 100000, Visible = false, ZIndex = 6, Parent = list })

    local isOpen, openSeq = false, 0
    local function applyFilter(animated)
        local any = false
        for _, b in ipairs(list:GetChildren()) do
            if b:IsA("TextButton") then
                local ok = matches(b:GetAttribute("Opt"))
                b.Visible = ok
                any = any or ok
            end
        end
        emptyLbl.Visible = not any
        if isOpen then
            local w = list.Size.X.Offset
            if animated then Tween(list, { Size = UDim2.new(0, w, 0, lh()) }, 0.2, Enum.EasingStyle.Quint) else list.Size = UDim2.new(0, w, 0, lh()) end
        end
    end
    local function close()
        if not isOpen then return end
        isOpen = false
        openSeq = openSeq + 1
        local my = openSeq
        if searchTb:IsFocused() then searchTb:ReleaseFocus() end
        -- folds back toward the select box, then hides (unless it was opened again meanwhile)
        local w = list.Size.X.Offset
        Tween(list, { Size = UDim2.new(0, w, 0, math.floor(lh() * 0.55)) }, 0.12, Enum.EasingStyle.Quad)
        task.delay(0.12, function() if openSeq == my then list.Visible = false end end)
        Tween(chevron, { Rotation = 0 }, 0.18)
        Tween(headStroke, { Color = T.BorderLow }, 0.18)
        if currentDrop and currentDrop.list == list then
            currentDrop = nil
            dropCatcher.Visible = false; floatCatcher.Visible = false
        end
    end
    local build
    function build()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, opt in ipairs(options) do
            local isSel = (multi and picked[opt]) or (not multi and opt == selected)
            local b = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = isSel and 0.6 or 1, BackgroundColor3 = T.CardHover,
                Text = tostring(opt), TextColor3 = isSel and T.Text or T.TextDim, TextTruncate = Enum.TextTruncate.AtEnd,
                FontFace = isSel and F.Medium or F.Regular, TextSize = 11, LayoutOrder = i,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = list, ZIndex = 6,
            })
            b:SetAttribute("Opt", tostring(opt))
            Corner(b, 5)
            Padding(b, 10, multi and 26 or 10, 0, 0)
            -- the chosen option carries a short accent bar on its left edge
            if isSel then
                New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -7, 0.5, 0), Size = UDim2.fromOffset(2, 12),
                    BackgroundColor3 = T.Accent, BorderSizePixel = 0, ZIndex = 7, Parent = b })
            end
            -- multi: a small check box on the right, filled while the option is on
            if multi then
                local box = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 18, 0.5, 0), Size = UDim2.fromOffset(12, 12),
                    BackgroundColor3 = isSel and T.Accent or T.BgDeep, BorderSizePixel = 0, ZIndex = 7, Parent = b })
                Corner(box, 3); Stroke(box, isSel and T.Accent or T.Border, 1)
                if isSel then
                    local ck = MakeIcon(box, "check", 10, T.BgDeep)
                    ck.AnchorPoint = Vector2.new(0.5, 0.5); ck.Position = UDim2.new(0.5, 0, 0.5, 0); ck.ZIndex = 8
                end
            end
            b.MouseEnter:Connect(function() Tween(b, { BackgroundTransparency = 0.45 }, 0.1) end)
            b.MouseLeave:Connect(function() Tween(b, { BackgroundTransparency = isSel and 0.6 or 1 }, 0.12) end)
            b.MouseButton1Click:Connect(function()
                if multi then
                    picked[opt] = (not picked[opt]) or nil
                    headLbl.Text = headText()
                    build(); applyFilter(false)
                    safe(cb, value())
                    return
                end
                selected = opt; headLbl.Text = headText()
                close(); build()
                safe(cb, opt)
            end)
        end
        searchFrame.Visible = searching()
    end
    build()
    searchTb:GetPropertyChangedSignal("Text"):Connect(function()
        query = (searchTb.Text:lower():gsub("^%s+", ""):gsub("%s+$", ""))
        applyFilter(true)
    end)

    local function open()
        closeOpenDrop()
        isOpen = true
        openSeq = openSeq + 1
        if searchTb.Text ~= "" then searchTb.Text = "" end
        query = ""; applyFilter(false)
        -- inside the window the list goes on its overlay; in a popped-out card, on the screen-level one
        local inWindow = head:IsDescendantOf(window)
        local layer = inWindow and overlay or floatOverlay
        list.Parent = layer
        -- both layers are scaled like the window: screen pixels / scale = the offsets they lay out in
        local sc = math.max(windowScale.Scale, 0.01)
        floatScale.Scale = sc
        local rel = (head.AbsolutePosition - layer.AbsolutePosition) / sc
        local w = head.AbsoluteSize.X / sc
        local y = rel.Y + head.AbsoluteSize.Y / sc + 4
        -- not enough room below? open upward instead (anchored at the bottom so it grows up)
        local up = y + lh() > layer.AbsoluteSize.Y / sc - 8
        if up then y = rel.Y - 4 end
        list.AnchorPoint = Vector2.new(0, up and 1 or 0)
        list.Position = UDim2.new(0, rel.X, 0, y)
        list.CanvasPosition = Vector2.new(0, 0)
        -- unfolds from the select box
        list.Size = UDim2.new(0, w, 0, math.floor(lh() * 0.55))
        list.Visible = true
        Tween(list, { Size = UDim2.new(0, w, 0, lh()) }, 0.24, Enum.EasingStyle.Quint)
        -- the options fade in top to bottom, each sliding a few pixels left into place
        local k = 0
        for _, b in ipairs(list:GetChildren()) do
            if b:IsA("TextButton") then
                k = k + 1
                local pad = b:FindFirstChildOfClass("UIPadding")
                b.TextTransparency = 1
                if pad then pad.PaddingLeft = UDim.new(0, 18) end
                task.delay(math.min(k, 8) * 0.025, function()
                    if not isOpen then b.TextTransparency = 0; if pad then pad.PaddingLeft = UDim.new(0, 10) end; return end
                    Tween(b, { TextTransparency = 0 }, 0.2)
                    if pad then Tween(pad, { PaddingLeft = UDim.new(0, 10) }, 0.3, Enum.EasingStyle.Quint) end
                end)
            end
        end
        if searching() then task.defer(function() if isOpen then searchTb:CaptureFocus() end end) end
        if inWindow then dropCatcher.Visible = true else floatCatcher.Visible = true end
        currentDrop = { list = list, close = close }
        Tween(chevron, { Rotation = 180 }, 0.25, Enum.EasingStyle.Back)
        Tween(headStroke, { Color = T.Accent }, 0.15)
    end
    head.MouseButton1Click:Connect(function()
        if isOpen then close() else open() end
    end)
    head.MouseEnter:Connect(function() if not isOpen then Tween(headStroke, { Color = T.Border }, 0.15) end end)
    head.MouseLeave:Connect(function() if not isOpen then Tween(headStroke, { Color = T.BorderLow }, 0.2) end end)
    return { Set = function(_, v, fire) setValue(v); headLbl.Text = headText(); build(); applyFilter(false); if fire then safe(cb, value()) end end,
             Get = function() return value() end,
             SetOptions = function(_, newList)
                 for i = #options, 1, -1 do table.remove(options, i) end
                 for _, o in ipairs(newList) do options[#options + 1] = o end
                 headLbl.Text = headText()
                 build(); applyFilter(false)
             end }
end

-- Row with right-aligned keybind pill (see KeyPill)
-- opts.mouse: right / middle mouse can be picked too (read them with UI.keyDown / UI.isKey, not Enum.KeyCode[name])
local function KeybindRow(parent, labelText, keyName, onSet, allowNone, opts)
    return KeyPill(Row(parent, labelText), keyName, onSet, allowNone, nil, nil, nil, opts and opts.mouse)
end

-- Row with right-aligned status text. Returns the TEXT LABEL (assign .Text to update it) and the row.
-- opts: width (default 150 px), desc (small grey line under the label)
local function StatusRow(parent, labelText, valueText, opts)
    local r = Row(parent, labelText, opts and opts.desc, opts and opts.tip)
    local lbl = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, (opts and opts.width) or 150, 1, 0), BackgroundTransparency = 1,
        Text = valueText, TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = r,
    })
    return lbl, r
end

local function toHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function parseHex(s)
    s = tostring(s):gsub("[#%s]", "")
    if #s == 6 and s:match("^%x+$") then
        return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
    end
end
local function Button(parent, labelText, cb, variant, iconName)
    local isPrimary = variant == "primary"
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = isPrimary and T.Accent or T.CardAlt,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = parent,
    })
    Corner(b, 8)
    if not isPrimary then Stroke(b, T.BorderLow, 1) end
    indexItem(labelText, b)
    local content = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, Parent = b,
    })
    HList(content, 7)
    if iconName then
        MakeIcon(content, iconName, 14, isPrimary and T.BgDeep or T.TextDim)
    end
    New("TextLabel", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, Text = labelText, TextColor3 = isPrimary and T.BgDeep or T.Text,
        FontFace = F.Medium, TextSize = 12, Parent = content })
    b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = isPrimary and T.AccentDim or T.CardHover }, 0.15) end)
    b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = isPrimary and T.Accent or T.CardAlt }, 0.15) end)
    b.MouseButton1Down:Connect(function() Tween(b, { Size = UDim2.new(1, 0, 0, 30) }, 0.08) end)
    b.MouseButton1Up:Connect(function()   Tween(b, { Size = UDim2.new(1, 0, 0, 32) }, 0.25, Enum.EasingStyle.Back) end)
    b.MouseLeave:Connect(function() Tween(b, { Size = UDim2.new(1, 0, 0, 32) }, 0.15) end)
    b.MouseButton1Click:Connect(function() Ripple(b, isPrimary and T.BgDeep or T.Text); safe(cb) end)
    return b
end

-- Grid of 2 buttons in one row
-- an item with confirm = true asks first: the first click turns it into a red "Confirm", a second click within
-- 3 s runs it, otherwise it goes back to normal
local function ButtonRow(parent, items)
    local r = New("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Parent = parent })
    HList(r, 8)
    for _, it in ipairs(items) do
        local btn = New("TextButton", {
            Size = UDim2.new(0.5, -4, 1, 0),
            BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Text = it.label,
            TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12, AutoButtonColor = false, Parent = r,
        })
        Corner(btn, 8); Stroke(btn, T.BorderLow, 1)
        btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = T.CardHover }, 0.15) end)
        btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = T.CardAlt }, 0.15) end)
        local armed = 0
        local function disarm()
            armed = 0
            btn.Text = it.label
            Tween(btn, { TextColor3 = T.Text }, 0.15)
        end
        btn.MouseButton1Click:Connect(function()
            Ripple(btn, (it.confirm and armed ~= 0) and T.Error or T.Text)
            if it.confirm and armed == 0 then
                armed = os.clock()
                local my = armed
                btn.Text = "Confirm"
                Tween(btn, { TextColor3 = T.Error }, 0.15)
                task.delay(3, function() if armed == my then disarm() end end)
                return
            end
            if it.confirm then disarm() end
            safe(it.cb)
        end)
    end
    return r
end

-- labeled input (single-line textbox)
local function Input(parent, labelText, placeholder, default, cb)
    local r = Row(parent, labelText)
    local box = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 150, 0, 26),
        BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = r,
    })
    Corner(box, 7)
    local stroke = Stroke(box, T.BorderLow, 1)
    Padding(box, 10, 10, 0, 0)
    local tb = New("TextBox", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        PlaceholderText = placeholder or "", PlaceholderColor3 = T.TextDim,
        TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Text = default or "", Parent = box,
    })
    tb.Focused:Connect(function() Tween(stroke, { Color = T.Accent }, 0.15) end)
    tb.FocusLost:Connect(function()
        Tween(stroke, { Color = T.BorderLow }, 0.15)
        safe(cb, tb.Text)
    end)
    return tb
end


-- slider with a value box on the right. The last argument is a suffix ("%", "px", "s", ...) or
-- { suffix =, step = }: step 0.05 gives values like 0.35; the default step 1 keeps whole numbers
local function Slider(parent, labelText, minV, maxV, default, cb, opts)
    if type(opts) ~= "table" then opts = { suffix = opts } end
    local suffix, step = opts.suffix or "", opts.step or 1
    local dec = #(tostring(step):match("%.(%d+)$") or "")
    local function snap(x)
        local v = math.clamp(minV + math.floor((x - minV) / step + 0.5) * step, minV, maxV)
        if dec == 0 then return math.floor(v + 0.5) end
        return tonumber(("%." .. dec .. "f"):format(v))
    end
    local function fmt(v) return (dec == 0 and tostring(v) or ("%." .. dec .. "f"):format(v)) .. suffix end
    local value = default
    local wrap = New("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = parent })
    indexItem(labelText, wrap)
    New("TextLabel", { Size = UDim2.new(0.6, 0, 0, 22), BackgroundTransparency = 1, Text = labelText,
        TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap })
    local valBox = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 56, 0, 22),
        BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = wrap })
    Corner(valBox, 6)
    local valStroke = Stroke(valBox, T.BorderLow, 1)
    -- the value box takes typing too (looks the same as a label until focused)
    local valLbl = New("TextBox", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = fmt(default),
        ClearTextOnFocus = false, PlaceholderText = "", TextColor3 = T.Text, FontFace = F.Medium, TextSize = 11, Parent = valBox })
    local track = New("Frame", { Position = UDim2.new(0, 0, 0, 32), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, Parent = wrap })
    Corner(track, 2)
    local rel0 = math.clamp((default - minV) / (maxV - minV), 0, 1)
    local fill = New("Frame", { Size = UDim2.new(rel0, 0, 1, 0), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = track })
    Corner(fill, 2)
    -- the fill fades in from the left, so the end at the knob is the brightest
    New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) }), Parent = fill })
    -- a soft accent halo behind the knob: it shows under the mouse and grows while dragging
    local halo = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(rel0, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = T.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = track })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = halo })
    local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(rel0, 0, 0.5, 0),
        Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = T.Text, BorderSizePixel = 0, Parent = track })
    Corner(knob, 7)
    local hit = New("TextButton", { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = wrap })
    local sliding, hovering = false, false
    local function glow()
        local s = sliding and 30 or (hovering and 24 or 14)
        Tween(halo, { Size = UDim2.new(0, s, 0, s), BackgroundTransparency = (sliding or hovering) and 0.8 or 1 }, 0.22, Enum.EasingStyle.Quint)
    end
    hit.MouseEnter:Connect(function() hovering = true; glow() end)
    hit.MouseLeave:Connect(function() hovering = false; glow() end)
    local function show(v, animate)
        local rel = math.clamp((v - minV) / (maxV - minV), 0, 1)
        if animate then
            Tween(fill, { Size = UDim2.new(rel, 0, 1, 0) }, 0.08); Tween(knob, { Position = UDim2.new(rel, 0, 0.5, 0) }, 0.08)
            Tween(halo, { Position = UDim2.new(rel, 0, 0.5, 0) }, 0.08)
        else
            fill.Size = UDim2.new(rel, 0, 1, 0); knob.Position = UDim2.new(rel, 0, 0.5, 0); halo.Position = knob.Position
        end
        valLbl.Text = fmt(v)
    end
    local function setFromX(x, instant)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = snap(minV + rel * (maxV - minV))
        if v == value then return end          -- the same step again: nothing to redraw, nothing to save
        value = v
        show(v, not instant)
        safe(cb, v)
    end
    -- typed value: the bare number while editing, then snapped to the step and clamped to min..max
    valLbl.Focused:Connect(function()
        Tween(valStroke, { Color = T.Accent }, 0.12)
        valLbl.Text = dec == 0 and tostring(value) or ("%." .. dec .. "f"):format(value)
    end)
    valLbl.FocusLost:Connect(function()
        Tween(valStroke, { Color = T.BorderLow }, 0.12)
        local n = tonumber((valLbl.Text:gsub(",", "."):gsub("[^%d%.%-]", "")))
        if not n then show(value, false); return end
        local v = snap(n)
        value = v
        show(v, true)
        safe(cb, v)
    end)
    -- the global input listeners exist only while this slider is being dragged (not one pair per slider, forever)
    local moveConn, endConn
    local function stopSliding()
        sliding = false
        if moveConn then moveConn:Disconnect(); moveConn = nil end
        if endConn then endConn:Disconnect(); endConn = nil end
        Tween(knob, { Size = UDim2.new(0, 14, 0, 14) }, 0.1); glow()
    end
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if moveConn then moveConn:Disconnect() end
            if endConn then endConn:Disconnect() end
            sliding = true; Tween(knob, { Size = UDim2.new(0, 18, 0, 18) }, 0.1); glow(); setFromX(i.Position.X)
            moveConn = UserInputService.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    setFromX(m.Position.X, true)
                end
            end)
            endConn = UserInputService.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then stopSliding() end
            end)
        end
    end)
    -- under the mouse, Left / Right move it one step (Shift: ten); the key handler at the bottom calls UI._sliderNudge
    local function nudge(dir, big)
        local v = snap(value + dir * step * (big and 10 or 1))
        if v == value then return end
        value = v; show(v, true); safe(cb, v)
    end
    wrap.MouseEnter:Connect(function() UI._sliderNudge = nudge end)
    wrap.MouseLeave:Connect(function() if UI._sliderNudge == nudge then UI._sliderNudge = nil end end)
    return { Set = function(_, v, fire) value = v; show(v, false); if fire then safe(cb, v) end end,
             Get = function() return value end, frame = wrap }
end

-- a full-width text box (for names, codes, links)
local function WideInput(parent, placeholder, default, cb)
    local box = New("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.BgDeep, BorderSizePixel = 0, Parent = parent })
    Corner(box, 8)
    local stroke = Stroke(box, T.BorderLow, 1)
    Padding(box, 10, 10, 0, 0)
    local tb = New("TextBox", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, PlaceholderText = placeholder or "",
        PlaceholderColor3 = T.TextDim, TextColor3 = T.Text, FontFace = F.Regular, TextSize = 11, ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left, Text = default or "", Parent = box })
    tb.Focused:Connect(function() Tween(stroke, { Color = T.Accent }, 0.15) end)
    tb.FocusLost:Connect(function()
        Tween(stroke, { Color = T.BorderLow }, 0.15)
        safe(cb, tb.Text)
    end)
    return tb, box
end

local function firstFeaturePage()
    local best, bestOrder
    for id, ref in pairs(navRefs) do
        if id ~= "home" and id ~= "settings" then
            local o = ref.button.LayoutOrder
            if not bestOrder or o < bestOrder then best, bestOrder = id, o end
        end
    end
    return best or "settings"
end

-- ============================================================================
-- PROGRAMMER API  (UI.*)  -  what a game script uses; nothing else in this file is needed.
--
--   structure   UI.page(id, title, icon) -> page      adds the sidebar entry AND the page
--               UI.card(page, title, icon) -> body     a titled, collapsible card
--   controls    UI.toggle(body, label, default, cb, {desc=})          -> {Set, Get}
--               UI.slider(body, label, min, max, default, cb, suffix) -> {Set}
--               UI.dropdown(body, label, options, default, cb)        UI.input(body, label, placeholder, default, cb)
--               UI.button(body, label, cb, "primary"|nil, icon)       UI.keybind(body, label, keyName, cb, allowNone)
--               UI.buttonRow(body, { {label=, cb=}, ... })
--               toggle opts: {desc=, tip=, hotkey="configKey", option=true}; slider suffix may be {suffix=, step=}
--               (hotkey: key pill + a key that flips it; option: a setting, not counted as "running" on the island)
--               liveRow opts: {width=, desc=, tip=}   tip / desc show as a tooltip on hover
--               every control's Set(v, true) also runs its callback (plain Set(v) only redraws)
--   bound       UI.bind.toggle(body, label, key, cb, opts)      UI.bind.slider(body, label, key, min, max, cb, opts)
--               UI.bind.dropdown(body, label, key, options, cb) UI.bind.input(body, label, key, placeholder, cb)
--               UI.bind.keybind(body, label, key, cb, allowNone)
--               the value is UI.config[key]: saved on change, redrawn (and cb run again) when a config load changes it
--   read-outs   UI.liveRow(body, label, text, {width=, desc=}) -> TextLabel (assign .Text)
--               UI.paragraph(body, text, {color=, size=, rich=}) -> TextLabel (wraps, grows)
--               UI.progress(body, label) -> {Set(frac, text)}          UI.logView(body, height) -> {Add(text, color), Clear()}
--   state       UI.config (saved to disk)   UI.defaults{k=v}  fills missing keys
--               UI.volatile{k=v}            these keys are reset now and never saved (bots must not auto-start)
--   lifecycle   UI.every(seconds|fn, fn, {visible=true, name=}) -> {Stop}   a pcall'd loop that dies with the script
--               UI.spawn(fn)   UI.after(seconds, fn)   UI.onUnload(fn)   UI.onPanic(fn)   UI.track(connection)
--   feedback    UI.notify("ok"|"warn"|"err"|"info", title, body)   UI.toast(title, on)   UI.footer(text|nil)   UI.island(text|nil)
--   debugging   UI.log(level, msg)   UI.logCard(page)   UI.diag.section(title, fn(add))   UI.diag.card(page)
--   misc        UI.char() -> character, humanoid, root   UI.copy(text)   UI.id / UI.title
--               UI.writeReport(prefix, text) -> ok, path     UI.safe(fn, ...)  pcall + log + one toast
--   raw access  UI.config UI.save UI.track UI.theme(colours) UI.font UI.new(class, props) UI.rawNotify({title=, body=, color=, icon=})
--               UI.icon UI.tween UI.gui UI.select(pageId)    (use these instead of reaching for the shell's locals)
-- ============================================================================
UI.id, UI.title = ID, BRAND
UI.config, UI.save, UI.track, UI.theme, UI.font = Config, SaveConfig, Track, T, F
UI.new, UI.icon, UI.tween, UI.gui, UI.copy = New, MakeIcon, Tween, gui, Copy
UI.rawNotify, UI.safe = Notify, safe
UI.card, UI.row, UI.toggle, UI.slider, UI.dropdown = TitledCard, Row, Toggle, Slider, Dropdown
UI.button, UI.buttonRow, UI.input, UI.wideInput, UI.keybind, UI.liveRow = Button, ButtonRow, Input, WideInput, KeybindRow, StatusRow
UI.select = function(id) if UI._selectPage then UI._selectPage(id) end end

function UI.page(id, title, iconName)
    AddNavItem(id, title, iconName)
    return MakePage(id, title, iconName)
end

-- bound controls: the value lives in Config[key] and is saved on every change; cb(v) runs after the save.
-- cb is not called when the control is built (same as UI.toggle); it runs when a config load changes the value.
UI.bind = {}
function UI._binder(key, cb)
    return function(v) Config[key] = v; SaveConfig(); if cb then cb(v) end end
end
function UI._bindAdd(key, ctl, cb)
    UI._bound[#UI._bound + 1] = { key = key, ctl = ctl, cb = cb }
    return ctl
end
-- after a config load: redraw every bound control whose value changed and run its callback
-- equal values; lists (multi dropdowns) are equal when they hold the same items in the same order
function UI._same(a, b)
    if type(a) == "table" and type(b) == "table" then
        if #a ~= #b then return false end
        for i = 1, #a do if a[i] ~= b[i] then return false end end
        return true
    end
    return a == b
end
function UI._refreshBound()
    for _, b in ipairs(UI._bound) do
        local v = Config[b.key]
        if v ~= nil and not UI._same(v, b.ctl:Get()) then
            pcall(b.ctl.Set, b.ctl, v)
            if b.cb then safe(b.cb, v) end
        end
    end
end
function UI.bind.toggle(parent, label, key, cb, opts)
    return UI._bindAdd(key, Toggle(parent, label, Config[key] == true, UI._binder(key, cb), opts), cb)
end
function UI.bind.slider(parent, label, key, minV, maxV, cb, opts)
    if Config[key] == nil then Config[key] = minV end
    return UI._bindAdd(key, Slider(parent, label, minV, maxV, Config[key], UI._binder(key, cb), opts), cb)
end
function UI.bind.dropdown(parent, label, key, options, cb, opts)
    if Config[key] == nil then Config[key] = (opts and opts.multi) and {} or options[1] end
    return UI._bindAdd(key, Dropdown(parent, label, options, Config[key], UI._binder(key, cb), opts), cb)
end
function UI.bind.input(parent, label, key, placeholder, cb)
    local tb = Input(parent, label, placeholder, Config[key] ~= nil and tostring(Config[key]) or "", UI._binder(key, cb))
    UI._bindAdd(key, { Set = function(_, v) tb.Text = tostring(v) end, Get = function() return tb.Text end }, cb)
    return tb
end
function UI.bind.keybind(parent, label, key, cb, allowNone, opts)
    if Config[key] == nil then Config[key] = "None" end
    return UI._bindAdd(key, KeybindRow(parent, label, Config[key], UI._binder(key, cb), allowNone, opts), cb)
end

function UI.paragraph(parent, text, opts)
    opts = opts or {}
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = text, TextWrapped = true, RichText = opts.rich == true,
        TextColor3 = opts.color or T.TextDim, FontFace = F.Regular, TextSize = opts.size or 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = parent,
    })
end

function UI.progress(parent, labelText, opts)
    opts = opts or {}
    local wrap = New("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, Parent = parent })
    indexItem(labelText, wrap)
    New("TextLabel", { Size = UDim2.new(0.55, 0, 0, 20), BackgroundTransparency = 1, Text = labelText,
        TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap })
    local valLbl = New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.45, 0, 0, 20), BackgroundTransparency = 1, Text = "-", TextColor3 = T.TextDim,
        FontFace = F.Medium, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = wrap })
    local track = New("Frame", { Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Parent = wrap })
    Corner(track, 3)
    local fill = New("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = opts.color or T.Accent,
        BorderSizePixel = 0, Parent = track })
    Corner(fill, 3)
    -- a sheen sweeps over the fill now and then
    local sheen = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = fill })
    Corner(sheen, 3)
    local sg = New("UIGradient", { Offset = Vector2.new(-1, 0), Parent = sheen,
        Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1),
            NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1) }) })
    TweenService:Create(sg, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0.8), { Offset = Vector2.new(1, 0) }):Play()
    local api = { frame = wrap }
    function api:Set(frac, text)
        Tween(fill, { Size = UDim2.new(math.clamp(frac or 0, 0, 1), 0, 1, 0) }, 0.2)
        if text then valLbl.Text = text end
    end
    return api
end

function UI.logView(parent, height)
    local box = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, height or 140), BackgroundColor3 = T.BgDeep, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = T.Border, ScrollBarImageTransparency = 0.5,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, Parent = parent,
    })
    Corner(box, 8); Stroke(box, T.BorderLow, 1); Padding(box, 8, 8, 6, 6); VList(box, 2)
    local items, n = {}, 0
    local api = { frame = box }
    function api:Add(text, color)
        n = n + 1
        local stick = box.CanvasPosition.Y + box.AbsoluteWindowSize.Y >= box.AbsoluteCanvasSize.Y - 8
        items[#items + 1] = New("TextLabel", {
            LayoutOrder = n, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Text = text, TextWrapped = true, TextColor3 = color or T.TextDim,
            FontFace = F.Regular, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, Parent = box,
        })
        if #items > 200 then table.remove(items, 1):Destroy() end
        if stick then task.defer(function() box.CanvasPosition = Vector2.new(0, 1e6) end) end
    end
    function api:Clear()
        for _, l in ipairs(items) do l:Destroy() end
        items = {}
    end
    return api
end

-- a ready-made "Log" card: everything sent to UI.log shows up in it (errors in red)
function UI.logCard(page)
    local body = TitledCard(page, "Log", "checklist")
    local view = UI.logView(body, 150)
    for _, l in ipairs(UI.logs) do view:Add(l) end
    UI._logHook = function(level, line)
        view:Add(line, (level == "error" and T.Error) or (level == "warn" and T.Warning) or nil)
    end
    Button(body, "Copy log", function() Copy(table.concat(UI.logs, "\n")) end, nil, "copy")
    return body, view
end

-- config helpers
function UI.defaults(tbl)
    for k, v in pairs(tbl) do if Config[k] == nil then Config[k] = v end end
    return Config
end
function UI.volatile(tbl)
    for k, v in pairs(tbl) do UI._volatile[k] = true; Config[k] = v end
    return Config
end

-- lifecycle helpers: everything started through these stops when the script is unloaded
function UI.onUnload(fn) UI._cleanups[#UI._cleanups + 1] = fn end
function UI.onPanic(fn) if UI._registerPanic then UI._registerPanic(fn) end end
function UI.spawn(fn, ...)
    local args = { ... }
    return task.spawn(function()
        local ok, err = pcall(fn, table.unpack(args))
        if not ok then UI.log("error", err) end
    end)
end
function UI.after(seconds, fn)
    return task.delay(seconds, function()
        local ok, err = pcall(fn)
        if not ok then UI.log("error", err) end
    end)
end
function UI.every(interval, fn, opts)
    opts = opts or {}
    local h = { alive = true }
    function h:Stop() self.alive = false end
    task.spawn(function()
        while h.alive and gui.Parent do
            if not (opts.visible and not windowOpen) then
                local ok, err = pcall(fn)
                if not ok then UI.log("error", (opts.name or "loop") .. ": " .. tostring(err)) end
            end
            task.wait(type(interval) == "function" and interval() or interval)
        end
    end)
    UI._cleanups[#UI._cleanups + 1] = function() h.alive = false end
    return h
end

-- feedback helpers
UI._kinds = {
    ok = function() return T.Success, "check" end, warn = function() return T.Warning, "alert-triangle" end,
    err = function() return T.Error, "x" end, info = function() return T.Accent, "check" end,
}
function UI.notify(kind, title, body, duration)
    local pick = UI._kinds[kind] or UI._kinds.info
    local color, icon = pick()
    Notify({ title = title, body = body, color = color, icon = icon, duration = duration })
end
function UI.toast(title, on)
    Notify({ title = title, body = on and "Enabled" or "Disabled", color = on and T.Success or T.TextDim, icon = on and "check" or "x" })
end
function UI.footer(text)
    if UI._footer then UI._footer.Text = text or UI._footerDefault or "Your executor is supported and fully compatible." end
end
function UI.island(text)
    if UI._setIslandText then UI._setIslandText(text) end
end
-- key names as the key pills store them: a KeyCode name, "MouseButton2" / "MouseButton3", or "None"
function UI.keyDown(name)
    if not name or name == "None" then return false end
    local ok, down = pcall(function()
        if name:sub(1, 11) == "MouseButton" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType[name]) end
        return UserInputService:IsKeyDown(Enum.KeyCode[name])
    end)
    return ok and down == true
end
function UI.isKey(input, name)
    if not name or name == "None" then return false end
    if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name == name end
    return input.UserInputType.Name == name
end
function UI.char()
    local c = LocalPlayer.Character
    return c, c and c:FindFirstChildWhichIsA("Humanoid"), c and c:FindFirstChild("HumanoidRootPart")
end

-- diagnostics: register sections once, one button writes the whole report (header + sections + UI log)
UI.diag = { sections = {} }
function UI.diag.section(title, fn) table.insert(UI.diag.sections, { title = title, fn = fn }) end
function UI.diag.build()
    local out = {}
    local function add(s) out[#out + 1] = tostring(s) end
    local function sec(title, fn)
        add(""); add(("="):rep(70)); add("## " .. title); add(("="):rep(70))
        local ok, err = pcall(fn, add)
        if not ok then add("ERROR: " .. tostring(err)) end
    end
    sec("HEADER", function(a)
        a(("OKUMA REPORT  %s  PlaceId %d  %s  (UI v%d)"):format(UI.title, game.PlaceId, os.date("%Y-%m-%d %H:%M:%S"), UI.version))
        local ex = UI.executor and (UI.executor.name .. (UI.executor.version and (" " .. UI.executor.version) or ""))
            or (type(identifyexecutor) == "function" and select(1, identifyexecutor())) or "?"
        local caps = {}
        for _, n in ipairs({ "getgc", "decompile", "hookfunction", "hookmetamethod", "getconnections", "fireproximityprompt",
            "firesignal", "writefile", "readfile", "setclipboard", "request", "getnilinstances" }) do
            caps[#caps + 1] = n .. "=" .. tostring(type(getfenv()[n]) == "function")
        end
        a("executor " .. tostring(ex)); a(table.concat(caps, " "))
        a(("players %d/%d   gravity %s   fps %s   ping %s"):format(#Players:GetPlayers(), Players.MaxPlayers, tostring(workspace.Gravity), tostring(liveFps), tostring(livePing)))
    end)
    for _, s in ipairs(UI.diag.sections) do sec(s.title, s.fn) end
    sec("UI LOG (latest last)", function(a) for _, l in ipairs(UI.logs) do a(l) end end)
    return table.concat(out, "\n")
end
-- writes any text to workspace/Okuma/Reports/<prefix>_<HHMMSS>.txt -> ok, path
function UI.writeReport(prefix, text)
    local path = ("Okuma/Reports/%s_%s.txt"):format(prefix or UI.id, os.date("%H%M%S"))
    local ok = false
    if type(writefile) == "function" then
        pcall(function()
            if type(isfolder) == "function" then
                if not isfolder("Okuma") then makefolder("Okuma") end
                if not isfolder("Okuma/Reports") then makefolder("Okuma/Reports") end
            end
            writefile(path, text); ok = true
        end)
    end
    return ok, path
end
function UI.diag.write(prefix)
    local text = UI.diag.build()
    local ok, path = UI.writeReport(prefix, text)
    return ok, path, text
end
function UI.diag.card(page, prefix)
    local body = TitledCard(page, "Diagnostics", "search")
    Button(body, "Generate report", function()
        task.spawn(function()
            local ok, path = UI.diag.write(prefix)
            Notify({ title = ok and "Report saved" or "Report", body = ok and ("workspace/" .. path) or "Could not write the file.",
                icon = ok and "check" or "x", color = ok and T.Success or T.Error, duration = 5 })
        end)
    end, "primary", "checklist")
    Button(body, "Copy report to clipboard", function()
        task.spawn(function()
            local ok = Copy(UI.diag.build())
            Notify({ title = "Report", body = ok and "Copied." or "Clipboard unavailable.", icon = ok and "check" or "x", color = ok and T.Success or T.Error })
        end)
    end, nil, "copy")
    return body
end

-- ============================================================================
-- COLOUR PICKER  -  UI.colorPicker(body, label, color, cb) -> {Set(c, fire), Get()}; UI.bind.color(body, label, key, cb)
-- A swatch on the row opens a popover (on the overlay layer, like a dropdown list): saturation / value square,
-- hue bar, hex box. cb gets a Color3 on every change while dragging.
-- ============================================================================
-- where the pointer is, in the same space as AbsolutePosition. That space starts below the top bar, while
-- GetMouseLocation counts from the top of the screen: take the inset off (it put the dot 36 px under the mouse).
-- A touch's Position is in AbsolutePosition space already.
function UI._pointer(input)
    if input and input.UserInputType == Enum.UserInputType.Touch then return Vector2.new(input.Position.X, input.Position.Y) end
    return UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
end
function UI.colorPicker(parent, labelText, color, cb)
    color = typeof(color) == "Color3" and color or Color3.new(1, 1, 1)
    local h, s, v = color:ToHSV()
    local r = Row(parent, labelText)
    local swatch = New("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 40, 0, 22),
        BackgroundColor3 = color, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = r })
    Corner(swatch, 6)
    local swStroke = Stroke(swatch, T.Border, 1)
    local hexLbl = New("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -48, 0.5, 0), Size = UDim2.new(0, 64, 1, 0),
        BackgroundTransparency = 1, Text = toHex(color), TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = r })

    local pop = New("CanvasGroup", { Size = UDim2.new(0, 220, 0, 196), BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
        GroupTransparency = 1, Visible = false, ZIndex = 5, Parent = overlay })
    Corner(pop, 10); Stroke(pop, T.Border, 1)
    local popScale = New("UIScale", { Scale = 1, Parent = pop })

    -- saturation left to right, value bottom to top: white fades out over the hue, black fades in from below
    local sv = New("Frame", { Position = UDim2.new(0, 10, 0, 10), Size = UDim2.new(0, 200, 0, 120), BackgroundColor3 = Color3.fromHSV(h, 1, 1),
        BorderSizePixel = 0, Parent = pop })
    Corner(sv, 6)
    local white = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = sv })
    Corner(white, 6)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
    local black = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2, Parent = sv })
    Corner(black, 6)
    New("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
    local svDot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 12, 0, 12), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 4, Parent = sv })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = svDot })
    New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = svDot })
    local svHit = New("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 5, Parent = sv })

    local hue = New("Frame", { Position = UDim2.new(0, 10, 0, 140), Size = UDim2.new(0, 200, 0, 12), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Parent = pop })
    Corner(hue, 6)
    local keys = {}
    for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)) end
    New("UIGradient", { Color = ColorSequence.new(keys), Parent = hue })
    local hueDot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(h, 0, 0.5, 0), Size = UDim2.new(0, 6, 0, 18),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = hue })
    Corner(hueDot, 3)
    New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1, Parent = hueDot })
    local hueHit = New("TextButton", { Position = UDim2.new(0, 0, 0, -4), Size = UDim2.new(1, 0, 1, 8), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, ZIndex = 5, Parent = hue })

    local preview = New("Frame", { Position = UDim2.new(0, 10, 0, 162), Size = UDim2.new(0, 26, 0, 24), BackgroundColor3 = color,
        BorderSizePixel = 0, Parent = pop })
    Corner(preview, 6); Stroke(preview, T.Border, 1)
    local hexBox = New("TextBox", { Position = UDim2.new(0, 42, 0, 162), Size = UDim2.new(0, 168, 0, 24), BackgroundColor3 = T.BgDeep,
        BorderSizePixel = 0, Text = toHex(color), ClearTextOnFocus = false, TextColor3 = T.Text, FontFace = F.Medium, TextSize = 11,
        PlaceholderText = "#RRGGBB", Parent = pop })
    Corner(hexBox, 6)
    local hexStroke = Stroke(hexBox, T.BorderLow, 1)

    local function paint()
        local c = Color3.fromHSV(h, s, v)
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svDot.Position = UDim2.new(s, 0, 1 - v, 0)
        hueDot.Position = UDim2.new(h, 0, 0.5, 0)
        preview.BackgroundColor3 = c; swatch.BackgroundColor3 = c
        hexLbl.Text = toHex(c)
        if not hexBox:IsFocused() then hexBox.Text = toHex(c) end
    end
    local function commit() paint(); safe(cb, Color3.fromHSV(h, s, v)) end
    paint()

    local mode = nil   -- "sv" or "hue" while dragging
    local function apply(input)
        local pt = UI._pointer(input)
        local box = mode == "sv" and sv or hue
        local ap, as = box.AbsolutePosition, box.AbsoluteSize
        local rx = math.clamp((pt.X - ap.X) / math.max(as.X, 1), 0, 1)
        if mode == "sv" then
            s, v = rx, 1 - math.clamp((pt.Y - ap.Y) / math.max(as.Y, 1), 0, 1)
        else
            h = math.min(rx, 0.999)
        end
        commit()
    end
    local function grab(which)
        return function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
            mode = which
            Tween(which == "sv" and svDot or hueDot, { Size = which == "sv" and UDim2.new(0, 16, 0, 16) or UDim2.new(0, 8, 0, 20) }, 0.12)
            apply(input)
        end
    end
    svHit.InputBegan:Connect(grab("sv"))
    hueHit.InputBegan:Connect(grab("hue"))
    Track(UserInputService.InputChanged:Connect(function(input)
        if mode and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then apply(input) end
    end))
    Track(UserInputService.InputEnded:Connect(function(input)
        if mode and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            mode = nil
            Tween(svDot, { Size = UDim2.new(0, 12, 0, 12) }, 0.15); Tween(hueDot, { Size = UDim2.new(0, 6, 0, 18) }, 0.15)
        end
    end))
    hexBox.Focused:Connect(function() Tween(hexStroke, { Color = T.Accent }, 0.12) end)
    hexBox.FocusLost:Connect(function()
        Tween(hexStroke, { Color = T.BorderLow }, 0.15)
        local c = parseHex(hexBox.Text)
        if c then h, s, v = c:ToHSV(); commit() else hexBox.Text = toHex(Color3.fromHSV(h, s, v)) end
    end)

    local isOpen, seq = false, 0
    local function close()
        if not isOpen then return end
        isOpen = false; seq = seq + 1
        local my = seq
        mode = nil
        Tween(pop, { GroupTransparency = 1 }, 0.12)
        Tween(popScale, { Scale = 0.94 }, 0.12)
        task.delay(0.13, function() if seq == my then pop.Visible = false end end)
        Tween(swStroke, { Color = T.Border }, 0.15)
        if currentDrop and currentDrop.list == pop then
            currentDrop = nil
            dropCatcher.Visible = false; floatCatcher.Visible = false
        end
    end
    local function open()
        closeOpenDrop()
        isOpen = true; seq = seq + 1
        local inWindow = swatch:IsDescendantOf(window)
        local layer = inWindow and overlay or floatOverlay
        pop.Parent = layer
        local sc = math.max(windowScale.Scale, 0.01)
        floatScale.Scale = sc
        local rel = (swatch.AbsolutePosition - layer.AbsolutePosition) / sc
        local x = math.max(4, rel.X + swatch.AbsoluteSize.X / sc - 220)
        local y = rel.Y + swatch.AbsoluteSize.Y / sc + 6
        local up = y + 196 > layer.AbsoluteSize.Y / sc - 8
        if up then y = rel.Y - 6 end
        pop.AnchorPoint = Vector2.new(0, up and 1 or 0)
        pop.Position = UDim2.new(0, x, 0, y)
        paint()
        pop.Visible = true
        popScale.Scale = 0.9
        Tween(pop, { GroupTransparency = 0 }, 0.18)
        Tween(popScale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
        Tween(swStroke, { Color = T.Accent }, 0.15)
        if inWindow then dropCatcher.Visible = true else floatCatcher.Visible = true end
        currentDrop = { list = pop, close = close }
    end
    swatch.MouseButton1Click:Connect(function() if isOpen then close() else open() end end)
    swatch.MouseEnter:Connect(function() if not isOpen then Tween(swStroke, { Color = T.Text }, 0.12) end end)
    swatch.MouseLeave:Connect(function() if not isOpen then Tween(swStroke, { Color = T.Border }, 0.15) end end)

    local api = { frame = r }
    function api:Set(c, fire) if typeof(c) ~= "Color3" then return end; h, s, v = c:ToHSV(); paint(); if fire then safe(cb, c) end end
    function api:Get() return Color3.fromHSV(h, s, v) end
    return api
end
-- bound colour: stored as "#RRGGBB" in UI.config[key] (JSON has no Color3); cb gets the Color3
function UI.bind.color(parent, label, key, cb)
    if not parseHex(Config[key] or "") then Config[key] = "#FFFFFF" end
    local picker = UI.colorPicker(parent, label, parseHex(Config[key]), function(c)
        Config[key] = toHex(c); SaveConfig()
        if cb then cb(c) end
    end)
    UI._bindAdd(key, { Set = function(_, hex) local c = parseHex(hex); if c then picker:Set(c) end end,
        Get = function() return toHex(picker:Get()) end },
        cb and function(hex) local c = parseHex(hex); if c then cb(c) end end)
    return picker
end

-- ============================================================================
-- HOME PAGE
-- ============================================================================
local pushFps, pushPing, playersLbl, sessionLbl
local TeleportService = game:GetService("TeleportService")
;(function()
local homePage = MakePage("home", "Welcome to " .. BRAND .. "!", "home")

-- WELCOME BACK card
local welcome = Card(homePage)
New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
    Text = "WELCOME BACK", TextColor3 = T.TextMute, FontFace = F.Bold, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = welcome, LayoutOrder = 1,
})
local welcomeRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 94), BackgroundTransparency = 1, Parent = welcome, LayoutOrder = 2,
})
local welcomeName = New("TextLabel", {
    Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -110, 0, 32),
    BackgroundTransparency = 1, Text = shownName(),
    TextColor3 = T.Text, FontFace = F.Bold, TextSize = 26, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = welcomeRow,
})
-- the name carries a slow shimmer: white text, the gradient holds the colours (repainted on a theme change)
do
    welcomeName.TextColor3 = Color3.new(1, 1, 1)
    local g = New("UIGradient", { Offset = Vector2.new(-1, 0), Parent = welcomeName })
    local function paint()
        g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Text), ColorSequenceKeypoint.new(0.4, T.Text),
            ColorSequenceKeypoint.new(0.5, T.Accent), ColorSequenceKeypoint.new(0.6, T.Text), ColorSequenceKeypoint.new(1, T.Text) })
    end
    paint()
    UI._onTheme = UI._onTheme or {}
    UI._onTheme[#UI._onTheme + 1] = paint
    TweenService:Create(g, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2.5), { Offset = Vector2.new(1, 0) }):Play()
end
local welcomeHandle = New("TextLabel", {
    Position = UDim2.new(0, 0, 0, 34), Size = UDim2.new(1, -110, 0, 14),
    BackgroundTransparency = 1, Text = shownHandle(),
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = welcomeRow,
})

local welcomeAvatar = New("Frame", {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 94, 0, 94), BackgroundColor3 = T.CardAlt,
    BorderSizePixel = 0, Parent = welcomeRow,
})
Corner(welcomeAvatar, 12); Stroke(welcomeAvatar, T.BorderLow, 1)
local welcomeAvatarImg = New("ImageLabel", {
    Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = "",
    ScaleType = Enum.ScaleType.Fit, Parent = welcomeAvatar,
})
Corner(welcomeAvatarImg, 12)
local welcomeSil = UI._silhouette(welcomeAvatar)
task.spawn(function()
    pcall(function()
        welcomeAvatarImg.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId,
            Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
    end)
end)

local badges = New("Frame", { Position = UDim2.new(0, 0, 0, 66), Size = UDim2.new(1, -110, 0, 28), BackgroundTransparency = 1, Parent = welcomeRow })
HList(badges, 8)
-- badges are small buttons; Name and Avatar hide your identity everywhere in the UI
local function Badge(parent, text, iconName, onClick, active)
    local b = New("TextButton", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = active and T.CardHover or T.CardAlt, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = parent,
    })
    Corner(b, 8)
    local st = Stroke(b, active and T.Accent or T.BorderLow, 1)
    Padding(b, 10, 12, 0, 0); HList(b, 6)
    MakeIcon(b, iconName, 12, T.TextDim)
    New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1, Text = text, TextColor3 = T.Text,
        FontFace = F.Medium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = b,
    })
    local api = {}
    local isOn = active and true or false
    function api.paint(on)
        isOn = on and true or false
        Tween(b, { BackgroundColor3 = isOn and T.CardHover or T.CardAlt }, 0.15)
        Tween(st, { Color = isOn and T.Accent or T.BorderLow }, 0.15)
    end
    if onClick then
        b.MouseButton1Click:Connect(onClick)
        b.MouseEnter:Connect(function() Tween(b, { BackgroundColor3 = T.CardHover }, 0.12) end)
        b.MouseLeave:Connect(function() Tween(b, { BackgroundColor3 = isOn and T.CardHover or T.CardAlt }, 0.15) end)
    end
    return b, api
end
local nameBadgeApi, avatarBadgeApi
local function refreshIdentity()
    welcomeName.Text = shownName(); welcomeHandle.Text = shownHandle()
    userNameLbl.Text = shownName(); userHandleLbl.Text = shownHandle()
    islName.Text = shownName(); islHandle.Text = shownHandle()
    local hide = Config.hideAvatar and true or false
    welcomeAvatarImg.ImageTransparency = hide and 1 or 0; welcomeSil.Visible = hide
    avatarImg.ImageTransparency = hide and 1 or 0; userSil.Visible = hide
    islAvatar.ImageTransparency = hide and 1 or 0
    if nameBadgeApi then nameBadgeApi.paint(Config.hideName) end
    if avatarBadgeApi then avatarBadgeApi.paint(Config.hideAvatar) end
end
Badge(badges, "Beta", "beta_badge")
local _nb
_nb, nameBadgeApi = Badge(badges, "Name", "tag", function()
    Config.hideName = not Config.hideName; SaveConfig(); refreshIdentity()
end, Config.hideName)
local _ab
_ab, avatarBadgeApi = Badge(badges, "Avatar", "user_person", function()
    Config.hideAvatar = not Config.hideAvatar; SaveConfig(); refreshIdentity()
end, Config.hideAvatar)
Apply.identity = refreshIdentity

-- STATS card: live frame-rate and ping graphs
local statsCard = Card(homePage)
local statsRow = New("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, Parent = statsCard, LayoutOrder = 1 })

local GRAPH_N = 44
local function StatCol(parent, xPct, label, unit, maxV, colorFn)
    local col = New("Frame", {
        Position = UDim2.new(xPct, xPct > 0 and 10 or 0, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
        BackgroundTransparency = 1, Parent = parent,
    })
    New("TextLabel", {
        Size = UDim2.new(0, 50, 0, 14), BackgroundTransparency = 1,
        Text = label, TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = col,
    })
    local statsLbl = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(1, -50, 0, 14), BackgroundTransparency = 1,
        Text = "min -   avg -   max -",
        TextColor3 = T.TextMute, FontFace = F.Regular, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = col,
    })
    local valueLabel = New("TextLabel", {
        Position = UDim2.new(0, 0, 0, 18), Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1, Text = "-", RichText = true, TextColor3 = T.Text, FontFace = F.Bold, TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = col,
    })
    local holder = New("Frame", { Position = UDim2.new(0, 0, 0, 52), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = col })
    HList(holder, 2, Enum.VerticalAlignment.Bottom)
    local bars = {}
    for i = 1, GRAPH_N do
        local bar = New("Frame", { Size = UDim2.new(1 / GRAPH_N, -2, 0.1, 0), BackgroundColor3 = T.CardHover,
            BorderSizePixel = 0, Visible = false, Parent = holder })
        Corner(bar, 1)
        bars[i] = bar
    end
    local hist = {}
    local function push(v)
        hist[#hist + 1] = v
        if #hist > GRAPH_N then table.remove(hist, 1) end
        local mn, mx, sum = math.huge, 0, 0
        for _, x in ipairs(hist) do mn = math.min(mn, x); mx = math.max(mx, x); sum = sum + x end
        statsLbl.Text = ("min %d   avg %d   max %d"):format(math.floor(mn), math.floor(sum / #hist + 0.5), math.floor(mx))
        valueLabel.Text = ('%d  <font color="rgb(140,140,150)" size="12">%s</font>'):format(math.floor(v), unit)
        for i = 1, GRAPH_N do
            local x = hist[#hist - (GRAPH_N - i)]
            local bar = bars[i]
            if x then
                bar.Visible = true
                Tween(bar, { Size = UDim2.new(1 / GRAPH_N, -2, math.clamp(x / maxV, 0.08, 1), 0), BackgroundColor3 = colorFn(x) }, 0.3)
            else
                bar.Visible = false
            end
        end
    end
    return push
end
pushFps = StatCol(statsRow, 0,   "FPS",  "fps", 75,  fpsColor)
pushPing = StatCol(statsRow, 0.5, "Ping", "ms",  300, pingColor)

New("Frame", { Position = UDim2.new(0, 0, 0, 80), Size = UDim2.new(1, 0, 0, 1),
    BackgroundColor3 = T.BorderLow, BorderSizePixel = 0, Parent = statsCard, LayoutOrder = 2 })

local counters = New("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = statsCard, LayoutOrder = 3 })
local function Counter(parent, xPct, label, value)
    local c = New("Frame", {
        Position = UDim2.new(xPct, 0, 0, 0), Size = UDim2.new(1/3, 0, 1, 0),
        BackgroundTransparency = 1, Parent = parent,
    })
    local valLbl = New("TextLabel", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1,
        Text = value, TextColor3 = T.Text, FontFace = F.Bold, TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
    New("TextLabel", { Position = UDim2.new(0, 0, 0, 24), Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1, Text = label, TextColor3 = T.TextDim,
        FontFace = F.Regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = c })
    return valLbl
end
genv.OkumaExecCount = (genv.OkumaExecCount or 0) + 1
playersLbl = Counter(counters, 0,   "Players", ("%d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers))
local execsLbl   = Counter(counters, 1/3, "Execs",   tostring(genv.OkumaExecCount))
sessionLbl = Counter(counters, 2/3, "Session", "0s")

-- GAME card
local gameCard = Card(homePage)
local gameHeader = New("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = gameCard, LayoutOrder = 1 })

local gameImg = New("ImageLabel", {
    Size = UDim2.new(0, 54, 0, 54), BackgroundColor3 = T.CardAlt, BorderSizePixel = 0,
    Image = "", ScaleType = Enum.ScaleType.Crop, Parent = gameHeader,
})
Corner(gameImg, 10); Stroke(gameImg, T.BorderLow, 1)

local gameNameLabel = New("TextLabel", {
    Position = UDim2.new(0, 66, 0, 6), Size = UDim2.new(1, -66, 0, 20),
    BackgroundTransparency = 1, Text = "Loading...", TextColor3 = T.Text,
    FontFace = F.Bold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = gameHeader,
})
local gameMetaLabel = New("TextLabel", {
    Position = UDim2.new(0, 66, 0, 28), Size = UDim2.new(1, -66, 0, 14),
    BackgroundTransparency = 1, Text = ("%d/%d players"):format(#Players:GetPlayers(), Players.MaxPlayers),
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = gameHeader,
})
local gameCreator
local function gameMeta()
    local count = ("%d/%d players"):format(#Players:GetPlayers(), Players.MaxPlayers)
    gameMetaLabel.Text = gameCreator and ("by %s  ·  %s"):format(gameCreator, count) or count
end
task.spawn(function()
    local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
    if ok and info then
        gameNameLabel.Text = info.Name or "Unknown"
        gameCreator = info.Creator and info.Creator.Name or "?"
        gameMeta()
        if info.IconImageAssetId and info.IconImageAssetId ~= 0 then
            gameImg.Image = "rbxassetid://" .. info.IconImageAssetId
        end
    end
end)
-- the player count follows people joining and leaving
Track(Players.PlayerAdded:Connect(function() task.defer(gameMeta) end))
Track(Players.PlayerRemoving:Connect(function() task.defer(gameMeta) end))

local actions = New("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1, Parent = gameCard, LayoutOrder = 2 })
HList(actions, 8)
local function ActionBtn(parent, label, iconName, cb)
    local b = New("TextButton", {
        Size = UDim2.new(0.25, -6, 1, 0), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = parent,
    })
    Corner(b, 10); Stroke(b, T.BorderLow, 1)
    local ic = MakeIcon(b, iconName, 20, T.Text)
    ic.AnchorPoint = Vector2.new(0.5, 0)
    ic.Position = UDim2.new(0.5, 0, 0, 12)
    New("TextLabel", { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1, Text = label, TextColor3 = T.TextDim,
        FontFace = F.Medium, TextSize = 11, Parent = b })
    -- hovered, the icon lifts and the outline brightens
    local st = b:FindFirstChildOfClass("UIStroke")
    b.MouseEnter:Connect(function()
        Tween(b, { BackgroundColor3 = T.CardHover }, 0.15); if st then Tween(st, { Color = T.Border }, 0.15) end
        local i = b:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { Position = UDim2.new(0.5, 0, 0, 8) }, 0.3, Enum.EasingStyle.Back) end
    end)
    b.MouseLeave:Connect(function()
        Tween(b, { BackgroundColor3 = T.CardAlt }, 0.15); if st then Tween(st, { Color = T.BorderLow }, 0.2) end
        local i = b:FindFirstChildWhichIsA("ImageLabel"); if i then Tween(i, { Position = UDim2.new(0.5, 0, 0, 12) }, 0.25, Enum.EasingStyle.Quint) end
    end)
    b.MouseButton1Click:Connect(function() Ripple(b, T.Text); safe(cb) end)
    return b
end

-- a failed teleport says so instead of nothing happening
local function teleportTo(server)
    local ok, err = pcall(function()
        if server then TeleportService:TeleportToPlaceInstance(game.PlaceId, server, LocalPlayer)
        else TeleportService:Teleport(game.PlaceId, LocalPlayer) end
    end)
    if not ok then Notify({ title = "Teleport", body = tostring(err):sub(1, 90), color = T.Error, icon = "x", duration = 5 }) end
end
ActionBtn(actions, "Rejoin", "rejoin", function()
    Notify({ title = "Rejoin", body = "Teleporting back to this server…", color = T.Accent })
    -- alone, this server shuts down as you leave: join the game again instead of this server
    teleportTo(#Players:GetPlayers() > 1 and game.JobId or nil)
end)
-- the public server list, several pages of 100 (following nextPageCursor), without this server and the full ones.
-- Stops early once enough servers are found, or when a page fails (rate limit): what was gathered still counts.
local function fetchServers(order, maxPages, enough)
    local pool, cursor = {}, nil
    for _ = 1, maxPages do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100&excludeFullGames=true"):format(game.PlaceId, order)
        if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end
        local ok, data = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then break end
        for _, s in ipairs(data.data) do
            if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then pool[#pool + 1] = s end
        end
        cursor = data.nextPageCursor
        if not cursor or #pool >= enough then break end
    end
    return pool
end
ActionBtn(actions, "Hop", "shuffle", function()
    Notify({ title = "Server Hop", body = "Finding a new server…", color = T.Accent })
    task.spawn(function()
        -- a random server with room, picked from up to 5 pages (Lowest is the one that picks the emptiest)
        local pool = fetchServers("Desc", 5, 150)
        if #pool > 0 then teleportTo(pool[math.random(1, #pool)].id); return end
        Notify({ title = "Server Hop", body = "No server found.", color = T.Error })
    end)
end)
ActionBtn(actions, "Lowest", "lowest", function()
    Notify({ title = "Lowest", body = "Hopping to least-populated server…", color = T.Accent })
    task.spawn(function()
        -- sorted emptiest first, but empty / 1-player servers can sit later in the list: look at 3 pages
        local best
        for _, s in ipairs(fetchServers("Asc", 3, 300)) do
            if not best or (s.playing or 0) < (best.playing or 0) then best = s end
        end
        if best then teleportTo(best.id); return end
        Notify({ title = "Lowest", body = "No server found.", color = T.Error })
    end)
end)

ActionBtn(actions, "Job ID", "copy", function()
    if Copy(game.JobId) then
        Notify({ title = "Job ID", body = "Copied to clipboard.", color = T.Success })
    else
        Notify({ title = "Job ID", body = "Clipboard unavailable.", color = T.Error })
    end
end)

New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
    Text = ("Job %s…  ·  Place %d"):format(string.sub(game.JobId, 1, 10), game.PlaceId),
    TextColor3 = T.TextMute, FontFace = F.Regular, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = gameCard, LayoutOrder = 3 })

-- LINKS card
local linksCard = Card(homePage)
New("TextLabel", { Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1,
    Text = "LINKS", TextColor3 = T.TextMute, FontFace = F.Bold, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = linksCard, LayoutOrder = 1 })

local function LinkRow(parent, iconName, title, subtitle, trailingIcon, cb)
    local row = New("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = parent })
    local ic = MakeIcon(row, iconName, 24, T.Text)
    ic.AnchorPoint = Vector2.new(0, 0.5)
    ic.Position = UDim2.new(0, 2, 0.5, 0)
    New("TextLabel", { Position = UDim2.new(0, 40, 0, 6), Size = UDim2.new(1, -80, 0, 16),
        BackgroundTransparency = 1, Text = title, TextColor3 = T.Text,
        FontFace = F.Medium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    if subtitle then
        New("TextLabel", { Position = UDim2.new(0, 40, 0, 24), Size = UDim2.new(1, -80, 0, 14),
            BackgroundTransparency = 1, Text = subtitle, TextColor3 = T.TextDim,
            FontFace = F.Regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
    end
    local trailing = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 32, 0, 28), BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = row,
    })
    Corner(trailing, 8); Stroke(trailing, T.BorderLow, 1)
    local trIcon = MakeIcon(trailing, trailingIcon or "copy", 14, T.TextDim)
    trIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    trIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    trailing.MouseEnter:Connect(function() Tween(trailing, { BackgroundColor3 = T.CardHover }, 0.15) end)
    trailing.MouseLeave:Connect(function() Tween(trailing, { BackgroundColor3 = T.CardAlt }, 0.15) end)
    trailing.MouseButton1Click:Connect(function() Ripple(trailing, T.Text); safe(cb) end)
    return row
end
if DISCORD then
    LinkRow(linksCard, "message-circle", "Community", DISCORD, "copy", function()
        if Copy(DISCORD) then Notify({ title = "Community", body = "Link copied.", color = T.Success }) end
    end)
end
LinkRow(linksCard, "checklist","Feature list", "Jump to the first feature page", "chevron_right", function()
    UI._selectPage(firstFeaturePage())
end)

end)()

-- ============================================================================
-- SETTINGS PAGE (two columns: Menu + Configs | Appearance + Themes + Panic)
-- ============================================================================
local panic, loadNamed
;(function()
local settingsPage = MakePage("settings", "Settings", "settings")

local twoColRow = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = settingsPage,
})
HList(twoColRow, 14, Enum.VerticalAlignment.Top)
local leftCol = New("Frame", {
    Size = UDim2.new(0.5, -7, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = twoColRow,
})
VList(leftCol, 14)
local rightCol = New("Frame", {
    Size = UDim2.new(0.5, -7, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, Parent = twoColRow,
})
VList(rightCol, 14)

-- panic: stop whatever the game scripts registered, then take the whole UI away
local PanicHooks = {}
UI._registerPanic = function(fn) PanicHooks[#PanicHooks + 1] = fn end
function panic()
    for _, fn in ipairs(PanicHooks) do pcall(fn) end
    if closeWindow then closeWindow() end
    hideIsland()
    task.delay(0.45, function() if genv[CLEAN] then genv[CLEAN]() end end)
end

local function refreshControls()
    for key, ctl in pairs(Ctl) do
        local v = Config[key]
        if v ~= nil and ctl.Set then pcall(ctl.Set, ctl, v) end
    end
    UI._refreshBound()
    if Apply.identity then Apply.identity() end
end

-- ---------------------------------------------------------------- Menu
local menuBody = TitledCard(leftCol, "Menu", "monitor")
Ctl.toggleKey = KeybindRow(menuBody, "Toggle UI", Config.toggleKey, function(name)
    Config.toggleKey = name; SaveConfig(); hidePillLabel.Text = keyShort(name)
    islHint.Text = "Click or press " .. keyShort(name) .. " to open"
end)
Ctl.toggleButton = Dropdown(menuBody, "Toggle button", { "Mobile only", "Always", "Never" }, Config.toggleButton, function(v)
    Config.toggleButton = v; SaveConfig(); Apply.toggleButton()
end)
Ctl.antiAfk = Toggle(menuBody, "Anti AFK", Config.antiAfk, function(v)
    Config.antiAfk = v; SaveConfig()
    Notify({ title = "Anti AFK", body = v and "Enabled." or "Disabled.", color = v and T.Success or T.TextDim })
end)
Ctl.autoReconnect = Toggle(menuBody, "Auto Reconnect", Config.autoReconnect, function(v) Config.autoReconnect = v; SaveConfig() end)
Ctl.reconnectDelay = Slider(menuBody, "Reconnect Delay", 1, 30, Config.reconnectDelay, function(v) Config.reconnectDelay = v; SaveConfig() end, "s")
Ctl.disable3d = Toggle(menuBody, "Disable 3D Rendering", Config.disable3d, function(v) Config.disable3d = v; SaveConfig(); Apply.render3d() end)
Ctl.minimizeOnStart = Toggle(menuBody, "Minimize UI on Start", Config.minimizeOnStart, function(v) Config.minimizeOnStart = v; SaveConfig() end)
Button(menuBody, "Reset window (center, default size)", function()
    Config.winX, Config.winY, Config.winW, Config.winH = 0, 0, WINDOW_W, WINDOW_H; SaveConfig()
    Tween(window, { Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H) }, 0.4, Enum.EasingStyle.Quint)
    task.delay(0.42, Apply.scale)
end, nil, "expand")
Button(menuBody, "Unload", function()
    Notify({ title = BRAND, body = "Unloading…", color = T.Error })
    task.wait(0.4)
    if genv[CLEAN] then genv[CLEAN]() end
end, nil, "unload")

-- ---------------------------------------------------------------- Configs
local configsBody = TitledCard(leftCol, "Configs", "folder")
local CFG_NS = (CONFIG_FILE:gsub("%.json$", ""))
local CFG_DIR = "Okuma/Configs/" .. CFG_NS
-- where things are on screen is not part of a config
local EXCLUDE = { themes = true, defaultTheme = true, autoLoad = true, cardsClosed = true, cardsPopped = true,
    winX = true, winY = true, winW = true, winH = true, lastPage = true }
local function ensureDirs()
    pcall(function()
        if not isfolder("Okuma") then makefolder("Okuma") end
        if not isfolder("Okuma/Configs") then makefolder("Okuma/Configs") end
        if not isfolder(CFG_DIR) then makefolder(CFG_DIR) end
    end)
end
local function cleanName(n)
    n = tostring(n or "")
    n = n:gsub("[^%w%-_ ]", "")
    n = n:gsub("^%s+", "")
    n = n:gsub("%s+$", "")
    return n:sub(1, 32)
end
local function cfgPath(name) return CFG_DIR .. "/" .. name .. ".json" end
-- volatile keys (UI.volatile) stay out of named configs too: an auto-loaded config must not start a bot
local function snapshot()
    local s = {}
    for k, v in pairs(Config) do if not EXCLUDE[k] and not UI._volatile[k] then s[k] = v end end
    return s
end
local function listConfigs()
    local out = {}
    ensureDirs()
    local ok, files = pcall(listfiles, CFG_DIR)
    if ok and type(files) == "table" then
        for _, f in ipairs(files) do
            local n = tostring(f):match("([^/\\]+)%.json$")
            if n then out[#out + 1] = n end
        end
    end
    table.sort(out)
    return out
end

local selectedCfg = nil
local cfgList = New("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = T.BgDeep, BorderSizePixel = 0, ScrollBarThickness = 3,
    ScrollBarImageColor3 = T.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = configsBody,
})
Corner(cfgList, 8); Stroke(cfgList, T.BorderLow, 1); Padding(cfgList, 6, 6, 6, 6); VList(cfgList, 3)
local cfgEmpty = New("TextLabel", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "no configs yet",
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, Parent = cfgList })
local cfgInfo = New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "", TextColor3 = T.TextDim,
    FontFace = F.Regular, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = configsBody })
New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Config name", TextColor3 = T.Text,
    FontFace = F.Medium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = configsBody })
local cfgNameBox = WideInput(configsBody, "Type config name here...", "")

local autoLoadToggle
local function refreshCfgList()
    for _, c in ipairs(cfgList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
    local names = listConfigs()
    cfgEmpty.Visible = #names == 0
    for _, n in ipairs(names) do
        local isSel = n == selectedCfg
        local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = isSel and T.CardHover or T.CardAlt,
            BorderSizePixel = 0, Text = n, TextColor3 = isSel and T.Text or T.TextDim, FontFace = F.Medium, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, Parent = cfgList })
        Corner(b, 6); Padding(b, 10, 10, 0, 0)
        b.MouseEnter:Connect(function() if n ~= selectedCfg then Tween(b, { BackgroundColor3 = T.CardHover }, 0.1) end end)
        b.MouseLeave:Connect(function() if n ~= selectedCfg then Tween(b, { BackgroundColor3 = T.CardAlt }, 0.1) end end)
        b.MouseButton1Click:Connect(function() selectedCfg = n; cfgNameBox.Text = n; refreshCfgList() end)
    end
    cfgInfo.Text = ("%d saved  ·  selected: %s  ·  auto: %s"):format(#names, selectedCfg or "none", Config.autoLoad ~= "" and Config.autoLoad or "none")
    if autoLoadToggle then autoLoadToggle:Set(Config.autoLoad ~= "" and Config.autoLoad == selectedCfg) end
end

local colorRows, palSpec, useSpec, refreshThemes
local function copyPal(p)
    return { accent = { table.unpack(p.accent) }, background = { table.unpack(p.background) }, surface = { table.unpack(p.surface) },
        text = { table.unpack(p.text) }, muted = { table.unpack(p.muted) } }
end
local function applyLoaded(tbl)
    for k, v in pairs(tbl) do if not EXCLUDE[k] and not UI._volatile[k] then Config[k] = v end end
    if tbl.customPal == nil then Config.customPal = nil end
    SaveConfig()
    palSpec = copyPal(paletteSpec())
    Apply.theme(palSpec)
    if refreshThemes then refreshThemes(true) end
    refreshControls()
    Apply.all()
end
local function saveNamed(name)
    name = cleanName(name)
    if name == "" then
        Notify({ title = "Configs", body = "Type a name first.", color = T.Warning, icon = "alert-triangle" }); return
    end
    ensureDirs()
    local ok = pcall(writefile, cfgPath(name), HttpService:JSONEncode(snapshot()))
    if ok then selectedCfg = name; cfgNameBox.Text = name end
    refreshCfgList()
    Notify({ title = ok and "Config saved" or "Configs", body = ok and name or "Could not write the file.",
        color = ok and T.Success or T.Error, icon = ok and "check" or "x" })
end
function loadNamed(name, quiet)
    if not name or name == "" then
        if not quiet then Notify({ title = "Configs", body = "Select a config first.", color = T.Warning, icon = "alert-triangle" }) end
        return false
    end
    local ok, raw = pcall(readfile, cfgPath(name))
    local okD, tbl = false, nil
    if ok and raw then okD, tbl = pcall(function() return HttpService:JSONDecode(raw) end) end
    if not (okD and type(tbl) == "table") then
        if not quiet then Notify({ title = "Configs", body = "Could not read " .. name .. ".", color = T.Error, icon = "x" }) end
        return false
    end
    applyLoaded(tbl)
    if not quiet then Notify({ title = "Config loaded", body = name, color = T.Accent, icon = "check" }) end
    return true
end
ButtonRow(configsBody, {
    { label = "Save", cb = function() saveNamed(cfgNameBox.Text ~= "" and cfgNameBox.Text or selectedCfg) end },
    { label = "Load", cb = function() loadNamed(selectedCfg or cleanName(cfgNameBox.Text)) end },
})
ButtonRow(configsBody, {
    { label = "Delete", confirm = true, cb = function()
        local n = selectedCfg
        if not n then Notify({ title = "Configs", body = "Select a config first.", color = T.Warning, icon = "alert-triangle" }); return end
        pcall(delfile, cfgPath(n))
        if Config.autoLoad == n then Config.autoLoad = ""; SaveConfig() end
        selectedCfg = nil; cfgNameBox.Text = ""; refreshCfgList()
        Notify({ title = "Config deleted", body = n, color = T.Error, icon = "x" })
    end },
    { label = "Refresh", cb = function() refreshCfgList() end },
})
autoLoadToggle = Toggle(configsBody, "Auto load the selected config", Config.autoLoad ~= "", function(v)
    if v then
        if selectedCfg then Config.autoLoad = selectedCfg
        else
            Notify({ title = "Configs", body = "Select a config first.", color = T.Warning, icon = "alert-triangle" })
            task.defer(function() autoLoadToggle:Set(false) end)
        end
    else
        Config.autoLoad = ""
    end
    SaveConfig(); refreshCfgList()
end)
New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "more", TextColor3 = T.TextMute,
    FontFace = F.Regular, TextSize = 10, Parent = configsBody })
local RESET_KEYS = { uiScale = 100, adaptive = true, cornerRadius = 10, density = "Default", dim = true, blur = true, transparent = false,
    dragStyle = "Outline", island = "Show on Hover", weather = "None", weatherMode = "Screen", bgMode = "None", bgImage = "",
    bgOpacity = 65, preset = "Mono" }
ButtonRow(configsBody, {
    { label = "Rename", cb = function()
        local old, new = selectedCfg, cleanName(cfgNameBox.Text)
        if not old or new == "" or new == old then
            Notify({ title = "Configs", body = "Select a config and type the new name.", color = T.Warning, icon = "alert-triangle" }); return
        end
        local ok, raw = pcall(readfile, cfgPath(old))
        if ok and raw and pcall(writefile, cfgPath(new), raw) then
            pcall(delfile, cfgPath(old))
            if Config.autoLoad == old then Config.autoLoad = new; SaveConfig() end
            selectedCfg = new; refreshCfgList()
            Notify({ title = "Config renamed", body = old .. "  →  " .. new, icon = "check" })
        end
    end },
    { label = "Reset", confirm = true, cb = function()
        for k, v in pairs(RESET_KEYS) do Config[k] = v end
        Config.customPal = nil
        SaveConfig(); palSpec = copyPal(paletteSpec())
        Apply.theme(palSpec)
        if refreshThemes then refreshThemes(true) end
        refreshControls(); Apply.all()
        Notify({ title = "Appearance", body = "Back to the defaults.", color = T.Accent, icon = "check" })
    end },
})
New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "share", TextColor3 = T.TextMute,
    FontFace = F.Regular, TextSize = 10, Parent = configsBody })
Button(configsBody, "Copy code", function()
    local code = "OKM1:" .. b64enc(HttpService:JSONEncode(snapshot()))
    if Copy(code) then Notify({ title = "Config code", body = "Copied (" .. #code .. " characters).", color = T.Success })
    else Notify({ title = "Config code", body = "Clipboard unavailable.", color = T.Error, icon = "x" }) end
end, nil, "copy")
local importBox = WideInput(configsBody, "paste a config code...", "")
Button(configsBody, "Import code", function()
    local code = importBox.Text:gsub("%s", "")
    if code:sub(1, 5) ~= "OKM1:" then
        Notify({ title = "Import", body = "That is not a valid config code.", color = T.Error, icon = "x" }); return
    end
    local ok, tbl = pcall(function() return HttpService:JSONDecode(b64dec(code:sub(6))) end)
    if ok and type(tbl) == "table" then
        applyLoaded(tbl); importBox.Text = ""
        Notify({ title = "Config imported", body = "Settings applied.", color = T.Success, icon = "check" })
    else
        Notify({ title = "Import", body = "The code could not be read.", color = T.Error, icon = "x" })
    end
end, nil, "folder")
refreshCfgList()

-- ---------------------------------------------------------------- Appearance
local appBody = TitledCard(rightCol, "Appearance", "overview")
Ctl.weather = Dropdown(appBody, "Weather", { "None", "Snow", "Rain" }, Config.weather, function(v) Config.weather = v; SaveConfig(); Apply.weather() end)
Ctl.weatherMode = Dropdown(appBody, "Weather Mode", { "Screen", "Window" }, Config.weatherMode, function(v) Config.weatherMode = v; SaveConfig(); Apply.weather() end)
Ctl.dim = Toggle(appBody, "Dim", Config.dim, function(v) Config.dim = v; SaveConfig(); Apply.dim() end)
Ctl.blur = Toggle(appBody, "Blur", Config.blur, function(v) Config.blur = v; SaveConfig(); Apply.blur() end, { tip = "Blur the game behind the open window" })
Ctl.transparent = Toggle(appBody, "Transparent", Config.transparent, function(v) Config.transparent = v; SaveConfig(); Apply.transparent() end)
Ctl.dragStyle = Dropdown(appBody, "Drag Style", { "Live", "Outline" }, Config.dragStyle, function(v) Config.dragStyle = v; SaveConfig() end)
Ctl.island = Dropdown(appBody, "Dynamic Island", { "Show on Hover", "Compact only", "Hidden" }, Config.island, function(v) Config.island = v; SaveConfig(); Apply.island() end)
Ctl.adaptive = Toggle(appBody, "Adaptive Size", Config.adaptive, function(v) Config.adaptive = v; SaveConfig(); Apply.scale() end)
Ctl.uiScale = Slider(appBody, "UI Scale", 60, 140, Config.uiScale, function(v) Config.uiScale = v; SaveConfig(); Apply.scale() end, "%")
Ctl.density = Dropdown(appBody, "Density", { "Compact", "Default", "Comfortable" }, Config.density, function(v) Config.density = v; SaveConfig(); Apply.density() end)
Ctl.cornerRadius = Slider(appBody, "Corner Radius", 2, 20, Config.cornerRadius, function(v) Config.cornerRadius = v; SaveConfig(); Apply.radius() end, "px")
Ctl.bgMode = Dropdown(appBody, "Background", { "None", "Image" }, Config.bgMode, function(v) Config.bgMode = v; SaveConfig(); Apply.background() end)
local bgRow = New("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = appBody })
HList(bgRow, 8)
local bgBox, bgBoxFrame = WideInput(bgRow, "image id or url", Config.bgImage)
bgBoxFrame.Size = UDim2.new(1, -66, 1, 0)
local bgSet = New("TextButton", { Size = UDim2.new(0, 58, 1, 0), BackgroundColor3 = T.CardAlt, BorderSizePixel = 0, Text = "Set",
    TextColor3 = T.Text, FontFace = F.Medium, TextSize = 12, AutoButtonColor = false, Parent = bgRow })
Corner(bgSet, 8); Stroke(bgSet, T.BorderLow, 1)
bgSet.MouseEnter:Connect(function() Tween(bgSet, { BackgroundColor3 = T.CardHover }, 0.12) end)
bgSet.MouseLeave:Connect(function() Tween(bgSet, { BackgroundColor3 = T.CardAlt }, 0.12) end)
bgSet.MouseButton1Click:Connect(function()
    Ripple(bgSet, T.Text)
    Config.bgImage = bgBox.Text; Config.bgMode = "Image"; SaveConfig()
    if Ctl.bgMode then Ctl.bgMode:Set("Image") end
    Apply.background()
end)
Ctl.bgOpacity = Slider(appBody, "Background Opacity", 10, 100, Config.bgOpacity, function(v) Config.bgOpacity = v; SaveConfig(); Apply.opacity() end, "%")

-- ---------------------------------------------------------------- Themes
local themesBody = TitledCard(rightCol, "Themes", "palette")
palSpec = copyPal(paletteSpec())
colorRows = {}
useSpec = function(spec, asCustom)
    palSpec = copyPal(spec)
    Config.customPal = asCustom and copyPal(spec) or nil
    SaveConfig()
    Apply.theme(palSpec)
    for key, row in pairs(colorRows) do row:Set(c3(palSpec[key])) end
end
Ctl.preset = Dropdown(themesBody, "Preset", PALETTE_NAMES, Config.preset, function(v)
    Config.preset = v; useSpec(PALETTES[v], false)
    Notify({ title = "Theme", body = "Preset set to " .. v .. ".", color = T.Accent })
end)
local themeNameBox = WideInput(themesBody, "theme name", "")
local selectedTheme = nil
local themeDrop
local defaultLbl
local function sortedThemes()
    local list = {}
    for n in pairs(Config.themes or {}) do list[#list + 1] = n end
    table.sort(list)
    return list
end
refreshThemes = function(keepSelection)
    if not themeDrop then return end
    local list = sortedThemes()
    if not (keepSelection and selectedTheme and (Config.themes or {})[selectedTheme]) then selectedTheme = list[1] end
    themeDrop:SetOptions(#list > 0 and list or { "no themes" })
    themeDrop:Set(selectedTheme or "no themes")
    if defaultLbl then defaultLbl.Text = "Default theme: " .. (Config.defaultTheme ~= "" and Config.defaultTheme or "none") end
    for key, row in pairs(colorRows) do row:Set(c3(palSpec[key])) end
end
Button(themesBody, "Create", function()
    local n = cleanName(themeNameBox.Text)
    if n == "" then Notify({ title = "Theme", body = "Type a name first.", color = T.Warning, icon = "alert-triangle" }); return end
    Config.themes = Config.themes or {}
    Config.themes[n] = copyPal(palSpec); SaveConfig()
    selectedTheme = n; themeNameBox.Text = ""
    refreshThemes(true)
    Notify({ title = "Theme created", body = n, color = T.Success })
end)
themeDrop = Dropdown(themesBody, "Theme", { "no themes" }, "no themes", function(v) if v ~= "no themes" then selectedTheme = v end end)
ButtonRow(themesBody, {
    { label = "Save", cb = function()
        if not selectedTheme or not (Config.themes or {})[selectedTheme] then
            Notify({ title = "Theme", body = "Create or select a theme first.", color = T.Warning, icon = "alert-triangle" }); return
        end
        Config.themes[selectedTheme] = copyPal(palSpec); SaveConfig()
        Notify({ title = "Theme saved", body = selectedTheme, color = T.Success })
    end },
    { label = "Load", cb = function()
        local spec = selectedTheme and (Config.themes or {})[selectedTheme]
        if not spec then Notify({ title = "Theme", body = "Nothing selected.", color = T.Warning, icon = "alert-triangle" }); return end
        useSpec(spec, true)
        Notify({ title = "Theme loaded", body = selectedTheme, color = T.Accent })
    end },
})
ButtonRow(themesBody, {
    { label = "Delete", confirm = true, cb = function()
        if not selectedTheme or not (Config.themes or {})[selectedTheme] then return end
        local n = selectedTheme
        Config.themes[n] = nil
        if Config.defaultTheme == n then Config.defaultTheme = "" end
        SaveConfig(); selectedTheme = nil; refreshThemes(false)
        Notify({ title = "Theme deleted", body = n, color = T.Error, icon = "x" })
    end },
    { label = "Set Default", cb = function()
        if not selectedTheme or not (Config.themes or {})[selectedTheme] then
            Notify({ title = "Theme", body = "Select a theme first.", color = T.Warning, icon = "alert-triangle" }); return
        end
        Config.defaultTheme = selectedTheme; SaveConfig(); refreshThemes(true)
        Notify({ title = "Default theme", body = selectedTheme .. " will load on start.", color = T.Accent })
    end },
})
defaultLbl = New("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Default theme: none",
    TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = themesBody })
-- the picker reports every drag step, and a theme change walks the whole UI: repaint at most every 0.1 s,
-- always with the latest colours
local themeQueued = false
local function colorRow(label, key)
    colorRows[key] = UI.colorPicker(themesBody, label, c3(palSpec[key]), function(c)
        palSpec[key] = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
        Config.customPal = copyPal(palSpec); SaveConfig()
        if themeQueued then return end
        themeQueued = true
        task.delay(0.1, function() themeQueued = false; Apply.theme(palSpec) end)
    end)
end
colorRow("Accent", "accent")
colorRow("Background", "background")
colorRow("Surface", "surface")
colorRow("Text", "text")
colorRow("Muted text", "muted")
refreshThemes(false)

-- ---------------------------------------------------------------- Panic
local panicBody = TitledCard(rightCol, "Panic", "shield")
Ctl.panicKey = KeybindRow(panicBody, "Panic key", Config.panicKey, function(name) Config.panicKey = name; SaveConfig() end, true)
Button(panicBody, "Panic now (stop everything)", panic, nil, "alert-triangle")


end)()

-- ============================================================================

-- boot: call once, after every tab has been added
UI.start = function()
    if UI._started then return end
    UI._started = true
-- the Settings entry always goes last in the sidebar
AddNavItem("settings", "Settings",   "settings")

-- the page open when the script last ran (Home the first time, or when that page no longer exists)
UI._selectPage((Config.lastPage and pages[Config.lastPage]) and Config.lastPage or "home")

-- ============================================================================
-- SEARCH: every row, button and card title of every page, plus the pages themselves.
-- Typing lists matches under the search box; choosing one opens its page, scrolls to it and
-- makes it pulse. The sidebar still filters as you type.
-- ============================================================================
;(function()
    local panel = New("CanvasGroup", {
        Name = "SearchResults", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 320, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, BorderSizePixel = 0,
        Visible = false, GroupTransparency = 1, ZIndex = 60, Parent = content,
    })
    Corner(panel, 10); Stroke(panel, T.Border, 1); Padding(panel, 6, 6, 6, 6); VList(panel, 2)

    local results = {}
    -- the page a control sits on; a control in a card popped out of the window has none ("popped" instead)
    local function pageOf(inst)
        for id, p in pairs(pages) do
            if inst:IsDescendantOf(p.frame) then return id, p.title end
        end
        if inst:FindFirstAncestor("PoppedCard") then return "popped", "Popped card" end
    end
    local function place()
        local sc = math.max(windowScale.Scale, 0.01)
        local rel = (searchBox.AbsolutePosition - content.AbsolutePosition) / sc
        panel.Position = UDim2.fromOffset(rel.X + searchBox.AbsoluteSize.X / sc, rel.Y + searchBox.AbsoluteSize.Y / sc + 6)
    end
    local function show()
        place()
        panel.Visible = true
        Tween(panel, { GroupTransparency = 0 }, 0.15)
    end
    local function hide()
        Tween(panel, { GroupTransparency = 1 }, 0.12)
        task.delay(0.14, function() if panel.GroupTransparency >= 0.99 then panel.Visible = false end end)
    end
    local function flash(inst)
        local f = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = T.Accent, BackgroundTransparency = 0.82,
            BorderSizePixel = 0, ZIndex = 20, Parent = inst })
        Corner(f, 8)
        Tween(f, { BackgroundTransparency = 1 }, 1.4, Enum.EasingStyle.Sine)
        task.delay(1.5, function() f:Destroy() end)
    end
    local function goTo(item)
        hide()
        searchInput.Text = ""
        if not item then return end
        -- a popped-out card floats on screen already: just make it pulse
        if item.page == "popped" then
            if item.inst and item.inst.Parent then flash(item.inst) end
            return
        end
        UI._selectPage(item.page)
        if item.inst then
            task.delay(0.5, function()
                if item.inst and item.inst.Parent then
                    local sc = math.max(windowScale.Scale, 0.01)
                    local target = (item.inst.AbsolutePosition.Y - body.AbsolutePosition.Y) / sc + body.CanvasPosition.Y
                    body.CanvasPosition = Vector2.new(0, math.max(0, target - 24))
                    flash(item.inst)
                end
            end)
        end
    end

    -- the part of a result that matches what was typed is drawn in full text color and bold, the rest dimmed
    local lastQ = ""
    local function esc(s) return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end
    local function highlight(label)
        local s, e = label:lower():find(lastQ, 1, true)
        if lastQ == "" or not s then return esc(label) end
        return esc(label:sub(1, s - 1)) .. ('<font color="%s"><b>%s</b></font>'):format(toHex(T.Text), esc(label:sub(s, e)))
            .. esc(label:sub(e + 1))
    end

    -- arrow keys move the highlighted result, Enter opens it
    local sel, rows = 1, {}
    local function paintSel()
        for i, b in ipairs(rows) do
            b.BackgroundColor3 = T.CardHover
            Tween(b, { BackgroundTransparency = (i == sel) and 0 or 1 }, 0.1)
        end
    end
    local function render()
        for _, c in ipairs(panel:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        rows, sel = {}, 1
        if #results == 0 then
            New("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Nothing found",
                TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 12, Parent = panel })
            return
        end
        for i = 1, math.min(8, #results) do
            local item = results[i]
            local b = New("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.Card, BackgroundTransparency = 1,
                BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = panel })
            Corner(b, 8)
            New("TextLabel", { Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1,
                Text = highlight(item.label), RichText = true, TextColor3 = T.TextDim, FontFace = F.Medium, TextSize = 12,
                TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
            New("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, 96, 1, 0),
                BackgroundTransparency = 1, Text = item.kind, TextColor3 = T.TextDim, FontFace = F.Regular, TextSize = 10,
                TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
            rows[i] = b
            b.MouseEnter:Connect(function() sel = i; paintSel() end)
            b.MouseButton1Click:Connect(function() goTo(item) end)
        end
        paintSel()
    end
    Track(UserInputService.InputBegan:Connect(function(input)
        local k = input.KeyCode
        -- Ctrl+F jumps into the search box while the window is open
        if k == Enum.KeyCode.F and windowOpen and not searchInput:IsFocused() and not UserInputService:GetFocusedTextBox()
            and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            searchInput:CaptureFocus()
            return
        end
        if not searchInput:IsFocused() then return end
        -- Esc empties it
        if k == Enum.KeyCode.Escape then searchInput.Text = ""; searchInput:ReleaseFocus(); return end
        if #rows == 0 then return end
        if k == Enum.KeyCode.Down then sel = sel % #rows + 1; paintSel()
        elseif k == Enum.KeyCode.Up then sel = (sel - 2) % #rows + 1; paintSel() end
    end))
    searchInput.PlaceholderText = "Search  (Ctrl+F)"

    local function search(q)
        lastQ = q
        results = {}
        if q == "" then return end
        local seen = {}
        for id, p in pairs(pages) do
            if p.title:lower():find(q, 1, true) then results[#results + 1] = { label = p.title, kind = "Page", page = id, rank = 0 } end
        end
        for _, it in ipairs(SearchIndex) do
            if it.inst and it.inst.Parent then
                local l = it.label:lower()
                local s = l:find(q, 1, true)
                if s then
                    local page, title = pageOf(it.inst)
                    local key = tostring(page) .. "|" .. l
                    if page and not seen[key] then
                        seen[key] = true
                        results[#results + 1] = { label = it.label, kind = title, page = page, inst = it.inst, rank = (s == 1) and 1 or 2 }
                    end
                end
            end
        end
        table.sort(results, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.label < b.label
        end)
    end

    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        local raw = searchInput.Text
        local q = raw:lower()
        q = q:gsub("^%s+", "")
        q = q:gsub("%s+$", "")
        -- the sidebar keeps filtering as before
        for id, ref in pairs(navRefs) do
            local title = string.lower(ref.labelObj.Text)
            ref.button.Visible = (q == "") or (string.find(title, q, 1, true) ~= nil)
        end
        placeNavHL(activePageId, true)
        if q == "" then hide() return end
        search(q); render(); show()
    end)
    searchInput.Focused:Connect(function()
        if searchInput.Text ~= "" then place(); show() end
    end)
    searchInput.FocusLost:Connect(function(enterPressed)
        if enterPressed and results[sel] then goTo(results[sel]); return end
        task.delay(0.2, hide)
    end)
end)()

-- ============================================================================
-- ANTI AFK (real)
-- ============================================================================
Track(LocalPlayer.Idled:Connect(function()
    if not Config.antiAfk then return end
    pcall(function()
        local vu = game:GetService("VirtualUser")
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
end))

local customIslandText = nil
hidePillLabel.Text = keyShort(Config.toggleKey)
islHint.Text = "Click or press " .. keyShort(Config.toggleKey) .. " to open"
-- ============================================================================
-- LIVE DATA
-- ============================================================================
do
local frames, lastTime = 0, tick()
Track(RunService.RenderStepped:Connect(function()
    frames = frames + 1
    local now = tick()
    if now - lastTime >= 1 then
        liveFps = math.floor(frames / (now - lastTime) + 0.5)
        pushFps(liveFps)
        frames = 0; lastTime = now
    end
end))
end

task.spawn(function()
    while gui.Parent do
        local ok, ping = pcall(function()
            return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        if ok and type(ping) == "number" then
            livePing = ping
            pushPing(ping)
            updateIslandBars()
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while gui.Parent do
        local text = sessionText()
        if sessionLbl then sessionLbl.Text = text end
        if playersLbl then playersLbl.Text = ("%d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers) end
        if islandExpanded then updateIslandCard() end
        if islandShown and not customIslandText and not UI._islFlashing then setPillText(BRAND .. " · " .. currentTabTitle()) end
        if islandShown and UI._pillTick then UI._pillTick() end
        task.wait(0.5)
    end
end)

-- game scripts can put their own words in the pill: UI._setIslandText("Farming  ·  42 coins")
UI._setIslandText = function(text)
    customIslandText = text
    UI._customIsl = text
    if islandShown then setPillText(text or (BRAND .. " · " .. currentTabTitle())) end
end

-- ============================================================================
-- KEYS, RECONNECT AND CLEANUP
-- ============================================================================
-- keys are named like the key pills store them: a KeyCode name, or "MouseButton2" / "MouseButton3"
Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp or listeningKey then return end
    local ut = input.UserInputType
    local n
    if ut == Enum.UserInputType.Keyboard then n = input.KeyCode.Name
    elseif ut == Enum.UserInputType.MouseButton2 or ut == Enum.UserInputType.MouseButton3 then n = ut.Name
    else return end
    -- a slider under the mouse takes Left / Right
    if UI._sliderNudge and windowOpen and (n == "Left" or n == "Right") then
        UI._sliderNudge(n == "Left" and -1 or 1, UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
        return
    end
    if n == Config.toggleKey then
        toggleWindow()
    elseif Config.panicKey ~= "None" and n == Config.panicKey then
        panic()
        return
    end
    -- toggles built with {hotkey=}: a press flips them, or with {hold=true} turns them on until the key is let go
    for _, h in ipairs(UI._hotkeys) do
        if Config[h.key] == n and h.row.Parent then
            if h.hold then h.set(true) else h.fire() end
        end
    end
end))
Track(UserInputService.InputEnded:Connect(function(input)
    if listeningKey then return end
    local ut = input.UserInputType
    local n = (ut == Enum.UserInputType.Keyboard) and input.KeyCode.Name or ut.Name
    for _, h in ipairs(UI._hotkeys) do
        if h.hold and Config[h.key] == n and h.row.Parent then h.set(false) end
    end
end))

-- auto reconnect: only when an error message really appears (it also changes when cleared), and once per
-- disconnect; the toggle is checked again when the delay is up
pcall(function()
    local GuiService = game:GetService("GuiService")
    Track(GuiService.ErrorMessageChanged:Connect(function()
        if not Config.autoReconnect or UI._reconnecting then return end
        local ok, msg = pcall(function() return GuiService:GetErrorMessage() end)
        if ok and (msg == nil or msg == "") then return end
        UI._reconnecting = true
        UI.log("warn", "disconnected: " .. tostring(msg) .. "  (reconnecting)")
        task.delay(math.max(1, Config.reconnectDelay or 5), function()
            if Config.autoReconnect then pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end) end
            task.delay(10, function() UI._reconnecting = false end)
        end)
    end))
end)

genv[CLEAN] = function()
    for _, fn in ipairs(UI._cleanups) do pcall(fn) end
    -- a save still waiting goes out now, and a re-run's fresh settings are never overwritten later
    if UI._saveQueued then pcall(SaveConfig, true) end
    UI._saveDead = true
    for _, c in ipairs(Connections) do pcall(function() c:Disconnect() end) end
    table.clear(Connections)
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
    pcall(function() gui:Destroy() end)
    genv[CLEAN] = nil
end

-- start: the saved settings are applied first, then the window opens (or the island shows)
Apply.all()
Apply.identity()
if Config.autoLoad ~= "" then pcall(loadNamed, Config.autoLoad, true) end
booting = false
if Config.minimizeOnStart then
    task.delay(0.5, showIsland)
else
    task.delay(0.35, openWindow)
end

task.delay(1.1, function()
    Notify({ title = BRAND, body = "UI loaded. Press " .. keyShort(Config.toggleKey) .. " to hide or show.", color = T.Success })
end)

end
UI.open, UI.toggleWindow, UI.unload = openWindow, toggleWindow, function() if genv[CLEAN] then genv[CLEAN]() end end
return UI
end

-- ============================================================================
-- PUBLIC API  (everything above is the shell; everything below is what you call)
-- ============================================================================
local UIS = game:GetService("UserInputService")
local Okuma = { version = "1.0.0" }
local Win, Tab, Card = {}, {}, {}
Win.__index, Tab.__index, Card.__index = Win, Tab, Card

local function slug(s)
    s = tostring(s):gsub("[^%w]+", "_")
    s = s:gsub("^_+", ""):gsub("_+$", "")
    return s
end
local function hex(c)
    return ("#%02X%02X%02X"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function persisted(opts) return not (type(opts) == "table" and opts.save == false) end

-- ---------------------------------------------------------------- window
function Okuma.new(opts)
    local UI = build(opts)
    return setmetatable({ UI = UI, Config = UI.config, started = false, _ids = {}, _keys = {}, _inits = {} }, Win)
end
-- API para editar o Logo / Brand ao vivo
function UI.setBrand(opts)
    if opts.layout then Config.brandLayout = opts.layout end
    if opts.logoSize then Config.brandLogoSize = opts.logoSize end
    if opts.height then Config.brandHeight = opts.height end
    if opts.titleSize then Config.brandTitleSize = opts.titleSize end
    if opts.subtitle then Config.brandSubtitle = opts.subtitle end
    
    if opts.title then
        BRAND = opts.title
        brandTitle.Text = BRAND
        headerTitle.Text = "Welcome to " .. BRAND .. "!"
    end
    
    if opts.logoId then
        ICONS.logo = "rbxassetid://" .. tostring(opts.logoId):match("%d+")
        brandIcon:Destroy()
        brandIcon = MakeIcon(brandIconHolder, "logo", Config.brandLogoSize, T.Text)
        brandIcon.Size = UDim2.new(1, 0, 1, 0)
        Corner(brandIcon, math.floor(Config.brandLogoSize * 0.3))
    end
    
    Apply.brand()
    SaveConfig()
end

-- Se quiser mudar o ícone do app no topo (Home)
function UI.setHeaderIcon(id)
    ICONS.header = "rbxassetid://" .. tostring(id):match("%d+")
    if headerIcon and headerIcon.Parent then headerIcon:Destroy() end
    headerIcon = MakeIcon(header, ICONS.header, 24, T.Text)
    headerIcon.Position = UDim2.new(0, 0, 0.5, -12)
end
function Win:Tab(name, icon)
    local base = slug(name):lower()
    if base == "" then base = "tab" end
    local id, n = base, 1
    while id == "home" or id == "settings" or self._ids[id] do n = n + 1; id = base .. "_" .. n end
    self._ids[id] = true
    icon = icon or "overview"
    return setmetatable({ win = self, id = id, name = name, icon = icon, page = self.UI.page(id, name, icon) }, Tab)
end

function Win:Start()
    if self.started then return self end
    self.started = true
    self.UI.start()
    local list = self._inits
    self._inits = {}
    for _, item in ipairs(list) do self:_run(item) end
    return self
end

function Win:_run(item)
    local ok, v = pcall(item.get)
    if ok and v ~= nil then self.UI.safe(item.cb, v) end
end
function Win:_reg(ctl, cb, opts, get)
    if cb and not (type(opts) == "table" and opts.init == false) then
        local item = { cb = cb, get = get or function() return ctl:Get() end }
        if self.started then self:_run(item) else self._inits[#self._inits + 1] = item end
    end
    return ctl
end
function Win:_key(card, label, opts)
    local k = type(opts) == "table" and opts.key
    if not k then
        local base = card.tab.id .. "_" .. slug(card.title) .. "_" .. slug(label)
        local n = 1
        k = base
        while self._keys[k] do n = n + 1; k = base .. "_" .. n end
    end
    k = tostring(k)
    self._keys[k] = true
    return k
end

function Win:Notify(kind, title, body, duration) self.UI.notify(kind, title, body, duration) end   -- kind: ok | warn | err | info
function Win:Get(key) return self.UI.config[key] end
function Win:Set(key, v) self.UI.config[key] = v; self.UI.save() end
function Win:Every(seconds, fn, opts) return self.UI.every(seconds, fn, opts) end                    -- pcall'd loop that stops on unload
function Win:Spawn(fn, ...) return self.UI.spawn(fn, ...) end
function Win:After(seconds, fn) return self.UI.after(seconds, fn) end
function Win:Track(connection) return self.UI.track(connection) end                                 -- disconnected on unload
function Win:OnUnload(fn) self.UI.onUnload(fn) end
function Win:OnPanic(fn) self.UI.onPanic(fn) end                                                    -- runs when the panic key is used
function Win:Island(text) self.UI.island(text) end                                                  -- text in the pill (nil = default)
function Win:Footer(text) self.UI.footer(text) end
function Win:Log(level, msg) self.UI.log(level, msg) end
function Win:Select(tab) self.UI.select(type(tab) == "table" and tab.id or tab) end
function Win:Toggle() self.UI.toggleWindow() end                                                    -- show / hide the window
function Win:Unload() self.UI.unload() end

-- ---------------------------------------------------------------- tab
function Tab:Card(title, icon)
    title = title or self.name
    return setmetatable({ win = self.win, tab = self, title = title, body = self.win.UI.card(self.page, title, icon or self.icon) }, Card)
end
function Tab:_card()
    if not self._default then self._default = self:Card(self.name) end
    return self._default
end
function Tab:Log() return self.win.UI.logCard(self.page) end
function Tab:Diagnostics() return self.win.UI.diag.card(self.page, self.win.UI.id) end

-- ---------------------------------------------------------------- controls
function Card:Toggle(label, default, cb, opts)
    local w, UI = self.win, self.win.UI
    default = default and true or false
    if not persisted(opts) then return UI.toggle(self.body, label, default, cb, opts) end
    local key = w:_key(self, label, opts)
    UI.defaults({ [key] = default })
    local c = UI.bind.toggle(self.body, label, key, cb, opts)
    c.key = key
    return w:_reg(c, cb, opts)
end

function Card:Slider(label, min, max, default, cb, opts)
    local w, UI = self.win, self.win.UI
    if type(opts) == "string" then opts = { suffix = opts } end
    opts = opts or {}
    default = math.clamp(default or min, min, max)
    if not persisted(opts) then return UI.slider(self.body, label, min, max, default, cb, opts) end
    local key = w:_key(self, label, opts)
    UI.defaults({ [key] = default })
    local c = UI.bind.slider(self.body, label, key, min, max, cb, opts)
    c.key = key
    return w:_reg(c, cb, opts)
end

function Card:Dropdown(label, options, default, cb, opts)
    local w, UI = self.win, self.win.UI
    opts = opts or {}
    if default == nil then default = opts.multi and {} or options[1] end
    if not persisted(opts) then return UI.dropdown(self.body, label, options, default, cb, opts) end
    local key = w:_key(self, label, opts)
    UI.defaults({ [key] = default })
    local c = UI.bind.dropdown(self.body, label, key, options, cb, opts)
    c.key = key
    return w:_reg(c, cb, opts)
end

function Card:Input(label, placeholder, default, cb, opts)
    local w, UI = self.win, self.win.UI
    default = default or ""
    if not persisted(opts) then return UI.input(self.body, label, placeholder, default, cb) end
    local key = w:_key(self, label, opts)
    UI.defaults({ [key] = default })
    local tb = UI.bind.input(self.body, label, key, placeholder, cb)
    return w:_reg(tb, cb, opts, function() if tb.Text ~= "" then return tb.Text end end)
end

-- Keybind(label, default, onPress, opts): onPress runs when the key is pressed; opts.changed(name) runs when it is rebound
function Card:Keybind(label, default, onPress, opts)
    local w, UI = self.win, self.win.UI
    opts = opts or {}
    default = default or "None"
    local allowNone = opts.allowNone ~= false
    local current, ctl
    if persisted(opts) then
        local key = w:_key(self, label, opts)
        UI.defaults({ [key] = default })
        ctl = UI.bind.keybind(self.body, label, key, opts.changed, allowNone, opts)
        current = function() return UI.config[key] end
    else
        local name = default
        ctl = UI.keybind(self.body, label, default, function(n) name = n; if opts.changed then opts.changed(n) end end, allowNone, opts)
        current = function() return name end
    end
    if onPress then
        w:Track(UIS.InputBegan:Connect(function(input, processed)
            if processed then return end
            if UI.isKey(input, current()) then UI.safe(onPress) end
        end))
    end
    return ctl
end

function Card:Color(label, default, cb, opts)
    local w, UI = self.win, self.win.UI
    if typeof(default) ~= "Color3" then default = Color3.new(1, 1, 1) end
    if not persisted(opts) then return UI.colorPicker(self.body, label, default, cb) end
    local key = w:_key(self, label, opts)
    UI.defaults({ [key] = hex(default) })
    local p = UI.bind.color(self.body, label, key, cb)
    return w:_reg(p, cb, opts, function() return p:Get() end)
end

function Card:Button(label, cb, opts)               -- opts: "primary" or { primary = true, icon = "copy" }
    if type(opts) == "string" then opts = { primary = opts == "primary" } end
    opts = opts or {}
    return self.win.UI.button(self.body, label, cb, opts.primary and "primary" or nil, opts.icon)
end
function Card:Buttons(list) return self.win.UI.buttonRow(self.body, list) end        -- { { label = "A", cb = fn }, ... }
function Card:Label(text, opts) return self.win.UI.paragraph(self.body, text, opts) end   -- returns the TextLabel (set .Text)
function Card:Status(label, text, opts) return self.win.UI.liveRow(self.body, label, text, opts) end   -- label + value, returns TextLabel
function Card:Progress(label, opts) return self.win.UI.progress(self.body, label, opts) end           -- returns { Set(fraction, text) }
function Card:LogView(height) return self.win.UI.logView(self.body, height) end                       -- returns { Add(text, color), Clear() }

-- controls can also be added straight on a tab (they go into one card named after the tab)
for _, m in ipairs({ "Toggle", "Slider", "Dropdown", "Input", "Keybind", "Color", "Button", "Buttons", "Label", "Status", "Progress", "LogView" }) do
    Tab[m] = function(self, ...) return Card[m](self:_card(), ...) end
end

return Okuma
