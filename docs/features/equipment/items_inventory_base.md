# Feature: Items e Inventario — Base

**Estado:** Implementado (MVP base). Sin conectar a player stats todavía.
**GDD referencia:** §5.1, §5.2, §5.3.
**Archivos principales:** `scripts/data/item_data.gd`, `scripts/data/affix_data.gd`, `scripts/systems/inventory_system.gd`.

---

## Qué hace

### ItemData (Resource)

Define el schema de cualquier item equipable en el juego. Campos:

| Campo | Tipo | Descripción |
| :--- | :--- | :--- |
| `id` | `StringName` | Identificador único (ej. `&"espada_madera"`). |
| `display_name` | `String` | Nombre visible en UI. |
| `description` | `String` | Texto descriptivo (lore + stats en plaintext). |
| `slot` | `Slot` (enum) | `ARMA`, `ARMADURA`, o `ESCUDO`. |
| `rarity` | `Rarity` (enum) | `R1` a `R4`. R4 excluido del MVP. |
| `element` | `Element` (enum) | `NEUTRO`, `FUEGO`, `AGUA`, `TIERRA`. |
| `stat_main` | `int` | Daño (arma) o Defensa (armadura/escudo). |
| `refinement_level` | `int [0–10]` | Nivel de refinamiento. 0 = sin refinar. |
| `affixes` | `Array[AffixData]` | Stats secundarias. Máx según rareza. |
| `icon` | `Texture2D` | Icono del item. Puede ser null. |

Helpers triviales disponibles: `is_weapon()`, `is_armor()`, `is_shield()`, `max_affixes()`, `block_charges()`, `refined_stat()`.

`refined_stat()` aplica la fórmula de GDD §5.6: `stat_base * (1 + 0.05 * refinement_level)`.

### AffixData (Resource)

Sub-resource embedido en `ItemData.affixes`. Campos: `stat_id` (StringName), `display_name` (String), `value` (int).

Cantidad máxima de afijos por rareza (GDD §5.2):
- R1 → 1 afijo
- R2 → 2 afijos
- R3 → 3 afijos
- R4 → 3 afijos (excluido del MVP)

### InventorySystem (Autoload)

Singleton registrado en `project.godot`. Fuente de verdad del inventario y equipo del jugador.

**API:**

| Función / Signal | Descripción |
| :--- | :--- |
| `add_item(item)` | Agrega item al inventario. |
| `remove_item(item) -> bool` | Elimina item. Devuelve false si no existía. Si estaba equipado, limpia el slot. |
| `get_all() -> Array[ItemData]` | Copia del inventario completo. |
| `equip(item)` | Equipa item en su slot. Si no estaba en inventario, lo agrega. No elimina el item anterior del inventario. |
| `unequip(slot) -> ItemData` | Desequipa y devuelve el item, o null si el slot estaba vacío. |
| `get_equipped(slot) -> ItemData` | Devuelve el item equipado en el slot, o null. |
| `item_added(item)` | Signal emitida al agregar. |
| `item_removed(item)` | Signal emitida al eliminar. |
| `equipped_changed(slot, item)` | Signal emitida al equipar o desequipar. `item` es null al desequipar. |

### Items de ejemplo

| Archivo | Nombre | Slot | Rareza | stat_main | Afijo |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `resources/items/weapons/espada_madera.tres` | Espada de Madera | ARMA | R1 | 8 daño | +3 Velocidad de Ataque |
| `resources/items/armor/tunica_aprendiz.tres` | Túnica de Aprendiz | ARMADURA | R1 | 5 defensa | +10 Vida |
| `resources/items/shields/escudo_tablones.tres` | Escudo de Tablones | ESCUDO | R1 | 6 defensa | +4 Defensa |

Escudo R1 tiene 0 cargas de bloqueo según GDD §4.3 / §5.2.

---

## Qué NO hace (pendiente)

