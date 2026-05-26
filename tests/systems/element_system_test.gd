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
	print("All passed.")
	quit()


# Shorthands de Element para legibilidad.
const NEUTRO: int  = ItemData.Element.NEUTRO
const FUEGO: int   = ItemData.Element.FUEGO
const AGUA: int    = ItemData.Element.AGUA
const TIERRA: int  = ItemData.Element.TIERRA


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
