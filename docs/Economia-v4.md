# Economía v4 — Recíclatas

> **22 oct 2026 · APROBADA por el usuario**, con estas respuestas a las preguntas abiertas (§ final), que mandan sobre el resto del documento:
> - **Turbo**: solo corre mientras se juega (se pausa al salir y tras 2 min sin actividad; tope de 3 h acumuladas).
> - **VIP**: 249 Robux, con corona, Estela VIP y un 4.º pedido diario.
> - **Tramo R3+**: se lanza tal cual y se mide; no se cambia aún la curva de las mejoras.
> - **Cambio de día** (pedidos, calendario y regalos): a las **06:00 UTC**, no a las 00:00.
>
> Hasta que se implemente, mandan los números de `src/ReplicatedStorage/Shared/Config`. Sustituye a la calibración de `CONTEXTO.md` §4 y responde a la auditoría del 22 oct (R1 ≈ 3 h, R5 ≈ 66 h, pedidos ≈ 1 % del R1, nada que abrir tras el R3, sin recompensas de regreso). Respeta la regla v2: no se vende dinero, ni saltos de rebirth, ni automatización, ni nada aleatorio, y no vuelve nada de lo quitado (mascotas, trajes, energía, gemas, venta, base…). Quedan fuera, por decisión del usuario, lo social (amigos, grupo) y los códigos.

## Resumen

| # | Qué | Hoy | Propuesta |
|---|---|---|---|
| 1 | Curva de las mejoras | coste base × 1,6^nivel → **$118.030** las 4 al máximo (76 % en los 3 últimos niveles) | mismos costes base × **1,35**^nivel → **$35.485** (62 %) |
| 2 | Requisito en mano R1…R5 | 50k / 200k / 800k / 3,2M / 12,8M | **15k / 100k / 250k / 500k / 800k** (tabla hasta el R10) |
| 3 | Multiplicador R1…R5 | x1,5 / 2 / 2,5 / 3 / 3,5 | **x1,5 / 2 / 3 / 4 / 5** (+1 por rebirth después) |
| 4 | Jugador medio, jugando seguido | R1 3 h · R5 66 h | **R1 58 min · R5 7 h 26 min** |
| 5 | Pedidos | $250 / 500 / 900 × multiplicador | **1,5 / 2 / 3 % del coste del siguiente rebirth** ($760 / 1.000 / 1.500 con 0 rebirths) |
| 6 | Calendario | — | 7 casillas; **saltarse un día no reinicia nada** |
| 7 | Regalos | — | por **minutos activos del día** (5 … 60 min) |
| 8 | Bono de regreso | — | ≥ 3 días sin jugar: Turbo 15 min + 4 %; ≥ 14 días: Turbo 30 min + 8 % |
| 9 | Turbo | corre en tiempo real | **solo corre mientras juegas** |
| 10 | Catálogo | 4 pases + Turbo 15 | + **VIP 249**, **Pack de inicio 99** (compra única), **Turbo 60 149** |
| 11 | R4 y R5 | "Solo multiplicador e insignia" (la insignia no existe) | **Bolsa de hielo** / **Estela de fuego + insignia** |
| 12 | Ofertas | — | 5 disparadores; nunca en la 1.ª sesión; 1 por sesión, 3 por semana |

---

## 1. Modelo

### 1.1 Qué mide y qué supone

Mide **minutos de juego** (dentro de sesiones) hasta cada rebirth. La tabla principal (§2.5) va **sin pases y sin recompensas**; las variantes con recompensas y con pases están en §2.6. Distancias en studs, tiempos en segundos, dinero en $.

Supuestos comunes:

- Las 4 mejoras suben a la par (se compra siempre la más barata): el **nivel L = 0…10** es el de las cuatro.
- El 60 % de las piezas sale de montones grandes (son 360 de las 600 piezas del patio), el resto de chicos.
- Una bolsa fallada se recoge y **se entrega a mano**: paga sin bonus y la racha vuelve a 0.
- La competencia en el patio, los menús y las pausas cortas no se modelan aparte: van en **η** (fracción de la sesión que se pasa en el bucle).
- Cada tramo de mejoras (las 4 de L a L+1) se paga con el ingreso del nivel L. Sobreestima un poco, pero la calibración (§1.4) se hizo igual y se compensa.

### 1.2 Fórmulas

**(1) Valor medio de una pieza de basura** con los tipos que abre cada rebirth (`MEZCLA.patio` 40/35/15/10, `VALOR_MATERIAL` 5/7/15/25, `MATERIAL_REBIRTH`):

```
v(r) = Σ peso·valor / Σ peso   (solo materiales abiertos)
v(0) = 5,933   (papel y plástico)      ρ(0) = 1
v(1) = 7,444   (+ metal)               ρ(1) = v(1)/v(0) = 1,2547
v(2+) = 9,200  (+ orgánico)            ρ(2+) = 1,5506
```

**(2) Factor por pieza** (qué es la pieza y en qué contenedor entra):

```
f_billete = 0,05            (vale 6 piezas)
f_tesoro  = 0,01 + 0,6·0,0091 = 0,0155   (vale 40; el tesoro seguro del grande añade
                                          P(ninguno en 60) / 60 = 0,99^60 / 60 = 0,0091
                                          por pieza de grande)
f_basura  = 1 − 0,05 − 0,0155 = 0,9345
S = (1 − s) + s·(2p + 0,5·(1 − p))       s = bolsas bien separadas, p = su pureza
K = 0,9345·S + 0,05·6 + 0,0155·40 = 0,9345·S + 0,919
```

**(3) Multiplicador medio del lanzamiento** (`DefinicionesPunteria`):

```
B(L) = 25 + 4,5·L                       alcance del Brazo
d(L) = k_d·B(L)                         distancia a la que tira el perfil
b_d  = BONUS_DISTANCIA en d(L)          (+20 % desde 10 … +150 % desde 60)
b_r  = 0,1·(1 + h + h² + h³ + h⁴)       racha media con acierto h (tope 5)
T(L) = 1 + h·(b_d + b_r)
```

**(4) Pago de una bolsa**

```
$(L) = N(L) · v(r) · K · T(L) · M(r)   [·2 Dinero x2] [·2 Turbo]
N(L) = 10 + 3·L                         (+10 con Bolsa XL)
```

**(5) Tiempo de un ciclo recoger → lanzar**

```
t(L) = N(L)·[ t_p0·√(6/A(L))·(1 + c_s·s) + t_m ]      recoger
     + 2·máx(D − d(L), 10) / V(L)                      andar ida y vuelta
     + t_l                                             cargar y lanzar
     + (1 − h)·(3 + 2·d(L)/V(L))                       ir a por la bolsa fallada y entregarla
A(L) = 6 + L (Alcance)      V(L) = 16 + 1,2·L (Velocidad)
```

**(6) Ingreso real:** `I(L) = η · 60 · $(L) / t(L)` en $/min.

**(7) Tiempo de un rebirth** (de n a n + 1 rebirths). El tiempo de un ciclo no depende del material ni del multiplicador, así que todo el ingreso con n rebirths es el de 0 rebirths por `M(n)·ρ(n)`:

```
T(n) = [ Σ_{L=0..9} C(L) / I₀(L)  +  Requisito(n+1) / I₀(10) ] / ( M(n)·ρ(n) )
C(L) = Σ costeBase · f^L = 650 · f^L           (las 4 mejoras de L a L+1)
```

Para reproducirlo en una hoja de cálculo: una fila por nivel L con N, A, V, B, d, b_d, T, $(L), t(L) e I(L) (columnas de §1.5); después C(L)/I(L) y la suma.

### 1.3 Los tres perfiles

| Parámetro | Eficiente (PC) | Medio (PC) | Casual / móvil |
|---|---|---|---|
| h — acierto | 0,75 | 0,65 | 0,50 |
| k_d — fracción del Brazo a la que tira | 0,86 | 0,75 | 0,65 |
| s — bolsas bien separadas | 40 % | 25 % | 10 % |
| p — pureza de una bolsa separada | 0,95 | 0,90 | 0,85 |
| t_p0 — s por pieza con Alcance 6 | 0,65 | 0,80 | 0,90 |
| c_s — sobrecoste de recoger un solo color | +25 % | +30 % | +40 % |
| t_m — s por pieza de ir al montón y excavar | 0,15 | 0,18 | 0,20 |
| D — montón → contenedor (studs) | 85 | 90 | 95 |
| t_l — s por lanzamiento | 2,0 | 2,5 | 3,0 |
| η — fracción de la sesión en el bucle | 0,75 | 0,75 | 0,75 |
| **Resultado:** viaje medio ida y vuelta | 88 studs | **109 studs** | 128 studs |
| **Resultado:** K | 2,199 | 2,052 | 1,926 |
| **Resultado:** T en L0 → L10 | 1,53 → 2,35 | 1,29 → 1,81 | 1,20 → 1,60 |

El medio es el de la auditoría (viaje ~110 studs, 65 % de acierto, 25 % de bolsas separadas). η es el único parámetro ajustado: con 0,75 los tres perfiles dan los tiempos de la auditoría (siguiente apartado). Medir η y t_p0 es lo primero del L10 (§7).

