-- Roman UI Lite | aim + lock + antiaim + esp + noclip + fly + speed + rapid fire + autoequip + teleport + positions | MADE BY ROMAN

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser  = game:GetService("VirtualUser")
local Lighting     = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LP = Players.LocalPlayer
local G  = (getgenv and getgenv()) or _G or {}

local EXCLUDE  = Enum.RaycastFilterType.Exclude or Enum.RaycastFilterType.Blacklist
local FONT_MED = Enum.Font.GothamMedium or Enum.Font.Gotham

local Camera = Workspace.CurrentCamera or Workspace:FindFirstChildWhichIsA("Camera")
local Mouse  = LP:GetMouse()

local SONG_ID, SONG_START = "rbxassetid://111018848542448", 30
local POPUP_TIME, FADE_IN, FADE_OUT = 4, 0.4, 1.6

local CFG = {
    Aim = false, AimKey = Enum.KeyCode.Q, FOV = 60, AimPart = "Head",
    CursorLock = true, CursorRadius = 60,
    TeamCheck = true, VisibleCheck = true, IgnoreKnocked = true, ForceFieldCheck = true,
    Predict = true, ProjectileSpeed = 900, MaxLead = 0.3, Highlight = true,
    Noclip = false, NoclipKey = Enum.KeyCode.N,
    Fly = false, FlyKey = Enum.KeyCode.F, FlySpeed = 60,
    WalkOn = false, WalkSpeed = 16,
    InfiniteJump = false, AntiAFK = false,
    ESP = false, Boxes = true, Names = true, Skeleton = true,
    Fullbright = false, NoFog = false,
    SavePosKey = Enum.KeyCode.Z, LoadPosKey = Enum.KeyCode.X,
    Accent = Color3.fromRGB(120, 170, 255),
    Color  = Color3.fromRGB(255, 255, 255),
    KnockNames = {
        "Knocked","Downed","IsKnocked","IsDowned","knocked","downed",
        "IsRagdoll","Ragdoll","ragdoll","IsDead","Dead",
    },
    FFNames = {
        "ForceField","forcefield","Forcefield","SpawnProtected",
        "Invulnerable","Invincible","GodMode","IsProtected","Protected",
    },
}
G.RomanLite = CFG

local GUI_PARENT = (gethui and gethui()) or LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
for _, n in ipairs({ "RomanLite", "RomanESP", "RomanFOV", "RomanFlyBtn", "RomanPopup", "RomanMobile" }) do
    local old = GUI_PARENT:FindFirstChild(n)
    if old then pcall(function() old:Destroy() end) end
end

local Target, TargetPart, TargetHit
local notify
local refs = {}
local TargetLock = { Player = nil }
local refreshTargetList
local tpBtn

--==================== HELPERS ====================--
local rayParams = RaycastParams.new()
rayParams.FilterType = EXCLUDE
rayParams.IgnoreWater = true

local cursorRayParams = RaycastParams.new()
cursorRayParams.FilterType = EXCLUDE
cursorRayParams.IgnoreWater = true

