# Convenciones de GDScript

Estilo unificado para todo el código del proyecto. Cuando dudés, mirá [`scripts/components/health_component.gd`](../../scripts/components/health_component.gd) — es el patrón canon hasta ahora.

## Naming

| Elemento | Convención | Ejemplo |
| :--- | :--- | :--- |
| Archivo `.gd` | `snake_case` | `health_component.gd` |
| Archivo `.tscn` | `snake_case` | `enemy_dummy.tscn` |
| Archivo `.tres` | `snake_case` | `axe_of_valley.tres` |
| `class_name` | `PascalCase` | `HealthComponent` |
| Función | `snake_case` | `take_damage(amount)` |
| Función privada | `_snake_case` (prefijo) | `_apply_damage_internal()` |
| Variable | `snake_case` | `current_health` |
| Variable privada | `_snake_case` | `_internal_buffer` |
| Constante | `SCREAMING_SNAKE_CASE` | `MAX_HEALTH` |
| Enum | `PascalCase` (tipo), `SCREAMING_SNAKE_CASE` (valores) | `enum Rarity { COMMON, RARE }` |
| Señal | verbo en pasado o evento puntual | `died`, `health_changed(new, max)` |
| Autoload | `PascalCase` | `MomentumSystem`, `InventorySystem` |

## Tipado fuerte (obligatorio)

```gdscript
# ✅ BIEN
@export var max_health: int = 100
var _state: StringName = &"idle"

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)

func get_position_clamped() -> Vector2:
    return position.clamp(Vector2.ZERO, get_viewport_rect().size)

# ❌ MAL — sin tipos
var max_health = 100

func take_damage(amount):
    current_health -= amount
```

**Reglas:**
- Argumentos: siempre tipados.
- Retornos: siempre tipados (incluido `-> void`).
- `@export`: siempre tipados.
- Variables locales: tipadas si el tipo no es obvio del literal.

## Anatomía de un script estándar

```gdscript
extends Node
class_name HealthComponent

# 1. Señales primero
signal died
signal health_changed(new_health: int, max_health: int)

# 2. Enums y constantes
const REGEN_TICK_SECONDS := 1.0

# 3. @export (en orden lógico de configuración del Inspector)
@export var max_health: int = 100
@export var regen_per_second: int = 0

# 4. Variables públicas
var current_health: int

# 5. Variables privadas
var _regen_accumulator: float = 0.0

# 6. @onready (referencias resueltas al entrar al árbol)
@onready var _timer: Timer = $Timer

# 7. Lifecycle methods
func _ready() -> void:
    current_health = max_health

func _process(delta: float) -> void:
    if regen_per_second > 0:
        _tick_regen(delta)

# 8. API pública
func take_damage(amount: int) -> void:
    if amount <= 0:
        return
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health == 0:
        died.emit()

func heal(amount: int) -> void:
    if amount <= 0:
        return
    current_health = min(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)

# 9. Funciones privadas
func _tick_regen(delta: float) -> void:
    _regen_accumulator += delta
    if _regen_accumulator >= REGEN_TICK_SECONDS:
        _regen_accumulator -= REGEN_TICK_SECONDS
        heal(regen_per_second)
```

## Indentación y formato

- **Tabs** (no espacios). Tab width 4 visual.
- Línea máxima sugerida: **100 caracteres** (no es regla dura, pero evitá líneas que crucen pantalla).
- 1 línea en blanco entre funciones.
- 2 líneas en blanco entre secciones lógicas grandes (lifecycle / API pública / privadas).

## Comentarios

- **Defecto: NO escribir comentarios.** Nombres bien elegidos > comentarios.
- **Sí escribir** cuando el "porqué" no es obvio:
  - Workaround de bug puntual de Godot 4.6.
  - Decisión de diseño no obvia (`Furia no regenera pasivamente. Refuerza agresividad. GDD §4.3`).
  - Invariante a respetar al editar.
