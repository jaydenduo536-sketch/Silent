--[[
    Venice UI v2  --  silent aim + spin + instant reload + noclip + ESP + chams + hitfx + snow + fly + tracers
    MADE BY ROMAN
    v2: trail fixed, rapid fire no longer tanks fps, mobile fly, low gfx removed,
        +57 combat features, +73 misc features
    Instant Reload: learns mag size, refills on heartbeat (no reload downtime)
    Note: all new modules live in globals so the main chunk stays under the 200-local limit
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local SoundService     = game:GetService("SoundService")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local VirtualUser      = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

--====================== ASSETS ======================--
local SONG_ID    = "rbxassetid://111018848542448"
local SONG_START = 30
POPUP_TIME = 5

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
    Window = 0.1, Cooldown = 0.08, Volume = 1, SoundSel = 1, EffectSel = 1,
}
getgenv().SilentAimHitFX = HitFX

local Spin = { Enabled = false, Speed = 1200, Axis = "Y" }
getgenv().SilentAimSpin = Spin

InstantReload = {
    Enabled = false, Reserve = true, Target = 0,
    _max = {}, _cache = {}, _lastRebuild = 0,
}
getgenv().RomanInstantReload = InstantReload

local AutoReload = { Enabled = false }
getgenv().SilentAimAutoReload = AutoReload

local AMMO_KEYWORDS = { "ammo","clip","mag","bullet","round","shell","reserve","shot" }
local function isAmmoName(n)
    n = string.lower(tostring(n))
    for i = 1, #AMMO_KEYWORDS do
        if string.find(n, AMMO_KEYWORDS[i], 1, true) then return true end
    end
    return false
end

local GUI = {
    Scale = 1, Opacity = 0.98, Width = 250, Rainbow = false, RainbowSpeed = 0.35,
    Accent = Color3.fromRGB(120, 170, 255),
}
getgenv().SilentAimGUI = GUI

local ESP = {
    Enabled = false, Boxes = true, Names = true, Skeleton = true,
    Color = Color3.fromRGB(255, 255, 255), TextColor = Color3.fromRGB(255, 255, 255),
}
getgenv().SilentAimESP = ESP

local Noclip = { Enabled = false, Bypass = true, Key = Enum.KeyCode.N }
getgenv().SilentAimNoclip = Noclip

local Snow = { Enabled = true, Count = 90 }
getgenv().RomanSnow = Snow

local Visual = { Fullbright = false, NoFog = false }
local Move   = { InfiniteJump = false, AntiAFK = false }
local Feedback = { HitMarker = true, DamageNumbers = true, KillNotifier = true, Strict = false, Cone = 60 }
local Trail  = { Enabled = false, Color = Color3.fromRGB(130, 220, 255) }
local HUD    = { FPS = false, Clock = false, Ping = false }
getgenv().RomanMisc = { Visual = Visual, Move = Move, Feedback = Feedback, HUD = HUD }

--==================== NEW MODULES (GLOBAL) ====================--
-- Combat extras
CombatX = {
    AimMode = "Toggle", HoldKey = Enum.KeyCode.LeftAlt, _hold = false,
    TargetMode = "Crosshair", Sticky = false,
    RingShape = "Circle", ShowRing = true, RingThick = 1, RingOpacity = 1,
    Smooth = 0.35, SmoothOn = false,
    OffsetEnabled = false, OffX = 0, OffY = 0, OffZ = 0,
    PredMul = 1, MinDist = 0, MaxDist = 0, HealthBelow = 0,
    HighlightFill = 0.55, HighlightOutline = 0,
    TargetRing = false, TargetTracer = false, TracerColor = Color3.fromRGB(0, 255, 255),
    TargetInfo = false, CameraLock = false, LockStrength = 0.15,
    TriggerBot = false, TriggerDelay = 0.05, TriggerRadius = 40,
    AutoShoot = false, ShootInterval = 0.1, AutoReloadOnKill = false,
    MultiTarget = false, SwitchDelay = 0.25, _lastSwitch = 0,
    Wallbang = false, IgnoreDead = false,
    AntiRecoil = false, RecoilReduction = 0.5, _recoilPitch = nil,
    NoSpread = false, InstantHit = false, SilentCamera = false,
    KillCounter = false, KillsHUD = false, Debug = false,
    _aimPoint = nil, _aimValid = false, _lastShoot = 0,
    _kills = 0, _hp = {}, _tracerPart = nil, _infoLabel = nil, _ringHL = nil,
}
getgenv().RomanCombatX = CombatX

-- Misc extras
MiscX = {
    Watermark = true,
    PlayerCount = false, JobId = false, InstanceCount = false,
    MemoryUsage = false, SessionTimer = false, SessionStart = tick(),
    ClockTime = 14, TimeOn = false,
    AmbientV = 0.5, AmbientOn = false,
    FogColor = Color3.fromRGB(180, 180, 190), FogEnd = 1000, FogOn = false,
    Bloom = false, Blur = false, DOF = false, ColorCorr = false, SunRays = false,
    Shadows = true, SkyOff = false, Water = true,
    CamFOV = 70, CamFOVOn = false, MaxZoom = 200, MaxZoomOn = false,
    FirstPerson = false, ShiftLock = false, NoHeadBob = false,
    Gravity = 196.2, GravityOn = false,
    JumpPower = 50, JumpOn = false,
    HipHeight = 2, HipOn = false,
    AutoJump = false, Sprint = false, SprintSpeed = 32,
    Crouch = false, CrouchSpeed = 8,
    ClickTP = false, AntiVoid = false, AntiVoidY = -80,
    Freeze = false, FaceCam = false, AntiFling = false, AntiFlingMax = 250, Desync = false,
    CharTrans = 0, CharTransOn = false,
    HideAcc = false, HideNames = false,
    MuteGame = false, Volume = 1,
    AutoRespawn = false, FpsUnlock = false, FpsCap = 240,
    AutoClicker = false, AutoClickerCPS = 10, _lastClick = 0,
    _fx = {}, _sky = nil, _origHip = 2, _origJump = 50, _origUseJump = false,
    _buf = {}, _lastSlow = 0,
}
getgenv().RomanMiscX = MiscX

NoParts = { Enabled = false, _fx = {}, _last = 0 }
getgenv().RomanNoParts = NoParts

--==================== GUI PARENT ====================--
local GUI_PARENT
pcall(function() GUI_PARENT = gethui and gethui() or nil end)
GUI_PARENT = GUI_PARENT or LocalPlayer:WaitForChild("PlayerGui")

for _, guiName in ipairs({ "SilentAimUI", "SilentAimESP", "SilentAimFOV", "VeniceUI",
                            "SilentAimToggle", "RomanSnow", "RomanFeedback", "RomanHUD",
                            "RomanFlyBtn", "RomanCombatHUD" }) do
    local old = GUI_PARENT:FindFirstChild(guiName)
    if old then pcall(function() old:Destroy() end) end
end

local Target, TargetPart, PartHighlight
local notify

--==================== HELPERS ====================--
local function fovRadiusPx()
    local vp = Camera.ViewportSize
    local m = math.min(vp.X, vp.Y)
    return (m * 0.5) * (Settings.FOV / 90)
end

local function aimActive()
    if not Settings.Enabled then return false end
    if CombatX.AimMode == "Hold" and not CombatX._hold then return false end
    return true
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function pathClear(from, to, ignore)
    local filter = {}
    if ignore then filter[#filter + 1] = ignore end
    local lc = LocalPlayer.Character
    if lc and lc ~= ignore then filter[#filter + 1] = lc end
    rayParams.FilterDescendantsInstances = filter
    local r = Workspace:Raycast(from, to - from, rayParams)
    if not r then return true end
    if ignore and r.Instance:IsDescendantOf(ignore) then return true end
    return false
end

local function hasLineOfSight(char, part)
    if CombatX.Wallbang then return true end
    if not Settings.VisibleCheck then return true end
    return pathClear(Camera.CFrame.Position, part.Position, char)
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

local function hitRelevant(plr, root)
    if Feedback.Strict then
        return Target ~= nil and plr == Target
    end
    if Settings.Enabled and Target then
        return plr == Target
    end
    if not root then return false end
    local sp = Camera:WorldToViewportPoint(root.Position)
    if sp.Z <= 0 then return false end
    local vp = Camera.ViewportSize
    local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(vp.X / 2, vp.Y / 2)).Magnitude
    return d <= Feedback.Cone
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

local function rawAimPos()
    if not TargetPart or not TargetPart.Parent then return nil end
    local pos = TargetPart.Position
    if Settings.Predict and TargetPart:IsA("BasePart") then
        local dist = (pos - Camera.CFrame.Position).Magnitude
        local t = math.clamp(dist / Settings.ProjectileSpeed, 0, Settings.MaxLead) * CombatX.PredMul
        pos = pos + TargetPart.AssemblyLinearVelocity * t
    end
    if CombatX.OffsetEnabled then
        pos = pos + Vector3.new(CombatX.OffX, CombatX.OffY, CombatX.OffZ)
    end
    return pos
end

local function aimPos()
    if CombatX.SmoothOn and CombatX._aimValid and CombatX._aimPoint then
        return CombatX._aimPoint
    end
    return rawAimPos()
end

local function targetScore(plr, char, hum, ap, cx, cy)
    local sp = Camera:WorldToViewportPoint(ap.Position)
    if sp.Z <= 0 then return nil end
    local screenD = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
    local mode = CombatX.TargetMode
    if mode == "Distance" then
        return (ap.Position - Camera.CFrame.Position).Magnitude
    elseif mode == "Health" then
        return hum.Health
    elseif mode == "Threat" then
        return screenD + hum.Health * 0.1
    end
    return screenD
end

local function findTarget()
    if not aimActive() then Target, TargetPart = nil, nil; CombatX._aimValid = false; return end
    local vp = Camera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local radius = fovRadiusPx()

    if CombatX.Sticky and Target and TargetPart and TargetPart.Parent then
        local th = Target.Character and Target.Character:FindFirstChildOfClass("Humanoid")
        if th and th.Health > 0 then
            local sp = Camera:WorldToViewportPoint(TargetPart.Position)
            if sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
                if d <= radius * 1.25 then return end
            end
        end
    end

    local now = tick()
    if CombatX.MultiTarget and Target and now - CombatX._lastSwitch < CombatX.SwitchDelay then
        return
    end

    local best, bestScore, bestPart = nil, math.huge, nil
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if plr ~= LocalPlayer and char and isEnemy(plr) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and isAlive(plr, char, hum) then
                local ap = resolveAimPart(char, Settings.AimPart)
                    or char:FindFirstChild("HumanoidRootPart")
                if ap then
                    local dist = (ap.Position - Camera.CFrame.Position).Magnitude
                    local pass = true
                    if CombatX.MaxDist > 0 and dist > CombatX.MaxDist then pass = false end
                    if CombatX.MinDist > 0 and dist < CombatX.MinDist then pass = false end
                    if CombatX.HealthBelow > 0 and hum.Health > CombatX.HealthBelow then pass = false end
                    if pass then
                        local sp = Camera:WorldToViewportPoint(ap.Position)
                        if sp.Z > 0 then
                            local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude
                            if d <= radius and hasLineOfSight(char, ap) then
                                local sc = targetScore(plr, char, hum, ap, cx, cy)
                                if sc and sc < bestScore then
                                    best, bestScore, bestPart = plr, sc, ap
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if best ~= Target then CombatX._lastSwitch = now end
    Target, TargetPart = best, bestPart
end

--==================== RAPID FIRE ====================--
RapidFire = {
    Enabled      = false,
    Override     = 0.01,
    OnlyIfHigher = true,
    Interval     = 0.2,
    ScanInterval = 2.5,
    Print        = false,
    Loose        = false,
    Keywords = {
        "firerate", "fire_rate", "firerat", "rate_of_fire", "rateoffire",
        "firecooldown", "fire_delay", "firedelay", "fireinterval",
        "attackrate", "attack_speed", "attackspeed", "rpm",
    },
    Blacklist = {
        "walkspeed", "jumppower", "spawnrate", "cashrate", "xprate",
        "goldrate", "droprate", "regenerate",
    },
    _targets = {}, _originals = {}, _memo = {}, _kw = {}, _bl = {},
    _last = 0, _lastScan = 0, _queue = nil, _qi = 1, _found = nil,
}
getgenv().RomanRapidFire = RapidFire

for i, k in ipairs(RapidFire.Keywords)  do RapidFire._kw[i] = string.lower(k) end
for i, b in ipairs(RapidFire.Blacklist) do RapidFire._bl[i] = string.lower(b) end

function rfMatches(name)
    local memo = RapidFire._memo
    local cached = memo[name]
    if cached ~= nil then return cached end
    local n = string.lower(name)
    local bl = RapidFire._bl
    for i = 1, #bl do
        if string.find(n, bl[i], 1, true) then memo[name] = false; return false end
    end
    local kw = RapidFire._kw
    local res = false
    for i = 1, #kw do
        if string.find(n, kw[i], 1, true) then res = true; break end
    end
    if not res and RapidFire.Loose then
        if string.find(n, "rate", 1, true) or string.find(n, "speed", 1, true) then
            res = true
        end
    end
    memo[name] = res
    return res
end

function rfTarget(orig)
    if RapidFire.OnlyIfHigher then return math.min(orig, RapidFire.Override) end
    return RapidFire.Override
end

function RapidFireScan()
    if not RapidFire.Enabled then return end
    RapidFire._queue = game:GetDescendants()
    RapidFire._qi = 1
    RapidFire._found = {}
end

function RapidFireStep(budget)
    local q = RapidFire._queue
    if not q then return end
    local i = RapidFire._qi
    local n = #q
    local stop = math.min(n, i + (budget or 600) - 1)
    local found = RapidFire._found or {}
    for k = i, stop do
        local obj = q[k]
        local ok, attrs = pcall(function() return obj:GetAttributes() end)
        if ok and attrs then
            for name, val in pairs(attrs) do
                if type(val) == "number" and rfMatches(name) then
                    local t = found[obj]
                    if not t then t = {}; found[obj] = t end
                    t[name] = true
                    local orig = RapidFire._originals
                    orig[obj] = orig[obj] or {}
                    if orig[obj][name] == nil then orig[obj][name] = val end
                    local tv = rfTarget(val)
                    if val ~= tv then pcall(function() obj:SetAttribute(name, tv) end) end
                end
            end
        end
    end
    RapidFire._found = found
    RapidFire._qi = stop + 1
    if RapidFire._qi > n then
        RapidFire._queue = nil
        RapidFire._targets = found
    end
end

function RapidFireApply()
    if not RapidFire.Enabled then return end
    for obj, names in pairs(RapidFire._targets) do
        if obj.Parent then
            for name in pairs(names) do
                local v = obj:GetAttribute(name)
                if type(v) == "number" then
                    local tv = rfTarget(v)
                    if v ~= tv then pcall(function() obj:SetAttribute(name, tv) end) end
                end
            end
        end
    end
end

function RapidFireRestore()
    for obj, t in pairs(RapidFire._originals) do
        for name, val in pairs(t) do
            pcall(function() obj:SetAttribute(name, val) end)
        end
    end
    RapidFire._originals = {}
    RapidFire._targets = {}
    RapidFire._queue = nil
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
        PartHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        PartHighlight.Parent = GUI_PARENT
    end
    PartHighlight.FillColor = Settings.HighlightColor
    PartHighlight.FillTransparency = CombatX.HighlightFill
    PartHighlight.OutlineColor = Settings.HighlightColor
    PartHighlight.OutlineTransparency = CombatX.HighlightOutline
    PartHighlight.Adornee = Target.Character
end

--==================== HOOKS ====================--
local nc = newcclosure or function(f) return f end
local oldIndex, oldNamecall, oldNewIndex
local installed = false

local function indexHook(self, key)
    if aimActive() and Target and self == Mouse then
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

    if method == "Move" and Fly and Fly.Enabled and Fly._hum and self == Fly._hum then
        local mv = ...
        if typeof(mv) == "Vector3" then Fly._moveVec = mv end
    end

    if RapidFire.Enabled and method == "SetAttribute" then
        local attr, val = ...
        if type(attr) == "string" and type(val) == "number" and rfMatches(attr) then
            return oldNamecall(self, attr, rfTarget(val))
        end
    end

    if InstantReload.Enabled and method == "SetAttribute" then
        local attr, val = ...
        if type(attr) == "string" and type(val) == "number" and isAmmoName(attr) then
            local skip = (not InstantReload.Reserve) and isReserveName(attr)
            if not skip then
                local m = (InstantReload.Target > 0) and InstantReload.Target
                    or InstantReload._max[self]
                if m and val < m then
                    return oldNamecall(self, attr, m)
                end
            end
        end
    end

    if method == "Kick" and Settings.AntiKick and self == LocalPlayer then return nil end
    if aimActive() and Target and self == Camera
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
    root.CFrame = root.CFrame * CFrame.fromAxisAngle(axis, math.rad(Spin.Speed * dt))
end

--==================== AMMO / INSTANT RELOAD ====================--
local vim = game:GetService("VirtualInputManager")

local RESERVE_HINTS = { "reserve","spare","stock","total","backup","stored","pool" }
local function isReserveName(n)
    n = string.lower(tostring(n))
    for i = 1, #RESERVE_HINTS do
        if string.find(n, RESERVE_HINTS[i], 1, true) then return true end
    end
    return false
end

local MAX_HINTS = { "maxammo","ammomax","maxammocount","clipsize","magsize",
                    "maxclip","maxmag","ammomaxcount","maxbullets","maxrounds" }
local function isMaxName(n)
    n = string.lower(tostring(n))
    for i = 1, #MAX_HINTS do
        if string.find(n, MAX_HINTS[i], 1, true) then return true end
    end
    return false
end

local function discoverMax(inst)
    for _, a in ipairs(inst:GetAttributes()) do
        if isMaxName(a) then
            local v = inst:GetAttribute(a)
            if type(v) == "number" and v > 0 then return v end
        end
    end
    local p = inst.Parent
    if p then
        for _, a in ipairs(p:GetAttributes()) do
            if isMaxName(a) then
                local v = p:GetAttribute(a)
                if type(v) == "number" and v > 0 then return v end
            end
        end
        for _, ch in ipairs(p:GetChildren()) do
            if (ch:IsA("NumberValue") or ch:IsA("IntValue")) and isMaxName(ch.Name) and ch.Value > 0 then
                return ch.Value
            end
        end
    end
    return nil
end

local function pressReload()
    pcall(function()
        vim:SendKeyEvent(true, "R", false, game)
        task.wait(0.03)
        vim:SendKeyEvent(false, "R", false, game)
    end)
end

local function rebuildAmmoCache()
    local list, seen = {}, {}
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    local bpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    local roots = { char, tool, bpack }
    for _, root in ipairs(roots) do
        if root then
            if (root:IsA("NumberValue") or root:IsA("IntValue")) and isAmmoName(root.Name)
            and not seen[root] then
                seen[root] = true; list[#list + 1] = root
            end
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("NumberValue") or d:IsA("IntValue")) and isAmmoName(d.Name)
                and not seen[d] then
                    seen[d] = true; list[#list + 1] = d
                end
            end
        end
    end
    InstantReload._cache = list
end

local ammoReloadCd = {}

local function ammoTick()
    if not (InstantReload.Enabled or AutoReload.Enabled) then return end
    local now = tick()
    if now - InstantReload._lastRebuild > 0.5 then
        InstantReload._lastRebuild = now
        rebuildAmmoCache()
    end
    for _, d in ipairs(InstantReload._cache) do
        if d.Parent then
            local v = d.Value
            if type(v) == "number" and v >= 0 then
                if InstantReload.Enabled then
                    local skip = (not InstantReload.Reserve) and isReserveName(d.Name)
                    if not skip then
                        local m
                        if InstantReload.Target > 0 then
                            m = InstantReload.Target
                        else
                            m = InstantReload._max[d]
                            if not m then
                                m = discoverMax(d) or v
                                InstantReload._max[d] = m
                            elseif v > m then
                                m = v; InstantReload._max[d] = m
                            end
                        end
                        if m and v < m then d.Value = m end
                    end
                end
                if AutoReload.Enabled and v <= 0 then
                    if now - (ammoReloadCd[d] or 0) > 0.4 then
                        ammoReloadCd[d] = now
                        pressReload()
                    end
                end
            end
        end
    end
end

local function bindAmmoChar(char)
    char.ChildAdded:Connect(function(ch)
        if ch:IsA("Tool") then task.wait(0.05); rebuildAmmoCache() end
    end)
end
if LocalPlayer.Character then bindAmmoChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    InstantReload._max = {}
    rebuildAmmoCache()
    bindAmmoChar(char)
end)

--==================== WALK / SPRINT / CROUCH ====================--
baseWalk = 16
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
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local target
    if MiscX.Crouch then target = MiscX.CrouchSpeed
    elseif MiscX.Sprint then target = MiscX.SprintSpeed
    elseif Settings.WalkspeedEnabled then target = Settings.Walkspeed
    else target = baseWalk end
    if hum.WalkSpeed ~= target then hum.WalkSpeed = target end
end

local function restoreCollide()
    local char = LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") then d.Collide = true; d.CanCollide = true end
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

--==================== FLY (MOBILE + PC) ====================--
Fly = {
    Enabled = false,
    Speed   = 60,
    Key     = Enum.KeyCode.F,
    _bv     = nil, _bg = nil, _hum = nil, _controls = nil,
    _moveVec = nil, _up = false, _down = false,
}
getgenv().RomanFly = Fly

function FlyGetControls()
    if Fly._controls then return Fly._controls end
    local ok, mod = pcall(function()
        return require(LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and mod then
        local ok2, ctrls = pcall(function() return mod:GetControls() end)
        if ok2 and ctrls then Fly._controls = ctrls; return ctrls end
    end
    return nil
end

function stopFly()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
    if Fly._bv then pcall(function() Fly._bv:Destroy() end); Fly._bv = nil end
    if Fly._bg then pcall(function() Fly._bg:Destroy() end); Fly._bg = nil end
    Fly._hum = nil
    if flyBtnGui then flyBtnGui.Enabled = false end
end

function applyFly()
    if not Fly.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    Fly._hum = hum

    if not Fly._bv or Fly._bv.Parent ~= root then
        if Fly._bv then pcall(function() Fly._bv:Destroy() end) end
        if Fly._bg then pcall(function() Fly._bg:Destroy() end) end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = root
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 10000
        bg.D = 500
        bg.CFrame = CFrame.new(root.Position)
        bg.Parent = root
        Fly._bv = bv
        Fly._bg = bg
    end

    if not hum.PlatformStand then hum.PlatformStand = true end

    local cam = Workspace.CurrentCamera
    local mv = nil
    local ctrl = FlyGetControls()
    if ctrl then
        local ok, v = pcall(function() return ctrl:GetMoveVector() end)
        if ok and v and v.Magnitude > 0.01 then mv = v end
    end
    if not mv and Fly._moveVec and Fly._moveVec.Magnitude > 0.01 then mv = Fly._moveVec end
    if not mv then
        local kx, kz = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then kz = kz - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then kz = kz + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then kx = kx - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then kx = kx + 1 end
        if kx ~= 0 or kz ~= 0 then mv = Vector3.new(kx, 0, kz) end
    end

    local dir = Vector3.new(0, 0, 0)
    if mv then
        dir = cam.CFrame.LookVector * (-mv.Z) + cam.CFrame.RightVector * mv.X
    end
    local vy = 0
    if Fly._up then vy = vy + 1 end
    if Fly._down then vy = vy - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vy = vy + 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vy = vy - 1 end
    if vy ~= 0 then dir = dir + Vector3.new(0, vy, 0) end

    if dir.Magnitude > 0 then dir = dir.Unit end
    Fly._bv.Velocity = dir * Fly.Speed
    Fly._bg.CFrame = CFrame.new(root.Position)

    if flyBtnGui then
        flyBtnGui.Enabled = UserInputService.TouchEnabled
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    Fly._bv, Fly._bg, Fly._hum = nil, nil, nil
    task.wait(0.2)
    if Fly.Enabled then applyFly() end
end)

--==================== INFINITE JUMP / ANTI-AFK ====================--
UserInputService.JumpRequest:Connect(function()
    if not Move.InfiniteJump then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

LocalPlayer.Idled:Connect(function()
    if not Move.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==================== FULLBRIGHT / NO FOG ====================--
local lightStore, fogStore = {}, {}
local function setFullbright(on)
    if on then
        if not lightStore.on then
            lightStore.on = true
            lightStore.Brightness = Lighting.Brightness
            lightStore.Ambient = Lighting.Ambient
            lightStore.OutdoorAmbient = Lighting.OutdoorAmbient
        end
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif lightStore.on then
        lightStore.on = false
        Lighting.Brightness = lightStore.Brightness
        Lighting.Ambient = lightStore.Ambient
        Lighting.OutdoorAmbient = lightStore.OutdoorAmbient
    end
end

local function setNoFog(on)
    if on then
        if not fogStore.on then
            fogStore.on = true
            fogStore.End = Lighting.FogEnd
            fogStore.Start = Lighting.FogStart
            fogStore.Color = Lighting.FogColor
        end
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    elseif fogStore.on then
        fogStore.on = false
        Lighting.FogEnd = fogStore.End
        Lighting.FogStart = fogStore.Start
        Lighting.FogColor = fogStore.Color
    end
end

local lastVisualCheck = 0
local function applyVisuals()
    local now = tick()
    if now - lastVisualCheck < 0.5 then return end
    lastVisualCheck = now
    if Visual.Fullbright then setFullbright(true) end
    if Visual.NoFog then setNoFog(true) end
end

--==================== NO PARTICLES (replaces low gfx) ====================--
function collectNoParts()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
        or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles"))
        and string.sub(d.Name, 1, 5) ~= "Roman"
        and NoParts._fx[d] == nil then
            NoParts._fx[d] = d.Enabled
            d.Enabled = false
        end
    end
end

function setNoParticles(on)
    if on then
        collectNoParts()
    else
        for inst, val in pairs(NoParts._fx) do
            if inst.Parent then inst.Enabled = val end
        end
        NoParts._fx = {}
    end
end

function noPartsTick()
    if not NoParts.Enabled then return end
    local now = tick()
    if now - NoParts._last < 2 then return end
    NoParts._last = now
    collectNoParts()
end

--==================== NEON TRACERS ====================--
Tracers = {
    Enabled = false, Color = Color3.fromRGB(0, 255, 255),
    Width = 0.14, Lifetime = 0.14, Interval = 0.06, _last = 0,
}
getgenv().RomanTracers = Tracers

MUZZLE_HINTS = { "muzzle", "barrel", "tip", "nozzle", "flash", "firepoint",
                 "shootpoint", "fire", "end", "point" }

function getMuzzle()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") then
                local n = string.lower(d.Name)
                for _, h in ipairs(MUZZLE_HINTS) do
                    if string.find(n, h, 1, true) then return d end
                end
            end
        end
        if tool:FindFirstChild("Handle") then return tool.Handle end
    end
    return char:FindFirstChild("HumanoidRootPart")
end

function tracerEndPoint()
    if TargetPart and TargetPart.Parent then return TargetPart.Position end
    local origin = Camera.CFrame.Position
    local dir = Camera.CFrame.LookVector * 1000
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local char = LocalPlayer.Character
    rp.FilterDescendantsInstances = char and { char } or {}
    local hit = Workspace:Raycast(origin, dir, rp)
    if hit then return hit.Position end
    return origin + dir
end

function drawTracer(from, to)
    local dist = (to - from).Magnitude
    if dist < 0.2 then return end
    local beam = Instance.new("Part")
    beam.Name = "RomanTracerShot"
    beam.Anchored = true
    beam.CanCollide = false
    beam.CanQuery = false
    beam.CastShadow = false
    beam.Material = Enum.Material.Neon
    beam.Color = Tracers.Color
    beam.Size = Vector3.new(Tracers.Width, Tracers.Width, dist)
    beam.CFrame = CFrame.lookAt((from + to) * 0.5, to)
    beam.Parent = Workspace
    task.spawn(function()
        local steps = 6
        for i = 1, steps do
            beam.Transparency = i / steps
            task.wait(Tracers.Lifetime / steps)
        end
        beam:Destroy()
    end)
end

function spawnTracer()
    local m = getMuzzle()
    if not m then return end
    drawTracer(m.Position, tracerEndPoint())
end

function tracersTick()
    if not Tracers.Enabled or not firing then return end
    local now = tick()
    if now - Tracers._last < Tracers.Interval then return end
    Tracers._last = now
    spawnTracer()
end

--==================== CHARACTER TRAIL (FIXED) ====================--
trailInst = nil

local function updateTrail()
    if not Trail.Enabled then
        if trailInst then pcall(function() trailInst:Destroy() end); trailInst = nil end
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if trailInst then pcall(function() trailInst:Destroy() end); trailInst = nil end
        return
    end
    -- rebuild if the trail or its attachments went missing
    if trailInst and (trailInst.Parent ~= root
        or not trailInst.Attachment0 or not trailInst.Attachment0.Parent
        or not trailInst.Attachment1 or not trailInst.Attachment1.Parent) then
        pcall(function() trailInst:Destroy() end)
        trailInst = nil
    end
    if not trailInst then
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(0, 1.7, 0); a0.Parent = root
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(0, -1.7, 0); a1.Parent = root
        local t = Instance.new("Trail")
        t.Name = "RomanTrail"
        t.Attachment0 = a0
        t.Attachment1 = a1
        t.Lifetime = 1.6
        t.MinLength = 0.2
        t.FaceCamera = true
        t.LightEmission = 1
        t.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        })
        t.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(0.5, 0.5),
            NumberSequenceKeypoint.new(1, 1),
        })
        t.Color = ColorSequence.new(Trail.Color)
        t.Parent = root
        trailInst = t
    end
    if trailInst.Color.Keypoints[1].Value ~= Trail.Color then
        trailInst.Color = ColorSequence.new(Trail.Color)
    end
end

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
    s.Color = ESP.Color; s.Thickness = 1.5; s.Transparency = 0; s.Parent = f
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
                if ESP.Skeleton then
                    updateBones(d, char)
                    for _, l in ipairs(d.lines) do l.BackgroundColor3 = ESP.Color end
                else
                    for _, l in ipairs(d.lines) do l.Visible = false end
                end
            else
                local d = espData[plr]
                if d then hideData(d) end
            end
        end
    end
end

--==================== CHAMS ====================--
Chams = {
    Enabled = false, Neon = true, Color = Color3.fromRGB(0, 255, 200),
    Material = "ForceField", Transparency = 0, Glow = true,
    _hl = nil, _light = nil, _last = 0,
}
getgenv().RomanChams = Chams

CHAMS_MATERIALS = { "ForceField", "Glass" }
ChamsOriginal = {}

function restoreChams()
    for part, data in pairs(ChamsOriginal) do
        if part.Parent then
            pcall(function()
                part.Material = data.m
                part.Color = data.c
                part.Transparency = data.t
            end)
        end
    end
    ChamsOriginal = {}
    if Chams._hl then pcall(function() Chams._hl:Destroy() end); Chams._hl = nil end
    if Chams._light then pcall(function() Chams._light:Destroy() end); Chams._light = nil end
end

function applyChams()
    if not Chams.Enabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local mat = Enum.Material[Chams.Material] or Enum.Material.ForceField
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            if not ChamsOriginal[d] then
                ChamsOriginal[d] = { m = d.Material, c = d.Color, t = d.Transparency }
            end
            d.Material = mat
            d.Color = Chams.Color
            d.Transparency = Chams.Transparency
        end
    end
    if Chams.Glow or Chams.Neon then
        local hl = Chams._hl
        if not hl or hl.Parent ~= char then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Name = "RomanChamsHL"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = char
            Chams._hl = hl
        end
        hl.FillColor = Chams.Color
        hl.FillTransparency = 0.5
        hl.OutlineColor = Chams.Color
        hl.OutlineTransparency = 0
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local l = Chams._light
            if not l or l.Parent ~= root then
                if l then pcall(function() l:Destroy() end) end
                l = Instance.new("PointLight")
                l.Name = "RomanChamsLight"
                l.Range = 14
                l.Brightness = 2.2
                l.Shadows = false
                l.Parent = root
                Chams._light = l
            end
            l.Color = Chams.Color
        end
    else
        if Chams._hl then pcall(function() Chams._hl:Destroy() end); Chams._hl = nil end
        if Chams._light then pcall(function() Chams._light:Destroy() end); Chams._light = nil end
    end
end

function updateChams()
    if not Chams.Enabled then return end
    local now = tick()
    if now - Chams._last < 0.1 then return end
    Chams._last = now
    applyChams()
end

LocalPlayer.CharacterAdded:Connect(function(char)
    ChamsOriginal = {}
    if Chams._hl then pcall(function() Chams._hl:Destroy() end); Chams._hl = nil end
    if Chams._light then pcall(function() Chams._light:Destroy() end); Chams._light = nil end
    task.wait(0.25)
    if Chams.Enabled then applyChams() end
end)

--==================== HITBOX EXPANDER ====================--
Hitbox = {
    Enabled = false, Size = Vector3.new(11, 14, 5),
    Transparency = 0.55, TeamCheck = true, _last = 0,
}
getgenv().RomanHitbox = Hitbox
OriginalSizes = {}

function restoreHitbox()
    for plr, data in pairs(OriginalSizes) do
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    hrp.Size = data.s
                    hrp.Transparency = data.t
                end)
            end
        end
    end
    OriginalSizes = {}
