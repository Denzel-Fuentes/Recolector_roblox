--!nonstrict
--[[
	Prueba de la actividad (C3, 22 oct): Services/Actividad, lo que comparten
	los minutos activos de las recompensas (R1) y la pausa del Turbo (K1).

	No toca a nadie de verdad: el "jugador" es una Folder (Actividad solo
	mira si esta en el juego), el reloj se inyecta (Actividad.ahora) y
	alAccion se cambia por una senal de prueba mientras dura, asi los oyentes
	reales no se enteran. No cede entre poner y quitar lo inyectado: ningun
	otro hilo corre con el reloj de mentira.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Senal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Senal"))

local Servicios = script.Parent.Parent
local Actividad = require(Servicios:WaitForChild("Actividad"))
local Montones = require(Servicios:WaitForChild("Montones"))

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- registrar, inactivo antes y despues del umbral, alAccion como mucho una vez
-- por segundo, el cableado (excavar marca) y la limpieza
function Pruebas.actividad()
	local falso = Instance.new("Folder")
	falso.Name = "JugadorPruebaActividad"
	falso.Parent = ServerStorage
	local relojAntes, senalAntes = Actividad.ahora, Actividad.alAccion
	local t = 0
	Actividad.ahora = function()
		return t
	end
	local senal = Senal.nueva()
	Actividad.alAccion = senal
	local avisos = 0
	senal:Connect(function(quien)
		if quien == falso then
			avisos += 1
		end
	end)

	local exito, d = pcall(function()
		local r = {}
		-- 1) Sin hacer nada: sin hora e inactivo
		r.nunca = Actividad.ultima(falso) == nil and Actividad.inactivo(falso, 120)
		-- 2) registrar marca la hora; inactivo desde el umbral (incluido), y
		-- otra accion lo reactiva
		t = 1000
		Actividad.registrar(falso)
		r.marca = Actividad.ultima(falso)
		t = 1119.5
		r.antes = Actividad.inactivo(falso, 120)
		t = 1120
		r.despues = Actividad.inactivo(falso, 120)
		Actividad.registrar(falso)
		r.otraVez = Actividad.inactivo(falso, 120)
		-- 3) alAccion como mucho una vez por segundo; registrar marca siempre
		avisos = 0
		t = 2000
		for _ = 1, 5 do
			Actividad.registrar(falso)
		end
		t = 2000.5
		Actividad.registrar(falso)
		t = 2001
		Actividad.registrar(falso)
		t = 2001.4
		Actividad.registrar(falso)
		t = 2002.2
		Actividad.registrar(falso)
		r.avisos = avisos
		r.ultimaTras = Actividad.ultima(falso)
		-- 4) El cableado (ActividadHandler): excavar marca la actividad. El
		-- otro oyente (Tutorial) no hace nada con una Folder: no tiene perfil
		t = 3000
		Montones.alExcavar:Fire(falso, "chico", "patio")
		r.cableado = Actividad.ultima(falso) == 3000
		-- 5) olvidar, y quien ya no esta en el juego no cuenta
		Actividad.olvidar(falso)
		r.olvidado = Actividad.ultima(falso) == nil
		falso.Parent = nil
		Actividad.registrar(falso)
		r.fuera = Actividad.ultima(falso) == nil
		return r
	end)

	Actividad.ahora, Actividad.alAccion = relojAntes, senalAntes
	Actividad.olvidar(falso)
	falso:Destroy()
	if not exito then
		return "error: " .. tostring(d) .. " => FALLO"
	end
	local bien = d.nunca and d.marca == 1000 and d.antes == false and d.despues == true and d.otraVez == false
		and d.avisos == 3 and d.ultimaTras == 2002.2 and d.cableado and d.olvidado and d.fuera
	return string.format(
		"sin acciones inactivo=%s | registrar marca %s | a 119,5 s inactivo=%s, a 120 s=%s, tras otra accion=%s | 9 acciones en 2,2 s -> %d avisos (esperados 3), ultima %s | excavar (cableado) marca=%s | olvidar=%s, fuera del juego no cuenta=%s => %s",
		tostring(d.nunca), tostring(d.marca), tostring(d.antes), tostring(d.despues), tostring(d.otraVez),
		d.avisos, tostring(d.ultimaTras), tostring(d.cableado), tostring(d.olvidado), tostring(d.fuera), ok(bien)
	)
end

return Pruebas
