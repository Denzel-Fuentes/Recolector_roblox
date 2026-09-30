--!strict
--[[
	DefinicionesTutorial
	Los pasos del tutorial jugable, en orden. Solo datos.

	Por que existe (auditoria 26 sep): el jugador aparecia en su base, lejos
	del patio, con un mensaje que lo mandaba a hablar con un NPC que solo da
	consejos. Roblox mide el rebote en los primeros 60 s como senal negativa
	de alta importancia, asi que el objetivo es llegar al primer cobro en
	menos de 90 s: patio -> excavar -> llenar -> lanzar -> mejora. (Diseno
	v2: el paso de la primera mascota llega en el lote 9.)

	perfil.tutorial = cuantos pasos ha completado (0..#PASOS). El servidor
	(Services/Tutorial) los avanza; el cliente (UI/Tutorial) pinta el actual
	y la flecha hacia su "objetivo": "montonLleno" (el monton sin abrir mas
	cercano, workspace.Montones con Estado = "lleno") o un tag de
	CollectionService ("Contenedor"). Sin objetivo, la tarjeta ofrece abrir
	el panel del paso (`panel`).
]]

export type Paso = {
	id: string,
	texto: string, -- clave de Textos.TUTORIAL
	objetivo: string?, -- a donde apunta la flecha (ver cabecera)
	panel: string?, -- panel que ofrece abrir la tarjeta (Menu)
}

local DefinicionesTutorial = {}

DefinicionesTutorial.PASOS = {
	{ id = "patio", texto = "paso1", objetivo = "montonLleno" },
	{ id = "excavar", texto = "paso2", objetivo = "montonLleno" },
	{ id = "llenar", texto = "paso3" },
	{ id = "lanzar", texto = "paso4", objetivo = "Contenedor" },
	{ id = "mejora", texto = "paso5", panel = "Tienda" },
} :: { Paso }

DefinicionesTutorial.TOTAL = #DefinicionesTutorial.PASOS

-- Posicion (1..TOTAL) del paso con ese id
function DefinicionesTutorial.indice(id: string): number
	for i, paso in DefinicionesTutorial.PASOS do
		if paso.id == id then
			return i
		end
	end
	error("paso de tutorial desconocido: " .. id)
end

-- El paso que toca con `completados` hechos; nil si ya termino
function DefinicionesTutorial.actual(completados: number): Paso?
	return DefinicionesTutorial.PASOS[completados + 1]
end

return DefinicionesTutorial