local function hasLineOfSight(char, pos)
    if not CFG.VisibleCheck then return true end
    if not char then return true end
    local filter = { char }
    local lc = LP.Character
    if lc and lc ~= char then filter[#filter + 1] = lc end
    rayParams.FilterDescendantsInstances = filter
    local origin = Camera.CFrame.Position
    return Workspace:Raycast(origin, pos - origin, rayParams) == nil
end

local function hasForceField(char, plr)
    if not CFG.ForceFieldCheck then return false end
    if char and char:FindFirstChildOfClass("ForceField") then return true end
    if plr and plr:FindFirstChildOfClass("ForceField") then return true end
    for _, n in ipairs(CFG.FFNames) do
        if char and char:GetAttribute(n) == true then return true end
        if plr and plr:GetAttribute(n) == true then return true end
        local inst = char and char:FindFirstChild(n)
        if inst then
            if inst:IsA("BoolValue") and inst.Value then return true end
            if inst:IsA("NumberValue") and inst.Value > 0 then return true end
        end
    end
    return false
end

local function resolveAimPart(char)
    if not char then return nil end
    if CFG.AimPart == "Head" then
        return char:FindFirstChild("Head")
            or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso")
            or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
end

local function aimCandidates(char, primary)
    local list = {}
    if primary then list[#list + 1] = primary end
    for _, n in ipairs({ "Head", "UpperTorso", "Torso", "HumanoidRootPart" }) do
        local p = char:FindFirstChild(n)
        if p and p:IsA("BasePart") and p ~= primary then list[#list + 1] = p end
    end
    return list
end

local function partVisible(char, part)
    return part ~= nil and part.Parent ~= nil and hasLineOfSight(char, part.Position)
end

local function isEnemy(plr)
    if not plr or plr == LP then return false end
    if not CFG.TeamCheck then return true end
    if plr.Team ~= nil and plr.Team == LP.Team then return false end
    return true
end

local function isKnocked(char, hum)
    if not CFG.IgnoreKnocked then return false end
    for _, name in ipairs(CFG.KnockNames) do
        if char:GetAttribute(name) == true then return true end
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

local function isAlive(char, hum)
    if not hum or hum.Health <= 0 then return false end
    local ok, state = pcall(function() return hum:GetState() end)
    if ok and state == Enum.HumanoidStateType.Dead then return false end
    return not isKnocked(char, hum)
end

local GunKeywords = {
    "gun","pistol","rifle","smg","shotgun","sniper","dmr","lmg","carbine",
    "revolver","magnum","deagle","glock","uzi","mp5","p90","awp","ak","m4",
    "ar15","scar","famas","vector","tommy","thompson","mosin","winchester",
    "launcher","rpg","minigun","gatling","weapon","handgun","marksman","auto",
}
local function isGun(name)
    local n = string.lower(name)
    for _, k in ipairs(GunKeywords) do
        if string.find(n, k, 1, true) then return true end
    end
    return false
end

local function displayOf(plr)
    local dn = plr.DisplayName
    if dn and dn ~= "" then return dn end
    return plr.Name
end

--==================== CURSOR / AIM ====================--
local function cursorViewportPos()
    return Vector2.new(Mouse.X, Mouse.Y)
end

local function viewportRay(vp)
    local w, h = Camera.ViewportSize.X, Camera.ViewportSize.Y
    if w <= 0 or h <= 0 then return nil end
    local tanY = math.tan(math.rad(Camera.FieldOfView) * 0.5)
    local aspect = w / h
    local ndcX = (vp.X / w) * 2 - 1
    local ndcY = 1 - (vp.Y / h) * 2
    local dir = Camera.CFrame.LookVector
        + Camera.CFrame.RightVector * (ndcX * tanY * aspect)
        + Camera.CFrame.UpVector * (ndcY * tanY)
    return Ray.new(Camera.CFrame.Position, dir.Unit)
end

local function getPlayerFromPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorOfClass("Model")
    if model then return Players:GetPlayerFromCharacter(model) end
    return nil
end

local function pickUnderCursor()
    local ray = viewportRay(cursorViewportPos())
    if not ray then return nil end
    local lc = LP.Character
    cursorRayParams.FilterDescendantsInstances = lc and { lc } or {}
    local hit = Workspace:Raycast(ray.Origin, ray.Direction * 3000, cursorRayParams)
    if not hit or not hit.Instance then return nil end
    local plr = getPlayerFromPart(hit.Instance)
    if not plr or plr == LP then return nil end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or not isAlive(char, hum) then return nil end
    if not isEnemy(plr) or hasForceField(char, plr) then return nil end
    if not hasLineOfSight(char, hit.Position) then return nil end
    return plr, hit
end

local function rawAimPos()
    if not TargetPart or not TargetPart.Parent then return nil end
    local origin = Camera.CFrame.Position
    local base = (CFG.CursorLock and TargetHit) or TargetPart.Position
    local pos = base
    if CFG.Predict then
        local v = TargetPart.AssemblyLinearVelocity
        if v.Magnitude > 0.05 then
            local speed = math.max(CFG.ProjectileSpeed, 1)
            for _ = 1, 2 do
                local dist = (pos - origin).Magnitude
                local t = math.clamp(dist / speed, 0, CFG.MaxLead)
                pos = base + v * t
            end
        end
    end
    local char = Target and Target.Character
    if char and not hasLineOfSight(char, pos) then return base end
    return pos
end

local function getAimCFrame()
    if not (CFG.Aim and Target and TargetPart and TargetPart.Parent) then return nil end
    local p = rawAimPos()
    if not p then return nil end
    return CFrame.lookAt(Camera.CFrame.Position, p)
end

--==================== TARGETING ====================--
local function findTarget()
    if TargetLock.Player then
        local lplr = TargetLock.Player
        if not lplr.Parent then
            TargetLock.Player = nil
            if refreshTargetList then refreshTargetList() end
        else
            local char = lplr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and isAlive(char, hum) then
                local primary = resolveAimPart(char) or char:FindFirstChild("HumanoidRootPart")
                if primary then
                    Target, TargetPart, TargetHit = lplr, primary, primary.Position
                    return
                end
            end
            Target, TargetPart, TargetHit = nil, nil, nil
            return
        end
    end

    if CFG.CursorLock then
        local plr, hit = pickUnderCursor()
        if plr and hit and hit.Instance and hit.Instance:IsA("BasePart") then
            Target, TargetPart, TargetHit = plr, hit.Instance, hit.Position
            return
        end
        local vp = cursorViewportPos()
        local best, bestDist, bestPart, bestHit = nil, math.huge, nil, nil
        for _, p in ipairs(Players:GetPlayers()) do
            if isEnemy(p) then
                local char = p.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and isAlive(char, hum) and not hasForceField(char, p) then
                    local primary = resolveAimPart(char) or char:FindFirstChild("HumanoidRootPart")
                    for _, cand in ipairs(aimCandidates(char, primary)) do
                        if partVisible(char, cand) then
                            local sp = Camera:WorldToViewportPoint(cand.Position)
                            if sp.Z > 0 then
                                local d = (Vector2.new(sp.X, sp.Y) - vp).Magnitude
                                if d <= CFG.CursorRadius and d < bestDist then
                                    best, bestDist, bestPart, bestHit = p, d, cand, cand.Position
                                end
                            end
                        end
                    end
                end
            end
        end
        Target, TargetPart, TargetHit = best, bestPart, bestHit
        return
    end

    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local radius = math.min(vp.X, vp.Y) * 0.5 * (CFG.FOV / 90)
    local best, bestDist, bestPart, bestHit = nil, math.huge, nil, nil

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and isAlive(char, hum) and not hasForceField(char, plr) then
                local primary = resolveAimPart(char) or char:FindFirstChild("HumanoidRootPart")
                local chosen, chosenD
                if partVisible(char, primary) then
                    local sp = Camera:WorldToViewportPoint(primary.Position)
                    if sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= radius then chosen, chosenD = primary, d end
                    end
                end
                if not chosen then
                    for _, cand in ipairs(aimCandidates(char, primary)) do
                        if partVisible(char, cand) then
                            local sp = Camera:WorldToViewportPoint(cand.Position)
                            if sp.Z > 0 then
                                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                if d <= radius and (chosenD == nil or d < chosenD) then
                                    chosen, chosenD = cand, d
                                end
                            end
                        end
                    end
                end
                if chosen and chosenD and chosenD < bestDist then
                    best, bestDist, bestPart, bestHit = plr, chosenD, chosen, chosen.Position
                end
            end
        end
    end
    Target, TargetPart, TargetHit = best, bestPart, bestHit
end

--==================== RAPID FIRE ====================--
local RapidFire = {
    Enabled = false, Override = 0.01, OnlyIfHigher = true,
    Interval = 0.2, ScanInterval = 2.5, Loose = false,
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
G.RomanRapidFire = RapidFire
for i, k in ipairs(RapidFire.Keywords)  do RapidFire._kw[i] = string.lower(k) end
for i, b in ipairs(RapidFire.Blacklist) do RapidFire._bl[i] = string.lower(b) end

local function rfMatches(name)
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
        if string.find(n, "rate", 1, true) or string.find(n, "speed", 1, true) then res = true end
    end
    memo[name] = res
    return res
end

local function rfTarget(orig)
    if RapidFire.OnlyIfHigher then return math.min(orig, RapidFire.Override) end
    return RapidFire.Override
end

local function RapidFireScan()
    if not RapidFire.Enabled then return end
    RapidFire._queue = game:GetDescendants()
    RapidFire._qi = 1
    RapidFire._found = {}
end

local function RapidFireStep(budget)
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

local function RapidFireApply()
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

local function RapidFireRestore()
    for obj, t in pairs(RapidFire._originals) do
        for name, val in pairs(t) do
            pcall(function() obj:SetAttribute(name, val) end)
        end
    end
    RapidFire._originals = {}
    RapidFire._targets = {}
    RapidFire._queue = nil
end

--==================== ANTI AIM ====================--
local AntiAim = { Enabled = false, Mode = 1, Speed = 20, Amount = 90, _bg = nil, _yaw = 0 }
G.RomanAntiAim = AntiAim

local function antiAimDir()
    local lv = Camera.CFrame.LookVector
    local camA = math.atan2(lv.X, lv.Z)
    local a
    local m = AntiAim.Mode
    if m == 1 then
        AntiAim._yaw = AntiAim._yaw + math.rad(AntiAim.Speed)
        a = AntiAim._yaw
    elseif m == 2 then
        a = camA + math.sin(tick() * AntiAim.Speed) * math.rad(AntiAim.Amount)
    elseif m == 3 then
        a = camA + math.rad((math.random() * 2 - 1) * AntiAim.Amount)
    elseif m == 4 then
        a = camA + math.rad(AntiAim.Amount)
    else
        a = camA + math.rad(180)
    end
    return Vector3.new(math.sin(a), 0, math.cos(a))
end

local function applyAntiAim()
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not AntiAim.Enabled then
        if AntiAim._bg then AntiAim._bg:Destroy(); AntiAim._bg = nil end
        if hum then pcall(function() hum.AutoRotate = true end) end
        return
    end
    if not root or not hum then return end
    if hum.AutoRotate then hum.AutoRotate = false end
    if not AntiAim._bg or AntiAim._bg.Parent ~= root then
        if AntiAim._bg then AntiAim._bg:Destroy() end
        local bg = Instance.new("BodyGyro")
        bg.Name = "RomanAntiAim"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 30000
        bg.D = 1000
        bg.Parent = root
        AntiAim._bg = bg
    end
    local dir = antiAimDir()
    AntiAim._bg.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
end

--==================== NOCLIP ====================--
local noclipStore = {}
local function noclipChar()
    local char = LP.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if noclipStore[p] == nil then noclipStore[p] = p.CanCollide end
            if p.CanCollide then p.CanCollide = false end
        end
    end
end
local function restoreCollide()
    for p, val in pairs(noclipStore) do
        if p.Parent then pcall(function() p.CanCollide = val end) end
    end
    noclipStore = {}
end
(RunService.PreSimulation or RunService.Stepped):Connect(function()
    if CFG.Noclip then noclipChar() end
end)

--==================== HOOKS ====================--
local nc = newcclosure or function(f) return f end
local oldIndex, oldNamecall, oldNewIndex, installed = nil, nil, nil, false
pcall(function()
    oldIndex = hookmetamethod(game, "__index", nc(function(self, key)
        if CFG.Aim and Target and self == Mouse then
            local cf = getAimCFrame()
            if cf then
                if key == "Hit" then return cf end
                if key == "Origin" then return CFrame.new(Camera.CFrame.Position) end
                if key == "Target" then return TargetPart end
                if key == "UnitRay" then return Ray.new(cf.Position, cf.LookVector * 1000) end
            end
        end
        return oldIndex(self, key)
    end))
    oldNamecall = hookmetamethod(game, "__namecall", nc(function(self, ...)
        local method = getnamecallmethod and getnamecallmethod()
        if RapidFire.Enabled and method == "SetAttribute" then
            local attr, val = ...
            if type(attr) == "string" and type(val) == "number" and rfMatches(attr) then
                return oldNamecall(self, attr, rfTarget(val))
            end
        end
        if method == "Kick" and self == LP then return nil end
        if CFG.Aim and Target and self == Camera
        and (method == "ViewportPointToRay" or method == "ScreenPointToRay") then
            local cf = getAimCFrame()
            if cf then return Ray.new(cf.Position, cf.LookVector * 1000) end
        end
        return oldNamecall(self, ...)
    end))
    oldNewIndex = hookmetamethod(game, "__newindex", nc(function(self, key, value)
        if CFG.Noclip and key == "CanCollide" and value == true
        and typeof(self) == "Instance" and self:IsA("BasePart") then
            local char = LP.Character
            if char and self:IsDescendantOf(char) then
                if noclipStore[self] == nil then noclipStore[self] = true end
                return oldNewIndex(self, key, false)
            end
        end
        return oldNewIndex(self, key, value)
    end))
    installed = true
end)

--==================== HIGHLIGHT / FOV RING ====================--
local highlight = Instance.new("Highlight")
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Parent = GUI_PARENT

local function updateHighlight()
    local char = Target and Target.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not CFG.Highlight or not hum or hum.Health <= 0 then
        highlight.Adornee = nil
        return
    end
    highlight.FillColor = CFG.Color
    highlight.OutlineColor = CFG.Color
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
end

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "RomanFOV"
fovGui.ResetOnSpawn = false
fovGui.DisplayOrder = 999
fovGui.Parent = GUI_PARENT

local ring = Instance.new("Frame")
ring.AnchorPoint = Vector2.new(0.5, 0.5)
ring.Position = UDim2.new(0.5, 0, 0.5, 0)
ring.BackgroundTransparency = 0.94
ring.BackgroundColor3 = Color3.new(1, 1, 1)
ring.BorderSizePixel = 0
ring.Parent = fovGui
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

local ringStroke = Instance.new("UIStroke")
ringStroke.Color = CFG.Color
ringStroke.Thickness = 2
ringStroke.Transparency = 0.3
ringStroke.Parent = ring

local function updateRing()
    fovGui.Enabled = CFG.Aim
    if not CFG.Aim then return end
    ringStroke.Color = CFG.Color
    ringStroke.Transparency = Target and 0.05 or 0.3
    if TargetLock.Player then
        ringStroke.Color = CFG.Accent
        ringStroke.Transparency = 0
    end
    if CFG.CursorLock then
        local r = CFG.CursorRadius
        ring.Size = UDim2.new(0, r * 2, 0, r * 2)
        ring.Position = UDim2.new(0, Mouse.X, 0, Mouse.Y)
    else
        local vp = Camera.ViewportSize
        local r = math.min(vp.X, vp.Y) * 0.5 * (CFG.FOV / 90)
        ring.Size = UDim2.new(0, r * 2, 0, r * 2)
        ring.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end

--==================== ESP ====================--
local espGui = Instance.new("ScreenGui")
espGui.Name = "RomanESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.DisplayOrder = 900
espGui.Parent = GUI_PARENT

local R15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6 = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
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
                        local w = (cf * CFrame.new(ix * sz.X, iy * sz.Y, iz * sz.Z)).Position
                        local sp = Camera:WorldToViewportPoint(w)
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

local function newData()
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    local st = Instance.new("UIStroke", box)
    st.Thickness = 1.5
    box.Parent = espGui
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Font = Enum.Font.GothamBold
    name.TextSize = 14
    name.TextStrokeTransparency = 0
    name.TextStrokeColor3 = Color3.new(0, 0, 0)
    name.AnchorPoint = Vector2.new(0.5, 1)
    name.Visible = false
    name.Parent = espGui
    return { box = box, stroke = st, name = name, lines = {} }
end

local function getLine(d, i)
    local l = d.lines[i]
    if not l then
        l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(0.5, 0.5)
        l.BorderSizePixel = 0
        l.Visible = false
        l.Parent = espGui
        d.lines[i] = l
    end
    return l
end

local function hideData(d)
    d.box.Visible = false
    d.name.Visible = false
    for _, l in ipairs(d.lines) do l.Visible = false end
end

local function updateESP()
    for plr, d in pairs(espData) do
        if not plr.Parent or not plr.Character then
            d.box:Destroy(); d.name:Destroy()
            for _, l in ipairs(d.lines) do l:Destroy() end
            espData[plr] = nil
        end
    end
    if not CFG.ESP then
        for _, d in pairs(espData) do hideData(d) end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if char and hum and hum.Health > 0 then
                local d = espData[plr]
                if not d then d = newData(); espData[plr] = d end
                local tl, br = screenBounds(char)
                if CFG.Boxes and tl then
                    d.box.Visible = true
                    d.box.Position = UDim2.new(0, tl.X, 0, tl.Y)
                    d.box.Size = UDim2.new(0, br.X - tl.X, 0, br.Y - tl.Y)
                    d.stroke.Color = (TargetLock.Player == plr) and CFG.Accent or CFG.Color
                else
                    d.box.Visible = false
                end
                if CFG.Names and tl then
                    d.name.Visible = true
                    d.name.Text = displayOf(plr)
                    d.name.TextColor3 = (TargetLock.Player == plr) and CFG.Accent or CFG.Color
                    d.name.Position = UDim2.new(0, (tl.X + br.X) / 2, 0, tl.Y - 2)
                else
                    d.name.Visible = false
                end
                if CFG.Skeleton then
                    local bones = char:FindFirstChild("UpperTorso") and R15 or R6
                    for i, bone in ipairs(bones) do
                        local line = getLine(d, i)
                        local a = char:FindFirstChild(bone[1])
                        local b = char:FindFirstChild(bone[2])
                        local pa = a and a:IsA("BasePart") and project(a.Position)
                        local pb = b and b:IsA("BasePart") and project(b.Position)
                        if pa and pb then
                            setLine(line, pa, pb)
                            line.BackgroundColor3 = CFG.Color
                        else
                            line.Visible = false
                        end
                    end
                    for i = #bones + 1, #d.lines do d.lines[i].Visible = false end
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

--==================== FLY ====================--
local Fly = { _bv = nil, _bg = nil, _up = false, _down = false }

local flyBtnGui = Instance.new("ScreenGui")
flyBtnGui.Name = "RomanFlyBtn"
flyBtnGui.ResetOnSpawn = false
flyBtnGui.IgnoreGuiInset = true
flyBtnGui.Enabled = false
flyBtnGui.Parent = GUI_PARENT

local function flyButton(label, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 54, 0, 54)
    b.Position = UDim2.new(1, x, 0.5, 60)
    b.BackgroundColor3 = Color3.fromRGB(23, 23, 27)
    b.BackgroundTransparency = 0.15
    b.BorderSizePixel = 0
    b.Text = label
    b.Font = Enum.Font.GothamBold
    b.TextSize = 22
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Parent = flyBtnGui
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    local function press(state)
        if label == "▲" then Fly._up = state else Fly._down = state end
    end
    b.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then press(true) end
    end)
    b.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then press(false) end
    end)
end
flyButton("▲", -74)
flyButton("▼", -140)

local controls
local function getControls()
    if controls then return controls end
    local ok, mod = pcall(function()
        return require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if ok and mod then
        local ok2, c = pcall(function() return mod:GetControls() end)
        if ok2 then controls = c end
    end
    return controls
end

local function moveInput()
    local c = getControls()
    if c then
        local ok, v = pcall(function() return c:GetMoveVector() end)
        if ok and v and v.Magnitude > 0.01 then return v end
    end
    local x, z = 0, 0
    if UIS:IsKeyDown(Enum.KeyCode.W) then z = z - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.S) then z = z + 1 end
    if UIS:IsKeyDown(Enum.KeyCode.A) then x = x - 1 end
    if UIS:IsKeyDown(Enum.KeyCode.D) then x = x + 1 end
    local ok, state = pcall(function() return UIS:GetGamepadState(Enum.UserInputType.Gamepad1) end)
    if ok and state then
        for _, inp in ipairs(state) do
            if inp.KeyCode == Enum.KeyCode.Thumbstick1 then
                x = x + inp.Position.X
                z = z - inp.Position.Y
            end
        end
    end
    if x ~= 0 or z ~= 0 then return Vector3.new(x, 0, z) end
    return nil
end

local function stopFly()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.PlatformStand = false end) end
    if Fly._bv then Fly._bv:Destroy(); Fly._bv = nil end
    if Fly._bg then Fly._bg:Destroy(); Fly._bg = nil end
    flyBtnGui.Enabled = false
end

local function applyFly()
    if not CFG.Fly then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    if not Fly._bv or Fly._bv.Parent ~= root then
        if Fly._bv then Fly._bv:Destroy() end
        if Fly._bg then Fly._bg:Destroy() end
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = root
        local bg = Instance.new("BodyGyro")
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.P = 10000
        bg.D = 500
        bg.CFrame = CFrame.new(root.Position)
        bg.Parent = root
        Fly._bv, Fly._bg = bv, bg
    end
    if not hum.PlatformStand then hum.PlatformStand = true end
    local mv = moveInput()
    local dir = Vector3.zero
    if mv then dir = Camera.CFrame.LookVector * (-mv.Z) + Camera.CFrame.RightVector * mv.X end
    local vy = 0
    if Fly._up or UIS:IsKeyDown(Enum.KeyCode.Space) then vy = vy + 1 end
    if Fly._down or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then vy = vy - 1 end
    if vy ~= 0 then dir = dir + Vector3.new(0, vy, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit end
    Fly._bv.Velocity = dir * CFG.FlySpeed
    Fly._bg.CFrame = CFrame.new(root.Position)
    flyBtnGui.Enabled = UIS.TouchEnabled
end

--==================== TELEPORT ====================--
local SLOT_COUNT = 3

local Teleport = {
    Offset = 3,
    SlotIndex = 1,
    Slots = {},
}
G.RomanTeleport = Teleport

local slotLabels = {}
for i = 1, SLOT_COUNT do slotLabels[i] = tostring(i) .. " · empty" end

local function refreshSlots()
    for i = 1, SLOT_COUNT do
        slotLabels[i] = tostring(i) .. (Teleport.Slots[i] and " · set" or " · empty")
    end
    if refs.slot then refs.slot.refresh() end
end

local function myRoot()
    local char = LP.Character
    return char, char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportNow()
    local _, root = myRoot()
    local tchar = Target and Target.Character
    local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
    if not root or not troot then return false end
    local delta = root.Position - troot.Position
    local dir = delta.Magnitude > 0.1 and delta.Unit or troot.CFrame.LookVector
    local dest = troot.Position + dir * Teleport.Offset
    root.CFrame = CFrame.new(dest, dest + root.CFrame.LookVector)
    root.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function flashBtn(b)
    if not b then return end
    b.BackgroundColor3 = CFG.Accent
    task.delay(0.18, function()
        if b.Parent then b.BackgroundColor3 = Color3.fromRGB(23, 23, 27) end
    end)
end

local function doTeleport()
    local ok = teleportNow()
    flashBtn(tpBtn)
    notify("Teleport", ok and "to target" or "no target")
end

local function savePosition()
    local _, root = myRoot()
    if not root then notify("Position", "no character"); return end
    Teleport.Slots[Teleport.SlotIndex] = root.CFrame
    refreshSlots()
    notify("Position", "saved slot " .. Teleport.SlotIndex)
end

local function loadPosition()
    local _, root = myRoot()
    if not root then notify("Position", "no character"); return end
    local cf = Teleport.Slots[Teleport.SlotIndex]
    if not cf then notify("Position", "slot " .. Teleport.SlotIndex .. " is empty"); return end
    root.CFrame = cf
    root.AssemblyLinearVelocity = Vector3.zero
    -- re-assert once; a game controller or a seat can eat the first set
    task.delay(0.06, function()
        local _, r = myRoot()
        if r then
            r.CFrame = cf
            r.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    notify("Position", "loaded slot " .. Teleport.SlotIndex)
end

local function clearSlot()
    Teleport.Slots[Teleport.SlotIndex] = nil
    refreshSlots()
    notify("Position", "slot " .. Teleport.SlotIndex .. " cleared")
end

refreshSlots()

--==================== MOBILE BUTTONS ====================--
local mobileGui = Instance.new("ScreenGui")
mobileGui.Name = "RomanMobile"
mobileGui.ResetOnSpawn = false
mobileGui.IgnoreGuiInset = true
mobileGui.Parent = GUI_PARENT

local function mobileButton(text, y, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 58, 0, 58)
    b.Position = UDim2.new(1, -74, 0.5, y)
    b.BackgroundColor3 = Color3.fromRGB(23, 23, 27)
    b.BackgroundTransparency = 0.12
    b.BorderSizePixel = 0
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Parent = mobileGui
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke")
    s.Color = CFG.Accent
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = b
    b.MouseButton1Click:Connect(onClick)
    return b
end

tpBtn = mobileButton("TP", 122, doTeleport)
mobileButton("SAV", 190, savePosition)
mobileButton("LOD", 258, loadPosition)

local function updateMobile() mobileGui.Enabled = UIS.TouchEnabled end
updateMobile()
UIS:GetPropertyChangedSignal("TouchEnabled"):Connect(updateMobile)

--==================== WALK / JUMP / AFK ====================--
local baseWalk = 16
local function captureWalk()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed > 0 then baseWalk = hum.WalkSpeed end
end
captureWalk()

LP.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    task.wait()
    captureWalk()
    if CFG.Fly then task.wait(0.2); applyFly() end
end)

local function applyWalk()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CFG.WalkOn then
        if hum.WalkSpeed ~= CFG.WalkSpeed then hum.WalkSpeed = CFG.WalkSpeed end
    elseif baseWalk and hum.WalkSpeed ~= baseWalk then
        hum.WalkSpeed = baseWalk
    end
end

UIS.JumpRequest:Connect(function()
    if not CFG.InfiniteJump then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end)

LP.Idled:Connect(function()
    if not CFG.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==================== AUTO RE-EQUIP ====================--
local AutoEquip = {
    Enabled = false, Double = true, Gap = 0.08, OnlyGuns = false,
    _last = {}, _pending = {}, _busy = false,
}
G.RomanAutoEquip = AutoEquip

local function getCharHum()
    local char = LP.Character
    return char, char and char:FindFirstChildOfClass("Humanoid")
end

local function equipTwice(tool)
    if not tool or not tool.Parent then return end
    local _, hum = getCharHum()
    if not hum or hum.Health <= 0 then return end
    pcall(function() hum:EquipTool(tool) end)
    if AutoEquip.Double then
        task.wait(AutoEquip.Gap)
        local _, hum2 = getCharHum()
        if hum2 and hum2.Health > 0 and tool.Parent then
            pcall(function() hum2:UnequipTools() end)
            task.wait(0.02)
            local _, hum3 = getCharHum()
            if hum3 and hum3.Health > 0 and tool.Parent then
                pcall(function() hum3:EquipTool(tool) end)
            end
        end
    end
end

local function requestEquip(tool)
    if not AutoEquip.Enabled then return end
    if not tool or not tool:IsA("Tool") or not tool.Parent then return end
    if AutoEquip.OnlyGuns and not isGun(tool.Name) then return end
    local now = tick()
    if AutoEquip._last[tool] and now - AutoEquip._last[tool] < (AutoEquip.Gap + 0.2) then return end
    AutoEquip._last[tool] = now
    AutoEquip._pending[tool] = true
    if AutoEquip._busy then return end
    AutoEquip._busy = true
    task.spawn(function()
        while true do
            local nextTool
            for t in pairs(AutoEquip._pending) do nextTool = t; break end
            if not nextTool then break end
            AutoEquip._pending[nextTool] = nil
            if nextTool.Parent then equipTwice(nextTool) end
        end
        AutoEquip._busy = false
    end)
end

local function scanBackpack()
    local bp = LP:FindFirstChildOfClass("Backpack")
    if not bp then return end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") then requestEquip(t) end
    end
end

local function bindBackpack(bp)
    if not bp then return end
    bp.ChildAdded:Connect(function(c)
        if c:IsA("Tool") then requestEquip(c) end
    end)
end
do
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then bindBackpack(bp) end
end
LP.ChildAdded:Connect(function(c)
    if c:IsA("Backpack") then bindBackpack(c) end
end)
LP.CharacterAdded:Connect(function(char)
    task.wait(0.25)
    if AutoEquip.Enabled then scanBackpack() end
end)

--==================== LIGHTING ====================--
local lightStore, fogStore = {}, {}
local function setFullbright(on)
    if on then
        if not lightStore.on then
            lightStore.on = true
            lightStore.b, lightStore.a, lightStore.o =
                Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient
        end
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    elseif lightStore.on then
        lightStore.on = false
        Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient =
            lightStore.b, lightStore.a, lightStore.o
    end
end
local function setNoFog(on)
    if on then
        if not fogStore.on then
            fogStore.on = true
            fogStore.e, fogStore.s = Lighting.FogEnd, Lighting.FogStart
        end
        Lighting.FogEnd = 1e5
        Lighting.FogStart = 0
    elseif fogStore.on then
        fogStore.on = false
        Lighting.FogEnd, Lighting.FogStart = fogStore.e, fogStore.s
    end
end

--==================== UI ====================--
local theme = {
    bg = Color3.fromRGB(16, 16, 18),
    panel = Color3.fromRGB(23, 23, 27),
    side = Color3.fromRGB(18, 18, 21),
    row = Color3.fromRGB(29, 29, 34),
    stroke = Color3.fromRGB(255, 255, 255),
    text = Color3.fromRGB(240, 240, 246),
    sub = Color3.fromRGB(138, 138, 150),
    track = Color3.fromRGB(55, 55, 63),
    knob = Color3.fromRGB(235, 235, 240),
}

local ui = Instance.new("ScreenGui")
ui.Name = "RomanLite"
ui.ResetOnSpawn = false
ui.IgnoreGuiInset = true
ui.DisplayOrder = 1000
ui.Parent = GUI_PARENT

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = inst
end
local function stroke(inst, col, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or theme.stroke
    s.Thickness = 1
    s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local toastHolder = Instance.new("Frame")
toastHolder.Size = UDim2.new(0, 220, 0, 400)
toastHolder.Position = UDim2.new(1, -14, 1, -14)
toastHolder.AnchorPoint = Vector2.new(1, 1)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = ui
local toastLayout = Instance.new("UIListLayout", toastHolder)
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.Padding = UDim.new(0, 8)

function notify(title, desc)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = theme.panel
    card.BorderSizePixel = 0
    card.LayoutOrder = -math.floor(tick())
    card.Parent = toastHolder
    corner(card, 10)
    stroke(card, theme.stroke, 0.86)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -14)
    bar.Position = UDim2.new(0, 8, 0.5, 0)
    bar.AnchorPoint = Vector2.new(0, 0.5)
    bar.BackgroundColor3 = CFG.Accent
    bar.BorderSizePixel = 0
    bar.Parent = card
    corner(bar, 2)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = title
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextColor3 = theme.text
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Position = UDim2.new(0, 18, 0, 5)
    t.Size = UDim2.new(1, -30, 0, 15)
    t.Parent = card
    local d = Instance.new("TextLabel")
    d.BackgroundTransparency = 1
    d.Text = desc or ""
    d.Font = Enum.Font.Gotham
    d.TextSize = 11
    d.TextColor3 = theme.sub
    d.TextXAlignment = Enum.TextXAlignment.Left
    d.Position = UDim2.new(0, 18, 0, 22)
    d.Size = UDim2.new(1, -26, 0, 14)
    d.Parent = card
    task.delay(2.2, function()
        if card.Parent then card:Destroy() end
    end)
end

local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0, 0.5)
win.Size = UDim2.new(0, 240, 0, 540)
win.Position = UDim2.new(0, 14, 0.5, 0)
win.BackgroundColor3 = theme.bg
win.BorderSizePixel = 0
win.Parent = ui
corner(win, 14)
stroke(win, theme.stroke, 0.84)

local winScale = Instance.new("UIScale", win)

local function fitWindow()
    local vp = (Camera and Camera.ViewportSize) or Vector2.new(1280, 720)
    local h = math.clamp(vp.Y - 50, 340, 620)
    win.Size = UDim2.new(0, 240, 0, h)
    winScale.Scale = math.clamp(math.min(1, (vp.Y - 20) / h, (vp.X - 20) / 240), 0.5, 1.4)
end
fitWindow()
if Camera then
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local c = Workspace.CurrentCamera
    if not c then return end
    Camera = c
    fitWindow()
    c:GetPropertyChangedSignal("ViewportSize"):Connect(fitWindow)
end)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 42)
top.BackgroundTransparency = 1
top.Parent = win

