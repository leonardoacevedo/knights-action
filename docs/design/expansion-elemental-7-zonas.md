# Propuesta de diseño — Sistema elemental v3 + expansión a 7 zonas

> **Estado:** PROPUESTA. No es canon todavía. El GDD vigente sigue siendo **v2.2** (doble triángulo, 4 zonas).
> **Origen:** decisión de dirección de Leo, 29/05/2026.
> **Gating (decisión Leo):** *diseñar primero, codear después*. Cero código hasta cerrar Fase 3 (arte + audio + playtest de zona 1). Este documento es el insumo de diseño; la implementación es trabajo de una fase futura (Fase 4+).
> **Source of truth actual:** [`GDD.md`](../../GDD.md) §5.3 (elementos) y §7 (zonas). Esta propuesta los reescribe; cuando se apruebe, se versiona el GDD a v3.0.

---

## 1. Resumen ejecutivo

Reemplazar el sistema de **doble triángulo de 6 elementos** (3 natural + 3 cósmico, GDD v2.2) por:

1. **Ciclo natural de 4 elementos:** `AGUA → FUEGO → TIERRA → VIENTO → AGUA` (cada uno vence al siguiente, ×1.5).
2. **2 elementos especiales:** `LUZ` y `SOMBRA`, opuestos directos entre sí (×1.5 mutuo), y con ventaja plana ×1.2 contra cualquier natural.
3. **7 zonas** encadenadas por elemento: `Normal → Agua → Fuego → Tierra → Viento → Luz → Sombra`.
4. **Regla de progresión:** el elemento de cada zona **vence** al de la zona siguiente → el loot que ganás en una zona counterea los mobs de la próxima. La build que armás zona a zona *es* tu ventaja.

**Por qué refuerza los pilares:**
- **Pilar 1 (build importa + skill importa):** el matchup elemental por zona hace que *qué* equipás importe tanto como cómo peleás. El loot fresco no es solo "más stats", es la llave del próximo desafío.
- **Pilar 2 (cada muerte enseña):** matchup legible (×1.5 / ×0.66) — perder por elemento equivocado es una lección clara, no azar.
- **Pilar 4 (5 min / 5 h):** 7 zonas = más profundidad opcional sin obligar a nadie.

**Riesgo principal:** scope. Pasamos de 4 a 7 zonas + reescritura del core elemental, siendo dev solo. Ver §10 (plan de fases) — se implementa por etapas, post-Fase 3, nunca en un big-bang.

---

## 2. Sistema elemental v3

### 2.1 Elementos

| # | Elemento | Tipo | Rol |
|---|----------|------|-----|
| 0 | NEUTRO | — | sin ventaja/desventaja (mobs zona 1, items base) |
| 1 | AGUA | natural | inicio del ciclo |
| 2 | FUEGO | natural | |
| 3 | TIERRA | natural | |
| 4 | VIENTO | natural | cierre del ciclo |
| 5 | LUZ | especial | versátil ofensivo, opuesto a SOMBRA |
| 6 | SOMBRA | especial | versátil ofensivo, opuesto a LUZ |

> **⚠️ Cambio de numeración:** el orden de enum cambia respecto a v2.2 (donde era FUEGO=1, AGUA=2...). Si se reordena el enum `ItemData.Element`, **se rompen todos los `.tres` existentes** que guardan `element = N` por índice. Decisión D8 (§9): ¿reordenamos el enum (migración masiva de .tres) o mantenemos los índices actuales y solo cambiamos la *lógica de matchup*? Recomendación: **mantener índices actuales**, cambiar solo la tabla de ventajas. El orden "narrativo" de zonas es independiente del valor de enum.

### 2.2 Ciclo natural

```
        AGUA
       ↗     ↘
   VIENTO     FUEGO
       ↖     ↙
        TIERRA
```

- **AGUA > FUEGO** · **FUEGO > TIERRA** · **TIERRA > VIENTO** · **VIENTO > AGUA**
- Ventaja (adyacente hacia adelante): **×1.5**
- Desventaja (adyacente hacia atrás): **×0.66** (se mantiene el valor de GDD v2.2)
- Opuesto (2 pasos en el ciclo, ej. AGUA vs TIERRA) y mismo elemento: **×1.0**

### 2.3 Especiales (LUZ / SOMBRA)

- **LUZ ↔ SOMBRA:** opuestos directos, **×1.5 en ambos sentidos** (los dos pegan fuerte al otro).
- **LUZ / SOMBRA → cualquier natural:** **×1.2** plano ("especiales por defecto pegan 1.2 a todo").
- **Natural → LUZ / SOMBRA:** **×1.1** (decisión D1 cerrada, Leo 29/05). Los naturales pegan un poco por encima de neutral a los especiales, pero menos que el ×1.2 que los especiales pegan a los naturales → asimetría a favor de los especiales en ofensiva.
- **LUZ vs LUZ / SOMBRA vs SOMBRA:** ×1.0.

### 2.4 Matriz completa (atacante ▼ / defensor ▶)

| atacante \ defensor | AGUA | FUEGO | TIERRA | VIENTO | LUZ | SOMBRA |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| **AGUA**   | 1.0 | **1.5** | 1.0 | *0.66* | 1.1 | 1.1 |
| **FUEGO**  | *0.66* | 1.0 | **1.5** | 1.0 | 1.1 | 1.1 |
| **TIERRA** | 1.0 | *0.66* | 1.0 | **1.5** | 1.1 | 1.1 |
| **VIENTO** | **1.5** | 1.0 | *0.66* | 1.0 | 1.1 | 1.1 |
| **LUZ**    | 1.2 | 1.2 | 1.2 | 1.2 | 1.0 | **1.5** |
| **SOMBRA** | 1.2 | 1.2 | 1.2 | 1.2 | **1.5** | 1.0 |

Asimetría especiales: natural → especial **×1.1**, especial → natural **×1.2** (ambos por encima de neutral, ventaja ofensiva al especial). Decisión D1 cerrada.

### 2.5 Status synergy on-hit

Se mantiene el sistema de GDD §5.3 (30% chance, status por elemento). Sin cambios:
FUEGO=Quemadura · AGUA=Congelación · TIERRA=Fractura · VIENTO=Desequilibrio · LUZ=Bendición (heal atacante) · SOMBRA=Miasma (bypass armor + -Furia). Los `.tres` de status quedan iguales (filenames legacy `vulnerable`→fractura, `poison`→miasma intactos).

### 2.6 Set bonuses / Afinidad de equipo (D18 cerrada)

Reemplaza el modelo 2pc/3pc de GDD §5.4. Afinidad = piezas del **mismo elemento** entre los **5 slots de set**: `arma`, `armadura`, `escudo`, `anillo`, `amuleto`. **Las alas NO cuentan** — van aparte (slot de utilidad libre).

- **2+ piezas mismo elemento → bonus incremental de stats:** `(N − 1) × 2%` por stat (vida / defensa / ataque), con N = piezas mismo elemento.
  - 2pc → **+2%** · 3pc → **+4%** · 4pc → **+6%** · 5pc → **+8%**
- **5 piezas (set completo mismo elemento) → habilidad única** del elemento (además del +8% de stats).

