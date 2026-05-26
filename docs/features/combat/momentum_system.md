# Sistema de Momentum

**Fase del proyecto:** 1 — Prototipo de Combate.
**Sección del GDD:** §4.3 (Momentum).
**Estado:** Implementado (lógica core + HUD + feedback visual a 5x). Bloqueo pendiente.

---

## Qué hace

El Momentum es un multiplicador global del combate del player. Recompensa secuencias largas de golpes sin recibir daño.

- **Sube +1 por cada golpe que conecta el player** (cap en 10x).
- **Resetea a 0 cuando el player recibe daño**, salvo que esté congelado por un Bloqueo activo (feature futura).
- **Escala 3 cosas a la vez:**
  - **Daño:** `daño_total = daño_base * (1 + 0.05 * nivel)` → en 10x = ×1.5.
  - **Drops** (cuando exista loot): `drop_rate = base * (1 + 0.1 * nivel)` → en 10x = ×2.
  - **Ganancia de Furia:** `gain = base * (1 + 0.05 * nivel)` → en 10x = ×1.5.
- **Feedback visual a partir de 5x** (umbral configurable): el contador del HUD cambia de color (blanco → naranja → rojo) y aparecen partículas alrededor del player.

---

## Arquitectura

### Autoload `MomentumSystem` ([scripts/systems/momentum_system.gd](../../../scripts/systems/momentum_system.gd))

Es un `Node` singleton registrado en `project.godot` bajo `[autoload]`.

**API pública:**

| Método | Quién lo llama | Qué hace |
| :--- | :--- | :--- |
| `on_hit_landed()` | `Player._on_hit_landed` | +1 al contador, emite `momentum_changed` y eventualmente `threshold_5x_reached`. |
| `on_damage_taken()` | `Player._on_hit_received` | Resetea a 0 (si no está frozen). Emite `momentum_reset` y eventualmente `threshold_5x_lost`. |
| `on_block_absorbed()` | (Pendiente — sistema de Bloqueo) | Congela el Momentum 1s sin resetearlo. |
| `damage_multiplier()` | `Player._start_attack` | Devuelve `1.0 + 0.05 * current_level`. |
| `drop_multiplier()` | (Pendiente — loot system) | `1.0 + 0.1 * current_level`. |
| `furia_multiplier()` | `Player._on_hit_landed` | `1.0 + 0.05 * current_level`. |
| `reset()` | Cambios de escena / tests | Helper que limpia estado. |

**Signals:**
- `momentum_changed(new_level: int)` — emitido en cada cambio (subida, reset, etc.).
- `momentum_reset` — emitido al resetear por daño.
- `threshold_5x_reached` — emitido al cruzar 0..4 → 5+ subiendo.
- `threshold_5x_lost` — emitido al cruzar 5+ → 0 (por reset o caída del umbral).

### Integración en `player.gd`

```gdscript
# _ready():
hitbox.hit_landed.connect(_on_hit_landed)
hurtbox.hit_received.connect(_on_hit_received)
MomentumSystem.threshold_5x_reached.connect(_on_momentum_threshold_reached)
MomentumSystem.threshold_5x_lost.connect(_on_momentum_threshold_lost)
MomentumSystem.momentum_reset.connect(_on_momentum_threshold_lost)

# Al iniciar swing: aplica el multiplicador al hitbox.
func _start_attack():
    hitbox.damage_multiplier = MomentumSystem.damage_multiplier()

# Al conectar golpe: suma Furia escalada y avisa al sistema.
func _on_hit_landed(_target):
    furia.add_on_hit(MomentumSystem.furia_multiplier())
    MomentumSystem.on_hit_landed()

# Al recibir daño: resetea.
func _on_hit_received(_amount, _source):
    MomentumSystem.on_damage_taken()
```

### Modificaciones a componentes

- **`HitboxComponent`:** agregado campo runtime `damage_multiplier: float = 1.0`. El daño final se calcula `int(round(damage * damage_multiplier))` en `_on_area_entered`.
- **`FuriaComponent`:** `add_on_hit()` ahora acepta `multiplier: float = 1.0` (retrocompatible).

### HUD ([scripts/ui/hud_combat.gd](../../../scripts/ui/hud_combat.gd) + [scenes/ui/hud_combat.tscn](../../../scenes/ui/hud_combat.tscn))

`CanvasLayer` instanciado en `world.tscn`. Tres widgets:
- **Top-center:** contador grande "Nx", color según nivel (blanco 0-4 / naranja 5-7 / rojo 8-10).
- **Top-left:** barra HP roja + numérico.
- **Top-left:** barra Furia violeta + numérico.

