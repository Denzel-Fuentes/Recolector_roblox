--!nonstrict
--[[
	Pruebas de la punteria del diseno v2 (lote 5): tabla de bonus por
	distancia, la racha (+10 % por acierto hasta +50 %, a 0 al fallar, sin
	contar tiros a quemarropa), el primer lanzamiento que siempre entra, la
	formula de pago de un tiro de verdad y los records.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesPunteria = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesPunteria"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Economia = require(Servicios:WaitForChild("Economia"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Botin = require(Servicios:WaitForChild("Botin"))
local Mundo = require(Servicios:WaitForChild("Mundo"))
local Lanzamiento = require(Servicios:WaitForChild("Lanzamiento"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador, teletransportar = Comunes.jugador, Comunes.teletransportar

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- De +20 % a 10 studs a +150 % desde 60; nada por debajo de 10
function Pruebas.bonusDistancia()
	local casos = { { 8, 0 }, { 15, 0.2 }, { 25, 0.4 }, { 40, 0.7 }, { 50, 1.0 }, { 65, 1.5 } }
	local partes, bien = {}, true
	for _, c in casos do
		local b = DefinicionesPunteria.bonusDistancia(c[1])
		table.insert(partes, string.format("%d->%+d%%", c[1], math.floor(b * 100 + 0.5)))
		bien = bien and math.abs(b - c[2]) < 1e-6
	end
	return table.concat(partes, " ") .. " => " .. ok(bien)
end

-- Cinco aciertos seguidos llegan a +50 % de racha, el sexto se queda en
-- +50 %; un tiro a quemarropa no suma ni corta; fallar la pone a 0
function Pruebas.racha()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.racha
	p.racha = 0
	local bonos = {}
	for _ = 1, 6 do
		local bonus = Lanzamiento.registrarAcierto(j, 25)
		table.insert(bonos, string.format("%.1f", bonus))
	end
	local rachaTras6 = p.racha
	local bonusCerca = Lanzamiento.registrarAcierto(j, 8)
	local rachaTrasCerca = p.racha
	Lanzamiento.registrarFallo(j)
	local rachaTrasFallo = p.racha
	p.racha = antes
	Perfiles.marcarSucio(j)
	local serie = table.concat(bonos, ",")
	return string.format("bonus desde 25 studs: %s | racha tras 6=%d | a 8 studs: bonus %.1f racha %d | tras fallar %d => %s",
		serie, rachaTras6, bonusCerca, rachaTrasCerca, rachaTrasFallo,
		ok(serie == "0.5,0.6,0.7,0.8,0.9,0.9" and rachaTras6 == 6 and bonusCerca == 0 and rachaTrasCerca == 6 and rachaTrasFallo == 0))
end

-- El primer lanzamiento del perfil entra aunque se apunte a otro sitio y
-- con poca fuerza
function Pruebas.primeroEntra()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local lanzamientosAntes = p.estadisticas.lanzamientos or 0
	local aciertosAntes = p.estadisticas.aciertos or 0
	p.estadisticas.lanzamientos = 0
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -35))
	task.wait(0.4)
	Bolsa.vaciar(j)
	Bolsa.meter(j, { tipo = "basura", nombre = "Papel", material = "Papel" })
	local lanzo = Botin.lanzarBolsa(j, zona.Position + Vector3.new(-40, 0, -60), 0.2)
	task.wait(3)
	local entro = (p.estadisticas.aciertos or 0) > aciertosAntes
	local segundo = Lanzamiento.esPrimero(j)
	p.estadisticas.lanzamientos = math.max(lanzamientosAntes, 1)
	Perfiles.marcarSucio(j)
	return string.format("lanzo=%s entro=%s | ya no es el primero=%s => %s", tostring(lanzo), tostring(entro), tostring(not segundo), ok(lanzo and entro and not segundo))
end

-- Pago de un tiro de verdad: 10 piezas de plastico ($7) desde ~25 studs con
-- la racha a 0 y sin rebirths: 70 x (1 + 0,4 + 0,1) = $105. Y el record del
-- servidor sube.
function Pruebas.pagoFormula()
	local j = jugador()
	Comunes.yaLanzo(j)
	local p = Perfiles.obtener(j)
	local rachaAntes, rebirthsAntes, brazoAntes = p.racha, p.rebirths, p.mejoras.Brazo
	p.racha = 0
	p.rebirths = 0
	p.mejoras.Brazo = GameConfig.NIVEL_MAX_MEJORA
	local zona = Mundo.zonaAcierto()
	teletransportar(j, zona.Position + Vector3.new(0, 0, -25))
	task.wait(0.4)
	Bolsa.vaciar(j)
	for _ = 1, 10 do
		Bolsa.meter(j, { tipo = "basura", nombre = "Plástico", material = "Plastico" })
	end
	local antes = Economia.dinero(j)
	local lanzo = Botin.lanzarBolsa(j, zona.Position, 1)
	task.wait(2.6)
	local cobrado = Economia.dinero(j) - antes
	local record = Lanzamiento.recordServidor()
	local rachaTras = p.racha
	p.racha, p.rebirths, p.mejoras.Brazo = rachaAntes, rebirthsAntes, brazoAntes
	Perfiles.marcarSucio(j)
	return string.format("lanzo=%s cobrado=$%d (esperado 105) racha=%d record del servidor=%d => %s",
		tostring(lanzo), cobrado, rachaTras, record, ok(lanzo and cobrado == 105 and rachaTras == 1 and record >= 20))
end

return Pruebas
