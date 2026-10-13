--[[
    Venice UI  --  silent aim + spin + instant reload + noclip + ESP + chams + hitfx + snow
    MADE BY ROMAN
    Instant Reload: learns mag size, refills on heartbeat (no reload downtime)
    Extra: fullbright, no fog, HUD, infinite jump, anti-afk, hit marker,
           damage numbers, kill notifier, character trail, auto reload,
           server hop, rejoin, neon ESP, hit FX tab, chams, hitbox expander,
           universal rapid fire (attribute finder + overrider)
    Note: chams/hitbox/rapidfire use globals (not locals) to stay under the 200-local limit
    Note: key system removed -- loads straight into the UI
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
local SONG_ID    = "rbxassetid://111018848542448"   -- new track
local SONG_START = 30   -- seconds in (set to 0 to start from the beginning)
POPUP_TIME = 5          -- total seconds the popup stays on screen (global)

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

-- instant reload (replaces infinite ammo) -- global
InstantReload = {
    Enabled = false,
    Reserve = true,   -- also top up reserve/total ammo
    Target  = 0,      -- 0 = auto (learn mag size)
    _max   = {},      -- [inst] = learned mag size
    _cache = {},      -- cached ammo instances
    _lastRebuild = 0,
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

-- ammo name helpers (hoisted above the hooks so __namecall can see them)
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

local GUI = {
    Scale = 1, Opacity = 0.98, Width = 250, Rainbow = false, RainbowSpeed = 0.35,
    Accent = Color3.fromRGB(120, 170, 255),
}
getgenv().SilentAimGUI = GUI

local ESP = {
    Enabled = false, Boxes = true, Names = true, Skeleton = true,
    Neon = true,
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

--==================== GUI PARENT ====================--
local GUI_PARENT
pcall(function() GUI_PARENT = gethui and gethui() or nil end)
GUI_PARENT = GUI_PARENT or LocalPlayer:WaitForChild("PlayerGui")

for _, guiName in ipairs({ "SilentAimUI", "SilentAimESP", "SilentAimFOV", "VeniceUI",
                            "SilentAimToggle", "RomanSnow", "RomanFeedback", "RomanHUD",
                            "RomanKeySystem" }) do
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

--==================== RAPID FIRE ====================--
--  GLOBAL module so the main chunk stays under the local limit.
RapidFire = {
    Enabled      = false,
    Override     = 0.01,
    OnlyIfHigher = true,
    Interval     = 0.15,
    ScanInterval = 1.0,
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
    _targets = {},
    _originals = {},
    _memo = {},
    _kw = {},
    _bl = {},
    _last = 0,
    _lastScan = 0,
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
        if string.find(n, bl[i], 1, true) then
            memo[name] = false
            return false
        end
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

function rfApply(obj, name, val)
    local t = RapidFire._targets[obj]
    if not t then t = {}; RapidFire._targets[obj] = t end
    t[name] = true

    local orig = RapidFire._originals
    orig[obj] = orig[obj] or {}
    if orig[obj][name] == nil then orig[obj][name] = val end

    local tv = rfTarget(val)
    if val ~= tv then
        pcall(function() obj:SetAttribute(name, tv) end)
        if RapidFire.Print then
            print(("[RapidFire] %s.%s : %s -> %s"):format(
                obj:GetFullName(), name, tostring(val), tostring(tv)))
        end
    end
end

function RapidFireScan()
    if not RapidFire.Enabled then return end
    local found = {}
    for _, obj in ipairs(game:GetDescendants()) do
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
                    if val ~= tv then
                        pcall(function() obj:SetAttribute(name, tv) end)
                    end
                end
            end
        end
    end
    RapidFire._targets = found
end

function RapidFireApply()
    if not RapidFire.Enabled then return end
    for obj, names in pairs(RapidFire._targets) do
        if obj.Parent then
            for name in pairs(names) do
                local v = obj:GetAttribute(name)
                if type(v) == "number" then
                    local tv = rfTarget(v)
                    if v ~= tv then
                        pcall(function() obj:SetAttribute(name, tv) end)
                    end
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
    local roots = { char, tool, bpack, LocalPlayer }
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

--==================== WALK ====================--
baseWalk = 16   -- global
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
    local target = Settings.WalkspeedEnabled and Settings.Walkspeed or baseWalk
    if hum.WalkSpeed ~= target then hum.WalkSpeed = target end
end

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

--==================== CHARACTER TRAIL ====================--
trailInst = nil   -- global
local function updateTrail()
    if not Trail.Enabled then
        if trailInst then trailInst:Destroy(); trailInst = nil end
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if trailInst then trailInst:Destroy(); trailInst = nil end
        return
    end
    if trailInst and trailInst.Parent == root then
        trailInst.Color = ColorSequence.new(Trail.Color)
        return
    end
    if trailInst then trailInst:Destroy() end
    local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 1.4, 0); a0.Parent = root
    local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -1.4, 0); a1.Parent = root
    local t = Instance.new("Trail")
    t.Attachment0 = a0; t.Attachment1 = a1
    t.Lifetime = 0.6
    t.MinLength = 0
    t.Color = ColorSequence.new(Trail.Color)
    t.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 1),
    })
    t.Parent = root
    trailInst = t
