extends Node
class_name EnemyBlockHandler

## Manejador de bloqueo por cargas para enemies R2/R3.
## Interfaz compatible con ShieldComponent (método try_absorb() -> bool)
## para que HurtboxComponent lo use directamente via duck typing.
##
## NO depende de InventorySystem ni de items equipados.
## Las cargas se setean desde enemy.gd al entrar al estado BLOCK.
##
## Flujo:
##   1. Enemy entra a BLOCK → llama reset_charges(1).
##   2. Player golpea → HurtboxComponent llama try_absorb().
##   3. Si hay carga: retorna true, emite charge_absorbed, luego broken → enemy reacciona.
##   4. Si el timer de BLOCK expira sin golpe → enemy llama deactivate() → limpia solo.

signal charge_absorbed(remaining: int)
## Emitido cuando se agotaron todas las cargas (el bloqueo se rompe por golpe).
signal broken

var current_charges: int = 0
var _active: bool = false


## Activar con N cargas. Llamar al entrar al estado BLOCK.
func reset_charges(n: int) -> void:
	current_charges = max(0, n)
	_active = current_charges > 0


## Llamado por HurtboxComponent al recibir hit (duck typing con ShieldComponent).
## Retorna true si el golpe fue absorbido (enemy bloqueó con éxito).
func try_absorb() -> bool:
	if not _active or current_charges <= 0:
		return false
	current_charges -= 1
	charge_absorbed.emit(current_charges)
	if current_charges <= 0:
		_active = false
		broken.emit()
	return true


## Desactivar sin absorber golpe (bloqueo expiró por tiempo).
## El enemy llama esto antes de salir del estado BLOCK por timeout.
func deactivate() -> void:
	_active = false
	current_charges = 0


func has_charges() -> bool:
	return _active and current_charges > 0
