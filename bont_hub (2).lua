--[[
    BONT HUB - Final Merged Version
    Combines Bont Duels logic with Bont GUI
    - Full keybind system (rebindable)
    - Speed cogwheel: Normal & Carry mode config
    - Bont steal bar with radius
    - No teleport section
    - No cogwheels except Speed
    - Modern black/dark-blue UI
]]




print("[BONT HUB] Loading...")
repeat task.wait() until game:IsLoaded()

-- ==========================================
-- SERVICES
-- ==========================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local pgui        = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui")



-- ==========================================
-- SPEED / KEY DEFAULTS
-- ==========================================
local NORMAL_SPEED = 60
local CARRY_SPEED  = 30

local speedToggled       = false
local autoBatToggled       = false
local autoBatKey         = Enum.KeyCode.E
local speedToggleKey     = Enum.KeyCode.Q
local autoLeftKey        = Enum.KeyCode.Z
local autoRightKey       = Enum.KeyCode.C
local autoLeftPlayKey    = Enum.KeyCode.J
local autoRightPlayKey   = Enum.KeyCode.K
local floatKey           = Enum.KeyCode.F
local guiToggleKey       = Enum.KeyCode.RightAlt
local tpDownKey          = Enum.KeyCode.G
local dropKey            = Enum.KeyCode.H
local lowSpeedKey        = Enum.KeyCode.V

local lowSpeedToggled    = false
local LOW_SPEED_VALUE    = 13

local guiVisible = true

-- ==========================================
-- PERFORMANCE / SMOOTHNESS
-- ==========================================
local SPEED_APPLY_EPSILON       = 0.1
local SPEED_LABEL_UPDATE_RATE   = 0.08
local MOBILE_VISUAL_UPDATE_RATE = 0.12
local AUTO_STEAL_TICK_RATE      = 0.05
local ANTI_RAGDOLL_TICK_RATE    = 0.05
local NOCLIP_TICK_RATE          = 0.08

-- ==========================================
-- WAYPOINTS  (offset-editable, K7 style)
-- ==========================================
local WP = {
    Left = {
        { label="L1", pos=Vector3.new(-476.48,-6.28, 92.73), offset=Vector3.new(0,0,0) },
        { label="L2", pos=Vector3.new(-483.12,-4.95, 94.80), offset=Vector3.new(0,0,0) },
    },
    Right = {
        { label="R1", pos=Vector3.new(-476.16,-6.52, 25.62), offset=Vector3.new(0,0,0) },
        { label="R2", pos=Vector3.new(-483.04,-5.09, 23.14), offset=Vector3.new(0,0,0) },
    },
    LeftPlay = {
        { label="LP1", pos=Vector3.new(-476.2,-6.5,  94.8), offset=Vector3.new(0,0,0) },
        { label="LP2", pos=Vector3.new(-484.1,-4.7,  94.7), offset=Vector3.new(0,0,0) },
        { label="LP3", pos=Vector3.new(-476.5,-6.1,   7.5), offset=Vector3.new(0,0,0) },
    },
    RightPlay = {
        { label="RP1", pos=Vector3.new(-476.2,-6.1,  25.8), offset=Vector3.new(0,0,0) },
        { label="RP2", pos=Vector3.new(-484.1,-4.7,  25.9), offset=Vector3.new(0,0,0) },
        { label="RP3", pos=Vector3.new(-476.2,-6.2, 113.5), offset=Vector3.new(0,0,0) },
    },
}
local function wpPos(wp) return wp.pos + wp.offset end

-- Keep legacy names working for the rest of the code
local POSITION_L1 = Vector3.new(-476.48, -6.28, 92.73)
local POSITION_L2 = Vector3.new(-483.12, -4.95, 94.80)
local POSITION_R1 = Vector3.new(-476.16, -6.52, 25.62)
local POSITION_R2 = Vector3.new(-483.04, -5.09, 23.14)

local ALP_P1 = Vector3.new(-476.2, -6.5, 94.8)
local ALP_P2 = Vector3.new(-484.1, -4.7, 94.7)
local ALP_P3 = Vector3.new(-476.5, -6.1, 7.5)

local ARP_P1 = Vector3.new(-476.2, -6.1, 25.8)
local ARP_P2 = Vector3.new(-484.1, -4.7, 25.9)
local ARP_P3 = Vector3.new(-476.2, -6.2, 113.5)

-- ==========================================
-- STATE
-- ==========================================
local Values = {
    STEAL_RADIUS       = 8,
    STEAL_DURATION     = 0.2,
    DEFAULT_GRAVITY    = 196.2,
    GalaxyGravityPercent = 70,
    HOP_POWER          = 36,
    HOP_COOLDOWN       = 0.15,
}

local Enabled = {
    AntiRagdoll        = false,
    AutoSteal          = false,
    Galaxy             = false,
    Optimizer          = false,
    Unwalk             = false,
    AutoLeftEnabled    = false,
    AutoRightEnabled   = false,
    AutoLeftPlayEnabled  = false,
    AutoRightPlayEnabled = false,
    FloatEnabled       = false,
    NoClip             = false,
    DarkMode           = false,
    MiniGuiEnabled     = false,
    WaypointESP        = false,
    Spinbot            = false,
    RagdollTP          = false,
    BatAimbot          = false,
    CounterMedusa      = false,
    MobileButtonsVisible = true,
    UILocked           = false,
    AutoCarryOnPickup  = false,
    LowSpeedEnabled    = false,
}

local Connections  = {}
local StealData    = {}
local VisualSetters = {}

local isStealing     = false
local stealStartTime = nil

local AutoLeftEnabled      = false
local AutoRightEnabled     = false
local AutoLeftPlayEnabled  = false
local AutoRightPlayEnabled = false

local autoLeftConnection      = nil
local autoRightConnection     = nil
local autoLeftPlayConnection  = nil
local autoRightPlayConnection = nil
local autoLeftPhase      = 1
local autoRightPhase     = 1
local autoLeftPlayPhase  = 1
local autoRightPlayPhase = 1

local galaxyVectorForce  = nil
local galaxyAttachment   = nil
local galaxyEnabled      = false
local hopsEnabled        = false
local lastHopTime        = 0
local spaceHeld          = false
local originalJumpPower  = 50

-- INFINITE JUMP (inlocuieste Galaxy mode)
local INF_JUMP_POWER   = 55
local INF_MAX_FALL_VEL = -120
local infJumpConn      = nil
local infFallConn      = nil

local floatEnabled   = false
local floatTargetY   = nil
local floatConn      = nil
local FLOAT_HEIGHT   = 10

local originalTransparency = {}
local xrayEnabled    = false
local savedAnimations = {}
local noClipTracked  = {}

local currentTransparency = 0
local MAIN_GUI_SCALE      = 1
local MOBILE_GUI_SCALE    = 1
local h, hrp, speedLbl    = nil, nil, nil

-- Ragdoll TP state
local tpWasRagdolled   = false
local tpCooldown       = false
local tpStateConn, tpChildConn, tpChildRemConn = nil, nil, nil

-- Steal bar UI refs
local SBFill, SBPct, SBStatus, SBRadBtn, StealBarFrame
local stealBarTimer = 0

local modeLabel    = nil
local autoSaveLabel = nil

-- ==========================================
-- CHARACTER HELPERS
-- ==========================================
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ==========================================
-- STEAL HELPERS
-- ==========================================
-- ==========================================
-- AUTO STEAL  (enhanced engine)
-- ==========================================

-- Pre-scanned animal/prompt cache
local jAnimalCache  = {}
local jPromptCache  = {}
local jStealCache   = {}
local jStealConn    = nil
local progressConnection = nil
local stealStartTime = nil

-- Optional: load AnimalsData for display names
local AnimalsData = {}
pcall(function()
    local rep   = game:GetService("ReplicatedStorage")
    local datas = rep:FindFirstChild("Datas")
    if datas then
        local animals = datas:FindFirstChild("Animals")
        if animals then AnimalsData = require(animals) end
    end
end)

local function jIsMyBase(plotName)
    local plots = workspace:FindFirstChild("Plots"); if not plots then return false end
    local plot  = plots:FindFirstChild(plotName);   if not plot  then return false end
    local sign  = plot:FindFirstChild("PlotSign");  if not sign  then return false end
    local yb    = sign:FindFirstChild("YourBase")
    return yb and yb:IsA("BillboardGui") and yb.Enabled == true
end

local function jScanPlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if jIsMyBase(plot.Name) then return end
    local podiums = plot:FindFirstChild("AnimalPodiums"); if not podiums then return end
    for _, pod in ipairs(podiums:GetChildren()) do
        if pod:IsA("Model") and pod:FindFirstChild("Base") then
            local name  = "Unknown"
            local spawn = pod.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        name = child.Name
                        local info = AnimalsData[name]
                        if info and info.DisplayName then name = info.DisplayName end
                        break
                    end
                end
            end
            local uid = plot.Name .. "_" .. pod.Name
            table.insert(jAnimalCache, {
                name = name, plot = plot.Name, slot = pod.Name,
                worldPos = pod:GetPivot().Position,
                uid  = uid,
            })
        end
    end
end

local function jFindPrompt(ad)
    if not ad then return nil end
    local cp = jPromptCache[ad.uid]
    if cp and cp.Parent then return cp end
    local plots = workspace:FindFirstChild("Plots"); if not plots then return nil end
    local plot  = plots:FindFirstChild(ad.plot);    if not plot  then return nil end
    local pods  = plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
    local pod   = pods:FindFirstChild(ad.slot);     if not pod   then return nil end
    local base  = pod:FindFirstChild("Base");        if not base  then return nil end
    local sp    = base:FindFirstChild("Spawn");      if not sp    then return nil end
    local att   = sp:FindFirstChild("PromptAttachment"); if not att then return nil end
    for _, p in ipairs(att:GetChildren()) do
        if p:IsA("ProximityPrompt") then jPromptCache[ad.uid] = p; return p end
    end
    return nil
end

local function jBuildCallbacks(prompt)
    if jStealCache[prompt] then return end
    local data = { hold = {}, trigger = {}, ready = true }
    local ok1, c1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(c1) == "table" then
        for _, conn in ipairs(c1) do
            if type(conn.Function) == "function" then table.insert(data.hold, conn.Function) end
        end
    end
    local ok2, c2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(c2) == "table" then
        for _, conn in ipairs(c2) do
            if type(conn.Function) == "function" then table.insert(data.trigger, conn.Function) end
        end
    end
    jStealCache[prompt] = data
end

local function jResetBar()
    if SBPct    then SBPct.Visible = false end
    if SBFill   then SBFill.Size = UDim2.new(0,0,1,0) end
    if SBStatus then SBStatus.Text = "READY" end
end

local function jExecSteal(prompt)
    local data = jStealCache[prompt]
    if not data or not data.ready then return end
    data.ready = false; isStealing = true; stealStartTime = tick()
    if progressConnection then progressConnection:Disconnect() end
    progressConnection = RunService.Heartbeat:Connect(function()
        if not isStealing then
            if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
            return
        end
        local prog = math.clamp((tick() - stealStartTime) / Values.STEAL_DURATION, 0, 1)
        if SBFill   then SBFill.Size = UDim2.new(prog, 0, 1, 0) end
        if SBPct    then SBPct.Visible = true; SBPct.Text = math.floor(prog*100).."%" end
        if SBStatus then SBStatus.Text = "STEALING" end
    end)
    task.spawn(function()
        for _, fn in ipairs(data.hold)    do task.spawn(pcall, fn) end
        task.wait(Values.STEAL_DURATION)
        for _, fn in ipairs(data.trigger) do task.spawn(pcall, fn) end
        -- fallback: fire prompt directly if no callbacks were found
        pcall(function() prompt:InputHoldBegin() end)
        task.wait(Values.STEAL_DURATION)
        pcall(function() prompt:InputHoldEnd() end)
        if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
        jResetBar()
        data.ready = true; isStealing = false
    end)
end

local function jNearestAnimal()
    local hrp = getHRP(); if not hrp then return nil end
    local best, bestD = nil, math.huge
    for _, ad in ipairs(jAnimalCache) do
        if not jIsMyBase(ad.plot) and ad.worldPos then
            local d = (hrp.Position - ad.worldPos).Magnitude
            if d < bestD and d <= Values.STEAL_RADIUS then bestD = d; best = ad end
        end
    end
    return best
end

-- Initial scan + periodic refresh every 5 s
task.spawn(function()
    task.wait(2)
    local plots = workspace:WaitForChild("Plots", 10); if not plots then return end
    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then jScanPlot(plot) end
    end
    plots.ChildAdded:Connect(function(plot)
        if plot:IsA("Model") then task.wait(0.5); jScanPlot(plot) end
    end)
    task.spawn(function()
        while task.wait(5) do
            jAnimalCache = {}; jPromptCache = {}
            for _, plot in ipairs(plots:GetChildren()) do
                if plot:IsA("Model") then jScanPlot(plot) end
            end
        end
    end)
end)

local function startAutoSteal()
    if jStealConn then return end
    local acc = 0
    jStealConn = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < AUTO_STEAL_TICK_RATE then return end
        acc = 0
        if not Enabled.AutoSteal or isStealing then return end
        local target = jNearestAnimal(); if not target then return end
        local prompt = jPromptCache[target.uid]
        if not prompt or not prompt.Parent then prompt = jFindPrompt(target) end
        if prompt then
            jBuildCallbacks(prompt)
            jExecSteal(prompt)
        end
    end)
end

local function stopAutoSteal()
    if jStealConn then jStealConn:Disconnect(); jStealConn = nil end
    isStealing = false
    if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
    jResetBar()
end



-- ==========================================
-- ANTI RAGDOLL
-- ==========================================
local function startBontShield()
    if Connections.antiRagdoll then return end
    local acc = 0
    Connections.antiRagdoll = RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < ANTI_RAGDOLL_TICK_RATE then return end
        acc = 0
        if not Enabled.AntiRagdoll then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local humState = hum:GetState()
            if humState == Enum.HumanoidStateType.Physics or humState == Enum.HumanoidStateType.Ragdoll or humState == Enum.HumanoidStateType.FallingDown then
                hum:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = hum
                pcall(function()
                    if LocalPlayer.Character then
                        local PM = LocalPlayer.PlayerScripts:FindFirstChild("PlayerModule")
                        if PM then require(PM:FindFirstChild("ControlModule")):Enable() end
                    end
                end)
                if root then root.AssemblyLinearVelocity = Vector3.new(0,0,0) root.AssemblyAngularVelocity = Vector3.new(0,0,0) end
            end
        end
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") and obj.Enabled == false then obj.Enabled = true end
        end
    end)
end

local function stopBontShield()
    if Connections.antiRagdoll then Connections.antiRagdoll:Disconnect(); Connections.antiRagdoll = nil end
end
-- Aliases pentru Bont compatibility
local startAntiRagdoll = startBontShield
local stopAntiRagdoll  = stopBontShield
-- ==========================================
local function captureJumpPower()
    local c = LocalPlayer.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid") if hum and hum.JumpPower > 0 then originalJumpPower = hum.JumpPower end end
end
task.spawn(function() task.wait(1); captureJumpPower() end)
LocalPlayer.CharacterAdded:Connect(function() task.wait(1); captureJumpPower() end)

-- ==========================================
-- INFINITE JUMP (Galaxy Mode replacement)
-- ==========================================
local function startGalaxy()
    galaxyEnabled = true
    -- Jump request: seteaza viteza verticala la fiecare apasare Space
    if infJumpConn then infJumpConn:Disconnect() end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        if not galaxyEnabled then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        root.Velocity = Vector3.new(root.Velocity.X, INF_JUMP_POWER, root.Velocity.Z)
    end)
    -- Fall limiter: previne caderea prea rapida
    if infFallConn then infFallConn:Disconnect() end
    infFallConn = RunService.Heartbeat:Connect(function()
        if not galaxyEnabled then return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        if root.Velocity.Y < INF_MAX_FALL_VEL then
            root.Velocity = Vector3.new(root.Velocity.X, INF_MAX_FALL_VEL, root.Velocity.Z)
        end
    end)
end

local function stopGalaxy()
    galaxyEnabled = false
    if infJumpConn then infJumpConn:Disconnect(); infJumpConn = nil end
    if infFallConn then infFallConn:Disconnect(); infFallConn = nil end
end

-- ==========================================
-- UNWALK / NOCLIP
-- ==========================================
local function startUnwalk()
    local c = LocalPlayer.Character; if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop() end end
    local anim = c:FindFirstChild("Animate")
    if anim then savedAnimations.Animate = anim:Clone(); anim:Destroy() end
end

local function stopUnwalk()
    local c = LocalPlayer.Character
    if c and savedAnimations.Animate then savedAnimations.Animate:Clone().Parent = c; savedAnimations.Animate = nil end
end

local function startNoClip()
    if Connections.noClip then return end
    local acc = 0
    Connections.noClip = RunService.Stepped:Connect(function(_, dt)
        acc = acc + (dt or 0.016)
        if acc < NOCLIP_TICK_RATE then return end
        acc = 0
        if not Enabled.NoClip then return end
        local playerParts = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                for _, part in ipairs(plr.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        playerParts[part] = true
                        if part.CanCollide then part.CanCollide = false; noClipTracked[part] = true end
                    end
                end
            end
        end
        for part, _ in pairs(noClipTracked) do
            if not playerParts[part] then pcall(function() part.CanCollide = true end); noClipTracked[part] = nil end
        end
    end)
end

local function stopNoClip()
    if Connections.noClip then Connections.noClip:Disconnect(); Connections.noClip = nil end
    for part, _ in pairs(noClipTracked) do pcall(function() part.CanCollide = true end) end
    noClipTracked = {}
end

-- ==========================================
-- DROP / TP DOWN
-- ==========================================
local function executeBontDrop()
    local r = getHRP(); if not r then return end
    r.AssemblyLinearVelocity = Vector3.new(0, 125, 0)
    task.wait(0.4)
    r.AssemblyLinearVelocity = Vector3.new(0, -600, 0)
end
local doDropBrainrots = executeBontDrop  -- alias Bont

local function doTPDown()
    local r = getHRP(); if not r then return end
    -- Raycast direct in jos de la pozitia curenta
    local rayOrigin = r.Position
    local rayDir    = Vector3.new(0, -500, 0)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(rayOrigin, rayDir, rayParams)
    if result then
        -- pune caracterul exact pe podea (+3 ca sa nu intre in ea)
        local _, ry, _ = r.CFrame:ToEulerAnglesYXZ()
        r.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, ry, 0)
    else
        -- fallback: -20 daca nu gaseste podea
        r.CFrame = r.CFrame * CFrame.new(0, -20, 0)
    end
end

-- AUTO CARRY ON BRAINROT PICKUP (din Bont)
local autoCarryToolConn = nil
local function hookAutoCarryChar(char)
    if autoCarryToolConn then autoCarryToolConn:Disconnect(); autoCarryToolConn = nil end
    if not char then return end
    autoCarryToolConn = char.ChildAdded:Connect(function(child)
        if not Enabled.AutoCarryOnPickup then return end
        if child:IsA("Tool") then
            speedToggled = true
            if modeLabel then modeLabel.Text = "Mode: Carry" end
        end
    end)
end
local autoCarryCharConn = nil
local function startAutoCarryMode()
    hookAutoCarryChar(LocalPlayer.Character)
    if autoCarryCharConn then autoCarryCharConn:Disconnect() end
    autoCarryCharConn = LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(0.1); hookAutoCarryChar(char)
    end)
end
local function stopAutoCarryMode()
    if autoCarryToolConn then autoCarryToolConn:Disconnect(); autoCarryToolConn = nil end
    if autoCarryCharConn then autoCarryCharConn:Disconnect(); autoCarryCharConn = nil end
end

-- ==========================================
-- OPTIMIZER / DARK MODE
-- ==========================================
local function enableOptimizer()
    if getgenv and getgenv().BONT_OPT_ACTIVE then return end
    if getgenv then getgenv().BONT_OPT_ACTIVE = true end
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        Lighting.GlobalShadows = false; Lighting.Brightness = 2; Lighting.FogEnd = 9e9; Lighting.FogStart = 9e9
        for _, fx in ipairs(Lighting:GetChildren()) do if fx:IsA("PostEffect") then fx.Enabled = false end end
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                    obj.Enabled = false; obj:Destroy()
                elseif obj:IsA("BasePart") then
                    obj.CastShadow = false; obj.Material = Enum.Material.Plastic
                    for _, child in ipairs(obj:GetChildren()) do
                        if child:IsA("Decal") or child:IsA("Texture") or child:IsA("SurfaceAppearance") then child:Destroy() end
                    end
                elseif obj:IsA("Sky") then obj:Destroy() end
            end)
        end
    end)
    xrayEnabled = true
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Anchored and (obj.Name:lower():find("base") or (obj.Parent and obj.Parent.Name:lower():find("base"))) then
                originalTransparency[obj] = obj.LocalTransparencyModifier
                obj.LocalTransparencyModifier = 0.88
            end
        end
    end)
end

local function disableOptimizer()
    if getgenv then getgenv().BONT_OPT_ACTIVE = false end
    if xrayEnabled then
        for part, value in pairs(originalTransparency) do if part then part.LocalTransparencyModifier = value end end
        originalTransparency = {}; xrayEnabled = false
    end
