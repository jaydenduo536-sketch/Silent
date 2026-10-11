--[[
    Silent Aim v32.0  --  spin + rainbow GUI + infinite ammo + FIXED INSTANT KILL + NOCLIP
    Instant Kill rewrite:
      * Learns the game's real damage remote by watching FireServer calls on shoot
      * Rewrites that remote's damage arg to lethal -> SERVER agrees, kill sticks
      * Keeps local health-0 for instant feedback + short hold as backup
    Kept: silent aim, aim assist, infinite ammo, spin, rainbow GUI + sliders,
          FOV ring, ESP, hit FX/sounds, anti-kick, walkspeed, noclip bypass
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--====================== CONFIG ======================--
local MINFOV, MAXFOV = 5, 180

local Settings = {
    Enabled = false, ToggleKey = Enum.KeyCode.Q, AntiKick = true,
    FOV = 60, TeamCheck = true, AimPart = "Head", Predict = true,
    ProjectileSpeed = 900, MaxLead = 0.35, ShowTarget = true, IgnoreKnocked = true,
    VisibleCheck = true,
    HighlightColor = Color3.fromRGB(255, 255, 255),
    RingColor      = Color3.fromRGB(255, 255, 255),
    Walkspeed = 16, WalkspeedEnabled = false,
    KnockNames = {
        "Knocked","Downed","IsKnocked","IsDowned","knocked","downed",
        "IsRagdoll","Ragdoll","ragdoll","IsDead","Dead",
    },
}
getgenv().SilentAim = Settings

local HitFX = {
    Enabled = true, Sound = true, Effect = true,
    Window = 0.7, Cooldown = 0.08, Volume = 1, SoundSel = 1, EffectSel = 1,
}
getgenv().SilentAimHitFX = HitFX

local Spin = { Enabled = false, Speed = 1200, Axis = "Y" }
getgenv().SilentAimSpin = Spin

local InfiniteAmmo = { Enabled = false, MinAmmo = 999 }
getgenv().SilentAimInfiniteAmmo = InfiniteAmmo

local AMMO_KEYWORDS = { "ammo","clip","mag","bullet","round","shell","reserve","shot" }
local function isAmmoName(n)
    n = string.lower(tostring(n))
    for i = 1, #AMMO_KEYWORDS do
        if string.find(n, AMMO_KEYWORDS[i], 1, true) then return true end
    end
    return false
end

local GUI = { Scale = 1, Opacity = 0.8, Width = 210, Rainbow = false, RainbowSpeed = 0.35 }
getgenv().SilentAimGUI = GUI

local ESP = {
    Enabled = false, Boxes = true, Names = true, Skeleton = true,
    Color = Color3.fromRGB(255, 255, 255), TextColor = Color3.fromRGB(255, 255, 255),
}
getgenv().SilentAimESP = ESP

local Noclip = { Enabled = false, Bypass = true, Key = Enum.KeyCode.N }
getgenv().SilentAimNoclip = Noclip

--==== INSTANT KILL config ====--
local InstantKill = {
    Enabled = false,
    Targets = "All",     -- "All" or "NPCs"
    Range = 1000,        -- max raycast distance
    Damage = 999999,     -- lethal damage pushed through the game's damage remote
    Notify = true,       -- also fire the learned remote proactively on shot
    Hold = 0.4,          -- seconds to keep forcing health to 0
}
getgenv().SilentAimInstantKill = InstantKill

--==================== GUI PARENT ====================--
local GUI_PARENT
pcall(function() GUI_PARENT = gethui and gethui() or nil end)
GUI_PARENT = GUI_PARENT or LocalPlayer:WaitForChild("PlayerGui")

for _, guiName in ipairs({ "SilentAimUI", "SilentAimESP", "SilentAimFOV", "SilentAimToggle" }) do
    local old = GUI_PARENT:FindFirstChild(guiName)
    if old then pcall(function() old:Destroy() end) end
end

local Target, TargetPart, PartHighlight

--==================== RAINBOW REGISTRY ====================--
local rainbowItems = {}
local rainbowHue = 0
local function addRainbow(inst, prop, orig)
    table.insert(rainbowItems, { inst = inst, prop = prop, orig = orig })
end

--==================== HELPERS ====================--
local function fovRadiusPx()
    local vp = Camera.ViewportSize
    local m = math.min(vp.X, vp.Y)
    return (m * 0.5) * (Settings.FOV / 90)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function hasLineOfSight(char, part)
    if not Settings.VisibleCheck then return true end
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local result = Workspace:Raycast(origin, dir, rayParams)
    if not result then return true end
    return result.Instance:IsDescendantOf(char)
end

local function resolveAimPart(char, name)
    if not char then return nil end
    if name == "Head" then return char:FindFirstChild("Head") end
    if name == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    end
    return char:FindFirstChild(name)
end

local function isEnemy(plr)
    if not Settings.TeamCheck then return true end
    if plr.Team and plr.Team == LocalPlayer.Team then return false end
    return true
end

local function isKnocked(plr, char, hum)
    if not Settings.IgnoreKnocked then return false end
    for _, name in ipairs(Settings.KnockNames) do
        local attr = char:GetAttribute(name)
        if attr == true then return true end
        local inst = char:FindFirstChild(name)
        if inst then
            if inst:IsA("BoolValue") and inst.Value then return true end
            if inst:IsA("NumberValue") and inst.Value > 0 then return true end
        end
    end
    if hum.PlatformStand then return true end
    local ok, state = pcall(function() return hum:GetState() end)
    if ok and state == Enum.HumanoidStateType.Physics then return true end
    return false
end

local function isAlive(plr, char, hum)
    if not hum or hum.Health <= 0 then return false end
    local ok, state = pcall(function() return hum:GetState() end)
    if ok and state == Enum.HumanoidStateType.Dead then return false end
    if isKnocked(plr, char, hum) then return false end
    return true
end

local function aimPos()
    if not TargetPart or not TargetPart.Parent then return nil end
    local pos = TargetPart.Position
    if Settings.Predict and TargetPart:IsA("BasePart") then
        local dist = (pos - Camera.CFrame.Position).Magnitude
        local t = math.clamp(dist / Settings.ProjectileSpeed, 0, Settings.MaxLead)
        pos = pos + TargetPart.AssemblyLinearVelocity * t
    end
    return pos
end

local function findTarget()
    if not Settings.Enabled then Target, TargetPart = nil, nil; return end

    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local radius = fovRadiusPx()

    local best, bestScore, bestPart = nil, math.huge, nil

    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if plr ~= LocalPlayer and char and isEnemy(plr) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and isAlive(plr, char, hum) then
                local ap = resolveAimPart(char, Settings.AimPart)
                    or char:FindFirstChild("HumanoidRootPart")
                if ap then
                    local sp = Camera:WorldToViewportPoint(ap.Position)
                    if sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
                        if d <= radius and d < bestScore and hasLineOfSight(char, ap) then
                            best, bestScore, bestPart = plr, d, ap
                        end
                    end
                end
            end
        end
    end
    Target, TargetPart = best, bestPart
end

--==================== TARGET HIGHLIGHT ====================--
local function updateHighlight()
    local alive = Target and Target.Character
        and Target.Character:FindFirstChildOfClass("Humanoid")
        and Target.Character:FindFirstChildOfClass("Humanoid").Health > 0

    if not Settings.ShowTarget or not alive then
        if PartHighlight then PartHighlight.Adornee = nil end
        return
    end

    if not PartHighlight or not PartHighlight.Parent then
        PartHighlight = Instance.new("Highlight")
        PartHighlight.FillColor = Settings.HighlightColor
        PartHighlight.FillTransparency = 0.55
        PartHighlight.OutlineColor = Settings.HighlightColor
        PartHighlight.OutlineTransparency = 0
        PartHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        PartHighlight.Parent = GUI_PARENT
    end
    PartHighlight.Adornee = Target.Character
end

--==================== INSTANT KILL CORE ====================--
local ikRayParams = RaycastParams.new()
ikRayParams.FilterType = Enum.RaycastFilterType.Exclude
ikRayParams.IgnoreWater = true

local ikRemote, ikSig, ikBestScore = nil, nil, 0
local ikCaptureUntil = 0
local ikHolds = {}

-- pull a damage-number + optional target instance out of a remote call
local function ikClassify(args)
    local dmgIdx, dmgKind, targetIdx = nil, nil, nil
    for i = 1, args.n do
        local a = args[i]
        local t = type(a)
        if t == "number" then
            if a > 0 and a < 1e7 and not dmgIdx then dmgIdx, dmgKind = i, "number" end
        elseif t == "string" then
            local num = tonumber(a)
            if num and num > 0 and num < 1e7 and not dmgIdx then dmgIdx, dmgKind = i, "string" end
        elseif typeof(a) == "Instance" then
            if (a:IsA("Model") or a:IsA("Humanoid") or a:IsA("BasePart")) and not targetIdx then
                targetIdx = i
            end
        end
    end
    return dmgIdx, dmgKind, targetIdx
end

-- score how likely a remote is the damage remote
local function ikScoreRemote(name, dmgIdx, targetIdx)
    local n = string.lower(tostring(name))
    local score = 0
    for _, k in ipairs({ "damage","deal","hurt","hit","kill","attack","strike" }) do
        if string.find(n, k, 1, true) then score = score + 5 break end
    end
    if targetIdx then score = score + 3 end
    if dmgIdx then score = score + 1 end
    return score
end

-- name scan to seed a candidate if nothing has been learned yet
local function ikScanRemote()
    local best, bestScore = nil, 0
    local function scan(root)
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") then
                local n = string.lower(d.Name)
                local sc = 0
                if string.find(n, "damage", 1, true) or string.find(n, "deal", 1, true)
                or string.find(n, "hurt", 1, true) or string.find(n, "hit", 1, true)
                or string.find(n, "kill", 1, true) then sc = 5 end
                if sc > bestScore then best, bestScore = d, sc end
            end
        end
    end
    pcall(function() scan(game:GetService("ReplicatedStorage")) end)
    if best and (not ikRemote or ikBestScore < bestScore) then
        ikRemote, ikBestScore = best, bestScore
    end
end

-- fire the learned remote ourselves (used when we raycast a target)
local function ikFireProactive(model)
    if not ikRemote or not ikSig then return end
    local args = table.pack()
    args[ikSig.targetIdx or 1] = model
    args[ikSig.dmgIdx] = (ikSig.dmgKind == "string") and tostring(InstantKill.Damage) or InstantKill.Damage
    local n = math.max(ikSig.targetIdx or 1, ikSig.dmgIdx, 1)
    pcall(function() ikRemote:FireServer(table.unpack(args, 1, n)) end)
end

local function ikValidTarget(model)
    if not model or not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local plr = Players:GetPlayerFromCharacter(model)
    if plr then
        if Settings.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then return false end
        return InstantKill.Targets == "All"
    end
    return true   -- NPC / dummy
end

local function ikKill(model, doRemote)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if doRemote and InstantKill.Notify then ikFireProactive(model) end
    hum.Health = 0
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
    if InstantKill.Hold > 0 then ikHolds[model] = tick() + InstantKill.Hold end
end

local function ikAimRay()
    local origin = Camera.CFrame.Position
    local ap = aimPos()
    local dir
    if Settings.Enabled and ap then
        dir = (ap - origin)
    else
        dir = Camera.CFrame.LookVector
    end
    if dir.Magnitude < 0.001 then dir = Camera.CFrame.LookVector end
    return origin, dir.Unit
end

local lastIKShot = 0
local function ikOnShot()
    if not InstantKill.Enabled then return end
    local now = tick()
    if now - lastIKShot < 0.01 then return end
    lastIKShot = now
    ikCaptureUntil = now + 0.25     -- watch for the game's damage remote

    local char = LocalPlayer.Character
    if not char then return end
    ikRayParams.FilterDescendantsInstances = { char }

    local origin, dir = ikAimRay()
    local result = Workspace:Raycast(origin, dir * (InstantKill.Range or 1000), ikRayParams)

    local model
    if result then
        model = result.Instance:GetFirstAncestorOfClass("Model")
    end
    if not (model and ikValidTarget(model)) then
        if Target and Target.Character and ikValidTarget(Target.Character) then
            model = Target.Character
        end
    end
    if model and ikValidTarget(model) then
        ikKill(model, true)
    end
end

--==================== HOOKS ====================--
local nc = newcclosure or function(f) return f end
local oldIndex, oldNamecall, oldNewIndex
local installed = false

local function indexHook(self, key)
    if Settings.Enabled and Target and self == Mouse then
        local p = aimPos()
        if p then
            if key == "Hit" then return CFrame.new(p) end
            if key == "Target" then return TargetPart end
            if key == "UnitRay" then
                local o = Camera.CFrame.Position
                return Ray.new(o, (p - o).Unit * 1000)
            end
        end
    end
    return oldIndex(self, key)
end

local function namecallHook(self, ...)
    local method = getnamecallmethod and getnamecallmethod()

    if method == "Kick" and Settings.AntiKick and self == LocalPlayer then
        return nil
    end

    -- INSTANT KILL: learn + amplify the game's own outgoing damage remote
    if InstantKill.Enabled and method == "FireServer"
    and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
        local args = table.pack(...)
        local dmgIdx, dmgKind, targetIdx = ikClassify(args)
        if dmgIdx then
            if tick() <= ikCaptureUntil then
                local sc = ikScoreRemote(self.Name, dmgIdx, targetIdx)
                if sc > ikBestScore then
                    ikBestScore = sc
                    ikRemote = self
                    ikSig = { dmgIdx = dmgIdx, dmgKind = dmgKind, targetIdx = targetIdx, n = args.n }
                end
            end
            if self == ikRemote then
                if not ikSig then
                    ikSig = { dmgIdx = dmgIdx, dmgKind = dmgKind, targetIdx = targetIdx, n = args.n }
                end
                local cur = args[ikSig.dmgIdx]
                if type(cur) == "number" then
                    if cur < InstantKill.Damage then args[ikSig.dmgIdx] = InstantKill.Damage end
                elseif type(cur) == "string" then
                    if (tonumber(cur) or 0) < InstantKill.Damage then
                        args[ikSig.dmgIdx] = tostring(InstantKill.Damage)
                    end
                end
                return oldNamecall(self, table.unpack(args, 1, args.n))
            end
        end
    end

    if InfiniteAmmo.Enabled and method == "SetAttribute" then
        local attr, val = ...
        if type(val) == "number" and isAmmoName(attr) and val < InfiniteAmmo.MinAmmo then
            return oldNamecall(self, attr, InfiniteAmmo.MinAmmo)
        end
    end

    if Settings.Enabled and Target and self == Camera
    and (method == "ViewportPointToRay" or method == "ScreenPointToRay") then
        local p = aimPos()
        if p then
            local o = Camera.CFrame.Position
            return Ray.new(o, (p - o).Unit * 1000)
        end
    end

    return oldNamecall(self, ...)
end

pcall(function()
    oldIndex    = hookmetamethod(game, "__index", nc(indexHook))
    oldNamecall = hookmetamethod(game, "__namecall", nc(namecallHook))
    installed = true
end)

-- NOCLIP hard bypass: swallow any CanCollide=true on our parts while active
if Noclip.Bypass then
    pcall(function()
        oldNewIndex = hookmetamethod(game, "__newindex", nc(function(self, key, value)
            if Noclip.Enabled and key == "CanCollide" and value == true
            and typeof(self) == "Instance" and self:IsA("BasePart") then
                local char = LocalPlayer.Character
                if char and self:IsDescendantOf(char) then
                    return oldNewIndex(self, key, false)
                end
            end
            return oldNewIndex(self, key, value)
        end))
    end)
end

--==================== SPIN ====================--
local function applySpin(dt)
    if not Spin.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local axis
    if Spin.Axis == "X" then axis = Vector3.new(1, 0, 0)
    elseif Spin.Axis == "Z" then axis = Vector3.new(0, 0, 1)
    else axis = Vector3.new(0, 1, 0) end
    local ang = math.rad(Spin.Speed * dt)
    root.CFrame = root.CFrame * CFrame.fromAxisAngle(axis, ang)
end

--==================== INFINITE AMMO ====================--
local watchedAmmo = setmetatable({}, { __mode = "k" })

local function watchAmmo(inst)
    if watchedAmmo[inst] then return end
    watchedAmmo[inst] = true
    inst:GetPropertyChangedSignal("Value"):Connect(function()
        if not InfiniteAmmo.Enabled then return end
        local v = inst.Value
        if type(v) == "number" then
            if v < InfiniteAmmo.MinAmmo then inst.Value = InfiniteAmmo.MinAmmo end
        elseif type(v) == "string" then
            local n = tonumber(v)
            if n and n < InfiniteAmmo.MinAmmo then
                inst.Value = tostring(InfiniteAmmo.MinAmmo)
            end
        end
    end)
end

local lastAmmoScan = 0
local function fillAmmo()
    if not InfiniteAmmo.Enabled then return end
    local now = tick()
    if now - lastAmmoScan < 0.1 then return end
    lastAmmoScan = now

    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    local containers = {
        char,
        tool,
        LocalPlayer:FindFirstChildOfClass("Backpack"),
        LocalPlayer,
    }

    local function process(d)
        if d:IsA("NumberValue") or d:IsA("IntValue") then
            if isAmmoName(d.Name) then
                watchAmmo(d)
                if d.Value < InfiniteAmmo.MinAmmo then d.Value = InfiniteAmmo.MinAmmo end
            end
        elseif d:IsA("StringValue") then
            if isAmmoName(d.Name) then
                watchAmmo(d)
                local n = tonumber(d.Value)
                if n and n < InfiniteAmmo.MinAmmo then
                    d.Value = tostring(InfiniteAmmo.MinAmmo)
                end
            end
        end
        for _, a in ipairs(d:GetAttributes()) do
            if isAmmoName(a) then
                local v = d:GetAttribute(a)
                if type(v) == "number" and v < InfiniteAmmo.MinAmmo then
                    d:SetAttribute(a, InfiniteAmmo.MinAmmo)
                end
            end
        end
    end

    for _, cont in ipairs(containers) do
        if cont then
            process(cont)
            for _, d in ipairs(cont:GetDescendants()) do process(d) end
        end
    end
end

local function bindAmmoTool(ch)
    if ch:IsA("Tool") then
        task.wait(0.05)
        fillAmmo()
    end
end
local function bindAmmoChar(char)
    char.ChildAdded:Connect(bindAmmoTool)
    for _, ch in ipairs(char:GetChildren()) do bindAmmoTool(ch) end
end
if LocalPlayer.Character then bindAmmoChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(bindAmmoChar)

--==================== WALKSPEED ====================--
local baseWalk = 16

local function captureBaseWalk()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then baseWalk = hum.WalkSpeed end
end

captureBaseWalk()
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid")
    task.wait()
    baseWalk = hum.WalkSpeed
end)

local function applyWalkspeed()
    if not Settings.WalkspeedEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed ~= Settings.Walkspeed then
        hum.WalkSpeed = Settings.Walkspeed
    end
end

--==================== NOCLIP ====================--
local function restoreCollide()
    local char = LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = true end
    end
end

local preSim = RunService.PreSimulation or RunService.Stepped
preSim:Connect(function()
    if not Noclip.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
    end
end)

--==================== ESP ====================--
local espGui = Instance.new("ScreenGui")
espGui.Name = "SilentAimESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 900
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.Parent = GUI_PARENT

local R15_BONES = {
    {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
    {"Torso","Left Leg"}, {"Torso","Right Leg"},
}

local function project(pos)
    local sp = Camera:WorldToViewportPoint(pos)
    if sp.Z <= 0 then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function screenBounds(char)
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local any = false
    for _, p in ipairs(char:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            local cf, sz = p.CFrame, p.Size
            for ix = -0.5, 0.5, 1 do
                for iy = -0.5, 0.5, 1 do
                    for iz = -0.5, 0.5, 1 do
                        local world = (cf * CFrame.new(ix * sz.X, iy * sz.Y, iz * sz.Z)).Position
                        local sp = Camera:WorldToViewportPoint(world)
                        if sp.Z > 0 then
                            any = true
                            minX = math.min(minX, sp.X); maxX = math.max(maxX, sp.X)
                            minY = math.min(minY, sp.Y); maxY = math.max(maxY, sp.Y)
                        end
                    end
                end
            end
        end
    end
    if not any then return nil end
    return Vector2.new(minX, minY), Vector2.new(maxX, maxY)
end

local function newBox()
    local f = Instance.new("Frame")
    f.BackgroundTransparency = 1; f.BorderSizePixel = 0; f.Visible = false; f.ZIndex = 2
    local s = Instance.new("UIStroke")
    s.Color = ESP.Color; s.Thickness = 1; s.Transparency = 0; s.Parent = f
    f.Parent = espGui
    return { frame = f, stroke = s }
end

local function newName()
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBold; t.TextSize = 14
    t.TextColor3 = ESP.TextColor; t.TextStrokeTransparency = 0
    t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    t.AnchorPoint = Vector2.new(0.5, 1); t.Visible = false; t.ZIndex = 3
    t.Parent = espGui
    return t
end

local function getLine(d, i)
    local l = d.lines[i]
    if not l then
        l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(0.5, 0.5); l.BackgroundColor3 = ESP.Color
        l.BorderSizePixel = 0; l.Visible = false; l.ZIndex = 1; l.Parent = espGui
        d.lines[i] = l
    end
    return l
end

local function setLine(frame, a, b)
    local delta = b - a
    local len = delta.Magnitude
    if len < 1 then frame.Visible = false; return end
    frame.Visible = true
    frame.Position = UDim2.new(0, (a.X + b.X) / 2, 0, (a.Y + b.Y) / 2)
    frame.Size = UDim2.new(0, len, 0, 1)
    frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
end

local espData = {}

local function updateBones(d, char)
    local bones = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
    for i, bone in ipairs(bones) do
        local line = getLine(d, i)
        local a = char:FindFirstChild(bone[1])
        local b = char:FindFirstChild(bone[2])
        local pa = a and a:IsA("BasePart") and project(a.Position)
        local pb = b and b:IsA("BasePart") and project(b.Position)
        if pa and pb then setLine(line, pa, pb) else line.Visible = false end
    end
    for i = #bones + 1, #d.lines do d.lines[i].Visible = false end
end

local function hideData(d)
    if d.box then d.box.frame.Visible = false end
    if d.name then d.name.Visible = false end
    for _, l in ipairs(d.lines) do l.Visible = false end
end

local function updateESP()
    for plr, d in pairs(espData) do
        if not plr.Parent or not plr.Character then
            if d.box then d.box.frame:Destroy() end
            if d.name then d.name:Destroy() end
            for _, l in ipairs(d.lines) do l:Destroy() end
            espData[plr] = nil
        end
    end

    if not ESP.Enabled then
        for _, d in pairs(espData) do hideData(d) end
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 then
                local d = espData[plr]
                if not d then
                    d = { box = newBox(), name = newName(), lines = {} }
                    espData[plr] = d
                end

                local tl, br = screenBounds(char)

                if ESP.Boxes and tl then
                    d.box.frame.Visible = true
                    d.box.frame.Position = UDim2.new(0, tl.X, 0, tl.Y)
                    d.box.frame.Size = UDim2.new(0, br.X - tl.X, 0, br.Y - tl.Y)
                    d.box.stroke.Color = ESP.Color
                else
                    d.box.frame.Visible = false
                end

                if ESP.Names and tl then
                    d.name.Visible = true
                    d.name.Text = plr.Name
                    d.name.TextColor3 = ESP.TextColor
                    d.name.Position = UDim2.new(0, (tl.X + br.X) / 2, 0, tl.Y - 2)
                else
                    d.name.Visible = false
                end

                if ESP.Skeleton then updateBones(d, char)
                else for _, l in ipairs(d.lines) do l.Visible = false end end
            else
                local d = espData[plr]
                if d then hideData(d) end
            end
        end
    end
end

--==================== FOV RING ====================--
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "SilentAimFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = false
fovGui.DisplayOrder = 999
fovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fovGui.Parent = GUI_PARENT

local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fovCircle.BackgroundTransparency = 0.93
fovCircle.BorderSizePixel = 0
fovCircle.ZIndex = 2
fovCircle.Parent = fovGui
local fcCorner = Instance.new("UICorner") fcCorner.CornerRadius = UDim.new(1, 0) fcCorner.Parent = fovCircle

local fcStroke = Instance.new("UIStroke")
fcStroke.Color = Settings.RingColor
fcStroke.Thickness = 2
fcStroke.Transparency = 0.2
fcStroke.Parent = fovCircle

local centerDot = Instance.new("Frame")
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
centerDot.Size = UDim2.new(0, 3, 0, 3)
centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
centerDot.BorderSizePixel = 0
centerDot.ZIndex = 3
centerDot.Parent = fovGui
local cdCorner = Instance.new("UICorner") cdCorner.CornerRadius = UDim.new(1, 0) cdCorner.Parent = centerDot

addRainbow(centerDot, "BackgroundColor3", Color3.fromRGB(255, 255, 255))

local function updateFOVRing()
    local r = fovRadiusPx()
    fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)

    local t = math.clamp((Settings.FOV - MINFOV) / (MAXFOV - MINFOV), 0, 1)
    fcStroke.Transparency = 0.35 - 0.2 * t
    fcStroke.Thickness = 2 + 2 * t
    fcStroke.Color = Settings.RingColor
    fovCircle.BackgroundTransparency = 0.95 - 0.05 * t

    if not Settings.Enabled then
        fcStroke.Transparency = math.min(1, fcStroke.Transparency + 0.15)
        centerDot.BackgroundTransparency = 0.4
    else
        centerDot.BackgroundTransparency = 0
    end

    if Target then
        fcStroke.Transparency = 0.05
        fcStroke.Thickness = fcStroke.Thickness + 1.5
    end
end

--==================== FX HELPERS ====================--
local function makeFlash(origin, color, range, brightness, life)
    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false; part.CanQuery = false
    part.Transparency = 1; part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(origin); part.Parent = Workspace
    local light = Instance.new("PointLight")
    light.Color = color; light.Range = range; light.Brightness = brightness
    light.Parent = part
    task.spawn(function()
        for i = 1, 10 do
            light.Brightness = brightness * (1 - i / 10)
            task.wait(life / 10)
        end
        part:Destroy()
    end)
end

local function makeSplatter(origin, color, count, speed, size)
    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false; part.CanQuery = false
    part.Transparency = 1; part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(origin); part.Parent = Workspace
    local pe = Instance.new("ParticleEmitter")
    pe.Color = ColorSequence.new(color)
    pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    pe.Lifetime = NumberRange.new(0.3, 0.7)
    pe.Rate = 0
    pe.Speed = NumberRange.new(speed * 0.5, speed)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new(size)
    pe.Transparency = NumberSequence.new(0)
    pe.Rotation = NumberRange.new(0, 360)
    pe.RotSpeed = NumberRange.new(-250, 250)
    pe.Parent = part
    pe:Emit(count)
    Debris:AddItem(part, 2)
end

local function makeBolt(origin, color, jitter, segs)
    local topY = origin.Y + 40
    local prev = Vector3.new(origin.X, topY, origin.Z)
    local parts = {}
    for i = 1, segs do
        local t = i / segs
        local nxt = (i == segs) and origin
            or Vector3.new(origin.X + math.random(-jitter, jitter),
                           topY - (topY - origin.Y) * t,
                           origin.Z + math.random(-jitter, jitter))
        local len = (nxt - prev).Magnitude
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.CanQuery = false
        p.CastShadow = false; p.Material = Enum.Material.Neon; p.Color = color
        p.Size = Vector3.new(0.2, 0.2, len)
        p.CFrame = CFrame.lookAt((prev + nxt) / 2, nxt)
        p.Parent = Workspace
        table.insert(parts, p)
        prev = nxt
    end
    task.spawn(function()
        for i = 1, 12 do
            local a = 1 - i / 12
            for _, p in ipairs(parts) do p.Transparency = 1 - a end
            task.wait(0.03)
        end
        for _, p in ipairs(parts) do p:Destroy() end
    end)
end

local function makeShockwave(origin, color, maxSize, life)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Ball
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Transparency = 0.25; p.Size = Vector3.new(1, 1, 1)
    p.CFrame = CFrame.new(origin); p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(maxSize, maxSize, maxSize), Transparency = 1,
    }):Play()
    Debris:AddItem(p, life + 0.1)
