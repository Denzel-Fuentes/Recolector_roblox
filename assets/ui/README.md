# assets/ui — arte 2D de la interfaz

Cada PNG de esta carpeta se llama como su clave en
`src/ReplicatedStorage/Shared/Config/Iconos.luau`. Mientras una clave tenga id
`0`, la UI dibuja el icono por código (`Utilidades/Glifos`); en cuanto tiene id,
usa la imagen. Nada más cambia.

## Iconos en uso (23 sep): set "Simulator Icon Pack" de la Creator Store

Las claves con id salen de un set gratuito de estilo simulador (el mismo
estilo que el "UI KIT GENERAL" de referencia). Las copias de la Toolbox
traían scripts maliciosos: se usaron solo sus imágenes (ver CONTEXTO).

| Clave | Imagen del set | Id |
|---|---|---|
| billete | Cash/CashIcon | 15402858705 |
| cartas | Menus/Pets (huella) | 16697439085 |
| gema | Gems/GemIcon | 17368064384 |
| rayo | Stats/Energy | 17368078790 |
| bolsa | Menus/Inventory (mochila) | 15402958715 |
| libreta | Menus/Index (libro) | 127110909372919 |
| telefono | Menus/Shop | 17368217589 |
| trofeo | Stats/Trophies/Wins | 12129301834 |
| casa | Misc/House | 15403180857 |
| montana | Menus/Teleport (portal) | 17368164592 |
| lanzar | Stats/Rocket | 16670799841 |
| mano | Cursors/Click | 17260727409 |
| raton | Cursors/Classic | 13443203578 |
| flecha | Stats/Strength | 15403007921 |
| sobre | RNG/Box | 17368122337 |
| contenedorDorado | RNG/Crate | 17368402884 |
| estrella | Stars/Star | 17368097932 |
| corona | Menus/VIP | 16912465495 |
| check | Misc/Accept | 17368190066 |
| candado | Misc/LockClosed | 17368080973 |
| corazon | Stats/Health | 17368075795 |
| nota, cinta | Misc/Disc | 95668779942949 |
| engranaje | Menus/Settings | 17368089841 |
| bota | Stats/Speed | 17368052918 |
| cofre | Gems/GemChest | 15402896733 |
| cruz | Misc/Deny | 17368208554 |
| pocion | Potions/BluePotion | 15403275152 |

Siguen dibujadas (sin equivalente en el set): `lata`, `figurina`, `iman`,
los `set*`, las `manos*`, `marcoCarta`, `papel`, `logo`.
Los briefs de abajo sirven para encargar esas.

## Estilo común

- PNG con transparencia, fondo vacío, sin texto dentro (el texto lo pone el
  juego), esquinas redondeadas.
- Contorno grueso de tinta (`#302A3C`, ≈ 10 px a 256), colores planos, una luz
  y una sombra. Referencia: los iconos del HUD de KOTAMON.
- Colores por función (de `Config/Paleta.luau`): dinero verde `#48A04E`,
  cartas azul `#4682DC`, gemas morado `#965AD2`, energía ámbar `#FFB032`,
  bolsa azul oscuro `#344A80`, fuerza naranja `#FF7846`, peligro rojo `#E24C4C`,
  papel `#FFF7E6`.

## Prioridad 1 — HUD y manos

| Archivo | Tamaño | Qué es |
|---|---|---|
| `manosVacia.png` | 1600×900 (o 2000×1125) | Primera persona: dos manos sujetando la bolsa azul abierta entre ellas, boca a ~40 % de la altura, brazos entrando por las esquinas inferiores y sangrando fuera del lienzo. Con esta sola ya funciona |
| `manosMedia.png` | igual | La misma, bolsa medio llena (se ve abultada) |
| `manosLlena.png` | igual | La misma, bolsa llena hasta la boca |
| `billete.png` | 256×256 | Billete verde |
| `cartas.png` | 256×256 | Dos cartas azules en abanico |
| `gema.png` | 256×256 | Gema morada |
| `rayo.png` | 256×256 | Rayo ámbar (energía) |
| `bolsa.png` | 256×256 | Bolsa de basura azul, cerrada |
| `libreta.png` | 256×256 | Libreta con pestañas de colores (álbum) |
| `telefono.png` | 256×256 | Teléfono (tienda) |
| `trofeo.png` | 256×256 | Trofeo dorado (logros) |
| `casa.png` | 256×256 | Casa (mi base) |
| `montana.png` | 256×256 | Montaña de basura (el patio) |
| `lanzar.png` | 256×256 | Bolsa volando en arco |
| `mano.png` | 256×256 | Mano abierta (recoger) |
| `raton.png` | 256×256 | Ratón con el botón izquierdo marcado |
| `lata.png` | 256×256 | Lata de refresco |
| `flecha.png` | 256×256 | Flecha hacia arriba (fuerza de lanzamiento) |

## Prioridad 2 — Paneles

`sobre`, `contenedorDorado`, `estrella`, `corona`, `check`, `candado`,
`corazon`, `nota`, `figurina`, `cinta`, `engranaje`, `iman`, `bota`, `cofre`,
`cruz` (256×256) y los sets `setMetal` (tuerca), `setPlastico` (botella),
`setPapel` (hoja de papel), `setOrganico` (hoja verde), `setRey` (corona).

## Prioridad 3 — Opcionales

| Archivo | Tamaño | Qué es |
|---|---|---|
| `marcoCarta.png` | 512×720 | Marco de carta **en blanco** (se tiñe por rareza con `ImageColor3`), ventana central transparente para el modelo 3D, banda inferior para el nombre |
| `papel.png` | 512×512 repetible | Textura sutil de papel/cartón, casi blanca (se pone al 15 % sobre el crema) |
| `logo.png` | 1024×512 | Logotipo "Recíclatas" |

## Cómo se suben

1. Dejar los PNG aquí.
2. `powershell -ExecutionPolicy Bypass -File herramientas/servir-fuentes.ps1`
   (sirve `/assets/...` como binario).
3. Desde Claude Code con Studio abierto: `upload_image` del MCP con
   `http://localhost:8123/assets/ui/<clave>.png` → devuelve `rbxassetid://N`;
   se escribe `N` en `Config/Iconos.luau`.
4. Roblox modera las imágenes: pueden tardar unos minutos en verse. Hasta
   entonces el respaldo dibujado sigue activo si el id es 0.

Alternativa: Asset Manager de Studio → Importar en lote, y copiar los ids.
