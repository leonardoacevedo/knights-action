# Feature: Controles Touch

**Estado:** Implementado — Fase 1  
**Fecha:** 2026-05-23  
**Archivos principales:**
- `scripts/ui/virtual_joystick.gd`
- `scripts/ui/touch_button.gd`
- `scenes/ui/virtual_joystick.tscn`
- `scenes/ui/touch_button.tscn`
- `scenes/ui/touch_controls.tscn`

---

## Descripción

Sistema de controles táctiles para mobile (iOS/Android). Consiste en un joystick virtual bottom-left y tres botones de acción bottom-right. Todo se encapsula en un `CanvasLayer` separado (`TouchControls`) instanciado al final de `world.tscn`. No modifica `player.gd` ni el input map existente.

---

## Componentes

### VirtualJoystick (`scripts/ui/virtual_joystick.gd`)

Nodo `Control` que:

1. Captura `InputEventScreenTouch` / `InputEventScreenDrag` para touch real.
2. Captura `InputEventMouseButton` / `InputEventMouseMotion` como fallback en PC (no requiere configuración adicional, funciona directamente con mouse).
3. Trackea el `touch_index` del primer dedo que entró en la zona; otros dedos (botones) son índices distintos — multitouch sin conflicto.
4. Calcula dirección normalizada y llama `Input.action_press` / `Input.action_release` según umbrales:
   - `direction.x > 0.3` → `ui_right`
   - `direction.x < -0.3` → `ui_left`
   - `direction.y < -0.5` → `ui_accept` (salto)
5. Dibuja con `_draw()`: círculo base (radio 80 dp, alpha 15%) + knob (radio 40 dp, alpha 55%).
6. Emite señal `direction_changed(direction: Vector2)` por si algún sistema futuro necesita polling.

**Hit area:** `custom_minimum_size = Vector2(160, 160)` — 160×160 dp, supera el mínimo recomendado.

### TouchButton (`scripts/ui/touch_button.gd`)

Nodo `Control` reutilizable con `@export`:
- `action_name: StringName` — action de Godot a simular.
- `label_text: String` — carácter visible dentro del botón.
- `color_normal / color_pressed: Color` — feedback visual de estado.
- `visual_radius: float` — radio del círculo dibujado (por defecto 38 dp).

Soporta múltiples dedos simultáneos sobre el mismo botón (array `_touch_indices`). Release solo ocurre cuando todos los dedos levantan.

**Hit area:** `custom_minimum_size = Vector2(90, 90)` — 90×90 dp, supera Material 48×48 dp y Apple HIG 44×44 dp.

### TouchControls (`scenes/ui/touch_controls.tscn`)

`CanvasLayer` en capa 10 (encima del HudCombat que usa capa por defecto = 1). Contiene:

```
TouchControls (CanvasLayer, layer=10)
└── SafeAreaContainer (Control, full-screen anchor)
    ├── JoystickZone (Control, 240×240 dp, bottom-left, offset 24 dp desde borde)
    │   └── VirtualJoystick (instancia, ocupa toda la zona)
    └── ButtonsContainer (Control, 280×260 dp, bottom-right, offset 24 dp desde borde)
        ├── BtnJump   — ui_accept, verde,  top-center  (offset: 95,0)
        ├── BtnDash   — dash,      cyan,   bottom-left (offset: 0,170)
        └── BtnAttack — attack,    rojo,   bottom-right(offset: 190,170)
```

**Separación entre botones:** mínimo 100 dp entre centros (knobs de 38 dp × 2 = 76 dp + 24 dp margen) — evita fat-finger errors.

---

## Layout en pantalla (1080×2400)

```
┌────────────────────────────────────┐
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│                                    │
│  ┌─────────┐          ┌──┐        │
│  │         │          │J │        │
│  │  VJOY   │     ┌──┐ └──┘ ┌──┐  │
│  │  160px  │     │D │      │A │  │
│  └─────────┘     └──┘      └──┘  │
│   24dp margin         24dp margin │
└────────────────────────────────────┘
```

