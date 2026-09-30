--!strict
--[[
	ColeccionablesHandler
	Cablea los coleccionables:

	  PonerTrajeEvent(idTraje | nil)  ponerse o quitarse un traje. Los de pago
	                                  se poseen por Game Pass, no por hallazgo.

	Figurinas FIJAS del patio (solo con la funcion FIGURINAS, pospuesta en la
	v2): al arrancar se instancia el modelo de cada una en su marcador (tag
	FigurinaFija, atributo FigurinaId). Son visibles para todos y cada jugador
	puede recogerla UNA vez: un bucle mide la distancia de cada jugador a cada
	figurina y, si esta a menos de 3 studs y no la tiene, se la da. El cliente
	la oculta localmente al verla en su perfil.

	Tambien avisa por toast de cintas y trajes nuevos (vengan de donde vengan).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Productos = require(Shared:WaitForChild("Config"):WaitForChild("Productos"))
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesColeccionables = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesColeccionables"))
local ModelosObjetos = require(Shared:WaitForChild("Utilidades"):WaitForChild("ModelosObjetos"))
local Primitivas = require(Shared:WaitForChild("Utilidades"):WaitForChild("Primitivas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Coleccionables = require(Servicios:WaitForChild("Coleccionables"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))

local NotificacionEvent = Red.evento("NotificacionEvent")
local PonerTrajeEvent = Red.evento("PonerTrajeEvent")

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

-- === Traje ===
PonerTrajeEvent.OnServerEvent:Connect(function(jugador, idTraje)
	if idTraje ~= nil and typeof(idTraje) ~= "string" then
		return
	end
	if idTraje ~= nil and not Coleccionables.tiene(jugador, "traje", idTraje) then
		local pase = Productos.paseParaTraje(idTraje)
		if pase and Monetizacion.tienePase(jugador, pase.id) then
			Coleccionables.agregar(jugador, "traje", idTraje)
		end
	end
	local ok = Coleccionables.ponerTraje(jugador, idTraje)
	if ok and idTraje then
		local def = DefinicionesColeccionables.TRAJE_POR_ID[idTraje]
		if def then
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.trajePuesto, { nombre = def.nombre }), "exito")
		end
	elseif not ok then
		notificar(jugador, Textos.TIENDA.noEncontrado, "aviso")
	end
end)

-- === Figurinas fijas (pospuestas) ===

local carpeta = Instance.new("Folder")
carpeta.Name = "FigurinasFijas"
carpeta.Parent = workspace

type FigurinaMundo = { id: string, modelo: Model, posicion: Vector3 }
local figurinas: { FigurinaMundo } = {}

for _, marcador in (if GameConfig.activa("FIGURINAS") then Mundo.figurinasFijas() else {}) do
	local id = marcador:GetAttribute("FigurinaId")
	local def = if typeof(id) == "string" then DefinicionesColeccionables.FIGURINA_POR_ID[id] else nil
	if def then
		local modelo = ModelosObjetos.figurina(def)
		modelo:PivotTo(CFrame.new(marcador.Position - Vector3.new(0, 0.5, 0)))
		modelo:SetAttribute("FigurinaId", def.id)
		Primitivas.etiqueta(modelo, def.nombre, nil, 2.4)
		modelo.Parent = carpeta
		table.insert(figurinas, { id = def.id, modelo = modelo, posicion = marcador.Position })
	end
end

local acumulado = 0
RunService.Heartbeat:Connect(function(dt)
	if #figurinas == 0 then
		return
	end
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
