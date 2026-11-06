--[[
    HAVAC CORE Block B — Componentes Premium
    Requer: havac_core.lua (Block A) carregado primeiro
]]

local HAVAC = _G.HAVAC
if not HAVAC or not HAVAC._internal then
    error("[HAVAC BLOCK B] Block A não carregado. Rode havac_core.lua primeiro.", 0)
end

local I = HAVAC._internal
local Gui, Window, Sidebar, Body, Header = I.Gui, I.Window, I.Sidebar, I.Body, I.Header
local T, F = I.T, I.F
local Anim = I.Anim
local Track = I.Track
local New, Corner, Stroke, Padding = I.New, I.Corner, I.Stroke, I.Padding
local VList, HList = I.VList, I.HList
local Locale, Caps = I.Locale, I.Caps

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- ============================================================================
-- PAGE SYSTEM
-- ============================================================================

local Pages, PageOrder, ActivePageId = {}, {}, nil

-- Find navHolder inside Sidebar
local navHolder
for _, child in ipairs(Sidebar:GetChildren()) do
    if child:IsA("Frame") and child.Position.Y.Offset == 76 then
        navHolder = child
        break
    end
end
if not navHolder then error("navHolder not found", 0) end

-- Find existing nav items
local navItems = {}
for _, child in ipairs(navHolder:GetChildren()) do
    if child:IsA("TextButton") then navItems[#navItems + 1] = child end
end

-- Find existing status card in Body
local oldStatusCard
for _, child in ipairs(Body:GetChildren()) do
    if child:IsA("Frame") then oldStatusCard = child; break end
end

local function setNavActive(btn, active)
    local accent, dot, label
    for _, c in ipairs(btn:GetChildren()) do
        if c:IsA("Frame") and c.AnchorPoint.Y == 0.5 and c.AnchorPoint.X == 0 then accent = c
        elseif c:IsA("Frame") and c.Size.X.Offset == 8 then dot = c
        elseif c:IsA("TextLabel") then label = c end
    end
    if accent then Anim.tween(accent, { Size = UDim2.new(0, active and 3 or 0, 0, 16) }, 0.25, "smooth", "nA_" .. tostring(btn)) end
    if dot then Anim.tween(dot, { BackgroundColor3 = active and T.Accent or T.TextDim }, 0.2, "gentle", "nD_" .. tostring(btn)) end
    if label then Anim.tween(label, { TextColor3 = active and T.Text or T.TextDim }, 0.2, "gentle", "nL_" .. tostring(btn)) end
    Anim.tween(btn, { BackgroundTransparency = active and 0 or 1 }, 0.2, "gentle", "nB_" .. tostring(btn))
end

local function createPage(id, title, navBtn, existingCard)
    local frame = New("Frame", {
        Name = "Page_" .. id,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = Body,
    })
    VList(frame, 14)
    if existingCard then existingCard.Parent = frame end

    Pages[id] = { frame = frame, title = title, navBtn = navBtn, id = id }
    PageOrder[#PageOrder + 1] = id
    return Pages[id]
end

createPage("home", "Início", navItems[1], oldStatusCard)
createPage("settings", "Configurações", navItems[2])

local function switchPage(id)
    local target = Pages[id]
    if not target or ActivePageId == id then return end
    local old = ActivePageId and Pages[ActivePageId]
    ActivePageId = id
    if old then
        old.frame.Visible = false
        if old.navBtn then setNavActive(old.navBtn, false) end
    end
    target.frame.Visible = true
    if target.navBtn then setNavActive(target.navBtn, true) end
    Body.CanvasPosition = Vector2.new(0, 0)
end

function HAVAC.showPage(id) switchPage(id) end
function HAVAC.pageExists(id) return Pages[id] ~= nil end

if navItems[1] then navItems[1].MouseButton1Click:Connect(function() switchPage("home") end) end
if navItems[2] then navItems[2].MouseButton1Click:Connect(function() switchPage("settings") end) end

function HAVAC.page(id, title)
    if Pages[id] then return Pages[id].frame end
    title = title or id

    local btn = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = #PageOrder + 1,
        Parent = navHolder,
    })
    Corner(btn, 9)

    local accent = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 0, 0, 16),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = btn,
    })
    Corner(accent, 2)

    local dot = New("Frame", {
        Position = UDim2.new(0, 16, 0.5, -4),
        Size = UDim2.new(0, 8, 0, 8),
        BackgroundColor3 = T.TextDim,
        BorderSizePixel = 0,
        Parent = btn,
    })
    Corner(dot, 4)

    New("TextLabel", {
        Position = UDim2.new(0, 34, 0, 0),
        Size = UDim2.new(1, -40, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = T.TextDim,
        FontFace = F.Medium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = btn,
    })

    btn.MouseEnter:Connect(function()
        if ActivePageId ~= id then
            Anim.tween(btn, { BackgroundTransparency = 0.75 }, 0.15, "gentle", "nh_" .. tostring(btn))
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActivePageId ~= id then
            Anim.tween(btn, { BackgroundTransparency = 1 }, 0.15, "gentle", "nh_" .. tostring(btn))
        end
    end)
    btn.MouseButton1Click:Connect(function() switchPage(id) end)

    return createPage(id, title, btn).frame
end

switchPage("home")

-- ============================================================================
-- TOOLTIP
-- ============================================================================

local tooltip = New("Frame", {
    BackgroundColor3 = T.BgDeep,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 500,
    Parent = Gui,
})
Corner(tooltip, 8)
Stroke(tooltip, T.Border, 1)
Padding(tooltip, 12, 12, 8, 8)

local tooltipLabel = New("TextLabel", {
    Size = UDim2.new(0, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.XY,
    BackgroundTransparency = 1,
    Text = "",
    TextColor3 = T.Text,
    FontFace = F.Regular,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Parent = tooltip,
})

local tooltipOwner, tooltipSeq = nil, 0

Track(UIS.InputChanged:Connect(function(input)
    if tooltipOwner and input.UserInputType == Enum.UserInputType.MouseMovement then
        local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
        local vp = Gui.AbsoluteSize
        local sz = tooltip.AbsoluteSize
        tooltip.Position = UDim2.fromOffset(
            math.clamp(m.X + 16, 4, vp.X - sz.X - 4),
            math.clamp(m.Y + 20, 4, vp.Y - sz.Y - 4)
        )
    end
end))

local function attachTooltip(inst, text)
    if not text or text == "" then return end
    inst.MouseEnter:Connect(function()
        if tooltipOwner == inst then return end
        tooltipOwner = inst
        tooltipSeq = tooltipSeq + 1
        local my = tooltipSeq
        task.delay(0.5, function()
            if tooltipSeq ~= my or tooltipOwner ~= inst then return end
            tooltipLabel.Text = text
            local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
            tooltip.Position = UDim2.fromOffset(m.X + 16, m.Y + 20)
            tooltip.Visible = true
            tooltip.BackgroundTransparency = 1
            Anim.tween(tooltip, { BackgroundTransparency = 0 }, 0.15, "gentle", "tt_" .. tostring(tooltip))
        end)
    end)
    inst.MouseLeave:Connect(function()
        if tooltipOwner == inst then
            tooltipOwner = nil
            tooltipSeq = tooltipSeq + 1
            Anim.tween(tooltip, { BackgroundTransparency = 1 }, 0.12, "gentle", "tt_" .. tostring(tooltip))
            task.delay(0.15, function() tooltip.Visible = false end)
        end
    end)
end

HAVAC.attachTooltip = attachTooltip

-- ============================================================================
-- HELPERS
-- ============================================================================

local function Row(parent, labelText, desc)
    local r = New("Frame", {
        Size = UDim2.new(1, 0, 0, desc and 46 or 34),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    if labelText then
        New("TextLabel", {
            Size = desc and UDim2.new(0.6, 0, 0, 22) or UDim2.new(0.55, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = labelText,
            TextColor3 = T.Text,
            FontFace = F.Medium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = r,
        })
    end
    if desc then
        New("TextLabel", {
            Position = UDim2.new(0, 0, 0, 24),
            Size = UDim2.new(0.6, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = desc,
            TextColor3 = T.TextDim,
            FontFace = F.Regular,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = r,
        })
    end
    return r
end

local function ripple(btn, color)
    local size = btn.AbsoluteSize
    if size.X <= 0 then return end
    local m = UIS:GetMouseLocation() - GuiService:GetGuiInset()
    local abs = btn.AbsolutePosition
    local host = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = (btn.ZIndex or 1) + 1,
        Parent = btn,
    })
    Corner(host, 8)
    local dot = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(
            math.clamp((m.X - abs.X) / size.X, 0, 1),
            math.clamp((m.Y - abs.Y) / size.Y, 0, 1)
        ),
        Size = UDim2.fromScale(0, 0),
        BackgroundColor3 = color or Color3.new(1, 1, 1),
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        ZIndex = (btn.ZIndex or 1) + 2,
        Parent = host,
    })
    Corner(dot, 100)
    Anim.tween(dot, { Size = UDim2.fromScale(2.5, 2.5), BackgroundTransparency = 1 }, 0.55, "linear", "rip_" .. tostring(host))
    task.delay(0.6, function() if host.Parent then host:Destroy() end end)
end

-- ============================================================================
-- CARD
-- ============================================================================

local cardSeq = 0

function HAVAC.card(pageOrId, title)
    local page = type(pageOrId) == "string" and Pages[pageOrId] or Pages[pageOrId.id or ""]
    if not page then error("HAVAC.card: página não encontrada", 2) end

    cardSeq = cardSeq + 1

    local card = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = page.frame,
    })
    Corner(card, 14)
    local stroke = Stroke(card, T.BorderLow, 1)

    -- Header
    local header = New("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Parent = card,
    })
    Padding(header, 20, 16, 0, 0)

    -- Accent bar (vertical gradient)
    local bar = New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 4, 0, 22),
        BackgroundColor3 = T.Accent,
        BorderSizePixel = 0,
        Parent = header,
    })
    Corner(bar, 2)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, T.Accent),
            ColorSequenceKeypoint.new(1, T.Secondary),
        }),
        Rotation = 90,
        Parent = bar,
    })

    New("TextLabel", {
        Position = UDim2.new(0, 18, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = title or "Card",
        TextColor3 = T.Text,
        FontFace = F.Bold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = header,
    })

    -- Chevron
    local chev = New("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 28, 0, 28),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = header,
    })
    local chevGlyph = New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = T.TextDim,
        FontFace = F.Medium,
        TextSize = 14,
        Parent = chev,
    })

    -- Body
    local body = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    Padding(body, 20, 20, 16, 20)
    VList(body, 14)

    -- Collapse
    local collapsed, busy = false, false
    local function toggle()
        if busy then return end
        busy = true
        collapsed = not collapsed
        if collapsed then
            Anim.tween(chevGlyph, { Rotation = -90 }, 0.25, "smooth", "ch_" .. cardSeq)
            local h = body.AbsoluteSize.Y
            body.AutomaticSize = Enum.AutomaticSize.None
            body.Size = UDim2.new(1, 0, 0, h)
            Anim.tween(body, { Size = UDim2.new(1, 0, 0, 0) }, 0.25, "smooth", "cl_" .. cardSeq)
            task.wait(0.26)
            if collapsed then body.Visible = false end
        else
            Anim.tween(chevGlyph, { Rotation = 0 }, 0.25, "smooth", "ch_" .. cardSeq)
            body.Visible = true
            body.AutomaticSize = Enum.AutomaticSize.Y
            body.Size = UDim2.new(1, 0, 0, 0)
        end
        busy = false
    end
    chev.MouseButton1Click:Connect(toggle)
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            toggle()
        end
    end)

    card.MouseEnter:Connect(function()
        Anim.tween(stroke, { Color = T.Border }, 0.2, "gentle", "cs_" .. cardSeq)
    end)
    card.MouseLeave:Connect(function()
        Anim.tween(stroke, { Color = T.BorderLow }, 0.25, "gentle", "cs_" .. cardSeq)
    end)

    return body
