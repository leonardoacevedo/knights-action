# Skill Tree Backend — Sistema de Progresión

**GDD:** §6 (Nivel del Personaje, Árbol de Habilidades, Respec, Fórmula Final de Stats)
**Fecha:** 2026-05-26
**Estado:** Implementado — backend completo, sin UI.

---

## Spec implementada

### 6.1 Nivel del Personaje
- Cap MVP: **30**.
- Por subir nivel: **1 punto de skill** + aumento automático de HP/Furia base.
- Curva XP: `xp_requerida = 100 × nivel^1.5` (constantes `XP_BASE=100`, `XP_EXPONENT=1.5`).

### 6.2 Árbol de Habilidades
Tres ramas **no exclusivas**. Cualquier combinación es válida. Prerequisitos solo dentro de la misma rama.
- **Guerrero:** daño físico, vida, supervivencia.
- **Mago:** daño elemental, Furia máxima, eficiencia.
- **Ágil:** velocidad, dash, i-frames, esquiva.

Total: **30 nodos** (10 por rama).

### 6.3 Respec
- Disponible en cualquier momento.
- Costo: 10 × `hierba_antigua` (material R1 común). Oro: 0 (placeholder — sistema de Oro pendiente).
- Atomicidad: materiales se descuentan y nodos se resetean en la misma operación.

### 6.4 Fórmula Final de Stats (implementada en `PlayerStatsComponent.recalculate()`)
```
HP_final = (HP_base + HP_nivel + HP_equipo + skill_hp_flat) × (1 + skill_hp_pct)
Daño_final = (daño_base_o_arma + skill_daño_flat) × (1 + skill_daño_pct)
Defensa_final = (defensa_base + defensa_equipo + skill_def_flat) × (1 + skill_def_pct)
```
Donde:
- `HP_base` = `GameConfig.PLAYER_BASE_HEALTH` (100)
- `HP_nivel` = `(nivel - 1) × 5` (+5 HP por nivel a partir del 2)
- `HP_equipo` = suma de afijos `hp` de ítems equipados
- `skill_hp_flat` = `PlayerProgression.get_skill_bonus_flat(HEALTH_MAX)`
- `skill_hp_pct` = `PlayerProgression.get_skill_bonus_pct(HEALTH_MAX)`

---

## Tabla de los 30 Nodos

### Guerrero (branch = 0)

| id | display_name | tier | prereqs | efectos | status |
|---|---|---|---|---|---|
| `guerrero_vitalidad_1` | Vitalidad | 1 | — | +10 HP flat | ✅ implementable |
| `guerrero_golpe_certero` | Golpe Certero | 1 | — | +3 daño físico flat | ✅ implementable |
| `guerrero_piel_dura` | Piel Dura | 1 | — | +4 defensa flat | ✅ implementable |
| `guerrero_cuerpo_forjado` | Cuerpo Forjado | 2 | `vitalidad_1` | +8% HP | ✅ implementable |
| `guerrero_fuerza_bruta` | Fuerza Bruta | 2 | `golpe_certero` | +8% daño físico | ✅ implementable |
| `guerrero_carga_extra` | Carga Extra | 2 | `piel_dura` | +1 carga de escudo | ⚠️ placeholder (BLOCK_CHARGES no wired aún) |
| `guerrero_voluntad_ferrea` | Voluntad Férrea | 3 | `cuerpo_forjado`, `piel_dura` | -10% daño recibido (DEFENSE_PCT) | ✅ implementable |
| `guerrero_maestria_marcial` | Maestría Marcial | 3 | `fuerza_bruta`, `golpe_certero` | +10% daño físico + 5 flat | ✅ implementable |
| `guerrero_iframes_escudo` | Bloqueo Activo | 4 | `carga_extra`, `voluntad_ferrea` | +15% i-frames | ⚠️ placeholder (IFRAMES_PCT no wired en DashComponent aún) |
| `guerrero_espiritu_marcial` | Espíritu Marcial | 5 | `maestria_marcial`, `iframes_escudo` | +20% daño físico + 20 HP (bonus post-bloqueo temporal en Fase 3+) | ✅ parcial |

### Mago (branch = 1)

