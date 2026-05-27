# Sistema Elemental — GDD §5.3

**Fase:** 3  
**Fecha:** 2026-05-26  
**Estado:** Implementado. Zona 1 asignada (2026-05-26). Pendiente: visual elemental de enemies, armadura elemental del player.

---

## Spec canónico

Triángulo elemental MVP:

| Atacante | Defensor | Modifier |
| :--- | :--- | :--- |
| Fuego | Tierra | ×1.5 (ventaja) |
| Tierra | Agua | ×1.5 (ventaja) |
| Agua | Fuego | ×1.5 (ventaja) |
| Tierra | Fuego | ×0.66 (desventaja) |
| Agua | Tierra | ×0.66 (desventaja) |
| Fuego | Agua | ×0.66 (desventaja) |
| Cualquiera | NEUTRO | ×1.0 |
| NEUTRO | Cualquiera | ×1.0 |
| X | X (mismo) | ×1.0 |

**Canon definitivo 27/05** — 6 elementos totales: VIENTO (4), LUZ (5), SOMBRA (6) agregados al enum. Triángulo secundario VIENTO > LUZ > SOMBRA > VIENTO. Cross-triángulo (primario vs secundario): ×1.0 neutral.

| Atacante | Defensor | Mult |
|---|---|---|
| Viento | Luz | ×1.5 |
| Luz | Sombra | ×1.5 |
| Sombra | Viento | ×1.5 |
| Luz | Viento | ×0.66 |
| Sombra | Luz | ×0.66 |
| Viento | Sombra | ×0.66 |
| Fuego/Agua/Tierra | Viento/Luz/Sombra | ×1.0 (cross-triángulo) |
| Viento/Luz/Sombra | Fuego/Agua/Tierra | ×1.0 (cross-triángulo) |

**Status synergy on-hit (30% chance, HitboxComponent + Projectile, rediseño 27/05 — eje natural vs cósmico):**

*Eje natural (control + daño elemental puro):*
- FUEGO → **Quemadura** (DOT 3s rápido)
- AGUA → **Congelación** (-30% velocidad 2s)
- TIERRA → **Fractura** (próximo golpe recibido +20% dmg, single-use, ventana 5s)
- VIENTO → **Desequilibrio** (interrumpe ataque actual + 1.5s CD penalty)

*Eje cósmico (alteración de stats + supervivencia + maldiciones):*
- LUZ → **Bendición Divina** — vampire heal: cura 5% HP máx al **atacante** (no aplica status al defender)
- SOMBRA → **Miasma** — DOT 5s + bypass armor + halve generación de Furia del defender

Detalle completo en `.claude/docs/habilidades_generales.md` §7.5.

---

## Cómo se calcula

**Punto único de cálculo:** `GameConfig.element_modifier(attacker_element, defender_element) -> float`.

El modifier se aplica en dos lugares (ambos independientes):

1. **`HitboxComponent._on_area_entered`** — melee. Lee `hitbox.element` (atacante) y `hurtbox.element` (defensor). Multiplica al final junto con `damage_multiplier` (Momentum).
2. **`Projectile._on_area_entered`** — ranged. Lee `projectile.element` (seteado por `launch()`) y `hurtbox.element` (defensor).

Fórmula completa (melee):
```
final_damage = round(damage * damage_multiplier * element_modifier)
```

Fórmula proyectil:
```
final_damage = round(damage * element_modifier)
```
(El Momentum ya fue aplicado al `damage` del proyectil antes del `launch()`.)

---

## Dónde vive el elemento de cada entidad

### Player (atacante)
- **Elemento:** el del arma equipada (`InventorySystem.get_equipped(ARMA).element`).
- **Seteado en:** `Player._start_attack()` — escribe `hitbox.element` y `hitbox.element` antes del swing.
- **Proyectil:** pasa `hitbox.element` como `attacker_element` a `proj.launch()`.
- **Hurtbox del player:** `element = NEUTRO` por defecto. Si en el futuro hay armaduras elementales, setear aquí.