El ×1.2 ofensivo de los especiales (§2.3) es independiente del set bonus — un set LUZ o SOMBRA escala con la misma fórmula que cualquier natural. Esto cierra **D7**.

### 2.7 Rarezas — 7 tiers (◑ PROPUESTA, D21)

> Extra de dirección (Leo 29/05, "cuando puedas"). Reemplaza las 4 rarezas actuales por 7. Backlog Fase 4+ — toca `ItemData.Rarity` (scope de bloqueantes), no se implementa hasta cerrar Fase 3.

| Tier | Nombre | Alias | Color | Hex sugerido (tuneable) |
|:--:|:--|:--:|:--|:--|
| R1 | Común | r1 | gris | `#9d9d9d` |
| R2 | Raro | r2 | verde | `#1eff00` |
| R3 | Súper raro | r3 | azul | `#0070dd` |
| R4 | Ultra raro | r4 | naranja | `#ff8000` |
| R5 | Épico | r5 | morado | `#a335ee` |
| R6 | Legendario | r6 | dorado | `#ffd700` |
| R7 | Mítico | r7 | rojo | `#e60000` |

**Migración (limpia, sin tocar .tres):** el enum `ItemData.Rarity` hoy es `{R1, R2, R3, R4}` (índices 0-3). Se **agregan R5/R6/R7 al final** (índices 4-6) → los índices 0-3 **no cambian**, cero migración de los 188 `.tres`. Lo único que cambia son los **labels de display**: R3 pasa de "Épico"→"Súper raro" y R4 de "Legendario"→"Ultra raro" (los nombres "Épico"/"Legendario" se mudan a R5/R6). **Ningún item cambia de tier**, solo su nombre mostrado y su color.

**Encaje de contenido:** los items actuales (rareza 0-2 = Común/Raro/Súper raro, + `martillo_guardian` en R4 Ultra raro) quedan como tiers **bajo-medio**. R5-R7 (Épico/Legendario/Mítico) son el **high-end futuro** — room to grow, sin re-taggear nada.

**Interacciones:**
- **Shards × rareza:** la matriz elemento × rareza se extiende de 3 a 7 tiers. **Las tablas de este doc que dicen "3 rarezas" (§5.2, §12.1, conversión D13) se entienden extendidas a 7** cuando se adopte este sistema; R1-R3 = contenido actual, R4-R7 = futuro.
- **Afijos por rareza** (GDD §5.2: R1=1, R2=2, R3=3) → extender a R4-R7 (propuesta: +1 por tier hasta cap razonable, ej. R7=6-7 afijos). Decisión menor.
- **UI:** el color de rareza se usa en nombre de item / loot card / inventario / pantalla de forja → wirear los 7 colores (tabla `Rarity → Color` única).
- **Refinamiento / set bonus / elementos:** no afectados por la cantidad de tiers.

**D21 — CERRADA (Leo 29/05): mantener índices actuales.** Los items rarity=2 quedan "Súper raro" (tier 3), `martillo_guardian` rarity=3 queda "Ultra raro" (R4). Cero migración de `.tres`. El contenido actual es bajo-medio; R4-R7 libres para high-end futuro. Solo cambian labels de display + colores.

---

## 3. Estructura de 7 zonas

| Zona | Elemento | Lore existente reusable | Boss | Estado |
|:--:|:--|:--|:--|:--|
| **Z1** | NORMAL (sin elemento) | — (nueva) | mini-boss sin elemento | 🆕 crear |
| **Z2** | AGUA | Acueducto del Lamento (hoy Z3) | Lyss | ♻️ reordenar |
| **Z3** | FUEGO | Fragua Cenicienta (hoy Z2) | Ignis | ♻️ reordenar |
| **Z4** | TIERRA | Valle de los Ecos (hoy Z1) | Guardián de la Maleza | ♻️ reordenar |
| **Z5** | VIENTO | Cumbres de la Tempestad (hoy Z4) | Vael | ♻️ reordenar (separar LUZ) |
| **Z6** | LUZ | — (nueva; hoy LUZ vive mezclada en Z4) | 🆕 boss LUZ | 🆕 crear |
| **Z7** | SOMBRA | — (nueva) | 🆕 boss SOMBRA | 🆕 crear |

**Observación clave:** las 4 zonas actuales **conservan su identidad de lore y su boss** — Acueducto sigue siendo agua, Fragua sigue siendo fuego, Valle tierra, Cumbres viento. Solo cambian:
1. el **orden de juego** (secuencia nueva),
2. se **antepone** una zona tutorial Normal,
3. se **separa LUZ** de Cumbres a su propia zona Z6,
4. se **agrega** zona SOMBRA Z7.

→ **3 zonas nuevas a construir** (Normal, LUZ, SOMBRA). Las otras 4 se migran/reordenan.

> **Capa Mundo (confirmada 29/05):** estas 7 zonas son el contenido del **Mundo 1 ("El Imperio Caído")**. Por encima va una jerarquía **Mundo → Zona → Etapa** con mapa de mundos + desbloqueo lineal (vencer un mundo habilita el siguiente), para alargar el juego con más mundos. Estructura barata + backward-compatible, detalle en [`multi-mundos-maqueta.md`](multi-mundos-maqueta.md). No reemplaza esta expansión — la envuelve.

### 3.1 Arco narrativo de las 7 zonas reordenadas — ◑ PROPUESTA (D4)

> **Estado: ◑ propuesta-completa.** Espera validación de Leo. No reescribe los `.md` de lore de las zonas existentes — define el *esqueleto* (hilo conductor + 1 párrafo por zona) sobre el cual `narrative-lore` redactaría los archivos en content-time (Fase 4+).

**El problema.** El lore vigente ordena la conciencia de los fragmentos como Valle (no sabe) → Fragua (intención sin sentido) → Acueducto (espera) → Cumbres (Vael *sabe*). La secuencia de juego nueva (Agua→Fuego→Tierra→Viento) reordena esas zonas, así que la "escalera de conciencia" lineal por orden de visita se rompe.

**La solución propuesta — desacoplar el eje "conciencia" del eje "orden", y reemplazarlo por un eje nuevo que SÍ respeta el orden: la profundidad geográfica.** El estilo canon ya da el lenguaje: cada zona es un **estrato del imperio caído** que la tierra selló a distinta profundidad. El nuevo hilo no es "qué tan conscientes son los fragmentos" sino **"qué tan hondo bajás en las ruinas del imperio — y qué tan cerca estás de lo que el imperio enterró a propósito"**. El forastero **desciende**: de la superficie civilizada hacia el núcleo cósmico que el imperio selló bajo todo lo demás. Cada zona conserva intacto su lore propio (verbo de conciencia incluido: el Valle sigue *conservando*, la Fragua *insistiendo*, etc.) — solo cambia el **marco que las encadena**.

Esto **respeta el estilo "imperio caído + fragmentos preservados"** sin tocar el contenido existente: los verbos de conciencia siguen siendo rasgo *de cada zona*, no la métrica de progresión global. Y aprovecha tres hooks ya plantados en el lore canon (faro de Vael con destinatario desconocido; "algo más profundo debajo del Acueducto que el imperio conocía"; "el humo de la Fragua sale por algún lado").

**Esqueleto narrativo — 1 párrafo por zona:**