end

local function makeGroundRing(origin, color, maxSize, life)
    local p = Instance.new("Part")
    p.Shape = Enum.PartType.Cylinder
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Transparency = 0.2; p.Size = Vector3.new(0.3, 1, 1)
    p.CFrame = CFrame.new(Vector3.new(origin.X, origin.Y - 2.5, origin.Z)) * CFrame.Angles(0, 0, math.rad(90))
    p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.3, maxSize, maxSize), Transparency = 1,
    }):Play()
    Debris:AddItem(p, life + 0.1)
end

local function slash(origin, color, angle, length, life)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Size = Vector3.new(length, 0.35, 0.35)
    local cam = Camera.CFrame
    p.CFrame = CFrame.new(origin) * (cam - cam.Position) * CFrame.Angles(0, 0, math.rad(angle))
    p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1, Size = Vector3.new(length * 1.35, 0.06, 0.06),
    }):Play()
    Debris:AddItem(p, life + 0.1)
end

local function rift(origin, color, height, life)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CastShadow = false
    p.Material = Enum.Material.Neon; p.Color = color
    p.Size = Vector3.new(0.2, height, 0.2)
    local cam = Camera.CFrame
    p.CFrame = CFrame.new(origin) * (cam - cam.Position)
    p.Parent = Workspace
    TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Transparency = 1, Size = Vector3.new(height * 0.7, height, 0.05),
    }):Play()
    Debris:AddItem(p, life + 0.1)
