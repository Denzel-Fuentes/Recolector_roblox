# Recíclatas (CleanRecycle) — estado del proyecto

Réplica mecánica de KOTAMON para Roblox, low-poly de partes con arte por
capas sobre un esqueleto whitebox (ver §3 "Arte del mundo"). El diseño
completo está en `docs/GDD.md`; este documento es lo que NO se deduce del
código: qué hay, cómo se trabaja y por qué se decidió lo no obvio.

**26 sep 2026: Diseño v2 "recoger y lanzar"** (documento de @FND, ver §3
"Diseño v2"). Sustituye al recorte por la auditoría del mismo día: lo que
la v2 quita se BORRÓ del código (base, energía, reparación, fusión, venta,
gemas, Sobre, Contenedor Dorado, Montón extra, logros con dinero) y lo que
solo pospone (figuritas, cintas, trajes del botín) queda tras
`GameConfig.FUNCIONES`. Se implementa por lotes verificados (L1–L10, plan en
§3); **hechos: L1** (retirada y perfil v3), **L2** (mundo v4), **L3**
(patio por zonas), **L4** (rebirths), **L5** (lanzamiento y pago) y
**L6** (mascotas). **29 sep, cambios del usuario sobre el documento:** los
montones traen basura **revuelta** (ya no un material por cuadrante; el
norte es más rico) y las mascotas se consiguen con **fragmentos** que salen
en los montones (fuera las cápsulas y sus medidores); ver §3 "Cambios del
29 sep". Lo que sigue en este documento sobre sistemas borrados queda como
historia de por qué se hicieron así.

Última pasada anterior: 16 sep 2026 (rendimiento móvil: sin árboles, valla ligera,
sombras y física de la basura recortadas; plano v3 del mapa: parcelas en columna al oeste,
recicladora al sur, valla alrededor de todo; antes, el mismo día, arte del
mundo por MCP: cabaña, máquinas, vallas,
árboles, camión, materiales IA; antes, 15 sep: interfaz v2 papel y tinta,
lotes 9–11). Estado: **todas las mecánicas del GDD implementadas y
verificadas en Play Solo**, HUD/manos/carteles/diálogo con el estilo nuevo,
mundo vestido; pendientes los paneles (lotes 12–13 de la UI), la prueba con
2+ jugadores y publicar.

## 1. Qué hay

| Sistema | Dónde | Estado |
|---|---|---|
| Cuadrantes: los 4 del sur abiertos (zona "patio"); la **zona de metal con el Rebirth 1 y la de orgánico con el 2**, tras barreras de cristal que son **por jugador** (grupos de colisión por nivel de rebirth) y que el servidor respalda (no se excava ni se recoge en un cuadrante cerrado) | `GameConfig.CUADRANTES`, `Utilidades/Cuadrantes`, `Services/Colisiones`, `ObjetosPatio.puedeReclamar` | verificado (`cuadrantes`, `bloqueoRebirth`, `barreraColision`, `caminarBarrera`) |
| Patio compartido: 18 **colinas** de basura (2x3 cuadrantes, 2 chicas de 20 piezas + 1 grande de 60 por cuadrante); al activar, la colina se sustituye por una **montaña de basura real con física**, **revuelta** según la zona (`TablasProbabilidad.MEZCLA`: el patio 45/40/10/5 papel/plástico/metal/orgánico; la zona de metal 55 % metal; la de orgánico 55 % orgánico); billetes 5 %, tesoros 1 %, **fragmentos de mascota 2,5 %**; la grande trae un tesoro y un fragmento seguros; **solo se recoge con clic** (o el imán de las mascotas, lote 6), reclamo atómico, **prioridad del excavador 10 s**, un montón terminado **vuelve a los 45 s** | `Services/Botin.luau` (fachada) → `GeneradorBotin`, `ObjetosPatio`, `FisicaBasura`, `Montones`, `Iman`, `Lanzamiento` + `BotinHandler` | verificado (`montonPiezas`, `reacomodo`, `sinRecogidaAutomatica`, `variedadBasura`, `mezclaZonas`, `variedadPiezas`) |
| Puntería: **mantener F carga y lanza la bolsa entera**, el alcance lo da la mejora **Brazo** (25 → 70 studs); al entrar paga el **bonus por distancia** (+20 % desde 10 studs … +150 % desde 60) más la **racha** (+10 % por acierto seguido, tope +50 %); el **primer lanzamiento siempre entra**; los 5 primeros llevan **línea de trayectoria**; récord personal y del servidor en el feed; si falla, racha a 0 y la bolsa queda en el suelo para **su dueño** hasta que vuelva a por ella (no se recicla sola desde el 29 sep; si cae en alto se baja junto al contenedor); **solo se lanza con la bolsa llena** (29 sep: el botón táctil y la pista "MANTÉN F" solo salen entonces) | `Services/Lanzamiento.luau`, `Config/DefinicionesPunteria`, `Utilidades/Trayectoria`, `Client/LineaTrayectoria` | verificado (`bonusDistancia`, `racha`, `primeroEntra`, `pagoFormula`, `lanzarBolsa`, `lanzarBolsaFallo`, `bolsaProtegida`, `brazoLimita`, `("trayectoria")`) |
| Primera persona automática en el patio con retícula (punto), manos+bolsa en 2D (Frames), brazos extendidos (cliente y servidor) sujetando una bolsa abierta soldada entre las manos | `Services/Patio.luau`, `Utilidades/PoseBrazos`, `Client/Camara.client`, `Client/UI/Manos.client`, `Escena.client` | verificado (`enPatio`, capturas) |
| HUD v2: botonera de 4 (Tienda; Mascotas, Rebirth y Pedidos aparecen con su lote), píldora del dinero arriba-dcha, barras de fuerza y **bolsa** (sin números, "¡LLENA!" en rojo), pistas de lanzar/recoger | `Client/UI/HUD.client.luau` | verificado (`("hud")` sin avisos en PC y táctil forzada) |
| Sistema de diseño en **Fusion 0.3** (`Client/UI/Kit`): Ventana, Boton, Tarjeta, Pestanas, Pildora, Barra, Insignia, Icono, Escala; prompts y carteles del mundo (el prompt de Doña Chatarra abre la tienda; sus diálogos se quitaron el 29 sep) | `Client/UI/Kit/*`, `Prompts.client`, `Escena.client` | verificado |
| **Mundo v5** (29 sep; v4 el 26): sin parcelas ni máquina de refrescos, valla a 24 studs del patio por los tres lados, suelo de tierra en el patio abierto y del color de su material en las zonas del norte, barreras "Rebirth 1 · Zona de metal" / "Rebirth 2 · Zona de orgánico", punto de aparición en la plaza; tienda SHOP y recicladora de Blender, vallas, postes, camión, Doña Chatarra vestida, iluminación cartoon | `ServerStorage/Herramientas/ArteMundo.luau` + `ConstructorMundo` v5 | verificado (horneado v5 el 29 sep: 1.004 instancias, 18 ranuras con `Zona`, 8 barreras; capturas); **guardar el place** |
| Bolsa: todo lo recogido ocupa hueco (billetes incluidos), **sólo el contenedor paga**; entregar a mano no da bonus, lanzar sí | `Services/Bolsa.luau` | verificado (`billeteEnBolsa`, `sinDineroAlRecoger`, `salirRecicla`) |
| **Rebirths**: con las 4 mejoras al máximo y el dinero del requisito en mano ($50k, 200k, 800k, 3,2M, 12,8M; luego ×4) se reinician dinero y mejoras y el dinero pasa a ×1,5 / 2 / 2,5 / 3 / 3,5 (luego +0,5); el 1 abre la zona de metal y el set Chatarrín, el 2 la de orgánico y Mostrenco, el 3 la segunda mascota. Panel con requisito, barra y lo que abre; barrita de progreso bajo el botón del HUD | `Config/DefinicionesRebirths`, `Services/Rebirths` + `RebirthsHandler`, `Client/UI/Rebirth.luau` | verificado (`rebirthTabla`, `renacerRequisitos`, `renacer`, capturas) |
| **4 mejoras × 10 niveles** (Bolsa 10→40, Alcance 6→16, Velocidad 16→28, Brazo 25→70), coste base × 1,6^nivel, total $118.030 | `Config/DefinicionesMejoras`, `Services/Mejoras.luau` | verificado (`mejorasV2`) |
| **Perfil v3** con el esquema entero de la v2 (rebirths, mascotas por nivel y sus fragmentos, pedidos, cosméticos); DataStore nuevo `ReciclatasPerfiles_v3`, sin migración | `Services/Perfiles.luau`, `DataService` | verificado (`perfilV3`); guardar sin probar: exige publicar |
| **Aparición** en la plaza mirando al patio (sin base), también al morir | `Services/AparicionHandler.server.luau`, `Mundo.cframeAparicion` | verificado (`aparicion`) |
| **Mascotas por fragmentos** (29 sep): los fragmentos salen entre la basura (2,5 %, uno seguro en el montón grande), son del set de su material (solo de los sets que quien excava tiene abiertos) y **cuentan al reciclarlos**. Cada set **monta una mascota a la vez**: el primer fragmento decide cuál (67/28/5 con pity por set: Rara+ a la 5.ª, Épica a la 20.ª; "siempre nueva" dentro de la rareza) y pide **5/8/12 fragmentos** según su rareza; **la primera mascota del jugador es Común y pide 3**. Repetidas suben de nivel (1–5) y después dan dinero; 41 mascotas (4 sets × 4/3/3 + **Rey Reciclón** con las 40, +50 % a todo); **1 equipada** (2 desde el Rebirth 3) que te sigue, da +20…+160 % a su material y, si es Rara o Épica, **imán** de su material (6/10 studs). Álbum con la mascota que monta cada set y las probabilidades, ventana de revelación al completarla, progreso en el HUD ("Latita 3/5") | `Services/Mascotas`, `Fragmentos`, `Seguidores` + `MascotasHandler`, `Config/DefinicionesMascotas`, `Client/UI/Mascotas`, `UI/Revelacion` | verificado (`rarezaOdds`, `siempreNueva`, `primeraMascota`, `montaje`, `fragmentoCerrado`, `fragmentoAlDepositar`, `fragmentosMonton`, `repetidaNivel`, `huecos`, `bonusMascota`, `imanMaterial`, `reyReciclon`, `simularSet`, revelación y HUD en el cliente) |
| Tutorial jugable (5 pasos: patio, excavar, llenar, lanzar, mejora); flecha (Beam) y tarjeta abajo-centro | `Config/DefinicionesTutorial`, `Services/Tutorial.luau`, `Client/UI/Tutorial.client` | verificado (`tutorial`); la versión "primeros 15 minutos" llega en el lote 9 |
| Tienda: Mejoras y Trajes de pago (Robux) | `Client/UI/Tienda.luau`, `TiendaHandler`, `ColeccionablesHandler` (trajes) | verificado (`("panel","Tienda")`) |
| Figuritas (6 fijas), cintas y trajes del botín: **pospuestos** (`FUNCIONES`) | `Config/DefinicionesColeccionables`, `Services/Coleccionables.luau` | apagados |
| Monetización: pases (hoy solo los 2 trajes), ProcessReceipt idempotente con otorgadores registrados por producto, modo dev | `Services/Monetizacion.luau`, `Config/Productos` | escrito; catálogo v2 en el lote 8 |
| Admin por chat (`/dar dinero`, `/maxmejoras`, `/pases`, `/rebirths n`, `/tutorial n`, `/repoblar`, `/reset`) | `Services/AdminHandler.server.luau` | escrito |

