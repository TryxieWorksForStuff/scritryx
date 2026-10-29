--[[
	VEE'S GAMESHOW GUI (admin + debug, solo versión de prueba)
	Estilo visual basado en DandysUI (uso libre según su autor).
	Tipo: LocalScript
	Ubicación: StarterPlayer > StarterPlayerScripts

	Toda la configuración está en la tabla CONFIG de abajo.
	IMPORTANTE: quítalo antes de publicar la versión final. -V0.1
]]

local CONFIG = {
	-- Nombres que ve el usuario
	PanelName     = "Vee's Gameshow GUI",
	AutoButton    = "Auto Prompt",
	TpButton      = "Tp To Machine",
	AutoTpButton  = "AutoTPMachine",
	DetectButton  = "DetectMonster",
	EscapeButton  = "AutoHide",
	NoCollideButton = "NoCollide Maq",
	AutoPickButton  = "AutoPickItem",
	ElevatorButton  = "AutoElevator",
	ResearchButton  = "Research",
	AutoAllButton   = "Automatizar",

	-- Tecla para mostrar/ocultar el panel en PC (en celular usa el botón V)
	ToggleKey = Enum.KeyCode.RightControl,

	-- Nombres de los objetos dentro del workspace
	RoomFolder       = "CurrentRoom",
	GeneratorsFolder = "Generators",
	GeneratorName    = "Generator",
	PromptPart       = "Prompt",
	DripPart         = "Drip",
	FloorFolder      = "CurrentFloor",
	MonstersFolder   = "Monsters",
	PlayersFolder    = "InGamePlayers",   -- donde está el modelo del jugador en partida
	ItemsFolder      = "Items",           -- dentro del modelo del mapa (CurrentRoom.<Mapa>.Items)
	StatsFolder      = "Stats",           -- dentro de cada Generator
	ConnieValue      = "Connie",
	-- Contador de máquinas del GUI del juego (para saber cuándo van todas: "4/4").
	-- Ruta desde tu Player. Si un paso no existe lo busca más adentro. Vacío = lo busca solo.
	MachinesGui      = "PlayerGui.ScreenGui.Menu.GeneratorFrame.Message",

	-- DetectMonster: distancia (studs) a la que una máquina se considera bloqueada.
	-- También se cambia desde el panel, en la fila "Dist. Maq".
	MonsterDistance  = 40,

	-- Comportamiento
	ScanInterval   = 0.25,   -- Auto Prompt: segundos entre cada ciclo
	AutoTpDelay    = 0.15,   -- AutoTPMachine: espera tras teletransportarse, antes de presionar
	AutoTpStep     = 0.30,   -- AutoTPMachine: delay entre máquinas (también se cambia en el panel: "Delay TP")
	TeleportOffset = Vector3.new(0, 4, 0),

	-- AutoPickItem: solo recoge estos ítems
	PickItems  = { "HealthKit", "Bandage", "ResearchCapsule" },
	PickDelay  = 0.15,   -- espera tras teletransportarse al ítem, antes de recogerlo
	PickStep   = 0.30,   -- espera entre ítem e ítem
	PickReturn = true,   -- true = vuelve a donde estabas después de recoger

	-- AutoElevator / Research
	ElevatorWait      = 1.5,                               -- segundos con todas las máquinas listas antes de actuar
	ElevatorSpot      = Vector3.new(-70.4, 168.5, 107.6),  -- a dónde te teletransporta
	ElevatorRiseTo    = 175,                               -- altura (Y) hasta la que sube
	ElevatorRiseSpeed = 40,                                -- studs por segundo al subir
	ResearchDistance  = 8,                                 -- distancia delante del twisted (también en el panel)
	ResearchTime      = 10,                                -- segundos siguiendo al twisted (también en el panel)

	-- AutoHide: si un monster se acerca al jugador, lo teletransporta al punto seguro
	EscapeDistance = 25,                               -- distancia monster-jugador que activa la huida (también en el panel)
	EscapeCooldown = 1.5,                              -- segundos mínimos entre una huida y otra
	EscapeSpot     = Vector3.new(-70.4, 168.5, 107.6), -- a dónde te teletransporta
	StopButtonPath = "PlayerGui.ScreenGui.Menu.StopGenerator", -- NUEVO: botón que presiona AutoHide (ruta desde tu Player)
	StopCooldown   = 1,                                         -- NUEVO: segundos mínimos entre cada presión del botón

	-- Estilo
	HeaderColor = Color3.fromRGB(160, 255, 70),  -- color del título
	Sounds      = true,                          -- sonidos de la interfaz (false = silencio)
}

--------------------------------------------------------------------
-- Servicios
--------------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
print("[VeesGameshowGUI] iniciando...")
if not player then
	warn("[VeesGameshowGUI] Este script debe ser un LocalScript (no un Script normal).")
	return
end

-- Indicador de arranque: muestra en pantalla si el script cargó, en qué paso
-- se quedó, o el error (útil en tablet/celular, donde no se ve la consola).
local bootGui, bootBox
local stage = "inicio"
local finished = false

local function setBoot(text, bad)
	warn("[VeesGameshowGUI] " .. text)
	pcall(function()
		if not bootBox or not bootBox.Parent then
			bootGui = Instance.new("ScreenGui")
			bootGui.Name = "VeesGameshowGUI_Boot"
			bootGui.ResetOnSpawn = false
			bootGui.IgnoreGuiInset = true
			bootGui.DisplayOrder = 10000
			bootGui.Parent = player:WaitForChild("PlayerGui")
			bootBox = Instance.new("TextButton")
			bootBox.AutomaticSize = Enum.AutomaticSize.Y
			bootBox.Size = UDim2.new(0.9, 0, 0, 0)
			bootBox.Position = UDim2.fromScale(0.05, 0.03)
			bootBox.TextColor3 = Color3.new(1, 1, 1)
			bootBox.TextSize = 18
			bootBox.TextWrapped = true
			bootBox.TextXAlignment = Enum.TextXAlignment.Left
			bootBox.TextYAlignment = Enum.TextYAlignment.Top
			bootBox.Font = Enum.Font.Code
			bootBox.Parent = bootGui
			bootBox.MouseButton1Click:Connect(function() bootGui:Destroy() end)
		end
		bootBox.BackgroundColor3 = bad and Color3.fromRGB(90, 20, 20) or Color3.fromRGB(10, 80, 45)
		bootBox.Text = string.sub(text, 1, 700)
	end)
end

setBoot("Vee's GUI: cargando...")

task.delay(8, function()
	if not finished then
		setBoot("Vee's GUI: se quedó esperando en el paso '" .. stage .. "' (toca para cerrar)", true)
	end
end)

local function showError(err)
	finished = true
	setBoot("Vee's GUI falló en el paso '" .. stage .. "' (toca para cerrar):\n" .. tostring(err), true)
end

--------------------------------------------------------------------
-- Lógica del juego
--------------------------------------------------------------------
local function getGenerators()
	local list = {}
	local room = workspace:FindFirstChild(CONFIG.RoomFolder)
	if not room then return list end

	local map = room:FindFirstChildWhichIsA("Model")
	if not map then return list end

	local folder = map:FindFirstChild(CONFIG.GeneratorsFolder)
	if not folder then return list end

	for _, child in ipairs(folder:GetChildren()) do
		if child.Name == CONFIG.GeneratorName then
			table.insert(list, child)
		end
	end
	return list
