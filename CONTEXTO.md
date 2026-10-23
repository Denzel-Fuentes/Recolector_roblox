# Recíclatas (CleanRecycle) — estado del proyecto

Réplica mecánica de KOTAMON para Roblox, low-poly de partes con arte por
capas sobre un esqueleto whitebox (ver §3 "Arte del mundo"). El diseño
completo está en `docs/GDD.md`, la economía vigente en
`docs/Economia-v4.md` (aprobada el 22 oct) y la ficha del Creator Hub en
`docs/Ficha-lanzamiento.md`; lo que ve el jugador, en `docs/Juego.md`. Este
documento es lo que NO se deduce del código: qué hay, cómo se trabaja y por
qué se decidió lo no obvio.

**22–23 oct 2026: plan de lanzamiento por agentes** (aprobado por el usuario
el 22 oct; los porqués en §3 "Lanzamiento por agentes", lo que falta en §5).
Esta vez no hubo lotes sino **paquetes**: una sesión orquesta, lanza un
agente por paquete con sus archivos y sus pruebas
(`PruebasDefinidas/<Área>`), le da su turno de Studio para verificar, pasa la
revisión y hace un commit local por paquete. **Hecho y en master**
(subido a origin/master): la fase 0 (la v3 commiteada con el tag
`base-lanzamiento`; el mundo re-horneado, W1), la 1 (C1 limpieza del copy;
P1 guardado v4 con cola y bloqueo de sesión; P2 recibos que se guardan antes
de confirmar y admin solo en Studio; P3 anti-trampas, con su revisión de
seguridad P3b), la 2 (L1 pantalla de carga, N1 analítica, A1 audio) y parte
de la 3: la **economía v4** con su contrato (C3: copy, perfil v5,
`Actividad`, `costeSiguiente`), el ritmo (E1: R1 en ~58 min, pedidos en % del
siguiente rebirth, Pedido VIP, día a las 06:00 UTC; unido **sin terminar de
verificar en Studio**) y las recompensas (R1: calendario de 7 días, regalos
por minutos activos y bono de regreso); y de la 4, los 6 pases y los 2
productos de Turbo creados en el Creator Hub con sus ids en `Config/Productos`
(F1b, 23 oct). El usuario pausó el plan el 23 oct y lo retomó ese mismo día;
**K1** (catálogo: Turbo solo jugando, VIP, Pack de inicio, ofertas y precio
real) se unió a master el 23 oct y, con E1 y N1b, quedó **verificado en
Studio** ese mismo día (la batería entera en verde). La ficha del Creator Hub está hecha y el juego sigue
**privado**.

**3 oct 2026: v3 para lanzar** (decisiones del usuario, ver §3 "Lanzamiento:
v3"): **cinco contenedores** (uno por tipo de basura, del color de su tipo,
y el general azul; premio por separar x2 / x0,5), **basura del color de su
tipo** en tonos, **fuera las mascotas** (y el imán y los fragmentos), la
**tienda con barras de 10 cuadros** sin studs, y **L7–L9 terminados**
(pedidos, 16 insignias, pases y cosméticos, tutorial de 8 pasos con
píldora, cámara en primera o tercera persona). Mundo v6 horneado. El place
ya está publicado (PlaceId 139915415713937, el DataStore carga): falta lo
del Creator Dashboard (§5).