- **Z1 · NORMAL — Las Ruinas de Borde (NUEVA, tutorial sin elemento).** La franja exterior del imperio caído: lo primero que la tierra cubrió y lo más somero que quedó. No es un estrato "elemental" — es el **escombro genérico** del imperio, sin la carga cosmológica de las zonas profundas. Aquí los fragmentos son los más simples: guardias de frontera, peones, gente común que el colapso atrapó sin un rol especializado que repetir. El forastero entra como entra cualquiera: por el borde, sin saber todavía que abajo hay estratos. **Función narrativa = umbral.** Aprende a pelear contra fragmentos que no pegan con elemento (combate moment-to-moment puro, sin matchup). Al limpiar Z1, **encuentra el primer descenso** — y con él, la primera veta de material *elemental*. Mecánicamente esto es el gate de shards (§4.1): la superficie da escombro neutro; los elementos viven abajo. Narrativamente: *el imperio en su borde era mundano; su naturaleza elemental empieza donde empieza la profundidad.*

- **Z2 · AGUA — Acueducto del Lamento (REORDENADA, lore intacto).** El primer estrato profundo: el sistema hidráulico que el imperio enterró bajo su superficie. Es la **puerta al descenso** porque el agua siempre busca el punto más bajo — seguir el Acueducto *es* bajar. El verbo de la zona sigue siendo *esperar*. **Lyss** se mantiene como la anomalía canon (no es del imperio, tiene alma) — y ahora gana una función estructural en el arco: ella es **la primera señal de que el imperio enterró cosas que no le pertenecían**. El forastero todavía no lo entiende; solo siente que algo "no debería estar acá". (El hook canon "hay algo más profundo debajo del Acueducto, el imperio lo conocía" ahora apunta literalmente hacia las zonas siguientes.)

- **Z3 · FUEGO — Fragua Cenicienta (REORDENADA, lore intacto).** Bajando desde el agua se llega al calor: los distritos industriales que la presión empujó *hacia abajo* hasta que las llamas encontraron veta profunda (esto ya es canon textual de la zona). El verbo sigue siendo *insistir*. Encaje en el descenso: el hook canon "el humo de la Fragua sale por algún lado, no se ve desde afuera" se resuelve aquí como **conducto vertical** — el humo sube por las grietas que conectan la Fragua con el Acueducto de arriba, y baja calor hacia los estratos de abajo. **Ignis** se mantiene; su martillo de brasa retenida es la primera vez que el forastero ve energía elemental *concentrada a propósito*, no ambiental.

- **Z4 · TIERRA — Valle de los Ecos (REORDENADA, lore intacto).** Aquí hay que reinterpretar levemente el marco sin tocar el archivo: el Valle deja de ser "la superficie verde por donde se entra" y pasa a leerse como **el estrato donde la tierra misma se volvió el agente preservador** — la capa geológica que cerró sobre el imperio, ahora poblada de raíces y piedra viva. Sigue *conservando*. **El Guardián de la Maleza** gana peso en el arco nuevo: el canon ya dice que "estaba antes del imperio" y que "las ruinas crecieron a su alrededor". En el descenso, eso lo vuelve **el primer ser que el forastero encuentra que es más viejo que el imperio caído** — un eslabón hacia lo que hay todavía más abajo (el eje cósmico). Su silencio (recomendación canon: no habla) refuerza que es pre-imperial.

- **Z5 · VIENTO — Cumbres de la Tempestad (REORDENADA + separar LUZ).** Giro del descenso: tras tres estratos hacia abajo, el forastero **sube** — pero a un lugar que el colapso dejó *suspendido*. El canon ya dice que las Cumbres no se hundieron; "la tierra se hundió por debajo" dejándolas flotando sobre el Valle/Acueducto/Fragua. En el arco nuevo, esto las vuelve **el punto bisagra**: lo único del imperio que quedó *por encima* del derrumbe, asomado al vacío. El verbo sigue siendo *observar*. **Vael** se mantiene como boss VIENTO de cierre del ciclo natural — pero su carga LUZ se **extrae** a Z6: ya no es "Señor de la Luz Cegadora" *en* las Cumbres, sino el último que **proyectaba luz hacia un destinatario que vive más arriba/afuera**. El faro de Vael deja de ser el clímax lumínico y pasa a ser **el dedo que señala hacia la Z6**. (Ajuste de archivo: el `cumbres_tempestad.md` describe a Vael como dual VIENTO+LUZ; en la promoción a v3.0 se reencuadra como VIENTO puro + "operador del faro", y la luz se canoniza en Z6. Pendiente de redline.)

- **Z6 · LUZ — El Faro del Cenit (NUEVA; hoy LUZ vive mezclada en Cumbres).** El destinatario del faro de Vael. Si las Cumbres eran lo más alto del imperio, **el Faro del Cenit está por encima incluso de eso** — el verdadero techo cósmico, donde el sacerdocio supremo de los portadores sostenía la *proyección* del cielo (hook canon: "el cielo de las Cumbres no es cielo real, es una proyección sostenida por voluntad colectiva"). El verbo propuesto de la zona: **irradiar** — sus fragmentos no esperan ni observan; *emiten*, sostienen activamente una realidad que ya no tiene a quién servir. Aquí el forastero entiende que la luz de Vael nunca fue ofensiva por naturaleza: era **comunicación**. La zona LUZ es santidad sin fe, una liturgia que ilumina el vacío. El boss LUZ (nuevo) sería el **interlocutor del faro** — el hook canon del Núcleo Fulgurante teoría #2 ("había alguien que respondía a los destellos de Vael"). Tono: cegador, ceremonial, sereno y terrible a la vez.

- **Z7 · SOMBRA — El Sello del Fondo (NUEVA; cierre del eje cósmico).** El estrato más profundo: lo que el imperio enterró **debajo de todo, a propósito**. El canon ya plantó la munición: "el imperio sabía que iba a caer y dejó cosas atrás deliberadamente"; "había algo bajo el Acueducto que el imperio conocía y por eso construyó encima". Z7 es eso — no una zona que el colapso creó, sino **la zona por la que el colapso ocurrió**. Si LUZ es la proyección que sostiene la realidad, SOMBRA es **lo que esa proyección fue diseñada para tapar**. El verbo propuesto: **filtrar** — la sombra no se preserva ni observa; *escapa*, se cuela por cada grieta (el humo de la Fragua que bajaba, el goteo que el Acueducto contenía, todo drenaba hacia aquí). LUZ y SOMBRA son el **eje cósmico** literal: el imperio entero — Valle, Fragua, Acueducto, Cumbres — fue construido **entre** un faro que irradia arriba y un sello que filtra abajo. El boss SOMBRA (nuevo) cierra el juego: aquello que el sello contenía, ahora libre porque el forastero, zona a zona, fue **quitando los anclajes** (cada boss derrotado debilitó una capa). Conexión al Coliseo: el canon dice "el Coliseo es una institución antigua; quien lo fundó conocía los Valles". Propuesta: **el Coliseo es el mecanismo que el imperio dejó para seguir conteniendo la sombra después de su caída** — los Ecos no son entretenimiento, son **carceleros**. El forastero que llega a Z7 descubre para qué sirvió pelear Ecos todo este tiempo.

