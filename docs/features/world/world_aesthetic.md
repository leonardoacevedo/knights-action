# World Aesthetic — Escena de Prueba (world.tscn)

**Fecha de implementación:** 2026-05-23
**Implementado por:** Claude Code (con dirección de Leo)
**Fase del proyecto:** 1 — Prototipo de Combate
**Sección GDD relevante:** §10 "El Valle de los Ecos"
**Pilar(es) reforzado(s):** #4 (5 minutos bastan, 5 horas también — el ambiente invita a quedarse)

---

## Qué hace

Transforma la escena de prueba `world.tscn` de rectángulos planos a un entorno visualmente coherente con la paleta del Valle de los Ecos. Sin imágenes externas: todo procedural (Gradient, GradientTexture2D, Polygon2D, ColorRect). No toca física ni lógica de combate.

---

## Paleta utilizada

Derivada de GDD §10: "verdes saturados, dorados cálidos, marrones profundos. Vectorial limpio con sombras planas."

| Nombre | Uso | Color (hex aprox.) |
| :--- | :--- | :--- |
| Cielo nocturno profundo | Background top | `#1A1430` |
| Cielo crepuscular medio | Background medio | `#2E2352` |
| Ocaso naranja | Background bajo | `#85511F` |
| Dorado cálido | Background bottom | `#B37A1A` |
| Azul montaña lejana | Parallax montañas | `#2E3359` — `#383D66` |
| Verde follaje oscuro | Parallax follaje | `#1A471F` — `#163519` |
| Verde pasto brillante | Borde superior suelo/plataformas | `#3F8C2E` |
| Verde pasto oscuro | Segunda franja borde | `#2E6620` |
| Marrón tierra | Cuerpo del suelo/plataformas | `#4D3829` |
| Marrón tronco árbol | Troncos decorativos | `#473314` |
| Verde canopy | Copas de árboles | `#1F5219` — `#238A1C` |
| Amarillo pálido luna | Luna + halo | `#F2E09E` + halo 18% alfa |

---

## Capas visuales y estructura

```
z=-10  Background (TextureRect + GradientTexture2D)
         Gradiente vertical: violeta/azul → naranja/dorado (crepúsculo)
         Cubre x=[-1200,1200] y=[-800,100]

z=-9   MoonGlow (Polygon2D círculo, 18% alfa)
z=-8   Moon (Polygon2D círculo, 90% alfa) — posición x=550 y=-450

z=-5   ParallaxBackground
  LayerMountains (scroll_scale x=0.15)
    5× Polygon2D siluetas triangulares — azul grisáceo, con alpha 0.75-0.85
    Mirroring x=1200 (se repiten sin corte al mover cámara)
  LayerFoliage (scroll_scale x=0.45)
    3× Polygon2D ondulado — verde oscuro
    Mirroring x=1200

z=-2   Decorations (estáticos, no parallax)
  TreeLeft  @ x=-680
  TreeRight @ x=670
  TreeSmallRight @ x=550
    Cada árbol: ColorRect tronco + 2× Polygon2D canopy (claro encima, oscuro abajo)

z=0    Floor, Platform1-3 (StaticBody2D — no tocados)
  FloorVisual (ColorRect marrón)
  FloorGrassEdge (ColorRect verde claro, 5px)
  FloorGrassEdgeDark (ColorRect verde oscuro, 4px)
  FloorTopHighlight (ColorRect sombra inferior, 6px)
  [mismo patrón ×3 en Platform1Visual/Platform2Visual/Platform3Visual]
    GrassTop (5px) + GrassDark (4px) + Shadow (4px)
```

---

## Por qué (pilares)

Pilar #4: "5 minutos bastan, 5 horas también." Un placeholder lindo reduce fatiga visual en sesiones largas de playtest y comunica la identidad estética del juego desde la primera vez que Leo (o un tester externo) abre Godot. No es scope creep: es hacer que las horas de playtest de Fase 1 se sientan menos áridas.