### 1.4 Calibración: con los números de hoy, el modelo reproduce la auditoría

| Perfil | R1 | R2 | R3 | R4 | R5 | Auditoría del 22 oct |
|---|---|---|---|---|---|---|
| Eficiente | 1:57 | 3:42 | 6:27 | 14:05 | 38:33 | R1 2 h |
| **Medio** | **2:58** | **5:44** | **10:19** | **23:17** | **65:05** | **3 / 6 / 10 / 24 / 66 h** |
| Casual / móvil | 4:13 | 8:07 | 14:27 | 32:17 | 89:38 | R1 4 h |

(horas:minutos acumulados). La primera bolsa sale a **$97** (10 piezas de papel y plástico, al general, sin bonus), como en la auditoría.

### 1.5 El jugador medio, nivel a nivel (0 rebirths, sin pases)

| L | N bolsa | Alcance | Velocidad | Brazo | Tira desde | Bonus distancia | T | $ por bolsa | s por ciclo | **$/min real** |
|---|---|---|---|---|---|---|---|---|---|---|
| 0 | 10 | 6 | 16 | 25 | 18,8 | +20 % | 1,294 | 158 | 23,7 | **299** |
| 1 | 13 | 7 | 17,2 | 29,5 | 22,1 | +40 % | 1,424 | 225 | 25,0 | **405** |
| 2 | 16 | 8 | 18,4 | 34 | 25,5 | +40 % | 1,424 | 277 | 26,3 | **474** |
| 3 | 19 | 9 | 19,6 | 38,5 | 28,9 | +40 % | 1,424 | 329 | 27,6 | **538** |
| 4 | 22 | 10 | 20,8 | 43 | 32,3 | +70 % | 1,619 | 434 | 28,8 | **677** |
| 5 | 25 | 11 | 22 | 47,5 | 35,6 | +70 % | 1,619 | 493 | 30,0 | **739** |
| 6 | 28 | 12 | 23,2 | 52 | 39,0 | +70 % | 1,619 | 552 | 31,2 | **796** |
| 7 | 31 | 13 | 24,4 | 56,5 | 42,4 | +70 % | 1,619 | 611 | 32,4 | **850** |
| 8 | 34 | 14 | 25,6 | 61 | 45,8 | +100 % | 1,814 | 751 | 33,5 | **1.008** |
| 9 | 37 | 15 | 26,8 | 65,5 | 49,1 | +100 % | 1,814 | 817 | 34,7 | **1.061** |
| 10 | 40 | 16 | 28 | 70 | 52,5 | +100 % | 1,814 | 883 | 35,8 | **1.110** |

Desglose del ciclo: en L0, recoger 10,4 s + andar 8,9 + lanzar 2,5 + fallos 1,9 = 23,7 s; en L10, 28,3 + 2,7 + 2,5 + 2,4 = 35,8 s. Con la bolsa grande, recoger es casi todo el ciclo: por eso Alcance, Brazo y Velocidad mueven el ingreso más que Bolsa al final.

**Ingreso real por nivel de los tres perfiles** ($/min con 0 rebirths; con n rebirths, × M(n)·ρ(n)):

| L | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Eficiente | 449 | 556 | 656 | 857 | 954 | 1.045 | 1.129 | 1.362 | 1.445 | 1.523 | 1.899 |
| Medio | 299 | 405 | 474 | 538 | 677 | 739 | 796 | 850 | 1.008 | 1.061 | 1.110 |
| Casual | 230 | 283 | 358 | 406 | 449 | 547 | 589 | 629 | 666 | 700 | 809 |

### 1.6 Pases y Turbo en el modelo

- **Dinero x2** y **Turbo** multiplican el pago: con Dinero x2 todos los tiempos se dividen entre 2; un Turbo de N minutos ahorra hasta N minutos de juego.
- **Bolsa XL** suma 10 huecos: +39 % de ingreso con la bolsa a nivel 0, +4 % a nivel 10 (con la bolsa grande, recoger domina el ciclo).
- Los premios en dinero (pedidos, calendario, regalos, regreso) **no** se multiplican por pases ni Turbo: así nadie paga por recibir más dinero gratis.

---

## 2. Números nuevos (para copiar a Config)

### 2.1 Mejoras

Solo cambia el factor: **`GameConfig.FACTOR_COSTE_MEJORA` = 1.35** (era 1.6). Los costes base (`DefinicionesMejoras.LISTA[*].costeBase` = 150 / 120 / 200 / 180), los valores (`base`, `porNivel`) y la fórmula de `DefinicionesMejoras.coste` no cambian.

| Compra | Bolsa | Alcance | Velocidad | Brazo | Las 4 |
|---|---|---|---|---|---|
| nivel 1 | 150 | 120 | 200 | 180 | 650 |
| 2 | 203 | 162 | 270 | 243 | 878 |
| 3 | 273 | 219 | 365 | 328 | 1.185 |
| 4 | 369 | 295 | 492 | 443 | 1.599 |
| 5 | 498 | 399 | 664 | 598 | 2.159 |
| 6 | 673 | 538 | 897 | 807 | 2.915 |
| 7 | 908 | 726 | 1.211 | 1.090 | 3.935 |
| 8 | 1.226 | 981 | 1.634 | 1.471 | 5.312 |
| 9 | 1.655 | 1.324 | 2.206 | 1.986 | 7.171 |
| 10 | 2.234 | 1.787 | 2.979 | 2.681 | 9.681 |
| **Total** | 8.189 | 6.551 | 10.918 | 9.827 | **35.485** |

Ritmo para el medio en el R0: las 4 primeras compras salen cada ~33 s (la primera, $120, con la primera bolsa); las 4 últimas, cada ~2,3 min. Media: una compra por minuto. Los 3 últimos tramos son el 51 % del tiempo de mejoras (antes, la mayoría).

### 2.2 Rebirths R1…R10

```lua
-- Config/DefinicionesRebirths.luau
DefinicionesRebirths.TABLA = {
	{ requisito = 15000, multiplicador = 1.5, desbloquea = "metal" },
	{ requisito = 100000, multiplicador = 2, desbloquea = "organico" },
	{ requisito = 250000, multiplicador = 3, desbloquea = "bolsaPlateada" },
	{ requisito = 500000, multiplicador = 4, desbloquea = "bolsaHielo" },
	{ requisito = 800000, multiplicador = 5, desbloquea = "estelaFuego" },
	{ requisito = 1200000, multiplicador = 6, desbloquea = "multiplicador" },
	{ requisito = 1800000, multiplicador = 7, desbloquea = "multiplicador" },
	{ requisito = 2500000, multiplicador = 8, desbloquea = "multiplicador" },
	{ requisito = 3500000, multiplicador = 9, desbloquea = "multiplicador" },
	{ requisito = 5000000, multiplicador = 10, desbloquea = "leyenda" },
}
-- Desde el 11: requisito x1,4 (redondeado a 2 cifras significativas) y +1 de multiplicador
DefinicionesRebirths.FACTOR_REQUISITO = 1.4 -- era 4
DefinicionesRebirths.PASO_MULTIPLICADOR = 1 -- era 0.5
```

| Rebirth | Requisito en mano | Coste del tramo (mejoras + requisito) | Multiplicador después | Abre | Tramo medio | Acumulado medio |
|---|---|---|---|---|---|---|
| 1 | $15.000 | $50.485 | x1,5 | basura de metal | 58 min | 0:58 |
| 2 | $100.000 | $135.485 | x2 | basura orgánica | 71 min | 2:09 |
| 3 | $250.000 | $285.485 | x3 | Bolsa plateada | 87 min | 3:36 |
| 4 | $500.000 | $535.485 | x4 | Bolsa de hielo | 106 min | 5:23 |
| 5 | $800.000 | $835.485 | x5 | Estela de fuego + insignia | 123 min | 7:26 |
| 6 | $1.200.000 | $1.235.485 | x6 | — | 145 min | 9:51 |
| 7 | $1.800.000 | $1.835.485 | x7 | — | 179 min | 12:50 |
| 8 | $2.500.000 | $2.535.485 | x8 | — | 212 min | 16:22 |
| 9 | $3.500.000 | $3.535.485 | x9 | — | 258 min | 20:40 |
| 10 | $5.000.000 | $5.035.485 | x10 | insignia Leyenda | 326 min | 26:06 |
| 11+ | ×1,4 | | +1 | — | ×1,26 cada uno | |

Por qué así:

- **Multiplicadores más gordos desde el R3** (x3, x4, x5 en vez de x2,5, x3, x3,5): con +0,5 cada salto valía +17–20 % y renacer dejaba de notarse. Ahora el R3 es +50 % y el R5 +25 %. Con números redondos el panel se lee mejor ("x4").
- **Requisitos para que cada rebirth dure un 16–26 % más que el anterior** (58 → 71 → 87 → 106 → 123 min) y el R5 llegue antes de ~10 h incluso para el casual.
- Los costes de las mejoras **no** crecen con los rebirths: tras renacer, recomprarlas va cada vez más rápido (23,6 min tras el R1, 7,2 tras el R4). Es la sensación de "ahora soy más fuerte". El precio: desde el R3, casi todo el tramo se juega con todo al máximo ahorrando (riesgo y pregunta en §7 y §8).