end

local function shards(origin, color, count, speed, life)
    for _ = 1, count do
        local p = Instance.new("Part")
        p.Size = Vector3.new(0.35, 0.35, 0.35)
        p.Material = Enum.Material.Neon; p.Color = color
        p.CanCollide = false; p.CanQuery = false
        p.CFrame = CFrame.new(origin)
        p.AssemblyLinearVelocity = Vector3.new(
            math.random(-speed, speed), math.random(0, speed), math.random(-speed, speed))
        p.Parent = Workspace
        Debris:AddItem(p, life)
    end
end

--==================== HIT SOUNDS ====================--
local SOUNDS = {
    { name = "Random" },
    { name = "Anime Slash",           id = "rbxassetid://8430383062" },
    { name = "Gojo Blue Slash",       id = "rbxassetid://411286671" },
    { name = "Sukuna Cleave",         id = "rbxassetid://125288142627715" },
    { name = "Sukuna Dismantle",      id = "rbxassetid://74232847084175" },
    { name = "Vergil Yamato Slash",   id = "rbxassetid://86506412325620" },
    { name = "Metal Sword Slash",     id = "rbxassetid://140553108821312" },
    { name = "Fast Katana Whoosh",    id = "rbxassetid://137122553198327" },
    { name = "Heavy Blade Impact",    id = "rbxassetid://9123334926" },
    { name = "Double Slash",          id = "rbxassetid://7117771309" },
    { name = "Triple Slash",          id = "rbxassetid://7150453268" },
    { name = "Critical Slash",        id = "rbxassetid://8255306220" },
    { name = "Blood Slash",           id = "rbxassetid://3739364168" },
    { name = "Air Blade Cut",         id = "rbxassetid://119142203253321" },
    { name = "Sharp Anime Cut",       id = "rbxassetid://122209095269858" },
    { name = "Black Flash Impact",    id = "rbxassetid://13792648554" },
    { name = "Wind Slash",            id = "rbxassetid://6006851551" },
    { name = "Void Slash",            id = "rbxassetid://14092824501" },
    { name = "Lightning Blade",       id = "rbxassetid://102930929366058" },
    { name = "Phantom Slash",         id = "rbxassetid://126598851794168" },
    { name = "Ultra-Quiet Katana Hit",id = "rbxassetid://132547948177910", vol = 0.45 },
}

