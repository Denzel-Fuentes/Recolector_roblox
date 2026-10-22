--!strict
--[[
	BotinHandler
	Cablea el patio: arranca Botin cuando el mundo esta listo y atiende
	  - ProximityPrompts del patio y la caseta (excavar, reciclar a mano; el
	    de Dona Chatarra solo abre la tienda y lo atiende el cliente,
	    Prompts.client),
	  - ReclamarObjetoEvent (clic dentro del Alcance, o la mira en el movil),
	  - LanzarObjetoEvent(punto, fuerza): lanzar la bolsa entera (punteria).
	Y avisa a TODOS los clientes de cada deposito (RecicladoraEvent con el
	contenedor y el material de cada objeto, "" si no es basura) para que la
	cinta de la recicladora de ese contenedor lo transporte: es decorado
	compartido, no estado de juego.

	Efectos solo para quien lo hizo (5 oct, peticion del usuario: nada de
	toasts al cobrar): CelebracionEvent al entregar a mano (los aciertos los
	manda Lanzamiento) y RecogidaEvent con el "+1" de cada objeto recogido,
	donde estaba. Los rechazos (monton agotado o pendiente, contenedor
	cerrado, bolsa vacia, demasiado cerca) son burbujas en el sitio
	(AvisosMundo, 6 oct), tampoco toasts.

	Un solo listener de ProximityPromptService.PromptTriggered para todo: se
	decide por el MODELO al que pertenece el prompt (atributo MontonId, tag
	Contenedor; el atributo Material del contenedor dice cual de los cinco
	es). Asi los prompts horneados en el place no necesitan scripts propios.

	Cada remote tiene cooldown por jugador: un cliente modificado que dispare
	1000 reclamos por segundo solo consigue que se ignoren.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Idioma = require(Shared:WaitForChild("Utilidades"):WaitForChild("Idioma"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))
local Contenedores = require(Shared:WaitForChild("Utilidades"):WaitForChild("Contenedores"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local ObjetosPatio = require(Servicios:WaitForChild("ObjetosPatio"))
local AvisosMundo = require(Servicios:WaitForChild("AvisosMundo"))

local ReclamarObjetoEvent = Red.evento("ReclamarObjetoEvent")
local LanzarObjetoEvent = Red.evento("LanzarObjetoEvent")
local RecicladoraEvent = Red.evento("RecicladoraEvent")
local CelebracionEvent = Red.evento("CelebracionEvent")
local RecogidaEvent = Red.evento("RecogidaEvent")

Mundo.asegurar()
Botin.iniciar()

Bolsa.alDepositar:Connect(function(_, items, resumen)
	local materiales = table.create(#items)
	for _, item in items do
		table.insert(materiales, if item.tipo == "basura" then item.material or "" else "")
	end
	RecicladoraEvent:FireAllClients(resumen.contenedor, materiales)
end)

-- (posicion, tipo, material, n, valor): n = objetos de una bolsa caida
-- recuperada; valor = lo que vale un billete al depositarlo (el cliente
-- ensena "+$valor" en vez de "+1", peticion del usuario 6 oct)
-- (las pruebas reclaman con jugadores simulados, que no son Player)
ObjetosPatio.alRecoger:Connect(function(jugador, item, posicion)
	if typeof(jugador) ~= "Instance" or not jugador:IsA("Player") or not jugador.Parent then
		return
	end
	local valor = if item.tipo == "billete" then Bolsa.valorDeposito(jugador, item) else 0
	RecogidaEvent:FireClient(jugador, posicion, item.tipo, item.material or "", if item.tipo == "bolsa" then #(item.contenido or {}) else 1, valor)
end)

-- === Cooldown por jugador y accion ===
local cooldowns: { [Player]: { [string]: number } } = {}
local function enCooldown(jugador: Player, accion: string, segundos: number): boolean
	local ahora = os.clock()
	local mapa = cooldowns[jugador]
	if not mapa then
		mapa = {}
		cooldowns[jugador] = mapa
	end
	if ahora - (mapa[accion] or 0) < segundos then
		return true
	end
	mapa[accion] = ahora
	return false
end

-- === Acciones de la caseta ===

-- Entregar a mano junto a un contenedor: funciona, pero sin bonus de
-- lanzamiento (el de separar si: x2 lo de su tipo)
local function reciclar(jugador: Player, material: string?)
	local resumen, motivo = Bolsa.depositar(jugador, material)
	if not resumen then
		-- Burbuja sobre el contenedor (AvisosMundo), no toast
		local contenedor = Mundo.contenedorDe(material)
		local sitio = if contenedor then contenedor.zona.Position + Vector3.new(0, 3, 0) else nil
		local texto = if motivo == "bloqueado"
			then Idioma.mensaje("PATIO.contenedorBloqueado", { n = GameConfig.MATERIAL_REBIRTH[material or ""] or 1 })
			else Idioma.mensaje("PATIO.bolsaVacia")
		if sitio then
			AvisosMundo.mostrar(jugador, sitio, texto, { icono = if motivo == "bloqueado" then "candado" else "bolsa" })
		else
			AvisosMundo.sobreJugador(jugador, texto)
		end
		return
	end
	if resumen.dinero > 0 then
		local contenedor = Mundo.contenedorDe(material)
		CelebracionEvent:FireClient(jugador, {
			tipo = "entrega",
			contenedor = resumen.contenedor,
			dinero = resumen.dinero,
			separadas = resumen.separadas,
			malSeparadas = resumen.malSeparadas,
			posicion = if contenedor then contenedor.zona.Position else nil,
		})
	end
end

-- === Excavar ===

-- Burbuja sobre el monton (AvisosMundo); con "termina tu montón" ademas
-- late el que tiene a medias, para que lo encuentre
local function avisarExcavar(jugador: Player, monton: Botin.Monton, ok: boolean, motivo: string)
	if ok then
		return
	end
	local sitio = monton.ranura.Position + Vector3.new(0, monton.params.h + 2, 0)
	if motivo == "agotado" then
		AvisosMundo.mostrar(jugador, sitio, Idioma.mensaje("PATIO.montonAgotado"))
	elseif motivo == "patioLleno" then
		AvisosMundo.mostrar(jugador, sitio, Idioma.mensaje("PATIO.patioLleno"))
	elseif motivo == "yaTienesUno" then
		local pendiente = Botin.montonPendienteDe(jugador)
		AvisosMundo.mostrar(jugador, sitio, Idioma.mensaje("PATIO.montonPendiente"), { resaltar = if pendiente then pendiente.modelo else nil })
	end
end

-- === Un listener para todos los prompts del patio y la caseta ===

ProximityPromptService.PromptTriggered:Connect(function(prompt, jugador)
	if not Perfiles.obtener(jugador) then
		return
	end
	local monton = Botin.montonDe(prompt)
	if monton then
		if enCooldown(jugador, "excavar", 0.5) then
			return
		end
		local ok, motivo = Botin.excavar(jugador, monton)
		avisarExcavar(jugador, monton, ok, motivo)
		return
	end
	local contenedor = Contenedores.duenoDe(prompt)
	if contenedor and not enCooldown(jugador, "reciclar", 0.5) then
		reciclar(jugador, contenedor.material)
	end
end)

-- === Remotes ===

-- (objetoId, porMira?): porMira = la recogida automatica de la mira en el
-- movil (mismas reglas que el clic, sin avisos de rechazo)
ReclamarObjetoEvent.OnServerEvent:Connect(function(jugador, objetoId, porMira)
	if typeof(objetoId) ~= "string" or enCooldown(jugador, "reclamar", GameConfig.COOLDOWN_REMOTE) then
		return
	end
	Botin.reclamar(jugador, objetoId, if porMira == true then "mira" else "clic")
end)

LanzarObjetoEvent.OnServerEvent:Connect(function(jugador, punto, fuerza)
	if typeof(punto) ~= "Vector3" or typeof(fuerza) ~= "number" or enCooldown(jugador, "lanzar", 0.4) then
		return
	end
	local ok, motivo = Botin.lanzarBolsa(jugador, punto, fuerza)
	if not ok then
		-- Burbuja sobre la cabeza (AvisosMundo), no toast
		if motivo == "demasiadoCerca" then
			AvisosMundo.sobreJugador(jugador, Idioma.mensaje("PATIO.demasiadoCerca"))
		elseif motivo == "nadaQueLanzar" then
			AvisosMundo.sobreJugador(jugador, Idioma.mensaje("PATIO.nadaQueLanzar"), { icono = "bolsa" })
		end
	end
end)

Players.PlayerRemoving:Connect(function(jugador)
	cooldowns[jugador] = nil
end)
