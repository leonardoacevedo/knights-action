# Stick Figure Prototype — Mundo + Player + Enemy

**Fecha de implementación:** 2026-05-21
**Implementado por:** Claude Code (sesión con Leo)
**Fase del proyecto:** Fase 1 — Prototipo de Combate
**Sección GDD relevante:** §4 (Combate), §7.3 (IA por rareza R1), §12.4 (Animación)
**Pilar(es) reforzado(s):** #2 (cada muerte enseña algo — telegrafía visible)

---

## Qué hace

Reemplaza el código placeholder original (cuadrados estáticos) por un setup arquitectónico completo con figuras humanas dibujadas proceduralmente. Sirve como base sólida para implementar Momentum, Bloqueo y el resto del backlog de Fase 1.

- **Mundo:** suelo + 3 plataformas + 2 paredes laterales + Camera2D que sigue al player.
- **Player:** stick figure azul controlable (mover, saltar, dash, atacar). Furia con decay.
- **Enemy R1:** stick figure rojo con state machine simple. Detecta player, persigue, telegrafía 0.7s (parpadeo), ataca, recovery.

---

## Por qué (pilares)

- **Pilar #2 (telegrafía clara):** el enemy R1 implementa la regla canónica del §7.3 GDD — telegrafía visible ≥0.6s antes de cada ataque. El parpadeo rojo lo hace obvio.
- **Pilar #4 (5 min bastan):** un sparring 1v1 contra el R1 está listo para jugar en cualquier momento, ideal para iteración rápida del feel.

---

## Cómo se integra

### Capas (siguiendo arquitectura.md)

```
World.tscn
 ├─ Floor / Platforms / Walls (StaticBody2D, layer 1)
 ├─ Background (ColorRect)
 ├─ Player (CharacterBody2D, layer 2)
 │   ├─ StickFigure (Node2D con _draw())
 │   ├─ HealthComponent
 │   ├─ FuriaComponent
 │   ├─ DashComponent
 │   ├─ Hitbox (Area2D, layer 4)
 │   ├─ Hurtbox (Area2D, layer 5)
 │   └─ Camera2D (sigue al player)
 └─ Enemy (CharacterBody2D, layer 3)
     ├─ StickFigure
     ├─ HealthComponent
     ├─ Hitbox / Hurtbox
     └─ (lógica SM inline en enemy.gd)
```

### Sistema de teams (anti friendly-fire)

- `HitboxComponent.team` y `HurtboxComponent.team` son `int`. Player team=1, Enemy team=2.
- `HitboxComponent._on_area_entered()` valida `hurtbox.team != team` antes de aplicar daño.
- Resultado: hitboxes del player solo dañan hurtboxes del enemy y viceversa, sin tocar layers físicas adicionales.

### Capas físicas finales

| Layer | Uso | Quién la usa |
| :---: | :--- | :--- |
| 1 | World (suelo, plataformas, paredes) | StaticBody2D |
| 2 | Player Body | Player CharacterBody2D |
| 3 | Enemy Body | Enemy CharacterBody2D |
| 4 | Hitbox (aplica daño) | Area2D HitboxComponent |
| 5 | Hurtbox (recibe daño) | Area2D HurtboxComponent |

Hitbox: `layer=4, mask=5`. Hurtbox: `layer=5, mask=4`. Cross detection sin colisión física.

### Componentes nuevos

| Componente | Responsabilidad |
| :--- | :--- |
| `HealthComponent` | HP, señales `died`/`damaged`/`healed`/`health_changed`, `is_alive()`, `get_health_percent()` |
| `HitboxComponent` (Area2D) | Aplica daño al entrar a Hurtbox de team distinto. `set_active(bool)` toggleable |
| `HurtboxComponent` (Area2D) | Recibe daño y lo delega al HealthComponent referenciado. Soporta `invulnerable` |
| `DashComponent` | Dash 100ms + i-frames + cooldown 0.8s. Setea `hurtbox.invulnerable=true` durante dash |
| `FuriaComponent` | +10/hit (vía `add_on_hit()`), decay -5/s tras 5s sin atacar (GDD §4.3) |

### Stick figure procedural

`scripts/rendering/stick_figure.gd` extiende `Node2D` con `_draw()`. Origen en los pies, dibuja en Y negativo. Estados: IDLE (bob suave), WALK (cycle de piernas+brazos), JUMP, ATTACK (swing del brazo frontal), HURT (flash blanco→rojo), DEAD (gris transparente).

Configurable: `body_color`, `line_width`, dimensiones de cabeza/torso/brazos/piernas. Reemplazable luego por sprites IA (Fase 3) sin tocar player.gd/enemy.gd.

### State machine del Enemy

Inline en `enemy.gd` (mob R1 simple no amerita SM modular todavía):

```
IDLE ─[player en rango DETECT]─▶ CHASE
CHASE ─[dist < ATTACK_RANGE]──▶ TELEGRAPH (0.7s parpadeo)
TELEGRAPH ─[timer]────────────▶ ATTACK (hitbox activo 0.05-0.15s)
ATTACK ─[timer]───────────────▶ RECOVERY (0.6s)
RECOVERY ─[timer]─────────────▶ IDLE
```

