extends SceneTree
# Regresión C7: el recipe craft_cota_cuero_glacial.tres debe producir cota_glacial,
# no cota_cuero (output_item apuntaba al item equivocado antes del fix).
# Carga el .tres real de disco — sin mocks.
# Ejecución: godot --headless --script res://tests/systems/craft_cota_glacial_recipe_test.gd

const RECIPE_PATH := "res://resources/recipes/craft_cota_cuero_glacial.tres"

func _init() -> void:
	print("== craft_cota_glacial_recipe_test ==")
	_test_recipe_loads()
	_test_output_is_cota_glacial()
	_test_recipe_is_valid()
	print("All passed.")
	quit()


# ─── El recipe carga como CraftRecipe ─────────────────────────────────────────
func _test_recipe_loads() -> void:
	var recipe: CraftRecipe = load(RECIPE_PATH) as CraftRecipe
	assert(recipe != null, "C7: el recipe debe cargar como CraftRecipe desde %s" % RECIPE_PATH)
	print("  - recipe_loads ok")


# ─── El output apunta a cota_glacial (no cota_cuero) — corazón del fix C7 ──────
func _test_output_is_cota_glacial() -> void:
	var recipe: CraftRecipe = load(RECIPE_PATH) as CraftRecipe
	assert(recipe.output_item != null, "C7: output_item no debe ser null")
	assert(recipe.output_item.id == &"cota_glacial",
		"C7: output_item.id debe ser 'cota_glacial', obtuvo '%s'" % str(recipe.output_item.id))
	print("  - output_is_cota_glacial ok")


# ─── Sanity: el recipe sigue siendo válido tras el cambio de output ──────────
func _test_recipe_is_valid() -> void:
	var recipe: CraftRecipe = load(RECIPE_PATH) as CraftRecipe
	assert(recipe.is_valid(), "C7: el recipe debe pasar is_valid()")
	print("  - recipe_is_valid ok")
