--!nonstrict
--[[
	instalar-desde-http.luau — HERRAMIENTA DE DESARROLLO, no entra al juego.

	Sustituto de emergencia del plugin de Rojo: descarga src/ desde
	herramientas/servir-fuentes.ps1 (http://localhost:8123) y crea/actualiza el
	arbol del juego en el DataModel Edit con las MISMAS reglas que
	default.project.json:

	    X.server.luau  -> Script         X.client.luau -> LocalScript
	    X.luau         -> ModuleScript   X.model.json  -> instancia (className)
	    carpetas       -> Folder (o el contenedor ya existente: StarterPlayerScripts)

	Solo escribe Source si cambio, y borra lo que sobre dentro de las carpetas
	gestionadas (semantica $path de Rojo). Es idempotente: se puede correr tras
	cada edicion. Cuando el plugin de Rojo se conecte no vera diferencias.

	Se pega en la barra de comandos o se manda por execute_luau.
]]

local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local BASE = "http://localhost:8123"

HttpService.HttpEnabled = true

local function get(ruta)
	return HttpService:GetAsync(BASE .. ruta, true)
end

local indice = HttpService:JSONDecode(get("/index.json"))

local grabando = ChangeHistoryService:TryBeginRecording("Instalar fuentes desde HTTP")

local creados, actualizados, iguales, borrados = 0, 0, 0, 0
local gestionadas = {} -- carpeta -> { nombre = true }

local function carpetaGestionada(inst)
	if not gestionadas[inst] then
		gestionadas[inst] = {}
	end
	return gestionadas[inst]
end

local function contenedor(segmentos)
	-- segmentos: { "ReplicatedStorage", "Shared", "Config" }
	local actual = game:GetService(segmentos[1])
	for i = 2, #segmentos do
		local nombre = segmentos[i]
		local hijo = actual:FindFirstChild(nombre)
		if not hijo then
			hijo = Instance.new("Folder")
			hijo.Name = nombre
			hijo.Parent = actual
			creados += 1
		end
		carpetaGestionada(actual)[nombre] = true
		actual = hijo
	end
	return actual
end

local function claseYNombre(archivo)
	local nombre, clase
	if archivo:match("%.server%.luau$") then
		nombre, clase = archivo:gsub("%.server%.luau$", ""), "Script"
	elseif archivo:match("%.client%.luau$") then
		nombre, clase = archivo:gsub("%.client%.luau$", ""), "LocalScript"
	elseif archivo:match("%.luau$") then
		nombre, clase = archivo:gsub("%.luau$", ""), "ModuleScript"
	elseif archivo:match("%.model%.json$") then
		nombre, clase = archivo:gsub("%.model%.json$", ""), "json"
	end
	return nombre, clase
end

for _, entrada in indice do
	local ruta = entrada.ruta -- "src/ReplicatedStorage/Shared/Config/X.luau"
	local segmentos = {}
	for s in ruta:gmatch("[^/]+") do
		table.insert(segmentos, s)
	end
	table.remove(segmentos, 1) -- "src"
	local archivo = table.remove(segmentos)
	local nombre, clase = claseYNombre(archivo)
	if nombre and clase then
		local padre = contenedor(segmentos)
		local fuente = get("/" .. ruta)
		if clase == "json" then
			local def = HttpService:JSONDecode(fuente)
			clase = def.className
		end
		carpetaGestionada(padre)[nombre] = true
		local existente = padre:FindFirstChild(nombre)
		if existente and existente.ClassName ~= clase then
			existente:Destroy()
			existente = nil
			borrados += 1
		end
		if not existente then
			local inst = Instance.new(clase)
			inst.Name = nombre
			if inst:IsA("LuaSourceContainer") then
				inst.Source = fuente
			end
			inst.Parent = padre
			creados += 1
		elseif existente:IsA("LuaSourceContainer") then
			if existente.Source ~= fuente then
				existente.Source = fuente
				actualizados += 1
			else
				iguales += 1
			end
		else
			iguales += 1
		end
	end
end

-- Borrar lo que sobre en las carpetas gestionadas (semantica $path)
for carpeta, esperados in gestionadas do
	for _, hijo in carpeta:GetChildren() do
		if not esperados[hijo.Name] and (hijo:IsA("LuaSourceContainer") or hijo:IsA("Folder") or hijo:IsA("RemoteEvent") or hijo:IsA("RemoteFunction")) then
			-- Solo dentro de carpetas que NO son servicios (un servicio puede tener otras cosas)
			if carpeta.Parent ~= game then
				hijo:Destroy()
				borrados += 1
			end
		end
	end
end

-- Restos de la plantilla rojo init
for _, resto in { game.ReplicatedStorage:FindFirstChild("Shared") and game.ReplicatedStorage.Shared:FindFirstChild("Hello"), game.ServerScriptService:FindFirstChild("Server") } do
	if resto and (resto:IsA("LuaSourceContainer")) then
		resto:Destroy()
		borrados += 1
	end
end
local spsClient = game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")
if spsClient and spsClient:IsA("LocalScript") then
	spsClient:Destroy()
	borrados += 1
end

-- Propiedades de default.project.json
local Lighting = game:GetService("Lighting")
Lighting.Ambient = Color3.new(0.32, 0.32, 0.32)
Lighting.OutdoorAmbient = Color3.new(0.38, 0.38, 0.38)
Lighting.ColorShift_Top = Color3.new(0, 0, 0)
Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
Lighting.Brightness = 1.3
Lighting.ExposureCompensation = -0.35
Lighting.EnvironmentDiffuseScale = 0.25
Lighting.EnvironmentSpecularScale = 0
Lighting.ClockTime = 13
Lighting.GlobalShadows = true
game.StarterPlayer.CharacterWalkSpeed = 16
game:GetService("SoundService").RespectFilteringEnabled = true
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate.Color = Color3.new(0.647, 0.647, 0.647)
	baseplate.Material = Enum.Material.SmoothPlastic
	baseplate.Locked = true
end

if grabando then
	ChangeHistoryService:FinishRecording(grabando, Enum.FinishRecordingOperation.Commit)
end

return string.format("instalado: %d creados, %d actualizados, %d iguales, %d borrados", creados, actualizados, iguales, borrados)
