# Ideas y Backlog de Diseño

> Documento vivo. Ideas no implementadas, propuestas, y bocetos para fases futuras (Fase 2+).
> Cada entrada lleva: **estado, pilar/es que refuerza, fase sugerida, esfuerzo (S/M/L)**.
> Cuando una idea entra al MVP real, se mueve a `docs/features/<carpeta>/<nombre>.md`.
>
> **Cómo usar:** Leo elige lo que entra al sprint de cada fase. Claude no implementa nada de acá sin confirmación.

---

## 0. Recordatorio de pilares (filtro obligatorio)

1. **Mi build importa, mi skill también.** (intersección loot ↔ reflejos)
2. **Cada muerte enseña algo.** (legibilidad, telegrafía, justicia)
3. **El ranking premia al que mejora, no al que farmea.** (skill > tiempo)
4. **5 minutos bastan, 5 horas también.** (sesiones cortas + profundidad opcional)

Si una idea no toca ninguno → se descarta. Si contradice alguno → se descarta.

---

## 1. UX Móvil — Layouts y ergonomía

### 1.1 Layout actual (Fase 1, ya en código)
```
                  TOP:  [HUD HP/Furia/Escudos/Momentum]

                                                    [INV] [J] [EQUIP]
[JOYSTICK]                                          [DSH] [B] [ATK]
```
Estado: implementado. Sirve como base para iterar.

### 1.2 Layout alternativo propuesto — "Cluster diagonal pulgar derecho"
```
                                                          [J]
                                                       [B]   [ATK]
                                                          [DSH]
[JOYSTICK]                                       [INV]              [EQUIP]
```
- **Estado:** propuesto.
- **Pilar:** #4 (sesiones cortas — menos viaje del pulgar).
- **Esfuerzo:** S (reposicionar nodos en `touch_controls.tscn`).
- **Por qué:** rombo diagonal coloca J (acción más común tras moverse) bajo el pulgar en reposo. INV/EQUIP se separan a los lados para no apretar accidental.
- **Trade-off:** menos compacto, requiere viewport amplio. Probar en celular real.

### 1.3 Skills slots dedicados (3 botones de Furia, GDD §4.2)
GDD pide 3 botones de skill. Hoy no existen. Layout propuesto cuando entren:
```
                                            [S1] [S2] [S3]   ← skills (arriba del cluster)
                                            [INV][J][EQUIP]
[JOYSTICK]                                  [DSH][B][ATK]
```
- **Estado:** pendiente (necesita sistema de Skills primero, Fase 3+).
- **Pilar:** #1 (build importa).
- **Esfuerzo:** M (necesita Skill resource + asignación + cooldown UI).
- **Visual de slot:** ícono de la skill + barra circular de Furia consumida + cooldown.

### 1.4 Inventario — propuesta de layout móvil
Hoy `inventory_screen.tscn` existe pero el layout está pensado para PC. Propuesta mobile-first:

```
┌─────────────────────────────────────────────┐
│  EQUIPADO                                   │
│  [Arma]   [Armadura]   [Escudo]             │
│  (icon)   (icon)       (icon)               │
├─────────────────────────────────────────────┤
│  MOCHILA (scroll vertical)                  │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐                    │
│  │R1 │ │R2 │ │R3 │ │R4 │                    │
│  └───┘ └───┘ └───┘ └───┘                    │
│  ┌───┐ ┌───┐ ...                            │
├─────────────────────────────────────────────┤
│  [TOCAR ITEM PARA DETALLES + EQUIPAR]       │
└─────────────────────────────────────────────┘
```
- **Estado:** propuesto. Validar el actual primero, iterar si no calza con dedos.
- **Pilar:** #4 (legibilidad rápida en 5 minutos).
- **Esfuerzo:** M (rediseño de scenes/ui/inventory_screen.tscn).
- **Detalle de item al tocar:** modal con stats, afijos, rarity color, botones EQUIPAR / DESEQUIPAR / REFINAR (Fase 3+) / VENDER (Fase 4+).

