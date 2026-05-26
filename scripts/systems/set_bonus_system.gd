extends Node
# Autoload "SetBonusSystem"
#
## Sistema de afinidad de set. GDD §5.4.
## Detecta cuántas piezas del mismo elemento tiene el jugador equipadas,
## devuelve el nivel de bonus activo (0/2/3) y provee los SetBonusData para
## que los componentes lean los valores sin hardcodearlos.
##
## API principal:
##   compute_affinity(weapon, armor, shield) → { element: int, pieces: int }
##   get_bonus_data(element) → SetBonusData | null
##
## Los .tres de SetBonusData se cargan desde SET_BONUS_DIR al _ready.

const SET_BONUS_DIR := "res://resources/set_bonuses"

## Cache element_int → SetBonusData. Cargado en _ready.
var _bonus_by_element: Dictionary = {}

## Flags de estado activo — leídos por componentes en _process / en eventos.
## Se actualiza cada vez que SetBonusSystem.refresh() es llamado
## (PlayerStatsComponent lo llama en recalculate()).
var active_element: int = ItemData.Element.NEUTRO
var active_pieces: int = 0


func _ready() -> void:
	_load_bonus_data()


## Carga todos los .tres de SET_BONUS_DIR y los indexa por element.
func _load_bonus_data() -> void:
	var dir := DirAccess.open(SET_BONUS_DIR)
	if dir == null:
		push_warning("SetBonusSystem: no se pudo abrir %s — sin set bonuses." % SET_BONUS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path := SET_BONUS_DIR + "/" + fname
			var data := load(path) as SetBonusData
			if data != null:
				_bonus_by_element[data.element] = data
		fname = dir.get_next()
	dir.list_dir_end()


# ─── API pública ──────────────────────────────────────────────────────────────

## Calcula la afinidad de equipo. Devuelve Dictionary { element: int, pieces: int }.
## pieces = 0 si no hay afinidad activa (ningún elemento llega a 2 piezas).
## NEUTRO nunca da afinidad propia. Si hay empate en count, usa el de mayor valor enum
## (desempate determinista). GDD §5.4.
func compute_affinity(weapon: ItemData, armor: ItemData, shield: ItemData) -> Dictionary:
	var counts: Dictionary = {}
	for item in [weapon, armor, shield]:
		if item == null:
			continue
		var elem: int = item.element
		if elem == ItemData.Element.NEUTRO:
			continue
		counts[elem] = counts.get(elem, 0) + 1

	var best_elem: int = ItemData.Element.NEUTRO
	var best_count: int = 0
	for elem in counts:
		var cnt: int = counts[elem]
		if cnt > best_count or (cnt == best_count and elem > best_elem):
			best_elem = elem
			best_count = cnt

	if best_count < 2:
		return { "element": ItemData.Element.NEUTRO, "pieces": 0 }
	return { "element": best_elem, "pieces": best_count }


## Retorna el SetBonusData para un elemento, o null si no existe.
func get_bonus_data(element: int) -> SetBonusData:
	return _bonus_by_element.get(element, null) as SetBonusData


## Refresca el estado activo (active_element / active_pieces) desde el inventario.
## Llamado por PlayerStatsComponent.recalculate() al final.
func refresh(weapon: ItemData, armor: ItemData, shield: ItemData) -> void:
	var result := compute_affinity(weapon, armor, shield)
	active_element = result["element"]
	active_pieces  = result["pieces"]


## Retorna true si el bonus de N piezas del elemento indicado está activo.
func is_active(element: int, min_pieces: int) -> bool:
	return active_element == element and active_pieces >= min_pieces


## Retorna el SetBonusData activo actualmente, o null si no hay afinidad.
func get_active_bonus_data() -> SetBonusData:
	if active_element == ItemData.Element.NEUTRO or active_pieces < 2:
		return null
	return get_bonus_data(active_element)
