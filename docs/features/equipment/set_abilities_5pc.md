# Habilidades únicas de set completo (5pc) — 1 por elemento

> **PROPUESTA Fase 4+ — validar con balance-engineer / Leo. GDD vigente v2.2.**
> Este doc NO toca código, `.tres` ni otros docs. Es insumo de diseño para la expansión elemental v3 (`docs/design/expansion-elemental-7-zonas.md`), no canon todavía.

---

## Qué es y cómo se activa

La decisión **D18** (cerrada, §2.6 + §12.4 del doc de expansión) define que la afinidad de set se calcula sobre **5 slots** — `arma`, `armadura`, `escudo`, `anillo`, `amuleto` (las **alas NO cuentan**, son slot de utilidad). El bonus de stats es incremental `(N−1)×2%` por stat desde 2pc. Y a **5 piezas del mismo elemento** se desbloquea, además del +8% de stats, **una habilidad única del elemento**.

Hoy hay **0 de esas 6 habilidades diseñadas**. Este doc las propone — una por cada elemento de set: AGUA, FUEGO, TIERRA, VIENTO, LUZ, SOMBRA. **NEUTRO no tiene habilidad de set** (no es un elemento de afinidad).

**Reglas de diseño que cumplen todas:**
- **Pasiva, no un cuarto botón.** El set bonus es pasivo por GDD §5.4 / D18. Ninguna agrega un slot de skill activa; se togglea sola al equipar/desequipar la 5ta pieza (mismo flujo que el 3pc actual, §12.4 del doc de expansión).
- **Payoff que define la build.** Cada una es el escalón final de la fantasía elemental: amplifica directamente el **status synergy on-hit** de ese elemento (GDD §5.3 / §2.5). Escala el tema que ya plantó el 3pc actual (ver columna "escala el 3pc" en cada sección).
- **Mecánica viable.** Todos los efectos reusan vocabulario ya existente o de "extensión chica" según `.claude/docs/habilidades_generales.md` §3 (DOT, PersistentHazard, slow externo, Fractura single-use, status genérico, AoE radial vía `PhysicsShapeQueryParameters2D`). No se inventa mecánica imposible. Lo que requiere infra nueva está marcado.
- **Pilares.** Build importa + skill importa (el efecto premia jugar bien, no solo equipar); legible (un solo efecto claro por set, telegrafía donde aplica); mobile-friendly (sin clutter de partículas, ≤6 partículas por efecto activo, sin spawns por frame).
- **Sin romper balance.** Ningún instakill, ninguna invuln permanente. Las ideas fuertes llevan cooldown interno (ICD) y/o condición de gatillo. **Todos los números son PROPUESTA — punto de partida para balance-engineer, no canon.**

> **Nomenclatura.** Nombres en español, temáticos, sin colisión con los 2pc/3pc existentes. Cuando se implemente, cada uno aterriza como un campo nuevo en `SetBonusData` (ej. `fuego_5pc_propagacion_radius`) leído por los componentes — igual que los flags 3pc actuales (`fuego_aoe_radius`, `agua_dash_reset_on_pass`, etc.).

---

## AGUA — "Tumba de Hielo"

**Status del elemento (Congelación):** −30% velocidad / 2s on-hit (slow legible, GDD §5.3).

- **Trigger (pasiva):** golpear a un enemy que ya está **Congelado**.
- **Efecto:** el golpe contra un objetivo Congelado hace **+35% de daño** (bonus de "shatter") y **refresca** la Congelación a duración completa. Si el objetivo recibe **3 golpes mientras sigue Congelado** dentro de la ventana, el slow se profundiza a **−50% por 1.5s** (una sola escalada; no se apila más). Sin instakill: es daño aumentado, no ejecución.
- **Números propuestos:** bonus shatter **+35% daño** vs. objetivo Congelado · refresh de Congelación en cada hit conectado · escalada a −50%/1.5s al 3er hit · ICD de la escalada profunda **6s** por objetivo (evita slow-lock permanente). El +35% no tiene ICD (es el payoff de mantener el estado), pero está topeado por ser condicional al status.
- **Sinergia con el status:** AGUA por sí sola "kitea" (slow 2s). Con 5pc, **mantener al enemy congelado se vuelve la win-condition**: cada golpe sobre hielo pega más fuerte y renueva el slow, premiando al jugador que sostiene presión sobre un blanco ralentizado en vez de soltarlo. Explota la Congelación en vez de solo aplicarla.
- **Por qué es build-defining:** convierte el slow "defensivo/kiteo" de AGUA en un **multiplicador de daño activo** — la build deja de ser "molesto pero no mata" y pasa a castigar fuerte a todo lo que logres mantener helado.
- **Escala el 3pc actual:** el 3pc AGUA ("Corriente Eterna") da movilidad infinita dasheando por enemies; el 5pc cierra el bucle dándole **daño** a esa movilidad agresiva sobre blancos congelados.
- **Viabilidad:** `StatusEffectComponent` ya expone `has(&"freeze")` / `get_magnitude` (§3 verde) y el slow externo en player ya está migrado; el bonus de daño condicional es el mismo patrón que el "daño extra al vulnerable" de `HurtboxComponent.receive_hit` (§3 verde). Contador de hits + ICD por objetivo = extensión chica.