- **Idioma:** español (matchea al GDD y comentarios existentes de Leo).
- **Estilo: caveman lite** (ver [`estilo-caveman.md`](estilo-caveman.md)). Sin filler, sin pleasantries, gramática completa, términos técnicos exactos.
- **Nunca** repitas el `what` del código:
  ```gdscript
  # ❌ MAL — explica el código (innecesario) y largo
  # Incrementa el valor de current_health en la cantidad amount
  func heal(amount: int) -> void:
      current_health += amount

  # ✅ BIEN — no hace falta comentario, el nombre lo dice
  func heal(amount: int) -> void:
      current_health = min(max_health, current_health + amount)
  ```
- **Estilo caveman lite en comentarios — antes vs después:**
  ```gdscript
  # ❌ Verboso (filler innecesario)
  # Aquí lo que estamos haciendo es resetear el contador de momentum
  # cada vez que el jugador recibe daño físico, porque eso es lo que
  # dice el GDD en la sección §4.3.

  # ✅ Caveman lite (preciso, sin filler)
  # Reset Momentum por daño físico. GDD §4.3.
  ```

## Señales

### Declaración
```gdscript
signal died
signal health_changed(new_health: int, max_health: int)
signal pattern_started(pattern_name: StringName, windup_seconds: float)
```

### Emisión
```gdscript
died.emit()
health_changed.emit(current_health, max_health)
```

### Conexión
```gdscript
# En _ready() del padre o gestor.
health_component.died.connect(_on_died)
health_component.health_changed.connect(_on_health_changed)
```

**No** uses `connect` con strings antiguo de Godot 3. Siempre callable.

## StringName vs String

Usá `StringName` (`&"foo"`) para:
- IDs de estados de state machines.
- Claves de diccionarios fijos.
- Identificadores de cualquier cosa que se compare muchas veces.

`String` para texto que vea el usuario o que se construya dinámicamente.

## await

Usá `await` con cuidado en `_physics_process` — pausa el callback. Para timing dentro de combate, preferí:
- Timers de nodo configurables.
- `AnimationPlayer.animation_finished` signal.
- Estados explícitos en state machine.

`await get_tree().create_timer(...)` es OK para acciones puntuales (cooldowns, retardo de hitbox), pero documentá por qué.

## Carga de Resources

```gdscript
# ✅ Preload para recursos conocidos en compile time
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const AXE_DATA := preload("res://resources/items/weapons/axe_basic.tres")

# ✅ Load dinámico solo cuando no se conoce de antemano
var item: ItemData = load("res://resources/items/weapons/%s.tres" % item_id)
```

## Manejo de errores

```gdscript
# Para invariantes que NUNCA deberían fallar:
assert(target_level >= 1 and target_level <= 10, "Refinement target out of range")

# Para validación de input externo (UI / red):
if amount < 0:
    push_error("Damage amount cannot be negative: %d" % amount)
    return
```

No abuses de `try/catch` (GDScript no lo tiene nativo). Diseñá funciones que fallen ruidosamente en debug y silenciosamente en release usando `push_error` / `assert`.

## Tests

```gdscript
# tests/upgrade_manager_test.gd
extends Node

func _ready() -> void:
    _test_success_table()
    _test_downgrade_on_fail()
    print("All tests passed.")

func _test_success_table() -> void:
    assert(UpgradeManager.SUCCESS_TABLE[1] == 1.0)
    assert(UpgradeManager.SUCCESS_TABLE[10] == 0.1)

func _test_downgrade_on_fail() -> void:
    var item: ItemData = ItemData.new()
    item.refinement_level = 8
    # Forzar fallo, etc.
```

Si Leo aprueba [GUT](https://github.com/bitwes/Gut), migrar — más limpio.

## Anti-patrones

- ❌ Usar `get_node("../..")` para subir el árbol. Romperá al renombrar.
- ❌ Mezclar `_process` con `_physics_process` sin razón.
- ❌ `if x == true:` → escribí `if x:`.
- ❌ `else: pass` → eliminá el `else`.
- ❌ Cadenas largas de `if/elif` en lugar de `match`.
- ❌ Hardcodear paths absolutos en strings.
- ❌ Variables globales sin autoload.

## `.editorconfig` del proyecto

El proyecto tiene un `.editorconfig`. Respetalo. Si encontrás un conflicto entre este doc y `.editorconfig`, **gana `.editorconfig`** — flagueá la inconsistencia para arreglarla.
