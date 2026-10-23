--!nonstrict
--[[
	Pruebas de los pases y cosmeticos (lote 8): Dinero x2 dobla el pago,
	Bolsa XL suma 10 huecos, el Turbo se acumula, y los cosmeticos solo se
	ponen si se tienen (y se ven en la bolsa lanzada). Las del catalogo de
	la economia v4 (Turbo que solo corre jugando, VIP, Pack de inicio,
	cosmeticos nuevos, ofertas) estan en Catalogo.

	Usan el modo dev de pases (Monetizacion.fijarModoDev) y lo dejan como
	estaba.
]]

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Mejoras = require(Servicios:WaitForChild("Mejoras"))
local Monetizacion = require(Servicios:WaitForChild("Monetizacion"))
local Cosmeticos = require(Servicios:WaitForChild("Cosmeticos"))
local Turbo = require(Servicios:WaitForChild("Turbo"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

local function conPases(activo: boolean, fn: () -> any): any
	local antes = Monetizacion.modoDev()
	Monetizacion.fijarModoDev(activo)
	local bien, resultado = pcall(fn)
	Monetizacion.fijarModoDev(antes)
	if not bien then
		error(resultado, 0)
	end
	return resultado
end

local function papel(n: number)
	local items = {}
	for _ = 1, n do
		table.insert(items, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 10 })
	end
	return items
end

-- Dinero x2: el mismo deposito paga el doble (sin Turbo: lo quita un
-- momento y lo devuelve)
function Pruebas.paseDineroX2()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local turbo = p.turboRestante
	p.turboRestante = 0
	local exito, sin, con = pcall(function()
		local s = conPases(false, function()
			return Bolsa.depositarItems(j, papel(5), 0, nil).dinero
		end)
		local c = conPases(true, function()
			return Bolsa.depositarItems(j, papel(5), 0, nil).dinero
		end)
		return s, c
	end)
	p.turboRestante = turbo
	Perfiles.marcarSucio(j)
	if not exito then
		return "error: " .. tostring(sin) .. " => FALLO"
	end
	return string.format("sin pase $%d | con pase $%d => %s", sin, con, ok(con == sin * 2 and sin > 0))
end

-- Bolsa XL: +10 huecos encima del nivel de la mejora
function Pruebas.paseBolsaXL()
	local j = jugador()
	local sin = conPases(false, function()
		return Bolsa.capacidad(j)
	end)
	local con = conPases(true, function()
		return Bolsa.capacidad(j)
	end)
	return string.format("Bolsa nivel %d: %d huecos sin pase, %d con Bolsa XL => %s", Mejoras.nivel(j, "Bolsa"), sin, con, ok(con == sin + 10))
end

-- El Turbo se acumula: 15 min sobre 15 min son 30 (en segundos que quedan,
-- perfil.turboRestante: economia v4)
function Pruebas.turboAcumula()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local antes = p.turboRestante
	p.turboRestante = 0
	Turbo.anadir(j, 15 * 60)
	local uno = Turbo.restante(j)
	Turbo.anadir(j, 15 * 60)
	local dos = Turbo.restante(j)
	p.turboRestante = antes
	Turbo.sincronizar(j)
	Perfiles.marcarSucio(j)
	return string.format("uno %d s, dos %d s => %s", uno, dos, ok(math.abs(uno - 900) <= 1 and math.abs(dos - 1800) <= 1))
end

-- Un cosmetico solo se pone si se tiene; puesto, la bolsa lanzada lo lleva
function Pruebas.cosmeticoBolsa()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local diseno, estela = p.disenoBolsa, p.estela
	local sinPase = conPases(false, function()
		return Cosmeticos.equipar(j, "bolsa", "Dorada")
	end)
	local resultado = conPases(true, function()
		local conPase = Cosmeticos.equipar(j, "bolsa", "Dorada")
		local conEstela = Cosmeticos.equipar(j, "estela", "Arcoiris")
		local puesto = Cosmeticos.puesto(j, "bolsa")
		-- Bolsa lanzada: se mira el modelo en vuelo (llena: el servidor no lanza
		-- una a medias; con los pases encendidos lleva los 10 huecos de Bolsa XL)
		Comunes.yaLanzo(j)
		local zona = require(Servicios:WaitForChild("Mundo")).zonaAcierto()
		Comunes.teletransportar(j, zona.Position + Vector3.new(0, 0, -20))
		task.wait(0.3)
		Comunes.llenarBolsa(j, { tipo = "basura", nombre = "Papel", material = "Papel", valor = 1 })
		local Botin = require(Servicios:WaitForChild("Botin"))
		Botin.lanzarBolsa(j, zona.Position, 1)
		task.wait(0.15)
		local dorada, trail = false, false
		for _, d in workspace.Objetos:GetDescendants() do
			if d:IsA("Trail") then
				trail = true
			elseif d:IsA("BasePart") and d.Parent and d.Parent.Name == "Bolsa" and d.Material == Enum.Material.Metal then
				dorada = true
			end
		end
		task.wait(2.5)
		return string.format("con pase: %s, estela %s, puesto %s | en vuelo: dorada=%s estela=%s",
			tostring(conPase), tostring(conEstela), if puesto then puesto.id else "nada", tostring(dorada), tostring(trail)),
			conPase and conEstela and puesto ~= nil and dorada and trail
	end)
	local texto, bien = resultado, false
	if typeof(resultado) == "string" then
		texto = resultado
	end
	-- conPases devuelve solo el primer valor: se repite la cuenta
	bien = string.find(texto, "con pase: true, estela true, puesto Dorada | en vuelo: dorada=true estela=true", 1, true) ~= nil
	p.disenoBolsa, p.estela = diseno, estela
	Perfiles.marcarSucio(j)
	Cosmeticos.alCambiar:Fire(j)
	return string.format("sin pase se pone=%s | %s => %s", tostring(sinPase), texto, ok(not sinPase and bien))
end

return Pruebas
