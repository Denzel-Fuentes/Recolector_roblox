--!strict
--[[
	Boton (constructor del Kit)
	Unica responsabilidad: el boton del kit. Cuerpo de color intenso con
	degradado, contorno marino, studs sutiles, texto blanco FredokaOne con
	contorno y una sombra dura debajo. Al pasar el raton crece un poco y al
	pulsar se hunde hasta la sombra (Springs de Fusion).

	  scope:Boton {
	    Texto?, Tamano? (del texto), Icono? (clave de Config/Iconos),
	    Color? (Paleta: los semanticos se respetan, cualquier otro se cambia
	            por el color fijo del boton, ver Tema.colorBoton),
	    Deshabilitado?, alPulsar?, Nombre?, Size?, Position?, AnchorPoint?,
	    Orden?, ZIndex?, Visible?, Radio?, Sombra? (por defecto si)
	  }

	=== Estructura ===
	Envoltorio (lo que se coloca y miden los layouts) { Sombra, Cuerpo }.
	El Cuerpo es el TextButton SIN texto propio: el texto va en un hijo
	(Etiqueta). Con ZIndexBehavior Sibling un hijo siempre se pinta encima
	del texto de su padre, asi que si el texto fuera del boton los studs lo
	taparian. Devuelve el envoltorio; el Cuerpo es el GuiButton que encuentra
	el gamepad (Selectable, contorno amarillo al elegirlo).

	Suena el "clic" del kit al pulsarlo (Client/Sonido) y "denegado" si se
	pulsa deshabilitado (p. ej. una mejora que no alcanza: el servidor ni se
	entera, pero el jugador si tiene que oir que no): lo que pase despues de
	un clic (una compra, un panel) trae su propio sonido.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))
local Paleta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Paleta"))
local Tema = require(script.Parent:WaitForChild("Tema"))
local Escala = require(script.Parent:WaitForChild("Escala"))
local Studs = require(script.Parent:WaitForChild("Studs"))
local Icono = require(script.Parent:WaitForChild("Icono"))
-- Kit -> UI -> Client
local Sonido = require(script.Parent.Parent.Parent:WaitForChild("Sonido"))

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek

type U<T> = Fusion.UsedAs<T>

export type Props = {
	Texto: U<string>?,
	Tamano: U<number>?,
	Icono: string?,
	Color: U<Color3?>?,
	Deshabilitado: U<boolean>?,
	alPulsar: (() -> ())?,
	Nombre: string?,
	Size: U<UDim2>?,
	Position: U<UDim2>?,
	AnchorPoint: U<Vector2>?,
	Orden: U<number>?,
	ZIndex: U<number>?,
	Visible: U<boolean>?,
	Radio: number?,
	Sombra: boolean?,
}