end

local darkCC = nil
local function enableDarkMode()
    if darkCC and darkCC.Parent then return end
    darkCC = Instance.new("ColorCorrectionEffect")
    darkCC.Name = "BontDarkMode"; darkCC.Brightness = -0.25; darkCC.Contrast = 0.1
    darkCC.Saturation = -0.1; darkCC.Enabled = true; darkCC.Parent = Lighting
end
local function disableDarkMode()
    if darkCC then darkCC:Destroy(); darkCC = nil end
end

-- Aliases pentru compatibilitate cu GUI toggles
local function activatePowerMode()   Enabled.Optimizer=true;  enableOptimizer()  end
local function deactivatePowerMode() Enabled.Optimizer=false; disableOptimizer() end
local function refreshAllBadges() end  -- stub (nu exista badge-uri in bont hub)

-- ==========================================
-- FLOAT
-- ==========================================
local function updateFloatHeight()
    if not floatEnabled then return end
    local c = LocalPlayer.Character; if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart"); if not r then return end
    floatTargetY = r.Position.Y + FLOAT_HEIGHT
end

local function startFloat()
    local c = LocalPlayer.Character; if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart"); if not r then return end
    floatTargetY = r.Position.Y + FLOAT_HEIGHT; floatEnabled = true
    if floatConn then floatConn:Disconnect() end
    floatConn = RunService.Heartbeat:Connect(function()
        if not floatEnabled then floatConn:Disconnect(); floatConn = nil; return end
        local char = LocalPlayer.Character; if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then return end
        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        local diff = floatTargetY - root.Position.Y
        if math.abs(diff) > 0.05 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, diff*12, root.AssemblyLinearVelocity.Z)
        end
    end)
end

local function stopFloat()
    floatEnabled = false; floatTargetY = nil
    if floatConn then floatConn:Disconnect(); floatConn = nil end
    local c = LocalPlayer.Character
    if c then local r = c:FindFirstChild("HumanoidRootPart") if r then r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X,-150,r.AssemblyLinearVelocity.Z) end end
end

-- ==========================================
-- AUTO MOVEMENTS
-- ==========================================
local function faceSouth()
    if Enabled.Spinbot then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart"); if not h then return end
    h.CFrame = CFrame.new(h.Position) * CFrame.Angles(0,0,0)
end
local function faceNorth()
    if Enabled.Spinbot then return end
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("HumanoidRootPart"); if not h then return end
    h.CFrame = CFrame.new(h.Position) * CFrame.Angles(0,math.rad(180),0)
end

local function stopAutoLeft()
    if autoLeftConnection then autoLeftConnection:Disconnect(); autoLeftConnection=nil end
    autoLeftPhase=1; AutoLeftEnabled=false; Enabled.AutoLeftEnabled=false
    local c = LocalPlayer.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid") if hum then hum:Move(Vector3.zero,false) end end
    if VisualSetters.AutoLeftEnabled then VisualSetters.AutoLeftEnabled(false, true) end
end

local function stopAutoRight()
    if autoRightConnection then autoRightConnection:Disconnect(); autoRightConnection=nil end
    autoRightPhase=1; AutoRightEnabled=false; Enabled.AutoRightEnabled=false
    local c = LocalPlayer.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid") if hum then hum:Move(Vector3.zero,false) end end
    if VisualSetters.AutoRightEnabled then VisualSetters.AutoRightEnabled(false, true) end
end

local function stopAutoLeftPlay()
    if autoLeftPlayConnection then autoLeftPlayConnection:Disconnect(); autoLeftPlayConnection=nil end
    autoLeftPlayPhase=1; AutoLeftPlayEnabled=false; Enabled.AutoLeftPlayEnabled=false
    speedToggled=true; if modeLabel then modeLabel.Text="Mode: Carry" end
    local c = LocalPlayer.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid") if hum then hum:Move(Vector3.zero,false) end end
    if VisualSetters.AutoLeftPlayEnabled then VisualSetters.AutoLeftPlayEnabled(false, true) end
end

local function stopAutoRightPlay()
    if autoRightPlayConnection then autoRightPlayConnection:Disconnect(); autoRightPlayConnection=nil end
    autoRightPlayPhase=1; AutoRightPlayEnabled=false; Enabled.AutoRightPlayEnabled=false
    speedToggled=true; if modeLabel then modeLabel.Text="Mode: Carry" end
    local c = LocalPlayer.Character
    if c then local hum = c:FindFirstChildOfClass("Humanoid") if hum then hum:Move(Vector3.zero,false) end end
    if VisualSetters.AutoRightPlayEnabled then VisualSetters.AutoRightPlayEnabled(false, true) end
end