### 2.3 Valores por material: no cambian

`VALOR_MATERIAL` (5/7/15/25), `MULT_BILLETE` (6), `MULT_TESORO` (40), `MULT_SEPARADO` (2), `MULT_MAL_SEPARADO` (0,5), `TablasProbabilidad` y `DefinicionesPunteria` se quedan igual. El precio de la bolsa es lo que el jugador aprende en el tutorial (~$97–126 la primera) y el metal (+25 % de valor medio) y el orgánico (+24 %) son lo que se nota al abrir el R1 y el R2. Para acortar los tiempos bastaba con abaratar lo que se compra.

### 2.4 Pedidos: un porcentaje del siguiente rebirth

```lua
-- Config/DefinicionesPedidos.luau (sustituye a RECOMPENSA)
DefinicionesPedidos.PORCENTAJE = { facil = 0.015, medio = 0.02, dificil = 0.03 }
DefinicionesPedidos.POR_DIA = 3
DefinicionesPedidos.POR_DIA_VIP = 4 -- el 4.º es el "Pedido VIP" y paga como difícil
DefinicionesPedidos.MINUTOS_TURBO = 10 -- sin cambios: completar los 3 normales

function DefinicionesPedidos.recompensa(dificultad: string, rebirths: number): number
	local base = DefinicionesRebirths.costeSiguiente(rebirths)
	return DefinicionesRebirths.redondear(DefinicionesPedidos.PORCENTAJE[dificultad] * base)
end

-- Config/DefinicionesRebirths.luau (nuevas). Viven aqui y no en
-- DefinicionesRecompensas para que no haya un require circular: Pedidos y
-- Recompensas dependen de Rebirths, nunca al reves.
-- Lo que cuesta el siguiente rebirth: las 4 mejoras + su requisito
function DefinicionesRebirths.costeSiguiente(rebirths: number): number
	return DefinicionesRebirths.rebirth(rebirths + 1).requisito + DefinicionesMejoras.costeTotal()
end

-- Dos cifras significativas (1.009,7 -> 1.000; 757,3 -> 760); por debajo de 100, a la unidad.
-- Lo usan los premios y los requisitos desde el 11.
function DefinicionesRebirths.redondear(n: number): number
	if n < 100 then
		return math.floor(n + 0.5)
	end
	local paso = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / paso + 0.5) * paso
end
```

- Se calcula **al cobrar** y el panel la enseña en vivo (misma función pura de Config en servidor y cliente). Si el jugador renace a media tarde, sus pedidos pendientes pasan a valer lo del rebirth nuevo. El campo `recompensa` guardado en cada pedido deja de usarse.
- No se multiplica por pases ni Turbo (`Economia.ganar` directo, como hoy).
- Los tres del día suman ~6,5 % del siguiente rebirth (antes, ~1 % del R1).

| Rebirths hechos | Coste del siguiente | Fácil 1,5 % | Medio 2 % | Difícil 3 % |
|---|---|---|---|---|
| 0 | $50.485 | $760 | $1.000 | $1.500 |
| 1 | $135.485 | $2.000 | $2.700 | $4.100 |
| 2 | $285.485 | $4.300 | $5.700 | $8.600 |
| 3 | $535.485 | $8.000 | $11.000 | $16.000 |
| 4 | $835.485 | $13.000 | $17.000 | $25.000 |

### 2.5 Tiempos resultantes (sin pases ni recompensas)

| Perfil | R1 | R2 | R3 | R4 | R5 | R10 |
|---|---|---|---|---|---|---|
| Eficiente (PC) | **0:38** | 1:23 | 2:15 | 3:18 | **4:31** | 15:27 |
| **Medio (PC)** | **0:58** | **2:09** | **3:36** | **5:23** | **7:26** | 26:06 |
| Casual / móvil | **1:22** | 3:01 | 5:01 | 7:27 | **10:17** | 35:53 |

Duración de cada rebirth (min):

| | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 |
|---|---|---|---|---|---|---|---|---|---|---|
| Eficiente | 38 | 44 | 52 | 63 | 73 | 85 | 105 | 124 | 151 | 191 |
| Medio | 58 | 71 | 87 | 106 | 123 | 145 | 179 | 212 | 258 | 326 |
| Casual | 82 | 99 | 120 | 146 | 170 | 199 | 246 | 290 | 354 | 447 |

Cómo se reparte el R1 del medio, en sesiones de 20 min: la 1.ª acaba hacia el nivel 6, la 2.ª hacia el 9, y en la 3.ª ahorra los $15.000 y renace.

| R0 → R1 (minutos) | Eficiente | Medio | Casual |
|---|---|---|---|
| Comprar las 40 mejoras | 30,5 | 44,4 | 63,0 |
| Ahorrar $15.000 | 7,9 | 13,5 | 18,5 |
| **R1** | **38,4** | **57,9** | **81,6** |

Recomprar las mejoras frente a ahorrar el requisito (medio, minutos):

| Tramo | Recomprar | Ahorrar | Total |
|---|---|---|---|
| R1 → R2 | 23,6 | 47,9 | 71,5 |
| R2 → R3 | 14,3 | 72,6 | 86,9 |
| R3 → R4 | 9,5 | 96,8 | 106,4 |
| R4 → R5 | 7,2 | 116,2 | 123,4 |

### 2.6 Con recompensas y con pases

**Medio que juega 20 min al día y cobra todo** (pedidos 4 de cada 5 días, 2 el primero; calendario; regalos de 5, 10 y 20 min; Turbo guardado entre sesiones). El R1 se calcula día a día; desde el R2, en régimen estable: `días por rebirth = 1 / ((20 + τ)/T(n) + e)`, con τ = 11,6 min de Turbo gratis al día y e = 9 % del coste del siguiente rebirth al día.

| | R1 | R2 | R3 | R4 | R5 |
|---|---|---|---|---|---|
| Minutos jugados (acumulados) | ~0:42 | ~1:20 | ~2:04 | ~2:55 | ~3:53 |
| Día en que llega | 3 (al empezar la 3.ª sesión) | 5 | 7 | 10 | 13 |

El R1 jugando seguido (58 min) cae dentro del objetivo de 45–60 min. Quien vuelve cada día llega antes (~42 min; con sesiones de 15 min, ~50; con sesiones de 25, ~38): volver se premia a propósito. Con todo, los rebirths siguen alargándose de uno a otro (desde el R2: 38 → 44 → 52 → 58 min por rebirth).

**Medio con pases**, sin recompensas:

| | R1 | R5 |
|---|---|---|
| Sin pases | 0:58 | 7:26 |
| Bolsa XL | 0:53 | 7:02 |
| Dinero x2 | 0:29 | 3:43 |
| Dinero x2 + Bolsa XL | 0:27 | 3:31 |

### 2.7 Qué cambia en cada archivo

| Archivo | Campo | Hoy | Propuesta |
|---|---|---|---|
| `Config/GameConfig.luau` | `FACTOR_COSTE_MEJORA` | 1.6 | **1.35** |
| ″ | nuevos `TURBO_PAUSA_INACTIVO` / `TURBO_TOPE_COMPRA` | — | 120 s / 10800 s (3 h) |
| `Config/DefinicionesMejoras.luau` | `LISTA`, `coste`, `valor` | | sin cambios (la cabecera cita $118.030: pasa a $35.485) |
| `Config/DefinicionesRebirths.luau` | `TABLA` | 5 filas | 10 filas (§2.2) |
| ″ | `FACTOR_REQUISITO` / `PASO_MULTIPLICADOR` | 4 / 0.5 | **1.4 / 1** |
| ″ | `rebirth(n)` con n > 10 | sin redondeo, `desbloquea = "insignia"` | redondeo a 2 cifras, `desbloquea = "multiplicador"` |
| ″ | nuevas `costeSiguiente(rebirths)` y `redondear(n)` | — | requisito(n + 1) + `DefinicionesMejoras.costeTotal()`; 2 cifras significativas |
| `Config/DefinicionesPedidos.luau` | `RECOMPENSA` | {250, 500, 900} × multiplicador | `PORCENTAJE` {0.015, 0.02, 0.03} + `recompensa(dificultad, rebirths)` |
| ″ | nuevo `POR_DIA_VIP` | — | 4 |
| `Config/Productos.luau` | `PASES` | 4 | + `VIP` (249), `PackInicio` (99) |
| ″ | `PRODUCTOS` | `Turbo15` | + `Turbo60` (149); descripciones "minutos de juego" |
| `Config/DefinicionesCosmeticos.luau` | `BOLSAS` / `ESTELAS` | 2 / 1 | + 3 / + 2; forma nueva `insignia`; `loTiene` mira `perfil.logros` |
| `Config/DefinicionesInsignias.luau` | `LISTA` | 16 | 20 |
| `Config/DefinicionesRecompensas.luau` | **nuevo** | — | `CALENDARIO`, `REGALOS`, `REGRESO`, `ACCIONES_MINUTO_ACTIVO` = 3, `PASO_DESBLOQUEO` = "mejora" (§4) |
| `Config/DefinicionesOfertas.luau` | **nuevo** | — | reglas y disparadores (§5.6) |
| `Config/Textos.luau` + `Traducciones/en`, `pt` | secciones `RECOMPENSAS`, `OFERTAS` y claves sueltas | | §6; se quita `REBIRTH.desbloquea.insignia` de los tres |
| `Services/Perfiles.luau` | `porDefecto` | `turboHasta` | + `turboRestante`, `recompensas`, `ofertas`; `turboHasta` se migra y pasa a `OBSOLETOS` |
| `Services/Turbo.luau` | reloj | `os.time` | segundos restantes que solo bajan jugando (§4.6) |

