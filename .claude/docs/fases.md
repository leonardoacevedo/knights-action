# Plan de Fases — Knights Action

Basado en §13 del GDD. **Total estimado: 14-18 meses** (multiplicar ×1.5-2 para realidad de dev solo).

## Fase 1 — Prototipo de Combate (2-3 meses) ✅ **CERRADA** (24/05/2026)

### Hito
*"Pelear se siente bien."* — Validado por Leo end-to-end.

### Scope entregado
- Player: movimiento + salto + dash con i-frames + ataque melee/ranged + bloqueo con cargas.
- **Sistema de Momentum** (autoload `MomentumSystem`).
- **Furia con decay** (-5/s tras 5s sin atacar).
- **Bloqueo con cargas** (`ShieldComponent`, signal `hit_blocked`, freeze Momentum al absorber).
- **Telegrafía enemy** ("!" amarillo bouncing en el último 40% del wind-up).
- **Hit-stop** global + **screen-shake** con decay (`HitStop`, `CameraShake` autoloads).
- **Game Over + Reintentar** modal.
- Touch HUD completo (joystick + 6 botones, flag `GameConfig.PLATFORM_MODE`).
- Bugfixes: facing del swing, enemy muerto desvanece, auto-jump joystick, TouchButton stuck.

### Lecciones / bugs Godot 4 documentados
- `.tscn` NO soporta comentarios `#` (parser silenciosamente saltea el siguiente `[node]`).
- `TouchButton` debe emitir `InputEventAction` sintético + tener poll defensivo de auto-release para sobrevivir CanvasLayer modales.
- Hit-stop al recibir daño se siente como lag en multi-enemy — solo se aplica al PEGAR/BLOQUEAR.

### Retrospectiva
Pendiente en `docs/features/phase_1_retrospective.md`.

---

## Fase 2 — Loop Básico (2-3 meses) ✅ **CERRADA** (25/05/2026)

### Hito
*"El loop pelear → lootear → mejorar engancha."* — Validado por Leo end-to-end.

### Backup
`backups/fase_2_cerrada_2026-05-25.tar.gz` (snapshot completo del proyecto al cierre).

### Scope entregado
- 3 enemigos R1/R2/R3 diferenciados (R2 bloquea, R3 dashea + skill).
- Drops Milestone A (materiales por kill) + Milestone B (items por stage_cleared).
- Crafteo backend + UI (5 recetas iniciales).
- Refinamiento +1 a +10 backend + UI con Pergaminos de Protección.
- Boss R4 "El Guardián de la Maleza" integrado (escudo cargas reales, 5 patrones, 2 fases).
- Stats del equipo impactan combate (`PlayerStatsComponent` + `HurtboxComponent.flat_defense`).
- UI completa: InventoryScreen + RefinementScreen + CraftingScreen + LootCardScreen + MaterialToast.

### Retrospectiva
Pendiente en `docs/features/phase_2_retrospective.md`.

---

## Fase 3 — Sistemas RPG Completos (3-4 meses) ← **ESTAMOS ACÁ**

### Hito
*"Una zona completa es jugable de principio a fin."*

### Scope
- **Árbol de skills** (~30 nodos, 3 ramas: Guerrero, Mago, Ágil).
- **Elementos** Tierra/Fuego/Agua con triángulo (×1.5 ventaja / ×0.66 desventaja).
- **Set bonuses** (afinidad de equipo 2pc/3pc).
- **Momentum integrado en UI** finalizada.
- **Primera zona completa** (Valle de los Ecos): actualmente 3 stages combate + boss = 4. GDD §7.1 pide 5-8. Sumar 2-4 stages más.
- **Arte de la zona generado por IA** (Midjourney/SD/Nano Banana).
- Parallax de la zona, sprites de los 3 enemigos y boss.
- Música de zona (1 track) y de combate.
- **Sistema de Oro** (placeholder en refinamiento/crafteo — implementar real).
- **Pool items R3 completo** (falta armor R3 y escudo R3).

