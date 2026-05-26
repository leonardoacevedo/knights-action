# Zona: Valle de los Ecos — Arquitectura de Pacing

**Fecha:** 26/05/2026 (actualizado — Fase 3, etapas 4 y 5 añadidas)
**Autor:** level-designer (Claude subagente)
**Referencia GDD:** §7 (Estructura de Zona), §7.2 (Eco Profundo), §7.3 (Escalado de IA por rareza), §10 (Zona MVP)

---

## Arquitectura real de la zona

La zona MVP tiene **6 etapas** (5 combate + 1 boss), satisfaciendo el mínimo del GDD §7.1:

| # | Archivo | Función |
|---|---------|---------|
| E1 | `zona1_etapa_1.tres` | Introducción suave — R1 puro |
| E2 | `zona1_etapa_2.tres` | Primera exposición a rarezas mixtas |
| E3 | `zona1_etapa_3.tres` | Presión sostenida — R2 dominante |
| E4 | `zona1_etapa_4.tres` | Emboscada en la Espesura — escalada táctica |
| E5 | `zona1_etapa_5.tres` | Vanguardia del Guardián — antesala climática |
| Boss | `zona1_etapa_boss.tres` | Boss fight — Guardián de la Maleza |

**Checkpoint sugerido:** después de E3 (entre E3 → E4), cumpliendo §7 "cada 2-3 etapas".

---

## Tabla de composición final (todas las etapas)

| Etapa | Enemies | Total | Rarezas presentes |
|-------|---------|-------|-------------------|
| E1 — Avanzada de Vanguardia | Melee R1 ×3, Archer R1 ×2 | 5 | R1 puro |
| E2 — Pelotón de Guarnición | Melee R1 ×2, Tank R2 ×1, Melee R3 ×1 | 4 | R1 + R2 + R3 |
| E3 — Cacería de Élites | Melee R1 ×1, Tank R2 ×2, Archer R2 ×1, Mage R3 ×1 | 5 | R1 + R2 + R3 |
| E4 — Emboscada en la Espesura | Melee R1 ×1, Tank R2 ×2, Archer R2 ×1, Mage R3 ×1 | 5 | R1 + R2 + R3 |
| E5 — Vanguardia del Guardián | Melee R1 ×1, Tank R2 ×1, Mage R3 ×2, Archer R3 ×1 | 5 | R1 + R2 + R3 |
| Boss — Guardián de la Maleza | Tank R4 ×1 | 1 | R4 (boss) |

> Todas las etapas respetan el tope de 6 enemies máximo (perf mobile, §7 "máximo 6").
> Todas mantienen al menos 1 R1 como "punching bag" de Momentum (excepto boss, que es R4 único).

---

## Justificación pedagógica

### E1: Introducción suave (R1 puro, mix melee/ranged)

E1 enseña los fundamentos del combate sin presión. Los 3 Melee R1 son directos, sin bloqueo ni habilidades especiales (R1 = telegrafía simple, sin bloqueo, §7.3). Los 2 Archer R1 introducen que los enemies pueden atacar desde distancia — el jugador aprende a manejar el espacio y a elegir a quién golpear primero. Todos R1 garantiza que la muerte en E1 solo ocurre por ignorar telégrafos obvios.

### E2: Primera exposición a rarezas mixtas

E2 introduce la mezcla que define el juego: un R1 de punching bag para mantener Momentum, un Tank R2 que bloquea ocasionalmente (el jugador aprende a esperar ventanas), y un Melee R3 que dashea y tiene skill (§7.3 R3). Cuatro enemies — dosis controlada. El jugador sale de E2 sabiendo que existen distintos niveles de amenaza.

### E3: Presión sostenida — R2 dominante

E3 consolida lo aprendido. El R1 Melee sigue como punching bag inicial. El Archer R2 presiona desde atrás mientras el jugador gestiona los dos Tank R2, forzando posicionamiento activo. El Mage R3 introduce amenaza ranged de alta rareza. Cinco enemies — límite para no caotizar la pantalla en mobile.

### E4: Emboscada en la Espesura — escalada táctica (NUEVA)

E4 diferencia de E3 en dos dimensiones:

1. **Composición:** mismo recuento (5) pero Tank R2 sube a ×2 (antes ×1 en E2, ×2 en E3 pero como mix con Archer). Ahora son el núcleo de la amenaza cuerpo a cuerpo. El Archer R2 ya no es novedad — se convierte en parte del "estándar".
2. **Layout:** plataformas en arco continuo de borde a borde (5 plataformas L→R con altura creciente al centro), dando sensación visual de estar rodeado antes de que el combate empiece. El Mage R3 en altura obliga al jugador a subir, lo que acerca al Tank R2 que estaba en el otro extremo.

El tint verde oscuro (0.70, 0.90, 0.65) refuerza la sensación de espesura densa vs el verde más brillante de E3.

**Qué enseña:** que los R2 en grupo coordinado son más peligrosos que uno solo; que el Mage R3 en posición elevada cambia las prioridades de eliminar.

### E5: Vanguardia del Guardián — antesala climática (NUEVA)

E5 cambia el paradigma: por primera vez los R3 son dominantes (Mage R3 ×2 + Archer R3 ×1 = 3 de 5 enemies). El Tank R2 pasa a rol de "escudo vivo" que bloquea el avance mientras los R3 presionan desde posición. El R1 Melee sigue, pero aquí su función es diferente: el jugador estará tan presionado por los R3 que probablemente lo mate primero para liberar espacio — el R1 ya no es cómodo, es urgente.

