# Prompts de arte — Expansión: accesorios elementales + Z1/Z6/Z7

> **PROPUESTA Fase 4+. GDD v2.2.** Prompts ready-to-paste, pipeline = [`canon_estilo_visual.md`](canon_estilo_visual.md).
>
> Este doc **no es canon todavía** y no toca código, `.tres`, otros docs ni imágenes. Es el insumo de arte para el contenido visual nuevo de la expansión a 7 zonas ([`../../design/expansion-elemental-7-zonas.md`](../../design/expansion-elemental-7-zonas.md)). Toda generación sigue el estilo master, las reglas anti-error de Gemini y los tamaños de capa del canon — **se reusa el template, no se deriva** (Riesgo #5 GDD §14: inconsistencia visual).
>
> **Idioma:** los prompts van en INGLÉS (matchea el canon §7 — Gemini entiende mejor). NO traducir, NO modificar, pegar tal cual. El texto explicativo va en español.

---

## 0. Cómo usar este doc

Dos bloques de contenido nuevo:

- **A) Accesorios elementales** (anillo / amuleto / alas) — son item-icons con alpha real, no parallax. Cada categoría tiene **1 prompt-template** con su silueta/estilo base mobile-friendly. La variación por elemento (AGUA/FUEGO/TIERRA/VIENTO/LUZ/SOMBRA) se inyecta vía la **tabla de variación elemental** (§A.1): reemplazás los tokens `[[ELEMENT]]`, `[[PALETTE]]`, `[[MOTIF]]` en el template. 3 templates × 6 elementos = 18 íconos sin escribir 18 prompts gigantes.
- **B) Backgrounds de 3 zonas nuevas** (Z1 Ruinas de Borde, Z6 Faro del Cenit, Z7 Sello del Fondo) — mismo pipeline parallax de 4 capas que zonas 2/3/4 del canon. Prompts completos por capa.

**Pipeline post-generación:** idéntico a canon §6 (verificar dimensiones + alpha con `sips`/PIL, `tools/scripts/clean_gemini_alpha.py` si fake alpha, crop bottom-left si watermark, reemplazar en `assets/art/<zona>/...` para reimport de Godot). No se repite aquí.

---

## A. Accesorios elementales (anillo / amuleto / alas)

Los 3 slots nuevos (D17/D19 de la propuesta) son **elementales**: 6 estilos cada uno, 1 por elemento. Estrategia: **template por categoría + inyección elemental**, no 18 prompts repetidos.

### Convención de tamaño y naming

Los accesorios son **item-icons**, no capas de parallax — no entran en la grilla BG/MID/FORE. Tamaño icon **square 512×512** con alpha real (legible a tamaño chico de inventario/loot-card mobile, escala bien hacia abajo). Naming espejo del canon (`<tipo>_<slot>_<elemento>_512x512.png`):

```
ring_anillo_<elemento>_512x512.png      (ej. ring_anillo_fuego_512x512.png)
amulet_amuleto_<elemento>_512x512.png
wings_alas_<elemento>_512x512.png
```

`<elemento>` ∈ `{agua, fuego, tierra, viento, luz, sombra}`.

### A.1 Tabla de variación elemental (se inyecta al template)

Reemplazá los 3 tokens del template por la fila del elemento. Paletas tomadas de las zonas canon (§2) + colores propuesta. **El color de rareza NO va acá** — va aparte en §A.5 (borde/glow R1-R7), porque el mismo ícono se reusa en las 7 rarezas cambiando solo el tratamiento de borde.

