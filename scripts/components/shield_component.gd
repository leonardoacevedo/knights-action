extends Node
class_name ShieldComponent

## Cargas de bloqueo del escudo equipado. ESTADO RUNTIME.
##
## Las cargas NO viven en el .tres (recurso compartido) sino acá.
## Se reconfigura cuando InventorySystem.equipped_changed dispara para slot ESCUDO.
##
## GDD §4.3 / §5.2:
## - R1: 0 cargas (no bloquea). R2: 1. R3: 2. R4: 3.
## - Recarga: al completar etapa (PvE). Coliseo sin recarga (post-MVP).
## - Bloquear absorbe el golpe completo y congela Momentum 1s.

signal charges_changed(current: int, maximum: int)
signal block_started
signal block_ended
signal charge_absorbed(remaining: int)

var max_charges: int = 0
var current_charges: int = 0
var is_blocking: bool = false

## Set bonus TIERRA 3pc. Si true, try_absorb() recupera 1 carga tras absorber.
## Seteado por player.gd cuando SetBonusSystem.is_active(TIERRA, 3) es true.
var tierra_3pc_active: bool = false

## Bonus de cargas por skill BLOCK_CHARGES (guerrero_carga_extra).
## Se suma al máximo del escudo equipado en _configure_from_item.
## Seteado por PlayerStatsComponent.recalculate() vía BLOCK_CHARGES.
var skill_charges_bonus: int = 0


func _ready() -> void:
	# Sincronizar con el escudo ya equipado al arrancar (deferred porque
	# InventorySystem y player_stats setean equipo en call_deferred al inicio).
	call_deferred("_initial_sync")
	if InventorySystem != null:
		InventorySystem.equipped_changed.connect(_on_equipped_changed)


func _initial_sync() -> void:
	if InventorySystem == null:
		return
	var shield: ItemData = InventorySystem.get_equipped(ItemData.Slot.ESCUDO)
	_configure_from_item(shield)


## Pedido del player: activar/desactivar bloqueo.
## Si pedís activar sin cargas, no pasa nada (return silencioso).
func set_blocking(value: bool) -> void:
	if value == is_blocking:
		return
	if value and current_charges <= 0:
		return
	is_blocking = value
	if is_blocking:
		block_started.emit()
	else:
		block_ended.emit()


func has_charges() -> bool:
	return current_charges > 0


## Actualiza el bonus de cargas de skill y reconfigura el escudo actual.
## Llamado por PlayerStatsComponent.recalculate() cuando cambian skills.
## Si no hay escudo equipado, el bonus queda guardado y se aplica al equipar uno.
func set_skill_charges_bonus(bonus: int) -> void:
	if skill_charges_bonus == bonus:
		return
	skill_charges_bonus = bonus
	# Re-configurar con el escudo actual para reflejar el nuevo máximo.
	if InventorySystem != null:
		var shield_item: ItemData = InventorySystem.get_equipped(ItemData.Slot.ESCUDO)
		_configure_from_item(shield_item)


## Llamado por HurtboxComponent al recibir hit. Si bloqueando y hay carga:
## consume una y retorna true (el daño NO se aplica). Sino, retorna false.
## TIERRA 3pc: si tierra_3pc_active, recupera +1 carga hasta el máximo original.
func try_absorb() -> bool:
	if not is_blocking or current_charges <= 0:
		return false
	current_charges -= 1
	# TIERRA 3pc: recuperar una carga inmediatamente (neto: no consume carga).
	# Cap: no supera max_charges. Refuerza fantasía de "bloqueo infinito mientras mantenés set".
	if tierra_3pc_active and current_charges < max_charges:
		current_charges += 1
	charges_changed.emit(current_charges, max_charges)
	charge_absorbed.emit(current_charges)
	# Si se quedó en 0 (tierra_3pc desactivado o max_charges=0), salir del bloqueo.
	if current_charges <= 0:
		is_blocking = false
		block_ended.emit()
	return true


## Restaurar cargas al máximo. Llamar al completar etapa (PvE).
func restore_all() -> void:
	if max_charges <= 0:
		return
	current_charges = max_charges
	charges_changed.emit(current_charges, max_charges)


func _on_equipped_changed(slot: int, item: ItemData) -> void:
	if slot != ItemData.Slot.ESCUDO:
		return
	_configure_from_item(item)


## Configura max/current según el escudo equipado. Cambiar escudo
## resetea las cargas (asumimos full al equipar, consistente con PvE start).
## skill_charges_bonus se suma al máximo del escudo — solo si hay escudo equipado.
func _configure_from_item(item: ItemData) -> void:
	var new_max: int = 0
	if item != null and item.is_shield():
		new_max = item.block_charges() + skill_charges_bonus
	max_charges = new_max
	current_charges = new_max
	# Salir del bloqueo si quedamos sin cargas tras el cambio.
	if is_blocking and current_charges <= 0:
		is_blocking = false
		block_ended.emit()
	charges_changed.emit(current_charges, max_charges)
