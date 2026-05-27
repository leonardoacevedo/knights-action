# Checklist de Testeo In-Game — Sesión 27/05/2026

> Lista priorizada de qué validar en Godot 4.6 abierto. Orden: más urgente arriba (regresiones + bloqueantes), menos urgente abajo (polish + edge cases).
>
> **Marcar [x] cuando pase.** Notas/bugs apuntar al lado.

---

## 🔴 BLOQUEANTES — validar primero (rompen TODO si fallan)

### [ ] 1. Compile limpio sin errores parse
**Abrir Godot 4.6 → load proyecto → ver consola.**
- Sin `parse error` ni `script error` en escena inicial.
- Sin warnings críticos rojos en autoloads (PlayerSkillSystem, SaveSystem, SetBonusSystem).
- Si hay parse error → mirar archivo señalado, generalmente tipado / sintaxis.

**Riesgo si falla:** nada del resto funciona.

---

### [ ] 2. Tests headless pasan
```bash
godot --headless --script res://tests/systems/element_system_test.gd
godot --headless --script res://tests/systems/status_effect_component_test.gd
godot --headless --script res://tests/systems/player_skill_system_test.gd
godot --headless --script res://tests/systems/element_status_synergy_test.gd
godot --headless --script res://tests/systems/r2_skills_test.gd
godot --headless --script res://tests/systems/capstone_skills_test.gd
```

Todos deben imprimir `All passed.` al final. Si alguno falla → leer assert que falló.

**Riesgo si falla:** algún subsistema base roto.

---

### [ ] 3. Zona 1 — nada regresó (regression check)
**Arrancar normal sin tocar zona. Pelear etapas 1-5 + boss Guardián.**

Validar:
- Movement player + jump + dash + i-frames funcionan.
- Ataque básico melee + arco + vara visualmente correctos.
- Furia sube +10/golpe, decay tras 5s.
- Bloqueo con cargas absorbe golpes.
- Momentum multiplicador escala.
- Boss Guardián 5 patrones (charge, roots, gap-close, slam, storm F2) + cargas escudo.
- Drops materiales + items.

**Riesgo si falla:** migración ad-hoc → StatusEffect rompió algo. Mirar `player.gd` _physics_process + tick handlers.

---

## 🟠 ALTO — features nuevas críticas

### [ ] 4. StatusEffect system básico (Zona 1 ya alcanza)
**Atacar mob FUEGO → ver Quemadura visual (no implementada VFX pero floater damage cada 0.5s).**
- 30% chance random aplica BURN al golpear.
- DOT 3s × 3 dmg/tick (6 ticks).
- Health.take_damage() directo (player) o hurtbox.receive_hit() (enemy).

Atacar mob AGUA → Congelación:
- 30% chance aplica FREEZE (-30% vel × 2s = mult 0.7).
- Enemy se mueve más lento durante CHASE.

Atacar mob TIERRA → Fractura:
- 30% chance aplica FRACTURA al enemy.
- **Siguiente** hit que recibe enemy → +20% damage.
- Tras consumir, status removido (single-use).

**Si fallan:** mirar `HitboxComponent._try_apply_element_status` + `StatusEffectComponent` lifecycle.

---

### [ ] 5. Eje cósmico — Bendición + Miasma (Zona 4 + items)
**Equipar arma LUZ (vara_luz) + atacar enemy:**
- Cada 30% chance hit LUZ → player se cura 5% HP máx (vampire).
- Si 3pc LUZ equipados → cura 10% (multiplicador set bonus 3pc).
- NO aplica status al defender — solo cura source.

**Equipar arma SOMBRA (daga_sombra) + atacar enemy:**
- 30% chance aplica MIASMA: 5s DOT 2 dmg/tick.
- MIASMA bypass armor (daño directo a HP, no pasa por flat_defense).
- Stack INDEPENDENT — 3 hits → 3 stacks simultáneos.
- Si 2pc SOMBRA equipados → duración 5s → 7.5s.
- Si 3pc SOMBRA → chance 30% → 45%.

**Player con MIASMA activo:**
- Furia gain reducida 50% (10 → 5 por hit).
- Validar via debug: `print(player.furia.current_furia)` antes y después de un hit.

**Si falla:** mirar `Hitbox/Projectile._try_apply_element_status` + `Player._on_hit_landed`.

---

### [ ] 6. Element triángulo secundario VIENTO/LUZ/SOMBRA
```
StageManager.set_zone(4)
get_tree().change_scene_to_file("res://scenes/world.tscn")
```