end

local function getRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function pivotOf(obj)
	return obj:IsA("Model") and obj:GetPivot() or obj.CFrame
end

local function getPrompt(generator)
	local part = generator:FindFirstChild(CONFIG.PromptPart)
	local prompt = part and part:FindFirstChildWhichIsA("ProximityPrompt")
	return part, prompt
end

local function pressPrompt(prompt)
	prompt:InputHoldBegin()
	if prompt.HoldDuration > 0 then
		task.wait(prompt.HoldDuration + 0.05)
	end
	prompt:InputHoldEnd()
end

-- DetectMonster ----------------------------------------------------
local detectEnabled = false

local function posOf(obj)
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
end

-- NUEVO: ruta real = CurrentFloor.<Modelo del mapa>.Monsters (el modelo cambia en cada mapa)
local function getMonstersFolder()
	local floor = workspace:FindFirstChild(CONFIG.FloorFolder)
	if not floor then return nil end

	-- 1) Primer Model dentro de CurrentFloor
	local map = floor:FindFirstChildWhichIsA("Model")
	local folder = map and map:FindFirstChild(CONFIG.MonstersFolder)
	if folder then return folder end

	-- 2) Recorre todos los Model hijos buscando Monsters
	for _, child in ipairs(floor:GetChildren()) do
		if child:IsA("Model") then
			local found = child:FindFirstChild(CONFIG.MonstersFolder)
			if found then return found end
		end
	end

	-- 3) Respaldo: ruta vieja CurrentFloor.Monsters
	return floor:FindFirstChild(CONFIG.MonstersFolder)
end

local function collectMonsters(container, list)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			table.insert(list, child)
		elseif child:IsA("Folder") then
			collectMonsters(child, list)
		end
	end
	return list
end

local function getMonsterInstances()
	local folder = getMonstersFolder()
	return folder and collectMonsters(folder, {}) or {}
end

local function getMonsterPositions()
	local list = {}
	for _, monster in ipairs(getMonsterInstances()) do
		local pos = posOf(monster)
		if pos then
			table.insert(list, pos)
		end
	end
	return list
end

-- true si hay un monster cerca de la máquina (solo con DetectMonster activo)
local function isBlocked(generator, monsters)
	if not detectEnabled then return false end
	monsters = monsters or getMonsterPositions()
	local genPos = posOf(generator)
	if not genPos then return false end
	for _, monsterPos in ipairs(monsters) do
		if (monsterPos - genPos).Magnitude <= CONFIG.MonsterDistance then
			return true
		end
	end
	return false
end

-- Connie (Stats de cada máquina) -----------------------------------
local function statBool(generator, name)
	local stats = generator:FindFirstChild(CONFIG.StatsFolder)
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("ValueBase") then
		local v = value.Value
		if type(v) == "number" then
			return v ~= 0
		end
		return v == true
	end
	return nil
end

local function isConnieActive(generator)
	return statBool(generator, CONFIG.ConnieValue) == true
end

-- No teletransportarse a una máquina con Connie activa
local function machineUnavailable(generator)
	return isConnieActive(generator)
end

-- La interfaz reasigna estas funciones más abajo
local setAutoTpInfo = function(_text, _good) end

-- Auto Prompt ------------------------------------------------------
local autoEnabled = false

local function runAutoPrompt()
	while autoEnabled do
		local root = getRoot()
		if root then
			local monsters = detectEnabled and getMonsterPositions() or nil
			for _, generator in ipairs(getGenerators()) do
				if not autoEnabled then break end
				local part, prompt = getPrompt(generator)
				if prompt and prompt.Enabled
					and not isBlocked(generator, monsters)
					and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance then
					pressPrompt(prompt)
				end
			end
		end
		task.wait(CONFIG.ScanInterval)
	end
end

-- Tp To Machine (manual, va rotando) ------------------------------
local tpIndex = 0