---

## FUEGO — "Incendio en Cadena"

**Status del elemento (Quemadura):** DOT 3s, 3 dmg/tick (GDD §5.3).

- **Trigger (pasiva):** un enemy con **Quemadura** activa **muere** *o* alcanza el último tick de su DOT.
- **Efecto:** la Quemadura **se propaga** a todos los enemies en un **radio de 90px**, aplicándoles una Quemadura fresca (misma magnitud). Además, mientras tengas 5pc, toda Quemadura que apliques dura **+1 tick extra** y cada tick hace **+1 dmg** (DOT levemente más fuerte y largo). La propagación tiene ICD para que no sea una reacción en cadena infinita en hordas.
- **Números propuestos:** radio de propagación **90px** · Quemadura propagada = misma magnitud base (no escala con cada salto, evita bola de nieve infinita) · buff pasivo del DOT propio **+1 tick (3s→3.5s aprox.) y +1 dmg/tick (3→4)** · **ICD de propagación 2s** (un brote de cadena cada 2s máx, sin importar cuántos mueran). Sin cascada recursiva: un salto por brote.
- **Sinergia con el status:** FUEGO es "DOT sostenido sinérgico con armas rápidas". El 5pc lo vuelve **AoE de control de hordas**: aplicás Quemadura a uno, lo rematás, y el fuego salta al grupo. Premia armas rápidas (más aplicaciones de Quemadura → más combustible para propagar).
- **Por qué es build-defining:** transforma FUEGO de "daño single-target sostenido" a **clear de oleadas** — la identidad de la build pasa a ser "prendo fuego al grupo entero", algo que ningún otro elemento hace.
- **Escala el 3pc actual:** el 3pc FUEGO ("Brasa Persistente") ya da un AoE one-shot **al matar**; el 5pc lo reinterpreta y amplifica como **propagación de Quemadura** (no un pulso de daño suelto, sino esparcir el DOT) + un DOT propio más fuerte.
- **Viabilidad:** AoE radial sin instanciar nodos ya resuelto vía `PhysicsShapeQueryParameters2D` (patrón del FUEGO 3pc actual, doc set_bonus_system §"Decisiones técnicas"). DOT ya tiene schema (`burn.tres`, §3). "Detectar muerte con status activo" = misma señal `hit_landed` / on-kill que usa `_check_fuego_kill` hoy. Aplicar status a un array de targets del query = trivial. ICD = un timer.

---

## TIERRA — "Falla Sísmica"

**Status del elemento (Fractura):** próximo golpe recibido +20%, **single-use**, ventana 5s (GDD §5.3).

