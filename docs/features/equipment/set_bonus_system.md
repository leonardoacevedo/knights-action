# Set Bonus System — Afinidad de Equipo

**GDD §5.4 | Fase 3**

## Qué hace

Detecta cuántas piezas del mismo elemento tiene el jugador equipadas (Arma + Armadura + Escudo) y aplica bonuses pasivos y habilidades según el conteo.

- **2pc mismo elemento:** bonus estadístico pasivo.
- **3pc mismo elemento:** habilidad pasiva única (acumula con 2pc).
- **NEUTRO** nunca da afinidad propia.

## Reglas de afinidad

- Se cuentan solo piezas con elemento distinto de NEUTRO.
- El elemento con mayor conteo gana. Si max_count < 2, no hay afinidad.
- Empate 1-1-1: sin afinidad (ninguno llega a 2).
- Empate 2-2 (imposible con 3 slots, pero defensivamente: gana el de mayor valor enum).

### Casos canónicos verificados

| Equipo | Resultado |
|--------|-----------|
| FUEGO + FUEGO + NEUTRO | FUEGO 2pc |
| FUEGO + FUEGO + FUEGO | FUEGO 3pc |
| FUEGO + AGUA + TIERRA | Sin afinidad |
| FUEGO + FUEGO + AGUA | FUEGO 2pc |

## Bonus por elemento

| Elem | 2pc | 3pc |
|------|-----|-----|
| FUEGO | +10% daño total | "Brasa Persistente" — kill → próximo golpe AoE (radio 80px, 60% daño) |
| AGUA | +1 Furia/s pasiva | "Corriente Eterna" — dash pasa por enemy → cooldown dash resetea |
| TIERRA | +15% HP máx | "Raíz Profunda" — bloquear consume y recupera 1 carga (neto: sin pérdida) |

## Arquitectura

### Nuevos archivos

- `scripts/data/set_bonus_data.gd` — Resource con valores de balance.
- `scripts/systems/set_bonus_system.gd` — Autoload. `compute_affinity`, `refresh`, `is_active`, `get_bonus_data`.
- `resources/set_bonuses/set_bonus_fuego.tres` / `agua.tres` / `tierra.tres` — Datos.

### Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `player_stats_component.gd` | Agrega `_apply_set_bonus()` al final de `recalculate()`. Aplica damage multiplier, HP multiplier y regen Furia. |
| `hitbox_component.gd` | Agrega `damage_set_bonus_multiplier` (default 1.0). Se multiplica en `_on_area_entered`. |
| `furia_component.gd` | Agrega `_passive_regen_per_sec` y `set_passive_regen()`. Regen aplica en `_process`. |
| `shield_component.gd` | Agrega `tierra_3pc_active`. `try_absorb()` recupera 1 carga si el flag está activo. |
| `dash_component.gd` | Agrega `agua_3pc_active`, `detection_area`, `_check_agua_dash_reset()`. |
| `player.gd` | Agrega `_fuego_next_attack_aoe`, `_check_fuego_kill`, `_trigger_fuego_aoe`, `_refresh_set_bonus_flags`. |
| `inventory_screen.gd` | Sección "AFINIDAD" en columna izquierda. Muestra elemento, pieces y descripciones de bonus. |
| `project.godot` | Registra `SetBonusSystem` como autoload. |

## Orden de aplicación de bonus

```
_apply_damage()          → hitbox.damage = stats base + skills
_apply_health_and_defense() → health.max_health, hurtbox.flat_defense
_apply_defender_element()   → hurtbox.element
_apply_set_bonus()       → multiplica damage / HP al final
```

El bonus se apila **al final** de la cadena para no romper las fórmulas base.

## Fórmula de daño final (con FUEGO 2pc activo)

```
daño_final = hitbox.damage × damage_multiplier × damage_set_bonus_multiplier × elem_mult
```

Donde `damage_set_bonus_multiplier = 1.10` si FUEGO 2pc activo.

## Cómo testear en editor

1. **FUEGO 2pc:** equipar Espada Runica (FUEGO) + Peto de Brasas (FUEGO) + escudo NEUTRO. El daño en HUD debe ser ~10% mayor que sin el set.
2. **FUEGO 3pc:** agregar escudo FUEGO. Matar un enemy y atacar → el golpe siguiente hace AoE visible (múltiples floaters en enemies cercanos).
3. **AGUA 2pc:** equipar set AGUA 2pc. La barra de Furia debe llenarse lentamente incluso sin atacar.
4. **AGUA 3pc:** con set AGUA 3pc, dashear a través de un enemy → el cooldown del dash (0.8s) se saltea, se puede dashear de nuevo inmediatamente.
5. **TIERRA 2pc:** equipar set TIERRA 2pc. El HP máx debe ser ~15% mayor que sin el set.
6. **TIERRA 3pc:** con set TIERRA 3pc y escudo R3 (2 cargas), bloquear dos golpes consecutivos → las cargas no bajan (consume + restaura).

## Decisiones técnicas

- **FUEGO 3pc AoE** usa `PhysicsShapeQueryParameters2D` (no spawn de nueva Area2D). Más limpio para mobile: no instancia nodos.
- **AGUA 3pc** usa `detection_area = hitbox` (la propia hitbox del player) para detectar overlap. Evita crear una Area2D extra.
- **TIERRA 3pc** lógica en `ShieldComponent.try_absorb()` — la lógica ya estaba ahí, se agrega solo el condicional.
- El `_passive_regen_per_sec` de AGUA 2pc es independiente del timer de decay. La regen sigue aunque estés en combate; el decay también sigue. Neto: depende de la tasa de ataque vs. regen.

## Riesgos conocidos

- **AGUA 3pc + dash corto:** el dash dura 0.1s. Si el enemy está muy lejos, `get_overlapping_areas()` puede no detectar overlap. Solución: aumentar `dash_duration` o el hitbox del player (ajuste en editor).
- **FUEGO 3pc multimatanza:** si el AoE mata otro enemy en su radio, `_check_fuego_kill` no vuelve a activarse en el mismo golpe (la señal `hit_landed` del AoE no va al player). Comportamiento correcto — no hay cascada.
- **TIERRA 3pc shield R1:** `max_charges = 0` para R1. La condición `current_charges < max_charges` (0 < 0 = false) nunca activa la restauración. Correcto por diseño.

## Tests

`tests/systems/set_bonus_test.gd` — headless, lógica pura.
Efectos runtime (AoE, dash reset, regen pasiva con timer) son `[INTEGRACION]` — requieren escena.