| `[[ELEMENT]]` | `[[PALETTE]]` (núcleo del material) | `[[MOTIF]]` (forma/efecto característico) |
|:--|:--|:--|
| **AGUA** | glacial cyan (#48CAE4), deep ocean blue (#003B5C), soft white ice highlights | flowing water curves, frozen droplets, glacial crystal facets, gentle cyan inner glow |
| **FUEGO** | brasa red (#C9302C), molten orange (#FF6B35), molten gold core (#FFD700) | live ember core, cracked-coal texture with glowing seams, rising heat wisps |
| **TIERRA** | deep saturated green (#2D6A4F, #52B788), warm gold (#D4A04D), deep brown (#6F4E37) | living roots wrapping the form, mossy stone, embedded floating yellow crystal |
| **VIENTO** | bone white (#EAEAEA), pale storm gray, lightning blue accent (#90E0EF) | swirling wind streaks, trailing feathers, a small contained lightning arc |
| **LUZ** | blinding gold (#FFB703, #FFD60A), bone white (#EAEAEA) | radiant halo rays, ceremonial engraved sigils, serene blinding core glow |
| **SOMBRA** | deep violet-black (#1A0A2E), muted purple (#5A189A), faint cold edge light | seeping shadow tendrils, void core that swallows light, thin cold rim light only |

> **Acentos cruzados del canon:** Z1 no tiene carga elemental (no aplica a accesorios — los accesorios siempre son elementales). LUZ/SOMBRA son el eje cósmico (§3.1): LUZ = santidad ceremonial cegadora, SOMBRA = sombra que filtra, núcleo que traga luz. Mantener ese contraste en el motivo.

### A.2 Template — ANILLO (`ring`)

Silueta base: aro ornamentado con gema/núcleo elemental engarzado al frente. Compacto, lectura de silueta circular clara a tamaño chico. **Las alas son más vistosas que esto** (ver §A.4) — el anillo es el accesorio más sobrio.

```
Generate a 2D vector game art ITEM ICON for a fantasy RPG mobile game.
Output dimensions: exactly 512 pixels wide by 512 pixels tall.
Square format, 1:1 aspect ratio, centered single object.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

SUBJECT: A single ornate fantasy RING, shown at a slight three-quarter angle
so the band and the front gem are both readable. An ornamented metal band
holding one prominent elemental gem/core at the front. The gem is the focal
point. Compact, bold, clean silhouette that reads clearly at small inventory
size on a phone screen. Element: [[ELEMENT]]. Palette: [[PALETTE]].
Elemental treatment: [[MOTIF]], applied to the gem core and subtly to the
band engraving. NO background scenery. NO hand or finger wearing it.

COMPOSITION: Single ring centered in frame, occupying the central 70% of the
canvas with even padding of transparency around it. No other objects.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any scenery, table, hand, finger, or display stand.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the ring.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any rarity frame or glow yet (rarity treatment added separately).
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the single ring should be visible against full transparency.
  Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

### A.3 Template — AMULETO (`amulet`)

Silueta base: pendiente/medallón colgando de una cadena corta, con núcleo elemental central. Lectura vertical, gema central como foco.

```
Generate a 2D vector game art ITEM ICON for a fantasy RPG mobile game.
Output dimensions: exactly 512 pixels wide by 512 pixels tall.
Square format, 1:1 aspect ratio, centered single object.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

SUBJECT: A single ornate fantasy AMULET (pendant) hanging from a short
metal chain loop at the top. An ornamented metal frame holds one glowing
elemental core at its center, the focal point. Symmetric, vertical, bold
clean silhouette that reads clearly at small inventory size on a phone
screen. Element: [[ELEMENT]]. Palette: [[PALETTE]]. Elemental treatment:
[[MOTIF]], radiating from the central core and tracing the metal frame.
NO background scenery. NO neck or character wearing it.

COMPOSITION: Single amulet centered, hanging from its top chain loop,
occupying the central 70% of the canvas with even transparent padding.
No other objects.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any scenery, neck, character, or display stand.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the amulet.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any rarity frame or glow yet (rarity treatment added separately).
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the single amulet should be visible against full transparency.
  Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

### A.4 Template — ALAS (`wings`) — las más vistosas

Las alas son cosmético + stat (slot de utilidad, fuera del set bonus por D18/D19) → son la pieza **más vistosa**: par de alas simétricas desplegadas, materializadas en energía del elemento, más espectaculares y luminosas que anillo/amuleto. Aun así, silueta legible a tamaño chico (par simétrico abierto = lectura inmediata).

```
Generate a 2D vector game art ITEM ICON for a fantasy RPG mobile game.
Output dimensions: exactly 512 pixels wide by 512 pixels tall.
Square format, 1:1 aspect ratio, centered single object.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

SUBJECT: A spectacular pair of symmetric fantasy WINGS, fully spread open
and shown from the front/back, the most eye-catching cosmetic equipment
piece in the game. The wings are made of materialized elemental energy and
ornate structure, glowing and dramatic, clearly more flashy and luminous
than a ring or amulet. Symmetric left-right, bold readable open-wing
silhouette that still reads clearly at small inventory size on a phone
screen. Element: [[ELEMENT]]. Palette: [[PALETTE]]. Elemental treatment:
[[MOTIF]], forming the feather/membrane shapes and a luminous energy aura
around the wing edges. NO character body between the wings. NO background
scenery.

COMPOSITION: Pair of wings spread symmetrically, centered, occupying the
central 80% of the canvas with even transparent padding. The space between
the two wings is empty transparency (no body). No other objects.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any character body, torso, or figure between the wings.
- DO NOT draw any scenery, sky, or display stand.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the wings.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any rarity frame or glow yet (rarity treatment added separately).
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the symmetric pair of wings should be visible against full
  transparency. Everything else (including the gap between wings) must be
  alpha = 0.
- Output as PNG file with alpha channel preserved.
```

### A.5 Tratamiento de color de rareza (R1-R7) — borde/glow

El **mismo ícono base** se reusa en las 7 rarezas; lo único que cambia es el **borde + glow** según el tier (colores de §2.7 de la propuesta — D21). Recomendación de pipeline: aplicar el borde/glow en **post** (Godot shader/overlay o capa en editor) para no regenerar 7× por elemento. Si se quiere generar variantes con IA, inyectar el bloque de abajo al template (reemplaza la línea `DO NOT add any rarity frame or glow yet`).

| Tier | Nombre | Color borde/glow | Hex (§2.7) | Intensidad sugerida |
|:--:|:--|:--|:--|:--|
| R1 | Común | gris | `#9d9d9d` | borde fino, sin glow |
| R2 | Raro | verde | `#1eff00` | borde + glow tenue |
| R3 | Súper raro | azul | `#0070dd` | borde + glow medio |
| R4 | Ultra raro | naranja | `#ff8000` | borde + glow medio-alto |
| R5 | Épico | morado | `#a335ee` | glow notorio + leve aura |
| R6 | Legendario | dorado | `#ffd700` | glow fuerte + partículas sutiles |
| R7 | Mítico | rojo | `#e60000` | glow máximo + aura pulsante |

**Snippet inyectable (rareza por IA, opcional)** — reemplazar `[[RARITY_COLOR]]` y `[[RARITY_HEX]]`:

```
RARITY TREATMENT: add a clean outer glow and a thin rim border around the
object silhouette in [[RARITY_COLOR]] ([[RARITY_HEX]]). The glow is a soft
halo hugging the object edge only — it must NOT become a rectangle, frame,
or background fill. Keep everything outside the glow fully transparent
(alpha = 0). DO NOT add any rectangular border or framed card.
```

---

## B. Backgrounds — Z1 / Z6 / Z7 (parallax 4 capas, pipeline canon)

Mismo pipeline que zonas 2/3/4 del canon §7: **4 capas** por sub-zona con los tamaños canónicos.

| Capa | Tamaño PNG | Aspect | Alpha |
|---|---|---|---|
| **BG** | 1920×1080 | 16:9 | opaco (full background) |
| **MID** | 1280×720 | 16:9 | alpha real (transparente) |
| **FORE_TOP** | 1280×360 | 32:9 | alpha real (anclado arriba, mitad inferior transparente) |
| **FORE_BOTTOM** | 1280×360 | 32:9 | alpha real (anclado piso, mitad superior transparente) |

Naming espejo del canon (`bg_<zona>_<capa><subzona>_<motivo>_<tamaño>.png`). Acá se dan los **4 prompts de sub-zona `a`** por zona (intro). Sub-zonas `b`/`c` se derivan variando paleta/densidad igual que en el canon (mismo template, no nuevos prompts).

---

### B.1 Zona 1 — Ruinas de Borde (NORMAL, sin elemento)

**Tema (§3.1):** franja exterior del imperio caído, escombro mundano, superficie, umbral. **Sin carga elemental** — escombro genérico, no cristales/material elemental. Paleta neutra terrosa (gris piedra, marrón polvo, cielo apagado), nada saturado de elemento. Es el tutorial: tono sobrio, mundano, "antes de que empiece lo cósmico".

**Paleta zona:** weathered stone gray (#8A8278), dusty brown (#6F4E37), pale washed-out sky (#B7B7A4), faint warm sun (#C9B079). NO elemental saturation, NO glowing crystals.

#### `bg_ruinas_bga_borde_1920x1080.png` (sub-zona a — BG escombro de superficie + cielo apagado)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Ruinas de Borde — NORMAL, no element. Mundane outer rim of a fallen
empire. Palette: weathered stone gray (#8A8278), dusty brown (#6F4E37),
pale washed-out sky (#B7B7A4), faint warm sun (#C9B079). Muted, earthy, NO
elemental saturation, NO glowing crystals.

SUBJECT: The outer edge of a fallen empire at surface level — a threshold.
Distant skyline of toppled stone buildings, broken arches and collapsed
walls receding into a hazy pale sky. The mundane debris of an empire the
land first covered: cracked pavement, fallen columns, generic rubble. A
weak overcast sun low in the sky. Quiet, abandoned, before anything cosmic
or elemental begins. Daytime, open sky visible (this is the surface).

COMPOSITION: Full background covering entire frame. Ruined skyline along
the lower-middle horizon. Pale open sky fills the top half. Soft haze in
the distance for depth.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background,
  no transparency needed for BG sky-equivalent).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any glowing elemental crystals or magical effects (this zone
  is mundane, no element).
- The image should fill the entire 1920x1080 canvas with fallen-empire
  surface ruins atmosphere.
- Output as PNG file.
```

#### `bg_ruinas_mida_escombro_1280x720.png` (sub-zona a — MID muros caídos + columnas)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Ruinas de Borde — NORMAL, no element. Palette: weathered stone gray,
dusty brown shadows, pale stone highlights. Muted, no elemental color.

SUBJECT: Mid-distance fallen-empire ruins — partially collapsed stone walls,
broken imperial columns, a toppled archway, scattered carved masonry blocks,
a leaning watchtower remnant. Generic mundane debris of a frontier outpost.
Soft daylight rim on the stone, no glow, no magic. Dry weeds creeping over
some stones. The simple, somber threshold of the empire.

COMPOSITION: Mid-distance band across the frame. Broken walls and columns
anchor the middle horizontal third. The leaning watchtower rises toward the
top edge on one side. Empty quiet space between ruins.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the ruins.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any glowing elemental crystals or magical effects.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the ruined walls, columns, and watchtower should be visible against
  full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_ruinas_forea_arco_1280x360.png` (FORE_TOP — arco roto colgando + polvo)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Ruinas de Borde — NORMAL, no element. Palette: weathered stone gray,
dusty brown, pale highlights, faint floating dust motes. No elemental color.

SUBJECT: The broken underside of a ruined stone archway and crumbling wall
top hanging from the top edge of the frame, as if the player passes beneath
collapsed masonry. Hanging cracked stone fragments, a few dangling dead
vines, faint floating dust particles catching weak daylight. Mundane,
weathered, no glow.

COMPOSITION: Anchored to top edge of image. Broken arch and masonry dangle
downward into frame. Bottom half mostly transparent (only the lowest stone
fragments and vine tips reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any ground.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the stone.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any glowing elemental crystals or magical effects.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom half of the image should be mostly transparent.
- ONLY the broken arch, masonry, vines, and dust should be visible against
  full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_ruinas_foreb_pavimento_1280x360.png` (FORE_BOTTOM — pavimento agrietado + escombro de piso)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Ruinas de Borde — NORMAL, no element. Palette: weathered stone gray,
dusty brown earth, pale broken-stone highlights, dry weed green-brown. No
elemental color.

SUBJECT: Cracked ancient pavement and broken ground at the bottom of frame.
Fallen masonry blocks, scattered rubble, a half-buried broken column lying
on its side, dry weeds growing through the cracks. The mundane surface
debris of a fallen frontier. Weathered, no glow, no magic.

COMPOSITION: Anchored to bottom edge of image. Pavement, rubble and weeds
grow upward into frame. Top half mostly transparent (only the tallest weeds
and the leaning column tip reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the rubble.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any glowing elemental crystals or magical effects.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the cracked pavement, rubble, fallen column, and weeds should be
  visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

---

### B.2 Zona 6 — El Faro del Cenit (LUZ)

**Tema (§3.1):** techo cósmico por encima de las Cumbres, luz ceremonial cegadora, santidad sin fe, liturgia que ilumina el vacío, alturas imposibles. El destinatario del faro de Vael. Tono: cegador, ceremonial, sereno y terrible a la vez. **Reusa la paleta LUZ del canon Z4** (dorado cegador #FFB703/#FFD60A, blanco hueso) pero **sin la tormenta de viento** — acá es luz pura, serena, vertical, ceremonial (no relámpagos).

**Paleta zona:** blinding gold (#FFB703, #FFD60A), bone white (#EAEAEA), soft pale-gold haze, faint warm shadow (NOT violet storm — that's Z5/viento). Serene, ceremonial, overwhelming light.

#### `bg_faro_bga_cenit_1920x1080.png` (sub-zona a — BG techo cósmico de luz cegadora)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Faro del Cenit — LUZ element. The cosmic ceiling above all peaks.
Palette: blinding gold (#FFB703, #FFD60A), bone white (#EAEAEA), pale-gold
haze, faint warm shadow. Serene, ceremonial, overwhelming light. NOT a storm
(no violet, no lightning) — this is pure vertical sacred light.

SUBJECT: An impossibly high ceremonial sanctum at the cosmic ceiling, far
above the storm peaks. A colossal central lighthouse-beacon of pure light
pouring a blinding vertical beam upward and outward into a radiant gold sky.
Floating sacred platforms and ringed halos of light suspended at impossible
altitude. Holiness without faith — a liturgy that lights an empty void.
Serene yet terrible, blinding. NO ground below, only luminous gold expanse.

COMPOSITION: Full background. The beacon anchors center frame, beam rising
to the top. Radiant gold light fills most of the frame, brightest at center.
Floating halo platforms scattered in the upper-mid area. Soft pale-gold haze
toward the edges.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any storm clouds, violet color, or lightning (that is a
  different zone — this is pure serene light).
- The image should fill the entire 1920x1080 canvas with blinding ceremonial
  high-altitude light atmosphere.
- Output as PNG file.
```

#### `bg_faro_mida_santuario_1280x720.png` (sub-zona a — MID columnas ceremoniales + halos)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Faro del Cenit — LUZ element. Palette: bone white stone, blinding
gold trim and engraved sigils, pale-gold inner glow, faint warm shadow.
Serene ceremonial light, no storm.

SUBJECT: Mid-distance ceremonial sanctum architecture — tall bone-white
pillars with golden engraved sacred sigils, suspended ring-shaped light
halos, partial floating altars and arches of polished pale stone. Beams of
soft gold light passing between the pillars. Ornate, holy, weightless,
ceremonial. The liturgical structure of a priesthood that sustains a
projected sky.

COMPOSITION: Mid-distance band. Tall sigil pillars rise from the middle
horizontal third toward the top edge. Floating halos and altars span the
mid-frame. Gold light beams cross the empty spaces between pillars.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the architecture.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any storm clouds, violet color, or lightning.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the pillars, halos, altars and light beams should be visible against
  full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_faro_forea_rayos_1280x360.png` (FORE_TOP — rayos de luz descendentes + halos colgando)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Faro del Cenit — LUZ element. Palette: blinding gold (#FFD60A),
bone white, soft pale-gold light rays. Serene ceremonial light, no storm.

SUBJECT: Blinding gold light rays and ceremonial light streaming down from
the top edge of the frame, as if from an unseen radiant ceiling. A few
suspended golden halo rings and dangling ceremonial light-banners hang into
frame. Soft floating motes of light. Overwhelming serene brightness from
above. No clouds, no storm.

COMPOSITION: Anchored to top edge. Light rays and halos descend into frame.
Bottom half mostly transparent (only the longest light rays and motes reach
there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any ground.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the light.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any storm clouds, violet color, or lightning.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom half of the image should be mostly transparent.
- ONLY the light rays, halos, banners and motes should be visible against
  full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_faro_foreb_altar_1280x360.png` (FORE_BOTTOM — borde de altar de luz + cristales dorados)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Faro del Cenit — LUZ element. Palette: bone white polished stone,
blinding gold trim, glowing pale-gold light crystals, soft warm highlights.
Serene ceremonial light, no storm.

SUBJECT: The edge of a polished bone-white ceremonial platform extending
across the bottom of frame, with golden engraved trim and glowing gold light
crystals embedded in its surface. Soft beams of light rising from the edge.
A faint floating-platform feel, suspended at impossible altitude with bright
luminous haze below instead of ground. Holy, serene, weightless.

COMPOSITION: Anchored to bottom edge. The ceremonial platform edge spans the
horizontal bottom. Top half mostly transparent (only the tallest light
crystals and rising light beams reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the platform.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any storm clouds, violet color, or lightning.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the platform edge, golden trim, light crystals and beams should be
  visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

---

### B.3 Zona 7 — El Sello del Fondo (SOMBRA)

**Tema (§3.1):** el estrato más profundo, sótano cósmico, lo que el imperio enterró debajo de todo a propósito, sombra que filtra (se cuela por cada grieta), clímax oscuro. Contraparte literal del Faro (techo) → este es el sello (fondo). Tono: opresivo, enterrado, lo que la proyección de luz fue diseñada para tapar. **Sombras profundas no negras** (canon §1: azul/violeta oscuro mejor que negro puro). Acento frío tenue, casi sin luz.

**Paleta zona:** deep violet-black (#1A0A2E), muted dark purple (#2D1654), cold faint edge light (#5A189A), rare thin teal seep (#2C5F5A). Oppressive, buried, near-lightless. Shadows are dark violet, NOT pure black.

#### `bg_sello_bga_fondo_1920x1080.png` (sub-zona a — BG sótano cósmico + sello sellado)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Sello del Fondo — SOMBRA element. The cosmic basement, deepest
buried stratum. Palette: deep violet-black (#1A0A2E), muted dark purple
(#2D1654), cold faint edge light (#5A189A), rare thin teal seep (#2C5F5A).
Shadows are dark violet, NOT pure black. Oppressive, buried, near-lightless.

SUBJECT: The deepest sealed vault beneath the entire fallen empire — what was
buried on purpose, below everything. A vast colossal ancient SEAL/sigil
structure dominating the far distance, faintly glowing cold purple at its
cracked seams, as if barely holding something back. Shadow seeping and
leaking from every crack like dark smoke filtering upward. No sky, no
surface — only deep buried darkness with faint cold light catching the
edges of immense sealed architecture. The terrible bottom of the world.
Climactic, oppressive, final.

COMPOSITION: Full background. The colossal seal structure anchors the center
distance, its glowing seams the brightest element. Deep violet-black fills
the frame, darkest toward the edges. Faint shadow tendrils rise through the
mid-frame.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT use pure black (#000000) for shadows — use deep violet-black instead.
- DO NOT add any open sky or daylight (this is the buried cosmic basement).
- The image should fill the entire 1920x1080 canvas with deep buried sealed
  shadow-vault atmosphere.
- Output as PNG file.
```

#### `bg_sello_mida_cadenas_1280x720.png` (sub-zona a — MID anclajes/cadenas del sello + arquitectura enterrada)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Sello del Fondo — SOMBRA element. Palette: deep violet-black stone
silhouettes, muted dark purple, cold faint purple edge light (#5A189A),
rare teal seep glow. Shadows dark violet, NOT pure black.

SUBJECT: Mid-distance buried vault architecture — massive dark stone anchor
pillars and immense binding chains running into the structure, holding the
seal shut. Broken sigil-stones, half-collapsed sealing buttresses, dark
columns of buried imperial engineering. Thin cold purple rim light along the
edges. Shadow leaking between the stones. The machinery built to contain
something forever, now weakening.

COMPOSITION: Mid-distance band. Anchor pillars and chains rise from the
middle horizontal third toward the top edge. Massive sealing buttresses span
the mid-frame. Shadow seeps in the dark empty spaces between.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the architecture.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT use pure black (#000000) — use deep violet-black for the silhouettes.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the anchor pillars, chains, buttresses and sigil-stones should be
  visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_sello_forea_filtracion_1280x360.png` (FORE_TOP — sombra filtrándose + estalactitas de piedra oscura)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Sello del Fondo — SOMBRA element. Palette: deep violet-black, muted
dark purple, cold faint purple glow (#5A189A) where shadow seeps. Shadows
dark violet, NOT pure black.

SUBJECT: The dark stone ceiling of the buried vault hanging from the top edge
of the frame, with dark jagged stone formations dangling down. Tendrils of
living shadow seeping and dripping downward through cracks in the ceiling,
faintly edge-lit cold purple. A heavy oppressive overhead weight, as if the
entire world presses from above. Near-lightless, the shadow itself is the
subject leaking through.

COMPOSITION: Anchored to top edge. Dark ceiling, stone formations and shadow
tendrils dangle downward into frame. Bottom half mostly transparent (only
the longest shadow tendrils and stone tips reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any ground.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the shadow.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT use pure black (#000000) — use deep violet-black for the dark shapes.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom half of the image should be mostly transparent.
- ONLY the dark ceiling, stone formations and seeping shadow tendrils should
  be visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_sello_foreb_grietas_1280x360.png` (FORE_BOTTOM — piso agrietado + sombra que escapa de las grietas)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: El Sello del Fondo — SOMBRA element. Palette: deep violet-black stone,
muted dark purple, cold purple glow (#5A189A) inside the cracks, rare thin
teal seep. Shadows dark violet, NOT pure black.

SUBJECT: Cracked dark stone floor at the bottom of frame, fractured deep,
with living shadow escaping upward out of the glowing purple cracks like dark
smoke or vapor. Broken sigil-fragments embedded in the stone. The seal is
failing from below; the buried shadow is filtering out. Cold faint purple
light only inside the fissures. Oppressive, climactic.

COMPOSITION: Anchored to bottom edge. Cracked floor and escaping shadow vapor
rise upward into frame. Top half mostly transparent (only the tallest shadow
tendrils reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the floor.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT use pure black (#000000) — use deep violet-black for the dark stone.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the cracked floor, sigil-fragments and escaping shadow vapor should
  be visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

---

## C. Checklist de consistencia (canon §4 + §6)

Antes de aceptar cualquier asset generado:

- [ ] Dimensiones exactas (icon 512×512 · BG 1920×1080 · MID 1280×720 · FORE 1280×360).
- [ ] Alpha real donde corresponde (MID/FORE/iconos: `alpha min == 0`; BG: opaco OK).
- [ ] Sin checkerboard, sin fondo blanco/gris, sin watermark, sin borde/frame.
- [ ] Estilo master cumplido (2D vector, flat + gradiente sutil, NO pixel/realista/painterly).
- [ ] Paleta de la zona/elemento respetada; sombras no-negras (violeta/azul oscuro).
- [ ] Z1 sin elemento (sin cristales mágicos). Z6 sin tormenta/violeta. Z7 sin negro puro.
- [ ] Silueta legible a tamaño chico (iconos mobile).
- [ ] Si falla alpha → `tools/scripts/clean_gemini_alpha.py`. Si watermark → crop bottom-left.