local function teleportToNextMachine()
	local root = getRoot()
	if not root then return false, "Sin personaje" end

	local generators = getGenerators()
	if #generators == 0 then return false, "No hay generadores" end

	local monsters = detectEnabled and getMonsterPositions() or nil
	local skipped = 0
	for _ = 1, #generators do
		tpIndex = tpIndex % #generators + 1
		local generator = generators[tpIndex]
		local drip = generator:FindFirstChild(CONFIG.DripPart)
		if drip then
			if isBlocked(generator, monsters) or machineUnavailable(generator) then
				skipped += 1
			else
				root.CFrame = pivotOf(drip) + CONFIG.TeleportOffset
				return true, ("Generador %d/%d"):format(tpIndex, #generators)
			end
		end
	end
	if skipped > 0 then
		return false, "Sin máquinas libres"
	end
	return false, "Ninguno tiene " .. CONFIG.DripPart
end

-- Candado para que los teleports automáticos no se pisen entre sí
local tpLock = false
local researching = false   -- true mientras Research sigue a un twisted
local function withLock(fn)
	tpLock = true
	local ok, err = pcall(fn)
	tpLock = false
	researching = false
	if not ok then
		warn("[VeesGameshowGUI] " .. tostring(err))
	end
end

-- AutoHide ---------------------------------------------------------
local escapeEnabled = false
local lastEscape = 0
local playerName = ""   -- lo escribe el jugador en el panel (con o sin @)
local setEscapeInfo = function(_text, _good) end

local function cleanName(text)
	local t = tostring(text or "")
	t = t:gsub("%s+", "")
	t = t:gsub("^@+", "")
	return t
end

-- Busca tu modelo en Workspace.InGamePlayers (sin importar mayúsculas).
-- Si no escribiste usuario y no lo encuentra, usa tu personaje.
local function findInGamePlayer()
	local folder = workspace:FindFirstChild(CONFIG.PlayersFolder)
	if folder then
		local wanted = (playerName ~= "" and playerName or player.Name):lower()
		local display = player.DisplayName:lower()
		for _, child in ipairs(folder:GetChildren()) do
			local n = child.Name:lower()
			if n == wanted or (playerName == "" and n == display) then
				return child
			end
		end
	end
	if playerName == "" then
		return player.Character
	end
	return nil
end

local function moveModel(model, cf)
	if model:IsA("Model") then
		local root = model:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = cf
			root.AssemblyLinearVelocity = Vector3.zero
		else
			model:PivotTo(cf)
		end
	elseif model:IsA("BasePart") then
		model.CFrame = cf
		model.AssemblyLinearVelocity = Vector3.zero
	end
end

-- Posición real del cuerpo (HumanoidRootPart si existe)
local function bodyPos(obj)
	if obj:IsA("Model") then
		local root = obj:FindFirstChild("HumanoidRootPart")
		if root then return root.Position end
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return posOf(obj)
end

local function nearestDistance(pos, positions)
	local best = math.huge
	for _, other in ipairs(positions) do
		local d = (other - pos).Magnitude
		if d < best then
			best = d
		end
	end
	return best
end

-- NUEVO: presiona el botón StopGenerator de la interfaz del juego (con cooldown)
local lastStop = 0
local STOP_SIGNALS = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" }

local stopStatus = "" -- NUEVO: qué método funcionó (se muestra en el aviso de AutoHide)

-- NUEVO: busca el botón por la ruta; si falla, lo busca por nombre en todo el PlayerGui
local function findStopButton()
	local button = player
	for segment in string.gmatch(CONFIG.StopButtonPath, "[^%.]+") do
		button = button and button:FindFirstChild(segment)
		if not button then break end
	end
	if button and button ~= player then return button end
	local name = string.match(CONFIG.StopButtonPath, "([^%.]+)$")
	local pg = player:FindFirstChild("PlayerGui")
	return (pg and name) and pg:FindFirstChild(name, true) or nil
end

-- NUEVO: true si el botón y todos sus padres están visibles
local function stopButtonShown(button)
	local current = button
	while current and current ~= game do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return true
end

local function pressStopGenerator()
	if os.clock() - lastStop < CONFIG.StopCooldown then return false end
	lastStop = os.clock()

	local button = findStopButton()
	if not button then
		stopStatus = "sin boton"
		return false
	end

	-- Método 1: getconnections (conecta con las funciones del botón)
	local gc = getconnections
	if type(gc) == "function" then
		local fired = false
		for _, signalName in ipairs(STOP_SIGNALS) do
			pcall(function()
				for _, conn in ipairs(gc(button[signalName])) do
					pcall(function() conn:Fire() end)
					fired = true
				end
			end)
		end
		if fired then stopStatus = "gc" return true end
	end

	-- Método 2: firesignal
	local fs = firesignal
	if type(fs) == "function" then
		local fired = false
		for _, signalName in ipairs(STOP_SIGNALS) do
			local ok = pcall(function() fs(button[signalName]) end)
			fired = fired or ok
		end
		if fired then stopStatus = "fs" return true end
	end

	-- Método 3: fireclick
	local fc = fireclick
	if type(fc) == "function" and pcall(function() fc(button) end) then
		stopStatus = "fc"
		return true
	end

	-- Método 4: clic virtual en el centro del botón (solo si se ve en pantalla)
	if button:IsA("GuiObject") and stopButtonShown(button) then
		local ok = pcall(function()
			local vim = game:GetService("VirtualInputManager")
			local inset = game:GetService("GuiService"):GetGuiInset()
			local p = button.AbsolutePosition + button.AbsoluteSize / 2 + inset
			vim:SendMouseButtonEvent(p.X, p.Y, 0, true, game, 0)
			vim:SendMouseButtonEvent(p.X, p.Y, 0, false, game, 0)
		end)
		if ok then stopStatus = "vim" return true end
	end

	stopStatus = "no pudo"
	return false
end

local function runAutoEscape()
	while escapeEnabled do
		local model = findInGamePlayer()
		if not model then
			setEscapeInfo(playerName == "" and "Escribe tu usuario" or "Usuario no encontrado", false)
		elseif researching then
			setEscapeInfo("Pausado (Research)", nil)
		elseif not getMonstersFolder() then
			setEscapeInfo("No encuentro Monsters", false) -- NUEVO: texto cambiado
		else
			local myPos = bodyPos(model)
			local monsters = getMonsterPositions()
			if not myPos then
				setEscapeInfo("No leo tu posición", false)
			elseif #monsters == 0 then
				setEscapeInfo("Sin monsters", true)
			else
				local nearest = nearestDistance(myPos, monsters)
				if nearest <= CONFIG.EscapeDistance then
					pressStopGenerator() -- NUEVO: primero presiona StopGenerator
					if (myPos - CONFIG.EscapeSpot).Magnitude <= 4 then
						setEscapeInfo("En el punto seguro", true)
					elseif os.clock() - lastEscape > CONFIG.EscapeCooldown then
						moveModel(model, CFrame.new(CONFIG.EscapeSpot))
						lastEscape = os.clock()
						setEscapeInfo("¡Escondido! [" .. stopStatus .. "]", false) -- NUEVO: muestra el método usado
					end
				elseif os.clock() - lastEscape > 2 then
					setEscapeInfo(("Monster a %d studs"):format(nearest), true)
				end
			end
		end
		task.wait(0.1)
	end
end

-- NoCollide Maq ----------------------------------------------------
-- Quita la colisión de las máquinas (solo en tu cliente) para atravesarlas.
local noCollideEnabled = false
local noCollideRunning = false
local savedCollide = setmetatable({}, { __mode = "k" })

local function applyNoCollide()
	for _, generator in ipairs(getGenerators()) do
		for _, part in ipairs(generator:GetDescendants()) do
			if part:IsA("BasePart") then
				if savedCollide[part] == nil then
					savedCollide[part] = part.CanCollide
				end
				part.CanCollide = false
			end
		end
	end
end

local function restoreCollide()
	for part, original in pairs(savedCollide) do
		if part.Parent then
			part.CanCollide = original
		end
	end
	table.clear(savedCollide)
end

local function runNoCollide()
	if noCollideRunning then return end
	noCollideRunning = true
	while noCollideEnabled do
		applyNoCollide()
		task.wait(0.5)
	end
	restoreCollide()
	noCollideRunning = false
end

-- AutoPickItem -----------------------------------------------------
local pickEnabled = false
local setPickInfo = function(_text, _good) end
local pickSet = {}
for _, name in ipairs(CONFIG.PickItems) do
	pickSet[name:lower()] = true
end
local lastTried = setmetatable({}, { __mode = "k" })

local function getPickItems()
	local list = {}
	local room = workspace:FindFirstChild(CONFIG.RoomFolder)
	local map = room and room:FindFirstChildWhichIsA("Model")
	local folder = map and map:FindFirstChild(CONFIG.ItemsFolder)
	if folder then
		for _, item in ipairs(folder:GetChildren()) do
			if pickSet[item.Name:lower()] then
				table.insert(list, item)
			end
		end
	end
	return list
end

local function itemPosition(item)
	local pos = posOf(item)
	if pos then return pos end
	local part = item:FindFirstChildWhichIsA("BasePart", true)
	return part and part.Position
end

local function promptPosition(prompt)
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	elseif parent and parent:IsA("Attachment") then
		return parent.WorldPosition
	end
end

local function pickItem(item)
	local root = getRoot()
	if not root or not item.Parent then return end
	local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt and not prompt.Enabled then return end

	local target = (prompt and promptPosition(prompt)) or itemPosition(item)
	if not target then return end

	local origin = root.CFrame
	root.CFrame = CFrame.new(target + CONFIG.TeleportOffset)
	task.wait(CONFIG.PickDelay)
	if prompt and prompt.Parent then
		pressPrompt(prompt)
	else
		task.wait(0.2) -- ítem sin prompt: se recoge al tocarlo
	end
	if CONFIG.PickReturn then
		task.wait(0.1)
		root.CFrame = origin
	end
end

local function runAutoPick()
	while pickEnabled do
		if tpLock or (escapeEnabled and os.clock() - lastEscape < 2) then
			task.wait(0.2)
		else
			local items = getPickItems()
			local monsters = detectEnabled and getMonsterPositions() or nil
			local target
			for _, item in ipairs(items) do
				local last = lastTried[item]
				if not (last and os.clock() - last < 3) and not isBlocked(item, monsters) then
					target = item
					break
				end
			end
			if target then
				lastTried[target] = os.clock()
				setPickInfo("Recogiendo...", true)
				withLock(function()
					pickItem(target)
				end)
			elseif #items > 0 then
				setPickInfo("Ítems bloqueados", false)
			else
				setPickInfo("Sin ítems", nil)
			end
			task.wait(CONFIG.PickStep)
		end
	end
end

-- AutoElevator + Research ------------------------------------------
local elevatorEnabled = false
local researchEnabled = false
local floorRunning = false
local setElevatorInfo = function(_text, _good) end
local setResearchInfo = function(_text, _good) end

local function floorSay(text, good)
	setElevatorInfo(text, good)
	if not elevatorEnabled then
		setResearchInfo(text, good)
	end
end

-- Lo que se mueve: tu modelo en InGamePlayers (o tu personaje de respaldo)
local function getMover()
	return findInGamePlayer() or getRoot()
end

local function nearestMonster(pos)
	local best, bestD
	for _, monster in ipairs(getMonsterInstances()) do
		local p = posOf(monster)
		if p then
			local d = (p - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = monster, d
			end
		end
	end
	return best
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Hacia dónde va el twisted: su velocidad si se mueve, o hacia dónde mira
local function monsterDirection(monster)
	local root
	if monster:IsA("BasePart") then
		root = monster
	else
		root = monster:FindFirstChild("HumanoidRootPart") or monster.PrimaryPart
			or monster:FindFirstChildWhichIsA("BasePart", true)
	end
	if not root then return nil end
	local vel = flat(root.AssemblyLinearVelocity)
	if vel.Magnitude > 2 then
		return vel.Unit
	end
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude > 0.01 then
		return look.Unit
	end
	return nil
end

-- Se pone delante del twisted a ResearchDistance studs y lo va siguiendo
local function researchPhase(isActive)
	isActive = isActive or function() return researchEnabled end
	researching = true
	local startTime = os.clock()
	local twisted
	while isActive() and os.clock() - startTime < CONFIG.ResearchTime do
		local mover = getMover()
		local myPos = mover and bodyPos(mover)
		if myPos then
			if not twisted or not twisted.Parent then
				twisted = nearestMonster(myPos)
			end
			if not twisted then
				setResearchInfo("Sin twisteds", false)
				break
			end
			local twistedPos = posOf(twisted)
			local dir = monsterDirection(twisted)
			if twistedPos and dir then
				local target = twistedPos + dir * CONFIG.ResearchDistance
				moveModel(mover, CFrame.lookAt(target, Vector3.new(twistedPos.X, target.Y, twistedPos.Z)))
				setResearchInfo("Frente al twisted", true)
			end
		end
		task.wait(0.05)
	end
	researching = false
end

-- Teletransporta al punto del ele y sube rápido hasta ElevatorRiseTo
local function goToElevator()
	local mover = getMover()
	if not mover then return end
	local spot = CONFIG.ElevatorSpot
	moveModel(mover, CFrame.new(spot))
	local y = spot.Y
	while y < CONFIG.ElevatorRiseTo and (elevatorEnabled or researchEnabled) do
		local dt = RunService.Heartbeat:Wait()
		y = math.min(CONFIG.ElevatorRiseTo, y + CONFIG.ElevatorRiseSpeed * dt)
		moveModel(mover, CFrame.new(spot.X, y, spot.Z))
	end
end

-- Contador de máquinas del GUI del juego --------------------------
-- Escucha TODOS los textos del frame (por ejemplo "Machines Completed" o "4/4").
-- Se engancha a los cambios de texto, así no se pierde un mensaje que aparece
-- solo un instante antes de cambiar a otro (como "Intermission").
local machinesDone = false
local machinesDoneKey = false
local lastGuiText = ""
local watchedTexts = setmetatable({}, { __mode = "k" })
local lastGuiScan = 0

local function isTextObject(obj)
	return obj ~= nil and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox"))
end

local function isShown(obj)
	local current = obj
	while current and current ~= game do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return true
end

-- Sigue la ruta; si un paso no existe lo busca más adentro.
-- Si solo falta el último paso, devuelve el contenedor.
local function resolvePath(path)
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	local obj = player
	for i, segment in ipairs(segments) do
		local nextObj = obj:FindFirstChild(segment) or obj:FindFirstChild(segment, true)
		if not nextObj then
			return (i == #segments and i > 1) and obj or nil
		end
		obj = nextObj
	end
	return obj
end

-- "done" / "working" / nil según lo que dice el texto
local function evaluateText(text)
	local a, b = text:match("(%d+)%s*/%s*(%d+)")
	if a and b then
		a, b = tonumber(a), tonumber(b)
		return (b > 0 and a >= b) and "done" or "working"
	end
	if text:lower():find("complet", 1, true) then
		return "done"
	end
	return nil
end

local function onGuiText(obj)
	local text = obj.Text
	if text == "" then return end
	lastGuiText = text
	local result = evaluateText(text)
	if result == "done" then
		machinesDone = true
		machinesDoneKey = getGenerators()[1] or false
	elseif result == "working" then
		machinesDone = false
	end
end

local function watchTextObject(obj)
	if watchedTexts[obj] then return end
	watchedTexts[obj] = true
	obj:GetPropertyChangedSignal("Text"):Connect(function()
		if isShown(obj) then
			onGuiText(obj)
		end
	end)
end

local function refreshMachinesWatch()
	if os.clock() - lastGuiScan >= 2 then
		lastGuiScan = os.clock()
		local container
		if CONFIG.MachinesGui ~= "" then
			local obj = resolvePath(CONFIG.MachinesGui)
			if obj then
				if isTextObject(obj) then
					watchTextObject(obj)
					container = obj.Parent
				else
					container = obj
				end
			end
		else
			-- Sin ruta: busca un texto con "machine/generator/máquina" y un "n/m"
			local pg = player:FindFirstChild("PlayerGui")
			for _, d in ipairs(pg and pg:GetDescendants() or {}) do
				if isTextObject(d) then
					local t = d.Text:lower()
					if (t:find("machine", 1, true) or t:find("generator", 1, true) or t:find("máquina", 1, true))
						and t:match("%d+%s*/%s*%d+") then
						container = d.Parent
						break
					end
				end
			end
		end
		if container then
			for _, d in ipairs(container:GetDescendants()) do
				if isTextObject(d) then
					watchTextObject(d)
				end
			end
		end
	end
	-- También revisa lo que se ve ahora mismo
	for obj in pairs(watchedTexts) do
		if obj.Parent and isShown(obj) then
			onGuiText(obj)
		end
	end
end

-- "none" = sin contador, "working" = faltan máquinas, "done" = todas listas
-- (el segundo valor es el texto para mostrar en el panel)
local function floorState()
	refreshMachinesWatch()
	local firstGenerator = getGenerators()[1]
	if machinesDone and firstGenerator and machinesDoneKey ~= firstGenerator then
		machinesDone = false -- empezó otro piso
	end
	if machinesDone then
		return "done", "Máquinas completas"
	end
	if lastGuiText == "" then
		return "none", "Sin contador de máquinas"
	end
	return "working", "Lee: " .. string.sub(lastGuiText, 1, 16)
end

local function runFloorWatcher()
	if floorRunning then return end
	floorRunning = true
	local doneSince, handled = nil, false
	while elevatorEnabled or researchEnabled do
		local state, detail = floorState()
		if state == "none" then
			doneSince, handled = nil, false
			floorSay(detail, nil)
		elseif state == "working" then
			doneSince, handled = nil, false
			floorSay(detail, true)
		else
			doneSince = doneSince or os.clock()
			if not handled and not tpLock and os.clock() - doneSince >= CONFIG.ElevatorWait then
				handled = true
				withLock(function()
					if researchEnabled then
						researchPhase()
					end
					goToElevator()
				end)
				floorSay("Dentro del ele", true)
			end
		end
		task.wait(0.25)
	end
	floorRunning = false
end

-- AutoTPMachine ----------------------------------------------------
local autoTpEnabled = false

local function getActiveMachines()
	local list = {}
	local monsters = detectEnabled and getMonsterPositions() or nil
	for _, generator in ipairs(getGenerators()) do
		local part, prompt = getPrompt(generator)
		if prompt and prompt.Enabled and not isBlocked(generator, monsters)
			and not machineUnavailable(generator) then
			table.insert(list, { generator = generator, part = part, prompt = prompt })
		end
	end
	return list
end

local function goToMachine(entry)
	local root = getRoot()
	if not root then return false end

	local drip = entry.generator:FindFirstChild(CONFIG.DripPart)
	if drip then
		root.CFrame = pivotOf(drip) + CONFIG.TeleportOffset
	end
	-- Si Drip queda fuera del alcance del prompt, va directo al Prompt
	if (root.Position - entry.part.Position).Magnitude > entry.prompt.MaxActivationDistance then
		root.CFrame = entry.part.CFrame + CONFIG.TeleportOffset
	end
	return true
end

local function runAutoTp()
	local done = {} -- generadores ya presionados en esta vuelta
	while autoTpEnabled do
		if tpLock or (escapeEnabled and os.clock() - lastEscape < 2) then
			task.wait(0.2)
			continue
		end
		local list = getActiveMachines()
		local target
		for _, entry in ipairs(list) do
			if not done[entry.generator] then
				target = entry
				break
			end
		end

		if target then
			done[target.generator] = true
			setAutoTpInfo(("%d activos: yendo a uno"):format(#list), true)
			withLock(function()
				if not isBlocked(target.generator) and goToMachine(target) and target.prompt.Enabled then
					task.wait(CONFIG.AutoTpDelay)
					pressPrompt(target.prompt)
				end
			end)
		else
			done = {} -- empieza otra vuelta
			if #list == 0 then
				setAutoTpInfo("Sin prompts libres", false)
			end
		end
		task.wait(CONFIG.AutoTpStep)
	end
end

-- Automatizar: Research -> ítems -> máquinas (el ele lo haces tú) ---
local autoAllEnabled = false
local autoAllRunning = false
local setAutoAllInfo = function(_text, _good) end

local function allActive()
	return autoAllEnabled
end

-- Espera mientras AutoHide te acaba de esconder
local function waitEscape(isActive)
	while isActive() and escapeEnabled and os.clock() - lastEscape < 2 do
		task.wait(0.2)
	end
end

local function anyPromptEnabled()
	for _, generator in ipairs(getGenerators()) do
		local _, prompt = getPrompt(generator)
		if prompt and prompt.Enabled then
			return true
		end
	end
	return false
end

-- Recoge todos los ítems de la lista (HealthKit, Bandage, ResearchCapsule)
local function pickAllItems(isActive)
	for _, item in ipairs(getPickItems()) do
		if not isActive() then break end
		waitEscape(isActive)
		if item.Parent and not isBlocked(item) then
			lastTried[item] = os.clock()
			withLock(function()
				pickItem(item)
			end)
			task.wait(CONFIG.PickStep)
		end
	end
end

-- Va de máquina en máquina hasta que no quede ninguna por hacer
local function machinesPhase(isActive)
	local visited = {}
	local idleSince
	while isActive() do
		if floorState() == "done" then return end
		waitEscape(isActive)

		local list = getActiveMachines()
		local target
		for _, entry in ipairs(list) do
			if not visited[entry.generator] then
				target = entry
				break
			end
		end

		if target then
			idleSince = nil
			visited[target.generator] = true
			setAutoAllInfo(("3/3 Máquinas (%d)"):format(#list), true)
			withLock(function()
				if not isBlocked(target.generator) and goToMachine(target) and target.prompt.Enabled then
					task.wait(CONFIG.AutoTpDelay)
					pressPrompt(target.prompt)
				end
			end)
		else
			visited = {} -- nueva vuelta
			if anyPromptEnabled() then
				-- hay prompts, pero bloqueados por monster o Connie: esperar
				idleSince = nil
				setAutoAllInfo("Máquinas ocupadas...", false)
			else
				idleSince = idleSince or os.clock()
				if os.clock() - idleSince >= CONFIG.ElevatorWait then
					return -- ya no quedan prompts activos
				end
			end
		end
		task.wait(CONFIG.AutoTpStep)
	end
end

local function runAutoAll()
	if autoAllRunning then return end
	autoAllRunning = true
	local finishedFloor = nil -- primera máquina del piso que ya se automatizó
	while autoAllEnabled do
		local first = getGenerators()[1]
		if not first then
			finishedFloor = nil
			setAutoAllInfo("Esperando piso", nil)
			task.wait(0.5)
		elseif finishedFloor == first then
			setAutoAllInfo("Listo: ve al ele", true)
			task.wait(0.5)
		else
			setAutoAllInfo("1/3 Research", true)
			researchPhase(allActive)
			if autoAllEnabled then
				setAutoAllInfo("2/3 Ítems", true)
				pickAllItems(allActive)
			end
			if autoAllEnabled then
				setAutoAllInfo("3/3 Máquinas", true)
				machinesPhase(allActive)
			end
			finishedFloor = first
		end
	end
	autoAllRunning = false
end

--------------------------------------------------------------------
-- Interfaz (estilo DandysUI)
-- Base visual: DandysUI (paneles oscuros con rayas, contorno negro grueso,
-- texto Fredoka con degradado plateado, filas con ◀ ON ▶).
--------------------------------------------------------------------
local function buildUI()
local ContentProvider = game:GetService("ContentProvider")

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function hex(s) return Color3.fromHex(s) end
local function grey(v) return Color3.new(v, v, v) end

local Theme = {
	Panel   = hex("4a4a4a"),
	Row     = hex("4d4d4d"),
	Text    = WHITE,
	SubText = hex("dedede"),
	On      = hex("6cff64"),
	Off     = hex("ff6d6f"),
	Value   = hex("efb524"),
	PanelShade = { { 0, 1 }, { 0.513, 0.541 }, { 0.789, 0.357 }, { 1, 0.357 } },
	RowShade   = { { 0, 0.826 }, { 0.513, 0.367 }, { 0.789, 0.183 }, { 1, 0.183 } },
	TextShade  = { { 0, 1 }, { 0.097, 0.923 }, { 0.458, 0.944 }, { 1, 0.208 } },
}

local Fonts = {
	Title = Font.new("rbxasset://fonts/families/FredokaOne.json"),
	Value = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
	Body  = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold),
}
local STRIPES_IMAGE = "rbxassetid://6794283750"

-- Pantalla ---------------------------------------------------------
local playerGui = player:WaitForChild("PlayerGui")
local isTouch = UserInputService.TouchEnabled

local old = playerGui:FindFirstChild("VeesGameshowGUI")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "VeesGameshowGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Escala automática (más chico en celular)
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function updateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	uiScale.Scale = isTouch and math.clamp(cam.ViewportSize.Y / 560, 0.6, 1) or 1
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- Ayudantes de construcción ----------------------------------------
local function New(className, props, children)
	local obj = Instance.new(className)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			obj[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = obj
	end
	if parent then obj.Parent = parent end
	return obj
end

local function Tween(obj, props, time, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad,
		dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function Corner(radius)
	return New("UICorner", { CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 8) })
end

local function Stroke(thickness, transparency, border)
	return New("UIStroke", {
		Color = BLACK,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
	})
end

local function Shade(stops, rotation)
	local points = {}
	for i, s in ipairs(stops) do
		points[i] = ColorSequenceKeypoint.new(s[1], grey(s[2]))
	end
	return New("UIGradient", { Color = ColorSequence.new(points), Rotation = rotation or 90 })
end

local function Stripes(parent, radius)
	local decor = parent:FindFirstChild("Decor") or New("Folder", { Name = "Decor", Parent = parent })
	return New("ImageLabel", {
		Name = "Stripes",
		BackgroundTransparency = 1,
		Image = STRIPES_IMAGE,
		ImageTransparency = 0.94,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(56, 56),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = decor,
	}, { Corner(radius) })
end

-- Texto Fredoka con contorno negro (y degradado plateado si shade ~= false)
local function Text(props, strokeThickness, shade)
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = Fonts.Title,
		TextColor3 = Theme.Text,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Text = "",
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local label = New("TextLabel", defaults)
	Stroke(strokeThickness or 2).Parent = label
	if shade ~= false then
		Shade(Theme.TextShade).Parent = label
	end
	return label
end

-- Sonidos ----------------------------------------------------------
stage = "sonidos"
local soundFolder = New("Folder", { Name = "Sounds", Parent = gui })
local sounds, lastPlayed = {}, {}
local FALLBACK_SOUND = "rbxasset://sounds/electronicpingshort.wav"
do
	local defs = {
		Click  = { "rbxassetid://552900451", 0.5 },
		Hover  = { "rbxassetid://6895079853", 0.3 },
		Toggle = { "rbxassetid://121531878137469", 0.7 },
		Error  = { "rbxassetid://4499400560", 0.3 },
	}
	local list = {}
	for name, def in pairs(defs) do
		local s = New("Sound", { Name = name, SoundId = def[1], Volume = def[2], Parent = soundFolder })
		sounds[name] = s
		table.insert(list, s)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(list, function(assetId, status)
				if status ~= Enum.AssetFetchStatus.Success then
					for _, s in ipairs(list) do
						if s.SoundId == assetId then
							s.SoundId = FALLBACK_SOUND
						end
					end
				end
			end)
		end)
	end)
end

local function PlaySound(name)
	if not CONFIG.Sounds then return end
	local template = sounds[name]
	if not template then return end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then return end
	lastPlayed[name] = now
	local clone = template:Clone()
	clone.Parent = soundFolder
	clone:Play()
	task.delay(4, function() clone:Destroy() end)
end

-- Panel, botón chunky y campo ---------------------------------------
local function Bounce(button, target, amount)
	local obj = target or button
	local scale = obj:FindFirstChild("BounceScale") or New("UIScale", { Name = "BounceScale", Parent = obj })
	local up = 1 + (amount or 0.05)
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		Tween(scale, { Scale = up }, 0.12)
		PlaySound("Hover")
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		Tween(scale, { Scale = 1 }, 0.12)
	end)
	button.MouseButton1Down:Connect(function()
		Tween(scale, { Scale = 0.94 }, 0.07)
	end)
	button.MouseButton1Up:Connect(function()
		Tween(scale, { Scale = hovering and up or 1 }, 0.25, Enum.EasingStyle.Back)
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			hovering = false
			Tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
		end
	end)
end

local function Panel(props, radius)
	local defaults = { BackgroundColor3 = Theme.Panel, BorderSizePixel = 0 }
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local frame = New("Frame", defaults)
	Corner(radius or 12).Parent = frame
	Stroke(3, 0, true).Parent = frame
	Shade(Theme.PanelShade).Parent = frame
	Stripes(frame, radius or 12)
	return frame
end

-- Botón del juego: base negra + cara de color con contorno
local function Chunky(props, color, radius)
	local defaults = {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
	}
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local button = New("TextButton", defaults)
	local holder = New("Frame", {
		Name = "Holder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = button,
	})
	New("Frame", {
		Name = "FrameBG",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = BLACK,
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = holder,
	}, { Corner(radius or 8) })
	New("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = holder,
	}, { Corner(radius or 8), Stroke(2.5, 0, true), Shade(Theme.PanelShade) })
	local label = Text({
		Name = "Label",
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 20,
		ZIndex = 4,
		Parent = holder,
	})
	Bounce(button, holder)
	return { Button = button, Label = label }
end

local function Field(props, radius)
	local defaults = { BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, ZIndex = 2 }
	for k, v in pairs(props) do
		defaults[k] = v
	end
	local frame = New("Frame", defaults)
	Corner(radius or 6).Parent = frame
	Stroke(2, 0.2, true).Parent = frame
	Shade(Theme.PanelShade).Parent = frame
	return frame
end

-- Mensaje grande en el centro (errores, avisos)
local function Message(text, isError)
	local label = Text({
		Name = "Message",
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.22),
		Size = UDim2.new(0.7, 0, 0, 50),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = isError and Theme.Off or WHITE,
		ZIndex = 200,
		Parent = gui,
	}, 3, not isError)
	local scale = New("UIScale", { Scale = 0.6, Parent = label })
	PlaySound(isError and "Error" or "Click")
	Tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
	task.delay(2, function()
		local st = label:FindFirstChildOfClass("UIStroke")
		Tween(label, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.18) }, 0.4)
		if st then Tween(st, { Transparency = 1 }, 0.4) end
		task.delay(0.45, function() label:Destroy() end)
	end)
