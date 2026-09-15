--!nonstrict
--[[
	PruebasDefinidas (ModuleScript con hijos)
	Pruebas de servidor que corren DENTRO de la VM del juego (ver Pruebas).
	Cada una devuelve un string legible que acaba en "=> OK" o "=> FALLO"
	cuando comprueba algo; las de depuracion solo describen. Usan al primer
	jugador conectado en Play Solo.

	Estan repartidas por area en los modulos hijos (Patio, Bolsa, Progreso), y
	este init las junta en una sola tabla: el runner y quien las invoca no
	necesitan saber en cual esta cada una. Los ayudantes comunes (jugador,
	teletransportar) estan en Comunes.

	Se invocan asi desde execute_luau (DataModel Server):
	    game.ServerStorage.EjecutarPrueba:Invoke("estado")
	    game.ServerStorage.EjecutarPrueba:Invoke("excavar", 3)
	o por atributo (ver Pruebas.server): ServerStorage:SetAttribute("Prueba", "1:excavar|3").
]]

local Pruebas = {}

for _, hijo in script:GetChildren() do
	if hijo:IsA("ModuleScript") and hijo.Name ~= "Comunes" then
		for nombre, prueba in require(hijo) do
			assert(Pruebas[nombre] == nil, "prueba repetida: " .. nombre)
			Pruebas[nombre] = prueba
		end
	end
end

return Pruebas
