# Ruinas de Borde — Lore de zona

> PROPUESTA Fase 4+ (expansión 7 zonas). GDD vigente v2.2. Numeración de zona provisional.

**Zona:** 1 (provisional)
**Elemento dominante:** ninguno (NEUTRO)
**Rango de nivel:** 1-8
**Mini-boss (Etapa final):** Sargento de Frontera (sin elemento)
**Materiales únicos:** Cascote de Borde, Sillar Hueco, Cuño de Aduana (+ Piedras de Resonancia universales)

---

## Origen

Las Ruinas de Borde son **lo primero que la tierra cubrió, porque eran lo que estaba más a mano**.

El imperio caído no terminaba en una muralla. Terminaba en un borde difuso: aduanas, puestos de peaje, barracas de guardia, almacenes de paso, casas de gente que vivía de entrar y salir. La franja exterior. Lo mundano del imperio — lo que no tenía templo, ni horno sagrado, ni acueducto ritual. **Trabajo de frontera, sin más.**

Cuando todo cayó, la tierra cerró primero sobre el borde, porque el borde era lo más somero. No hubo presión que empujara nada hacia abajo, ni veta profunda que encontrar. La franja exterior quedó **tal cual estaba** — un escombro genérico, sin la carga cosmológica de los estratos hondos. Acá no hay elemento. Hay polvo, sillar caído y caminos que ya no llevan adentro.

Por eso el forastero entra por acá. Como entra cualquiera: por el borde, sin saber todavía que abajo hay estratos.

## Las Ruinas como entidad

El Valle conserva, la Fragua insiste, el Acueducto espera, las Cumbres observan. Las Ruinas de Borde **no hacen nada de eso todavía**. Apenas **persisten**.

Es la zona menos consciente del juego, a propósito. Los fragmentos de acá no repiten un oficio especializado — repiten gestos de **rutina**: el guardia que pide papeles, el peón que carga, el cobrador que tiende la mano. No hay propósito perdido que duela, como en la Fragua. Hay solo costumbre. La franja exterior del imperio era mundana en vida, y sigue siendo mundana en ruina.

Esto la vuelve el umbral perfecto. No hay matchup elemental que leer, no hay status que temer. Solo hay combate: acercarse, pegar, esquivar, leer telegraphs. **Lo que el forastero aprende acá es a pelear, nada más.** Las reglas profundas — los elementos — viven más abajo.

## Por qué viene el jugador

El forastero no "viene" a las Ruinas de Borde. **Empieza acá.** No hay leyenda que lo atraiga ni material legendario que lo tiente. Es el punto de entrada físico al imperio caído, y se atraviesa porque es el único camino hacia adentro.

Las tres cosas que ofrece son modestas, a propósito:

- **Materiales neutros:** Cascote de Borde, Sillar Hueco, Cuño de Aduana. Escombro genérico, sin afinidad. Sirven para forjar el primer equipo NEUTRO — el que se usa hasta encontrar el primer elemento.
- **El primer descenso:** al limpiar la zona, el forastero **encuentra la grieta que baja** hacia el Acueducto. Con ella aparece la primera veta de material *elemental*. Narrativamente: el imperio en su borde era mundano; su naturaleza elemental empieza donde empieza la profundidad.
- **Aprender a pelear:** sin la capa elemental encima, el combate moment-to-moment se enseña limpio. Es el único tramo del juego donde perder no puede achacarse al matchup.

## El Sargento de Frontera

Mini-boss de cierre. **No es del imperio profundo.** Es lo que queda del oficial que mandaba el puesto de aduana más grande del borde — el que revisaba caravanas, sellaba permisos, decidía quién entraba.

Sigue revisando. Su trabajo era **detener a quien no tenía papeles**, y el forastero, claramente, no los tiene. No pelea por odio. Pelea porque **el forastero es exactamente el tipo de cosa que él existía para frenar**: alguien que quiere entrar.

No tiene elemento, no tiene status synergy. Sus patrones son fuerza física directa: una estocada de lanza larga (telegraph generoso), un escudazo de empuje que abre distancia, y en su segunda fase un grito de "alto" que lo hace cargar en línea recta. Es el primer y único boss que el forastero enfrenta **sin nada elemental de por medio** — la prueba de que ya sabe pelear, antes de que el juego le agregue una capa más.

Cuando cae, **no pasa nada en la zona**. No se apagan hornos, no baja el agua, no se oscurece el cielo. El borde es mundano hasta en su silencio. Lo único que cambia es que **el camino hacia abajo queda abierto.**

## Hook al Coliseo

Las Ruinas de Borde son la primera vez que el forastero pelea contra Ecos — y la única zona donde el paralelo Eco/imperio es **literal sin ser todavía pesado**.

Estos fragmentos eran gente común: un guardia de turno, un cargador, un cobrador de peaje. No tenían historia épica. Hacían su trabajo y el colapso los atrapó en mitad de un gesto rutinario. Cuando el forastero llegue al Coliseo, peleará contra Ecos de jugadores reales — algunos con builds elaboradas, otros torpes y de paso. **Los del borde son el equivalente al jugador casual que subió un Eco sin pensarlo demasiado.** Patrón puro, sin alma detrás prestando atención. La zona enseña, sin decirlo, que un Eco puede ser solo eso: una repetición mundana de alguien que ya está en otra cosa.

Esa lectura barata acá se complica después, zona a zona. Pero arranca simple, como debe arrancar un tutorial.

## Hooks narrativos para zonas posteriores

- **El borde no tenía elemento, pero el imperio sí.** El forastero limpia toda la zona sin ver un solo golpe elemental. Recién al encontrar el primer descenso aparece la primera veta con afinidad. ¿Por qué la superficie era mundana y la profundidad no? Algo abajo cargó al imperio de elementos — y el borde quedó afuera de esa carga.
- **Los caminos del borde llevaban a algún lado.** Las aduanas controlaban tráfico. Tráfico hacia dónde, hacia qué centro, ya no se ve desde acá. Solo se sabe que **todo bajaba.**
- **El Sargento detenía a quien quería entrar.** Custodiaba la entrada de algo que valía la pena custodiar. Él ya no recuerda qué. El forastero lo va a averiguar bajando.

## Inconsistencias detectadas

- Los mobs NEUTRO ya existen en el motor (los enemies base actuales son elementless), así que esta zona reusa `EnemyFigure` procedural sin necesidad de variante de elemento. Confirmar al implementar que el drop table de Z1 solo entrega shards NEUTRO (gate §4.1 de la propuesta) y que completar la zona abre el flag de shards elementales.
- El **Sargento de Frontera** puede reusar una base `enemy_tank.tscn` con configuración custom (capa de aduana, lanza larga, escudo de puesto). No requiere scene boss dedicada en su primera versión — es mini-boss, no boss elemental. Pendiente decidir si se le da scene propia.

## Pendientes

- **Sprites IA + parallax** — paleta tierra apagada, piedra gris, madera vieja, óxido de herrajes. Sin saturación elemental (importante: el borde es *mundano*, contrasta con el color de las zonas profundas). Geometría: arcos de aduana caídos, barracas, postes de peaje, sillares apilados, un camino que se hunde al fondo.
- **Audio de zona** — viento seco de superficie + crujido de madera + algún metal de herraje suelto. Sin el "elemento sin descanso" que define a las otras zonas (acá no hay goteo ni tempestad ni martilleo). Música: simple, percusiva, didáctica — música de tutorial.
- **Cinemática post-Sargento** — al caer el Sargento, mostrar que **el camino al descenso queda despejado**. No es un evento dramático (el borde es mundano). Pero sí marcar visualmente que ahora se baja.