end

-- ============================================================================
-- COMPONENTS
-- ============================================================================

function HAVAC.toggle(card, label, default, cb, opts)
    opts = opts or {}
    local r = Row(card, label, opts.desc)
    attachTooltip(r, opts.tip or opts.desc)

    local track = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 40, 0, 22),
        BackgroundColor3 = default and T.Primary or T.CardAlt,
        BorderSizePixel = 0,
        Parent = r,
    })
    Corner(track, 11)

    local knob = New("Frame", {
        Position = UDim2.new(0, default and 20 or 2, 0.5, -9),
        Size = UDim2.new(0, 18, 0, 18),
        BackgroundColor3 = default and T.BgDeep or T.TextDim,
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(knob, 9)

    local btn = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = r,
    })

    local state, hovered = default and true or false, false

    local function paint(animated)
        local tc = state and T.Primary or (hovered and T.CardHover or T.CardAlt)
        local kc = state and T.BgDeep or T.TextDim
        local kp = UDim2.new(0, state and 20 or 2, 0.5, -9)
        if animated then
            Anim.tween(track, { BackgroundColor3 = tc }, 0.2, "gentle", "tt_" .. tostring(track))
            Anim.tween(knob, { Position = kp, BackgroundColor3 = kc }, 0.3, "overshoot", "tk_" .. tostring(knob))
        else
            track.BackgroundColor3 = tc
            knob.Position = kp
            knob.BackgroundColor3 = kc
        end
    end

    btn.MouseEnter:Connect(function() hovered = true; if not state then paint(true) end end)
    btn.MouseLeave:Connect(function() hovered = false; if not state then paint(true) end end)
    btn.MouseButton1Click:Connect(function()
        state = not state
        paint(true)
        if state then
            local ring = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 18, 0, 18),
                BackgroundColor3 = T.Accent,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Parent = track,
            })
            Corner(ring, 100)
            Anim.tween(ring, { Size = UDim2.new(0, 44, 0, 44), BackgroundTransparency = 1 }, 0.5, "gentle", "tr_" .. tostring(track))
            task.delay(0.55, function() if ring.Parent then ring:Destroy() end end)
        end
        if cb then pcall(cb, state) end
    end)

    return {
        Set = function(_, v, fire) state = v and true or false; paint(true); if fire and cb then pcall(cb, state) end end,
        Get = function() return state end,
    }