### 1.5 Pantalla de equipo dedicada (separada del inventario)
Hoy el botón EQUIP abre el mismo InventoryScreen. Propuesta: pantalla **paper-doll** con el personaje renderizado en el centro y los slots alrededor.
- **Estado:** propuesto.
- **Pilar:** #1 (visualizar la build).
- **Esfuerzo:** M.
- **Beneficio:** ver el personaje renderizado con su equipo aplicado (sword visible, escudo, armadura color) en pantalla grande sin estar jugando.

---

## 2. Sistema de Drops y Craft

### 2.1 ¿En qué fase entran?

**Recomendación:** Fase 2 — Loop core PvE (la siguiente después de cerrar Fase 1).

**Por qué Fase 2:**
- Sin drops, el loop PvE es "matar enemigos por el match-up táctico". Eso refuerza pilares #1/#2 pero queda corto en pilar #4 (¿qué obtengo de esos 5 minutos?).
- Drops desbloquean el ciclo: pelear → obtener material → craftear/refinar → re-pelear con mejor build → desafiar a Eco más fuerte (Fase 4 con Coliseo).
- Sin drops nunca se justifica volver a una zona ya completada (Modo Eco Profundo, GDD §11).

### 2.2 Modelo de drops propuesto

**Drop rate base por tier de enemy:**
| Rareza enemy | Chance de dropear material | Chance de dropear item completo |
| :---: | :---: | :---: |
| R1 (común) | 30% → 1 material zona | 0% |
| R2 (raro) | 60% → 1-2 materiales zona | 2% → 1 item R1 |
| R3 (épico) | 100% → 2-3 materiales zona | 8% → 1 item R1/R2 |
| R4 (boss) | 100% → 5-10 materiales zona + 1 material elite | 50% → 1 item R3/R4 |

**Aplicar Momentum:** `drop_rate_final = base * (1 + 0.1 * momentum)` ya está en `MomentumSystem.drop_multiplier()`. Solo conectar.

**Materiales por zona (concept para Zona 1 "Bosque de la Maleza"):**
- Común: `madera_nudosa`, `corteza_humeda`
- Raro: `savia_esmeralda`
- Elite (solo del boss): `corazon_de_roble_antiguo`