| Feature | Dónde va | Referencia GDD |
| :--- | :--- | :--- |
| Aplicar stats del equipo al player | `StatAggregator` o hook en `player.gd` | §6.4 |
| Set Bonus (2pc / 3pc mismo elemento) | `SetBonusResolver` autoload | §5.4 |
| Refinamiento con RNG y penalizaciones | `UpgradeManager` autoload | §5.6 |
| Fusión 3→1 | `FusionManager` autoload | §5.5 |
| Crafteo con materiales | `CraftingManager` autoload | §5.5 |
| Generación procedural de afijos | Pool de afijos por zona/rareza | §5.2 |
| Persistencia a disco | `SaveSystem` | — |
| Drop tables por zona | `ZoneData` + loot roller | §7.1 |
| WeaponData / ArmorData / ShieldData (subclases) | `scripts/data/` | §5.1 |

---

## Decisiones técnicas

### ¿Por qué enum typed en lugar de @export_enum con String?

La plantilla del README de `scripts/data/` usa `@export_enum("weapon", ...)` con String. Elegí enums tipados (`ItemData.Slot`, `ItemData.Rarity`, etc.) porque:

1. El compilador de GDScript detecta valores inválidos en tiempo de edición.
2. `match` sobre enum es más seguro que comparar strings.
3. `ItemData.Slot.ARMA` es legible sin magia de strings.
4. `InventorySystem._equipped` usa `ItemData.Slot` como clave de Dictionary sin ambigüedad.

**Trade-off:** los valores enum se guardan como enteros en el `.tres` (0, 1, 2). Si se reordena el enum, los `.tres` existentes apuntarán al valor equivocado. Convención: nunca reordenar, solo agregar al final.

### ¿Por qué Dictionary para _equipped en lugar de tres variables sueltas?

`_equipped: Dictionary` con `ItemData.Slot` como clave permite:
- `get_equipped(slot)` genérico sin `if/elif` por slot.
- Iterar todos los slots fácilmente para set bonus resolver.
- Agregar slots futuros sin tocar la API pública.

**Trade-off:** el Dictionary no tiene tipado fuerte de valores. Los valores son `ItemData | null`. Se documenta en el código.

### ¿Por qué el inventario incluye items equipados?

`_items` contiene todos los items, incluyendo los equipados. El equipo vive en `_equipped` como referencia al mismo objeto. Alternativa: dos Arrays separados. Elegí un solo Array porque:
- `get_all()` devuelve todo sin necesidad de merge.
- `remove_item()` no necesita buscar en dos lugares.
- La UI de inventario puede mostrar ítems equipados con un flag visual, sin lógica extra.

---

## Cómo testear manualmente (en Godot)

En el `_ready()` de cualquier nodo de prueba (ej. `world.tscn`):

```gdscript
var espada: ItemData = load("res://resources/items/weapons/espada_madera.tres")
InventorySystem.add_item(espada)
InventorySystem.equip(espada)
print(InventorySystem.get_equipped(ItemData.Slot.ARMA).display_name)
# Output esperado: "Espada de Madera"
print(InventorySystem.get_all().size())
# Output esperado: 1
```

---

## Tests automatizados

```bash
godot --headless --script res://tests/systems/inventory_system_test.gd
```

Cubre: `add_item`, `remove_item`, `equip`, `get_equipped`, `unequip`, equip auto-add, remove-clears-slot.

---

## Próximos pasos sugeridos

1. **Enganchar con player stats:** `StatAggregator` lee `InventorySystem.get_equipped(slot)` y suma `stat_main` + afijos activos al personaje.
2. **SetBonusResolver:** escucha `equipped_changed` y evalúa si 2 o 3 slots tienen el mismo elemento → aplica bonus pasivo.
3. **Subclases de Item:** `WeaponData`, `ArmorData`, `ShieldData` heredando de `ItemData` para campos específicos (ej. `attack_speed` en armas, `block_charges` calculado en shield se puede mover a ShieldData como campo explícito).
4. **UpgradeManager:** implementa refinamiento con probabilidades de GDD §5.6.
5. **Generación procedural de afijos:** pool `AffixData` por zona/rareza, roller que asigna aleatoriamente al craftear.
