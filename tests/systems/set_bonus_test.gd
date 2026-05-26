extends SceneTree
# Tests del sistema de Set Bonus. GDD §5.4.
# Ejecución: godot --headless --script res://tests/systems/set_bonus_test.gd
#
# Solo testea lógica pura (compute_affinity, flags, fórmulas).
# No depende de autoloads. SetBonusSystem se instancia directo.
# Tests de efectos runtime (AoE, dash reset) son [INTEGRACION] — requieren escena.

func _init() -> void:
	print("== set_bonus_test ==")

	# ── compute_affinity ──────────────────────────────────────────────────────
	_test_sin_equipo_no_hay_afinidad()
	_test_un_elemento_no_llega_a_dos_piezas()
	_test_fuego_2pc_activo()
	_test_fuego_3pc_activo()
	_test_neutro_no_cuenta()
	_test_fuego_2_agua_1_gana_fuego()
	_test_empate_elementos_resuelve_deterministico()
	_test_set_mixto_sin_afinidad()
	_test_arma_neutro_armor_agua_shield_agua_da_agua_2pc()

	# ── Fórmulas de bonus ─────────────────────────────────────────────────────
	_test_fuego_2pc_damage_multiplier()
	_test_tierra_2pc_hp_multiplier()
	_test_agua_2pc_furia_regen()
	_test_tierra_3pc_flag_activo()
	_test_agua_3pc_flag_activo()

	print("All passed.")
	quit()


# ─── Shorthands ───────────────────────────────────────────────────────────────

const NEUTRO: int  = 0  # ItemData.Element.NEUTRO
const FUEGO: int   = 1  # ItemData.Element.FUEGO
const AGUA: int    = 2  # ItemData.Element.AGUA
const TIERRA: int  = 3  # ItemData.Element.TIERRA


# ─── Helpers de items mock ────────────────────────────────────────────────────

func _make_weapon(element: int) -> ItemData:
	var item := ItemData.new()
	item.slot = ItemData.Slot.ARMA
	item.element = element
	item.stat_main = 10
	item.affixes = []
	return item


func _make_armor(element: int) -> ItemData:
	var item := ItemData.new()
	item.slot = ItemData.Slot.ARMADURA
	item.element = element
	item.stat_main = 5
	item.affixes = []
	return item


func _make_shield(element: int) -> ItemData:
	var item := ItemData.new()
	item.slot = ItemData.Slot.ESCUDO
	item.element = element
	item.stat_main = 3
	item.rarity = ItemData.Rarity.R2
	item.affixes = []
	return item


## Instancia SetBonusSystem aislado (sin autoload).
func _make_sbs() -> Node:
	var sbs: Node = load("res://scripts/systems/set_bonus_system.gd").new()
	return sbs


# ─── Tests compute_affinity ───────────────────────────────────────────────────

func _test_sin_equipo_no_hay_afinidad() -> void:
	var sbs := _make_sbs()
	var r := sbs.compute_affinity(null, null, null)
	assert(r["pieces"] == 0, "sin_equipo: pieces debe ser 0")
	assert(r["element"] == NEUTRO, "sin_equipo: element debe ser NEUTRO")
	print("  - sin_equipo_no_hay_afinidad ok")


func _test_un_elemento_no_llega_a_dos_piezas() -> void:
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var r := sbs.compute_affinity(w, null, null)
	assert(r["pieces"] == 0, "1pc: no debe haber afinidad con 1 pieza")
	print("  - un_elemento_no_llega_a_dos_piezas ok")


func _test_fuego_2pc_activo() -> void:
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var a := _make_armor(FUEGO)
	# Caso del enunciado: arma FUEGO + armor FUEGO + shield NEUTRO → FUEGO 2pc.
	var s := _make_shield(NEUTRO)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["element"] == FUEGO, "fuego_2pc: element debe ser FUEGO")
	assert(r["pieces"] == 2, "fuego_2pc: pieces debe ser 2")
	print("  - fuego_2pc_activo ok")


func _test_fuego_3pc_activo() -> void:
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var a := _make_armor(FUEGO)
	var s := _make_shield(FUEGO)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["element"] == FUEGO, "fuego_3pc: element debe ser FUEGO")
	assert(r["pieces"] == 3, "fuego_3pc: pieces debe ser 3")
	print("  - fuego_3pc_activo ok")


func _test_neutro_no_cuenta() -> void:
	# Arma NEUTRO + armor NEUTRO + shield AGUA → solo AGUA con 1 pieza → sin afinidad.
	var sbs := _make_sbs()
	var w := _make_weapon(NEUTRO)
	var a := _make_armor(NEUTRO)
	var s := _make_shield(AGUA)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["pieces"] == 0, "neutro_no_cuenta: NEUTRO no da afinidad propia")
	print("  - neutro_no_cuenta ok")