local logo = Instance.new("Frame")
logo.Size = UDim2.new(0, 22, 0, 22)
logo.Position = UDim2.new(0, 12, 0.5, -11)
logo.BackgroundColor3 = CFG.Accent
logo.BorderSizePixel = 0
logo.Parent = top
corner(logo, 6)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Text = "ROMAN"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = theme.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 42, 0, 6)
title.Size = UDim2.new(0, 160, 0, 16)
title.Parent = top

local sub = Instance.new("TextLabel")
sub.BackgroundTransparency = 1
sub.Text = "lite"
sub.Font = Enum.Font.Gotham
sub.TextSize = 10
sub.TextColor3 = theme.sub
sub.TextXAlignment = Enum.TextXAlignment.Left
sub.Position = UDim2.new(0, 43, 0, 21)
sub.Size = UDim2.new(0, 160, 0, 12)
sub.Parent = top

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0.5, -12)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.TextColor3 = theme.sub
closeBtn.Parent = top
closeBtn.MouseButton1Click:Connect(function() win.Visible = false end)

local dragging, dragStart, startPos = false, nil, nil
top.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        dragging, dragStart, startPos = true, i.Position, win.Position
    end
end)
top.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                 startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local tabs = Instance.new("ScrollingFrame")
tabs.Size = UDim2.new(1, -20, 0, 30)
tabs.Position = UDim2.new(0, 10, 0, 48)
tabs.BackgroundTransparency = 1
tabs.BorderSizePixel = 0
tabs.ScrollBarThickness = 2
tabs.ScrollingDirection = Enum.ScrollingDirection.X
tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
tabs.CanvasSize = UDim2.new(0, 0, 0, 0)
tabs.Parent = win
local tabLayout = Instance.new("UIListLayout", tabs)
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 5)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -92)
content.Position = UDim2.new(0, 10, 0, 84)
content.BackgroundTransparency = 1
content.Parent = win