local lastSound = 0
local function playHitSound()
    local idx = HitFX.SoundSel
    if idx <= 1 or not SOUNDS[idx] then
        idx = math.random(2, #SOUNDS)
        if #SOUNDS > 2 and idx == lastSound then idx = (idx % (#SOUNDS - 1)) + 2 end
    end
    lastSound = idx
    local entry = SOUNDS[idx]
    local s = Instance.new("Sound")
    s.SoundId = entry.id
    s.Volume = HitFX.Volume * (entry.vol or 1)
    s.PlaybackSpeed = 1 + math.random() * 0.14 - 0.07
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 3)
end

--==================== HIT EFFECTS ====================--
local EFFECTS = {
    { name = "Random" },
    { name = "Crimson Slash", fn = function(o)
        slash(o, Color3.fromRGB(255, 40, 40), 45, 9, 0.35)
        makeSplatter(o, Color3.fromRGB(255, 200, 60), 22, 26, 0.4)
        makeFlash(o, Color3.fromRGB(255, 50, 50), 16, 6, 0.25)
    end },
    { name = "Azure Crescent", fn = function(o)
        slash(o, Color3.fromRGB(80, 180, 255), 35, 9, 0.35)
        slash(o, Color3.fromRGB(120, 200, 255), 45, 10, 0.4)
        slash(o, Color3.fromRGB(60, 150, 255), 55, 9, 0.35)
    end },
    { name = "Void Cut", fn = function(o)
        rift(o, Color3.fromRGB(120, 40, 200), 12, 0.5)
        makeSplatter(o, Color3.fromRGB(150, 60, 255), 20, 20, 0.5)
    end },
    { name = "Black Flash", fn = function(o)
        makeShockwave(o, Color3.fromRGB(20, 20, 25), 12, 0.4)
        makeBolt(o, Color3.fromRGB(160, 60, 255), 4, 6)
        makeFlash(o, Color3.fromRGB(180, 80, 255), 26, 9, 0.3)
    end },
    { name = "Golden Breaker", fn = function(o)
        for i = 1, 8 do
            slash(o, Color3.fromRGB(255, 220, 80), (i / 8) * 180, 9, 0.4)
        end
        makeSplatter(o, Color3.fromRGB(255, 235, 130), 30, 30, 0.45)
    end },
    { name = "Double Cross", fn = function(o)
        slash(o, Color3.fromRGB(255, 255, 255), 45, 10, 0.4)
        slash(o, Color3.fromRGB(255, 255, 255), -45, 10, 0.4)
    end },
    { name = "Triple Rend", fn = function(o)
        slash(o, Color3.fromRGB(255, 255, 255), 50, 9, 0.3)
        task.delay(0.05, function() slash(o, Color3.fromRGB(255, 255, 255), -50, 9, 0.3) end)
        task.delay(0.10, function() slash(o, Color3.fromRGB(255, 255, 255), 90, 9, 0.3) end)
    end },
    { name = "Lightning Split", fn = function(o)
        makeBolt(o, Color3.fromRGB(255, 240, 90), 6, 7)
        makeFlash(o, Color3.fromRGB(255, 245, 140), 24, 8, 0.3)
    end },
    { name = "Blood Moon", fn = function(o)
        makeGroundRing(o, Color3.fromRGB(200, 20, 40), 18, 0.6)
        makeShockwave(o, Color3.fromRGB(220, 30, 50), 10, 0.5)
    end },
    { name = "Wind Cutter", fn = function(o)
        slash(o, Color3.fromRGB(240, 250, 255), 30, 10, 0.4)
        slash(o, Color3.fromRGB(240, 250, 255), -30, 10, 0.4)
        slash(o, Color3.fromRGB(240, 250, 255), 0, 10, 0.4)
    end },
    { name = "Phantom Shatter", fn = function(o)
        shards(o, Color3.fromRGB(180, 220, 255), 16, 22, 0.8)
        makeFlash(o, Color3.fromRGB(200, 230, 255), 14, 5, 0.25)
    end },
    { name = "Dragon Claw", fn = function(o)
        slash(o, Color3.fromRGB(255, 120, 30), 60, 8, 0.35)
        slash(o, Color3.fromRGB(255, 150, 40), 40, 8, 0.35)
        slash(o, Color3.fromRGB(255, 90, 20), 20, 8, 0.35)
        makeSplatter(o, Color3.fromRGB(255, 140, 40), 24, 22, 0.5)
    end },
    { name = "Ice Break", fn = function(o)
        slash(o, Color3.fromRGB(170, 220, 255), 55, 9, 0.4)
        slash(o, Color3.fromRGB(200, 235, 255), -35, 9, 0.4)
        shards(o, Color3.fromRGB(190, 230, 255), 12, 18, 0.7)
    end },
    { name = "Flame Burst", fn = function(o)
        makeFlash(o, Color3.fromRGB(255, 120, 40), 22, 8, 0.3)
        makeSplatter(o, Color3.fromRGB(255, 120, 40), 30, 26, 0.6)
        makeSplatter(o, Color3.fromRGB(255, 220, 90), 16, 22, 0.45)
    end },
    { name = "Shadow Explosion", fn = function(o)
        makeShockwave(o, Color3.fromRGB(15, 10, 25), 14, 0.45)
        makeShockwave(o, Color3.fromRGB(140, 60, 220), 18, 0.55)
    end },
    { name = "Pixel Glitch", fn = function(o)
        for _ = 1, 14 do
            local p = Instance.new("Part")
            p.Size = Vector3.new(0.5, 0.5, 0.5)
            p.Material = Enum.Material.Neon
            p.Color = Color3.fromRGB(math.random(80, 255), math.random(80, 255), math.random(80, 255))
            p.CanCollide = false; p.CanQuery = false
            p.CFrame = CFrame.new(o)
            p.AssemblyLinearVelocity = Vector3.new(
                math.random(-16, 16), math.random(-4, 16), math.random(-16, 16))
            p.Parent = Workspace
            Debris:AddItem(p, 0.7)
        end
    end },
    { name = "Sonic Cut", fn = function(o)
        makeShockwave(o, Color3.fromRGB(255, 255, 255), 26, 0.35)
        slash(o, Color3.fromRGB(255, 255, 255), 0, 11, 0.25)
    end },
    { name = "Spirit Strike", fn = function(o)
        makeShockwave(o, Color3.fromRGB(90, 240, 240), 12, 0.45)
        makeSplatter(o, Color3.fromRGB(140, 255, 255), 30, 22, 0.5)
    end },
    { name = "Dimension Split", fn = function(o)
        rift(o, Color3.fromRGB(200, 220, 255), 14, 0.6)
        makeSplatter(o, Color3.fromRGB(180, 210, 255), 18, 18, 0.4)
    end },
    { name = "Heavenly Impact", fn = function(o)
        makeFlash(o, Color3.fromRGB(255, 245, 200), 30, 9, 0.35)
        for i = 1, 12 do
            slash(o, Color3.fromRGB(255, 250, 220), (i / 12) * 180, 11, 0.4)
        end
    end },
}