**Cómo encadenan (hilo conductor en una línea):** *superficie mundana (Z1) → se desciende por agua (Z2) → calor (Z3) → tierra/raíz pre-imperial (Z4) → se asoma al vacío en altura (Z5) → se sube al techo cósmico de luz (Z6) → se baja al sótano cósmico de sombra (Z7).* El forastero empieza atravesando escombro y termina destapando el eje luz/sombra entre el cual el imperio entero estaba suspendido. La progresión de **conciencia** (verbo por zona) se conserva como textura local; la progresión **global** pasa a ser de **profundidad cosmológica** — coherente con el orden de juego y con el estilo "imperio caído / fragmentos preservados".

**Riesgo / nota de validación:** el único reencuadre que toca un archivo existente es Vael (dual VIENTO+LUZ → VIENTO + operador-del-faro). Las 4 zonas reordenadas conservan texto; solo se reinterpreta el *marco* del Valle (de "entrada verde" a "estrato geológico") y de las Cumbres (de "final del MVP" a "bisagra hacia lo cósmico"). **Validar con Leo antes de redactar los `.md` nuevos de Z1/Z6/Z7.**

---

## 4. Lógica de progresión (reward loop)

Regla de Leo: *"la zona actual es del elemento superior a la siguiente"*. El jugador llega a cada zona con el loot de la anterior, que tiene **ventaja elemental** contra los mobs nuevos.

| Transición | Loot que traés | Mobs nuevos | Matchup | ¿Recompensa? |
|:--|:--|:--|:--:|:--:|
| Z2→Z3 | AGUA | FUEGO | ×1.5 | ✅ |
| Z3→Z4 | FUEGO | TIERRA | ×1.5 | ✅ |
| Z4→Z5 | TIERRA | VIENTO | ×1.5 | ✅ |
| **Z5→Z6** | **VIENTO** | **LUZ** | **×1.1** | **⚠️ seam débil (D3)** |
| Z6→Z7 | LUZ | SOMBRA | ×1.5 | ✅ |

**Seam Z5→Z6 (VIENTO→LUZ) — resuelto (D3):** se deja con el **matchup normal, sin puente**. VIENTO pega ×1.1 a LUZ y recibe ×1.2 de vuelta → el jugador entra a Z6 en **ligera desventaja neta**, lo que sube la dificultad un poco de forma natural (intencional). **La regla "zona previa vence a la actual" aplica solo a la cadena natural (Z2→Z5).** En las zonas de elemento especial (Z6 LUZ, Z7 SOMBRA) NO se garantiza esa ventaja — entrás al eje cósmico y rearmás build. (Z6→Z7 igual queda favorable porque LUZ > SOMBRA ×1.5 por matchup, pero es consecuencia del matchup, no una regla de diseño.)

### 4.1 Economía de obtención — shards + drops de boss (estilo Knights & Dragons)

Cambia el modelo de drops actual (hoy las etapas dropean items completos + materiales). Dos fuentes de equipo:

1. **Etapas (mobs normales) → shards.** Los mobs dropean **shards** (fragmentos de equipo), no items completos. Juntás N shards → forjás/ensamblás el item.
2. **Boss de zona → shards garantizados + chance de item completo.** El boss siempre dropea shards; además tiene **chance** (no garantizado) de soltar un item completo — será una pieza fuerte, por eso es raro (estilo cofre/boss de K&D). Decisión D12.

**Gate por zona Normal (Z1):**
- Z1 (Normal) solo dropea **shards normales** (equipo NEUTRO).
- Los **shards elementales** (AGUA, FUEGO, …) recién se desbloquean al **completar Z1**.
- Z1 es gate obligatorio: tutorial + llave de acceso a la capa elemental.

**Esto cierra D2:** el jugador no "recibe un elemento" suelto — al limpiar Z1 desbloquea la capacidad de juntar shards elementales, y en cada zona elemental farmea los shards de ESE elemento para forjar su gear (que counterea la zona siguiente, §4). El loop "farmeo shards de mi elemento actual → forjo → counterea la próxima" *es* la progresión.

**Taxonomía de shards.** Un shard se define por **elemento × rareza** (ej. `shard_agua_r2`). Hay shards de distintas rarezas; forjar un item R(n) consume shards R(n) de su elemento. Total ≈ 7 elementos (incl. NEUTRO) × 3 rarezas R1-R3 = **~21 tipos de shard**. **Todo el equipo se obtiene solo por forja de shards o drop de boss** — no hay otra fuente.

**Equipo = 6 slots fijos (D17 cerrada):** `arma` · `armadura` (pieza completa, sin split casco/torso/piernas) · `escudo` · `anillo` · `amuleto` · `alas`. Todos craftables por shards de su elemento + rareza. Esto **duplica** los slots actuales (hoy 3: arma/armadura/escudo) y agrega 3 categorías nuevas (anillo/amuleto/alas) que no existen aún como item: requieren modelo de datos + stats propios + representación visual (D19). Con 6 slots, los thresholds de set bonus 2pc/3pc de GDD §5.4 quedan obsoletos → rediseño (D18).

**Crafteo = shards + oro (D11 cerrada).** Forjar un item cuesta **N shards** (del elemento + rareza, D13) **+ oro**. Los shards reemplazan a los materiales como input de equipo. El **oro es la moneda universal**, con doble sink:
1. **Forjar equipo** (shards + oro).
2. **Mejoras de skills** (§6 progresión).

Esto crea tensión de economía deliberada — *¿invertís el oro en gear o en skills?* — que refuerza Pilar 1 (build importa). **Pendientes que destraba:** qué pasa con los materiales + 14 recetas actuales (D14) y si "mejoras de skills con oro" es una capa nueva sobre el árbol de puntos de GDD §6.2 (D15). Además, el **income de oro todavía no está implementado** (CLAUDE.md lo marca pendiente) — esta expansión lo necesita real, con fuentes balanceadas (mobs/boss/venta de shards sobrantes).

**Encaje con plataforma:** modelo shard-fusion + moneda universal es canónico mobile (target del proyecto) — sesiones cortas que acumulan fragmentos, gratificación diferida, decisiones de gasto. Refuerza Pilares 1 y 4.

---

## 5. Inventario de contenido necesario

### 5.1 Zonas nuevas (3) — cada una requiere

Por zona (según GDD §7.1: 5-8 etapas + boss):
- 5-8 `stage_data.tres` con spawns, plataformas, tints
- Mobs por clase (MELEE/TANK/ARCHER/MAGE) con el elemento de la zona — reusan `EnemyFigure` procedural + variantes de skill R2/R3
- 1 boss nuevo (`BossFigure` + patrones + scene) — Z6 LUZ, Z7 SOMBRA; Z1 Normal puede cerrar con mini-boss sin elemento
- Lore: mundo + bestiario + materiales (patrón de `docs/lore/`)
- Backgrounds (prompts Gemini vía `art-prompt-engineer`, mismo pipeline canon)
- Drop tables + materiales por zona
- Set de items del elemento (arma×4 tipos + armor + escudo)

### 5.2 Items por elemento — estado actual

