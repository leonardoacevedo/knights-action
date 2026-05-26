# Los 4 Pilares de Diseño — Detalle

Los pilares son la **constitución** del juego. No se cambian. Toda decisión se evalúa contra ellos.

## Pilar #1 — Mi build importa, mi skill también.

### Qué significa
La intersección de **build** (equipo, refinamiento, skills, set bonuses, árbol) y **skill mecánica** (lectura de telegrafías, gestión de Furia, mantenimiento de Momentum, uso de dash y bloqueo) determina el resultado. Ninguno de los dos por sí solo gana.

### Aplicaciones positivas
- ✅ **Refinamiento +10:** una build pulida da +50% stats — recompensa al que invierte. Pero un jugador con build cruda y buen skill puede ganarle a uno con build +10 que no esquiva.
- ✅ **Set bonuses (§5.4):** "perseguir builds" sobre "perseguir stats". Hay decisión activa.
- ✅ **Respec barato (§6.3):** invita a experimentar builds. Más builds = más expresión.
- ✅ **Coliseo 1v1 contra Ecos:** tu build se ve, tu skill se ve, las dos cuentan.

### Violaciones a detectar
- ❌ **Pay-to-win:** comprar stats con dinero real rompe la importancia del skill.
- ❌ **Auto-combate / auto-targeting fuerte:** elimina el skill.
- ❌ **Sistemas que escalan automáticamente con el del enemigo:** rompen la importancia del build.
- ❌ **One-shot kits únicos:** convierten skill en irrelevante.

---

## Pilar #2 — Cada muerte enseña algo.

### Qué significa
Cuando el jugador muere o falla, debe poder decir "ya sé qué pasó y cómo evitarlo". Nada debe sentirse aleatorio o injusto.

### Aplicaciones positivas
- ✅ **Telegrafía obligatoria** en bosses y enemigos de alta rareza (§7.3). 0.5-1.0s mínimos.
- ✅ **Probabilidades mostradas** en refinamiento (§5.6). Si fallás +10 con 10% de chance, **lo sabías**.
- ✅ **Marcadores AoE en el suelo** antes del daño en área.
- ✅ **Decay de Furia visible** (§4.3) — el jugador sabe por qué su recurso baja.

### Violaciones a detectar
- ❌ **Daño sin warning.**
- ❌ **Stuns o disables sin tell.**
- ❌ **RNG oculto** que decide combates (esquiva enemigo del 20% no mostrada).
- ❌ **Mecánicas de boss "fase enrage"** sin signal claro.
- ❌ **Crashes en mitad de combate** (técnico — pero igual rompe pilar).
- ❌ **Hitboxes mentirosas** (visualmente no parece que pega pero pega).

---

## Pilar #3 — El ranking premia al que mejora, no al que farmea.

### Qué significa
Subir en el ranking del Coliseo debe correlacionar con **habilidad creciente**, no con tiempo invertido. Un jugador que juega 5h diarias farmeando no debe poder superar a uno que juega 30 minutos pero pelea con cabeza.

### Aplicaciones positivas
- ✅ **Gloria balanceada (§8.4):** -15 a -30 por derrota implica que farmear partidas fáciles no acumula tanto, y perder algunas te castiga.
- ✅ **Stats cap** por nivel y por refinamiento (+10 = +50% max). Hay techo.
- ✅ **Ecos asíncronos:** no podés "elegir" jugar solo a horarios cuando hay novatos online.
- ✅ **Sin equipamiento exclusivo del Coliseo top:** los items vienen de PvE, accesibles a todos.

### Violaciones a detectar
- ❌ **Energy / heart system** que limita partidas → fomenta whaling.
- ❌ **VIP / pase de batalla** con stats exclusivas.
- ❌ **Drops exclusivos del Coliseo top** que aceleran progresión.
- ❌ **Sistema de "racha"** con bonus crecientes — incentiva farmear horarios bajos.
- ❌ **Compra de XP / niveles / Gloria con dinero real.**

---

## Pilar #4 — 5 minutos bastan, 5 horas también.

### Qué significa
El juego debe respetar tanto al jugador casual de viaje en colectivo (5-10 min) como al jugador que se sienta una tarde de fin de semana. **Sesiones cortas con profundidad opcional.**

### Aplicaciones positivas
- ✅ **Etapas PvE de 2-5 min** (§7.1) — perfectas para un loop corto.
- ✅ **Batalla de Coliseo de 1-3 min** (§3.1) — entra/salí rápido.
- ✅ **Dailies de 3 misiones** (§9.1) — algo que hacer cada día sin compromiso largo.
- ✅ **Sin pérdida de progreso al cerrar app** — save constante.
- ✅ **Sin "energía" que castigue jugar mucho** ni "compromiso obligatorio" que castigue jugar poco.

### Violaciones a detectar
- ❌ **Sesiones forzadas de 30+ min** (raids, etapas que no se pueden pausar).
- ❌ **Dungeons sin checkpoints** que exigen empezar de cero.
- ❌ **Login bonuses crecientes** que castigan saltarse un día.
- ❌ **Eventos limitados que requieren X horas/día** para no perderse recompensas.
- ❌ **Crafteo con tiempos de espera reales** (3 horas para forjar — F2P tóxico).

---

## Cómo usar los pilares en una decisión

Ante cualquier feature, hacé estas preguntas en orden:

1. **¿Refuerza al menos un pilar?**
   - SÍ → seguir al paso 2.
   - NO → descartar. (Si Leo insiste, pedir justificación clara.)

2. **¿Contradice algún pilar?**
   - SÍ → descartar sin discusión.
   - NO → seguir al paso 3.

3. **¿Refuerza más de un pilar?**
   - SÍ → fuerte candidato.
   - NO → OK, pero priorizar features que refuercen múltiples.

4. **¿Está en el MVP (§11)?**
   - SÍ → pasar a planificación.
   - NO → ¿es post-launch? Backlog.

## Ejemplos resueltos

### Ejemplo A: "Sistema de Reliquias estilo roguelite"
- Refuerza #1 (más variedad de builds). Refuerza #2 (cada run enseña algo distinto).
- No contradice ninguno.
- Pero está en post-MVP (§11). **Veredicto:** posponer.

### Ejemplo B: "Daily login con +5% XP por día consecutivo"
- ¿Refuerza algún pilar?
  - #1: no.
  - #2: no.
  - #3: NO — premia al que **farmea** (entra todos los días), no al que mejora.
  - #4: NO — castiga saltarse días.
- **Veredicto:** descartar. Contradice #3 y #4.

### Ejemplo C: "Mostrar números de daño flotantes durante combate"
- Refuerza #2 (feedback claro de qué tan fuerte pegás).
- Pero en mobile satura visualmente, perjudicando #2 por exceso.
- **Veredicto:** sí, pero **off por defecto** en mobile, on por toggle.

### Ejemplo D: "Energy / Heart system que limita partidas a 5/día"
- Contradice #3 (premia comprar refills) y #4 (castiga jugar mucho).
- **Veredicto:** descartar.

### Ejemplo E: "Boss enrage al 10% HP que aumenta daño +200% sin warning"
- Contradice #2 frontalmente.
- **Veredicto:** descartar. (Si se quiere enrage, debe tener telegrafía clarísima.)