### Estado actual (26/05/2026) — recién abierta
- ⏹ Árbol de Skills (sistema más diferenciador del RPG, define progresión vertical).
- ⏹ Sistema Elementos + triángulo.
- ⏹ Set Bonuses (depende de elementos).
- ⏹ Completar zona 1 (2-4 stages más).
- ⏹ Sistema de Oro.
- ⏹ Pool R3 completo.
- ⏹ Arte / sprites IA (delegar a `art-prompt-engineer`).
- ⏹ Audio pipeline + 2 tracks iniciales.
- ⏳ Decidir orden de implementación con Leo.

### Backlog opcional (no en scope crítico de Fase 3)
- HUD finalizado con Momentum visual definitivo.
- UI bestiario interactivo (actualmente solo lore en docs).
- Tutorial integrado (no requerido por GDD para cerrar Fase 3 pero ayuda al criterio "sin tutorial extenso").

### Criterio para cerrar fase
Un tester nuevo termina la zona, vence al boss y entiende el sistema RPG sin tutorial extenso.

### Zonas 2/3/4 — lógica implementada anticipadamente (27/05)

**Decisión Leo (27/05):** implementar lógica de zonas 2-4 ahora aunque GDD §11 las marca
post-launch backlog. Visual estético queda pendiente. Razón: bestiario + StageData +
materials + bosses son contenido de relleno aprovechable durante Fase 4 (Coliseo) sin
saltarse cierre formal de Fase 3 (Zona 1 polished).

**Implementado:**
- **Zona 2 (Fragua Cenicienta — FUEGO):** 6 stages + boss [Ignis](../../resources/stages/zona2_etapa_boss.tres). 3 materials nuevos (`fragmento_ascuas`, `mineral_hierro_rojo`, `nucleo_igneo`). Drop tables per-stage + boss. 2 recetas crafteo (`craft_peto_brasas`, `craft_aegis_igneo`). Boss Ignis: 5 patrones (Hammer Overhead, Salto Sísmico con PersistentHazard lava, Lluvia Meteoros, Sed de Sangre F2, Corte Giratorio F2).
- **Zona 3 (Acueducto del Lamento — AGUA):** 7 stages + boss [Lyss](../../resources/stages/zona3_etapa_boss.tres). 3 materials (`gota_lamento`, `cristal_escarcha`, `nucleo_abisal`). Drop tables. Boss Lyss: 5 patrones (Látigo Helado, Nova de Hielo + FREEZE, Triple Tiro, Vórtice Gravedad F2, Canto Helado aura F2).
- **Zona 4 (Cumbres de la Tempestad — VIENTO/LUZ):** 5 stages + mini-boss (Capitán de los Vientos) + boss placeholder. 3 materials (`pluma_tormenta`, `fragmento_cielo_roto`, `nucleo_fulgurante`). Boss Vael "Señor de la Luz Cegadora" (placeholder, usa boss_heraldo via routing por clase).
- **Routing por zona:** `StageManager.current_zone` (1..4) + `get_stages_for_zone(id)`. `set_zone(N)` API para MainMenu (UI pendiente).
- **Boss override per-stage:** `StageData.boss_scene_override` permite asignar bosses propios sin tocar routing por clase.

**Pendiente:**
- Visual estético (sprites, parallax, audio) — TODAS las zonas.
- Skills nuevas del bestiario zona 2-3 (Muro Llamas, Trampa Cazador, Tajo Doble, etc.) — viables con infra actual, no implementadas todavía.
- Mini-boss stage type dedicado (zona 4 etapa 3 usa stage normal con 1 R3 archer).
- Items dedicados zona 2-4 (los crafteos zona 2 reusan items zona 1; zona 3 craft usa cota_cuero placeholder).
- UI selección de zona en MainMenu (API `StageManager.set_zone` lista para wireado).