| Elemento | Items existentes | Falta |
|:--|:--|:--|
| AGUA | cota_glacial, escudo_glacial, arco_glacial, maza_glacial, espada_lamento, vara_cristal | revisar cobertura 4 tipos arma |
| FUEGO | espada_runica, martillo_fragua, peto_brasas, aegis_igneo, **arco_brasas, vara_brasas** (hoy huérfanos → aquí encuentran casa) | — |
| TIERRA | manto_raices, baluarte_terreo, martillo_guardian, coraza_placas | armas faltantes |
| VIENTO | manto_viento, arco_huracan, maza_tormenta, sable_brisa, vara_tempestad | escudo/armor extra |
| LUZ | casulla_luz, halo_luz, vara_luz, arco_solar, espada_alborada, martillo_radiante | (mover de Z4 a Z6) |
| SOMBRA | **daga_sombra, capa_sombra, orbe_sombra** (hoy huérfanos) | set completo: espada/martillo/arco/vara/armor pesado SOMBRA |

**Gap de categorías nuevas:** la tabla arriba solo cubre arma/armadura/escudo. Los slots `anillo`/`amuleto`/`alas` **no tienen ningún item creado** — hay que diseñarlos para los 7 elementos × 3 rarezas. Es el grueso del contenido de items nuevo de esta expansión (D19 define su identidad de stat).

→ Los **5 items huérfanos** que originaron esta conversación (`arco_brasas`, `vara_brasas` FUEGO; `daga_sombra`, `capa_sombra`, `orbe_sombra` SOMBRA) **dejan de ser huérfanos**: FUEGO va a Z3, SOMBRA a Z7. Resuelve el problema original sin parche.

### 5.3 Zona Normal (Z1) — caso especial

- Mobs **sin elemento** (NEUTRO) — ya existen (los enemies base actuales son elementless).
- Sirve de tutorial: enseña combate moment-to-moment sin la capa elemental.
- Solo dropea **shards normales** (NEUTRO). Completarla **desbloquea los shards elementales** de las zonas siguientes (gate, §4.1). El boss de Z1 puede dar un item normal completo.

---

## 6. Impacto en código (cuando se implemente)

> Solo inventario, **no se toca nada ahora**.

- **Core matchup:** reescribir `GameConfig.ELEMENT_ADVANTAGE` (hoy doble triángulo) → matriz 6×6 de §2.4. Punto único de verdad; `HitboxComponent` y `Projectile` ya la consumen.
- **ItemData:** extender enum `Slot` (hoy weapon/armor/shield) con `anillo`/`amuleto`/`alas`. Equip UI + cálculo de stats para 6 slots. Las 3 nuevas dan atk/def/vida y son elementales (6 estilos c/u); alas fuera del conteo de set bonus (D19).
- **SetBonusSystem:** reescribir a fórmula `(N−1)×2%` sobre **5 slots** (alas excluida del conteo) + habilidad única a 5pc. Hoy es 2pc/3pc.
- **Sistema de shards (nuevo):** tipo de dato shard (elemento × rareza), inventario de shards, pantalla de forja (shards + oro → item). Reestructura DropSystem (mobs→shards, boss→items).
- **Economía de oro:** implementar income real (hoy placeholder) + sinks (forja + skills, D15/D16).
- **Crafteo legacy eliminado (D14):** quitar el `CraftingSystem` por materiales + las 14 recetas + `MaterialData` + drops de materiales. Reemplazado por forja de shards. ⚠️ borrado de contenido — confirmar en implementación (Regla 1). Refinamiento (§5.6) sobrevive aparte (D20).
- **Skills con niveles (D15):** `PlayerSkillData` / árbol gana niveles — el punto desbloquea el nodo, el oro sube el nivel (efecto creciente por nivel). Nuevo sink de oro.
- **Status synergy:** sin cambios (`_try_apply_element_status`).
- **Set bonus:** `SetBonusSystem` — reinterpretar "elemento opuesto" según matriz nueva (D7).
- **Zonas:** `StageManager` + `world.gd` zone chaining 1→7 (hoy 1→4). Reordenar refs de `stage_data`.
- **Drop tables:** reasignar por zona nueva.
- **HUD:** indicador de matchup elemental (hoy implícito) — oportunidad de hacerlo visible (Pilar 2).
- **GDD:** reescribir §5.3 + §7.1 + tabla §10 fórmulas + versionar a v3.0.
- **Balance:** re-banding de niveles (hoy max 30, "Valle 1-15") para 7 zonas — `balance-engineer`.

---

## 7. Migración de contenido existente

1. **Zonas:** renumerar refs (Valle Z1→Z4, Fragua Z2→Z3, Acueducto Z3→Z2, Cumbres Z4→Z5). Cuidado con `boss_scene_override`, `zone chaining`, y los `_items.tres` que apuntan por path.
2. **Items LUZ:** mover lógicamente de drops Z4 a Z6 (los `.tres` no cambian, solo qué tabla los referencia).
3. **Drop tables:** `zona4_boss_items.tres` (hoy VIENTO+LUZ) se parte en VIENTO (Z5) + LUZ (Z6 nueva).
4. **Lore:** rehacer hilo conductor (D4).
5. **GDD:** v2.2 → v3.0 con changelog.

---

## 8. Balance (notas para `balance-engineer`)

> Todo lo de esta sección es **PROPUESTA — validar con balance-engineer / Leo**. Los números son puntos de partida para tunear en playtest, no canon. Las tres decisiones de balance abiertas (D6, D13, D16) se desarrollan en §8.1–8.3.

**Notas generales:**
- 7 zonas × 5-8 etapas = ~35-56 etapas de combate. Re-bandear curva XP/nivel (D6, §8.1).
- El reward loop ×1.5 zona-a-zona puede hacer la progresión **demasiado fácil** si el jugador siempre tiene ventaja. Contrapeso: los mobs de cada zona tienen *su* elemento, que es desventaja (×0.66) para el loot **viejo** (2 zonas atrás) — incentiva actualizar gear, no quedarse.
- Especiales (LUZ/SOMBRA) con ×1.2 plano + status fuertes (Bendición heal / Miasma bypass) → vigilar que no eclipsen a los naturales en endgame. Posible cap o costo.
- El seam VIENTO→LUZ (D3) es el momento de máxima dificultad — tunear ahí.

### 8.1 Re-banding de niveles para 7 zonas — ◑ PROPUESTA (D6)

> **Estado: ◑ propuesta-completa.** PROPUESTA — validar con balance-engineer / Leo.

**Restricción de diseño (GDD §7.1):** sin auto-scaling. Cada zona tiene una **banda de nivel fija**. Volver a zona vieja con nivel alto = power fantasy intencional. Hoy el GDD solo define Valle = 1-15 y nivel máx = 30 (MVP, 4 zonas). Con 7 zonas, 30 niveles repartidos en 7 bandas dan ~4 niveles útiles por zona — demasiado apretado, y choca con la curva XP `100 × nivel^1.5` que se empina mucho al final.

**Propuesta: subir el nivel máximo de 30 → 60.** Razón: 7 zonas necesitan espacio de progresión, y el techo de 30 era para un MVP de 1-4 zonas. 60 da ~7-9 niveles de banda por zona (con solapes intencionales para el power-fantasy de re-run), y mantiene la curva XP manejable porque cada zona aporta su tramo. Las bandas **se solapan en los bordes** (no son disjuntas) — entrás a una zona cerca del piso de su banda y la dejás cerca del techo, con margen para volver más fuerte.

