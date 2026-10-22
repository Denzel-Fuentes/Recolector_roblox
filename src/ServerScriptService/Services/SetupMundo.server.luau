--!strict
--[[
	SetupMundo
	Unica responsabilidad: al arrancar, asegurar que existe la geometria del
	mundo (adoptando workspace.Mundo o construyendolo como fallback) y publicar
	un resumen en consola para poder verificar el place de un vistazo.

	ESTE SCRIPT NO CONSTRUYE NADA en el flujo normal: ver Services/Mundo.luau.

	Mientras el place guardado sea anterior al mundo v2 (lote 2), aun tiene
	parcelas y la maquina de refrescos: sus prompts se apagan aqui para que
	no ofrezcan nada que ya no existe. Y el de Dona Chatarra horneado antes
	del 29 sep aun dice "Hablar": ya no tiene dialogos (decision del
	usuario), solo abre la tienda.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Servicios = ServerScriptService:WaitForChild("Services")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local Textos = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Textos"))
local Mundo = require(Servicios:WaitForChild("Mundo"))

Mundo.asegurar()

local ranuras = #Mundo.ranuras()
local figurinas = #Mundo.figurinasFijas()
local contenedor = Mundo.contenedor() ~= nil
local zona = Mundo.zonaAcierto() ~= nil

print(string.format(
	"SetupMundo: %d ranuras, %d figurinas fijas, contenedor=%s, zonaAcierto=%s",
	ranuras,
	figurinas,
	tostring(contenedor),
	tostring(zona)
))

local ranurasEsperadas = 0
for _, def in GameConfig.TAMANOS_MONTON do
	ranurasEsperadas += def.cantidad
end
local figurinasBien = figurinas == 6 or not GameConfig.activa("FIGURINAS")
if ranuras ~= ranurasEsperadas or not figurinasBien or not contenedor or not zona then
	warn(string.format("SetupMundo: el mundo no coincide con lo esperado (%d ranuras + contenedor + zona). Rehornea con herramientas/construir-mundo.luau", ranurasEsperadas))
end

-- Restos de un place anterior al mundo v2: sin prompts
for _, tag in { "Parcela", "MaquinaRefrescos" } do
	for _, inst in CollectionService:GetTagged(tag) do
		for _, d in inst:GetDescendants() do
			if d:IsA("ProximityPrompt") then
				d.Enabled = false
			end
		end
	end
end

-- El prompt del tendero de un place horneado antes (29 sep: abre la tienda;
-- 5 oct: ya no se llama "Dona Chatarra")
local chatarra = Mundo.npc("DonaChatarra")
if chatarra then
	for _, d in chatarra:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.ActionText = Textos.PATIO.tienda
			d.ObjectText = Textos.MUNDO.tendero
		end
	end
end