local tabsDef = {
    { id = "combat",  label = "Combat" },
    { id = "gun",     label = "Gun" },
    { id = "player",  label = "Player" },
    { id = "visuals", label = "Visuals" },
    { id = "misc",    label = "Misc" },
}
local sections, tabButtons = {}, {}

for i, def in ipairs(tabsDef) do
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.Visible = false
    sf.Parent = content
    local lay = Instance.new("UIListLayout", sf)
    lay.Padding = UDim.new(0, 6)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingRight = UDim.new(0, 7)
    pad.PaddingBottom = UDim.new(0, 8)
    sections[def.id] = sf

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 58, 0, 30)
    b.BackgroundColor3 = theme.side
    b.BorderSizePixel = 0
    b.Text = ""
    b.LayoutOrder = i
    b.Parent = tabs
    corner(b, 8)
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = def.label
    lbl.Font = FONT_MED
    lbl.TextSize = 10
    lbl.TextColor3 = theme.sub
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Parent = b
    tabButtons[def.id] = { bg = b, lbl = lbl }
    b.MouseButton1Click:Connect(function()
        for id, f in pairs(sections) do f.Visible = (id == def.id) end
        for id, tb in pairs(tabButtons) do
            tb.bg.BackgroundColor3 = (id == def.id) and theme.row or theme.side
            tb.lbl.TextColor3 = (id == def.id) and theme.text or theme.sub
        end
    end)