Sin bloqueo (R1 según GDD §7.3). Sin dash. Detection range = 250px. Attack range = 60px.

---

## Decisiones técnicas no obvias

1. **Stick figure por `_draw()` en vez de Skeleton2D:** más rápido para prototipo, animaciones por fórmula matemática (sin tener que setear poses). Cuando lleguen sprites IA en Fase 3, se reemplaza solo el StickFigure sin tocar lógica de combate.

2. **Hitbox.position.x se invierte según `current_facing`:** truco económico — el `Hitbox` del player tiene `position=(25,-25)` por default (mirando derecha). Cuando facing=-1, se invierte a `position=(-25,-25)`. Mismo nodo, sin duplicar.

3. **HitboxComponent usa `monitoring` toggle + disabled de shapes:** defensa en profundidad. `monitoring=false` evita que se procese cualquier `area_entered`, y `shape.disabled=true` libera la colisión también.

4. **FuriaComponent guarda `current_furia` como `float`:** permite decay suave (-5/s con delta variable). Se reporta como `int` vía señal para UI.

5. **Enemy resuelve `_target` desde `target_path` exportado en `_ready()`:** evita acoplamiento a un singleton; el `world.tscn` apunta al Player vía NodePath. Si más adelante hay multiplayer o respawn, se actualiza el path sin tocar el script.

6. **Camera2D dentro del Player con `position_smoothing_enabled`:** sigue automáticamente. `limit_left/right` previene mostrar fuera del mundo. Ajustar si el mundo se agranda.

---

## Cómo testear manualmente

1. Abrir Godot 4.6 y abrir el proyecto.
2. Verificar que `scenes/world.tscn` es la escena principal (ya está en `project.godot`).
3. Run (F5). Debería ver:
   - Player azul a la izquierda, enemy rojo a la derecha.
   - Suelo + 3 plataformas + paredes.
   - Camera siguiendo al player con smoothing.
4. **Controles:**
   - Flechas izq/der: mover.
   - Espacio (ui_accept): saltar.
   - F: atacar.
   - Space (dash key): dash.
5. **Esperar comportamientos:**
   - Acercarse al enemy → entra en CHASE (camina hacia ti).
   - Dentro de ~60px → telegrafía rojo 0.7s → ataque (si no esquivás, te pega).
   - Atacarle 4 veces (10 daño × 4 = 40 HP del enemy) → muere.
   - Dash atravesando el ataque del enemy → no recibís daño (i-frames).
   - Furia sube +10 por golpe conectado. Esperá 5s sin atacar y verás que baja (no hay UI todavía, pero se nota en lógica).

---

## Tests unitarios

⚠ **Pendientes.** Recomendado escribir cuando lleguemos al test runner (GUT o equivalente).

Candidatos para primer test:
- `HealthComponent.take_damage(N)` con N positivo, negativo, mayor a max_health.
- `DashComponent.try_dash()` mientras dasheando devuelve `false`.
- `FuriaComponent.add_on_hit()` resetea timer de decay.
- `HitboxComponent` no daña a Hurtbox del mismo team.

---

## Assets necesarios (futuro)

- Sprites IA reemplazando StickFigure (Fase 3).
- SFX placeholder de impacto, salto, dash (Fase 1 backlog).

---

## Archivos tocados

### Creados (10)
- `scripts/components/health_component.gd` (rehecho desde cero, mejorado)
- `scripts/components/hitbox_component.gd`
- `scripts/components/hurtbox_component.gd`
- `scripts/components/dash_component.gd`
- `scripts/components/furia_component.gd`
- `scripts/rendering/stick_figure.gd`
- `scripts/entities/player.gd`
- `scripts/entities/enemy.gd`
- `scenes/entities/player.tscn`
- `scenes/entities/enemy.tscn`
- `scenes/world.tscn` (rehecho)

### Borrados (8)
- `scripts/player.gd` + `.uid`
- `scripts/components/health_component.gd` (versión vieja) + `.uid`
- `scenes/enemy_dummy.gd` + `.uid`
- `scenes/enemies/enemy_dummy.tscn`
- `scenes/player/player.tscn` (vacío)
- `scenes/world.tscn` (versión vieja)

---

## Pendientes / mejoras futuras

- **Sistema de Momentum** (autoload) — siguiente feature en backlog Fase 1. `Player._on_hit_landed()` ya tiene comentario indicando dónde se enchufa.
- **BlockComponent** + cargas de escudo (GDD §4.3).
- **Feedback de impacto:** hitstop 30-80ms, screenshake, partículas básicas, SFX.
- **HUD básico:** barras de HP y Furia visibles.
- **Telegrafía mejorada:** además del parpadeo, marcador en el suelo o indicador de dirección del ataque.
- **Multiple enemies:** el `Enemy` ya soporta `target_path`, solo hace falta agregar más instancias al `world.tscn`.
- **Tests unitarios** cuando se elija runner.
