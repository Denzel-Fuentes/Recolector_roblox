--!nonstrict
--[[
	Pruebas de los ajustes del jugador (A1, 22 oct). Ejercitan las reglas de
	Services/Ajustes, que es lo que hay detras de AjustesEvent (el Handler
	solo le pasa lo que llega; un RemoteEvent no se puede disparar desde el
	servidor): solo acepta { musica: boolean, efectos: boolean }, respeta su
	cooldown, no reescribe lo que ya era igual, sin perfil no hace nada, y lo
	que acepta queda en el perfil y sobrevive a guardarlo y cargarlo (ida y
	vuelta por JSON, como el DataStore, y Perfiles.completar, como Guardado
	al cargar). Deja los ajustes del jugador como estaban.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Ajustes = require(Servicios:WaitForChild("Ajustes"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

function Pruebas.ajustesValidos()
	local j = Comunes.jugador()
	local p = Perfiles.obtener(j)
	if not p then
		return "sin perfil => FALLO"
	end
	local antes = {
		musica = not (p.ajustes and p.ajustes.musica == false),
		efectos = not (p.ajustes and p.ajustes.efectos == false),
	}
	local espera = GameConfig.COOLDOWN_AJUSTES + 0.05
	-- Sin el cooldown de un cambio anterior (el panel)
	task.wait(espera)

	-- 1) Basura: se rechaza toda (y no gasta el cooldown)
	local basura = {
		"musica",
		42,
		true,
		Vector3.zero,
		{},
		{ musica = "si", efectos = true },
		{ musica = 1, efectos = 0 },
		{ musica = true },
		{ efectos = false },
		{ true, false },
	}
	local rechazados = 0
	for _, dato in basura do
		local bien, motivo = Ajustes.aplicar(j, dato)
		if not bien and motivo == "invalido" then
			rechazados += 1
		end
	end
	local bienNil, motivoNil = Ajustes.aplicar(j, nil)
	local nilRechazado = not bienNil and motivoNil == "invalido"
	local intactos = p.ajustes.musica == antes.musica and p.ajustes.efectos == antes.efectos

	-- 2) Los dos booleanos (lo contrario de lo que habia, para ver el cambio):
	-- se guardan en una tabla nueva y sin lo que sobra
	local nuevo = { musica = not antes.musica, efectos = not antes.efectos, sobra = string.rep("x", 64) }
	local bienNuevo, motivoNuevo = Ajustes.aplicar(j, nuevo)
	local guardado = p.ajustes.musica == nuevo.musica and p.ajustes.efectos == nuevo.efectos
		and p.ajustes.sobra == nil and p.ajustes ~= nuevo

	-- 3) Cooldown: uno justo detras se ignora; pasado el cooldown, entra
	local bienSeguido, motivoSeguido = Ajustes.aplicar(j, { musica = antes.musica, efectos = antes.efectos })
	local sigue = p.ajustes.musica == nuevo.musica and p.ajustes.efectos == nuevo.efectos
	task.wait(espera)
	local bienLuego, motivoLuego = Ajustes.aplicar(j, { musica = antes.musica, efectos = nuevo.efectos })
	local luego = p.ajustes.musica == antes.musica and p.ajustes.efectos == nuevo.efectos

	-- 4) Lo mismo que ya tiene: "igual", sin tocar la tabla
	task.wait(espera)
	local tablaAntes = p.ajustes
	local bienIgual, motivoIgual = Ajustes.aplicar(j, { musica = antes.musica, efectos = nuevo.efectos })
	local igual = bienIgual and motivoIgual == "igual" and p.ajustes == tablaAntes

	-- 5) Sin perfil (alguien que aun no cargo): nada
	local sinPerfil = Instance.new("Folder")
	local bienSin, motivoSin = Ajustes.aplicar(sinPerfil, { musica = true, efectos = true })
	Ajustes.olvidar(sinPerfil)
	sinPerfil:Destroy()
	local sinPerfilOk = not bienSin and motivoSin == "sinPerfil"

	-- 6) Persiste: el snapshot (lo que se publica y lo que guarda Guardado)
	-- pasa por JSON como en el DataStore y vuelve por completar como al cargar
	local enJSON = HttpService:JSONDecode(HttpService:JSONEncode(Perfiles.snapshot(p)))
	local guardadoJSON = typeof(enJSON.ajustes) == "table" and enJSON.ajustes.musica == antes.musica and enJSON.ajustes.efectos == nuevo.efectos
	local vuelta = Perfiles.completar(enJSON)
	local persiste = guardadoJSON and vuelta.ajustes.musica == antes.musica and vuelta.ajustes.efectos == nuevo.efectos

	-- Como estaba (a mano: el cooldown no deja otro cambio aun)
	p.ajustes = { musica = antes.musica, efectos = antes.efectos }
	Perfiles.marcarSucio(j)

	return string.format(
		"basura rechazada %d/%d, nil=%s, intactos=%s | booleanos: %s (%s), guardado=%s | justo detras: %s (%s), sigue=%s | tras %.2f s: %s (%s) | lo mismo: %s (%s) | sin perfil: %s | en JSON=%s, tras cargar musica=%s efectos=%s => %s",
		rechazados, #basura, tostring(nilRechazado), tostring(intactos),
		tostring(bienNuevo), motivoNuevo, tostring(guardado),
		tostring(bienSeguido), motivoSeguido, tostring(sigue),
		espera, tostring(bienLuego), motivoLuego,
		tostring(bienIgual), motivoIgual,
		motivoSin,
		tostring(guardadoJSON), tostring(vuelta.ajustes.musica), tostring(vuelta.ajustes.efectos),
		ok(rechazados == #basura and nilRechazado and intactos
			and bienNuevo and motivoNuevo == "guardado" and guardado
			and not bienSeguido and motivoSeguido == "cooldown" and sigue
			and bienLuego and motivoLuego == "guardado" and luego
			and igual and sinPerfilOk and persiste)
	)
end

return Pruebas