end

function applyHitbox()
    if not Hitbox.Enabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local want = (not Hitbox.TeamCheck) or isEnemy(plr)
            if hrp then
                if want then
                    if not OriginalSizes[plr] then
                        OriginalSizes[plr] = { s = hrp.Size, t = hrp.Transparency }
                    end
                    if hrp.Size ~= Hitbox.Size then hrp.Size = Hitbox.Size end
                    if hrp.Transparency ~= Hitbox.Transparency then
                        hrp.Transparency = Hitbox.Transparency
                    end
                elseif OriginalSizes[plr] then
                    hrp.Size = OriginalSizes[plr].s
                    hrp.Transparency = OriginalSizes[plr].t
                    OriginalSizes[plr] = nil
                end
            end
        end
    end
end

function updateHitbox()
    if not Hitbox.Enabled then return end
    local now = tick()
    if now - Hitbox._last < 0.1 then return end
    Hitbox._last = now
    applyHitbox()
end

Players.PlayerRemoving:Connect(function(plr)
    OriginalSizes[plr] = nil
end)

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
local cdCorner = Instance.new("UICorner") cdCorner.CornerRadius = UDim.new(1, 0); cdCorner.Parent = centerDot

local function updateFOVRing()
    fovGui.Enabled = CombatX.ShowRing
    if not CombatX.ShowRing then return end
    local r = fovRadiusPx()
    fovCircle.Size = UDim2.new(0, r * 2, 0, r * 2)
    if CombatX.RingShape == "Square" then
        fcCorner.CornerRadius = UDim.new(0, 0)
    else
        fcCorner.CornerRadius = UDim.new(1, 0)
    end
    local t = math.clamp((Settings.FOV - MINFOV) / (MAXFOV - MINFOV), 0, 1)
    fcStroke.Transparency = math.clamp((0.35 - 0.2 * t) / math.max(0.05, CombatX.RingOpacity), 0, 1)
    fcStroke.Thickness = (2 + 2 * t) * CombatX.RingThick
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

