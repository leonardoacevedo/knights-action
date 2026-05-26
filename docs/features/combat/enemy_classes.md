# Clases de Enemy

**Fase del proyecto:** 1 — Prototipo de Combate.
**Sección del GDD:** §7.3 (R1 enemies: telegrafía ≥0.7s, sin bloqueo).
**Estado:** Implementado (Melee/Tank/Archer/Mage + sistema de proyectiles).

---

## Las 4 clases

Stats base leídos de `GameConfig` autoload (el "archivo .env" del proyecto).

| Clase | HP | Daño | Velocidad | Rango ataque | Telegrafía | Cuerpo |
| :--- | --: | --: | --: | --: | --: | :--- |
| **Melee** | 100 | 10 | 400 | 60 px | 0.7 s | cuerpo a cuerpo |
| **Tank** | 200 | 5 | 260 | 70 px | 1.0 s | cuerpo a cuerpo |
| **Archer** | 80 | 15 | 400 | 380 px | 0.7 s | proyectil flecha |
| **Mage** | 60 | 18 | 360 | 420 px | 0.7 s | proyectil fireball |

Fórmula:
- `health = ENEMY_BASE_HEALTH * HEALTH_MULT[class]`
- `damage = ENEMY_BASE_DAMAGE * DAMAGE_MULT[class]`
- `speed = ENEMY_BASE_SPEED * SPEED_MULT[class]`
- `range = PREFERRED_RANGE[class]`

Editar `scripts/systems/game_config.gd` para tunear.

---

## Comportamiento

### Melee / Tank (cuerpo a cuerpo)

Igual al enemy básico R1 original:
1. IDLE → detecta target → CHASE.
2. CHASE → persigue + multi-hop entre plataformas (fix v1+v2 validado).
3. Si `dist < attack_range (60-70)` + altura similar → TELEGRAPH.
4. TELEGRAPH (0.7 o 1.0 s) → flash rojo.
5. ATTACK → activa hitbox cuerpo a cuerpo en ventana 0.05-0.15 s.
6. RECOVERY (0.6 s) → IDLE.

**Diferencia Tank vs Melee:** Tank más lento (260 px/s vs 400) + telegrafía 1.0 s en lugar de 0.7. Compensación: tiene el doble de HP (200) y mitad de daño (5).

### Archer / Mage (a distancia)

1. CHASE → se acerca hasta `dist < attack_range (380-420)`.
2. Si en rango: TELEGRAPH (sin requerir altura similar — puede atacar diagonal).
3. ATTACK → instancia 1 proyectil en `_state_timer >= ATTACK_ACTIVE_START` con flag `_projectile_fired_this_attack` para garantizar 1 disparo por ATTACK.
4. Proyectil viaja en línea recta. Lifetime 2.0-2.5 s.
5. Choque con HurtboxComponent del player (team distinto) → aplica daño + queue_free.

**Diferencia Archer vs Mage:** Archer dispara flechas (700 px/s, daño 15). Mage dispara fireballs más lentas (450 px/s) pero hacen más daño (18). Mage también es ligeramente más lento (-10%).

### Notas técnicas del comportamiento

- **Retreat NO implementado.** Si el player se mete dentro del attack_range, Archer/Mage quedan quietos y siguen disparando. Mejorable en futura iteración (state RETREAT).
- **Líneas de tiro NO obstruidas.** El proyectil no chequea raycast antes de disparar — si hay una plataforma entre Archer y player, igual dispara y la flecha choca contra la plat (silently). Aceptable para MVP.
- **Sin friendly fire.** Los proyectiles tienen `team = enemy.team`. Solo dañan a HurtboxComponents con team distinto.

---

## Arquitectura

### `Projectile` ([scripts/projectiles/projectile.gd](../../../scripts/projectiles/projectile.gd))

Area2D autónomo. Layer 4 (Hitbox), Mask 5 (detecta Hurtbox).

```gdscript
proj.launch(direction: Vector2, damage: int, team_id: int)
get_tree().current_scene.add_child(proj)
```

Movimiento lineal `position += direction * speed * delta` en `_physics_process`. Lifetime auto-queue_free.

### Escenas de proyectil

