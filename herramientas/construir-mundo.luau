--!nonstrict
--[[
	construir-mundo.luau — HERRAMIENTA DE DISENO, no entra al juego.

	Esta carpeta NO esta mapeada en default.project.json: Rojo no la sincroniza.
	Se pega en la barra de comandos de Studio (o se manda por execute_luau) sobre
	el DataModel Edit, con Rojo conectado para que exista
	ServerStorage.Herramientas.ConstructorMundo.

	DESPUES DE CONSTRUIR HAY QUE GUARDAR EL PLACE (Ctrl+S). La geometria vive en
	el place; este script y ConstructorMundo son su codigo fuente.

	    MODO = "previsualizar"  imprime el plan sin tocar nada
	    MODO = "construir"      borra workspace.Mundo y lo rehace (deshacible)
]]

local MODO = "construir"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerStorage = game:GetService("ServerStorage")

local ConstructorMundo = require(ServerStorage:WaitForChild("Herramientas"):WaitForChild("ConstructorMundo"))

if MODO == "previsualizar" then
	ConstructorMundo.previsualizar()
elseif MODO == "construir" then
	local grabando = ChangeHistoryService:TryBeginRecording("Construir mundo whitebox")
	local mundo = ConstructorMundo.construir()
	if grabando then
		ChangeHistoryService:FinishRecording(grabando, Enum.FinishRecordingOperation.Commit)
	end
	game:GetService("Selection"):Set({ mundo })
	print("Listo. Guarda el place (Ctrl+S).")
else
	warn("MODO desconocido: " .. tostring(MODO))
end
