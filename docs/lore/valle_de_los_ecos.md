# Valle de los Ecos — Lore de zona

**Zona:** 1
**Elemento dominante:** Tierra
**Rango de nivel:** 1-15
**Boss:** El Guardián de la Maleza
**Materiales únicos:** Hierba Antigua, Savia Resonante, Esencia del Verdor (+ Piedras de Resonancia universales)

---

## Origen

Hubo un imperio. Ya nadie sabe qué nombre llevaba — los registros se perdieron cuando la tierra cerró sobre ellos. Lo único que quedó fueron sus fortalezas: piedras labradas con precisión, caminos pavimentados con un orden geométrico que la naturaleza no comprende, escudos colgando todavía en murallas que ya nadie defiende.

El imperio cayó. No por guerra, no por hambruna, no por un acto único. Cayó como caen los grandes árboles viejos: lentamente, hasta que un día el peso fue demasiado y el suelo se abrió.

Y entonces el Valle creció.

## El Valle como entidad

El Valle de los Ecos no es un escenario neutral. Es una **presencia**. No piensa, no decide, no tiene voluntad en el sentido humano — pero **conserva**. Conserva los gestos del imperio caído como un eco repite un sonido: sin entender el contenido, repitiendo la forma.

Los guardias que custodiaban las puertas todavía las custodian — aunque las puertas ya no existan.
Los exploradores que vigilaban los caminos todavía los vigilan — aunque los caminos no lleven a ninguna parte.
Los hechiceros que canalizaban la energía de la tierra todavía levantan las manos — aunque ahora la tierra los canalice a ellos.

Esto explica a los enemies. No son "monstruos". Son **fragmentos del imperio** que el Valle preservó porque era lo que tenía a mano cuando todo cayó. Su hostilidad no es voluntaria. Es la única cosa que les queda.

## Por qué viene el jugador

El jugador es un **guerrero contemporáneo** — no parte del imperio caído, no parte del Valle. Es un forastero.

La razón canónica para entrar a Zona 1 no está cerrada (Leo decide cuando arme la introducción narrativa del juego). Hipótesis viables:

- **Comercio:** los Valles guardan materiales valiosos (Hierba Antigua, Savia Resonante) que ningún herrero puede sintetizar. El guerrero entra para recolectar.
- **Búsqueda:** algo o alguien se perdió en el Valle. El guerrero busca, pelea por necesidad de seguir avanzando.
- **Iniciación:** el Valle es la primera prueba en el camino al Coliseo. Quien lo conquista demuestra que está listo para enfrentar Ecos reales.

Las tres son compatibles. Lo importante: **el guerrero NO viene a destruir el Valle** ni a "salvar" a los enemies de su condición. Viene a atravesarlo y, al hacerlo, **libera** lo que el Valle retuvo demasiado tiempo.

## El Guardián

**El Guardián de la Maleza no fue creado por el imperio.** Estaba antes. Las ruinas crecieron a su alrededor como si él las hubiera convocado.

No protege el Valle. **El Valle lo protege a él** — aunque ninguno de los dos recuerda cuándo se acordó esa relación. La maleza que lo cubre responde a sus movimientos. La piedra que es su armadura es acreción de siglos, no equipo forjado.

Cuando el jugador lo derrota, **algo se desbloquea**: no solo la próxima zona. Algo más amplio, conceptual. Es la primera vez que el guerrero entiende que estos combates *significan algo más que su propia progresión*.

## Hook al Coliseo

Los enemies del Valle son la primera versión del concepto que define el Coliseo: **fragmentos de seres reales preservados en un sistema que los repite indefinidamente, sin propósito, hasta que alguien los libera**.

En el Valle, esos fragmentos son del imperio caído.
En el Coliseo, son de otros jugadores reales — vivos, en este momento.

El paralelo no es accidental. Cuando el jugador entra al Coliseo por primera vez (nivel 10), debería **reconocer la sensación**: ya peleó contra Ecos antes. Solo que esos Ecos no sabían que eran Ecos. Estos sí.

> *"Los Ecos son fragmentos de almas de guerreros caídos atrapados en una dimensión espejo. Combatirlos no los mata — los libera. La Gloria que ganás es el reconocimiento de esas almas."* — GDD §8.2

El Valle de los Ecos es donde el jugador aprende, sin que se lo digan, qué es ser un Eco.

## Hooks narrativos para zonas futuras

Sin spoilers — solo el guiño:

1. **El imperio caído tenía nombre.** En zonas posteriores (Fuego, Agua, Viento) hay piedras con inscripciones legibles. Quien las lea entenderá qué cayó realmente.
2. **No todos los fragmentos son hostiles.** En zonas profundas hay Ecos que **no atacan** — solo observan. El Bestiario tier 3 del Guardián sugiere por qué.
3. **El Coliseo no es invención de los desarrolladores del juego.** Es una institución antigua. Quien fundó el Coliseo conocía los Valles.

## Inconsistencias detectadas con doc previa

- El GDD §10 menciona enemies con nombres "Guerreros de corteza / Chamanes de espinas / Espíritus de madera" como nomenclatura canónica de Zona 1. El bestiario actual (`bestiario_zona_1.md`) usa una nomenclatura distinta más narrativa (Vigía Roto, Centinela Ciego, Carcelero de Musgo, Vidente del Verdor, Heraldo Vacío, El Guardián de la Maleza).
- **Decisión necesaria de Leo:** elegir cuál nomenclatura es canon o reconciliar ambas. La actual (de narrative-lore) refuerza la fantasía del "imperio caído"; la del GDD original refuerza la fantasía de "naturaleza salvaje". No son incompatibles — el imperio podría haber sido humano y el Valle haberlo cubierto, y los enemies podrían tener AMBOS nombres (interno del Valle, externo del bestiario).
- El glosario menciona materiales "Madera Ancestral / Colmillos Duros / Núcleos de Tierra" que NUNCA se implementaron. Los materiales reales son Hierba Antigua, Savia Resonante, Esencia del Verdor + Piedra de Resonancia (universal). Sugerencia: cuando se diseñen enemies con drops únicos (sugerencia archivada en `docs/sugerencias.md`), los nombres viejos del glosario podrían pasar a esos drops específicos.

## Pendientes

- **Introducción narrativa del juego** — cuando el jugador arranca, ¿cómo se le presenta el Valle? Vía cinemática, texto, o se descubre solo? Decisión Leo.
- **Texto del Bestiario in-game** — el `bestiario_zona_1.md` define el contenido. La UI del bestiario (cuándo y dónde se lee) es feature de UX.
- **Diálogo del Guardián** — si tiene voz, qué dice? GDD no lo menciona. Mi recomendación: el Guardián NO habla. Solo gesticula. El silencio es parte de su identidad.