end

function HAVAC.slider(card, label, minV, maxV, default, cb, opts)
    if type(opts) == "string" then opts = { suffix = opts } end
    opts = opts or {}
    local suffix, step = opts.suffix or "", opts.step or 1
    local dec = #(tostring(step):match("%.(%d+)$") or "")

    local function snap(x)
        local v = math.clamp(minV + math.floor((x - minV) / step + 0.5) * step, minV, maxV)
        return dec == 0 and math.floor(v + 0.5) or tonumber(("%." .. dec .. "f"):format(v))
    end
    local function fmt(v)
        return (dec == 0 and tostring(v) or ("%." .. dec .. "f"):format(v)) .. suffix
    end

    local value = default
    local wrap = New("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = card,
    })

    New("TextLabel", {
        Size = UDim2.new(0.6, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = T.Text,
        FontFace = F.Medium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = wrap,
    })

    local valBox = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0, 60, 0, 20),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Parent = wrap,
    })
    Corner(valBox, 6)
    New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = fmt(default),
        TextColor3 = T.Text,
        FontFace = F.Medium,
        TextSize = 11,
        Parent = valBox,
    })
    local valLbl = valBox:FindFirstChildWhichIsA("TextLabel")

    local track = New("Frame", {
        Position = UDim2.new(0, 0, 0, 34),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Parent = wrap,
    })
    Corner(track, 3)

    local rel0 = math.clamp((default - minV) / (maxV - minV), 0, 1)
    local fill = New("Frame", {
        Size = UDim2.new(rel0, 0, 1, 0),
        BackgroundColor3 = T.Primary,
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(fill, 3)
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.4),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = fill,
    })

    local halo = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(rel0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = T.Primary,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(halo, 100)

    local knob = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(rel0, 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = T.Text,
        BorderSizePixel = 0,
        Parent = track,
    })
    Corner(knob, 8)

    local hit = New("TextButton", {
        Position = UDim2.new(0, 0, 0, 24),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Parent = wrap,
    })

    local sliding, hovering = false, false
    local function glow()
        local s = sliding and 32 or (hovering and 24 or 16)
        Anim.tween(halo, {
            Size = UDim2.new(0, s, 0, s),
            BackgroundTransparency = (sliding or hovering) and 0.7 or 1,
        }, 0.2, "gentle", "sh_" .. tostring(halo))
    end

    hit.MouseEnter:Connect(function() hovering = true; glow() end)
    hit.MouseLeave:Connect(function() hovering = false; glow() end)

    local function show(v)
        local rel = math.clamp((v - minV) / (maxV - minV), 0, 1)
        Anim.tween(fill, { Size = UDim2.new(rel, 0, 1, 0) }, 0.08, "linear", "sf_" .. tostring(fill))
        Anim.tween(knob, { Position = UDim2.new(rel, 0, 0.5, 0) }, 0.08, "linear", "sk_" .. tostring(knob))
        Anim.tween(halo, { Position = UDim2.new(rel, 0, 0.5, 0) }, 0.08, "linear", "shp_" .. tostring(halo))
        valLbl.Text = fmt(v)
    end

    local function setFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        local v = snap(minV + rel * (maxV - minV))
        if v == value then return end
        value = v
        show(v)
        if cb then pcall(cb, v) end
    end

    local moveConn, endConn
    local function stopSliding()
        sliding = false
        if moveConn then moveConn:Disconnect(); moveConn = nil end
        if endConn then endConn:Disconnect(); endConn = nil end
        Anim.tween(knob, { Size = UDim2.new(0, 16, 0, 16) }, 0.1, "gentle", "sks_" .. tostring(knob))
        glow()
    end

    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if moveConn then moveConn:Disconnect() end
            if endConn then endConn:Disconnect() end
            sliding = true
            Anim.tween(knob, { Size = UDim2.new(0, 20, 0, 20) }, 0.1, "gentle", "sks_" .. tostring(knob))
            glow()
            setFromX(i.Position.X)
            moveConn = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    setFromX(m.Position.X)
                end
            end)
            endConn = UIS.InputEnded:Connect(function(e)
                if e.UserInputType == Enum.UserInputType.MouseButton1 or e.UserInputType == Enum.UserInputType.Touch then
                    stopSliding()
                end
            end)
        end
    end)

    return {
        Set = function(_, v, fire) value = v; show(v); if fire and cb then pcall(cb, v) end end,
        Get = function() return value end,
    }