end

local function baseRow(parent, h)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, h or 44)
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
    l.Font = FONT_MED; l.TextSize = 12; l.TextColor3 = theme.text
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
    knob.BackgroundColor3 = theme.knob
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 8)
    local function render()
        local on = getter()
        track.BackgroundColor3 = on and CFG.Accent or theme.track
        knob.Position = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
    end
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        setter(not getter())
        render()
        notify(label, getter() and "on" or "off")
    end)
    render()
    return { refresh = render }
end

local function makeSlider(parent, label, minV, maxV, getter, setter, decimals)
    local row = baseRow(parent, 44)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = FONT_MED; l.TextSize = 12; l.TextColor3 = theme.text
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Position = UDim2.new(0, 12, 0, 6); l.Size = UDim2.new(1, -70, 0, 15)
    l.Parent = row
    local val = Instance.new("TextLabel")
    val.BackgroundTransparency = 1
    val.Font = Enum.Font.GothamBold; val.TextSize = 12; val.TextColor3 = theme.text
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Position = UDim2.new(1, -70, 0, 6); val.Size = UDim2.new(0, 58, 0, 15)
    val.Parent = row
    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.new(0, 12, 0, 28)
    track.BackgroundColor3 = theme.track
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 5)
    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = CFG.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    corner(fill, 5)
    local function render(v)
        if decimals and decimals > 0 then
            val.Text = string.format("%." .. decimals .. "f", v)
        else
            val.Text = tostring(math.floor(v + 0.5))
        end
        fill.Size = UDim2.new((v - minV) / (maxV - minV), 0, 1, 0)
    end
    local drag = false
    local function setFromX(x)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((x - track.AbsolutePosition.X) / w, 0, 1)
        local raw = minV + rel * (maxV - minV)
        local v = (decimals and decimals > 0) and raw or math.floor(raw + 0.5)
        render(v); setter(v)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag = true; parent.ScrollingEnabled = false; setFromX(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch) then
            setFromX(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch) then
            drag = false; parent.ScrollingEnabled = true
        end
    end)
    render(getter())
    return { refresh = render }