| Zona | Elemento | Banda de nivel (propuesta) | Notas |
|:--:|:--|:--:|:--|
| **Z1** | NORMAL | **1 – 8** | Tutorial. Onboarding suave; primer punto de skill temprano. |
| **Z2** | AGUA | **7 – 16** | Primera zona elemental. Solape con Z1 (7-8). |
| **Z3** | FUEGO | **15 – 24** | |
| **Z4** | TIERRA | **23 – 33** | Cruza el viejo techo de 30 — aquí se justifica subir el cap. |
| **Z5** | VIENTO | **32 – 42** | Cierre del ciclo natural. |
| **Z6** | LUZ | **40 – 51** | Primera zona cósmica. Banda un poco más ancha (curva de aprendizaje del eje especial). |
| **Z7** | SOMBRA | **50 – 60** | Endgame. Techo del juego en su nivel narrativo más profundo. |

- **Coliseo:** desbloqueo a nivel 10 (GDD §8.3) cae dentro de Z2 — sin cambios.
- **Eco Profundo (GDD §7.2):** enemies +20 niveles sobre la banda. Con cap 60, el Eco Profundo de Z7 llegaría a ~80 efectivos — definir si el cap de personaje sube o si Eco Profundo escala enemies por encima del cap del player (probablemente lo segundo).
- **Validación pendiente:** balance-engineer debe correr la curva `100 × nivel^1.5` contra estas bandas y el income de oro/XP (D16) para confirmar que el tiempo-a-nivel por zona es sano para sesiones mobile (Pilar 4). Posible alternativa conservadora: cap 50 con bandas de ~7. Marcado para tuning.

### 8.2 Conversión shards → item por rareza — ◑ PROPUESTA (D13)

> **Estado: ◑ propuesta-completa.** PROPUESTA — validar con balance-engineer / Leo.

Forjar 1 item consume **N shards del mismo elemento + rareza** (D10) **+ oro** (D11). Objetivo de feel: **grind mobile sano** — que juntar un item se sienta como una meta de varias sesiones cortas, no de un solo run (trivial) ni de semanas (farmeo tóxico). Referencia de plataforma: fusion-stones estilo K&D.

**Tabla de costos de forja (propuesta):**

| Rareza item | Shards requeridos (mismo elem+rareza) | Oro | Sesiones-objetivo aprox.* |
|:--:|:--:|:--:|:--:|
| **R1 — Común** | **8** | **150** | < 1 (forjable casi al toque) |
| **R2 — Raro** | **20** | **600** | 1–2 |
| **R3 — Épico** | **45** | **2.000** | 3–5 |

*Asumiendo tasas de drop de shards de §8.3 y ~1 etapa por sesión corta. Solo para dar sentido al feel; balance-engineer ajusta.

**Decisiones de tuning embebidas (todas validables):**
- **Curva ~×2.5 por rareza** (8 → 20 → 45) en vez de lineal: que R3 cueste sustancialmente más refuerza que el endgame es una meta, no un trámite. Más suave que el ejemplo del default §9 (10/25/50) para no inflar el grind en mobile.
- **Oro escala más fuerte que shards** (×4 → ×3.3 por salto) porque el oro tiene **doble sink** (forja + skills, D11/D15) — encarecer la forja en oro crea la tensión "gear vs skills" deseada (Pilar 1).
- **Sin "upgrade" directo R(n)→R(n+1) por shards.** La fusión legacy (3×R(n) → 1×R(n+1), GDD §5.5) queda fuera del scope shard salvo que Leo la quiera reintroducir — por defecto, cada rareza se forja con sus propios shards de su rareza. (Nota: D10 dice "shards R(n) forjan item R(n)"; mantener consistente.)
- **Drop de item completo del boss (D12)** es el atajo a R3 sin juntar 45 shards — por eso es raro (chance, no garantizado). Mantiene la zanahoria de boss.

### 8.3 Income de oro — ◑ PROPUESTA (D16)

> **Estado: ◑ propuesta-completa.** PROPUESTA — validar con balance-engineer / Leo.

**Problema crítico (no cosmético):** hoy el income de oro es **placeholder** (CLAUDE.md / §6) y la forja (D13) + las mejoras de skills (D15) **ya cobran oro**. Sin income real, el juego se **traba** al implementar la expansión: el jugador tiene sinks pero no source. Esta decisión desbloquea D13 y D15.

**Modelo propuesto — 3 fuentes:**

| Fuente | Tasa aprox. (oro) | Notas |
|:--|:--|:--|
| **Mobs normales** | **2–6 por kill**, escalado por banda de zona | Escala suave con el nivel de la zona (Z1 ~2, Z7 ~6). Afectado por **Momentum drop-rate** (GDD §4.3: ×(1+0.1×Momentum)) — jugar bien rinde más oro. Refuerza Pilar 1. |
| **Boss de zona** | **80–250 por kill** según zona | Recompensa principal por completar zona. Primer kill de cada boss puede dar un bono extra one-time. |
| **Venta de shards sobrantes** | **shard R1 ~5 · R2 ~15 · R3 ~40** | Sink-to-source: shards de elementos que no usás se venden. Cierra el loop de "farmeo shards de mi elemento → me sobran de otros → los vendo para forjar el mío". |

**Estimación de equilibrio (sanity check, no canon):**
- Una etapa de Z3 (FUEGO) con ~15 mobs a ~3 oro + Momentum medio ≈ **50–80 oro/etapa**, más shards.
- Forjar 1 item R2 cuesta 600 oro (§8.2) → **~8-12 etapas** de income puro, o menos si vendés shards sobrantes. Cae en la franja "varias sesiones cortas" → grind sano.
- **Tensión deliberada (Pilar 1):** el mismo oro sube niveles de skill (D15). El jugador elige. El income debe ser suficiente para *progresar en un eje* a ritmo sano, pero **no en ambos a la vez** sin esfuerzo — esa escasez es el diseño, no un bug.

**Sinks a balancear contra este income (referencia):**
1. Forja de equipo (D13, §8.2).
2. Subir niveles de skills (D15).
3. Refinamiento +1→+10 (GDD §5.6, sobrevive — D20): oro + Piedras de Resonancia.
4. Respec (GDD §6.3): oro + materiales comunes — revisar qué cuenta como "material común" tras eliminar materiales (D14); probablemente pase a oro + shards o solo oro.

**Pendiente para balance-engineer:** fijar las constantes finales corriendo income vs. los 4 sinks sobre las 7 bandas (D6). El número clave a vigilar es **oro/hora efectivo** vs. **costo total de un set completo R3 (5 slots × 45 shards + oro) + skills maxeadas** — que el endgame se sienta alcanzable en semanas de juego casual, no de grind hostil.

---

## 9. Decisiones abiertas (para redline de Leo)

> **Leyenda:** ✅ = cerrada (canon de la propuesta) · **◑** = propuesta-completa, dimensionada en este doc pero **esperando validación de Leo/balance** (no canon todavía).