end

--------------------------------------------------------------------
-- Panel principal
--------------------------------------------------------------------
local FULL_H, MIN_H, PANEL_W = 540, 58, 300

stage = "panel"
local panel = Panel({
	Name = "Panel",
	Size = UDim2.fromOffset(PANEL_W, FULL_H),
	Position = UDim2.new(0, 70, 0.5, -FULL_H / 2),
	ClipsDescendants = true,
	Parent = gui,
})

-- Cabecera (arrastrable)
local header = New("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundTransparency = 1,
	Parent = panel,
})

Text({
	Name = "Title",
	Text = CONFIG.PanelName,
	Position = UDim2.fromOffset(16, 4),
	Size = UDim2.new(1, -66, 0, 30),
	TextSize = 22,
	TextColor3 = CONFIG.HeaderColor,
	ZIndex = 4,
	Parent = header,
}, 3, false)

-- Medidor de señal (motivo TV)
local bulbRow = New("Frame", {
	Size = UDim2.new(1, -32, 0, 10),
	Position = UDim2.fromOffset(16, 40),
	BackgroundTransparency = 1,
	Parent = header,
}, {
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 6),
	}),
})
local bulbs = {}
for i = 1, 16 do
	bulbs[i] = New("Frame", {
		Size = UDim2.fromOffset(6, 3),
		BackgroundColor3 = Theme.On,
		BorderSizePixel = 0,
		LayoutOrder = i,
		ZIndex = 4,
		Parent = bulbRow,
	})