local lastEffect = 0
local function playHitEffect(o)
    local idx = HitFX.EffectSel
    if idx <= 1 or not EFFECTS[idx] then
        idx = math.random(2, #EFFECTS)
        if #EFFECTS > 2 and idx == lastEffect then idx = (idx % (#EFFECTS - 1)) + 2 end
    end
    lastEffect = idx
    local ok = pcall(EFFECTS[idx].fn, o)
    if not ok then EFFECTS[2].fn(o) end
end

local function doHitFX(origin)
    if HitFX.Sound then playHitSound() end
    if HitFX.Effect then playHitEffect(origin) end
end

--==================== SHOT TRIGGERS (instakill) ====================--
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        ikOnShot()
    end
end)

local function bindIKTool(tool)
    if tool:IsA("Tool") then
        tool.Activated:Connect(function() ikOnShot() end)
    end
end
local function bindIKChar(char)
    char.ChildAdded:Connect(function(ch) if ch:IsA("Tool") then bindIKTool(ch) end end)
    for _, ch in ipairs(char:GetChildren()) do if ch:IsA("Tool") then bindIKTool(ch) end end
end
if LocalPlayer.Character then bindIKChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(bindIKChar)

-- hold loop: keep forcing health to 0 briefly so a server revert can't revive
RunService.Heartbeat:Connect(function()
    for model, expiry in pairs(ikHolds) do
        if not model.Parent or tick() > expiry then
            ikHolds[model] = nil
        else
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then hum.Health = 0 end
        end
    end
end)

--==================== SHOOT INPUT ====================--
local lastFire = 0
local function markFire() lastFire = tick() end

local function tryActivate()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
        markFire()
    end
end

Mouse.Button1Down:Connect(function() markFire(); tryActivate() end)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        markFire(); tryActivate()
    end
end)

--==================== SINGLE HEARTBEAT ====================--
local lastHP, lastFX = {}, {}
RunService.Heartbeat:Connect(function()
    fillAmmo()

    if HitFX.Enabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local prev = lastHP[hum]
                    if prev and hum.Health < prev and prev > 0 then
                        local cd = tick() - (lastFX[plr] or 0)
                        if isEnemy(plr) and (tick() - lastFire) <= HitFX.Window and cd >= HitFX.Cooldown then
                            lastFX[plr] = tick()
                            local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                            if root then doHitFX(root.Position) end
                        end
                    end
                    lastHP[hum] = hum.Health
                end
            end
        end
    end
end)

--==================== MOBILE UI ====================--
local AIM_CYCLE = { "Head", "Torso" }

local gui = Instance.new("ScreenGui")
gui.Name = "SilentAimUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = GUI_PARENT

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, GUI.Width, 0, 900)
panel.Position = UDim2.new(0, 20, 0, 40)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
panel.BackgroundTransparency = 1 - GUI.Opacity
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
local pCorner = Instance.new("UICorner") pCorner.CornerRadius = UDim.new(0, 10) pCorner.Parent = panel

local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(255, 255, 255)
pStroke.Thickness = 1
pStroke.Transparency = 0.6
pStroke.Parent = panel
addRainbow(pStroke, "Color", Color3.fromRGB(255, 255, 255))

local panelScale = Instance.new("UIScale")
panelScale.Parent = panel

local function fitPanel()
    local vp = Camera.ViewportSize
    local baseW = GUI.Width
    local s = math.min(1, (vp.Y - 70) / 900, (vp.X - 40) / baseW)
    panelScale.Scale = math.clamp(s, 0.4, 1.5) * GUI.Scale
    panel.Size = UDim2.new(0, baseW, 0, 900)
    panel.BackgroundTransparency = 1 - GUI.Opacity
end
fitPanel()
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -70, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Silent Aim v32.0"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 10, 0, 0)
title.Active = true
title.Parent = panel
addRainbow(title, "TextColor3", Color3.fromRGB(255, 255, 255))