Atacar enemies zona 4 con arma SOMBRA → ×1.5 contra VIENTO. ×0.66 contra LUZ.
Atacar con arma LUZ → ×1.5 contra SOMBRA. ×0.66 contra VIENTO.
Atacar con arma VIENTO → ×1.5 contra LUZ. ×0.66 contra SOMBRA.
Cross-triángulo (FUEGO vs VIENTO, AGUA vs LUZ, etc.) → ×1.0.

**Verificar damage floaters:**
- Ventaja: número verde con flecha arriba.
- Desventaja: número rojo con flecha abajo.
- Neutro: número estándar.

---

### [ ] 7. Boss Ignis (Zona 2 FUEGO)
```
StageManager.set_zone(2)
```

Avanzar hasta etapa 7 (boss). Validar 5 patrones:
- [ ] Hammer Overhead (telegraph 0.7s + dmg ×1.5 al impactar)
- [ ] Salto Sísmico (jump high + landing AoE 100px + deja **PersistentHazard lava 4s** en suelo donde aterrizó)
- [ ] Lluvia Meteoros (3 AoeTelegraph rojos + AoE 48px + aplica BURN)
- [ ] **F2 trigger en HP ≤ 50%** (tinte rojo más intenso + shake)
- [ ] Sed de Sangre F2 (+25% vel 6s + tinte rojizo)
- [ ] Corte Giratorio F2 (hitbox móvil 1.5s avance lento)

**Mirar lava persistente:** sobrevive 4s tras Salto. Si player pisa → DOT.

---

### [ ] 8. Boss Lyss (Zona 3 AGUA) — Muralla Estática refleja
```
StageManager.set_zone(3)
```

Boss etapa 8. Validar:
- [ ] Látigo Helado (hitbox lineal rectangular frontal rápido)
- [ ] Nova de Hielo (AoeTelegraph 70px + AoE damage + aplica FREEZE)
- [ ] Triple Tiro (3 proyectiles spread ±18°)
- [ ] F2 trigger en HP ≤ 50%
- [ ] Vórtice de Gravedad F2 (pull player hacia Lyss durante 1.5s — override input)
- [ ] Canto Helado F2 (aura SLOW si player <220px)
- [ ] **Muralla Estática F2** — disparar fireball con arco/vara → ver proyectil con **tinte dorado** regresar hacia player. Aura cyan GPUParticles durante state.

**Si Muralla no refleja:** mirar `boss_lyss._check_muralla_reflect` + `Projectile.reflect()` API.

---

### [ ] 9. Boss Vael (Zona 4 LUZ) — Lanza de Luz Penetrante
```
StageManager.set_zone(4)
```

Boss etapa 6. Validar 5 patrones:
- [ ] Ráfaga Arcana (3 fireballs delay 0.12s)
- [ ] Patada Frontal (hitbox 110px + **knockback fuerte 300/-180** empuja player hacia abismo)
- [ ] Destello Sanador (heal 8% HP propio + flash dorado)
- [ ] F2 trigger en HP ≤ 50%
- [ ] Salto Cegador F2 (jump + landing AoE 90px + aplica STUN player 0.3s — inputs bloqueados breves)
- [ ] **Lanza de Luz Penetrante F2** — Line2D dorado tracking lento hacia player (1.8 rad/s lerp) + tick damage cada 0.3s. Player esquiva saliendo del cono.
- [ ] Auto-Destello si HP ≤ 30%.

**Vael es boss MÁS RÁPIDO del juego (velocidad 1.6× normal).** Si se siente lento → bug.

---

### [ ] 10. PlayerSkillSystem (Furia → habilidad)
**Equipar arma. Pelear hasta tener Furia ≥ 30. Presionar tecla 1.**

- [ ] Skill 1 (Embestida default) ejecuta: impulso horizontal hacia facing + buff dmg al próximo swing (0.4s).
- [ ] Costo 30 Furia consumido (chequear via debug `print(furia.current_furia)`).
- [ ] Cooldown 4s — no se puede usar de nuevo hasta passar.
- [ ] Tecla 2 (Bola Fuego) → spawn fireball con ×1.5 daño. Costo 40, CD 6s.
- [ ] Tecla 3 (Onda Sísmica) → AoE radial 100px + aplica BURN a enemies. Costo 50, CD 8s.