Recibe `player_path: NodePath` desde Inspector. Conecta a:
- `MomentumSystem.momentum_changed` (sin acoplamiento al player).
- `player.health.health_changed`.
- `player.furia.furia_changed`.

### Partículas a 5x

`GPUParticles2D` agregado a `player.tscn` como hijo del Player. `emitting = false` por default. Toggle por las signals `threshold_5x_reached` / `threshold_5x_lost`. Gradient amarillo→naranja→rojo, spread 180°, 24 partículas, lifetime 0.7s. Subida leve (gravity Y=-30).

---

## Cómo testear manualmente

1. Abrir Godot, correr `world.tscn`.
2. **Subir Momentum:** golpear al enemy con F repetidamente. El contador debe subir 1x → 2x → ... → 10x. El número del HUD debe cambiar y el daño emitido al enemy crecer.
3. **Llegar a 5x:** al cruzar 5x, el color del contador pasa a naranja Y empiezan a aparecer partículas alrededor del player.
4. **Llegar a 8x:** color cambia a rojo.
5. **Resetear:** dejar que el enemy te pegue. Contador vuelve a 1x (display), partículas se apagan, color vuelve a blanco.
6. **Cap 10x:** golpear muchas veces. Debe quedar fijo en 10x, no subir más.

Pendiente para testear el bloqueo: no implementado todavía. El método `on_block_absorbed()` existe pero no se invoca desde ningún lado.

---

## Decisiones técnicas

1. **`MomentumSystem` como autoload global (singleton).** No es un componente del player porque otros sistemas (drops, Furia, Coliseo) lo van a necesitar como referencia única. Tampoco es un Resource porque tiene estado runtime que no queremos persistir.
2. **`damage_multiplier` se aplica en HitboxComponent runtime, no se hardcodea en el daño del .tscn.** Permite que el mismo Hitbox sirva con o sin Momentum (Player con, Enemy sin).
3. **El reset por daño se dispara desde `Hurtbox.hit_received`, no desde `Health.damaged`.** Diferencia importante: si en el futuro hay daño que no resetea Momentum (ej. ambiental, sangrado), basta con que ese damage no pase por la Hurtbox del player.
4. **Furia escala con `furia_multiplier()` igual que daño.** Refuerza el ciclo "agresividad → más recursos → más agresividad". Si tras playtest se siente "snowballing", reducir a 0.025 por nivel.
5. **El HUD se conecta al player por NodePath exportado, no por singleton ni busqueda en árbol.** Más explícito; si cambia la escena el path se ajusta en Inspector sin tocar código.

---

## Qué NO hace (todavía)

- **Bloqueo:** `on_block_absorbed()` existe pero no se invoca. Próxima feature de Fase 1.
- **No afecta drops:** no hay sistema de loot todavía. `drop_multiplier()` está listo para cuando exista.
- **No persiste entre escenas:** el autoload mantiene el contador. Si se quiere resetear al cambiar de mapa, llamar `MomentumSystem.reset()` desde el manager de escenas (no existe aún).
- **No expone debug visual del estado frozen.** Cuando se implemente bloqueo, agregar un overlay si frozen=true.

---

## Próximos pasos sugeridos

1. **Bloqueo** con cargas (GDD §4.3). Al absorber un golpe: invocar `MomentumSystem.on_block_absorbed()` + consumir carga.
2. **Cambio de escena:** llamar `MomentumSystem.reset()` al instanciar una zona nueva o tras muerte.
3. **Tests unitarios:** simular secuencias de `on_hit_landed` + `on_damage_taken` y verificar valores. Stub básico en `tests/systems/`.
4. **Tuning de números** tras playtest: posiblemente bajar el cap a 8x o subir el daño escalado a 0.06 por nivel.

---

## Archivos tocados

**Creados:**
- `scripts/systems/momentum_system.gd`
- `scripts/ui/hud_combat.gd`
- `scenes/ui/hud_combat.tscn`
- `docs/features/combat/momentum_system.md` (este archivo)

**Modificados:**
- `project.godot` — agregada sección `[autoload]` con `MomentumSystem`.
- `scripts/components/hitbox_component.gd` — campo runtime `damage_multiplier`, aplicado en `_on_area_entered`.
- `scripts/components/furia_component.gd` — `add_on_hit(multiplier: float = 1.0)`.
- `scripts/entities/player.gd` — conexiones a hurtbox, signals de Momentum, particles toggle, multiplicador en `_start_attack`.
- `scenes/entities/player.tscn` — nodo `MomentumParticles` (GPUParticles2D) + materiales.
- `scenes/world.tscn` — instancia `HudCombat` como hijo del root.