`Perfiles.completar` solo rellena por clave dentro de `mejoras`: si más adelante se añaden claves dentro de `recompensas` u `ofertas`, hay que completarlas igual.

**Pruebas que cambian:** `mejorasV2` (esperado Bolsa {10, 40, 150, 2234}, Alcance {6, 16, 120, 1787}, Velocidad {16, 28, 200, 2979}, Brazo {25, 70, 180, 2681}, total 35485; los ,5 exactos pueden bailar 1 por coma flotante, comprobarlo en Studio), `rebirthTabla` (requisitos "15000,100000,250000,500000,800000,1200000,1800000", multiplicadores "1.5,2,3,4,5,6,7"), `pedidosDia` y `pedidoSeparadas` (premios de la tabla de §2.4), `premioTurbo`, `turboAcumula` y `paseDineroX2` (usan `turboHasta`), `perfilV3` (claves nuevas), `insignias` (20), `cosmeticoBolsa` (forma `insignia`) e `idioma`. **Pruebas nuevas:** `costeSiguiente`, `turboPausa`, `calendario`, `regalosActivos`, `bonoRegreso`, `paseVip`, `packInicio`, `ofertasReglas`.

---

## 3. Qué abren R4 y R5 (y del R6 al R10)

Solo con lo que ya existe (diseños de bolsa, estelas, insignias); ningún sistema nuevo.

| Rebirth | Abre | Clave de `Textos.REBIRTH.desbloquea` |
|---|---|---|
| 1–3 | sin cambios: metal, orgánico, Bolsa plateada | `metal`, `organico`, `bolsaPlateada` |
| **4** | x4 y la **Bolsa de hielo** (diseño de bolsa, gratis) | `bolsaHielo` |
| **5** | x5, la **Estela de fuego** (gratis) y la insignia **Reciclador de élite** | `estelaFuego` |
| 6–9 | solo multiplicador; el panel lo dice tal cual | `multiplicador` |
| **10** | x10 y la insignia **Leyenda del reciclaje** | `leyenda` |

Se quita `desbloquea.insignia` ("Solo multiplicador e insignia"): prometía unas insignias que no existían. **Insignias nuevas** (4; Roblox deja crear 5 gratis cada 24 h por experiencia y cobra 100 Robux por cada una más. Con las 16 que siguen pendientes son 20: cuatro días de 5, o pagar las que pasen):

| id | Nombre | Condición | Icono |
|---|---|---|---|
| `rebirth5` | Reciclador de élite | `rebirthMaximo` ≥ 5 | `estrella` |
| `rebirth10` | Leyenda del reciclaje | `rebirthMaximo` ≥ 10 | `trofeo` |
| `semanaCompleta` | Constante | `diasCalendario` ≥ 7 (estadística nueva: casillas cobradas) | `check` |
| `pedidos30` | Cumplidor | `pedidosCompletados` ≥ 30 | `libreta` |

---

## 4. Recompensas

### 4.1 Base común

Todo premio en dinero es un **porcentaje del coste del siguiente rebirth** (`DefinicionesRebirths.costeSiguiente`), redondeado a 2 cifras significativas (`DefinicionesRebirths.redondear`, §2.4: 1.009,7 → 1.000; 757,3 → 760; por debajo de 100, a la unidad). Así un premio vale lo mismo, en proporción, con 0 rebirths que con 9, y no hace falta retocarlo al cambiar la curva. Los días son UTC, como los pedidos (ver pregunta 4).

| Porcentaje | 0 rebirths | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| 0,5 % | $250 | $680 | $1.400 | $2.700 | $4.200 |
| 1 % | $500 | $1.400 | $2.900 | $5.400 | $8.400 |
| 2 % | $1.000 | $2.700 | $5.700 | $11.000 | $17.000 |
| 3 % | $1.500 | $4.100 | $8.600 | $16.000 | $25.000 |
| 4 % | $2.000 | $5.400 | $11.000 | $21.000 | $33.000 |
| 8 % | $4.000 | $11.000 | $23.000 | $43.000 | $67.000 |

### 4.2 Calendario de 7 casillas

Una casilla por **día jugado**; se cobra con un botón en la pestaña Recompensas (el panel enseña las 7 y la siguiente, para que apetezca volver).

| Casilla | Premio | Por qué |
|---|---|---|
| 1 | 2 % ($1.000 con 0 rebirths) | llega con la primera mejora (paso 5): da para 4–5 mejoras de golpe y enseña la pestaña |
| 2 | 2 % | |
| 3 | Turbo 10 min | prueba del Turbo, el mismo que se vende |
| 4 | 3 % | |
| 5 | 3 % | |
| 6 | Turbo 15 min | |
| 7 | 4 % — la 1.ª vez llega con ella la insignia **Constante**, que regala la **Bolsa de cartón**; desde la 2.ª vuelta, + Turbo 15 min | la meta de la semana |

Por semana: 14 % del siguiente rebirth y 25 min de Turbo (40 desde la 2.ª vuelta). Tras la casilla 7 se vuelve a la 1.

### 4.3 Si se salta un día

**No pasa nada.** El calendario avanza solo los días que se juega: la siguiente casilla espera. No hay racha que perder ni nada que caduque: con público infantil, perder lo acumulado por no entrar un día es presión, y Roblox pide no presionar a los menores (§5.7). Lo que sí caduca cada día son los pedidos (como hoy) y los regalos del día (§4.5).

### 4.4 Bono de regreso

Al entrar, si `hoy − ultimoDiaJugado` ≥ 3 días y el tutorial va por el paso 5 o más (un jugador nuevo nunca lo recibe). Se da solo, con una ventana de bienvenida (es un regalo, no una oferta):

| Días sin jugar | Premio |
|---|---|
| 3 a 13 | Turbo 15 min + 4 % |
| 14 o más | Turbo 30 min + 8 % |

`ultimoDiaJugado` (nuevo, día UTC) se pone al dar el bono y en cada minuto activo: entrar 10 s cada 3 días da como mucho un bono cada 3 días, menos que jugar a diario. No se usa `ultimaSesion` porque se escribe al entrar, no al jugar.

### 4.5 Regalos por minutos activos

**Por día**, no por sesión: los minutos se suman entre las sesiones del mismo día (al móvil, de sesiones cortas, no le cuesta más) y salir y volver no reinicia los tramos (con tramos por sesión, entrar y salir cada 5 min rendiría más que jugar).

**Minuto activo:** en ese minuto el servidor vio al menos **3 acciones** de juego: pieza recogida, excavar, lanzar, depositar o comprar una mejora. Andar o estar en un menú no cuenta, así que el AFK no suma. Va en el tic de 60 s que ya existe en `Perfiles` (`tiempoJugado`).

| Minutos activos hoy | Premio (se da solo, con un aviso) |
|---|---|
| 5 | 0,5 % |
| 10 | 0,5 % |
| 20 | 1 % |
| 30 | Turbo 5 min |
| 45 | 1 % |
| 60 | 2 % (el último: no se premia jugar más de una hora) |

20 minutos dan 2 %; una hora, 5 % y 5 min de Turbo.

Todo §4 en datos (`dinero` = fracción del coste del siguiente rebirth; `turbo` = minutos):

```lua
-- Config/DefinicionesRecompensas.luau (nuevo)
DefinicionesRecompensas.PASO_DESBLOQUEO = "mejora" -- como los pedidos
DefinicionesRecompensas.CALENDARIO = {
	{ dinero = 0.02 },
	{ dinero = 0.02 },
	{ turbo = 10 },
	{ dinero = 0.03 },
	{ dinero = 0.03 },
	{ turbo = 15 },
	-- La 7.ª cobrada da la insignia semanaCompleta (diasCalendario = 7), que
	-- regala la Bolsa de carton; desde la 2.ª vuelta suma Turbo
	{ dinero = 0.04, turboDesdeVuelta2 = 15 },
}
DefinicionesRecompensas.ACCIONES_MINUTO_ACTIVO = 3
DefinicionesRecompensas.REGALOS = { -- minutos activos del dia (UTC)
	{ minutos = 5, dinero = 0.005 },
	{ minutos = 10, dinero = 0.005 },
	{ minutos = 20, dinero = 0.01 },
	{ minutos = 30, turbo = 5 },
	{ minutos = 45, dinero = 0.01 },
	{ minutos = 60, dinero = 0.02 },
}
DefinicionesRecompensas.REGRESO = { -- el primero que se cumpla
	{ dias = 14, dinero = 0.08, turbo = 30 },
	{ dias = 3, dinero = 0.04, turbo = 15 },
}
```

