# UI de Refinamiento

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (ux-mobile) con dirección de Leo
**Fase del proyecto:** 2 — Loop Básico
**Sección GDD relevante:** §5.6 Sistema de Refinamiento (+1 a +10)
**Pilar(es) reforzado(s):** #2 (cada muerte enseña algo — nada debe sentirse aleatorio o injusto)

---

## Qué hace

Pantalla modal (`CanvasLayer` layer 25) que permite al jugador intentar refinar un item de +0 a +10.
El jugador ve **siempre, antes de confirmar**: la probabilidad de éxito, el coste en Piedras de Resonancia, y la penalización en caso de fallo. Después de confirmar, una animación de suspenso (≈1.6s) precede al reveal del resultado con feedback visual diferenciado por tipo de outcome.

## Por qué (pilares)

**Pilar #2 — Nada debe sentirse aleatorio o injusto:**
- Probabilidad de éxito: número grande (32pt) y barra proporcional, coloreados por riesgo (verde/amarillo/rojo).
- Penalización: texto explícito antes del intento ("el item baja 1 nivel" / "se pierden los materiales").
- Anti-rage: contador de intentos en sesión visible en el header ("intentos: N") para que el jugador entienda que una cadena de fallos es estadísticamente normal.
- Resultado claro: 4 estados visuales distintos (éxito dorado / fallo gris / fallo rojo / protección azul).

## Cómo se integra

```
InventoryScreen (abierto)
  └── Botón "REFINAR (+X → +Y)" en panel de detalle del item seleccionado
        → InventoryScreen.close()
        → RefinementScreen.open(item)

RefinementScreen (CanvasLayer layer 25)
  ├── consume UpgradeManager.attempt_refine(item, use_scroll)
  ├── escucha InventorySystem.materials_changed → refresca coste/botón
  ├── escucha InventorySystem.item_added/removed → refresca lista
  └── emite nada hacia afuera (pantalla autocontenida)
```

**Trigger de apertura — Opción A (implementada):**
- El `InventoryScreen` muestra un botón "REFINAR (+X → +Y)" en la sección de detalle cuando el item seleccionado puede ser refinado.
- Al presionarlo: `InventoryScreen.close()` + `RefinementScreen.open(item_seleccionado)`.
- `InventoryScreen._get_refinement_screen()` resuelve el nodo en 3 pasos: path del inspector → búsqueda en árbol → instanciar escena en runtime.

**Trigger de testing — Opción C (provisional):**
- Tecla `R` abre la pantalla con el primer item refinable del inventario.
- TODO: remover o restringir a debug build antes de producción.

**Resolución de RefinementScreen desde InventoryScreen:**
1. `refinement_screen_path` asignado en Inspector.
2. Búsqueda recursiva en el árbol por clase `RefinementScreen`.
3. Instanciar `res://scenes/ui/refinement_screen.tscn` y agregar como hermano.

## Decisiones técnicas no obvias

### Barra de probabilidad con anchor_right
La barra se llena proporcionalmente usando `_chance_bar_fg.anchor_right = chance` dentro de un padre con `clip_contents = true`. Se usa `set_deferred` porque el tamaño del padre puede estar en 0 en el primer frame. Alternativa descartada: ProgressBar de Godot (más difícil de estilizar en mobile).

### Animación con Tween, no AnimationPlayer
Toda la animación de suspenso y resultado usa `create_tween()`. Razón: sin assets de AnimationPlayer, el Tween es suficiente, no agrega nodos extra al árbol y se destruye solo. El dots-tween (`Refinando. / .. / ...`) tiene 3 loops y dura `ANIM_SUSPENSE_DURATION` total.

### `_get_refinement_screen()` con fallback de instanciación
InventoryScreen no asume que RefinementScreen está en la escena. Lo resuelve en runtime. Esto permite que Leo agregue o no la escena en `world.tscn` sin romper nada — el botón aparece y funciona siempre.

