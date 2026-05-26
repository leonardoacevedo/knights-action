extends Control
class_name XpToastContainer

## Gestiona el stack de toasts de XP ganada.
## Escucha PlayerProgression.xp_gained y decide si crear toast nuevo
## o sumar al existente (stacking en ventana de STACK_WINDOW_SEC).
##
## Posición: superior izquierda del HUD (distinto al MaterialToastContainer
## que está arriba-derecha — separación visual intencional).
## Hasta MAX_VISIBLE toasts simultáneos.

# ─── Config ──────────────────────────────────────────────────────────────────

## Ventana de stacking: si llega más XP en este tiempo, acumula en el toast activo.
@export var stack_window_sec: float = 1.0
@export var max_visible: int = 3
@export var slot_separation: int = 6

# ─── Escena del toast individual ─────────────────────────────────────────────

const TOAST_SCENE := preload("res://scenes/ui/xp_toast.tscn")

# ─── Estado ──────────────────────────────────────────────────────────────────

## Clave constante "xp" → {toast: XpToast, timestamp: float}.
## Solo hay una "línea" de XP (a diferencia del material que stackea por id).
const STACK_KEY := &"xp"

var _active: Dictionary = {}
var _queue: Array[XpToast] = []
var _vbox: VBoxContainer


# ─── Setup ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", slot_separation)
	# Anclar arriba-izquierda dentro del container.
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(_vbox)

	PlayerProgression.xp_gained.connect(_on_xp_gained)


# ─── Handler ─────────────────────────────────────────────────────────────────

func _on_xp_gained(amount: int, _total_xp: int) -> void:
	if amount <= 0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0

	# ¿Hay toast activo dentro de la ventana de stacking?
	if _active.has(STACK_KEY):
		var entry: Dictionary = _active[STACK_KEY]
		var elapsed: float = now - entry.get("timestamp", 0.0)
		if elapsed <= stack_window_sec:
			var existing: XpToast = entry.get("toast")
			if is_instance_valid(existing):
				existing.add_amount(amount)
				entry["timestamp"] = now
				return

	_spawn_toast(amount, now)


# ─── Privados ────────────────────────────────────────────────────────────────

func _spawn_toast(amount: int, timestamp: float) -> void:
	if _queue.size() >= max_visible:
		_evict_oldest()

	var toast: XpToast = TOAST_SCENE.instantiate()
	_vbox.add_child(toast)
	toast.setup(amount)
	toast.toast_finished.connect(_on_toast_finished)

	_queue.append(toast)
	_active[STACK_KEY] = {"toast": toast, "timestamp": timestamp}


func _evict_oldest() -> void:
	if _queue.is_empty():
		return
	var oldest: XpToast = _queue[0]
	if is_instance_valid(oldest):
		oldest.modulate.a = 0.0
		oldest.queue_free()
		_queue.pop_front()
		_active.erase(STACK_KEY)
	else:
		_queue.pop_front()


func _on_toast_finished(_toast: XpToast) -> void:
	_active.erase(STACK_KEY)
	# Limpiar referencias inválidas de la cola.
	for i: int in range(_queue.size() - 1, -1, -1):
		if not is_instance_valid(_queue[i]):
			_queue.remove_at(i)
