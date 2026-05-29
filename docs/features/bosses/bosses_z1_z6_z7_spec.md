# Bosses Z1 / Z6 / Z7 — Spec de diseño

> **PROPUESTA Fase 4+ — validar con Leo. GDD vigente v2.2. No implementado.**
> Diseño, NO código. Se promueve a contenido recién en Fase 5 (Z6) / Fase 6 (Z7) del plan de fases (`expansion-elemental-7-zonas.md` §10). Los 3 bosses sirven al arco D4 (descenso cosmológico, §3.1) y al escalado IA R4 del GDD §7.3 (telegrafía obligatoria, ventana 0.5–1s antes de cada ataque pesado).
>
> **Todos los números marcados `[PROP]` son punto de partida para balance** — `balance-engineer` los tunea en playtest. Multiplicadores de daño expresados como ×R3-mage (convención de los bosses existentes Ignis/Lyss/Vael).

---

## Convenciones (del formato checklist + bosses existentes)

- **Telegrafía:** todo ataque pesado abre con `sprite.start_telegraph(windup)` (Pilar 2 — cada muerte enseña). Ventana visible 0.5–1.0s. Ningún patrón pega sin aviso.
- **Trigger de fase:** F2 dispara en `HP ≤ 50%` vía `health.health_changed` (igual que Ignis/Lyss/Vael). F3 (solo Z7) en `HP ≤ 20%`.
- **Status `.tres` reusados (sin tocar archivos):** `bendicion.tres` (LUZ heal source), `miasma`/`poison.tres` (SOMBRA DOT bypass armor + −Furia), `stun.tres`, `freeze.tres`, `desequilibrio.tres`. Los aplica el boss on-hit igual que Vael aplica STUN en Salto Cegador.
- **Infra confirmada viable** (vista en `boss_lyss.gd` / `boss_vael.gd`): hitbox lineal rectangular (`intersect_shape` RectangleShape2D) · AoeTelegraph + AoE circular (`aoe_telegraph.tscn` + CircleShape2D) · proyectiles spread/secuenciales (`projectile_scene.launch`) · pull (`apply_external_velocity`, boss-only) · aura periódica (tick + `apply_slow`) · knockback fuerte · heal propio (`health.heal`) · salto + landing AoE · Line2D tracking + tick damage (Lanza de Vael) · hazard persistente (lava de Ignis) · reflejo de proyectiles (Muralla de Lyss).
- `[PROP]` = número propuesto. `REQ-INFRA` = mecánica que NO existe hoy y requiere infra nueva — marcada explícitamente, con fallback viable al lado.

---

## 1. Mini-boss Z1 — **El Centinela de Borde**

| Campo | Valor |
|:--|:--|
| **Temática** | Un guardia de frontera del imperio caído, petrificado a medias en su puesto. No defiende nada — repite la última orden que recibió. El **umbral** del descenso (D4 §3.1 Z1: escombro mundano, sin carga cosmológica). |
| **Rareza** | R3-equivalente (NO R4 — sin espejo del jugador, sin F2 compleja). Es el tutorial de "leer telegrafía + romper guardia". |
| **Elemento** | NEUTRO (ninguno). Sin matchup elemental — combate moment-to-moment puro (§5.3). |
| **HP** | ~1.0× TANK R3 base `[PROP]`. Más vida que un mob, menos que un R4. |
| **Escudo** | **2 cargas** `[PROP]` — núcleo del tutorial: enseña a romper guardia (paralelo al checklist ítem 18, taunt/tank). |
| **Fases** | Sin F2 estructural. Solo un **enrage leve** a HP≤40% (cooldowns ×0.85), no cambia patrones. |

### Patrones (3 — telegrafía obligatoria)