- `scenes/projectiles/projectile_arrow.tscn` — ColorRect alargado marrón + tip plateado. Velocidad 700.
- `scenes/projectiles/projectile_fireball.tscn` — ColorRect circular naranja + halo translúcido. Velocidad 450.

### `Enemy` ([scripts/entities/enemy.gd](../../../scripts/entities/enemy.gd))

Refactorizado para soportar `enemy_class`:
- `@export_enum("Melee:0", "Tank:1", "Archer:2", "Mage:3") var enemy_class: int = 0`
- `@export var projectile_scene: PackedScene` (null para melee/tank, asignado para archer/mage).
- En `_ready()` aplica stats desde GameConfig.
- En `_tick_state` ATTACK: helper `_is_ranged()` decide si dispara proyectil o usa hitbox.

### Escenas variantes (inherited)

`scenes/entities/enemy_melee.tscn`, `enemy_tank.tscn`, `enemy_archer.tscn`, `enemy_mage.tscn`.

Cada una hereda de `enemy.tscn` base y sobre-escribe:
- `enemy_class`.
- `body_color` del StickFigure (visual identification).
- `projectile_scene` (archer/mage).

### Spawner ([scripts/world/world.gd](../../../scripts/world/world.gd))

Weighted random:
- `@export spawn_weight_melee/tank/archer/mage` (default 0.50 / 0.20 / 0.20 / 0.10).
- `@export scene_melee/tank/archer/mage` (PackedScenes, default = las 4 variantes).
- `_pick_random_scene()` normaliza weights y elige.

---

## Cómo agregar una clase nueva (ej. "Berserker")

1. **GameConfig:** agregar `BERSERKER` al enum + entries en HEALTH_MULT/DAMAGE_MULT/SPEED_MULT/PREFERRED_RANGE.
2. **enemy.tscn variante:** crear `enemy_berserker.tscn` heredando de base, setear `enemy_class = 4`, body_color custom, projectile_scene si aplica.
3. **enemy.gd:** si tiene comportamiento especial (ej. rage al perder HP), agregar lógica condicional en `_tick_state`.
4. **world.gd:** agregar `@export var scene_berserker` y `@export var spawn_weight_berserker`. Incluir en `_pick_random_scene()`.
5. **Doc:** agregar fila a la tabla de stats arriba.

---

## Cómo testear manualmente

1. Abrir Godot, correr `world.tscn`.
2. Con `enemy_count = 10`, weights default → esperar ~5 melee + 2 tank + 2 archer + 1 mage.
3. Identificar por color: rojo (melee), marrón (tank), verde (archer), violeta (mage).
4. Acercarse a un Archer → debería retroceder no, quedar quieto a ~380 px y disparar flechas.
5. Acercarse a un Tank → camina más lento, telegraph dura 1 s (notable).
6. Pegar a un Mage → debería morir en 5 hits con espada R1 (60 HP / 12 daño = 5).
7. Pegar a un Tank → 17 hits con espada R1 (200 / 12 = 16.67).

---

## Decisiones técnicas

1. **`Projectile` agregado al `current_scene`** (no como hijo del enemy). Sobrevive si el enemy muere mientras el proyectil viaja.
2. **`receive_hit(amount, source = null)`** — agregado default null en `HurtboxComponent` para que Projectile pueda usarlo sin pasar un HitboxComponent (porque no tiene).
3. **`enemy_class` como `int` con @export_enum** en lugar de `GameConfig.EnemyClass` directo. Razón: el enum de un autoload puede no estar accesible en parse time del @export en algunas builds de Godot 4. Usar enteros con hint es 100% confiable.
4. **NO retreat para ranged.** Si el player se mete dentro del rango, archer/mage NO huyen. Es funcional pero ranged se vuelven menos efectivos. Mejorable en próxima iteración.

---

## Pendiente / próximas mejoras

- Retreat behavior para Archer/Mage cuando el player está demasiado cerca.
- Raycast obstacle-check antes de disparar (evitar "lanzar flecha contra una pared").
- Indicador visual de telegraph en proyectiles antes de spawn (línea fina previa).
- Mage podría tener un secondary attack (ej. AOE) al cargar Furia.
- Variantes de cada clase (ej. Heavy Tank, Frost Mage) con elementos del GDD §10.
