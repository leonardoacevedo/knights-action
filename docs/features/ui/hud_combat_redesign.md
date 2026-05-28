# HUD Combat — Redesign Spec v2

> **Spec mobile-first matching reference visual aprobada por Leo el 28/05/2026.**
> Implementación pendiente. NO ejecutar sin confirmación adicional de Leo (decisiones marcadas con ⚠️ requieren respuesta).

**Versión:** v2.0 spec
**Estado:** propuesta — esperar OK Leo en decisiones flagueadas
**Implementación target:** `scenes/ui/hud_combat.tscn` + `scripts/ui/hud_combat.gd`

---

## 1. Imagen referencia — elementos identificados

| Posición | Elemento | Función |
|---|---|---|
| Top-left | Avatar circular (Knight) + label "Knight (Nivel)" | Player identity + level |
| Top-left | HP bar verde gradient + número "75%" | Vida |
| Top-left | Maná bar azul gradient | Recurso skill |
| Top-left | Mini-icon "25" debajo | Currency / cargas (ambiguo) |
| Top-center | "Mundo 1: Valle de los Ecos - Etapa 6/10" | Stage info |
| Top-right | Avatar circular (boss) + nombre "Guerrero Corrupto" | Enemy info |
| Top-right | HP bar roja gradient | Enemy HP |
| Top-right | "Enemigo R2" label | Rareza |
| Mid-frame | Damage floater "+10 Maná" cyan con icono gota | Resource gain feedback |
| Bottom-left | Cruceta direccional gris + 4 flechas naranjas | Movement (touch) |
| Bottom-right | 5 chips circulares (Viento/Fuego/Tierra/AtkBásico/Flecha→) | Skills + basic attack + next |

---

## 2. Wireframe ASCII (resolución target: 1280×720 landscape — adaptar viewport actual 1152×648)

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ┌──┐ Knight (Nivel)         Mundo 1: Valle de los Ecos       Guerrero ┌──┐│
│ │AV│ ▓▓▓▓▓▓▓▓░░ 75%             Etapa 6/10                  Corrupto │AV││
│ └──┘ ▓▓▓▓▓▓▓▓▓▓ 100%                              ░░▓▓▓▓▓▓▓▓▓▓ R2 / └──┘│
│  25                                                                       │
│                                                                           │
│                  ┌─────────┐     +10 Maná                                 │
│                  │         │     ✦                                        │
│                  │ GAMEPLAY│                                              │
│                  │         │                                              │
│                  │  AREA   │                                              │
│                  │         │                                              │
│                  └─────────┘                                              │
│                                                                           │
│                                                                           │
│   ┌───┐                                                ◯ Viento  ┌→┐    │
│   │ ↑ │                                              ◯ Fuego ◉  └─┘    │
│   │   │                                              ◯ Tierra Atk     │
│   │←J→│                                                                │
│   │   │                                                                │
│   │ ↓ │                                                                │
│   └───┘                                                                │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Decisiones requeridas (Leo confirma antes de implementar)

### ✅ Decisión #1 — RESUELTA: Furia canon

**Contexto:** GDD §4.3 + glossary canon usa **Furia** como recurso de skills. La imagen muestra **Maná**.

**Decisión Leo 28/05:** **Mantener Furia**. La imagen es referencia visual de estilo, no de naming. Pilar #1 refuerza con concepto Furia (agresión recompensada).

**Implementación:** label "Furia" en HUD. Damage floater de gain dice "+10 Furia" (cyan). Code intacto.

### ✅ Decisión #2 — RESUELTA: 6 botones GDD canon + Atk Básico más grande

**Contexto:** GDD §4.2 define **6 botones**: 1 Atk + 3 Skill + 1 Dash + 1 Block. La imagen muestra 5.

**Decisión Leo 28/05:** **6 botones canon GDD §4.2** con **Atk Básico prominente más grande** (destaca como acción principal).

**Layout final:**

```
                                              ┌────┐ ┌────┐ ┌────┐
                                              │ S1 │ │ S2 │ │ S3 │   ← 3 skills circulares 56dp
                                              └────┘ └────┘ └────┘

                                          ┌────┐  ┌──────────┐  ┌────┐
                                          │Dash│  │  ATAQUE  │  │Blk │
                                          │    │  │  BÁSICO  │  │    │   ← Atk grande 72dp central
                                          └────┘  └──────────┘  └────┘     Dash + Block 56dp flanquean
```

