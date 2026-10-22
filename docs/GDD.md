# GDD — Réplica fiel de KOTAMON para Roblox
## "Recíclatas" (título de trabajo)

> **3 oct 2026 — v3 para lanzar.** Este documento es el diseño ORIGINAL (réplica de KOTAMON) y ya no describe el juego: sin base, sin energía, sin gemas, sin reparación y, desde el 3 oct, **sin mascotas**. El juego actual es "recoger y lanzar": montones de basura revuelta del color de su tipo, **cinco contenedores** (uno por tipo, x2 lo bien separado, y el general azul), mejoras en barras de 10 cuadros, rebirths que abren zonas, pedidos del día, 16 insignias, pases personales y cosméticos. Lo vigente y por qué está en `CONTEXTO.md` §1 y §3 "Lanzamiento: v3".

> **26 sep 2026 — alcance actual reducido a MVP.** Tras una auditoría de diseño, energía, gemas, Sobre Premium, Pase de la Suerte, Montón extra, cintas, fusión y ensamblaje manual están apagados (`GameConfig.FUNCIONES`), la colección es un set variado de **10 mascotas** con **acompañante**, la bolsa fallida es solo de su dueño y hay tutorial. Este GDD describe el diseño completo; lo que está activo y por qué está en `CONTEXTO.md` §3 "Recorte por la auditoría".

> Este documento reemplaza el enfoque del GDD anterior ("MVP inventado desde cero") por una **réplica mecánica fiel** de KOTAMON, mecanismo por mecanismo, adaptada a Roblox con 3 decisiones de diseño ya definidas: **temática de mascotas de basura reciclada**, **mundo compartido sin robo + base personal por jugador**, y **monetización mixta** (boosts + auto-farm/cosméticos + packs premium con probabilidades visibles).

---

# 0. TABLA DE EQUIVALENCIAS (Kotamon → Recíclatas)

| Mecánica en KOTAMON (original) | Adaptación en Recíclatas (Roblox) |
|---|---|
| Patio de un solo jugador, basura infinita dada por Jenny | **Patio compartido** (varios jugadores en el mismo servidor), basura infinita dada por **Doña Chatarra** |
| Cartas *catgirl* con temática ecchi, 4 sets elementales (Agua/Aire/Fuego/Oscuridad) | **Mascotas de basura reciclada**, 4 sets por material (Metal/Plástico/Papel/Orgánico-Misterio) |
| 40 cartas (4×10, en 4R/3SR/3SSR) + Kotalion especial | 40 mascotas (4×10, en 4 Común/3 Rara/3 Épica) + **Rey Reciclón** (Mítica especial) |
| Stats HP/ATK como valor de colección (sin combate) | Stats **Resistencia/Poder** como valor de colección (sin combate) — se mantiene igual, solo cambia el nombre |
| Quality/condición de cada copia (sucia → perfecta) | **Estado de conservación** por copia (igual, 5 niveles) |
| Limpieza manual + ensamblaje de 5 fragmentos en mesa de pegado | Igual, **pero en tu base personal**, con upgrade opcional de auto-ensamblaje (mejora sobre el original — ver sección 4) |
| 3 copias iguales de misma calidad → 1 copia de mejor calidad | Igual, sin cambios |
| Jenny da trabajo, paga reciclaje, compra tesoros, vende cajas de cereal a $10,000 en endgame | **Doña Chatarra** da trabajo, paga reciclaje, compra tesoros, vende **Contenedor Dorado** a precio alto en endgame |
| 7 upgrades: Bag, Energy, Buzz, Capacity, Speed, Range, Magnet | Igual en función, renombrados: Mochila, Energía, Chispa, Almacén, Velocidad, Alcance, Imán |
| 1 moneda ($) | 2 monedas: **$ / Billetes** (gratis, idéntica en esencia a la moneda única del original) + **Gemas** (premium, añadida para habilitar monetización sana en Roblox — ver sección 11) |
| 12 figurinas (6 fijas + 6 random), decorativas en estantería del garaje | Igual, decorativas en la **estantería de tu base** |
| 7 cintas de audio, se reproducen en la radio | Igual, radio en tu base |
| 3 trajes de cosplay, se regalan a Jenny | **Cambio de diseño:** en vez de regalarse a un NPC, son **disfraces que tu propio avatar se pone** — encaja mejor con la cultura de Roblox (expresión personal) y abre una categoría de monetización cosmética adicional |
| 40 logros en 11 categorías | 40 logros adaptados, mismas 11 categorías temáticas |
| Sin niveles de personaje, un solo basurero | Igual: sin niveles de personaje tradicionales, un solo patio (pero ahora compartido) |
| RNG "duro" señalado como queja #1 en reseñas | **Corregido a propósito:** sistema de pity/probabilidad creciente (ver sección 3) |
| Ensamblaje de fragmentos señalado como queja #2 | **Corregido a propósito:** upgrade de auto-ensamblaje disponible (ver sección 4) |
| Sin gamepad completo (queja de reseñas) | Soporte completo de gamepad + móvil + PC desde el diseño (estándar Roblox) |