end

local minimize = Chunky({
	Name = "Minimize",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 8),
	Size = UDim2.fromOffset(32, 32),
	Parent = header,
}, hex("2b2b2b"))
minimize.Label.Text = "–"

-- Contenedor con scroll para las filas
stage = "cuerpo"
local body = New("ScrollingFrame", {
	Name = "Body",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 60),
	Size = UDim2.new(1, -20, 1, -70),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = Theme.Value,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = panel,
}, {
	New("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	New("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	}),
})

-- Fila con interruptor ◀ ON ▶
local function toggleRow(order, name, subtitle, onChanged)
	local row = New("TextButton", {
		Name = name,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = body,
	}, { Corner(10), Stroke(2.5, 0, true), Shade(Theme.RowShade) })
	Stripes(row, 10)

	Text({
		Name = "Name",
		Text = name,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -130, 0, 26),
		TextSize = 20,
		Parent = row,
	})
	local info = Text({
		Name = "Info",
		Text = subtitle,
		FontFace = Fonts.Body,
		TextColor3 = Theme.SubText,
		TextSize = 15,
		Position = UDim2.fromOffset(14, 33),
		Size = UDim2.new(1, -130, 0, 20),
		Parent = row,
	}, 1, false)
	local value = Text({
		Name = "Value",
		Text = "◀ OFF ▶",
		FontFace = Fonts.Value,
		TextColor3 = Theme.Off,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(1, -112, 0, 0),
		Size = UDim2.new(0, 100, 1, 0),
		Parent = row,
	}, 1.5, false)

	local api = { subtitle = subtitle }
	local state = false

	function api.set(on)
		state = on
		value.Text = on and "◀ ON ▶" or "◀ OFF ▶"
		Tween(value, { TextColor3 = on and Theme.On or Theme.Off }, 0.15)
	end

	-- good: true = verde, false = rojo, nil = normal
	function api.say(text, good)
		info.Text = text
		if good == true then
			info.TextColor3 = Theme.On
		elseif good == false then
			info.TextColor3 = Theme.Off
		else
			info.TextColor3 = Theme.SubText
		end
	end

	row.MouseButton1Click:Connect(function()
		api.set(not state)
		PlaySound("Toggle")
		onChanged(state)
	end)
	Bounce(row, nil, 0.02)

	return api
