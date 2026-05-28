# Fragua Cenicienta — Lore de zona

**Zona:** 2
**Elemento dominante:** Fuego
**Rango de nivel:** 10-22
**Boss:** Ignis, el Martillo Demente
**Materiales únicos:** Fragmento de Ascuas, Mineral de Hierro Rojo, Núcleo Ígneo (+ Piedras de Resonancia universales)

---

## Origen

Donde el Valle preservó lo civil, la Fragua preservó lo industrial.

El imperio no cayó únicamente sobre su capital. Cayó también sobre sus **distritos productivos** — los lugares donde el imperio se hacía a sí mismo. La Fragua Cenicienta era uno de esos distritos. Su nombre original (si tuvo uno) se perdió. Lo único que quedó fue el hábito de fundir.

Cuando la tierra se cerró sobre las murallas, **la Fragua no se apagó**. La presión la empujó hacia adentro, hacia abajo, hasta que las llamas encontraron veta de mineral profundo y aprendieron a alimentarse de roca caliente. El distrito siguió ardiendo. Sigue ardiendo.

Lo único que cambió fue para qué.

## La Fragua como entidad

A diferencia del Valle — que conserva sin entender — la Fragua **insiste**. Hay una voluntad gruesa en cómo se reactivan los hornos, en cómo las cadenas todavía suenan al ritmo de un martilleo que ya nadie golpea, en cómo el aire pesa con humo aunque ningún cuerpo respire.

La Fragua quiere **terminar lo que estaba forjando**. Pero ya no recuerda qué era. Y los herreros que la habitaban — los que ahora son fragmentos, eternamente atados a sus yunques — siguen golpeando metal que ya no se enfría.

El resultado es un distrito que produce **armas sin propósito, armaduras sin dueño, cadenas sin nada que sujetar**. Y cuando esas producciones se acumulan más allá de lo razonable, la Fragua las funde de vuelta y empieza de nuevo. Es un ciclo cerrado. Una repetición que el imperio nunca planeó.

## Por qué viene el jugador

El guerrero entra a la Fragua porque **el Valle no fue suficiente**. Las armas que fabrican los herreros del exterior — los que viven, los que sí saben para qué forjan — son adecuadas para los primeros pasos. Para zonas profundas, no.

La Fragua tiene tres cosas que ningún herrero contemporáneo puede replicar:

- **Fragmento de Ascuas:** brasas que arden a temperaturas que el aire normal no alcanza. Útiles para forjar acero que mantiene filo bajo calor.
- **Mineral de Hierro Rojo:** veta profunda, oxidada por siglos de calor sin oxígeno. El metal recuerda su rojo incluso después de enfriarse.
- **Núcleo Ígneo:** lo que se forma en el corazón de un horno que nunca se apagó. Imposible de reproducir. Solo se encuentra acá.

El guerrero pelea contra los herreros porque ellos no entregan. Defienden la Fragua con la misma terquedad con la que la golpean. **No es hostilidad. Es continuidad.**

## Ignis

**Ignis no es un herrero.** Es lo que queda cuando un herrero golpea durante siglos sin parar.

Las cadenas que lo anclan al centro de la arena no fueron puestas para contenerlo — **él se ancló a sí mismo**. La cadena es parte de su forja. Cuando se libera de ellas en Fase 2, no es porque haya escapado: es porque **dejó de necesitarlas**. La Fragua le dio permiso de moverse, y el guerrero está por descubrir por qué la Fragua quería que se quedara quieto.

El martillo que blande está al rojo vivo permanente. Eso no es magia ni encantamiento — es **brasa retenida en el metal**, alimentada por los hornos del distrito vía una conexión que nadie diseñó pero que existe. Cada golpe libera un fragmento de esa brasa. Por eso los suelos donde Ignis pisó quedan cubiertos de charcos de lava: no es el calor del suelo. Es el calor que el martillo perdió al impactar.

Cuando Ignis cae, **los hornos del distrito se apagan unos minutos**. Es lo más cerca que la Fragua ha estado del silencio en siglos.

## Hook al Coliseo

Los herreros de la Fragua son la primera variante del concepto Eco que difiere de los Vigías del Valle. Donde el Vigía Roto repite un gesto sin razón, **el Herrero de la Fragua repite un gesto con propósito** — propósito que ya no se sostiene, pero que estructura todo lo que hace.

Esta es la primera vez que el guerrero entiende que un Eco puede tener **intencionalidad sin sentido**. Que puede querer algo sin saber qué.

En el Coliseo eso es relevante. Los Ecos del Coliseo son jugadores reales, con builds y estrategias intencionadas. Pero cuando peleás contra un Eco, **el jugador que lo subió ya no está pensando en esa pelea** — está jugando otra cosa, o está dormido, o está vivo en otro continente. La intención del Eco es real. El contexto, no.

La Fragua es la primera vez que esa idea se vuelve viscosa.

## Hooks narrativos para zonas posteriores

- **Las cadenas de Ignis no son su única cadena.** En el Acueducto del Lamento (Zona 3) hay un personaje que también está atado a un lugar — pero el suyo es agua. Cuando el jugador la conozca, debería recordar a Ignis. La forma del cautiverio cambia. El cautiverio no.
- **El mineral rojo no es el mineral más profundo.** Veteranos del Valle mencionan, sin certeza, un metal que se forma a más profundidad — donde la Fragua nunca llegó. Quien lo encuentre entenderá por qué el imperio quería quemar la tierra entera.
- **El humo de la Fragua sale por algún lado.** No se ve desde afuera. ¿A dónde va?

## Inconsistencias detectadas

- Algunos `.tres` referenciaban un material `mineral_hierro_oxidado` que nunca se implementó. El nombre canon es **Mineral de Hierro Rojo** (`mineral_hierro_rojo`). Si Leo prefiere otro, cambiar `display_name` en `resources/materials/mineral_hierro_rojo.tres`.
- El boss Ignis está documentado en `.claude/docs/habilidades_generales.md` con 5 patrones — el quinto (Corte Giratorio F2) es el más raro. Validar in-game que su animación de cadena rota antes de F2 es legible.

## Pendientes

- **Sprites IA + parallax** — Fragua Cenicienta visual queda pendiente del pipeline `art-prompt-engineer`. Paleta sugerida: rojos saturados, ceniza gris, dorado fundido, negro carbón.
- **Audio de zona** — un track principal con martilleo rítmico de fondo + crackling de hornos. SFX por patrón de Ignis (especialmente Salto Sísmico — el thump debería sentirse hasta en touch controls).