---

# 1. CONCEPTO

| Campo | Definición |
|---|---|
| **Nombre provisional** | Recíclatas |
| **Género** | Simulación de coleccionismo + recolección en mundo compartido |
| **Público objetivo** | 8–17 años |
| **Elevator pitch** | Tu hermana encontró una mascota de reciclaje rarísima en la caja de cereal. Ahora trabajas en el vertedero de Doña Chatarra, buscando entre la basura junto a otros jugadores para completar tu colección de mascotas hechas de metal, plástico, papel y misterio — y decorar tu propia base con lo que encuentres. |
| **Fantasía del jugador** | "Soy un coleccionista/tesorero de basura" — curiosidad + recompensa sorpresa, ahora con la calidez extra de tener mi propio rincón para presumir la colección |
| **Core gameplay loop** | Entrar al patio compartido → excavar/bolsear basura junto a otros → volver a mi base → reparar/mejorar/exhibir cartas → comprar upgrades → repetir |
| **Duración de sesión ideal** | 15–25 minutos |
| **Jugadores por servidor** | 8–16 en el patio compartido |

---

# 2. MUNDO Y ESTRUCTURA SOCIAL (decisión de diseño confirmada)

Esta es la desviación más importante frente al KOTAMON original (que es 100% solitario) y frente al modelo "Steal a Brainrot" (que es 100% competitivo). El diseño elegido es un punto intermedio:

### Patio compartido
- Todos los jugadores del servidor ven y excavan en **el mismo patio de basura**, con montones visibles para todos.
- **No hay robo entre jugadores** ni ataque a la base ajena — se descarta explícitamente esa mecánica.
- **Activación compartida:** cualquier jugador puede activar un montón (igual que en el original, la "imagen" de basura se convierte en objetos físicos). **A diferencia del original, ese montón activado no es exclusivo de quien lo activó** — es un recurso compartido: cualquier jugador cercano puede recoger los objetos que aparecieron, sin importar quién hizo la activación. El "primero en llegar, primero en servir" no es por montón completo, sino **por objeto individual dentro del montón**: si dos jugadores van por la misma mascota que acaba de aparecer, se la lleva quien la toque primero (resuelto en servidor).
- Esto convierte la activación en un **acto cooperativo/social por diseño**: activar un montón grande beneficia a todos los que estén cerca, lo que anima a jugar en grupo y a "avisar" a otros cuando algo bueno aparece — es la pieza central de la tensión social ligera que se busca en la sección 2, más fuerte que un simple "ve a otro montón si este ya lo tomaron".
- El patio compartido es lo que da la sensación de mundo vivo (ver otros jugadores excavando) sin sacrificar la calma del original.

### Base personal
- Cada jugador tiene **su propia parcela pequeña**, visitable por otros (like/visita, sin edición ajena).
- En la base personal viven: la **estantería de figuritas**, la **radio de cintas**, la **mesa de reparación/ensamblaje**, el **álbum/exhibidor de mascotas**, y el acceso a la tienda de Doña Chatarra.
- La base es también el principal gancho de **retención social**: los jugadores querrán completar su colección para que su base "se vea mejor" que la de sus amigos — sustituye al componente competitivo del robo por un componente de **presunción/comparación social sana** (similar a cómo funciona el jardín en Grow a Garden o la casa en Adopt Me).

---

# 3. SISTEMA DE MASCOTAS COLECCIONABLES

### Temática: Mascotas de basura reciclada
Cuatro sets por tipo de material, replicando la estructura exacta 4×10 del original (4 Común + 3 Rara + 3 Épica por set) más 1 mascota Mítica especial — **40 + 1 en total, igual que KOTAMON**.

| Set | Material | Vibra visual |
|---|---|---|
| **Chatarrín** | Metal | Latas, tornillos, tuberías — mascotas robóticas y brillantes |
| **Plastín** | Plástico | Botellas, tapas, bolsas — mascotas elásticas y coloridas |
| **Cartonín** | Papel/Cartón | Cajas, periódicos, rollos — mascotas suaves y torpes |
| **Mostrenco** | Orgánico/Misterio | Cáscaras, restos sin identificar — mascotas espeluznantes-tiernas, la más rara del set |

