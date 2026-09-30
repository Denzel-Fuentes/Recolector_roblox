# Recíclatas — el juego tal como se juega hoy

Este documento describe **solo lo que el jugador ve y puede hacer** en la versión actual: reglas, números, lugares y pantallas. No habla de cómo está construido por dentro. Si algo no está aquí, no es jugable todavía.

---

## 1. En una frase

Eres un reciclador en un vertedero: excavas montones de basura, llenas tu bolsa, la llevas (o la lanzas) al contenedor de reciclaje para cobrar, y con el dinero mejoras tu equipo y completas una colección de **41 mascotas hechas de basura** que exhibes en tu base.

### El bucle principal

1. **Excavar** un montón del patio: se convierte en una montaña de basura con premios mezclados.
2. **Recoger** piezas con clic (o con el imán) hasta llenar la bolsa. Cada pieza gasta energía.
3. **Volver al contenedor** de la recicladora y reciclar la bolsa, o **lanzarla** desde lejos para cobrar más.
4. **Cobrar**: el dinero *solo* sale del contenedor. Nada se paga al recogerlo.
5. **Gastar** en mejoras, refrescos de energía y, al final, el Contenedor Dorado.
6. **Coleccionar**: mascotas, fragmentos, figuritas, cintas y trajes. Reparar lo roto, fusionar duplicados y exhibir lo mejor en tu base.

---

## 2. Al entrar

- Cada servidor tiene **6 bases**, una por jugador. Al entrar se te asigna la primera libre y **apareces en la puerta de tu base**, frente al arco con tu nombre ("Base de *tu nombre*").
- Al morir o reaparecer, también vuelves a la puerta de tu base.
- La energía empieza **llena**.
- Si tu progreso no se pudo cargar, se avisa: *"No se pudo cargar tu progreso. Esta sesión no se guardará."*
- Doña Chatarra da la bienvenida: *"Bienvenido a Recíclatas. Habla con Doña Chatarra para empezar."*

---

## 3. Controles

### PC (teclado y ratón)
| Acción | Control |
|---|---|
| Moverse / saltar | WASD / Espacio |
| Recoger basura | **Mantener clic** sobre la pieza (recoge una cada ~0,16 s mientras mantienes) |
| Lanzar la bolsa | **Mantener F** para cargar la fuerza, soltar para lanzar hacia donde apuntas |
| Interactuar (excavar, reciclar, comprar refresco, hablar…) | **E** (algunas acciones hay que mantenerlas) |
| Tienda | **Q** o **T** |
| Álbum | **J** |
| Logros | **L** |
| Mi base | **B** |
| Cerrar panel | **Esc** |

### Móvil (táctil)
- Palanca y botón de salto de Roblox.
- **Toca la basura** para recogerla ("TOCA LA BASURA PARA RECOGER").
- Botón **MANTÉN** para cargar y soltar el lanzamiento.
- Las interacciones aparecen como pegatinas en pantalla que se tocan (o se mantienen).
- La rejilla de botones del menú se coloca arriba a la izquierda, bajo el retrato.

### Mando
- Botón X: recoger. Botón Y: cargar y lanzar. B: cerrar panel. Select: Álbum.

### Cámara
- **Dentro del patio** la cámara pasa sola a **primera persona**: ves tus manos sujetando la bolsa abierta y un **punto de mira** en el centro. Un anillo alrededor del punto crece cuando hay una pieza a tu alcance.
- **Al salir del patio** vuelves a la cámara normal, con la misma distancia que tenías al entrar.
- Con un panel abierto el ratón queda libre para usar la interfaz.

---

## 4. El mundo

Todo el mapa está rodeado por una **valla de madera** de vertedero. De norte a sur y de oeste a este:

