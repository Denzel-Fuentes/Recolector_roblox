--!strict
--[[
	Base (ModuleScript)
	El panel de tu base personal, con tres pestanas que corresponden a los
	muebles fisicos de la parcela (los prompts de cada mueble abren su pestana):

	  Estanteria  las 12 figuritas: nombre, tenida o no, y para las 6 fijas la
	              pista de su escondite (KOTAMON: las fijas se encuentran
	              explorando; la pista hace que explorar tenga sentido).
	  Radio       las 7 cintas: reproducir / parar (ReproducirCintaEvent).
	  Exhibidor   los 6 pedestales: que mascota hay en cada uno y quitarla.
	              Poner se hace desde el Album (elegir la copia).

	Arriba, el contador de "me gusta" recibidos: la unica puntuacion social.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Paleta = require(Config:WaitForChild("Paleta"))
local Textos = require(Config:WaitForChild("Textos"))
local GameConfig = require(Config:WaitForChild("GameConfig"))
local DefinicionesColeccionables = require(Config:WaitForChild("DefinicionesColeccionables"))
local DefinicionesMascotas = require(Config:WaitForChild("DefinicionesMascotas"))
local Red = require(Shared:WaitForChild("Utilidades"):WaitForChild("Red"))

local Cliente = script.Parent.Parent
local EstadoCliente = require(Cliente:WaitForChild("EstadoCliente"))
local Componentes = require(script.Parent:WaitForChild("Componentes"))
local Menu = require(script.Parent:WaitForChild("Menu"))

local ReproducirCintaEvent = Red.evento("ReproducirCintaEvent")
local ExhibirEvent = Red.evento("ExhibirEvent")

local Base = {}

local modal = Componentes.modal("Base", Textos.BASE.titulo, 760, 560)
local contenido = modal.contenido
local textoMeGusta = Componentes.texto({ Parent = modal.panel, Size = UDim2.fromOffset(260, 24), Position = UDim2.new(1, -330, 0, 14), Tamano = 14, Color = Paleta.UI_ACENTO, Alinear = Enum.TextXAlignment.Right })
local cuerpo = Componentes.scroll(contenido, UDim2.new(1, 0, 1, -46), UDim2.fromOffset(0, 44))
Componentes.lista(cuerpo, 6)
Componentes.padding(cuerpo, 4)

local pestanaActual = 1

local function fila(orden: number, alto: number?): Frame
	local f = Componentes.marco({ Parent = cuerpo, Size = UDim2.new(1, -12, 0, alto or 48), Color = Paleta.UI_PANEL, Radio = 8, Orden = orden, Nombre = "Fila" .. orden })
	Componentes.padding(f, 10, 6)
	return f
end

local function pintarEstanteria()
	local p = EstadoCliente.perfil
	for i, def in DefinicionesColeccionables.FIGURINAS do
		local tiene = p and p.figurinas and p.figurinas[def.id] == true
		local f = fila(i, 46)
		local marca = Componentes.marco({ Parent = f, Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(0, 8), Color = if tiene then Paleta.UI_ACENTO else Paleta.UI_FONDO, Radio = 9 })
		marca.Name = "Marca"
		Componentes.texto({ Parent = f, Texto = string.format("%d. %s", i, if tiene then def.nombre else "???"), Size = UDim2.new(0.5, 0, 0, 22), Position = UDim2.fromOffset(28, 0), Tamano = 15, Negrita = true, Color = if tiene then Paleta.UI_TEXTO else Paleta.UI_TEXTO_SUAVE })
		local pista = if def.fija then ("Escondite: " .. (def.escondite or "")) else "Sale de los montones"
		Componentes.texto({ Parent = f, Texto = pista, Size = UDim2.new(0.6, 0, 0, 16), Position = UDim2.fromOffset(28, 22), Tamano = 11, Color = Paleta.UI_TEXTO_SUAVE })
	end
end

local function pintarRadio()
	local p = EstadoCliente.perfil
	local puesta = if p then p.cintaPuesta else nil
	for i, def in DefinicionesColeccionables.CINTAS do
		local tiene = p and p.cintas and p.cintas[def.id] == true
		local f = fila(i, 50)
		Componentes.texto({ Parent = f, Texto = "♫ " .. (if tiene then def.nombre else "???"), Size = UDim2.new(0.55, 0, 0, 22), Tamano = 15, Negrita = true, Color = if tiene then Paleta.UI_TEXTO else Paleta.UI_TEXTO_SUAVE })
		Componentes.texto({ Parent = f, Texto = if tiene then (if def.sonidoId == 0 then Textos.BASE.sinAudio else string.format("%d:%02d", math.floor(def.duracion / 60), def.duracion % 60)) else Textos.BASE.cintaNoTienes, Size = UDim2.new(0.55, 0, 0, 16), Position = UDim2.fromOffset(0, 22), Tamano = 11, Color = Paleta.UI_TEXTO_SUAVE })
		if tiene then
			local sonando = puesta == def.id
			Componentes.boton({ Parent = f, Texto = if sonando then Textos.BASE.parar else Textos.BASE.reproducir, Size = UDim2.fromOffset(130, 32), Position = UDim2.new(1, -130, 0.5, -16), Color = if sonando then Paleta.UI_PANEL_CLARO else Paleta.UI_ACENTO, ColorTexto = if sonando then Paleta.UI_TEXTO else Paleta.UI_FONDO, Tamano = 13, alPulsar = function()
				ReproducirCintaEvent:FireServer(if sonando then nil else def.id)
			end })
		end
	end
end

local function pintarExhibidor()
	local p = EstadoCliente.perfil
	for i = 1, GameConfig.PEDESTALES do
		local uid = p and p.exhibidas and p.exhibidas[tostring(i)]
		local copia = uid and p.mascotas[uid]
		local def = copia and DefinicionesMascotas.obtener(copia.id)
		local f = fila(i, 50)
		Componentes.texto({ Parent = f, Texto = "Pedestal " .. i, Size = UDim2.new(0.3, 0, 1, 0), Tamano = 14, Color = Paleta.UI_TEXTO_SUAVE })
		if def and copia then
			Componentes.texto({ Parent = f, Texto = def.nombre .. " · " .. DefinicionesMascotas.nombreEstado(copia.estado), Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(0.3, 0, 0, 0), Tamano = 15, Negrita = true, Color = Paleta.RAREZA[def.rareza] })
			Componentes.boton({ Parent = f, Texto = Textos.ALBUM.quitarExhibir, Size = UDim2.fromOffset(150, 32), Position = UDim2.new(1, -150, 0.5, -16), Tamano = 12, alPulsar = function()
				ExhibirEvent:FireServer(nil, i)
			end })
		else
			Componentes.texto({ Parent = f, Texto = "Vacío · elige una mascota en el Álbum", Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0.3, 0, 0, 0), Tamano = 13, Color = Paleta.UI_TEXTO_SUAVE })
		end
	end
	local abrir = Componentes.boton({ Parent = cuerpo, Texto = Textos.HUD.album, Size = UDim2.new(1, -12, 0, 36), Orden = 99, Color = Paleta.UI_ACENTO, ColorTexto = Paleta.UI_FONDO, alPulsar = function()
		Menu.abrir("Album")
	end })
	abrir.Name = "AbrirAlbum"
end

local PINTORES = { pintarEstanteria, pintarRadio, pintarExhibidor }

local function repintar()
	Componentes.limpiar(cuerpo)
	local p = EstadoCliente.perfil
	textoMeGusta.Text = Textos.formatear(Textos.BASE.meGusta, { n = if p then (p.meGusta or 0) else 0 })
	local pintor = PINTORES[pestanaActual]
	if pintor then
		pintor()
	end
end

local pestanas = Componentes.pestanas(contenido, { Textos.BASE.estanteria, Textos.BASE.radio, Textos.BASE.exhibidor }, function(i)
	pestanaActual = i
	repintar()
end)

EstadoCliente.alCambiarPerfil:Connect(function()
	if modal.estaAbierto() then
		repintar()
	end
end)

table.insert(modal.alCerrar, function()
	Menu.notificarCierre("Base")
end)

Menu.registrar("Base", {
	abrir = function(argumento)
		modal.abrir()
		local indice = 1
		if argumento == "radio" then
			indice = 2
		elseif argumento == "exhibidor" then
			indice = 3
		end
		pestanas.seleccionar(indice)
	end,
	cerrar = modal.cerrar,
	estaAbierto = modal.estaAbierto,
	primerSeleccionable = function()
		return Componentes.primerSeleccionable(cuerpo) or modal.botonCerrar
	end,
})

return Base