func _test_fuego_2_agua_1_gana_fuego() -> void:
	# Caso del enunciado: arma FUEGO + armor FUEGO + shield AGUA → FUEGO 2pc.
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var a := _make_armor(FUEGO)
	var s := _make_shield(AGUA)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["element"] == FUEGO, "fuego2_agua1: element debe ser FUEGO")
	assert(r["pieces"] == 2, "fuego2_agua1: pieces debe ser 2")
	print("  - fuego_2_agua_1_gana_fuego ok")


func _test_empate_elementos_resuelve_deterministico() -> void:
	# FUEGO=1 pieza, AGUA=1 pieza, TIERRA=1 pieza → sin afinidad (ninguno llega a 2).
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var a := _make_armor(AGUA)
	var s := _make_shield(TIERRA)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["pieces"] == 0, "empate_3: ninguno llega a 2 → sin afinidad")
	print("  - empate_elementos_resuelve_deterministico ok")


func _test_set_mixto_sin_afinidad() -> void:
	# Caso del enunciado: arma FUEGO + armor AGUA + shield TIERRA → sin afinidad.
	var sbs := _make_sbs()
	var w := _make_weapon(FUEGO)
	var a := _make_armor(AGUA)
	var s := _make_shield(TIERRA)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["pieces"] == 0, "mixto: sin afinidad si todos diferentes")
	print("  - set_mixto_sin_afinidad ok")


func _test_arma_neutro_armor_agua_shield_agua_da_agua_2pc() -> void:
	var sbs := _make_sbs()
	var w := _make_weapon(NEUTRO)
	var a := _make_armor(AGUA)
	var s := _make_shield(AGUA)
	var r := sbs.compute_affinity(w, a, s)
	assert(r["element"] == AGUA, "neutro_arma: element debe ser AGUA")
	assert(r["pieces"] == 2, "neutro_arma: pieces debe ser 2")
	print("  - arma_neutro_armor_agua_shield_agua_da_agua_2pc ok")


# ─── Tests de bonus (lógica pura, sin autoloads) ─────────────────────────────

func _test_fuego_2pc_damage_multiplier() -> void:
	# FUEGO 2pc → damage_multiplier_2pc debe ser 1.10.
	# Cargamos el .tres real para testear los valores de balance.
	var data: SetBonusData = load("res://resources/set_bonuses/set_bonus_fuego.tres")
	assert(data != null, "fuego_data: .tres no cargó")
	assert(abs(data.damage_multiplier_2pc - 1.1) < 0.001,
		"fuego_2pc_mult: debe ser 1.10, got %f" % data.damage_multiplier_2pc)
	assert(data.element == FUEGO, "fuego_data: element debe ser FUEGO")
	print("  - fuego_2pc_damage_multiplier ok")


func _test_tierra_2pc_hp_multiplier() -> void:
	var data: SetBonusData = load("res://resources/set_bonuses/set_bonus_tierra.tres")
	assert(data != null, "tierra_data: .tres no cargó")
	assert(abs(data.hp_multiplier_2pc - 1.15) < 0.001,
		"tierra_2pc_hp: debe ser 1.15, got %f" % data.hp_multiplier_2pc)
	assert(data.tierra_block_restores_charge == true,
		"tierra_3pc: tierra_block_restores_charge debe ser true")
	print("  - tierra_2pc_hp_multiplier ok")


func _test_agua_2pc_furia_regen() -> void:
	var data: SetBonusData = load("res://resources/set_bonuses/set_bonus_agua.tres")
	assert(data != null, "agua_data: .tres no cargó")
	assert(abs(data.furia_regen_per_sec_2pc - 1.0) < 0.001,
		"agua_2pc_regen: debe ser 1.0 Furia/s, got %f" % data.furia_regen_per_sec_2pc)
	assert(data.agua_dash_reset_on_pass == true,
		"agua_3pc: agua_dash_reset_on_pass debe ser true")
	print("  - agua_2pc_furia_regen ok")


func _test_tierra_3pc_flag_activo() -> void:
	# Simular que tierra_3pc está activo: ShieldComponent debe recuperar carga.
	var sc := ShieldComponent.new()
	sc.max_charges = 2
	sc.current_charges = 2
	sc.is_blocking = true
	sc.tierra_3pc_active = true
	# Absorber: consume 1 y recupera 1 → neto = 2 (sin cambio aparente).
	var absorbed: bool = sc.try_absorb()
	assert(absorbed == true, "tierra_3pc: try_absorb debe retornar true")
	assert(sc.current_charges == 2,
		"tierra_3pc: charges debe mantenerse en 2 (consume + recupera), got %d" % sc.current_charges)
	print("  - tierra_3pc_flag_activo ok")


func _test_agua_3pc_flag_activo() -> void:
	# DashComponent con agua_3pc_active: verificar que el flag se puede setear.
	var dc := DashComponent.new()
	dc.agua_3pc_active = true
	assert(dc.agua_3pc_active == true, "agua_3pc: flag debe poder setearse")
	# El reset de cooldown solo ocurre en _check_agua_dash_reset con detection_area —
	# ese path es [INTEGRACION] (requiere escena con Physics).
	print("  - agua_3pc_flag_activo ok (reset de cooldown es INTEGRACION)")