- **Calle de las bases** (oeste): las 6 bases en columna, cada una con su camino de tierra hasta la calle.
- **El patio de basura** (centro): una explanada de césped claro de 97,5 × 150 studs, con un **borde rojo**, dividida en 2 × 3 cuadrantes por caminos. Tiene **18 montones** (3 por cuadrante). Alrededor hay decorado de vertedero (tubos, contenedores, lavadora vieja, neumáticos…) donde se esconden figuritas.
- **La plaza** (al sur del patio): el cruce de caminos con los postes indicadores "Parcelas ↑" y "Patio de basura ↑".
- **La recicladora** (sur): sobre una solera de hormigón en un lote de tierra están:
  - la **tienda SHOP**: dos contenedores apilados, menta y coral, con el letrero amarillo y **Doña Chatarra** tras el mostrador;
  - la **máquina de refrescos** ("RESTAURAR ENERGÍA");
  - el **contenedor verde** de reciclaje ("VENDER BASURA") con la **trituradora** y su cinta;
  - alrededor, camiones abandonados, pilas de neumáticos, barriles, cajas y postes de luz con cables.
- Fuera de las zonas, césped verde.

---

## 5. El patio y los montones

### Montones
| Tamaño | Cantidad en el patio | Piezas al excavar | Tiradas de premio |
|---|---|---|---|
| Chico | 11 | 18–24 | 10–12 |
| Mediano | 4 | 45–60 | 16–20 |
| Grande | 3 | 90–115 | 24–30 |

- Cada montón es una **colina**. Al **excavar** (mantener E 1,5 s; no gasta energía) se transforma en una **montaña de basura del mismo tamaño**: las piezas brotan de abajo arriba y caen con física, amontonándose.
- La montaña **se puede escalar**: las piezas quietas son sólidas. Al recoger las de abajo, las de encima caen y se vuelven a asentar.
- Las piezas **no caducan**: se quedan hasta que alguien las recoja.
- Un montón vacío queda **agotado** (una marca plana). Cuando quedan **6 o menos montones disponibles**, a los 20 s Doña Chatarra **repone** los agotados (aviso: *"¡Doña Chatarra trajo más basura!"*). Un montón al que le queda menos del 25 % ya no cuenta como disponible.

### Límites al excavar
- **Un montón a medias por jugador.** Si quieres abrir otro sin terminar el tuyo, aparece la oferta **"Montón extra"** (Robux) con las opciones "Abrir ya" o "Sigo recogiendo".
- Si el patio ya tiene demasiada basura suelta (360 piezas), no se puede excavar: *"Hay demasiada basura en el patio: espera a que se recoja un poco"*.

### Qué sale de un montón
Cada tirada de premio decide qué es la pieza. El resto de piezas es basura de relleno.

| Tipo | Probabilidad |
|---|---|
| Basura | 58 % |
| Billete | 15 % |
| Fragmento de mascota | 14 % |
| Mascota completa | 6 % |
| Tesoro | 4 % |
| Coleccionable (figurita, cinta o traje) | 3 % |

- **Basura**: Metal 25 %, Plástico 30 %, Papel 30 %, Orgánico 15 %. Hay muchas formas distintas (latas, botellas, cajas, periódicos, barriles, neumáticos, cáscaras…).
- **Mascota completa**: sale **sucia** el 70 % de las veces. Estado: Dañada 30 %, Regular 35 %, Buena 25 %, Excelente 8 %, Perfecta 2 %. La rareza la decide el **pity** (ver §10).
- **Fragmento**: Común 70 %, Rara 22 %, Épica 8 %. La mitad de las veces es de una mascota que ya tienes a medias, para que completarla no se eternice.
- **Coleccionable**: figurita 50 %, cinta 35 %, traje 15 %, siempre entre los que **te faltan**.

### Recoger
- **Solo con clic** (o tocando en móvil) dentro de tu **alcance** (6 studs de base), o arrastrado por el **imán**. Pasar por encima no recoge nada.
- La pieza apuntada se resalta. Al recogerla, vuela hacia ti y entra en la bolsa.
- Cada pieza cuesta **2 de energía** y ocupa **un hueco de la bolsa**, sea basura, billete, tesoro o mascota.
- **Imán** (mejora): atrae las piezas de su radio y las mete en la bolsa sin clic. Se detiene si la bolsa está llena o no te queda energía.
- Todo es **compartido**: lo que sale de un montón es de quien lo recoja primero, lo haya excavado quien sea.

---

## 6. La bolsa