local function startAutoLeft()
    if autoLeftConnection then autoLeftConnection:Disconnect() end
    autoLeftPhase = 1
    autoLeftConnection = RunService.Heartbeat:Connect(function()
        if not AutoLeftEnabled then return end
        local c = LocalPlayer.Character if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local currentSpeed = NORMAL_SPEED
        local T1 = wpPos(WP.Left[1]); local T2 = wpPos(WP.Left[2])
        if autoLeftPhase == 1 then
            local dist = (Vector3.new(T1.X, h.Position.Y, T1.Z) - h.Position).Magnitude
            if dist < 1 then autoLeftPhase = 2 return end
            local dir = Vector3.new((T1-h.Position).X,0,(T1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity = Vector3.new(dir.X*currentSpeed,h.AssemblyLinearVelocity.Y,dir.Z*currentSpeed)
        elseif autoLeftPhase == 2 then
            local dist = (Vector3.new(T2.X, h.Position.Y, T2.Z) - h.Position).Magnitude
            if dist < 1 then
                hum:Move(Vector3.zero,false) h.AssemblyLinearVelocity = Vector3.new(0,0,0)
                AutoLeftEnabled=false Enabled.AutoLeftEnabled=false
                if autoLeftConnection then autoLeftConnection:Disconnect() autoLeftConnection=nil end
                autoLeftPhase=1
                if VisualSetters.AutoLeftEnabled then VisualSetters.AutoLeftEnabled(false,true) end
                faceSouth() return
            end
            local dir = Vector3.new((T2-h.Position).X,0,(T2-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity = Vector3.new(dir.X*currentSpeed,h.AssemblyLinearVelocity.Y,dir.Z*currentSpeed)
        end
    end)
end

local function startAutoRight()
    if autoRightConnection then autoRightConnection:Disconnect() end
    autoRightPhase=1
    local arLastPos, arStuckTimer = nil, 0
    autoRightConnection = RunService.Heartbeat:Connect(function(dt)
        if not AutoRightEnabled then return end
        local c = LocalPlayer.Character if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local currentSpeed = NORMAL_SPEED
        local T1 = wpPos(WP.Right[1]); local T2 = wpPos(WP.Right[2])
        local currentPos = h.Position
        if arLastPos then
            if (currentPos-arLastPos).Magnitude < 0.05 then arStuckTimer=arStuckTimer+dt else arStuckTimer=0 end
        end
        arLastPos = currentPos
        if autoRightPhase == 1 then
            local dist = (Vector3.new(T1.X,h.Position.Y,T1.Z)-h.Position).Magnitude
            if dist < 1 then autoRightPhase=2 arStuckTimer=0 return end
            if arStuckTimer > 0.4 then
                arStuckTimer=0
                local sd=(T1-h.Position)
                local ss=Vector3.new(sd.X,0,sd.Z).Unit*math.min(4,sd.Magnitude)
                h.CFrame=CFrame.new(h.Position+ss) h.AssemblyLinearVelocity=Vector3.zero return
            end
            local dir=Vector3.new((T1-h.Position).X,0,(T1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*currentSpeed,h.AssemblyLinearVelocity.Y,dir.Z*currentSpeed)
        elseif autoRightPhase == 2 then
            local dist=(Vector3.new(T2.X,h.Position.Y,T2.Z)-h.Position).Magnitude
            if dist < 1 then
                hum:Move(Vector3.zero,false) h.AssemblyLinearVelocity=Vector3.new(0,0,0)
                AutoRightEnabled=false Enabled.AutoRightEnabled=false
                if autoRightConnection then autoRightConnection:Disconnect() autoRightConnection=nil end
                autoRightPhase=1
                if VisualSetters.AutoRightEnabled then VisualSetters.AutoRightEnabled(false,true) end
                faceNorth() return
            end
            if arStuckTimer > 0.4 then
                arStuckTimer=0
                local sd=(T2-h.Position)
                local ss=Vector3.new(sd.X,0,sd.Z).Unit*math.min(4,sd.Magnitude)
                h.CFrame=CFrame.new(h.Position+ss) h.AssemblyLinearVelocity=Vector3.zero return
            end
            local dir=Vector3.new((T2-h.Position).X,0,(T2-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*currentSpeed,h.AssemblyLinearVelocity.Y,dir.Z*currentSpeed)
        end
    end)
end

local function startAutoLeftPlay()
    if autoLeftPlayConnection then autoLeftPlayConnection:Disconnect() end
    autoLeftPlayPhase=1
    autoLeftPlayConnection=RunService.Heartbeat:Connect(function()
        if not AutoLeftPlayEnabled then return end
        local c=LocalPlayer.Character if not c then return end
        local h=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local P1=wpPos(WP.LeftPlay[1]); local P2=wpPos(WP.LeftPlay[2]); local P3=wpPos(WP.LeftPlay[3])
        if autoLeftPlayPhase==1 then
            local dist=(Vector3.new(P1.X,h.Position.Y,P1.Z)-h.Position).Magnitude
            if dist<1.5 then speedToggled=true autoLeftPlayPhase=2 if modeLabel then modeLabel.Text="Mode: Carry" end return end
            local dir=Vector3.new((P1-h.Position).X,0,(P1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*NORMAL_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*NORMAL_SPEED)
        elseif autoLeftPlayPhase==2 then
            local dist=(Vector3.new(P2.X,h.Position.Y,P2.Z)-h.Position).Magnitude
            if dist<1.5 then autoLeftPlayPhase=3 return end
            local dir=Vector3.new((P2-h.Position).X,0,(P2-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        elseif autoLeftPlayPhase==3 then
            local dist=(Vector3.new(P1.X,h.Position.Y,P1.Z)-h.Position).Magnitude
            if dist<1.5 then autoLeftPlayPhase=4 return end
            local dir=Vector3.new((P1-h.Position).X,0,(P1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        elseif autoLeftPlayPhase==4 then
            local dist=(Vector3.new(P3.X,h.Position.Y,P3.Z)-h.Position).Magnitude
            if dist<1.5 then
                hum:Move(Vector3.zero,false) h.AssemblyLinearVelocity=Vector3.new(0,0,0)
                AutoLeftPlayEnabled=false Enabled.AutoLeftPlayEnabled=false
                if autoLeftPlayConnection then autoLeftPlayConnection:Disconnect() autoLeftPlayConnection=nil end
                autoLeftPlayPhase=1 speedToggled=true
                if modeLabel then modeLabel.Text="Mode: Carry" end
                if VisualSetters.AutoLeftPlayEnabled then VisualSetters.AutoLeftPlayEnabled(false,true) end
                return
            end
            local dir=Vector3.new((P3-h.Position).X,0,(P3-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        end
    end)
end

local function startAutoRightPlay()
    if autoRightPlayConnection then autoRightPlayConnection:Disconnect() end
    autoRightPlayPhase=1
    autoRightPlayConnection=RunService.Heartbeat:Connect(function()
        if not AutoRightPlayEnabled then return end
        local c=LocalPlayer.Character if not c then return end
        local h=c:FindFirstChild("HumanoidRootPart")
        local hum=c:FindFirstChildOfClass("Humanoid")
        if not h or not hum then return end
        local P1=wpPos(WP.RightPlay[1]); local P2=wpPos(WP.RightPlay[2]); local P3=wpPos(WP.RightPlay[3])
        if autoRightPlayPhase==1 then
            local dist=(Vector3.new(P1.X,h.Position.Y,P1.Z)-h.Position).Magnitude
            if dist<1.5 then speedToggled=true autoRightPlayPhase=2 if modeLabel then modeLabel.Text="Mode: Carry" end return end
            local dir=Vector3.new((P1-h.Position).X,0,(P1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*NORMAL_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*NORMAL_SPEED)
        elseif autoRightPlayPhase==2 then
            local dist=(Vector3.new(P2.X,h.Position.Y,P2.Z)-h.Position).Magnitude
            if dist<1.5 then autoRightPlayPhase=3 return end
            local dir=Vector3.new((P2-h.Position).X,0,(P2-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        elseif autoRightPlayPhase==3 then
            local dist=(Vector3.new(P1.X,h.Position.Y,P1.Z)-h.Position).Magnitude
            if dist<1.5 then autoRightPlayPhase=4 return end
            local dir=Vector3.new((P1-h.Position).X,0,(P1-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        elseif autoRightPlayPhase==4 then
            local dist=(Vector3.new(P3.X,h.Position.Y,P3.Z)-h.Position).Magnitude
            if dist<1.5 then
                hum:Move(Vector3.zero,false) h.AssemblyLinearVelocity=Vector3.new(0,0,0)
                AutoRightPlayEnabled=false Enabled.AutoRightPlayEnabled=false
                if autoRightPlayConnection then autoRightPlayConnection:Disconnect() autoRightPlayConnection=nil end
                autoRightPlayPhase=1 speedToggled=true
                if modeLabel then modeLabel.Text="Mode: Carry" end
                if VisualSetters.AutoRightPlayEnabled then VisualSetters.AutoRightPlayEnabled(false,true) end
                return
            end
            local dir=Vector3.new((P3-h.Position).X,0,(P3-h.Position).Z).Unit
            hum:Move(dir,false) h.AssemblyLinearVelocity=Vector3.new(dir.X*CARRY_SPEED,h.AssemblyLinearVelocity.Y,dir.Z*CARRY_SPEED)
        end
    end)
end



-- ==========================================
-- BAT AIMBOT
-- ==========================================

-- ================================================
-- BAT AIMBOT  v3  –  camera lock + corp lock + auto-swing
-- ================================================
local AIMBOT_SPEED      = 58      -- viteza de miscare spre target
local AIMBOT_SWING_DIST = 3       -- distanta la care activeaza batul (mai mic = mai aproape)
local AIMBOT_CAM_SMOOTH = 0.18
local AIMBOT_JUMP_SPEED = 40      -- viteza verticala cand inamicul e sus
local aimbotLastSwing   = 0
local BAT_SWING_COOLDOWN = 0.18
local lastBatSwing       = 0
local hittingCooldown    = false

-- ==========================================
-- BAT AIMBOT - ADAPTAT LA BONT (fără schimbare de logică)
-- ==========================================

local function getBat()
    local char = LocalPlayer.Character; if not char then return nil end
    local tool = char:FindFirstChild("Bat"); if tool then return tool end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then tool=bp:FindFirstChild("Bat"); if tool then tool.Parent=char; return tool end end
    return nil
end

local function getClosestPlayer()
    local c = LocalPlayer.Character; if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart"); if not hrp then return nil end
    local cp, cd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < cd then cd = d; cp = p end
            end
        end
    end
    return cp
end

local function findBat()
    local c = LocalPlayer.Character; if not c then return nil end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    local SlapList = {"Bat","Slap","Iron Slap","Gold Slap","Diamond Slap","Emerald Slap","Ruby Slap","Dark Matter Slap","Flame Slap","Nuclear Slap","Galaxy Slap","Glitched Slap"}
    for _, name in ipairs(SlapList) do
        local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if t then return t end
    end
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    return nil
end

-- ==================== FUNCȚIA PRINCIPALĂ ====================
local function startBatAimbot()
    if Connections.batAimbot then return end
    
    Connections.batAimbot = RunService.Heartbeat:Connect(function()
        if not Enabled.BatAimbot or not autoBatToggled then return end

        local now = tick()

        local c = LocalPlayer.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- Mișcare rapidă spre țintă (logica ta originală)
        local target = getClosestPlayer()
        if target and target.Character then
            local tr = target.Character:FindFirstChild("HumanoidRootPart")
            if tr then
                local fp = tr.Position + tr.CFrame.LookVector * 1.5
                local dir = (fp - hrp.Position).Unit
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X*56.5, dir.Y*56.5, dir.Z*56.5)
            end
        end

        -- Auto equip + swing (logica ta originală)
        local bat = findBat()
        if bat then
            if bat.Parent ~= c then 
                local hum2 = c:FindFirstChildOfClass("Humanoid")
                if hum2 then hum2:EquipTool(bat) end 
            end

            if now - lastBatSwing >= BAT_SWING_COOLDOWN and not hittingCooldown then
                lastBatSwing = now
                hittingCooldown = true
                pcall(function() bat:Activate() end)
                task.delay(0.18, function() hittingCooldown = false end)
            end
        end
    end)
end

local function stopBatAimbot()
    if Connections.batAimbot then
        Connections.batAimbot:Disconnect()
        Connections.batAimbot = nil
    end
    hittingCooldown = false
end

-- ==========================================
-- CHARACTER SETUP  (identic cu Bont ? lipsea complet din bont_hub)
-- ==========================================
local function setupChar(char)
    h   = char:WaitForChild("Humanoid")
    hrp = char:WaitForChild("HumanoidRootPart")
    h.Died:Connect(function()
        h   = nil
        hrp = nil
    end)
    local head = char:FindFirstChild("Head")
    if head then
        for _, c in ipairs(head:GetChildren()) do
            if c:IsA("BillboardGui") and c.Name == "BontHubSpeedBB" then c:Destroy() end
        end
        local bb = Instance.new("BillboardGui", head)
        bb.Name = "BontHubSpeedBB"
        bb.Size = UDim2.new(0, 160, 0, 40)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.AlwaysOnTop = true
        speedLbl = Instance.new("TextLabel", bb)
        speedLbl.Size = UDim2.new(1, 0, 1, 0)
        speedLbl.BackgroundTransparency = 1
        speedLbl.TextColor3 = Color3.fromRGB(190, 180, 255)
        speedLbl.Font = Enum.Font.GothamBlack
        speedLbl.TextSize = 15
        speedLbl.TextStrokeTransparency = 0.1
        speedLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        speedLbl.TextScaled = false
    end
end

-- CharacterAdded principal ? reset auto-movements + setupChar (identic Bont)
LocalPlayer.CharacterAdded:Connect(function(char)
    AutoLeftEnabled = false;      Enabled.AutoLeftEnabled = false
    AutoRightEnabled = false;     Enabled.AutoRightEnabled = false
    AutoLeftPlayEnabled = false;  Enabled.AutoLeftPlayEnabled = false
    AutoRightPlayEnabled = false; Enabled.AutoRightPlayEnabled = false
    if autoLeftConnection      then autoLeftConnection:Disconnect();      autoLeftConnection = nil end
    if autoRightConnection     then autoRightConnection:Disconnect();     autoRightConnection = nil end
    if autoLeftPlayConnection  then autoLeftPlayConnection:Disconnect();  autoLeftPlayConnection = nil end
    if autoRightPlayConnection then autoRightPlayConnection:Disconnect(); autoRightPlayConnection = nil end
    if VisualSetters.AutoLeftEnabled      then VisualSetters.AutoLeftEnabled(false, true) end
    if VisualSetters.AutoRightEnabled     then VisualSetters.AutoRightEnabled(false, true) end
    if VisualSetters.AutoLeftPlayEnabled  then VisualSetters.AutoLeftPlayEnabled(false, true) end
    if VisualSetters.AutoRightPlayEnabled then VisualSetters.AutoRightPlayEnabled(false, true) end
    setupChar(char)
end)

-- Initializare imediata pentru characterul existent la momentul load-ului
task.defer(function()
    if LocalPlayer.Character then setupChar(LocalPlayer.Character) end
end)

-- ==========================================
-- SPEED HEARTBEAT
-- ==========================================
do
    local labelAcc = 0
    local lastSpeedLabelText = ""

    RunService.Heartbeat:Connect(function(dt)
        if not (h and hrp) or not h.Parent then return end

        if not (AutoLeftEnabled or AutoRightEnabled or AutoLeftPlayEnabled or AutoRightPlayEnabled) then
            local md = h.MoveDirection
            local speed = lowSpeedToggled and LOW_SPEED_VALUE or (speedToggled and CARRY_SPEED or NORMAL_SPEED)

            if md.Magnitude > SPEED_APPLY_EPSILON then
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * speed, hrp.AssemblyLinearVelocity.Y, md.Z * speed)
            end
        end

        if speedLbl then
            labelAcc = labelAcc + dt
            if labelAcc >= SPEED_LABEL_UPDATE_RATE then
                labelAcc = 0
                local v = hrp.AssemblyLinearVelocity
                local spd = math.floor(Vector3.new(v.X, 0, v.Z).Magnitude + 0.5)
                local mode = lowSpeedToggled and ("LOW " .. tostring(LOW_SPEED_VALUE)) or (speedToggled and "CARRY" or "NORMAL")
                local nextText = spd .. " - " .. mode
                if nextText ~= lastSpeedLabelText then
                    speedLbl.Text = nextText
                    lastSpeedLabelText = nextText
                end
            end
        end
    end)
end

-- ==========================================
-- CONFIG SAVE / LOAD
-- ==========================================
local function saveConfig()
    local cfg = {
        normalSpeed=NORMAL_SPEED, carrySpeed=CARRY_SPEED,
        autoBatKey=autoBatKey.Name, speedToggleKey=speedToggleKey.Name,
        autoLeftKey=autoLeftKey.Name, autoRightKey=autoRightKey.Name,
        autoLeftPlayKey=autoLeftPlayKey.Name, autoRightPlayKey=autoRightPlayKey.Name,
        floatKey=floatKey.Name, guiToggleKey=guiToggleKey.Name,
        tpDownKey=tpDownKey.Name, dropKey=dropKey.Name, lowSpeedKey=lowSpeedKey.Name,
        lowSpeedValue=LOW_SPEED_VALUE, lowSpeedEnabled=lowSpeedToggled,
        autoSteal=Enabled.AutoSteal, stealRadius=Values.STEAL_RADIUS, stealDuration=Values.STEAL_DURATION,
        antiRagdoll=Enabled.AntiRagdoll, galaxy=Enabled.Galaxy,
        galaxyGravity=Values.GalaxyGravityPercent, hopPower=Values.HOP_POWER,
        optimizer=Enabled.Optimizer, unwalk=Enabled.Unwalk, noClip=Enabled.NoClip,
        darkMode=Enabled.DarkMode, floatHeight=FLOAT_HEIGHT,
        uiTransparency=currentTransparency, mainGuiScale=MAIN_GUI_SCALE, mobileGuiScale=MOBILE_GUI_SCALE, miniGuiEnabled=Enabled.MiniGuiEnabled,
        batAimbot=Enabled.BatAimbot, ragdollTP=Enabled.RagdollTP,
        spinbot=Enabled.Spinbot, counterMedusa=Enabled.CounterMedusa,
        autoCarry=Enabled.AutoCarryOnPickup, waypointESP=Enabled.WaypointESP,
        floatEnabled=floatEnabled,
        autoLeftEnabled=AutoLeftEnabled, autoRightEnabled=AutoRightEnabled,
        autoLeftPlayEnabled=AutoLeftPlayEnabled, autoRightPlayEnabled=AutoRightPlayEnabled,
        speedToggled=speedToggled,
    }
    local json = HttpService:JSONEncode(cfg)
    local ok = false
    if writefile then local w=pcall(writefile,"BontHubConfig.json",json); if w then ok=true end end
    if getgenv   then pcall(function() getgenv().__BontHubCfg=json end); ok=true end
    pcall(function()
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui"); if not pg then return end
        local sv=pg:FindFirstChild("__BontHubCfg")
        if not sv then sv=Instance.new("StringValue"); sv.Name="__BontHubCfg"; sv.Parent=pg end
        sv.Value=json; ok=true
    end)
    return ok
end

local function loadConfig()
    local raw = nil
    -- 1. file
    if isfile and readfile then
        local ex=false; pcall(function() ex=isfile("BontHubConfig.json") end)
        if ex then local ok,r=pcall(readfile,"BontHubConfig.json"); if ok and type(r)=="string" and #r>2 then raw=r end end
    end
    -- 2. getgenv
    if not raw and getgenv then
        pcall(function() local v=getgenv().__BontHubCfg; if type(v)=="string" and #v>2 then raw=v end end)
    end
    -- 3. PlayerGui StringValue
    if not raw then pcall(function()
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui"); if not pg then return end
        local sv=pg:FindFirstChild("__BontHubCfg")
        if sv and type(sv.Value)=="string" and #sv.Value>2 then raw=sv.Value end
    end) end
    if not raw then return end
    local ok,cfg=pcall(HttpService.JSONDecode,HttpService,raw)
    if not ok or type(cfg)~="table" then return end
    if cfg.normalSpeed and cfg.normalSpeed>=10 and cfg.normalSpeed<=300 then NORMAL_SPEED=cfg.normalSpeed end
    if cfg.carrySpeed  and cfg.carrySpeed >=10 and cfg.carrySpeed <=300 then CARRY_SPEED =cfg.carrySpeed  end
    if cfg.speedToggleKey    and Enum.KeyCode[cfg.speedToggleKey]    then speedToggleKey    =Enum.KeyCode[cfg.speedToggleKey]    end
    if cfg.autoLeftKey       and Enum.KeyCode[cfg.autoLeftKey]       then autoLeftKey       =Enum.KeyCode[cfg.autoLeftKey]       end
    if cfg.autoRightKey      and Enum.KeyCode[cfg.autoRightKey]      then autoRightKey      =Enum.KeyCode[cfg.autoRightKey]      end
    if cfg.autoLeftPlayKey   and Enum.KeyCode[cfg.autoLeftPlayKey]   then autoLeftPlayKey   =Enum.KeyCode[cfg.autoLeftPlayKey]   end
    if cfg.autoRightPlayKey  and Enum.KeyCode[cfg.autoRightPlayKey]  then autoRightPlayKey  =Enum.KeyCode[cfg.autoRightPlayKey]  end
    if cfg.floatKey          and Enum.KeyCode[cfg.floatKey]          then floatKey          =Enum.KeyCode[cfg.floatKey]          end
    if cfg.guiToggleKey      and Enum.KeyCode[cfg.guiToggleKey]      then guiToggleKey      =Enum.KeyCode[cfg.guiToggleKey]      end
    if cfg.tpDownKey         and Enum.KeyCode[cfg.tpDownKey]         then tpDownKey         =Enum.KeyCode[cfg.tpDownKey]         end
    if cfg.dropKey           and Enum.KeyCode[cfg.dropKey]           then dropKey           =Enum.KeyCode[cfg.dropKey]           end
    if cfg.autoBatKey        and Enum.KeyCode[cfg.autoBatKey]        then autoBatKey        =Enum.KeyCode[cfg.autoBatKey]        end
    if cfg.lowSpeedKey       and Enum.KeyCode[cfg.lowSpeedKey]       then lowSpeedKey       =Enum.KeyCode[cfg.lowSpeedKey]       end
    if cfg.lowSpeedValue     then LOW_SPEED_VALUE = math.clamp(tonumber(cfg.lowSpeedValue) or 13, 10, 20) end
    if cfg.stealRadius   then Values.STEAL_RADIUS=cfg.stealRadius end
    if cfg.stealDuration then Values.STEAL_DURATION=cfg.stealDuration end
    if cfg.galaxyGravity then Values.GalaxyGravityPercent=cfg.galaxyGravity end
    if cfg.hopPower      then Values.HOP_POWER=cfg.hopPower end
    if cfg.floatHeight   then FLOAT_HEIGHT=math.clamp(cfg.floatHeight,1,20) end
    if cfg.uiTransparency then currentTransparency=math.clamp(cfg.uiTransparency,0,1) end
    if cfg.mainGuiScale   then MAIN_GUI_SCALE=math.clamp(cfg.mainGuiScale,0.25,1.0) end
    if cfg.mobileGuiScale then MOBILE_GUI_SCALE=math.clamp(cfg.mobileGuiScale,0.25,1.0) end
    if cfg.antiRagdoll     ~=nil then Enabled.AntiRagdoll      =cfg.antiRagdoll     end
    if cfg.autoSteal       ~=nil then Enabled.AutoSteal         =cfg.autoSteal       end
    if cfg.galaxy          ~=nil then Enabled.Galaxy            =cfg.galaxy          end
    if cfg.optimizer       ~=nil then Enabled.Optimizer         =cfg.optimizer       end
    if cfg.unwalk          ~=nil then Enabled.Unwalk            =cfg.unwalk          end
    if cfg.noClip          ~=nil then Enabled.NoClip            =cfg.noClip          end
    if cfg.darkMode        ~=nil then Enabled.DarkMode          =cfg.darkMode        end
    if cfg.batAimbot       ~=nil then Enabled.BatAimbot         =cfg.batAimbot       end
    if cfg.ragdollTP       ~=nil then Enabled.RagdollTP         =cfg.ragdollTP       end
    if cfg.spinbot         ~=nil then Enabled.Spinbot           =cfg.spinbot         end
    if cfg.counterMedusa   ~=nil then Enabled.CounterMedusa     =cfg.counterMedusa   end
    if cfg.autoCarry       ~=nil then Enabled.AutoCarryOnPickup =cfg.autoCarry       end
    if cfg.waypointESP     ~=nil then Enabled.WaypointESP       =cfg.waypointESP     end
    if cfg.miniGuiEnabled  ~=nil then Enabled.MiniGuiEnabled    =cfg.miniGuiEnabled  end
    if cfg.floatEnabled    ~=nil then floatEnabled              =cfg.floatEnabled    end
    if cfg.autoLeftEnabled      ~=nil then AutoLeftEnabled      =cfg.autoLeftEnabled      end
    if cfg.autoRightEnabled     ~=nil then AutoRightEnabled     =cfg.autoRightEnabled     end
    if cfg.autoLeftPlayEnabled  ~=nil then AutoLeftPlayEnabled  =cfg.autoLeftPlayEnabled  end
    if cfg.autoRightPlayEnabled ~=nil then AutoRightPlayEnabled =cfg.autoRightPlayEnabled end
    if cfg.speedToggled    ~=nil then speedToggled              =cfg.speedToggled    end
    if cfg.lowSpeedEnabled  ~=nil then lowSpeedToggled            =cfg.lowSpeedEnabled  end
    Enabled.LowSpeedEnabled = lowSpeedToggled
end

loadConfig()

-- auto-save every 30s
task.spawn(function() while task.wait(30) do pcall(saveConfig) end end)

-- ==========================================
-- COUNTER MEDUSA  (Eppilson source, faster cooldowns)
-- ==========================================
local medusaNames = { ["medusa's head"]=true, ["medusa"]=true }
local medusaCounterConn    = nil
local medusaToolConns      = {}
local medusaPlayerConns    = {}
local lastMedusaUse        = 0
local lastBoogieUse        = 0

local function isMedusaToolName(name)
    if not name then return false end
    local lower = name:lower()
    if medusaNames[lower] then return true end
    return lower:find("medusa") ~= nil
end

local function isBoogieName(name)
    if not name then return false end
    return name:lower():find("boogie") ~= nil
end

local function safeDiscMedusa(conn)
    if conn and typeof(conn) == "RBXScriptConnection" then
        pcall(function() conn:Disconnect() end)
    end
end

local function getMedusaTool()
    local char = LocalPlayer.Character
    if char then
        for _, i in ipairs(char:GetChildren()) do
            if i:IsA("Tool") and isMedusaToolName(i.Name) then return i end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, i in ipairs(bp:GetChildren()) do
            if i:IsA("Tool") and isMedusaToolName(i.Name) then return i end
        end
    end
end

local function getBoogieTool()
    local char = LocalPlayer.Character
    if char then
        for _, i in ipairs(char:GetChildren()) do
            if i:IsA("Tool") and isBoogieName(i.Name) then return i end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, i in ipairs(bp:GetChildren()) do
            if i:IsA("Tool") and isBoogieName(i.Name) then return i end
        end
    end
end

local function enemyHasMedusa(character)
    if not character then return false end
    for _, i in ipairs(character:GetChildren()) do
        if i:IsA("Tool") and isMedusaToolName(i.Name) then return true end
    end
    return false
end

local function activateMedusa(tool)
    if not tool then return end
    local now = workspace:GetServerTimeNow()
    if now - lastMedusaUse <= 0.3 then return end  -- faster: was 1.5s
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if tool.Parent ~= LocalPlayer.Character then pcall(function() hum:EquipTool(tool) end) end
    pcall(function() if type(tool.Activate) == "function" then tool:Activate() end end)
    lastMedusaUse = now
    task.delay(0.1, function()  -- faster: was 0.35s
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:UnequipTools() end) end
    end)
end

local function activateBoogie(tool)
    if not tool then return end
    local now = workspace:GetServerTimeNow()
    if now - lastBoogieUse <= 0.3 then return end  -- faster: was 1.5s
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if tool.Parent ~= LocalPlayer.Character then pcall(function() hum:EquipTool(tool) end) end
    pcall(function() if type(tool.Activate) == "function" then tool:Activate() end end)
    lastBoogieUse = now
    task.delay(0.1, function()  -- faster: was 0.35s
        local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:UnequipTools() end) end
    end)
end

local function useCounterTool()
    local now = workspace:GetServerTimeNow()
    if now - lastMedusaUse > 0.3 then
        local t = getMedusaTool()
        if t then activateMedusa(t); return true end
    end
    if now - lastBoogieUse > 0.3 then
        local t = getBoogieTool()
        if t then activateBoogie(t); return true end
    end
    return false
end

local function unbindMedusaTool(tool)
    if medusaToolConns[tool] then
        safeDiscMedusa(medusaToolConns[tool])
        medusaToolConns[tool] = nil
    end
end

local function bindMedusaTool(tool)
    if not tool or not tool:IsA("Tool") or medusaToolConns[tool] then return end
    if not isMedusaToolName(tool.Name) then return end
    local conn = tool.Activated:Connect(function()
        if not Enabled.CounterMedusa then return end
        local attackerRoot = tool.Parent and tool.Parent:FindFirstChild("HumanoidRootPart")
        local myHRP = getHRP()
        if not (attackerRoot and myHRP) then return end
        if (attackerRoot.Position - myHRP.Position).Magnitude <= 20 then
            useCounterTool()
        end
    end)
    medusaToolConns[tool] = conn
    tool.Destroying:Connect(function() unbindMedusaTool(tool) end)
end

local function unbindPlayerMedusa(plr)
    local list = medusaPlayerConns[plr]
    if list then
        for _, c in ipairs(list) do safeDiscMedusa(c) end
        medusaPlayerConns[plr] = nil
    end
end

local function bindPlayerMedusa(plr)
    if not plr or plr == LocalPlayer then return end
    unbindPlayerMedusa(plr)
    local conns = {}
    local function scan(char)
        if not char then return end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then bindMedusaTool(child) end
        end
        table.insert(conns, char.ChildAdded:Connect(function(obj)
            if obj:IsA("Tool") then bindMedusaTool(obj) end
        end))
    end
    local cChar = plr.Character or plr.CharacterAdded:Wait()
    scan(cChar)
    table.insert(conns, plr.CharacterAdded:Connect(function(c) scan(c) end))
    medusaPlayerConns[plr] = conns
end

local function startCounterMedusa()
    if medusaCounterConn then return end
    Enabled.CounterMedusa = true
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then bindPlayerMedusa(plr) end
    end
    medusaPlayerConns["_added"] = Players.PlayerAdded:Connect(bindPlayerMedusa)
    medusaCounterConn = RunService.Heartbeat:Connect(function()
        if not Enabled.CounterMedusa then return end
        local myHRP = getHRP(); if not myHRP then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local ch = plr.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp and enemyHasMedusa(ch) then
                    if (hrp.Position - myHRP.Position).Magnitude <= 5 then
                        useCounterTool(); break
                    end
                end
            end
        end
    end)
end

local function stopCounterMedusa()
    Enabled.CounterMedusa = false
    if medusaCounterConn then safeDiscMedusa(medusaCounterConn); medusaCounterConn = nil end
    if medusaPlayerConns["_added"] then safeDiscMedusa(medusaPlayerConns["_added"]); medusaPlayerConns["_added"] = nil end
    for tool, _ in pairs(medusaToolConns) do unbindMedusaTool(tool) end
    for plr, _ in pairs(medusaPlayerConns) do
        if plr ~= "_added" then unbindPlayerMedusa(plr) end
    end
end

-- ==========================================
-- RAGDOLL TP
-- ==========================================
local TP_PRE_STEP = Vector3.new(-452.5, -6.6, 57.7)
local TP_STEPS = {
    Left  = { Vector3.new(-475.0, -6.6, 94.7), Vector3.new(-482.6, -4.7, 94.6) },
    Right = { Vector3.new(-475.2, -6.6, 23.5), Vector3.new(-482.2, -4.7, 23.4) },
}
local TP_PRE_STEP_DELAY = 0.10
local TP_STEP_DELAY     = 0.10
local TP_COOLDOWN_SEC   = 1.2

local MEDUSA_OBJECT_NAMES = {
    ["Petrified"]=true,["Petrify"]=true,["Stone"]=true,["MedusaStone"]=true,
    ["MedusaEffect"]=true,["Stoned"]=true,["MedusaHead"]=true,["Frozen"]=true,
    ["Statue"]=true,["PetrifyEffect"]=true,
}

local function isCharacterPetrified(char)
    if not char then return false end
    for _, obj in ipairs(char:GetChildren()) do
        if MEDUSA_OBJECT_NAMES[obj.Name] then return true end
        if obj:IsA("BoolValue") or obj:IsA("IntValue") then
            local low = obj.Name:lower()
            if low:find("medusa") or low:find("petri") or low:find("stone") or low:find("statue") then return true end
        end
    end
    local ok, CS = pcall(function() return game:GetService("CollectionService") end)
    if ok and CS then
        for _, tag in ipairs(CS:GetTags(char)) do
            local low = tag:lower()
            if low:find("medusa") or low:find("petri") or low:find("stone") or low:find("statue") then return true end
        end
    end
    return false
end

local function tpMoveTo(pos)
    local r = getHRP(); if not r then return end
    r.CFrame = CFrame.new(pos)
    r.AssemblyLinearVelocity = Vector3.zero
end

local function detectEnemySide()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return "Left" end
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yb = sign:FindFirstChild("YourBase")
            if yb and yb:IsA("BillboardGui") and yb.Enabled then
                local part = plot:FindFirstChildWhichIsA("BasePart")
                local z = part and part.Position.Z or 0
                return z > 60 and "Right" or "Left"
            end
        end
    end
    return "Left"
end

local function teleportToBase()
    if tpCooldown then return end
    if isCharacterPetrified(LocalPlayer.Character) then return end
    tpCooldown = true
    local side = detectEnemySide()
    local steps = TP_STEPS[side]
    tpMoveTo(TP_PRE_STEP)
    task.delay(TP_PRE_STEP_DELAY, function()
        tpMoveTo(steps[1])
        task.delay(TP_STEP_DELAY, function()
            tpMoveTo(steps[2])
            task.wait(0.05)
            tpMoveTo(steps[2])
            task.delay(TP_COOLDOWN_SEC, function() tpCooldown = false end)
        end)
    end)
end

local TP_RAGDOLL_STATES = {
    [Enum.HumanoidStateType.Physics]     = true,
    [Enum.HumanoidStateType.FallingDown] = true,
    [Enum.HumanoidStateType.Ragdoll]     = true,
}

local function hookTPCharacter(char)
    if tpStateConn    then tpStateConn:Disconnect();    tpStateConn    = nil end
    if tpChildConn    then tpChildConn:Disconnect();    tpChildConn    = nil end
    if tpChildRemConn then tpChildRemConn:Disconnect(); tpChildRemConn = nil end
    local hum = char:WaitForChild("Humanoid")
    tpStateConn = hum.StateChanged:Connect(function(_, newState)
        if not Enabled.RagdollTP then return end
        if TP_RAGDOLL_STATES[newState] then
            if isCharacterPetrified(char) then return end
            if not tpWasRagdolled then tpWasRagdolled = true; task.defer(teleportToBase) end
        else
            tpWasRagdolled = false
        end
    end)
    tpChildConn = char.ChildAdded:Connect(function(child)
        if not Enabled.RagdollTP then return end
        if MEDUSA_OBJECT_NAMES[child.Name] then tpWasRagdolled = false; return end
        if child:IsA("BoolValue") or child:IsA("IntValue") then
            local low = child.Name:lower()
            if low:find("medusa") or low:find("petri") or low:find("stone") or low:find("statue") then
                tpWasRagdolled = false; return
            end
        end
        if child.Name == "Ragdoll" or child.Name == "IsRagdoll" then
            if not tpWasRagdolled then tpWasRagdolled = true; task.defer(teleportToBase) end
        end
    end)
    tpChildRemConn = char.ChildRemoved:Connect(function(child)
        if child.Name == "Ragdoll" or child.Name == "IsRagdoll" then tpWasRagdolled = false end
    end)
end

local function startRagdollTP()
    tpWasRagdolled = false; tpCooldown = false
    local char = LocalPlayer.Character
    if char then hookTPCharacter(char) end
end

local function stopRagdollTP()
    if tpStateConn    then tpStateConn:Disconnect();    tpStateConn    = nil end
    if tpChildConn    then tpChildConn:Disconnect();    tpChildConn    = nil end
    if tpChildRemConn then tpChildRemConn:Disconnect(); tpChildRemConn = nil end
    tpWasRagdolled = false
end

LocalPlayer.CharacterAdded:Connect(function(char)
    tpWasRagdolled = false; tpCooldown = false
    if Enabled.RagdollTP then hookTPCharacter(char) end
end)

-- All waypoints across all 4 routes - covers Left, Right, LeftPlay, RightPlay
-- Each entry holds a direct reference to the WP entry so offset changes propagate instantly
local ESP_DEFS = {
    { wpFn = function() return WP.Left[1]      end, label = "L1",  color = Color3.fromRGB(109, 112, 255) },
    { wpFn = function() return WP.Left[2]      end, label = "L2",  color = Color3.fromRGB(150,  90, 255) },
    { wpFn = function() return WP.Right[1]     end, label = "R1",  color = Color3.fromRGB(52,  211, 153) },
    { wpFn = function() return WP.Right[2]     end, label = "R2",  color = Color3.fromRGB(36,  180, 120) },
    { wpFn = function() return WP.LeftPlay[1]  end, label = "LP1", color = Color3.fromRGB(251, 191,  36) },
    { wpFn = function() return WP.LeftPlay[2]  end, label = "LP2", color = Color3.fromRGB(255, 160,  30) },
    { wpFn = function() return WP.LeftPlay[3]  end, label = "LP3", color = Color3.fromRGB(255, 120,  20) },
    { wpFn = function() return WP.RightPlay[1] end, label = "RP1", color = Color3.fromRGB(248, 113, 113) },
    { wpFn = function() return WP.RightPlay[2] end, label = "RP2", color = Color3.fromRGB(240,  80,  80) },
    { wpFn = function() return WP.RightPlay[3] end, label = "RP3", color = Color3.fromRGB(220,  50,  50) },
}

-- Direct part references keyed by def index - rebuilt in buildESP
local espParts = {}

-- Call this any time a waypoint offset changes to immediately move its ESP marker
local function refreshESPPart(defIdx)
    local entry = espParts[defIdx]
    if not entry then return end
    local def = ESP_DEFS[defIdx]
    local wp  = def.wpFn()
    local newPos = wpPos(wp)
    entry.part.CFrame = CFrame.new(newPos)
    -- Update billboard label to show offset if non-zero
    local ox, oz = math.floor(wp.offset.X), math.floor(wp.offset.Z)
    local suffix = (ox ~= 0 or oz ~= 0) and (" [" .. ox .. "," .. oz .. "]") or ""
    entry.lbl.Text = def.label .. suffix
end

-- Expose so the waypoint editor can call it immediately on offset change
_G.BontHubESPRefresh = refreshESPPart
-- Expose the full rebuild for when ESP is toggled back on
_G.BontESPRebuild = nil  -- set below

local function buildESP()
    if espFolder then espFolder:Destroy() end
    espFolder = Instance.new("Folder")
    espFolder.Name = "BontHubMiniESP"
    espFolder.Parent = workspace
    espParts = {}

    for idx, def in ipairs(ESP_DEFS) do
        local wp  = def.wpFn()
        local pos = wpPos(wp)

        local part = Instance.new("Part")
        part.Name = "ESPBox_" .. def.label
        part.Size = Vector3.new(1.5, 2.5, 1.5)
        part.CFrame = CFrame.new(pos)
        part.Anchored = true
        part.CanCollide = false; part.CanQuery = false; part.CanTouch = false
        part.Transparency = 1
        part.Parent = espFolder

        local box = Instance.new("BoxHandleAdornment")
        box.Adornee = part; box.Size = part.Size
        box.Color3 = def.color; box.AlwaysOnTop = true
        box.ZIndex = 5; box.Transparency = 0.5
        box.Parent = part

        local sel = Instance.new("SelectionBox")
        sel.Adornee = part; sel.Color3 = def.color
        sel.LineThickness = 0.04; sel.SurfaceTransparency = 1
        sel.Parent = part

        local bb = Instance.new("BillboardGui")
        bb.Adornee = part; bb.Size = UDim2.new(0, 110, 0, 22)
        bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
        bb.Parent = part

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0); lbl.BackgroundTransparency = 1
        lbl.Text = def.label; lbl.TextColor3 = def.color
        lbl.Font = Enum.Font.GothamBlack; lbl.TextSize = 12
        lbl.TextStrokeTransparency = 0.1; lbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        lbl.Parent = bb

        -- Store direct refs so refreshESPPart can update without searching
        espParts[idx] = { part = part, box = box, lbl = lbl }
    end

    -- Animate box pulse on heartbeat - pure visual, no position recalc needed here
    -- (positions are updated immediately via refreshESPPart on offset change)
    if espConn then espConn:Disconnect() end
    espConn = RunService.Heartbeat:Connect(function()
        if not Enabled.WaypointESP or not espFolder or not espFolder.Parent then return end
        local t = tick()
        for _, entry in pairs(espParts) do
            if entry.box and entry.box.Parent then
                entry.box.Transparency = 0.45 + 0.25 * math.abs(math.sin(t * 1.8))
            end
        end
    end)
end

_G.BontESPRebuild = buildESP

local function startWaypointESP()
    buildESP(); Enabled.WaypointESP = true
end

local function stopWaypointESP()
    Enabled.WaypointESP = false
    if espConn then espConn:Disconnect(); espConn = nil end
    if espFolder then espFolder:Destroy(); espFolder = nil end
    espParts = {}
end

-- ==========================================
-- SPINBOT
-- ==========================================
local spinConn        = nil
local spinAngle       = 0
local spinAutoRotConn = nil
local SPIN_SPEED      = 18 -- degrees per frame (kept for nudge compat)
local SPIN_RAD_S      = 60 -- radians per second of angular velocity

local function cleanupSpin()
    if spinAutoRotConn then spinAutoRotConn:Disconnect(); spinAutoRotConn = nil end
    RunService:UnbindFromRenderStep("BontSpinbot")
    -- Zero out any leftover angular velocity
    local hrp = getHRP()
    if hrp then pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end) end
    -- Restore AutoRotate
    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.AutoRotate = true end) end
end

local function startSpinbot()
    if spinConn then return end
    Enabled.Spinbot = true
    spinAngle = 0

    RunService:UnbindFromRenderStep("BontSpinbot")

    -- Suppress AutoRotate every heartbeat so shiftlock can never reclaim it
    if spinAutoRotConn then spinAutoRotConn:Disconnect() end
    spinAutoRotConn = RunService.Heartbeat:Connect(function()
        if not Enabled.Spinbot then return end
        local c = LocalPlayer.Character; if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum and hum.AutoRotate then
            pcall(function() hum.AutoRotate = false end)
        end
    end)

    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.AutoRotate = false end) end

    -- Drive spin via raw angular velocity - nothing can override this,
    -- not shiftlock, not BodyGyro, not AlignOrientation conflicts.
    -- Y-axis = yaw. Positive = counter-clockwise from above.
    RunService:BindToRenderStep("BontSpinbot", Enum.RenderPriority.Last.Value + 1, function()
        if not Enabled.Spinbot then return end
        local hrp = getHRP(); if not hrp then return end
        spinAngle = (spinAngle + SPIN_SPEED) % 360
        hrp.AssemblyAngularVelocity = Vector3.new(0, SPIN_RAD_S, 0)
    end)

    spinConn = true
end

local function stopSpinbot()
    Enabled.Spinbot = false
    spinConn = nil
    cleanupSpin()
end

LocalPlayer.CharacterAdded:Connect(function()
    if Enabled.Spinbot then
        spinConn = nil
        if spinAutoRotConn then spinAutoRotConn:Disconnect(); spinAutoRotConn = nil end
        RunService:UnbindFromRenderStep("BontSpinbot")
        task.wait(0.5)
        startSpinbot()
    end
end)

-- ==========================================
-- WAYPOINT EDITOR UI  (vertical card layout)
-- ==========================================
local wpEditorGui = nil

local WP_C = {
    bg        = Color3.fromRGB(7,  7,  14),
    card      = Color3.fromRGB(12, 12, 24),
    cardInner = Color3.fromRGB(17, 17, 34),
    border    = Color3.fromRGB(60, 55,140),
    borderDim = Color3.fromRGB(24, 22, 56),
    accent    = Color3.fromRGB(120,100,255),
    accent2   = Color3.fromRGB(190, 80,255),
    accentGlow= Color3.fromRGB(190,180,255),
    text      = Color3.fromRGB(245,245,255),
    textDim   = Color3.fromRGB(150,150,210),
    textMid   = Color3.fromRGB(70, 68,120),
    headerBg  = Color3.fromRGB(5,  5,  12),
    btnBg     = Color3.fromRGB(22, 22, 46),
    axX       = Color3.fromRGB(248,113,113),
    axZ       = Color3.fromRGB(100,180,255),
}

local function openWPPanel(side)
    if wpEditorGui and wpEditorGui.Parent then
        if wpEditorGui:GetAttribute("Side") == side then
            wpEditorGui:Destroy(); wpEditorGui = nil; return
        end
        wpEditorGui:Destroy(); wpEditorGui = nil
    end

    local wps = WP[side]
    if not wps then return end

    local PANEL_W = 220
    local HDR_H   = 52
    local CARD_H  = 80
    local CARD_GAP= 6
    local PAD     = 10
    local RESET_H = 32
    local PANEL_H = HDR_H + PAD + #wps*(CARD_H+CARD_GAP) - CARD_GAP + PAD + RESET_H + PAD

    local sideName = side:gsub("Play"," PLAY"):upper()

    local eGui = Instance.new("ScreenGui")
    eGui.Name="BontHubWPEditor"; eGui.ResetOnSpawn=false
    eGui.DisplayOrder=20; eGui.Parent=pgui
    eGui:SetAttribute("Side",side)
    wpEditorGui = eGui

    local panel = Instance.new("Frame")
    panel.Size=UDim2.new(0,PANEL_W,0,PANEL_H)
    panel.Position=UDim2.new(0.5,-PANEL_W/2,0.5,-PANEL_H/2)
    panel.BackgroundColor3=WP_C.bg
    panel.BorderSizePixel=0; panel.Active=true; panel.Draggable=true
    panel.ZIndex=50; panel.Parent=eGui
    Instance.new("UICorner",panel).CornerRadius=UDim.new(0,16)
    do local s=Instance.new("UIStroke"); s.Color=WP_C.accent; s.Thickness=1.5; s.Transparency=0.45; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Parent=panel end
    do local g=Instance.new("Frame"); g.Size=UDim2.new(0.45,0,0,1); g.Position=UDim2.new(0.275,0,0,1); g.BackgroundColor3=Color3.fromRGB(200,195,255); g.BackgroundTransparency=0.5; g.BorderSizePixel=0; g.ZIndex=60; g.Parent=panel; Instance.new("UICorner",g).CornerRadius=UDim.new(1,0) end

    -- Header
    local hdr=Instance.new("Frame"); hdr.Size=UDim2.new(1,0,0,HDR_H); hdr.BackgroundColor3=WP_C.headerBg; hdr.BorderSizePixel=0; hdr.ZIndex=51; hdr.Parent=panel
    Instance.new("UICorner",hdr).CornerRadius=UDim.new(0,16)
    do local sq=Instance.new("Frame"); sq.Size=UDim2.new(1,0,0,16); sq.Position=UDim2.new(0,0,1,-16); sq.BackgroundColor3=WP_C.headerBg; sq.BorderSizePixel=0; sq.ZIndex=51; sq.Parent=hdr end
    do local tint=Instance.new("Frame"); tint.Size=UDim2.new(1,0,1,0); tint.BackgroundColor3=WP_C.headerBg; tint.BackgroundTransparency=0; tint.BorderSizePixel=0; tint.ZIndex=51; tint.Parent=hdr; Instance.new("UICorner",tint).CornerRadius=UDim.new(0,16); local tg=Instance.new("UIGradient"); tg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(20,10,56)),ColorSequenceKeypoint.new(0.6,Color3.fromRGB(7,7,18)),ColorSequenceKeypoint.new(1,Color3.fromRGB(16,6,44))}; tg.Rotation=115; tg.Parent=tint end
    do local rule=Instance.new("Frame"); rule.Size=UDim2.new(1,0,0,2); rule.Position=UDim2.new(0,0,1,-2); rule.BackgroundColor3=WP_C.accent; rule.BorderSizePixel=0; rule.ZIndex=53; rule.Parent=hdr; local rg=Instance.new("UIGradient"); rg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),ColorSequenceKeypoint.new(0.35,WP_C.accent),ColorSequenceKeypoint.new(0.65,WP_C.accent2),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0))}; rg.Parent=rule end
    do local ico=Instance.new("Frame"); ico.Size=UDim2.new(0,32,0,32); ico.Position=UDim2.new(0,12,0.5,-16); ico.BorderSizePixel=0; ico.ZIndex=53; ico.Parent=hdr; Instance.new("UICorner",ico).CornerRadius=UDim.new(0,9); do local ig=Instance.new("UIGradient"); ig.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,WP_C.accent2),ColorSequenceKeypoint.new(1,WP_C.accent)}; ig.Rotation=135; ig.Parent=ico end; local ic=Instance.new("TextLabel"); ic.Size=UDim2.new(1,0,1,0); ic.BackgroundTransparency=1; ic.Text="COG"; ic.TextColor3=Color3.fromRGB(255,255,255); ic.Font=Enum.Font.Gotham; ic.TextSize=15; ic.ZIndex=54; ic.Parent=ico end
    do local t=Instance.new("TextLabel"); t.Size=UDim2.new(1,-80,0,20); t.Position=UDim2.new(0,52,0.5,-20); t.BackgroundTransparency=1; t.Text="AUTO "..sideName; t.TextColor3=WP_C.text; t.Font=Enum.Font.GothamBlack; t.TextSize=13; t.TextXAlignment=Enum.TextXAlignment.Left; t.ZIndex=53; t.Parent=hdr; local s=Instance.new("TextLabel"); s.Size=UDim2.new(1,-80,0,14); s.Position=UDim2.new(0,52,0.5,3); s.BackgroundTransparency=1; s.Text="checkpoint offsets"; s.TextColor3=WP_C.textMid; s.Font=Enum.Font.GothamBold; s.TextSize=9; s.TextXAlignment=Enum.TextXAlignment.Left; s.ZIndex=53; s.Parent=hdr end
    local closeBtn=Instance.new("TextButton"); closeBtn.Size=UDim2.new(0,26,0,26); closeBtn.Position=UDim2.new(1,-36,0.5,-13); closeBtn.BackgroundColor3=WP_C.btnBg; closeBtn.BorderSizePixel=0; closeBtn.Text="X"; closeBtn.TextColor3=WP_C.textDim; closeBtn.Font=Enum.Font.GothamBlack; closeBtn.TextSize=12; closeBtn.ZIndex=54; closeBtn.Parent=hdr; Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,7); do local cs=Instance.new("UIStroke"); cs.Color=WP_C.borderDim; cs.Thickness=1; cs.Parent=closeBtn end; closeBtn.MouseButton1Click:Connect(function() eGui:Destroy(); wpEditorGui=nil end)

    local boxRefs = {}

    for i, wp in ipairs(wps) do
        local cardY = HDR_H + PAD + (i-1)*(CARD_H+CARD_GAP)
        local tag   = i==1 and "START" or (i==#wps and "END" or "MID")
        local tagCol= i==1 and WP_C.accent or (i==#wps and WP_C.accent2 or WP_C.accentGlow)

        local card=Instance.new("Frame"); card.Size=UDim2.new(1,-PAD*2,0,CARD_H); card.Position=UDim2.new(0,PAD,0,cardY); card.BackgroundColor3=WP_C.card; card.BorderSizePixel=0; card.ZIndex=51; card.Parent=panel; Instance.new("UICorner",card).CornerRadius=UDim.new(0,10); do local cs=Instance.new("UIStroke"); cs.Color=WP_C.borderDim; cs.Thickness=1; cs.Parent=card end

        -- Left colour bar
        local bar=Instance.new("Frame"); bar.Size=UDim2.new(0,3,0.7,0); bar.Position=UDim2.new(0,0,0.15,0); bar.BackgroundColor3=tagCol; bar.BorderSizePixel=0; bar.ZIndex=53; bar.Parent=card; Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)

        -- Label + tag badge
        local wpNameLbl=Instance.new("TextLabel"); wpNameLbl.Size=UDim2.new(0,60,0,18); wpNameLbl.Position=UDim2.new(0,10,0,8); wpNameLbl.BackgroundTransparency=1; wpNameLbl.Text=wp.label; wpNameLbl.TextColor3=WP_C.accentGlow; wpNameLbl.Font=Enum.Font.GothamBlack; wpNameLbl.TextSize=11; wpNameLbl.TextXAlignment=Enum.TextXAlignment.Left; wpNameLbl.ZIndex=53; wpNameLbl.Parent=card
        local tagBadge=Instance.new("Frame"); tagBadge.Size=UDim2.new(0,40,0,16); tagBadge.Position=UDim2.new(0,72,0,9); tagBadge.BackgroundColor3=WP_C.cardInner; tagBadge.BorderSizePixel=0; tagBadge.ZIndex=53; tagBadge.Parent=card; Instance.new("UICorner",tagBadge).CornerRadius=UDim.new(1,0); do local ts=Instance.new("UIStroke"); ts.Color=tagCol; ts.Thickness=1; ts.Transparency=0.5; ts.Parent=tagBadge end; local tagTxt=Instance.new("TextLabel"); tagTxt.Size=UDim2.new(1,0,1,0); tagTxt.BackgroundTransparency=1; tagTxt.Text=tag; tagTxt.TextColor3=tagCol; tagTxt.Font=Enum.Font.GothamBlack; tagTxt.TextSize=8; tagTxt.ZIndex=54; tagTxt.Parent=tagBadge

        -- X and Z spinners
        local function makeSpinner(axis, spinX)
            local axCol = axis=="X" and WP_C.axX or WP_C.axZ
            local sf=Instance.new("Frame"); sf.Size=UDim2.new(0,88,0,28); sf.Position=UDim2.new(0,spinX,0,36); sf.BackgroundColor3=WP_C.cardInner; sf.BorderSizePixel=0; sf.ZIndex=52; sf.Parent=card; Instance.new("UICorner",sf).CornerRadius=UDim.new(0,7); do local ss=Instance.new("UIStroke"); ss.Color=WP_C.borderDim; ss.Thickness=1; ss.Parent=sf end
            local axTag=Instance.new("TextLabel"); axTag.Size=UDim2.new(0,14,1,0); axTag.Position=UDim2.new(0,4,0,0); axTag.BackgroundTransparency=1; axTag.Text=axis; axTag.TextColor3=axCol; axTag.Font=Enum.Font.GothamBlack; axTag.TextSize=9; axTag.ZIndex=54; axTag.Parent=sf
            local minus=Instance.new("TextButton"); minus.Size=UDim2.new(0,18,0,18); minus.Position=UDim2.new(0,17,0.5,-9); minus.BackgroundColor3=WP_C.btnBg; minus.BorderSizePixel=0; minus.Text="-"; minus.TextColor3=axCol; minus.Font=Enum.Font.GothamBlack; minus.TextSize=14; minus.ZIndex=55; minus.Parent=sf; Instance.new("UICorner",minus).CornerRadius=UDim.new(0,4); do local ms=Instance.new("UIStroke"); ms.Color=WP_C.borderDim; ms.Thickness=1; ms.Parent=minus end
            local valBox=Instance.new("TextBox"); valBox.Size=UDim2.new(0,28,0,18); valBox.Position=UDim2.new(0,37,0.5,-9); valBox.BackgroundColor3=WP_C.bg; valBox.BorderSizePixel=0; valBox.Text="0"; valBox.TextColor3=WP_C.text; valBox.Font=Enum.Font.GothamBlack; valBox.TextSize=10; valBox.ClearTextOnFocus=false; valBox.ZIndex=55; valBox.Parent=sf; Instance.new("UICorner",valBox).CornerRadius=UDim.new(0,4); do local vs=Instance.new("UIStroke"); vs.Color=axCol; vs.Thickness=1; vs.Transparency=0.65; vs.Parent=valBox end
            local plus=Instance.new("TextButton"); plus.Size=UDim2.new(0,18,0,18); plus.Position=UDim2.new(0,67,0.5,-9); plus.BackgroundColor3=WP_C.btnBg; plus.BorderSizePixel=0; plus.Text="+"; plus.TextColor3=axCol; plus.Font=Enum.Font.GothamBlack; plus.TextSize=12; plus.ZIndex=55; plus.Parent=sf; Instance.new("UICorner",plus).CornerRadius=UDim.new(0,4); do local ps=Instance.new("UIStroke"); ps.Color=WP_C.borderDim; ps.Thickness=1; ps.Parent=plus end
            local function applyVal(val)
                val=math.floor(val); local cur=wp.offset
                if axis=="X" then wp.offset=Vector3.new(val,cur.Y,cur.Z) else wp.offset=Vector3.new(cur.X,cur.Y,val) end
                valBox.Text=tostring(val)
                -- Immediately move the matching ESP marker if ESP is active
                if _G.BontHubESPRefresh then
                    -- Find the def index whose wpFn returns this same wp table entry
                    for defIdx, def in ipairs(ESP_DEFS) do
                        if def.wpFn() == wp then
                            _G.BontHubESPRefresh(defIdx)
                            break
                        end
                    end
                end
            end
            minus.MouseButton1Click:Connect(function() applyVal((tonumber(valBox.Text) or 0)-1) end)
            plus.MouseButton1Click:Connect(function()  applyVal((tonumber(valBox.Text) or 0)+1) end)
            valBox.FocusLost:Connect(function() applyVal(tonumber(valBox.Text:match("^%- %d+") or "0") or 0) end)
            if not boxRefs[i] then boxRefs[i]={} end
            boxRefs[i][axis]=valBox
        end
        makeSpinner("X", 8)
        makeSpinner("Z", 104)
    end

    -- Reset button
    local rstY = HDR_H + PAD + #wps*(CARD_H+CARD_GAP) - CARD_GAP + PAD
    local resetBtn=Instance.new("TextButton"); resetBtn.Size=UDim2.new(1,-PAD*2,0,RESET_H-6); resetBtn.Position=UDim2.new(0,PAD,0,rstY); resetBtn.BackgroundColor3=WP_C.btnBg; resetBtn.BorderSizePixel=0; resetBtn.Text="RESET ALL"; resetBtn.TextColor3=WP_C.accentGlow; resetBtn.Font=Enum.Font.GothamBlack; resetBtn.TextSize=11; resetBtn.ZIndex=52; resetBtn.Parent=panel; Instance.new("UICorner",resetBtn).CornerRadius=UDim.new(0,8); do local rs=Instance.new("UIStroke"); rs.Color=WP_C.border; rs.Thickness=1; rs.Transparency=0.45; rs.Parent=resetBtn end
    resetBtn.MouseButton1Click:Connect(function()
        for i, wp in ipairs(wps) do
            wp.offset = Vector3.new(0,0,0)
            if boxRefs[i] then
                if boxRefs[i]["X"] then boxRefs[i]["X"].Text="0" end
                if boxRefs[i]["Z"] then boxRefs[i]["Z"].Text="0" end
            end
        end
        -- Refresh all ESP parts for this side
        if _G.BontHubESPRefresh then
            for defIdx, def in ipairs(ESP_DEFS) do
                for _, wp in ipairs(wps) do
                    if def.wpFn() == wp then
                        _G.BontHubESPRefresh(defIdx)
                    end
                end
            end
        end
    end)
end
;(function()

-- Destroy old instance if reloading
if pgui:FindFirstChild("BontHubMini") then pgui.BontHubMini:Destroy() end

local C = {
    bg        = Color3.fromRGB(6, 2, 14),
    panel     = Color3.fromRGB(10, 3, 22),
    rowBg     = Color3.fromRGB(12, 4, 26),
    rowActive = Color3.fromRGB(28, 8, 54),
    border    = Color3.fromRGB(150, 60, 220),
    borderDim = Color3.fromRGB(50, 15, 80),
    accent    = Color3.fromRGB(170, 80, 255),
    accentGlow= Color3.fromRGB(220, 180, 255),
    accent2   = Color3.fromRGB(210, 60, 255),
    text      = Color3.fromRGB(245, 245, 255),
    textDim   = Color3.fromRGB(190, 150, 240),
    textMid   = Color3.fromRGB(100, 40, 150),
    headerBg  = Color3.fromRGB(5, 2, 14),
    btnBg     = Color3.fromRGB(16, 5, 36),
    toggleOn  = Color3.fromRGB(170, 80, 255),
    toggleOff = Color3.fromRGB(18, 5, 40),
    circleOn  = Color3.fromRGB(255, 255, 255),
    circleOff = Color3.fromRGB(70, 20, 110),
    success   = Color3.fromRGB(52, 211, 153),
    danger    = Color3.fromRGB(248, 113, 113),
    stealFill = Color3.fromRGB(170, 80, 255),
    stealTrack= Color3.fromRGB(12, 4, 30),
    tabActive = Color3.fromRGB(28, 8, 58),
    tabInact  = Color3.fromRGB(8, 3, 18),
}

local GUI_W   = 400
local GUI_H   = 680
local HEADER_H = 90
local TAB_BAR_H = 40

-- TABS definition
local TAB_DEFS = {
    { id="steal",   label="STEAL",   icon="S" },
    { id="movement",label="MOVE",    icon="M" },
    { id="esp",     label="ESP",     icon="E" },
    { id="char",    label="CHAR",    icon="C" },
    { id="settings",label="SET",     icon="G" },
}
local activeTab = "steal"
local tabFrames = {}
local tabBtns   = {}

local gui = Instance.new("ScreenGui")
gui.Name = "BontHubMini"; gui.ResetOnSpawn = false
gui.DisplayOrder = 10; gui.IgnoreGuiInset = true
gui.Parent = pgui

-- ===================================================
-- MAIN FRAME
-- ===================================================
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, GUI_W, 0, GUI_H)
main.Position = UDim2.new(0, 16, 0.5, -(GUI_H/2))
main.BackgroundColor3 = C.bg
main.BackgroundTransparency = currentTransparency
main.BorderSizePixel = 0
main.Active = true; main.Draggable = true; main.ClipsDescendants = false
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = C.accent; mainStroke.Thickness = 1.5; mainStroke.Transparency = 0.3
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; mainStroke.Parent = main

local function ensureGuiScale(target)
    if not target then return nil end
    local scaleObj = target:FindFirstChild("BontGuiScale")
    if not scaleObj then
        scaleObj = Instance.new("UIScale")
        scaleObj.Name = "BontGuiScale"
        scaleObj.Parent = target
    end
    return scaleObj
end

local function applyMainGuiScale(scale)
    MAIN_GUI_SCALE = math.clamp(scale or 1, 0.25, 1.0)
    local scaleObj = ensureGuiScale(main)
    if scaleObj then scaleObj.Scale = MAIN_GUI_SCALE end
    if syncStealBar then task.defer(syncStealBar) end
end

local function applyMobileGuiScale(scale)
    MOBILE_GUI_SCALE = math.clamp(scale or 1, 0.25, 1.0)
    if _G.BontHubMobileContainer then
        local scaleObj = ensureGuiScale(_G.BontHubMobileContainer)
        if scaleObj then scaleObj.Scale = MOBILE_GUI_SCALE end
    end
end

applyMainGuiScale(MAIN_GUI_SCALE)

-- ===================================================
-- ANIMATED BACKGROUND  (floating G / BONT letters)
-- ===================================================
local bgCanvas = Instance.new("Frame")
bgCanvas.Name = "BgCanvas"
bgCanvas.Size = UDim2.new(1,0,1,0)
bgCanvas.BackgroundTransparency = 1
bgCanvas.BorderSizePixel = 0; bgCanvas.ZIndex = 1
bgCanvas.ClipsDescendants = true
bgCanvas.Parent = main

do
    local words = {"G","BONT","G","BONT","G","BONT","G","BONT"}
    local particles = {}
    for i = 1, 12 do
        local lbl = Instance.new("TextLabel")
        lbl.BackgroundTransparency = 1
        lbl.Text = words[((i-1)%#words)+1]
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = math.random(18, 42)
        lbl.TextColor3 = Color3.fromRGB(
            math.random(120,200),
            math.random(40,80),
            math.random(200,255)
        )
        lbl.TextTransparency = math.random(70,90) / 100
        lbl.BorderSizePixel = 0
        lbl.ZIndex = 2
        lbl.Size = UDim2.new(0, 80, 0, 50)
        lbl.Position = UDim2.new(
            math.random(0, 90) / 100,
            0,
            math.random(0, 90) / 100,
            0
        )
        lbl.Parent = bgCanvas
        local speed  = math.random(4, 12) / 1000
        local angle  = math.random(0, 628) / 100
        local drift  = math.random(-8, 8) / 10000
        table.insert(particles, {lbl=lbl, angle=angle, speed=speed, drift=drift,
            px = math.random(0,90)/100, py = math.random(0,90)/100})
    end
    task.spawn(function()
        task.wait(0.2)
        while main and main.Parent do
            task.wait(0.05)
            pcall(function()
                for _, p in ipairs(particles) do
                    p.angle = p.angle + p.drift
                    p.px = p.px + math.cos(p.angle) * p.speed
                    p.py = p.py + math.sin(p.angle) * p.speed
                    if p.px < -0.1 then p.px = 1.0 end
                    if p.px >  1.1 then p.px = 0.0 end
                    if p.py < -0.1 then p.py = 1.0 end
                    if p.py >  1.1 then p.py = 0.0 end
                    p.lbl.Position = UDim2.new(p.px, 0, p.py, 0)
                end
            end)
        end
    end)
end

-- ===================================================
-- PULSING BORDER + NEON STREAKS
-- ===================================================
task.spawn(function()
    task.wait(0.15)
    pcall(function()
        local t = 0
        while task.wait(0.05) do
            pcall(function()
                if not mainStroke or not mainStroke.Parent then return end
                t = t + 0.07
                local p = (math.sin(t)+1)/2
                mainStroke.Color = Color3.new((150+p*80)/255,(40+p*20)/255,(215+p*40)/255)
                mainStroke.Thickness = 1.2 + p*1.4
            end)
        end
    end)
end)

task.spawn(function()
    task.wait(0.2)
    pcall(function()
        local ls = Instance.new("Frame"); ls.Size=UDim2.new(0,2,0,50)
        ls.BackgroundColor3=Color3.fromRGB(190,80,255); ls.BorderSizePixel=0; ls.ZIndex=16; ls.Parent=main
        local rs = Instance.new("Frame"); rs.Size=UDim2.new(0,2,0,50)
        rs.BackgroundColor3=Color3.fromRGB(190,80,255); rs.BorderSizePixel=0; rs.ZIndex=16; rs.Parent=main
        local tL,tR = 0,math.pi
        while task.wait(0.016) do
            pcall(function()
                if not main or not main.Parent then return end
                tL=tL+0.014; tR=tR+0.014
                ls.Position=UDim2.new(0,0,0,(math.sin(tL)*0.5+0.5)*(GUI_H-50))
                rs.Position=UDim2.new(1,-2,0,(math.sin(tR)*0.5+0.5)*(GUI_H-50))
                local p=(math.sin(tL*2)+1)/2
                local col=Color3.new((170+p*85)/255,(50+p*30)/255,1)
                ls.BackgroundColor3=col; rs.BackgroundColor3=col
            end)
        end
    end)
end)

-- ===================================================
-- HEADER
-- ===================================================
local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,HEADER_H)
header.BackgroundColor3 = C.headerBg
header.BorderSizePixel = 0; header.ZIndex = 6; header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0,14)
do local sq=Instance.new("Frame"); sq.Size=UDim2.new(1,0,0,14); sq.Position=UDim2.new(0,0,1,-14)
   sq.BackgroundColor3=C.headerBg; sq.BorderSizePixel=0; sq.ZIndex=6; sq.Parent=header end

-- header gradient
do
    local tint=Instance.new("Frame"); tint.Size=UDim2.new(1,0,1,0)
    tint.BackgroundColor3=C.headerBg; tint.BackgroundTransparency=0
    tint.BorderSizePixel=0; tint.ZIndex=6; tint.Parent=header
    Instance.new("UICorner",tint).CornerRadius=UDim.new(0,14)
    local tg=Instance.new("UIGradient"); tg.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(35,8,70)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8,3,20)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(30,5,60)),
    }; tg.Rotation=125; tg.Parent=tint