**Mítica especial:** **Rey Reciclón** — una mascota gigante hecha de un poco de cada material, equivalente directo a Kotalion. Solo se obtiene completando ciertos hitos de colección (no cae de la basura), reforzando que es el objetivo aspiracional del juego.

### Stats de colección (sin combate, igual que el original)
- **Resistencia** (equivalente a HP) y **Poder** (equivalente a ATK) — puramente de colección/valor, no hay batalla en el juego, exactamente como en KOTAMON.
- Cada mascota tiene además una habilidad pasiva de sabor (ej. "+ recompensa al reciclar Metal") para dar utilidad sin desequilibrar el juego.

### Estado de conservación (igual que "Quality" en el original)
5 niveles: **Dañada → Regular → Buena → Excelente → Perfecta.** Afecta directamente el precio de venta y el aspecto visual de la carta/mascota en el álbum.

### Corrección deliberada del RNG "duro"
La queja #1 de las reseñas de KOTAMON fue el drop rate injusto. En Recíclatas se implementa un **sistema de probabilidad creciente (pity)**: cada montón sin mascota rara aumenta ligeramente la probabilidad del siguiente, reseteándose al conseguir una. Esto mantiene la emoción del azar sin la frustración reportada en el original.

---

# 4. SISTEMA DE REPARACIÓN

Igual que el original, son **dos procesos distintos**:

1. **Limpieza:** mascotas sucias pero completas — minijuego corto y relajante (arrastrar para limpiar), igual que en KOTAMON.
2. **Ensamblaje de fragmentos:** mascotas rotas requieren **5 fragmentos** encontrados en la basura, unidos en la **mesa de reparación de tu base**, rotando cada pieza hasta encajar — mecánica idéntica al original.

**Corrección deliberada de la queja #2:** el ensamblaje manual fue la segunda queja más repetida en las reseñas de KOTAMON ("no automation... rotating for a long time"). En Recíclatas se añade un **Game Pass opcional "Auto-Ensamblaje"** que resuelve el encaje de piezas automáticamente al depositar el fragmento — quien no lo compre sigue pudiendo jugar el minijuego manual gratis, así que no es pay-to-win, es una solución de conveniencia. Esto es además una pieza de monetización natural (ver sección 11).

### Mejora por duplicados
Idéntico al original: **3 copias de la misma mascota con el mismo estado de conservación se combinan en 1 copia de mejor estado** (incluida la versión "Perfecta", equivalente a foil).

---

# 5. DOÑA CHATARRA (equivalente a Jenny)

NPC dueña del vertedero, da el "trabajo" al jugador:
- **Basura infinita:** al vaciar el patio, Doña Chatarra repone montones nuevos — igual que Jenny en el original.
- **Paga por reciclar** (bonus por bolsa llena) y **por tesoros ocultos**.
- **Recompensa por completar sets** de mascotas.
- **Endgame:** al maxear los 7 upgrades, Doña Chatarra vende el **Contenedor Dorado** (equivalente al "cereal box de $10,000" del original) — fuente repetible de mascotas de alta calidad, el sumidero de dinero del jugador avanzado.

---

# 6. UPGRADES (7 stats, idénticos en función al original)

| Upgrade | Función | Equivalente Kotamon |
|---|---|---|
| **Mochila** | Cuánto cargas por viaje | Bag |
| **Energía** | Cuánto puedes jugar antes de necesitar un refresco | Energy |
| **Chispa** | Cuánta energía restaura cada refresco (reemplaza la cerveza del original por algo apto para todo público) | Buzz |
| **Almacén** | Espacio de inventario en tu base | Capacity |
| **Velocidad** | Velocidad de movimiento | Speed |
| **Alcance** | Distancia para agarrar basura | Range |
| **Imán** | Radio de atracción de objetos | Magnet |

Se compran con **$** (moneda gratuita — billetes literales que encuentras y que te paga Doña Chatarra, no puntos abstractos), igual que en el original donde todo se compra con la única moneda del juego.

---

# 7. COLECCIONABLES ADICIONALES

- **12 Figuritas** (6 en ubicaciones fijas del patio + 6 aleatorias de los montones) — decorativas en la estantería de tu base. Igual que el original.
- **7 Cintas Retro** — se reproducen en la radio de tu base, desbloquean pistas musicales ambientales. Igual que el original.
- **3 Trajes de Reciclador — cambio de diseño respecto al original:** en vez de regalarse a Doña Chatarra (como en Kotamon, donde se regalan a Jenny), **tu propio avatar se los pone**. Esto encaja mejor con la cultura de expresión personal de Roblox y abre una vía de monetización cosmética adicional (trajes extra vendibles post-MVP), sin tocar el balance del juego.