--==================== HIT SOUNDS / EFFECTS ====================--
local SOUNDS = {
    { name = "Random" },
    { name = "Bell",  id = "rbxassetid://5276754334" },
    { name = "Ring",  id = "rbxassetid://82635963679205" },
}

lastSound = 0
local function playHitSound()
    local idx = HitFX.SoundSel
    if idx <= 1 or not SOUNDS[idx] then
        idx = math.random(2, #SOUNDS)
        if #SOUNDS > 2 and idx == lastSound then
            idx = idx + 1
            if idx > #SOUNDS then idx = 2 end
        end
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

local KILL_SOUND = "rbxassetid://5656369639"
local function playKillSound()
    local s = Instance.new("Sound")
    s.SoundId = KILL_SOUND
    s.Volume = 0.7
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 3)
end

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
        for i = 1, 8 do slash(o, Color3.fromRGB(255, 220, 80), (i / 8) * 180, 9, 0.4) end
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
        for i = 1, 12 do slash(o, Color3.fromRGB(255, 250, 220), (i / 12) * 180, 11, 0.4) end
    end },
}

local SOUND_NAMES, EFFECT_NAMES = {}, {}
for i, s in ipairs(SOUNDS)  do SOUND_NAMES[i]  = s.name end
for i, e in ipairs(EFFECTS) do EFFECT_NAMES[i] = e.name end

lastEffect = 0
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
    if not HitFX.Enabled then return end
    if HitFX.Sound then playHitSound() end
    if HitFX.Effect then playHitEffect(origin) end
end

--==================== FEEDBACK ====================--
local fbGui = Instance.new("ScreenGui")
fbGui.Name = "RomanFeedback"
fbGui.ResetOnSpawn = false
fbGui.IgnoreGuiInset = true
fbGui.DisplayOrder = 950
fbGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fbGui.Parent = GUI_PARENT

local function showHitmarker()
    if not Feedback.HitMarker then return end
    local holder = Instance.new("Frame")
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0.5, 0, 0.5, 0)
    holder.Size = UDim2.new(0, 46, 0, 46)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 100
    holder.Parent = fbGui
    local lines = {}
    for _, ang in ipairs({ 45, 135, 225, 315 }) do
        local rad = math.rad(ang)
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.Position = UDim2.new(0.5, math.cos(rad) * 12, 0.5, math.sin(rad) * 12)
        line.Size = UDim2.new(0, 10, 0, 2)
        line.Rotation = ang
        line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        line.BorderSizePixel = 0
        line.ZIndex = 100
        line.Parent = holder
        lines[#lines + 1] = line
    end
    task.spawn(function()
        for i = 1, 8 do
            local a = 1 - i / 8
            for _, l in ipairs(lines) do l.BackgroundTransparency = 1 - a end
            task.wait(0.025)
        end
        holder:Destroy()
    end)
end

local function showDamageNumber(worldPos, amount)
    if not Feedback.DamageNumbers then return end
    local sp = Camera:WorldToViewportPoint(worldPos)
    if sp.Z <= 0 then return end
    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint = Vector2.new(0.5, 1)
    lbl.Position = UDim2.new(0, sp.X, 0, sp.Y)
    lbl.Size = UDim2.new(0, 80, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 16
    lbl.TextColor3 = Color3.fromRGB(255, 235, 90)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Text = "-" .. tostring(math.floor(amount + 0.5))
    lbl.ZIndex = 99
    lbl.Parent = fbGui
    TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, sp.X, 0, sp.Y - 34),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    }):Play()
    Debris:AddItem(lbl, 0.8)
end

--==================== HEARTBEAT ====================--
lastFire = 0
firing = false
lastFX = {}
lastHP = {}
function markFire() lastFire = tick() end

RunService.Heartbeat:Connect(function()
    ammoTick()
    applyVisuals()
    if not (HitFX.Enabled or Feedback.HitMarker or Feedback.DamageNumbers or Feedback.KillNotifier) then
        return
    end
    local activeShot = firing or (tick() - lastFire) <= HitFX.Window
    if not activeShot then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and isEnemy(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                local prev = lastHP[hum]
                if prev and hum.Health < prev and prev > 0 then
                    local dmg = prev - hum.Health
                    local root = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                    if hitRelevant(plr, root) then
                        local cd = tick() - (lastFX[plr] or 0)
                        if cd >= HitFX.Cooldown then
                            lastFX[plr] = tick()
                            if root then doHitFX(root.Position) end
                            showHitmarker()
                            if root then showDamageNumber(root.Position, dmg) end
                        end
                        if hum.Health <= 0 and Feedback.KillNotifier then
                            playKillSound()
                            if notify then notify("Kill", plr.Name .. " eliminated") end
                        end
                    end
                end
                lastHP[hum] = hum.Health
            end
        end
    end
end)

--==================== SHOOT INPUT ====================--
local function tryActivate()
    local char = LocalPlayer.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
        markFire()
    end
end

local function fireTracer()
    if Tracers.Enabled then
        Tracers._last = tick()
        spawnTracer()
    end
end

Mouse.Button1Down:Connect(function()
    firing = true; markFire(); tryActivate(); fireTracer()
end)
Mouse.Button1Up:Connect(function() firing = false end)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        firing = true; markFire(); tryActivate(); fireTracer()
        if MiscX.ClickTP then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hit = Mouse.Hit
            if root and hit then
                root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
            end
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        firing = false
    end
end)

--==================== FALLING SNOW ====================--
local snowGui = Instance.new("ScreenGui")
snowGui.Name = "RomanSnow"
snowGui.ResetOnSpawn = false
snowGui.IgnoreGuiInset = true
snowGui.DisplayOrder = 500
snowGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
snowGui.Parent = GUI_PARENT

local flakes = {}

local function makeFlake()
    local f = Instance.new("Frame")
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    f.BackgroundTransparency = math.random(20, 55) / 100
    local sz = math.random(2, 5)
    f.Size = UDim2.new(0, sz, 0, sz)
    f.ZIndex = 1
    f.Parent = snowGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = f
    local vp = Camera.ViewportSize
    f.Position = UDim2.new(0, math.random(0, math.max(1, vp.X)), 0, math.random(0, math.max(1, vp.Y)))
    return {
        frame = f,
        speed = math.random(35, 95),
        drift = math.random(-18, 18),
        wob = math.random(6, 16) / 10,
        phase = math.random() * math.pi * 2,
    }
end

