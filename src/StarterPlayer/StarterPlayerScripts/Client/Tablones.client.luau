--!strict
--[[
	Tablones
	Unica responsabilidad: pintar los tablones de ranking de la plaza. Cada
	pantalla horneada (tag PantallaRanking, atributo Ranking = id de
	Config/DefinicionesRankings) recibe aqui un SurfaceGui LOCAL en su cara
	Front con dos columnas: Historico y Esta semana. Cada columna lleva el
	top 10 (puesto, cara del avatar, nombre y valor) y al pie tu fila.

	Los puestos llegan del servidor (RankingsHandler: RankingsEvent cada
	pocos minutos, y al pedirlos al entrar). Tu valor no espera a la lectura:
	sale de tu perfil (DefinicionesRankings.valor), asi el pie se mueve en
	cuanto juegas; tu puesto si es el de la ultima lectura.

	Al ser local cada jugador lo ve en su idioma (Idioma.textos) y con su
	fila resaltada.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Utilidades = Shared:WaitForChild("Utilidades")
local Paleta = require(Config:WaitForChild("Paleta"))
local DefinicionesRankings = require(Config:WaitForChild("DefinicionesRankings"))
local Formato = require(Utilidades:WaitForChild("Formato"))
local Idioma = require(Utilidades:WaitForChild("Idioma"))
local Red = require(Utilidades:WaitForChild("Red"))
local Fusion = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Fusion"))

local Kit = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"))
local EstadoCliente = require(script.Parent:WaitForChild("EstadoCliente"))

local Children = Fusion.Children
local Textos = Idioma.textos

type Ranking = DefinicionesRankings.Ranking

local PIXELES_POR_STUD = 50
local MEDALLAS = { Paleta.UI_ORO, Paleta.UI_PLATA, Paleta.UI_BRONCE }

local miId = Players.LocalPlayer.UserId
local RankingsEvent = Red.evento("RankingsEvent")

-- La ultima lectura del servidor (Services/Rankings.Datos) o nil
local raiz = Fusion.scoped(Fusion)
local datos = raiz:Value(nil :: any)

RankingsEvent.OnClientEvent:Connect(function(d)
	if typeof(d) == "table" and typeof(d.listas) == "table" then
		datos:set(d)
	end
end)
RankingsEvent:FireServer()

local function formatear(def: Ranking, v: number): string
	return if def.formato == "dinero" then Formato.dinero(v) else Formato.miles(v)
end

-- Una fila del top: puesto (medalla en los tres primeros), cara, nombre y
-- valor. Vacia si ese puesto no existe todavia.
local function fila(scope: any, def: Ranking, periodo: string, i: number, altoPx: number)
	local entrada = scope:Computed(function(use)
		local d = use(datos)
		local lista = d and d.listas[def.id] and d.listas[def.id][periodo]
		return if lista then lista[i] else nil
	end)
	local hay = scope:Computed(function(use)
		return use(entrada) ~= nil
	end)
	local esMia = scope:Computed(function(use)
		local e = use(entrada)
		return e ~= nil and e.u == miId
	end)
	local tamCara = math.floor(altoPx * 0.82)
	return scope:New("Frame")({
		Name = "Fila" .. i,
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 1 / DefinicionesRankings.TOP, -3),
		BackgroundColor3 = scope:Computed(function(use)
			return if use(esMia) then Paleta.UI_PRIMARIO elseif i % 2 == 0 then Paleta.UI_PAPEL_OSCURO else Paleta.UI_PAPEL
		end),
		Visible = hay,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
			-- Puesto
			scope:New("Frame")({
				Name = "Puesto",
				Size = UDim2.new(0, tamCara, 0, tamCara),
				Position = UDim2.new(0, 4, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = MEDALLAS[i] or Paleta.UI_PAPEL,
				BackgroundTransparency = if MEDALLAS[i] then 0 else 1,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
					scope:Texto({
						Texto = tostring(i),
						Size = UDim2.fromScale(1, 0.8),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Fuente = "titulo",
						Alinear = Enum.TextXAlignment.Center,
						Escalar = true,
						Ajustar = false,
					}),
				},
			}),
			-- Cara del avatar (miniatura de Roblox por UserId, no un icono)
			scope:New("ImageLabel")({
				Name = "Cara",
				Size = UDim2.new(0, tamCara, 0, tamCara),
				Position = UDim2.new(0, 8 + tamCara, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Paleta.UI_PAPEL_SOMBRA,
				Image = scope:Computed(function(use)
					local e = use(entrada)
					return if e and e.u > 0 then string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", e.u) else ""
				end),
				[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			}),
			scope:Texto({
				Nombre = "Nombre",
				Texto = scope:Computed(function(use)
					local e = use(entrada)
					local d = use(datos)
					return if e and d then (d.nombres[tostring(e.u)] or "") else ""
				end),
				Size = UDim2.new(0.72, -(14 + 2 * tamCara), 0.8, 0),
				Position = UDim2.new(0, 12 + 2 * tamCara, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				Fuente = "negrita",
				Escalar = true,
				Ajustar = false,
			}),
			scope:Texto({
				Nombre = "Valor",
				Texto = scope:Computed(function(use)
					local e = use(entrada)
					return if e then formatear(def, e.v) else ""
				end),
				Size = UDim2.new(0.28, -8, 0.7, 0),
				Position = UDim2.new(1, -6, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Fuente = "titulo",
				Alinear = Enum.TextXAlignment.Right,
				Escalar = true,
				Ajustar = false,
			}),
		},
	})
end

-- Una columna: cabecera (Historico / Esta semana), el top y tu fila al pie
local function columna(scope: any, def: Ranking, periodo: string, x: number, altoPx: number)
	local lista = scope:Computed(function(use)
		local d = use(datos)
		return d and d.listas[def.id] and d.listas[def.id][periodo]
	end)
	local aviso = scope:Computed(function(use)
		local d = use(datos)
		local l = use(lista)
		if not d then
			return Textos.RANKING.cargando
		elseif l and #l > 0 then
			return ""
		elseif not d.disponible then
			return Textos.RANKING.noDisponible
		end
		return Textos.RANKING.vacio
	end)
	local miValor = scope:Computed(function(use)
		return DefinicionesRankings.valor(use(EstadoCliente.reactivo.perfil), def, periodo, os.time())
	end)
	local miPuesto = scope:Computed(function(use)
		for i, e in use(lista) or {} do
			if e.u == miId then
				return i
			end
		end
		return 0
	end)
	local filas = {}
	for i = 1, DefinicionesRankings.TOP do
		table.insert(filas, fila(scope, def, periodo, i, altoPx * 0.06))
	end
	return scope:New("Frame")({
		Name = "Columna_" .. periodo,
		Size = UDim2.fromScale(0.485, 0.83),
		Position = UDim2.fromScale(x, 0.155),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Cabecera",
				Size = UDim2.fromScale(1, 0.085),
				BackgroundColor3 = Paleta.UI_PAPEL,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
					scope:Texto({
						Texto = if periodo == "historico" then Textos.RANKING.historico else Textos.RANKING.semanal,
						Size = UDim2.fromScale(0.9, 0.75),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Fuente = "titulo",
						Alinear = Enum.TextXAlignment.Center,
						Escalar = true,
						Ajustar = false,
						Mayusculas = true,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Filas",
				Size = UDim2.fromScale(1, 0.79),
				Position = UDim2.fromScale(0, 0.1),
				BackgroundTransparency = 1,
				[Children] = {
					scope:New("UIListLayout")({
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 3),
					}),
					filas,
				},
			}),
			scope:Texto({
				Nombre = "Aviso",
				Texto = aviso,
				Visible = scope:Computed(function(use)
					return use(aviso) ~= ""
				end),
				Size = UDim2.fromScale(0.9, 0.08),
				Position = UDim2.fromScale(0.5, 0.3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = Paleta.UI_PAPEL,
				Fuente = "titulo",
				Alinear = Enum.TextXAlignment.Center,
				Escalar = true,
				Ajustar = false,
			}),
			scope:New("Frame")({
				Name = "Tu",
				Size = UDim2.fromScale(1, 0.09),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Paleta.UI_PRIMARIO,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
					scope:Texto({
						Texto = scope:Computed(function(use)
							local v = use(miValor)
							local puesto = use(miPuesto)
							if v <= 0 then
								return Textos.RANKING.tuSinValor
							elseif puesto > 0 then
								return Textos.formatear(Textos.RANKING.tu, { pos = puesto, valor = formatear(def, v) })
							end
							return Textos.formatear(Textos.RANKING.tuFuera, { n = DefinicionesRankings.LEER, valor = formatear(def, v) })
						end),
						Size = UDim2.fromScale(0.94, 0.72),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Fuente = "titulo",
						Alinear = Enum.TextXAlignment.Center,
						Escalar = true,
						Ajustar = false,
					}),
				},
			}),
		},
	})
end

local montados: { [Instance]: any } = {}

local function montar(pantalla: Instance)
	if montados[pantalla] or not pantalla:IsA("BasePart") then
		return
	end
	local def = DefinicionesRankings.POR_ID[pantalla:GetAttribute("Ranking") :: any]
	if not def then
		return
	end
	local scope = Fusion.scoped(Fusion, Kit)
	montados[pantalla] = scope
	local anchoPx = pantalla.Size.X * PIXELES_POR_STUD
	local altoPx = pantalla.Size.Y * PIXELES_POR_STUD
	local tamIcono = math.floor(altoPx * 0.09)
	scope:New("SurfaceGui")({
		Name = "TablonRanking",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELES_POR_STUD,
		LightInfluence = 0,
		MaxDistance = 160,
		AutoLocalize = false,
		Parent = pantalla,
		[Children] = scope:New("Frame")({
			Name = "Fondo",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Paleta.UI_TINTA,
			[Children] = {
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, anchoPx * 0.025),
					PaddingRight = UDim.new(0, anchoPx * 0.025),
					PaddingTop = UDim.new(0, altoPx * 0.02),
					PaddingBottom = UDim.new(0, altoPx * 0.02),
				}),
				scope:New("Frame")({
					Name = "Titulo",
					Size = UDim2.fromScale(1, 0.13),
					BackgroundColor3 = def.color,
					[Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0.25, 0) }),
						scope:New("UIStroke")({ Color = Paleta.UI_PAPEL, Thickness = 3 }),
						scope:Icono({
							Clave = def.icono,
							Tamano = tamIcono,
							Position = UDim2.new(0, 10, 0.5, 0),
							AnchorPoint = Vector2.new(0, 0.5),
						}),
						scope:Texto({
							Texto = (Textos.RANKING.titulo :: any)[def.id] or def.id,
							Size = UDim2.new(1, -(tamIcono + 30), 0.72, 0),
							Position = UDim2.new(0, tamIcono + 20, 0.5, 0),
							AnchorPoint = Vector2.new(0, 0.5),
							Color = Paleta.UI_PAPEL,
							Contorno = Paleta.UI_TINTA,
							Fuente = "titulo",
							Alinear = Enum.TextXAlignment.Center,
							Escalar = true,
							Ajustar = false,
							Mayusculas = true,
						}),
					},
				}),
				columna(scope, def, "historico", 0, altoPx),
				columna(scope, def, "semanal", 0.515, altoPx),
			},
		}),
	})
end

local function desmontar(pantalla: Instance)
	local scope = montados[pantalla]
	if scope then
		montados[pantalla] = nil
		Fusion.doCleanup(scope)
	end
end

for _, pantalla in CollectionService:GetTagged("PantallaRanking") do
	task.spawn(montar, pantalla)
end
CollectionService:GetInstanceAddedSignal("PantallaRanking"):Connect(montar)
CollectionService:GetInstanceRemovedSignal("PantallaRanking"):Connect(desmontar)