end

local function makeCycle(parent, label, desc, options, getIndex, setIndex)
    local row = baseRow(parent, 44)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = FONT_MED; l.TextSize = 12; l.TextColor3 = theme.text
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
    chipLbl.BackgroundTransparency = 1
    chipLbl.Font = Enum.Font.GothamBold
    chipLbl.TextSize = 10
    chipLbl.TextColor3 = theme.text
    chipLbl.TextTruncate = Enum.TextTruncate.AtEnd
    chipLbl.Size = UDim2.new(1, -8, 1, 0)
    chipLbl.Parent = chip
    local function render() chipLbl.Text = options[getIndex()] or "?" end
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        local i = (getIndex() % #options) + 1
        setIndex(i)
        render()
        notify(label, options[i])
    end)
    render()
    return { refresh = render }
end

local function makeButton(parent, label, onClick)
    local row = baseRow(parent, 38)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1; l.Text = label
    l.Font = Enum.Font.GothamBold; l.TextSize = 12; l.TextColor3 = theme.text
    l.Position = UDim2.new(0, 12, 0, 0); l.Size = UDim2.new(1, -20, 1, 0)
    l.Parent = row
    local btn = Instance.new("TextButton")
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = row
    btn.MouseButton1Click:Connect(onClick)
end

local function makeHeader(parent, text)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = string.upper(text)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextColor3 = theme.sub
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, -10, 0, 16)
    l.Parent = parent
end

