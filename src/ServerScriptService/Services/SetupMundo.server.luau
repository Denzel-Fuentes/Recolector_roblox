--!strict
--[[
	SetupMundo
	Unica responsabilidad: al arrancar, asegurar que existe la geometria del
	mundo (adoptando workspace.Mundo o construyendolo como fallback) y publicar
	un resumen en consola para poder verificar el place de un vistazo.

	ESTE SCRIPT NO CONSTRUYE NADA en el flujo normal: ver Services/Mundo.luau.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local Mundo = require(Servicios:WaitForChild("Mundo"))

Mundo.asegurar()

local ranuras = #Mundo.ranuras()
local parcelas = #Mundo.parcelas()
local figurinas = #Mundo.figurinasFijas()
local contenedor = Mundo.contenedor() ~= nil
local zona = Mundo.zonaAcierto() ~= nil
local maquina = Mundo.maquinaRefrescos() ~= nil

print(string.format(
	"SetupMundo: %d ranuras, %d parcelas, %d figurinas fijas, contenedor=%s, zonaAcierto=%s, maquina=%s",
	ranuras,
	parcelas,
	figurinas,
	tostring(contenedor),
	tostring(zona),
	tostring(maquina)
))

if ranuras ~= 24 or parcelas ~= 16 or figurinas ~= 6 or not contenedor or not zona or not maquina then
	warn("SetupMundo: el mundo no coincide con lo esperado (24/16/6 + contenedor + zona + maquina). Rehornea con herramientas/construir-mundo.luau")
end
