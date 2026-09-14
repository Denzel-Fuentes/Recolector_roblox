--!strict
--[[
	Senal
	Evento minimo entre modulos del mismo lado (servidor con servidor, cliente
	con cliente). Evita depender de BindableEvents para cosas que solo son tablas
	de callbacks. Los callbacks se ejecutan en su propio hilo para que un error en
	uno no rompa a los demas.
]]

export type Conexion = { Disconnect: (Conexion) -> () }
export type Senal<T...> = {
	Connect: (Senal<T...>, (T...) -> ()) -> Conexion,
	Fire: (Senal<T...>, T...) -> (),
}

local Senal = {}
Senal.__index = Senal

function Senal.nueva<T...>(): Senal<T...>
	local self = setmetatable({ _callbacks = {} :: { [number]: (T...) -> () }, _siguiente = 1 }, Senal)
	return (self :: any) :: Senal<T...>
end

function Senal:Connect(callback)
	local id = self._siguiente
	self._siguiente += 1
	self._callbacks[id] = callback
	local callbacks = self._callbacks
	return {
		Disconnect = function()
			callbacks[id] = nil
		end,
	}
end

function Senal:Fire(...)
	for _, callback in self._callbacks do
		task.spawn(callback, ...)
	end
end

return Senal