### Enemy (atacante y defensor)
- **Elemento:** campo `element` en `Enemy` (`@export_enum`).
- **Seteado desde:** `EnemySpawnEntry.element` → `World._instantiate_enemy()` → `enemy.element`.
- **En `enemy._ready()`:** propaga a `hitbox.element` y `hurtbox.element`.
- **Proyectil de enemy:** pasa `element` a `proj.launch()`.

### BossGuardian
- Hereda de `Enemy` — `element` propagado automáticamente en `_ready`.

---

## UI feedback

Floaters de daño sobre enemies usan `spawn_with_size()`:

| Situación | Color | Tamaño fuente |
| :--- | :--- | :--- |
| Ventaja (×1.5) | Dorado brillante `(1.0, 0.80, 0.15)` | 32 |
| Desventaja (×0.66) | Gris azulado `(0.55, 0.70, 0.90)` | 20 |
| Neutral | Amarillo estándar `(1.0, 0.95, 0.35)` | 26 |

Player recibe daño siempre en rojo (su hurtbox es NEUTRO por defecto — los enemies no tienen ventaja elemental sobre él hasta que se asignen elementos al player/armadura).

---

## Archivos modificados

- `scripts/systems/game_config.gd` — función `element_modifier()`, constantes `ELEMENT_ADVANTAGE_MULT`, `ELEMENT_DISADVANTAGE_MULT`.
- `scripts/components/hitbox_component.gd` — campo `element`, cálculo elemental en `_on_area_entered`.
- `scripts/components/hurtbox_component.gd` — campo `element`, señal `hit_received` con `was_advantage`.
- `scripts/projectiles/projectile.gd` — campo `element`, `launch()` acepta `attacker_element`, cálculo elemental en `_on_area_entered`.
- `scripts/data/enemy_spawn_entry.gd` — campo `element`.
- `scripts/entities/enemy.gd` — campo `element`, propagación en `_ready`, floater elemental vía `hurtbox.hit_received`.
- `scripts/entities/player.gd` — setea `hitbox.element` en `_start_attack`, actualiza firma `_on_hit_received` (3 params), pasa `hitbox.element` al proyectil.
- `scripts/ui/damage_floater.gd` — método `spawn_with_size()`.
- `scripts/world/world.gd` — `_instantiate_enemy()` acepta `enemy_element` y lo propaga.

---

## Tests

Archivo: `tests/systems/element_system_test.gd`

Casos cubiertos (10):
1. NEUTRO vs FUEGO → 1.0
2. NEUTRO vs AGUA → 1.0
3. NEUTRO vs TIERRA → 1.0
4. FUEGO vs NEUTRO → 1.0
5. NEUTRO vs NEUTRO → 1.0
6. FUEGO vs FUEGO → 1.0 (mismo elemento)
7. FUEGO vs TIERRA → 1.5 (ventaja)
8. TIERRA vs AGUA → 1.5 (ventaja)
9. AGUA vs FUEGO → 1.5 (ventaja)
10. TIERRA vs FUEGO → 0.66 (desventaja)
11. AGUA vs TIERRA → 0.66 (desventaja)
12. FUEGO vs AGUA → 0.66 (desventaja)

Ejecución:
```
godot --headless --script res://tests/systems/element_system_test.gd
```

---

## Asignaciones zona 1 — Valle de los Ecos (2026-05-26)

Zona dominante: **TIERRA**. Presencia secundaria de AGUA en Mages (Savia Resonante, lore).

### Armas

| Arma | Rareza | Elemento | Valor enum | Justificación |
| :--- | :--- | :--- | :---: | :--- |
| `espada_madera.tres` | R1 | NEUTRO | 0 | Starter, sin afinidad. |
| `espada_hierro.tres` | R2 | NEUTRO | 0 | Crafteable genérica. |
| `espada_runica.tres` | R3 | FUEGO | 1 | Filo místico. Ventaja sobre zona TIERRA. |
| `arco_corto.tres` | R1 | NEUTRO | 0 | Starter ranged. |
| `vara_cristal.tres` | R3 | AGUA | 2 | Cristal acuoso. Ventaja sobre zonas FUEGO futuras. |
| `martillo_guardian.tres` | R3 | TIERRA | 3 | Forjado del Guardián caído. Ventaja sobre Mages AGUA. |