end

-- Fila con caja de texto
local function textRow(order, name, placeholder, onSubmit)
	local row = New("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = body,
	}, { Corner(10), Stroke(2.5, 0, true), Shade(Theme.RowShade) })
	Stripes(row, 10)

	Text({
		Name = "Name",
		Text = name,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(0, 76, 1, 0),
		TextSize = 17,
		Parent = row,
	})

	local field = Field({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(1, -100, 0, 34),
		Parent = row,
	})
	local box = New("TextBox", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		Text = "",
		PlaceholderText = placeholder,
		FontFace = Fonts.Value,
		TextColor3 = Theme.Value,
		PlaceholderColor3 = Theme.SubText,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = field,
	})
	box.FocusLost:Connect(function()
		onSubmit(box.Text)
	end)

	return row
end

-- Fila con – [valor] + (para delays y distancias)
local function stepperRow(order, name, get, set, step, minV, maxV)
	local row = New("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Theme.Row,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = body,
	}, { Corner(10), Stroke(2.5, 0, true), Shade(Theme.RowShade) })
	Stripes(row, 10)

	Text({
		Name = "Name",
		Text = name,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -150, 1, 0),
		TextSize = 17,
		Parent = row,
	})

	local minus = Chunky({
		Name = "Minus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -104, 0.5, -2),
		Size = UDim2.fromOffset(32, 32),
		Parent = row,
	}, hex("d9661c"))
	minus.Label.Text = "-"

	local field = Field({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.fromOffset(54, 32),
		Parent = row,
	})
	local box = New("TextBox", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = Fonts.Value,
		TextColor3 = Theme.Value,
		TextSize = 19,
		ClearTextOnFocus = false,
		ZIndex = 4,
		Parent = field,
	})

	local plus = Chunky({
		Name = "Plus",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, -2),
		Size = UDim2.fromOffset(32, 32),
		Parent = row,
	}, hex("d9661c"))
	plus.Label.Text = "+"

	local function apply(n)
		n = math.clamp(n, minV, maxV)
		n = math.floor(n * 100 + 0.5) / 100 -- evita 0.30000000004
		set(n)
		box.Text = tostring(get())
	end
	box.Text = tostring(get())

	minus.Button.MouseButton1Click:Connect(function()
		PlaySound("Click")
		apply(get() - step)
	end)
	plus.Button.MouseButton1Click:Connect(function()
		PlaySound("Click")
		apply(get() + step)
	end)
	box.FocusLost:Connect(function()
		apply(tonumber(box.Text) or get())
	end)

	return row