- Capacidad inicial: **8 objetos**, +3 por nivel de la mejora Bolsa (hasta 38).
- En el HUD, la barra **Bolsa** se llena sin números. Llena, muestra **"¡LLENA!"** en rojo y aparece el aviso *"¡Bolsa llena! Vuelve a la caseta"*.
- En primera persona ves la bolsa en tus manos. Los demás jugadores te ven con los brazos extendidos y la bolsa abierta mientras estás en el patio.

### Reciclar en el contenedor
Junto al contenedor verde, mantén E en **"Reciclar bolsa"**. Se vacía todo:

| Lo que llevas | Qué pasa |
|---|---|
| Basura | Se paga según su material (§7) |
| Billetes y tesoros | Se pagan |
| Fragmentos | Pasan a tu colección |
| Mascotas | Van a tu almacén si hay sitio; si no, **se quedan en la bolsa** y se avisa |
| Figuritas, cintas, trajes | Pasan a tu colección |

- **Bonus bolsa llena: +25 %** del dinero si la bolsa iba llena ("… (+25% bolsa llena)").
- Al reciclar, la **cinta de la recicladora** se pone en marcha: la basura sube por la cinta en L, cae en la trituradora (los rodillos giran más rápido) y sale un bloque prensado por la rampa. Lo ven todos los jugadores.

### Lanzar la bolsa (puntería)
- Mantén **F** para cargar la **barra de fuerza** (se llena en 1,2 s) y suelta: la bolsa **entera** vuela en parábola hacia donde apuntas. Cuanta más fuerza, más lejos (hasta 70 studs).
- Cuesta **10 de energía**. Hace falta estar a **más de 6 studs** del destino.
- Si **entra en el contenedor**: se recicla todo con un **+50 %** extra (se suma al +25 % de bolsa llena) y aparece *"¡Dentro! +$… desde N studs"*. Cuenta para los logros de Puntería.
- Si **falla**: la bolsa rebota contra lo que golpee y **queda en el suelo con todo dentro**. *Cualquier jugador* puede recogerla ("Recogiste la bolsa de X (N objetos)").
- La bolsa rebota en paredes y máquinas y puede quedarse encima de ellas (por ejemplo, en el techo de la trituradora).

### Si te desconectas
Lo que vale dinero y no reciclaste **se pierde**. Las mascotas y los coleccionables que lleves pasan a tu colección si caben.

---

## 7. Dinero y Gemas

### Dinero ($)
Moneda gratuita. **Solo se gana al reciclar en el contenedor**, al vender mascotas y con los logros.

| Fuente | Valor |
|---|---|
| Basura de metal | $12 |
| Basura de plástico | $8 |
| Basura de papel | $6 |
| Basura orgánica | $5 |
| Billete | $20–80 |
| Tesoro | $150–600 |
| Logro desbloqueado | $100 |
| Venta de mascota | Ver §10 |

- La basura vale más con **mascotas exhibidas** en tu base (su pasiva; ver §10).
- Se gasta en mejoras, refrescos ($50) y el Contenedor Dorado ($25.000).

### Gemas
Moneda premium: solo se consiguen con Robux. Se gastan en el Sobre de Mascotas Premium (149) y en el Contenedor Dorado (150, alternativa al dinero).

---

## 8. Energía y refrescos

- Máximo inicial **100**, +15 por nivel de la mejora Energía (hasta 250). Barra naranja arriba a la derecha.
- **Gasta**: recoger una pieza (2) y lanzar la bolsa (10). Excavar es gratis. Con la bolsa inicial, un viaje completo gasta unos 26: da para unas 4 bolsas por barra.
- **Regenera sola** 1 punto cada 6 s (10 por minuto), para que nadie se quede atascado.
- Sin energía: *"Sin energía: compra un refresco en la máquina"*.
- **Máquina de refrescos** (junto a la tienda): mantén E 1,5 s → **$50** → recupera **30** de energía, +8 por nivel de la mejora Chispa (hasta 110). Mensaje: *"¡Glup! +N energía"*.

---

## 9. La tienda SHOP y Doña Chatarra

