# Canon Visual Master — Knights Action

> **Source of truth visual.** Toda generación de arte (Midjourney/Gemini/SD/Nano Banana) sigue este doc. Si una imagen no cumple este canon, se descarta o se regenera. Riesgo #5 GDD §14: inconsistencia visual.

**Versión:** v1.0 — 28/05/2026
**Aprobación:** Leo aprobó imagen de referencia que define este canon.
**Imagen de referencia:** combate Knight vs Guerrero Corrupto en Valle de los Ecos, parallax denso bosque.

---

## 1. Estilo master

**Pipeline objetivo:** mobile-first Action-RPG con sensación pulida estilo gacha mid-tier (Knights & Dragons, Vainglory) + readability indie (Hollow Knight, Dead Cells).

**Reglas absolutas:**

- **2D vector art**, líneas limpias.
- **Flat shading + gradientes sutiles** — NO painterly, NO photorealistic, NO pixel art.
- **Saturated colors**, no chillones.
- **Lectura de silueta clara** — personaje/enemy reconocible solo por sombra.
- **Side-view** para todo lo animable.
- **Coherencia cross-zona** — mismo nivel de detalle, mismo tratamiento de luz, distinto tema.

**Reference style explícito (para prompts IA):**
```
hand-painted vector style, like Hollow Knight backgrounds + Dead Cells
environments + Knights & Dragons character pulish, NOT pixel art,
NOT realistic, NOT painterly
```

**Palette philosophy:** cada zona dominada por **un par de colores principales** + 1 acento contraste. Saturación alta pero no neón. Sombras profundas no negras (azul/violeta oscuro mejor que negro puro).

---

## 2. Variables por zona

