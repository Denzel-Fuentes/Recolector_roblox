--!strict
--[[
	Escena
	Detalles de presentacion del mundo que solo importan a ESTE cliente:

	  Figurinas fijas  las que ya tienes se ocultan localmente (transparencia
	                   local): para los demas siguen en su escondite.
	  Radios           las de todas las parcelas con CintaId puesto giran los
	                   carretes y muestran el titulo de la cinta (y "sin audio"
	                   mientras el id sea placeholder).
	  Exhibidas        las mascotas Perfectas de los pedestales giran despacio.
	  Brazos           quien esta en el patio (EnPatio) lleva los brazos al frente
	                   sujetando la bolsa (Transform de los hombros en Stepped).

	Nada de esto toca el estado del juego; es puro RenderStepped.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local Paleta = require(Shared:WaitForChild("Config"):WaitForChild("Paleta"))
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))

local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

-- === Figurinas fijas ===
local function ocultarFigurinas()
	local carpeta = workspace:FindFirstChild("FigurinasFijas")
	local p = EstadoCliente.perfil
	if not carpeta or not p then
		return
	end
	for _, modelo in carpeta:GetChildren() do
		local id = modelo:GetAttribute("FigurinaId")
		local tiene = typeof(id) == "string" and p.figurinas and p.figurinas[id] == true
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if tiene then 1 else 0
			elseif d:IsA("BillboardGui") then
				d.Enabled = not tiene
			end
		end
	end
end

EstadoCliente.alCambiarPerfil:Connect(ocultarFigurinas)
workspace.ChildAdded:Connect(function(hijo)
	if hijo.Name == "FigurinasFijas" then
		hijo.ChildAdded:Connect(function()
			task.defer(ocultarFigurinas)
		end)
		task.defer(ocultarFigurinas)
	end
end)
task.defer(ocultarFigurinas)

-- === Radios ===
type RadioVista = { modelo: Model, carretes: { BasePart }, cartel: BillboardGui?, texto: TextLabel? }
local radios: { RadioVista } = {}

local function prepararRadio(modelo: Model)
	-- Los hijos del modelo pueden llegar despues que el modelo: se esperan.
	local cuerpo = modelo:WaitForChild("Cuerpo", 10)
	local carretes = {}
	for i = 1, 2 do
		local carrete = modelo:WaitForChild("Carrete" .. i, 10)
		if carrete and carrete:IsA("BasePart") then
			table.insert(carretes, carrete)
		end
	end
	local vista: RadioVista = { modelo = modelo, carretes = carretes, cartel = nil, texto = nil }
	if cuerpo and cuerpo:IsA("BasePart") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "CartelRadio"
		bb.Size = UDim2.fromOffset(200, 40)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.MaxDistance = 40
		bb.Enabled = false
		bb.Parent = cuerpo
		local tl = Instance.new("TextLabel")
		tl.Size = UDim2.fromScale(1, 1)
		tl.BackgroundColor3 = Paleta.UI_FONDO
		tl.BackgroundTransparency = 0.3
		tl.TextColor3 = Paleta.UI_ACENTO
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamMedium
		tl.Parent = bb
		vista.cartel = bb
		vista.texto = tl
	end
	table.insert(radios, vista)
end

-- El Mundo se replica por partes: al aparecer workspace.Mundo sus 1.200
-- descendientes aun estan llegando. Se escucha DescendantAdded y se hace una
-- pasada inicial; el conjunto evita preparar dos veces la misma radio.
local preparadas: { [Model]: boolean } = {}
local function considerar(d: Instance)
	if d:IsA("Model") and d:GetAttribute("Mueble") == "Radio" and not preparadas[d] then
		preparadas[d] = true
		task.defer(prepararRadio, d)
	end
end

task.defer(function()
	local mundo = workspace:WaitForChild("Mundo", 60)
	if not mundo then
		return
	end
	mundo.DescendantAdded:Connect(considerar)
	for _, d in mundo:GetDescendants() do
		considerar(d)
	end
end)

local giro = 0
RunService.RenderStepped:Connect(function(dt)
	giro += dt * 3
	for _, r in radios do
		local cintaId = r.modelo:GetAttribute("CintaId")
		local activa = typeof(cintaId) == "string"
		if r.cartel then
			r.cartel.Enabled = activa
			if activa and r.texto then
				local def = DefinicionesColeccionables.CINTA_POR_ID[cintaId]
				if def then
					r.texto.Text = "♫ " .. def.nombre .. (if def.sonidoId == 0 then " " .. Textos.BASE.sinAudio else "")
				end
			end
		end
		if activa then
			for i, carrete in r.carretes do
				local base = carrete:GetAttribute("CFrameBase")
				if typeof(base) ~= "CFrame" then
					base = carrete.CFrame
					carrete:SetAttribute("CFrameBase", base)
				end
				carrete.CFrame = base * CFrame.Angles(giro * (if i == 1 then 1 else -1), 0, 0)
			end
		end
	end
end)

-- === Mascotas Perfectas exhibidas giran ===
RunService.RenderStepped:Connect(function(dt)
	local mundo = workspace:FindFirstChild("Mundo")
	if not mundo then
		return
	end
	local parcelas = mundo:FindFirstChild("Parcelas")
	if not parcelas then
		return
	end
	for _, parcela in parcelas:GetChildren() do
		local contenido = parcela:FindFirstChild("Contenido")
		if contenido then
			for _, modelo in contenido:GetChildren() do
				if modelo:IsA("Model") and modelo:GetAttribute("Estado") == DefinicionesMascotas.ESTADO_MAX and modelo:GetAttribute("MascotaId") then
					modelo:PivotTo(modelo:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
				end
			end
		end
	end
end)

-- === Brazos extendidos de quien esta en el patio ===
-- Se escribe Transform de los hombros en Stepped, DESPUES de que el Animator
-- del personaje haya puesto el suyo: es la forma documentada de posar
-- articulaciones por codigo. Vale para Motor6D y para AnimationConstraint
-- (los rigs nuevos), que comparten esa propiedad. Se hace para todos los
-- personajes con EnPatio, asi cada cliente ve a los demas sujetando la bolsa.
local POSE_BRAZO = CFrame.Angles(math.rad(65), 0, 0)
local NOMBRES_HOMBRO = { RightShoulder = true, LeftShoulder = true, ["Right Shoulder"] = true, ["Left Shoulder"] = true }

RunService.Stepped:Connect(function()
	for _, otro in Players:GetPlayers() do
		if otro:GetAttribute("EnPatio") == true then
			local ch = otro.Character
			if ch then
				for _, nombre in { "RightUpperArm", "LeftUpperArm", "Torso" } do
					local brazo = ch:FindFirstChild(nombre)
					if brazo then
						for _, hijo in brazo:GetChildren() do
							if NOMBRES_HOMBRO[hijo.Name] and (hijo:IsA("Motor6D") or hijo:IsA("AnimationConstraint")) then
								(hijo :: any).Transform = POSE_BRAZO
							end
						end
					end
				end
			end
		end
	end
end)
