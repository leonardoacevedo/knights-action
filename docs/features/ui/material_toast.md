# Toast de Material Recogido

**Fecha de implementación:** 2026-05-25
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 2 (Drops por etapa)
**Sección GDD relevante:** §5.5 (Materiales), §12.1 (feedback de drops)
**Pilar(es) reforzado(s):** #1 (la build importa → ver qué drops llegan), #4 (5 minutos bastan → info legible de un vistazo)

---

## Qué hace

Muestra un toast no intrusivo en la esquina superior derecha del HUD cada vez que `InventorySystem` emite `material_added`. El toast apila drops del mismo material que lleguen en menos de 0.6 segundos (stacking inteligente). Hasta 4 toasts visibles simultáneos; el más viejo se evicta si llega un 5to. Lifetime de 2.5 s + fadeout de 0.4 s, con reset si llegan más drops durante la ventana.

## Por qué (pilares)

- **Pilar #1** — El jugador necesita saber qué materiales está farmando para evaluar si su build/ruta vale la pena. El toast es la retroalimentación inmediata de que los drops funcionan.
- **Pilar #4** — Información concisa arriba a la derecha, sin interrumpir el flujo de combate. Jugadores de 5 min entienden qué cayó; jugadores de 5 horas pueden contabilizar sin abrir el inventario.

## Cómo se integra

```
InventorySystem (autoload)
  └─ signal material_added(material, count)
        │
        ▼
MaterialToastContainer (Control hijo de HudCombat CanvasLayer)
  ├─ escucha signal, decide crear o acumular
  ├─ instancia MaterialToast (scene res://scenes/ui/material_toast.tscn)
  └─ VBoxContainer interno apila toasts verticalmente
        │
        ▼
MaterialToast (Control, nodo "tonto")
  ├─ Panel (fondo semitransparente, StyleBoxFlat, corners 6px)
  │   └─ HBoxContainer
  │       ├─ ColorRect placeholder (color por rareza, 48×48 px)
  │       ├─ Label "+N" (24pt, outline negro)
  │       └─ Label display_name (22pt, outline negro)
  ├─ Animación slide-in: 80px desde derecha + fadein, 0.2s, EASE_OUT TRANS_QUINT
  ├─ Animación pulso count: scale 1.0→1.3→1.0 al acumular, 0.25s total
  └─ Fadeout: alpha 1→0, 0.4s, luego queue_free + señal toast_finished
```

## Decisiones técnicas no obvias

- **No object pool**: con máximo 4 toasts simultáneos y duración 2.9 s, el overhead de instanciar/liberar es insignificante en mobile. Object pool agregaría complejidad sin beneficio medible en este volumen.
- **Nodo "tonto"**: `MaterialToast` no conoce `InventorySystem` ni al container. Toda la lógica de stacking/eviction vive en `MaterialToastContainer`. Facilita testeo y reemplazo futuro.
- **`_evict_oldest()` usa `queue_free()` directo** (no llama `_start_fadeout()`): como el método privado no es accesible desde el container, se optó por matar el nodo inmediatamente. El efecto visual es que el toast más viejo desaparece de golpe — aceptable porque el evict solo ocurre en rafadas de 5+ materiales distintos, situación de todos modos caótica en pantalla.
- **Posicionamiento del container** en `hud_combat.tscn`: `anchor_left=1.0`, `anchor_right=1.0`, `offset_left=-320`, `offset_right=-16`, `offset_top=24`. Queda flush a la derecha, a la misma altura que el HUD top, pero sin solapar el `StatsContainer` izquierdo (que termina en `offset_right=360`, lejos del borde derecho).
- **`_on_toast_finished` limpia `_active` por id**: es posible que entre el fadeout y la señal llegue un drop nuevo del mismo id y se cree un toast nuevo. En ese caso `_active[id]` apunta al nuevo toast; borrar por id es safe porque solo borramos si el id existe — si ya fue reemplazado, el entry nuevo queda intacto (el test `entry.get("toast") == oldest` en `_evict_oldest` garantiza lo mismo).

## Cómo testear manualmente

1. Abrir `scenes/world.tscn` en Godot.
2. Ejecutar la escena (F5). Matar un enemigo para disparar `DropSystem` → `InventorySystem.add_material`.
3. Verificar: aparece toast en esquina sup-derecha con icono de color, "+N" y nombre del material.
4. Matar otro enemigo del mismo tipo rápido (<0.6 s): el count debe sumar en el toast existente con pulso.
5. Con `GameConfig.PLATFORM_MODE = MOBILE`, verificar que el layout no choca con touch controls inferiores.
6. Forzar 5 materiales distintos rápido (desde el editor o un script de debug): el toast más viejo debe desaparecer para dar lugar al 5to.

Para test rápido sin matar enemigos, podés llamar desde el editor/debugger:
```gdscript
InventorySystem.add_material(load("res://resources/items/materials/piedra_resonancia.tres"), 3)
```

## Tests unitarios

No hay tests unitarios para esta feature (UI pura, difícil de testear en GUT sin mock del árbol de nodos). Validación manual per arriba.

## Assets necesarios

- **Iconos de materiales** (Texture2D por material): pendiente, delegar a `art-prompt-engineer`. El sistema ya maneja `icon == null` via placeholder de color.

## Archivos tocados

- `scripts/ui/material_toast.gd` — creado
- `scripts/ui/material_toast_container.gd` — creado
- `scenes/ui/material_toast.tscn` — creado
- `scenes/ui/material_toast_container.tscn` — creado (standalone, no en uso activo — el container se instancia directo en hud_combat.tscn)
- `scenes/ui/hud_combat.tscn` — modificado (agrega `MaterialToastContainer` como hijo de `HudCombat`)

## Pendientes / mejoras futuras

- Reemplazar `ColorRect` placeholder por `TextureRect` cuando lleguen los iconos (`art-prompt-engineer`).
- SFX suave al aparecer el primer toast por kill (cuando exista el pipeline de audio).
- Opción en Settings para desactivar toasts (accesibilidad).
- Diferenciar R4 legendario con animación extra (brillo / partículas) al aparecer — scope post-Fase 2.