end

function HAVAC.button(card, label, variant, cb)
    if type(variant) == "function" then cb = variant; variant = nil end
    local primary = variant == "primary"

    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = primary and T.Primary or T.CardAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = card,
    })
    Corner(b, 9)
    if not primary then Stroke(b, T.BorderLow, 1) end

    New("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = primary and T.BgDeep or T.Text,
        FontFace = F.Medium,
        TextSize = 12,
        Parent = b,
    })

    b.MouseEnter:Connect(function()
        Anim.tween(b, { BackgroundColor3 = primary and T.AccentDim or T.CardHover }, 0.15, "gentle", "bh_" .. tostring(b))
    end)
    b.MouseLeave:Connect(function()
        Anim.tween(b, { BackgroundColor3 = primary and T.Primary or T.CardAlt }, 0.15, "gentle", "bh_" .. tostring(b))
    end)
    b.MouseButton1Click:Connect(function()
        ripple(b, primary and T.BgDeep or T.Text)
        if cb then pcall(cb) end
    end)
    return b
end

function HAVAC.buttonRow(card, items)
    local r = New("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = card,
    })
    HList(r, 8)

    for _, it in ipairs(items) do
        local btn = New("TextButton", {
            Size = UDim2.new(1 / #items, -(8 * (#items - 1) / #items), 1, 0),
            BackgroundColor3 = T.CardAlt,
            BorderSizePixel = 0,
            Text = it.label or "",
            TextColor3 = T.Text,
            FontFace = F.Medium,
            TextSize = 12,
            AutoButtonColor = false,
            Parent = r,
        })
        Corner(btn, 9)
        Stroke(btn, T.BorderLow, 1)

        btn.MouseEnter:Connect(function()
            Anim.tween(btn, { BackgroundColor3 = T.CardHover }, 0.15, "gentle", "brh_" .. tostring(btn))
        end)
        btn.MouseLeave:Connect(function()
            Anim.tween(btn, { BackgroundColor3 = T.CardAlt }, 0.15, "gentle", "brh_" .. tostring(btn))
        end)
        btn.MouseButton1Click:Connect(function()
            ripple(btn, T.Text)
            if it.cb then pcall(it.cb) end
        end)
    end
    return r
end

function HAVAC.dropdown(card, label, options, default, cb, opts)
    opts = opts or {}
    local hasLabel = label ~= nil and label ~= ""

    local r = New("Frame", {
        Size = UDim2.new(1, 0, 0, hasLabel and 56 or 36),
        BackgroundTransparency = 1,
        Parent = card,
    })

    if hasLabel then
        New("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = T.Text,
            FontFace = F.Medium,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = r,
        })
    end

    local head = New("TextButton", {
        Position = UDim2.new(0, 0, 0, hasLabel and 22 or 0),
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = r,
    })
    Corner(head, 8)
    local headStroke = Stroke(head, T.BorderLow, 1)

    local headLbl = New("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -34, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(default or options[1] or ""),
        TextColor3 = T.Text,
        FontFace = F.Regular,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = head,
    })

    local chevron = New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = T.TextDim,
        FontFace = F.Medium,
        TextSize = 12,
        Parent = head,
    })

    local list = New("ScrollingFrame", {
        Size = UDim2.new(0, 200, 0, 0),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Border,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        ZIndex = 200,
        Parent = Gui,
    })
    Corner(list, 10)
    Stroke(list, T.Border, 1)
    Padding(list, 4, 4, 4, 4)
    VList(list, 1)

    local selected = default or options[1]
    local isOpen = false

    local function buildItems()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        for i, opt in ipairs(options) do
            local isSel = (opt == selected)
            local b = New("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = T.CardHover,
                BackgroundTransparency = isSel and 0.6 or 1,
                Text = tostring(opt),
                TextColor3 = isSel and T.Text or T.TextDim,
                FontFace = isSel and F.Medium or F.Regular,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
                LayoutOrder = i,
                Parent = list,
                ZIndex = 201,
            })
            Corner(b, 6)
            Padding(b, 10, 10, 0, 0)
            b.MouseButton1Click:Connect(function()
                selected = opt
                headLbl.Text = tostring(opt)
                if isOpen then
                    isOpen = false
                    Anim.tween(list, { Size = UDim2.new(0, list.AbsoluteSize.X, 0, 0) }, 0.15, "gentle", "ddc_" .. tostring(list))
                    task.delay(0.16, function() list.Visible = false end)
                    Anim.tween(chevron, { Rotation = 0 }, 0.2, "smooth", "ddcv_" .. tostring(head))
                    Anim.tween(headStroke, { Color = T.BorderLow }, 0.2, "gentle", "ddstr_" .. tostring(head))
                end
                buildItems()
                if cb then pcall(cb, opt) end
            end)
        end
    end
    buildItems()

    local function close()
        if not isOpen then return end
        isOpen = false
        Anim.tween(list, { Size = UDim2.new(0, list.AbsoluteSize.X, 0, 0) }, 0.15, "gentle", "ddc_" .. tostring(list))
        Anim.tween(chevron, { Rotation = 0 }, 0.2, "smooth", "ddcv_" .. tostring(head))
        Anim.tween(headStroke, { Color = T.BorderLow }, 0.2, "gentle", "ddstr_" .. tostring(head))
        task.delay(0.16, function() list.Visible = false end)
    end

    head.MouseButton1Click:Connect(function()
        if isOpen then close() return end
        isOpen = true
        local headAbs = head.AbsolutePosition
        local headSize = head.AbsoluteSize
        list.Position = UDim2.fromOffset(headAbs.X, headAbs.Y + headSize.Y + 4)
        local targetW = headSize.X
        local targetH = math.min(#options, 6) * 25 + 8
        list.Size = UDim2.new(0, targetW, 0, 0)
        list.Visible = true
        Anim.tween(list, { Size = UDim2.new(0, targetW, 0, targetH) }, 0.22, "smooth", "ddo_" .. tostring(list))
        Anim.tween(chevron, { Rotation = 180 }, 0.22, "smooth", "ddcv_" .. tostring(head))
        Anim.tween(headStroke, { Color = T.Accent }, 0.15, "gentle", "ddstr_" .. tostring(head))
    end)

    head.MouseEnter:Connect(function()
        if not isOpen then Anim.tween(headStroke, { Color = T.Border }, 0.15, "gentle", "ddstr_" .. tostring(head)) end
    end)
    head.MouseLeave:Connect(function()
        if not isOpen then Anim.tween(headStroke, { Color = T.BorderLow }, 0.2, "gentle", "ddstr_" .. tostring(head)) end
    end)

    return {
        Set = function(_, v, fire) selected = v; headLbl.Text = tostring(v); buildItems(); if fire and cb then pcall(cb, v) end end,
        Get = function() return selected end,
    }
end

function HAVAC.input(card, label, placeholder, default, cb)
    local r = Row(card, label)
    local box = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 170, 0, 28),
        BackgroundColor3 = T.CardAlt,
        BorderSizePixel = 0,
        Parent = r,
    })
    Corner(box, 7)
    local stroke = Stroke(box, T.BorderLow, 1)
    Padding(box, 10, 10, 0, 0)

    local tb = New("TextBox", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = T.TextDim,
        TextColor3 = T.Text,
        FontFace = F.Regular,
        TextSize = 11,
        Text = default or "",
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = box,
    })
    tb.Focused:Connect(function()
        Anim.tween(stroke, { Color = T.Accent }, 0.15, "gentle", "is_" .. tostring(tb))
    end)
    tb.FocusLost:Connect(function()
        Anim.tween(stroke, { Color = T.BorderLow }, 0.15, "gentle", "is_" .. tostring(tb))
        if cb then pcall(cb, tb.Text) end
    end)
    return tb