end

stage = "botones"
-- 0) Automatizar (Research -> ítems -> máquinas)
local autoAllRow
autoAllRow = toggleRow(0, CONFIG.AutoAllButton, "Research, ítems y máqs", function(on)
	autoAllEnabled = on
	if on then
		autoAllRow.say("Empezando...", true)
		task.spawn(runAutoAll)
	else
		autoAllRow.say(autoAllRow.subtitle, nil)
	end
end)
setAutoAllInfo = function(text, good)
	if autoAllEnabled then
		autoAllRow.say(text, good)
	end
end

-- 1) Auto Prompt
local autoRow
autoRow = toggleRow(1, CONFIG.AutoButton, "Presiona prompts cercanos", function(on)
	autoEnabled = on
	if on then
		autoRow.say("Presionando prompts", true)
		task.spawn(runAutoPrompt)
	else
		autoRow.say(autoRow.subtitle, nil)
	end
end)

-- 2) Tp To Machine (acción)
local tpBtn = Chunky({
	Name = CONFIG.TpButton,
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 46),
	Parent = body,
}, hex("37963a"))
tpBtn.Label.Text = CONFIG.TpButton

local tpToken
tpBtn.Button.MouseButton1Click:Connect(function()
	PlaySound("Click")
	local ok, msg = teleportToNextMachine()
	if ok then
		tpBtn.Label.Text = msg
		local id = {}
		tpToken = id
		task.delay(1.5, function()
			if tpToken == id then
				tpBtn.Label.Text = CONFIG.TpButton
			end
		end)
	else
		Message(msg, true)
	end
end)