| id | display_name | tier | prereqs | efectos | status |
|---|---|---|---|---|---|
| `mago_deposito_furia` | Depósito de Furia | 1 | — | +15 Furia max | ⚠️ placeholder (FURIA_MAX no wired en FuriaComponent aún) |
| `mago_golpe_canalizado` | Golpe Canalizado | 1 | — | +15% Furia ganada/golpe | ⚠️ placeholder (FURIA_GAIN_PCT no wired) |
| `mago_toque_elemental` | Toque Elemental | 1 | — | +8% daño elemental | ⚠️ placeholder (ELEMENTAL_DAMAGE_PCT no wired) |
| `mago_reserva_amplia` | Reserva Amplia | 2 | `deposito_furia` | +20 Furia max + 10% ganancia | ⚠️ placeholder |
| `mago_poder_elemental` | Poder Elemental | 2 | `toque_elemental` | +12% daño elemental | ⚠️ placeholder |
| `mago_flujo_constante` | Flujo Constante | 2 | `golpe_canalizado` | +20% Furia ganada/golpe | ⚠️ placeholder |
| `mago_ventaja_aguzada` | Ventaja Aguzada | 3 | `poder_elemental`, `toque_elemental` | +15% mult ventaja elemental | ⚠️ placeholder (ELEMENTAL_ADV_MULT) |
| `mago_tormenta_interior` | Tormenta Interior | 3 | `reserva_amplia`, `flujo_constante` | +15% elemental + 10 Furia max | ⚠️ placeholder |
| `mago_canalizar_masivo` | Canalizar Masivo | 4 | `tormenta_interior`, `ventaja_aguzada` | +20 Furia max + 10% elemental | ⚠️ placeholder |
| `mago_resonancia_arcana` | Resonancia Arcana | 5 | `canalizar_masivo` | +1 Furia/s pasiva + 15% elemental (regen Fase 3+) | ⚠️ placeholder parcial |

### Ágil (branch = 2)

| id | display_name | tier | prereqs | efectos | status |
|---|---|---|---|---|---|
| `agil_paso_ligero` | Paso Ligero | 1 | — | +7% velocidad | ⚠️ placeholder (MOVE_SPEED_PCT no wired en player.gd aún) |
| `agil_dash_rapido` | Dash Rápido | 1 | — | -20% cooldown dash | ⚠️ placeholder (DASH_COOLDOWN_PCT no wired) |
| `agil_velo_fantasma` | Velo Fantasma | 1 | — | +20% i-frames | ⚠️ placeholder (IFRAMES_PCT no wired) |
| `agil_velocidad_cazador` | Velocidad del Cazador | 2 | `paso_ligero` | +8% velocidad | ⚠️ placeholder |
| `agil_golpe_tras_dash` | Golpe Tras Dash | 2 | `dash_rapido` | +10% daño físico | ✅ implementable |
| `agil_esquiva_instintiva` | Esquiva Instintiva | 2 | `velo_fantasma` | +8% chance esquiva física | ⚠️ placeholder (EVADE_PCT, requiere sistema de esquiva) |
| `agil_torbellino` | Torbellino | 3 | `velocidad_cazador`, `velo_fantasma` | +10% velocidad + 15% i-frames | ⚠️ placeholder |
| `agil_cazador_implacable` | Cazador Implacable | 3 | `golpe_tras_dash`, `esquiva_instintiva` | +12% daño físico + -15% cooldown | ✅ parcial (daño wired, cooldown placeholder) |
| `agil_flujo_perpetuo` | Flujo Perpetuo | 4 | `torbellino`, `cazador_implacable` | +10% velocidad + -20% cooldown | ⚠️ placeholder |
| `agil_sombra_del_valle` | Sombra del Valle | 5 | `flujo_perpetuo` | +30% i-frames + 15% daño (invisibilidad Fase 3+) | ✅ parcial |

---

## Fórmulas

### XP por nivel
```
xp_requerida(n) = 100 × n^1.5   (donde n = nivel actual)
```

Ejemplos:
- 1→2: 100 XP
- 5→6: 1342 XP
- 10→11: 3162 XP
- 20→21: 8944 XP
- 29→30: 16432 XP

### Stats por nivel (incrementos base automáticos)
- HP: `base (100) + (nivel - 1) × 5`
- Furia: gestionado por FuriaComponent; `FURIA_PER_LEVEL = 2` definido pero no wired en FuriaComponent todavía (ver TODOs).

---

## Archivos creados / modificados

### Nuevos
- `scripts/data/skill_effect.gd` — Resource: enum Stat, enum Mode, amount.
- `scripts/data/skill_node.gd` — Resource: id, branch, tier, prereqs, effects.
- `scripts/data/skill_tree.gd` — Resource container con helpers de lookup.
- `scripts/systems/player_progression.gd` — Autoload: XP, nivel, árbol, respec.
- `resources/skills/main_tree.tres` — SkillTree con los 30 nodos como ExtResource.
- `resources/skills/nodes/guerrero/` — 10 archivos .tres.
- `resources/skills/nodes/mago/` — 10 archivos .tres.
- `resources/skills/nodes/agil/` — 10 archivos .tres.
- `tests/systems/player_progression_test.gd` — 17 casos de test.

### Modificados
- `scripts/components/player_stats_component.gd` — Aplica fórmula §6.4 completa (nivel + equipo + skills).
- `project.godot` — Registra `PlayerProgression` como autoload.

