# Loot Card Screen

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 2
**Sección GDD relevante:** §5.5 (drops por stage cleared), Milestone B
**Pilar(es) reforzado(s):** #2 ("cada muerte enseña algo"), #4 ("5 minutos bastan")

---

## Qué hace

Modal de feedback que aparece al completar cada stage mostrando los items dropeados por `DropSystem`.
Pausa el árbol mientras está abierta para que el jugador lea con tranquilidad.
Al presionar CONTINUAR, el árbol resume y el `create_timer` del `StageManager` retoma la cuenta para la siguiente stage.
Siempre aparece, incluso si no cayó ningún item (el jugador necesita saber que la etapa se cerró).

## Por qué (pilares)

- **Pilar #2** — El jugador siempre sabe qué obtuvo y por qué. Nunca hay ambigüedad sobre si el stage se completó o si algo cayó silenciosamente al inventario.
- **Pilar #4** — El flujo stage → loot card → CONTINUAR es inmediato. Sin menús extra, sin confirmaciones dobles.

## Cómo se integra

```
DropSystem.items_dropped  →  LootCardScreen._on_items_dropped()
                              ├── _populate(items)  → construye item cards
                              └── _show()           → get_tree().paused = true

LootCardScreen._on_continue_pressed()
  └── get_tree().paused = false
        └── StageManager.create_timer retoma → stage_pending siguiente
```

- Escucha `DropSystem.items_dropped` (emitido siempre en `stage_cleared`, lista puede ser vacía).
- Escucha `StageManager.stage_cleared` para actualizar `_last_stage_index` (muestra "Etapa N completada").
- No modifica `DropSystem`, `StageManager` ni `InventorySystem`.
- `process_mode = ALWAYS` → responde a input aunque el árbol esté pausado.
- Layer 27 → sobre `RefinementScreen` (25) y `CraftingScreen` (26).

## Decisiones técnicas no obvias

### Por qué pausar el árbol en vez de tocar StageManager

La alternativa habría sido agregar una signal `stage_advance_ready` a `StageManager` y que la loot card la emitiera al presionar CONTINUAR. Eso acopla UI con la lógica de progresión y requiere modificar `StageManager`.

La opción de pausar el árbol (`get_tree().paused = true`) es más limpia: el `create_timer` en `StageManager._handle_stage_cleared` queda congelado automáticamente (los timers respetan la pausa), y al hacer `false` retoma desde donde estaba. Sin acoplamiento.

### Por qué instanciar en world.gd._ready() y no en world.tscn

Agregar un nodo a `world.tscn` requiere UIDs válidos generados por Godot. Crear el `.tscn` con un UID hardcodeado en texto plano puede producir colisiones o "UID not found" al abrir el editor. Instanciar desde código es seguro, trazable y trivialmente reversible.

Desventaja: si en el futuro hay varias escenas con stages (dungeon, coliseo, etc.), habrá que mover esto a un `SceneManager` o autoload UI. El `TODO` en `world.gd` lo marca.

### Por qué siempre mostrar la card aunque no haya items

Un stage vacío de drops puede sentirse como un bug si no hay feedback visual. Mostrar "Sin botín en esta etapa" con el subtítulo "Etapa X completada" confirma que el sistema funcionó correctamente. Remueve ambigüedad → Pilar #2.

### Por qué reutilizar la pantalla sin queue_free

Hacer `queue_free` y re-instanciar en cada stage es más costoso (GC, reconstrucción del árbol) y puede causar frames de latencia visible en mobile. La pantalla queda oculta y se repopula via `_populate()` que hace `queue_free` de las cards viejas (nodos livianos) y construye las nuevas.

## Cómo testear manualmente

1. Abrir `scenes/world.tscn` en Godot 4.6.
2. Asignar al menos una `StageData` en el export `stages` del World (o dejar `auto_load_default_stages = true`).
3. Asegurarse que la `StageData` tiene `item_drops` configurado con al menos un item con chance > 0.
4. Correr la escena. Matar todos los enemies de la primera etapa.
5. **Smoke check A:** La loot card aparece, el fondo se oscurece, el juego se pausa (el player no se mueve).
6. **Smoke check B:** La card muestra el subtítulo "Etapa 1 completada — N items obtenidos".
7. **Smoke check C:** Cada item muestra nombre, slot, stat y rareza con el color correcto.
8. **Smoke check D:** Presionar CONTINUAR oculta la card, el juego retoma y después de ~1.5s aparece el banner de la siguiente stage.
9. **Smoke check E (vacío):** Configurar una stage con `item_drops = null` o con chance 0. Al completarla, la card aparece con el mensaje "Sin botín en esta etapa." (no se saltea).
10. **Smoke check F (mobile):** Verificar en celular real que el botón CONTINUAR es fácilmente tappeable (mínimo 64dp alto + full-width).

## Tests unitarios

No aplica directamente (UI pura). El backend que la alimenta (`DropSystem.roll_items_only`) tiene tests en `tests/`.

## Assets necesarios (si aplica)

- **Íconos de items por slot/rareza** — `item.icon` es `null` en Fase 2; la card muestra un `ColorRect` de placeholder del color de rareza. Delegar a `art-prompt-engineer` cuando llegue Fase 3.
- **SFX de apertura de loot card** — efecto de "recompensa" (campana, fanfarria corta). Pendiente Fase 3.
- **Animación de entrada de cards** — actualmente fade-in del panel completo. En Fase 3 considerar stagger (cada card entra con 50ms de delay).

## Archivos tocados

- `scripts/ui/loot_card_screen.gd` — nuevo (lógica completa).
- `scenes/ui/loot_card_screen.tscn` — nuevo (CanvasLayer shell + script).
- `scripts/world/world.gd` — agrega instancia de `LootCardScreen` en `_ready()`.

## Pendientes / mejoras futuras

- [ ] Sprites reales de items cuando llegue el arte (Fase 3) — reemplazar `ColorRect` placeholder por `TextureRect`.
- [ ] SFX de reveal de loot (épico si hay R3/R4, normal si es R1/R2).
- [ ] Animación de stagger: cards entran una a una con delay de 60ms (más satisfactorio que fade de panel completo).
- [ ] Botón "Ver Inventario" que abre `InventoryScreen` sin cerrar la card (low priority).
- [ ] Highlight especial si algún item es R4 (glow, partículas) — considerar pillar-check primero.
- [ ] Mover instancia de `world.gd._ready()` a un `SceneManager` o autoload UI cuando haya múltiples escenas con stages.