---

# 8. LOGROS (40, en las mismas 11 categorías del original)

Adaptados 1:1 a la temática de Recíclatas — mismas categorías que KOTAMON (Reciclaje, Ahorro, Upgrades, Sets de mascotas, Estado Perfecto, Contenedor Dorado, Figuritas, Cintas, Trajes, Refrescos, Puntería) con nombres propios (ej. "Primer Vistazo" por la primera mascota, "Coleccionista de Chatarrín" por completar el set Metal, "Reciclador de Oro" por $100,000 ahorrados, etc.). El detalle completo de los 40 nombres se desarrolla en producción siguiendo esta plantilla de categorías.

---

# 9. ECONOMÍA

**Dos monedas** (el original solo tenía una; se añade la segunda para habilitar la monetización de Roblox sin romper el balance):

- **$ / Billetes (gratuita):** dinero literal, igual que la única moneda del KOTAMON original — no es un punto abstracto de "chatarra". Se gana reciclando, encontrando billetes sueltos en la basura, y vendiendo tesoros/duplicados a Doña Chatarra. Se usa para upgrades, refrescos y mascotas básicas.
- **Gemas (premium):** se compran con Robux — se usan para packs de mascotas premium, trajes extra, y aceleradores.

---

# 10. MONETIZACIÓN — enfoque mixto (decisión confirmada)

Se combinan los tres enfoques, cada uno cubriendo una necesidad distinta para que ningún jugador sienta presión de un solo lado:

### A) Boosts de suerte/velocidad (Game Passes permanentes)
| Producto | Precio (Robux) | Qué hace |
|---|---|---|
| Pase de la Suerte | 249 | Mejora el pity de mascotas raras un tramo extra |
| Pase de Velocidad | 149 | +25% velocidad de movimiento permanente |
| Pase de Imán | 149 | +50% radio de imán |
| Auto-Ensamblaje | 199 | Resuelve el minijuego de fragmentos automáticamente |

### B) Auto-farm + cosméticos
| Producto | Precio (Robux) | Qué hace |
|---|---|---|
| ~~Pase Auto-Reciclaje~~ | ~~299~~ | **Retirado en producción**: el dinero sólo se obtiene depositando en el contenedor (ver `CONTEXTO.md`); un pase que paga al recoger rompía ese bucle |
| Trajes de Reciclador extra | 79–199 c/u | Cosméticos de avatar más allá de los 3 gratuitos |
| Skins de base (temas decorativos) | 99–249 | Personalización visual de la parcela |

### C) Packs premium con probabilidades visibles
| Producto | Precio (Robux) | Qué hace |
|---|---|---|
| Pack de Gemas (varios tamaños) | 99 / 249 / 499 | Moneda premium |
| Sobre de Mascotas Premium | 149 Gemas | Probabilidad mejorada de Rara/Épica — **odds mostrados numéricamente antes de comprar**, cumpliendo la política de Roblox sobre ítems aleatorios pagados |
| Contenedor Dorado (endgame) | Precio alto en $ + opción de acelerar con Gemas | Fuente repetible de mascotas de alta calidad tras maxear upgrades |

**Cumplimiento obligatorio:** cualquier compra con Robux (directa o indirecta, como el Sobre de Mascotas Premium comprado con Gemas) debe mostrar **la probabilidad exacta de cada resultado posible, sumando 100%**, según la política vigente de Roblox sobre ítems aleatorios pagados — esto se diseña desde el día uno, no se añade después.

**Por qué esta mezcla no se siente forzada:** ningún Game Pass bloquea contenido — solo aceleran o embellecen. La única fuente de ítems de probabilidad mejorada (el Sobre Premium) es opcional y transparente en sus odds, y el reciclaje gratuito sigue siendo suficiente para completar la colección sin gastar, tal como el propio KOTAMON demostró ser posible (~5 horas para comprar todos los upgrades jugando gratis).

---

# 11. UI/UX ESENCIAL

| Pantalla | Elementos principales |
|---|---|
| Patio compartido | Montones activos, otros jugadores visibles, HUD de bolsa actual |
| Base personal | Estantería de figuritas, radio, mesa de reparación, álbum, tienda |
| Álbum de mascotas | Grid por set (4 pestañas), estado de conservación por copia, botón de mejora |
| Mesa de reparación | Minijuego de limpieza / ensamblaje de fragmentos |
| Tienda de Doña Chatarra | Pestañas: Upgrades / Mascotas / Trajes / Gemas |
| Perfil/Base de amigos | Visitar bases de otros jugadores para comparar colecciones |