| ID | Decisión | Estado / propuesta |
|:--:|:--|:--|
| ~~D1~~ ✅ | Multiplicador natural → especial (LUZ/SOMBRA) | **×1.1 — CERRADA (Leo 29/05)** |
| ~~D2~~ ✅ | Cómo se desbloquean los elementos | **CERRADA: completar zona Normal (Z1) desbloquea shards elementales. Etapas dan shards, boss da items.** |
| ~~D3~~ ✅ | Seam VIENTO→LUZ | **CERRADA: matchup normal sin puente (1.1↔1.2). Dificultad sube un poco, intencional. Regla "prev vence actual" solo en cadena natural Z2→Z5; especiales no la garantizan.** |
| **D4** ◑ | Arco narrativo con zonas reordenadas | **◑ PROPUESTA (§3.1) — no canon, valida Leo:** descenso cosmológico (superficie→profundidad); eje luz/sombra como techo/sótano del imperio; esqueleto de las 7 zonas. Zonas existentes conservan lore (solo reencuadre de marco + Vael VIENTO+faro). |
| ~~D5~~ ✅ | Desventaja natural | **CERRADA: ×0.66 (igual que v2.2).** |
| **D6** ◑ | Re-banding de niveles para 7 zonas | **◑ PROPUESTA (§8.1) — validar con balance-engineer / Leo:** nivel máx 30→60; tabla zona→banda con solapes (Z1 1-8 … Z7 50-60). Números de partida para tuning. |
| ~~D7~~ ✅ | ×1.2 especiales en set bonus | **CERRADA: el ×1.2 es solo matchup ofensivo. Set bonus = % por cantidad de piezas (D18), independiente e igual para todos los elementos.** |
| ~~D8~~ ✅ | Enum Element | **CERRADA: mantener índices actuales; el ciclo se define solo en la tabla de matchup, no en el orden del enum. Cero migración de .tres.** |
| ~~D9~~ ✅ | Opuesto natural (2 pasos) | **CERRADA: ×1.0 — los opuestos son "igual de fuertes" entre sí, sin relación de ventaja.** |
| ~~D10~~ ✅ | Granularidad del shard | **CERRADA: genérico por elemento + rareza (1 "shard AGUA R2" → cualquier item AGUA R2). Estilo fusion-stones K&D.** |
| ~~D11~~ ✅ | Modelo de crafteo | **CERRADA: craft = shards + oro. Shards reemplazan materiales como input de equipo. Oro = moneda universal (equipo + mejoras de skills).** |
| ~~D12~~ ✅ | Boss da item | **CERRADA: por chance (no garantizado) — será pieza fuerte. Shards igual garantizados.** |
| **D13** ◑ | Conversión shards → item por rareza (cuántos shards = 1 item R1/R2/R3) | **◑ PROPUESTA (§8.2) — validar con balance-engineer / Leo:** R1=8 shards+150 oro · R2=20+600 · R3=45+2.000. Curva ~×2.5, oro escala más fuerte (doble sink). |
| ~~D14~~ ✅ | Materiales + 14 recetas | **CERRADA: obsoletos, eliminar. Todo el equipo pasa por shards + oro.** |
| ~~D15~~ ✅ | Mejoras de skills con oro | **CERRADA: puntos desbloquean el nodo (§6.2), oro sube el nivel del skill. Cada skill tiene niveles con efecto creciente (ej. +daño: lvl1 5%, lvl2 7%…).** |
| **D20** | ¿Refinamiento (§5.6, piedras + oro) sobrevive a la eliminación de materiales? | sí — refinamiento es upgrade aparte; piedras de resonancia siguen como su consumible |
| ~~D21~~ ✅ | Rarezas 7 tiers (§2.7) | **CERRADA: 7 tiers Común/Raro/Súper raro/Ultra raro/Épico/Legendario/Mítico + colores. Append R5-R7 al enum, mantener índices actuales (cero migración). Items actuales = tier bajo-medio. Pendiente menor: afijos R4-R7.** |
| **D16** ◑ | Income de oro (hoy placeholder) — fuentes + tasas | **◑ PROPUESTA (§8.3) — validar con balance-engineer / Leo:** 3 fuentes (mobs 2-6/kill ×Momentum · boss 80-250 · venta shards R1~5/R2~15/R3~40). Balancear contra 4 sinks. Desbloquea D13/D15. |
| ~~D17~~ ✅ | Conteo de slots de equipo | **CERRADA: 6 slots — arma, armadura (completa), escudo, anillo, amuleto, alas.** |
| ~~D18~~ ✅ | Set bonus con 6 slots | **CERRADA: afinidad sobre 5 slots (alas excluida). (N−1)×2% por stat desde 2pc. 5pc = habilidad única del elemento.** |
| ~~D19~~ ✅ | Categorías anillo/amuleto/alas | **CERRADA: las 3 dan ataque/defensa/vida (por ahora) y son elementales — 6 estilos base, 1 por elemento. anillo+amuleto cuentan para set bonus; alas NO (slot utilidad, elemental pero fuera de afinidad). Falta solo modelo de datos + visual en impl.** |

---

## 10. Plan de fases (post Fase 3)

Nunca big-bang. Orden sugerido:

1. **Fase 4 — Core elemental v3:** reescribir matriz matchup + HUD de ventaja + tests. Reordenar las 4 zonas existentes + insertar Z1 Normal. **Sin contenido nuevo de combate** salvo el tutorial. Valida que el reward loop *se siente* antes de invertir en zonas nuevas.
2. **Fase 5 — Zona LUZ (Z6):** zona completa + boss + items + lore. Primera zona "cósmica".
3. **Fase 6 — Zona SOMBRA (Z7):** cierre del set. Homes definitivos de los items SOMBRA.
4. **Fase 7 — Balance + Eco Profundo** de las 7 zonas.

Cada fase es un hito jugable independiente (Pilar 4: entregables chicos, sin burnout).

---

## 11. Estado y próximo paso

**Diseño del sistema cerrado (29/05).** 16 de 20 decisiones cerradas: D1, D2, D3, D5, D7, D8, D9, D10, D11, D12, D14, D15, D17, D18, D19 + D20 (default). Las 4 restantes ahora tienen **propuesta-completa (◑)** — desarrolladas en este doc, esperando validación de Leo/balance, **no canon todavía**:
- **D4** (arco narrativo) → ◑ propuesta en §3.1: descenso cosmológico, eje luz/sombra, esqueleto de las 7 zonas. Valida Leo en content-time.
- **D6** (re-banding) · **D13** (conversión shards→item) · **D16** (income de oro) → ◑ propuestas en §8.1–8.3. Números de partida para `balance-engineer`; tunear en playtest.

Ninguna de las 4 **bloquea el diseño del sistema** — quedan como insumo dimensionado para implementación.

Esta spec queda **lista para implementar en Fase 4+**, recién después de cerrar Fase 3 (arte + audio + playtest de zona 1). Plan de fases en §10. El **data model de implementación** está en §12. Cuando se implemente, esta propuesta se promueve a **GDD v3.0**.

Mientras tanto, **el GDD sigue siendo v2.2** y el código no se toca.

---

## 12. Data model (spec de implementación)

> **Mapa de implementación para Fase 4+, no código.** Describe estructuras de datos y flujo, sin GDScript real. Asume el motor actual (Godot 4.6, Resources `.tres`). Sigue siendo **PROPUESTA** — no se toca código hasta cerrar Fase 3. Las decisiones cerradas que aterriza: D10/D11/D13 (shards+forja), D17/D18/D19 (6 slots + set bonus), D15 (skills con nivel).

