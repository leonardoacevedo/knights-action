extends Node
## PortraitFactory — autoload helper para portraits.
##
## Estrategia híbrida (canon Leo 28/05):
## - Si existe PNG en `assets/art/portraits/<id>.png` → devuelve Texture2D.
## - Si no existe → caller debe dibujar procedural fallback.
##
## Paths canon:
##   - Player: `player_knight.png`
##   - Bosses: `boss_<id>.png` (ej. `boss_guardian.png`, `boss_lyss.png`)
##   - Enemies normales: `enemy_<class>.png` (ej. `enemy_melee.png`)
##
## Cuando se generen los PNGs con IA Gemini, drop in `assets/art/portraits/`
## sin tocar código — la próxima carga los detecta automático.

const PORTRAITS_DIR: String = "res://assets/art/portraits/"

## Returns Texture2D si existe el PNG canon para ese id, sino null.
func get_portrait(id: StringName) -> Texture2D:
	# Sanitizar el id: separadores y espacios romperían el path apuntando a subfolders
	# inexistentes sin warning (M5). Reemplazar por "_".
	var safe_id: String = String(id).replace("/", "_").replace("\\", "_").replace(" ", "_")
	var path: String = PORTRAITS_DIR + safe_id + ".png"
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	return tex


## Color sugerido para el fill procedural del portrait según elemento.
## ItemData.Element: 0=NEUTRO, 1=FUEGO, 2=AGUA, 3=TIERRA, 4=VIENTO, 5=LUZ, 6=SOMBRA.
func get_element_color(element: int) -> Color:
	match element:
		1: return Color(0.79, 0.18, 0.17, 0.92)  # FUEGO rojo brasa
		2: return Color(0.28, 0.79, 0.89, 0.92)  # AGUA cyan glacial
		3: return Color(0.32, 0.72, 0.53, 0.92)  # TIERRA verde
		4: return Color(0.85, 0.85, 0.95, 0.92)  # VIENTO blanco-gris
		5: return Color(1.00, 0.82, 0.30, 0.92)  # LUZ dorado
		6: return Color(0.40, 0.20, 0.55, 0.92)  # SOMBRA púrpura
		_: return Color(0.45, 0.45, 0.55, 0.92)  # NEUTRO gris