- **Doña Chatarra** está tras el mostrador de la tienda. Acercarse y pulsar **"Tienda"** abre el panel de la tienda (sin diálogos: se quitaron el 29 sep).
- El **panel de la tienda** se abre con **Q/T**, con el botón Tienda del HUD o desde el **teléfono** de tu base ("Llamar a Doña Chatarra"). Tiene 4 pestañas:

**Mejoras**: las 7 mejoras (§12), con su nivel, el valor actual → el siguiente y el coste.

**Mascotas**
- **Sobre de Mascotas Premium** (149 Gemas): 1 mascota **limpia**. Rareza: Común 55 %, Rara 35 %, Épica 10 %. Estado: Regular 40 %, Buena 35 %, Excelente 20 %, Perfecta 5 %.
- **Contenedor Dorado** ($25.000 o 150 Gemas): **3 mascotas** Raras (60 %) o Épicas (40 %), en estado Buena 50 %, Excelente 40 % o Perfecta 10 %. **Bloqueado** hasta tener las 7 mejoras al máximo ("Se desbloquea con las 7 mejoras al máximo (N/7)").
- Los dos tienen el botón **"Ver probabilidades"**, que muestra las cifras exactas antes de comprar. En la tabla de montones aparece tu probabilidad actual de Rara o mejor.
- **Vender duplicados**: vende de una vez todas las copias repetidas y se queda con la mejor de cada mascota.
- No se cobra nada si no hay sitio en el almacén para lo que pueda salir.

**Trajes**: los 3 trajes gratuitos (hay que encontrarlos; se equipan), los 2 de pago y las 2 skins de base.

**Gemas y Pases**: packs de Gemas y pases (§16).

Al abrir un sobre o un contenedor, una ventana revela lo que salió.

---

## 10. Mascotas

### La colección
**41 mascotas**: 4 sets de 10 (4 Comunes, 3 Raras y 3 Épicas) más el **Rey Reciclón** (Mítica).

| Set | Material | Estilo |
|---|---|---|
| Chatarrín | Metal | Latas, tornillos, tuberías: robóticas y brillantes |
| Plastín | Plástico | Botellas, tapas, bolsas: elásticas y coloridas |
| Cartonín | Papel | Cajas, periódicos, rollos: suaves y torpes |
| Mostrenco | Orgánico | Cáscaras y restos: espeluznantes-tiernas |

<details>
<summary>Las 41 mascotas</summary>

| Set | Comunes | Raras | Épicas |
|---|---|---|---|
| Chatarrín | Latita, Tornillín, Clavito, Tuberco | Engranín, Robolata, Chispazo | Ferrotón, Cromadón, Magnetrón |
| Plastín | Botellín, Tapita, Bolsuki, Pajito | Elastiko, Burbujín, Tupperín | Polímero, Neoplast, Vinilón |
| Cartonín | Cajita, Periodín, Rollito, Papelón | Origamo, Libretín, Cartonazo | Papiro, Enciclopedio, Cartonio |
| Mostrenco | Cascarón, Semillín, Hojarasca, Pepita | Mohosín, Fantasmita, Raicilla | Compostor, Espectrón, Musgrón |
| — | | | **Rey Reciclón** (Mítica) |

</details>

- Cada una tiene **Resistencia** y **Poder** (valores de colección; no hay combate), una descripción y una **pasiva**.
- Colores de rareza: Común gris, Rara azul, Épica morado, Mítica dorado.

### Estado de conservación
**Dañada → Regular → Buena → Excelente → Perfecta.** Se ve en la etiqueta de la mascota (p. ej. "Latita · Regular").

### Sucias
Las mascotas sacadas de los montones suelen venir **sucias**. Una mascota sucia vale la mitad, no se puede fusionar ni exhibir: hay que **limpiarla** en la mesa de reparación.

### Cómo se consiguen
1. **Completas en un montón** (6 % de las tiradas).
2. **Fragmentos**: 5 fragmentos de la misma mascota se ensamblan en la mesa → 1 copia **Regular y limpia**. Aviso: *"¡Tienes los 5 fragmentos de X! Ve a la mesa de reparación"*.
3. **Sobre Premium** y **Contenedor Dorado** (tienda).
4. **Rey Reciclón**: se consigue automáticamente al tener las 40 mascotas de los 4 sets. No se puede vender.