end

-- accent rule
do
    local rule=Instance.new("Frame"); rule.Size=UDim2.new(1,0,0,2); rule.Position=UDim2.new(0,0,1,-2)
    rule.BackgroundColor3=C.accent; rule.BorderSizePixel=0; rule.ZIndex=9; rule.Parent=header
    local rg=Instance.new("UIGradient"); rg.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(0.3,C.accent),
        ColorSequenceKeypoint.new(0.7,C.accent2),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0)),
    }; rg.Parent=rule
end

-- logo square removed (only BONT HUB in header)

-- Title BONT HUB only - centered, with fade in/out gradient violet animation
local titleLbl
do
    titleLbl=Instance.new("TextLabel")
    titleLbl.Size=UDim2.new(1,-20,0,50); titleLbl.Position=UDim2.new(0,10,0.5,-25)
    titleLbl.BackgroundTransparency=1; titleLbl.Text="BONT HUB"
    titleLbl.Font=Enum.Font.GothamBlack; titleLbl.TextSize=28
    titleLbl.TextColor3=Color3.fromRGB(230,100,255)
    titleLbl.TextXAlignment=Enum.TextXAlignment.Center
    titleLbl.TextYAlignment=Enum.TextYAlignment.Center
    titleLbl.ZIndex=9; titleLbl.Parent=header
    titleLbl.TextStrokeTransparency=0.5; titleLbl.TextStrokeColor3=Color3.fromRGB(80,0,120)
    titleLbl.TextTransparency=1

    task.spawn(function()
        task.wait(0.2)
        for i=1,20 do
            task.wait(0.05)
            pcall(function() if not titleLbl or not titleLbl.Parent then return end; titleLbl.TextTransparency=1-(i/20) end)
        end
        local gradColors={Color3.fromRGB(230,80,255),Color3.fromRGB(200,60,255),Color3.fromRGB(255,100,255),Color3.fromRGB(180,50,255),Color3.fromRGB(210,90,255)}
        local step,idx,fadeT=0,1,0
        while task.wait(0.04) do
            pcall(function()
                if not titleLbl or not titleLbl.Parent then return end
                step=step+0.03; fadeT=fadeT+0.025
                titleLbl.TextTransparency=((math.sin(fadeT)+1)/2)*0.18
                local p=(math.sin(step)+1)/2; local nx=(idx%#gradColors)+1
                local c1,c2=gradColors[idx],gradColors[nx]
                titleLbl.TextColor3=Color3.new(c1.R+(c2.R-c1.R)*p,c1.G+(c2.G-c1.G)*p,c1.B+(c2.B-c1.B)*p)
                titleLbl.TextStrokeColor3=Color3.new((c1.R+(c2.R-c1.R)*p)*0.3,0,(c1.B+(c2.B-c1.B)*p)*0.4)
                if step>=math.pi*2 then step=0;idx=nx end
            end)
        end
    end)
end

-- ===================================================
-- TAB BAR
-- ===================================================
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,0,0,TAB_BAR_H)
tabBar.Position = UDim2.new(0,0,0,HEADER_H)
tabBar.BackgroundColor3 = Color3.fromRGB(8,3,18)
tabBar.BorderSizePixel = 0; tabBar.ZIndex = 8; tabBar.Parent = main

