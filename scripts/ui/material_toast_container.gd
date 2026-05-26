extends Control
class_name MaterialToastContainer

## Gestiona el stack de toasts de material recogido.
## Escucha InventorySystem.material_added y decide si crear un toast nuevo
## o sumar al existente (si el mismo id llegó en los últimos STACK_WINDOW_SEC).
##
## Posición: superior derecha del HUD, debajo del área de Momentum.
## Hasta MAX_VISIBLE toasts simultáneos; si llega uno más, el más viejo sale.

# ─── Config ──────────────────────────────────────────────────────────────────

## Ventana de tiempo (segundos) en la que un segundo drop del mismo id
## se acumula en el toast existente en vez de crear uno nuevo.
@export var stack_window_sec: float = 0.6
## Cantidad máxima de toasts visibles a la vez.
@export var max_visible: int = 4
## Separación vertical entre toasts (px).
@export var slot_separation: int = 8

# ─── Escena del toast individual ─────────────────────────────────────────────

const TOAST_SCENE := preload("res://scenes/ui/material_toast.tscn")

# ─── Estado ──────────────────────────────────────────────────────────────────

## id material → {toast: MaterialToast, timestamp: float}
## Sólo contiene toasts que todavía están vivos y dentro de la ventana de stacking.
var _active: Dictionary = {}

## Cola FIFO de toasts vivos (para el límite MAX_VISIBLE).
var _queue: Array[MaterialToast] = []

## VBoxContainer hijo que organiza verticalmente los toasts.
var _vbox: VBoxContainer


# ─── Setup ───────────────────────────────────────────────────────────────────

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# VBox interno para apilar toasts.
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", slot_separation)
	# Anclar arriba-derecha dentro del container.
	_vbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	add_child(_vbox)

	# Conectar al signal de inventario.
	InventorySystem.material_added.connect(_on_material_added)


# ─── Handler del signal ───────────────────────────────────────────────────────

func _on_material_added(material: MaterialData, count: int) -> void:
	var id: StringName = material.id
	var now: float = Time.get_ticks_msec() / 1000.0

	# ¿Hay un toast activo para este id dentro de la ventana de stacking?
	if _active.has(id):
		var entry: Dictionary = _active[id]
		var elapsed: float = now - entry.get("timestamp", 0.0)
		if elapsed <= stack_window_sec:
			var existing: MaterialToast = entry.get("toast")
			if is_instance_valid(existing):
				existing.add_count(count)
				entry["timestamp"] = now  # resetea la ventana
				return

	# No había toast activo → crear uno nuevo.
	_spawn_toast(material, count, now)


# ─── Privados ────────────────────────────────────────────────────────────────

func _spawn_toast(material: MaterialData, count: int, timestamp: float) -> void:
	# Si llegamos al límite visible, sacamos el más viejo.
	if _queue.size() >= max_visible:
		_evict_oldest()

	var toast: MaterialToast = TOAST_SCENE.instantiate()
	_vbox.add_child(toast)
	toast.setup(material, count)
	toast.toast_finished.connect(_on_toast_finished.bind(material.id))

	_queue.append(toast)
	_active[material.id] = {"toast": toast, "timestamp": timestamp}


func _evict_oldest() -> void:
	# Fuerza el fadeout del toast más viejo de la cola.
	if _queue.is_empty():
		return
	var oldest: MaterialToast = _queue[0]
	if is_instance_valid(oldest):
		# Llamar _start_fadeout vía método privado no es posible desde afuera;
		# en vez de eso lo liberamos directamente — ya emite toast_finished.
		oldest.modulate.a = 0.0
		oldest.queue_free()
		# _on_toast_finished se conectó con el id pero la señal no se emitirá
		# porque queue_free() cancela pending signals. Limpiamos a mano.
		_queue.pop_front()
		# Limpiamos _active si apuntaba a ese nodo.
		for id: StringName in _active.keys():
			var entry: Dictionary = _active[id]
			if entry.get("toast") == oldest:
				_active.erase(id)
				break


func _on_toast_finished(id: StringName) -> void:
	# El toast terminó su ciclo; limpiar referencias.
	_active.erase(id)
	# Eliminar de la cola (puede que ya se haya ido por evict).
	for i: int in range(_queue.size() - 1, -1, -1):
		if not is_instance_valid(_queue[i]):
			_queue.remove_at(i)
