# Zona 1 — "El Valle de los Ecos": Prompts de Arte para Nano Banana

**Módulo:** Arte Visual / Backgrounds Parallax  
**Zona:** Zona 1 — El Valle de los Ecos  
**Elemento:** TIERRA  
**Herramienta objetivo:** Nano Banana (Google Gemini image gen) — también funciona en Midjourney/SD  
**Resolución objetivo:** 1920×1080 (landscape, 16:9)  
**Responsable de generación:** Leo  
**Source of truth de diseño:** GDD §7.1, CLAUDE.md §4  
**Fecha de creación:** 2026-05-27  

---

## 0. Notas previas antes de generar

### Por qué este doc existe
El estilo visual es el riesgo #5 del GDD: inconsistencia por generación estocástica. Cada prompt de este doc es derivado del **master template** abajo. Si necesitás modificarlo, documentalo en esta sección con el motivo.

### Nano Banana: quirks y cómo compensarlos
- **Tileability:** NB no garantiza que el borde derecho conecte con el izquierdo. Solución: pedir "wide panoramic scene, content centered, empty/blurred edges on left and right sides". Recortar el centro limpio para usar como tile (o scroll infinito pegando dos copias).
- **Characters:** NB a veces mete humanoides aunque no se pidan. Agregar "no characters, no humans, no figures, no silhouettes of people" al negativo.
- **Contraste:** tiende a generar imágenes oscuras. Si sale muy apagado, iterá con "+ bright highlights, high contrast lighting".
- **Variantes:** generá 4–6 variantes del mismo prompt. Elegí la de paleta más coherente con la tabla de colores de §Paleta abajo.

### Notas de coherencia entre zonas
- **Zona 2 (Fragua Cenicienta):** carbón, rojos, naranjas, magma. Cuando llegues al arte de Zona 2, el master template de *esa* zona debe divergir agresivamente en temperatura de color (cálido extremo vs. el verde frío del Valle).
- **Zona 3 (Acueducto del Lamento):** azules, cian, plata. Frío pero vidrioso.
- **Zona 4 (Cumbres de la Tempestad):** púrpura, amarillo eléctrico, abismo. Asegurarse de que el Valle no robe la paleta verde-morado (S3 tiene acento violáceo pero es secundario, no dominante).
- Mantener el **negro de outline** consistente entre sprites de personaje/enemigo y los elementos del mid-ground y foreground.

---

## 1. Paleta Canónica — Valle de los Ecos

Estos son los colores que deben aparecer (en distintas proporciones por capa) en todos los assets de la zona. Guardalos para validar cada generación.

| Rol | Color | Hex |
|---|---|---|
| Verde primario (folliage base) | Verde bosque saturado | `#2D6A4F` |
| Verde secundario (hojas luz) | Verde brillante | `#52B788` |
| Dorado cálido (accent atardecer/detalle) | Ocre dorado | `#D4A04D` |
| Dorado claro (highlight máximo) | Amarillo suave | `#FBC777` |
| Marrón tierra profundo | Tierra oscura | `#6F4E37` |
| Marrón muy oscuro (sombras, ruinas) | Casi negro cálido | `#3E2723` |
| Blanco focal | Blanco puro | `#FFFFFF` |
| Acento mágico (secundario, no dominar) | Magenta suave | `#9D4EDD` |

**Proporciones por capa:**
- **Background (cielo/horizonte):** verdes + dorados, mínimo marrón, sin magenta.
- **Mid-ground (ruinas/árboles):** marrones + verdes. Magenta solo en detalles mágicos (musgo brillante, runas).
- **Foreground (hierba/ramas):** verdes saturados + marrón. Puede haber toques de `#FBC777` en luz que filtra desde arriba.

---

## 2. Master Template — Valle de los Ecos