-- 3) AutoTPMachine
local autoTpRow
autoTpRow = toggleRow(3, CONFIG.AutoTpButton, "Va de máquina en máquina", function(on)
	autoTpEnabled = on
	if on then
		autoTpRow.say("Buscando prompts activos...", true)
		task.spawn(runAutoTp)
	else
		autoTpRow.say(autoTpRow.subtitle, nil)
	end
end)
setAutoTpInfo = function(text, good)
	if autoTpEnabled then
		autoTpRow.say(text, good)
	end
end

-- 3b) Delay entre máquinas del AutoTPMachine (segundos)
stepperRow(4, "Delay TP",
	function() return CONFIG.AutoTpStep end,
	function(n) CONFIG.AutoTpStep = n end,
	0.1, 0, 10)

-- 4) DetectMonster
local detectRow
detectRow = toggleRow(5, CONFIG.DetectButton, "Salta máquinas con monster", function(on)
	detectEnabled = on
	if on then
		detectRow.say("Vigilando monsters", true)
	else
		detectRow.say(detectRow.subtitle, nil)
	end
end)

-- 6) Distancia monster-máquina de DetectMonster
stepperRow(6, "Dist. Maq",
	function() return CONFIG.MonsterDistance end,
	function(n) CONFIG.MonsterDistance = n end,
	5, 1, 1000)

-- 7) Usuario (para que AutoEscape encuentre tu modelo en InGamePlayers)
textRow(7, "Usuario", "@tu_usuario", function(text)
	playerName = cleanName(text)
	if playerName == "" then return end
	local model = findInGamePlayer()
	if model then
		Message("Usuario listo: " .. model.Name, false)
	else
		Message("Aún no estás en InGamePlayers", true)
	end
end)

-- 8) AutoEscape
local escapeRow
escapeRow = toggleRow(8, CONFIG.EscapeButton, "Huye de monsters", function(on)
	escapeEnabled = on
	if on then
		escapeRow.say("Vigilando a tu alrededor", true)
		task.spawn(runAutoEscape)
	else
		escapeRow.say(escapeRow.subtitle, nil)
	end
end)
setEscapeInfo = function(text, good)
	if escapeEnabled then
		escapeRow.say(text, good)
	end
end

-- 9) Distancia monster-jugador que activa la huida
stepperRow(9, "Dist. Huida",
	function() return CONFIG.EscapeDistance end,
	function(n) CONFIG.EscapeDistance = n end,
	5, 1, 500)

-- 10) NoCollide Maq
local noCollideRow
noCollideRow = toggleRow(10, CONFIG.NoCollideButton, "Atraviesas las máquinas", function(on)
	noCollideEnabled = on
	if on then
		noCollideRow.say("Sin colisión con máquinas", true)
		task.spawn(runNoCollide)
	else
		noCollideRow.say(noCollideRow.subtitle, nil)
	end
end)

-- 11) AutoPickItem
local pickRow
pickRow = toggleRow(11, CONFIG.AutoPickButton, "Recoge kits y cápsulas", function(on)
	pickEnabled = on
	if on then
		pickRow.say("Buscando ítems", true)
		task.spawn(runAutoPick)
	else
		pickRow.say(pickRow.subtitle, nil)
	end
end)
setPickInfo = function(text, good)
	if pickEnabled then
		pickRow.say(text, good)
	end
end

-- 12) AutoElevator (cuando todas las máquinas están completadas)
local elevatorRow
elevatorRow = toggleRow(12, CONFIG.ElevatorButton, "Va al ele al acabar", function(on)
	elevatorEnabled = on
	if on then
		elevatorRow.say("Vigilando máquinas", true)
		task.spawn(runFloorWatcher)
	else
		elevatorRow.say(elevatorRow.subtitle, nil)
	end
end)
setElevatorInfo = function(text, good)
	if elevatorEnabled then
		elevatorRow.say(text, good)
	end
end

-- 13) Research (antes del ele: se pone delante del twisted)
local researchRow
researchRow = toggleRow(13, CONFIG.ResearchButton, "Twisted y luego al ele", function(on)
	researchEnabled = on
	if on then
		researchRow.say("Vigilando máquinas", true)
		task.spawn(runFloorWatcher)
	else
		researchRow.say(researchRow.subtitle, nil)
	end
end)
setResearchInfo = function(text, good)
	if researchEnabled then
		researchRow.say(text, good)
	end
end

-- 14) Distancia delante del twisted
stepperRow(14, "Dist. Research",
	function() return CONFIG.ResearchDistance end,
	function(n) CONFIG.ResearchDistance = n end,
	1, 1, 100)

-- 15) Cuánto tiempo sigue al twisted
stepperRow(15, "Dur. Research",
	function() return CONFIG.ResearchTime end,
	function(n) CONFIG.ResearchTime = n end,
	1, 1, 120)

-- Estado en vivo de DetectMonster: cuántas máquinas están bloqueadas
task.spawn(function()
	while gui.Parent do
		if detectEnabled then
			local monsters = getMonsterPositions()
			local blocked = 0
			for _, generator in ipairs(getGenerators()) do
				if isBlocked(generator, monsters) then
					blocked += 1
				end
			end
			if blocked > 0 then
				detectRow.say(("Monster cerca: %d maq"):format(blocked), false)
			else
				detectRow.say("Todo despejado", true)
			end
		end
		task.wait(0.25)
	end
end)

--------------------------------------------------------------------
-- Minimizar, botón flotante, tecla, arrastre y animaciones
--------------------------------------------------------------------
stage = "final"
local minimized = false
minimize.Button.MouseButton1Click:Connect(function()
	PlaySound("Click")
	minimized = not minimized
	minimize.Label.Text = minimized and "+" or "–"
	Tween(panel, { Size = UDim2.fromOffset(PANEL_W, minimized and MIN_H or FULL_H) }, 0.25)
end)

stage = "boton V"
local fab = Chunky({
	Name = "Toggle",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(46, 46),
	Parent = gui,
}, hex("37963a"), 23)
fab.Label.Text = "V"
fab.Label.TextSize = 24

local function togglePanel()
	PlaySound("Click")
	panel.Visible = not panel.Visible
end
fab.Button.MouseButton1Click:Connect(togglePanel)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == CONFIG.ToggleKey then
		togglePanel()
	end
end)

-- Arrastrar desde la cabecera (mouse y táctil)
do
	local dragging, dragStart, startPos
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = panel.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = (input.Position - dragStart) / uiScale.Scale
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- Medidor de señal
task.spawn(function()
	while gui.Parent do
		if panel.Visible then
			for _, b in ipairs(bulbs) do
				local h = math.random(2, 9)
				b.Size = UDim2.fromOffset(6, h)
				b.BackgroundColor3 = h >= 8 and CONFIG.HeaderColor or Theme.On
			end
		end
		task.wait(0.12)
	end
end)

-- Entrada del panel
local intro = New("UIScale", { Scale = 0.85, Parent = panel })
Tween(intro, { Scale = 1 }, 0.35, Enum.EasingStyle.Back)
end

local ok, err = xpcall(buildUI, debug.traceback)
if ok then
	finished = true
	setBoot("Vee's GUI listo (toca para cerrar)")
	task.delay(3, function()
		if bootGui then bootGui:Destroy() end
	end)
else
	showError(err)
end