### Pity (suerte que sube)
La probabilidad de que una mascota completa de un montón sea **Rara o mejor** empieza en **8 %** y sube **2 puntos** por cada montón que excavas sin conseguir una Rara (3 con el Pase de la Suerte), hasta un **60 %**. Al salir una Rara vuelve al 8 %. De las Raras o mejores, 1 de cada 4 es Épica.

### Fusión
**3 copias limpias** de la misma mascota **en el mismo estado** → 1 copia en el estado siguiente. Las Perfectas no se fusionan. Se hace desde el Álbum ("Fusionar ×3").

### Vender
Valor = base por rareza × multiplicador de estado (×0,5 si está sucia):

| Rareza | Base | Dañada ×0,5 | Regular ×1 | Buena ×1,6 | Excelente ×2,5 | Perfecta ×4 |
|---|---|---|---|---|---|---|
| Común | $40 | $20 | $40 | $64 | $100 | $160 |
| Rara | $200 | $100 | $200 | $320 | $500 | $800 |
| Épica | $900 | $450 | $900 | $1.440 | $2.250 | $3.600 |

### Almacén
Cuántas mascotas puedes guardar: **30** de base, +10 por nivel de la mejora Almacén (hasta 130). Si está lleno: *"Almacén lleno: vende o fusiona mascotas"*. Lo que no cabe se queda en la bolsa.

### Exhibir y pasivas
- Hasta **6 mascotas limpias** en los **6 podios** de tu base. Se ponen desde el Álbum.
- **Solo las exhibidas activan su pasiva**: Común +2 %, Rara +4 % y Épica +6 % al dinero de **la basura de su material**. El Rey Reciclón da **+10 % a toda la basura**.

---

## 11. Mesa de reparación

Es el banco del taller de tu base; también se abre desde el Álbum. Tiene dos minijuegos:

- **Limpieza**: arrastras el puntero (o el dedo) sobre las **8–12 manchas** de la mascota; cada una se va tras un momento de frotar. Sin manchas, la mascota queda limpia.
- **Ensamblaje**: 5 piezas giradas al azar; tocar una la gira 90°. Cuando todas encajan, sale la mascota en estado Regular.
- Con el pase **Auto-Ensamblaje**, los 5 fragmentos se ensamblan al instante, sin minijuego.
- Si no tienes nada que reparar: *"No tienes mascotas sucias ni fragmentos completos"*.

---

## 12. Mejoras

Se compran en la tienda. Cada una tiene **10 niveles**. El coste del siguiente nivel es el coste base × 1,6 elevado al nivel actual.

| Mejora | Qué hace | Nivel 0 → 10 | Coste nivel 1 | Coste nivel 10 |
|---|---|---|---|---|
| Bolsa | Cuánto cabe en la bolsa | 8 → 38 objetos | $150 | $10.310 |
| Energía | Energía máxima | 100 → 250 | $200 | $13.740 |
| Chispa | Energía que da cada refresco | 30 → 110 | $120 | $8.250 |
| Almacén | Mascotas que caben en tu base | 30 → 130 | $180 | $12.370 |
| Velocidad | Velocidad al andar | 16 → 28 studs/s | $250 | $17.180 |
| Alcance | Distancia para recoger con clic | 6 → 16 studs | $160 | $11.000 |
| Imán | Radio de atracción automática | 0 → 15 studs | $220 | $15.120 |

Los pases de Velocidad (+25 %) e Imán (+50 %) se suman encima. Tener las 7 al máximo desbloquea el **Contenedor Dorado**.

---

## 13. Coleccionables

### Figuritas (12)
Se colocan solas en la **vitrina** de tu base.
- **6 escondidas en el mundo**: se recogen al acercarte a ellas. Cada jugador puede recoger cada una una vez, y en su pantalla desaparece. Las pistas, en la pestaña Estantería de "Mi base":
  - Gnomo Oxidado: detrás de la caseta de Doña Chatarra
  - Pato de Goma: dentro del tubo tumbado
  - Robot de Hojalata: encima del contenedor azul
  - Gatito de Cartón: bajo la rampa
  - Dinosaurio Sin Cola: dentro de la lavadora vieja
  - Astronauta Pequeñito: sobre la pila de neumáticos