local function buildSnow()
    for _, fl in ipairs(flakes) do fl.frame:Destroy() end
    flakes = {}
    for _ = 1, Snow.Count do flakes[#flakes + 1] = makeFlake() end
end
buildSnow()

local function updateSnow(dt)
    if not Snow.Enabled then
        for _, fl in ipairs(flakes) do fl.frame.Visible = false end
        return
    end
    local vp = Camera.ViewportSize
    for _, fl in ipairs(flakes) do
        fl.frame.Visible = true
        local p = fl.frame.Position
        local x = p.X.Offset + (fl.drift + math.sin(tick() * fl.wob + fl.phase) * 16) * dt
        local y = p.Y.Offset + fl.speed * dt
        if y > vp.Y + 6 then
            y = -6
            x = math.random(0, math.max(1, vp.X))
        end
        if x < -8 then x = vp.X + 8
        elseif x > vp.X + 8 then x = -8 end
        fl.frame.Position = UDim2.new(0, x, 0, y)
    end
end

--==================== HUD ====================--
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "RomanHUD"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 1002
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = GUI_PARENT

local hudLabel = Instance.new("TextLabel")
hudLabel.AnchorPoint = Vector2.new(1, 0)
hudLabel.Position = UDim2.new(1, -14, 0, 12)
hudLabel.Size = UDim2.new(0, 320, 0, 20)
hudLabel.BackgroundTransparency = 1
hudLabel.Font = Enum.Font.GothamBold
hudLabel.TextSize = 13
hudLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hudLabel.TextStrokeTransparency = 0.4
hudLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hudLabel.TextXAlignment = Enum.TextXAlignment.Right
hudLabel.Text = ""
hudLabel.Parent = hudGui

wmLabel = Instance.new("TextLabel")
wmLabel.AnchorPoint = Vector2.new(0, 0)
wmLabel.Position = UDim2.new(0, 14, 0, 12)
wmLabel.Size = UDim2.new(0, 260, 0, 20)
wmLabel.BackgroundTransparency = 1
wmLabel.Font = Enum.Font.GothamBold
wmLabel.TextSize = 13
wmLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
wmLabel.TextStrokeTransparency = 0.4
wmLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
wmLabel.TextXAlignment = Enum.TextXAlignment.Left
wmLabel.Text = "Roman UI"
wmLabel.Parent = hudGui

combatGui = Instance.new("ScreenGui")
combatGui.Name = "RomanCombatHUD"
combatGui.ResetOnSpawn = false
combatGui.IgnoreGuiInset = true
combatGui.DisplayOrder = 1003
combatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
combatGui.Parent = GUI_PARENT

CombatX._infoLabel = Instance.new("TextLabel")
CombatX._infoLabel.AnchorPoint = Vector2.new(0.5, 1)
CombatX._infoLabel.Position = UDim2.new(0.5, 0, 0.5, -70)
CombatX._infoLabel.Size = UDim2.new(0, 220, 0, 18)
CombatX._infoLabel.BackgroundTransparency = 1
CombatX._infoLabel.Font = Enum.Font.GothamBold
CombatX._infoLabel.TextSize = 13
CombatX._infoLabel.TextColor3 = Color3.fromRGB(255, 235, 90)
CombatX._infoLabel.TextStrokeTransparency = 0
CombatX._infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
CombatX._infoLabel.Visible = false
CombatX._infoLabel.Parent = combatGui

local fpsFrames, fpsTimer, fpsValue = 0, tick(), 60
local hudTimer = 0
local instCount = 0
local instTimer = 0

local function updateHUD(dt)
    fpsFrames = fpsFrames + 1
    local now = tick()
    if now - fpsTimer >= 0.5 then
        fpsValue = math.floor(fpsFrames / (now - fpsTimer) + 0.5)
        fpsFrames = 0
        fpsTimer = now
    end
    if now - hudTimer < 0.4 then return end
    hudTimer = now
    if now - instTimer > 2 then
        instTimer = now
        instCount = #Workspace:GetDescendants()
    end
    local parts = {}
    if HUD.FPS then parts[#parts + 1] = "FPS: " .. tostring(fpsValue) end
    if HUD.Ping then
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        parts[#parts + 1] = "Ping: " .. tostring(ping) .. "ms"
    end
    if HUD.Clock then parts[#parts + 1] = os.date("%H:%M:%S") end
    if MiscX.PlayerCount then parts[#parts + 1] = "Players: " .. tostring(#Players:GetPlayers()) end
    if MiscX.JobId then parts[#parts + 1] = "Job: " .. string.sub(game.JobId, 1, 8) end
    if MiscX.InstanceCount then parts[#parts + 1] = "Parts: " .. tostring(instCount) end
    if MiscX.MemoryUsage then
        local mb = 0
        pcall(function() mb = math.floor(Stats:GetTotalMemoryUsageMb()) end)
        parts[#parts + 1] = "Mem: " .. tostring(mb) .. "MB"
    end
    if MiscX.SessionTimer then
        parts[#parts + 1] = "Session: " .. string.format("%d:%02d", math.floor((now - MiscX.SessionStart) / 60), math.floor((now - MiscX.SessionStart) % 60))
    end
    if CombatX.KillsHUD then parts[#parts + 1] = "Kills: " .. tostring(CombatX._kills) end
    if CombatX.Debug then parts[#parts + 1] = "Target: " .. (Target and Target.Name or "none") end
    hudLabel.Text = table.concat(parts, "   ")

    wmLabel.Visible = MiscX.Watermark
    if MiscX.Watermark then
        wmLabel.Text = "Roman UI  |  " .. tostring(fpsValue) .. " fps"
    end
end

--==================== COMPACT SIDE UI ====================--
local theme = {
    bg      = Color3.fromRGB(16, 16, 18),
    panel   = Color3.fromRGB(23, 23, 27),
    side    = Color3.fromRGB(18, 18, 21),
    row     = Color3.fromRGB(29, 29, 34),
    stroke  = Color3.fromRGB(255, 255, 255),
    text    = Color3.fromRGB(240, 240, 246),
    sub     = Color3.fromRGB(138, 138, 150),
    track   = Color3.fromRGB(55, 55, 63),
    knob    = Color3.fromRGB(235, 235, 240),
}
local ACCENT = GUI.Accent

local function corner(inst, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = inst; return c
end
local function stroke(inst, col, th, tr)
    local s = Instance.new("UIStroke"); s.Color = col or theme.stroke
    s.Thickness = th or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = inst; return s
end
local function pad(inst, l, t, r, b)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, l or 0); p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingRight = UDim.new(0, r or 0); p.PaddingBottom = UDim.new(0, b or 0)
    p.Parent = inst; return p
end

local refreshables = {}
local function onAccentChange()
    for _, f in ipairs(refreshables) do pcall(f) end
end

local ui = Instance.new("ScreenGui")
ui.Name = "VeniceUI"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ui.DisplayOrder = 1000
ui.Parent = GUI_PARENT

local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.new(0, 230, 0, 400)
toastHolder.Position = UDim2.new(1, -14, 1, -14)
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = ui
local toastLayout = Instance.new("UIListLayout")
toastLayout.FillDirection = Enum.FillDirection.Vertical
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Padding = UDim.new(0, 8)
toastLayout.Parent = toastHolder

function notify(title, desc)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 50)
    card.BackgroundColor3 = theme.panel
    card.BackgroundTransparency = 0.03
    card.BorderSizePixel = 0
    card.LayoutOrder = -tick()
    corner(card, 10)
    stroke(card, theme.stroke, 1, 0.86)
    card.Parent = toastHolder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -16)
    bar.Position = UDim2.new(0, 8, 0.5, 0)
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.BackgroundColor3 = ACCENT
    bar.BorderSizePixel = 0
    bar.Parent = card
    corner(bar, 2)
    table.insert(refreshables, function() bar.BackgroundColor3 = ACCENT end)

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1; t.Text = title
    t.Font = Enum.Font.GothamBold; t.TextSize = 13; t.TextColor3 = theme.text
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Position = UDim2.new(0, 18, 0, 7); t.Size = UDim2.new(1, -40, 0, 15)
    t.Parent = card

    local d = Instance.new("TextLabel")
    d.BackgroundTransparency = 1; d.Text = desc
    d.Font = Enum.Font.Gotham; d.TextSize = 11; d.TextColor3 = theme.sub
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.Position = UDim2.new(0, 18, 0, 24); d.Size = UDim2.new(1, -30, 0, 14)
    d.Parent = card

    local prog = Instance.new("Frame")
    prog.Size = UDim2.new(1, -24, 0, 2)
    prog.Position = UDim2.new(0, 12, 1, -6)
    prog.BackgroundColor3 = ACCENT
    prog.BorderSizePixel = 0
    prog.Parent = card
    corner(prog, 2)

    card.Position = UDim2.new(1, 40, 0, 0)
    TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0),
    }):Play()
    TweenService:Create(prog, TweenInfo.new(2.2, Enum.EasingStyle.Linear), {
        Size = UDim2.new(0, 0, 0, 2),
    }):Play()

    task.delay(2.4, function()
        TweenService:Create(card, TweenInfo.new(0.25), {
            Position = UDim2.new(1, 40, 0, 0), BackgroundTransparency = 1,
        }):Play()
        task.wait(0.3)
        card:Destroy()
    end)
end

local win = Instance.new("Frame")
win.Name = "Window"
win.AnchorPoint = Vector2.new(0, 0.5)
win.Size = UDim2.new(0, GUI.Width, 0, 540)
win.Position = UDim2.new(0, 14, 0.5, 0)
win.BackgroundColor3 = theme.bg
win.BackgroundTransparency = 1 - GUI.Opacity
win.BorderSizePixel = 0
win.Parent = ui
corner(win, 14)
stroke(win, theme.stroke, 1, 0.84)

local winScale = Instance.new("UIScale")
winScale.Scale = 1
winScale.Parent = win

local function fitWindow()
    local vp = Camera.ViewportSize
    local h = math.clamp(vp.Y - 50, 360, 620)
    win.Size = UDim2.new(0, GUI.Width, 0, h)
    local fit = math.min(1, (vp.Y - 20) / h, (vp.X - 20) / GUI.Width)
    winScale.Scale = math.clamp(fit, 0.45, 1.4) * GUI.Scale
    win.BackgroundTransparency = 1 - GUI.Opacity
end
fitWindow()
Camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 42)
top.BackgroundTransparency = 1
top.ZIndex = 2
top.Parent = win

local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 22, 0, 22)
logo.Position = UDim2.new(0, 12, 0.5, -11)
logo.BackgroundColor3 = ACCENT
logo.BorderSizePixel = 0
logo.ZIndex = 3
logo.Parent = top
corner(logo, 6)
table.insert(refreshables, function() logo.BackgroundColor3 = ACCENT end)

local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0, 8, 0, 8)
logoDot.Position = UDim2.new(0.5, -4, 0.5, -4)
logoDot.BackgroundColor3 = theme.bg
logoDot.BorderSizePixel = 0
logoDot.ZIndex = 4
logoDot.Parent = logo
corner(logoDot, 2)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1; title.Text = "ROMAN"
title.Font = Enum.Font.GothamBold; title.TextSize = 14; title.TextColor3 = theme.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 42, 0, 6); title.Size = UDim2.new(0, 160, 0, 16)
title.ZIndex = 3
title.Parent = top

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1; subtitle.Text = "made by roman"
subtitle.Font = Enum.Font.Gotham; subtitle.TextSize = 10; subtitle.TextColor3 = theme.sub
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Position = UDim2.new(0, 43, 0, 21); subtitle.Size = UDim2.new(0, 160, 0, 12)
subtitle.ZIndex = 3
subtitle.Parent = top

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
closeBtn.BackgroundTransparency = 1; closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14; closeBtn.TextColor3 = theme.sub
closeBtn.ZIndex = 3
closeBtn.Parent = top

dragging, dragStart, startPos = false, nil, nil

top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = win.Position
    end
end)
top.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                 startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local tabs = Instance.new("ScrollingFrame")
tabs.Size = UDim2.new(1, -20, 0, 38)
tabs.Position = UDim2.new(0, 10, 0, 44)
tabs.BackgroundTransparency = 1
tabs.BorderSizePixel = 0
tabs.ScrollBarThickness = 2
tabs.ScrollBarImageColor3 = theme.stroke
tabs.ScrollBarImageTransparency = 0.6
tabs.ScrollingDirection = Enum.ScrollingDirection.X
tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
tabs.ZIndex = 2
tabs.Parent = win
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local cTitle = Instance.new("TextLabel")
cTitle.BackgroundTransparency = 1; cTitle.Text = "Combat"
cTitle.Font = Enum.Font.GothamBold; cTitle.TextSize = 13; cTitle.TextColor3 = theme.text
cTitle.TextXAlignment = Enum.TextXAlignment.Left
cTitle.Position = UDim2.new(0, 12, 0, 86); cTitle.Size = UDim2.new(1, -24, 0, 16)
cTitle.ZIndex = 2
cTitle.Parent = win

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -110)
content.Position = UDim2.new(0, 10, 0, 106)
content.BackgroundTransparency = 1
content.ZIndex = 2
content.Parent = win

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = theme.stroke
scroll.ScrollBarImageTransparency = 0.5
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ZIndex = 3
scroll.Parent = content
local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding = UDim.new(0, 6)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Parent = scroll
pad(scroll, 1, 1, 7, 8)

local function baseRow(parent, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 44)
    row.BackgroundColor3 = theme.row
    row.BackgroundTransparency = 0.15
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 9)
    return row
end

local function makeToggle(parent, label, desc, getter, setter)
    local row = baseRow(parent, 44)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = theme.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = UDim2.new(0, 12, 0, 6); l.Size = UDim2.new(1, -70, 0, 15)
    l.Parent = row

    local d = Instance.new("TextLabel")
    d.BackgroundTransparency = 1; d.Text = desc or ""
    d.Font = Enum.Font.Gotham; d.TextSize = 10; d.TextColor3 = theme.sub
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.Position = UDim2.new(0, 12, 0, 22); d.Size = UDim2.new(1, -70, 0, 13)
    d.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 40, 0, 22)
    track.Position = UDim2.new(1, -50, 0.5, -11)
    track.BackgroundColor3 = theme.track
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 3, 0.5, 0)
    knob.BackgroundColor3 = theme.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 8)

    local function render()
        local on = getter()
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = on and ACCENT or theme.track }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }):Play()
    end

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1; btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        render()
        notify(label, getter() and "Enabled" or "Disabled")
    end)

    render()
    table.insert(refreshables, render)
    return { refresh = render }
end

local function makeSlider(parent, label, minV, maxV, initV, onChanged, decimals)
    local row = baseRow(parent, 44)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = theme.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = UDim2.new(0, 12, 0, 6); l.Size = UDim2.new(1, -70, 0, 15)
    l.Parent = row

    local valLbl = Instance.new("TextLabel")
    valLbl.BackgroundTransparency = 1; valLbl.Text = ""
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 12; valLbl.TextColor3 = theme.text
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Position = UDim2.new(1, -70, 0, 6); valLbl.Size = UDim2.new(0, 58, 0, 15)
    valLbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 5)
    track.Position = UDim2.new(0, 12, 0, 30)
    track.BackgroundColor3 = theme.track
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 3)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 11, 0, 11)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(0, 0, 0.5, 0)
    knob.BackgroundColor3 = theme.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 6)

    local function render(val)
        local shown = val
        if decimals and decimals > 0 then shown = string.format("%." .. decimals .. "f", val) end
        valLbl.Text = tostring(shown)
        local rel = (val - minV) / (maxV - minV)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
    end

    local drag = false
    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local raw = minV + rel * (maxV - minV)
        local val = (decimals and decimals > 0) and raw or math.floor(raw + 0.5)
        render(val); onChanged(val)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            drag = true; setFromX(input.Position.X)
        end
    end)
    track.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)

    render(initV)
    table.insert(refreshables, function() fill.BackgroundColor3 = ACCENT end)
    return { render = render }
end

local function makeCycle(parent, label, desc, options, getIndex, setIndex)
    local row = baseRow(parent, 44)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = theme.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = UDim2.new(0, 12, 0, 6); l.Size = UDim2.new(1, -100, 0, 15)
    l.Parent = row

    local d = Instance.new("TextLabel")
    d.BackgroundTransparency = 1; d.Text = desc or ""
    d.Font = Enum.Font.Gotham; d.TextSize = 10; d.TextColor3 = theme.sub
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.Position = UDim2.new(0, 12, 0, 22); d.Size = UDim2.new(1, -100, 0, 13)
    d.Parent = row

    local chip = Instance.new("Frame")
    chip.Size = UDim2.new(0, 82, 0, 24)
    chip.Position = UDim2.new(1, -92, 0.5, -12)
    chip.BackgroundColor3 = theme.track
    chip.BorderSizePixel = 0
    chip.Parent = row
    corner(chip, 8)

    local chipLbl = Instance.new("TextLabel")
    chipLbl.BackgroundTransparency = 1; chipLbl.Text = ""
    chipLbl.Font = Enum.Font.GothamBold; chipLbl.TextSize = 10; chipLbl.TextColor3 = theme.text
    chipLbl.TextTruncate = Enum.TextTruncate.AtEnd
    chipLbl.Size = UDim2.new(1, -8, 1, 0)
    chipLbl.Parent = chip

    local function render()
        chipLbl.Text = options[getIndex()] or "?"
    end

    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1; btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        local i = (getIndex() % #options) + 1
        setIndex(i)
        render()
        notify(label, options[i])
    end)

    render()
    return { render = render }
end

local PALETTE = {
    Color3.fromRGB(120, 170, 255), Color3.fromRGB(150, 120, 255),
    Color3.fromRGB(255, 95, 150),  Color3.fromRGB(255, 95, 95),
    Color3.fromRGB(255, 160, 70),  Color3.fromRGB(255, 220, 95),
    Color3.fromRGB(110, 230, 150), Color3.fromRGB(95, 230, 230),
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 162),
}