Perfil nuevo: `recompensas = { calendario = { siguiente = 1, vueltas = 0, ultimoDia = 0 }, regalos = { dia = 0, minutos = 0, cobrados = 0 }, ultimoDiaJugado = 0, packOtorgado = false }`, `turboRestante = 0`, `ofertas = {}`; estadísticas nuevas `diasCalendario`, `sesiones` y `minutosActivos`.

### 4.6 Turbo solo mientras juegas (cambio del Turbo actual)

Hoy `perfil.turboHasta` es un `os.time()`: el Turbo de los pedidos, que suele llegar al final de la sesión, se gasta con el jugador fuera, y quien compra 15 min y se le cae la conexión los pierde. Propuesta:

- `perfil.turboRestante` en segundos, que solo baja si el jugador está en el juego y ha hecho algo en los últimos **120 s** (`TURBO_PAUSA_INACTIVO`). El HUD dice "x2 en pausa" mientras no corre.
- Migración al cargar: si `turboHasta` > ahora, lo que queda pasa a `turboRestante`.
- **Tope de compra:** con más de 3 h guardadas (`TURBO_TOPE_COMPRA`) los botones de Turbo se desactivan ("Ya tienes más de 3 h de Turbo guardado"). Evita compras en serie; si aun así entra un recibo, se otorga.
- Afecta a los cinco orígenes del Turbo: pedidos, calendario, regalos, regreso y Robux.

### 4.7 Cuándo se abre cada cosa (tutorial de 8 pasos)

| Qué | Se abre | Nota |
|---|---|---|
| Contar minutos activos | desde el primer minuto | al abrirse los regalos se dan de golpe los tramos ya pasados |
| Pedidos | paso 5 completado (primera mejora) | sin cambios (`PASO_DESBLOQUEO = "mejora"`) |
| Calendario y regalos | paso 5 completado | pestaña **Recompensas** del panel Pedidos y punto rojo en el botón Pedidos con algo por cobrar; aviso "¡Recompensas nuevas!" |
| Bono de regreso | tutorial ≥ 5 y `ultimoDiaJugado` > 0 | |
| Ofertas | 7 pasos completados (primer pedido) **y** 2.ª sesión o más | nunca en la primera sesión |
| Pedido VIP | con VIP y pedidos abiertos | si se compra VIP a media tarde, se añade al momento |

### 4.8 Cuánto suma al día (medio, 20 min)

| Fuente | % del siguiente rebirth al día | Turbo al día |
|---|---|---|
| Pedidos (3) | ~6,5 % | 10 min (cumpliendo los 3) |
| Calendario (media de la semana) | 2 % | 3,6 min |
| Regalos (5, 10, 20 min) | 2 % | — |
| **Total** | **~10 %** | **~13 min** |
| VIP: Pedido VIP | +3 % | — |

Con 0 rebirths son ~$5.000 al día (4,7 min de su ingreso máximo); con 4, ~$89.000 (13 min). Al subir de rebirth pesa más volver cada día que jugar más rato: estrecha la distancia entre el que juega poco y el que juega mucho.

---

## 5. Catálogo y ofertas

### 5.1 Catálogo

| id | Tipo | Qué da exactamente | Precio | Justificación |
|---|---|---|---|---|
| `DineroX2` | pase | x2 a todo lo reciclado, para siempre | 199 | sin cambios; la mejor compra para quien juega a menudo (todos los tiempos a la mitad) |
| `BolsaXL` | pase | +10 huecos | 149 | sin cambios; −8 % al R1, −5 % al R5: sobre todo ahorra viajes al principio |
| `EstelaArcoiris` | pase | estela | 99 | sin cambios |
| `BolsaDorada` | pase | diseño de bolsa | 99 | sin cambios |
| **`VIP`** | pase (nuevo) | corona VIP sobre la cabeza (la ven todos), **Estela VIP** y un **4.º pedido diario** (Pedido VIP, paga como difícil: 3 %) | **249** | estatus visible y una ventaja pequeña que hay que jugar; no toca el pago por bolsa (no duplica Dinero x2) ni la capacidad (no duplica Bolsa XL) |
| **`PackInicio`** | pase (nuevo, compra única) | **30 min de Turbo** (una vez) y la **Bolsa del reciclador** (solo en el pack) | **99** | primera compra barata y clara; como pase, Roblox impide comprarlo dos veces |
| `Turbo15` | producto | x2 durante 15 min de juego, acumulable | 49 | sin cambios, salvo que solo corre jugando |
| **`Turbo60`** | producto (nuevo) | x2 durante 60 min de juego, acumulable | **149** | precio por cantidad (4 de 15 = 196): no se anuncia como "oferta" ni "descuento" |

Escalera de precios: 49 · 99 · 149 · 199 · 249. Las recompensas por minutos activos y el calendario suben el tiempo de juego, que es lo que reparten los Premium Payouts; no hay ventaja de Premium.

### 5.2 VIP

- **Corona VIP:** el servidor pone el atributo `VIP` en el `Player`; cada cliente dibuja sobre su cabeza un BillboardGui con el icono `corona` (ya está en `Config/Iconos`) y "VIP". No va en el chat: en las cuentas Select el chat suele ir apagado.
- **Estela VIP:** dorada (`pase = "VIP"`).
- **Pedido VIP:** `Pedidos.generar` crea `POR_DIA_VIP` = 4 si tiene el pase; el 4.º sale de las plantillas que no han salido, con la etiqueta "Pedido VIP", y paga 3 %. No cuenta para el Turbo de "los 3 del día".
- No se pinta nada VIP en los tablones: el top 10 viene de otros servidores y no sabemos si son VIP sin preguntar a Roblox jugador por jugador.

### 5.3 Pack de inicio

- **Pase**, no producto: es la única forma de que Roblox garantice una compra única (un producto se puede comprar dos veces y no se reembolsa solo).
- Al ver el pase (al entrar o al comprarlo, `Monetizacion.alCambiarPases`), si `perfil.recompensas.packOtorgado` es falso: +30 min de Turbo, la marca a true y el aviso "Pack de inicio: +30 min de Turbo". Comprado desde la web, llega al entrar.
- Siempre a la vista, arriba de la pestaña Pases, con "Compra única", hasta tenerlo. Sin cuenta atrás ni "solo para nuevos": el precio no cambia nunca.
- Icono `estrella` (no `cofre` ni `sobre`, que parecen cajas de premio al azar).

### 5.4 Cosméticos nuevos

Tres se ganan jugando y dos van dentro de VIP y del Pack (no se venden sueltos). Todos son color + material de la bolsa existente o una `ColorSequence`: ni arte nuevo ni Blender.

| id | Tipo | Nombre | Aspecto | Cómo se consigue |
|---|---|---|---|---|
| `Carton` | bolsa | Bolsa de cartón | `Cardboard`, (176, 134, 88) | insignia **Constante** (casilla 7 del calendario): `insignia = "semanaCompleta"` |
| `Hielo` | bolsa | Bolsa de hielo | `Ice`, (165, 220, 255) | Rebirth 4: `rebirth = 4` |
| `Reciclador` | bolsa | Bolsa del reciclador | `Fabric`, (64, 170, 92) | Pack de inicio: `pase = "PackInicio"` |
| `Fuego` | estela | Estela de fuego | (255, 60, 30) → (255, 140, 0) → (255, 220, 60) | Rebirth 5: `rebirth = 5` |
| `VIP` | estela | Estela VIP | (240, 180, 40) → (255, 236, 160) → (240, 180, 40) | VIP: `pase = "VIP"` |

`DefinicionesCosmeticos.loTiene(def, rebirths, tienePase, tieneInsignia)` gana la forma `insignia` (mira `perfil.logros[def.insignia]`). En la pestaña Estilo, el origen sale como "Con la insignia Constante", "Regalo del Rebirth 4", "Del Pack de inicio" o "Exclusivo VIP".

### 5.5 Turbo 60

```lua
{ id = "Turbo60", nombre = "Turbo 60 min", descripcion = "Dinero x2 durante 60 minutos de juego (se suma al que te quede)",
  precioRobux = 149, productId = 0, icono = "rayo", turboMinutos = 60 },
```

`Services/Turbo` ya registra solo todo producto con `turboMinutos`. Una línea en la tienda: "El Turbo solo corre mientras juegas".

### 5.6 Ofertas en el momento justo

**Reglas generales** (`DefinicionesOfertas.GLOBAL`):