local function makeDraggableHandle(handle, target)
    local dragging, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                        startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local dragHandle = Instance.new("TextButton")
dragHandle.Name = "DragHandle"
dragHandle.Size = UDim2.new(0, 56, 0, 24)
dragHandle.Position = UDim2.new(1, -62, 0, 2)
dragHandle.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
dragHandle.BackgroundTransparency = 0.1
dragHandle.Text = "⠿ MOVE"
dragHandle.TextSize = 12
dragHandle.Font = Enum.Font.GothamBold
dragHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
dragHandle.AutoButtonColor = true
dragHandle.Parent = panel
local dhCorner = Instance.new("UICorner") dhCorner.CornerRadius = UDim.new(0, 8) dhCorner.Parent = dragHandle
local dhStroke = Instance.new("UIStroke")
dhStroke.Color = Color3.fromRGB(255, 255, 255)
dhStroke.Thickness = 1
dhStroke.Transparency = 0.5
dhStroke.Parent = dragHandle
makeDraggableHandle(dragHandle, panel)
makeDraggableHandle(title, panel)

local function styleToggle(btn, on)
    if on then
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextColor3 = Color3.fromRGB(20, 20, 20)
    else
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local silentBtn = Instance.new("TextButton")
silentBtn.Size = UDim2.new(1, -20, 0, 34)
silentBtn.Position = UDim2.new(0, 10, 0, 30)
silentBtn.Font = Enum.Font.GothamBold
silentBtn.TextSize = 15
silentBtn.Text = "Silent Aim: " .. (Settings.Enabled and "ON" or "OFF")
silentBtn.Parent = panel
local sCorner = Instance.new("UICorner") sCorner.CornerRadius = UDim.new(0, 8) sCorner.Parent = silentBtn
styleToggle(silentBtn, Settings.Enabled)
silentBtn.MouseButton1Click:Connect(function()
    Settings.Enabled = not Settings.Enabled
    silentBtn.Text = "Silent Aim: " .. (Settings.Enabled and "ON" or "OFF")
    styleToggle(silentBtn, Settings.Enabled)
    if not Settings.Enabled then Target, TargetPart = nil, nil end
end)

local aimBtn = Instance.new("TextButton")
aimBtn.Size = UDim2.new(1, -20, 0, 32)
aimBtn.Position = UDim2.new(0, 10, 0, 68)
aimBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
aimBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
aimBtn.Font = Enum.Font.GothamBold
aimBtn.TextSize = 15
aimBtn.Text = "Aim Part: " .. Settings.AimPart
aimBtn.Parent = panel
local aCorner = Instance.new("UICorner") aCorner.CornerRadius = UDim.new(0, 8) aCorner.Parent = aimBtn

local aimIndex = 1
for i, v in ipairs(AIM_CYCLE) do if v == Settings.AimPart then aimIndex = i end end
aimBtn.MouseButton1Click:Connect(function()
    aimIndex = (aimIndex % #AIM_CYCLE) + 1
    Settings.AimPart = AIM_CYCLE[aimIndex]
    aimBtn.Text = "Aim Part: " .. Settings.AimPart
    Target, TargetPart = nil, nil
end)

local function makeSlider(parent, y, label, minV, maxV, initV, onChanged, decimals)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -20, 0, 40)
    holder.Position = UDim2.new(0, 10, 0, y)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = holder

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 26)
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    track.BackgroundTransparency = 0.5
    track.BorderSizePixel = 0
    track.Active = true
    track.Parent = holder
    local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(1, 0) tc.Parent = track

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(1, 0) fc.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob

    local function render(val)
        local shown = val
        if decimals and decimals > 0 then
            shown = string.format("%." .. decimals .. "f", val)
        end
        lbl.Text = label .. ": " .. shown
        local rel = (val - minV) / (maxV - minV)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
    end

    local dragging = false
    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local raw = minV + rel * (maxV - minV)
        local val = (decimals and decimals > 0) and raw or math.floor(raw + 0.5)
        render(val)
        onChanged(val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    track.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)

    render(initV)
    return render
end

makeSlider(panel, 104, "FOV", MINFOV, MAXFOV, Settings.FOV, function(v) Settings.FOV = v end)
makeSlider(panel, 144, "Walkspeed", 1, 50, Settings.Walkspeed, function(v) Settings.Walkspeed = v end)

local wsBtn = Instance.new("TextButton")
wsBtn.Size = UDim2.new(1, -20, 0, 26)
wsBtn.Position = UDim2.new(0, 10, 0, 186)
wsBtn.Font = Enum.Font.GothamBold
wsBtn.TextSize = 13
wsBtn.Text = "Walkspeed: " .. (Settings.WalkspeedEnabled and "ON" or "OFF")
wsBtn.Parent = panel
local wCorner = Instance.new("UICorner") wCorner.CornerRadius = UDim.new(0, 8) wCorner.Parent = wsBtn
styleToggle(wsBtn, Settings.WalkspeedEnabled)
wsBtn.MouseButton1Click:Connect(function()
    Settings.WalkspeedEnabled = not Settings.WalkspeedEnabled
    wsBtn.Text = "Walkspeed: " .. (Settings.WalkspeedEnabled and "ON" or "OFF")
    styleToggle(wsBtn, Settings.WalkspeedEnabled)
    if not Settings.WalkspeedEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = baseWalk end
    end
end)

local antiKickBtn = Instance.new("TextButton")
antiKickBtn.Size = UDim2.new(1, -20, 0, 26)
antiKickBtn.Position = UDim2.new(0, 10, 0, 216)
antiKickBtn.Font = Enum.Font.GothamBold
antiKickBtn.TextSize = 13
antiKickBtn.Text = "Anti-Kick: " .. (Settings.AntiKick and "ON" or "OFF")
antiKickBtn.Parent = panel
local akCorner = Instance.new("UICorner") akCorner.CornerRadius = UDim.new(0, 8) akCorner.Parent = antiKickBtn
styleToggle(antiKickBtn, Settings.AntiKick)
antiKickBtn.MouseButton1Click:Connect(function()
    Settings.AntiKick = not Settings.AntiKick
    antiKickBtn.Text = "Anti-Kick: " .. (Settings.AntiKick and "ON" or "OFF")
    styleToggle(antiKickBtn, Settings.AntiKick)
end)

local visBtn = Instance.new("TextButton")
visBtn.Size = UDim2.new(1, -20, 0, 26)
visBtn.Position = UDim2.new(0, 10, 0, 246)
visBtn.Font = Enum.Font.GothamBold
visBtn.TextSize = 13
visBtn.Text = "Visible Only: " .. (Settings.VisibleCheck and "ON" or "OFF")
visBtn.Parent = panel
local vCorner = Instance.new("UICorner") vCorner.CornerRadius = UDim.new(0, 8) vCorner.Parent = visBtn
styleToggle(visBtn, Settings.VisibleCheck)
visBtn.MouseButton1Click:Connect(function()
    Settings.VisibleCheck = not Settings.VisibleCheck
    visBtn.Text = "Visible Only: " .. (Settings.VisibleCheck and "ON" or "OFF")
    styleToggle(visBtn, Settings.VisibleCheck)
end)

local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(1, -20, 0, 26)
espBtn.Position = UDim2.new(0, 10, 0, 276)
espBtn.Font = Enum.Font.GothamBold
espBtn.TextSize = 13
espBtn.Text = "ESP: " .. (ESP.Enabled and "ON" or "OFF")
espBtn.Parent = panel
local espCorner = Instance.new("UICorner") espCorner.CornerRadius = UDim.new(0, 8) espCorner.Parent = espBtn
styleToggle(espBtn, ESP.Enabled)
espBtn.MouseButton1Click:Connect(function()
    ESP.Enabled = not ESP.Enabled
    espBtn.Text = "ESP: " .. (ESP.Enabled and "ON" or "OFF")
    styleToggle(espBtn, ESP.Enabled)
end)

local espStyleBtn = Instance.new("TextButton")
espStyleBtn.Size = UDim2.new(1, -20, 0, 24)
espStyleBtn.Position = UDim2.new(0, 10, 0, 306)
espStyleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
espStyleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
espStyleBtn.Font = Enum.Font.Gotham
espStyleBtn.TextSize = 12
espStyleBtn.Text = "ESP Style: Box+Name+Skeleton"
espStyleBtn.Parent = panel
local esCorner = Instance.new("UICorner") esCorner.CornerRadius = UDim.new(0, 8) esCorner.Parent = espStyleBtn