local function makeColorRow(parent, label, getColor, setColor)
    local row = baseRow(parent, 48)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextColor3 = theme.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = UDim2.new(0, 12, 0, 6); l.Size = UDim2.new(1, -20, 0, 15)
    l.Parent = row

    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Position = UDim2.new(0, 10, 0, 26)
    holder.Size = UDim2.new(1, -20, 0, 16)
    holder.Parent = row
    local hl = Instance.new("UIListLayout")
    hl.FillDirection = Enum.FillDirection.Horizontal
    hl.Padding = UDim.new(0, 4)
    hl.SortOrder = Enum.SortOrder.LayoutOrder
    hl.Parent = holder

    local swatches = {}
    local function render()
        local cur = getColor()
        for _, s in ipairs(swatches) do
            s.stroke.Transparency = (s.color == cur) and 0 or 0.7
            s.stroke.Thickness = (s.color == cur) and 2 or 1
        end
    end

    for _, col in ipairs(PALETTE) do
        local sw = Instance.new("TextButton")
        sw.Size = UDim2.new(0, 16, 0, 16)
        sw.BackgroundColor3 = col
        sw.BorderSizePixel = 0
        sw.Text = ""
        sw.Parent = holder
        corner(sw, 5)
        local st = stroke(sw, Color3.fromRGB(255, 255, 255), 1, 0.7)
        table.insert(swatches, { color = col, stroke = st })
        sw.MouseButton1Click:Connect(function()
            setColor(col)
            render()
            notify(label, "Color updated")
        end)
    end

    render()
    table.insert(refreshables, render)
    return { render = render }
end

local function makeButton(parent, label, onClick)
    local row = baseRow(parent, 40)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamBold; l.TextSize = 12; l.TextColor3 = theme.text
    l.Position = UDim2.new(0, 12, 0, 0); l.Size = UDim2.new(1, -20, 1, 0)
    l.Parent = row
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1; btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0); btn.Parent = row
    btn.MouseButton1Click:Connect(onClick)
    return row
end

local function makeHeader(parent, text)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1; lbl.Text = string.upper(text)
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10; lbl.TextColor3 = theme.sub
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Size = UDim2.new(1, -10, 0, 16)
    lbl.Parent = parent
    pad(lbl, 4, 3, 0, 0)
    return lbl
end

local sections, tabButtons = {}, {}
local uiRefs = {}

local SECTION_DEFS = {
    { id = "combat",  icon = "✚", label = "Combat",    title = "Combat" },
    { id = "hitfx",   icon = "♪", label = "Hit FX",    title = "Hit FX" },
    { id = "player",  icon = "●", label = "Player",    title = "Player" },
    { id = "gun",     icon = "▲", label = "Gun Mods",  title = "Gun Mods" },
    { id = "visuals", icon = "◉", label = "Visuals",   title = "Visuals" },
    { id = "misc",    icon = "★", label = "Misc",      title = "Misc" },
    { id = "colors",  icon = "■", label = "Colors",    title = "Colors" },
    { id = "anims",   icon = "✦", label = "Animations",title = "Animations" },
    { id = "config",  icon = "⚙", label = "Config",    title = "Config" },
}

local function showSection(id)
    for sid, f in pairs(sections) do f.Visible = (sid == id) end
    for sid, b in pairs(tabButtons) do
        local on = (sid == id)
        b.bg.BackgroundColor3 = on and theme.row or theme.side
        b.accent.Visible = on
        b.lbl.TextColor3 = on and theme.text or theme.sub
    end
    for _, def in ipairs(SECTION_DEFS) do
        if def.id == id then cTitle.Text = def.title end
    end
end

for i, def in ipairs(SECTION_DEFS) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 66, 0, 34)
    b.BackgroundColor3 = theme.side
    b.BackgroundTransparency = 0.2
    b.BorderSizePixel = 0
    b.Text = ""
    b.LayoutOrder = i
    b.Parent = tabs
    corner(b, 8)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(1, -14, 0, 2)
    accent.Position = UDim2.new(0.5, 0, 1, -4)
    accent.AnchorPoint = Vector2.new(0.5, 0)
    accent.BackgroundColor3 = ACCENT
    accent.BorderSizePixel = 0
    accent.Visible = false
    accent.Parent = b
    corner(accent, 1)
    table.insert(refreshables, function() accent.BackgroundColor3 = ACCENT end)

    local icon = Instance.new("TextLabel")
    icon.BackgroundTransparency = 1; icon.Text = def.icon
    icon.Font = Enum.Font.GothamBold; icon.TextSize = 12; icon.TextColor3 = theme.sub
    icon.Position = UDim2.new(0, 0, 0, 3); icon.Size = UDim2.new(1, 0, 0, 14)
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.Parent = b

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1; lbl.Text = def.label
    lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 9; lbl.TextColor3 = theme.sub
    lbl.Position = UDim2.new(0, 0, 0, 17); lbl.Size = UDim2.new(1, 0, 0, 12)
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Parent = b

    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, 0, 1, 0)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 3
    contentFrame.ScrollBarImageColor3 = theme.stroke
    contentFrame.ScrollBarImageTransparency = 0.5
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentFrame.Visible = false
    contentFrame.Parent = scroll
    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 6)
    cl.SortOrder = Enum.SortOrder.LayoutOrder
    cl.Parent = contentFrame

    sections[def.id] = contentFrame
    tabButtons[def.id] = { bg = b, accent = accent, lbl = lbl }

    b.MouseButton1Click:Connect(function() showSection(def.id) end)
end

--==================== COMBAT (57 features) ====================--
do
    local p = sections.combat
    makeHeader(p, "aim")
    uiRefs.silent = makeToggle(p, "Silent Aim", "Redirect shots to target",
        function() return Settings.Enabled end,
        function(v) Settings.Enabled = v; if not v then Target, TargetPart = nil, nil end end)
    makeCycle(p, "Aim Mode", "Toggle or hold to aim", { "Toggle", "Hold" },
        function() return (CombatX.AimMode == "Hold") and 2 or 1 end,
        function(i) CombatX.AimMode = (i == 2) and "Hold" or "Toggle" end)
    makeCycle(p, "Hold Key", "Key used in hold mode", { "LeftAlt", "LeftControl", "E", "R", "T", "G", "V" },
        function()
            local opts = { "LeftAlt", "LeftControl", "E", "R", "T", "G", "V" }
            for i, o in ipairs(opts) do if o == CombatX.HoldKey.Name then return i end end
            return 1
        end,
        function(i)
            local opts = { "LeftAlt", "LeftControl", "E", "R", "T", "G", "V" }
            CombatX.HoldKey = Enum.KeyCode[opts[i]]
        end)
    makeCycle(p, "Aim Part", "Hitbox to target", { "Head", "Torso" },
        function() return (Settings.AimPart == "Head") and 1 or 2 end,
        function(i) Settings.AimPart = (i == 1) and "Head" or "Torso"; Target, TargetPart = nil, nil end)
    makeCycle(p, "Target Mode", "How the best target is picked", { "Crosshair", "Distance", "Health", "Threat" },
        function()
            local opts = { "Crosshair", "Distance", "Health", "Threat" }
            for i, o in ipairs(opts) do if o == CombatX.TargetMode then return i end end
            return 1
        end,
        function(i) CombatX.TargetMode = ({ "Crosshair", "Distance", "Health", "Threat" })[i] end)
    makeToggle(p, "Sticky Target", "Keep target until out of range",
        function() return CombatX.Sticky end, function(v) CombatX.Sticky = v end)
    makeSlider(p, "FOV", MINFOV, MAXFOV, Settings.FOV, function(v) Settings.FOV = v end)
    makeCycle(p, "FOV Shape", "Ring shape", { "Circle", "Square" },
        function() return (CombatX.RingShape == "Square") and 2 or 1 end,
        function(i) CombatX.RingShape = (i == 2) and "Square" or "Circle" end)
    makeToggle(p, "Show FOV Ring", "Draw the FOV circle",
        function() return CombatX.ShowRing end, function(v) CombatX.ShowRing = v end)
    makeSlider(p, "Ring Thickness", 0.2, 3, CombatX.RingThick, function(v) CombatX.RingThick = v end, 2)
    makeSlider(p, "Ring Opacity", 0.1, 1, CombatX.RingOpacity, function(v) CombatX.RingOpacity = v end, 2)
    makeToggle(p, "Aim Smoothing", "Smoothly slide onto target",
        function() return CombatX.SmoothOn end, function(v) CombatX.SmoothOn = v; CombatX._aimPoint = nil end)
    makeSlider(p, "Smoothing", 0.05, 1, CombatX.Smooth, function(v) CombatX.Smooth = v end, 2)
    makeToggle(p, "Aim Offset", "Shift the aim point",
        function() return CombatX.OffsetEnabled end, function(v) CombatX.OffsetEnabled = v end)
    makeSlider(p, "Offset X", -5, 5, CombatX.OffX, function(v) CombatX.OffX = v end, 2)
    makeSlider(p, "Offset Y", -5, 5, CombatX.OffY, function(v) CombatX.OffY = v end, 2)
    makeSlider(p, "Offset Z", -5, 5, CombatX.OffZ, function(v) CombatX.OffZ = v end, 2)
    makeToggle(p, "Prediction", "Lead moving targets",
        function() return Settings.Predict end, function(v) Settings.Predict = v end)
    makeSlider(p, "Projectile Speed", 100, 3000, Settings.ProjectileSpeed, function(v) Settings.ProjectileSpeed = v end)
    makeSlider(p, "Max Lead", 0, 1, Settings.MaxLead, function(v) Settings.MaxLead = v end, 2)
    makeSlider(p, "Lead Multiplier", 0, 3, CombatX.PredMul, function(v) CombatX.PredMul = v end, 2)
    makeSlider(p, "Min Distance", 0, 500, CombatX.MinDist, function(v) CombatX.MinDist = v end)
    makeSlider(p, "Max Distance", 0, 2000, CombatX.MaxDist, function(v) CombatX.MaxDist = v end)
    makeSlider(p, "Health Below", 0, 1000, CombatX.HealthBelow, function(v) CombatX.HealthBelow = v end)
    makeButton(p, "Re-scan Rapid Fire Targets", function()
        RapidFire._lastScan = 0; RapidFireScan(); notify("Rapid Fire", "Re-scanning")
    end)

    makeHeader(p, "target visuals")
    makeToggle(p, "Target Highlight", "Outline the target",
        function() return Settings.ShowTarget end, function(v) Settings.ShowTarget = v end)
    makeSlider(p, "Highlight Fill", 0, 1, CombatX.HighlightFill, function(v) CombatX.HighlightFill = v end, 2)
    makeSlider(p, "Highlight Outline", 0, 1, CombatX.HighlightOutline, function(v) CombatX.HighlightOutline = v end, 2)
    makeToggle(p, "Target Ring", "Pulsing outline ring on target",
        function() return CombatX.TargetRing end, function(v) CombatX.TargetRing = v end)
    makeToggle(p, "Target Tracer", "Persistent line to target",
        function() return CombatX.TargetTracer end, function(v) CombatX.TargetTracer = v end)
    makeColorRow(p, "Tracer Color", function() return CombatX.TracerColor end,
        function(c) CombatX.TracerColor = c end)
    makeToggle(p, "Target Info", "Name / health / distance over target",
        function() return CombatX.TargetInfo end, function(v) CombatX.TargetInfo = v end)
    makeToggle(p, "Camera Lock", "Camera follows the target",
        function() return CombatX.CameraLock end, function(v) CombatX.CameraLock = v end)
    makeSlider(p, "Lock Strength", 0.02, 1, CombatX.LockStrength, function(v) CombatX.LockStrength = v end, 2)

    makeHeader(p, "automation")
    makeToggle(p, "Trigger Bot", "Fire when crosshair is on target",
        function() return CombatX.TriggerBot end, function(v) CombatX.TriggerBot = v end)
    makeSlider(p, "Trigger Delay", 0, 0.5, CombatX.TriggerDelay, function(v) CombatX.TriggerDelay = v end, 2)
    makeSlider(p, "Trigger Radius", 2, 200, CombatX.TriggerRadius, function(v) CombatX.TriggerRadius = v end)
    makeToggle(p, "Auto Shoot", "Fire continuously at target",
        function() return CombatX.AutoShoot end, function(v) CombatX.AutoShoot = v end)
    makeSlider(p, "Shoot Interval", 0.02, 1, CombatX.ShootInterval, function(v) CombatX.ShootInterval = v end, 2)
    makeToggle(p, "Auto Reload On Kill", "Reload after a kill",
        function() return CombatX.AutoReloadOnKill end, function(v) CombatX.AutoReloadOnKill = v end)
    makeToggle(p, "Multi Target", "Cycle between targets",
        function() return CombatX.MultiTarget end, function(v) CombatX.MultiTarget = v end)
    makeSlider(p, "Switch Delay", 0, 2, CombatX.SwitchDelay, function(v) CombatX.SwitchDelay = v end, 2)

    makeHeader(p, "checks / tuning")
    makeToggle(p, "Visible Only", "Require line of sight",
        function() return Settings.VisibleCheck end, function(v) Settings.VisibleCheck = v end)
    makeToggle(p, "Team Check", "Ignore teammates",
        function() return Settings.TeamCheck end, function(v) Settings.TeamCheck = v end)
    makeToggle(p, "Ignore Knocked", "Skip downed players",
        function() return Settings.IgnoreKnocked end, function(v) Settings.IgnoreKnocked = v end)
    makeToggle(p, "Ignore Dead", "Skip dead players",
        function() return CombatX.IgnoreDead end, function(v) CombatX.IgnoreDead = v end)
    makeToggle(p, "Wallbang", "Ignore walls entirely",
        function() return CombatX.Wallbang end, function(v) CombatX.Wallbang = v end)
    makeToggle(p, "Anti-Kick", "Block kick calls",
        function() return Settings.AntiKick end, function(v) Settings.AntiKick = v end)
    makeToggle(p, "Anti-Recoil", "Pull camera back while firing",
        function() return CombatX.AntiRecoil end, function(v) CombatX.AntiRecoil = v; CombatX._recoilPitch = nil end)
    makeSlider(p, "Recoil Reduction", 0, 1, CombatX.RecoilReduction, function(v) CombatX.RecoilReduction = v end, 2)
    makeToggle(p, "No Spread", "Reduce spread (best effort)",
        function() return CombatX.NoSpread end, function(v) CombatX.NoSpread = v end)
    makeToggle(p, "Instant Hit", "Zero prediction, max speed",
        function() return CombatX.InstantHit end,
        function(v)
            CombatX.InstantHit = v
            if v then Settings.ProjectileSpeed = 3000; Settings.MaxLead = 0 end
        end)
    makeToggle(p, "Silent Camera Snap", "Snap camera to target too",
        function() return CombatX.SilentCamera end, function(v) CombatX.SilentCamera = v end)

    makeHeader(p, "stats")
    makeToggle(p, "Kill Counter", "Count kills you get",
        function() return CombatX.KillCounter end, function(v) CombatX.KillCounter = v end)
    makeToggle(p, "Kills HUD", "Show kill count on HUD",
        function() return CombatX.KillsHUD end, function(v) CombatX.KillsHUD = v end)
    makeToggle(p, "Debug", "Show target debug on HUD",
        function() return CombatX.Debug end, function(v) CombatX.Debug = v end)
    makeButton(p, "Reset Aim Settings", function()
        Settings.FOV = 60; CombatX.Smooth = 0.35; CombatX.SmoothOn = false
        CombatX.OffX, CombatX.OffY, CombatX.OffZ = 0, 0, 0
        CombatX.OffsetEnabled = false; CombatX.PredMul = 1
        CombatX.MinDist, CombatX.MaxDist, CombatX.HealthBelow = 0, 0, 0
        CombatX.Sticky, CombatX.MultiTarget = false, false
        notify("Combat", "Aim settings reset")
    end)