1. Solo con **7 pasos del tutorial completados** (primer pedido) y desde la **2.ª sesión** (estadística nueva `sesiones`); nunca en los 3 primeros minutos de una sesión.
2. **Nunca si ya lo tiene** (pases), ni el Turbo con Turbo guardado; nunca un producto con id 0.
3. Como mucho **1 por sesión y 3 por semana** (7 días móviles).
4. **Ninguna en las 24 h siguientes a una compra con Robux:** nada de encadenar compras.
5. Se enseña en un **momento tranquilo**: tras un depósito o al terminar una celebración, sin panel abierto, sin cargar un lanzamiento y sin bolsa en el aire. Si en 60 s no hay ese momento, se descarta y no cuenta.
6. Ventana del Kit con el icono, un título y una frase con lo que da, y **dos botones del mismo tamaño, tipo de letra y peso**: "Comprar · 149 Robux" y "**Ahora no**" (color neutro, no gris de desactivado). La X y Esc valen "Ahora no". La compra la confirma siempre la ventana de Roblox.
7. Sin cuentas atrás, sin "¡solo hoy!", sin precios tachados ni "OFERTA": los precios no cambian.
8. Tras un "Ahora no", esa oferta no vuelve en 7 días; tras 3, no vuelve sola (sigue en la tienda).

**Disparadores** (si coinciden dos en la misma sesión, gana el de prioridad más alta):

| Prioridad | Oferta | Momento | Como pronto | Tope |
|---|---|---|---|---|
| 1 | Pack de inicio | al empezar la sesión, tras cobrar el calendario | sesión 2 (y otra vez la 4) | 2 veces; nunca con 2 rebirths o más |
| 2 | Dinero x2 | al cerrar la celebración del Rebirth 1 (y del 3): "Tu dinero ya vale x1,5. Con Dinero x2 valdría x3, para siempre." | R1 | 2 veces |
| 3 | VIP | al cerrar la celebración del Rebirth 2 | R2 | 1 vez |
| 4 | Bolsa XL | tras un depósito, si en la sesión intentó recoger con la bolsa llena 5 veces y su Bolsa va por el nivel 3 o más (el servidor cuenta los rechazos por bolsa llena) | sesión 2 | 1 cada 7 días, 3 en total |
| 5 | Turbo 15 / Turbo 60 | tras el primer depósito después de acabarse un Turbo **ganado** (pedidos, calendario, regalo, regreso) | sesión 3 | 1 por sesión, 2 por semana; tres botones iguales (15 min, 60 min, Ahora no) |

Lo decide el servidor (`Services/Ofertas` → `OfertaEvent`) y el cliente responde (`OfertaRespuestaEvent`: "ahoraNo" / "comprar") para guardar `perfil.ofertas[id] = { vistas, ultima, rechazos }`.

```lua
-- Config/DefinicionesOfertas.luau (nuevo)
DefinicionesOfertas.GLOBAL = {
	pasosTutorial = 7, -- con 7 pasos completados (el primer pedido)
	sesionMinima = 2, -- nunca en la primera sesion
	minutosEnSesion = 3,
	porSesion = 1,
	porSemana = 3,
	horasTrasCompra = 24,
	esperaMomento = 60, -- s para encontrar un momento tranquilo; si no, se descarta
	diasTrasAhoraNo = 7,
	rechazosMax = 3, -- con 3 "Ahora no", no vuelve sola
}
DefinicionesOfertas.LISTA = { -- en orden de prioridad
	{ id = "PackInicio", pases = { "PackInicio" }, momento = "inicioSesion", sesiones = { 2, 4 }, total = 2, rebirthsMax = 1 },
	{ id = "DineroX2", pases = { "DineroX2" }, momento = "rebirth", rebirths = { 1, 3 }, total = 2 },
	{ id = "VIP", pases = { "VIP" }, momento = "rebirth", rebirths = { 2 }, total = 1 },
	{ id = "BolsaXL", pases = { "BolsaXL" }, momento = "deposito", intentosBolsaLlena = 5, nivelBolsa = 3, cadaDias = 7, total = 3 },
	{ id = "Turbo", productos = { "Turbo15", "Turbo60" }, momento = "finTurboGanado", sesionMinima = 3, porSesion = 1, porSemana = 2 },
}
```

### 5.7 Cumplimiento (normas de Roblox)

- Roblox pide presentar lo que se vende de forma **transparente, honesta y sin presión**; prohíbe la escasez falsa, las cuentas atrás que no son reales o se reinician, y los descuentos permanentes o tan cortos que meten prisa; y pide evitar con menores los mensajes insistentes o urgentes (pone como ejemplo "View Item" en vez de "GET IT NOW"). Las reglas de §5.6 lo cumplen por diseño: precios fijos, sin temporizadores, un "Ahora no" igual de visible y como mucho tres ofertas por semana.
- Nada aleatorio de pago: no hace falta `PolicyService`.
- Lanzamiento: la fase de prueba solo deja entrar a usuarios **verificados de 16 o más**. Para llegar a Roblox Select (9–15) hacen falta **250 partidas únicas de jugadores muy comprometidos con la edad verificada en 60 días** (se ve en Audience Reach), una cuenta de creador verificada con verificación en dos pasos y una tarifa reembolsable por juego o Roblox Plus/Premium de 2 meses o más. El catálogo y las ofertas ya están pensados para ese público: no habrá que cambiarlos al abrirlo.

---

## 6. Copy nuevo (es | en | pt)

Glosario de siempre (en: bag, bin, order, upgrade, badge, streak; pt: saco, lixeira, pedido, melhoria, emblema, sequência). "Rebirth", "Turbo" y "VIP" no se traducen. `{premio}` es un dinero (`Idioma.dinero`, ya trae el $) o un mensaje anidado (`premioTurbo`, `premioY`, el nombre de un cosmético con `Idioma.mensajeNombre`); `{mult}` y `{mult2}` van con `Idioma.multiplicador`; `{precio}`, `{minutos}`, `{horas}` y `{n}` son números sueltos.

### 6.1 `DEF` (nombres de Config, por id)

| Clave | es | en | pt |
|---|---|---|---|
| `Pases.VIP.nombre` | VIP | VIP | VIP |
| `Pases.VIP.descripcion` | Corona VIP sobre tu cabeza, la Estela VIP y un pedido más cada día | A VIP crown over your head, the VIP trail and one more order every day | Coroa VIP sobre a sua cabeça, o Rastro VIP e um pedido a mais todo dia |
| `Pases.PackInicio.nombre` | Pack de inicio | Starter pack | Pacote inicial |
| `Pases.PackInicio.descripcion` | 30 min de Turbo (una vez) y la Bolsa del reciclador, que solo está en este pack | 30 min of Turbo (once) and the Recycler bag, which only comes in this pack | 30 min de Turbo (uma vez) e o Saco do reciclador, que só vem neste pacote |
| `Productos.Turbo15.descripcion` (cambia) | Dinero x2 durante 15 minutos de juego (se suma al que te quede) | x2 money for 15 minutes of play (adds to any you have left) | Dinheiro x2 por 15 minutos de jogo (soma ao que você ainda tiver) |
| `Productos.Turbo60.nombre` | Turbo 60 min | Turbo 60 min | Turbo 60 min |
| `Productos.Turbo60.descripcion` | Dinero x2 durante 60 minutos de juego (se suma al que te quede) | x2 money for 60 minutes of play (adds to any you have left) | Dinheiro x2 por 60 minutos de jogo (soma ao que você ainda tiver) |
| `Bolsas.Carton.nombre` | Bolsa de cartón | Cardboard bag | Saco de papelão |
| `Bolsas.Hielo.nombre` | Bolsa de hielo | Ice bag | Saco de gelo |
| `Bolsas.Reciclador.nombre` | Bolsa del reciclador | Recycler bag | Saco do reciclador |
| `Estelas.Fuego.nombre` | Estela de fuego | Fire trail | Rastro de fogo |
| `Estelas.VIP.nombre` | Estela VIP | VIP trail | Rastro VIP |
| `Insignias.rebirth5` | Reciclador de élite · Llega al Rebirth 5 | Elite recycler · Reach Rebirth 5 | Reciclador de elite · Chegue ao Rebirth 5 |
| `Insignias.rebirth10` | Leyenda del reciclaje · Llega al Rebirth 10 | Recycling legend · Reach Rebirth 10 | Lenda da reciclagem · Chegue ao Rebirth 10 |
| `Insignias.semanaCompleta` | Constante · Cobra las 7 casillas del calendario | Dedicated · Claim all 7 calendar rewards | Dedicado · Resgate os 7 prêmios do calendário |
| `Insignias.pedidos30` | Cumplidor · Cumple 30 pedidos | Reliable · Complete 30 orders | Confiável · Cumpra 30 pedidos |

(En las insignias, "nombre · descripción": son dos campos.)

### 6.2 `REBIRTH.desbloquea`

| Clave | es | en | pt |
|---|---|---|---|
| `bolsaHielo` | Regala la Bolsa de hielo | Gives you the Ice bag | Dá o Saco de gelo |
| `estelaFuego` | Regala la Estela de fuego y una insignia | Gives you the Fire trail and a badge | Dá o Rastro de fogo e um emblema |
| `multiplicador` | Sube tu multiplicador de dinero | Raises your money multiplier | Aumenta seu multiplicador de dinheiro |
| `leyenda` | Regala la insignia Leyenda del reciclaje | Gives you the Recycling legend badge | Dá o emblema Lenda da reciclagem |
| ~~`insignia`~~ | se quita en los tres idiomas | | |