## 2. Cómo se trabaja

### Sincronizar código a Studio

Flujo normal: `rojo serve default.project.json --port 34872` y **Connect** en el
plugin de Rojo. Rojo 7 crea `X.luau` → ModuleScript, `X.server.luau` → Script,
`X.client.luau` → LocalScript, `X.model.json` → instancia.

Flujo de emergencia (cuando no se puede pulsar Connect, p. ej. trabajando por
MCP): `herramientas/servir-fuentes.ps1` sirve `src/` por HTTP en
`localhost:8123` y `herramientas/instalar-desde-http.luau`, ejecutado en la
barra de comandos (o `execute_luau`) sobre el DataModel Edit, crea/actualiza el
mismo árbol con las mismas reglas. Es idempotente y sólo escribe `Source` si
cambió; cuando el plugin de Rojo se conecte no verá diferencias.

### El mundo

`workspace.Mundo` es geometría REAL del place, construida por
`herramientas/construir-mundo.luau` (que llama a
`ServerStorage/Herramientas/ConstructorMundo`, y este viste el esqueleto con
`ArteMundo`). **Tras construir hay que guardar el place.** `SetupMundo` sólo
lo adopta; si falta, lo construye en runtime como fallback y avisa. Todo se
localiza por tags/atributos, nunca por nombre: `RanuraMonton` (18, con
`Tamano`, `Cuadrante` y `Material`), `BarreraCuadrante` (8, con `Cuadrante`
y `Rebirth`), `PuntoAparicion`, `Contenedor`, `Limite`, `SoloDecorado`,
`FigurinaFija` (solo con `FIGURINAS`); atributo `NPC`. Mundo v4 (26 sep):
~1.050 instancias.

Lo generado por IA vive **en el place**, no en git: las variantes de
material de `MaterialService` (`MontanaBasura` es la única en uso; `CespedCartoon` y
`MaderaVieja` quedaron huérfanas al pasar suelo y parcelas a color liso; hijas directas; el generador las deja en carpetas
`Material: X` con 4 candidatas) y las mallas de `ServerStorage.Arte`
(`Camion`, `Bolsa` —saco facetado atado con banda amarilla, referencia del
usuario—; `Arbol` ya no se usa: se quitaron todos los árboles por
rendimiento). El código las usa por nombre (`Paleta.VARIANTES`,
`ArteMundo.clonarMalla`) y sin ellas construye igual con materiales base y
props de partes. Para regenerarlas: `generate_material` / `generate_mesh`
del MCP y renombrar.

### Trabajar por el MCP de Studio

El hilo de `execute_luau` (Edit) **puede** crear partes, escribir `Source` y
propiedades, y leer `Source`; **no puede** hacer `require` de módulos del
juego, usar HttpService, crear/reparentar scripts ni invocar
BindableFunctions/RemoteEvents (le faltan capacidades: "LoadUnownedAsset",
"Network", "RobloxScript"). De ahí:

- Hornear desde el MCP: `herramientas/hornear-desde-mcp.luau`, un `require`
  que carga cada módulo con `loadstring(modulo.Source)` y `setfenv`.
- Sincronizar código sin el plugin de Rojo: `multi_edit` crea y edita
  scripts y `Source = [==[...]==]` por `execute_luau` reescribe los
  existentes; se comprueba con una huella (largo, suma de bytes y suma
  ponderada por posición) igual en local y en Studio. **Con Rojo conectado no
  usar `multi_edit`**: aplica el mismo cambio dos veces (pasó con `Paleta`).
- Pruebas: por atributos (`Prueba` / `PruebaCliente`, ver arriba).
- `screen_capture` acepta `camera_position` / `look_at_position` en Edit;
  en Play, mover `workspace.CurrentCamera` (Scriptable) desde el cliente.
- Los eventos de `user_keyboard_input` / `user_mouse_input` llegan al juego
  ~6–8 s después de que la herramienta responda; para pulsar algo que
  aparece por un tiempo (el diálogo) hay que esperar a verlo (poll desde
  `execute_luau`) y usar `instance_path` en el clic.

### Probar

- `ServerStorage.EjecutarPrueba:Invoke(nombre, ...)` (sólo Studio) ejecuta las
  pruebas de `Services/PruebasDefinidas/` (por área: Patio, Bolsa, Progreso) DENTRO de la VM del servidor.
  Existe porque la barra de comandos / execute_luau corren en la VM del plugin y
  allí `require` devuelve copias vacías de los módulos.
- `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir", "Album")` abre
  paneles desde la VM del cliente.