---

## Decisiones técnicas no obvias

### ParallaxBackground vs Parallax2D

Se eligió `ParallaxBackground` + `ParallaxLayer` (API Godot 4.0+) en lugar de `Parallax2D` (API Godot 4.4+) porque:
- `ParallaxBackground` funciona automáticamente con la `Camera2D` existente sin un script extra — detecta la cámara activa y ajusta offsets.
- `Parallax2D` requiere Godot 4.4+ y su integración con Camera2D todavía tiene edge cases documentados en 4.6 cuando `limit_*` está activo.
- Para este uso (2 capas, scroll horizontal únicamente) la diferencia de features es nula.

### GradientTexture2D en lugar de Shader

Un shader de gradiente sería más flexible, pero introduce dependencia de un `.gdshader` externo. `GradientTexture2D` con `width=4` (1 columna efectiva, el GPU la estira) es equivalente visual con cero overhead de shader compilation en mobile.

### scroll_scale Y = 0.0

Las capas de parallax no se mueven verticalmente (motion_scale.y = 0.0). El jugador salta bastante; si el fondo se moviera en Y, las montañas "nadarían" cuando se salta sobre plataformas. Scroll solo en X.

### Árboles fuera de parallax

Los árboles decorativos (TreeLeft, TreeRight, TreeSmallRight) están en un nodo `Decorations` estático en world space, no dentro del `ParallaxBackground`. Motivo: están a los bordes del área jugable (x=±550 a ±680) y si estuvieran en parallax se desincronizarían del suelo, flotando visualmente sobre él. Estáticos en world space los ancla correctamente al suelo.

### load_steps = 16

El header cuenta: 3 ext_resource + 3 shape sub_resource + 3 Gradient + 3 GradientTexture2D = 12 sub_resources. Total load_steps = 3 (ext) + 12 (sub) + 1 (scene root) = 16. Si Godot recalcula al abrir no hay problema.

---

## Cómo testear manualmente

1. Abrir Godot 4.6, cargar `scenes/world.tscn`.
2. Verificar en el editor 2D que el fondo muestra degradado crepuscular (arriba violeta/azul, abajo naranja/dorado).
3. Correr la escena (F5). Mover al jugador izquierda y derecha: las montañas del fondo deben scrollear más lento que el personaje, el follaje a velocidad media.
4. Verificar que los bordes verdes del suelo y plataformas se ven. Son 5px + 4px, pueden ser difíciles de ver en editor pequeño — sí son visibles a 100%.
5. Confirmar que los CollisionShape2D no se movieron (en el editor, habilitar "Show Collision Shapes" y verificar que Floor/Platform*Shape coinciden con el visual inferior de cada plataforma).
6. Verificar que el Enemy sigue funcionando (combate normal tras abrir escena).

---

## Assets necesarios

Ninguno. Todo procedural. Cuando llegue el momento de arte real (Fase 2+), estos Polygon2D y ColorRect se reemplazan por Sprite2D con texturas generadas vía `art-prompt-engineer`.

---

## Archivos tocados

- `scenes/world.tscn` — reescritura de Background + nodos visuales de plataformas + nuevas capas.

## Archivos creados

- `docs/features/world/world_aesthetic.md` — este archivo.

---

## Pendientes / mejoras futuras

- Partículas de polen flotante (CPUParticles2D, amount <= 15) — se puede agregar en Fase 2 cuando el foco deje de ser el combate puro.
- Luz dinámica: un `PointLight2D` simulando la luna para dar sombras en las plataformas.
- Animación de follaje: AnimationPlayer en los Polygon2D de las copas con offset sutil de color (shimmer de hojas).
- Cuando existan escenas de zona real (`scenes/zones/valle_de_los_ecos/`), world.tscn vuelve a ser un sandbox mínimo o se elimina.