Cada zona = 3-4 materiales distintos, totalmente distintos a otras zonas (refuerza pilar #4 — vale la pena rejugar zonas para builds específicas).

### 2.3 Sistema de craft propuesto (Fase 2-3)

**Receta básica:** `N materiales + M oro = ítem aleatorio del tier`. Ejemplo:
- Receta espada R2 Tierra: 5 madera_nudosa + 3 corteza_humeda + 200 oro → Espada R2 con elemento Tierra y afijos random.

**Where:** una "Mesa de Crafteo" accesible desde menú o hub (Fase 3+ cuando haya hub).

**Costo mental para Leo:** definir 1 receta por tier × 3 elementos × 3 slots × 3 zonas iniciales = 81 recetas. Mucho. Sugerencia: empezar con SISTEMA AUTOMÁTICO que tira receta basada en materiales aportados (sin diseño manual de cada receta). Fase 3.

### 2.4 Fusión (GDD §5.5) — Fase 4+
3 piezas R(n) del mismo slot → 1 pieza R(n+1) con stats aleatorizadas. Ya está en GDD. Implementación: simple combinación + RNG en stats.

### 2.5 Refinamiento (GDD §5.6) — Fase 3
Sistema +1 a +10 con riesgo de fallar. Ya está fórmulado. Necesita:
- UpgradeManager singleton
- UI de refinamiento (escudo + barra de éxito + warning de fallo)
- Consumibles: Piedras de Resonancia, Pergaminos de Protección

---

## 3. Lógica de IA adicional para mobs

Hoy R1-R4 tienen state machine `IDLE → CHASE → TELEGRAPH → ATTACK → RECOVERY`. Funciona, pero todos los enemies se sienten parecidos. Propuestas para diferenciarlos:

### 3.1 Comportamientos por arquetipo (Fase 2-3)

#### Tank → "Embestida cargada"
- En vez de telegraph normal, **carga durante 1.5s** acumulando velocidad (visual: partículas + tinte rojo creciente).
- Suelta una embestida horizontal de 8m que puede romper bloqueo (consume 2 cargas de escudo en vez de 1).
- **Pilar:** #2 (telegrafía clara: huí o consumí 2 cargas, decisión informada).
- **Esfuerzo:** M.

#### Archer → "Disparo de seguimiento + reposicionamiento"
- Tras 2 disparos, hace dash hacia atrás 5m (evita melee).
- Ocasionalmente carga un disparo más fuerte (telegraph 1.2s, daño x2, atraviesa terreno).
- **Pilar:** #1 (build con dash es viable, build melee tiene que cerrar distancia).
- **Esfuerzo:** M.

#### Mage → "AOE telegrafiada"
- Marca un área en el suelo (círculo rojo, 1.5s) y luego explosión.
- Si el player está en el círculo cuando explota, daño masivo.
- **Pilar:** #2 + #1 (esquiva con dash bien timeado, o usá build con +mov speed).
- **Esfuerzo:** M.

#### Melee → "Combo de 3 golpes"
- En vez de 1 golpe por ATTACK, hace cadena de 3 con telegraphs cortos (0.3s entre cada uno).
- El 3er golpe es más fuerte y telegrafiado (rojo intenso).
- Permite al player aprender el ritmo del combo y bloquear el 3ro.
- **Pilar:** #2 (combo es legible una vez visto), #3 (skill de bloquear el 3ro premia mejora).
- **Esfuerzo:** M.

### 3.2 Comportamientos cooperativos entre mobs (Fase 3+)

- **Flanking:** si 2+ enemies persiguen al player, uno se va por el flanco contrario en lugar de pegarse uno detrás del otro.
- **Cover-fire (archer + melee):** archer espera a que melee llegue antes de disparar (no friendly-fire).
- **Heal/buff (futuro mob "Acolito"):** mob no-combatiente que sigue a otro y le da +30% velocidad. Matar al acolito primero es la lectura correcta.

### 3.3 Comportamientos por bajo HP (Fase 3+)

- A < 30% HP, el enemy entra a **modo desesperación**: telegraph se reduce 50% y se vuelve más agresivo.
- Indicador visual: el "!" sobre la cabeza pulsa más rápido.
- **Pilar:** #2 (advertido visualmente), #3 (skill = saber priorizar finish vs bloquear).

### 3.4 Pathfinding mejorado (Fase 4+)

Hoy es heurístico (gradual climb con plats intermedias). Funciona en escenarios simples. Para arenas complejas:
- Pre-baked NavigationPolygon por etapa (Godot lo soporta nativamente).
- Permite enemies que esquivan obstáculos sin parche de heurística.
- **Esfuerzo:** L.

---

## 4. Skills nuevas — propuestas

### 4.1 Skills pasivas activadas por combo (Leo's idea expandida)

#### "Ráfaga elemental" (R2+ weapons)
- Cada **3 hits consecutivos** sin recibir daño → próximo ataque básico libera ráfaga del elemento del arma.
- Espada de Fuego → cono de fuego frontal.
- Vara de Agua → onda circular de agua.
- Hammer de Tierra → onda sísmica (knockback).
- **Pilar:** #1 (recompensa al que mantiene combo + build de afinidad).
- **Esfuerzo:** M.
- **Diseño:** afijo "Ráfaga elemental" en armas R2+. Drop rate medio.

#### "Stance del combo" (passive set bonus)
- Set 3pc mismo elemento → cada 5 hits consecutivos, próximo ataque tiene crítico garantizado ×2.
- **Pilar:** #1 (premia builds dedicadas a un elemento).

### 4.2 Skills activas con Furia (los 3 slots del GDD §4.2)

#### Costo Furia bajo (~25)

**"Dash explosivo"** — dash que detona al final con daño AOE.
**"Escudo de viento"** — bloqueo activo 1.5s con 5 cargas (consumibles), reflejas proyectiles.
**"Salto cargado"** — salto vertical alto + slam descendente con AOE.

#### Costo Furia medio (~50)

**"Ira de Berserker"** — durante 3s: +50% velocidad de ataque, -50% defensa.
**"Curación del Maestro"** — recupera 30% HP en 1s (telegrafía: sos vulnerable).
**"Marca elemental"** — marca un enemy. Tus próximos 5 hits a ese enemy hacen +30% daño del elemento.

#### Costo Furia alto (~80-100)

**"Despertar del Coloso"** — durante 5s: tamaño x1.5, daño x1.5, no podés ser interrumpido.
**"Eco de mi mejor yo"** — invoca un eco del player que ataca por 4s (replica los últimos 4 segundos de tu input).
**"Fractura elemental"** — un solo ataque masivo (×5 daño) que ignora defensa, consume el 100% de Furia.

### 4.3 Skills situacionales (raras, dropean en R3+)

**"Contraataque perfecto"** — si bloqueás en la ventana de 6 frames del impacto, el próximo ataque tuyo es crítico ×3.
- **Pilar:** #3 (skill puro, premiable con práctica).

**"Lectura de patrón"** — tras 3 enemies muertos del mismo tipo, sus telegraphs son ×1.5 más largos para vos.
- **Pilar:** #2 + #3 (conoce a tu enemigo).

---

## 5. Ideas extra (propuestas como game-designer)

### 5.1 Critical hits con build
- **Idea:** afijo "% crítico" en armas R2+. Base 5%, max 30% con afijos.
- Crítico = ×2 daño + screen-shake leve + floater dorado en vez de amarillo.
- **Pilar:** #1.
- **Esfuerzo:** S (modificar HitboxComponent).

### 5.2 Status effects (Fase 3+)
- **Sangrado** (físico): daño en el tiempo, 5 ticks de 5% maxHP cada 1s. Aplica con armas R3+ con afijo.
- **Quemado** (Fuego): daño en el tiempo, además reduce defensa 20%.
- **Mojado** (Agua): -30% velocidad de ataque enemy, propaga eléctrico (si entra rayo en post-MVP).
- **Petrificado** (Tierra): stun 1.5s, próximo golpe rompe stun y hace ×2 daño.
- **Pilar:** #1 (build con DOTs es viable).
- **Esfuerzo:** M (StatusEffectComponent reusable).

### 5.3 Sistema de "amuletos" — 4ta pieza opcional (Fase 4+)
- Pieza extra que no entra en la fórmula de set bonus pero da pasivas únicas.
- Ejemplo: "Amuleto del Lobo" — +10% velocidad de movimiento, pierdes 5% defensa.
- **Pilar:** #1 (más opciones de build sin perder enfoque).
- **Esfuerzo:** M.

### 5.4 Daily Challenges (Fase 5 — Coliseo + meta)
- Diariamente 3 desafíos: "matá 10 mobs sin recibir daño", "completá zona 1 en <3min", "venciste a 2 Ecos".
- Recompensa: oro + 1 Piedra de Resonancia.
- **Pilar:** #4 (5 minutos diarios + razón para volver).
- **Esfuerzo:** L (necesita backend persistente).

### 5.5 Tutorial implícito por nivel de zona (Fase 2-3)
- Zona 1 etapa 1: solo melee R1.
- Zona 1 etapa 2: melee + 1 archer (introduce ranged).
- Zona 1 etapa 3: melee + tank (introduce bloqueo necesario).
- Zona 1 etapa 4: BOSS R4 con todas las mecánicas.
- **Pilar:** #2 (cada muerte enseña), #4 (escalada gradual).
- **Esfuerzo:** S (solo definir spawn lists).

### 5.6 "Perfect Dash" — recompensa de skill (Fase 2)
- Si dasheás en los 4 frames previos a un impacto inminente, ganás +25 Furia + i-frames extra 3 frames.
- Premia leer la telegrafía + reflejos.
- **Pilar:** #3 (skill puro premia mejora).
- **Esfuerzo:** S (ya tenemos i-frames del dash, solo timing detect).

### 5.7 Modo "Eco Profundo" (GDD §11) — Fase 4
- Una zona ya completada en +20 niveles. Enemies más fuertes, drops exclusivos (materiales para R4).
- Switch en el menú de selección de zona.
- **Pilar:** #4 (profundidad opcional), #3 (premia al que mejora con la build).
- **Esfuerzo:** M.

### 5.8 Replay del propio Eco (Fase 4+ — para Coliseo)
- El jugador puede ver el replay de su Eco (los inputs que grabó) peleando contra otros Ecos.
- Identifica errores propios sin necesidad de pelear de nuevo.
- **Pilar:** #3 (analizar mejora la skill).
- **Esfuerzo:** L.

### 5.9 Boss intro con cinemática mínima (Fase 2-3)
- Al entrar al stage del boss, camera zoom + slow-mo 1s + el boss hace su animación de presentación.
- No bloquea input más de 1.5s.
- **Pilar:** #4 (énfasis en el momento importante de la sesión).
- **Esfuerzo:** S.

### 5.10 Sistema de "Marcas de Maestría" por enemy (Fase 5+)
- Cada tipo de enemy tiene 3 marcas desbloqueables:
  - Matar 50 (Marca Bronce: +5% daño contra ese tipo).
  - Matar 200 sin recibir daño (Marca Plata: +10% daño).
  - Matar al rival más fuerte sin bloqueo activo (Marca Oro: 20% chance de oneshot ese tipo).
- Bonus pasivos acumulables.
- **Pilar:** #3 (premia dominio progresivo), #4 (objetivo a largo plazo).
- **Esfuerzo:** M.

---

## 6. Anti-ideas (cosas que NO entran)

Lista de "esto sonaba bien pero contradice los pilares — no implementar":

- ❌ **Stamina bar** (estilo Dark Souls). Contradice pilar #4 (frena sesiones cortas). Ya tenemos Furia + Momentum, no necesitamos otro recurso defensivo.
- ❌ **Loot box premium** (microtransacciones random). Contradice pilar #3.
- ❌ **Auto-attack / auto-play**. Contradice pilar #3 (skill irrelevante).
- ❌ **PvP en tiempo real**. Contradice fantasía del Coliseo (Ecos asincrónicos, GDD §8).
- ❌ **Save scumming** (recargar para cambiar RNG del refinamiento). Penalización -1 nivel es parte del riesgo (GDD §5.6).
- ❌ **Stats de daño elemental separados visualmente** (sumar fuego + físico para 1 número). Sumar todo en 1 número final, mostrar elemento solo en el ícono.

---

## 7. Cómo priorizar

Cuando arranque Fase 2, sugerencia de orden:

1. **Drops básicos** (sección 2.2) — barato, conecta loop.
2. **Boss R4 real Zona 1** (con `boss-designer`, GDD §10).
3. **Comportamientos de mob diferenciados** (sección 3.1) — al menos Tank embestida + Mage AOE.
4. **Layout inventario mobile-first** (sección 1.4) — Leo pidió.
5. **Critical hits** (sección 5.1) — barato, refuerza build.
6. **Refinamiento real con UpgradeManager** (sección 2.5) — necesario antes de Fase 3.

Cualquier orden distinto es válido si Leo lo decide. Esto es backlog, no roadmap.

---

## 8. Cómo Claude debe usar este doc

- **No** implementar nada de acá sin que Leo lo pida explícito por nombre/sección.
- **Sí** citarlo cuando Leo pregunte "¿qué falta?" o "¿qué podríamos hacer?".
- **Sí** agregar nuevas ideas acá (con el mismo formato) cuando surjan en conversación pero no se implementen al momento.
- **Sí** mover una idea a `docs/features/<carpeta>/<nombre>.md` cuando se confirme su implementación.
- **No** borrar ideas descartadas — moverlas a sección 6 (Anti-ideas) con justificación.

---

**Última actualización:** 24 de Mayo 2026, post-cierre Fase 1.