- **Fila superior:** 3 chips circulares (Skill 1/2/3) — 56dp diameter
- **Fila inferior:** Dash (56dp izq) + Atk Básico (72dp center prominente) + Block (56dp der)

Atk Básico más grande = acción más usada destacada visualmente.

**Implementación:** Atk Básico custom_minimum_size = Vector2(72, 72). Border más grueso. Color sword/weapon icon dorado destacado.

### ✅ Decisión #3 — RESUELTA: C híbrido (PNG si existe, procedural fallback)

**Contexto:** imagen muestra portraits circulares con border ornamentado. Actualmente NO hay.

**Decisión Leo 28/05:** **C híbrido**. Código carga `Texture2D` si existe en path canon, sino dibuja procedural.

**Implementación:**
- Path canon player: `assets/art/portraits/player_knight.png` (256×256)
- Path canon bosses: `assets/art/portraits/boss_<id>.png` (256×256)
- `PortraitFactory.get_portrait(id) -> Texture2D | null` — autoload o helper
- Si returns null → render procedural circle + element color + initial letter
- Si returns Texture2D → use directamente

Permite generar IA gradual sin bloquear redesign.

### ✅ Decisión #4 — RESUELTA: ambos visibles

**Contexto:** imagen muestra "Mundo 1: Valle de los Ecos - Etapa 6/10". Currently HUD muestra Momentum top-center.

**Decisión Leo 28/05:** **los 2** — Stage label + Momentum ambos visibles top-center.

**Layout final top-center:**

```
┌─────────────────────────────────────────────────────┐
│   Mundo 1: Valle de los Ecos - Etapa 6/10           │  ← StageLabel font 12pt opacity 0.7
│                                                      │
│                    5x                                │  ← MomentumLabel font 48pt color escala
│                                                      │
└─────────────────────────────────────────────────────┘
```

- **StageLabel:** font 12pt, color blanco opacity 0.7, outline negro 2px. Top edge 16dp.
- **MomentumLabel:** font 48pt (existing), color escala 1→10 (existing), pulse + shake (existing). Debajo de StageLabel.

**Data sources:**
- StageLabel.text = `"Mundo %d: %s - Etapa %d/%d" % [StageManager.current_zone, zone_name, current_index+1, total_stages]`
- zone_name from `ZONE_NAMES` dict en world.gd o StageManager (verificar existe)

### ✅ Decisión #5 — RESUELTA: "25" = nivel del personaje

**Contexto:** Leo confirmó 28/05 — el "25" es el **nivel del personaje** (PlayerProgression.get_current_level()).

**Implementación:**
- Badge dorado debajo del avatar circular (matching imagen)
- Tamaño: 32×32 dp circular con border dorado `#D4A04D`
- Font: 16pt bold blanco con outline negro
- Fuente del dato: `PlayerProgression.get_current_level()`
- Update via signal `level_changed(level)` en PlayerProgression (verificar API existe — sino conectar a `xp_gained` y read level cada vez)

El label "Knight (Nivel)" del header es solo indicador semántico — display real puede ser "Knight" + badge separado con número grande, O inline "Knight Lv.25". Mi recomendación: **badge separado prominente** (más cerca de imagen).

**Nota:** esto elimina la sección "Gold display" del HUD top-left. Gold queda solo visible en pantalla de inventario/crafting/refinamiento. Si Leo quiere Gold también en HUD combat, decir.

---

## 4. Spec implementación (assumiendo decisiones A/C/C/B/Gold)

### 4.1 Estructura escena `hud_combat.tscn`