local STYLES = {
    { boxes = true,  names = true,  skeleton = true,  label = "Box+Name+Skeleton" },
    { boxes = true,  names = true,  skeleton = false, label = "Box+Name" },
    { boxes = true,  names = false, skeleton = false, label = "Box Only" },
    { boxes = false, names = true,  skeleton = true,  label = "Name+Skeleton" },
    { boxes = false, names = false, skeleton = true,  label = "Skeleton Only" },
}
local styleIndex = 1
espStyleBtn.MouseButton1Click:Connect(function()
    styleIndex = (styleIndex % #STYLES) + 1
    local s = STYLES[styleIndex]
    ESP.Boxes, ESP.Names, ESP.Skeleton = s.boxes, s.names, s.skeleton
    espStyleBtn.Text = "ESP Style: " .. s.label
end)

local hitFxBtn = Instance.new("TextButton")
hitFxBtn.Size = UDim2.new(1, -20, 0, 24)
hitFxBtn.Position = UDim2.new(0, 10, 0, 334)
hitFxBtn.Font = Enum.Font.GothamBold
hitFxBtn.TextSize = 12
hitFxBtn.Text = "Hit FX: " .. (HitFX.Enabled and "ON" or "OFF")
hitFxBtn.Parent = panel
local hfCorner = Instance.new("UICorner") hfCorner.CornerRadius = UDim.new(0, 8) hfCorner.Parent = hitFxBtn
styleToggle(hitFxBtn, HitFX.Enabled)
hitFxBtn.MouseButton1Click:Connect(function()
    HitFX.Enabled = not HitFX.Enabled
    hitFxBtn.Text = "Hit FX: " .. (HitFX.Enabled and "ON" or "OFF")
    styleToggle(hitFxBtn, HitFX.Enabled)
end)

local hitSoundBtn = Instance.new("TextButton")
hitSoundBtn.Size = UDim2.new(1, -20, 0, 24)
hitSoundBtn.Position = UDim2.new(0, 10, 0, 362)
hitSoundBtn.Font = Enum.Font.GothamBold
hitSoundBtn.TextSize = 12
hitSoundBtn.Text = "Hit Sound: " .. (HitFX.Sound and "ON" or "OFF")
hitSoundBtn.Parent = panel
local hsCorner = Instance.new("UICorner") hsCorner.CornerRadius = UDim.new(0, 8) hsCorner.Parent = hitSoundBtn
styleToggle(hitSoundBtn, HitFX.Sound)
hitSoundBtn.MouseButton1Click:Connect(function()
    HitFX.Sound = not HitFX.Sound
    hitSoundBtn.Text = "Hit Sound: " .. (HitFX.Sound and "ON" or "OFF")
    styleToggle(hitSoundBtn, HitFX.Sound)
end)

local soundSelBtn = Instance.new("TextButton")
soundSelBtn.Size = UDim2.new(1, -20, 0, 24)
soundSelBtn.Position = UDim2.new(0, 10, 0, 390)
soundSelBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
soundSelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
soundSelBtn.Font = Enum.Font.Gotham
soundSelBtn.TextSize = 12
soundSelBtn.Text = "Sound: " .. SOUNDS[HitFX.SoundSel].name
soundSelBtn.Parent = panel
local ssCorner = Instance.new("UICorner") ssCorner.CornerRadius = UDim.new(0, 8) ssCorner.Parent = soundSelBtn
soundSelBtn.MouseButton1Click:Connect(function()
    HitFX.SoundSel = (HitFX.SoundSel % #SOUNDS) + 1
    soundSelBtn.Text = "Sound: " .. SOUNDS[HitFX.SoundSel].name
    if HitFX.SoundSel > 1 and HitFX.Sound then
        local e = SOUNDS[HitFX.SoundSel]
        local s = Instance.new("Sound")
        s.SoundId = e.id
        s.Volume = HitFX.Volume * (e.vol or 1)
        s.Parent = SoundService
        s:Play()
        Debris:AddItem(s, 3)
    end
end)

local hitEffectBtn = Instance.new("TextButton")
hitEffectBtn.Size = UDim2.new(1, -20, 0, 24)
hitEffectBtn.Position = UDim2.new(0, 10, 0, 418)
hitEffectBtn.Font = Enum.Font.GothamBold
hitEffectBtn.TextSize = 12
hitEffectBtn.Text = "Hit Effect: " .. (HitFX.Effect and "ON" or "OFF")
hitEffectBtn.Parent = panel
local heCorner = Instance.new("UICorner") heCorner.CornerRadius = UDim.new(0, 8) heCorner.Parent = hitEffectBtn
styleToggle(hitEffectBtn, HitFX.Effect)
hitEffectBtn.MouseButton1Click:Connect(function()
    HitFX.Effect = not HitFX.Effect
    hitEffectBtn.Text = "Hit Effect: " .. (HitFX.Effect and "ON" or "OFF")
    styleToggle(hitEffectBtn, HitFX.Effect)
end)

local effectSelBtn = Instance.new("TextButton")
effectSelBtn.Size = UDim2.new(1, -20, 0, 24)
effectSelBtn.Position = UDim2.new(0, 10, 0, 446)
effectSelBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
effectSelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
effectSelBtn.Font = Enum.Font.Gotham
effectSelBtn.TextSize = 12
effectSelBtn.Text = "Effect: " .. EFFECTS[HitFX.EffectSel].name
effectSelBtn.Parent = panel
local efCorner = Instance.new("UICorner") efCorner.CornerRadius = UDim.new(0, 8) efCorner.Parent = effectSelBtn
effectSelBtn.MouseButton1Click:Connect(function()
    HitFX.EffectSel = (HitFX.EffectSel % #EFFECTS) + 1
    effectSelBtn.Text = "Effect: " .. EFFECTS[HitFX.EffectSel].name
end)

local spinBtn = Instance.new("TextButton")
spinBtn.Size = UDim2.new(1, -20, 0, 26)
spinBtn.Position = UDim2.new(0, 10, 0, 476)
spinBtn.Font = Enum.Font.GothamBold
spinBtn.TextSize = 13
spinBtn.Text = "Spin: " .. (Spin.Enabled and "ON" or "OFF")
spinBtn.Parent = panel
local spCorner = Instance.new("UICorner") spCorner.CornerRadius = UDim.new(0, 8) spCorner.Parent = spinBtn
styleToggle(spinBtn, Spin.Enabled)
spinBtn.MouseButton1Click:Connect(function()
    Spin.Enabled = not Spin.Enabled
    spinBtn.Text = "Spin: " .. (Spin.Enabled and "ON" or "OFF")
    styleToggle(spinBtn, Spin.Enabled)
end)

makeSlider(panel, 506, "Spin Speed", 100, 5000, Spin.Speed, function(v) Spin.Speed = v end)

local ammoBtn = Instance.new("TextButton")
ammoBtn.Size = UDim2.new(1, -20, 0, 26)
ammoBtn.Position = UDim2.new(0, 10, 0, 548)
ammoBtn.Font = Enum.Font.GothamBold
ammoBtn.TextSize = 13
ammoBtn.Text = "Infinite Ammo: " .. (InfiniteAmmo.Enabled and "ON" or "OFF")
ammoBtn.Parent = panel
local amCorner = Instance.new("UICorner") amCorner.CornerRadius = UDim.new(0, 8) amCorner.Parent = ammoBtn
styleToggle(ammoBtn, InfiniteAmmo.Enabled)
ammoBtn.MouseButton1Click:Connect(function()
    InfiniteAmmo.Enabled = not InfiniteAmmo.Enabled
    ammoBtn.Text = "Infinite Ammo: " .. (InfiniteAmmo.Enabled and "ON" or "OFF")
    styleToggle(ammoBtn, InfiniteAmmo.Enabled)
    if InfiniteAmmo.Enabled then fillAmmo() end
end)

local rainbowBtn = Instance.new("TextButton")
rainbowBtn.Size = UDim2.new(1, -20, 0, 26)
rainbowBtn.Position = UDim2.new(0, 10, 0, 578)
rainbowBtn.Font = Enum.Font.GothamBold
rainbowBtn.TextSize = 13
rainbowBtn.Text = "Rainbow GUI: " .. (GUI.Rainbow and "ON" or "OFF")
rainbowBtn.Parent = panel
local rbCorner = Instance.new("UICorner") rbCorner.CornerRadius = UDim.new(0, 8) rbCorner.Parent = rainbowBtn
styleToggle(rainbowBtn, GUI.Rainbow)
rainbowBtn.MouseButton1Click:Connect(function()
    GUI.Rainbow = not GUI.Rainbow
    rainbowBtn.Text = "Rainbow GUI: " .. (GUI.Rainbow and "ON" or "OFF")
    styleToggle(rainbowBtn, GUI.Rainbow)
end)

makeSlider(panel, 608, "GUI Size", 0.5, 1.5, GUI.Scale, function(v) GUI.Scale = v; fitPanel() end, 2)
makeSlider(panel, 652, "GUI Opacity", 0.1, 1, GUI.Opacity, function(v) GUI.Opacity = v; fitPanel() end, 2)
makeSlider(panel, 696, "GUI Width", 150, 400, GUI.Width, function(v) GUI.Width = v; fitPanel() end)

--==== INSTANT KILL UI ====--
local ikBtn = Instance.new("TextButton")
ikBtn.Size = UDim2.new(1, -20, 0, 30)
ikBtn.Position = UDim2.new(0, 10, 0, 736)
ikBtn.Font = Enum.Font.GothamBold
ikBtn.TextSize = 14
ikBtn.Text = "Instant Kill: " .. (InstantKill.Enabled and "ON" or "OFF")
ikBtn.Parent = panel
local ikCorner = Instance.new("UICorner") ikCorner.CornerRadius = UDim.new(0, 8) ikCorner.Parent = ikBtn
styleToggle(ikBtn, InstantKill.Enabled)
ikBtn.MouseButton1Click:Connect(function()
    InstantKill.Enabled = not InstantKill.Enabled
    ikBtn.Text = "Instant Kill: " .. (InstantKill.Enabled and "ON" or "OFF")
    styleToggle(ikBtn, InstantKill.Enabled)
    LocalPlayer:SetAttribute("IKEnabled", InstantKill.Enabled)
    if InstantKill.Enabled then ikScanRemote() end
end)
LocalPlayer:SetAttribute("IKEnabled", InstantKill.Enabled)

local ikTargetsBtn = Instance.new("TextButton")
ikTargetsBtn.Size = UDim2.new(1, -20, 0, 24)
ikTargetsBtn.Position = UDim2.new(0, 10, 0, 772)
ikTargetsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ikTargetsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ikTargetsBtn.Font = Enum.Font.Gotham
ikTargetsBtn.TextSize = 12
ikTargetsBtn.Text = "Instant Kill Targets: " .. InstantKill.Targets
ikTargetsBtn.Parent = panel
local iktCorner = Instance.new("UICorner") iktCorner.CornerRadius = UDim.new(0, 8) iktCorner.Parent = ikTargetsBtn
ikTargetsBtn.MouseButton1Click:Connect(function()
    InstantKill.Targets = (InstantKill.Targets == "NPCs") and "All" or "NPCs"
    ikTargetsBtn.Text = "Instant Kill Targets: " .. InstantKill.Targets
end)

local ikNotifyBtn = Instance.new("TextButton")
ikNotifyBtn.Size = UDim2.new(1, -20, 0, 24)
ikNotifyBtn.Position = UDim2.new(0, 10, 0, 800)
ikNotifyBtn.Font = Enum.Font.GothamBold
ikNotifyBtn.TextSize = 12
ikNotifyBtn.Text = "IK Server Notify: " .. (InstantKill.Notify and "ON" or "OFF")
ikNotifyBtn.Parent = panel
local iknCorner = Instance.new("UICorner") iknCorner.CornerRadius = UDim.new(0, 8) iknCorner.Parent = ikNotifyBtn
styleToggle(ikNotifyBtn, InstantKill.Notify)
ikNotifyBtn.MouseButton1Click:Connect(function()
    InstantKill.Notify = not InstantKill.Notify
    ikNotifyBtn.Text = "IK Server Notify: " .. (InstantKill.Notify and "ON" or "OFF")
    styleToggle(ikNotifyBtn, InstantKill.Notify)
end)

--==== NOCLIP UI ====--
local noclipBtn
local function setNoclip(state)
    Noclip.Enabled = state
    if noclipBtn then
        noclipBtn.Text = "Noclip: " .. (state and "ON" or "OFF")
        styleToggle(noclipBtn, state)
    end
    if not state then restoreCollide() end
end

noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(1, -20, 0, 28)
noclipBtn.Position = UDim2.new(0, 10, 0, 830)
noclipBtn.Font = Enum.Font.GothamBold
noclipBtn.TextSize = 14
noclipBtn.Text = "Noclip: " .. (Noclip.Enabled and "ON" or "OFF")
noclipBtn.Parent = panel
local ncCorner = Instance.new("UICorner") ncCorner.CornerRadius = UDim.new(0, 8) ncCorner.Parent = noclipBtn
styleToggle(noclipBtn, Noclip.Enabled)
noclipBtn.MouseButton1Click:Connect(function() setNoclip(not Noclip.Enabled) end)

--==================== FLOATING GUI TOGGLE ====================--
local toggleGui = Instance.new("ScreenGui")
toggleGui.Name = "SilentAimToggle"
toggleGui.ResetOnSpawn = false
toggleGui.IgnoreGuiInset = true
toggleGui.DisplayOrder = 1000
toggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
toggleGui.Parent = GUI_PARENT

local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleButton"
toggleBtn.Size = UDim2.new(0, 118, 0, 44)
toggleBtn.Position = UDim2.new(0, 16, 0, 60)
toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
toggleBtn.BackgroundTransparency = 0.1
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 15
toggleBtn.Text = "CLOSE GUI"
toggleBtn.AutoButtonColor = true
toggleBtn.Active = true
toggleBtn.Parent = toggleGui

local tbCorner = Instance.new("UICorner") tbCorner.CornerRadius = UDim.new(0, 10) tbCorner.Parent = toggleBtn
local tbStroke = Instance.new("UIStroke")
tbStroke.Color = Color3.fromRGB(255, 255, 255)
tbStroke.Thickness = 1.5
tbStroke.Transparency = 0.35
tbStroke.Parent = toggleBtn
addRainbow(tbStroke, "Color", Color3.fromRGB(255, 255, 255))

local function updateToggleLabel()
    toggleBtn.Text = gui.Enabled and "CLOSE GUI" or "OPEN GUI"
end
local function toggleMainGUI()
    gui.Enabled = not gui.Enabled
    updateToggleLabel()
end

local dragging, dragStart, startPos, moved = false, nil, nil, false
local function clampToScreen(x, y)
    local vp = Camera.ViewportSize
    local sz = toggleBtn.AbsoluteSize
    x = math.clamp(x, 0, math.max(0, vp.X - sz.X))
    y = math.clamp(y, 0, math.max(0, vp.Y - sz.Y))
    return x, y
end

toggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        moved = false
        dragStart = input.Position
        startPos = toggleBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if not moved then toggleMainGUI() end
            end
        end)
    end
end)

toggleBtn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then moved = true end
        if moved then
            local nx = startPos.X.Offset + delta.X
            local ny = startPos.Y.Offset + delta.Y
            nx, ny = clampToScreen(nx, ny)
            toggleBtn.Position = UDim2.new(0, nx, 0, ny)
        end
    end
end)