end

--==================== HIT FX ====================--
do
    local p = sections.hitfx
    makeHeader(p, "sounds")
    makeToggle(p, "Hit FX", "Master toggle for hit feedback",
        function() return HitFX.Enabled end, function(v) HitFX.Enabled = v end)
    makeToggle(p, "Hit Sounds", "Play sound on confirmed hit",
        function() return HitFX.Sound end, function(v) HitFX.Sound = v end)
    makeCycle(p, "Sound", "Pick a hit sound", SOUND_NAMES,
        function() return HitFX.SoundSel end, function(i) HitFX.SoundSel = i end)
    makeHeader(p, "effects")
    makeToggle(p, "Hit Effects", "Play visual on confirmed hit",
        function() return HitFX.Effect end, function(v) HitFX.Effect = v end)
    makeCycle(p, "Effect", "Pick a hit effect", EFFECT_NAMES,
        function() return HitFX.EffectSel end, function(i) HitFX.EffectSel = i end)
    makeHeader(p, "markers")
    makeToggle(p, "Hit Marker", "Crosshair marker on hit",
        function() return Feedback.HitMarker end, function(v) Feedback.HitMarker = v end)
    makeToggle(p, "Damage Numbers", "Floating damage text",
        function() return Feedback.DamageNumbers end, function(v) Feedback.DamageNumbers = v end)
    makeToggle(p, "Kill Notifier", "Sound + toast on kill",
        function() return Feedback.KillNotifier end, function(v) Feedback.KillNotifier = v end)
    makeHeader(p, "tuning")
    makeToggle(p, "Strict Mode", "Only FX on your locked target",
        function() return Feedback.Strict end, function(v) Feedback.Strict = v end)
    makeSlider(p, "Hit Cone", 10, 300, Feedback.Cone, function(v) Feedback.Cone = v end)
    makeSlider(p, "Volume", 0, 2, HitFX.Volume, function(v) HitFX.Volume = v end, 2)
    makeSlider(p, "Hit Window", 0.05, 1, HitFX.Window, function(v) HitFX.Window = v end, 2)
    makeSlider(p, "Cooldown", 0.02, 0.5, HitFX.Cooldown, function(v) HitFX.Cooldown = v end, 2)
end

--==================== PLAYER ====================--
do
    local p = sections.player
    makeHeader(p, "movement")
    makeToggle(p, "Walkspeed", "Override walk speed",
        function() return Settings.WalkspeedEnabled end,
        function(v)
            Settings.WalkspeedEnabled = v
            if not v then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then hum.WalkSpeed = baseWalk end
            end
        end)
    makeSlider(p, "Speed", 1, 50, Settings.Walkspeed, function(v) Settings.Walkspeed = v end)
    uiRefs.noclip = makeToggle(p, "Noclip", "Walk through walls",
        function() return Noclip.Enabled end,
        function(v) Noclip.Enabled = v; if not v then restoreCollide() end end)
    uiRefs.fly = makeToggle(p, "Fly", "WASD / thumbstick to fly (F)",
        function() return Fly.Enabled end,
        function(v)
            Fly.Enabled = v
            if v then
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then root.CFrame = root.CFrame + Vector3.new(0, 6, 0) end
                applyFly()
            else
                stopFly()
            end
        end)
    makeSlider(p, "Fly Speed", 10, 300, Fly.Speed, function(v) Fly.Speed = v end)
    makeToggle(p, "Infinite Jump", "Jump mid-air",
        function() return Move.InfiniteJump end, function(v) Move.InfiniteJump = v end)
    makeToggle(p, "Anti-AFK", "Stay online",
        function() return Move.AntiAFK end, function(v) Move.AntiAFK = v end)
end

--==================== GUN MODS ====================--
do
    local p = sections.gun
    makeHeader(p, "reload")
    uiRefs.instant = makeToggle(p, "Instant Reload", "Refill mag instantly (no downtime)",
        function() return InstantReload.Enabled end,
        function(v)
            InstantReload.Enabled = v
            InstantReload._max = {}
            rebuildAmmoCache()
        end)
    makeToggle(p, "Keep Reserve", "Also top up reserve ammo",
        function() return InstantReload.Reserve end, function(v) InstantReload.Reserve = v end)
    makeSlider(p, "Reload Target", 0, 200, InstantReload.Target,
        function(v) InstantReload.Target = v end)
    makeButton(p, "Relearn Mag Size", function()
        InstantReload._max = {}
        notify("Instant Reload", "Mag size re-learned")
    end)
    makeToggle(p, "Auto Reload", "Press R when empty",
        function() return AutoReload.Enabled end, function(v) AutoReload.Enabled = v end)

    makeHeader(p, "fire rate")
    uiRefs.rapidfire = makeToggle(p, "Rapid Fire", "Force max fire rate (chunked scan)",
        function() return RapidFire.Enabled end,
        function(v)
            RapidFire.Enabled = v
            if v then RapidFire._lastScan = 0; RapidFireScan() else RapidFireRestore() end
        end)
    makeSlider(p, "Fire Rate", 0.001, 0.5, RapidFire.Override,
        function(v) RapidFire.Override = v end, 3)
    makeToggle(p, "Only If Slower", "Keep values already faster than yours",
        function() return RapidFire.OnlyIfHigher end, function(v) RapidFire.OnlyIfHigher = v end)
    makeToggle(p, "Loose Match", "Also match any 'rate'/'speed' attribute",
        function() return RapidFire.Loose end,
        function(v) RapidFire.Loose = v; RapidFire._memo = {} end)
    makeSlider(p, "Apply Rate", 0.05, 0.5, RapidFire.Interval,
        function(v) RapidFire.Interval = v end, 2)
    makeSlider(p, "Scan Rate", 0.5, 5, RapidFire.ScanInterval,
        function(v) RapidFire.ScanInterval = v end, 2)

    makeHeader(p, "tracers")
    makeToggle(p, "Neon Tracers", "Muzzle neon tracer (replaces default)",
        function() return Tracers.Enabled end, function(v) Tracers.Enabled = v end)
    makeColorRow(p, "Tracer Color", function() return Tracers.Color end,
        function(c) Tracers.Color = c end)
    makeSlider(p, "Tracer Width", 0.02, 0.5, Tracers.Width,
        function(v) Tracers.Width = v end, 2)
end

--==================== VISUALS ====================--
do
    local p = sections.visuals
    makeHeader(p, "esp")
    makeToggle(p, "ESP", "Draw players through walls",
        function() return ESP.Enabled end, function(v) ESP.Enabled = v end)
    local STYLE_LABELS = { "Box+Name+Skeleton", "Box+Name", "Box Only", "Name+Skeleton", "Skeleton Only" }
    local STYLE_DATA = {
        { true, true, true }, { true, true, false }, { true, false, false },
        { false, true, true }, { false, false, true },
    }
    makeCycle(p, "ESP Style", "What to draw", STYLE_LABELS,
        function()
            for i, s in ipairs(STYLE_DATA) do
                if s[1] == ESP.Boxes and s[2] == ESP.Names and s[3] == ESP.Skeleton then return i end
            end
            return 1
        end,
        function(i)
            local s = STYLE_DATA[i]
            ESP.Boxes, ESP.Names, ESP.Skeleton = s[1], s[2], s[3]
        end)

    makeHeader(p, "chams")
    uiRefs.chams = makeToggle(p, "Chams", "Recolor your own character",
        function() return Chams.Enabled end,
        function(v)
            Chams.Enabled = v
            if v then applyChams() else restoreChams() end
        end)
    makeToggle(p, "Neon Glow", "Add glow outline + light",
        function() return Chams.Neon end,
        function(v) Chams.Neon = v; applyChams() end)
    makeToggle(p, "Glow", "Outline glow + light",
        function() return Chams.Glow end,
        function(v) Chams.Glow = v; applyChams() end)
    makeCycle(p, "Chams Material", "Body material", CHAMS_MATERIALS,
        function()
            for i, m in ipairs(CHAMS_MATERIALS) do
                if m == Chams.Material then return i end
            end
            return 1
        end,
        function(i) Chams.Material = CHAMS_MATERIALS[i]; applyChams() end)
    makeColorRow(p, "Chams Color", function() return Chams.Color end,
        function(c) Chams.Color = c; applyChams() end)
    makeSlider(p, "Chams Transparency", 0, 0.9, Chams.Transparency,
        function(v) Chams.Transparency = v; applyChams() end, 2)

    makeHeader(p, "hitbox")
    makeToggle(p, "Hitbox Expander", "Enlarge player hitboxes",
        function() return Hitbox.Enabled end,
        function(v)
            Hitbox.Enabled = v
            if v then applyHitbox() else restoreHitbox() end
        end)
    makeToggle(p, "Hitbox Team Check", "Only expand enemies",
        function() return Hitbox.TeamCheck end,
        function(v) Hitbox.TeamCheck = v; applyHitbox() end)
    makeSlider(p, "Hitbox X", 2, 40, Hitbox.Size.X, function(v)
        Hitbox.Size = Vector3.new(v, Hitbox.Size.Y, Hitbox.Size.Z); applyHitbox() end, 1)
    makeSlider(p, "Hitbox Y", 2, 40, Hitbox.Size.Y, function(v)
        Hitbox.Size = Vector3.new(Hitbox.Size.X, v, Hitbox.Size.Z); applyHitbox() end, 1)
    makeSlider(p, "Hitbox Z", 2, 40, Hitbox.Size.Z, function(v)
        Hitbox.Size = Vector3.new(Hitbox.Size.X, Hitbox.Size.Y, v); applyHitbox() end, 1)
    makeSlider(p, "Hitbox Transparency", 0, 1, Hitbox.Transparency,
        function(v) Hitbox.Transparency = v; applyHitbox() end, 2)
end