- **Trigger (pasiva):** consumir una **Fractura** (es decir, conectar el golpe potenciado +20% sobre un objetivo Fracturado).
- **Efecto:** al consumir la Fractura, esta **no desaparece del todo** — se **re-aplica automáticamente** una Fractura nueva al mismo objetivo (cooldown interno por objetivo). Resultado: Fractura deja de ser single-use y se vuelve **recurrente** — golpe potenciado, se gasta, vuelve a armarse, golpe potenciado otra vez. El +20% sigue siendo single-use por instancia (no se apilan dos Fracturas), solo que se renueva.
- **Números propuestos:** re-aplicación de Fractura al consumirla, **ICD 3.5s por objetivo** (define el ritmo "golpe fuerte cada ~3.5s sobre el mismo blanco, no cada hit") · magnitud sin cambios respecto al status base (+20%, single-use por instancia) · ventana de la Fractura re-aplicada = 5s estándar. El ICD impide que TIERRA se vuelva +20% permanente sobre todo.
- **Sinergia con el status:** TIERRA ya es "combo: Fractura + pegar fuerte". El problema del status base es que es **un solo uso** — armás el combo una vez y se acabó. El 5pc lo vuelve un **motor recurrente**: el payoff de TIERRA (golpe amplificado) deja de ser un evento y pasa a ser un ritmo sostenido contra blancos duros (ideal vs. bosses y R3+).
- **Por qué es build-defining:** convierte el "burst de una vez" en una **cadencia de golpes pesados periódicos** — la build TIERRA pasa de tanque con un combo puntual a un martillo que rompe guardia rítmicamente, especialmente fuerte en peleas largas de boss.
- **Escala el 3pc actual:** el 3pc TIERRA ("Raíz Profunda") sostiene la defensa (recupera carga de escudo); el 5pc agrega la **pata ofensiva recurrente** sobre esa base defensiva — sobrevivís *y* repetís el burst.
- **Viabilidad:** la Fractura ya se consume en `HurtboxComponent.receive_hit` (§3 verde, doc §7.5). Re-aplicarla en el mismo punto donde se consume + un timer de ICD por objetivo = extensión chica. No requiere infra nueva.

---

## VIENTO — "Ojo de la Tormenta"

**Status del elemento (Desequilibrio):** interrumpe el ataque actual + 1.5s de CD penalty (GDD §5.3).

- **Trigger (pasiva):** aplicar **Desequilibrio** a un enemy (es decir, interrumpir con éxito un ataque/cast enemigo).
- **Efecto:** cada interrupción exitosa te da un stack de **"Racha de Viento"** (buff propio, no al enemy): **+8% velocidad de movimiento y +6% velocidad de ataque por stack**, hasta **5 stacks**, **3s de duración refrescable** en cada nueva interrupción. Si llegás a 5 stacks, tu siguiente golpe **garantiza** Desequilibrio (chance 100% por un hit, luego se vuelve a la chance normal). Premia interrumpir; si dejás de interrumpir, la racha decae.
- **Números propuestos:** **+8% move speed / +6% atk speed por stack**, máx **5 stacks** (tope **+40% move / +30% atk**) · duración **3s refrescable** · a 5 stacks, **1 Desequilibrio garantizado** en el próximo hit (consume el "techo", no es permanente) · sin daño directo añadido (es un buff de tempo, no de daño bruto). El decay natural (3s sin interrumpir → pierde stacks) es el límite anti-abuso.
- **Sinergia con el status:** VIENTO es "control puro" — cancela casts. El status base no recompensa al jugador por interrumpir más allá del corte en sí. El 5pc hace que **interrumpir se auto-alimente**: cada cancelación te acelera, lo que te deja interrumpir el siguiente cast más fácil → loop de tempo. Convierte el control en **dominio de ritmo de combate**.
- **Por qué es build-defining:** la build VIENTO pasa de "molesto para casters" a un **estilo hiper-móvil de denegación**: contra enemies con casts (R3, mini-bosses) entrás en un estado donde los apagás en cadena y te volvés cada vez más rápido. Skill-expressive: recompensa leer telegrafías enemigas (Pilar 2).
- **Escala el 3pc actual:** el 3pc VIENTO ("Brisa Cortante") sube la *chance* de Desequilibrio a 45%; el 5pc construye encima un **bucle de recompensa por interrumpir** y, a tope de racha, garantiza el corte.
- **Viabilidad:** buff propio del player con stacks + timer = patrón ya usado (`espiritu_marcial`, Sed de Sangre — §2/§3). El move-speed/atk-speed buff temporal reusa el mismo mecanismo que el slow externo a la inversa. "Detectar interrupción exitosa" = la señal que ya dispara el branch Desequilibrio en `Enemy._on_status_applied(&"desequilibrio")`. Garantizar status 1 hit = mismo hook que la "ventaja elemental garantizada" del skill `sombra`/`agil_sombra_del_valle`. Sin infra nueva.

---

## LUZ — "Comunión Radiante"

