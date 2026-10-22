--!strict
--[[
	TraducirMundo
	Unica responsabilidad: poner en el idioma del jugador los textos que vienen
	escritos en el mundo (carteles y placas horneados, la etiqueta "Bolsa de X"
	que crea el servidor). La UI y los prompts se traducen solos (Idioma.textos,
	Prompts.client); esto es lo que el cliente no construye.

	Un TextLabel con atributo Mensaje (Idioma.codificar) se escribe con ese
	mensaje; si no lo tiene y su texto es un literal del original ("Patio de
	basura ↑"), con su traduccion. Lo demas se deja (nombres, numeros).
	Cambiar Text en el cliente es local: el servidor y los demas jugadores no
	lo ven. En espanol no hace nada.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Idioma = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Utilidades"):WaitForChild("Idioma"))

if Idioma.codigo == "es" then
	return
end

local function traducir(inst: Instance)
	if not inst:IsA("TextLabel") then
		return
	end
	local mensaje = Idioma.decodificar(inst:GetAttribute("Mensaje"))
	local texto = if mensaje then Idioma.resolver(mensaje) else Idioma.literal(inst.Text)
	if texto ~= "" and texto ~= inst.Text then
		inst.Text = texto
	end
end

for _, inst in workspace:GetDescendants() do
	traducir(inst)
end
workspace.DescendantAdded:Connect(traducir)