--==================== MISC (73 features) ====================--
do
    local p = sections.misc

    makeHeader(p, "hud")
    makeToggle(p, "Watermark", "Show script watermark",
        function() return MiscX.Watermark end,
        function(v) MiscX.Watermark = v; if wmLabel then wmLabel.Visible = v end end)
    makeToggle(p, "FPS Counter", "Show frames per second",
        function() return HUD.FPS end, function(v) HUD.FPS = v end)
    makeToggle(p, "Ping", "Show server ping",
        function() return HUD.Ping end, function(v) HUD.Ping = v end)
    makeToggle(p, "Clock", "Show local time",
        function() return HUD.Clock end, function(v) HUD.Clock = v end)
    makeToggle(p, "Player Count", "Show player count",
        function() return MiscX.PlayerCount end, function(v) MiscX.PlayerCount = v end)
    makeToggle(p, "Job ID", "Show server job id",
        function() return MiscX.JobId end, function(v) MiscX.JobId = v end)
    makeButton(p, "Copy Job ID", function()
        pcall(function() setclipboard(game.JobId) end)
        notify("Server", "Job ID copied")
    end)
    makeToggle(p, "Instance Count", "Show workspace part count",
        function() return MiscX.InstanceCount end, function(v) MiscX.InstanceCount = v end)
    makeToggle(p, "Memory Usage", "Show memory in MB",
        function() return MiscX.MemoryUsage end, function(v) MiscX.MemoryUsage = v end)
    makeToggle(p, "Session Timer", "Show time in session",
        function() return MiscX.SessionTimer end, function(v) MiscX.SessionTimer = v end)

    makeHeader(p, "world")
    makeToggle(p, "Fullbright", "Brighten lighting",
        function() return Visual.Fullbright end,
        function(v) Visual.Fullbright = v; setFullbright(v) end)
    makeToggle(p, "No Fog", "Remove distance fog",
        function() return Visual.NoFog end,
        function(v) Visual.NoFog = v; setNoFog(v) end)
    makeColorRow(p, "Fog Color", function() return MiscX.FogColor end,
        function(c) MiscX.FogColor = c; if MiscX.FogOn then Lighting.FogColor = c end end)
    makeSlider(p, "Fog Distance", 0, 5000, MiscX.FogEnd,
        function(v) MiscX.FogEnd = v; if MiscX.FogOn then Lighting.FogEnd = v end end)
    makeToggle(p, "Custom Fog", "Use your own fog distance",
        function() return MiscX.FogOn end,
        function(v) MiscX.FogOn = v; if v then Lighting.FogEnd = MiscX.FogEnd; Lighting.FogColor = MiscX.FogColor end end)
    makeSlider(p, "Ambient", 0, 1, MiscX.AmbientV,
        function(v) MiscX.AmbientV = v; if MiscX.AmbientOn then Lighting.Ambient = Color3.new(v, v, v) end end, 2)
    makeToggle(p, "Custom Ambient", "Use your own ambient light",
        function() return MiscX.AmbientOn end,
        function(v) MiscX.AmbientOn = v; if v then Lighting.Ambient = Color3.new(MiscX.AmbientV, MiscX.AmbientV, MiscX.AmbientV) end end)
    makeSlider(p, "Time of Day", 0, 24, MiscX.ClockTime,
        function(v) MiscX.ClockTime = v; if MiscX.TimeOn then Lighting.ClockTime = v end end, 1)
    makeToggle(p, "Custom Time", "Lock the time of day",
        function() return MiscX.TimeOn end,
        function(v) MiscX.TimeOn = v; if v then Lighting.ClockTime = MiscX.ClockTime end end)
    makeToggle(p, "Bloom", "Enable bloom",
        function() return MiscX.Bloom end, function(v) MiscX.Bloom = v; setPostFx("Bloom", "Bloom", { Intensity = 0.6, Size = 24 }, v) end)
    makeToggle(p, "Blur", "Enable blur",
        function() return MiscX.Blur end, function(v) MiscX.Blur = v; setPostFx("Blur", "Blur", { Size = 8 }, v) end)
    makeToggle(p, "Depth of Field", "Enable DOF",
        function() return MiscX.DOF end, function(v) MiscX.DOF = v; setPostFx("DOF", "DepthOfField", { FarIntensity = 0.3 }, v) end)
    makeToggle(p, "Saturation", "Boost color saturation",
        function() return MiscX.ColorCorr end,
        function(v) MiscX.ColorCorr = v; setPostFx("CC", "ColorCorrectionEffect", { Saturation = 0.3, Contrast = 0.08 }, v) end)
    makeToggle(p, "Sun Rays", "Enable sun rays",
        function() return MiscX.SunRays end, function(v) MiscX.SunRays = v; setPostFx("Sun", "SunRaysEffect", { Intensity = 0.15 }, v) end)
    makeToggle(p, "Global Shadows", "Toggle world shadows",
        function() return MiscX.Shadows end,
        function(v) MiscX.Shadows = v; Lighting.GlobalShadows = v end)
    makeToggle(p, "Remove Skybox", "Hide custom sky",
        function() return MiscX.SkyOff end, function(v) MiscX.SkyOff = v; setSkyOff(v) end)
    makeToggle(p, "No Particles", "Disable world particle FX",
        function() return NoParts.Enabled end, function(v) NoParts.Enabled = v; setNoParticles(v) end)
    makeToggle(p, "Water Waves", "Toggle terrain water animation",
        function() return MiscX.Water end,
        function(v)
            MiscX.Water = v
            pcall(function()
                Workspace.Terrain.WaterWaveSize = v and 0.15 or 0
                Workspace.Terrain.WaterWaveSpeed = v and 10 or 0
            end)
        end)

    makeHeader(p, "camera")
    makeSlider(p, "Camera FOV", 20, 120, MiscX.CamFOV,
        function(v) MiscX.CamFOV = v; if MiscX.CamFOVOn then Camera.FieldOfView = v end end)
    makeToggle(p, "Custom FOV", "Use your own camera FOV",
        function() return MiscX.CamFOVOn end,
        function(v) MiscX.CamFOVOn = v; if v then Camera.FieldOfView = MiscX.CamFOV end end)
    makeSlider(p, "Max Zoom", 20, 2000, MiscX.MaxZoom,
        function(v) MiscX.MaxZoom = v; if MiscX.MaxZoomOn then LocalPlayer.CameraMaxZoomDistance = v end end)
    makeToggle(p, "Custom Max Zoom", "Change how far you can zoom",
        function() return MiscX.MaxZoomOn end,
        function(v) MiscX.MaxZoomOn = v; if v then LocalPlayer.CameraMaxZoomDistance = MiscX.MaxZoom end end)
    makeToggle(p, "First Person", "Lock to first person",
        function() return MiscX.FirstPerson end,
        function(v)
            MiscX.FirstPerson = v
            LocalPlayer.CameraMode = v and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
        end)
    makeToggle(p, "Shift Lock", "Center the mouse",
        function() return MiscX.ShiftLock end,
        function(v)
            MiscX.ShiftLock = v
            UserInputService.MouseBehavior = v and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
        end)
    makeToggle(p, "No Head Bob", "Reduce camera bob (best effort)",
        function() return MiscX.NoHeadBob end, function(v) MiscX.NoHeadBob = v end)

    makeHeader(p, "movement")
    makeSlider(p, "Gravity", 0, 500, MiscX.Gravity,
        function(v) MiscX.Gravity = v; if MiscX.GravityOn then Workspace.Gravity = v end end, 1)
    makeToggle(p, "Custom Gravity", "Use your own gravity",
        function() return MiscX.GravityOn end,
        function(v) MiscX.GravityOn = v; Workspace.Gravity = v and MiscX.Gravity or 196.2 end)
    makeSlider(p, "Jump Power", 10, 500, MiscX.JumpPower, function(v) MiscX.JumpPower = v; applyJump() end)
    makeToggle(p, "Custom Jump", "Use your own jump power",
        function() return MiscX.JumpOn end, function(v) MiscX.JumpOn = v; applyJump() end)
    makeSlider(p, "Hip Height", -5, 20, MiscX.HipHeight, function(v) MiscX.HipHeight = v; applyHip() end, 1)
    makeToggle(p, "Custom Hip Height", "Change your hip height",
        function() return MiscX.HipOn end, function(v) MiscX.HipOn = v; applyHip() end)
    makeToggle(p, "Auto Jump", "Jump automatically",
        function() return MiscX.AutoJump end, function(v) MiscX.AutoJump = v end)
    makeToggle(p, "Sprint", "Faster walkspeed",
        function() return MiscX.Sprint end, function(v) MiscX.Sprint = v end)
    makeSlider(p, "Sprint Speed", 17, 200, MiscX.SprintSpeed, function(v) MiscX.SprintSpeed = v end)
    makeToggle(p, "Crouch", "Slower walkspeed",
        function() return MiscX.Crouch end, function(v) MiscX.Crouch = v end)
    makeSlider(p, "Crouch Speed", 1, 16, MiscX.CrouchSpeed, function(v) MiscX.CrouchSpeed = v end)
    makeToggle(p, "Click Teleport", "Teleport to where you click",
        function() return MiscX.ClickTP end, function(v) MiscX.ClickTP = v end)
    makeToggle(p, "Anti-Void", "Save yourself from falling",
        function() return MiscX.AntiVoid end, function(v) MiscX.AntiVoid = v end)
    makeSlider(p, "Anti-Void Y", -500, 0, MiscX.AntiVoidY, function(v) MiscX.AntiVoidY = v end)
    makeToggle(p, "Freeze", "Anchor your character",
        function() return MiscX.Freeze end, function(v) MiscX.Freeze = v; applyFreeze() end)
    makeToggle(p, "Face Camera", "Character faces where you look",
        function() return MiscX.FaceCam end, function(v) MiscX.FaceCam = v end)
    makeToggle(p, "Anti-Fling", "Clamp crazy velocity",
        function() return MiscX.AntiFling end, function(v) MiscX.AntiFling = v end)
    makeSlider(p, "Anti-Fling Max", 50, 1000, MiscX.AntiFlingMax, function(v) MiscX.AntiFlingMax = v end)
    makeToggle(p, "Desync", "Lagged position (best effort)",
        function() return MiscX.Desync end, function(v) MiscX.Desync = v end)

    makeHeader(p, "character")
    makeSlider(p, "Transparency", 0, 1, MiscX.CharTrans,
        function(v) MiscX.CharTrans = v; applyCharTrans() end, 2)
    makeToggle(p, "Custom Transparency", "Set your own transparency",
        function() return MiscX.CharTransOn end, function(v) MiscX.CharTransOn = v; applyCharTrans() end)
    makeToggle(p, "Hide Accessories", "Remove hats and extras",
        function() return MiscX.HideAcc end, function(v) MiscX.HideAcc = v; applyAccessories() end)
    makeToggle(p, "Hide Nametags", "Hide health/name tags",
        function() return MiscX.HideNames end, function(v) MiscX.HideNames = v; applyNametags() end)
    makeToggle(p, "Character Trail", "Trail behind you",
        function() return Trail.Enabled end, function(v) Trail.Enabled = v; updateTrail() end)
    makeColorRow(p, "Trail Color", function() return Trail.Color end, function(c) Trail.Color = c end)
    makeToggle(p, "Falling Snow", "Snow overlay",
        function() return Snow.Enabled end, function(v) Snow.Enabled = v end)
    makeSlider(p, "Snow Amount", 20, 200, Snow.Count, function(v) Snow.Count = v; buildSnow() end)

    makeHeader(p, "sound")
    makeToggle(p, "Mute Game", "Mute all sounds",
        function() return MiscX.MuteGame end,
        function(v) MiscX.MuteGame = v; SoundService.Volume = v and 0 or MiscX.Volume end)
    makeSlider(p, "Master Volume", 0, 3, MiscX.Volume,
        function(v) MiscX.Volume = v; if not MiscX.MuteGame then SoundService.Volume = v end end, 2)
    makeButton(p, "Play Song", function() playSong() notify("Music", "Playing") end)
    makeButton(p, "Test Notification", function() notify("Test", "This is a toast") end)

    makeHeader(p, "session / server")
    makeButton(p, "Reset Character", function()
        local char = LocalPlayer.Character
        if char then pcall(function() char:BreakJoints() end) end
    end)
    makeButton(p, "Teleport to Spawn", function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(0, 60, 0) end
        notify("Teleport", "Sent to spawn area")
    end)
    makeButton(p, "Save Position", function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then MiscX._savedPos = root.CFrame; notify("Position", "Saved") end
    end)
    makeButton(p, "Load Position", function()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and MiscX._savedPos then root.CFrame = MiscX._savedPos; notify("Position", "Loaded") end
    end)
    makeToggle(p, "Auto Respawn", "Respawn automatically on death",
        function() return MiscX.AutoRespawn end, function(v) MiscX.AutoRespawn = v end)
    makeToggle(p, "FPS Unlock", "Remove the FPS cap",
        function() return MiscX.FpsUnlock end,
        function(v)
            MiscX.FpsUnlock = v
            if type(setfpscap) == "function" then
                pcall(function() setfpscap(v and MiscX.FpsCap or 60) end)
            end
        end)
    makeSlider(p, "FPS Cap", 30, 500, MiscX.FpsCap,
        function(v) MiscX.FpsCap = v; if MiscX.FpsUnlock and type(setfpscap) == "function" then pcall(function() setfpscap(v) end) end end)
    makeToggle(p, "Auto Clicker", "Auto activate tool",
        function() return MiscX.AutoClicker end, function(v) MiscX.AutoClicker = v end)
    makeSlider(p, "Auto Clicker CPS", 1, 60, MiscX.AutoClickerCPS, function(v) MiscX.AutoClickerCPS = v end)
    makeButton(p, "Rejoin Server", function()
        notify("Rejoin", "Teleporting...")
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
    makeButton(p, "Server Hop", function()
        notify("Server Hop", "Searching...")
        task.spawn(function()
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
            end)
            if ok and res and res.data then
                for _, s in ipairs(res.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then
                        pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                        end)
                        return
                    end
                end
            end
            notify("Server Hop", "No open server found")
        end)
    end)
    makeButton(p, "Unload Script", function()
        unloadUI()
        notify("Unload", "UI removed (re-run to restore)")
    end)
end

--==================== COLORS ====================--
do
    local p = sections.colors
    makeHeader(p, "interface")
    makeColorRow(p, "Accent", function() return GUI.Accent end,
        function(c) GUI.Accent = c; ACCENT = c; onAccentChange() end)
    makeToggle(p, "Rainbow GUI", "Cycle accent colors",
        function() return GUI.Rainbow end, function(v) GUI.Rainbow = v end)
    makeHeader(p, "elements")
    makeColorRow(p, "Highlight", function() return Settings.HighlightColor end,
        function(c) Settings.HighlightColor = c end)
    makeColorRow(p, "FOV Ring", function() return Settings.RingColor end,
        function(c) Settings.RingColor = c; fcStroke.Color = c end)
    makeColorRow(p, "ESP", function() return ESP.Color end,
        function(c) ESP.Color = c; ESP.TextColor = c end)
    makeColorRow(p, "Chams", function() return Chams.Color end,
        function(c) Chams.Color = c; applyChams() end)
    makeColorRow(p, "Tracer", function() return Tracers.Color end,
        function(c) Tracers.Color = c end)
end

--==================== ANIMATIONS ====================--
do
    local p = sections.anims
    makeHeader(p, "spin")
    makeToggle(p, "Spin", "Rotate your character",
        function() return Spin.Enabled end, function(v) Spin.Enabled = v end)
    makeSlider(p, "Spin Speed", 100, 5000, Spin.Speed, function(v) Spin.Speed = v end)
    makeCycle(p, "Spin Axis", "Rotation axis", { "X", "Y", "Z" },
        function()
            if Spin.Axis == "X" then return 1 elseif Spin.Axis == "Y" then return 2 else return 3 end
        end,
        function(i) Spin.Axis = ({ "X", "Y", "Z" })[i] end)
    makeHeader(p, "rainbow")
    makeToggle(p, "Rainbow", "Animated hue cycling",
        function() return GUI.Rainbow end, function(v) GUI.Rainbow = v end)
    makeSlider(p, "Rainbow Speed", 0.05, 2, GUI.RainbowSpeed, function(v) GUI.RainbowSpeed = v end, 2)
end

--==================== CONFIG ====================--
do
    local p = sections.config
    makeHeader(p, "interface")
    makeSlider(p, "Scale", 0.5, 1.6, GUI.Scale, function(v) GUI.Scale = v; fitWindow() end, 2)
    makeSlider(p, "Opacity", 0.3, 1, GUI.Opacity, function(v) GUI.Opacity = v; fitWindow() end, 2)
    makeSlider(p, "Width", 200, 400, GUI.Width, function(v) GUI.Width = v; fitWindow() end)
    makeHeader(p, "info")
    makeButton(p, "Toggle Key:  Q", function() notify("Toggle Key", "Silent Aim is bound to Q") end)
    makeButton(p, "Noclip Key:  N", function() notify("Toggle Key", "Noclip is bound to N") end)
    makeButton(p, "Fly Key:  F", function() notify("Toggle Key", "Fly is bound to F") end)
end

showSection("combat")

--==================== FLOATING PILL ====================--
local pillGui = Instance.new("ScreenGui")
pillGui.Name = "SilentAimToggle"
pillGui.ResetOnSpawn = false
pillGui.IgnoreGuiInset = true
pillGui.DisplayOrder = 1001
pillGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pillGui.Parent = GUI_PARENT

local pill = Instance.new("TextButton")
pill.Size = UDim2.new(0, 120, 0, 38)
pill.Position = UDim2.new(0, 14, 0, 54)
pill.BackgroundColor3 = theme.panel
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel = 0
pill.Text = ""
pill.Parent = pillGui
corner(pill, 19)
stroke(pill, theme.stroke, 1, 0.82)

local pillDot = Instance.new("Frame")
pillDot.Size = UDim2.new(0, 8, 0, 8)
pillDot.Position = UDim2.new(0, 13, 0.5, -4)
pillDot.BackgroundColor3 = ACCENT
pillDot.BorderSizePixel = 0
pillDot.Parent = pill
corner(pillDot, 4)
table.insert(refreshables, function() pillDot.BackgroundColor3 = ACCENT end)

local pillTxt = Instance.new("TextLabel")
pillTxt.BackgroundTransparency = 1; pillTxt.Text = "Roman"
pillTxt.Font = Enum.Font.GothamBold; pillTxt.TextSize = 13; pillTxt.TextColor3 = theme.text
pillTxt.TextXAlignment = Enum.TextXAlignment.Left
pillTxt.Position = UDim2.new(0, 28, 0, 0); pillTxt.Size = UDim2.new(1, -34, 1, 0)
pillTxt.Parent = pill

pillDragging, pillMoved = false, false
pillStart, pillStartPos = Vector2.new(), UDim2.new()

pill.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        pillDragging = true; pillMoved = false
        pillStart = input.Position; pillStartPos = pill.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not pillDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - pillStart
        if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then pillMoved = true end
        if pillMoved then
            pill.Position = UDim2.new(pillStartPos.X.Scale, pillStartPos.X.Offset + delta.X,
                                      pillStartPos.Y.Scale, pillStartPos.Y.Offset + delta.Y)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not pillDragging then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        pillDragging = false
        if not pillMoved then
            win.Visible = not win.Visible
            notify("Menu", win.Visible and "Opened" or "Hidden")
        end
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    win.Visible = false
    notify("Menu", "Hidden")
end)

--==================== FLY BUTTONS (MOBILE) ====================--
flyBtnGui = Instance.new("ScreenGui")
flyBtnGui.Name = "RomanFlyBtn"
flyBtnGui.ResetOnSpawn = false
flyBtnGui.IgnoreGuiInset = true
flyBtnGui.DisplayOrder = 1004
flyBtnGui.Enabled = false
flyBtnGui.Parent = GUI_PARENT