**Si tecla no responde:** chequear `Input.is_action_just_pressed("skill_1")` en debug. Validar input map registrado en `project.godot` para skill_1/2/3 → físical_keycode 49/50/51.

---

### [ ] 11. SetBonus runtime — LUZ 2pc passive HP regen
**Equipar 2 items LUZ** (ej. casulla_luz + halo_luz desde inventario debug):
- [ ] HUD elemento muestra "LUZ 2pc activo".
- [ ] Player HP regen pasivo +1.5 HP/s en combate (verificar tras dejarse golpear y observar HP subir).

**Equipar 3 items LUZ** (sumar vara_luz):
- [ ] HUD muestra "LUZ 3pc activo".
- [ ] Atacar enemy con vara_luz → vampire heal 5% × 2 = 10% HP máx por hit con synergy LUZ.

---

### [ ] 12. SetBonus runtime — VIENTO 2pc move speed
**Equipar 2 items VIENTO** (arco_huracan + manto_viento + paves_viento si quieres 3pc):
- [ ] Move speed +10% notable. Comparar con set sin VIENTO.

**3pc:** chance Desequilibrio on-hit 30% → 45%.

---

## 🟡 MEDIO — gameplay polish

### [ ] 13. R3 skills nuevas
**Spawn enemy ARCHER R3 (zona 1 etapa 5 o test arena):**
- [ ] Lluvia de Flechas: 3 AoeTelegraph amarillos + damage radial 42px tras 0.55s.

**Spawn enemy MAGE R3:**
- [ ] Lluvia de Meteoros: 3 AoeTelegraph rojos + AoE damage + aplica BURN.

**Spawn enemy TANK R3:**
- [ ] Muralla Estática: 1.2s status `muralla_estatica` → ataque frontal del player aparece "BLOCK!". Ataque por atrás entra normal.

---

### [ ] 14. Skill variants por zona aplicadas
**Zona 2 (FUEGO) enemies:**
- [ ] MELEE R2 usa Corte Giratorio (hitbox activo 1.5s rotando + avance lento).
- [ ] ARCHER R2 usa Disparo Reactivo (proyectil veloz, low dmg).
- [ ] MAGE R2 usa Erupción Terrestre (AoeTelegraph + AoE + FRACTURA).

**Zona 3 (AGUA):**
- [ ] MELEE R2 usa Tajo Doble (2 hits secuenciales con gap).
- [ ] TANK R2 usa Gancho Ascendente (hit + rompe 2 cargas escudo player).
- [ ] MAGE R2 usa Nova de Hielo (AoeTelegraph + AoE + FREEZE).

**Zona 4 (VIENTO/LUZ):**
- [ ] MELEE R2 usa Salto de Asalto (jump arc + landing AoE + knockback).
- [ ] MAGE R2 usa Ráfaga Arcana (3 proyectiles secuenciales).

**Si variants no aplican:** mirar `world._apply_zone_skill_variant` + `ZONA_SKILL_VARIANTS` dict.

---

### [ ] 15. Mini-boss banner zona 4 etapa 3
**Zona 4 → completar etapas 1-2 → entrar etapa 3.**
- [ ] Banner muestra "MINI-BOSS — ETAPA 3 / 6" en color dorado tamaño intermedio (no normal ni BOSS rojo).
- [ ] Capitán de los Vientos (Archer R3 LUZ) spawneado.

---

### [ ] 16. FRACTURA single-use consume
**Atacar enemy con arma TIERRA varias veces hasta ver FRACTURA aplicada (30% chance).**
- [ ] Siguiente hit que reciba el enemy → +20% damage.
- [ ] Tras consumir, FRACTURA removida (próximo hit base).

**Si no consume:** mirar `HurtboxComponent.receive_hit` después de aplicar multiplicador, debe haber `se.remove(&"fractura")`.

---

### [ ] 17. DESEQUILIBRIO interrumpe ataques
**Atacar enemy con arma VIENTO mientras enemy está en TELEGRAPH (cargando ataque).**
- [ ] 30% chance enemy cancela el state (cambia a RECOVERY).
- [ ] Cooldowns enemy +1.5s (más tiempo entre ataques).

**Si no interrumpe:** mirar `Enemy._on_status_applied(&"desequilibrio")`.

---