return function(scope: any, p: Props): Frame
	local conSombra = p.Sombra ~= false
	local desplazamiento = if conSombra then Tema.SOMBRA else 0
	local radio = p.Radio or Tema.RADIO
	local clave = p.Nombre or (if typeof(p.Texto) == "string" then p.Texto else "Boton")

	local encima = scope:Value(false)
	local pulsado = scope:Value(false)
	local elegido = scope:Value(false) -- seleccion con gamepad

	local deshabilitado = scope:Computed(function(use)
		return use(p.Deshabilitado or false) == true
	end)
	local color = scope:Computed(function(use)
		if use(deshabilitado) then
			return Paleta.UI_BLOQUEADO
		end
		return Tema.colorBoton(clave, use(p.Color) :: Color3?)
	end)
	local colorTexto = scope:Computed(function(use)
		return if use(deshabilitado) then Color3.fromRGB(236, 238, 245) else Tema.textoSobre(use(color))
	end)

	local escala = scope:Spring(
		scope:Computed(function(use)
			return if use(encima) and not use(deshabilitado) then 1.05 else 1
		end),
		40,
		0.6
	)
	local posicion = scope:Spring(
		scope:Computed(function(use)
			return UDim2.fromOffset(0, if use(pulsado) and not use(deshabilitado) then desplazamiento else 0)
		end),
		60,
		0.8
	)

	local tamanoTexto = scope:Computed(function(use)
		local base = use(p.Tamano or 16) :: number
		return math.max(base, if use(Escala.compacto) then Tema.TEXTO_MINIMO_COMPACTO else 0)
	end)

	-- Icono a la izquierda: el texto se aparta
	local icono = nil
	local margenIzquierdo = 10
	if p.Icono then
		local tamanoCaja = if typeof(p.Size) == "UDim2" then p.Size else UDim2.fromOffset(140, 40)
		local alto = tamanoCaja.Y.Offset - desplazamiento
		local lado = math.max(16, math.floor(alto * 0.62))
		icono = Icono(scope, {
			Clave = p.Icono,
			Tamano = lado,
			Position = UDim2.new(0, 8, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 3,
		})
		margenIzquierdo = lado + 14
	end

	local cuerpo = scope:New("TextButton")({
		Name = "Cuerpo",
		Text = "",
		Size = UDim2.new(1, 0, 1, -desplazamiento),
		Position = posicion,
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Selectable = scope:Computed(function(use)
			return not use(deshabilitado)
		end),
		-- Activo aunque este deshabilitado: asi Activated (el clic de verdad,
		-- que el motor cancela si el dedo arrastra una lista) llega y suena
		-- "denegado"; la accion la frena el propio Activated
		Active = true,
		SelectionImageObject = Tema.SELECCION_INVISIBLE,
		ZIndex = 2,
		[OnEvent("MouseEnter")] = function()
			encima:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			encima:set(false)
			pulsado:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pulsado:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pulsado:set(false)
		end,
		[OnEvent("SelectionGained")] = function()
			elegido:set(true)
		end,
		[OnEvent("SelectionLost")] = function()
			elegido:set(false)
		end,
		[OnEvent("Activated")] = function()
			if peek(deshabilitado) then
				Sonido.tocar("denegado")
				return
			end
			Sonido.tocar("clic")
			-- Toque o gamepad: no hay MouseButton1Down, se hunde un momento
			pulsado:set(true)
			task.delay(0.08, function()
				pulsado:set(false)
			end)
			if p.alPulsar then
				p.alPulsar()
			end
		end,
		[Children] = {
			Studs(scope, { Transparencia = Tema.STUDS_BOTON, Radio = radio }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, radio) }),
			scope:New("UIGradient")({ Color = Tema.DEGRADADO, Rotation = 90 }),
			scope:New("UIScale")({ Scale = escala }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = scope:Computed(function(use)
					return if use(elegido) then Paleta.UI_SELECCION else Paleta.UI_TINTA
				end),
				Thickness = scope:Computed(function(use)
					return if use(elegido) then Tema.GROSOR + 2 else Tema.GROSOR
				end),
			}),
			icono,
			scope:New("TextLabel")({
				Name = "Etiqueta",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = p.Texto or "",
				TextColor3 = colorTexto,
				TextSize = tamanoTexto,
				FontFace = Tema.FUENTE_TITULO,
				TextWrapped = true,
				TextXAlignment = if p.Icono then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
				ZIndex = 3,
				[Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, margenIzquierdo),
						PaddingRight = UDim.new(0, 10),
					}),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Paleta.UI_TINTA,
						Enabled = scope:Computed(function(use)
							return use(colorTexto) ~= Paleta.UI_TINTA
						end),
						Thickness = scope:Computed(function(use)
							return math.max(1.5, (use(tamanoTexto) :: number) * 0.12)
						end),
					}),
				},
			}),
		},
	})

	local sombra = nil
	if conSombra then
		sombra = scope:New("Frame")({
			Name = "Sombra",
			Size = UDim2.new(1, 0, 1, -desplazamiento),
			Position = UDim2.fromOffset(0, desplazamiento),
			BackgroundColor3 = Paleta.UI_SOMBRA,
			BackgroundTransparency = 0.55,
			ZIndex = 1,
			[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, radio) }),
		})
	end

	return scope:New("Frame")({
		Name = p.Nombre or "Boton",
		Size = p.Size or UDim2.fromOffset(140, 40),
		Position = p.Position,
		AnchorPoint = p.AnchorPoint,
		LayoutOrder = p.Orden,
		ZIndex = p.ZIndex,
		Visible = p.Visible,
		BackgroundTransparency = 1,
		[Children] = { sombra, cuerpo },
	})
end