```
HudCombat (CanvasLayer)
├── TopRow (HBoxContainer, anchors top stretch)
│   ├── PlayerInfo (HBoxContainer)
│   │   ├── PlayerAvatar (Control 64×64)
│   │   │   ├── Frame (Polygon2D circular + Line2D ring border)
│   │   │   ├── PortraitFill (procedural color por elemento equip)
│   │   │   └── LevelLabel (top-right corner badge)
│   │   ├── StatsColumn (VBoxContainer)
│   │   │   ├── NameLabel ("Knight")
│   │   │   ├── HPRow (HBoxContainer)
│   │   │   │   ├── HPBarBG (Panel + ColorRect FG gradient verde)
│   │   │   │   └── HPLabel ("75%" overlay center)
│   │   │   └── FuriaRow (similar — gradient azul)
│   │   ├── LevelBadge (Control 32×32 dorado)
│   │   │   ├── Frame (Polygon2D circular + Line2D ring border)
│   │   │   └── LevelNumber (Label grande "25")
│   │   └── ShieldChargesRow (existing component)
│   ├── CenterColumn (VBoxContainer)
│   │   ├── StageLabel ("Mundo 1: Valle de los Ecos - Etapa 6/10", font 12pt, opacity 0.7)
│   │   └── MomentumLabel (existing — font 48pt, color escala)
│   └── EnemyInfo (HBoxContainer mirror del PlayerInfo)
│       └── (similar — populated solo cuando hay boss/elite activo)
├── DamageFloaterLayer (Node2D)
│   └── (spawned por DamageFloater autoload existente)
├── BottomLeft (Control)
│   └── VirtualJoystick (existing, sin cambios)
├── BottomRight (Control)
│   ├── SkillChipsRow (HBoxContainer)
│   │   ├── SkillChip[0] (existing — Skill 1)
│   │   ├── SkillChip[1] (Skill 2)
│   │   └── SkillChip[2] (Skill 3)
│   └── ActionsRow (HBoxContainer)
│       ├── BasicAttackButton (existing)
│       ├── DashButton (existing)
│       └── BlockButton (existing)
└── BackToMenuButton (existing, sin cambios)
```

### 4.2 Hit areas + medidas (mobile-safe per ux-mobile rules)

| Elemento | Tamaño mínimo | Margen separación |
|---|---|---|
| PlayerAvatar | 64×64 dp | — |
| LevelBadge (player) | 32×32 dp circular | 4 dp debajo avatar |
| EnemyAvatar | 64×64 dp | — |
| HP/Furia bars | 120×16 dp cada una | 2 dp |
| SkillChip (circular) | **56×56 dp** | **8 dp** |
| BasicAttackButton | **64×64 dp** | 8 dp del primer SkillChip |
| DashButton | 56×56 dp | 8 dp |
| BlockButton | 56×56 dp | 8 dp |
| Joystick total area | 160×160 dp | 16 dp del borde |

Todos cumplen Material 48dp mínimo. Skill chips y BasicAttack más grandes (sobre el promedio) porque son los más usados.

### 4.3 Estilo visual matching reference

**Bars (HP / Furia / Enemy HP):**
- Background: rounded rectangle 12 dp radius, color `#0A0A14` con alpha 0.85, border 1px color `#FFFFFF22`
- Foreground gradient:
  - HP: verde `#52B788` (start) → verde más oscuro `#2D6A4F` (end), gradient horizontal
  - Furia: azul `#48CAE4` (start) → azul oscuro `#003B5C` (end)
  - Enemy HP: rojo `#C9302C` (start) → carmesí `#8B0000` (end)
- Texto número overlay centrado con outline negro 2px

**Avatares (placeholder procedural ahora):**
- Circle 64dp diameter
- Border ring 2dp width, color dorado `#D4A04D`
- Fill interior: gradient radial centro→borde, colores según elemento equipado (TIERRA = verde, FUEGO = rojo, etc.)
- Letra grande inicial del personaje (K para Knight, primera letra del enemy class)
- Pequeño badge nivel top-right (Level number)

**Skill chips:**
- Circle 56dp
- Border 2dp color elemento del skill
- Fill: gradient radial color elemento con alpha 0.85
- Center: 3 letras short del display_name (current implementation)
- CD overlay (current implementation) — semitransparente desde arriba

**Stage label:**
- Font 12pt, color `#FFFFFF` opacity 0.7
- Posición: top-center, 16dp del top edge
- Background: opcional rounded rect `#0A0A14` alpha 0.5 padding 8dp para legibilidad sobre cualquier fondo

**Momentum label (existing):**
- Mantener implementación actual (color escala + outline + pulse)
- Mover ligeramente abajo del stage label

### 4.4 Damage floaters

**Existing:** `DamageFloater.spawn_text(scene, pos, text, color)` ya funciona para "BLOCK!" etc.