**Status del elemento (Bendición Divina):** vampire heal — el atacante recupera 5% HP máx por golpe LUZ (va al atacante, no aplica status al defender — GDD §5.3).

- **Trigger (pasiva):** estar a **HP lleno** (o tope de overheal) cuando dispararías la Bendición.
- **Efecto:** la Bendición de LUZ **siempre cura** (como hoy), pero con 5pc el sustain **escala** y, cuando ya estás a tope de vida, el heal **no se desperdicia**: se convierte en un **escudo de sobrecuración temporal** (overheal → barrera) que absorbe daño, hasta un cap. Además el porcentaje de vampire heal sube. Así LUZ no "tira" la curación cuando estás full y el sustain se vuelve resiliencia ofensiva.
- **Números propuestos:** vampire heal **6% HP máx** por golpe LUZ con 5pc (sube del 5% base; nota: el 3pc LUZ ya lo lleva a 10% → con 5pc encima, **~12%** combinado, validar curva con balance-engineer para no volverlo intocable) · overheal → **escudo temporal con cap = 25% del HP máx**, decae **5% HP/s** si no se rellena · sin cap de heal por segundo aparte del implícito en la tasa de ataque. Anti-abuso: el escudo tiene cap duro (25%) y decae — no es invuln permanente ni stacking infinito.
- **Sinergia con el status:** LUZ es "sustain → agresión sostenida sin retroceder". El techo natural del vampirismo es que **a vida llena el heal se pierde**. El 5pc tapa ese hueco: el sustain excedente se vuelve **buffer ofensivo**, premiando al jugador agresivo que ya domina el daño entrante y quiere convertir su exceso de curación en más presión.
- **Por qué es build-defining:** transforma LUZ de "no muero" a **"no muero Y mi sustain me hace tanky de forma activa"** — la build se define por jugar al filo: cuanto más golpeás, más escudo de overheal generás, habilitando un estilo de combate sin retirada. Sinergiza con el ×1.2 ofensivo plano de los especiales (D7) sin depender de él.
- **Escala el 3pc actual:** el 3pc LUZ ("Bendición Amplificada") duplica el heal; el 5pc resuelve el desperdicio a vida llena convirtiéndolo en **escudo**, cerrando la fantasía de sustain total.
- **Viabilidad:** el heal de Bendición ya cura al source vía `_apply_bendicion_heal_to_source` (§7.5). Subir el porcentaje = un multiplicador (igual que `luz_bendicion_heal_mult_3pc`). El **escudo de overheal temporal** es lo único que pide infra: un pool de "shield HP" temporal en el player con decay — extensión media (similar al `add_temporary_charges` pendiente, pero numérico en HP). Marcado para balance/impl. Si se quiere MVP sin escudo: degradar a "heal +X% y se descarta el sobrante" (sin overheal) hasta tener el pool.

---

## SOMBRA — "Plaga Devoradora"

**Status del elemento (Miasma):** DOT 5s 2 dmg/tick + bypass armor + −50% Furia gen del defensor. Stack mode INDEPENDENT — snowballea lategame (GDD §5.3).

