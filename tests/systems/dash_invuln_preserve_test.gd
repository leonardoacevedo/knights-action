extends SceneTree
# Regresión A3: DashComponent no debe pisar la invulnerabilidad de otras fuentes.
# Guarda el invuln previo en try_dash y lo restaura en _end_dash (no fuerza false).
#
# Testeable headless sin escena: instanciamos DashComponent + HurtboxComponent reales
# y manejamos el ciclo con try_dash() + _end_dash() directos (sin _process, que requiere
# árbol). set_invulnerable/invulnerable son ops de campo, no dependen del SceneTree.
# _ready() del hurtbox NO corre con .new() (sin add_child) → sin side-effects de colisión.
#
# Ejecución: godot --headless --script res://tests/systems/dash_invuln_preserve_test.gd

func _init() -> void:
	print("== dash_invuln_preserve_test ==")
	_test_invuln_preserved_after_dash()
	_test_invuln_active_during_dash()
	_test_invuln_false_restored_to_false()
	print("All passed.")
	quit()


# ─── invuln=true antes del dash → sigue true al terminar (corazón del fix A3) ─
func _test_invuln_preserved_after_dash() -> void:
	var ctx := _make_dash()
	var dash: DashComponent = ctx["dash"]
	var hurtbox: HurtboxComponent = ctx["hurtbox"]

	# Otra fuente activó invuln antes del dash (ej. otro i-frame / habilidad).
	hurtbox.set_invulnerable(true)

	var started: bool = dash.try_dash(1)
	assert(started, "A3: try_dash debe iniciar (can_dash true)")
	assert(hurtbox.invulnerable == true, "A3: durante el dash debe estar invulnerable")

	dash._end_dash()  # simula fin del dash (sin depender de _process)

	assert(hurtbox.invulnerable == true,
		"A3: tras el dash el invuln previo (true) debe preservarse, no forzarse a false")
	print("  - invuln_preserved_after_dash ok")


# ─── Sin invuln previo, el dash igual da i-frames durante su duración ─────────
func _test_invuln_active_during_dash() -> void:
	var ctx := _make_dash()
	var dash: DashComponent = ctx["dash"]
	var hurtbox: HurtboxComponent = ctx["hurtbox"]

	assert(hurtbox.invulnerable == false, "A3: pre-dash sin invuln")
	dash.try_dash(1)
	assert(hurtbox.invulnerable == true,
		"A3: el dash debe activar i-frames (invuln) mientras dura")
	print("  - invuln_active_during_dash ok")


# ─── invuln=false antes → vuelve a false al terminar (no queda pegado en true) ─
func _test_invuln_false_restored_to_false() -> void:
	var ctx := _make_dash()
	var dash: DashComponent = ctx["dash"]
	var hurtbox: HurtboxComponent = ctx["hurtbox"]

	hurtbox.set_invulnerable(false)
	dash.try_dash(1)
	dash._end_dash()
	assert(hurtbox.invulnerable == false,
		"A3: sin invuln previo, el dash debe restaurar a false al terminar")
	print("  - invuln_false_restored_to_false ok")


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _make_dash() -> Dictionary:
	# Instancias reales. Sin add_child: _ready del hurtbox no corre (sin side-effects),
	# y manejamos el dash con try_dash/_end_dash directos en vez de _process.
	var hurtbox := HurtboxComponent.new()
	var dash := DashComponent.new()
	dash.hurtbox = hurtbox
	return { "dash": dash, "hurtbox": hurtbox }