**Mejora propuesta:** soporte para resource gain visual (Furia +10):
- Color cyan `#48CAE4`
- Icono pequeño gota o cristal antes del texto
- Float up + fade out (current behavior)

Implementación: extender `DamageFloater.spawn_resource_gain(scene, pos, amount, resource_type)` con icono. **Trabajo de godot-expert** cuando se implemente.

### 4.5 Mobile responsive

Resoluciones target:
- **1080×2400** (Android portrait modern) → adaptar via anchors %
- **1280×720** (PC playtest)
- **1170×2532** (iPhone 13/14)
- **812×375** (iPhone SE pequeño — peor caso)

**Reglas:**
- Top row siempre ocupa ~12% altura
- Bottom rows ocupan ~25% altura (más para touch comfort)
- Gameplay area ~63% mínimo
- Anchors en porcentajes, no offsets fijos

---

## 5. Implementation plan (por orden)

### Fase 1 — Quick win visible
1. Crear `PlayerAvatar` procedural (~50 líneas GDScript en hud_combat.gd)
2. Mejorar `_hp_bar_fg` con gradient (set_gradient via Theme override)
3. Agregar `StageLabel` top-center
4. Test in editor (sin run-time validation) — Leo confirma estética antes de seguir

**Esfuerzo:** 1-2h. Cero rompe regresiones.

### Fase 2 — Enemy info top-right
5. Crear `EnemyInfo` mirror del PlayerInfo
6. Conectar a primer enemy "registered" del stage actual via StageManager (el primer R2/R3/R4)
7. Si no hay enemy elite, ocultar EnemyInfo
8. Test in editor — Leo confirma

**Esfuerzo:** 2h. Riesgo bajo (no toca lógica existente, solo lee state).

### Fase 3 — Reorganizar skill chips + acciones
9. Mover skill chips a fila superior bottom-right
10. Acomodar BasicAttack + Dash + Block fila inferior
11. Conectar SkillChip[i] color al elemento del skill (PlayerSkillData.color)
12. Test in editor — Leo confirma

**Esfuerzo:** 1h. Reorganización de nodos existentes, no nueva lógica.

### Fase 4 — Polish + assets (cuando lleguen IA portraits)
13. Swap procedural portraits → texturas IA
14. Implement gold display si Leo confirma decisión #5
15. Implement damage floater resource gain
16. Verify mobile real device test (delegar Leo)

**Esfuerzo:** depende de assets IA. Bloqueado por pipeline arte.

---

## 6. Quick win snippet (opcional, no aplicar todavía)

> Pseudocode del PlayerAvatar procedural. **NO escribir en repo hasta OK Leo.**

```gdscript
# En hud_combat.gd, agregar método

func _build_player_avatar() -> Control:
    var holder := Control.new()
    holder.custom_minimum_size = Vector2(64, 64)
    holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

    # Circle frame ring (border dorado)
    var ring := Line2D.new()
    ring.width = 3.0
    ring.default_color = Color(0.83, 0.62, 0.30, 0.95)  # dorado #D4A04D
    ring.closed = true
    for i in range(24):
        var ang := i * TAU / 24.0
        ring.add_point(Vector2(32 + cos(ang) * 30, 32 + sin(ang) * 30))
    holder.add_child(ring)

    # Fill interior (gradient por elemento — placeholder verde TIERRA por ahora)
    var fill := Polygon2D.new()
    fill.color = Color(0.32, 0.72, 0.53, 0.90)  # verde TIERRA
    var pts := PackedVector2Array()
    for i in range(24):
        var ang := i * TAU / 24.0
        pts.append(Vector2(32 + cos(ang) * 28, 32 + sin(ang) * 28))
    fill.polygon = pts
    holder.add_child(fill)

    # Inicial del personaje
    var letter := Label.new()
    letter.text = "K"
    letter.add_theme_font_size_override("font_size", 32)
    letter.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    letter.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
    letter.add_theme_constant_override("outline_size", 4)
    letter.size = Vector2(64, 64)
    letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    holder.add_child(letter)

    # Level badge top-right
    var level_badge := PanelContainer.new()
    level_badge.custom_minimum_size = Vector2(22, 22)
    level_badge.anchor_left = 1.0
    level_badge.anchor_top = 0.0
    level_badge.offset_left = -22.0
    level_badge.offset_right = 0.0
    level_badge.offset_top = -4.0
    level_badge.offset_bottom = 18.0
    var bg_style := StyleBoxFlat.new()
    bg_style.bg_color = Color(0.83, 0.62, 0.30, 0.95)
    bg_style.corner_radius_top_left = 11
    bg_style.corner_radius_top_right = 11
    bg_style.corner_radius_bottom_left = 11
    bg_style.corner_radius_bottom_right = 11
    level_badge.add_theme_stylebox_override("panel", bg_style)
    var level_label := Label.new()
    level_label.text = str(PlayerProgression.get_current_level())
    level_label.add_theme_font_size_override("font_size", 11)
    level_label.add_theme_color_override("font_color", Color(0, 0, 0, 0.95))
    level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    level_badge.add_child(level_label)
    holder.add_child(level_badge)

    return holder
```