### `close()` antes de `open()` en el trigger de inventario
El InventoryScreen cierra primero y luego abre el RefinementScreen. Esto evita que dos CanvasLayers pausen el árbol simultáneamente (doble `get_tree().paused = true`). Godot acepta múltiples pausas pero la lógica de "quién reanuda" se vuelve frágil.

### Scroll toggle deshabilitado vs oculto
Cuando el jugador no tiene Pergaminos y el target es +8/+9/+10, el `CheckBox` se muestra deshabilitado (no oculto). Esto informa que la opción existe y qué falta, en lugar de confundir con una opción que aparece y desaparece.

### Layer 25 (sobre InventoryScreen layer 20)
Si por alguna razón el jugador abre Refinamiento con InventoryScreen visible (caso edge), RefinementScreen siempre cubre al Inventario. Layer 10 = HUD, 20 = Inventory, 25 = Refinement.

## Layout en mobile vertical (wireframe)

```
┌─────────────────────────────────────────────┐ ← 88% ancho pantalla
│  REFINAMIENTO        intentos: N         [X]│ ← header 56dp, btn X 64×56dp
├──────────────────────┬──────────────────────┤
│  TUS ITEMS           │  ITEM SELECCIONADO   │
│ ┌──────────────────┐ │  [franja rareza]      │
│ │ [nombre item]    │ │  Espada de Hierro     │
│ │ sin refinar ATK  │ │  +3  →  +4            │
│ └──────────────────┘ │  ATK: 52  →  55       │
│ ┌──────────────────┐ ├──────────────────────┤
│ │ [nombre item]    │ │  PROBABILIDAD DE EXITO│
│ │ +3  DEF 40       │ │  ┌───┬─────────────┐ │
│ └──────────────────┘ │  │70%│ ████████░░░ │ │
│ ┌──────────────────┐ │  └───┴─────────────┘ │
│ │ [otro item]      │ ├──────────────────────┤
│ │ +5  BLQ 30       │ │  SI FALLA             │
│ └──────────────────┘ │  Se pierden los       │
│                      │  materiales usados.   │
│                      ├──────────────────────┤
│                      │  COSTE                │
│                      │  [■] Piedras: 2/1  OK │
│                      │  [■] Oro: 0  (N/A)    │
│                      ├──────────────────────┤
│                      │  (scroll toggle       │
│                      │   visible si +8/9/10) │
│                      ├──────────────────────┤
│                      │  (razón de bloqueo)   │
│                      │ [ INTENTAR REFINAR +4]│ ← btn 56dp alto
└──────────────────────┴──────────────────────┘
```

**Durante animación — overlay fullscreen sobre el panel:**
```
┌─────────────────────────────────────────────┐
│                                             │
│                                             │
│           Refinando...                      │
│                                             │
│                                             │
└─────────────────────────────────────────────┘

→ (1.6s después) →

┌─────────────────────────────────────────────┐
│                                             │
│           +4  EXITO                         │  ← dorado
│      El item subió a refinamiento +4        │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
```

## Hit areas

| Elemento | Mínimo | Real |
| :--- | :---: | :--- |
| Botón X (cerrar) | 44×44dp | 64×56dp |
| Botón "INTENTAR REFINAR" | 44×44dp | 56dp alto, 100% ancho |
| Filas de items en lista | 44×44dp | 56dp alto, 100% ancho columna |
| Checkbox del Pergamino | 44×44dp | 44dp alto declarado |
| Botón "REFINAR" en InventoryScreen | 44×44dp | 48dp alto, 100% ancho |

## Cómo testear manualmente

1. **Abrir sin items:** inventario vacío → RefinementScreen muestra "ninguno refinable" en la lista.
2. **Selección y preview:**
   - Agregar item R1 `stat_main=50` sin refinar → seleccionar → verificar que muestra "+0 → +1", "ATK: 50 → 52", "100%", "Nada. Este nivel es seguro."
