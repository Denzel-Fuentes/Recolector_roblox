# assets/ui — arte 2D de la interfaz

Cada PNG de esta carpeta se llama como su clave en
`src/ReplicatedStorage/Shared/Config/Iconos.luau`. Mientras una clave tenga id
`0`, la UI dibuja el icono por código (`Utilidades/Glifos`); en cuanto tiene id,
usa la imagen. Nada más cambia.

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
| `retratoChatarra.png` | 512×512 | Retrato de Doña Chatarra para el diálogo (si no, se usa su modelo) |

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
