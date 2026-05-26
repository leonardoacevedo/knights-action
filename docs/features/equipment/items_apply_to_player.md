# Feature: Items — Aplicación de Stats al Player

**Estado:** Implementado (MVP). Arma, Armadura, Escudo aplican stats al player.
**GDD referencia:** §5.1, §5.2, §5.6, §6.4.
**Depende de:** `items_inventory_base.md`, `InventorySystem`, `HealthComponent`, `HitboxComponent`, `HurtboxComponent`.

---

## Qué hace

Cuando el jugador equipa o desequipa un item, los stats del player se actualizan automáticamente:

- **Arma equipada:** `hitbox.damage` = `stat_main` del arma con refinamiento aplicado.
- **Sin arma:** `hitbox.damage` = `GameConfig.PLAYER_BASE_DAMAGE` (10, equivalente a "puños").
- **Armadura + Escudo:** defensa flat acumulada de ambos (`stat_main` + afijos `defense`) → `hurtbox.flat_defense`.
- **Afijos `hp`:** se suman a `GameConfig.PLAYER_BASE_HEALTH` (100) → `health.max_health`.
- **Refinamiento:** aplicado via `ItemData.refined_stat()` (fórmula GDD §5.6).

---

## Fórmula de stats finales

Según `formulas.md` §Equipamiento y GDD §6.4:

```
stats_totales = stats_base(nivel) + stats_equipamiento + bonus_skills + bonus_set
```

En esta iteración (bonus_skills y bonus_set son futuro):

```
hitbox.damage     = arma.stat_main * (1 + 0.05 * arma.refinement_level)
                    o GameConfig.PLAYER_BASE_DAMAGE (10) si no hay arma

health.max_health = GameConfig.PLAYER_BASE_HEALTH (100)
                    + suma(afijos hp de todos los slots equipados)

hurtbox.flat_defense = GameConfig.PLAYER_BASE_DEFENSE (0)
                       + armadura.stat_main * (1 + 0.05 * armadura.refinement_level)
                       + escudo.stat_main   * (1 + 0.05 * escudo.refinement_level)
                       + suma(afijos defense de todos los slots equipados)

daño recibido efectivo = max(1, daño_entrante - hurtbox.flat_defense)
```

### Constantes base (sin equipo)

| Constante | Valor | Descripción |
| :--- | :--- | :--- |
| `GameConfig.PLAYER_BASE_DAMAGE` | 10 | Daño de "puños" — sin arma equipada. |
| `GameConfig.PLAYER_BASE_HEALTH` | 100 | HP máximo sin armadura ni escudo. |
| `GameConfig.PLAYER_BASE_DEFENSE` | 0 | Defensa flat sin equipo defensivo. |

---

## Cómo se conecta con InventorySystem

1. `PlayerStatsComponent` se conecta a `InventorySystem.equipped_changed` en `_ready()`.
2. Cada vez que el inventario emite `equipped_changed` (equip o unequip), llama `recalculate()`.
3. `recalculate()` lee los 3 slots via `InventorySystem.get_equipped(slot)` y actualiza los componentes.

```
InventorySystem.equip(espada)
  → equipped_changed.emit(Slot.ARMA, espada)
    → PlayerStatsComponent._on_equipped_changed()
      → recalculate()
        → hitbox.damage = 8 (stat_main de espada, sin refinamiento)
```

---

## Afijos soportados (MVP)

| stat_id | Efecto | Notas |
| :--- | :--- | :--- |
| `&"hp"` | Suma a `health.max_health` | Cualquier slot puede tenerlo. |
| `&"defense"` | Suma a `hurtbox.flat_defense` | Útil en armadura/escudo, pero cualquier slot. |
| `&"attack_speed"` | **Reservado** — sin sistema implementado. | Se loggea warning pero no crashea. |
| (otros) | **Ignorados** — warning en consola. | No rompe el juego. |

---

## Decisiones técnicas

### ¿Por qué componente y no autoload?

`PlayerStatsComponent` vive como hijo del Player (igual que `HealthComponent`, `HitboxComponent`, etc.). Razones:

1. Los stats son del entity específico, no de un sistema global.
2. Cuando haya entidades con stats similares (NPCs con equipamiento, Ecos en el Coliseo), cada uno tiene su propio componente — no compiten por estado global.
3. Consistente con la arquitectura de composición documentada en `arquitectura.md`.

### ¿HP absoluto o ratio al re-equipar?

**Decisión: absoluto.** Si tenías 80/100 HP y equipás una armadura que sube el max a 120, quedás en 80/120 — no en 96/120 (ratio).

Razones:
1. Más predecible: el jugador sabe exactamente cuánta HP tiene.
2. No regala HP gratis al re-equipar.
3. Más fácil de debuggear (el número no cambia "mágicamente").

Si el nuevo max es **menor** que el HP actual (ej. desequipás una armadura y tu max baja de 150 a 100 pero tenías 130), el HP actual se **clampea al nuevo max**. El jugador no puede tener más HP que el máximo.

### Defensa flat: ¿por qué en HurtboxComponent?

Alternativa considerada: un método `reduce_damage()` en `PlayerStatsComponent` que intercepta. Elegí `flat_defense` en `HurtboxComponent` porque:
1. El Hurtbox ya es el receptor de daño — es el lugar correcto para la reducción.
2. Mantiene `PlayerStatsComponent` como escritor de stats, no como interceptor de lógica de combate.
3. Limpio y predecible: `receive_hit()` aplica la reducción en un solo lugar.

Daño mínimo garantizado: **1**. Un defensor con 100 de defensa no puede absorber 100% del daño — siempre entra al menos 1 punto.

---

## Pendiente (no en este scope)

| Feature | Sistema | Referencia GDD |
| :--- | :--- | :--- |
| Refinamiento (RNG +1 a +10) | `UpgradeManager` | §5.6 |
| Set Bonus (2pc/3pc mismo elemento) | `SetBonusResolver` | §5.4 |
| Attack Speed desde afijo `attack_speed` | `player.gd` ATTACK_DURATION | §5.2 |
| Resistencia elemental aplicada al daño recibido | `HurtboxComponent` + `ElementData` | §5.3 |
| Stats de skills sumadas | `SkillSystem` | §6.2 |
| Stats de nivel del player (`stats_base(nivel)`) | `ProgressionSystem` | §6.1 |

---

## Tests automatizados

```bash
godot --headless --script res://tests/systems/player_stats_component_test.gd
```

Cubre: equip arma → damage, equip armadura con afijo hp → max_health, unequip reverts, HP clamped al bajar max, HP absoluto al subir max, refinamiento aplicado, afijo defense en hurtbox, afijo desconocido no crashea.

**Nota headless:** los tests instancian los componentes directamente, sin escena. Usan el autoload `InventorySystem` global (limpiando estado antes de cada test). Si el autoload no está disponible en modo headless, los tests fallarán con "Identifier 'InventorySystem' not declared". En ese caso, correr con `--scene res://scenes/world.tscn --quit-after 0` o migrar a dependency injection en `PlayerStatsComponent` (exponer `var inventory_ref` inyectable).