local tabUnderline = Instance.new("Frame")
tabUnderline.Size = UDim2.new(0, GUI_W/#TAB_DEFS, 0, 2)
tabUnderline.Position = UDim2.new(0,0,1,-2)
tabUnderline.BackgroundColor3 = C.accent
tabUnderline.BorderSizePixel = 0; tabUnderline.ZIndex = 9; tabUnderline.Parent = tabBar

local TAB_W = GUI_W / #TAB_DEFS

local function switchTab(tabId)
    activeTab = tabId
    for _, f in pairs(tabFrames) do f.Visible = false end
    if tabFrames[tabId] then tabFrames[tabId].Visible = true end
    for i, def in ipairs(TAB_DEFS) do
        local btn = tabBtns[def.id]
        if btn then
            if def.id == tabId then
                btn.BackgroundColor3 = C.tabActive
                btn.TextColor3 = C.accentGlow
                TweenService:Create(tabUnderline, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(0, (i-1)*TAB_W, 1, -2)
                }):Play()
            else
                btn.BackgroundColor3 = C.tabInact
                btn.TextColor3 = C.textMid
            end
        end
    end
end

for i, def in ipairs(TAB_DEFS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, TAB_W, 1, 0)
    btn.Position = UDim2.new(0, (i-1)*TAB_W, 0, 0)
    btn.BackgroundColor3 = i==1 and C.tabActive or C.tabInact
    btn.BorderSizePixel = 0
    btn.Text = def.label
    btn.TextColor3 = i==1 and C.accentGlow or C.textMid
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 9
    btn.ZIndex = 9
    btn.Parent = tabBar
    tabBtns[def.id] = btn
    btn.MouseButton1Click:Connect(function() switchTab(def.id) end)
end

-- thin divider under tab bar
do local d=Instance.new("Frame"); d.Size=UDim2.new(1,0,0,1); d.Position=UDim2.new(0,0,0,HEADER_H+TAB_BAR_H)
   d.BackgroundColor3=C.border; d.BackgroundTransparency=0.5; d.BorderSizePixel=0; d.ZIndex=7; d.Parent=main end

-- ===================================================
-- TAB CONTENT FRAMES
-- ===================================================
local CONTENT_Y = HEADER_H + TAB_BAR_H + 2
local CONTENT_H = GUI_H - CONTENT_Y

local function makeTabFrame(tabId)
    local f = Instance.new("ScrollingFrame")
    f.Name = "Tab_"..tabId
    f.Size = UDim2.new(1,0,0,CONTENT_H)
    f.Position = UDim2.new(0,0,0,CONTENT_Y)
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0
    f.ScrollBarThickness = 2; f.ScrollBarImageColor3 = C.accent
    f.CanvasSize = UDim2.new(0,0,0,0)
    f.ZIndex = 5; f.Visible = (tabId == "steal")
    f.Parent = main
    tabFrames[tabId] = f
    return f
end

local tSteal    = makeTabFrame("steal")
local tMovement = makeTabFrame("movement")
local tESP      = makeTabFrame("esp")
local tChar     = makeTabFrame("char")
local tSettings = makeTabFrame("settings")

-- ===================================================
-- GUI HELPERS
-- ===================================================
local function addDividerTo(parent, yp)
    local d=Instance.new("Frame"); d.Size=UDim2.new(1,-24,0,1); d.Position=UDim2.new(0,12,0,yp)
    d.BackgroundColor3=Color3.fromRGB(255,255,255); d.BackgroundTransparency=0.91
    d.BorderSizePixel=0; d.ZIndex=5; d.Parent=parent
    local g=Instance.new("UIGradient"); g.Color=ColorSequence.new{
        ColorSequenceKeypoint.new(0,Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(0.15,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(0.85,Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1,Color3.fromRGB(0,0,0)),
    }; g.Parent=d
    return yp+16
end

local function addCatHeader(parent, txt, yp)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,-20,0,22); f.Position=UDim2.new(0,10,0,yp)
    f.BackgroundTransparency=1; f.ZIndex=5; f.Parent=parent
    local dot=Instance.new("Frame"); dot.Size=UDim2.new(0,6,0,6); dot.Position=UDim2.new(0,1,0.5,-3)
    dot.BackgroundColor3=C.accent2; dot.BorderSizePixel=0; dot.ZIndex=6; dot.Parent=f
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(1,-14,1,0); lbl.Position=UDim2.new(0,13,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=txt; lbl.TextColor3=C.textDim; lbl.Font=Enum.Font.GothamBlack
    lbl.TextSize=10; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=6; lbl.Parent=f
    return yp+28
end

local function makeToggle(parent, labelText, enabledKey, callback, keybindKey, yp)
    local ROW_H=46
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,-20,0,ROW_H); row.Position=UDim2.new(0,10,0,yp)
    row.BackgroundColor3=C.rowBg; row.BorderSizePixel=0; row.ZIndex=5; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
    do local s=Instance.new("UIStroke"); s.Color=C.borderDim; s.Thickness=1; s.Parent=row end

    local xOff=12
    local keybindBtn=nil
    if keybindKey then
        keybindBtn=Instance.new("TextButton"); keybindBtn.Size=UDim2.new(0,36,0,22); keybindBtn.Position=UDim2.new(0,xOff,0.5,-11)
        keybindBtn.BackgroundColor3=C.btnBg; keybindBtn.BorderSizePixel=0
        keybindBtn.Text=keybindKey.Name; keybindBtn.TextColor3=C.textDim
        keybindBtn.Font=Enum.Font.GothamBlack; keybindBtn.TextSize=9; keybindBtn.ZIndex=7; keybindBtn.Parent=row
        Instance.new("UICorner",keybindBtn).CornerRadius=UDim.new(0,5)
        do local s=Instance.new("UIStroke"); s.Color=C.borderDim; s.Thickness=1; s.Parent=keybindBtn end
        xOff=xOff+42
        keybindBtn.MouseButton1Click:Connect(function()
            waitingForKeybind=keybindBtn; waitingForKeybindType=enabledKey
            keybindBtn.Text="..."
        end)
    end

    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,-(xOff+58),1,0); label.Position=UDim2.new(0,xOff,0,0)
    label.BackgroundTransparency=1; label.Text=labelText; label.TextColor3=C.text
    label.Font=Enum.Font.GothamBlack; label.TextSize=13
    label.TextXAlignment=Enum.TextXAlignment.Left; label.ZIndex=6; label.Parent=row

    local toggleBg=Instance.new("Frame"); toggleBg.Size=UDim2.new(0,40,0,22); toggleBg.Position=UDim2.new(1,-52,0.5,-11)
    toggleBg.BackgroundColor3=Enabled[enabledKey] and C.toggleOn or C.toggleOff
    toggleBg.BorderSizePixel=0; toggleBg.ZIndex=7; toggleBg.Parent=row
    Instance.new("UICorner",toggleBg).CornerRadius=UDim.new(1,0)
    do local ts=Instance.new("UIStroke"); ts.Color=C.borderDim; ts.Thickness=1; ts.Parent=toggleBg end

    local circle=Instance.new("Frame"); circle.Size=UDim2.new(0,16,0,16)
    circle.Position=Enabled[enabledKey] and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8)
    circle.BackgroundColor3=Enabled[enabledKey] and C.circleOn or C.circleOff
    circle.BorderSizePixel=0; circle.ZIndex=8; circle.Parent=toggleBg
    Instance.new("UICorner",circle).CornerRadius=UDim.new(1,0)

    local clickBtn=Instance.new("TextButton"); clickBtn.Size=UDim2.new(1,0,1,0)
    clickBtn.BackgroundTransparency=1; clickBtn.Text=""; clickBtn.ZIndex=9; clickBtn.Parent=toggleBg

    local function setVisual(state)
        TweenService:Create(toggleBg,TweenInfo.new(0.15),{BackgroundColor3=state and C.toggleOn or C.toggleOff}):Play()
        TweenService:Create(circle,TweenInfo.new(0.15,Enum.EasingStyle.Quad),{
            Position=state and UDim2.new(1,-18,0.5,-8) or UDim2.new(0,2,0.5,-8),
            BackgroundColor3=state and C.circleOn or C.circleOff,
        }):Play()
        if state then
            row.BackgroundColor3=C.rowActive
        else
            TweenService:Create(row,TweenInfo.new(0.15),{BackgroundColor3=C.rowBg}):Play()
        end
    end

    clickBtn.MouseButton1Click:Connect(function()
        local ns = not Enabled[enabledKey]
        Enabled[enabledKey] = ns
        setVisual(ns)
        if callback then callback(ns) end
    end)

    VisualSetters[enabledKey] = function(state, skipCallback)
        Enabled[enabledKey] = state
        setVisual(state)
    end

    setVisual(Enabled[enabledKey])
    return yp + ROW_H + 4