### 6.3 `RECOMPENSAS` (sección nueva)

| Clave | es | en | pt |
|---|---|---|---|
| `calendario` | Calendario | Calendar | Calendário |
| `dia` | Día {n} | Day {n} | Dia {n} |
| `semana` | Semana {n} | Week {n} | Semana {n} |
| `reclamar` | Reclamar | Claim | Resgatar |
| `reclamado` | Reclamado | Claimed | Resgatado |
| `vuelveManana` | Vuelve mañana para el día {n} | Come back tomorrow for day {n} | Volte amanhã para o dia {n} |
| `listo` | ¡Tu premio del día está listo! | Your daily reward is ready! | Seu prêmio do dia está pronto! |
| `cobrado` | Día {n}: {premio} | Day {n}: {premio} | Dia {n}: {premio} |
| `sinPrisa` | Si un día no juegas, no pierdes nada: el calendario te espera | Miss a day and you lose nothing: the calendar waits for you | Se ficar um dia sem jogar, você não perde nada: o calendário te espera |
| `regalos` | Regalos por jugar | Playtime gifts | Presentes por jogar |
| `minutosHoy` | Hoy llevas {n} min jugando | You've played {n} min today | Hoje você já jogou {n} min |
| `siguiente` | Siguiente regalo a los {n} min | Next gift at {n} min | Próximo presente aos {n} min |
| `todos` | ¡Ya tienes todos los regalos de hoy! Mañana hay más | You got all of today's gifts! More tomorrow | Você ganhou todos os presentes de hoje! Amanhã tem mais |
| `soloActivo` | Cuentan los minutos en los que recoges, lanzas o excavas | Only minutes where you pick up, throw or dig count | Só contam os minutos em que você pega, joga ou cava |
| `regalo` | ¡Regalo por jugar {n} min! {premio} | Gift for playing {n} min! {premio} | Presente por jogar {n} min! {premio} |
| `tramo` | {n} min | {n} min | {n} min |
| `regresoTitulo` | ¡Qué bien verte otra vez! | Great to see you again! | Que bom te ver de novo! |
| `regresoTexto` | Por volver te llevas {premio} | For coming back, you get {premio} | Por voltar, você ganha {premio} |
| `cerradas` | Las recompensas se abren cuando compres tu primera mejora | Rewards open when you buy your first upgrade | As recompensas abrem quando você comprar sua primeira melhoria |
| `abiertas` | ¡Recompensas nuevas! Míralas en Pedidos | New rewards! Check them in Orders | Novas recompensas! Veja em Pedidos |
| `premioTurbo` | Turbo {minutos} min | Turbo {minutos} min | Turbo {minutos} min |
| `premioY` | {a} y {b} | {a} and {b} | {a} e {b} |

### 6.4 `OFERTAS` (sección nueva)

| Clave | es | en | pt |
|---|---|---|---|
| `comprar` | Comprar · {precio} Robux | Buy · {precio} Robux | Comprar · {precio} Robux |
| `ahoraNo` | Ahora no | Not now | Agora não |
| `packTitulo` | Pack de inicio | Starter pack | Pacote inicial |
| `packTexto` | 30 min de Turbo y la Bolsa del reciclador, que solo está en este pack. Se compra una sola vez. | 30 min of Turbo and the Recycler bag, which only comes in this pack. One-time purchase. | 30 min de Turbo e o Saco do reciclador, que só vem neste pacote. Compra única. |
| `bolsaXLTitulo` | ¿Se te llena la bolsa? | Is your bag always full? | Seu saco vive cheio? |
| `bolsaXLTexto` | Bolsa XL: 10 huecos más para siempre. Menos viajes al contenedor. | XL Bag: 10 more slots forever. Fewer trips to the bin. | Saco XL: 10 espaços a mais para sempre. Menos viagens até a lixeira. |
| `turboTitulo` | Se acabó tu Turbo | Your Turbo ran out | Seu Turbo acabou |
| `turboTexto` | El Turbo paga el doble mientras juegas y solo corre mientras estás en el juego. | Turbo pays double while you play, and it only runs while you're in the game. | O Turbo paga o dobro enquanto você joga e só corre enquanto você está no jogo. |
| `turboOpcion` | {minutos} min · {precio} Robux | {minutos} min · {precio} Robux | {minutos} min · {precio} Robux |
| `dineroTitulo` | Tu dinero ya vale {mult} | Your money is now worth {mult} | Seu dinheiro agora vale {mult} |
| `dineroTexto` | Con Dinero x2 valdría {mult2}, para siempre. | With x2 Money it would be worth {mult2}, forever. | Com Dinheiro x2 valeria {mult2}, para sempre. |
| `vipTitulo` | VIP | VIP | VIP |
| `vipTexto` | Corona VIP sobre tu cabeza, la Estela VIP y un pedido más cada día. | A VIP crown over your head, the VIP trail and one more order every day. | Coroa VIP sobre a sua cabeça, o Rastro VIP e um pedido a mais todo dia. |
| `gracias` | ¡Gracias! Ya es tuyo: {nombre} | Thanks! It's yours: {nombre} | Obrigado! Agora é seu: {nombre} |

### 6.5 Claves sueltas en secciones que ya existen

| Clave | es | en | pt |
|---|---|---|---|
| `TIENDA.conInsignia` | Con la insignia {nombre} | With the {nombre} badge | Com o emblema {nombre} |
| `TIENDA.dePack` | Del Pack de inicio | From the Starter pack | Do Pacote inicial |
| `TIENDA.deVip` | Exclusivo VIP | VIP exclusive | Exclusivo VIP |
| `TIENDA.compraUnica` | Compra única | One-time purchase | Compra única |
| `TIENDA.turboTope` | Ya tienes más de {horas} h de Turbo guardado | You already have over {horas} h of Turbo saved | Você já tem mais de {horas} h de Turbo guardado |
| `TURBO.soloJugando` | El Turbo solo corre mientras juegas | Turbo only runs while you play | O Turbo só corre enquanto você joga |
| `TURBO.pausado` | x2 en pausa | x2 paused | x2 pausado |
| `PEDIDOS.pestanaRecompensas` | Recompensas | Rewards | Recompensas |
| `PEDIDOS.vip` | Pedido VIP | VIP order | Pedido VIP |
| `NOTIFICACIONES.packTurbo` | Pack de inicio: +{minutos} min de Turbo | Starter pack: +{minutos} min of Turbo | Pacote inicial: +{minutos} min de Turbo |
| `MUNDO.vip` | VIP | VIP | VIP |

Lo que enseña Roblox fuera del juego (nombre y descripción de los pases, del producto y de las insignias) se traduce a mano en el Creator Dashboard → Localization, con estos mismos textos (CONTEXTO §5).

---

## 7. Riesgos y medición

### 7.1 Riesgos

| Riesgo | Por qué | Qué se mira | Plan si sale mal |
|---|---|---|---|
| El modelo se equivoca | t_p0, η, acierto y viaje son supuestos; se calibraron contra la auditoría, que también lo era | segundos por ciclo, bolsas por minuto, acierto por distancia, mediana de minutos hasta el R1 | regla de §7.3 |
| Fase de ahorro larga desde el R3 | 90 % de cada rebirth con todo al máximo y nada que comprar | sesiones que acaban en esa fase, días entre "todas al máximo" y el rebirth | escalar el coste de las mejoras con √(multiplicador) y bajar requisitos (pregunta 3) |
| Quien vuelve cada día va el doble de rápido | ~10 % del siguiente rebirth al día + ~13 min de Turbo gratis | minutos hasta R5 de los que tienen 7+ días de juego | bajar el calendario y los regalos un tercio (los pedidos, no) |
| El Turbo gratis le quita valor al de pago | con la pausa, el Turbo gratis se aprovecha entero | minutos guardados (p90), Turbo comprado frente a ganado | si el p90 pasa de 60 min, quitar el Turbo de la casilla 6 |
| Pago para progresar (Dinero x2 + Bolsa XL + Turbo: R1 en ~20 min) | permitido (ventajas personales que piden jugar), pero el tablón de Dinero ganado lo dominará quien pague | % del top 100 de Dinero ganado con Dinero x2 | Racha y Bolsas encestadas ya son rankings de habilidad; no meter más ventajas de dinero |
| Ofertas que molestan | público infantil | ofertas por jugador y día, % de "Ahora no", sesiones que acaban en menos de 3 min tras una oferta | si pasan del 5 %, quitar ese disparador |
| Renacer duele | se pierden mejoras y dinero | sesiones que acaban en menos de 5 min tras un rebirth | la oferta de Dinero x2 nunca justo antes; revisar el texto del panel |
| Lo que sobra del requisito se pierde al renacer | el dinero vuelve a 0 y algunos premios llegan después del requisito | dinero en mano al renacer frente al requisito | el panel ya avisa ("Se reinician el dinero y las mejoras"); si sobra mucho, decir cuánto |
| AFK y autoclicker en los regalos | minutos regalados | minutos activos frente a piezas por minuto | subir el umbral de 3 acciones por minuto |
| Turbo antiguo | perfiles con `turboHasta` | prueba de migración | `perfilV3` y `turboPausa` |