### Zona 1 — Valle de los Ecos (TIERRA)
- **Dominantes:** verde saturado profundo (#2D6A4F, #52B788), dorado cálido (#D4A04D, #FBC777)
- **Sombras:** marrón profundo (#6F4E37, #3E2723)
- **Acento contraste:** magenta sutil (#9D4EDD) — usado en pequeñas flores, cristales, ojos enemigo
- **Iconografía:** raíces gigantes, mossy stones, ruinas imperiales semi-cubiertas, polen dorado, cristales flotantes amarillos
- **Luz:** rayos dorados atravesando canopy denso, halos cálidos
- **Materiales asociados:** Hierba Antigua (verde tallo), Savia Resonante (ámbar cristalizado), Esencia del Verdor (verde-dorado pulsante)

### Zona 2 — Fragua Cenicienta (FUEGO)
- **Dominantes:** rojo brasa (#C9302C, #E55934), naranja fundido (#FF6B35, #FFA62B)
- **Sombras:** negro carbón (#1A1A1A), gris ceniza (#4A4A4A)
- **Acento contraste:** dorado fundido brillante (#FFD700) en metales activos
- **Iconografía:** hornos abiertos, cadenas al rojo vivo, yunques, charcos de lava persistente (PersistentHazard zona), brasas suspendidas, humo grueso
- **Luz:** rojiza desde abajo (hornos), no sun rays — la zona es subterránea/industrial
- **Materiales asociados:** Fragmento de Ascuas (brasa naranja), Mineral de Hierro Rojo (rojo oxidado denso), Núcleo Ígneo (esfera roja pulsante)

### Zona 3 — Acueducto del Lamento (AGUA)
- **Dominantes:** azul profundo (#003B5C, #006A8E), cyan glacial (#48CAE4, #90E0EF)
- **Sombras:** azul muy oscuro casi negro (#001D3D)
- **Acento contraste:** dorado tenue (#FFB703) — luz cálida que casi no llega, contraste melancólico
- **Iconografía:** arcos arquitectónicos imperiales, columnas, agua estancada, pilares de hielo, cristales translúcidos, goteo visible perpetuo
- **Luz:** filtrada por agua, ondulante, fría. Caustics en superficies
- **Materiales asociados:** Gota de Lamento (gota suspendida cyan), Cristal de Escarcha (hielo translúcido), Núcleo Abisal (esfera negro-violeta pulsante)

### Zona 4 — Cumbres de la Tempestad (VIENTO + LUZ)
- **Dominantes:** dorado luz cegadora (#FFB703, #FFD60A), blanco hueso (#EAEAEA)
- **Sombras:** violeta tormenta (#3A0CA3, #480CA8)
- **Acento contraste:** azul relámpago (#90E0EF) en flashes de tormenta
- **Iconografía:** torres delgadas, observatorios cilíndricos, faros en cumbre, plataformas flotantes, nubes en movimiento, relámpagos lejanos
- **Luz:** alta, vertical desde un sol/faro central. Dramática, contraste fuerte
- **Materiales asociados:** Pluma de Tormenta (gris plumoso), Fragmento de Cielo Roto (cristal azul-blanco translúcido), Núcleo Fulgurante (esfera dorada brillante interior)

---

## 3. Composición parallax (todas las zonas)

**4 capas canon** (definidas 28/05):

| Capa | Función | Tamaño PNG | Motion Scale | Notas |
|---|---|---|---|---|
| **BG** | Cielo / fondo lejano | 1920×1080 | 0.1 | Más grande para parallax lento, profundidad |
| **MID** | Estructuras mid-distance | 1280×720 (16:9) | 0.4 | Mid-frame composición, transparent alpha |
| **FORE_TOP** | Overlay arriba (ramas/nubes/etc) | 1280×360 (32:9) | 0.7 | Tira superior, ancla arriba |
| **FORE_BOTTOM** | Overlay piso (hierba/lava/agua/etc) | 1280×360 (32:9) | 0.8 | Tira inferior, ancla piso |

**Viewport real:** 1152×648. Aspect 16:9.

**Sub-zonas por stage:**
- Sub-zona **a** (stages 1-2): inicio de la zona, intro
- Sub-zona **b** (stages 3-4): mid-zone, ya inmerso
- Sub-zona **c** (stage 5 + boss): profundo, climax

Cada sub-zona puede tener variación de paleta sutil (mañana/mediodía/atardecer en Z1, etc).

---

## 4. Reglas anti-error (CRÍTICAS para Gemini)

Gemini Imagen tiene 4 problemas comunes que debemos prevenir EN PROMPT:

1. **Checkerboard pattern fake transparency** — Gemini dibuja cuadrícula gris en lugar de aplicar alpha real. Prompt anti:
   ```
   The PNG must have a fully TRANSPARENT background with a real alpha channel.
   DO NOT add any checkerboard pattern. DO NOT add gray squares.
   DO NOT add any visible background pattern simulating transparency.
   ```

2. **Watermark Gemini** — logo en esquina inferior izquierda. Prompt anti:
   ```
   DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
   Output the raw subject only, no signatures, no branding, no copyright marks.
   ```

3. **Fondo blanco/gris en lugar de alpha** — Gemini rellena fondo con color en lugar de dejar transparente. Prompt anti:
   ```
   DO NOT add any white background. DO NOT add any gray background.
   DO NOT add any solid color rectangle behind the subject.
   DO NOT add any border, frame, or padding rectangle.
   ```

4. **Dimensiones ignoradas** — Gemini no soporta `--ar`. Prompt explícito:
   ```
   Output dimensions: exactly XXXX pixels wide by YYYY pixels tall.
   Horizontal landscape orientation, wide format, AA:BB aspect ratio.
   ```

**Si Gemini falla en alpha igual:** correr el script python `tools/scripts/clean_gemini_alpha.py` (flood fill desde esquinas + saturación baja → alpha 0). Ver workflow en sección 6.

---

## 5. Prompt template master (Gemini Imagen)

```
Generate a 2D vector game art [LAYER TYPE] for a fantasy RPG mobile game.
Output dimensions: exactly [WIDTH] pixels wide by [HEIGHT] pixels tall.
[ORIENTATION], [ASPECT RATIO].

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: [ZONE NAME] — [ELEMENT] element, [PALETTE DESCRIPTION].

SUBJECT: [SPECIFIC SUBJECT DESCRIPTION matching zone lore]

COMPOSITION: [Where the subject sits in the frame — top edge, mid band,
bottom edge, full frame, etc]

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any [things that should not be drawn — sky, ground, horizon, etc].
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the subject.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the [subject] should be visible against full transparency.
  Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

---

## 6. Workflow post-generación

1. **Generar PNG con Gemini Imagen** usando prompt de §7.
2. **Verificar con sips/python:**
   ```bash
   sips -g pixelWidth -g pixelHeight -g hasAlpha file.png
   python3 -c "from PIL import Image; im=Image.open('f.png'); print(im.split()[-1].getextrema())"
   ```
   Alpha min debe ser 0 (transparente real). Si min=255 → fake alpha, usar script clean.
3. **Si checkerboard visible / fake alpha:** correr `tools/scripts/clean_gemini_alpha.py` (flood fill).
4. **Si watermark visible:** crop bottom-left 12% width × 10% height → alpha 0 (esto borra watermark Gemini típica).
5. **Verificar aspect ratio vs target** — si difiere mucho, regenerar con prompt más específico.
6. **Reemplazar en `assets/art/<zona>/backgrounds/`** con mismo filename para que Godot reimporte automático.

---

## 7. Prompts canon — Zonas 2, 3, 4

> **NOTA:** los prompts siguientes están en INGLÉS porque Gemini Imagen entiende mejor. NO traducir. NO modificar. NO caveman. Pegar tal cual.

### 7.1 Zona 2 — Fragua Cenicienta (FUEGO)

#### `bg_fragua_bga_forja_1920x1080.png` (sub-zona a — hornos abiertos)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Fragua Cenicienta — FUEGO element. Palette: brasa red (#C9302C),
molten orange (#FF6B35), carbon black (#1A1A1A), molten gold accents (#FFD700).

SUBJECT: Deep industrial forge chamber filled with red-orange glow. Multiple
open furnaces in the distance casting hot light from below. Heavy chains
hanging from a vast unseen ceiling. Smoke columns rising. NO sky visible —
this is underground industrial. Dark silhouettes of unfinished armor pieces
suspended in mid-distance.

COMPOSITION: Full background covering entire frame. The red-orange glow
emanates from the bottom-center. Smoke fills the top third. Chains and
suspended objects punctuate the middle band.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background,
  no transparency needed for BG sky-equivalent).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- The image should fill the entire 1920x1080 canvas with industrial forge
  atmosphere — no transparent areas needed for BG layer.
- Output as PNG file.
```

#### `bg_fragua_mida_yunques_1280x720.png` (sub-zona a — MID yunques + cadenas)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Fragua Cenicienta — FUEGO element. Palette: brasa red, molten orange,
carbon black silhouettes, dark iron gray.

SUBJECT: Mid-distance industrial forge silhouettes — large blacksmith anvils
on stone platforms, hanging chains with hooks, partial walls of soot-stained
brick, broken tools scattered, an unattended hammer mid-swing position. All
in dark silhouette with orange-red rim lighting from below.

COMPOSITION: Mid-distance band across the frame. Anvils anchor the middle
horizontal third. Chains hang from top edge into mid-frame. Empty industrial
working space.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the subject.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the forge silhouettes (anvils, chains, partial walls) should be
  visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_fragua_foreb_humo_1280x360.png` (FORE_TOP — humo grueso colgando)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Fragua Cenicienta — FUEGO element. Palette: dark gray smoke (#4A4A4A),
soot black, faint orange glow from below filtering up.

SUBJECT: Heavy industrial smoke clouds hanging from the top edge of the
frame, like factory smoke trapped under an invisible ceiling. Volumetric,
opaque, with orange undertones where heat from below illuminates the
underside. Some smaller embers floating within the smoke.

COMPOSITION: Anchored to top edge of image. Smoke dangles downward into
frame in irregular billowing shapes. Bottom half of image mostly transparent
(only smoke tails reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any ground.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the smoke.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom half of the image should be mostly transparent (only smoke
  tails reach there).
- ONLY the smoke clouds and embers should be visible against full
  transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_fragua_forea_lava_1280x360.png` (FORE_BOTTOM — charcos de lava piso)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Fragua Cenicienta — FUEGO element. Palette: bright lava orange
(#FF6B35, #FFD700), dark stone (#1A1A1A), bright yellow-white at lava
centers.

SUBJECT: Cracked stone ground with multiple pools of glowing lava breaking
through. Some larger pools, some smaller. Stone fragments around the
cracks. Faint heat shimmer effect over the lava. Charred edges where stone
meets lava.

COMPOSITION: Anchored to bottom edge of image. Stone and lava plants grow
upward into frame. Top half of image mostly transparent (only the tallest
lava splashes reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the lava.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the cracked stone ground and lava pools should be visible against
  full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

### 7.2 Zona 3 — Acueducto del Lamento (AGUA)

#### `bg_acueducto_bga_canales_1920x1080.png` (sub-zona a — canales arquitectónicos)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Acueducto del Lamento — AGUA element. Palette: deep ocean blue
(#003B5C), glacial cyan (#48CAE4), dim distant gold rays (#FFB703),
shadow blue-black (#001D3D).

SUBJECT: Vast underground aqueduct chamber. Arched stone columns receding
into deep blue distance, suspended in still water. Soft cyan caustic light
on far walls. Distant golden light barely filtering down from above through
a structural opening. Atmosphere of cathedral underwater. NO direct sky.
NO surface water visible — only deep submerged architecture.

COMPOSITION: Full background covering entire frame. Architectural columns
recede toward central vanishing point. Cyan light bands across mid-third.
Distant gold pinpoint top-center.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background,
  no transparency needed for BG layer).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- The image should fill the entire 1920x1080 canvas with underwater
  aqueduct atmosphere.
- Output as PNG file.
```

#### `bg_acueducto_mida_pilares_1280x720.png` (sub-zona a — MID pilares + agua)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Acueducto del Lamento — AGUA element. Palette: cyan-blue stone,
cracked aged columns, glacial blue ice formations, dark blue shadows.

SUBJECT: Mid-distance aqueduct architecture — large stone columns covered in
ice formations and cyan moss. Pieces of broken arches floating impossibly
at mid-height (the water once held them). Cyan crystals embedded in the
column surfaces. Some suspended water droplets, frozen in place. The
melancholic ruins of imperial water-engineering.

COMPOSITION: Mid-distance band. Columns anchor the middle horizontal third
and rise tall to the top edge. Floating broken arch pieces in the mid-air
spaces between columns.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the columns.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the columns, broken arches, and ice formations should be visible
  against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_acueducto_foreb_goteras_1280x360.png` (FORE_TOP — goteras y techos colgantes)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Acueducto del Lamento — AGUA element. Palette: dark stone gray-blue,
cyan ice stalactites, dripping water cyan, dark shadows.

SUBJECT: Stone vaulted ceiling fragments hanging from the top edge of the
frame. Ice stalactites of varying lengths dangling downward. Visible water
droplets caught mid-fall, suspended unnaturally. Cracked stone underside
of an imperial vault structure.

COMPOSITION: Anchored to top edge. Ceiling and stalactites dangle downward
into frame. Bottom half mostly transparent (only the longest stalactite
tips and some water droplets reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any ground.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the stalactites.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom half of the image should be mostly transparent.
- ONLY the stalactites, ceiling fragments, and water droplets should be
  visible against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_acueducto_forea_charcos_1280x360.png` (FORE_BOTTOM — charcos + cristales hielo)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Acueducto del Lamento — AGUA element. Palette: cyan still water,
glacial blue ice crystals, dark stone fragments, soft white highlights on
ice edges.

SUBJECT: Flooded stone floor with shallow still water pools. Ice crystals
emerging upward through the water surface like translucent plants. Some
broken stone fragments protruding. Soft cyan reflections on the water
surface.

COMPOSITION: Anchored to bottom edge. Water surface and ice crystals
grow upward into frame. Top half mostly transparent (only ice crystal
tips reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the water.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the water pools, ice crystals, and stone fragments should be visible
  against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

### 7.3 Zona 4 — Cumbres de la Tempestad (VIENTO + LUZ)

#### `bg_cumbres_bga_tormenta_1920x1080.png` (sub-zona a — cielo de tormenta + torres lejanas)

```
Generate a 2D vector game art BACKGROUND layer for a fantasy RPG mobile game.
Output dimensions: exactly 1920 pixels wide by 1080 pixels tall.
Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Cumbres de la Tempestad — VIENTO + LUZ elements. Palette: golden
storm light (#FFB703), white bone (#EAEAEA), violet storm shadows (#3A0CA3),
lightning blue accents (#90E0EF).

SUBJECT: Vast high-altitude storm sky. Distant golden lighthouse in the
center, projecting a beam of light upward into clouds. Surrounding it,
suspended floating platforms in mid-air. Far below, only churning storm
clouds — no ground visible. Distant flashes of blue lightning in the
violet storm horizon. Dramatic, vast scale.

COMPOSITION: Full background. Lighthouse anchors center-mid frame.
Floating platforms scattered around it. Storm clouds fill bottom 40%.
Open golden sky top 60%.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a real PNG output (this layer is full opaque background).
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- DO NOT add any border, frame, or padding rectangle.
- The image should fill the entire 1920x1080 canvas with high-altitude
  storm atmosphere.
- Output as PNG file.
```

#### `bg_cumbres_mida_plataformas_1280x720.png` (MID plataformas flotantes + torres)

```
Generate a 2D vector game art MID-DISTANCE foreground layer for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 720 pixels
tall. Horizontal landscape orientation, wide format, 16:9 aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Cumbres de la Tempestad — VIENTO + LUZ. Palette: bone white stone
silhouettes, golden trim on observatories, violet storm shadows underneath
floating elements.

SUBJECT: Mid-distance suspended stone platforms with broken edges, tall
cylindrical observatory towers reaching upward, partial archways
suspended in mid-air. Faint golden trim glowing on observatory cupolas.
Wind-blown banners trailing from the towers. Dramatic suspension over
storm void.

COMPOSITION: Mid-distance band. Tall towers rise from middle horizontal
toward top edge. Floating platforms span across horizontal mid-frame.
Empty void in spaces between.

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any ground or floor.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the towers.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- ONLY the towers, platforms, and arches should be visible against full
  transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_cumbres_foreb_nubes_1280x360.png` (FORE_TOP — nubes pasando + relámpagos)

```
Generate a 2D vector game art FOREGROUND TOP STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Cumbres de la Tempestad — VIENTO + LUZ. Palette: violet storm clouds
(#3A0CA3), gray cloud highlights, occasional bright blue lightning bolt
flashes (#90E0EF), golden glow tints where storm meets sun.

SUBJECT: Storm clouds rolling across the top edge of the frame from one
side. Volumetric, violet-gray, with occasional bright blue lightning arcs
visible inside or between cloud masses. Some cloud tendrils dangle downward.
Wind streak motion implied through cloud directionality.

COMPOSITION: Anchored to top edge. Storm clouds occupy top two-thirds.
Bottom third mostly transparent (only cloud tails reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky behind the clouds. DO NOT draw any horizon.
- DO NOT draw any ground. DO NOT add any sun.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the clouds.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The bottom third of the image should be mostly transparent.
- ONLY the storm clouds and lightning should be visible against full
  transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

#### `bg_cumbres_forea_plataforma_1280x360.png` (FORE_BOTTOM — borde plataforma + pluma + cristales)

```
Generate a 2D vector game art FOREGROUND BOTTOM STRIP overlay for a fantasy
RPG mobile game. Output dimensions: exactly 1280 pixels wide by 360 pixels
tall. Very wide horizontal strip format, 32:9 ultra-wide aspect ratio.

ART STYLE: 2D vector art, clean lines, FLAT shading with subtle color
gradients, hand-painted fantasy RPG aesthetic, saturated colors,
references: Hollow Knight backgrounds, Dead Cells environmental art,
Knights & Dragons polish. NOT pixel art. NOT photorealistic.
NOT painterly. NOT 3D rendered.

ZONE: Cumbres de la Tempestad — VIENTO + LUZ. Palette: pale stone
(#EAEAEA), golden cracked edges, translucent sky crystal blue-white,
falling feather grays.

SUBJECT: Edge of a stone platform extending across the bottom of frame,
with cracked broken edges that drop off into void below. Some falling
storm feathers caught mid-fall. Small sky crystal fragments embedded in
the stone surface. A few wind-blown grass tufts emerging from cracks.

COMPOSITION: Anchored to bottom edge. Platform edge spans across horizontal
bottom. Top half mostly transparent (only the tallest grass tips and
falling feathers reach there).

CRITICAL OUTPUT REQUIREMENTS:
- The PNG must have a fully TRANSPARENT background with a real alpha channel.
- DO NOT draw any sky. DO NOT draw any horizon. DO NOT draw any mountains.
- DO NOT add any white background. DO NOT add any gray background.
- DO NOT add any checkerboard pattern. DO NOT add gray squares.
- DO NOT add any visible background pattern simulating transparency.
- DO NOT add any solid color rectangle behind the platform.
- DO NOT add any border, frame, or padding rectangle.
- DO NOT add any watermark. DO NOT add any logo. DO NOT add any text overlay.
- The top half of the image should be mostly transparent.
- ONLY the platform edge, crystals, grass, and feathers should be visible
  against full transparency. Everything else must be alpha = 0.
- Output as PNG file with alpha channel preserved.
```

---

## 8. Personajes y enemies (placeholder — sesión separada)

OUT OF SCOPE de este doc. Pendiente:
- **Player Knight** sprite IA matching reference (armadura mossy + espada fuego + escudo runas)
- **Bosses** sprites IA: Guardián / Ignis / Lyss / Vael
- **Mobs por clase × rareza**: 4 clases × 3 rarezas × 4 zonas = 48 sprites (mucho — priorizar primero zonas implementadas)

Cuando se aborde, **re-leer este doc canon** y aplicar mismo estilo. Generar siempre **T-pose** + alpha real.

---

## 9. Changelog

| Versión | Fecha | Cambio | Razón |
|---|---|---|---|
| v1.0 | 28/05/2026 | Versión inicial — canon visual master + 12 prompts Z2/Z3/Z4 | Leo aprobó imagen referencia. Sync estilo visual master con prompts ready-to-paste. |