end

--==================== NEON GLOW HELPER ====================--
local function applyNeon(inst, color)
    local g = inst:FindFirstChild("__glow")
    if not g then
        g = Instance.new("UIStroke")
        g.Name = "__glow"
        g.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        g.Parent = inst
    end
    g.Color = color
    if ESP.Neon then
        g.Thickness = 3
        g.Transparency = 0.45
    else
        g.Transparency = 1
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
                    d.box.stroke.Thickness = ESP.Neon and 1.5 or 1
                    applyNeon(d.box.frame, ESP.Color)
                else
                    d.box.frame.Visible = false
                end
                if ESP.Names and tl then
                    d.name.Visible = true
                    d.name.Text = plr.Name
                    d.name.TextColor3 = ESP.TextColor
                    d.name.Position = UDim2.new(0, (tl.X + br.X) / 2, 0, tl.Y - 2)
                    applyNeon(d.name, ESP.TextColor)
                else
                    d.name.Visible = false
                end
                if ESP.Skeleton then
                    updateBones(d, char)
                    for _, l in ipairs(d.lines) do
                        l.BackgroundColor3 = ESP.Color
                        applyNeon(l, ESP.Color)
                    end
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
-- GLOBALS so the main chunk stays under the local limit.
Chams = {
    Enabled = false,
    Neon = true,
    Color = Color3.fromRGB(0, 255, 200),
    Material = "ForceField",
    Transparency = 0,
    Glow = true,
    _hl = nil, _light = nil, _last = 0,
}
getgenv().RomanChams = Chams

CHAMS_MATERIALS = {
    "ForceField", "Glass", "Plastic", "SmoothPlastic", "Metal", "Foil",
    "Marble", "Ice", "Granite", "DiamondPlate", "Slate", "Concrete", "Sand", "Fabric", "Neon",
}

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
            hl.Name = "RomanChams"
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
    Enabled = false,
    Size = Vector3.new(11, 14, 5),
    Transparency = 0.55,
    TeamCheck = true,
    _last = 0,
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

--==================== HIT SOUNDS / EFFECTS ====================--
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
    { name = "Bell",                  id = "rbxassetid://5276754334" },
    { name = "Ring",                  id = "rbxassetid://82635963679205" },
}

lastSound = 0   -- global
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

lastEffect = 0   -- global
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
lastFire = 0    -- global
firing = false  -- global
lastFX = {}     -- global
lastHP = {}     -- global
function markFire() lastFire = tick() end

