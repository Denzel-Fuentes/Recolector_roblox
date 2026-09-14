# Recíclatas (CleanRecycle) — guía para trabajar en este repo

Réplica whitebox de KOTAMON para Roblox. El diseño está en `docs/GDD.md`; el
estado del proyecto y las decisiones no obvias en `CONTEXTO.md`. Léelos antes de
tocar balance o estructura.

## Toolchain

- Rojo 7.7.0 (aftman). `rojo serve default.project.json --port 34872` y conectar
  el plugin en Studio. No hay Wally: cero dependencias externas a propósito.
- Sin plugin (p. ej. trabajando por MCP): arrancar
  `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1` y en
  la barra de comandos / `execute_luau` (Edit):
  `loadstring(game:GetService("HttpService"):GetAsync("http://localhost:8123/herramientas/instalar-desde-http.luau", true))()`.
  Crea el mismo árbol que Rojo; idempotente.
- Pruebas dentro de la VM del juego (Play): `game.ServerStorage.EjecutarPrueba:Invoke("estado")`
  (ver `Services/PruebasDefinidas.luau`) y `ReplicatedStorage.EjecutarPruebaCliente:Invoke("abrir","Album")`.
  La barra de comandos corre en la VM del plugin: `require` allí da copias vacías.
- El mundo NO se genera en runtime: se hornea en el place con
  `herramientas/construir-mundo.luau` (pegar en la barra de comandos o mandar
  por `execute_luau` sobre el DataModel Edit) y después se **guarda el place**.
  `SetupMundo` solo adopta `workspace.Mundo`; si no existe, lo construye como
  fallback y avisa.
- El place (`*.rbxl`) está en `.gitignore`: la fuente del mundo es la herramienta.

## Estructura (espejo del DataModel)

```
src/ReplicatedStorage/Shared/{Config,Events,Utilidades}
src/ServerStorage/Herramientas/ConstructorMundo.luau
src/ServerScriptService/Services/       Modulo.luau (estado/reglas) + ModuloHandler.server.luau (cableado)
src/StarterPlayer/StarterPlayerScripts/Client/{*.client.luau, *.luau, UI/}
herramientas/                           NO mapeado en Rojo: scripts de diseño para la barra de comandos
```

Rojo 7: `.luau` → ModuleScript, `.server.luau` → Script, `.client.luau` →
LocalScript, `X.model.json` → instancia (los RemoteEvents van así).

## Convenciones de código

- `--!strict` (o `--!nonstrict` en constructores de geometría), tabs.
- Identificadores, archivos y comentarios en **español**. UI en español, todo el
  copy en `Config/Textos.luau`.
- Cabecera de cada archivo: qué hace ("Única responsabilidad") y el **porqué**
  de lo no obvio. Documenta decisiones, no sintaxis.
- El servidor es la autoridad: el cliente sólo envía intención por RemoteEvent y
  el servidor valida distancia, cooldown, energía y dinero.
- `Config/TablasProbabilidad.luau` es la ÚNICA fuente de probabilidades
  (servidor y modal de la tienda la leen). Toda tabla suma 100; hay assert.
- Persistencia: todo acceso a DataStore va en `pcall`, un perfil que no cargó
  nunca se guarda (bandera `cargado`).
- Geometría del runtime se localiza por **tags/atributos** de CollectionService
  (`RanuraMonton`, `Parcela`, `Contenedor`…), nunca por listas de nombres.
- Whitebox: colores planos, sin texturas, escalera de grises de `Config/Paleta.luau`.

## Verificar

1. Consola de Studio sin errores tras sincronizar (`get_console_output`).
2. Hornear mundo → capturas → contar tags (24 `RanuraMonton`, 16 `Parcela`).
3. Play: asserts de servidor en `execute_luau` (reclamo atómico, pity, fusión,
   odds suman 100, 41/40/12/7/3 definiciones).
4. Multijugador: Studio → Test → Clients and Servers (2 jugadores), ver
   `README-pruebas.md`.

## Bash del harness

Los heredocs de más de ~8 KB con comillas simples se corrompen: para archivos
grandes usar la herramienta Write; Bash para archivos pequeños y comandos.