local function flyButton(label, xPos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 54, 0, 54)
    b.Position = UDim2.new(1, xPos, 0.5, 60)
    b.BackgroundColor3 = theme.panel
    b.BackgroundTransparency = 0.15
    b.BorderSizePixel = 0
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 22
    b.TextColor3 = theme.text
    b.Parent = flyBtnGui
    corner(b, 27)
    stroke(b, theme.stroke, 1, 0.75)
    b.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if label == "▲" then Fly._up = true else Fly._down = true end
        end
    end)
    b.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if label == "▲" then Fly._up = false else Fly._down = false end
        end
    end)
    return b
end
flyButton("▲", -74)
flyButton("▼", -140)

--==================== HELPERS USED BY MISC ====================--
function setPostFx(name, class, props, on)
    local fx = MiscX._fx[name]
    if on then
        if not fx or not fx.Parent then
            fx = Instance.new(class)
            for k, v in pairs(props) do fx[k] = v end
            fx.Name = "Roman" .. name
            fx.Parent = Lighting
            MiscX._fx[name] = fx
        end
        fx.Enabled = true
    elseif fx then
        fx.Enabled = false
    end
end

function setSkyOff(on)
    if on then
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then MiscX._sky = sky; sky.Parent = nil end
    elseif MiscX._sky then
        MiscX._sky.Parent = Lighting; MiscX._sky = nil
    end
end

function applyJump()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if MiscX.JumpOn then
        hum.UseJumpPower = true
        hum.JumpPower = MiscX.JumpPower
    end
end

function applyHip()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if MiscX.HipOn then hum.HipHeight = MiscX.HipHeight end
end

function applyFreeze()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = MiscX.Freeze end
end

function applyCharTrans()
    local char = LocalPlayer.Character
    if not char then return end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
            d.LocalTransparencyModifier = MiscX.CharTransOn and MiscX.CharTrans or 0
        end
    end
end

function applyAccessories()
    local char = LocalPlayer.Character
    if not char then return end
    for _, a in ipairs(char:GetChildren()) do
        if a:IsA("Accessory") or a:IsA("Hat") then
            local h = a:FindFirstChild("Handle")
            if h then h.Transparency = MiscX.HideAcc and 1 or 0 end
        end
    end
end

function applyNametags()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if MiscX.HideNames then
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
    else
        hum.NameDisplayDistance = 100
        hum.HealthDisplayDistance = 100
    end
end

function unloadUI()
    for _, n in ipairs({ "VeniceUI", "SilentAimESP", "SilentAimFOV", "SilentAimToggle",
                        "RomanSnow", "RomanFeedback", "RomanHUD", "RomanFlyBtn", "RomanCombatHUD" }) do
        local g = GUI_PARENT:FindFirstChild(n)
        if g then pcall(function() g:Destroy() end) end
    end
end

--==================== TOGGLE KEYS ====================--
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CombatX.HoldKey then CombatX._hold = true end
    if input.KeyCode == Settings.ToggleKey then
        Settings.Enabled = not Settings.Enabled
        if not Settings.Enabled then Target, TargetPart = nil, nil end
        if uiRefs.silent then uiRefs.silent.refresh() end
        notify("Silent Aim", Settings.Enabled and "Enabled" or "Disabled")
    elseif input.KeyCode == Noclip.Key then
        Noclip.Enabled = not Noclip.Enabled
        if not Noclip.Enabled then restoreCollide() end
        if uiRefs.noclip then uiRefs.noclip.refresh() end
        notify("Noclip", Noclip.Enabled and "Enabled" or "Disabled")
    elseif input.KeyCode == Fly.Key then
        Fly.Enabled = not Fly.Enabled
        if Fly.Enabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = root.CFrame + Vector3.new(0, 6, 0) end
            applyFly()
        else
            stopFly()
        end
        if uiRefs.fly then uiRefs.fly.refresh() end
        notify("Fly", Fly.Enabled and "Enabled" or "Disabled")
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == CombatX.HoldKey then CombatX._hold = false end
end)

--==================== RAINBOW ====================--
rainbowHue = 0
function updateRainbow(dt)
    if GUI.Rainbow then
        rainbowHue = (rainbowHue + dt * GUI.RainbowSpeed) % 1
        local c = Color3.fromHSV(rainbowHue, 0.85, 1)
        ACCENT = c
        Settings.RingColor = c
        ESP.Color = c
        ESP.TextColor = c
        onAccentChange()
    else
        if ACCENT ~= GUI.Accent then ACCENT = GUI.Accent; onAccentChange() end
    end
end

--==================== POPUP / SONG ====================--
function playSong()
    local song = Instance.new("Sound")
    song.SoundId = SONG_ID
    song.Volume = 0.5
    song.Looped = false
    song.Parent = SoundService
    local t0 = tick()
    while not song.IsLoaded and tick() - t0 < 3 do task.wait(0.05) end
    if SONG_START > 0 then song.TimePosition = SONG_START end
    pcall(function() song:Play() end)
    return song
end

function showBeautifulPopup()
    local pop = Instance.new("Frame")
    pop.AnchorPoint = Vector2.new(0.5, 0.5)
    pop.Position = UDim2.new(0.5, 0, 0.5, 26)
    pop.Size = UDim2.new(0, 320, 0, 110)
    pop.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
    pop.BackgroundTransparency = 1
    pop.BorderSizePixel = 0
    pop.ZIndex = 70
    pop.Parent = ui
    corner(pop, 18)
    local ps = stroke(pop, Color3.fromRGB(255, 255, 255), 1, 1)

    local popScale = Instance.new("UIScale")
    popScale.Scale = 0.85
    popScale.Parent = pop

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Text = "made by Roman"
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 22
    title.TextColor3 = theme.text
    title.TextTransparency = 1
    title.Position = UDim2.new(0, 16, 0, 0)
    title.Size = UDim2.new(1, -32, 1, 0)
    title.ZIndex = 71
    title.Parent = pop

    local song = playSong()

    local EASE = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    TweenService:Create(pop, EASE, {
        BackgroundTransparency = 0.06,
        Position = UDim2.new(0.5, 0, 0.5, 0),
    }):Play()
    TweenService:Create(ps, EASE, { Transparency = 0.6 }):Play()
    TweenService:Create(popScale, EASE, { Scale = 1 }):Play()
    TweenService:Create(title, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
        TextTransparency = 0,
    }):Play()

    task.delay(POPUP_TIME - 0.9, function()
        local OUT = TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
        TweenService:Create(pop, OUT, {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, -18),
        }):Play()
        TweenService:Create(popScale, OUT, { Scale = 0.95 }):Play()
        TweenService:Create(title, OUT, { TextTransparency = 1 }):Play()
        TweenService:Create(ps, OUT, { Transparency = 1 }):Play()
        TweenService:Create(song, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Volume = 0 }):Play()
        task.wait(0.9)
        song:Stop()
        song:Destroy()
        pop:Destroy()
    end)
end

--==================== COMBAT TICK ====================--
function CombatXTick(dt)
    -- aim smoothing point
    if Target and TargetPart and TargetPart.Parent then
        local raw = rawAimPos()
        if raw then
            if CombatX.SmoothOn then
                CombatX._aimPoint = CombatX._aimPoint and CombatX._aimPoint:Lerp(raw, CombatX.Smooth) or raw
            else
                CombatX._aimPoint = raw
            end
            CombatX._aimValid = true
        end
    else
        CombatX._aimValid = false
        CombatX._aimPoint = nil
    end

    -- kill counter
    if CombatX.KillCounter then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    local prev = CombatX._hp[hum]
                    if prev and prev > 0 and hum.Health <= 0 then
                        CombatX._kills = CombatX._kills + 1
                        if CombatX.AutoReloadOnKill then pressReload() end
                    end
                    CombatX._hp[hum] = hum.Health
                end
            end
        end
    end

    local hasTarget = Target and TargetPart and TargetPart.Parent

    -- target ring
    if CombatX.TargetRing and hasTarget then
        if not CombatX._ringHL or not CombatX._ringHL.Parent then
            CombatX._ringHL = Instance.new("Highlight")
            CombatX._ringHL.Name = "RomanTargetRing"
            CombatX._ringHL.FillTransparency = 1
            CombatX._ringHL.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            CombatX._ringHL.Parent = combatGui
        end
        CombatX._ringHL.Adornee = Target.Character
        CombatX._ringHL.OutlineColor = CombatX.TracerColor
    elseif CombatX._ringHL then
        CombatX._ringHL.Adornee = nil
    end

    -- target tracer
    if CombatX.TargetTracer and hasTarget then
        local tp = CombatX._tracerPart
        if not tp or not tp.Parent then
            tp = Instance.new("Part")
            tp.Name = "RomanTargetLine"
            tp.Anchored = true; tp.CanCollide = false; tp.CanQuery = false
            tp.CastShadow = false; tp.Material = Enum.Material.Neon
            tp.Parent = Workspace
            CombatX._tracerPart = tp
        end
        local from = getMuzzle()
        from = from and from.Position or Camera.CFrame.Position
        local to = TargetPart.Position
        local dist = (to - from).Magnitude
        tp.Color = CombatX.TracerColor
        tp.Transparency = 0.25
        tp.Size = Vector3.new(0.08, 0.08, math.max(0.1, dist))
        tp.CFrame = CFrame.lookAt((from + to) * 0.5, to)
    elseif CombatX._tracerPart then
        CombatX._tracerPart.Transparency = 1
    end

    -- target info
    if CombatX.TargetInfo and hasTarget then
        local hum = Target.Character and Target.Character:FindFirstChildOfClass("Humanoid")
        local dist = math.floor((TargetPart.Position - Camera.CFrame.Position).Magnitude)
        CombatX._infoLabel.Visible = true
        CombatX._infoLabel.Text = Target.Name .. "  |  " .. tostring(math.floor(hum and hum.Health or 0)) .. " hp  |  " .. tostring(dist) .. " studs"
    elseif CombatX._infoLabel then
        CombatX._infoLabel.Visible = false
    end

    -- auto shoot / trigger bot
    if (CombatX.TriggerBot or CombatX.AutoShoot) and hasTarget then
        local now = tick()
        local doFire = false
        if CombatX.AutoShoot then
            if now - CombatX._lastShoot >= CombatX.ShootInterval then doFire = true end
        end
        if not doFire and CombatX.TriggerBot then
            local sp = Camera:WorldToViewportPoint(TargetPart.Position)
            if sp.Z > 0 then
                local vp = Camera.ViewportSize
                local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(vp.X / 2, vp.Y / 2)).Magnitude
                if d <= CombatX.TriggerRadius and now - CombatX._lastShoot >= CombatX.TriggerDelay then
                    doFire = true
                end
            end
        end
        if doFire then
            CombatX._lastShoot = now
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function() tool:Activate() end)
                markFire()
            end
        end
    end
end

-- camera lock / anti recoil must run after the default camera
RunService:BindToRenderStep("RomanCamLock", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if CombatX.CameraLock and Target and TargetPart and TargetPart.Parent then
        local pos = TargetPart.Position
        local camPos = Camera.CFrame.Position
        if (pos - camPos).Magnitude > 0.5 then
            local goal = CFrame.lookAt(camPos, pos)
            Camera.CFrame = Camera.CFrame:Lerp(goal, math.clamp(CombatX.LockStrength, 0.01, 1))
        end
    elseif CombatX.AntiRecoil and firing then
        local pitch = math.asin(math.clamp(Camera.CFrame.LookVector.Y, -1, 1))
        if CombatX._recoilPitch then
            local diff = pitch - CombatX._recoilPitch
            if diff > 0.001 then
                local goal = Camera.CFrame * CFrame.Angles(-diff * CombatX.RecoilReduction, 0, 0)
                Camera.CFrame = goal
            end
        else
            CombatX._recoilPitch = pitch
        end
    elseif not firing then
        CombatX._recoilPitch = nil
    end
end)

--==================== MISC TICK ====================--
function MiscXTick(dt)
    noPartsTick()

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if char then
        if MiscX.AutoJump and hum then
            if hum.FloorMaterial ~= Enum.Material.Air then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end
        if MiscX.FaceCam and root then
            local lv = Camera.CFrame.LookVector
            if Vector3.new(lv.X, 0, lv.Z).Magnitude > 0.01 then
                root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(lv.X, 0, lv.Z))
            end
        end
        if MiscX.AntiFling and root then
            local v = root.AssemblyLinearVelocity
            if v.Magnitude > MiscX.AntiFlingMax then
                root.AssemblyLinearVelocity = v.Unit * MiscX.AntiFlingMax
            end
        end
        if MiscX.Desync and root then
            local buf = MiscX._buf
            buf[#buf + 1] = root.CFrame
            if #buf > 12 then table.remove(buf, 1) end
            local old = buf[1]
            root.CFrame = CFrame.new(old.Position) * (root.CFrame - root.CFrame.Position)
        end
        if MiscX.AntiVoid and root and root.Position.Y < MiscX.AntiVoidY then
            root.CFrame = CFrame.new(root.Position.X, 100, root.Position.Z)
        end
    end

    if MiscX.AutoClicker then
        local now = tick()
        if now - MiscX._lastClick >= 1 / math.max(1, MiscX.AutoClickerCPS) then
            MiscX._lastClick = now
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then pcall(function() tool:Activate() end) end
        end
    end

    local now = tick()
    if now - MiscX._lastSlow > 0.5 then
        MiscX._lastSlow = now
        if MiscX.HideNames then applyNametags() end
        if MiscX.HideAcc then applyAccessories() end
        if MiscX.CharTransOn then applyCharTrans() end
    end
end

--==================== RENDER LOOP ====================--
RunService.RenderStepped:Connect(function(dt)
    applySpin(dt)
    updateRainbow(dt)
    updateSnow(dt)
    updateTrail()
    updateHUD(dt)
    findTarget()
    updateHighlight()
    updateESP()
    updateChams()
    updateHitbox()
    updateFOVRing()
    applyWalkspeed()
    applyFly()
    tracersTick()
    CombatXTick(dt)
    MiscXTick(dt)

    if RapidFire.Enabled then
        local now = tick()
        if RapidFire._queue then
            RapidFireStep(600)
        elseif now - RapidFire._lastScan >= RapidFire.ScanInterval then
            RapidFire._lastScan = now
            RapidFireScan()
        end
        if now - RapidFire._last >= RapidFire.Interval then
            RapidFire._last = now
            RapidFireApply()
        end
    end
end)

--==================== AUTO RESPAWN ====================--
local function bindRespawn(char)
    local hum = char:WaitForChild("Humanoid")
    hum.Died:Connect(function()
        if MiscX.AutoRespawn then
            task.wait(0.5)
            pcall(function() LocalPlayer:LoadCharacter() end)
        end
    end)
    applyNametags()
    applyAccessories()
end
if LocalPlayer.Character then bindRespawn(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(bindRespawn)

--==================== LOAD ====================--
task.spawn(function()
    win.BackgroundTransparency = 1
    TweenService:Create(win, TweenInfo.new(0.3), {
        BackgroundTransparency = 1 - GUI.Opacity,
    }):Play()
end)

task.delay(0.5, function() showBeautifulPopup() end)
task.delay(0.6, function() notify("Roman", "Loaded. Q silent aim, N noclip, F fly. Mobile fly buttons appear when flying.") end)

print("[Roman] loaded | hooks=" .. tostring(installed))
