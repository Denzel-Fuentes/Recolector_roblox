# Recíclatas (CleanRecycle) — estado del proyecto

Réplica mecánica de KOTAMON para Roblox, en whitebox low-poly sin texturas.
El diseño completo está en `docs/GDD.md`; este documento es lo que NO se deduce
del código: qué hay, cómo se trabaja y por qué se decidió lo no obvio.

Última pasada: 14 sep 2026. Estado: **todas las mecánicas del GDD implementadas
y verificadas en Play Solo**; pendiente la prueba con 2+ jugadores y publicar.

## 1. Qué hay

| Sistema | Dónde | Estado |
|---|---|---|
| Patio compartido: 24 montones, activación con prompt, objetos físicos, reclamo atómico, imán, despawn, repoblación | `Services/Botin.luau` + `BotinHandler` | verificado |
| Puntería: lanzar objetos de la bolsa al Contenedor de la caseta | `Botin.lanzar` | verificado (acierto desde 20 studs) |
| Bolsa, depósito con bonus +25% por bolsa llena, Auto-Reciclaje | `Services/Bolsa.luau` | verificado |
| Energía, refrescos (máquina), regen lenta | `Services/Energia.luau` | verificado |
| 41 mascotas, 5 estados, fusión 3→1, venta, exhibición, pasivas, Rey Reciclón | `Config/DefinicionesMascotas`, `Services/Mascotas.luau` | verificado |
| Reparación: limpieza (frotar manchas) y ensamblaje (girar 5 piezas), Auto-Ensamblaje | `Services/Reparacion.luau`, `Client/UI/Reparacion.luau` | verificado por UI simulada |
| 7 mejoras × 10 niveles, coste ×1.6 | `Config/DefinicionesMejoras`, `Services/Mejoras.luau` | verificado (232.430 $ para maxear) |
| Tienda: Sobre Premium, Contenedor Dorado, trajes, skins, gemas, pases; modal de probabilidades | `Services/Tienda.luau`, `Client/UI/Tienda.luau`, `UI/Probabilidades.luau` | verificado |
| 16 parcelas: estantería, radio, exhibidor, mesa, teléfono, almacén, me gusta, skins | `Services/Parcelas.luau`, `Client/UI/Base.luau` | verificado |
| 12 figurinas (6 fijas en escondites), 7 cintas, 3 trajes gratis + 2 premium | `Config/DefinicionesColeccionables`, `Services/Coleccionables.luau` | verificado |
| 40 logros en 11 categorías, progreso compartido servidor/cliente | `Config/DefinicionesLogros`, `Utilidades/ProgresoLogros`, `Services/Logros.luau` | verificado |
| Persistencia DataStore (pcall, `cargado`, UpdateAsync, autosave, BindToClose) | `Services/DataService.server.luau` | sin probar: exige publicar |
| Monetización: pases, ProcessReceipt idempotente, modo dev | `Services/Monetizacion.luau` | verificado (recibo duplicado no paga dos veces) |
| HUD, álbum, notificaciones, feed social, gamepad/táctil | `Client/UI/*` | verificado |
| Admin por chat (`/dar`, `/maxmejoras`, `/pases`, `/reset`…) | `Services/AdminHandler.server.luau` | escrito |

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
`ServerStorage/Herramientas/ConstructorMundo`). **Tras construir hay que guardar
el place.** `SetupMundo` sólo lo adopta; si falta, lo construye en runtime como
fallback y avisa. Todo se localiza por tags/atributos, nunca por nombre:
`RanuraMonton`, `Parcela`, `FigurinaFija`, `Contenedor`, `MaquinaRefrescos`,
`Limite`, `SoloDecorado`; atributos `Mueble`, `Pintable`, `NPC`, `IndiceParcela`.

### Probar

- `ServerStorage.EjecutarPrueba:Invoke(nombre, ...)` (sólo Studio) ejecuta las
  pruebas de `Services/PruebasDefinidas.luau` DENTRO de la VM del servidor.
  Existe porque la barra de comandos / execute_luau corren en la VM del plugin y
  allí `require` devuelve copias vacías de los módulos.
- `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir", "Album")` abre
  paneles desde la VM del cliente.
- Multijugador: Studio → Test → *Clients and Servers* (2 jugadores). Ver
  `README-pruebas.md`.

## 3. Decisiones no obvias (y por qué)

### El reclamo compartido es atómico sin locks

`Botin.reclamar` comprueba `obj.reclamadoPor` y lo asigna en la misma llamada,
sin ningún yield entre medias. Luau es monohilo: dos reclamos "simultáneos"
(dos eventos de red, o el bucle del imán de dos jugadores) siempre se resuelven
en orden. El perdedor ve `noExiste` (el objeto ya se retiró del registro), no
`yaReclamado`: sólo hay ventana para `yaReclamado` si la bolsa del ganador
estaba llena y se liberó el bloqueo. Prueba: `reclamoAtomico`.

### No se usa `.Touched` para recoger

