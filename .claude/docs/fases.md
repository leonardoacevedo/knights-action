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
- Elementos Viento, Rayo, Sombra.
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
