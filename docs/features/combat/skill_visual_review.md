# Review — Legibilidad visual de skills de mobs/bosses (29/05/2026)

> Pedido de Leo: que cada skill de enemy/boss **se vea claro QUÉ hace**, no solo "círculos en el suelo". Disparador: los "charcos" de daño del boss mago aparecen como círculos sin comunicar que dañan ni qué son.
> **Estado: review READ-ONLY, no aplicado.** Los fixes son VFX = código de combate (scope de bloqueantes). Pilar #2: "cada muerte enseña, nada se siente injusto/aleatorio" → el feedback visual debe comunicar la mecánica.

---

## Patrón raíz (3 piezas transversales)

1. **Telegraph del sprite** (`stick_figure.gd::_draw_telegraph_overlay`): tinte naranja + "!" amarillo rebotando en el último 40% de la carga. Comunica **"voy a hacer algo" pero NO qué ni dónde** (idéntico para martillazo, AoE bajo tus pies, o láser).
2. **AoeTelegraph** (`aoe_telegraph.gd`): elipse plana achatada que crece 6% + fade. Sin daño. El único differentiator entre lava/hielo/tierra/arcano es el **matiz de color** — sin iconografía/borde/símbolo.
3. **`_spawn_aoe_impact_burst`** (`enemy.gd`): anillo Line2D expansivo + partículas. **El mejor efecto del juego** — las skills que lo llaman se leen ✅; las que no, quedan ⚠️.

**Regla:** una skill se lee ✅ con (telegraph posicional con la FORMA correcta) + (impacto con burst). Queda ⚠️/❌ cuando solo tiene el "!" + daño invisible, o un círculo plano sin identidad.

---

## ❌ Críticos — mecánica afecta al player con CERO VFX (anti-Pilar #2)

1. **Lyss — Vórtice de Gravedad:** arrastra al player 1.5s, **sin ningún VFX**. → espiral/líneas de succión hacia el boss + tinte radial.
2. **Lyss — Canto Helado (F2):** slow pasivo radio 220px, **invisible**. → anillo/domo tenue de 220px que pulsa al tick.
3. **Lyss — Látigo Helado:** hitbox lineal 220×30px **sin VFX**. → Line2D/rect de barrido (copiar el patrón de la Lanza de Vael).
4. **Guardian — Slam Aplastante:** AoE radio 140px **sin marker en el suelo**. → spawnear AoeTelegraph r=140 durante el salto (hoy solo "!" sobre el boss en el aire).
5. **Heraldo — Eco Eterno (F2):** 2 hazards permanentes que aparecen de golpe → ver §charcos. El peor por permanencia.

## ⚠️ Altos — telegraph/charco plano sin identidad, o impacto faltante

6. **PersistentHazard (todos los charcos)** → §charcos (sistema por tipo).
7. **Ignis/Heraldo/Cazadora — Meteoros/Lluvia AoE:** marcan el AoE pero **NO spawnean el proyectil visual cayendo** ni burst — pese a que el mob Archer/Mage R3 ya tiene `_r3_spawn_lluvia_visuals` + `_spawn_aoe_impact_burst` resueltos. **Reusar esos helpers en los bosses** = fix barato + unifica.
8. **Heraldo — Onda Expansiva:** falta llamar `_spawn_aoe_impact_burst` al detonar (1 línea).
9. **Duelista Llamarada (cono mostrado como círculo) / Guardian Storm & Raíces (ColorRect plano):** telegraph con la FORMA equivocada → telegraph con forma real (cono/iconografía) + burst.
10. **Proyectiles arrow/fireball no colorean por elemento:** Lyss (hielo) y Cazadora (agua) disparan proyectiles naranja-fuego. → centralizar `modulate` por `element` en `projectile.gd` (FUEGO naranja / AGUA cyan / LUZ dorado / SOMBRA violeta…). Hoy los bosses lo parchean a mano, inconsistente.

## ⚠️ Medios — melee sin slash VFX / buffs por modulate

11. **Corte Giratorio (mob+Ignis), Tajo Doble/Combo (Duelista), Patada/Gancho:** hitbox melee sin slash/arco VFX (solo sprite ATTACK). Los combos multi-hit no distinguen golpe a golpe. → arcos slash Line2D.
12. **Buffs por `modulate` (Arma Imbuida, Sed de Sangre boss-side):** tinte ambiguo → aura localizada (en el arma para Imbuida).

## ✅ Modelos a imitar (ya legibles)
- **Vael — Lanza de Luz:** Line2D que muestra la geometría exacta → patrón para Látigo de Lyss.
- **Tank — Taunt:** multi-capa (aura+marker+flash+grito+shockwave) → referencia de feedback máximo.
- **Mob Archer/Mage R3 Lluvia/Meteoros:** telegraph + proyectil visible cayendo + burst → el combo completo.
- **Guardian escudo:** burst + floater de cargas + aura off al romper.

---

## Caso flagship — Charcos / PersistentHazard

**Hoy:** una elipse Polygon2D de color sólido + pulso de escala. Cero telegraph de aparición, textura, borde o símbolo. Usado por Ignis (lava naranja) + Heraldo (Campo/Eco violeta) — solo difieren en matiz. Problemas: (1) no comunica que daña, (2) no comunica qué es, (3) aparece sin aviso.

**Propuesta — `HazardType` con preset visual** (en vez de pasar solo `color`):

Capas comunes a todos los tipos (lo que arregla "es solo un círculo"), mobile-friendly:
- **(A) Telegraph de aparición** 0.3-0.4s (reusar AoeTelegraph antes de instanciar).
- **(B) Borde de peligro animado** — Line2D cerrado saturado con width/dash pulsante (striping = "zona caliente"). *Lo que más comunica peligro a bajo costo.*
- **(C) Símbolo central tenue** — glyph (⚠/calavera/runa) alpha bajo, escala con radio. Lee mejor que textura de relleno a tamaño chico.
- **(D) Partículas verticales** — 1 GPUParticles2D, amount ≤8, **subiendo** (señal universal de "activo/emanando").

Presets (solo cambian borde + partícula + glyph):

| HazardType | Borde | Partícula | Glyph | Usado por |
|---|---|---|---|---|
| LAVA | rojo-naranja dash grueso | brasas subiendo | gota fuego | Ignis Salto Sísmico |
| ARCANE | violeta-cyan dash fino | motas orbitando | runa | Heraldo Campo / Eco Eterno |
| POISON | verde ácido pulso lento | burbujas que estallan | calavera | (futuro SOMBRA/veneno) |
| ICE | cyan claro | cristales lentos | copo | (futuro) |

`setup()` recibe `hazard_type`; `color` queda como override opcional. **Mínimo viable si hay que priorizar: (A) + (B)** — con telegraph + borde animado el charco ya grita "peligro". (C)+(D) = identidad por elemento.

---

## Procedencia
Review de [enemy.gd + 7 boss_*.gd + projectile.gd + aoe_telegraph.gd + persistent_hazard.gd + stick_figure.gd]. Read-only, ningún archivo modificado. Tabla completa por skill en el reporte de sesión.
