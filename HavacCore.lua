--[[
    HAVAC CORE v2.0.1 — Adapter premium sobre OkumaUI
    
    Rodar no executor:
        _G.Okuma = loadstring(game:HttpGet(".../DemoUI.lua"))()
        loadstring(game:HttpGet(".../HavacCore.lua"))()
]]

local HAVAC = { version = "2.0.1" }
HAVAC._hooks  = { unload = {}, panic = {} }
HAVAC._pages  = {}
HAVAC._cards  = {}
HAVAC._errors = {}

-- ============================================================================
-- 1. CARREGAR A BASE OKUMA
-- ============================================================================

local OkumaBase = _G.Okuma

if not OkumaBase then
    local ok, result = pcall(function()
        local loader = loadstring or rawget(_G, "loadstring")
        if not loader then error("loadstring não disponível", 0) end
        return loader(game:HttpGet(
            "https://raw.githubusercontent.com/twistoficial/HavacCore/main/DemoUI.lua"
        ))()
    end)
    if ok and type(result) == "table" and type(result.new) == "function" then
        OkumaBase = result
        _G.Okuma = result
    end
end

if not OkumaBase then
    error([[
[HAVAC CORE] Base Okuma não encontrada.
Certifique-se de que DemoUI.lua está no repositório HavacCore.
Carregue primeiro:
  _G.Okuma = loadstring(game:HttpGet(".../DemoUI.lua"))()
]], 0)
end

HAVAC._okuma = OkumaBase

-- ============================================================================
-- 2. PALETAS HAVAC
-- ============================================================================

HAVAC.palettes = {
    Havac = {
        accent = { 139, 92, 246 },
        background = { 8, 8, 10 },
        surface = { 18, 18, 22 },
        text = { 245, 243, 255 },
        muted = { 161, 161, 170 },
    },
    Void = {
        accent = { 120, 80, 200 },
        background = { 4, 4, 8 },
        surface = { 14, 10, 24 },
        text = { 230, 225, 245 },
        muted = { 120, 110, 145 },
    },
    Ember = {
        accent = { 245, 130, 60 },
        background = { 10, 6, 4 },
        surface = { 20, 14, 10 },
        text = { 250, 240, 230 },
        muted = { 170, 145, 125 },
    },
    Frost = {
        accent = { 120, 200, 250 },
        background = { 4, 8, 12 },
        surface = { 12, 18, 26 },
        text = { 235, 245, 255 },
        muted = { 140, 160, 180 },
    },
}

HAVAC._currentTheme = "Havac"

-- ============================================================================
-- 3. DICIONÁRIO PT-BR
-- ============================================================================

local DICT = {
    ["Home"] = "Início",
    ["Settings"] = "Configurações",
    ["Search"] = "Buscar",
    ["Appearance"] = "Aparência",
    ["Themes"] = "Temas",
    ["Configs"] = "Configurações",
    ["Panic"] = "Pânico",
    ["Menu"] = "Menu",
    ["Hide with"] = "Ocultar com",
    ["Close"] = "Fechar",
    ["Cancel"] = "Cancelar",
    ["Confirm"] = "Confirmar",
    ["Save"] = "Salvar",
    ["Load"] = "Carregar",
    ["Delete"] = "Excluir",
    ["Refresh"] = "Atualizar",
    ["Reset"] = "Redefinir",
    ["Preset"] = "Preset",
    ["Apply"] = "Aplicar",
    ["Discord"] = "Discord",
    ["Feature list"] = "Lista de funções",
    ["Welcome to"] = "Bem-vindo ao",
    ["WELCOME BACK"] = "BEM-VINDO DE VOLTA",
    ["Community"] = "Comunidade",
    ["Unload"] = "Descarregar",
    ["Copy code"] = "Copiar código",
    ["Import code"] = "Importar código",
    ["Rejoin"] = "Reentrar",
    ["Hop"] = "Trocar servidor",
    ["Lowest"] = "Menor servidor",
    ["Job ID"] = "ID do job",
    ["Anti AFK"] = "Anti AFK",
    ["Auto Reconnect"] = "Auto Reconectar",
    ["Disable 3D Rendering"] = "Desativar renderização 3D",
    ["Minimize UI on Start"] = "Minimizar UI ao iniciar",
    ["Toggle UI"] = "Tecla de toggle",
    ["Toggle button"] = "Botão flutuante",
    ["Dim"] = "Escurecer",
    ["Blur"] = "Desfocar",
    ["Transparent"] = "Transparente",
    ["Adaptive Size"] = "Tamanho adaptativo",
    ["UI Scale"] = "Escala da UI",
    ["Density"] = "Densidade",
    ["Corner Radius"] = "Raio dos cantos",
    ["Weather"] = "Clima",
    ["Weather Mode"] = "Modo do clima",
    ["Drag Style"] = "Estilo de arraste",
    ["Dynamic Island"] = "Ilha dinâmica",
    ["Background"] = "Fundo",
    ["Background Opacity"] = "Opacidade do fundo",
    ["Accent"] = "Destaque",
    ["Surface"] = "Superfície",
    ["Text"] = "Texto",
    ["Muted text"] = "Texto apagado",
    ["Copy report to clipboard"] = "Copiar relatório",
    ["Generate report"] = "Gerar relatório",
}