No hay riesgo de inflación: la única moneda se gasta en mejoras, vuelve a 0 en cada rebirth, y los premios son porcentajes del siguiente rebirth, así que crecen con él.

### 7.2 Analítica (`AnalyticsService`)

| Evento | Llamada | Cuándo | Campos propios (3 como mucho, en tramos, sin UserId) | Para qué |
|---|---|---|---|---|
| Embudo de entrada | `LogOnboardingFunnelStepEvent(j, paso, nombre)` | los 8 pasos del tutorial y el R1 (paso 9) | plataforma | abandono por paso |
| Rebirth | `LogProgressionCompleteEvent(j, "Rebirth", n)` | al renacer | plataforma, minutos activos totales (tramos de 10), Dinero x2 sí/no | **tiempo hasta cada rebirth**: la cifra que calibra todo |
| Dinero que entra | `LogEconomyEvent(j, Source, "Dinero", …, tipo, sku)` | depósito (`Gameplay`, `Deposito_General` / `Deposito_Tipo`), pedido (`Gameplay`, `Pedido_medio`…), calendario, regalo y regreso (`TimedReward`, `Calendario_3`, `Regalo_20`, `Regreso_14`) | | fuentes de dinero |
| Dinero que sale | `LogEconomyEvent(j, Sink, "Dinero", …)` | mejora (`Shop`, `Mejora_Brazo_7`), rebirth (`Gameplay`, `Rebirth_2`) | | sumideros |
| Turbo | `LogEconomyEvent` con la moneda `TurboMin` | entra por Robux (`IAP`: `Turbo15`, `Turbo60`, `PackInicio`), premios (`TimedReward`, `Gameplay`); sale al consumirse (cada 5 min y al salir) | | Turbo gratis frente a pagado, minutos guardados |
| Bolsa | `LogCustomEvent(j, "Bolsa", segundosCiclo)` | 1 de cada 3 depósitos | vía (lanzada / a mano / fallada), tramo de distancia, contenedor (general / de tipo) | t por ciclo, acierto por distancia, % separadas |
| Oferta | `LogCustomEvent(j, "Oferta", 1)` | al mostrarla y al contestar | id, resultado, número de sesión (tramo) | conversión y rechazo |
| Calendario | `LogCustomEvent(j, "Calendario", casilla)` | al cobrar | vuelta, días desde la última | uso y vuelta |

### 7.3 Objetivos y regla de recalibración

| KPI | Objetivo | Si se desvía |
|---|---|---|
| Mediana de minutos activos hasta el R1, PC (todos los que llegan) | 45–60 | regla de abajo |
| Ídem, móvil | 60–85 | si solo falla el móvil, es recoger con la mira (t_p0), no la economía |
| Segundos por ciclo, medio PC, nivel 0 / nivel 10 | ~24 / ~36 | recalcular t_p0 y η |
| Acierto: 10–19 m / 45–59 m | ~80 % / ~55 % | revisar los tramos del bonus |
| % de piezas en el contenedor de su tipo | ~25 % | |
| Jugadores nuevos que cobran la casilla 2 / la 7 | medir (referencia tras 2 semanas) | |
| Minutos de Turbo guardados, p90 | < 60 | quitar Turbo del calendario |
| Sesiones que acaban < 3 min tras una oferta | < 5 % | quitar el disparador |
| Camino a Select: partidas de jugadores muy comprometidos | 250 en 60 días | Audience Reach |

**Regla:** con 200 jugadores o más que hayan llegado al R1 y dos semanas de datos, si la mediana de PC (M minutos) se sale de 45–60, multiplicar los 4 `costeBase` y los 10 requisitos de `TABLA` por **k = 52 / M**. Los tiempos son proporcionales a los costes, y los premios, al ser porcentajes del siguiente rebirth, se ajustan solos. Una sola vez, y anotarlo en CONTEXTO.

---

## 8. Preguntas abiertas

1. **Turbo solo mientras juegas** (en pausa al salir y tras 2 min sin hacer nada, §4.6). Cambia el Turbo de los pedidos y el de 15 min, que nadie ha comprado aún (ids a 0). ¿De acuerdo?
2. **VIP:** ¿a 249 con el 4.º pedido diario (una ventaja pequeña que hay que jugar), o solo estético (corona y estela) a 199?
3. **Fase de ahorro:** desde el R3, ~90 % de cada rebirth se juega con todo al máximo ahorrando para el requisito. ¿Lo lanzamos así y lo medimos (propuesta), o escalamos ya el coste de las mejoras con la raíz del multiplicador (más compras en cada rebirth, requisitos más bajos)?
4. **Cambio de día:** pedidos y calendario cambian a las 00:00 UTC, que en Latinoamérica son las 19–21 h. ¿Lo dejamos así o lo pasamos (para los dos) a las 06:00 UTC (00–03 h en América, 07–08 h en España)?

---

## Anexo A. Plan de trabajo (cuando se apruebe)

| # | Agente | Tarea | Terminado cuando |
|---|---|---|---|
| 1 | `roblox-dev` | Curva: `FACTOR_COSTE_MEJORA`, `DefinicionesRebirths` (tabla, fórmula, `costeSiguiente`, claves `desbloquea`), copy de §6.2, cabeceras | `mejorasV2`, `rebirthTabla`, `costeSiguiente` e `idioma` en verde; el panel de Rebirth dice "Regala la Bolsa de hielo" en el R4 |
| 2 | `roblox-dev` | Pedidos en porcentaje, calculados al cobrar; panel y HUD desde Config | `pedidosDia` da $760 / 1.000 / 1.500 con 0 rebirths y $2.000 / 2.700 / 4.100 con 1 |
| 3 | `roblox-dev` | Turbo por tiempo jugado: `turboRestante`, migración, pausa por inactividad, tope de 3 h | `turboPausa` (salir y volver lo conserva; 2 min quieto no descuenta), `turboAcumula`, `premioTurbo` |
| 4 | `roblox-dev` | Recompensas: `DefinicionesRecompensas`, `Services/Recompensas` + Handler, minutos activos, calendario, regalos, regreso, pestaña Recompensas y punto rojo | `calendario` (7 casillas, vuelta, saltarse un día no reinicia), `regalosActivos` (el AFK no cuenta), `bonoRegreso` (3 y 14 días); `("hud")` sin solapes en PC y táctil |
| 5 | `roblox-dev` | Catálogo: VIP (corona, pedido, estela), Pack de inicio (Turbo una vez), Turbo 60, 5 cosméticos con la forma `insignia`, 4 insignias, copy de §6.1 | `paseVip`, `packInicio` (una sola vez aunque se recargue el perfil), `cosmeticoBolsa`, `insignias` (20), `idioma` |
| 6 | `roblox-dev` | Ofertas: `DefinicionesOfertas`, `Services/Ofertas`, `UI/Oferta` con los dos botones iguales | `ofertasReglas` (no en la 1.ª sesión, no si lo tiene, 1 por sesión, 3 por semana, 24 h tras una compra); capturas en PC y táctil |
| 7 | `roblox-dev` | Analítica de §7.2 | los eventos salen en el Creator Dashboard tras una partida en el place publicado |
| 8 | usuario | Creator Dashboard: pases VIP y Pack de inicio, producto Turbo 60 (y los pendientes), 4 insignias nuevas (+16 pendientes, 5 por día), traducciones; ids en Config | ningún "Próximamente" en la tienda |
| 9 | `roblox-dev` | CONTEXTO §1, §3 y §4 al día con lo hecho; aviso en el GDD | CONTEXTO describe la economía v4 |
| 10 | — | L10: medir dos semanas y aplicar la regla de §7.3 | k aplicado (o descartado) y anotado |

`roblox-builder` y `blender-modeler` no hacen falta: los cosméticos son color, material y `ColorSequence`, y la corona es un icono del Kit.

## Anexo B. Fuentes

- Roblox Creator Hub, [Kids and Select](https://create.roblox.com/docs/production/publishing/kids-and-select): edades, fase de prueba 16+, umbral de 250 partidas en 60 días, requisitos del creador.
- Roblox Creator Hub, [Monetization](https://create.roblox.com/docs/en-us/production/monetization): transparencia, descuentos genuinos y justos, sin escasez ni cuentas atrás falsas, sin mensajes urgentes con menores.
- Roblox Creator Hub, [Badges](https://create.roblox.com/docs/en-us/production/publishing/badges): 5 insignias gratis cada 24 h por experiencia, 100 Robux cada una más.
- Roblox Engine API, [AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService): `LogEconomyEvent`, `LogOnboardingFunnelStepEvent`, `LogProgressionCompleteEvent`, `LogCustomEvent`.
