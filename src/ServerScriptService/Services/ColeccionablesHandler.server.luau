--!strict
--[[
	ColeccionablesHandler
	Las 6 figurinas FIJAS del patio: al arrancar se instancia el modelo de cada
	una en su marcador (tag FigurinaFija, atributo FigurinaId). Son visibles
	para todos y cada jugador puede recogerla UNA vez: un bucle mide la
	distancia de cada jugador a cada figurina y, si esta a menos de 3 studs y
	no la tiene, se la da. El cliente la oculta localmente al verla en su perfil
	(FigurinasFijas en el cliente), asi que para los demas sigue ahi.

	Tambien avisa por toast de cintas y trajes nuevos (vengan de donde vengan).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local ModelosMascota = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosMascota"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))

local NotificacionEvent = Red.evento("NotificacionEvent")

local carpeta = Instance.new("Folder")
carpeta.Name = "FigurinasFijas"
carpeta.Parent = workspace

type FigurinaMundo = { id: string, modelo: Model, posicion: Vector3 }
local figurinas: { FigurinaMundo } = {}

for _, marcador in Mundo.figurinasFijas() do
	local id = marcador:GetAttribute("FigurinaId")
	local def = if typeof(id) == "string" then DefinicionesColeccionables.FIGURINA_POR_ID[id] else nil
	if def then
		local modelo = ModelosMascota.figurina(def)
		modelo:PivotTo(CFrame.new(marcador.Position - Vector3.new(0, 0.5, 0)))
		modelo:SetAttribute("FigurinaId", def.id)
		ModelosMascota.etiqueta(modelo, def.nombre, nil, 2.4)
		modelo.Parent = carpeta
		table.insert(figurinas, { id = def.id, modelo = modelo, posicion = marcador.Position })
	end
end

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	acumulado += dt
	if acumulado < 0.3 then
		return
	end
	acumulado = 0
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local root = personaje and personaje:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and Perfiles.obtener(jugador) then
			for _, f in figurinas do
				if (root.Position - f.posicion).Magnitude <= 3.5 and not Coleccionables.tiene(jugador, "figurina", f.id) then
					if Coleccionables.agregar(jugador, "figurina", f.id) then
						local def = DefinicionesColeccionables.FIGURINA_POR_ID[f.id]
						NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.PATIO.figurinaEncontrada, { nombre = def.nombre }), "exito")
					end
				end
			end
		end
	end
end)

Coleccionables.alAgregar:Connect(function(jugador, tipo, id)
	if tipo == "cinta" then
		local def = DefinicionesColeccionables.CINTA_POR_ID[id]
		if def then
			NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.NOTIFICACIONES.cintaEncontrada, { nombre = def.nombre }), "exito")
		end
	elseif tipo == "traje" then
		local def = DefinicionesColeccionables.TRAJE_POR_ID[id]
		if def then
			NotificacionEvent:FireClient(jugador, Textos.formatear(Textos.NOTIFICACIONES.trajeEncontrado, { nombre = def.nombre }), "exito")
		end
	end
end)