local function translate(text)
    if type(text) ~= "string" then return text end
    if DICT[text] then return DICT[text] end
    for en, pt in pairs(DICT) do
        if text:find(en, 1, true) then
            return (text:gsub(en:gsub("%p", "%%%0"), pt))
        end
    end
    return text
end
HAVAC.translate = translate

local function applyIdentity(win)
    task.spawn(function()
        task.wait(0.2)
        local gui = win.UI and win.UI.gui
        if not gui then return end
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = translate(d.Text)
                if t ~= d.Text then d.Text = t end
            elseif d:IsA("TextBox") then
                local t = translate(d.PlaceholderText)
                if t ~= d.PlaceholderText then d.PlaceholderText = t end
            end
        end
    end)
end

-- ============================================================================
-- 4. INIT
-- ============================================================================

function HAVAC.init(opts)
    opts = opts or {}
    local win = OkumaBase.new({
        title = "HAVAC CORE",
        id = (opts.id or "havac"):gsub("[^%w_]", ""),
        discord = opts.discord,
        config = {
            customPal = HAVAC.palettes[opts.theme or "Havac"],
            themeVersion = 4,      -- força paleta custom a sobreviver ao boot
            minimizeOnStart = opts.minimizeOnStart or false,
            toggleKey = opts.toggleKey,
        },
    })
    HAVAC._win = win
    _G.__HAVAC_WIN = win
    applyIdentity(win)
    return HAVAC
end

function HAVAC.start()
    if HAVAC._win and not HAVAC._win.started then
        HAVAC._win:Start()
    end
    return HAVAC
end

-- ============================================================================
-- 5. PÁGINAS E CARDS
-- ============================================================================

function HAVAC.page(id, title)
    if not HAVAC._win then HAVAC.init() end
    title = title or id
    local tab = HAVAC._win:Tab(title, "overview")
    HAVAC._pages[id] = { tab = tab, id = id, title = title }
    return HAVAC._pages[id]
end

function HAVAC.card(pageOrId, title)
    local page = type(pageOrId) == "string" and HAVAC._pages[pageOrId] or pageOrId
    if not page then error("HAVAC.card: página não encontrada", 2) end
    return page.tab:Card(title or "Card")
end

-- ============================================================================
-- 6. COMPONENTES
-- ============================================================================

function HAVAC.toggle(card, label, default, cb)
    return card:Toggle(label, default, cb)
end

function HAVAC.slider(card, label, minV, maxV, default, cb, opts)
    if type(opts) == "string" then opts = { suffix = opts } end
    return card:Slider(label, minV, maxV, default, cb, opts or {})
end

function HAVAC.dropdown(card, label, options, default, cb)
    return card:Dropdown(label, options, default, cb)
end

function HAVAC.input(card, label, placeholder, default, cb)
    return card:Input(label, placeholder, default, cb)
end

function HAVAC.keybind(card, label, default, cb, opts)
    return card:Keybind(label, default, cb, opts)
end

function HAVAC.color(card, label, default, cb)
    return card:Color(label, default, cb)
end

function HAVAC.button(card, label, variant, cb)
    if type(variant) == "function" then cb = variant; variant = nil end
    return card:Button(label, cb, variant)
end

function HAVAC.buttonRow(card, items)
    return card:Buttons(items)
end

function HAVAC.label(card, text, opts)
    return card:Label(text, opts or {})
end

function HAVAC.paragraph(card, text, opts)
    opts = opts or {}
    opts.size = opts.size or 11
    return card:Label(text, opts)
end

function HAVAC.status(card, label, text, opts)
    return card:Status(label, text, opts)
end

function HAVAC.progress(card, label, opts)
    return card:Progress(label, opts)
end

function HAVAC.divider(card)
    local body = card.body
    if not body then return nil end
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.BackgroundColor3 = Color3.fromRGB(60, 55, 75)
    line.BorderSizePixel = 0
    line.Parent = body
    return line
end

-- ============================================================================
-- 7. NOTIFICAÇÕES
-- ============================================================================

function HAVAC.notify(kind, title, bodyText, duration)
    if HAVAC._win then
        HAVAC._win:Notify(kind, title, bodyText, duration)
    end
end

-- ============================================================================
-- 8. TEMAS (change em runtime requer patch no DemoUI — ver README)
-- ============================================================================

function HAVAC.setTheme(name)
    local p = HAVAC.palettes[name]
    if not p then return false end
    HAVAC._currentTheme = name
    local win = HAVAC._win
    -- Se o DemoUI foi patchado para expor UI._Apply.theme, aplica em runtime
    if win and win.UI and win.UI._Apply and win.UI._Apply.theme then
        pcall(win.UI._Apply.theme, p)
        return true
    end
    -- Senão: salva e avisa
    if win and win.UI and win.UI.config then
        win.UI.config.customPal = p
        if win.UI.save then pcall(win.UI.save) end
    end
    HAVAC.notify("info", "Tema", name .. " será aplicado no próximo boot.")
    return true