updateToggleLabel()

--==================== TOGGLE KEYS ====================--
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        if not Settings.Enabled then Target, TargetPart = nil, nil end
        silentBtn.Text = "Silent Aim: " .. (Settings.Enabled and "ON" or "OFF")
        styleToggle(silentBtn, Settings.Enabled)
    elseif input.KeyCode == Noclip.Key then
        setNoclip(not Noclip.Enabled)
    end
end)

--==================== RAINBOW RENDER ====================--
local function updateRainbow(dt)
    if GUI.Rainbow then
        rainbowHue = (rainbowHue + dt * GUI.RainbowSpeed) % 1
        local c = Color3.fromHSV(rainbowHue, 0.85, 1)
        for _, it in ipairs(rainbowItems) do it.inst[it.prop] = c end
        Settings.RingColor = c
        ESP.Color = c
        ESP.TextColor = c
    else
        for _, it in ipairs(rainbowItems) do it.inst[it.prop] = it.orig end
        Settings.RingColor = Color3.fromRGB(255, 255, 255)
        ESP.Color = Color3.fromRGB(255, 255, 255)
        ESP.TextColor = Color3.fromRGB(255, 255, 255)
    end
end

--==================== SINGLE RENDER LOOP ====================--
RunService.RenderStepped:Connect(function(dt)
    applySpin(dt)
    updateRainbow(dt)
    findTarget()
    updateHighlight()
    updateESP()
    updateFOVRing()
    applyWalkspeed()
end)

--==================== INIT ====================--
ikScanRemote()

print("[Silent Aim v32.0] loaded | hooks=" .. tostring(installed)
    .. " | spin=" .. tostring(Spin.Enabled) .. " | ammo=" .. tostring(InfiniteAmmo.Enabled)
    .. " | instakill=" .. tostring(InstantKill.Enabled) .. " | noclip=" .. tostring(Noclip.Enabled))
