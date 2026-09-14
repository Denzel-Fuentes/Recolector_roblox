--!strict
--[[
	ReparacionHandler
	Atiende los dos remotes de la mesa de reparacion y responde por el mismo
	evento para que el cliente sepa si su minijuego cuenta:

	  LimpiezaEvent(accion, uid)        accion = "iniciar" | "terminar"
	    -> cliente: LimpiezaEvent(resultado, uid, ok)
	  EnsamblajeEvent(accion, idMascota) accion = "iniciar" | "terminar"
	    -> cliente: EnsamblajeEvent(resultado, idMascota, ok)
	       resultado = "iniciado" | "auto" | "terminado" | motivo de fallo

	"auto" significa que el pase Auto-Ensamblaje lo resolvio al instante: el
	cliente muestra el aviso y no abre el minijuego.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Textos = require(Shared:WaitForChild("Config"):WaitForChild("Textos"))
local DefinicionesMascotas = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Servicios = ServerScriptService:WaitForChild("Services")
local Reparacion = require(Servicios:WaitForChild("Reparacion"))

local LimpiezaEvent = Red.evento("LimpiezaEvent")
local EnsamblajeEvent = Red.evento("EnsamblajeEvent")
local NotificacionEvent = Red.evento("NotificacionEvent")

local function notificar(jugador: Player, texto: string, tipo: string)
	NotificacionEvent:FireClient(jugador, texto, tipo)
end

LimpiezaEvent.OnServerEvent:Connect(function(jugador, accion, uid)
	if typeof(uid) ~= "string" then
		return
	end
	if accion == "iniciar" then
		local ok, motivo = Reparacion.iniciarLimpieza(jugador, uid)
		LimpiezaEvent:FireClient(jugador, if ok then "iniciado" else motivo, uid, ok)
	elseif accion == "terminar" then
		local ok, motivo = Reparacion.terminarLimpieza(jugador, uid)
		LimpiezaEvent:FireClient(jugador, if ok then "terminado" else motivo, uid, ok)
		if ok then
			notificar(jugador, Textos.REPARACION.completado, "exito")
		end
	elseif accion == "cancelar" then
		Reparacion.cancelar(jugador)
	end
end)

EnsamblajeEvent.OnServerEvent:Connect(function(jugador, accion, id)
	if typeof(id) ~= "string" then
		return
	end
	local def = DefinicionesMascotas.obtener(id)
	if not def then
		return
	end
	if accion == "iniciar" then
		local ok, resultado = Reparacion.iniciarEnsamblaje(jugador, id)
		EnsamblajeEvent:FireClient(jugador, resultado, id, ok)
		if ok and resultado == "auto" then
			notificar(jugador, Textos.REPARACION.autoEnsamblado, "exito")
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.mascotaNueva, { nombre = def.nombre }), "exito")
		elseif not ok and resultado == "almacenLleno" then
			notificar(jugador, Textos.PATIO.almacenLleno, "aviso")
		end
	elseif accion == "terminar" then
		local ok, resultado = Reparacion.terminarEnsamblaje(jugador, id)
		EnsamblajeEvent:FireClient(jugador, if ok then "terminado" else resultado, id, ok)
		if ok then
			notificar(jugador, Textos.formatear(Textos.NOTIFICACIONES.mascotaNueva, { nombre = def.nombre }), "exito")
		elseif resultado == "almacenLleno" then
			notificar(jugador, Textos.PATIO.almacenLleno, "aviso")
		end
	elseif accion == "cancelar" then
		Reparacion.cancelar(jugador)
	end
end)