- **6 salen de los montones**: Sirena de Botella, Caballero de Latas, Búho de Periódico, Rana de Tapitas, Payaso Descolorido y Doña Chatarra en Miniatura.

### Cintas (7)
Salen de los montones y se ponen en la **radio** de tu base: Ritmo Chatarra, Balada del Vertedero, Plástico Elástico, Noticias de Ayer, Compost Nocturno, Refresco Burbujeante y Marcha del Rey Reciclón. Al reproducir una, los carretes de la radio giran y se muestra el título. **Todavía no tienen audio** (el panel lo indica: "sin audio todavía").

### Trajes (3 gratis + 2 de pago)
Cambian los colores de tu avatar y le ponen un accesorio. Se equipan en la pestaña Trajes.
- Gratis (se encuentran en los montones): **Mono Naranja** (gorra), **Chaleco Reflectante** (casco), **Escafandra de Chatarra**.
- De pago: **Traje Dorado** (corona), **Fantasma del Vertedero**.

### Skins de base (de pago)
Recolorean el suelo, la cerca y los muebles de tu base: **Base Neón** y **Base Jardín**.

---

## 14. Tu base

Una parcela de 36 × 36 studs con esta distribución:

- **Arco de entrada** coral, con el nombre del dueño encima ("Base de *nombre*" o "Parcela libre").
- **Alfombra roja** desde la entrada hasta el fondo.
- **6 podios**, tres a cada lado de la alfombra. La mascota exhibida **gira despacio** sobre el suyo, con su nombre y estado encima. El **aro del podio brilla** con el color de su rareza (neón y luz). Vacíos, los aros son neutros.
- **Escenario** al fondo con la **vitrina de figuritas**: 2 baldas de cristal con 6 huecos cada una.
- **Radio** en una esquina del fondo y **banco del taller** (mesa de reparación) en la otra.
- **Teléfono** (abre la tienda) y **almacén** (cofre, abre el Álbum).
- Cerca menta alrededor, abierta al frente.

**Interacciones** (solo en tu base):

| Mueble | Qué abre |
|---|---|
| Vitrina | Mi base → Estantería |
| Radio | Mi base → Radio |
| Podios | Mi base → Exhibidor |
| Banco del taller | Mesa de reparación |
| Teléfono | Tienda |
| Almacén | Álbum |

**Visitar**: puedes entrar en las bases de otros jugadores y mirar, pero no tocar. Bajo su arco puedes darles **"Me gusta"**, una vez por base y sesión. El dueño recibe el aviso *"¡A X le gusta tu base!"* y lo ve en su contador de "Me gusta recibidos".

**Viajar**: los botones **Ir a casa** e **Ir al patio** del HUD te teletransportan a tu base o a la plaza.

---

## 15. Logros (40)

En 11 categorías. Cada uno da **$100** y se anuncia con una tarjeta grande con trofeo. El panel de Logros muestra una barra de progreso por logro y el total "N/40 logros".

| Categoría | Logros |
|---|---|
| Reciclaje | Reciclar 1 / 100 / 1.000 / 10.000 / 100.000 objetos |
| Ahorro | Tener $1.000 / $10.000 / $100.000 / $1.000.000 a la vez |
| Mejoras | Primera mejora; una mejora a nivel 5; una a nivel 10; las 7 a nivel 10 |
| Sets | Completar cada uno de los 4 sets; conseguir al Rey Reciclón |
| Estado Perfecto | 1 / 10 / 40 mascotas distintas en estado Perfecto |
| Contenedor Dorado | Abrir 1 / 10 / 50 |
| Figuritas | Encontrar 1 / 6 / 12 |
| Cintas | Encontrar 1 / 4 / 7 |
| Trajes | Encontrar 1 / 2 / 3 trajes gratuitos |
| Refrescos | Beber 1 / 25 / 100 |
| Puntería | Acertar en el contenedor desde 15 / 25 / 40 studs; acertar 50 lanzamientos |