end

function HAVAC.section(card, text)
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = tostring(text):upper(),
        TextColor3 = T.TextMute,
        FontFace = F.Bold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = card,
    })
end

function HAVAC.divider(card)
    return New("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = T.BorderLow,
        BorderSizePixel = 0,
        Parent = card,
    })
end

function HAVAC.label(card, text, opts)
    opts = opts or {}
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(text),
        TextColor3 = opts.color or T.Text,
        FontFace = opts.bold and F.Bold or F.Regular,
        TextSize = opts.size or 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })
end

function HAVAC.paragraph(card, text, opts)
    opts = opts or {}
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = tostring(text),
        TextColor3 = opts.color or T.TextDim,
        FontFace = F.Regular,
        TextSize = opts.size or 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = card,
    })
end

function HAVAC.status(card, label, value, opts)
    opts = opts or {}
    local r = Row(card, label)
    return New("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, opts.width or 150, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(value or ""),
        TextColor3 = opts.color or T.TextDim,
        FontFace = F.Medium,
        TextSize = 12,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = r,
    })
end

-- ============================================================================
-- TOAST (notificação premium)
-- ============================================================================

local toastStack = New("Frame", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -20, 1, -20),
    Size = UDim2.new(0, 300, 0, 400),
    BackgroundTransparency = 1,
    ZIndex = 500,
    Parent = Gui,
})
HList(toastStack, 0)  -- not used, stack managed manually
toastStack:FindFirstChildWhichIsA("UIListLayout"):Destroy()

local toastSeq = 0

function HAVAC.notify(kind, title, bodyText, duration)
    local color = kind == "ok" and T.Success
               or kind == "err" and T.Error
               or kind == "warn" and T.Warning
               or T.Accent

    toastSeq = toastSeq + 1
    local offsetY = -20

    -- Find current stack height
    for _, c in ipairs(toastStack:GetChildren()) do
        if c:IsA("Frame") then
            offsetY = offsetY - (c.Size.Y.Offset + 8)
        end
    end

    local wrap = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, 0, 1, offsetY),
        Size = UDim2.new(0, 300, 0, 68),
        BackgroundColor3 = T.BgDeep,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 500,
        Parent = toastStack,
    })
    Corner(wrap, 12)
    Stroke(wrap, T.BorderLow, 1)

    -- Accent stripe
    local stripe = New("Frame", {
        Position = UDim2.new(0, 0, 0, 14),
        Size = UDim2.new(0, 3, 0, 40),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Parent = wrap,
    })
    Corner(stripe, 2)

    New("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -30, 0, 