RunService.Heartbeat:Connect(function()
    ammoTick()          -- instant reload runs every frame = instant
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
Mouse.Button1Down:Connect(function()
    firing = true; markFire(); tryActivate()
end)
Mouse.Button1Up:Connect(function() firing = false end)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        firing = true; markFire(); tryActivate()
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
hudLabel.Size = UDim2.new(0, 260, 0, 20)
hudLabel.BackgroundTransparency = 1
hudLabel.Font = Enum.Font.GothamBold
hudLabel.TextSize = 13
hudLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hudLabel.TextStrokeTransparency = 0.4
hudLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hudLabel.TextXAlignment = Enum.TextXAlignment.Right
hudLabel.Text = ""
hudLabel.Parent = hudGui

local fpsFrames, fpsTimer, fpsValue = 0, tick(), 60
local hudTimer = 0
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
    local parts = {}
    if HUD.FPS then parts[#parts + 1] = "FPS: " .. tostring(fpsValue) end
    if HUD.Ping then
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        parts[#parts + 1] = "Ping: " .. tostring(ping) .. "ms"
    end
    if HUD.Clock then parts[#parts + 1] = os.date("%H:%M:%S") end
    hudLabel.Text = table.concat(parts, "   ")
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

dragging, dragStart, startPos = false, nil, nil   -- globals

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

do
    local p = sections.combat
    makeHeader(p, "aim")
    uiRefs.silent = makeToggle(p, "Silent Aim", "Redirect shots to target",
        function() return Settings.Enabled end,
        function(v) Settings.Enabled = v; if not v then Target, TargetPart = nil, nil end end)
    makeCycle(p, "Aim Part", "Hitbox to target", { "Head", "Torso" },
        function() return (Settings.AimPart == "Head") and 1 or 2 end,
        function(i) Settings.AimPart = (i == 1) and "Head" or "Torso"; Target, TargetPart = nil, nil end)
    makeSlider(p, "FOV", MINFOV, MAXFOV, Settings.FOV, function(v) Settings.FOV = v end)
    makeHeader(p, "checks")
    makeToggle(p, "Visible Only", "Require line of sight",
        function() return Settings.VisibleCheck end, function(v) Settings.VisibleCheck = v end)
    makeToggle(p, "Team Check", "Ignore teammates",
        function() return Settings.TeamCheck end, function(v) Settings.TeamCheck = v end)
    makeToggle(p, "Ignore Knocked", "Skip downed players",
        function() return Settings.IgnoreKnocked end, function(v) Settings.IgnoreKnocked = v end)
    makeToggle(p, "Target Highlight", "Outline the target",
        function() return Settings.ShowTarget end, function(v) Settings.ShowTarget = v end)
    makeToggle(p, "Anti-Kick", "Block kick calls",
        function() return Settings.AntiKick end, function(v) Settings.AntiKick = v end)
end

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
    makeToggle(p, "Infinite Jump", "Jump mid-air",
        function() return Move.InfiniteJump end, function(v) Move.InfiniteJump = v end)
    makeToggle(p, "Anti-AFK", "Stay online",
        function() return Move.AntiAFK end, function(v) Move.AntiAFK = v end)
end

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
    uiRefs.rapidfire = makeToggle(p, "Rapid Fire", "Force max fire rate on any attribute",
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
    makeSlider(p, "Scan Rate", 0.25, 3, RapidFire.ScanInterval,
        function(v) RapidFire.ScanInterval = v end, 2)
end

do
    local p = sections.visuals
    makeHeader(p, "esp")
    makeToggle(p, "ESP", "Draw players through walls",
        function() return ESP.Enabled end, function(v) ESP.Enabled = v end)
    makeToggle(p, "Neon ESP", "Glowing outlines",
        function() return ESP.Neon end, function(v) ESP.Neon = v end)
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

    makeHeader(p, "world")
    makeToggle(p, "Fullbright", "Brighten lighting",
        function() return Visual.Fullbright end,
        function(v) Visual.Fullbright = v; setFullbright(v) end)
    makeToggle(p, "No Fog", "Remove distance fog",
        function() return Visual.NoFog end,
        function(v) Visual.NoFog = v; setNoFog(v) end)
    makeToggle(p, "Character Trail", "Trail behind you",
        function() return Trail.Enabled end, function(v) Trail.Enabled = v; updateTrail() end)
    makeColorRow(p, "Trail Color", function() return Trail.Color end, function(c) Trail.Color = c end)
    makeHeader(p, "snow")
    uiRefs.snow = makeToggle(p, "Falling Snow", "Snow overlay",
        function() return Snow.Enabled end, function(v) Snow.Enabled = v end)
    makeSlider(p, "Snow Amount", 20, 200, Snow.Count, function(v) Snow.Count = v; buildSnow() end)
end

do
    local p = sections.misc
    makeHeader(p, "hud")
    makeToggle(p, "FPS Counter", "Show frames per second",
        function() return HUD.FPS end, function(v) HUD.FPS = v end)
    makeToggle(p, "Ping", "Show server ping",
        function() return HUD.Ping end, function(v) HUD.Ping = v end)
    makeToggle(p, "Clock", "Show local time",
        function() return HUD.Clock end, function(v) HUD.Clock = v end)
    makeHeader(p, "server")
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
end

do
    local p = sections.colors
    makeHeader(p, "interface")
    makeColorRow(p, "Accent", function() return GUI.Accent end,
        function(c) GUI.Accent = c; ACCENT = c; onAccentChange() end)
    makeToggle(p, "Rainbow GUI", "Cycle accent colors",
        function() return GUI.Rainbow end, function(v) GUI.Rainbow = v end)
    makeHeader(p, "elements")
    makeColorRow(p, "Highlight", function() return Settings.HighlightColor end,
        function(c) Settings.HighlightColor = c
            if PartHighlight then PartHighlight.FillColor = c; PartHighlight.OutlineColor = c end end)
    makeColorRow(p, "FOV Ring", function() return Settings.RingColor end,
        function(c) Settings.RingColor = c; fcStroke.Color = c end)
    makeColorRow(p, "ESP", function() return ESP.Color end,
        function(c) ESP.Color = c; ESP.TextColor = c end)
    makeColorRow(p, "Chams", function() return Chams.Color end,
        function(c) Chams.Color = c; applyChams() end)
end

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

do
    local p = sections.config
    makeHeader(p, "interface")
    makeSlider(p, "Scale", 0.5, 1.6, GUI.Scale, function(v) GUI.Scale = v; fitWindow() end, 2)
    makeSlider(p, "Opacity", 0.3, 1, GUI.Opacity, function(v) GUI.Opacity = v; fitWindow() end, 2)
    makeSlider(p, "Width", 200, 400, GUI.Width, function(v) GUI.Width = v; fitWindow() end)
    makeHeader(p, "info")
    makeButton(p, "Toggle Key:  Q", function() notify("Toggle Key", "Silent Aim is bound to Q") end)
    makeButton(p, "Noclip Key:  N", function() notify("Toggle Key", "Noclip is bound to N") end)
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

pillDragging, pillMoved = false, false   -- globals
pillStart, pillStartPos = Vector2.new(), UDim2.new()   -- globals

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

--==================== TOGGLE KEYS ====================--
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
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
    end
end)

--==================== RAINBOW ====================--
rainbowHue = 0   -- global
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
local function playSong()
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

    if RapidFire.Enabled then
        local now = tick()
        if now - RapidFire._last >= RapidFire.Interval then
            RapidFire._last = now
            RapidFireApply()
        end
        if now - RapidFire._lastScan >= RapidFire.ScanInterval then
            RapidFire._lastScan = now
            RapidFireScan()
        end
    end
end)

--==================== LOAD ====================--
task.spawn(function()
    win.BackgroundTransparency = 1
    TweenService:Create(win, TweenInfo.new(0.3), {
        BackgroundTransparency = 1 - GUI.Opacity,
    }):Play()
end)

task.delay(0.5, function() showBeautifulPopup() end)
task.delay(0.6, function() notify("Roman", "Loaded. Press Q for silent aim, N for noclip.") end)

print("[Roman] loaded | hooks=" .. tostring(installed))