Layout simétrico tipo "antesala de trono" (espejo L-R, cima central elevada) que contrasta con los layouts asimétricos de E3 y E4. El tint naranja-dorado cálido (1.10, 0.92, 0.70) prefigura el tint del boss (1.20, 0.75, 0.60) y señala al jugador: "algo viene".

**Qué enseña:** a manejar múltiples R3 simultáneos antes de enfrentar al R4; a reconocer que el Archer R3 y el Mage R3 son peligros distintos (posicionamiento vs burst); que el boss está cerca.

---

## Pacing de la zona completa (E1 → Boss)

```
E1  [R1×5]           → Warm-up, no presión, aprende mecánicas básicas
E2  [R1×2 + R2×1 + R3×1]  → Primer susto: hay enemies que responden
E3  [R1×1 + R2×3 + R3×1]  → R2 es el estándar, R3 es la excepción
─── CHECKPOINT ───────────────────────────────────────────────────────
E4  [R1×1 + R2×3 + R3×1]  → R2 en grupo coordinado + layout hostil
E5  [R1×1 + R2×1 + R3×3]  → R3 dominante, preparación boss
Boss [R4×1]           → Clímax, espejo del jugador
```

Duración estimada por etapa (objetivo 2-5 min §7):
- E1: ~2 min (sin presión)
- E2: ~2.5 min
- E3: ~3 min
- E4: ~3 min (layout complejo ralentiza)
- E5: ~3.5 min (R3 dominante = más healing necesario)
- Boss: ~4-5 min (4 cargas, fases)

**Total zona:** 18-23 min primer run. Runs posteriores más cortas por familiaridad.

---

## Drop tables

| Etapa | Materials (stage fallback) | Items |
|-------|--------------------------|-------|
| E1 | `zona1_etapa_1_materials.tres` | — |
| E2 | `zona1_etapa_2_materials.tres` | `zona1_etapa_2_items.tres` |
| E3 | `zona1_etapa_3_materials.tres` | `zona1_etapa_3_items.tres` |
| E4 | `zona1_etapa_4_materials.tres` | `zona1_etapa_4_items.tres` |
| E5 | `zona1_etapa_5_materials.tres` | `zona1_etapa_5_items.tres` |
| Boss | `zona1_etapa_boss_materials.tres` | `zona1_etapa_boss_items.tres` |

**Drop tables de enemies (por entry):**
- R1 entries → `enemy_r1_materials.tres`
- R2 entries → `enemy_r2_materials.tres`
- R3 entries → `enemy_r3_materials.tres`
- R4 (boss) → solo stage-level drop table del boss

**Diseño de items por etapa:**
- E2 → items de entrada (espada_madera, escudo_tablones): R1 accesible
- E3 → mix R1-R2 items (cota_cuero, arco_corto, escudo_hierro)
- E4 → mix R1-R2 items con más variedad (espada_hierro, cota_cuero, escudo_hierro, arco_corto): drop_chance generoso (0.35/0.30)
- E5 → items R2-R3 premium, drop_chance moderado (0.22/0.20/0.15/0.10): vara_cristal, coraza_placas, escudo_torre, espada_runica
- Boss → items R2-R3 premium alto (espada_hierro, coraza_placas, vara_cristal, martillo_guardian)

El patrón de drop_chance decreciente de E4 → E5 → Boss en items premium refleja el pilar 3: "el ranking premia al que mejora, no al que farmea" — llegar al boss no garantiza el mejor loot, pero los items finales son los más potentes.

---

## Escalado material por etapa

La `esencia_verdor` (material premium de zona) escala su drop_chance de E3 a Boss:

| Etapa | esencia_verdor drop_chance |
|-------|--------------------------|
| E3 | 5% |
| E4 (nueva) | 7% |
| E5 (nueva) | 12% |
| Boss | 10% (baja vs E5 — el boss da items, E5 da materiales) |

Nota: E5 tiene más esencia_verdor que el Boss intencionalmente. La idea: el jugador que llega a E5 y muere igual gana algo. El boss ya tiene items premium; no necesita ser también el mejor para materiales.

---

## Pendientes

### Drop table de boss con materiales exclusivos
`zona1_etapa_boss_materials.tres` reutiliza materiales que también dropean en etapas anteriores. Una drop table real debería incluir un material exclusivo del boss (ej. `colmillo_guardian.tres`) para diferenciar el premio de completar la zona. Tarea para `balance-engineer` + Leo.

### Checkpoint implementación técnica
El checkpoint después de E3 está sugerido por diseño pero no está implementado en `StageManager`. Requiere que `StageManager` emita señal al completar E3 y que `World` ejecute la restauración de cargas de escudo (§4.3 Recarga PvE). Tarea de Fase 3.

### Eco Profundo
Una vez la zona esté completa y jugada, habilitar modo Eco Profundo (§7.2): mismas escenas, enemies +20 niveles, IA R2/R3 mínimo, sin checkpoints intermedios. Sin costo de contenido extra.

### Auditoría de balance
Recomendar que `balance-engineer` valide:
- TTK en E4/E5 contra player de nivel 8-12 (rango esperado).
- Drop rate de esencia_verdor acumulada en run completa E1→Boss.
- Si la chance de items en E5 (0.10-0.22) está bien calibrada para no trivializar crafteo.

---

## Campos preservados de etapas existentes

Ningún campo de E1, E2, E3 ni de la stage boss fue modificado. Solo:
- `zona1_etapa_boss.tres`: `stage_index` 4 → 6 (refleja posición real en la secuencia), paths de drop tables actualizados a `_boss_`.
- `world.gd.DEFAULT_STAGE_PATHS`: extendido de 4 a 6 paths.