end

local function makeActionBtn(parent, labelTxt, btnTxt, onPress, yp)
    local ROW_H=44
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,-20,0,ROW_H); row.Position=UDim2.new(0,10,0,yp)
    row.BackgroundColor3=C.rowBg; row.BorderSizePixel=0; row.ZIndex=5; row.Parent=parent
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
    do local s=Instance.new("UIStroke"); s.Color=C.borderDim; s.Thickness=1; s.Parent=row end

    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.6,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=labelTxt; lbl.TextColor3=C.text; lbl.Font=Enum.Font.GothamBlack; lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.Position=UDim2.new(0,12,0,0); lbl.ZIndex=6; lbl.Parent=row

    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,90,0,30); btn.Position=UDim2.new(1,-102,0.5,-15)
    btn.BackgroundColor3=C.btnBg; btn.BorderSizePixel=0
    btn.Text=btnTxt; btn.TextColor3=C.accentGlow; btn.Font=Enum.Font.GothamBlack; btn.TextSize=11
    btn.ZIndex=6; btn.Parent=row
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    do local s=Instance.new("UIStroke"); s.Color=C.border; s.Thickness=1; s.Parent=btn end
    btn.MouseButton1Click:Connect(onPress)
    return yp+ROW_H+4
end

local function makeKeyRow(parent, lTxt, defKeyName, yp)
    local ROW_H=34
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,-24,0,ROW_H); row.Position=UDim2.new(0,12,0,yp)
    row.BackgroundTransparency=1; row.ZIndex=5; row.Parent=parent
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=lTxt; lbl.TextColor3=C.textMid; lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=5; lbl.Parent=row
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(0,80,0,26); btn.Position=UDim2.new(1,-80,0.5,-13)
    btn.BackgroundColor3=C.btnBg; btn.BorderSizePixel=0; btn.Text=defKeyName
    btn.TextColor3=C.text; btn.Font=Enum.Font.GothamBold; btn.TextSize=11; btn.ZIndex=5; btn.Parent=row
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
    do local s=Instance.new("UIStroke"); s.Color=C.border; s.Thickness=1; s.Parent=btn end
    return btn, yp+ROW_H+2
end

local function makeInputRow(parent, lTxt, defVal, onChange, yp)
    local ROW_H=34
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,-24,0,ROW_H); row.Position=UDim2.new(0,12,0,yp)
    row.BackgroundTransparency=1; row.ZIndex=5; row.Parent=parent
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.6,0,1,0); lbl.BackgroundTransparency=1
    lbl.Text=lTxt; lbl.TextColor3=C.textMid; lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=5; lbl.Parent=row
    local box=Instance.new("TextBox"); box.Size=UDim2.new(0,80,0,26); box.Position=UDim2.new(1,-80,0.5,-13)
    box.BackgroundColor3=C.btnBg; box.BorderSizePixel=0; box.Text=tostring(defVal)
    box.TextColor3=C.text; box.Font=Enum.Font.GothamBold; box.TextSize=12
    box.ClearTextOnFocus=false; box.ZIndex=5; box.Parent=row
    Instance.new("UICorner",box).CornerRadius=UDim.new(0,5)
    do local s=Instance.new("UIStroke"); s.Color=C.border; s.Thickness=1; s.Parent=box end
    box.FocusLost:Connect(function() local v=tonumber(box.Text); if v then onChange(v); box.Text=tostring(v) else box.Text=tostring(defVal) end end)
    return box, yp+ROW_H+4
end

local waitingForKeybind = nil
local waitingForKeybindType = nil

-- ===================================================
-- TAB: STEAL
-- ===================================================
do
    local y = 10
    y = addCatHeader(tSteal, "AUTO STEAL", y)
    y = makeToggle(tSteal, "Auto Steal", "AutoSteal", function(s) if s then startAutoSteal() else stopAutoSteal() end end, nil, y)

    -- steal settings inline
    local stealCard=Instance.new("Frame"); stealCard.Size=UDim2.new(1,-20,0,90); stealCard.Position=UDim2.new(0,10,0,y)
    stealCard.BackgroundColor3=C.panel; stealCard.BorderSizePixel=0; stealCard.ZIndex=5; stealCard.Parent=tSteal
    Instance.new("UICorner",stealCard).CornerRadius=UDim.new(0,10)
    do local s=Instance.new("UIStroke"); s.Color=C.borderDim; s.Thickness=1; s.Parent=stealCard end

    do
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,0,26); lbl.Position=UDim2.new(0,10,0,10)
        lbl.BackgroundTransparency=1; lbl.Text="Steal Duration"; lbl.TextColor3=C.textMid
        lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=6; lbl.Parent=stealCard
        local bx=Instance.new("TextBox"); bx.Size=UDim2.new(0,70,0,22); bx.Position=UDim2.new(1,-82,0,14)
        bx.BackgroundColor3=C.bg; bx.BorderSizePixel=0; bx.Text=tostring(Values.STEAL_DURATION)
        bx.TextColor3=C.text; bx.Font=Enum.Font.GothamBold; bx.TextSize=11
        bx.ClearTextOnFocus=false; bx.ZIndex=6; bx.Parent=stealCard
        Instance.new("UICorner",bx).CornerRadius=UDim.new(0,4)
        do local s=Instance.new("UIStroke"); s.Color=C.border; s.Thickness=1; s.Parent=bx end
        bx.FocusLost:Connect(function() local v=tonumber(bx.Text); if v then Values.STEAL_DURATION=math.max(0.01,v); bx.Text=tostring(v) else bx.Text=tostring(Values.STEAL_DURATION) end end)
    end
    do
        local sbRadSteps={5,8,10,15,20,30}; local sbRadIdx=2
        local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,0,26); lbl.Position=UDim2.new(0,10,0,46)
        lbl.BackgroundTransparency=1; lbl.Text="Steal Radius"; lbl.TextColor3=C.textMid
        lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=11; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=6; lbl.Parent=stealCard
        SBRadBtn=Instance.new("TextButton"); SBRadBtn.Size=UDim2.new(0,70,0,22); SBRadBtn.Position=UDim2.new(1,-82,0,50)
        SBRadBtn.BackgroundColor3=C.btnBg; SBRadBtn.BorderSizePixel=0
        SBRadBtn.Text=tostring(sbRadSteps[sbRadIdx]); SBRadBtn.TextColor3=C.accentGlow
        SBRadBtn.Font=Enum.Font.GothamBlack; SBRadBtn.TextSize=12; SBRadBtn.ZIndex=6; SBRadBtn.Parent=stealCard
        Instance.new("UICorner",SBRadBtn).CornerRadius=UDim.new(0,6)
        do local s=Instance.new("UIStroke"); s.Color=C.border; s.Thickness=1; s.Parent=SBRadBtn end
        SBRadBtn.MouseButton1Click:Connect(function()
            sbRadIdx=(sbRadIdx%#sbRadSteps)+1
            Values.STEAL_RADIUS=sbRadSteps[sbRadIdx]
            SBRadBtn.Text=tostring(Values.STEAL_RADIUS)
        end)
    end
    y = y + 98

    y = addDividerTo(tSteal, y)
    y = addCatHeader(tSteal, "COMBAT", y)
    y = makeToggle(tSteal, "Bat Aimbot",     "BatAimbot",     function(s) Enabled.BatAimbot=s; autoBatToggled=s; if s then startBatAimbot() else stopBatAimbot() end end, autoBatKey, y)
    y = makeToggle(tSteal, "Counter Medusa", "CounterMedusa", function(s) if s then startCounterMedusa() else stopCounterMedusa() end end, nil, y)
    y = makeToggle(tSteal, "Anti Ragdoll",   "AntiRagdoll",   function(s) if s then startBontShield() else stopBontShield() end end, nil, y)
    y = makeToggle(tSteal, "Spinbot",        "Spinbot",       function(s) if s then startSpinbot() else stopSpinbot() end end, nil, y)
    y = makeActionBtn(tSteal, "Drop Brainrots", "DROP", function() task.spawn(executeBontDrop) end, y)
    tSteal.CanvasSize = UDim2.new(0,0,0,y+10)
end

-- ===================================================
-- TAB: MOVEMENT
-- ===================================================
do
    local y = 10
    y = addCatHeader(tMovement, "AUTO MOVEMENT", y)
    y = makeToggle(tMovement, "Auto Left",        "AutoLeftEnabled",      function(s) AutoLeftEnabled=s;      if s then startAutoLeft()      else stopAutoLeft()      end end, autoLeftKey,      y)
    y = makeToggle(tMovement, "Auto Right",       "AutoRightEnabled",     function(s) AutoRightEnabled=s;     if s then startAutoRight()     else stopAutoRight()     end end, autoRightKey,     y)
    y = makeToggle(tMovement, "Auto Left Play",   "AutoLeftPlayEnabled",  function(s) AutoLeftPlayEnabled=s;  if s then startAutoLeftPlay()  else stopAutoLeftPlay()  end end, autoLeftPlayKey,  y)
    y = makeToggle(tMovement, "Auto Right Play",  "AutoRightPlayEnabled", function(s) AutoRightPlayEnabled=s; if s then startAutoRightPlay() else stopAutoRightPlay() end end, autoRightPlayKey, y)
    y = makeToggle(tMovement, "Auto Carry Pickup","AutoCarryOnPickup",    function(s) if s then startAutoCarryMode() else stopAutoCarryMode() end end, nil, y)
    y = makeToggle(tMovement, "Ragdoll TP",       "RagdollTP",            function(s) if s then startRagdollTP() else stopRagdollTP() end end, nil, y)

    y = addDividerTo(tMovement, y)
    y = addCatHeader(tMovement, "PHYSICS", y)
    y = makeToggle(tMovement, "Galaxy Mode",  "Galaxy",       function(s) if s then startGalaxy() else stopGalaxy() end end, Enum.KeyCode.M, y)
    y = makeToggle(tMovement, "Float",        "FloatEnabled", function(s) floatEnabled=s; Enabled.FloatEnabled=s; if s then startFloat() else stopFloat() end end, floatKey, y)
    y = makeActionBtn(tMovement, "TP Down", "TPDN", function() task.spawn(doTPDown) end, y)

    y = addDividerTo(tMovement, y)
    y = addCatHeader(tMovement, "SPEED", y)
    y = makeToggle(tMovement, "Low Speed", "LowSpeedEnabled", function(s)
        lowSpeedToggled = s
        Enabled.LowSpeedEnabled = s
        if s then
            speedToggled = false
            if modeLabel then modeLabel.Text = "Mode: Low (" .. tostring(LOW_SPEED_VALUE) .. ")" end
        else
            if modeLabel then modeLabel.Text = speedToggled and "Mode: Carry" or "Mode: Normal" end
        end
    end, lowSpeedKey, y)
    modeLabel=Instance.new("TextLabel"); modeLabel.Size=UDim2.new(1,-24,0,20); modeLabel.Position=UDim2.new(0,12,0,y)
    modeLabel.BackgroundTransparency=1; modeLabel.Text=(lowSpeedToggled and ("Mode: Low (" .. tostring(LOW_SPEED_VALUE) .. ")") or (speedToggled and "Mode: Carry" or "Mode: Normal")); modeLabel.TextColor3=C.textDim
    modeLabel.Font=Enum.Font.GothamBold; modeLabel.TextSize=12; modeLabel.ZIndex=5; modeLabel.Parent=tMovement
    y = y + 24
    local normalBox; local carryBox; local lowSpeedBox
    normalBox, y = makeInputRow(tMovement, "Normal Speed", NORMAL_SPEED, function(v) NORMAL_SPEED=v end, y)
    carryBox,  y = makeInputRow(tMovement, "Carry Speed",  CARRY_SPEED,  function(v) CARRY_SPEED=v end, y)
    lowSpeedBox, y = makeInputRow(tMovement, "Low Speed Value", LOW_SPEED_VALUE, function(v)
        LOW_SPEED_VALUE = math.clamp(v, 10, 20)
        lowSpeedBox.Text = tostring(LOW_SPEED_VALUE)
        if lowSpeedToggled and modeLabel then
            modeLabel.Text = "Mode: Low (" .. tostring(LOW_SPEED_VALUE) .. ")"
        end
    end, y)

    tMovement.CanvasSize = UDim2.new(0,0,0,y+10)
end

-- ===================================================
-- TAB: ESP
-- ===================================================
do
    local y = 10
    y = addCatHeader(tESP, "WAYPOINT ESP", y)
    y = makeToggle(tESP, "Waypoint ESP", "WaypointESP", function(s) if s then startWaypointESP() else stopWaypointESP() end end, nil, y)

    y = addDividerTo(tESP, y)
    y = addCatHeader(tESP, "WP EDITORS", y)
    y = makeActionBtn(tESP, "Edit Left Waypoints",      "OPEN", function() openWPPanel("Left")      end, y)
    y = makeActionBtn(tESP, "Edit Right Waypoints",     "OPEN", function() openWPPanel("Right")     end, y)
    y = makeActionBtn(tESP, "Edit Left Play Waypoints", "OPEN", function() openWPPanel("LeftPlay")  end, y)
    y = makeActionBtn(tESP, "Edit Right Play Waypoints","OPEN", function() openWPPanel("RightPlay") end, y)

    tESP.CanvasSize = UDim2.new(0,0,0,y+10)
end

-- ===================================================
-- TAB: CHARACTER
-- ===================================================
do
    local y = 10
    y = addCatHeader(tChar, "CHARACTER", y)
    y = makeToggle(tChar, "No Clip",           "NoClip",    function(s) if s then startNoClip()     else stopNoClip()     end end, nil, y)
    y = makeToggle(tChar, "Disable Animation", "Unwalk",    function(s) if s then startUnwalk()     else stopUnwalk()     end end, nil, y)
    y = makeToggle(tChar, "Dark Mode",         "DarkMode",  function(s) if s then enableDarkMode()  else disableDarkMode()  end end, nil, y)
    y = makeToggle(tChar, "X-Ray + Optimizer", "Optimizer", function(s) if s then activatePowerMode() else deactivatePowerMode() end end, nil, y)

    tChar.CanvasSize = UDim2.new(0,0,0,y+10)
end

-- ===================================================
-- TAB: SETTINGS
-- ===================================================
do
    local y = 10
    y = addCatHeader(tSettings, "KEY CONFIG", y)

    local keyBtnAutoLeft,      keyBtnAutoRight
    local keyBtnAutoLeftPlay,  keyBtnAutoRightPlay
    local keyBtnSpeed,         keyBtnGUI
    local keyBtnFloat,         keyBtnAimbot
    local keyBtnTPDown,        keyBtnDrop
    local keyBtnLowSpeed

    keyBtnAutoLeft,      y = makeKeyRow(tSettings, "Auto Left",      autoLeftKey.Name,      y)
    keyBtnAutoRight,     y = makeKeyRow(tSettings, "Auto Right",     autoRightKey.Name,     y)
    keyBtnAutoLeftPlay,  y = makeKeyRow(tSettings, "Auto Left Play", autoLeftPlayKey.Name,  y)
    keyBtnAutoRightPlay, y = makeKeyRow(tSettings, "Auto Right Play",autoRightPlayKey.Name, y)
    keyBtnSpeed,         y = makeKeyRow(tSettings, "Speed Toggle",   speedToggleKey.Name,   y)
    keyBtnGUI,           y = makeKeyRow(tSettings, "GUI Toggle",     guiToggleKey.Name,     y)
    keyBtnFloat,         y = makeKeyRow(tSettings, "Float",          floatKey.Name,         y)
    keyBtnAimbot,        y = makeKeyRow(tSettings, "Aimbot",         autoBatKey.Name,       y)
    keyBtnTPDown,        y = makeKeyRow(tSettings, "TP Down",        tpDownKey.Name,        y)
    keyBtnDrop,          y = makeKeyRow(tSettings, "Drop Brainrots", dropKey.Name,          y)
    keyBtnLowSpeed,      y = makeKeyRow(tSettings, "Low Speed",      lowSpeedKey.Name,      y)

    local function hookKey(btn, ktype) btn.MouseButton1Click:Connect(function() btn.Text="..."; waitingForKeybind=btn; waitingForKeybindType=ktype end) end
    hookKey(keyBtnAutoLeft,      "AutoLeft")
    hookKey(keyBtnAutoRight,     "AutoRight")
    hookKey(keyBtnAutoLeftPlay,  "AutoLeftPlay")
    hookKey(keyBtnAutoRightPlay, "AutoRightPlay")
    hookKey(keyBtnSpeed,         "SpeedToggle")
    hookKey(keyBtnGUI,           "GUIToggle")
    hookKey(keyBtnFloat,         "Float")
    hookKey(keyBtnAimbot,        "AutoBat")
    hookKey(keyBtnTPDown,        "TPDown")
    hookKey(keyBtnDrop,          "Drop")
    hookKey(keyBtnLowSpeed,      "LowSpeed")

    y = addDividerTo(tSettings, y)
    y = addCatHeader(tSettings, "DISPLAY", y)

    -- Float height slider
    do
        local lRow=Instance.new("Frame"); lRow.Size=UDim2.new(1,-24,0,20); lRow.Position=UDim2.new(0,12,0,y)
        lRow.BackgroundTransparency=1; lRow.ZIndex=5; lRow.Parent=tSettings
        local slLbl=Instance.new("TextLabel"); slLbl.Size=UDim2.new(0.6,0,1,0); slLbl.BackgroundTransparency=1
        slLbl.Text="Float Height"; slLbl.TextColor3=C.textDim; slLbl.Font=Enum.Font.GothamSemibold
        slLbl.TextSize=11; slLbl.TextXAlignment=Enum.TextXAlignment.Left; slLbl.ZIndex=5; slLbl.Parent=lRow
        local slVal=Instance.new("TextLabel"); slVal.Size=UDim2.new(0.4,0,1,0); slVal.Position=UDim2.new(0.6,0,0,0)
        slVal.BackgroundTransparency=1; slVal.Text=tostring(FLOAT_HEIGHT).." st"
        slVal.TextColor3=C.textDim; slVal.Font=Enum.Font.GothamBold
        slVal.TextSize=11; slVal.TextXAlignment=Enum.TextXAlignment.Right; slVal.ZIndex=5; slVal.Parent=lRow
        y=y+22
        local track=Instance.new("Frame"); track.Size=UDim2.new(1,-24,0,6); track.Position=UDim2.new(0,12,0,y)
        track.BackgroundColor3=Color3.fromRGB(30,10,50); track.BorderSizePixel=0; track.ZIndex=5; track.Parent=tSettings
        Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(math.clamp((FLOAT_HEIGHT-1)/19,0,1),0,1,0)
        fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.ZIndex=5; fill.Parent=track
        Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
        local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14)
        knob.Position=UDim2.new(math.clamp((FLOAT_HEIGHT-1)/19,0,1),-7,0.5,-7)
        knob.BackgroundColor3=Color3.fromRGB(220,200,255); knob.BorderSizePixel=0; knob.ZIndex=6; knob.Parent=track
        Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
        local hitbox=Instance.new("TextButton"); hitbox.Size=UDim2.new(1,14,1,14); hitbox.Position=UDim2.new(0,-7,0,-7)
        hitbox.BackgroundTransparency=1; hitbox.Text=""; hitbox.ZIndex=7; hitbox.Parent=track
        local isDrag=false
        local function updateSlider(ix)
            local ap=track.AbsolutePosition.X; local as=track.AbsoluteSize.X
            local pct=math.clamp((ix-ap)/as,0,1)
            FLOAT_HEIGHT=math.floor(1+pct*19)
            fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-7,0.5,-7)
            slVal.Text=tostring(FLOAT_HEIGHT).." st"
        end
        hitbox.MouseButton1Down:Connect(function() isDrag=true end)
        UserInputService.InputChanged:Connect(function(i) if isDrag and i.UserInputType==Enum.UserInputType.MouseMovement then updateSlider(i.Position.X) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then isDrag=false end end)
        y=y+22
    end

    -- UI Transparency slider
    do
        local lRow=Instance.new("Frame"); lRow.Size=UDim2.new(1,-24,0,20); lRow.Position=UDim2.new(0,12,0,y)
        lRow.BackgroundTransparency=1; lRow.ZIndex=5; lRow.Parent=tSettings
        local tlLbl=Instance.new("TextLabel"); tlLbl.Size=UDim2.new(0.6,0,1,0); tlLbl.BackgroundTransparency=1
        tlLbl.Text="UI Transparency"; tlLbl.TextColor3=C.textDim; tlLbl.Font=Enum.Font.GothamSemibold
        tlLbl.TextSize=11; tlLbl.TextXAlignment=Enum.TextXAlignment.Left; tlLbl.ZIndex=5; tlLbl.Parent=lRow
        local tVal=Instance.new("TextLabel"); tVal.Size=UDim2.new(0.4,0,1,0); tVal.Position=UDim2.new(0.6,0,0,0)
        tVal.BackgroundTransparency=1; tVal.Text="0%"; tVal.TextColor3=C.textDim
        tVal.Font=Enum.Font.GothamBold; tVal.TextSize=11; tVal.TextXAlignment=Enum.TextXAlignment.Right
        tVal.ZIndex=5; tVal.Parent=lRow
        y=y+22
        local track=Instance.new("Frame"); track.Size=UDim2.new(1,-24,0,6); track.Position=UDim2.new(0,12,0,y)
        track.BackgroundColor3=Color3.fromRGB(30,10,50); track.BorderSizePixel=0; track.ZIndex=5; track.Parent=tSettings
        Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)
        local fill=Instance.new("Frame"); fill.Size=UDim2.new(currentTransparency,0,1,0)
        fill.BackgroundColor3=C.accent; fill.BorderSizePixel=0; fill.ZIndex=5; fill.Parent=track
        Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
        local knob=Instance.new("Frame"); knob.Size=UDim2.new(0,14,0,14)
        knob.Position=UDim2.new(currentTransparency,-7,0.5,-7)
        knob.BackgroundColor3=Color3.fromRGB(220,200,255); knob.BorderSizePixel=0; knob.ZIndex=6; knob.Parent=track
        Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)
        local hitbox=Instance.new("TextButton"); hitbox.Size=UDim2.new(1,14,1,14); hitbox.Position=UDim2.new(0,-7,0,-7)
        hitbox.BackgroundTransparency=1; hitbox.Text=""; hitbox.ZIndex=7; hitbox.Parent=track
        local isDrag=false
        local function updateTrans(ix)
            local ap=track.AbsolutePosition.X; local as=track.AbsoluteSize.X
            local pct=math.clamp((ix-ap)/as,0,1)
            currentTransparency=pct
            fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,-7,0.5,-7)
            main.BackgroundTransparency=pct
            if StealBarFrame then StealBarFrame.BackgroundTransparency=math.max(0.04,pct) end
            tVal.Text=math.floor(pct*100).."%"
        end
        hitbox.MouseButton1Down:Connect(function() isDrag=true end)
        UserInputService.InputChanged:Connect(function(i) if isDrag and i.UserInputType==Enum.UserInputType.MouseMovement then updateTrans(i.Position.X) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then isDrag=false end end)
        y=y+22
    end

    do
        local lRow=Instance.new("Frame"); lRow.Size=UDim2.new(1,-24,0,20); lRow.Position=UDim2.new(0,12,0,y)
        lRow.BackgroundTransparency=1; lRow.ZIndex=5; lRow.Parent=tSettings
        local tlLbl=Instance.new("TextLabel"); tlLbl.Size=UDim2.new(0.6,0,1,0); tlLbl.BackgroundTransparency=1
        tlLbl.Text="Main GUI Size"; tlLbl.TextColor3=C.textDim; tlLbl.Font=Enum.Font.GothamSemibold
        tlLbl.TextSize=11; tlLbl.TextXAlignment=Enum.TextXAlignment.Left; tlLbl.ZIndex=5; tlLbl.Parent=lRow
        local tVal=Instance.new("TextLabel"); tVal.Size=UDim2.new(0.4,0,1,0); tVal.Position=UDim2.new(0.6,0,0,0)
        tVal.BackgroundTransparency=1; tVal.Text=string.format("%.0f%%", MAIN_GUI_SCALE*100); tVal.TextColor3=C.textDim
        tVal.Font=Enum.Font.GothamBold; tVal.TextSize=11; tVal.TextXAlignment=Enum.TextXAlignment.Right
        tVal.ZIndex=5; tVal.Parent=lRow
        y=y+24
        local btnRow=Instance.new("Frame"); btnRow.Size=UDim2.new(1,-24,0,26); btnRow.Position=UDim2.new(0,12,0,y)
        btnRow.BackgroundTransparency=1; btnRow.ZIndex=5; btnRow.Parent=tSettings
        local mainSizePresets={{label="25%",value=0.25},{label="50%",value=0.50},{label="75%",value=0.75},{label="100%",value=1.0}}
        local mainSizeBtns={}
        local function refreshMainSizeBtns()
            for _,info in ipairs(mainSizePresets) do
                local isActive=math.abs(MAIN_GUI_SCALE-info.value)<0.01
                info.btn.BackgroundColor3=isActive and C.accent or Color3.fromRGB(30,10,60)
                info.btn.TextColor3=isActive and Color3.fromRGB(255,255,255) or C.textDim
            end
        end
        for i,info in ipairs(mainSizePresets) do
            local bw=math.floor((1/4)*100+0.5)
            local btn=Instance.new("TextButton")
            btn.Size=UDim2.new(0.25,-3,1,0)
            btn.Position=UDim2.new((i-1)*0.25,(i==1 and 0 or 2),0,0)
            btn.BackgroundColor3=Color3.fromRGB(30,10,60)
            btn.TextColor3=C.textDim
            btn.Font=Enum.Font.GothamBold
            btn.TextSize=11
            btn.Text=info.label
            btn.BorderSizePixel=0
            btn.ZIndex=6
            btn.Parent=btnRow
            Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
            info.btn=btn
            btn.MouseButton1Click:Connect(function()
                applyMainGuiScale(info.value)
                tVal.Text=string.format("%.0f%%",MAIN_GUI_SCALE*100)
                refreshMainSizeBtns()
            end)
        end
        refreshMainSizeBtns()
        y=y+32
    end

    do
        local lRow=Instance.new("Frame"); lRow.Size=UDim2.new(1,-24,0,20); lRow.Position=UDim2.new(0,12,0,y)
        lRow.BackgroundTransparency=1; lRow.ZIndex=5; lRow.Parent=tSettings
        local tlLbl=Instance.new("TextLabel"); tlLbl.Size=UDim2.new(0.6,0,1,0); tlLbl.BackgroundTransparency=1
        tlLbl.Text="Mobile Buttons Size"; tlLbl.TextColor3=C.textDim; tlLbl.Font=Enum.Font.GothamSemibold
        tlLbl.TextSize=11; tlLbl.TextXAlignment=Enum.TextXAlignment.Left; tlLbl.ZIndex=5; tlLbl.Parent=lRow
        local tVal=Instance.new("TextLabel"); tVal.Size=UDim2.new(0.4,0,1,0); tVal.Position=UDim2.new(0.6,0,0,0)
        tVal.BackgroundTransparency=1; tVal.Text=string.format("%.0f%%", MOBILE_GUI_SCALE*100); tVal.TextColor3=C.textDim
        tVal.Font=Enum.Font.GothamBold; tVal.TextSize=11; tVal.TextXAlignment=Enum.TextXAlignment.Right
        tVal.ZIndex=5; tVal.Parent=lRow
        y=y+24
        local btnRow=Instance.new("Frame"); btnRow.Size=UDim2.new(1,-24,0,26); btnRow.Position=UDim2.new(0,12,0,y)
        btnRow.BackgroundTransparency=1; btnRow.ZIndex=5; btnRow.Parent=tSettings
        local mobileSizePresets={{label="25%",value=0.25},{label="50%",value=0.50},{label="75%",value=0.75},{label="100%",value=1.0}}
        local mobileSizeBtns={}
        local function refreshMobileSizeBtns()
            for _,info in ipairs(mobileSizePresets) do
                local isActive=math.abs(MOBILE_GUI_SCALE-info.value)<0.01
                info.btn.BackgroundColor3=isActive and C.accent or Color3.fromRGB(30,10,60)
                info.btn.TextColor3=isActive and Color3.fromRGB(255,255,255) or C.textDim
            end
        end
        for i,info in ipairs(mobileSizePresets) do
            local btn=Instance.new("TextButton")
            btn.Size=UDim2.new(0.25,-3,1,0)
            btn.Position=UDim2.new((i-1)*0.25,(i==1 and 0 or 2),0,0)
            btn.BackgroundColor3=Color3.fromRGB(30,10,60)
            btn.TextColor3=C.textDim
            btn.Font=Enum.Font.GothamBold
            btn.TextSize=11
            btn.Text=info.label
            btn.BorderSizePixel=0
            btn.ZIndex=6
            btn.Parent=btnRow
            Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
            info.btn=btn
            btn.MouseButton1Click:Connect(function()
                applyMobileGuiScale(info.value)
                tVal.Text=string.format("%.0f%%",MOBILE_GUI_SCALE*100)
                refreshMobileSizeBtns()
            end)
        end
        refreshMobileSizeBtns()
        y=y+32
    end

    y=y+10
    y = makeToggle(tSettings, "Mobile Buttons", "MobileButtonsVisible", function(s)
        Enabled.MobileButtonsVisible=s
        if _G.BontHubMobileContainer then _G.BontHubMobileContainer.Visible=s end
    end, nil, y)
    y = makeToggle(tSettings, "Lock UI", "UILocked", function(s)
        Enabled.UILocked=s; main.Draggable=not s
        if _G.BontHubMobileContainer then _G.BontHubMobileContainer.Draggable=not s end
    end, nil, y)

    tSettings.CanvasSize = UDim2.new(0,0,0,y+10)