**26 sep 2026: Diseño v2 "recoger y lanzar"** (documento de @FND, ver §3
"Diseño v2"). Sustituye al recorte por la auditoría del mismo día: lo que
la v2 quita se BORRÓ del código (base, energía, reparación, fusión, venta,
gemas, Sobre, Contenedor Dorado, Montón extra, logros con dinero) y lo que
solo pospone (figuritas, cintas; los trajes del botín también, hasta que el
5 oct se quitaron todos los trajes) queda tras `GameConfig.FUNCIONES`. Se implementa por lotes verificados (L1–L10, plan en
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
| Progreso por **tipo de basura** (decisión del usuario, 5 oct): los seis cuadrantes son zona "patio", abiertos y **sin barreras**; el Rebirth 1 desbloquea el metal y el 2 el orgánico (`GameConfig.MATERIAL_REBIRTH`). Un montón solo trae los tipos que tiene abiertos **quien lo excava**, y nadie recoge una pieza de un tipo que no tiene aunque la haya sacado otro (`"materialBloqueado"`; el cliente no la resalta, atributo `MaterialBasura`) | `GameConfig.MATERIAL_REBIRTH`/`materialAbierto`, `GeneradorBotin`, `ObjetosPatio.puedeReclamar`, `ControlPatio` | `materialPorRebirth`, `reclamoMaterialBloqueado`, `sinBarreras` |
| Recicladora de cada color (5 oct, petición del usuario): la caseta, la general y su chatarra se movieron al oeste (`LAYOUT.CASETA_X = -35`, lote de valla a valla) y cada contenedor de color lleva detrás la **trituradora con cinta de la general, escalada al 65 %** (`ArteMundo.recicladora` con `{ escala, material, sinContenedor }`, colisión escalada). El cliente anima las cinco: cada depósito tritura en la de su contenedor (`RecicladoraEvent(contenedor, materiales)`) | `ConstructorMundo.construirContenedoresTipo`, `ArteMundo.recicladora`, `Recicladora.client` | `lanzarATipo`, `recicladora`, cliente `("recicladora")` (5 animadas) |
| **Celebraciones** en vez del toast al cobrar (5 oct): "¡DENTRO!"/"¡RECICLADO!" grande con rebote en el color del contenedor, el dinero contando y volando al contador, píldoras del desglose y destellos + anillo sobre el contenedor; y un **"+1"** en el mundo por cada objeto recogido (billete "+1 $", tesoro "¡TESORO!", bolsa "+N"), sin encadenar | `CelebracionEvent` (Lanzamiento, BotinHandler), `RecogidaEvent` (ObjetosPatio.alRecoger con posición), `UI/Celebraciones.client`, `EfectoRecogida.client` | cliente `("celebracion", "Papel")`, `("mas1")` |
| Patio compartido: 18 **colinas** de basura (2x3 cuadrantes, 2 chicas de 20 piezas + 1 grande de 60 por cuadrante); al activar, la colina se sustituye por una **montaña de basura real con física**, **revuelta** (`TablasProbabilidad.MEZCLA.patio` 40/35/15/10 papel/plástico/metal/orgánico, sin los tipos que el excavador no tiene); billetes 5 %, tesoros 1 %; la grande trae un tesoro seguro; **cada pieza es del color de su tipo** en uno de 5 tonos (`Paleta.TIPO`/`BASURA`, 3 oct); **solo se recoge con clic** (o la mira en táctil), reclamo atómico, **prioridad del excavador 10 s**, un montón terminado **vuelve a los 45 s** | `Services/Botin.luau` (fachada) → `GeneradorBotin`, `ObjetosPatio`, `FisicaBasura`, `Montones`, `Lanzamiento` + `BotinHandler` | verificado (`montonPiezas`, `reacomodo`, `sinRecogidaAutomatica`, `variedadBasura`, `coloresBasura`, `materialPorRebirth`, `variedadPiezas`) |
| **Cinco contenedores** (3 oct): 4 de tipo (Papel celeste, Plástico amarillo, Metal plomo, Orgánico verde) en fila al este de la caseta y el **general azul** (el volquete de la recicladora). Premio por separar: en el de su tipo cada pieza de basura paga **x2**, en el de otro x0,5, en el general x1; billetes y tesoros x1 en todos. La bolsa entera va al contenedor donde cae (lanzada) o al del prompt (a mano) | `Utilidades/Contenedores`, `Bolsa.factorContenedor`, `Lanzamiento` (una caja y una boca por contenedor), `ConstructorMundo.cajaContenedor`, `ArteMundo.contenedorColor` | verificado (`pagoSeparado`, `lanzarATipo`, capturas) |
| Puntería: **mantener F carga y lanza la bolsa entera**, el alcance lo da la mejora **Brazo** (25 → 70 studs); al entrar paga el **bonus por distancia** (+20 % desde 10 studs … +150 % desde 60) más la **racha** (+10 % por acierto seguido, tope +50 %); el **primer lanzamiento siempre entra**, pero desde el 22 oct paga como mucho la distancia del Brazo y no cuenta para récords; los 5 primeros llevan **línea de trayectoria**; récord personal y del servidor en una tarjeta (el del servidor, también en el feed de los demás); si falla, racha a 0 y la bolsa queda en el suelo **30 s solo para su dueño** y después para cualquiera (no se recicla sola desde el 29 sep; si cae en alto se baja junto al contenedor). **Solo se lanza con la bolsa llena**: desde el 29 sep el botón táctil y la pista "MANTÉN F" solo salen entonces, y desde el 22 oct (P3) lo impone el servidor; como mucho **3 bolsas caídas** por jugador (con una más, la más vieja se recicla sola, sin bonus y a x0,5). El vuelo se integra con el paso exacto (§3 "Lanzamiento por agentes") | `Services/Lanzamiento.luau`, `Config/DefinicionesPunteria`, `Utilidades/Trayectoria`, `Client/LineaTrayectoria` | verificado (`bonusDistancia`, `racha`, `primeroEntra`, `pagoFormula`, `lanzarBolsa`, `lanzarBolsaFallo`, `bolsaProtegida`, `bolsaLibre`, `brazoLimita`, `lanzarSoloLlena`, `primeroSinRecord`, `topeBolsasCaidas`, `("trayectoria")`) |
| Primera persona por defecto (en todo el mapa desde el 6 oct) con retícula (punto); en el patio (atributo `EnPatio`), manos+bolsa en 2D (Frames) y brazos extendidos sujetando una bolsa abierta soldada entre las manos (la pose la pinta cada cliente; el bucle del servidor, solo en Studio desde el 22 oct) | `Services/Patio.luau`, `Utilidades/PoseBrazos`, `Client/Camara.client`, `Client/UI/Manos.client`, `Escena.client` | verificado (`enPatio`, `poseSinBucle`, capturas) |
| HUD: **botonera 2×3** (22 oct; era de 4), cada botón con su tecla: Tienda **Q** (o T), Rebirth **R**, Pedidos **P**, Cámara **V**, Sonido **M** (el panel Ajustes) y Recompensas **G** (con un punto rojo si hay una casilla del calendario por cobrar). En PC, sin panel abierto, el ratón está bloqueado al centro y la botonera solo se usa con su tecla. Píldora del dinero arriba-dcha con el **Turbo** (x2 y el tiempo; gris, "x2 en pausa", cuando no corre: K1) y el **pedido más avanzado** debajo, barras de fuerza y **bolsa** (sin números, "¡LLENA!" en rojo), pista de lanzar (abajo-dcha) y de recoger (abajo-izq; en táctil bajo los contadores: pisaba las barras) | `Client/UI/HUD.client.luau`, `UI/Paneles.client` (teclas) | verificado (`("hud")` sin avisos en PC y táctil forzada, 3 oct; con la botonera de 6, A1); `("hud")` con el punto rojo, sin avisos (23 oct) |
| Sistema de diseño en **Fusion 0.3** (`Client/UI/Kit`): Ventana, Boton, Tarjeta, Pestanas, Pildora, Barra, Segmentos, Insignia, Icono, Interruptor (A1), Escala; prompts y carteles del mundo (el prompt del tendero, "Reciclador", abre la tienda; sus diálogos se quitaron el 29 sep) | `Client/UI/Kit/*`, `Prompts.client`, `Escena.client` | verificado |
| **Mundo v6** (3 oct: los 4 contenedores de tipo en fila, la solera ensanchada al este, el volquete general en azul, un poste movido; v5 el 29 sep; sin barreras desde el 5 oct; re-horneado el 22 oct, W1: placas de los contenedores traducidas y las cajas de cartón de la caseta con su marrón fijo): sin parcelas ni máquina de refrescos, valla a 24 studs del patio por los tres lados, cada contenedor de color con su trituradora, punto de aparición en la plaza con los 3 tablones de ranking; tienda SHOP y recicladora de Blender, vallas, postes, camión, el tendero vestido, iluminación cartoon | `ServerStorage/Herramientas/ArteMundo.luau` + `ConstructorMundo` v6 | verificado (W1, 22 oct: 1.054 instancias, 18 ranuras con `Zona`, 0 barreras, 5 `Contenedor` (4 con `Material`), 5 `RecicladoraArte`, 3 `PantallaRanking`; capturas); **guardar el place** tras hornear |
| Bolsa: todo lo recogido ocupa hueco (billetes incluidos), **sólo el contenedor paga**; entregar a mano no da bonus de lanzamiento (el de separar sí), lanzar sí. Al salir, lo de la mano, las bolsas caídas y las que vuelan se cobran sin bonus en `Perfiles.alSalir`, antes del guardado de salida (22 oct) | `Services/Bolsa.luau`, `Lanzamiento.cobrarAlSalir` | verificado (`billeteEnBolsa`, `sinDineroAlRecoger`, `salirRecicla`, `vueloAlSalir`) |
| **Rebirths** (economía v4, 22 oct): con las 4 mejoras al máximo y el dinero del requisito en mano ($15k, 100k, 250k, 500k, 800k, 1,2M, 1,8M, 2,5M, 3,5M, 5M; desde el 11, ×1,4 en dos cifras significativas) se reinician dinero y mejoras y el dinero pasa a x1,5 / 2 / 3 / 4 / 5 … x10 (luego +1). El 1 abre la basura de metal, el 2 la orgánica, el 3 regala la **Bolsa plateada** (era la segunda mascota), el 4 la **Bolsa de hielo**, el 5 la **Estela de fuego** y la insignia Reciclador de élite, del 6 al 9 solo sube el multiplicador y el 10 da la insignia Leyenda del reciclaje. Panel con requisito, barra y el icono y el texto de lo que abre; barrita de progreso bajo el botón del HUD | `Config/DefinicionesRebirths`, `Services/Rebirths` + `RebirthsHandler`, `Client/UI/Rebirth.luau` | verificado (`rebirthTabla`, `renacerRequisitos`, `renacer`, capturas); los números v4 y `rebirthsAbren`, en Studio el 23 oct |
| **4 mejoras × 10 niveles** (Bolsa 10→40, Alcance 6→16, Velocidad 16→28, Brazo 25→70), coste base × **1,35**^nivel (economía v4; era 1,6): las 4 al máximo $35.485 (eran $118.030); en la tienda el nivel es una **barra de 10 cuadros** (`Kit/Segmentos`) sin valores ni studs (3 oct) | `Config/DefinicionesMejoras`, `GameConfig.FACTOR_COSTE_MEJORA`, `Services/Mejoras.luau` | verificado (`mejorasV2`, captura); con 1,35, en Studio el 23 oct |
| **Economía v4** (aprobada el 22 oct, `docs/Economia-v4.md`; números en §4): el jugador medio hace el R1 en ~58 min y el R5 en ~7 h 26 min jugando seguido (antes 3 h y 66 h). Todo premio en dinero es un % del **coste del siguiente rebirth** (`costeSiguiente`: su requisito más las 4 mejoras de 0 a 10, $50.485 con 0 rebirths) en dos cifras significativas (`redondear`), calculado al cobrar y sin pases ni Turbo | `Config/DefinicionesRebirths` (`costeSiguiente`, `redondear`) | verificado en Studio el 23 oct (`ritmoR1` 57,9 min, `costeSiguiente`, `premioAlCobrar`) |
| **Persistencia** (22 oct, P1): `Services/Guardado` es lo único que habla con el DataStore: cola por jugador (el guardado de salida nunca se descarta), `BindToClose` que espera todo lo que está en vuelo (hasta 25 s), `guardarAhora` para los recibos y **bloqueo de sesión** propio con un token por carga (latido en cada autoguardado de 120 s; caduca a los 600 s; una sesión ajena viva se roba a los 60 s; si al guardar ya no es suya, no escribe y expulsa con el texto en su idioma). **Perfil v5** en `ReciclatasPerfiles_v4` (perfiles desde cero el 22 oct; `_Studio` en Studio) con migraciones versión a versión; `Perfiles.alSalir` (antes del guardado de salida), `Perfiles.anterior` (el perfil tal como llegó), `alMinuto` y el atributo `PerfilListo` | `Services/Guardado.luau`, `Services/Perfiles.luau`, `DataService.server` (solo cableado) | verificado (`perfilV5`, `estado`, las de `Datos`); parar y volver a Play conserva el progreso |
| **Aparición** en la plaza mirando al patio (sin base), también al morir; el personaje se carga cuando llega el perfil (o a los 75 s sin él, `SESION_ESPERA_ROBO` + 15: con los 15 s de antes se jugaba sin perfil mientras otro servidor soltaba la sesión, y lo reciclado se perdía; Q4b) y su salto a la plaza se avisa a `Movimiento` | `Services/AparicionHandler.server.luau`, `Mundo.cframeAparicion` | verificado (`aparicion`) |
| Tutorial jugable de **8 pasos** (patio, excavar, llenar, lanzar al general, mejora, **separar**, **un pedido**, **meta Rebirth 1**); flecha (Beam) y una **píldora** arriba-izq ("Paso 6/8 · …", abre el panel del paso). Cada paso completado sale en `Tutorial.alCompletar` (el embudo de la analítica; el 5 abre pedidos y recompensas) | `Config/DefinicionesTutorial`, `Services/Tutorial.luau`, `Client/UI/Tutorial.client` | verificado (`tutorial`, capturas) |
| **Pedidos del día** (L7; economía v4 el 22 oct): 3 retos (el primero de puntería; "lejos" adaptado al Brazo, "material" a los tipos abiertos) que se cobran solos y pagan el **1,5 / 2 / 3 %** del coste del siguiente rebirth según la dificultad ($760 / 1.000 / 1.500 con 0 rebirths), calculado al cobrar; los tres dan **10 min de Turbo**; con el pase VIP, un **4.º pedido** ("Pedido VIP", paga como difícil, no cuenta para el Turbo). El día cambia a las **06:00 UTC**. Se abren al comprar la primera mejora | `Config/DefinicionesPedidos`, `Services/Pedidos` + `PedidosHandler`, `Client/UI/Pedidos` | verificado (`pedidosDia`, `pedidoSeparadas`, `premioTurbo`, captura); con la v4 y `pedidoVip`, en Studio el 23 oct (captura con el Pedido VIP) |
| **Recompensas** (22–23 oct, R1): panel propio con el botón del regalo (**G**), pestañas Calendario y Regalos. **Calendario** de 7 casillas, una por día jugado y con botón (2 % · 2 % · Turbo 10 min · 3 % · 3 % · Turbo 15 min · 4 %; saltarse un día no reinicia nada; la 7.ª da la insignia Constante, que regala la Bolsa de cartón (se pone en Estilo desde K1); desde la 2.ª vuelta suma Turbo 15 min). **Regalos** solos por minutos activos del día (5/10/20/30/45/60: 0,5 % · 0,5 % · 1 % · Turbo 5 min · 1 % · 2 %; un minuto es activo con 3 acciones). **Bono de regreso** al entrar tras 3 días sin jugar (Turbo 15 min + 4 %) o 14 (Turbo 30 min + 8 %), con ventana de bienvenida. Se abre con la primera mejora; el panel se abre solo al entrar si hay algo que cobrar | `Config/DefinicionesRecompensas`, `Services/Recompensas` + `RecompensasHandler`, `Services/Actividad` + `ActividadHandler`, `Client/UI/Recompensas.luau` | verificado (las 8 de `Recompensas`, `actividad`); también con la curva v4, y captura del panel y `("hud")` con el punto rojo (23 oct); en táctil, pendiente (§5) |
| **20 insignias** (16 del L7 y 4 de la economía v4: rebirth5, rebirth10, semanaCompleta, pedidos30): en el perfil (`logros`) y como Badge si tienen id (10 creadas en Roblox; 5 gratis al día); al entrar se consultan en lotes (`CheckUserBadgesAsync`) con caché de la sesión; tarjeta al conseguirlas; pestaña Insignias del panel Pedidos | `Config/DefinicionesInsignias`, `Services/Insignias` | verificado (`insignias`, `insigniasLote`); faltan 10 Badges (§5) |
| **Tablones de ranking** en la plaza (8 oct): Dinero ganado, Racha máxima y Bolsas encestadas, histórico y semanal (desde el lunes 00:00 UTC); stores `Ranking_v2_*` desde el 22 oct (tablones limpios para el lanzamiento); se publican en `alSalir` y el cierre espera las escrituras | `Config/DefinicionesRankings`, `Services/Rankings` + `RankingsHandler`, `Client/Tablones.client` | verificado (`rankings`, `rankingsDatastore`, `("tablones")`) |
| Tienda (L8): pestañas **Mejoras / Pases / Estilo**. Pases (catálogo de la economía v4; creados en Roblox el 23 oct, F1b, con sus ids en `Config/Productos`): Pack de inicio 99 (compra única), Dinero x2 199, Bolsa XL 149 (+10 huecos), VIP 249, Estela arcoíris 99 y Bolsa dorada 99; productos Turbo 15 min (49) y Turbo 60 min (149). Estilo: bolsas plateada (Rebirth 3), de hielo (R4), de cartón (insignia Constante), del reciclador (Pack) y dorada (pase); estelas arcoíris (pase), de fuego (R5) y VIP (pase); los 2 trajes de pago se quitaron el 5 oct. Desde K1 (23 oct): el **precio real** de Roblox (`Client/PreciosRobux`, `GetProductInfo` con caché y un reintento; el de Config si falla; lo que Roblox dice que no está a la venta no se ofrece), el Pack ("Compra única"; comprado, baja al final) y el VIP arriba, "El Turbo solo corre mientras juegas" bajo los pases, los Turbo apagados con 3 h guardadas y en Estilo el origen de cada cosmético (los del Pack y del VIP sin botón de Robux) | `Client/UI/Tienda.luau`, `Client/PreciosRobux`, `Config/Productos`, `Config/DefinicionesCosmeticos`, `Services/Cosmeticos`, `Services/Turbo`, `TiendaHandler` | verificado (`paseDineroX2`, `paseBolsaXL`, `turboAcumula`, `cosmeticoBolsa`, capturas); lo de K1, en Studio el 23 oct (`cosmeticosNuevos`; capturas de Pases y Estilo con los precios de Roblox) |
| **Turbo, Pack y VIP** (K1, 23 oct; economía v4 §4.6): el Turbo son segundos (`turboRestante`) que **solo bajan jugando**: en pausa tras 120 s sin una acción de `Actividad` y fuera del juego (atributo `TurboPausado`; en pausa sigue pagando x2), se para al salir antes del guardado y vuelve en la siguiente sesión; tope de compra de **3 h** solo en la tienda y las ofertas (un recibo pagado se otorga entero). **Pack de inicio**: 30 min de Turbo una sola vez (`compras.packInicio`) y la Bolsa del reciclador. **VIP**: atributo `VIP`, corona sobre la cabeza (BillboardGui; la propia se oculta en primera persona), `[VIP]` en el chat, la Estela VIP y el Pedido VIP de E1. Cada compra con Robux anota `compras.ultimaRobux` | `Services/Turbo`, `Services/Monetizacion`, `Client/CoronaVIP.client`, `Client/EtiquetaVIP.client`, `UI/HUD.client`, `Musica.client` | verificado en Studio el 23 oct (`turboPausa`, `turboTope`, `turboProductos`, `packInicioUnaVez`, `vipVentajas`, `turboAcumula`; capturas del HUD con "x2 en pausa" y de la corona) |
| **Ofertas** (K1, 23 oct; economía v4 §5.6): cinco disparadores por prioridad (Pack de inicio en la 2.ª y la 4.ª sesión; Dinero x2 en los Rebirths 1 y 3; VIP en el 2; Bolsa XL tras 5 intentos de recoger con la bolsa llena y la mejora Bolsa en 3+; Turbo tras acabarse uno ganado, desde la 3.ª sesión). Nunca en la 1.ª sesión, antes del paso 7 del tutorial, en los 3 primeros minutos ni en las 24 h siguientes a una compra; 1 por sesión y 3 por semana; 7 días tras un "Ahora no" y, con 3, no vuelve sola. Ventana con "Comprar" y "Ahora no" iguales, en un momento tranquilo que busca el cliente. En Studio solo salen con `ServerStorage.OfertasEnStudio = true` | `Config/DefinicionesOfertas`, `Services/Ofertas` + `OfertasHandler`, `Client/UI/Oferta.luau` | verificado en Studio el 23 oct (`ofertaReglas`; las cinco ventanas, con botones iguales); de punta a punta, con otra cuenta (§5) |
| **Cámara** (L9): primera persona por defecto; **V** o el botón Cámara pasa a **tercera persona** sobre el hombro (ratón al centro, el personaje gira con la cámara; las manos 2D se ocultan), en todo el mapa desde el 6 oct. Se guarda en el perfil; `CamaraEvent` con cooldown desde el 22 oct (la última vista pedida no se pierde) | `Client/Camara.client`, `PatioHandler` (CamaraEvent), `Patio.elegirVista` | verificado (`("camara","tercera")`, `camaraCooldown`, captura) |
| Figuritas (6 fijas) y cintas: **pospuestas** (`FUNCIONES`; los trajes, gratis y de pago, se quitaron el 5 oct) | `Config/DefinicionesColeccionables`, `Services/Coleccionables.luau` | apagados |
| **Monetización** (P2, 22 oct): los pases se cachean al entrar y una compra solo cuenta si Roblox la confirma (`UserOwnsGamePassAsync`, P3b; con esperas que doblan hasta ~1 min, porque Roblox recuerda un "no" unos 10 s, Q4b) y sale en `alComprarPase`; `ProcessReceipt` idempotente, con otorgadores registrados por producto (`Turbo` registra los suyos), **espera al perfil** (hasta `SESION_ESPERA_ROBO` + 15 s) y solo devuelve `PurchaseGranted` con la compra ya guardada (`guardarAhora`); modo dev de pases solo en Studio (apagado por defecto: `/pases on`) | `Services/Monetizacion.luau`, `Config/Productos` | verificado (las 8 de `Monetizacion`); ids reales desde el 23 oct (F1b); falta una compra real de cada uno (Q3, §5) |
| **Anti-trampas** (P3 y su revisión P3b, 22–23 oct): el servidor solo lanza bolsas llenas, recorta el primer tiro al Brazo, pone tope a las bolsas caídas, exige argumentos de lanzamiento finitos y dentro del mapa y cooldown a la cámara. **`Movimiento`** vigila la velocidad horizontal con un crédito (Velocidad × 1,8, ráfaga de 2,1 s): quien se mueve más de lo que puede andando pasa **2 s** sin recoger, excavar, entregar a mano ni lanzar, sin aviso y **sin expulsión nunca**; los saltos del propio servidor se avisan con `permitirSalto` | `Services/Movimiento` + `MovimientoHandler`, `Lanzamiento`, `ObjetosPatio`, `Bolsa`, `BotinHandler` | verificado (las de `Antitrampas`); falta medirlo con varios jugadores (Q1, `README-pruebas.md`) |
| Admin por chat **solo en Studio** (22 oct; sin autocompletar y todos los de la sesión son admin): `/dar dinero n` (acotado; no cuenta como dinero ganado), `/maxmejoras`, `/pases on` u `off`, `/rebirths n`, `/tutorial n`, `/repoblar`, `/reset`. En el juego publicado no hay comandos ni admins, tampoco el creador | `Services/Admin.luau`, `AdminHandler.server` | verificado (`adminOculto`, `modoDevSoloStudio`) |
| **Audio** (22 oct, A1; decisión del usuario: los recomendados de `docs/Audio-propuesta.md`, de la biblioteca con licencia de Roblox): `Config/Sonidos` (un id por clave; id 0 la calla), efectos 2D y 3D con voces reutilizadas, música del patio en orden aleatorio con fundido cruzado (y la del Turbo, como mucho dos veces) que baja en celebraciones, rebirths e insignias; botón **Sonido (M)** con Música y Efectos, que valida y guarda el servidor (`AjustesEvent`, `perfil.ajustes`) | `Config/Sonidos`, `Client/Sonido.luau`, `Musica.client`, `SonidosMundo.client`, `UI/Ajustes.luau`, `Services/Ajustes` + `AjustesHandler` | verificado (`ajustesValidos`, `("modulo","Sonido","listar")`); el usuario los escucha jugando y cambia los que no le gusten |
| **Pantalla de carga** (22 oct, L1): desde el primer fotograma del cliente hasta que el perfil responde (`PerfilListo`) o hay personaje, con red de seguridad a los 90 s (por encima de los 75 del servidor); los cinco contenedores saltando por turnos, título y consejos traducidos ("Cargando tu progreso…" a los 8 s); precarga iconos y sonidos sin retener a nadie | `src/ReplicatedFirst/Carga.luau` + `PantallaCarga.client` | verificado (23/23 precargas, carga lenta simulada, es/en; `("modulo","Carga",...)`) |
| **Analítica** (22 oct, N1; N1b el 23): embudo de inicio de 9 pasos (entrar y los 8 del tutorial), fuentes y sumideros del Dinero con el saldo final (desde N1b también el calendario, los regalos y el regreso, como `TimedReward`: `Calendario_3`, `Regalo_20`, `Regreso_14`), progresión por rebirth y eventos propios (Acierto, Fallo, Rebirth, Insignia, CompraPase, CompraProducto, Sesion, PerfilNoCargado, Sospecha y, con N1b, Calendario y Oferta), todo en pcall y en tramos; la plataforma la manda el cliente una vez. En Studio no se envía (`Analitica.registro`) | `Services/Analitica` + `AnaliticaHandler`, `Client/Telemetria.client`, `AnaliticaEvent` | verificado (las 7 de `Analitica`); `analiticaRecompensas` (N1b), en Studio el 23 oct; los datos reales, tras publicar (24–48 h) |
| **Idiomas** (7 oct): español (original y respaldo), inglés y portugués con módulos Luau, sin LocalizationTable ni traducción automática de Roblox; el servidor manda mensajes y no texto (salvo el `Kick`) | `Config/Traducciones/{en,pt}`, `Utilidades/Idioma`, `TraducirMundo.client` | verificado (`idioma`, `("idioma")`) |

## 2. Cómo se trabaja

### Sincronizar código a Studio

Flujo normal: `herramientas/rojo-serve-bucle.ps1` (un `rojo serve
default.project.json --port 34872` que se relanza solo si se cae; Rojo no
está en el PATH y el script usa `~/.aftman/bin/rojo.exe`) y **Connect** en el
plugin de Rojo. Rojo 7 crea `X.luau` → ModuleScript, `X.server.luau` → Script,
`X.client.luau` → LocalScript, `X.model.json` → instancia; desde el 22 oct
`src/ReplicatedFirst` va al servicio.

Rojo 7.7.0 (y 7.7.1) se cae cuando un editor guarda con un archivo temporal y
lo renombra, que es lo que hace la herramienta Edit de los agentes
("called Result::unwrap() on an Err value ... NotFound", rojo-rbx/rojo#1338;
el arreglo, PR #1319, aún no está en ninguna versión). El bucle lo relanza,
pero **el plugin no se reconecta solo**: hasta que alguien pulse Connect, lo
editado no llega a Studio. Por eso los agentes sincronizan por HTTP.

Por HTTP (agentes, MCP, o cuando no se puede pulsar Connect):
`herramientas/servir-fuentes.ps1` sirve el repo en `localhost:8123` y
`herramientas/instalar-desde-http.luau`, ejecutado en la barra de comandos (o
`execute_luau`) sobre el DataModel Edit, crea/actualiza el mismo árbol con las
mismas reglas: borra lo que sobre en las carpetas gestionadas y en
`ReplicatedFirst` (un LocalScript viejo ahí correría el primero en cada
cliente) y normaliza los finales de línea CRLF→LF como Rojo (con
`core.autocrlf` el disco va en CRLF, y sin eso cada pasada reescribía ~140
`Source` que Rojo volvía a parchear). Es idempotente y sólo escribe `Source` si
cambió: una segunda pasada da 0 cambios, y cuando el plugin de Rojo se
conecte no verá diferencias.

Studio se abre por shell (`RobloxStudioBeta.exe -task EditPlace -placeId
139915415713937 -universeId 10766595888`; la línea entera en CLAUDE.md), no
con `open_application` de computer use, que el 22 oct abrió tres veces una
instancia nueva en la página de inicio. Computer use queda para pulsar
Connect en el plugin y Start en Test → Clients and Servers.

### El mundo

`workspace.Mundo` es geometría REAL del place, construida por
`herramientas/construir-mundo.luau` (que llama a
`ServerStorage/Herramientas/ConstructorMundo`, y este viste el esqueleto con
`ArteMundo`). **Tras construir hay que guardar el place.** `SetupMundo` sólo
lo adopta; si falta, lo construye en runtime como fallback y avisa. Todo se
localiza por tags/atributos, nunca por nombre: `RanuraMonton` (18, con
`Tamano`, `Cuadrante` y `Zona`), `BarreraCuadrante` (con `Cuadrante` y
`Rebirth`; ninguna desde el 5 oct, el código aún las respeta),
`PuntoAparicion`, `Contenedor` (+ `Material` en los 4 de tipo),
`RecicladoraArte`, `PantallaRanking`, `Limite`, `SoloDecorado`,
`FigurinaFija` (solo con `FIGURINAS`); atributo `NPC`. Mundo v6 re-horneado
el 22 oct: 1.054 instancias.

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
propiedades, y leer `Source`; en septiembre **no podía** hacer `require` de
módulos del juego, usar HttpService, crear/reparentar scripts ni invocar
BindableFunctions/RemoteEvents (le faltaban capacidades: "LoadUnownedAsset",
"Network", "RobloxScript"). El 22–23 oct los agentes ya corrían por ese hilo
el instalador HTTP (`loadstring` + `HttpService`) y `EjecutarPrueba:Invoke`;
si una capacidad vuelve a faltar, quedan los rodeos de abajo:

- Hornear desde el MCP: `herramientas/hornear-desde-mcp.luau`, un `require`
  que carga cada módulo con `loadstring(modulo.Source)` y `setfenv`.
- Sincronizar código sin el plugin de Rojo: el instalador HTTP (arriba).
  Desde el plan del 22 oct ya no se usa `multi_edit` ni `Source = [==[...]==]`
  por `execute_luau` para escribir código (antes se comprobaba con una huella:
  largo, suma de bytes y suma ponderada por posición): con Rojo conectado
  `multi_edit` aplica el mismo cambio dos veces (pasó con `Paleta`), y el
  código que no sale de los archivos de `src/` se salta la revisión.
- Pruebas: por atributos (`Prueba` / `PruebaCliente`, ver arriba).
- `screen_capture` acepta `camera_position` / `look_at_position` en Edit;
  en Play, mover `workspace.CurrentCamera` (Scriptable) desde el cliente.
- Los eventos de `user_keyboard_input` / `user_mouse_input` llegan al juego
  ~6–8 s después de que la herramienta responda; para pulsar algo que
  aparece por un tiempo (el diálogo) hay que esperar a verlo (poll desde
  `execute_luau`) y usar `instance_path` en el clic.

### Probar

- `ServerStorage.EjecutarPrueba:Invoke(nombre, ...)` (sólo Studio) ejecuta las
  pruebas de `Services/PruebasDefinidas/` (un módulo por área: Patio, Bolsa,
  Progreso, Datos, Monetizacion, Antitrampas, Analitica, Economia,
  Recompensas…; la lista entera en CLAUDE.md "Verificar") DENTRO de la VM del servidor.
  Existe porque la barra de comandos / execute_luau corren en la VM del plugin y
  allí `require` devuelve copias vacías de los módulos. Desde el 22 oct las
  que mueven al jugador pasan por `Comunes.teletransportar` (si no,
  `Movimiento` lo toma por un salto del cliente) y las que lanzan, por
  `Comunes.llenarBolsa` (el servidor solo lanza bolsas llenas).
- `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir", "Tienda")` abre
  paneles desde la VM del cliente; `("modulo", nombre, accion, ...)` llama a
  `require(nombre).prueba[accion]` de un ModuleScript del cliente (o de
  `ReplicatedFirst`): así se prueban `Sonido`, `Carga` y `Recompensas` sin
  tocar `PruebasCliente`, que desde el 22 oct ya no se edita.
- Si el hilo del MCP no puede invocar BindableFunctions ("additional values for
  the Capabilities property", visto en Studio tras reabrir el place), la misma
  prueba se lanza por atributos (ese hilo tampoco puede crear ni mover scripts
  ni usar HttpService: para sincronizar codigo en ese caso solo queda el plugin
  de Rojo): `ServerStorage:SetAttribute("Prueba",
  "3:montonPiezas")` (número de orden + nombre|args) y el texto queda en el
  atributo `Resultado`; en el cliente `ReplicatedStorage` con `PruebaCliente` /
  `ResultadoCliente`. El número evita ejecuciones dobles con señales diferidas.
- Multijugador: Studio → Test → *Clients and Servers* (2 jugadores). Ver
  `README-pruebas.md` (también qué mirar de `Movimiento` y del bloqueo de
  sesión). En Studio las sesiones de otro Play se dan por caducadas: no hay
  que esperar entre un Play y el siguiente.

## 3. Decisiones no obvias (y por qué)

### Lanzamiento por agentes (22–23 oct)

Petición del usuario: analizar todo lo que falta para lanzar y trabajarlo
con los agentes. Una auditoría de tres frentes (el código, el place en
Studio y el producto frente al GDD y a otros simuladores) concluyó que el
bucle estaba completo y el mundo íntegro, pero que no se podía abrir: pases,
producto e insignias con id 0, la ficha vacía, Max players en 60, un
guardado frágil (un guardado se descartaba si coincidía con otro, el cierre
no esperaba, no había bloqueo de sesión y la compra no se guardaba), Studio
escribiendo en el DataStore real y ni un sonido; en el producto, un R1 a las
2–4 h, nada nuevo tras el R3 y ninguna recompensa por volver. El plan
aprobado (`de-acuerdo-analiza-el-soft-rossum.md`, en los planes de Claude
Code, fuera del repo) lo reparte en fases (0 punto de partida, 1
endurecimiento, 2 producto base, 3 economía y retención, 4 imágenes y
Creator Hub, 5 verificación, 6 lanzamiento en dos tiempos) y paquetes.

**Decisiones del usuario** (22 oct): commit por paquete verificado y push al
cerrar cada fase; el Creator Hub lo hace `roblox-publisher` en su Chrome y se
para antes de fijar precios, enviar el cuestionario, hacerla pública o gastar
Robux; pulir antes de abrir (lo social y los códigos, después); el R1 en
45–60 min, con el número que recalcule `game-designer` y apruebe él;
**perfiles desde cero** en `ReciclatasPerfiles_v4` y rankings v2 (el store
v3 se abandona, no se borra); **admin solo en Studio**; permiso para
re-hornear; insignias gratis, 5 al día (Roblox cobra 100 Robux por cada una
más).

**Cómo se trabajó.** Una sesión orquesta: lanza cada agente con su brief, le
da **turno de Studio** (hay uno solo con MCP; hasta 3 paquetes de código a
la vez si no comparten archivos) y une su trabajo. Cada paquete edita solo
sus archivos, pide las claves de texto que le falten en vez de inventarlas,
pone sus pruebas en su `PruebasDefinidas/<Área>` y cierra con sus pruebas y
las que afecta, la consola limpia, la revisión de `code-reviewer` y un
commit local. Los archivos calientes tienen un solo dueño en cada momento;
`Textos` y sus traducciones solo los tocan las "ventanas de copy" C1, C2 y
C3, que añaden de una vez las claves de su fase en los tres idiomas (van
antes que el código: `Idioma.mensaje` falla con una clave que no existe).
Los agentes en worktree no pueden escribir en la carpeta principal:
devuelven sus archivos y el orquestador los une.

Lo no obvio de cada paquete:

- **W1, re-horneado** (22 oct): las placas de los contenedores salen
  traducidas y con la tilde bien ("ORGÁNICO"). Además `ArteMundo.caja`
  tomaba `Paleta.BASURA.Papel[1]`, que sigue al color del tipo: desde que el
  papel pasó a celeste (6 oct) las 6 cajas de la caseta salían celestes;
  ahora llevan `Paleta.MUNDO.CARTON`. Mismos conteos (1.054).
- **C1, copy y limpieza**: fuera 7 textos sin uso (`HUD.lanzar`, `HUD.cerrar`,
  `PATIO.figurinaYaTienes`, `TIENDA.comprar`, `TIENDA.equipado`,
  `NOTIFICACIONES.guardado`, `NOTIFICACIONES.tesoro`), los iconos gema, sobre,
  contenedorDorado y pocion y el glifo gema (los glifos sobre y
  contenedorDorado se habían quedado y se borraron el 23 oct); `sinRestos`
  falla si vuelven.
- **P1, guardado v4** (y los arreglos de su revisión, el mismo día):
  `Services/Guardado` hereda el guardado de `DataService` (que queda como
  cableado), sigue sin ProfileStore y pone el bloqueo de sesión dentro de
  `UpdateAsync` (ver "Persistencia propia" más abajo). Lo no obvio:
  - un **token por carga**: con la carga lenta, salir y volver a entrar en el
    MISMO servidor no pierde la sesión (lo que queda del Player viejo ya no
    se la quita al nuevo);
  - el robo de una sesión viva se cancela si el jugador se va o el servidor
    cierra, y espera 60 s (por encima del peor caso de una salida lenta;
    robar antes dejaría sin guardar lo último jugado allí);
  - un perfil de una **versión más nueva** que el código (lo escribió un
    servidor ya actualizado) se juega sin guardar (`versionNueva`);
  - la carga en segundo plano tras un fallo conserva el provisional si no
    había partida y, si la había, la sustituye y avisa (`progresoRecuperado`);
  - en Studio las sesiones de otro Play ("Studio-…") se dan por caducadas;
  - `Perfiles.alSalir` llega **antes** del guardado de salida y sustituye al
    `task.wait(0.2)` de `PlayerRemoving`; `Perfiles.anterior` es el perfil
    tal como llegó (`registrar` pisa `ultimaSesion`); el atributo
    `PerfilListo` (nil cargando, true o false) es lo que espera la pantalla de
    carga, y `ServerStorage.SimularCargaLenta` (solo Studio) retrasa la carga.
- **P2, monetización**: Roblox deja de reintentar un recibo confirmado, así
  que `PurchaseGranted` solo con la compra **guardada**; si el guardado
  falla, `NotProcessedYet` y lo otorgado queda anotado (el reintento no lo
  repite). Antes un `/pases on` en el juego publicado daba todos los pases a
  todo el servidor: el modo dev y los comandos solo existen en Studio (sin
  autocompletar; `/dar` acotado y fuera de las estadísticas, para no ensuciar
  rankings ni insignias). Las insignias se consultan con
  `CheckUserBadgesAsync` en lotes de 10 y caché de la sesión.
- **P3, anti-trampas** (y su revisión de seguridad **P3b**, 23 oct):
  - Antes solo el cliente exigía la bolsa llena y uno modificado farmeaba
    aciertos, rachas, pedidos e insignias con una pieza: ahora lo exige el
    servidor.
  - Tope de 3 bolsas caídas por jugador (sin tope, un cliente que lanzara sin
    parar llenaría el patio de modelos): con una más, la más vieja se recicla
    sola sin bonus y **a x0,5** (decisión del usuario, 23 oct: a x1, tirar
    bolsas al suelo cobraba sin andar hasta el contenedor).
  - El primer tiro sigue entrando siempre, pero paga como mucho la distancia
    del Brazo y no cuenta para récords: un novato que lanzaba desde el patio
    cobraba +150 % y se llevaba "Francotirador" con un récord imposible de
    batir.
  - Al salir se cobra sin bonus también lo que está en el aire, en `alSalir`
    (en `PlayerRemoving` no había orden con el guardado: se cobraba quizá
    después de guardar, o la bolsa se quedaba en el suelo de alguien que ya
    no estaba).
  - **`Movimiento`** nunca expulsa ni devuelve al personaje a su sitio (lo
    simula su cliente, y corregirlo pelearía con el lag): hace que el salto no
    sirva. Mide con un **crédito** de distancia y no muestra a muestra, para
    que el lag (el personaje parece quieto y luego llega todo el camino) y los
    empujones de la física no cuenten; la vertical no se mide. Margen medido
    en Studio (P3b): andando hay picos de 1,44x, sobre una montaña recién
    excavada 1,75x; `FACTOR_VELOCIDAD` 2,5 → **1,8** con ráfaga de 2,1 s (el
    crédito guarda lo mismo y el ritmo sostenido baja). P3b además:
    `sospechoso` mide la posición de ese instante (un teletransporte y una
    acción en el mismo frame ya se cogen), `permitirSalto` mide desde el
    destino y la entrega a mano también se bloquea.
  - **Un bug real del vuelo**: se integraba con Euler y la bolsa quedaba
    0,5·g·t·dt por debajo del arco de la línea de ayuda (0,4 studs corta a 60
    fps, 0,8 a 30): acertar dependía de los fps del servidor (`lanzarATipo`
    pasaba 2 de cada 6). Ahora paso exacto (`pos += vel·dt + g·dt²/2`): 7 de 7.
  - El bucle de la pose de brazos del servidor solo corre en Studio: en un
    juego publicado nadie mira la vista del servidor (`poseSinBucle`).
- **L1, pantalla de carga**: el servidor solo crea el personaje con el perfil
  cargado, y con el DataStore lento se veían hasta 15 s de nada justo en el
  primer minuto. Vive en `ReplicatedFirst` sin Fusion ni el Kit (corre antes
  de que llegue `ReplicatedStorage`, y ningún `require` de ahí antes de
  `game:IsLoaded()`: un ModuleScript que falla al cargarse queda roto para
  todo el cliente), con los colores **copiados** de `Paleta` (el gancho
  `("modulo", "Carga", "estado")` los compara). `PreloadAsync` con el texto `rbxassetid` pedía otro
  tipo de asset (22 de 23 iconos fallaban): precarga una `ImageLabel` o un
  `Sound` por id. El consejo de la tecla F no sale en táctil ni con mando, y
  en móvil el consejo crece dentro de una zona fija (`AutomaticSize` solo
  crece dentro de su padre).
- **N1, analítica**: todo en pcall (si AnalyticsService falla, el juego
  sigue; un aviso por minuto como mucho) y los campos en tramos (Roblox
  admite 3 campos propios y 8.000 combinaciones por experiencia). En Studio
  el servicio de verdad escribe una línea "event fired" por llamada (49 en
  una tanda de pruebas): `ENVIAR_EN_STUDIO` va apagado y las pruebas miran
  `Analitica.registro`. Lo que Bolsa recicla sin señal (al salir, por el
  tope de bolsas) se cuadra al salir como `Reciclaje_SinBonus`: una fuente de
  dinero nueva que no pase por `Analitica` saldrá ahí. Roblox aún no enseña
  `LogProgressionCompleteEvent` en ningún gráfico: el rebirth va también como
  evento propio. La plataforma la dice el cliente y el servidor la valida;
  nada del cliente se reenvía tal cual.
- **A1, audio** (decisión del usuario: los recomendados de
  `docs/Audio-propuesta.md`, de la biblioteca con licencia de Roblox, que él
  escuchará jugando y cambiará en `Config/Sonidos`): nadie más crea `Sound`s;
  un toque reutiliza voces de una plantilla por clave. Lo que suena en un
  cliente no se replica: los 3D que oyen todos (bolsa lanzada, golpes,
  recicladoras) los reproduce cada cliente al ver el evento. Hasta que llega
  el primer perfil la música está a 0 (no se sabe si el jugador la quitó).
  El botón Sonido nació sin tecla y en PC no se podía abrir (sin panel, el
  ratón está bloqueado al centro): desde entonces **cada botón de panel lleva
  su tecla**, M en este.
- **C2 y C3, copy y contrato**: secciones `CARGA`, `SONIDO`, `RECOMPENSAS` y
  `OFERTAS` y los nombres nuevos en `DEF`, en los tres idiomas. En portugués,
  "cheio/encher" del saco pasa a "lotado/lotar" (en Brasil "encher o saco" es
  fastidiar). C2 añadió el gancho `("modulo", nombre, accion, ...)` de
  `PruebasCliente`. C3 dejó el contrato de E1, R1 y K1 sin lógica de juego:
  perfil v5 (`turboRestante`, `recompensas`, `ofertas`, `compras`; completar
  clave a clave a cualquier profundidad); `Services/Actividad`, sin
  dependencias de otros servicios porque la requiere `Turbo` (y `Bolsa`
  requiere `Turbo`); `costeSiguiente` con las mejoras **desde cero** y no con
  las que le faltan al jugador (un premio solo cambia al renacer, no baja al
  comprar mejoras) y `redondear` (dos cifras significativas, como el
  documento); el botón Recompensas en el sexto hueco con la tecla **G** (E es
  de los prompts; F, Q, T, R, P, V y M ya estaban) y su punto rojo arriba a la
  izquierda (la tecla va arriba a la derecha). Las recompensas tienen **panel
  y botón propios** (el documento las ponía en una pestaña de Pedidos).
  `Oferta` quedó como ventana vacía sin botón ni tecla: la abrirá el servidor.
- **E1, ritmo** (números en §4): el factor de las mejoras baja a 1,35 con los
  mismos costes base (con 1,6 el 76 % del gasto estaba en los tres últimos
  niveles y el final de cada tramo se hacía eterno); multiplicadores redondos
  (x3, x4, x5…) porque con +0,5 renacer valía un 17–20 % y dejaba de notarse;
  los pedidos pasan a un % del siguiente rebirth (antes, ~1 % del R1: nadie lo
  notaba), calculado al cobrar (si renace a media tarde, lo pendiente vale lo
  del rebirth nuevo). **El día cambia a las 06:00 UTC** (decisión del
  usuario): a medianoche UTC los pedidos cambiaban a las 19–21 h en
  Latinoamérica, en plena tarde de juego; a las 06:00 es de madrugada en
  América y por la mañana en España. **Pedido VIP**: con el pase, un 4.º
  pedido de las plantillas que no salieron, que paga como difícil y no cuenta
  para el Turbo de los tres; si el pase llega con el día empezado, se añade al
  momento (`Monetizacion.alCambiarPases`). Otras decisiones del usuario al
  aprobar la economía: el Turbo solo correrá mientras se juega (K1), VIP a
  249, y el tramo desde el R3 se lanza tal cual y se mide.
- **R1, recompensas**: saltarse un día del calendario no reinicia nada (con
  público infantil, perder lo acumulado por no entrar es presión, y Roblox
  pide no presionar a los menores). Los regalos cuentan los minutos activos
  **del día** y no de la sesión (por sesión, entrar y salir cada 5 min
  rendiría más que jugar); `Actividad.alAccion` llega como mucho una vez por
  segundo, así que "3 acciones en un minuto" son 3 segundos con algo hecho y
  un autoclicker no suma más. El regreso se mira una vez por perfil con
  `Perfiles.anterior` (no depende de que otro oyente ya tocara
  `ultimoDiaJugado`) y nunca a un jugador nuevo. Al cobrar, primero el estado
  y después el pago: lo peor es no cobrar, nunca cobrar dos veces; un día
  guardado por delante del de hoy (si cambia la hora del día) tampoco deja
  cobrar dos veces.
- **Estado transitorio del Turbo** (22–23 oct, resuelto con K1): entre C3 y
  K1, `Services/Turbo` seguía con la hora de fin (`perfil.turboHasta`, tiempo
  real), pero desde la v5 del perfil `turboHasta` es OBSOLETO y `completar` lo
  borra al cargar, y nada leía aún `turboRestante`: un Turbo en marcha no
  sobrevivía a salir y volver, y las pruebas de pedidos tenían que restaurar a
  mano un `turboHasta` que no estaba (`premioTurbo` dejaba 660 s de Turbo que
  doblaban el dinero de las siguientes: `salirRecicla` daba $124 en vez de
  $62). Hoy solo quedan la migración v5, `OBSOLETOS` y comentarios.
- **K1, catálogo** (23 oct; verificado en Lune y en Studio):
  - El Turbo descuenta con el reloj de `Actividad` (las pruebas lo sustituyen)
    y entre dos tics cuenta solo hasta la última acción + 120 s: las cuentas
    salen exactas aunque el reloj salte. **En pausa sigue pagando x2**: lo que
    paga es reciclar, y reciclar ya es una acción que lo reanuda (si no, la
    bolsa lanzada tras un rato quieto pagaría x1 con el HUD diciendo x2).
    **Entrar no es jugar**: el Turbo empieza en pausa y arranca con la
    primera acción (no se llama a `Actividad.registrar` al entrar). Mientras
    corre, el perfil se publica cada 30 s para que el HUD no se desvíe; el tic
    va en `pcall` por jugador.
  - El tope de 3 h solo apaga los botones (tienda y ofertas): `ProcessReceipt`
    nunca rechaza una compra pagada, así que un recibo que llegue igual se
    otorga entero.
  - El Pack da su Turbo **una vez** (`compras.packInicio`), solo con el pase de
    verdad en `pasesCache` (el modo dev no lo da: no se envenena el perfil) y
    con el perfil guardable (un provisional se descarta y lo daría dos veces);
    se mira al cargar, al cambiar los pases y en cada tic.
  - Ofertas: el servidor manda la oferta con un **token** y solo cuenta la
    que el cliente llega a enseñar ("mostrada"); en ese momento se vuelven a
    pasar las reglas (si mientras esperaba compró algo o le llegó Turbo, se
    cancela). Una compra cancela la que espera. "Cerrada" (otro panel encima)
    no es un "Ahora no"; la X y Esc sí. Los intentos con la bolsa llena los
    avisa el cliente (ControlPatio no pide el reclamo con la bolsa llena) y el
    servidor solo los cuenta si la bolsa está llena de verdad, uno por segundo.
    "n por semana" de una oferta se cumple separándolas 7/n días (el perfil
    solo guarda la última vez de cada una): más estricto que el documento,
    nunca más permisivo. El Pack, que espera al cobro del calendario, sale en
    la práctica en el primer depósito pasado el minuto 3.
  - **En Studio las ofertas no salen solas** (`ServerStorage.OfertasEnStudio`):
    con los ids reales, cualquier prueba que deposite abriría una ventana de
    compra a mitad de la batería y se contaría en el perfil de Studio.
  - La pista de música del Turbo suena solo mientras corre, y sus
    repeticiones se cuentan por Turbo, no por cada pausa.
- **Q4b, revisión de todo el diff desde `base-lanzamiento`** (23 oct): nada
  que rompa el juego ni que cobre o pague dos veces. Arreglado ese día:
  - La compra de un pase sigue confirmándose con `UserOwnsGamePassAsync` (la
    decisión de P2: el "comprado" del evento no es prueba de pago, y en la
    comunidad hay quien dice que se puede falsear), pero con esperas que
    doblan hasta ~1 min (consultas a los 0, 2, 6, 14, 30 y 62 s): Roblox
    recuerda un "no" unos 10 s (medido por la comunidad), y con 3 consultas
    en 4 s una primera hecha antes de que la compra se viera dejaba el pase
    sin aplicar hasta volver a entrar. La guía oficial de Roblox otorga con el
    evento sin más; la Q3 dirá cuánto tarda de verdad.
  - Sin perfil no aparece el personaje hasta `SESION_ESPERA_ROBO` + 15 s (la
    pantalla de carga aguanta 90): con 15 s, mientras otro servidor soltaba
    la sesión se jugaban ~45 s sin perfil y lo reciclado se perdía. Y sin
    perfil, los remotes de recoger y lanzar se ignoran, como los prompts.
  - Pedidos solo cambia de día hacia delante ("menor que", como Recompensas):
    un día guardado por delante del de hoy volvía a generar y pagar los del día.
- **Ficha y Creator Hub** (22 oct, `docs/Ficha-lanzamiento.md`; decisiones
  del usuario): nombre **"Recíclatas: Lanza la Basura"** (en "Throw the
  Trash", pt "Jogue o Lixo"), que sustituye a "Garbage Collector" (chocaba
  con *Garbage Collector Simulator*, con el término de programación y con el
  nombre que el juego enseña dentro); descripciones en los tres idiomas;
  género Simulación → **Simulador incremental** (solo se cambia cada 3 meses:
  bloqueado hasta el 18 nov); PC, móvil y tableta (consola apagada hasta una
  pasada con mando); **Max players 6**; servidores privados a 50 Robux al
  mes; el icono de la propuesta 1; idioma fuente español con **la traducción
  automática del contenido apagada** (las traducciones son las nuestras, ver
  "Idiomas"); cuestionario de madurez enviado (Minimal). Sigue privada:
  hacerla pública es del usuario, primero para 16+ y después Roblox Select.
- **Imágenes de lanzamiento** (I1a, 22 oct): renders de Blender a 512×512 sin
  texto en `thumbnails/` (3 propuestas de icono, la 1 copiada a
  `icon_512.png`; las 20 insignias en bronce, plata y oro; los 6 pases y los 2
  productos con recorte circular); el `.blend` de trabajo
  (`thumbnails/blender/`) explica cómo volver a renderizarlas.
- **Herramientas**: Rojo en bucle, el instalador HTTP con LF y
  `ReplicatedFirst`, y Studio abierto por shell (§2 "Sincronizar código").

### Tablones de ranking en la plaza (8 oct)

Petición del usuario: tablones de **Dinero ganado**, **Racha máxima** y
**Bolsas encestadas**, solo en la plaza (nada en la lista de jugadores),
cada uno con **histórico** y **semanal** (se reinicia el lunes 00:00 UTC),
con el modelo del usuario "Leader Board".

- El modelo vive en `ServerStorage.Arte.LeaderBoard` (se movió desde
  workspace; solo existe en el place, como las mallas). La pantalla es su
  parte `background wall`, cuya cara Front es el frente del modelo.
  `ArteMundo.tablonRanking` lo clona (sin él, un tablón de partes),
  etiqueta la pantalla `PantallaRanking` con atributo `Ranking`, y choca y
  es consultable (la bolsa rebota). `ConstructorMundo` los pone en
  `LAYOUT.TABLONES`: césped del este donde acaba la calle (x 41, z 74/89/104)
  mirando al spawn, fuera de las líneas de tiro del patio a los
  contenedores. `ConstructorMundo.rehacerTablones()` los rehace sin hornear
  todo (así se pusieron).
- Definiciones en `Config/DefinicionesRankings` (de qué estadística sale
  cada uno; suma o máximo). El **semanal** de las sumas es lo de ahora menos
  la foto del lunes (`perfil.semana.base`, `Perfiles.semanaAlDia`); el de la
  racha, el máximo de la semana (`perfil.semana.maximos`, en
  `estadisticaMaxima`). Lo jugado antes de que existiera esto no cuenta para
  la primera semana.
- `Services/Rankings`: un OrderedDataStore por ranking y periodo
  (`Ranking_v<VERSION>_<id>_Historico` / `_S<semana>`; en Studio el prefijo
  lleva `_Studio` para que las pruebas no ensucien los del juego). Desde el
  22 oct `DefinicionesRankings.VERSION` = 2: tablones limpios para el
  lanzamiento, con los perfiles v4 desde cero. Escribe cada 2 min solo lo que
  cambió (y al salir, en `Perfiles.alSalir`, antes del guardado; al cerrar el
  servidor se esperan las escrituras), lee cada 2 min el top 100 (una página: cada cliente
  ve su puesto aunque no esté en el top 10) y los DisplayName del top 10
  por `UserService` en lote. `RankingsHandler` lo manda a todos
  (`RankingsEvent`).
- `Client/Tablones` pinta un SurfaceGui local por pantalla (Fusion + Kit):
  título del color del ranking, dos columnas con el top 10 (medallas,
  cara del avatar por `rbxthumb`, nombre, valor) y al pie tu fila, con tu
  valor en vivo desde el perfil y tu puesto de la última lectura.

### Idiomas: inglés y portugués con módulos Luau (7 oct)

Petición del usuario: el juego en inglés y portugués; el español sigue
siendo el original y el respaldo, y cualquier otro idioma sale en español.
**No se usa la `LocalizationTable` ni la traducción automática de Roblox**:
las traducciones son `Config/Traducciones/{en,pt}.luau`, tablas parciales
con la forma de `Textos` (más `DEF`, los nombres de mejoras, pases,
productos, insignias y cosméticos por id). Así funcionan igual en Studio y
en producción, no hay que exportar CSV y la prueba `idioma` ve las claves que
faltan, las que sobran y los `{marcadores}` distintos. `AutoLocalize = false`
en nuestras GUIs para que Roblox no traduzca encima si algún día se activa
Automatic Text Capture (que **no** hay que activar: captura los textos ya
formateados, "+35 %", "+36 %"…, y llena la tabla de basura).

- `Utilidades/Idioma` elige el idioma (`Player.LocaleId` → "en-us" → `en`)
  una vez al cargar: un cambio de idioma a mitad de partida se aplica al
  volver a entrar. El cliente lee `Idioma.textos` (la misma forma que
  `Textos`, ya traducida) en vez de `Config/Textos`.
- **El servidor no envía texto montado**: no sabe el idioma de cada jugador.
  Envía `Idioma.mensaje("SECCION.clave", valores)`; los valores pueden ser
  otro mensaje (un material, el nombre de una mejora con
  `Idioma.mensajeNombre`) o un número con formato (`Idioma.dinero`,
  `miles`, `multiplicador`), que cada cliente escribe con sus separadores
  (inglés `$12,500` / `x1.5`; español y portugués `$12.500` / `x1,5`, en
  `Formato.configurar`). Las insignias viajan por id.
- Lo que el servidor escribe en instancias lleva el mensaje en un atributo
  JSON (`Idioma.codificar`): `MensajeObjeto` en el prompt del montón,
  `Mensaje` en la etiqueta "Bolsa de X" y en las placas horneadas de los
  contenedores. `TraducirMundo.client` y `Prompts.client` lo usan; lo que no
  lo tiene se traduce por búsqueda inversa del literal (`Idioma.literal`:
  "Excavar" → "Dig", "Patio de basura ↑").
- Las placas de los contenedores ("PAPEL · x2") llevan su atributo desde el
  re-horneado del 22 oct (W1); antes salían en español y con la tilde mal
  ("ORGáNICO", que el horneado arregla con `Idioma.mayusculas`).
- **Excepción (22 oct): `Player:Kick`** solo admite texto plano, así que el
  servidor resuelve él el aviso de la sesión abierta en otro servidor:
  `Idioma.resolver(Idioma.mensaje(...), Idioma.normalizar(jugador.LocaleId))`
  (Guardado).
- Se quedan en español a propósito las figuritas y las cintas (pospuestas)
  y el rótulo "SHOP" (las letras son de la malla).
- Para probar otro idioma en Studio: atributo `IdiomaStudio = "en"` en
  `ReplicatedStorage` en Edit, antes de Play (solo cuenta dentro de Studio;
  quitarlo después), o Test → Player Emulator → Locale.
  `LocalizationService.ForcePlayModeGameLocaleId` por script **no** cambia
  `Player.LocaleId`.
- En el Creator Dashboard (Localization) se traducen a mano el nombre, la
  descripción, los pases, los productos y las insignias: esos textos los
  enseña Roblox, no el juego. Hecho el 22 oct: el nombre y la descripción en
  los tres idiomas, el español como idioma fuente, la traducción automática
  del contenido apagada y las 10 insignias creadas; los pases, los productos y
  las insignias que faltan se traducen al crearlos (§5).

### Fuera los trajes (5 oct)

Decisión del usuario ("quita los trajes"), tras ver que en la tienda salían
"Próximamente": se borró el sistema entero, como las mascotas el 3 oct. Los
2 trajes de pago (Traje Dorado, Fantasma del Vertedero) y los 3 gratis del
botín (ya pospuestos tras `TRAJES_BOTIN`, que desaparece), vestir al
personaje (BodyColors + accesorio), `PonerTrajeEvent` y los campos
`trajes`/`trajePuesto` del perfil (`Perfiles.completar` los borra de uno
guardado, OBSOLETOS). La pestaña Estilo queda con los diseños de bolsa y
la estela. `TablasProbabilidad.COLECCIONABLE` pasa a figurita 60 / cinta
40 (misma proporción que 50/35). `sinRestos` y `perfilV3` (hoy `perfilV5`)
lo comprueban.

### Lanzamiento: v3 (3 oct)

Petición del usuario: *"acabemos de una vez el juego y lancémoslo"*, con
cuatro cambios y "completar todo (L7–L9)". Decisiones suyas (preguntadas):

- **Un contenedor por tipo de basura y uno general** que acepta todo, cada
  uno de su color. Cómo pagan, elegido entre tres: **premio por separar**:
  basura en el de su tipo x2, en el de otro tipo x0,5, en el general x1;
  billetes y tesoros x1 en cualquiera (`GameConfig.MULT_SEPARADO` /
  `MULT_MAL_SEPARADO`, `Bolsa.factorContenedor`, única regla). La bolsa no
  se reparte entre contenedores: separar es recoger por colores antes.
- **Colores** (los dio el usuario): papel celeste (era cartón suave; el 6 oct
  se cambió porque en sus tonos oscuros se confundía con el amarillo del
  plástico; el arte horneado del contenedor de papel se repintó a mano),
  plástico amarillo,
  metal plomo metálico, orgánico verde, general azul; **cada pieza de
  basura en un tono distinto de su color** (`Paleta.tonos`: dos hacia
  negro, el color y dos hacia blanco). `Paleta.MATERIAL` es ahora
  `Paleta.TIPO`: suelos de zona, barreras y glifos cambiaron solos. Las
  mallas de `Arte.Basura` traían una textura de paleta que tapa `Color`: se
  le quita al clonar (`TextureID` se puede escribir en runtime, medido).
  Las llantas ya no son negras.
- **Ubicación**: los 4 en fila sobre la solera al este de la caseta (local
  x −14,25 … −34,35, z 6, de 5,5 × 4,5 × 4, más pequeños que el general:
  pagan el doble, que cueste acertar), mirando a la plaza; el general es el
  volquete de la recicladora repintado de azul (`pintarPiezaRecicladora`:
  todo lo que cuelga de `Contenedor`). Los neumáticos, el barril y la bolsa
  de la solera pasaron detrás de la fila; los barriles del lote este, a un
  lado; el poste de luz de local x −14 a −10,5 (tapaba el de papel).
- **Fuera las mascotas** ("creo que es mucho trabajo para implementar"):
  borrados `DefinicionesMascotas`, `ModelosMascota`, `Mascotas`,
  `Fragmentos`, `Seguidores`, `Iman` (el imán solo venía de las mascotas),
  `MascotasHandler`, `UI/Mascotas`, `UI/Revelacion`, sus 3 RemoteEvents y
  sus pruebas; el 2,5 % de fragmentos volvió a basura. `sinRestos` lo
  comprueba (también los campos del perfil).
- **Tienda**: el nivel de cada mejora es una **barra de 10 cuadros**
  (`Kit/Segmentos`) y no se menciona studs: fuera "25 studs → 29,5 studs",
  `textoValor`, `unidad`, `Formato.studs`; los avisos de distancia dicen
  "m".

Decisiones mías donde no se concretó (revisables):
- Contenedores de tipo con su cartel "PAPEL · x2" con el borde de su color
  (Escena) y una placa en el frente; el general, "GENERAL · TODO".
- Lanzar: no se lanza a menos de 6 studs de NINGÚN contenedor; el bonus de
  distancia se mide al contenedor en el que entra; una vez que la bolsa
  choca con una pared ya no entra en ninguno (como antes con uno).
- **Pedidos** (L7): se cobran solos al cumplirse (sin botón que olvidar);
  se abren con la primera mejora (paso 5 del tutorial); plantillas nuevas
  `separadas`, `material` y `lejos`; completar los tres da **10 min de
  Turbo** (dinero x2), el mismo efecto que el producto de Robux.
- **Insignias** (L7): 16 por estadísticas del perfil (y "mejoras al
  máximo"), comprobadas en cada publicación del perfil (`Perfiles.
  alCambiar`, ≤ 4/s): barato y ningún módulo tiene que avisar. Badge solo
  con id ≠ 0; quien ya la tenía la recibe al entrar cuando se rellene. (Son
  20 desde la economía v4, 22 oct.)
- **Catálogo** (L8, precios provisionales): Dinero x2 199, Bolsa XL 149,
  Estela arcoíris 99, Bolsa dorada 99, Turbo 15 min 49 (producto, se
  acumula). El Rebirth 3 regala la Bolsa plateada (era la segunda
  mascota). La economía v4 (22 oct) mantiene esos precios y añade el Pack de
  inicio (99), el VIP (249) y el Turbo 60 min (149). `PASES_DEV_EN_STUDIO` pasa a false: con Dinero x2 en Studio
  las pruebas de pago fallarían (`/pases on` para probarlos).
- **Tutorial** (L9): tres pasos más (separar ≥ 3 bien y más bien que mal,
  un pedido, el Rebirth 1, que queda como meta a la vista); se enseña en
  una píldora arriba a la izquierda (en táctil, bajo la botonera) que abre
  el panel del paso. Los perfiles con los 5 viejos hechos siguen por el 6.
- **Tercera persona** (L9): "shift lock" propio en `Camara.client` (zoom
  fijo 11, `CameraOffset` al hombro, ratón al centro, el personaje gira con
  la cámara cada frame); la mira sigue en el centro y `ControlPatio` ya
  excluía al personaje del rayo. Las manos 2D solo en primera persona.
- La pista "mantén para recoger" pisaba las barras (aviso viejo de
  `("hud")`): ahora abajo a la izquierda en PC y bajo los contadores en
  táctil.

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
(`FIGURINAS`, `CINTAS`; `TRAJES_BOTIN` se fue con los trajes el 5 oct); al quitar las parcelas el mapa se
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
| L7 | Pedidos diarios y 16 insignias (3 oct: el premio de los tres es un Turbo, ya no fragmentos) | hecho |
| L8 | Tienda, pases y cosméticos (Dinero x2, Bolsa XL, estela, diseños de bolsa, Turbo; sin Tercera mascota) | hecho |
| L9 | Tutorial "primeros 15 minutos" (8 pasos con píldora) y cámara primera/tercera | hecho |
| L10 | Medición (viaje y acierto) con jugadores; GDD al día (`docs/Juego.md` se reescribió el 23 oct) | pendiente (tras publicar; la regla de recalibración en §4) |

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

(Tabla del lote 7: desde la v2 no hay `Energia` y desde el 3 oct tampoco
`Iman` ni `Mascotas`; los demás módulos siguen igual.)

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

(El Imán se fue con las mascotas el 3 oct: hoy solo se recoge con el clic o,
en táctil, con la mira y el botón RECOGER. Lo del Imán queda como historia.)

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

### El pity es por jugador y persiste (histórico)

(Sin pity ni rarezas desde la v2 y sin mascotas desde el 3 oct; queda como
historia.) Cada monton sin Rara+ suma 1; una Rara+ lo resetea. La probabilidad se calcula
en `TablasProbabilidad.probabilidadRara` (8% + 2%·pity, tope 60%; el Pase de la
Suerte sube el paso a 3%). Medido con 300 montones grandes: pity 0 → 6%, pity
10 → 37%, pity 26 → 57% (teóricos 8/28/60). Los fragmentos usan tabla plana con
sesgo del 50% hacia mascotas a medias para que el ensamblaje converja.

### `TablasProbabilidad` es la única fuente de odds

El servidor (`GeneradorBotin`) lo lee de ReplicatedStorage, para que
cualquier número que se enseñe al jugador sea el que se usa de verdad;
`verificar()` hace assert al cargar de que cada tabla suma 100. Era el
requisito de política de Roblox sobre ítems aleatorios pagados (lo leían
también `Tienda` y el panel `Probabilidades`, que ya no existen); hoy no se
vende nada aleatorio.

### Persistencia propia, sin ProfileStore

Cero dependencias (no hay Wally). Desde el 22 oct (P1) todo vive en
`Services/Guardado` y `DataService` solo cablea. Reglas: todo en `pcall` con
reintentos y avisos con `warn` (un DataStore caído no impide jugar); un
perfil que no cargó nunca se guarda (`Perfiles.estaCargado`: se juega con el
de por defecto y se reintenta cargar en segundo plano, a los 30 s y luego el
doble, hasta 5 min), ni uno de una versión más nueva que el código;
`UpdateAsync`; autoguardado cada 120 s; **cola por clave** (nunca dos
operaciones de la misma clave a la vez; lo que se pide guardar durante otro
guardado se junta en una ronda que escribe lo más nuevo; la salida nunca se
descarta y, si falla, se reintenta sin soltar el turno); `BindToClose` hace
salir a todos y espera hasta 25 s a todo lo que está en vuelo.

**Bloqueo de sesión** propio (antes no había: se apuntó migrar a ProfileStore
el día que hubiera servidores concurrentes, y abrir el juego es ese día). El
registro es `{ perfil, sesion = { servidor, token, latido } }` y todo se
decide dentro de `UpdateAsync`: una sesión de otro servidor con el latido de
hace 600 s o más es de un servidor que murió y se toma; una viva (el jugador
acaba de cambiar de servidor y el otro aún guarda su salida) se reintenta
cada 5 s sin escribir y se roba a los 60 s; al guardar, si la sesión ya no es
la de esta carga, no se escribe y se expulsa al jugador ("Tu partida se abrió
en otro servidor"). La sesión va al lado del perfil, nunca al cliente.

Hasta el 22 oct `PlayerRemoving` esperaba 0,2 s para guardar después de que
Bolsa tocara el perfil; ahora `Perfiles.alSalir` va antes del guardado de
salida y sus oyentes no ceden. El contexto (almacén, reloj, tiempos,
expulsión) es inyectable: las pruebas de `Datos` usan un almacén en memoria
con la semántica de `UpdateAsync` y claves de prueba.

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
- Dan $ sin pasar por el contenedor los premios, que no son botín: los
  pedidos y, desde el 22 oct, el calendario, los regalos por jugar y el bono
  de regreso (`Economia.ganar`, sin pases ni Turbo). Hasta la v2 también
  vender mascotas y los logros.

### La bolsa no persiste, y al salir se recicla sin bonus

Al desconectar (`Bolsa.reciclarSinBonus`): lo que vale dinero se paga sin
bonus de lanzamiento (entonces, sin el +25 % ni el +50 %), y los
coleccionables van al perfil si caben. Las bolsas propias que estén en el
suelo, igual. Hasta el 26 sep el
dinero se perdía (se temía un atajo: salir y volver en vez de caminar al
contenedor); la auditoría lo revirtió porque castigaba las caídas de
conexión, y sin bonus y con la vuelta a entrar el atajo no compensa. Desde
el 22 oct (P3) se hace en `Perfiles.alSalir`, antes del guardado de salida,
e incluye las bolsas que están en el aire (`Lanzamiento.cobrarAlSalir`).

### Las pasivas sólo actúan exhibidas (histórico: apagadas el 26 sep, borradas con las mascotas el 3 oct)

Las 6 mascotas del exhibidor daban +2/4/6% al reciclar su material. Con
`FUNCIONES.EXHIBIR_PASIVAS` apagada exhibir es solo para presumir; el efecto
jugable de una mascota es llevarla de acompañante.

### Modo dev de pases

En Studio, `GameConfig.PASES_DEV_EN_STUDIO` (apagado por defecto desde el
lote 8) hace que todos los Game Passes cuenten como comprados sin tocar el
perfil (viaja en `extras` del snapshot, no en `pasesCache`, para no envenenar
perfiles). `/pases on` u `off` lo cambia en la sesión. **Solo en Studio**
desde el 22 oct (P2): fuera, `fijarModoDev` no hace nada y `modoDev()` es
siempre false (antes un `/pases on` en el juego publicado daba todos los pases
a todo el servidor). Los ids reales (0 = placeholder) se rellenan en
`Config/Productos` y `Config/DefinicionesInsignias` (badgeId).

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

Mantener F carga la fuerza (1,2 s = el alcance del Brazo, hasta 70 studs); al
soltar, la bolsa sale con TODO lo que llevaba hacia donde apuntas (solo si va
llena: desde el 22 oct lo exige el servidor). Si entra en un contenedor se
recicla con el bonus de distancia y de racha (§4; hasta la v2, +50 % y +25 %
más si iba llena) y cuenta para Puntería. Si falla cae como
objeto `bolsa` que **solo su dueño** puede recoger (`item.duenoId`; 30 s,
ver abajo; como mucho 3 caídas por jugador desde el 22 oct). Hasta
el 29 sep, si no volvía a por ella en 20 s se reciclaba sola sin bonus; el
usuario lo quitó: ahora espera en el suelo, y si queda en alto (techo de la
recicladora, tapa del contenedor) se baja junto al contenedor del lado del
que lanzó (prueba `bolsaEnAlto`). Al salir del juego sus bolsas caídas se
reciclan para él sin bonus. Hasta el 26 sep la podía recoger cualquiera (decisión del usuario:
"tensión social"); la auditoría lo revirtió porque castiga al que arriesga y
con público infantil invita al acoso. **Desde el 6 oct, punto medio**
(decisión del usuario): es solo del dueño durante
`GameConfig.BOLSA_LIBRE_SEGUNDOS` (30 s) desde que se posa; después la
recoge cualquiera y se queda lo que lleva (al dueño le llega "{quien} se
llevó tu bolsa"). El servidor guarda `item.libreEn` y pone el atributo
`LibreEn` (un `workspace:GetServerTimeNow()`); `TemporizadorBolsas.client`
dibuja encima la cuenta atrás en letras ("30s", "29s"…, los últimos 5 s
en rojo latiendo, y "¡LIBRE!" en verde). Pruebas `bolsaProtegida` y
`bolsaLibre`. Reciclar por el prompt de cerca sigue existiendo, pero no
cuenta para Puntería.

La parábola se integra paso a paso en el servidor (`PivotTo`, sin física de
Roblox: determinista y el servidor decide el acierto; desde el 22 oct con el
paso exacto de una aceleración constante, porque con Euler la bolsa quedaba
por debajo de la línea de ayuda, §3 "Lanzamiento por agentes") y desde el 16 sep
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
respaldo; desde el 6 oct la de Blender, ver "Bolsa de Blender");
`lanzarBolsaFallo` apunta ahora hacia el patio (plano v3).

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
caídos y la bolsa a un lado. Desde el 22 oct ese bucle del servidor solo
corre en Studio: en un juego publicado nadie mira la vista del servidor, y la
bolsa se suelda igual entre las manos medidas (`poseSinBucle`). La bolsa abierta (`ModelosObjetos.bolsaAbierta`,
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

`ModelosObjetos` construye la basura (16 formas: 4 por material), billetes,
tesoros, figurinas, cintas y bolsas; `ModelosMonton` la colina; todos sobre
`Primitivas`: un solo vocabulario visual para el mundo y los ViewportFrames.
(`Utilidades/ModelosMascota` construía las mascotas y sus fragmentos; se
borró con ellas el 3 oct.)

## 4. Números de calibración (economía v4)

Los de la economía v4 (aprobada el 22 oct; el modelo, los tres perfiles de
jugador y los porqués en `docs/Economia-v4.md`, que sustituye a la
calibración del Diseño v2). Mandan los de `Config`; esto es para leerlos de
un vistazo. Lo primero que hay que medir con jugadores (L10) es η (la
fracción de la sesión que se pasa en el bucle) y el tiempo por pieza. Regla
del documento (§7.3): con 200 jugadores en el R1 y dos semanas de datos, si
la mediana de PC (M minutos hasta el R1) se sale de 45–60, multiplicar los 4
costes base y los 10 requisitos por k = 52 / M, una sola vez, y anotarlo
aquí.

- Mejoras: coste base 150 / 120 / 200 / 180 (Bolsa, Alcance, Velocidad,
  Brazo) × 1,35^nivel, redondeo a la unidad: el nivel 10 de Bolsa cuesta
  $2.234 y las 4 al máximo **$35.485** (eran $118.030 con 1,6). Valores:
  Bolsa 10 (+3/nivel), Alcance 6 (+1), Velocidad 16 (+1,2), Brazo 25 (+4,5)
  studs.
- Rebirths: requisito en mano $15.000 / 100.000 / 250.000 / 500.000 /
  800.000 / 1,2M / 1,8M / 2,5M / 3,5M / 5M con multiplicador x1,5 / 2 / 3 /
  4 / 5 / 6 / 7 / 8 / 9 / 10; desde el 11, requisito ×1,4 (dos cifras
  significativas) y +1. Coste del siguiente rebirth (`costeSiguiente`,
  requisito + $35.485): $50.485 / 135.485 / 285.485 / 535.485 / 835.485 con
  0 … 4 rebirths.
- Ritmo modelado del jugador medio de PC, jugando seguido, sin pases ni
  recompensas: R1 en **58 min** (`ritmoR1`: 57,9), R2 2:09, R3 3:36, R4 5:23
  y R5 **7:26** (h:min acumulados); el eficiente hace el R1 en 38 min y el
  casual o de móvil en 82. Con las recompensas y 20 min al día, el R1 llega
  al empezar la 3.ª sesión (~42 min jugados). Con Dinero x2, todo a la mitad.
- Montones: 12 chicos de 20 piezas y 6 grandes de 60 (uno por cuadrante,
  con un tesoro garantizado); una tirada por pieza: basura 94 %, billete 5 %,
  tesoro 1 %; tipo de basura 40 / 35 / 15 / 10 % papel / plástico / metal /
  orgánico, sin los que el excavador no tiene abiertos (con 0 rebirths, 53 /
  47). Valor por pieza: Papel 5, Plástico 7, Metal 15, Orgánico 25; billete
  ×6 y tesoro ×40 de su material. La basura paga x2 en el contenedor de su
  tipo, x0,5 en el de otro y x1 en el general. La primera bolsa (10 piezas,
  al general, sin bonus) sale a ~$97.
- Reposición: 45 s después de que un montón baje del 25 % (o se vacíe) se
  retiran sus restos y vuelve la colina. Prioridad del excavador: 10 s. Un
  montón a medias por jugador y como mucho 360 piezas sueltas en el patio.
- Lanzamiento: 1,2 s de carga = el alcance del Brazo. Bonus al entrar: <10
  studs 0; 10–19 +20 %; 20–29 +40 %; 30–44 +70 %; 45–59 +100 %; 60–70 +150 %;
  racha +10 % por acierto seguido (tope +50 %). Pago = valor de las piezas
  (con el factor de separar) × (1 + distancia + racha) × multiplicador del
  rebirth × 2 con Dinero x2 × 2 con Turbo. Bolsa fallada: 30 s solo de su
  dueño, después de cualquiera; como mucho 3 caídas por jugador (con una
  más, la más vieja se recicla sola, sin bonus y a x0,5).
- Pedidos: 1,5 / 2 / 3 % de `costeSiguiente` (fácil / medio / difícil):
  $760 / 1.000 / 1.500 con 0 rebirths y $2.000 / 2.700 / 4.100 con 1. Los
  tres del día suman ~6,5 % del siguiente rebirth y dan 10 min de Turbo; el
  Pedido VIP paga como difícil.
- Recompensas: calendario 2 % · 2 % · Turbo 10 min · 3 % · 3 % · Turbo 15 min
  · 4 % (+ Turbo 15 min en la 7.ª desde la 2.ª vuelta); regalos a los 5 / 10
  / 20 / 30 / 45 / 60 minutos activos del día: 0,5 % · 0,5 % · 1 % · Turbo 5
  min · 1 % · 2 % (minuto activo: 3 acciones o más); regreso tras 3 días
  Turbo 15 min + 4 %, tras 14 Turbo 30 min + 8 %. Jugando 20 min al día, todo
  suma ~10 % del siguiente rebirth y ~13 min de Turbo al día. Ningún premio
  en dinero lo multiplican pases ni Turbo.
- Turbo: x2 a lo reciclado; 10 min por los pedidos, 15 y 60 min por Robux,
  30 min con el Pack de inicio. Solo corre jugando (K1: en pausa tras 120 s
  sin actividad; los botones de compra se apagan con 3 h guardadas).
- Precios en Robux (así se crearon en Roblox el 23 oct; los dos Turbo con
  precio fijo, sin el precio gestionado de Roblox, que pedía aceptar un
  acuerdo: decisión del usuario): Turbo 15 min 49 · Pack de inicio 99 ·
  Estela arcoíris 99 · Bolsa dorada 99 · Bolsa XL 149 · Turbo 60 min 149 ·
  Dinero x2 199 · VIP 249.

## 5. Pendiente

Estado el 23 oct (el plan se pausó y se retomó ese mismo día; master subido
a origin/master). Lo que falta, en orden:

1. **E1, K1 y N1b, verificados en Studio el 23 oct**: la batería entera con
   veredicto (116 pruebas, por lotes) en verde, tras arreglar las que no
   contaban con los pases de verdad del creador (`Comunes.sinPasesReales` y
   `cobroLimpio`; `reacomodo`, de física, a la segunda). En el cliente:
   `("hud")` sin avisos (también con el punto rojo), los 8 precios de Roblox
   (`PreciosRobux`), y capturas de la Tienda (Pases y Estilo), las cinco
   ofertas (botones iguales: 2 de 257 px, o 3 de 166 con el Turbo), Pedidos
   con el Pedido VIP, Rebirth, Recompensas (cabecera rosa), el HUD con
   "x2 en pausa" y la corona VIP en tercera persona. La consola, sin errores
   del juego (el aviso de `rbxassetid://203785492` no es del juego: ni está en
   el repo ni en el mundo).
2. **Lo que falta de E1/K1 en Studio**: las capturas en táctil (Recompensas
   y la píldora del tutorial), `[VIP]` en el chat y la corona vista desde
   otro cliente (Q1), y la oferta de punta a punta.
   De punta a punta, con `ServerStorage.OfertasEnStudio = true` en Play
   (quitarlo después): tutorial en el paso 7+, 2.ª sesión o posterior, más de
   3 min, sin compras en 24 h y sin el Pack → depositar → sale el Pack en el
   siguiente momento tranquilo; "Comprar · 99" abre el prompt real y "Ahora
   no" suma `perfil.ofertas.porId.PackInicio.rechazos` (con la cuenta del
   creador, que ya tiene el Pack, no sale: hace falta otra cuenta o apartarle
   los pases como `Comunes.sinPasesReales`). Una compra de prueba
   de Turbo15 suma 900 s y pone `ultimaRobux`. Con 2 jugadores, la corona se
   ve desde el otro cliente (Q1).
3. **N1b**: hecho y verificado (Lune y Studio) el 23 oct. El dinero de las recompensas ya no sale
   al salir como `Reciclaje_SinBonus`: es una fuente `TimedReward` con su sku.
   El calendario manda su evento con la vuelta y los días desde la casilla
   anterior (`diasDesde` en el aviso de `Recompensas`), y cada oferta el suyo
   al enseñarse y al contestar. De la tabla §7.2 de `docs/Economia-v4.md`
   quedan sin hacer la moneda `TurboMin` (el Turbo que entra y se consume) y
   el evento "Bolsa" (1 de cada 3 depósitos); N1 midió el acierto con
   Acierto/Fallo. Son para después si hacen falta.
4. Pulido: la píldora del tutorial en táctil cae dentro de la zona del
   joystick (hay que medirlo en Studio), y en PC corta el texto del paso 6
   ("Paso 6/8 · Recoge basura de un solo color y", visto el 23 oct): tiene
   que crecer o partir la línea. Hecho el 23 oct: la cabecera del
   panel Recompensas en rosa (`Paleta.CABECERA_PANEL`). Los avisos de
   `RECOMPENSAS` no necesitan entrada en `SONIDO_AVISO`: cada cobro ya suena
   ("regalo") por `RecompensaEvent` "premio" en `UI/Recompensas`, y los
   informativos ("abiertas", "listo") callan como los demás.
   También del 23 oct: con mando, las insignias de tecla (Q, R…) no sirven;
   y el poste del cartel "Patio de basura ↑" de la plaza tapa una letra
   desde el este ("Patio de|asura", "Junk|ard"): moverlo pide re-hornear.
   La píldora flotante del candado ("REBIRTH 1", `ContenedoresBloqueados.client`)
   a veces sale vacía (TextBounds 0,0: el BillboardGui con TextScaled).
   (Hecho ese día: las pestañas con el mismo color en los tres idiomas,
   `Kit/Pestanas` con `Claves`, y `REBIRTH.conserva` sin las "zonas
   abiertas".) Y lo menor de la revisión Q4b: con el perfil
   provisional (DataStore caído) la tienda deja comprar Turbo, que no llega
   hasta que Roblox reintenta el recibo (apagar los botones de productos con
   `cargado == false`); una bolsa caída que no cabe no se recoge ni avisa, y
   tras renacer (capacidad 10) su dueño ya no recupera una de 40 (dejar que la
   recoja con la mano vacía y avisar); y el servidor no mide cuánto se cargó
   un lanzamiento, así que un cliente modificado acierta siempre hasta el
   alcance del Brazo sin cargar (que el cliente avise al empezar a cargar y el
   servidor exija el mínimo; ya venía de antes).
5. Documentación de K1: hecha el 23 oct (este documento, CLAUDE.md
   "Verificar", `docs/Juego.md`, `README-pruebas.md`).
6. **Insignias**: 10 de 20 creadas y con su id en
   `Config/DefinicionesInsignias` (primerReciclaje, primerAcierto,
   primerTesoro, racha5, tiro30, dinero10k, piezas1000, separadas500,
   mejoraMax, rebirth1). Faltan tiro60, racha10, piezas10000, dinero1M,
   todasMax, rebirth3 y las 4 nuevas (rebirth5, rebirth10, semanaCompleta,
   pedidos30); las imágenes están en `thumbnails/`. Roblox da 5 gratis cada
   24 h (el cupo se renueva a las 00:00 GMT y se consulta en
   `badges.roblox.com/v1/universes/10766595888/free-badges-quota`). Se
   traducen a en/pt en el Creator Hub al crearlas.
7. **Miniaturas**: hechas (I1b, 23 oct) y elegidas por el usuario (G10):
   01 (portada), 02, 03, 05 y 07 en `thumbnails/thumb_*` (las que llevan
   texto, en `_es`, `_en` y `_pt`; `hoja-miniaturas.png` las enseña juntas).
   Son capturas de Studio de 1424×801 ampliadas a 1920×1080: algo blandas;
   para más nitidez, repetirlas con la vista de Studio a 1920 de ancho. **Subida
   a medias**: en el Creator Hub (Places → el place → Thumbnails → Experience
   Detail Page, porque la experiencia las hereda del place de inicio) solo
   están la 01 y la 02_es, en orden inverso y sin texto alternativo
   (moderación "Completed"); el control de permisos del modo automático paró
   al agente al editarlas. Falta: subir la 03_es, 05_es y 07_es, ordenarlas
   (01, 02, 03, 05, 07), los textos alternativos de la ficha §4.3, Save
   Changes, y la serie entera en Localization → English y Portuguese →
   Information. La 4, la 6 y la 8 piden varias cuentas (Q1). Ojo: Game
   details enseñaba el nombre y la descripción en inglés; comprobar en
   Localization que el idioma fuente sigue siendo el español. Los **pases y
   productos** ya están (F1b, 23 oct: los 6 pases y los 2 Turbo con su
   imagen de `thumbnails/` y sus traducciones, ids en `Config/Productos`).
8. **Verificación de lanzamiento**: Q0, la regresión completa (la batería de
   CLAUDE.md "Verificar", `("hud")` en PC, táctil y mando, el juego en inglés
   y en portugués, la consola limpia y capturas de cada panel) y Q4b (revisión
   de todo el diff desde `base-lanzamiento`); **el usuario publica el place**;
   Q1, multijugador con 2–3 clientes (`README-pruebas.md`); Q2, un móvil real,
   y Q3, una compra real de cada tipo (estas dos, del usuario). **Ojo con Q3**:
   Roblox da a su creador los pases que crea (`UserOwnsGamePassAsync` da
   `true` en los seis para fuentes_arial12, comprobado el 23 oct), así que
   con esa cuenta no se puede comprar ningún pase ni ver sus ofertas: hace
   falta otra cuenta. Los Turbo (productos) sí los puede comprar.
9. **Abrir**: T1, pública para mayores de 16 (el usuario se verifica o hace
   una compra con dinero real y la hace pública con la ficha completa; tag
   `v1.0`); L10, calibración de 1–2 semanas con los datos del Dashboard
   (regla de §4); y T2, Roblox Select (cuestionario completo, 2FA,
   verificación de identidad, la tasa o Premium y 250 partidas de jugadores
   de 16+ muy implicados en 60 días).

Hecho en el Creator Hub (22 oct, §3 "Lanzamiento por agentes"): nombre y
descripciones es/en/pt, género, dispositivos, Max players 6, servidores
privados, icono, idioma fuente y traducción automática apagada, y el
cuestionario de madurez enviado (Minimal); el 23 oct, los 6 pases y los 2
productos de Turbo (F1b). Sigue privada.

Siguen valiendo de antes:
- **Guardar el place** tras cada horneado: el mundo, las variantes de
  `MaterialService`, `ServerStorage.Arte` (con `LeaderBoard`) y los tablones
  viven ahí; el `.rbxl` no va en git.
- Arte 2D propio para la UI en `assets/ui/` (siguen dibujados `lata`,
  `camara`, `sonido`, `regalo`, `calendario`, los `set*`, las manos…) y el
  avatar.
- La prueba con 2+ jugadores del patio compartido (el riesgo "tibio" del GDD
  §14) es la Q1.
- Para después del lanzamiento: lo social (amigos, grupo, invitar) y los
  códigos; contenido después del R3 (las zonas ricas ya están definidas en
  `TablasProbabilidad.MEZCLA` y `GameConfig.ZONAS`); figuritas y cintas;
  premios semanales de ranking y títulos sobre el personaje; cooperación en
  el patio; consola; iconos propios para los glifos; promoción de pago.

### Tienda "SHOP" de Blender (24 sep)

La cabaña de Doña Chatarra se sustituye por dos contenedores apilados (petición del
usuario): menta abajo con mostrador (sin toldo), coral arriba, y rótulo
amarillo con letras 3D "SHOP". Fuente `assets/3d/Tienda.fbx` (escena `Tienda`
del .blend del usuario; modelado en studs, origen en el suelo en el centro de
la cabina, frente a -Y). En el place: `ServerStorage.Arte.Tienda`, pintada por
sufijo (`Tienda_Menta`…) en `ArteMundo.tiendaDeMalla`. La cabina whitebox
sigue siendo la colisión. Sin la malla, `ArteMundo.caseta` usa la cabaña de
partes con el rótulo `Textos.MUNDO.tienda`.

### Base del jugador de Blender (25 sep; histórico: la base se quitó con la v2)

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

### Bolsa de Blender (6 oct)

Había dos bolsas que no casaban (petición del usuario): en las manos, una
esfera azul de partes; lanzada, la malla gris generada por IA. Ahora es un
solo saco azul low-poly facetado modelado en Blender, en dos estados.
- Fuentes `assets/3d/Bolsa.fbx` (cerrada: `Cuerpo` + `Nudo` + `Cincho`) y
  `assets/3d/BolsaAbierta.fbx` (`Cuerpo` + `Boca` + `Interior`); el
  `.blend` (escena `Bolsa`) en `assets/3d/Bolsa.blend`. Modeladas en studs,
  exportadas con escala 0,01 y «FBX All», como la recicladora.
- En el place: `ServerStorage.Arte.Bolsa` y `.BolsaAbierta`, cada una un
  Model con un MeshPart por color. Sin ellas (o si `Arte.Bolsa` sigue siendo
  el MeshPart viejo), `ModelosObjetos` construye las bolsas de partes.
- El importador pierde los colores: `clonarMallaBolsa` pinta por nombre con
  tonos de `Paleta.BOLSA` (`Nudo` ×1: la cerrada toda del mismo azul; `Boca` ×1,12, `Interior` ×0,5: azul oscuro, no gris) y guarda el
  factor en el atributo `Tono`, que `vestirBolsa` usa para mantener el
  claroscuro con los diseños de la tienda.
- La escala sale del alto real del clon (`ALTO_MALLA_BOLSA`: 3,6 la cerrada,
  2,6 la abierta, al 100 %), no de la escala con la que importe Studio.
- La abierta, tras dos intentos (un toro de borde parecía jarra; un cuello
  fruncido con solapas parecía corona), sigue la referencia del usuario:
  saco casi recto y alto, todo arrugado en facetas, abierto de par en par
  con el borde ondulado; `Boca` es solo el canto fino del plástico (se
  lee el grosor) e `Interior` la piel por dentro, azul oscuro. Va colgada
  de las manos: fondo redondeado, sin base plana (la cerrada sí la tiene:
  se apoya en el suelo).
- La cerrada sigue otra referencia del usuario (bolsa negra atada):
  barriga ancha abajo por el peso, el saco sube en cono con pliegues
  largos que se ahondan y giran hacia el atado (algo descentrado), y
  `Nudo` es el atado más un penacho de plástico arrugado e inclinado con
  dos orejas. Un cuello largo con picos simétricos parecía una granada.
- El `Cincho` del atado va en amarillo (`Paleta.CINCHO_BOLSA`, petición
  del usuario): sin atributo `Tono`, y `vestirBolsa` no lo repinta con
  los diseños de la tienda.
- La bolsa fallada se queda como cayó (petición del usuario: al pararse
  volvía a ponerse de pie, `PivotTo(CFrame.new(suelo))` borraba el giro
  del vuelo). `Lanzamiento.posturaDeReposo` conserva hacia dónde mira y
  hacia dónde se inclinaba: casi derecha se queda ladeada, si no tumbada
  a 75° sobre la barriga (hacia fuera si chocó con un contenedor);
  el giro tal cual podía dejarla boca abajo o medio enterrada. Al pararse
  rueda 0,35 s hasta esa postura (`ASENTARSE`), no cambia de golpe.
- En vuelo la bolsa gira alrededor del centro de su Cuerpo y la posición
  del vuelo (barrido, botes) es su punto MÁS BAJO (`apoyar`, con los
  semiejes del Cuerpo, casi un elipsoide). Antes giraba sobre el pivote
  (la base): girada se hundía hasta 1,8 studs al botar y saltaba 1,5 al
  posarse. El ángulo se acumula paso a paso (`t * giro` saltaba de
  orientación en cada bote, que frena el giro). Medido: 0 de hundimiento,
  ≤ 8° de giro por frame.
- En las manos la bolsa se **cierra con el nudo al llenarse**
  (`bolsaAbierta(1)` devuelve la cerrada), como el dibujo de primera
  persona de `Manos.client`; Patio la cuelga entonces del nudo. Prueba
  `bolsaManosLlena`.

### Avisos en el mundo, contenedores cerrados y otros ajustes (6 oct)

Peticiones del usuario tras probar el juego:

- **Avisos en el mundo en vez de toasts de rechazo.** `Services/AvisosMundo`
  manda por `AvisoMundoEvent` una burbuja (pastilla del Kit con icono, pop
  elástico, sube y se funde) que pinta `AvisosMundo.client` EN EL SITIO:
  sobre la pieza (tipo bloqueado con candado, prioridad del excavador,
  bolsa ajena), el montón (agotado, patio lleno, "termina tu montón",
  que además hace latir tu montón pendiente con un Highlight), el
  contenedor (bolsa vacía, contenedor cerrado) o tu cabeza (demasiado
  cerca, bolsa vacía al lanzar). El mismo texto se agrupa (1,2 s). Se
  quitaron los toasts de "bolsa llena" (la barra del HUD tiembla:
  `EstadoCliente.alRecogerConBolsaLlena`), "Fuera…" (lo dice el contador
  de la bolsa) y "recuperaste tu bolsa" (ya sale el "+N"). Los toasts que
  quedan (pedidos, rebirth, compras, "X se llevó tu bolsa"…) tienen estilo
  nuevo: medalla del color del tipo con icono, pop con muelle, sacudida
  en aviso/peligro y barra de tiempo.
- **Contenedores de tipos cerrados.** `Bolsa.contenedorAbierto`: el de
  metal no acepta nada hasta el Rebirth 1 y el de orgánico hasta el 2
  (`GameConfig.MATERIAL_REBIRTH`). Lanzada, la bolsa rebota en la tapa
  como en una pared y cae al pie (fallo); a mano, `Bolsa.depositar`
  devuelve `"bloqueado"`. `ContenedoresBloqueados.client` pone un candado
  "REBIRTH N" sobre ellos y apaga su prompt (localmente). Pruebas
  `contenedorBloqueado`; `lanzarATipo` corre con 2 rebirths.
- **Recoger en móvil/tablet con botón.** Se apunta con la mira (arrastrar
  gira la cámara) y se mantiene el botón RECOGER de la derecha
  (ContextActionService, mismo sitio que LANZAR, se alternan). Antes se
  recogía solo con arrastrar el dedo. No se puede ver en Studio de
  escritorio (sin pantalla táctil, ContextActionService no crea botones).
  Apuntar a una pieza de tipo bloqueado SÍ pide al servidor, para que
  salga su burbuja con candado.
- **Rótulo de la bolsa caída siempre encima.** Cuelga de un Attachment en
  `workspace.Terrain` que cada frame se pone sobre el tope de la caja
  envolvente (medido: 0,5 studs sobre el tope con la bolsa tumbada); el
  número y "Bolsa de X" (atributo `Dueno`) van en una pila y la etiqueta
  del servidor se oculta al posarse.
- **Tesoros y billetes brillan.** `ModelosObjetos.tesoro` lleva oro Foil,
  PointLight dorada y destellos; el billete, destellos verdes. Al
  recogerlos, `EfectoRecogida` lanza una ráfaga (y el tesoro un anillo de
  neón y un fogonazo).
- El medidor de fuerza del HUD se ve siempre (se lanza desde fuera del
  patio) y la bolsa atada en las manos va 0,6 studs más arriba
  (`Patio.SUBIDA_CERRADA`).

### Ajustes tras probarlo (7 oct)

- **Burbujas a media pantalla.** `AvisosMundo.client.puntoLegible` ya no
  pinta la burbuja en el sitio de la cosa (sobre un montón grande quedaba a
  10+ studs y había que alejarse para leerla): la pone a 12 studs delante
  de la cámara, en la dirección en que mira (media altura de pantalla),
  ladeada hacia la cosa como mucho 20°. Medido: 50-51 % de alto en los
  cuatro casos (cima de montón, pieza a un lado, detrás, sobre la cabeza).
  Ponerla a la altura de la cabeza no bastaba: la cámara en tercera
  persona mira desde arriba y salía al 12-23 % de la pantalla.
- **Tesoro violeta** (`Paleta.TESORO` 170,85,235; cierre dorado): dorado se
  confundía con la basura de plástico. El "¡TESORO!" y su ráfaga, del
  mismo color.
- **Récord de distancia en grande.** Al que lo bate le llega una tarjeta
  como la de insignia (`NotificacionEvent` tipo `"record"`,
  `"distancia|servidor|personal"`, `Notificaciones.record`); el del
  servidor sigue en el feed de los demás, que pasa a 18 px, 420 de ancho y
  borde del color primario. `("record", 32, true)` en PruebasCliente.
- **Contenedor cerrado con recuadro.** Además del candado flotante, un
  recuadro rojo translúcido (`Paleta.UI_PELIGRO`, transparencia 0,6) que
  envuelve el contenedor, con un candado grande y "REBIRTH N" en su cara
  del frente (SurfaceGui). Se recolocan en cada actualización: recién
  creados, con el mundo aún llegando al cliente, salían en el origen.
  8 oct: eso no bastaba. Si el perfil no cambiaba después de que llegara el
  contenedor, el candado se quedaba en el origen y el prompt de entregar a
  mano encendido (el servidor seguía rechazando). Ahora cada contenedor se
  vuelve a mirar cuando le llega una pieza (`DescendantAdded`) y todos cada
  3 s.