---

## 7. Assets necesarios (delegar `art-prompt-engineer`)

Cuando se confirme decisión #3 sobre portraits:

| Asset | Tamaño | Notas |
|---|---|---|
| Player Knight portrait | 256×256 PNG | T-pose busto, mismo estilo canon visual |
| Boss Guardián portrait | 256×256 PNG | Busto frontal |
| Boss Ignis portrait | 256×256 PNG | Igual |
| Boss Lyss portrait | 256×256 PNG | Igual |
| Boss Vael portrait | 256×256 PNG | Igual |
| Boss Duelista portrait | 256×256 PNG | (R4 genérico Melee) |
| Boss Cazadora portrait | 256×256 PNG | (R4 genérico Archer) |
| Boss Heraldo portrait | 256×256 PNG | (R4 genérico Mage) |
| Capitán de los Vientos portrait | 256×256 PNG | Mini-boss zona 4 |
| Mini icon coin (gold) | 32×32 PNG | Dorado |
| Mini icon drop (resource gain floater) | 32×32 PNG | Cyan cristal |

Total: ~11 assets. Esfuerzo Gemini ~1h.

---

## 8. Riesgos identificados

| Riesgo | Mitigación |
|---|---|
| Romper layout actual sin testear en mobile | Fase 1 conservadora, Leo valida en editor antes de seguir |
| Decisión naming Furia/Maná inconsistente | NO implementar sin OK Leo (decisión #1) |
| Skill chips circular más grandes ocupan mucho espacio bottom-right | Acomodar fila inferior compacta con Atk/Dash/Block |
| Avatar procedural se ve mal vs imagen referencia | Aceptar como placeholder. Swap a IA cuando pipeline arte avance |
| StageManager.current_zone + current_stage no expone display_name fácil | Verificar API antes de implementar StageLabel |

---

## 9. Pendientes ANTES de implementar

1. ✅ **Decisión #1 — RESUELTA: Furia canon (Leo 28/05)**
2. ✅ **Decisión #2 — RESUELTA: 6 botones GDD + Atk Básico grande (Leo 28/05)**
3. ✅ **Decisión #3 — RESUELTA: C híbrido PNG si existe + procedural fallback (Leo 28/05)**
4. ✅ **Decisión #4 — RESUELTA: Stage + Momentum ambos top-center (Leo 28/05)**
5. ✅ **Decisión #5 — RESUELTA "25" = nivel personaje (Leo 28/05)**

Esperar respuesta #3 antes de aplicar Fase 1.

---

## 10. Testing pendiente

- [ ] Probar en celular real Android (no PC) — Riesgo #2 GDD §14
- [ ] Validar contrast HP/Furia bars sobre cualquier background del parallax
- [ ] Validar legibilidad stage label sobre cualquier zona
- [ ] Validar tamaño touch targets en 5.5" pantalla mínima
- [ ] Validar latencia tap → feedback visual <50ms

## 11. Cierre

```
PANTALLA / COMPONENTE: HUD Combat redesign v2 (matching reference image)
RESOLUCIÓN TESTEADA: NINGUNA — spec only, esperar OK Leo
ASSETS NECESARIOS: 11 (portraits + icons) — pendiente Gemini
TESTEAR EN MOBILE: SÍ — obligatorio antes de cerrar implementación
DECISIONES PENDIENTES LEO: 5 (Furia/Mana, chips count, portraits, stage label, mini-icon)
```