end

-- ===================================================
-- STEAL BAR (rebuilt, attached cleanly to main)
-- ===================================================
local STEAL_BAR_HEIGHT = 64
local STEAL_BAR_SIDE_PAD = 12
local STEAL_BAR_BOTTOM_PAD = 12

StealBarFrame = Instance.new("Frame")
StealBarFrame.Name = "BontHubStealBar"
StealBarFrame.Size = UDim2.new(1, -(STEAL_BAR_SIDE_PAD*2), 0, STEAL_BAR_HEIGHT)
StealBarFrame.Position = UDim2.new(0, STEAL_BAR_SIDE_PAD, 1, -(STEAL_BAR_HEIGHT + STEAL_BAR_BOTTOM_PAD))
StealBarFrame.BackgroundColor3 = C.headerBg
StealBarFrame.BackgroundTransparency = 0.04
StealBarFrame.BorderSizePixel = 0
StealBarFrame.Visible = false
StealBarFrame.Active = false
StealBarFrame.Draggable = false
StealBarFrame.AnchorPoint = Vector2.new(0, 0)
StealBarFrame.ZIndex = 10
StealBarFrame.Parent = main
Instance.new("UICorner", StealBarFrame).CornerRadius = UDim.new(0, 12)
do local s=Instance.new("UIStroke"); s.Color=C.accent; s.Thickness=1.5; s.Parent=StealBarFrame end

local function syncStealBar()
    if not StealBarFrame or not main then return end
    StealBarFrame.Size = UDim2.new(1, -(STEAL_BAR_SIDE_PAD*2), 0, STEAL_BAR_HEIGHT)
    StealBarFrame.Position = UDim2.new(0, STEAL_BAR_SIDE_PAD, 1, -(STEAL_BAR_HEIGHT + STEAL_BAR_BOTTOM_PAD))
end
syncStealBar()

do
    local sbTitle=Instance.new("TextLabel"); sbTitle.Size=UDim2.new(0,110,0,22); sbTitle.Position=UDim2.new(0,12,0,4)
    sbTitle.BackgroundTransparency=1; sbTitle.Text="AUTO STEAL"; sbTitle.Font=Enum.Font.GothamBlack; sbTitle.TextSize=12; sbTitle.TextColor3=C.accent
    sbTitle.TextXAlignment=Enum.TextXAlignment.Left; sbTitle.ZIndex=11; sbTitle.Parent=StealBarFrame
    SBStatus=Instance.new("TextLabel"); SBStatus.Size=UDim2.new(0,80,0,22); SBStatus.Position=UDim2.new(0,124,0,4)
    SBStatus.BackgroundTransparency=1; SBStatus.Text="READY"; SBStatus.Font=Enum.Font.GothamBlack; SBStatus.TextSize=11; SBStatus.TextColor3=C.textDim
    SBStatus.ZIndex=11; SBStatus.Parent=StealBarFrame
    SBPct=Instance.new("TextLabel"); SBPct.Size=UDim2.new(0,40,0,22); SBPct.Position=UDim2.new(0,8,0,4)
    SBPct.BackgroundTransparency=1; SBPct.Text="0%"; SBPct.Font=Enum.Font.GothamBlack; SBPct.TextSize=13; SBPct.TextColor3=C.text
    SBPct.TextXAlignment=Enum.TextXAlignment.Left; SBPct.ZIndex=11; SBPct.Visible=false; SBPct.Parent=StealBarFrame
end

local sbTrack=Instance.new("Frame"); sbTrack.Size=UDim2.new(1,-16,0,8); sbTrack.Position=UDim2.new(0,8,0,42)
sbTrack.BackgroundColor3=C.stealTrack; sbTrack.BorderSizePixel=0; sbTrack.ClipsDescendants=true; sbTrack.ZIndex=11; sbTrack.Parent=StealBarFrame
Instance.new("UICorner",sbTrack).CornerRadius=UDim.new(1,0)
SBFill=Instance.new("Frame"); SBFill.Size=UDim2.new(0,0,1,0); SBFill.BackgroundColor3=C.stealFill
SBFill.BorderSizePixel=0; SBFill.ZIndex=12; SBFill.Parent=sbTrack
do local fg=Instance.new("UIGradient"); fg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,C.accent),ColorSequenceKeypoint.new(1,C.accent2)}; fg.Parent=SBFill end
Instance.new("UICorner",SBFill).CornerRadius=UDim.new(1,0)

local stealBarTimer=0
RunService.Heartbeat:Connect(function(dt)
    if not StealBarFrame then return end
    syncStealBar()
    StealBarFrame.Visible=Enabled.AutoSteal
    if not Enabled.AutoSteal then stealBarTimer=0
        if SBFill then SBFill.Size=UDim2.new(0,0,1,0) end
        if SBPct then SBPct.Visible=false end
        if SBStatus then SBStatus.Text="READY" end; return
    end
    if isStealing and stealStartTime then
        local prog=math.clamp((tick()-stealStartTime)/Values.STEAL_DURATION,0,1)
        if SBFill then SBFill.Size=UDim2.new(prog,0,1,0) end
        if SBPct then SBPct.Visible=true; SBPct.Text=math.floor(prog*100).."%" end
        if SBStatus then SBStatus.Text="STEALING" end
    else
        stealBarTimer=stealBarTimer+dt
        local pulse=math.abs(math.sin(stealBarTimer*1.4))*0.35
        if SBFill then SBFill.Size=UDim2.new(pulse,0,1,0) end
        if SBPct then SBPct.Visible=false end
        if SBStatus then SBStatus.Text="SCANNING" end
    end
end)

-- ===================================================
-- MINI GUI  (redesigned - cleaner compact dashboard)
-- ===================================================
local miniGui = Instance.new("Frame")
miniGui.Name = "BontHubMiniPanel"
_G.BontMiniGui = miniGui
miniGui.Size = UDim2.new(0, 188, 0, 168)
miniGui.Position = UDim2.new(1, -(188+16), 0, 16)
miniGui.BackgroundColor3 = Color3.fromRGB(6, 2, 14)
miniGui.BackgroundTransparency = 0.04
miniGui.BorderSizePixel = 0
miniGui.Active = true
miniGui.Draggable = true
miniGui.ZIndex = 30
miniGui.Parent = gui
Instance.new("UICorner", miniGui).CornerRadius = UDim.new(0, 18)

do
    local ms = Instance.new("UIStroke")
    ms.Color = Color3.fromRGB(170,80,255)
    ms.Thickness = 1.5
    ms.Transparency = 0.22
    ms.Parent = miniGui
end

local function makeMiniCard(parent, x, y, w, h)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, w, 0, h)
    card.Position = UDim2.new(0, x, 0, y)
    card.BackgroundColor3 = Color3.fromRGB(13, 5, 28)
    card.BorderSizePixel = 0
    card.ZIndex = 31
    card.Parent = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 70, 200)
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = card

    return card
end

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -20, 0, 18)
titleLbl.Position = UDim2.new(0, 10, 0, 10)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "BONT HUB"
titleLbl.TextColor3 = Color3.fromRGB(220,180,255)
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 13
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.ZIndex = 32
titleLbl.Parent = miniGui

local statsHolder = Instance.new("Frame")
statsHolder.Size = UDim2.new(1, -20, 0, 34)
statsHolder.Position = UDim2.new(0, 10, 0, 34)
statsHolder.BackgroundTransparency = 1
statsHolder.ZIndex = 31
statsHolder.Parent = miniGui

local fpsCard = makeMiniCard(statsHolder, 0, 0, 80, 34)
local spdCard = makeMiniCard(statsHolder, 88, 0, 80, 34)

local function makeStat(card, topText)
    local top = Instance.new("TextLabel")
    top.Size = UDim2.new(1, -12, 0, 12)
    top.Position = UDim2.new(0, 6, 0, 4)
    top.BackgroundTransparency = 1
    top.Text = topText
    top.TextColor3 = Color3.fromRGB(125, 90, 180)
    top.Font = Enum.Font.GothamBold
    top.TextSize = 8
    top.TextXAlignment = Enum.TextXAlignment.Left
    top.ZIndex = 32
    top.Parent = card

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, -12, 0, 14)
    val.Position = UDim2.new(0, 6, 0, 16)
    val.BackgroundTransparency = 1
    val.Text = "--"
    val.TextColor3 = Color3.fromRGB(245,245,255)
    val.Font = Enum.Font.GothamBlack
    val.TextSize = 11
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.ZIndex = 32
    val.Parent = card
    return val
end

local fpsVal = makeStat(fpsCard, "FPS")
local spdVal = makeStat(spdCard, "SPD")

local speedWrap = makeMiniCard(miniGui, 10, 76, 168, 64)

local speedTitle = Instance.new("TextLabel")
speedTitle.Size = UDim2.new(1, -12, 0, 12)
speedTitle.Position = UDim2.new(0, 6, 0, 5)
speedTitle.BackgroundTransparency = 1
speedTitle.Text = "SPEED"
speedTitle.TextColor3 = C.accentGlow
speedTitle.Font = Enum.Font.GothamBlack
speedTitle.TextSize = 9
speedTitle.TextXAlignment = Enum.TextXAlignment.Left
speedTitle.ZIndex = 32
speedTitle.Parent = speedWrap

local miniNormalBox, miniCarryBox
local function miniSpdCompact(labelText, defVal, onCh, getVal, y)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -12, 0, 22)
    row.Position = UDim2.new(0, 6, 0, y)
    row.BackgroundTransparency = 1
    row.ZIndex = 32
    row.Parent = speedWrap

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 60, 1, 0)
    lbl.Position = UDim2.new(0, 2, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = C.textMid
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 33
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 54, 0, 20)
    box.AnchorPoint = Vector2.new(1, 0)
    box.Position = UDim2.new(1, -2, 0, 1)
    box.BackgroundColor3 = Color3.fromRGB(18, 6, 36)
    box.BorderSizePixel = 0
    box.Text = tostring(defVal)
    box.TextColor3 = C.text
    box.Font = Enum.Font.GothamBold
    box.TextSize = 11
    box.TextXAlignment = Enum.TextXAlignment.Right
    box.ClearTextOnFocus = false
    box.ZIndex = 33
    box.Parent = row
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local s = Instance.new("UIStroke")
    s.Color = C.border
    s.Thickness = 1
    s.Transparency = 0.35
    s.Parent = box

    box.FocusLost:Connect(function()
        local v = tonumber(box.Text)
        if v then
            onCh(v)
            box.Text = tostring(v)
        else
            box.Text = tostring(getVal())
        end
    end)
    return box
end

miniNormalBox = miniSpdCompact("Normal", NORMAL_SPEED, function(v) NORMAL_SPEED = v end, function() return NORMAL_SPEED end, 22)
miniCarryBox  = miniSpdCompact("Carry",  CARRY_SPEED,  function(v) CARRY_SPEED  = v end, function() return CARRY_SPEED  end, 42)

local activeCard = makeMiniCard(miniGui, 10, 144, 168, 14)
activeCard.BackgroundTransparency = 1
for _, child in ipairs(activeCard:GetChildren()) do
    if child:IsA("UIStroke") then child:Destroy() end
end

