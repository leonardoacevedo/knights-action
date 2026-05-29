extends Node
class_name DashComponent

## Dash con i-frames + cooldown. GDD §4.3.
## 6 frames de invulnerabilidad (~100ms a 60fps). Cooldown 0.8s.
## Ventana de habilidad, no escape gratuito.

signal dash_started
signal dash_ended
signal cooldown_finished

@export var dash_speed: float = 1200.0
@export var dash_duration: float = 0.1     # ~6 frames a 60fps (~6 i-frames base)
@export var cooldown: float = 0.8
## Si está seteado, el dash setea invulnerable en este hurtbox durante i-frames.
@export var hurtbox: HurtboxComponent

## Multiplicador sobre el cooldown base. -20% = 0.80. Seteado por PlayerStatsComponent
## vía DASH_COOLDOWN_PCT (skill agil_dash_rapido). Valor < 1.0 = cooldown más corto.
var dash_cooldown_mult: float = 1.0

## Multiplicador sobre la duración de i-frames (dash_duration).
## +30% = 1.30 → duración pasa de 0.1s a 0.13s. Seteado por PlayerStatsComponent
## vía IFRAMES_PCT (skill agil_sombra_del_valle, +30%).
var iframes_mult: float = 1.0

## Area2D del player para detectar overlap con hurtboxes de enemies durante el dash.
## Seteado por player.gd en _ready. Solo se usa si agua_3pc_active es true.
var detection_area: Area2D = null

## Set bonus AGUA 3pc. Si true, pasar por hitbox de enemy durante el dash resetea cooldown.
## Seteado por player.gd cuando SetBonusSystem.is_active(AGUA, 3) es true.
var agua_3pc_active: bool = false

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: int = 1

var _duration_timer: float = 0.0
var _cooldown_timer: float = 0.0
## Flag: ya activamos el reset de cooldown en este dash (evitar doble-reset).
var _agua_reset_triggered: bool = false
## Estado de invuln del hurtbox previo al dash. Se restaura en _end_dash para no
## pisar otras fuentes de invulnerabilidad (fix A3).
var _prev_invuln: bool = false


func _process(delta: float) -> void:
	if is_dashing:
		_duration_timer -= delta
		# AGUA 3pc: comprobar overlap con hurtbox de enemy una vez por dash.
		if agua_3pc_active and not _agua_reset_triggered:
			_check_agua_dash_reset()
		if _duration_timer <= 0.0:
			_end_dash()

	# fix M3: el cooldown corre siempre que > 0 (también durante is_dashing), pero
	# can_dash solo se rehabilita fuera del dash (no permitir re-dash mid-dash).
	if not can_dash and _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0 and not is_dashing:
			can_dash = true
			cooldown_finished.emit()


func try_dash(direction: int) -> bool:
	if not can_dash or is_dashing:
		return false
	is_dashing = true
	can_dash = false
	_agua_reset_triggered = false
	dash_direction = sign(direction) if direction != 0 else 1
	# Aplicar multiplicadores de skill: iframes_mult extiende duración; dash_cooldown_mult acorta espera.
	_duration_timer = dash_duration * iframes_mult
	_cooldown_timer = cooldown * dash_cooldown_mult
	if hurtbox != null:
		# fix A3: guardar invuln previo para restaurarlo al terminar (no forzar false).
		_prev_invuln = hurtbox.invulnerable
		hurtbox.set_invulnerable(true)
	dash_started.emit()
	return true


func _end_dash() -> void:
	is_dashing = false
	if hurtbox != null:
		# fix A3: restaurar el invuln que había antes del dash en vez de forzar false.
		hurtbox.set_invulnerable(_prev_invuln)
	# fix M3: si el cooldown ya expiró mientras dasheábamos, rehabilitar dash ahora
	# (el gate `not is_dashing` del _process lo dejó pendiente).
	if not can_dash and _cooldown_timer <= 0.0:
		can_dash = true
		cooldown_finished.emit()
	dash_ended.emit()


func get_dash_velocity_x() -> float:
	return dash_direction * dash_speed if is_dashing else 0.0


## AGUA 3pc: revisa si el detection_area solapa con algún HurtboxComponent de enemy.
## Si sí, resetea el cooldown del dash (puede dashear de nuevo inmediatamente).
func _check_agua_dash_reset() -> void:
	if detection_area == null:
		return
	var overlapping: Array[Area2D] = detection_area.get_overlapping_areas()
	for area in overlapping:
		if area is HurtboxComponent:
			var hb: HurtboxComponent = area
			# Solo enemies (team != player team). Player es team 1, enemy es team 2.
			if hb.team != 1:
				_agua_reset_triggered = true
				# Reset cooldown: volver a poder dashear sin esperar.
				_cooldown_timer = 0.0
				can_dash = true
				cooldown_finished.emit()
				return
