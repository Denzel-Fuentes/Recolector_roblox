--!strict
--[[
	Red
	Acceso a los RemoteEvents de Shared/Events por nombre, con WaitForChild para
	que el orden de arranque de scripts no importe. Los eventos existen como
	*.model.json en el repo; aqui no se crea ninguno.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Red = {}

local eventos = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Events")

function Red.evento(nombre: string): RemoteEvent
	local e = eventos:WaitForChild(nombre, 10)
	assert(e and e:IsA("RemoteEvent"), "Red: no existe el RemoteEvent " .. nombre)
	return e
end

return Red