Armaduras y escudos: **NEUTRO** (hurtbox del player no consume element de armadura en MVP).

### Enemies por stage

| Stage | Entry ID | Clase | Rareza | Elemento | Valor enum |
| :--- | :--- | :--- | :--- | :--- | :---: |
| etapa_1 | Entry_e1_melee_r1 | Melee | R1 | NEUTRO | 0 |
| etapa_1 | Entry_e1_archer_r1 | Archer | R1 | NEUTRO | 0 |
| etapa_2 | Entry_e2_melee_r1 | Melee | R1 | NEUTRO | 0 |
| etapa_2 | Entry_e2_tank_r2 | Tank | R2 | TIERRA | 3 |
| etapa_2 | Entry_e2_melee_r3 | Melee | R3 | TIERRA | 3 |
| etapa_3 | Entry_e3_melee_r1 | Melee | R1 | NEUTRO | 0 |
| etapa_3 | Entry_e3_tank_r2 | Tank | R2 | TIERRA | 3 |
| etapa_3 | Entry_e3_archer_r2 | Archer | R2 | TIERRA | 3 |
| etapa_3 | Entry_e3_mage_r3 | Mage | R3 | AGUA | 2 |
| etapa_4 | Entry_e4n_melee_r1 | Melee | R1 | NEUTRO | 0 |
| etapa_4 | Entry_e4n_tank_r2 | Tank | R2 | TIERRA | 3 |
| etapa_4 | Entry_e4n_archer_r2 | Archer | R2 | TIERRA | 3 |
| etapa_4 | Entry_e4n_mage_r3 | Mage | R3 | AGUA | 2 |
| etapa_5 | Entry_e5_melee_r1 | Melee | R1 | NEUTRO | 0 |
| etapa_5 | Entry_e5_tank_r2 | Tank | R2 | TIERRA | 3 |
| etapa_5 | Entry_e5_mage_r3 | Mage | R3 | AGUA | 2 |
| etapa_5 | Entry_e5_archer_r3 | Archer | R3 | TIERRA | 3 |
| etapa_boss | Entry_e4_boss | Tank (Guardián) | R4 | TIERRA | 3 |

---

## Pendientes (TODOs)

- ~~**Asignar elementos a items existentes:**~~ Resuelto 2026-05-26 — ver tabla de armas arriba.
- ~~**Asignar elementos a EnemySpawnEntry zona 1:**~~ Resuelto 2026-05-26 — ver tabla de enemies arriba.
- **Armadura elemental del player:** `hurtbox.element` del player es NEUTRO hardcodeado. Si se implementa, leer de la armadura equipada en `PlayerStatsComponent.recalculate()`.
- **Audit de balance:** con modifier ×1.5 el TTK baja ~33% en matchups de ventaja. Consultar `balance-engineer` antes de asignar elementos en zona 2+.
- **Visual de elemento del enemy:** aura de color elemental (naranja=Fuego, azul=Agua, verde=Tierra). Actualmente no hay indicador visual del elemento del enemy al jugador. Futuro task UX.

---

## Decisiones técnicas

1. **`element_modifier` en `GameConfig`** (no autoload nuevo): una función estática, overhead cero, sin dependencia de instancia.
2. **Cálculo en el atacante** (`HitboxComponent`/`Projectile`), no en el receptor (`Hurtbox`). El atacante tiene el elemento del defensor disponible desde `hurtbox.element`. Esto mantiene el flujo unidireccional: el hitbox calcula → llama `receive_hit(final_damage)`.
3. **`was_advantage` en la señal `hit_received`**: el hurtbox no sabe cómo mostrar UI — propaga el int al owner para que decida. Neutro hacia el receptor, legible en los callbacks.
4. **`hurtbox.element` como `@export`**: permite setear desde el editor en .tscn de enemies específicos (sin depender del spawner). Útil para bosses o encounters manuales.
5. **Player hurtbox = NEUTRO**: el player no tiene "tipo" propio en MVP. Los enemies no tienen ventaja elemental sobre él por ahora. Extensible sin breaking change: basta con que `PlayerStatsComponent.recalculate()` escriba `hurtbox.element`.