### 12.1 Shard — nuevo Resource

Nuevo tipo de dato (Resource, ej. `ShardData`). Un shard es **genérico por elemento × rareza** (D10) — no tiene slot ni stats propios; es materia prima fungible.

**Campos:**
- `element: Element` — reusa el enum existente `ItemData.Element` (NEUTRO=0 … SOMBRA=6). Sin migración (D8: índices intactos).
- `rarity: Rarity` — reusa el enum de rareza existente (R1-R3 hoy; hasta R7 con rarezas v2, §2.7).
- `quantity: int` — cantidad acumulada (un shard es un stack, no un ítem único).
- (opcional) `display_name` / `icon` derivables de element+rarity para la UI.

**Almacenamiento en inventario:** **no** se guarda un Resource por unidad. El inventario lleva un **diccionario de stacks** indexado por la clave `(element, rarity)` → `quantity` (ej. `{ (FUEGO, R2): 14, (AGUA, R1): 33, … }`). ~21 claves con 3 rarezas activas hoy; hasta 49 (7 elem × 7 rarezas) si se adopta rarezas v2 (§2.7). Esto evita instanciar miles de Resources y encaja con el modelo fusion-stones. Persistencia: el dict serializa al save existente (local + cloud, GDD §14). Catálogo de definiciones (icono/nombre por combinación) como tabla estática o `.tres` por combinación, separado del conteo del jugador.

**Quién los produce:** `DropSystem` reestructurado — mobs normales dropean shards (no items completos), boss dropea shards garantizados + chance de item (D12). Z1 solo dropea shards NEUTRO; completar Z1 abre el flag que habilita drops de shards elementales (D2, gate §4.1).

### 12.2 Forja — input/output + pantalla nueva

Sistema nuevo (ej. `ForgeSystem`) que reemplaza al crafteo por materiales (D14, eliminado).

**Contrato:**
- **Input:** `N` shards de un `(element, rarity)` dado **+ oro**. `N` y oro según tabla §8.2 (R1=8/150, R2=20/600, R3=45/2.000 — propuesta, validable).
- **Selección de output:** el jugador elige **slot** (arma/armadura/escudo/anillo/amuleto/alas, §12.3). El elemento y la rareza del output **los fija el shard** (forjar con shards FUEGO R2 → item FUEGO R2 del slot elegido).
- **Output:** 1 `ItemData` de ese elemento + slot + rareza, con afijos rolados según rareza (GDD §5.2: R1=1, R2=2, R3=3 stats secundarias). Para arma, el subtipo (espada/martillo/arco/vara) también se elige.
- **Validación:** verifica `quantity >= N` y `oro >= costo` antes de confirmar; descuenta ambos atómicamente.

**Pantalla de forja (nueva UI):** selector de elemento → selector de rareza (limitado a las rarezas con stock suficiente) → selector de slot/subtipo → preview de costo (N shards + oro) y de stats-rango del resultado → botón forjar. Muestra stock actual de shards por `(element, rarity)`. Sin tiempo de espera (instantáneo en MVP, GDD §5.5). Acceso desde el hub/menú junto a equipar y árbol de skills.

### 12.3 6 slots de equipo — extender `ItemData.Slot`

Hoy el enum `ItemData.Slot` = `{ weapon, armor, shield }`. Extender a **6** (D17):

```
Slot = { weapon, armor, shield, ring, amulet, wings }
```

(añadir `ring`/`amulet`/`wings` **al final** del enum para no reordenar índices existentes — mismo principio que D8.)

**Identidad de stat (D19) — los 3 slots nuevos dan atk/def/vida:**

| Slot nuevo | Stats | Elemental | Cuenta para set bonus |
|:--|:--|:--:|:--:|
| **anillo** (`ring`) | ataque / defensa / vida | sí (6 estilos, 1 por elemento) | **sí** |
| **amuleto** (`amulet`) | ataque / defensa / vida | sí (6 estilos, 1 por elemento) | **sí** |
| **alas** (`wings`) | ataque / defensa / vida | sí (6 estilos) | **NO** (slot utilidad) |

- Los 3 son **elementales** y craftables por shards (igual que arma/armadura/escudo).
- Contenido nuevo a crear: 6 estilos base (1 por elemento) × 3 rarezas para cada uno de los 3 slots = el grueso de items nuevos de la expansión (§5.2 gap).
- **Equip UI + cálculo de stats** deben pasar de iterar 3 slots a iterar 6. La fórmula final (GDD §6.4) suma los 6 al bloque "Stats de Equipamiento".

### 12.4 Set bonus — fórmula sobre 5 slots (alas excluida)

Reescribir `SetBonusSystem` (hoy 2pc/3pc, GDD §5.4) a la fórmula de D18.

- **Conteo:** `N` = nº de piezas del **mismo elemento** entre los **5 slots de set** (arma, armadura, escudo, anillo, amuleto). **Alas NO entra al conteo** (D18/D19).
- **Bonus de stats incremental:** `(N − 1) × 2%` aplicado a cada stat (vida / defensa / ataque), desde N=2.
  - 2pc → +2% · 3pc → +4% · 4pc → +6% · 5pc → +8%.
- **5pc (set completo mismo elemento):** además del +8%, desbloquea la **habilidad única del elemento** (1 por elemento; el ×1.2 ofensivo de LUZ/SOMBRA es matchup aparte, D7 — no es la habilidad de set).
- **Flujo:** al equipar/desequipar, recalcular N por elemento sobre los 5 slots → aplicar % y togglear la habilidad de 5pc. Alas se ignora en este cálculo aunque aporte sus stats base al total.

### 12.5 Skills con nivel — punto desbloquea, oro sube nivel

Extender `PlayerSkillData` / el árbol (GDD §6.2) para que cada nodo tenga **niveles** (D15).

- **Desbloqueo:** 1 **punto de skill** abre el nodo a nivel 1 (igual que hoy).
- **Subir de nivel:** consume **oro** (sink de D16, §8.3), no puntos. Cada nivel sube el efecto del skill de forma creciente (ej. +daño: lvl1 +5%, lvl2 +7%, lvl3 +9%…).
- **Campos por nodo:** `unlocked: bool` · `level: int` (0 = bloqueado) · `max_level: int` · curva de efecto por nivel (tabla o fórmula) · costo de oro por nivel (creciente).
- **Cálculo:** "Bonus de Skills" de la fórmula final (GDD §6.4) pasa a sumar el efecto **al nivel actual** de cada nodo, no un valor fijo.
- **Respec (GDD §6.3):** devuelve puntos; definir si reembolsa el oro invertido en niveles o si el oro se pierde (probablemente se pierde — refuerza el peso de la decisión de gasto, Pilar 1). Pendiente de redline.

### 12.6 Resumen de lo que toca (cross-ref §6)

Esta spec aterriza, en orden de dependencia: enum `Slot` (12.3) → `ShardData` + inventario de stacks (12.1) → `ForgeSystem` + UI (12.2) → `SetBonusSystem` reescrito (12.4) → skills con nivel (12.5). El income de oro (D16/§8.3) es prerequisito transversal: sin él, forja y skills no tienen source. El detalle de qué se borra (crafting legacy, materiales, 14 recetas — D14) está en §6.