- Si el hilo del MCP no puede invocar BindableFunctions ("additional values for
  the Capabilities property", visto en Studio tras reabrir el place), la misma
  prueba se lanza por atributos (ese hilo tampoco puede crear ni mover scripts
  ni usar HttpService: para sincronizar codigo en ese caso solo queda el plugin
  de Rojo; `multi_edit` del MCP sirve para parches pequenos): `ServerStorage:SetAttribute("Prueba",
  "3:montonPiezas")` (número de orden + nombre|args) y el texto queda en el
  atributo `Resultado`; en el cliente `ReplicatedStorage` con `PruebaCliente` /
  `ResultadoCliente`. El número evita ejecuciones dobles con señales diferidas.
- Multijugador: Studio → Test → *Clients and Servers* (2 jugadores). Ver
  `README-pruebas.md`.

## 3. Decisiones no obvias (y por qué)

### Diseño v2: recoger y lanzar (26 sep)

El documento de diseño v2 (@FND, 26 sep; en `docs/GDD.md` a partir del lote
10) centra el juego en recoger y lanzar: elegir cuadrante → excavar y
escalar → recoger → lanzar (bonus por distancia y racha) → cobrar → mejorar
y renacer. Sin base, sin limpieza y sin gestión de mascotas; rebirths que
abren zonas nuevas; pases que no hacen el trabajo por el jugador. (El
documento separaba los cuadrantes por material y daba las mascotas en
cápsulas; el usuario lo cambió el 29 sep, ver abajo.)

**Decisiones del usuario:** lo marcado "Se quita" se **borra** (git guarda la
historia; la regla anterior de "apagar con banderas y no borrar" era del
recorte de la auditoría); lo "Se pospone" queda tras `GameConfig.FUNCIONES`
(`FIGURINAS`, `CINTAS`, `TRAJES_BOTIN`); al quitar las parcelas el mapa se
recorta por el oeste; entrega por lotes verificados en Studio.

**Plan por lotes** (cada uno termina con consola limpia, pruebas en verde y
este documento al día):

| Lote | Qué | Estado |
|---|---|---|
| L1 | Retirada de lo quitado, perfil v3, aparición en la plaza, 4 mejoras, Brazo limita el tiro | hecho |
| L2 | Mundo v4: sin parcelas ni máquina, mapa recortado al oeste, 3 ranuras por cuadrante con `Cuadrante`/`Material`, barreras "Rebirth 1/2", suelo por material (v5 el 29 sep: `Zona` en vez de `Material`, sin carteles por fila, horneado) | hecho |
| L3 | Patio por material: generador por material (billete 5 % ×6, tesoro 1 % ×40), prioridad del excavador 10 s, reposición 45 s por montón, bloqueo por rebirth (grupos de colisión por nivel). El 29 sep, zonas revueltas | hecho |
| L4 | Rebirths: requisitos, multiplicador, panel | hecho |
| L5 | Lanzamiento y pago: bonus por distancia, racha, "el primero siempre entra", línea de trayectoria (5 primeros), récords, fórmula de pago | hecho |
| L6 | Mascotas y cápsulas: medidores por material, pity por set, niveles, huecos, imán, Rey, panel Mascotas y ventana de cápsula. El 29 sep, fragmentos en vez de cápsulas | hecho |
| L7 | Pedidos diarios y 16 insignias | pendiente |
| L8 | Tienda, pases y cosméticos (Dinero x2, Tercera mascota, Bolsa XL, estelas, diseños de bolsa, Turbo) | pendiente |
| L9 | Tutorial "primeros 15 minutos" y cámara primera/tercera | pendiente |
| L10 | Medición (viaje y acierto) y documentación (GDD v2, Juego.md) | pendiente |

**Qué se borró en el L1 y por qué:** energía y refrescos (peaje sin
decisiones), gemas, Sobre, Contenedor Dorado, Pase de la Suerte y Montón extra
(riesgo con la política de objetos aleatorios de pago), limpieza, ensamblaje,
fragmentos, estados, fusión, venta, almacén (seis capas de gestión sin uso
jugable), parcelas, podios, vitrina, radio, "Me gusta" y teletransportes (sin
base), el panel de logros y su dinero (vuelven como 16 insignias), mejoras
Energía, Chispa, Almacén e Imán (el imán pasa a las mascotas), pases de
Velocidad e Imán (servirían para quitarle piezas a los demás en el patio
compartido), el bonus +25 % por bolsa llena (el riesgo y el premio están en
la distancia del tiro) y la mascota garantizada / el pity de los montones (las
mascotas salen de cápsulas). Servicios borrados: `Parcelas`, `Mascotas`,
`Acompanante`, `Reparacion`, `Energia`, `Logros`, `Tienda` (y sus Handlers);
17 RemoteEvents; `DefinicionesLogros`, `ProgresoLogros`; los paneles Álbum,
Base, Logros, Reparación, Montón extra y Probabilidades. Prueba `sinRestos`.

**Cambios del 29 sep (el usuario, tras jugarlo: "no me siento a gusto con
el juego"):**
- *"No me gusta que los montones ya estén separados por tipo de basura."*
  Todos los montones traen los cuatro materiales revueltos
  (`TablasProbabilidad.MEZCLA`). Elegido por el usuario entre tres
  opciones: las zonas del norte siguen tras las barreras de Rebirth 1 y 2
  pero son **más ricas** (55 % metal u orgánico, que pagan 3–5 veces más que
  el papel). El patio abierto (45/40/10/5) deja la bolsa inicial en ~$125,
  como antes con plástico. `GameConfig.CUADRANTES` pasa de `material` a
  `zona`; los sets de mascotas se abren por su propio `rebirth`
  (`DefinicionesMascotas.SETS`), ya no por el cuadrante.
- *"La mascota se obtiene demasiado rápido"* y *"las mascotas deberían
  recolectarse por fragmentos que se encuentren en los montones de
  basura".* Fuera las cápsulas, sus medidores y su pity por cápsula
  (`Services/Capsulas`, `CapsulaEvent`, `AbrirCapsulaEvent`, `UI/Capsula`);
  entra `Services/Fragmentos`. Decisiones mías (revisables): **una mascota
  a la vez por set**, decidida por el primer fragmento (así cada fragmento
  cuenta y se ve a quién montas, en vez de fragmentos sueltos de 10
  mascotas); **5/8/12 fragmentos** por rareza; **la primera, Común con 3**
  (llega hacia el minuto 6–8, el gancho de los primeros 15 minutos);
  **2,5 %** de fragmentos por pieza y uno seguro en el montón grande; el
  fragmento **cuenta al reciclarlo** (ocupa hueco, como todo: "el contenedor
  es el único camino"); uno de un set cerrado para quien lo recicla se paga
  como un billete; el premio de los pedidos pasa a **2 fragmentos libres**
  del set que elijas y se abren con la primera mascota.
  **Calibración:** `simularSet` da una mediana de 240 fragmentos (37
  mascotas empezadas: la cola la ponen las 3 Épicas) para completar un set;
  a 2,5 % son ~9.600 piezas de ese set. Es un recorrido largo a propósito
  (el usuario lo quería más lento), pero hay que medirlo con jugadores.
- *"Quita los diálogos de Doña Chatarra."* Fuera la caja de diálogo con
  retrato (`UI/Dialogo`), sus tres consejos (`Textos.NPC`) y `DialogoEvent`.
  Su prompt pasa de "Hablar" a "Tienda" y abre el panel directamente desde
  el cliente (`Prompts.client`); `SetupMundo` cambia el texto del prompt en
  un place horneado antes. El tutorial del L9 no usará diálogos.
- Tras probarlo en el emulador de teléfono: fuera la **tarjeta del
  tutorial** de abajo ("Primeros pasos 3/5 · Recoge basura…", con "Abrir
  Tienda"); el tutorial sigue avanzando en el servidor y la flecha guía,
  y el L9 decidirá cómo se explica cada paso. Los **avisos (toasts) van
  arriba en el centro** (a 122 px caían a media pantalla en el móvil, que
  mide ~490 px de diseño); en táctil se centran en el hueco entre la
  botonera y los contadores, medido en pantalla, y el **feed** se pone
  bajo los contadores (pegado al borde tapaba las barras). Las **manos y
  la bolsa en táctil** van a 0,6 de tamaño y más abajo
  (`Manos.client`, `AJUSTES.tactil*`). Pendiente visto en la prueba: la
  pista "Toca la basura para recoger" se solapa con las barras de bolsa y
  fuerza (`("hud")` lo avisa), en táctil y en escritorio.
- Más cambios del usuario tras la prueba en el móvil: la **retícula también
  en táctil** (antes se ocultaba porque en el móvil se recoge tocando la
  basura), y en táctil **elige la mira, no el dedo**: mientras un dedo
  arrastra la pantalla para mover la mira se recoge lo que pasa por ella y
  está al alcance; sin dedo no se recoge nada (una versión intermedia
  recogía sola solo con apuntar y el usuario la rechazó: "quiero poder mover
  el puntero"). El reclamo va con origen "mira" (reglas del clic, sin avisos
  de rechazo, que al barrer un montón ajeno saldrían sin parar). Lanzar apunta a la mira (antes, por el último toque, que era el
  del botón). El juego va **siempre en horizontal** en el móvil
  (`ScreenOrientation = LandscapeSensor` en StarterGui y en el PlayerGui;
  el place tenía `Sensor` y arrancaba en vertical); **solo se lanza con la bolsa llena** (regla del cliente: el botón
  y la pista solo salen entonces; el servidor sigue aceptando una a medias,
  que no da ventaja); la **bolsa fallada ya no se recicla sola**; y los
  **iconos de la botonera** pasan de 76 a 88 px.

**Decisiones mías donde el documento no concreta** (revisables):
- Perfil v3 con DataStore nuevo y **sin migración**: el juego nunca se
  publicó, no hay perfiles reales.
- Las 40 mascotas son las del juego original (commit `fd601a9`, 4 C / 3 R /
  3 É por set) sin Resistencia ni Poder; el modelo cambia por nivel (4 brilla,
  5 luce como la antigua "Perfecta"). Siluetas propias: pendiente de arte.
- Aparición: `AparicionHandler` con `CharacterAutoLoads = false` (también en
  `default.project.json` e `instalar-desde-http`): el personaje no existe
  antes que su perfil.
- Productos de Robux: `Monetizacion.registrarProducto(id, otorgar)`; cada
  servicio registra el efecto de lo suyo (así Monetización no depende de
  todo lo que se vende).
- `SetupMundo` apaga los prompts de parcelas y máquina de refrescos si un
  place anterior al mundo v4 aún los tiene.
- Mundo v4 (L2): las barreras son paredes de cristal (60 % transparente) del
  color del material que destaca en su zona, con postes y travesaños de obra; se probó un campo de
  fuerza (`ForceField`) y de día casi no se veía. Las colinas usan la malla
  IA `ServerStorage.Arte.Monton`, que no admite tinte: la zona se lee por
  el **suelo de cada cuadrante** (losa decorativa `SueloCuadrante`: tierra en
  el patio abierto, el color del material en las zonas del norte; en el v4,
  cada cuadrante con su material y un poste por fila, quitados en el v5).
  El cartel de cada barrera va adelantado 3 studs hacia la cámara
  (`StudsOffset` Z): en el plano de la pared, el cristal lo tapaba al
  mirarlo de frente (en el v4 solo se veía en diagonal).
- Patio por zonas (L3): el tamaño de cada montón sale del atributo de su
  ranura y la zona de `GameConfig.CUADRANTES` por su cuadrante; en un place anterior al v4 el cuadrante se
  deduce de la posición (`Cuadrantes.en`). `ObjetosPatio.puedeReclamar` es la
  única regla de "¿me lo puedo llevar?" (bolsa ajena, cuadrante cerrado,
  prioridad del excavador) y la comparten el clic y el imán.
- Lanzamiento (L5): el arco se calcula en `Utilidades/Trayectoria`, el mismo
  módulo para el servidor (que decide) y la línea del cliente. El HUD
  muestra sobre la barra de fuerza el bonus que daría acertar desde donde
  estás. El récord del servidor es de la sesión (en memoria); el personal
  (`mejorDistanciaAcierto`) persiste. `Comunes.yaLanzo` da por hechos los
  primeros lanzamientos en las pruebas que necesitan fallar.
- Bloqueo por rebirth (L3): grupos de colisión por nivel de rebirth en el
  servidor (`PersonajeR0/R1/R2` contra `BarreraR1/R2`), no un script de
  cliente: funciona con streaming y lo decide el servidor. La autoridad sigue
  en excavar/reclamar/imán.
- Montón terminado (L3): al bajar del 25 %, a los 45 s se retiran sus restos
  y vuelve la colina (hoy no se repone mientras quede una pieza).
- Racha (L5): +10 % por acierto contando el primero, tope +50 % desde el
  quinto; un tiro desde menos de 10 studs ni da bonus ni toca la racha;
  entregar a mano no la toca; fallar la pone a 0. "El primero siempre
  entra": el primer lanzamiento del perfil apunta solo al contenedor.
- Fragmentos (29 sep): tirar la rareza, elegir la mascota y empezar un
  montaje son funciones puras sobre el perfil (las pruebas las tiran miles de
  veces con uno de mentira). Medido (`rarezaOdds`, 20.000 tiradas): con los
  dos pity las tasas reales son ~61/31/8 (la garantía de "Rara o mejor"
  también puede dar Épica). Los avisos (cada fragmento reciclado, la
  revelación al completar, el feed de Raras y Épicas) los manda
  `MascotasHandler` escuchando `Fragmentos.alAgregar`.
- La ventana de revelación es un panel de `Menu` ("Revelacion"): así el ratón
  se libera en primera persona; varias a la vez van en cola.
- Seguidores (L6): los modelos los mueve el servidor en cada Heartbeat
  (anclados, sin colisión ni raycast), con etiqueta del nombre; se rehacen
  al cambiar las equipadas o su nivel.
- Pedidos (L7): se abren con la primera mascota completada; retos
  adaptados al brazo y a los sets abiertos; recompensa provisional
  250/500/900 × multiplicador; los tres del día dan 2 fragmentos libres.
- Pases en Studio (L8): `PASES_DEV_EN_STUDIO = false` por defecto, para que
  las pruebas midan el ritmo sin Dinero x2 (`/pases on` para probarlos).

### Recorte por la auditoría (26 sep, sustituido por el Diseño v2)

Una auditoría externa de diseño concluyó que el juego repartía el esfuerzo
entre muchos sistemas que no se refuerzan entre sí: lo que lo distingue es
la montaña física y el lanzamiento; las mascotas no pintaban nada en el
bucle; la energía era un peaje sin decisión; el montón chico rendía ~40 %
más por pieza que el grande; no había onboarding; y el Sobre, las Gemas, el
Pase de la Suerte y el Montón extra chocan con la política de "paid random
items" de Roblox. Se apagó todo eso con banderas, la colección bajó a 10 con
acompañante y se añadió el tutorial. El Diseño v2 del mismo día recoge esas
conclusiones y va más lejos (arriba): las banderas de lo quitado y su código
se borraron. Sigue vigente de aquí: la bolsa fallida es solo de su dueño y
al salir la bolsa se recicla sin bonus.

### Arquitectura del patio (lote 7: limpieza)

`Botin.luau` llegó a 1.060 líneas con siete responsabilidades. Se partió en
módulos de una responsabilidad, sin ciclos, y `Botin` quedó como **fachada**
(lo único que `BotinHandler`, `Admin` y las pruebas importan):

| Módulo | Responsabilidad | Depende de |
|---|---|---|
| `TiposPatio` | solo tipos (`Item`, `Monton`, `Objeto`) | `ModelosMonton`, `Bolsa` (tipo Item) |
| `GeneradorBotin` | qué sale de un montón (pity, lotes, relleno); devuelve items | Perfiles, Mascotas, Coleccionables, Monetizacion |
| `ObjetosPatio` | registro de objetos, `modeloPara`, reclamo atómico, vuelo a la bolsa; publica `alRetirar` | Bolsa, Economia, Perfiles, Mejoras |
| `FisicaBasura` | soldar/soltar/anclar, cascada, bucle de asentar | Colisiones, ObjetosPatio (lee), `alRetirar` |
| `Montones` | colina → montaña → agotado → repoblado; `excavar` | GeneradorBotin, ObjetosPatio, FisicaBasura, Energia, Mundo, `alRetirar` |
| `Iman` | la única recogida sin clic | ObjetosPatio, FisicaBasura, Montones |
| `Lanzamiento` | la puntería | ObjetosPatio, Bolsa, Mundo |

La regla que evita ciclos: **quien retira un objeto no sabe quién lo cuenta**.
`ObjetosPatio.reclamar` dispara `alRetirar`; `Montones` descuenta y agota,
`FisicaBasura` despierta a los vecinos. Antes `quitarObjeto` llamaba a los dos
a mano y cualquier módulo nuevo tenía que tocar `Botin`.

Lo mismo en `Utilidades`: `ModelosMascota` (830 líneas) se partió en
`Primitivas` (los ladrillos y la etiqueta), `ModelosMascota` (mascotas y
fragmentos), `ModelosObjetos` (basura, tesoros, coleccionables, bolsas) y
`ModelosMonton` (la colina y sus puntos). `Geometria.distanciaASuperficie`
es una sola función para servidor y cliente: antes cada uno tenía su copia y
un desajuste habría hecho que el cliente resaltara lo que el servidor rechaza.

Las pruebas (`PruebasDefinidas/`, carpeta con `init.luau`) están por área:
`Patio`, `Bolsa`, `Progreso`, con `Comunes` para los ayudantes; `init` las
junta en una tabla y falla si dos áreas repiten un nombre.

Se quitaron las señales sin suscriptores (`alReclamar`, `alActivar`,
`alAcertar`, `alReciclarLanzando`), `alturaMonton`, el parámetro `escala`
de `parametrosColina` (la colina ya no encoge) y el estado de física que
vivía dentro de cada `Objeto` (ahora es una tabla privada de `FisicaBasura`).

### El reclamo compartido es atómico sin locks

`ObjetosPatio.reclamar` comprueba `obj.reclamadoPor` y lo asigna en la misma llamada,
sin ningún yield entre medias. Luau es monohilo: dos reclamos "simultáneos"
(dos eventos de red, o el bucle del imán de dos jugadores) siempre se resuelven
en orden. El perdedor ve `noExiste` (el objeto ya se retiró del registro), no
`yaReclamado`: sólo hay ventana para `yaReclamado` si la bolsa del ganador
estaba llena y se liberó el bloqueo. Prueba: `reclamoAtomico`.

### Nada se recoge por pasar encima: clic, o el Imán

Decisión del usuario (lote 4): sin la mejora Imán **nada** entra en la bolsa
por cercanía; cada objeto se recoge con clic, y **manteniendo el clic** (dedo
en táctil, X en gamepad) se recoge en cadena lo que pase por la mira, una
pieza cada `INTERVALO_RECOGIDA` (0,16 s ≥ `COOLDOWN_REMOTE`, lo que el servidor
acepta por jugador; el mismo id no se reenvía hasta que el servidor lo retira
y el objeto que vuela a la bolsa deja de ser consultable por el rayo, así el
siguiente entra al instante) (`ReclamarObjetoEvent` →
`ObjetosPatio.reclamar(..., "clic")`), validado en el servidor por distancia del
personaje a la **superficie** del objeto ≤ Alcance + 2 (medir al centro engaña
con modelos grandes; el cliente mide igual para el resaltado). El bucle cada
0,2 s solo sirve al Imán: dentro de su radio suelta el objeto de la colina y
lo arrastra con `PivotTo`, y cuando un objeto **arrastrado** llega a
`DISTANCIA_RECLAMO_IMAN` lo mete en la bolsa. No se usa `.Touched`. Al
reclamar, el modelo vuela 0,25 s al torso del jugador (feedback del clic) y se
destruye al llegar. La bolsa caída también se recoge con clic.

### El pity es por jugador y persiste

Cada monton sin Rara+ suma 1; una Rara+ lo resetea. La probabilidad se calcula
en `TablasProbabilidad.probabilidadRara` (8% + 2%·pity, tope 60%; el Pase de la
Suerte sube el paso a 3%). Medido con 300 montones grandes: pity 0 → 6%, pity
10 → 37%, pity 26 → 57% (teóricos 8/28/60). Los fragmentos usan tabla plana con
sesgo del 50% hacia mascotas a medias para que el ensamblaje converja.

### `TablasProbabilidad` es la única fuente de odds

Servidor (`Tienda`, `GeneradorBotin`) y cliente (`Probabilidades`) leen el mismo módulo
de ReplicatedStorage; `verificar()` hace assert al cargar de que cada tabla
suma 100. Es el requisito de política de Roblox sobre ítems aleatorios pagados.

### Persistencia propia, sin ProfileStore

Cero dependencias (no hay Wally). Reglas: todo en `pcall` con reintentos; un
perfil que no cargó nunca se guarda (`Perfiles.estaCargado`); `UpdateAsync`;
autosave 120 s; `PlayerRemoving` espera 0,2 s para guardar DESPUÉS de que
Bolsa/Parcelas toquen el perfil. Sin bloqueo de sesión: migrar a ProfileStore
si algún día hay servidores concurrentes escribiendo el mismo perfil.

### El dinero sólo sale del contenedor (lote 8)

Decisión del usuario: **recoger nunca paga**. Todo lo que se levanta del patio
(basura, billetes, tesoros, mascotas…) ocupa un hueco de la bolsa y sólo se
convierte en $ al depositarlo (prompt del Contenedor o bolsa lanzada), las dos
vías por `Bolsa.depositarItems` con `Bolsa.valorDeposito(item)` como única
tabla de precios. Consecuencias:

- Los billetes ya no dan "+$" al tocarlos: son un objeto más (`billeteEnBolsa`).
  El Imán tampoco los excluye del corte por bolsa llena.
- El **Pase Auto-Reciclaje** del GDD (basura → $ al recogerla, sin ocupar
  hueco) se retiró de `Config/Productos`: era exactamente lo que la regla
  prohíbe, y en Studio (`PASES_DEV_EN_STUDIO`) hacía que la basura
  "desapareciera en dinero" sin llenar la bolsa, que fue lo que el usuario vio.
- El HUD no muestra `n/cap`: la bolsa es una **barra vertical junto a la de
  fuerza** que se llena, y en rojo pulsando dice "¡LLENA!" (`Textos.HUD`).
  La bolsa 2D de las manos también crece con el llenado.
- Siguen dando $ sin pasar por el contenedor: vender mascotas/duplicados a
  Doña Chatarra (en la caseta) y la recompensa de cada logro. No son botín.

### La bolsa no persiste, y al salir se recicla sin bonus

Al desconectar (`Bolsa.reciclarSinBonus`): lo que vale dinero se paga SIN el
+25 % ni el +50 %, y mascotas, fragmentos y coleccionables van al perfil si
caben. Las bolsas propias que estén en el suelo, igual. Hasta el 26 sep el
dinero se perdía (se temía un atajo: salir y volver en vez de caminar al
contenedor); la auditoría lo revirtió porque castigaba las caídas de
conexión, y sin bonus y con la vuelta a entrar el atajo no compensa.

### Las pasivas sólo actúan exhibidas (apagadas desde el 26 sep)

Las 6 mascotas del exhibidor daban +2/4/6% al reciclar su material. Con
`FUNCIONES.EXHIBIR_PASIVAS` apagada exhibir es solo para presumir; el efecto
jugable de una mascota es llevarla de acompañante.

### Modo dev de pases

En Studio, `GameConfig.PASES_DEV_EN_STUDIO` hace que todos los Game Passes
cuenten como comprados sin tocar el perfil (viaja en `extras` del snapshot, no
en `pasesCache`, para no envenenar perfiles). `/pases off` lo apaga para probar
sin ellos. Los ids reales (0 = placeholder) se rellenan en `Config/Productos` y
`Config/DefinicionesLogros` (badges) al publicar.

### Arte del mundo por capas (16 sep)

Decisión del usuario: "modela todo el juego, dale color como en KOTAMON,
usando solo el MCP de Roblox" → low-poly de partes + IA del MCP para
materiales y dos props. La regla que lo hace barato y seguro: **el whitebox
sigue siendo el esqueleto funcional** (tags, atributos, prompts,
`ZonaAcierto`, colisiones, tamaños intactos) y el arte es una capa
`SoloDecorado` sin colisión ni query alrededor (`ArteMundo`), más pintura de
materiales sobre las cajas que se ven. Ninguna prueba ni servicio distingue
el mundo vestido del desnudo (verificado: `estado`, `excavar`, `reclamarTodo`,
`lanzarBolsa`, `depositar`, `parcela`, `irCasa` en Play sobre el mundo v2).

- Los grises del whitebox (110 suelo, 140 montones, 165 muros, 195 losas,
  215 muebles, 240 caseta) siguen en `Paleta` como respaldo; `Paleta.MUNDO`
  es la paleta de arte y `Paleta.LOSA_PARCELA/MUEBLE/MUROS` pasan a madera
  porque `Parcelas.pintar` repinta con ellos las partes `Pintable` sin skin.
  Objetos y mascotas siguen con color por material y disco de rareza (set y
  rareza son información de juego); sin neón en el mapa.
- Montones intactos: **montañas de escombros** (petición del usuario, 16 sep,
  con foto de referencia: ni bolas lisas ni pirámides puntiagudas). Cada
  montón es un pico principal + 2–3 secundarios; cada pico, una bola grande
  hundida que da el bulto, bolas medianas apiñadas en la cima y bolas de
  tamaños varios medio enterradas por la falda, con `Rock` + variante
  `MontanaBasura` y tono por bola (~40–55 partes por montón, sin sombra).
  Perfil para colocar la basura: cono redondeado `h·(1−d/r)^1.6`. Radios
  9/12/17 (antes 7/10/14). Se probaron capas de cilindro (parecían una
  tarta), pirámides de `CornerWedgePart` y una malla IA (`generate_mesh`
  dio cajas apiladas sobre un disco, no escombros; `ModelosMonton` la
  usaría si existiera `ServerStorage.Arte.Monton`). Las partes siguen
  llamándose `Loma_…` porque `Montones` y las pruebas las reconocen por ese
  prefijo. La basura se reparte en el 60 % de la altura y en el 65 % del
  radio: cayendo desde más de ~8 studs se clavaba en el suelo, y apretada se
  asienta antes que suelta por el suelo. `Patio.Suelo` pasa a 4 studs de
  grosor por lo mismo; agotado = parches `Ground`. La basura real coge colores
  vivos de `Paleta.BASURA` y material de Roblox por tipo (latas `Metal`,
  cartón `Cardboard`, neumáticos `Rubber` negros).
- Caminos: `Ground` base sin variante a propósito (las cuatro tandas de IA
  salían agrietadas y naranjas). Suelo, baseplate y parcelas: `SmoothPlastic` liso, sin variante (el usuario no quiso textura de césped ni de madera en las bases: look minimalista).
- La caseta mira a +Z (el patio): la cara visible de sus letreros es la
  `Back` de Roblox (`CARA_PATIO` en ArteMundo); un letrero por cara
  (`LetreroFront`/`LetreroBack`) para que las tablas se lean por los dos
  lados.
- Las cuñas (`WedgePart`): la cara vertical es la trasera (+Z local) y la
  rampa baja hacia -Z; el tejado a dos aguas son dos cuñas, la del frente
  girada 180°.
- Los cables de los postes son `Beam` entre Attachments con `CurveSize`
  negativo (comba).
- Iluminación cartoon en `ConstructorMundo.iluminar()` (idempotente) y
  reflejada en `default.project.json`; `Technology` es de plugin y desde el
  MCP ni se lee, por eso va en pcall.
- Fuera de alcance de esta pasada: las 41 mascotas (siguen siendo primitivas
  por set/rareza, y el álbum depende de ese vocabulario), el avatar, sonidos.

### Recicladora de Blender (22 sep)

El contenedor verde y la trituradora de partes se sustituyen por un modelo
hecho en Blender (referencia: capturas de KOTAMON): volquete verde,
trituradora amarilla con rodillos dentados, cinta en L que sale de una caja
gris junto al volquete, y salida con rampa por la que caen bloques prensados.

- Fuente: `assets/3d/Recicladora.fbx` (el `.blend` es del usuario, fuera del
  repo). Se exporta con escala de unidades 0,01 y «FBX All»: el importador de
  Roblox lee centímetros como studs, y con la escala por defecto el modelo
  salía 100 veces más grande. Piezas fijas unidas en una malla por color;
  las móviles, sueltas en `Trituradora.Moviles` con el pivote en su eje.
- En el place: `ServerStorage.Arte.Recicladora` (hijos `Contenedor`,
  `Trituradora`, `Bloque`). El importador pierde los colores de Blender, así
  que `ArteMundo.recicladora` pinta cada malla por el sufijo del nombre
  (`Trituradora_Amarillo`…). Sin la malla, `ConstructorMundo` usa el decorado
  de partes de antes (`contenedorVerde` + `trituradora`).
- Decisiones del usuario: la recicladora entera, con el contenedor funcional,
  pasa de x=14 a x=22,5 local (la cinta y la caja chocaban con la cabaña) y
  la solera se ensancha hasta x=38. **Manda el modelo**: las paredes del
  contenedor funcional bajan de 6 a 4,7 de alto (la del volquete), para que
  los rodillos se vean por encima del borde; la bolsa se encesta un poco más
  fácil. Las paredes whitebox siguen colisionando y llevando el prompt, pero
  quedan invisibles.
- Animación (`Client/Recicladora.client`, datos en `Config/Recicladora`): los
  rodillos de la trituradora giran siempre; la cinta solo se mueve cuando
  alguien deposita. `Bolsa.alDepositar` → `BotinHandler` →
  `RecicladoraEvent:FireAllClients(materiales)`: salen hasta 10 objetos de
  `ModelosObjetos.basura` de la caja gris, recorren la L, caen en la tolva y
  después baja un bloque (clon de `BloqueMolde`) por la rampa. La ruta está en
  el marco del pivote del modelo (el suelo bajo el volquete, +Z al frente),
  sacada de las medidas del `.blend`: si se reexporta con otras medidas hay
  que recalcularla. Prueba: servidor `recicladora` + cliente `recicladora`.
- Colisión (petición del usuario): la malla sigue sin colisionar; la
  bloquean 19 cajas y losas invisibles (`Caseta.ColisionRecicladora`, datos
  en `Config/Recicladora.COLISION_*`, mismo marco que la ruta) que
  ConstructorMundo crea solo si hay malla. No se usó la colisión de las
  mallas porque cada una junta piezas sueltas del mismo color y su casco
  cerraría los huecos. Tienen `CanQuery`: la bolsa lanzada choca con ellas y
  el apuntado las ve. Las cintas y la rampa son losas inclinadas: se puede
  subir andando por la cinta hasta el techo.
- Bolsa lanzada con colisión (petición del usuario, atravesaba la máquina):
  `Lanzamiento` barre en cada paso una esfera de radio 0,7 (`Spherecast`)
  contra todo lo consultable salvo el contenedor y los `Limite`, que siguen
  con su rebote propio. Normal casi vertical = se posa y bota ahí; si no,
  rebota como en una pared. El decorado sin `CanQuery` (camión, cabaña de
  arte) sigue atravesándose, igual que lo atraviesa el jugador. La bolsa puede
  quedarse en el techo de la trituradora (se sube por la cinta).
  `lanzarBolsa` ahora lanza desde el frente del contenedor: desde detrás la
  máquina tapa el tiro.

### Plano v3 del mapa (16 sep)

El usuario pidió el plano de su boceto: las 6 bases en columna a la
izquierda, el patio de basura grande a la derecha, la recicladora de Doña
Chatarra debajo del patio, y **la valla que rodeaba el patio pasa a rodear
todo el mapa**. `ConstructorMundo` v3 (`LAYOUT`):

- El patio (200×200) **no se mueve del origen**: `Patio.posicionEnPatio`
  comprueba `|x|, |z| < PATIO_LADO/2`, así que se recoloca todo lo demás a
  su alrededor. Sin muros: es la explanada de césped claro un stud más alta.
- Recicladora al SUR (z 140–186, lote de tierra del ancho del patio) con la
  caseta mirando al norte. Como `ArteMundo` espera el frente en +Z local
  (`CARA_PATIO = Back`), `construirCaseta` construye todo sobre un pivote
  girado 180° (`en(x, y, z)`); las paredes del contenedor pasan a llamarse
  `ParedFrente/Fondo/Izq/Der`. La cara de Doña Chatarra está en +Z local de
  la cabeza, por eso el retrato del diálogo pone la cámara relativa a
  `Cabeza.CFrame` y no en +Z del mundo.
- Plaza del spawn (40×38, pegada al borde sur del patio, z 100–138); se
  aparece mirando a la caseta. `Mundo.posicionPlaza()` sigue siendo la
  fuente para "Ir al patio" y para las pruebas (`Comunes.fueraDelPatio()`
  en vez de un `(0,0,-130)` a mano).
- Parcelas en x = −150, z = {−87, −37, 13, 63, 113, 163}, mirando al este;
  calle de tierra en x = −116 con un ramal a cada entrada.
- Límite rectangular (`LAYOUT.LIMITE`, x −196..124, z −124..202): muro
  invisible de 60 studs (tag `Limite`, 4) y la valla de madera de 10 studs
  (no se salta: el salto llega a ~7,5)
  por dentro (sin árboles: se quitaron todos a petición del usuario y por
  rendimiento). El Baseplate mide justo el rectángulo del límite (320×326,
  centrado en −36, 39): fuera de la valla no hay terreno. Igual en el
  constructor, `default.project.json` e `instalar-desde-http`.
- El contenedor grande (escondite F3) pasa al fondo norte del patio para no
  tapar la entrada desde la plaza; F1 queda detrás de la caseta.

### Patio rectangular 97,5×150, 2x3 cuadrantes con 2 montones (22 sep)

Dos peticiones seguidas del usuario. Primero "recorta el mapa… solo 9
cuadrantes de 3x3… más montañas de basura, se ve muy vacío" (patio de 150,
montones **excavables**, no decorado). Después "reduce el patio un 35 % del
lado opuesto de las bases": el ancho oeste-este pasa de 150 a 97,5 (el
borde este de x = 75 a 22,5) y el patio queda rectangular. Eligió 2
columnas × 3 filas con una pareja por cuadrante y acercar la valla este.

- `GameConfig.PATIO = { oeste = −75, este = 22,5, norte = −75, sur = 75 }`
  sustituye a `PATIO_LADO`: el patio ya no es un cuadrado centrado en el
  origen. Lo leen `Patio.posicionEnPatio` y `ConstructorMundo`.
- Cuadrantes: el rectángulo partido en 2×3 iguales (~49×50; centros x
  −50,6 / −1,9, z −50 / 0 / 50), caminos en sus bordes interiores (x
  −26,25; z ±25). Cada cuadrante lleva una PAREJA en diagonal
  (`LAYOUT.PAREJAS_MONTON`: 3 grande+chico, 2 mediano+chico, 1
  mediano+mediano, barajadas con la semilla de siempre), con
  `SEPARACION_MONTONES` = 6 entre faldas y la pareja centrada.
- Montones más pequeños para que quepan dos: radios 7/10/13 (antes
  9/12/17), 12 en total (5 chicos, 4 medianos, 3 grandes). Con todo activo
  hay ~700 objetos y ~200 tiradas de premio. **Cada excavación rinde menos
  por la misma energía** (`COSTE_EXCAVAR` sigue en 10): vigilar.
- Mapa: límite x −171..46,5, z −99..177 (baseplate 217,5×276 centrado en
  −62,25, 39); plaza z 75–113 (spawn 96); lote de la recicladora z 115–161
  (caseta 133), en x desde el borde oeste del patio hasta 3 antes de la
  valla este: por el este solo quedan 11 studs entre la solera y el borde,
  así que el segundo camión se quitó. Parcelas en x −125, z {−78, −32, 14,
  60, 106, 152} (cada 46), calle en x −91.
- El decorado del patio y los escondites F2–F6 están en la franja de
  césped entre el patio y la valla (norte y este, suelo a y = 0): dentro ya
  no queda ningún punto a más de 20 studs de todas las ranuras.
- `enPatio` teletransporta a (−26,25, 0, 0), el camino entre columnas.
  `lanzarBolsa` lanza desde el frente del contenedor.

### `Mundo.Manual`: lo editado a mano sobrevive al horneado (16 sep)

El usuario editó el place a mano y un horneado posterior lo borró:
`construir()` destruye `workspace.Mundo` entero. Desde entonces
`limpiarPlace` aparta la carpeta `Mundo.Manual` antes de borrar y
`construir()` la vuelve a colgar del Mundo nuevo (si no existe, la crea
vacía). Regla: lo que se toque a mano en Studio va a `Manual`; si se mueve
una pieza funcional, avisar para que el constructor no la duplique. Y antes
de hornear, preguntar siempre.

### Rendimiento en móvil (16 sep)

Medido en Play con 3 montones grandes + 2 medianos activos (el caso malo
realista). Antes: 2.470 partes de mundo (todas con sombra) + 902 objetos de
basura ≈ 5.300 partes en `workspace`, ~3 partes por pieza con colisión y
masa cada una. Después: 1.336 partes de mundo (601 con sombra) + 733
objetos ≈ 3.640 partes, y solo el `Cuerpo` de cada pieza colisiona. Los
FPS de Studio no sirven de métrica (el cliente de Play va capado a ~15 fps
sin foco, con GPU a 0): la medida buena es en dispositivo con el menú de
Stats de Roblox. Qué se hizo y por qué:

- **Sin árboles** (petición del usuario): eran ~200 modelos y el anillo
  exterior no aportaba nada al juego. `ArteMundo.arbol/arbusto` y
  `construirArboleda` se borraron; la malla `Arbol` queda huérfana en el
  place.
- **Valla**: postes cada 6 studs y una tabla ancha por vano (el material de
  tablas dibuja las juntas) en vez de una tabla cada 1,25 studs: de ~1.350
  a ~440 partes para rodear el mapa.
- **Sombras**: `ArteMundo.parte` no proyecta sombra salvo `Sombra = true`
  (cabaña, tejado, trituradora, postes, barriles, neumáticos). La basura
  tampoco (`ModelosObjetos.basura`): cientos de piezas pequeñas cuya sombra
  no se lee.
- **Física de la basura**: se probó dejar solo el `Cuerpo` con colisión y
  masa (los detalles `Massless` y sin `CanCollide`) para ahorrar contactos, y
  se REVIRTIÓ: las piezas redondas sin aros ni tapones que las frenen rodaban
  segundos (`reacomodo` bajaba del 90 % anclado a los 5 s) y en mascotas y
  tesoros el "cuerpo" es solo el torso y se hundían hasta la cabeza
  (`montonPiezas`, bajo −1,5). Colisiona todo, como antes; el ahorro real
  vino de menos piezas por montón y de quitar sombras.
- **Montón grande** de 200–280 a 160–200 piezas (`GameConfig.TAMANOS_MONTON`);
  los lotes de premio no cambian, así que la economía tampoco.
- Mallas clonadas con `RenderFidelity = Automatic` y `CollisionFidelity =
  Box`.
- Pendiente y solo medible en dispositivo: FPS reales, tamaño de las
  texturas IA (ya solo `MontanaBasura`) y si en calidad baja, sin
  Bloom/ColorCorrection, el look sigue gustando.

### Interfaz en Fusion con estilo "UI Kit" (23 sep)

- Toda la UI se reescribió en **Fusion 0.3** (decisión del usuario). Fusion
  vive copiado en `Packages/Fusion`; el Kit (`Client/UI/Kit`) sustituye a
  `Componentes`. Estilo del "UI KIT GENERAL" de DEValen (capturas del
  usuario): el kit no está en la Creator Store, así que se imitó el estilo y
  los iconos salen del set gratuito "Simulator Icon Pack" (muy parecido).
- **Las copias de ese set en la Toolbox traían scripts maliciosos
  escondidos** (dentro de `UIStroke`, nombres tipo `CoreSkyboxSystem`,
  `LightConfig`, `BloomDefect.Protocol`). Se insertaron en
  `ServerStorage.CuarentenaIconos`, se borraron todos los scripts, se
  apuntaron solo los ids de imagen en `Config/Iconos` y se borró la
  cuarentena. Cualquier modelo gratis: mismo protocolo.
- Rendimiento: el perfil llega hasta 4/s como tablas nuevas. Las pantallas
  derivan primitivos con `Computed` (Fusion corta la propagación si no
  cambian) y recorren definiciones de Config. El Álbum construye el modelo
  de una tarjeta la primera vez que su set se ve (`("panel","Album")`
  informa de `modelosConstruidos`).
- Los pasteles del 23 sep se sustituyeron por los colores intensos del kit
  (`Paleta.UI_KIT`, fijo por nombre de botón; semánticos rojo/morado/verde);
  los studs se quedan como fondo (el kit usa un damero).
- El **suelo** también lleva studs (`ArteMundo.studsSuelo`): una Texture
  con la imagen `studs` en la cara de arriba del baseplate, el patio, los
  caminos y el lote de tierra (con sus manchas), la solera, la plaza, el
  spawn y las losas de las parcelas. Una baldosa cada 4 studs = un relieve
  por stud (a 8 se veían grandes). Va en el horneado; en el place actual se
  aplicó sin rehornear, cargando ArteMundo con el shim de
  `hornear-desde-mcp` y llamando solo a `studsSuelo`.

### Interfaz "papel y tinta" (lotes 9–11, 15 sep; sustituida el 23 sep)

- Tema claro tipo pegatina (crema + contorno de tinta + sombra dura) con
  FredokaOne/Nunito, en `Componentes` v2. Un hijo no puede pintarse detrás
  de su padre, así que cada pegatina/botón es un envoltorio `{Sombra,
  Cuerpo}`; los botones devuelven el cuerpo (TextButton) y su envoltorio es
  `.Parent`. La escala del hover va en el cuerpo para no mover los layouts.
- Iconos por registro: `Config/Iconos` (id 0 = respaldo dibujado con
  `Utilidades/Glifos`); el arte 2D del usuario va en `assets/ui/<clave>.png`
  (brief en `assets/ui/README.md`) y se sube con `upload_image` del MCP.
- Táctil: el thumbstick y el salto de Roblox ocupan las esquinas de abajo →
  dock arriba-centro, retrato junto a las píldoras, botón de lanzar de
  ContextActionService restilizado. `Entrada.forzar()` +
  `EjecutarPruebaCliente:Invoke("plataforma","tactil")` para capturar sin
  dispositivo; `("hud")` avisa de solapes.
- Los modales miden mín(máximo de diseño, 94 % del viewport ÷ escala): caben
  en un teléfono sin diseñar dos veces.
- Prompts: `Style = Custom` puesto **localmente** por el cliente a todos los
  ProximityPrompt (sin re-hornear ni tocar el servidor) y pegatina propia en
  `PromptShown`. Medido en Studio: un BillboardGui con `AlwaysOnTop = true`
  (o en PlayerGui) no se pintaba; va dentro de la parte y sin AlwaysOnTop,
  flotando por encima del tope del modelo.
- Los carteles flotantes horneados se restilizan en el cliente (`Escena`) y
  miden en studs para encoger con la distancia; el texto de los de parcela lo
  sigue poniendo el servidor.
- El saludo de Doña Chatarra abre la tienda al **descartar** el diálogo (como
  Jenny), no por debajo de él; si se cierra solo por tiempo, no abre nada.
- FredokaOne no trae "✕": la X de cerrar es una "X".

### Replicación del mundo en el cliente

`workspace.Mundo` aparece en el cliente antes que sus 1.191 descendientes.
Cualquier script de cliente que busque muebles debe escuchar `DescendantAdded`
(ver `Escena.client.luau`); una pasada única al arrancar se queda corta.

### ⚠️ `Model.WorldPivot` se ignora si hay `PrimaryPart`

Medido en Studio: asignar `WorldPivot` a un modelo con `PrimaryPart` no hace
nada; el pivote sigue siendo la parte principal. Durante el lote 1 todos los
modelos "en el suelo" (montones, objetos, mascotas) se colocaban con `PivotTo`
y quedaban HUNDIDOS la altura de su parte principal: por eso los montones se
veían como bloques pequeños (solo asomaba la cima). Lo correcto es
`PrimaryPart.PivotOffset = PrimaryPart.CFrame:Inverse()`
(`Primitivas.pivoteEnSuelo`). Cualquier modelo nuevo debe pasar por ahí.

### La colina se convierte en una montaña de basura, y no caduca

Un montón sin activar es una **colina lisa** (`ModelosMonton.monton` →
`parametrosColina` + bolas hundidas `Loma_i`: una principal y 2–3 lomas
secundarias hacia el borde, semilla fija por montón). Radio = el de
`TAMANOS_MONTON`, altura ∝ `numPiezas`. El usuario quiere ponerle después una
textura de basura; con primitivas eso será un MeshPart, hoy es gris
`Paleta.MONTON`.

Al activarlo, la colina **se sustituye entera por una montaña de basura con
su mismo bulto** (decisión del usuario, lote 5: "mucha basura, equivalente al
tamaño del montón, no un poquito"): `numPiezas` objetos (hoy 18–24 / 45–60 /
90–115 según tamaño; eran 30–40 / 80–110 / 160–200) con **modelo real** (latas, llantas, barriles, botellas,
bidones, cajas de cartón, periódicos, plátanos, huesos… y los premios:
mascotas, fragmentos, tesoros, billetes, coleccionables; sin etiquetas)
repartidos por TODO el volumen del casquete (`puntosEnColina`: muestreo
"mejor candidato" sesgado hacia la capa exterior para que no se vea el
interior), revueltos (giro libre, inclinación ±40°), brotando de abajo arriba
en 1 s. Una grande son ~270 objetos / ~800 partes.

**Premios por lotes**: `TAMANOS_MONTON[t].lotes` (hoy 8–10 / 20–24 / 38–46
tras el reequilibrio del 26 sep) son las tiradas de `TIPO_OBJETO`; el resto hasta
`min/max` es basura de relleno. Así la cantidad de basura no multiplica
mascotas ni fragmentos. La basura sí vale dinero: un montón da ahora 3–6×
más $ que antes (ver §4, calibración pendiente).

**La basura tiene física** (lote 6, "¿por qué se queda flotando? colócale
física"): cada objeto es un modelo soldado a su parte principal, sin anclar,
**mientras cae** en el grupo de colisión `Basura` (`Services/Colisiones`:
choca con el suelo y con otra basura, no con los personajes: una lluvia de
270 piezas no debe empujarlos ni encajonarlos). Las lomas de la colina se
destruyen al activar (chocarían con la basura). Lo que lleva ~1 s quieto se
**ancla y pasa a Default** (`FisicaBasura`, cada 0,5 s; tope 8 s por si algo
rueda): la basura asentada **sí choca con los personajes** y la montaña se
sube como escombros (decisión del usuario: "no quiero traspasar la basura");
nunca se ancla una pieza con un personaje metido en su caja
(`personajeEncima`), que quedaría encajonado. El objeto que vuela a la bolsa
va sin colisión. Así el servidor tampoco simula cientos de cuerpos, y
al recoger una pieza se **despiertan** las vecinas de encima (radio 5), que
caen y se vuelven a asentar; una pieza suelta que se mueve > 1 stud despierta
a su vez a las suyas (cascada). `SetNetworkOwner(nil)`: lo simula el servidor,
nadie empuja basura desde su cliente. Con física la montaña asienta más baja
y ancha que la colina (grande: ~5,5 de 10 studs): se compensa con fricción 2 y
lluvia de abajo arriba en 1,5 s. Con 0 objetos → `agotado` (marcas planas
`Resto`).

Historia: lote 2, las piezas rodaban al suelo ("aparecía muy poca basura");
lote 3, cono de bloques que se convertían en sitio ("son bloques, no basura de
verdad", y se recogían al pasar); lote 4, basura real clavada sobre la colina
que encogía ("me gusta cómo colocaste los montones, pero que se reemplace del
todo por basura"); lote 5, montaña de basura anclada sobre suelo invisible
("se queda flotando"); lote 6, física.

`ModelosObjetos.basura(material, rng?)`: 4 formas por material, cuerpo en el
color del material y detalles con `Paleta.escalar`; atributo `Forma`;
`ScaleTo(1.35)` para que abulten.

El Imán (único que recoge solo) filtra primero montañas enteras por distancia
al centro antes de mirar objetos: con cientos por montaña, iterar todo por
jugador cada 0,2 s sería tonto.

Los objetos no desaparecen nunca (decisión del usuario, como en KOTAMON). Para
que la repoblación no espere al último papel, un montón activo deja de contar
como "disponible" cuando le queda menos del 25 % de sus objetos.

### La bolsa se lanza entera, y si falla es de su dueño

Mantener F carga la fuerza (1,2 s = 70 studs); al soltar, la bolsa sale con
TODO lo que llevaba hacia donde apuntas. Si entra en el Contenedor se recicla
con +50 % (y +25 % más si iba llena) y cuenta para Puntería. Si falla cae como
objeto `bolsa` que **solo su dueño** puede recoger (`item.duenoId`). Hasta
el 29 sep, si no volvía a por ella en 20 s se reciclaba sola sin bonus; el
usuario lo quitó: ahora espera en el suelo, y si queda en alto (techo de la
recicladora, tapa del contenedor) se baja junto al contenedor del lado del
que lanzó (prueba `bolsaEnAlto`). Al salir del juego sus bolsas caídas se
reciclan para él sin bonus. Hasta el 26 sep la podía recoger cualquiera (decisión del usuario:
"tensión social"); la auditoría lo revirtió porque castiga al que arriesga y
con público infantil invita al acoso. Reciclar por el prompt de cerca sigue
existiendo, pero no cuenta para Puntería.

La parábola se integra paso a paso en el servidor (`PivotTo`, sin física de
Roblox: determinista y el servidor decide el acierto) y desde el 16 sep
**bota** al caer (petición del usuario): hasta 3 botes conservando el 40 %
de la velocidad vertical y el 55 % de la horizontal, y contra la pared del
contenedor sale despedida hacia fuera con el 30 %. La altura del suelo se
mide con un raycast (patio a 1, plaza a 0,9, lote a 0,12), no con una
constante. Medido: cae desde 21 studs, bota a ~4, luego a ~1,5 y se queda;
todo en menos de 3 s, que es lo que espera `lanzarBolsaFallo`. También
rebota hacia dentro contra los muros `Limite` del borde (antes una bolsa
podía perderse fuera de la valla). Acierto o pared se deciden por el TRAMO
entre dos ticks (por dónde cruza el plano del borde superior de la caja),
no por el punto actual: la bolsa avanza ~1,5 studs por tick y la pared
mide 0,5, y mirar solo el punto era una lotería (un acierto de cada cinco
fallaba). La bolsa lanzada es la malla `ServerStorage.Arte.Bolsa` escalada
por el llenado (`ModelosObjetos.bolsaLlena`, con el modelo de partes de
respaldo); `lanzarBolsaFallo` apunta ahora hacia el patio (plano v3).

### Primera persona en el patio y el bug de los modales

Entrar al patio (servidor: atributo `EnPatio`) pone `LockFirstPerson`. Con un
panel abierto el script de cámara de Roblox re-bloquea el ratón CADA frame, y
cambiar a `Classic` tampoco lo libera mientras el zoom está a distancia de
primera persona. La solución que funciona: `BindToRenderStep` con prioridad
`Camera + 1` que deja `MouseBehavior = Default` mientras hay panel
(`Camara.client`). Además `Menu` solo fija `GuiService.SelectedObject` con
gamepad: en PC forzaba la navegación por teclado.

Los rigs nuevos usan `AnimationConstraint` (sin `C0`) y el Animator pisa
cualquier cambio único: la pose de brazos (`Utilidades/PoseBrazos`: hombros
70° al frente y 15° hacia el centro, codos y muñecas a identidad para que el
brazo quede recto) se escribe en `Transform` cada `RunService.Stepped`. La
escribe cada cliente para todos los personajes con `EnPatio` (`Escena.client`)
**y también el servidor** (`Patio`): `Transform` no se replica y la vista de
servidor de Studio (donde el usuario miraba a su personaje) mostraba los brazos
caídos y la bolsa a un lado. La bolsa abierta (`ModelosObjetos.bolsaAbierta`,
bola con boca clara e interior oscuro, crece con el llenado) se suelda al torso
entre las manos **medidas de verdad** 0,2 s después de entrar (el largo real
del brazo no se deduce bien de los tamaños de las partes: los rig attachments
no están en los extremos).

Retícula: en primera persona Roblox sigue pintando la flecha del ratón en el
centro. En el patio sin panel abierto se oculta (`MouseIconEnabled = false`) y
`Camara.client` dibuja un punto en el centro del viewport (ScreenGui con
`IgnoreGuiInset`, que es de donde sale el rayo). Para capturar al propio
personaje desde fuera en Studio: `EjecutarPruebaCliente:Invoke("verme", 8)`
(apaga `Humanoid.AutoRotate`: en primera persona el motor gira el personaje
hacia donde mira la cámara en cada paso de física y pisa cualquier CFrame).

### Modelos por código

`Utilidades/ModelosMascota` construye las mascotas (forma por familia de
material y `forma`, tamaño por rareza, estado visible:
torcida/apagada/reflectante/neón, manchas si está sucia; eran 41 hasta el
26 sep, ahora 10) y sus fragmentos;
`ModelosObjetos` la basura (16 formas: 4 por material), billetes, tesoros,
figurinas, cintas, trajes y bolsas; `ModelosMonton` la colina; todos sobre
`Primitivas`. Sirven al mundo y a los ViewportFrames del álbum: un solo
vocabulario visual.

## 4. Números de calibración (punto de partida)

Los objetivo son los del Diseño v2 (salen de una simulación de 400 partidas;
el juego real será más lento). Estado tras el L1:

- 4 mejoras al máximo: $118.030 (Bolsa 150, Alcance 120, Velocidad 200,
  Brazo 180 de base, × 1,6^nivel, redondeo a la unidad).
- Bolsa 10 (+3/nivel), alcance 6 (+1/nivel), velocidad 16 (+1,2/nivel),
  brazo 25 (+4,5/nivel) studs.
- Montones: 12 chicos de 20 piezas y 6 grandes de 60 (uno por cuadrante,
  con un tesoro garantizado); una tirada por pieza: basura 94 %, billete 5 %,
  tesoro 1 %; 90 % del material del cuadrante. Valor por pieza: Papel 5,
  Plástico 7, Metal 15, Orgánico 25; billete ×6 y tesoro ×40 de su material.
- Reposición: 45 s después de que un montón baje del 25 % (o se vacíe) se
  retiran sus restos y vuelve la colina. Prioridad del excavador: 10 s.
- Lanzamiento: 1,2 s de carga = el alcance del Brazo. Bonus al entrar: <10
  studs 0; 10–19 +20 %; 20–29 +40 %; 30–44 +70 %; 45–59 +100 %; 60–70 +150 %;
  racha +10 % por acierto seguido (tope +50 %). Pago = valor de las piezas ×
  (1 + distancia + racha) × rebirth (× mascotas y pases en L6 y L8). Una
  bolsa de 10 de plástico desde 25 studs, sin racha: $105. Bolsa perdida:
  20 s hasta reciclarse sola.

## 5. Pendiente

- **Lotes L2–L10 del Diseño v2** (tabla en §3 "Diseño v2").
- **Guardar el place** tras hornear (el mundo, las variantes de
  MaterialService y `ServerStorage.Arte` viven ahí; el `.rbxl` no va en git).
- Arte 2D del usuario para la UI en `assets/ui/` (iconos); hasta entonces,
  glifos dibujados.
- Arte pendiente del mundo: siluetas propias de las 41 mascotas y el avatar.
- Fijar **Max players = 6** en Game Settings / Creator Dashboard
  (`Players.MaxPlayers` es de solo lectura por script).
- Publicar el place y activar *Studio Access to API Services* para probar el
  DataStore; crear pases, productos y badges y rellenar sus ids.
- Prueba con 2+ jugadores del patio compartido (riesgo "tibio" del GDD §14).
- Calibrar la economía con jugadores: tiempo de viaje y tasa de acierto (PC
  y móvil) antes que nada.

### Tienda "SHOP" de Blender (24 sep)

La cabaña de Doña Chatarra se sustituye por dos contenedores apilados (petición del
usuario): menta abajo con mostrador (sin toldo), coral arriba, y rótulo
amarillo con letras 3D "SHOP". Fuente `assets/3d/Tienda.fbx` (escena `Tienda`
del .blend del usuario; modelado en studs, origen en el suelo en el centro de
la cabina, frente a -Y). En el place: `ServerStorage.Arte.Tienda`, pintada por
sufijo (`Tienda_Menta`…) en `ArteMundo.tiendaDeMalla`. La cabina whitebox
sigue siendo la colisión. Sin la malla, `ArteMundo.caseta` usa la cabaña de
partes con el rótulo `Textos.MUNDO.tienda`.

### Base del jugador de Blender (25 sep)

Parcela rediseñada (petición del usuario, referencia: bases de simuladores
actuales tipo Steal a Brainrot) y simplificada al mínimo: arco de entrada
coral con el cartel del dueño, alfombra roja hasta un escenario con la
vitrina de figurinas (2 baldas × 6), 3 podios a cada lado, radio y banco en
las esquinas del fondo. Teléfono y almacén siguen de partes donde estaban.
- Fuente `assets/3d/Base.fbx` (escena `Base` del .blend). En el place:
  `ServerStorage.Arte.Base`. `ArteMundo.parcela` la clona; `construirParcela`
  deja las partes whitebox con la misma disposición pero invisibles
  (colisión, prompts, marcadores). Sin malla, se ven.
- `ArteMundo.colocarImportada` deduce el frente de dos mallas conocidas (el
  importador de Studio deja los modelos con el frente a −Z y la X del
  diseño invertida); lo usan la tienda y la base.
- El `Cartel` del dueño es el travesaño del arco (prompt "Me gusta" a 12).
- Skin: las mallas Losa/Borde/Mueble llevan `Pintable` y `ColorBase`;
  `Parcelas.pintar` vuelve a `ColorBase` sin skin.
- Brillo por rareza: cada podio tiene un `Aro` de partes (la malla `Base_Aro`
  se oculta) con una PointLight; `Parcelas.renderizar` lo pone en neón del
  color de la rareza de lo exhibido.
- Mascotas girando: tag `MascotaExhibida` (servidor) → `GiroExhibidas.client`
  rota las partes localmente con BulkMoveTo.
- `ConstructorMundo.rehacerParcelasYTienda()` rehace solo parcelas y tienda
  sin hornear (por el shim de `hornear-desde-mcp.luau`).
