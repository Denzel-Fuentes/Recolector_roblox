--!strict
--[[
	Ajustes (ModuleScript)
	Unica responsabilidad: los ajustes del jugador que guarda su perfil
	(perfil.ajustes; hoy, el sonido: musica y efectos encendidos o no, A1).
	Los aplica el cliente (Client/Sonido); aqui solo se validan y se guardan.

	  Ajustes.aplicar(jugador, datos) -> (ok, motivo)
	      datos tiene que ser { musica: boolean, efectos: boolean }: los dos
	      y booleanos; si no, "invalido" (y no gasta el cooldown). Lo demas
	      que traiga se ignora: solo se copian esos dos a una tabla nueva,
	      nada del cliente entra en el perfil tal cual. Con el cooldown de
	      GameConfig.COOLDOWN_AJUSTES por jugador, como los demas remotes (un
	      cliente que mande cien por segundo solo consigue que se ignoren).
	      motivo: "guardado" | "igual" | "invalido" | "cooldown" | "sinPerfil"
	  Ajustes.olvidar(jugador)   al salir

	Guardar es dejarlo en el perfil y marcarlo sucio (se publica al cliente y
	Guardado escribe el perfil entero en el autoguardado y al salir), como la
	vista de la camara en PatioHandler. Un modulo y no solo el Handler para
	que la prueba ajustesValidos ejercite estas reglas sin RemoteEvent.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local Perfiles = require(ServerScriptService:WaitForChild("Services"):WaitForChild("Perfiles"))

local Ajustes = {}

local ultimo: { [Player]: number } = {}

function Ajustes.valido(datos: any): boolean
	return typeof(datos) == "table" and typeof(datos.musica) == "boolean" and typeof(datos.efectos) == "boolean"
end

function Ajustes.aplicar(jugador: Player, datos: any): (boolean, string)
	if not Ajustes.valido(datos) then
		return false, "invalido"
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < GameConfig.COOLDOWN_AJUSTES then
		return false, "cooldown"
	end
	ultimo[jugador] = ahora
	local perfil = Perfiles.obtener(jugador)
	if not perfil then
		return false, "sinPerfil"
	end
	local musica: boolean, efectos: boolean = datos.musica, datos.efectos
	local actuales = perfil.ajustes
	if typeof(actuales) == "table" and actuales.musica == musica and actuales.efectos == efectos then
		return true, "igual"
	end
	perfil.ajustes = { musica = musica, efectos = efectos }
	Perfiles.marcarSucio(jugador)
	return true, "guardado"
end

function Ajustes.olvidar(jugador: Player)
	ultimo[jugador] = nil
end

return Ajustes