- **Trigger (pasiva):** un enemy afectado por Miasma **muere**.
- **Efecto:** al morir un enemy con Miasma, **liberás una nube de Miasma** (zona persistente) en su posición que aplica/refresca Miasma a quien la pise, **y** recuperás un poco de Furia (la presión de SOMBRA se vuelve auto-sostenible). Como el Miasma es INDEPENDENT (apila), en grupos el DOT se vuelve un **snowball**: cada muerte siembra más Miasma, que mata más, que siembra más. La nube tiene lifetime corto + ICD para que no cubra la pantalla.
- **Números propuestos:** nube persistente **radio 70px, lifetime 3s**, aplica Miasma fresca cada **1s** a quien esté dentro · **+15 Furia** al morir un enemy con Miasma (paga parcialmente el −50% Furia gen que el propio Miasma te quitaría si te lo aplicaran a vos — y premia el playstyle de presión) · **ICD de spawn de nube 2.5s** (una nube cada 2.5s máx, anti-pantalla-llena) · stacks de Miasma topeados a un máximo razonable por objetivo (ej. **3 stacks**) para que el snowball sea fuerte pero no literal-infinito. Sin instakill: es DOT acumulado, telegrafiado por la nube visible.
- **Sinergia con el status:** SOMBRA ya es "presión — DOT que ignora armor + ahoga Furia, snowball que el target no puede limpiar". El 5pc lleva el snowball a su conclusión: **las muertes alimentan más Miasma**, cerrando un bucle donde una pelea de grupo se descontrola a tu favor cuanto más dura. Es el espejo "ofensivo de desgaste" del clear de FUEGO (FUEGO = burst de cadena rápida; SOMBRA = marea lenta imparable).
- **Por qué es build-defining:** define la build como **desgaste imparable** — no matás rápido, pero una vez que el Miasma prende en un grupo, el combate se gana solo mientras sobrevivís. La recuperación de Furia la vuelve **autosuficiente** (resuelve la tensión de que SOMBRA, irónicamente, sufre con la Furia). Lategame puro, encaja con Z7 endgame.
- **Escala el 3pc actual:** el 3pc SOMBRA ("Marea Negra") sube la chance de Miasma a 45% para arrancar el snowball; el 5pc lo **propaga por muerte** + lo hace **sostenible en Furia**, completando la fantasía de plaga.
- **Viabilidad:** Miasma DOT INDEPENDENT ya existe (`poison.tres`/`miasma`, §3/§7.5). La **nube persistente** = `PersistentHazard` (Area2D con daño/aplicación por tick + lifetime) — listada como "infra parcial, extensión chica" en §3 🟡 (también la piden Salto Sísmico, Muro de Llamas, etc., así que se construye una vez y la reusan varias). "Detectar muerte con Miasma activa" = misma señal on-kill + query de status. Recuperar Furia = `furia.add(...)`. ICD = timer. Stack cap = parámetro del status.

---

## Tabla resumen — las 6 habilidades 5pc

| Elemento | Nombre (5pc) | Efecto en 1 frase |
|:--|:--|:--|
| **AGUA** | **Tumba de Hielo** | Golpear a un enemy Congelado pega +35% y refresca el slow; sostener hielo = win-condition de daño. |
| **FUEGO** | **Incendio en Cadena** | Al morir/expirar un enemy Quemado, la Quemadura salta en AoE (90px) al grupo; DOT propio +1 tick/+1 dmg. |
| **TIERRA** | **Falla Sísmica** | Consumir una Fractura la re-aplica sola (ICD 3.5s/objetivo): el golpe potenciado +20% se vuelve recurrente. |
| **VIENTO** | **Ojo de la Tormenta** | Cada interrupción (Desequilibrio) da stacks de velocidad (máx +40% move/+30% atk); a tope, 1 Desequilibrio garantizado. |
| **LUZ** | **Comunión Radiante** | Vampire heal escalado; a vida llena el overheal se vuelve escudo temporal (cap 25% HP) en vez de desperdiciarse. |
| **SOMBRA** | **Plaga Devoradora** | Muerte con Miasma → nube persistente que re-infecta el grupo + recupera Furia; snowball de desgaste sostenible. |

---

## Notas para balance-engineer / Leo

- **Todos los números son punto de partida**, marcados explícito en cada sección. Validar ICDs, magnitudes y caps en playtest. El riesgo transversal (señalado en §8 del doc de expansión) es que **LUZ/SOMBRA no eclipsen a los naturales en endgame** — vigilar especialmente el combinado 3pc+5pc de LUZ (heal ~12%) y el snowball de SOMBRA.
- **Infra a confirmar antes de implementar** (cross-ref `habilidades_generales.md` §3): `PersistentHazard` (lo piden SOMBRA 5pc + varias skills del pool → construir una vez) y el **escudo de overheal temporal** de LUZ (extensión media, único efecto que pide pool nuevo; hay fallback degradado sin escudo para MVP). El resto reusa infra ya verde.
- **Aterrizaje técnico sugerido (no canon):** cada habilidad = campos nuevos en `SetBonusData` (`{elem}_5pc_*`) + un branch de toggle en `SetBonusSystem.refresh()` cuando `active_pieces >= 5`, leídos por los componentes — mismo patrón que los flags 3pc actuales. No es trabajo de este doc; es para la fase de implementación (Fase 4+, post-Fase 3).
- **D18 / D19 dependientes:** estas habilidades asumen los 6 slots y la afinidad sobre 5 (alas excluida) ya cerrados en D17/D18/D19. No se activan hasta que exista el modelo de datos de anillo/amuleto/alas.