| # | Nombre | Telegrafía | Efecto | Números `[PROP]` |
|:--:|:--|:--|:--|:--|
| 1 | **Mandoble de Guardia** | Levanta el arma 0.8s (`start_telegraph`) | Hitbox lineal rectangular frontal (estilo Látigo de Lyss). Daño medio. El golpe-base que el jugador aprende a esquivar con dash i-frames. | windup 0.8s · range 130px · width 36px · dmg ×1.1 · CD 3.0–4.5s |
| 2 | **Calar Escudo** | El centinela alza su escudo y un marcador estático aparece 0.6s | Entra en estado defensivo (postura `muralla_estatica`-like 1.5s): los ataques frontales del jugador muestran "BLOCK!". **Enseña a flanquear / esperar la apertura.** Atacar por la espalda entra normal. | postura 1.5s · CD 6.0–8.0s · REQ-INFRA: ninguna (reusa el status `muralla_estatica` de TANK R3, checklist ítem 13/216) |
| 3 | **Embate de Hombro** | Ruge + da un paso atrás 0.7s | Gap-closer: avanza y suelta hitbox de empuje con **knockback medio** (estilo Patada de Vael, más suave). Castiga quedarse pegado durante la postura defensiva. | windup 0.7s · range 110px · knockback 180/−120 `[PROP]` · dmg ×1.0 · CD 5.0–7.0s |

**Qué le enseña/exige al jugador:** las 3 lecciones base del combate. (1) **leer un telegraph y esquivar con dash** (i-frames); (2) **romper guardia** — el escudo de 2 cargas + la postura Calar Escudo obligan a no spamear ataque frontal, hay que crear apertura; (3) **gestionar el espacio** — el Embate castiga quedarse encima. Sin elemento, sin status, sin presión de DPS: el jugador puede fallar y reintentar sin sentirse castigado por azar (Pilar 2). Complejidad de R3, no de R4.

---

## 2. Boss Z6 LUZ — **El Interlocutor del Faro**