---

## Cómo conectar la UI futura

El agente `ux-mobile` necesita:
1. `PlayerProgression.get_level()` / `get_xp()` / `get_xp_progress()` — barra de XP.
2. `PlayerProgression.get_skill_points_available()` — badge de puntos disponibles.
3. `PlayerProgression.get_tree().get_nodes_by_branch(branch)` — listado de nodos por rama.
4. `PlayerProgression.can_unlock(id)` — habilitar/deshabilitar botón de compra.
5. `PlayerProgression.unlock_node(id)` — acción de compra.
6. `PlayerProgression.respec()` — botón de respec (mostrá el costo antes).
7. Signals: `xp_gained`, `level_up`, `skill_unlocked`, `respec_done`, `stats_changed`.
8. Para preview antes/después: leer `SkillNode.effects` y calcular diff contra stats actuales.

---

## TODOs (efectos no wired en Fase 2)

### Wire pendiente en sistemas existentes

| Stat | Sistema | Qué hacer |
|---|---|---|
| `FURIA_MAX` | `FuriaComponent` | Leer `PlayerProgression.get_skill_bonus_flat(FURIA_MAX)` en `_ready()` y sumar a `max_furia`. Reconectar en `stats_changed`. |
| `FURIA_GAIN_PCT` | `FuriaComponent.add_on_hit()` | Multiplicar `gain_per_hit` por `(1 + bonus_pct)`. |
| `FURIA_REGEN_FLAT` | `FuriaComponent._process()` | Si stage no es boss y hay bonus, sumar `amount × delta` a `current_furia`. |
| `MOVE_SPEED_PCT` | `player.gd` | Usar `SPEED × (1 + bonus_pct)` en `_physics_process`. |
| `DASH_COOLDOWN_PCT` | `DashComponent` | Exponer campo `cooldown_multiplier` y aplicar en `_cooldown_timer`. |
| `IFRAMES_PCT` | `DashComponent` | Exponer `iframe_duration_mult` y aplicar al timer de i-frames. |
| `BLOCK_CHARGES` | `ShieldComponent` | Sumar `int(bonus_flat)` a `max_charges` en `_ready()`. |
| `ELEMENTAL_DAMAGE_PCT` | `HitboxComponent` o `player.gd` | Multiplicar daño elemental por `(1 + bonus_pct)` al calcular ventaja. |
| `ELEMENTAL_ADV_MULT` | `GameConfig.element_modifier()` | Usar `ELEMENT_ADVANTAGE_MULT × (1 + bonus_pct)` si el player tiene el nodo. |
| `EVADE_PCT` | `HurtboxComponent` | Sistema de esquiva completo (roll RNG en `on_hit_received`). |
| `CRIT_PCT` | `HitboxComponent` | Sistema de críticos (Fase 3+). |

### Otros TODOs

- **XP por kill:** `HealthComponent.died` del enemy → `PlayerProgression.add_xp(GameConfig.xp_for_kill(rarity))`. NO implementado acá — scope del round siguiente o `balance-engineer`.
- **Sistema de Oro:** `RESPEC_GOLD_COST = 0` es placeholder. Al tener Oro, cambiar lógica en `respec()`.
- **SaveSystem:** `PlayerProgression` no persiste entre reinicios. Cuando `SaveSystem` exista, serializar `_level`, `_xp`, `_skill_points_available`, `_unlocked_nodes`.
- **Furia por nivel:** `FURIA_PER_LEVEL = 2` definido en `PlayerProgression` pero no wired en `FuriaComponent` (ver tabla arriba).

---

## Decisiones técnicas

### Nodos en archivos separados vs inline en main_tree.tres
Decisión: **archivos separados** (`nodes/<rama>/<id>.tres`). `main_tree.tres` referencia via `ExtResource`. Ventajas:
- Cada nodo editable independientemente en el Inspector.
- `main_tree.tres` no crece a medida que se agregan nodos.
- Diff más limpio en git.

### Atomicidad del respec
La operación verifica materiales ANTES de tocar estado. Si `remove_material()` falla (race condition teórica), el estado de nodos no se toca. No hay punto intermedio inválido.

### Atomicidad del unlock
`_skill_points_available -= cost` y `_unlocked_nodes.append(id)` ocurren en la misma función sin yields intermedios. En GDScript single-threaded, esto es suficiente para garantizar atomicidad.

### Bonus de skills para stats no wired
Los nodos con efectos `FURIA_MAX`, `MOVE_SPEED_PCT`, etc. se pueden desbloquear sin problemas. `PlayerProgression` calcula y almacena el bonus, pero los sistemas que lo consumen aún no lo leen. El nodo está "comprado" y el punto invertido — el efecto se materializa cuando se wire el sistema correspondiente.