- Joystick: esquina inferior izquierda, 24 dp de margen de pantalla.
- Botones en arco diagonal: J arriba-centro, D abajo-izq, A abajo-der.
- Separación joystick ↔ botones: ~40% del ancho de pantalla — sin overlap en ninguna resolución >360 dp de ancho.

---

## Compatibilidad con teclado

No se modificaron las actions existentes (`attack`, `dash`, `ui_left`, `ui_right`, `ui_accept`, `ui_jump`). Los scripts Touch solo llaman `Input.action_press/release`, que se suma al estado de la action sin reemplazar los eventos de teclado. Teclado y touch funcionan simultáneamente.

---

## Configuración de project.godot

Se agregó:

```ini
[input_devices]
pointing/emulate_touch_from_mouse=true
```

Esto permite que el mouse en PC emule `InputEventScreenTouch` / `InputEventScreenDrag`, haciendo que el joystick funcione también por click-drag sin tocar `player.gd` ni el input map.

**AVISO para el agente equipment-system:** si también editaste `project.godot`, la sección `[input_devices]` es nueva — no rompe el resto. Hacer merge manual de las dos versiones si hubo conflicto.

---

## Decisiones técnicas

| Decisión | Razón |
| :--- | :--- |
| `Input.action_press/release` en lugar de inyectar InputEvents | Más simple. Player.gd no necesita cambios. Compatible con `is_action_just_pressed` solo si press y release no ocurren en el mismo frame — lo cual se garantiza porque press está en touch down y release en touch up (eventos separados). |
| Mouse como fallback adicional (no solo emulación engine) | `emulate_touch_from_mouse` debería ser suficiente, pero el handler de mouse en los scripts sirve como seguro extra si la opción de proyecto no está activa. |
| `CanvasLayer` independiente | Permite toggle fácil futuro (`visible = false`), sin tocar HudCombat. Layer 10 garantiza que queda encima del HUD (layer 1). |
| `mouse_filter = 2` en containers y labels | Evita que los nodos contenedores o las Labels consuman eventos de mouse/touch antes de que lleguen a los botones. |
| Dibujo procedural con `_draw()` | Sin assets externos. Performance: `draw_circle` es barato. `queue_redraw()` solo cuando cambia estado — no cada frame. |
| Joystick base flotante (sigue al primer toque) | Más ergonómico en mobile que base fija — el jugador no necesita posicionar el dedo exactamente. |

---

## Validación (traza mental)

1. **Touch en joystick → drag derecha:** `_touch_index = 0`, `_update_knob(pos)`, `direction.x > 0.3` → `Input.action_press("ui_right")`. Player detecta `get_axis("ui_left","ui_right") = 1.0`. OK.
2. **Touch en BtnAttack:** `_is_inside_zone(pos)` true, `_press()` → `Input.action_press("attack")`. Player detecta `is_action_just_pressed("attack")` en siguiente frame. OK.
3. **Simultáneo joystick + botón:** joystick tiene `_touch_index = 0`; botón recibe dedo con índice 1 — paths independientes, sin conflicto. OK.
4. **Soltar dedo del botón:** `_handle_screen_touch(event.pressed=false)` → `_touch_indices.erase(index)` → si vacío: `_release()` → `Input.action_release("attack")`. OK.
5. **PC con mouse:** `emulate_touch_from_mouse=true` convierte clicks en ScreenTouch. El handler de mouse en scripts actúa como doble seguro. OK.

---

## Limitaciones conocidas / backlog

- Sin feedback de vibración (haptics). Agregar cuando Leo confirme que quiere vibración configurable.
- Sin animación de pulso al press (`<50 ms` recomendado en spec UX). Por ahora el cambio de color es inmediato (suficiente para MVP).
- Botón Block no está incluido: no existe todavía en `player.gd`. Agregar cuando se implemente Bloqueo (GDD §4.3).
- No testeado en celular real — **validar en Android físico antes de cerrar Fase 1** (Riesgo #2 del GDD §14).

---

## Assets necesarios (futuro)

Actualmente todo procedural. Cuando se sume arte:
- Sprite para base del joystick (círculo con textura).
- Sprite para knob del joystick.
- Iconos para botones (espada, rayo, flecha → reemplaza las letras A/D/J).

Delegar a `art-prompt-engineer` cuando llegue el momento.
