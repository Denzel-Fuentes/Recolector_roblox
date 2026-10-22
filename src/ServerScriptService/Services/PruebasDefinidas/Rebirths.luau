--!nonstrict
--[[
	Pruebas de los rebirths (diseno v2, lote 4): la tabla y su formula, los
	requisitos (mejoras al maximo y dinero en mano), que renacer reinicia lo
	que toca y conserva lo demas, el multiplicador en el pago y el grupo de
	colision del personaje (las barreras de los cuadrantes).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local DefinicionesRebirths = require(Shared:WaitForChild("Config"):WaitForChild("DefinicionesRebirths"))

local Servicios = script.Parent.Parent
local Perfiles = require(Servicios:WaitForChild("Perfiles"))
local Bolsa = require(Servicios:WaitForChild("Bolsa"))
local Rebirths = require(Servicios:WaitForChild("Rebirths"))
local Economia = require(Servicios:WaitForChild("Economia"))

local Comunes = require(script.Parent:WaitForChild("Comunes"))
local jugador = Comunes.jugador

local Pruebas = {}

local function ok(cond: boolean): string
	return if cond then "OK" else "FALLO"
end

-- Guarda y restaura lo que tocan las pruebas de rebirth (tambien los
-- cosmeticos: "renacer" se pone la estela para ver que se conserva, y antes
-- se quedaba puesta en el perfil)
local function copiar(p)
	return { dinero = p.dinero, rebirths = p.rebirths, mejoras = table.clone(p.mejoras), estela = p.estela, disenoBolsa = p.disenoBolsa }
end
local function restaurar(j, p, copia)
	p.dinero = copia.dinero
	p.rebirths = copia.rebirths
	p.mejoras = copia.mejoras
	p.estela = copia.estela
	p.disenoBolsa = copia.disenoBolsa
	Perfiles.marcarSucio(j)
end

local function maxear(p)
	for id in p.mejoras do
		p.mejoras[id] = GameConfig.NIVEL_MAX_MEJORA
	end
end

-- Los cinco del diseno y la formula desde el sexto (x4 y +0,5)
function Pruebas.rebirthTabla()
	local requisitos, mults = {}, {}
	for n = 1, 7 do
		local r = DefinicionesRebirths.rebirth(n)
		table.insert(requisitos, tostring(r.requisito))
		table.insert(mults, tostring(r.multiplicador))
	end
	local req, mul = table.concat(requisitos, ","), table.concat(mults, ",")
	return string.format("requisitos %s | multiplicadores %s | x%s sin rebirths | el 3 abre %s => %s",
		req, mul, tostring(DefinicionesRebirths.multiplicador(0)), DefinicionesRebirths.rebirth(3).desbloquea,
		ok(req == "50000,200000,800000,3200000,12800000,51200000,204800000" and mul == "1.5,2,2.5,3,3.5,4,4.5"
			and DefinicionesRebirths.multiplicador(0) == 1 and DefinicionesRebirths.rebirth(3).desbloquea == "bolsaPlateada"))
end

-- Sin mejoras al maximo, o sin el dinero, no se renace
function Pruebas.renacerRequisitos()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = copiar(p)
	p.rebirths = 0
	for id in p.mejoras do
		p.mejoras[id] = 0
	end
	p.dinero = 10 ^ 7
	local ok1, m1 = Rebirths.renacer(j)
	maxear(p)
	p.dinero = DefinicionesRebirths.rebirth(1).requisito - 1
	local ok2, m2 = Rebirths.renacer(j)
	local sigue = p.rebirths == 0 and p.dinero == DefinicionesRebirths.rebirth(1).requisito - 1
	restaurar(j, p, copia)
	return string.format("sin mejoras: %s (%s) | con mejoras y $1 menos: %s (%s) | nada cambio=%s => %s",
		tostring(ok1), m1, tostring(ok2), m2, tostring(sigue), ok(not ok1 and m1 == "mejoras" and not ok2 and m2 == "dinero" and sigue))
end

-- Renacer: dinero y mejoras a 0, un rebirth mas, el resto intacto; el pago
-- sale multiplicado (papel $5 x1,5 = $8) y el personaje cambia de grupo
function Pruebas.renacer()
	local j = jugador()
	local p = Perfiles.obtener(j)
	local copia = copiar(p)
	p.estela = "Arcoiris"
	local aciertos = p.estadisticas.aciertos or 0
	p.rebirths = 0
	maxear(p)
	p.dinero = DefinicionesRebirths.rebirth(1).requisito + 123
	Bolsa.vaciar(j)
	local exito = Rebirths.renacer(j)
	local rebirthsTras = p.rebirths
	local mejorasCero = true
	for _, n in p.mejoras do
		mejorasCero = mejorasCero and n == 0
	end
	task.wait(0.6)
	local humanoide = j.Character and j.Character:FindFirstChildOfClass("Humanoid")
	local root = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
	local grupo = root and root.CollisionGroup
	local velocidad = humanoide and humanoide.WalkSpeed
	local antesPago = Economia.dinero(j)
	local resumen = Bolsa.depositarItems(j, { { tipo = "basura", nombre = "Papel", material = "Papel" } }, 0)
	local cobrado = Economia.dinero(j) - antesPago
	local conserva = p.estela == "Arcoiris" and (p.estadisticas.aciertos or 0) == aciertos
	restaurar(j, p, copia)
	return string.format("renacer=%s | dinero tras renacer=%d mejoras a 0=%s rebirths=%d | conserva estela y estadisticas=%s | velocidad=%s grupo=%s | papel paga $%d (resumen %d) => %s",
		tostring(exito), antesPago, tostring(mejorasCero), rebirthsTras, tostring(conserva), tostring(velocidad), tostring(grupo), cobrado, resumen.dinero,
		ok(exito and antesPago == 0 and mejorasCero and rebirthsTras == 1 and conserva and velocidad == 16 and grupo == "PersonajeR1" and cobrado == 8))
end

return Pruebas