### [ ] 18. Taunt MMO real preservado (Zona 1)
**Spawn Tank R2 + player con espada.** Tank cast Taunt:
- [ ] Marker "!" pulsante sobre tank.
- [ ] Flash rojo pantalla.
- [ ] Player **forzado** a girar hacia tank (override input).
- [ ] Pull horizontal hacia tank hasta pegarse (35px).
- [ ] Player conserva salto/ataque/bloqueo/dash.
- [ ] 100% del daño del player a aliados → tank.
- [ ] Damage floater grande naranja sobre tank.

**Si Taunt no funciona:** mirar `player.set_taunt_source(tank)` API + `_handle_input` override.

---

### [ ] 19. Player skills active — más casos
**Equipar Curación slot 0 (override loadout):**
- [ ] `PlayerSkillSystem.equip(0, load("res://resources/player_skills/curacion.tres"))`
- [ ] Tecla 1 → recupera 30% HP máx. Costo 60 Furia, CD 15s.

**Equipar Sombra slot 2:**
- [ ] Tecla 3 → invis 2s + próximo golpe garantiza ventaja elemental. Costo 70, CD 25s.

---

### [ ] 20. Save loadout persistencia
**Cambiar skill loadout (debug):**
```gdscript
PlayerSkillSystem.equip(0, load("res://resources/player_skills/escudo_magico.tres"))
SaveSystem.save_now()
```

Cerrar Godot → reabrir → cargar save:
- [ ] Slot 0 sigue siendo Escudo Mágico (no se reseteó al default Embestida).

**Si no persiste:** mirar autoload order (PlayerSkillSystem antes de SaveSystem) + `_serialize_state/_restore_state`.

---

## 🟢 BAJO — edge cases + polish

### [ ] 21. UI display elementos VIENTO/LUZ/SOMBRA
**Abrir Inventario (tecla I) con item VIENTO/LUZ/SOMBRA equipado.**
- [ ] Display name correcto ("Viento", "Luz", "Sombra").
- [ ] Color del nombre correcto (verde-blanco VIENTO, dorado-cream LUZ, púrpura SOMBRA).
- [ ] HUD combat muestra elemento equipado con color correcto.

---

### [ ] 22. Items dedicados nuevos drop/equip
**Inventario debug add:**
```gdscript
InventorySystem.add_item(load("res://resources/items/weapons/arco_huracan.tres"))
InventorySystem.add_item(load("res://resources/items/armor/cota_glacial.tres"))
```
- [ ] Aparecen en inventario.
- [ ] Equipables.
- [ ] Stats aplicados (verificar HP/dmg/def post-equip).

---

### [ ] 23. Recetas crafteo nuevas
**Abrir CraftingScreen:**
- [ ] `craft_peto_brasas` visible (require 8 ascuas + 3 hierro_rojo + 1 nucleo_igneo).
- [ ] `craft_aegis_igneo` visible.
- [ ] `craft_cota_cuero_glacial` visible.

**Materials suficientes → craft:**
- [ ] Item creado y sumado al inventario.
- [ ] Materiales restados.

---

### [ ] 24. ShieldComponent.consume_charge_force
**Cargar a player con shield equipado. Spawn Tank R2 zona 3 (Gancho Ascendente).**
- [ ] Tank cast Gancho → tu escudo pierde 2 cargas inmediatamente.
- [ ] Si tenías 2 cargas → quedaste sin escudo. Si tenías 3 → quedan 1.

---

### [ ] 25. Arma Imbuida bypass shield
**Spawn Melee R2 con `r2_melee_arma_imbuida.tres` asignado.**
- [ ] Enemy castea buff 5s + tinte naranja.
- [ ] Mientras buff activo, ataques básicos del enemy NO son bloqueados por shield (incluso si player bloquea con cargas disponibles).

---

### [ ] 26. Status effects nuevos cosmico
**Equipar arma LUZ + atacar enemy:**
- [ ] Si proyectil (vara_luz) → player heals si source_entity tracking funciona.
- [ ] Si melee LUZ → player heals directo.

**Equipar arma SOMBRA + matar al player con miasma activo:**
- [ ] Verificar daño bypass armor visible en damage floaters.

---

## 📋 Notas + bugs detectados

(Anotar acá lo que falle o se sienta raro.)

```
-
-
-
```

---

## 🎯 Criterio de cierre Fase 3 lógica

Cierre completo cuando:
- ✅ Items 1-20 todos pasan (bloqueantes + alto + medio).
- ⚠ Items 21-26 al menos 70% pasan (edge cases — algunos pueden quedar como TODO post-visual).

**Post checklist:** abrir nueva sesión para visual estético (sprites + parallax + audio + VFX).