---

# 12. ARQUITECTURA TÉCNICA

**Stack:** Roblox Studio + Luau, extendiendo la propuesta del documento anterior con soporte para **mundo compartido + parcela personal por jugador**.

```
ServerScriptService/
  Services/
    DataService (perfil por jugador vía ProfileService/ProfileStore)
    EconomyService ($ + Gemas)
    PetService (colección, estado de conservación, fusión de duplicados)
    RepairService (limpieza + ensamblaje, valida el Auto-Ensamblaje del Game Pass)
    LootService (montones compartidos, RNG con pity server-side)
    PlotService (asignación y streaming de parcelas personales)
    MonetizationService (Game Passes, Dev Products, ProcessReceipt idempotente)
ReplicatedStorage/
  Modules/
    PetDefinitions (40 + 1 mascotas, stats, sets)
    OddsTables (probabilidades de sobres premium, para mostrarlas en UI y auditoría)
```

**Puntos críticos heredados del análisis de KOTAMON:**
- Todo el RNG y otorgamiento de moneda/mascotas ocurre en servidor; el cliente solo envía intención.
- **La activación de un montón es un evento compartido**, no exclusivo de quien lo activa: cualquier jugador cercano puede recoger los objetos que aparecen. Lo que sí debe resolverse de forma atómica (lock server-side, primer `ClaimItem` que llega gana) es **cada objeto individual dentro del montón**, para que dos jugadores no puedan reclamar la misma mascota física al tocarla casi simultáneamente. Esto es el único punto verdaderamente nuevo frente a un simulador solitario como el original, y el de mayor cuidado en el diseño de red: `RequestDig` activa el montón para todos los presentes, pero cada `ClaimItem` posterior se valida uno por uno.
- Las **probabilidades de los sobres premium** viven en un módulo único (`OddsTables`) que alimenta tanto la lógica de otorgamiento como el texto mostrado en la tienda, para que nunca puedan desincronizarse (riesgo de incumplimiento de política si el número mostrado no coincide con el real).

---

# 13. ROADMAP

Se mantiene la misma estructura de 6 fases del documento anterior (Prototipo → MVP → Alpha → Beta → Lanzamiento → Post-MVP), con dos ajustes de contenido:

- **Fase 1 (Prototipo)** ahora debe validar también el **patio compartido** (¿se siente bien ver a otros jugadores excavar en el mismo espacio sin fricción?), no solo la excavación en solitario.
- **Fase 2 (MVP)** incluye ya las 3 decisiones de diseño de este documento desde el inicio (tema de mascotas, mundo compartido + base personal, monetización mixta) — no se tratan como añadidos posteriores.

---

# 14. EVALUACIÓN CRÍTICA

**¿La réplica es fiel?** Sí en el núcleo mecánico (excavar, coleccionar, reparar, mejorar, upgrades, logros, coleccionables extra) — el mapeo de la sección 0 es prácticamente 1:1. Las únicas desviaciones deliberadas son: (1) mundo compartido en vez de solitario, (2) trajes puestos por el avatar en vez de regalados a un NPC, (3) segunda moneda premium, y (4) las dos correcciones de UX (pity de RNG y auto-ensamblaje) que las propias reseñas de KOTAMON señalaron como sus mayores defectos — replicar el juego "tal cual" incluyendo sus quejas más repetidas habría sido un error de diseño evitable.

**Mayor riesgo:** que el patio compartido sin robo se sienta "tibio" — ni la calma total del original ni la emoción social de un juego competitivo. Hay que probarlo en el prototipo antes de comprometer arte.

**Qué prototipar primero:** la sensación de ver a otros jugadores compitiendo suavemente por el mismo montón (sin poder robarse nada) — es el elemento social más nuevo y el que más puede fallar si no genera la tensión ligera y positiva que se busca.

---

## Decisiones tomadas en implementación (fuera del GDD original)

- **Puntería** (categoría de logros heredada de Kotamon): no hay aro. Se lanzan objetos de la bolsa al Contenedor de la caseta de Doña Chatarra y los logros premian acertar desde más lejos.
- **Persistencia**: capa propia sobre DataStore (sin ProfileService/Wally), como en Fly_Roblox.
- **Nombres de código**: en español (Botin, Parcelas, Mascotas…), como Fly_Roblox.