Un bucle cada 0,2 s mide distancias jugador→objeto. A ≤ 2,5 studs se reclama
("tocar"); dentro del radio de la mejora Imán se arrastra con `PivotTo`. Los
objetos son modelos ANCLADOS sin física: determinista, sin welds, y el mismo
bucle sirve para toque e imán. El clic (Alcance) llega por RemoteEvent y se
valida con la misma distancia.

### El pity es por jugador y persiste

Cada monton sin Rara+ suma 1; una Rara+ lo resetea. La probabilidad se calcula
en `TablasProbabilidad.probabilidadRara` (8% + 2%·pity, tope 60%; el Pase de la
Suerte sube el paso a 3%). Medido con 300 montones grandes: pity 0 → 6%, pity
10 → 37%, pity 26 → 57% (teóricos 8/28/60). Los fragmentos usan tabla plana con
sesgo del 50% hacia mascotas a medias para que el ensamblaje converja.

### `TablasProbabilidad` es la única fuente de odds

Servidor (`Tienda`, `Botin`) y cliente (`Probabilidades`) leen el mismo módulo
de ReplicatedStorage; `verificar()` hace assert al cargar de que cada tabla
suma 100. Es el requisito de política de Roblox sobre ítems aleatorios pagados.

### Persistencia propia, sin ProfileStore

Cero dependencias (no hay Wally). Reglas: todo en `pcall` con reintentos; un
perfil que no cargó nunca se guarda (`Perfiles.estaCargado`); `UpdateAsync`;
autosave 120 s; `PlayerRemoving` espera 0,2 s para guardar DESPUÉS de que
Bolsa/Parcelas toquen el perfil. Sin bloqueo de sesión: migrar a ProfileStore
si algún día hay servidores concurrentes escribiendo el mismo perfil.

### La bolsa no persiste, pero no se pierde

Al desconectar, la basura se recicla sin bonus y las mascotas van al almacén si
caben (`Bolsa.vaciarAlSalir`). Perder una Épica por una caída de conexión sería
cruel.

### Las pasivas sólo actúan exhibidas

Las 6 mascotas del exhibidor dan +2/4/6% al reciclar su material (Rey: +10% a
todo). Exhibir tiene así un motivo además de presumir.

### Modo dev de pases

En Studio, `GameConfig.PASES_DEV_EN_STUDIO` hace que todos los Game Passes
cuenten como comprados sin tocar el perfil (viaja en `extras` del snapshot, no
en `pasesCache`, para no envenenar perfiles). `/pases off` lo apaga para probar
sin ellos. Los ids reales (0 = placeholder) se rellenan en `Config/Productos` y
`Config/DefinicionesLogros` (badges) al publicar.

### Whitebox: grises por función + color por material

Escenario: 110 suelo del patio, 140 montones/decorado, 165 caminos/muros, 195
losas/contenedor, 215 muebles/NPC, 240 caseta. Objetos y mascotas llevan color
plano por material y disco de rareza: set y rareza son información de juego. Un
solo neón: el anillo del montón recién activado (la señal social). Todo en
`Config/Paleta.luau`.

### Replicación del mundo en el cliente

`workspace.Mundo` aparece en el cliente antes que sus 1.191 descendientes.
Cualquier script de cliente que busque muebles debe escuchar `DescendantAdded`
(ver `Escena.client.luau`); una pasada única al arrancar se queda corta.

### Modelos por código

`Utilidades/ModelosMascota` construye las 41 mascotas (forma por set y `forma`,
tamaño por rareza, estado visible: torcida/apagada/reflectante/neón, manchas si
está sucia), fragmentos, basura, billetes, tesoros, figurinas, cintas, trajes y
montones. 1.673 partes para las 41×5 variantes. Sirve al mundo y a los
ViewportFrames del álbum: un solo vocabulario visual.

## 4. Números de calibración (punto de partida)

- Maxear las 7 mejoras: 232.430 $. Un montón chico deja ~5 objetos; basura
  5–12 $, billetes 20–80 $, tesoros 150–600 $. Objetivo KOTAMON: ~5 h gratis.
- Energía 100 (+15/nivel), excavar cuesta 10, refresco 50 $ restaura 30 (+8/nivel),
  regen 1 punto / 2 s.
- Bolsa 8 (+3/nivel), almacén 30 (+10/nivel), imán 1,5 studs/nivel, alcance 6 (+1/nivel).
- Sobre Premium 149 gemas; Contenedor Dorado 25.000 $ o 150 gemas, 3 mascotas.
- Repoblación: con ≤ 8 montones no agotados, 20 s después se rellenan todos.

## 5. Pendiente

- Publicar el place y activar *Studio Access to API Services* para probar el
  DataStore; crear pases, productos y badges y rellenar sus ids.
- Ids de audio de las 7 cintas (`sonidoId = 0`).
- Prueba con 2+ jugadores del patio compartido (riesgo "tibio" del GDD §14).
- Calibrar economía tras las pruebas cerradas.