> Bloque base reutilizable. Se inserta en TODOS los prompts específicos de esta zona. NO modificar sin documentar en §0 por qué.

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game background, transparent background (where applicable),
fantasy RPG style, Valley of Echoes environment,
dense ancient forest with overgrown ruins of a forgotten empire,
rich earth tones: deep forest greens (#2D6A4F, #52B788), warm golds (#D4A04D, #FBC777),
deep earth browns (#6F4E37, #3E2723), subtle magic accents (soft purple-violet),
melancholic but beautiful atmosphere — dangerous yet lush,
moss-covered stone ruins partially consumed by thick vegetation,
high contrast between lit canopy and deep shadow below,
no gradients, no painterly textures, no realistic shading,
no characters, no humans, no player figures, no enemies
```

**Negativo universal (pegar siempre en campo "Negative prompt" si NB lo soporta):**

```
realistic, photorealistic, 3D render, cinematic, dramatic lighting,
oil painting, watercolor, painterly, gradient fills,
characters, humans, humanoid figures, silhouettes of people,
anime style, chibi, cartoon network style, low contrast,
oversaturated bloom, HDR glow, lens flare
```

---

## 3. Prompts de Background Base (Capa 1 — Cielo + Horizonte Lejano)

Estas capas van **más atrás en el parallax** — se mueven más lento. Son el cielo y el horizonte lejano del Valle. Sin detalles nítidos, bordes suaves, alta desaturación relativa (comparado con mid y fore).

**Técnica de tileado para estas capas:** el cielo puede repetirse con overlap. Generá una imagen y duplicala horizontalmente — si los tonos de cielo son continuos, no se nota el corte.

---

### Prompt BG-A — Amanecer Frío (Stages 1–2)

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game background layer, FAR background only,
fantasy RPG style, Valley of Echoes — early morning,
pale cool sky transitioning from deep teal to misty sage green,
distant mountain silhouettes heavily covered in dense ancient forest,
low-lying morning mist in the valleys between mountain ridges,
soft desaturated greens and blue-greens for the distant treeline,
warm golden sunrise light barely touching the highest canopy,
color palette: muted teal sky (#A8DADC), distant forest silhouette in deep sage (#52B788 desaturated),
subtle warm gold glow on horizon (#D4A04D at 40% opacity),
wide panoramic scene, content centered horizontally,
blurred soft edges on far left and far right sides for seamless tiling,
no foreground elements, no mid-ground structures, sky and distant horizon only,
no characters, no humans, no figures, no interactive elements
```

**Capa:** Background (capa 1 / más lejana)  
**Stages que usan este asset:** S1 (Avanzada de Vanguardia) y S2 (Pelotón de Guarnición)  
**Notas de iteración:**
- Si sale muy gris/oscuro: añadir "bright morning light, vivid color saturation" al prompt.
- Si el horizonte tiene árboles muy detallados: añadir "extremely distant, highly blurred, impressionistic silhouette only".
- Si hay personajes: reforzar negativo con "absolutely no characters, empty landscape only".

---

### Prompt BG-B — Mediodía Denso (Stages 3–4)

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game background layer, FAR background only,
fantasy RPG style, Valley of Echoes — deep midday, overgrown and dense,
sky barely visible through thick canopy overhead, filtered green light,
distant ancient forest so dense it forms a solid wall of vegetation,
deep saturated greens dominating the entire horizon,
subtle magical luminescence in the deep forest — faint violet-purple glow between trunks,
color palette: deep forest green dominant (#2D6A4F), highlights in bright green (#52B788),
faint magic accent glow in shadows (soft #9D4EDD, very subtle),
heavy shadow areas in lower portion suggesting dense undergrowth,
wide panoramic scene, content centered horizontally,
soft blurred edges left and right for seamless tiling,
no foreground elements, no mid-ground, distant treeline and sky slivers only,
no characters, no humans, no figures
```

**Capa:** Background (capa 1 / más lejana)  
**Stages que usan este asset:** S3 (Cacería de Élites) y S4 (Emboscada en la Espesura)  
**Notas de iteración:**
- El tint en engine para S3 es violáceo (0.85/1.05 en rojo-azul) y para S4 verde denso (0.70 rojo, 0.65 azul) — el fondo puede ser más neutro, el `modulate` hace el trabajo fino.
- Si el glow morado domina demasiado: "subtle, barely perceptible hint of violet light, not glowing, not neon".
- Si los árboles tienen demasiado detalle: "silhouette only, no internal detail on distant trees".

---

### Prompt BG-C — Atardecer Crepuscular (Stage 5 y Boss)

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game background layer, FAR background only,
fantasy RPG style, Valley of Echoes — golden hour turning to dusk,
dramatic sunset sky with deep amber, burnt orange and warm gold gradients (FLAT COLOR bands, not gradient blends),
color palette: warm amber sky (#D4A04D), deep orange at horizon (#C0622B), 
darkening forest silhouette almost black-brown (#3E2723) against the lit sky,
sense of something large and ancient beyond the treeline — massive shape implied in silhouette,
wide panoramic scene, content centered horizontally,
soft blurred edges left and right for seamless tiling,
no foreground elements, no mid-ground, sky and distant forest silhouette only,
no characters, no humans, no creatures visible
```

**Capa:** Background (capa 1 / más lejana)  
**Stages que usan este asset:** S5 (Vanguardia del Guardián) y Boss (Guardián de la Maleza)  
**Notas de iteración:**
- El tint del Boss stage es naranja intenso (1.20 rojo, 0.75 verde, 0.60 azul) — el fondo puede ser más neutral-dorado, el modulate empuja a crepuscular.
- Si el cielo sale con gradiente suave (y no bandas planas de color): añadir "no gradients, hard color block sky bands, flat fill colors".
- Si aparece alguna silueta sugerida de criatura: usarla como ventaja visual — o removerla con negativo si es demasiado literal.

---

## 4. Prompts de Mid-Ground Parallax (Capa 2 — Estructuras + Árboles medios)

Capa intermedia. Se mueve a velocidad media. Árboles, ruinas, formaciones rocosas. Fondo transparente obligatorio. Estos assets son los que más definen el carácter visual de la zona.

**Técnica de tileado para esta capa:** pedir "isolated architectural/natural elements on transparent background, content spread across full width but not touching edges". Luego componer en Godot poniendo 2–3 instancias del mismo sprite horizontalmente.

---

### Prompt MID-A — Ruinas del Imperio Caído

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game mid-ground layer, transparent background,
fantasy RPG style, Valley of Echoes,
crumbling ruins of an ancient stone empire being consumed by the forest,
broken stone arches and collapsed pillars covered in thick green moss,
gnarled tree roots cracking through the stone floors and walls,
carved stone blocks with faded glyphs barely visible under the moss layer,
color palette: deep stone gray (#5C5552) for ruins, rich moss green (#52B788),
earth brown for exposed soil (#6F4E37), occasional warm gold trim on intact carvings (#D4A04D),
ruins are mid-distance — medium detail, clear silhouette, no complex inner detail,
spread horizontally across a wide panoramic composition,
no characters, no humans, no interactive game elements,
elements do not touch the left or right edges of the image
```

**Capa:** Mid-ground (capa 2)  
**Stages que usan este asset:** genérico para todos los stages (S1–S5 + Boss). Más visible en S3/S4 donde el foliage es más denso.  
**Notas de iteración:**
- Si las ruinas tienen demasiado detalle interno: "simplified forms, readable from distance, no intricate carvings visible".
- Si el musgo tiene textura painterly: "moss rendered as flat green fill with darker edge highlights only".
- Si los arcos salen demasiado intactos y medievales: "heavily damaged, partially collapsed, overgrown beyond recognition in places".

---

### Prompt MID-B — Bosque Ancestral con Luz Filtrada

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game mid-ground layer, transparent background,
fantasy RPG style, Valley of Echoes,
ancient towering trees with thick gnarly trunks and wide canopies,
shafts of warm golden light filtering through the high canopy from above,
hanging vines and trailing moss draping from the branches,
forest floor hidden in deep shadow, occasional patches of soft green glow (bioluminescent moss),
color palette: dark brown trunks (#3E2723 to #6F4E37), bright lit canopy (#52B788),
golden light shafts (#FBC777 at soft opacity), deep shadow pools (#1A120B),
trees spaced enough to allow gameplay visibility in the lower third of the image,
wide panoramic composition spread horizontally,
no characters, no humans, no figures in the light shafts or shadows,
elements do not touch the left or right edges of the image
```

**Capa:** Mid-ground (capa 2)  
**Stages que usan este asset:** preferentemente S4 (Emboscada en la Espesura) y S5 (Vanguardia del Guardián). Alternativo a MID-A para mayor variedad.  
**Notas de iteración:**
- Si los rayos de luz son gradientes difuminados: "light shafts as flat diagonal color bands, not soft glow or bloom".
- Si los árboles no tienen outline claro: "each tree trunk and major branch with clean black outline, 2px minimum".
- Si el bioluminiscente glow domina: "bioluminescent moss as very small subtle accents only, no large glowing areas".

---

## 5. Prompts de Foreground Parallax (Capa 3 — Decoración Cercana)

Capa más cercana a cámara. Se mueve más rápido que todo el resto. **No debe tapar el área de juego central** — estos elementos van en el borde inferior y/o superior de pantalla. Fondo transparente obligatorio.

**Técnica de tileado para foreground:** pedir elementos concentrados en una franja horizontal (inferior O superior, no ambas en el mismo prompt). Godot los posiciona con `offset` en el `ParallaxLayer`.

---

### Prompt FORE-A — Hierba Alta + Helechos (borde inferior)

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game foreground layer, transparent background,
fantasy RPG style, Valley of Echoes,
dense low foreground vegetation: tall grass, large tropical ferns, gnarled surface roots,
elements positioned ONLY in the BOTTOM THIRD of the image frame,
top two-thirds of the image COMPLETELY TRANSPARENT (empty),
grass blades rendered as clean flat shapes with hard outline, no individual blade detail,
ferns with large flat leaf shapes in layered silhouette,
thick roots emerging from the ground and curling across the bottom edge,
color palette: bright foreground greens (#52B788, #40916C), dark root brown (#3E2723),
occasional small wildflowers in warm gold (#FBC777) as accent details,
slight blur or soft edge acceptable on the very bottom edge (cut-off at frame),
wide panoramic composition, content spread left to right,
no characters, no humans, no items, no glowing effects
```

**Capa:** Foreground (capa 3 / más cercana)  
**Stages que usan este asset:** genérico, aplica a todos los stages.  
**Notas de iteración:**
- Si los elementos suben al tercio central de la imagen: muy importante reenfatizar "ONLY bottom third, rest transparent" o recortar manualmente en post.
- Si la hierba tiene textura pintada: "flat solid color fills, no texture, hard outline on each grass shape".
- Si las raíces parecen serpientes o tentáculos: "clearly tree roots, branching structure, brown earth tones only".

---

### Prompt FORE-B — Ramas Colgantes (borde superior)

```
2D vector art, clean lines, flat shading, saturated colors,
side-scrolling video game foreground layer, transparent background,
fantasy RPG style, Valley of Echoes,
hanging tree branches and vines drooping from above into the TOP THIRD of the image frame,
elements positioned ONLY in the TOP THIRD of the image,
bottom two-thirds of the image COMPLETELY TRANSPARENT (empty),
thick ancient tree branches entering from the top edge with trailing vines and moss clumps,
large leaf clusters on the branches, occasional hanging seed pods or lichen,
color palette: dark branch brown (#3E2723), bright foliage green (#52B788),
trailing vine in slightly yellow-green (#74C69D), moss in muted green (#40916C),
branches should partially frame/vignette the top corners but NOT cover the center top,
slight natural blur acceptable at the very top cut-off,
wide panoramic composition, content spread left to right,
no characters, no humans, no creatures visible on the branches
```

**Capa:** Foreground (capa 3 / más cercana)  
**Stages que usan este asset:** preferentemente S3–S4 (zona más densa). Opcional en S1–S2 si el arte luce vacío arriba.  
**Notas de iteración:**
- Si las ramas bajan demasiado al centro de la imagen: recortar o reenfatizar "branches do not pass below the top 30% of the frame".
- Si las hojas tienen textura realista: "leaves as solid flat teardrop shapes, black outline, no vein detail".
- Si las vides parecen cabello o tentáculos: "clearly botanical vines, woody texture, irregular natural hanging pattern".

---

## 6. Tabla Resumen de Prompts

| ID | Capa | Tipo | Stages | Transparente |
|---|---|---|---|---|
| BG-A | Background (capa 1) | Cielo amanecer frío | S1, S2 | No (cielo sólido) |
| BG-B | Background (capa 1) | Cielo mediodía denso | S3, S4 | No (cielo sólido) |
| BG-C | Background (capa 1) | Atardecer crepuscular | S5, Boss | No (cielo sólido) |
| MID-A | Mid-ground (capa 2) | Ruinas con musgo | Genérico | Sí |
| MID-B | Mid-ground (capa 2) | Bosque ancestral | S4, S5 pref. | Sí |
| FORE-A | Foreground (capa 3) | Hierba + helechos (base) | Genérico | Sí |
| FORE-B | Foreground (capa 3) | Ramas colgantes (techo) | S3–S4 pref. | Sí |

**Total de prompts generables:** 7 bases × 4–6 variantes cada uno = 28–42 imágenes. Elegir 1 por ID como canon, guardar variantes en carpeta separada.

---

## 7. Naming Convention de Archivos

Una vez generados y elegidos los assets finales, guardarlos en:

```
assets/art/zona1/backgrounds/
```

Esquema de nombre: `bg_valle_{id}_{variante}_{resolucion}.png`

| Asset | Archivo esperado |
|---|---|
| BG-A (elegida) | `bg_valle_bga_amanecer_1920x1080.png` |
| BG-B (elegida) | `bg_valle_bgb_mediodia_1920x1080.png` |
| BG-C (elegida) | `bg_valle_bgc_atardecer_1920x1080.png` |
| MID-A (elegida) | `bg_valle_mida_ruinas_1920x1080.png` |
| MID-B (elegida) | `bg_valle_midb_bosque_1920x1080.png` |
| FORE-A (elegida) | `bg_valle_forea_hierba_1920x1080.png` |
| FORE-B (elegida) | `bg_valle_foreb_ramas_1920x1080.png` |

Variantes descartadas pero guardadas como referencia: subcarpeta `assets/art/zona1/backgrounds/descartadas/`.

Prompts versionados (este doc) en: `docs/features/visual/zona1_prompts_nanobanana.md` (este archivo).

---

## 8. Cómo integrar los assets en Godot

### 8.1 Dónde van los archivos
Una vez Leo entregue las imágenes aprobadas, el agente que implemente el parallax los importa como `Texture2D` en Godot desde `assets/art/zona1/backgrounds/`.

### 8.2 Estructura de nodos en world.tscn

```
World (Node2D)
└── ParallaxBackground
    ├── ParallaxLayer (background)    ← BG-A/B/C según stage
    │   └── Sprite2D (textura sólida, motion_scale = Vector2(0.1, 0.0))
    ├── ParallaxLayer (mid-ground)    ← MID-A o MID-B
    │   └── Sprite2D (transparent PNG, motion_scale = Vector2(0.4, 0.0))
    └── ParallaxLayer (foreground)    ← FORE-A + FORE-B
        ├── Sprite2D FORE-A (bottom, motion_scale = Vector2(0.8, 0.0))
        └── Sprite2D FORE-B (top, motion_scale = Vector2(0.7, 0.0))
```

**Valores de `motion_scale` sugeridos (ajustar en playtest):**
- Background: 0.10 horizontal, 0.0 vertical (no mueve verticalmente)
- Mid-ground: 0.40 horizontal
- Foreground base: 0.80 horizontal
- Foreground top: 0.70 horizontal

### 8.3 Tileado horizontal
Para los assets que necesiten scroll infinito (BG-A/B/C y MID-A/B), activar en el nodo `ParallaxLayer`:
- `mirroring = Vector2(1920, 0)` (o el ancho de la textura generada)

Esto hace que Godot repita la capa automáticamente al scrollear.

### 8.4 Cambio de fondo por stage
El `StageData` ya tiene `ambient_tint` (modulate). Para cambiar el fondo base entre BG-A/B/C:
- Opción A (más simple): el Claude que implemente esto añade un `@export` en `world.gd` con los 3 fondos y los swapea en `_load_stage()` según el index del stage.
- Opción B (más flexible): añadir `background_texture: Texture2D` al `StageData` Resource y cargar desde ahí.

Recomendación: **Opción B** — queda limpio y consistente con la arquitectura de datos del proyecto (datos en `.tres`, no hardcodeados en `.gd`).

### 8.5 Sprites de personaje y enemigos
Los sprites de player, enemies y bosses se renderizan **encima del parallax** en capas separadas (Z-index > 0). Los backgrounds NO deben incluir personajes — eso ya está cubierto por el negativo universal de los prompts.

---

## 9. Checklist de aprobación de un asset

Antes de marcar un asset como "canon" para producción:

- [ ] ¿Los colores están dentro de la paleta de §1?
- [ ] ¿No hay personajes ni figuras humanas?
- [ ] ¿El fondo es transparente (para MID y FORE)?
- [ ] ¿Los bordes izquierdo/derecho permiten tileado (o hay margen suficiente para recorte limpio)?
- [ ] ¿El elemento se lee claro como silueta en escala de grises?
- [ ] ¿Está en flat shading sin texturas painterly ni gradientes?
- [ ] ¿El area de juego (tercio central de la imagen) está libre de elementos que tapen?

Si algún punto falla: re-prompt con los ajustes de "Notas de iteración" de cada sección.

---

## 10. Historial de cambios al Master Template

| Fecha | Cambio | Motivo |
|---|---|---|
| 2026-05-27 | Versión inicial | Creación del doc |

> Si modificás el master template de §2, agregá una fila acá.