**Decisiones pendientes (zona 4 desbloqueada elemento, otros pendientes):**
- ✅ **6 elementos canon definitivos 27/05 (decisión Leo)**: FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA. Enum `ItemData.Element` (0=NEUTRO, 1..6). Dos triángulos: primario FUEGO>TIERRA>AGUA>FUEGO + secundario VIENTO>LUZ>SOMBRA>VIENTO. Status synergy: VIENTO=SLOW (suave), LUZ=STUN (destello cegador), SOMBRA=POISON. Ver habilidades_generales.md §7.5.
- Stage type mini-boss — agregar campo `is_mini_boss: bool` a StageData para UI banner propio. Pendiente.
- Reflexión proyectiles (boss Lyss "Muralla Estática refleja" + zonas futuras) — REQ-INFRA grande, no implementado.
- Boss Vael completo (5 patrones reales) — actualmente placeholder R4 Mage element=LUZ. Crear `boss_vael.gd/.tscn` con Ráfaga Arcana, Lanza de Luz Penetrante (REQ-INFRA laser tracking 2s), Patada Frontal, etc.
- Items dedicados elementos VIENTO/LUZ/SOMBRA — actualmente todos los items canónicos son FUEGO/AGUA/TIERRA/NEUTRO. Agregar 2-3 weapons + armors por elemento nuevo cuando se balance economía zona 4.

---

## Fase 4 — Coliseo (2-3 meses)

### Hito
*"Puedo subir mi Eco y pelear contra el de otro tester."*

### Scope
- Backend (Firebase o Supabase) configurado.
- **Upload de Eco** con build + telemetría.
- **Asignación de Perfil IA** (1 de 4).
- **Matchmaking asíncrono** (3 Ecos candidatos por Gloria similar).
- **Sistema de Gloria** con +/- por victoria/derrota.
- **Ranking** y leaderboard global.
- UI del Coliseo completa.
- Anti-cheat básico (validación al subir).

### Criterio para cerrar fase
2-3 testers suben sus Ecos, pelean entre sí asíncronamente, el ranking refleja sus skills relativos.

---

## Fase 5 — Pulido y Lanzamiento (3-4 meses)

### Hito
*"Listo para soft launch."*

### Scope
- Arte final de toda la zona (no placeholders).
- Audio final (música + SFX completo).
- UX móvil afinada — testing en dispositivos reales (Android y iOS).
- Balance final (curvas validadas con datos de los testers).
- Misiones diarias funcionales.
- Bestiario completo con lore.
- Optimización (carga, memoria, fps en mid-range).
- Tienda básica (si aplica — definir con Leo si MVP tiene store de cosméticos).
- Política de privacidad, T&C, GDPR mínimo.

### Criterio para cerrar fase
APK / IPA en TestFlight / Internal Testing con ~50 jugadores reales por 1 semana sin crashes mayores.

---

## Reglas inviolables del plan

1. **No saltarse fases.** Si Fase 1 no se siente bien, Fase 2 no arregla nada.
2. **Cada hito requiere un playtest validatorio** antes de cerrar.
3. **El alcance de cada fase es el §13 del GDD + acuerdo con Leo.** Si algo se mueve entre fases, documentarlo en este archivo.
4. **No agregues contenido a una fase para "cubrir un agujero" de la siguiente.** Mejor cerrar la fase y arrancar la próxima limpia.
5. **Documentá lo aprendido al cerrar cada fase** en `docs/features/phase_<N>_retrospective.md`.

## Post-launch — Backlog (NO entra al MVP)

- Zonas 2 (Fuego) y 3 (Agua) con sus bosses.
- Rareza R4 Legendaria.
- ~~Elementos Viento, Rayo, Sombra~~ → **Canon definitivo 27/05**: 6 elementos = FUEGO, AGUA, TIERRA, VIENTO, LUZ, SOMBRA. Implementado en código + tests (RAYO descartado, LUZ ocupa slot 5).
- Sistema de Reliquias (roguelite-lite).
- Logros y cosméticos.
- Eventos de temporada en Coliseo.
- Localización (inicialmente solo castellano).

Source: GDD §11.

---

## Riesgos identificados (§14 GDD) — recordatorio

| Riesgo | Mitigación |
| :--- | :--- |
| Performance animación skeletal mobile | Limitar huesos <20, usar AnimationTree |
| UI de 5+joystick en pantalla chica | Probar en celular real desde **Fase 1**, no en PC |
| Corrupción de saves | Backup local + cloud desde día 1 |
| Backend Coliseo costoso | Firebase free tier para soft launch, migrar si escala |
| Inconsistencia visual IA generativa | Template maestro reusado siempre |
| Scope creep | Releer pilares antes de cada decisión |
| Burnout de dev solo | Sprints cortos, pausas planificadas |

Mantener estos en vista durante todas las fases.