end

function HAVAC.getTheme() return HAVAC._currentTheme end

-- ============================================================================
-- 9. PANIC / UNLOAD
-- ============================================================================

function HAVAC.onPanic(fn)  table.insert(HAVAC._hooks.panic,  fn) end
function HAVAC.onUnload(fn) table.insert(HAVAC._hooks.unload, fn) end

local function sweepOrphans()
    local parents = { game:GetService("CoreGui") }
    local ok, hui = pcall(function() return type(gethui) == "function" and gethui() or nil end)
    if ok and hui then table.insert(parents, hui) end
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if pg then table.insert(parents, pg) end
    for _, p in ipairs(parents) do
        if p then
            for _, c in ipairs(p:GetChildren()) do
                if c:IsA("ScreenGui") and (c.Name:find("HAVAC") or c.Name:find("OkumaLib_")) then
                    pcall(function() c:Destroy() end)
                end
            end
        end
    end
end

function HAVAC.panic()
    for _, fn in ipairs(HAVAC._hooks.panic) do pcall(fn) end
    if HAVAC._win and HAVAC._win.UI and HAVAC._win.UI.unload then
        pcall(HAVAC._win.UI.unload)
    end
    sweepOrphans()
end

function HAVAC.unload()
    for _, fn in ipairs(HAVAC._hooks.unload) do pcall(fn) end
    if HAVAC._win and HAVAC._win.UI and HAVAC._win.UI.unload then
        pcall(HAVAC._win.UI.unload)
    end
    sweepOrphans()
end

-- ============================================================================
-- 10. TAP MOBILE
-- ============================================================================

local tapTimes = {}
local tapCount = 3
local tapWindow = 1.2
local tapEnabled = true

game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
    if gp or not tapEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    local now = tick()
    local fresh = {}
    for _, t in ipairs(tapTimes) do
        if now - t <= tapWindow then fresh[#fresh + 1] = t end
    end
    fresh[#fresh + 1] = now
    tapTimes = fresh
    if #tapTimes >= tapCount then
        tapTimes = {}
        if HAVAC._win and HAVAC._win.UI and HAVAC._win.UI.open then
            pcall(HAVAC._win.UI.open)
        end
    end
end)

HAVAC.mobile = {
    setSequence = function(n, w)
        tapCount  = math.max(2, math.min(6, n or 3))
        tapWindow = math.max(0.4, math.min(3, w or 1.2))
    end,
    enableGesture  = function() tapEnabled = true  end,
    disableGesture = function() tapEnabled = false end,
}

-- ============================================================================
-- 11. SHOWCASE
-- ============================================================================

function HAVAC.showcase()
    local p = HAVAC.page("showcase", "Showcase")
    local c = HAVAC.card(p, "Todos os Componentes")

    HAVAC.label(c, "HAVAC CORE — Showcase completo", { size = 14 })
    HAVAC.paragraph(c, "Cada componente abaixo é o motor Okuma premium com API HAVAC.")
    HAVAC.divider(c)

    HAVAC.label(c, "BOTÕES", { size = 11 })
    HAVAC.button(c, "Primário", "primary", function()
        HAVAC.notify("ok", "Primário", "Funcionou")
    end)
    HAVAC.button(c, "Secundário", function()
        HAVAC.notify("info", "Secundário", "Funcionou")
    end)
    HAVAC.buttonRow(c, {
        { label = "A", cb = function() HAVAC.notify("ok", "A", "ok") end },
        { label = "B", cb = function() HAVAC.notify("ok", "B", "ok") end },
    })

    HAVAC.divider(c)
    HAVAC.label(c, "CONTROLES", { size = 11 })
    HAVAC.toggle(c, "Toggle", false, function(on) print("toggle:", on) end)
    HAVAC.slider(c, "Slider", 0, 100, 50, function(v) print("slider:", v) end, { suffix = "%" })
    HAVAC.dropdown(c, "Dropdown", { "A", "B", "C" }, "A", function(v) print("dd:", v) end)
    HAVAC.input(c, "Input", "digite...", "", function(v) print("input:", v) end)
    HAVAC.keybind(c, "Keybind", "E", function(k) print("key:", k) end)

    HAVAC.divider(c)
    HAVAC.label(c, "NOTIFICAÇÕES", { size = 11 })
    HAVAC.button(c, "OK",   function() HAVAC.notify("ok",   "OK",    "Sucesso")  end)
    HAVAC.button(c, "WARN", function() HAVAC.notify("warn", "Aviso", "Aviso")    end)
    HAVAC.button(c, "ERR",  function() HAVAC.notify("err",  "Erro",  "Erro")     end)
    HAVAC.button(c, "INFO", function() HAVAC.notify("info", "Info",  "Info")     end)
end

-- ============================================================================
-- 12. AUTO-BOOT
-- ============================================================================

HAVAC.init({ id = "havac", theme = "Havac" })
HAVAC.start()

task.delay(1.5, function()
    HAVAC.notify("ok", "HAVAC CORE", "UI carregada. RCtrl para abrir.")
end)

_G.HAVAC = HAVAC
return HAVAC