local activeLabel = Instance.new("TextLabel")
activeLabel.Size = UDim2.new(1, 0, 1, 0)
activeLabel.BackgroundTransparency = 1
activeLabel.Text = "-- none active --"
activeLabel.TextColor3 = Color3.fromRGB(110, 70, 165)
activeLabel.Font = Enum.Font.GothamBold
activeLabel.TextSize = 8
activeLabel.TextXAlignment = Enum.TextXAlignment.Center
activeLabel.TextWrapped = true
activeLabel.ZIndex = 32
activeLabel.Parent = activeCard

do
    local fpsT = 0
    local fpsCount = 0
    RunService.Heartbeat:Connect(function(dt)
        fpsCount = fpsCount + 1
        fpsT = fpsT + dt
        if fpsT >= 0.5 then
            pcall(function()
                fpsVal.Text = tostring(math.floor(fpsCount / fpsT + 0.5))
            end)
            fpsT = 0
            fpsCount = 0
        end
        pcall(function()
            local r = getHRP()
            if r then
                spdVal.Text = tostring(math.floor(Vector3.new(r.AssemblyLinearVelocity.X,0,r.AssemblyLinearVelocity.Z).Magnitude + 0.5))
            end
        end)
    end)
end

task.spawn(function()
    while miniGui and miniGui.Parent do
        task.wait(0.5)
        pcall(function()
            local active = {}
            if Enabled.AutoSteal then table.insert(active,"STEAL") end
            if AutoLeftEnabled then table.insert(active,"A.LEFT") end
            if AutoRightEnabled then table.insert(active,"A.RIGHT") end
            if Enabled.Galaxy then table.insert(active,"GALAXY") end
            if floatEnabled then table.insert(active,"FLOAT") end
            if Enabled.BatAimbot then table.insert(active,"AIMBOT") end
            activeLabel.Text = #active > 0 and table.concat(active, " | ") or "-- none active --"
        end)
    end
end)

miniGui.Size = UDim2.new(0,188,0,168)

-- ??????????????????????????????????????????
-- MOBILE BUTTONS  (compact mobile redesign - mov/negru)
-- ??????????????????????????????????????????
do
    local vp = workspace.CurrentCamera.ViewportSize
    local baseScale = math.clamp(math.min(vp.X, vp.Y) / 430, 0.82, 1.0)

    local MB = {
        panel      = Color3.fromRGB(7, 5, 18),
        panel2     = Color3.fromRGB(18, 8, 36),
        btnOff     = Color3.fromRGB(10, 8, 20),
        btnOn      = Color3.fromRGB(120, 36, 190),
        border     = Color3.fromRGB(120, 70, 200),
        borderOff  = Color3.fromRGB(45, 35, 85),
        text       = Color3.fromRGB(245, 245, 255),
        textDim    = Color3.fromRGB(205, 185, 255),
        textOff    = Color3.fromRGB(150, 135, 195),
        glow       = Color3.fromRGB(190, 120, 255),
        danger     = Color3.fromRGB(215, 45, 95),
        topStrip   = Color3.fromRGB(34, 18, 64),
    }

    local BTN_W   = math.floor(88 * baseScale)
    local BTN_H   = math.floor(72 * baseScale)
    local GAP     = math.floor(8 * baseScale)
    local PAD     = math.floor(10 * baseScale)
    local RADIUS  = math.floor(18 * baseScale)
    local FSIZE_1 = math.floor(12 * baseScale)
    local FSIZE_2 = math.floor(12 * baseScale)
    local PANEL_W = PAD * 2 + BTN_W * 2 + GAP
    local PANEL_H = PAD * 2 + BTN_H * 4 + GAP * 3

    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "BontHubMobileButtons"
    mobileGui.ResetOnSpawn = false
    mobileGui.DisplayOrder = 20
    mobileGui.IgnoreGuiInset = true
    mobileGui.Parent = pgui

    local panel = Instance.new("Frame")
    panel.Name = "BontHubMobilePanel"
    panel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
    panel.Position = UDim2.new(1, -(PANEL_W + 10), 1, -(PANEL_H + 12))
    panel.BackgroundColor3 = MB.panel
    panel.BorderSizePixel = 0
    panel.Active = true
    panel.ZIndex = 18
    panel.Parent = mobileGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, RADIUS)

    local panelGrad = Instance.new("UIGradient")
    panelGrad.Rotation = 125
    panelGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, MB.panel2),
        ColorSequenceKeypoint.new(0.45, MB.panel),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 4, 12))
    }
    panelGrad.Parent = panel

    local panelStroke = Instance.new("UIStroke")
    panelStroke.Color = MB.border
    panelStroke.Thickness = 1.4
    panelStroke.Transparency = 0.18
    panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    panelStroke.Parent = panel
    _G.BontHubMobilePanelStroke = panelStroke

    local container = Instance.new("Frame")
    container.Name = "ButtonsContainer"
    container.Size = UDim2.new(1, -PAD * 2, 1, -PAD * 2)
    container.Position = UDim2.new(0, PAD, 0, PAD)
    container.BackgroundTransparency = 1
    container.ZIndex = 19
    container.Parent = panel

    panel.Visible = Enabled.MobileButtonsVisible
    applyMobileGuiScale(MOBILE_GUI_SCALE)

    local mobileVisualUpdaters = {}

    local uiLocked = false
    _G.BontHubUILocked = false

    local function setLock(locked)
        uiLocked = locked
        _G.BontHubUILocked = locked
        panelStroke.Color = locked and MB.glow or MB.border
    end

    local dragging = false
    local dragInput, dragStart, startPos
    local function updateDrag(input)
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end

    local function beginDrag(input)
        if uiLocked then return end
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
        dragInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end

    panel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginDrag(input)
        end
    end)

    panel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            updateDrag(input)
        end
    end)

    local function makeMobileBtn(col, row, labelLine1, labelLine2, activeColor, onPress, getState, isMomentary)
        local btn = Instance.new("Frame")
        btn.Size = UDim2.new(0, BTN_W, 0, BTN_H)
        btn.Position = UDim2.new(0, (col - 1) * (BTN_W + GAP), 0, (row - 1) * (BTN_H + GAP))
        btn.BackgroundColor3 = MB.btnOff
        btn.BorderSizePixel = 0
        btn.ZIndex = 20
        btn.Parent = container
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, RADIUS)

        local btnGrad = Instance.new("UIGradient")
        btnGrad.Rotation = 135
        btnGrad.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 12, 34)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 5, 13))
        }
        btnGrad.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = MB.borderOff
        stroke.Thickness = 1.2
        stroke.Transparency = 0.08
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btn

        local lbl1 = Instance.new("TextLabel")
        lbl1.Size = UDim2.new(1, -8, 0, math.floor(BTN_H * 0.36))
        lbl1.Position = UDim2.new(0, 4, 0, math.floor(BTN_H * 0.22))
        lbl1.BackgroundTransparency = 1
        lbl1.Text = labelLine1
        lbl1.TextColor3 = MB.text
        lbl1.Font = Enum.Font.GothamBlack
        lbl1.TextSize = FSIZE_1
        lbl1.TextWrapped = true
        lbl1.ZIndex = 22
        lbl1.Parent = btn

        local lbl2 = Instance.new("TextLabel")
        lbl2.Size = UDim2.new(1, -8, 0, math.floor(BTN_H * 0.30))
        lbl2.Position = UDim2.new(0, 4, 0, math.floor(BTN_H * 0.54))
        lbl2.BackgroundTransparency = 1
        lbl2.Text = labelLine2
        lbl2.TextColor3 = MB.textDim
        lbl2.Font = Enum.Font.GothamBlack
        lbl2.TextSize = FSIZE_2
        lbl2.TextWrapped = true
        lbl2.ZIndex = 22
        lbl2.Parent = btn

        local touch = Instance.new("TextButton")
        touch.Size = UDim2.new(1, 0, 1, 0)
        touch.BackgroundTransparency = 1
        touch.Text = ""
        touch.AutoButtonColor = false
        touch.ZIndex = 25
        touch.Parent = btn

        local function updateVisual(active)
            if active then
                btn.BackgroundColor3 = activeColor
                stroke.Color = Color3.fromRGB(225, 190, 255)
                lbl2.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                btn.BackgroundColor3 = MB.btnOff
                stroke.Color = MB.borderOff
                lbl2.TextColor3 = MB.textDim
            end
        end

        local pressBusy = false
        touch.MouseButton1Click:Connect(function()
            if pressBusy then return end
            pressBusy = true
            TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
                Size = UDim2.new(0, BTN_W - 2, 0, BTN_H - 2),
                Position = UDim2.new(0, (col - 1) * (BTN_W + GAP) + 1, 0, (row - 1) * (BTN_H + GAP) + 1)
            }):Play()
            task.delay(0.08, function()
                pcall(onPress)
                updateVisual(getState())
                TweenService:Create(btn, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
                    Size = UDim2.new(0, BTN_W, 0, BTN_H),
                    Position = UDim2.new(0, (col - 1) * (BTN_W + GAP), 0, (row - 1) * (BTN_H + GAP))
                }):Play()
                if isMomentary then
                    task.delay(0.12, function() updateVisual(getState()) end)
                end
                pressBusy = false
            end)
        end)

        table.insert(mobileVisualUpdaters, function()
            if panel and panel.Parent then
                updateVisual(getState())
            end
        end)

        return btn, updateVisual
    end

    makeMobileBtn(1, 1, "DROP", "BR", MB.danger,
        function() task.spawn(doDropBrainrots) end,
        function() return false end, true)

    makeMobileBtn(2, 1, "AUTO", "LEFT", MB.btnOn,
        function()
            AutoLeftEnabled = not AutoLeftEnabled
            Enabled.AutoLeftEnabled = AutoLeftEnabled
            if VisualSetters.AutoLeftEnabled then VisualSetters.AutoLeftEnabled(AutoLeftEnabled) end
            if AutoLeftEnabled then startAutoLeft() else stopAutoLeft() end
        end,
        function() return AutoLeftEnabled end)

    makeMobileBtn(1, 2, "BAT", "AIMBOT", Color3.fromRGB(150, 48, 220),
        function()
            local ns = not Enabled.BatAimbot
            Enabled.BatAimbot = ns
            autoBatToggled = ns
            if VisualSetters.BatAimbot then VisualSetters.BatAimbot(ns) end
            if ns then startBatAimbot() else stopBatAimbot() end
        end,
        function() return Enabled.BatAimbot end)

    makeMobileBtn(2, 2, "AUTO", "RIGHT", MB.btnOn,
        function()
            AutoRightEnabled = not AutoRightEnabled
            Enabled.AutoRightEnabled = AutoRightEnabled
            if VisualSetters.AutoRightEnabled then VisualSetters.AutoRightEnabled(AutoRightEnabled) end
            if AutoRightEnabled then startAutoRight() else stopAutoRight() end
        end,
        function() return AutoRightEnabled end)

    makeMobileBtn(1, 3, "TP", "DOWN", Color3.fromRGB(110, 70, 185),
        function() task.spawn(doTPDown) end,
        function() return false end, true)

    makeMobileBtn(2, 3, "CARRY", "SPEED", Color3.fromRGB(135, 44, 205),
        function()
            speedToggled = not speedToggled
            if speedToggled then
                lowSpeedToggled = false
                Enabled.LowSpeedEnabled = false
                if VisualSetters.LowSpeedEnabled then VisualSetters.LowSpeedEnabled(false, true) end
            end
            if modeLabel then
                modeLabel.Text = speedToggled and "Mode: Carry" or "Mode: Normal"
            end
        end,
        function() return speedToggled end)

    makeMobileBtn(1, 4, "LAGGER", "SPEED", Color3.fromRGB(115, 56, 235),
        function()
            lowSpeedToggled = not lowSpeedToggled
            Enabled.LowSpeedEnabled = lowSpeedToggled
            if VisualSetters.LowSpeedEnabled then VisualSetters.LowSpeedEnabled(lowSpeedToggled, true) end
            if lowSpeedToggled then
                speedToggled = false
                if modeLabel then
                    modeLabel.Text = "Mode: Low (" .. tostring(LOW_SPEED_VALUE) .. ")"
                end
            else
                if modeLabel then
                    modeLabel.Text = speedToggled and "Mode: Carry" or "Mode: Normal"
                end
            end
        end,
        function() return lowSpeedToggled end)

    task.spawn(function()
        while panel and panel.Parent do
            for _, updater in ipairs(mobileVisualUpdaters) do
                pcall(updater)
            end
            task.wait(MOBILE_VISUAL_UPDATE_RATE)
        end
    end)

    _G.BontHubMobileSetLock = setLock
    _G.BontMobileContainer = panel
    _G.BontHubMobileContainer = panel

    print("[BONT HUB] Compact mobile buttons loaded")
end

-- -- STANDALONE ? TOGGLE BUTTON (identic cu Bont)
-- ??????????????????????????????????????????
do
    local stGui = Instance.new("ScreenGui")
    stGui.Name = "BontHubUIToggleBtn"
    stGui.ResetOnSpawn = false
    stGui.DisplayOrder = 30
    stGui.IgnoreGuiInset = true
    stGui.Parent = pgui

    local SIZE = 52

    local gBtn = Instance.new("TextButton")
    gBtn.Size = UDim2.new(0, SIZE, 0, SIZE)
    gBtn.Position = UDim2.new(0, 10, 0.5, -SIZE/2)
    gBtn.BackgroundColor3 = Color3.fromRGB(7, 7, 14)
    gBtn.BackgroundTransparency = 0.08
    gBtn.BorderSizePixel = 0
    gBtn.Text = "?"
    gBtn.TextSize = 28
    gBtn.Font = Enum.Font.GothamBlack
    gBtn.ZIndex = 30
    gBtn.Active = true
    gBtn.Draggable = true
    gBtn.Parent = stGui
    Instance.new("UICorner", gBtn).CornerRadius = UDim.new(0, 14)

    local gStroke = Instance.new("UIStroke")
    gStroke.Color = Color3.fromRGB(120, 100, 255)
    gStroke.Thickness = 1.5; gStroke.Transparency = 0.4
    gStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    gStroke.Parent = gBtn

    local function updateBtn()
        if guiVisible then
            gBtn.BackgroundColor3 = Color3.fromRGB(7, 7, 14)
            gStroke.Transparency = 0.4
        else
            gBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 72)
            gStroke.Transparency = 0
        end
    end

    gBtn.MouseButton1Click:Connect(function()
        guiVisible = not guiVisible
        main.Visible = guiVisible
        updateBtn()
    end)

    RunService.Heartbeat:Connect(function()
        if main.Visible ~= guiVisible then guiVisible = main.Visible end
        updateBtn()
    end)

    _G.BontHubUIToggleBtn = gBtn
end
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if waitingForKeybind and input.KeyCode ~= Enum.KeyCode.Unknown then
        local k = input.KeyCode
        local t = waitingForKeybindType
        if t=="AutoLeft"      then autoLeftKey=k
        elseif t=="AutoRight" then autoRightKey=k
        elseif t=="AutoLeftPlay"  then autoLeftPlayKey=k
        elseif t=="AutoRightPlay" then autoRightPlayKey=k
        elseif t=="AutoBat"       then autoBatKey=k
        elseif t=="SpeedToggle"   then speedToggleKey=k
        elseif t=="GUIToggle"     then guiToggleKey=k
        elseif t=="Float"         then floatKey=k
        elseif t=="TPDown"        then tpDownKey=k
        elseif t=="Drop"          then dropKey=k
        elseif t=="LowSpeed"      then lowSpeedKey=k end
        waitingForKeybind.Text = k.Name
        waitingForKeybind.TextColor3 = C.text
        waitingForKeybind = nil; waitingForKeybindType = nil
        return
    end
    if input.KeyCode == speedToggleKey then
        speedToggled = not speedToggled
        if speedToggled then
            lowSpeedToggled = false
            Enabled.LowSpeedEnabled = false
            if VisualSetters.LowSpeedEnabled then VisualSetters.LowSpeedEnabled(false, true) end
        end
        if modeLabel then modeLabel.Text = speedToggled and "Mode: Carry" or "Mode: Normal" end
    end
    if input.KeyCode == lowSpeedKey then
        lowSpeedToggled = not lowSpeedToggled
        Enabled.LowSpeedEnabled = lowSpeedToggled
        if VisualSetters.LowSpeedEnabled then VisualSetters.LowSpeedEnabled(lowSpeedToggled, true) end
        if lowSpeedToggled then
            speedToggled = false
            if modeLabel then modeLabel.Text = "Mode: Low (" .. tostring(LOW_SPEED_VALUE) .. ")" end
        else
            if modeLabel then modeLabel.Text = speedToggled and "Mode: Carry" or "Mode: Normal" end
        end
    end
    if input.KeyCode == guiToggleKey then
        guiVisible = not guiVisible; main.Visible = guiVisible
    end
    if input.KeyCode == autoBatKey then
        autoBatToggled = not autoBatToggled; Enabled.BatAimbot = autoBatToggled
        if VisualSetters.BatAimbot then VisualSetters.BatAimbot(autoBatToggled) end
        if autoBatToggled then startBatAimbot() else stopBatAimbot() end
    end
    if input.KeyCode == floatKey then
        floatEnabled = not floatEnabled; Enabled.FloatEnabled = floatEnabled
        if VisualSetters.FloatEnabled then VisualSetters.FloatEnabled(floatEnabled) end
        if floatEnabled then startFloat() else stopFloat() end
    end
    if input.KeyCode == tpDownKey then task.spawn(doTPDown) end
    if input.KeyCode == dropKey   then task.spawn(executeBontDrop) end
    if input.KeyCode == autoLeftKey then
        AutoLeftEnabled = not AutoLeftEnabled; Enabled.AutoLeftEnabled = AutoLeftEnabled
        if VisualSetters.AutoLeftEnabled then VisualSetters.AutoLeftEnabled(AutoLeftEnabled) end
        if AutoLeftEnabled then startAutoLeft() else stopAutoLeft() end
    end
    if input.KeyCode == autoRightKey then
        AutoRightEnabled = not AutoRightEnabled; Enabled.AutoRightEnabled = AutoRightEnabled
        if VisualSetters.AutoRightEnabled then VisualSetters.AutoRightEnabled(AutoRightEnabled) end
        if AutoRightEnabled then startAutoRight() else stopAutoRight() end
    end
    if input.KeyCode == autoLeftPlayKey then
        AutoLeftPlayEnabled = not AutoLeftPlayEnabled; Enabled.AutoLeftPlayEnabled = AutoLeftPlayEnabled
        if VisualSetters.AutoLeftPlayEnabled then VisualSetters.AutoLeftPlayEnabled(AutoLeftPlayEnabled) end
        if AutoLeftPlayEnabled then startAutoLeftPlay() else stopAutoLeftPlay() end
    end
    if input.KeyCode == autoRightPlayKey then
        AutoRightPlayEnabled = not AutoRightPlayEnabled; Enabled.AutoRightPlayEnabled = AutoRightPlayEnabled
        if VisualSetters.AutoRightPlayEnabled then VisualSetters.AutoRightPlayEnabled(AutoRightPlayEnabled) end
        if AutoRightPlayEnabled then startAutoRightPlay() else stopAutoRightPlay() end
    end
    if input.KeyCode == Enum.KeyCode.M then
        Enabled.Galaxy = not Enabled.Galaxy
        if VisualSetters.Galaxy then VisualSetters.Galaxy(Enabled.Galaxy) end
        if Enabled.Galaxy then startGalaxy() else stopGalaxy() end
    end
end)

-- Initial visual sync + restart features loaded from config
task.spawn(function()
    task.wait(0.15)
    for key, setter in pairs(VisualSetters) do
        if Enabled[key] ~= nil then pcall(setter, Enabled[key], true) end
    end
    if Enabled.AutoSteal     then pcall(startAutoSteal)     end
    if Enabled.AntiRagdoll   then pcall(startBontShield)    end
    if Enabled.Galaxy        then pcall(startGalaxy)        end
    if Enabled.Optimizer     then pcall(activatePowerMode)  end
    if Enabled.Unwalk        then pcall(startUnwalk)        end
    if Enabled.NoClip        then pcall(startNoClip)        end
    if Enabled.BatAimbot     then autoBatToggled=true; pcall(startBatAimbot) end
    if Enabled.CounterMedusa then pcall(startCounterMedusa) end
    if Enabled.RagdollTP     then pcall(startRagdollTP)     end
    if Enabled.Spinbot       then pcall(startSpinbot)       end
    if Enabled.AutoCarryOnPickup then pcall(startAutoCarryMode) end
    if Enabled.WaypointESP   then pcall(startWaypointESP)   end
    if Enabled.DarkMode      then pcall(activateDarkVision) end
    if floatEnabled          then pcall(startFloat)         end
    if AutoLeftEnabled       then pcall(startAutoLeft)      end
    if AutoRightEnabled      then pcall(startAutoRight)     end
    if AutoLeftPlayEnabled   then pcall(startAutoLeftPlay)  end
    if AutoRightPlayEnabled  then pcall(startAutoRightPlay) end
    if currentTransparency>0 then
        if main then main.BackgroundTransparency=currentTransparency end
        if StealBarFrame then StealBarFrame.BackgroundTransparency=math.max(0.04,currentTransparency) end
    end
    if speedToggled and modeLabel then modeLabel.Text="Mode: Carry" end
end)

end)()

print("[BONT HUB] Loaded OK")

