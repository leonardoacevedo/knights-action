extends SceneTree
# Tests del sistema elemental GDD §5.3.
# Cubre: triángulo completo, NEUTRO, mismo elemento, casos cruzados.
# Ejecución: godot --headless --script res://tests/systems/element_system_test.gd

func _init() -> void:
	print("== element_system_test ==")
	_test_neutro_vs_cualquiera()
	_test_cualquiera_vs_neutro()
	_test_neutro_vs_neutro()
	_test_mismo_elemento()
	_test_fuego_vence_tierra()
	_test_tierra_vence_agua()
	_test_agua_vence_fuego()
	_test_tierra_pierde_fuego()
	_test_agua_pierde_tierra()
	_test_fuego_pierde_agua()
	# Triángulo secundario (extensión 27/05): VIENTO > LUZ > SOMBRA > VIENTO.
	_test_viento_vence_rayo()
	_test_rayo_vence_sombra()
	_test_sombra_vence_viento()
	_test_rayo_pierde_viento()
	_test_sombra_pierde_rayo()
	_test_viento_pierde_sombra()
	# Cross-triángulo: primario vs secundario = neutral 1.0.
	_test_cross_triangle_neutral()
	print("All passed.")
	quit()


# Shorthands de Element para legibilidad.
const NEUTRO: int  = ItemData.Element.NEUTRO
const FUEGO: int   = ItemData.Element.FUEGO
const AGUA: int    = ItemData.Element.AGUA
const TIERRA: int  = ItemData.Element.TIERRA
const VIENTO: int  = ItemData.Element.VIENTO
const LUZ: int    = ItemData.Element.LUZ
const SOMBRA: int  = ItemData.Element.SOMBRA


func _assert_modifier(attacker: int, defender: int, expected: float, label: String) -> void:
	var got: float = GameConfig.element_modifier(attacker, defender)
	assert(
		abs(got - expected) < 0.001,
		"%s — esperado %.2f, got %.2f" % [label, expected, got]
	)
	print("  - %s ok (%.2f)" % [label, got])


func _test_neutro_vs_cualquiera() -> void:
	_assert_modifier(NEUTRO, FUEGO, 1.0, "NEUTRO vs FUEGO")
	_assert_modifier(NEUTRO, AGUA, 1.0, "NEUTRO vs AGUA")
	_assert_modifier(NEUTRO, TIERRA, 1.0, "NEUTRO vs TIERRA")


func _test_cualquiera_vs_neutro() -> void:
	_assert_modifier(FUEGO, NEUTRO, 1.0, "FUEGO vs NEUTRO")
	_assert_modifier(AGUA, NEUTRO, 1.0, "AGUA vs NEUTRO")
	_assert_modifier(TIERRA, NEUTRO, 1.0, "TIERRA vs NEUTRO")


func _test_neutro_vs_neutro() -> void:
	_assert_modifier(NEUTRO, NEUTRO, 1.0, "NEUTRO vs NEUTRO")


func _test_mismo_elemento() -> void:
	_assert_modifier(FUEGO, FUEGO, 1.0, "FUEGO vs FUEGO")
	_assert_modifier(AGUA, AGUA, 1.0, "AGUA vs AGUA")
	_assert_modifier(TIERRA, TIERRA, 1.0, "TIERRA vs TIERRA")


func _test_fuego_vence_tierra() -> void:
	_assert_modifier(FUEGO, TIERRA, 1.5, "FUEGO vence TIERRA (×1.5)")


func _test_tierra_vence_agua() -> void:
	_assert_modifier(TIERRA, AGUA, 1.5, "TIERRA vence AGUA (×1.5)")


func _test_agua_vence_fuego() -> void:
	_assert_modifier(AGUA, FUEGO, 1.5, "AGUA vence FUEGO (×1.5)")


func _test_tierra_pierde_fuego() -> void:
	_assert_modifier(TIERRA, FUEGO, 0.66, "TIERRA pierde vs FUEGO (×0.66)")


func _test_agua_pierde_tierra() -> void:
	_assert_modifier(AGUA, TIERRA, 0.66, "AGUA pierde vs TIERRA (×0.66)")


func _test_fuego_pierde_agua() -> void:
	_assert_modifier(FUEGO, AGUA, 0.66, "FUEGO pierde vs AGUA (×0.66)")


# ─── Triángulo secundario ────────────────────────────────────────────────────

func _test_viento_vence_rayo() -> void:
	_assert_modifier(VIENTO, LUZ, 1.5, "VIENTO vence LUZ (×1.5)")


func _test_rayo_vence_sombra() -> void:
	_assert_modifier(LUZ, SOMBRA, 1.5, "LUZ vence SOMBRA (×1.5)")


func _test_sombra_vence_viento() -> void:
	_assert_modifier(SOMBRA, VIENTO, 1.5, "SOMBRA vence VIENTO (×1.5)")


func _test_rayo_pierde_viento() -> void:
	_assert_modifier(LUZ, VIENTO, 0.66, "LUZ pierde vs VIENTO (×0.66)")


func _test_sombra_pierde_rayo() -> void:
	_assert_modifier(SOMBRA, LUZ, 0.66, "SOMBRA pierde vs LUZ (×0.66)")


func _test_viento_pierde_sombra() -> void:
	_assert_modifier(VIENTO, SOMBRA, 0.66, "VIENTO pierde vs SOMBRA (×0.66)")


# ─── Cross-triángulo: primario vs secundario = neutral ──────────────────────

func _test_cross_triangle_neutral() -> void:
	_assert_modifier(FUEGO, VIENTO, 1.0, "FUEGO vs VIENTO cross-triangle neutral")
	_assert_modifier(FUEGO, LUZ, 1.0, "FUEGO vs LUZ cross-triangle neutral")
	_assert_modifier(FUEGO, SOMBRA, 1.0, "FUEGO vs SOMBRA cross-triangle neutral")
	_assert_modifier(AGUA, VIENTO, 1.0, "AGUA vs VIENTO cross-triangle neutral")
	_assert_modifier(TIERRA, LUZ, 1.0, "TIERRA vs LUZ cross-triangle neutral")
	_assert_modifier(VIENTO, FUEGO, 1.0, "VIENTO vs FUEGO cross-triangle neutral")
	_assert_modifier(SOMBRA, AGUA, 1.0, "SOMBRA vs AGUA cross-triangle neutral")
	_assert_modifier(LUZ, TIERRA, 1.0, "LUZ vs TIERRA cross-triangle neutral")