---

## 16. Pases y compras con Robux

Ningún pase bloquea contenido: la colección entera se completa gratis.

| Pase | Precio | Efecto |
|---|---|---|
| Pase de la Suerte | 249 R$ | El pity de Raras sube 3 % por montón en vez de 2 % |
| Pase de Velocidad | 149 R$ | +25 % de velocidad |
| Pase de Imán | 149 R$ | +50 % de radio de imán |
| Auto-Ensamblaje | 199 R$ | Los 5 fragmentos se ensamblan al instante |
| Traje Dorado | 199 R$ | Traje premium |
| Fantasma del Vertedero | 79 R$ | Traje premium |
| Base Neón | 249 R$ | Skin de base |
| Base Jardín | 99 R$ | Skin de base |

| Producto | Precio | Da |
|---|---|---|
| Puñado de Gemas | 99 R$ | 100 Gemas |
| Bolsa de Gemas | 249 R$ | 300 Gemas |
| Cubo de Gemas | 499 R$ | 700 Gemas |
| Montón extra | 49 R$ | Abrir otro montón sin terminar el tuyo (se ofrece al intentar excavar) |

> Los productos todavía no están publicados en Roblox: fuera de Studio, al intentar comprarlos aparece "Producto no disponible todavía". En Studio los pases cuentan como comprados para probarlos.

---

## 17. Pantalla (HUD) y paneles

**HUD**
- **Izquierda**: botones grandes con icono: Tienda (Q), Álbum (J), Logros (L), Mi base (B), Ir a casa e Ir al patio.
- **Arriba a la derecha**: mascotas conseguidas (N/41), Gemas, el **dinero** en una píldora verde grande y la **barra de energía**.
- **Derecha**: la barra de **Fuerza** (al cargar el lanzamiento) y la barra de **Bolsa**.
- **Abajo a la izquierda**: el retrato de tu avatar.
- **Abajo a la derecha**: las pistas "MANTÉN [F] PARA LANZAR" y "MANTÉN PARA RECOGER". La de recoger desaparece sola tras 20 recogidas.
- **Avisos**:
  - arriba en el centro, lo que te pasa a ti ("Reciclaste 8 objetos por $64", "Fragmento de Latita (3/5)"…);
  - arriba a la derecha, un **feed** de lo que pasa en el servidor ("X activó un montón grande", "¡X encontró una Robolata (Rara)!", "¡Doña Chatarra trajo más basura!", "X obtuvo al Rey Reciclón").
- En el mundo hay **carteles flotantes**: "VENDER BASURA", "RESTAURAR ENERGÍA", "DOÑA CHATARRA" y el nombre de cada base. Las interacciones aparecen como pegatinas bajo la mira, con la tecla y una barra que se llena si hay que mantener.

**Paneles** (solo uno abierto a la vez)
- **Álbum**: una pestaña por set y otra del Rey. A la izquierda, las 10 tarjetas del set (silueta gris si no la tienes); a la derecha, el detalle con todas tus copias y las acciones Limpiar, Vender, Exhibir / Quitar del pedestal, Fusionar ×3 y Ensamblar. Muestra los fragmentos (N/5), "Exhibidas N/6" y "Almacén N/máx".
- **Tienda**: §9.
- **Logros**: §15.
- **Mi base**: pestañas Estantería (las 12 figuritas, con pista para las escondidas), Radio (reproducir o parar cintas) y Exhibidor (qué hay en cada podio, y quitarlo). Arriba, los "Me gusta" recibidos.
- **Mesa de reparación**: §11.

---

## 18. Multijugador

- Hasta **6 jugadores** por servidor, cada uno con su base.
- **Compartido**: el patio, sus montones y todo lo que sale de ellos (quien recoge primero, se lo lleva), las bolsas lanzadas que fallan (cualquiera las recoge) y la animación de la recicladora.
- **De cada uno**: su bolsa, su energía, su dinero, su colección y su base. Las figuritas escondidas las puede recoger cada jugador una vez.
- **Social**: el feed del servidor, visitar bases y los "Me gusta".
