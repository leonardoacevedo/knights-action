# Notas — Bugfixes sesión 27/05 no testeables headless

> Estos fixes requieren escena/combate corriendo (player + enemies + cámara + proyectiles
> en `world.tscn`). El harness de tests es unitario (`extends SceneTree`, sin instanciar
> entidades que hereden de `Enemy`/`CharacterBody2D` ni `@onready $Nodo`). Validación
> in-game manual. Referencias al **Checklist de Testeo In-Game 27/05**
> (`docs/handoffs/2026-05-27-checklist-testeo-ingame.md`).

## Cubiertos por tests nuevos (headless)

| Fix | Test | Qué valida |
|-----|------|------------|
| C7  | `craft_cota_glacial_recipe_test.gd`        | `craft_cota_cuero_glacial.tres` → output `cota_glacial` |
| A6  | `crafting_rollback_test.gd`                | inputs duplicados + stock insuficiente → no agrega item, materiales/oro intactos |
| A7  | `inventory_material_overflow_test.gd`      | `add_material` respeta `max_stack`, devuelve cantidad real |
| A4  | `inventory_unequipped_signal_test.gd`      | `equip` emite `unequipped(slot, prev_item)` al reemplazar |
| A9  | `inventory_deserialize_fallback_test.gd`   | `_deserialize_item` resuelve por `base_id` si `base_path` falla |
| A3  | `dash_invuln_preserve_test.gd`             | dash preserva invuln previo, no fuerza false |

## NO testeables headless — validación in-game manual

### C1 — CameraShake call-sites
- **Dónde:** `scripts/systems/camera_shake.gd` (`shake(magnitude, duration)`) + call-sites en
  `player.gd`, `enemy.gd`, `boss_*.gd`, `game_over_screen.gd`.
- **Por qué no headless:** `CameraShake` es autoload que opera sobre una `Camera2D` viva del
  árbol; el efecto es visual y depende de `_process` + nodo cámara en escena. No hay estado
  asertable de forma determinística sin escena.
- **Validar in-game:** checklist item **3** (dash/slam/boss patterns disparan shake) e item
  **7** (Boss Ignis F2 trigger "+shake"). Confirmar que cada call-site invoca con la firma
  correcta y la cámara tiembla (sin errores de argumentos).

### C2 — Boss state_timer
- **Dónde:** `boss_heraldo.gd` (y hermanos) — `_state_timer += delta` en la state machine de fases.
- **Por qué no headless:** la transición depende de `_physics_process`/`_process` acumulando
  `delta` mientras el boss está vivo en escena, más windups por estado (ORBE/CAMPO/ONDA). El
  boss hereda de `Enemy` (requiere árbol + autoloads); el harness no lo instancia (ver
  `boss_phases_test.gd`, que valida solo la lógica pura de threshold de fase).
- **Validar in-game:** checklist items **7/8/9** (cada boss ejecuta sus patrones con timing
  correcto y cruza a F2 en HP ≤ 50%).

### C3 — Player ranged
- **Dónde:** `player.gd` — `_is_ranged_attack`, `_projectile_fired_this_attack`,
  `PLAYER_ARROW_SCENE`/`PLAYER_FIREBALL_SCENE` (`preload(.tscn)`).
- **Por qué no headless:** spawnea proyectiles (escenas `.tscn`) en el árbol y depende del
  tipo de arma equipada + animación de ataque + `_physics_process`. Requiere player vivo en
  `world.tscn`.
- **Validar in-game:** checklist item **3** (ataque arco + vara visualmente correctos, no
  activa hitbox melee) e item **10** (Bola Fuego spawnea fireball).

### C5 — Lyss Muralla Estática refleja
- **Dónde:** `boss_lyss.gd` — `_check_muralla_reflect()`, `_muralla_reflected_set`,
  `_spawn_muralla_aura()`.
- **Por qué no headless:** requiere proyectil del player entrando al área de la Muralla durante
  el estado F2, detección por overlap de `Area2D` y `Projectile.reflect()`. Física de colisión
  + boss vivo en escena. No instanciable en el harness.
- **Validar in-game:** checklist item **8** ("Muralla Estática F2 — disparar fireball → ver
  proyectil con tinte dorado regresar hacia player").

### C6 — Enemy R2 hitbox
- **Dónde:** `enemy.gd` — `@onready var hitbox: HitboxComponent = $Hitbox`, estados
  `R2_SKILL_TELEGRAPH`/`R2_SKILL_ATTACK`.
- **Por qué no headless:** el hitbox es un nodo hijo (`$Hitbox`) que solo existe instanciando
  la escena del enemy; activar/desactivar el hitbox ocurre dentro de la state machine en
  `_physics_process`. Requiere enemy vivo en escena.
- **Validar in-game:** checklist items **14** (variantes R2 por zona: Corte Giratorio, Tajo
  Doble, Gancho Ascendente, etc. con hitbox correcto) y **24** (Gancho rompe 2 cargas escudo).

## Cómo correr los tests nuevos

```bash
godot --headless --script res://tests/systems/craft_cota_glacial_recipe_test.gd
godot --headless --script res://tests/systems/crafting_rollback_test.gd
godot --headless --script res://tests/systems/inventory_material_overflow_test.gd
godot --headless --script res://tests/systems/inventory_unequipped_signal_test.gd
godot --headless --script res://tests/systems/inventory_deserialize_fallback_test.gd
godot --headless --script res://tests/systems/dash_invuln_preserve_test.gd
```

Cada uno debe imprimir `All passed.` al final.

> ⚠️ **Estos tests NO fueron ejecutados** (no hay binario Godot en este entorno). Leo los corre.