3. **Probabilidad por nivel (Pilar #2):**
   - Item en +3 → target +4: probabilidad debe ser "70%", color amarillo, penalización "materiales".
   - Item en +7 → target +8: probabilidad "30%", color rojo, penalización "baja 1 nivel", scroll toggle visible.
4. **Coste — Piedras insuficientes:**
   - Sin Piedras de Resonancia → "Falta 1" en rojo, botón "INTENTAR" deshabilitado.
5. **Pergamino:**
   - Target +8, sin pergaminos → checkbox visible pero deshabilitado, count "Tenés: 0 (necesitás 1)".
   - Target +8, con 1 pergamino → checkbox activo, se puede marcar.
6. **Intento con éxito forzado:**
   - En `upgrade_manager.gd`: `_force_outcome = 1`, intentar → overlay dorado "EXITO", nivel sube.
7. **Intento con fallo level_loss sin pergamino:**
   - `_force_outcome = 0`, item en +7, target +8 → overlay rojo "FALLO", nivel baja a +6.
8. **Intento con fallo protegido por pergamino:**
   - `_force_outcome = 0`, item en +7, target +8, pergamino disponible y marcado → overlay azul "FALLO — Pergamino activo", nivel intacto.
9. **Trigger desde InventoryScreen:**
   - Abrir inventario, tap en item → panel detalle muestra "REFINAR (+0 → +1)" → tap → inventario cierra, refinamiento abre con el item preseleccionado.
10. **Anti-rage:** después de varios intentos en la misma sesión, el header muestra "intentos: N".

## Tests unitarios

No se agregaron tests unitarios adicionales — la lógica de UI no tiene estado testeable en aislamiento.
Los tests del backend siguen siendo los 12 de `tests/systems/upgrade_manager_test.gd`.

## Assets necesarios

| Asset | Prioridad | Delegar a |
| :--- | :---: | :--- |
| Icono de Piedra de Resonancia (reemplaza ColorRect azul) | Media | `art-prompt-engineer` |
| Icono de Pergamino de Protección | Media | `art-prompt-engineer` |
| Icono de Oro (para la fila de coste futura) | Baja | `art-prompt-engineer` |
| SFX éxito de refinamiento (burst épico) | Media | pipeline de audio (Suno) |
| SFX fallo de refinamiento (golpe seco) | Media | pipeline de audio |
| SFX activación de pergamino (brillo mágico) | Baja | pipeline de audio |
| Partículas de éxito (reemplaza Tween de color) | Baja | `godot-expert` |

## Archivos tocados

- **Creados:**
  - `scripts/ui/refinement_screen.gd`
  - `scenes/ui/refinement_screen.tscn`
  - `docs/features/ui/refinement_screen.md`
- **Modificados:**
  - `scripts/ui/inventory_screen.gd` — añadido botón "Refinar", variable `_refine_btn`, helper `_get_refinement_screen()`, handler `_on_refine_btn_pressed()`, actualización de `_refresh_detail()` y `_clear_detail()`.

## Pendientes / mejoras futuras

- [ ] SFX para éxito / fallo / protección pergamino (no hay pipeline de audio aún).
- [ ] Sprites de iconos para materiales (Piedra, Pergamino, Oro) — actualmente ColorRect placeholder.
- [ ] Partículas de éxito en overlay (Tween de color es suficiente para MVP pero visualmente pobre).
- [ ] Remover o restringir tecla `R` a debug build antes de producción.
- [ ] Implementar fila de Oro cuando `GoldSystem` esté disponible (hook ya está, gold siempre muestra 0).
- [ ] Vibración haptic (Android) en resultado — configurable on/off en Settings.
- [ ] Probar en celular Android real (no testeado en mobile — validar hit areas y scroll).
- [ ] `refinement_screen_path` en `inventory_screen.gd`: asignar en `world.tscn` para evitar búsqueda en árbol en producción.