--==================== PAGES ====================--
do
    local p = sections.combat
    makeHeader(p, "aim")
    refs.silent = makeToggle(p, "Silent Aim", "Q to toggle",
        function() return CFG.Aim end,
        function(v) CFG.Aim = v end)
    makeToggle(p, "Cursor Lock", "Only lock what the cursor is on",
        function() return CFG.CursorLock end, function(v) CFG.CursorLock = v end)
    makeSlider(p, "Cursor Radius", 10, 200,
        function() return CFG.CursorRadius end, function(v) CFG.CursorRadius = v end)
    makeSlider(p, "FOV", 5, 180, function() return CFG.FOV end, function(v) CFG.FOV = v end)
    makeCycle(p, "Aim Part", "Hitbox to target", { "Head", "Torso" },
        function() return CFG.AimPart == "Head" and 1 or 2 end,
        function(i) CFG.AimPart = i == 1 and "Head" or "Torso" end)
    makeToggle(p, "Team Check", "Ignore teammates",
        function() return CFG.TeamCheck end, function(v) CFG.TeamCheck = v; refreshTargetList() end)
    makeToggle(p, "Visible Only", "Require line of sight",
        function() return CFG.VisibleCheck end, function(v) CFG.VisibleCheck = v end)
    makeToggle(p, "Ignore Knocked", "Skip downed players",
        function() return CFG.IgnoreKnocked end, function(v) CFG.IgnoreKnocked = v end)
    makeToggle(p, "Forcefield Check", "Skip spawn-protected",
        function() return CFG.ForceFieldCheck end, function(v) CFG.ForceFieldCheck = v end)
    makeToggle(p, "Prediction", "Lead moving targets",
        function() return CFG.Predict end, function(v) CFG.Predict = v end)
    makeSlider(p, "Projectile Speed", 100, 3000,
        function() return CFG.ProjectileSpeed end, function(v) CFG.ProjectileSpeed = v end)
    makeSlider(p, "Max Lead", 0, 1,
        function() return CFG.MaxLead end, function(v) CFG.MaxLead = v end, 2)
    makeToggle(p, "Target Highlight", "Outline the target",
        function() return CFG.Highlight end, function(v) CFG.Highlight = v end)

    makeHeader(p, "single target")
    makeButton(p, "Clear Lock", function()
        TargetLock.Player = nil
        refreshTargetList()
        notify("Target Lock", "Cleared")
    end)

    local lockList = Instance.new("Frame")
    lockList.Size = UDim2.new(1, 0, 0, 0)
    lockList.AutomaticSize = Enum.AutomaticSize.Y
    lockList.BackgroundTransparency = 1
    lockList.Parent = p
    local lockLayout = Instance.new("UIListLayout", lockList)
    lockLayout.Padding = UDim.new(0, 4)
    lockLayout.SortOrder = Enum.SortOrder.LayoutOrder

    function refreshTargetList()
        for _, c in ipairs(lockList:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local order = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if isEnemy(plr) then
                order += 1
                local locked = (TargetLock.Player == plr)
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(1, 0, 0, 30)
                b.BackgroundColor3 = locked and CFG.Accent or theme.side
                b.BackgroundTransparency = locked and 0 or 0.1
                b.BorderSizePixel = 0
                b.Text = (locked and "● " or "") .. displayOf(plr)
                b.Font = FONT_MED
                b.TextSize = 12
                b.TextColor3 = locked and Color3.new(1, 1, 1) or theme.text
                b.LayoutOrder = order
                b.Parent = lockList
                corner(b, 8)
                b.MouseButton1Click:Connect(function()
                    if TargetLock.Player == plr then
                        TargetLock.Player = nil
                        notify("Target Lock", "Unlocked")
                    else
                        TargetLock.Player = plr
                        notify("Target Lock", displayOf(plr))
                    end
                    refreshTargetList()
                end)
            end
        end
    end
    refreshTargetList()

    Players.PlayerAdded:Connect(function(plr)
        plr:GetPropertyChangedSignal("Team"):Connect(refreshTargetList)
        refreshTargetList()
    end)
    Players.PlayerRemoving:Connect(function(plr)
        if TargetLock.Player == plr then TargetLock.Player = nil end
        refreshTargetList()
    end)
    if LP.Team then
        LP:GetPropertyChangedSignal("Team"):Connect(refreshTargetList)
    end

    makeHeader(p, "anti aim")
    refs.antiaim = makeToggle(p, "Anti Aim", "Desync body facing from camera",
        function() return AntiAim.Enabled end, function(v) AntiAim.Enabled = v end)
    makeCycle(p, "AA Mode", "Spin / jitter / random / sideways / backwards",
        { "Spin", "Jitter", "Random", "Sideways", "Backwards" },
        function() return AntiAim.Mode end,
        function(i) AntiAim.Mode = i end)
    makeSlider(p, "AA Speed", 1, 60,
        function() return AntiAim.Speed end, function(v) AntiAim.Speed = v end)
    makeSlider(p, "AA Amount", 0, 180,
        function() return AntiAim.Amount end, function(v) AntiAim.Amount = v end)
end

do
    local p = sections.gun
    makeHeader(p, "fire rate")
    refs.rapid = makeToggle(p, "Rapid Fire", "Force max fire rate",
        function() return RapidFire.Enabled end,
        function(v)
            RapidFire.Enabled = v
            if v then
                RapidFire._lastScan = 0
                RapidFireScan()
            else
                RapidFireRestore()
            end
        end)
    makeSlider(p, "Fire Rate", 0.001, 0.5,
        function() return RapidFire.Override end,
        function(v) RapidFire.Override = v end, 3)
    makeToggle(p, "Only If Slower", "Keep values already faster",
        function() return RapidFire.OnlyIfHigher end,
        function(v) RapidFire.OnlyIfHigher = v end)
    makeToggle(p, "Loose Match", "Also match any 'rate'/'speed' attr",
        function() return RapidFire.Loose end,
        function(v) RapidFire.Loose = v; RapidFire._memo = {} end)
    makeSlider(p, "Apply Rate", 0.05, 0.5,
        function() return RapidFire.Interval end,
        function(v) RapidFire.Interval = v end, 2)
    makeSlider(p, "Scan Rate", 0.5, 5,
        function() return RapidFire.ScanInterval end,
        function(v) RapidFire.ScanInterval = v end, 2)
    makeButton(p, "Re-scan Targets", function()
        RapidFire._lastScan = 0
        RapidFireScan()
        notify("Rapid Fire", "Re-scanning")
    end)

    makeHeader(p, "weapon")
    refs.autoequip = makeToggle(p, "Auto Re-Equip", "Equip guns the instant they appear",
        function() return AutoEquip.Enabled end,
        function(v) AutoEquip.Enabled = v; if v then scanBackpack() end end)
    makeToggle(p, "Double Equip", "Equip twice fast",
        function() return AutoEquip.Double end, function(v) AutoEquip.Double = v end)
    makeSlider(p, "Equip Gap", 0.02, 0.3,
        function() return AutoEquip.Gap end, function(v) AutoEquip.Gap = v end, 2)
    makeToggle(p, "Guns Only", "Only tools with gun-like names",
        function() return AutoEquip.OnlyGuns end, function(v) AutoEquip.OnlyGuns = v end)
end

do
    local p = sections.player
    makeHeader(p, "movement")
    makeToggle(p, "Walkspeed", "Override walk speed",
        function() return CFG.WalkOn end, function(v) CFG.WalkOn = v end)
    makeSlider(p, "Speed", 1, 100, function() return CFG.WalkSpeed end, function(v) CFG.WalkSpeed = v end)
    refs.noclip = makeToggle(p, "Noclip", "N to toggle (bypasses anti-noclip)",
        function() return CFG.Noclip end,
        function(v) CFG.Noclip = v; if not v then restoreCollide() end end)
    refs.fly = makeToggle(p, "Fly", "F to toggle",
        function() return CFG.Fly end,
        function(v)
            CFG.Fly = v
            if v then
                local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if root then root.CFrame = root.CFrame + Vector3.new(0, 6, 0) end
                applyFly()
            else
                stopFly()
            end
        end)
    makeSlider(p, "Fly Speed", 10, 300, function() return CFG.FlySpeed end, function(v) CFG.FlySpeed = v end)
    makeToggle(p, "Infinite Jump", "Jump mid-air",
        function() return CFG.InfiniteJump end, function(v) CFG.InfiniteJump = v end)
    makeToggle(p, "Anti-AFK", "Stay online",
        function() return CFG.AntiAFK end, function(v) CFG.AntiAFK = v end)

    makeHeader(p, "teleport")
    makeButton(p, "Teleport To Target (T / Y)", doTeleport)
    makeSlider(p, "TP Distance", 2, 30,
        function() return Teleport.Offset end, function(v) Teleport.Offset = v end)

    makeHeader(p, "positions")
    refs.slot = makeCycle(p, "Slot", "Which position save/load uses", slotLabels,
        function() return Teleport.SlotIndex end,
        function(i) Teleport.SlotIndex = i end)
    makeButton(p, "Save Position (Z)", savePosition)
    makeButton(p, "Load Position (X)", loadPosition)
    makeButton(p, "Clear Slot", clearSlot)
end

do
    local p = sections.visuals
    makeHeader(p, "esp")
    makeToggle(p, "ESP", "Draw players through walls",
        function() return CFG.ESP end, function(v) CFG.ESP = v end)
    makeToggle(p, "Boxes", "2D bounding box",
        function() return CFG.Boxes end, function(v) CFG.Boxes = v end)
    makeToggle(p, "Names", "Display name above box",
        function() return CFG.Names end, function(v) CFG.Names = v end)
    makeToggle(p, "Skeleton", "Bone lines",
        function() return CFG.Skeleton end, function(v) CFG.Skeleton = v end)
end

do
    local p = sections.misc
    makeHeader(p, "world")
    makeToggle(p, "Fullbright", "Brighten lighting",
        function() return CFG.Fullbright end,
        function(v) CFG.Fullbright = v; setFullbright(v) end)
    makeToggle(p, "No Fog", "Remove distance fog",
        function() return CFG.NoFog end, function(v) CFG.NoFog = v; setNoFog(v) end)
    makeHeader(p, "session")
    makeButton(p, "Reset Character", function()
        if LP.Character then pcall(function() LP.Character:BreakJoints() end) end
    end)
    makeButton(p, "Rejoin Server", function()
        notify("Rejoin", "Teleporting...")
        pcall(function() game:GetService("TeleportService"):Teleport(game.PlaceId, LP) end)
    end)
    makeButton(p, "Play Song", function()
        playSong()
        notify("Music", "Playing")
    end)
    makeButton(p, "Unload", function()
        for _, n in ipairs({ "RomanLite", "RomanESP", "RomanFOV", "RomanFlyBtn", "RomanPopup", "RomanMobile" }) do
            local g = GUI_PARENT:FindFirstChild(n)
            if g then g:Destroy() end
        end
    end)
end

sections.combat.Visible = true
tabButtons.combat.bg.BackgroundColor3 = theme.row
tabButtons.combat.lbl.TextColor3 = theme.text

--==================== PILL ====================--
local pill = Instance.new("TextButton")
pill.Size = UDim2.new(0, 110, 0, 36)
pill.Position = UDim2.new(0, 14, 0, 54)
pill.BackgroundColor3 = theme.panel
pill.BackgroundTransparency = 0.05
pill.BorderSizePixel = 0
pill.Text = ""
pill.Parent = ui
corner(pill, 18)
stroke(pill, theme.stroke, 0.82)

local pillDot = Instance.new("Frame")
pillDot.Size = UDim2.new(0, 8, 0, 8)
pillDot.Position = UDim2.new(0, 13, 0.5, -4)
pillDot.BackgroundColor3 = CFG.Accent
pillDot.BorderSizePixel = 0
pillDot.Parent = pill
corner(pillDot, 4)

local pillTxt = Instance.new("TextLabel")
pillTxt.BackgroundTransparency = 1
pillTxt.Text = "Roman"
pillTxt.Font = Enum.Font.GothamBold
pillTxt.TextSize = 13
pillTxt.TextColor3 = theme.text
pillTxt.TextXAlignment = Enum.TextXAlignment.Left
pillTxt.Position = UDim2.new(0, 28, 0, 0)
pillTxt.Size = UDim2.new(1, -34, 1, 0)
pillTxt.Parent = pill

local pillDrag, pillMoved, pillStart, pillStartPos = false, false, nil, nil
pill.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        pillDrag, pillMoved, pillStart, pillStartPos = true, false, i.Position, pill.Position
    end
end)
UIS.InputChanged:Connect(function(i)
    if not pillDrag then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - pillStart
        if math.abs(d.X) > 6 or math.abs(d.Y) > 6 then pillMoved = true end
        if pillMoved then
            pill.Position = UDim2.new(pillStartPos.X.Scale, pillStartPos.X.Offset + d.X,
                                      pillStartPos.Y.Scale, pillStartPos.Y.Offset + d.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(i)
    if not pillDrag then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        pillDrag = false
        if not pillMoved then win.Visible = not win.Visible end
    end
end)

--==================== KEYS + GAMEPAD ====================--
UIS.InputBegan:Connect(function(input, gp)
    local kc = input.KeyCode
    local isPad = typeof(kc) == "EnumItem" and string.sub(kc.Name, 1, 6) == "Button"
    if gp and not isPad then return end

    if kc == CFG.AimKey then
        CFG.Aim = not CFG.Aim
        if refs.silent then refs.silent.refresh() end
        notify("Silent Aim", CFG.Aim and "on" or "off")
    elseif kc == CFG.NoclipKey then
        CFG.Noclip = not CFG.Noclip
        if not CFG.Noclip then restoreCollide() end
        if refs.noclip then refs.noclip.refresh() end
        notify("Noclip", CFG.Noclip and "on" or "off")
    elseif kc == CFG.FlyKey then
        CFG.Fly = not CFG.Fly
        if CFG.Fly then
            local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = root.CFrame + Vector3.new(0, 6, 0) end
            applyFly()
        else
            stopFly()
        end
        if refs.fly then refs.fly.refresh() end
        notify("Fly", CFG.Fly and "on" or "off")
    elseif kc == CFG.SavePosKey or kc == Enum.KeyCode.ButtonX then
        savePosition()
    elseif kc == CFG.LoadPosKey or kc == Enum.KeyCode.ButtonB then
        loadPosition()
    elseif kc == Enum.KeyCode.T or kc == Enum.KeyCode.ButtonY or kc == Enum.KeyCode.ButtonSelect then
        doTeleport()
    end
end)

--==================== POPUP + SONG ====================--
local popupGui = Instance.new("ScreenGui")
popupGui.Name = "RomanPopup"
popupGui.ResetOnSpawn = false
popupGui.IgnoreGuiInset = true
popupGui.DisplayOrder = 5000
popupGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
popupGui.Parent = GUI_PARENT

local popupBusy = false

local function newSong()
    local song = Instance.new("Sound")
    song.SoundId = SONG_ID
    song.Volume = 0
    song.Looped = false
    song.PlayOnRemove = false
    song.Parent = SoundService
    return song
end

local function killSong(song)
    if not song then return end
    pcall(function() song.Volume = 0 end)
    pcall(function() song:Stop() end)
    pcall(function() song:Destroy() end)
end

local function startSong(song, volume)
    task.spawn(function()
        local t0 = os.clock()
        while not song.IsLoaded and song.Parent and os.clock() - t0 < 5 do
            task.wait(0.05)
        end
        if not song.Parent then return end
        if SONG_START > 0 then pcall(function() song.TimePosition = SONG_START end) end
        song.Volume = volume or 0.5
        pcall(function() song:Play() end)
    end)
end

function playSong()
    local song = newSong()
    song.Ended:Connect(function() task.delay(0.05, function() killSong(song) end) end)
    startSong(song, 0.5)
    task.delay(300, function() killSong(song) end)
    return song
end

function showPopup()
    if popupBusy then return end
    popupBusy = true
    local pop = Instance.new("Frame")
    pop.AnchorPoint = Vector2.new(0.5, 0.5)
    pop.Position = UDim2.new(0.5, 0, 0.5, 0)
    pop.Size = UDim2.new(0, 360, 0, 120)
    pop.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
    pop.BackgroundTransparency = 1
    pop.BorderSizePixel = 0
    pop.ZIndex = 5
    pop.Parent = popupGui
    corner(pop, 20)
    local ps = stroke(pop, Color3.fromRGB(255, 255, 255), 1)
    local popScale = Instance.new("UIScale", pop)
    popScale.Scale = 0.9
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = "MADE BY ROMAN"
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 26
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextTransparency = 1
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.ZIndex = 6
    lbl.Parent = pop
    local song = newSong()
    startSong(song, 0.5)
    local done = false
    local function finish()
        if done then return end
        done = true
        killSong(song)
        if pop.Parent then pop:Destroy() end
        popupBusy = false
    end
    task.delay(FADE_IN + POPUP_TIME + FADE_OUT + 1.5, finish)
    task.spawn(function()
        local t = 0
        while t < FADE_IN do
            t = t + task.wait()
            local a = math.clamp(t / FADE_IN, 0, 1)
            pop.BackgroundTransparency = 1 - a
            ps.Transparency = 1 - 0.25 * a
            lbl.TextTransparency = 1 - a
            popScale.Scale = 0.9 + 0.1 * a
        end
        pop.BackgroundTransparency = 0
        ps.Transparency = 0.75
        lbl.TextTransparency = 0
        popScale.Scale = 1
        task.wait(math.max(0, POPUP_TIME - FADE_IN - FADE_OUT))
        local t2 = 0
        while t2 < FADE_OUT do
            t2 = t2 + task.wait()
            local a = math.clamp(t2 / FADE_OUT, 0, 1)
            local e = a * a * (3 - 2 * a)
            pop.BackgroundTransparency = e
            ps.Transparency = 0.75 + 0.25 * e
            lbl.TextTransparency = e
            popScale.Scale = 1 - 0.08 * e
            pop.Position = UDim2.new(0.5, 0, 0.5, math.floor(-30 * e))
            if song.Parent then song.Volume = 0.5 * (1 - e) end
        end
        finish()
    end)
end

--==================== LOOP ====================--
RunService.RenderStepped:Connect(function(dt)
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera end
    if not Camera then return end
    findTarget()
    updateHighlight()
    updateESP()
    updateRing()
    applyWalk()
    applyFly()
    applyAntiAim()
    if CFG.Noclip then noclipChar() end
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

--==================== LOAD ====================--
task.delay(0.5, showPopup)
task.delay(0.6, function()
    notify("Roman Lite", "Q aim | T/Y/pad TP | Z save | X load | N noclip | F fly")
end)

print("[Roman Lite] loaded | hooks=" .. tostring(installed))