| Campo | Valor |
|:--|:--|
| **Temática** | El destinatario que respondía a los destellos de Vael (D4 §3.1 Z6 + hook canon Núcleo Fulgurante teoría #2). Sacerdote-máquina del Cenit que sostiene la *proyección* del cielo. Santidad sin fe: una liturgia que ilumina el vacío. Sereno y terrible — no odia al forastero, lo **bendice** mientras lo borra. |
| **Rareza** | R4 (boss). Espejo del jugador, escudo, skills, patrones complejos, telegrafía obligatoria (GDD §7.3). |
| **Elemento** | LUZ. Aprovecha Bendición (heal source) — el boss se **sustaina** y **ciega**. Sustain como gimmick: la pelea es una carrera de DPS contra su auto-curación. |
| **HP** | ~1.05× MAGE R4 base `[PROP]` (un pelo más tanque que Vael; sustain hace que su HP efectivo sea mayor — vigilar). |
| **Escudo** | **2 cargas** `[PROP]` (R4 podría dar 3; se baja a 2 porque su defensa real es el heal + ceguera, no el bloqueo). Recarga al checkpoint (PvE). |
| **Velocidad** | Normal-lenta (mage). Es estático/ceremonial, lo opuesto a Vael. Controla por zona, no por movilidad. |

### Gimmick central — **Sustain + Ceguera**

El Interlocutor se cura activamente (Liturgia) y degrada la *legibilidad* del jugador con luz cegadora. La tensión: si no abrís su guardia rápido, te supera con sustain; si te ciega, perdés referencia de los telegraphs. **Counter de diseño:** todo telegraph sigue siendo audio + sprite, nunca solo lumínico (Pilar 2 — la ceguera estorba pero no hace la muerte injusta).

### Patrones F1 (3)

| # | Nombre | Telegrafía | Efecto | Números `[PROP]` |
|:--:|:--|:--|:--|:--|
| 1 | **Verso de Luz** | windup 0.6s, halo dorado | 3 proyectiles LUZ en abanico (estilo Triple Tiro de Lyss / Ráfaga de Vael). Daño medio; 30% on-hit Bendición → **el boss se cura** si conecta (heal source va al atacante = el boss). | windup 0.6s · spread ±16° · dmg ×0.9 c/u · CD 4.5–6.0s |
| 2 | **Columna del Cenit** | AoeTelegraph dorado bajo el player 0.6s | Pilar de luz vertical: AoE circular telegrafiado (estilo Nova de Lyss / Salto landing de Vael). Castiga quedarse quieto. | tele 0.6s · radius 75px · dmg ×1.3 · CD 6.5–9.0s |
| 3 | **Liturgia** (sustain) | windup 0.7s + flash dorado creciente | Heal propio (estilo Destello de Vael) **+ se cura extra por cada Verso que conectó** (`[PROP]` regla simple: heal base + bonus fijo si hubo hit reciente — no requiere tracking complejo, un flag basta). Es la zanahoria: hay que **interrumpir/superar** el sustain. | windup 0.7s · heal 7% HP máx base `[PROP]` · CD 13–17s |

### F2 — `HP ≤ 50%` ("Apertura del Cenit")

Al entrar: tinte dorado intenso + shake (igual que los existentes). Cooldowns ×0.78 `[PROP]`. Suma 2 patrones:

| # | Nombre | Telegrafía | Efecto | Números `[PROP]` |
|:--:|:--|:--|:--|:--|
| 4 | **Aurora Cegadora** | Carga lumínica 0.8s, el sprite se sobreexpone | Flash de área: aplica **CEGUERA** al player en radio (REQ-INFRA — ver abajo). **Fallback sin infra nueva:** aplica `stun.tres` corto (0.3s, como el Salto Cegador de Vael) + un tinte de pantalla breve. No resetea telegraphs de audio. | windup 0.8s · radius 200px · stun 0.3s (fallback) · CD 12–15s |
| 5 | **Letanía Persistente** | Line2D dorado naciendo del boss, tracking lento 1.0s | Rayo de luz que sigue al player lento (estilo **Lanza de Vael — ya implementado**, `lerp_angle` 1.8 rad/s + tick rect query). Tick damage cada 0.3s; **30% por tick → Bendición (boss se cura mientras el rayo te toca)**. Esquivable saliendo del cono. | windup 1.0s · tracking 1.8 rad/s · tick 0.3s · dmg ×0.8/tick · CD 13–18s |

> **REQ-INFRA (Aurora Cegadora):** un status "ceguera" real (oscurecer/atenuar la pantalla del player N segundos sin bloquear input) **no existe hoy** — no hay `ceguera.tres` ni overlay de pantalla. Implementarlo es un status nuevo + un CanvasLayer de viñeta. **Mientras tanto el fallback (`stun.tres` 0.3s + flash breve) es 100% viable con la infra actual** y conserva el feel "te deslumbra". Decisión de Leo si se invierte en la ceguera real en Fase 5.

**Qué le enseña/exige al jugador:** **carrera de DPS contra sustain** — no podés jugar pasivo; si dejás respirar al boss, la Liturgia revierte tu progreso (refuerza Pilar 1: build de daño + agresión sostenida importan, eco del feel LUZ "agresión sin retroceder" del GDD §5.3). Exige **mantener Momentum alto** (más daño) mientras leés telegraphs bajo la ceguera de F2. Castiga al jugador que se queda quieto (Columna/Letanía) y al que farmea hits sin matar (Liturgia se cura de tus propios Versos conectados — aprendé a no comerte el abanico).

---

## 3. Boss FINAL Z7 SOMBRA — **El Confinado del Sello** (alias: "lo que el Sello contenía")

| Campo | Valor |
|:--|:--|
| **Temática** | Lo que el imperio enterró debajo de todo, a propósito — la zona *por la que* el colapso ocurrió (D4 §3.1 Z7). Ahora libre porque el forastero, zona a zona, quitó los anclajes (cada boss derrotado debilitó una capa). **Cierre del descenso.** El Coliseo eran los carceleros (los Ecos te entrenaron para esto sin que lo supieras — guiño narrativo, no mecánica). |
| **Rareza** | R4 — **el más difícil del juego.** Espejo pleno: escudo, skills, dash, patrones complejos, telegrafía obligatoria. |
| **Elemento** | SOMBRA. Miasma tematizado (DOT bypass armor + −50% Furia gen + −Furia). Su gimmick es **ahogar al jugador**: cortarle el recurso de skills (Furia) y meter daño que la armadura no para. |
| **HP** | ~1.15× MAGE R4 base `[PROP]` (el más alto; es el clímax). |
| **Escudo** | **3 cargas** `[PROP]` (R4 pleno, GDD §5.2 — el único de los tres con 3). |
| **Velocidad** | Media, con un **dash de boss** (REQ-INFRA leve — ver abajo) que reposiciona. Más móvil que el Interlocutor, menos frenético que Vael. |
| **Fases** | **3 fases** (es el final): F1 → F2 (`HP≤50%`) → **F3 clímax** (`HP≤20%`). |

### Gimmick central — **Asfixia de Furia + presión que ignora defensa**

SOMBRA bypassa armadura (Miasma) y ahoga la Furia: el jugador **no puede spamear skills** porque el boss le corta el recurso. Hay que ganar con ataque básico limpio + ventanas. Snowballea si lo dejás (Miasma stack INDEPENDENT, GDD §5.3) → presión creciente, coherente con el verbo D4 de Z7 "filtrar / escapar".

### Patrones F1 (3)

| # | Nombre | Telegrafía | Efecto | Números `[PROP]` |
|:--:|:--|:--|:--|:--|
| 1 | **Zarpa de Vacío** | windup 0.7s, garra de sombra se materializa | Hitbox lineal frontal (estilo Látigo). 30% on-hit Miasma (DOT bypass armor + −Furia gen). El golpe que enseña que su daño **atraviesa tu defensa**. | windup 0.7s · range 150px · width 38px · dmg ×1.2 · CD 4.0–5.5s |
| 2 | **Marea de Miasma** | 3 AoeTelegraph morados en posiciones distintas 0.55s | 3 AoE circulares secuenciales (estilo Lluvia de Meteoros de Ignis, pero SOMBRA). Cada uno aplica Miasma. Cubre zona — obliga a moverse. | tele 0.55s · radius 48px ×3 · dmg ×1.0 c/u · CD 7.0–9.5s |
| 3 | **Filtración** (proyectiles) | windup 0.7s | Abanico de 3 proyectiles SOMBRA persiguiendo levemente al player (reusa `projectile_scene`; el leve homing es opcional). 30% Miasma on-hit. | windup 0.7s · spread ±18° · dmg ×0.9 c/u · CD 5.0–7.0s |

### F2 — `HP ≤ 50%` ("El Sello se Quiebra")

Tinte morado intenso + shake. Cooldowns ×0.78 `[PROP]`. Suma 2 patrones:

| # | Nombre | Telegrafía | Efecto | Números `[PROP]` |
|:--:|:--|:--|:--|:--|
| 4 | **Atracción del Abismo** | windup 0.7s, vórtice morado bajo el boss | **Pull** del player hacia el boss 1.5s (estilo Vórtice de Lyss — `apply_external_velocity`, boss-only OK), seguido inmediato de una Zarpa. Castiga el kiteo: te arrastra al melee donde el Miasma pega. | windup 0.7s · pull 1.5s @ 280px/s · CD 12–16s |
| 5 | **Aura de Asfixia** | Aura morada permanente F2 (visible, no es ataque puntual) | Aura periódica (estilo Canto Helado de Lyss): si el player está dentro del radio, cada tick **aplica −Furia / refresca Miasma**. **Le enseña a no acampar en melee.** No es daño grande; es presión de recurso. | radius 220px · tick 0.5s · −Furia/tick `[PROP]` · activa toda la F2 |

### F3 — `HP ≤ 20%` ("El Confinado, Libre") — **clímax del juego**

> Es el final del descenso: la fase tiene que **sentirse** como el límite. No agrega muchos patrones nuevos — **acelera y combina** los que el jugador ya aprendió, más un hazard de zona.

Al entrar: flash de pantalla + shake fuerte + el sprite del boss se "desborda" (modulate sobreexpuesto morado). Cooldowns globales ×0.65 `[PROP]`. Cambios:

| Cambio | Efecto | Números `[PROP]` |
|:--|:--|:--|
| **Hazard persistente: Miasma del suelo** | Al entrar a F3, el suelo de la arena emite **charcos de sombra persistentes** (estilo lava de Ignis — `PersistentHazard`): zonas que aplican Miasma al pisarlas. Reduce el espacio seguro → fuerza movimiento constante. | 2–3 charcos · radius 60px · vida 5–6s · re-spawn cada ~4s |
| **Encadenado Atracción→Marea** | La Atracción del Abismo (P4) ahora encadena directo a Marea de Miasma (P2) — te tira al centro y llueve AoE. Combo telegrafiado (windup visible antes de cada eslabón). | — |
| **Sin Furia fácil** | Aura de Asfixia (P5) activa permanente + radio +10%. El jugador llega al clímax con Furia mínima → el final se gana con **ataque básico + dash limpio**, no con skills. Cierre temático: la sombra te ahogó, terminás con lo básico. | radio ×1.1 |

> **REQ-INFRA (dash de boss):** un "dash/teleport corto" de enemigo no está implementado como tal (los bosses se mueven por `velocity`/salto). Es infra leve. **Fallback viable hoy:** reusar el patrón de **Salto** (jump VY + reposición, como el Salto de Vael/Ignis) sin landing AoE, como movimiento de reposicionamiento. No bloquea el diseño.

**Qué le enseña/exige al jugador:** la **síntesis de todo el juego** (Pilar 1 + Pilar 2 a la vez). (1) **Build importa** — SOMBRA bypassa armadura, así que stackear defensa no salva; hay que haber armado DPS + sustain propio + (idealmente) gear que counteree (LUZ > SOMBRA ×1.5, el loot de Z6). (2) **Gestión de recurso bajo presión** — el boss te corta la Furia; el jugador que dependía de spamear skills choca con un muro y debe volver al fundamento (ataque básico + dash i-frames + Momentum). (3) **Lectura de combos** en F3 con espacio reducido por el hazard. Es el examen final: exige todo lo que Z1 enseñó (telegrafía, romper guardia, espacio) escalado al máximo, contra un boss que castiga cada mala costumbre (kiteo → pull; acampar melee → asfixia; spamear skills → sin Furia).

---

## Resumen comparativo

| | Z1 Centinela de Borde | Z6 Interlocutor del Faro | Z7 Confinado del Sello |
|:--|:--|:--|:--|
| **Rol** | Umbral / tutorial | 1ª zona cósmica | Final del juego |
| **Rareza** | R3-equiv | R4 | R4 (más difícil) |
| **Elemento** | NEUTRO | LUZ | SOMBRA |
| **Patrones** | 3 (sin F2) | 5 (3 F1 + 2 F2) | 8 (3 F1 + 2 F2 + 3 cambios F3) |
| **Escudo** | 2 cargas | 2 cargas | 3 cargas |
| **Gimmick** | romper guardia + leer telegraph | sustain + ceguera | asfixia de Furia + bypass armor |
| **Status tematizado** | — | Bendición (heal boss) | Miasma (DOT + −Furia) |
| **REQ-INFRA** | ninguno | ceguera real (fallback: stun) | dash de boss (fallback: salto) |

Todos los patrones son **viables con la infra actual** salvo los 2 `REQ-INFRA` marcados, cada uno con fallback implementable hoy. Telegrafía obligatoria en el 100% de los ataques pesados (Pilar 2). Números `[PROP]` — tunear con `balance-engineer` en playtest.
