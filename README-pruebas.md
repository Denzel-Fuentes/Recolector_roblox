# Guía de pruebas cerradas — Recíclatas

Para 3–5 probadores en el mismo servidor (máximo 6 por partida). **Esto no mide si el juego funciona,
mide si se siente bien.** Lo técnico ya está cubierto con pruebas automáticas
(`EjecutarPrueba`, ver `CLAUDE.md`); aquí interesa la sensación, y para eso
hace falta gente que no lo haya jugado. Con varios jugadores hay además dos
sistemas que solo se pueden comprobar así (ver "Lo técnico que se mira con
varios").

El mayor riesgo del diseño: que el patio compartido sin robo se sienta
"tibio", ni la calma del original ni la emoción de un juego competitivo.
Esta sesión existe para responder a eso, y a si separar por colores tiene
gracia o es un trámite.

## Cómo se juega

| Control | Acción |
|---|---|
| Al entrar | Una pantalla de carga tapa el juego hasta que llega tu progreso; apareces en la plaza, mirando al patio |
| Cámara | **Primera persona** en todo el mapa (en el patio, con tus manos y la bolsa). **V** (o el botón Cámara) cambia a tercera persona |
| Acercarse a una colina de basura y mantener **E** | Excavarla: se convierte en una montaña de basura de verdad (20 o 60 piezas). Durante 10 s solo la recoge quien la excavó |
| **Mantener el clic** apuntando a la basura (el punto del centro es la mira) | Recoge lo que pasa por la mira. Cada pieza es del **color de su tipo**: papel celeste, plástico amarillo, metal gris plomo, orgánico verde (metal y orgánico se abren con el Rebirth 1 y 2) |
| **Mantener F** (o el botón táctil) con la bolsa llena, soltar | Lanzar la **bolsa entera** a un contenedor; cuanto más lejos, más bonus (+20 % desde 10 m … +150 % desde 60 m) y racha si aciertas seguido. Solo con la bolsa llena: el servidor no lanza una a medias |
| Si la bolsa cae fuera | Es tuya 30 s (la cuenta atrás va encima); después se la puede llevar cualquiera. Como mucho 3 bolsas tuyas en el suelo: con la cuarta, la más vieja se recicla sola, sin bonus y a mitad de precio |
| **Los 5 contenedores** junto a la recicladora | 4 de color (papel, plástico, metal, orgánico) y el **general azul**. En el de su color, cada pieza paga **x2**; en el de otro color, x0,5; en el general, x1 |
| **E** en un contenedor | Reciclar a mano, sin bonus de lanzamiento (el de separar sí) |
| **Q** / **R** / **P** | Tienda / Rebirth / Pedidos e insignias |
| **M** / **G** | Sonido (música y efectos) / Recompensas (calendario y regalos por jugar; se abren con la primera mejora) |
| Gamepad | X recoger, Y lanzar, B cerrar |

Los comandos de admin para acelerar (`/dar dinero 5000`, `/maxmejoras`,
`/pases on` u `off`, `/rebirths 1`, `/tutorial 0`, `/repoblar`, `/reset`)
**solo existen en Studio** desde el 22 oct: allí todos los de la sesión son
admin y los comandos no salen en el autocompletado del chat. En el juego
publicado no hay ninguno, ni para el creador: se juega con el perfil de
verdad.

## Antes de empezar

Jugad **al menos 20 minutos** juntos, en el mismo servidor, y que al menos dos
personas exploren el patio a la vez. Si cada uno va a un montón distinto y no
os cruzáis, no se está probando lo que hay que probar. Que al menos uno sea
nuevo: el tutorial (la píldora de arriba a la izquierda) también se prueba.
Los perfiles del juego publicado empezaron de cero el 22 oct (y los
rankings): lo jugado antes no está.

## Las cuatro preguntas

Responde con frases, no con números. "Me dio rabia que se llevara el tesoro
del montón que yo había excavado" vale más que un 7/10.

### 1. El montón compartido

- ¿Fuiste a montones que excavaron otros? ¿Te pareció bien o "robar"?
- ¿Alguna vez excavaste uno grande y otros se llevaron lo bueno? ¿Qué sentiste?
- ¿Se siente vivo ver a otros excavando, o da igual que estén?

### 2. Separar por colores

- ¿Entendiste sin que nadie te lo dijera que cada contenedor paga el doble su color?
- ¿Recogiste a propósito de un solo color para llenar la bolsa, o lo mezclaste todo y fuiste al general?
- ¿Te equivocaste de contenedor alguna vez? ¿Se entendió por qué pagó menos?

### 3. El ritmo

- ¿La vuelta a los contenedores es un paseo agradable o un trámite?
- ¿Probaste a lanzar desde lejos? ¿Cuántos tiros fallaste antes de pillarle el truco?
- ¿Los pedidos del día te dieron un objetivo, o ni los miraste?
- ¿Viste el calendario y los regalos por jugar (botón Recompensas, G)? ¿Te dan ganas de volver mañana?

### 4. El dinero y las mejoras

- ¿La primera mejora llegó pronto o tardó demasiado?
- ¿Se entendió que hay que volver al contenedor para cobrar? ¿Alguien siguió
  recogiendo con la bolsa llena sin darse cuenta?
- ¿La meta del Rebirth 1 parece alcanzable o muy lejana? (Con la economía v4
  debería llegar hacia la hora de juego.)

## Lo técnico que se mira con varios (22–23 oct)

**Anti-trampas (`Movimiento`).** El servidor vigila que nadie se mueva más
deprisa de lo que permite su mejora Velocidad, con margen para el lag y los
empujones. Si alguien se pasa, durante **2 s** no puede recoger, excavar,
entregar a mano ni lanzar, **sin ningún aviso**; nunca se le echa ni se le
devuelve a su sitio. Un jugador honrado no debería notarlo jamás, así que
cualquier "pulsé y no pasó nada" durante un par de segundos es un posible
falso positivo: apuntad qué estaba haciendo (lag, saltar o caer de la
recicladora o de una montaña, justo al reaparecer, empujado por otro jugador
o por la basura que cae). En Studio,
`EjecutarPrueba:Invoke("vigilarSospechas", "empezar")`, jugar, y
`("vigilarSospechas", "ver")` dicen cuántas sospechas tuvo el primer
jugador y la última (studs, segundos y velocidad frente a su límite). En el
juego publicado cada sospecha llega a la analítica como evento `Sospecha`
(se ve en el Creator Dashboard a las 24–48 h).

**Bloqueo de sesión.** Un perfil solo lo puede tener abierto un servidor. Al
cambiar de servidor, el nuevo espera a que el viejo termine de guardar la
salida (normalmente unos segundos; si el viejo no la suelta, a los 60 s se la
queda): mientras, la pantalla de carga sigue ("Cargando tu progreso…" desde
los 8 s) y el personaje no aparece hasta que llega el perfil (como mucho a
los 75 s; con el DataStore caído aparece enseguida y se juega sin guardar).
Si un servidor intenta guardar un perfil que ya se llevó otro, echa al
jugador con "Tu partida se abrió en otro servidor. Vuelve a entrar para
seguir jugando." Para probarlo en el juego publicado: jugar un rato, pasar a
otro servidor (o entrar con la misma cuenta desde otro dispositivo, y Roblox
echa del primero) y comprobar que están el dinero, las mejoras y lo que
llevabas en la bolsa (se cobra al salir, sin bonus, también una bolsa que
estuviera en el aire); apuntad cuánto tardó en cargar. En Studio no hace
falta esperar entre un Play y el siguiente (las sesiones de otro Play de
Studio se dan por caducadas) y los perfiles van a un store aparte (`_Studio`).

Y lo que hay que ver entre varios: la prioridad de 10 s del que excava; la
bolsa ajena a los 30 s (al dueño le llega "X se llevó tu bolsa"); el récord
del servidor en el feed de los demás; las celebraciones solo para quien
cobra; las recicladoras (cinta y sonido) para todos; los tablones de la
plaza; y que los pedidos, el calendario y los regalos sean de cada uno.
Del catálogo (K1, 23 oct): la corona del VIP se ve sobre su cabeza desde
los demás clientes (el propio VIP no la ve en primera persona) y `[VIP]`
sale delante de su nombre en el chat de todos; el Turbo de cada uno se pausa
por su cuenta (quien se queda quieto 2 min ve "x2 en pausa"; el de los demás
sigue); y las ofertas son de cada uno y salen en un momento tranquilo, nunca
en la primera sesión ni a la vez que una celebración. En Studio no salen
solas: `ServerStorage:SetAttribute("OfertasEnStudio", true)` en Play.

## Qué apuntar el organizador

- Cuántos montones se excavan por minuto con 3+ personas (¿se vacía el patio
  antes de que vuelvan las colinas, 45 s después de terminar cada una?).
- Qué contenedor usa cada uno (¿todos al general? entonces el x2 no se entiende o no compensa).
- Cuánto tarda la pantalla de carga, y si alguien vio el aviso de que su
  progreso no cargó o no se guardará.
- Cualquier momento en que recoger, entregar o lanzar no respondió (ver
  `Movimiento` arriba).
- Momentos de risa o de queja en voz alta: son los datos.
