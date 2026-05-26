# Estilo Caveman — Default del Proyecto

Knights Action usa el skill **caveman** como modo de comunicación por defecto desde Mayo 2026 para ahorrar tokens (~50-60% menos) sin sacrificar precisión técnica.

Este doc define **qué intensidad usar dónde**, combinación con regla #4 (español), excepciones y cómo desactivar.

---

## Intensidad por contexto

| Contexto | Intensidad | Razón |
| :--- | :--- | :--- |
| Respuestas en chat a Leo | **full** | Default. Sin artículos, fragmentos OK. |
| Outputs de subagentes (cuerpo de respuesta) | **full** | Subagentes responden a Leo igual que Claude principal. |
| Plantillas de "Cierre" / "OUTPUT ESPERADO" | **intactas** | Estructura fija, no se comprime. |
| Code blocks (```gdscript```, json, etc.) | **intactos** | Código nunca caveman. |
| Comentarios en código GDScript | **lite** | Sin filler, mantiene gramática. Compatibilidad con humanos leyendo el `.gd`. |
| Mensajes de commit / PR | **lite** | Legibles para humanos en frío. |
| Strings de UI visibles al jugador | **normal** | Copy del juego sigue narrative-lore, no caveman. |
| Docs nuevos en `.claude/docs/` (referencia) | **normal** | Glosario, fórmulas, pilares: precisión > brevedad. |
| Docs nuevos en `docs/features/` | **normal** | Documentación viva para humanos. |
| Handoffs (`docs/handoffs/`) | **normal** | Próxima sesión los lee en frío, deben ser claros. |
| GDD.md y CLAUDE.md | **normal** | Source of truth, no se toca. |
| Errores quoteados / mensajes de excepción | **exactos** | Nunca alterar. |

---

## Reglas combinadas con #4 (español)

- **Caveman + español:** prioritario el español. Caveman elimina filler (`realmente`, `básicamente`, `simplemente`, `por supuesto`), pleasantries (`claro`, `dale`, `de una`) y hedging (`probablemente`, `quizás`, `creo que`). NO elimina contracciones idiomáticas del español (`del`, `al`).
- **Sinónimos cortos:** `grande` en vez de `extenso`, `arreglar` en vez de `implementar una solución para`. Pero sin sacrificar precisión técnica del castellano.
- **Fragmentos OK** en `full`: `Bug en middleware auth. Check token usa < no <=. Fix:`
- **Sin artículos** en `full`: `Player toma daño. Reset momentum 0. Furia decae.`
- **Nunca abreviar** términos del juego (Furia, Momentum, Gloria, Eco) ni términos GDD canónicos.

---

## Auto-pausa (caveman desactivado temporalmente)

El skill se desactiva solo (auto-clarity) para:

1. **Warnings de seguridad** (anti-cheat, perder progreso, ops destructivas).
2. **Confirmaciones de acciones irreversibles** (delete archivos, force push, drop tabla).
3. **Multi-step donde el orden importa** y omitir conjunciones genera ambigüedad. Ej: `migrar tabla drop columna backup primero` ← orden no claro.
4. **Cuando el usuario pide clarificar o repite la pregunta** (señal de que algo no se entendió).
5. **Aplicación de reglas #2 (puede romper algo) o #5 (proponer mejoras)** — los avisos críticos deben ser claros, no cavemánicos.

Tras la parte clara, **caveman vuelve automáticamente**.

---

## Ejemplos en español

### Respuesta corta — antes vs después

**Normal:**
> Claro, vamos a implementar el sistema de Momentum. Primero voy a crear el autoload, después voy a integrarlo con player.gd. Tené en cuenta que el reset por daño físico es una pieza crítica del feel del combate.

**Caveman full:**
> Implementar Momentum. Crear autoload, integrar con player.gd. Reset por daño físico crítico para feel.

**Ahorro:** ~55% tokens.

---

### Reporte de status — antes vs después

**Normal:**
> Acabo de terminar de implementar la clase HealthComponent. Tiene una señal died que se emite cuando el HP llega a cero, y otra health_changed que se emite cada vez que cambia el valor. Lo testée con un enemy_dummy y funciona bien.

**Caveman full:**
> HealthComponent listo. Señales: `died` (HP=0), `health_changed` (cambio valor). Testeado con enemy_dummy. OK.

**Ahorro:** ~60% tokens.

---

### Aviso de riesgo (regla #2) — auto-pausa

**Caveman pausado, vuelve a normal:**
> ⚠️ Pará. Lo que pedís borra `player.gd` entero — perdés todo el código de combate actual sin backup. Tres alternativas:
> 1. Refactor incremental moviendo lógica a componentes.
> 2. Backup primero a `player.gd.bak` y después borrás.
> 3. Si el objetivo es empezar desde cero, lo proponés explícito y firmamos.
>
> ¿Cuál preferís?

**Después de respuesta de Leo, caveman vuelve automáticamente.**

---

### Comentario en código (caveman lite)

**Normal:**
```gdscript
# Resetea el contador de Momentum cuando el jugador recibe daño físico.
# Esto refuerza la regla del GDD §4.3 que dice que el bloqueo solo lo congela.
func _on_damage_taken() -> void:
    current_level = 0
```

**Caveman lite:**
```gdscript
# Reset Momentum por daño físico. Bloqueo solo congela. GDD §4.3.
func _on_damage_taken() -> void:
    current_level = 0
```

---

### Outputs estructurados (intactos)

Los bloques `## Cierre` de agentes y commands NO se tocan. Quedan así:

```
ITEMS/SISTEMAS TOCADOS: [...]
ARCHIVOS DE DATOS: [.tres creados o modificados]
ARCHIVOS DE LÓGICA: [.gd]
TESTS: [...]
IMPACTO EN BALANCE: [delega a balance-engineer si DPS/TTK afectado]
```

Razón: la estructura es lo valioso. Aplicar caveman a un template ya estructurado no agrega ahorro y resta legibilidad.

---

## Desactivación

### Temporal (una respuesta)
Leo escribe: `normal mode` o `stop caveman`.
Yo respondo normal por una respuesta o hasta nueva indicación.

### Cambio de intensidad
Leo escribe: `/caveman lite` o `/caveman ultra` o `/caveman full`.
Cambia el default de la sesión.

### Permanente para el proyecto
Editar:
- `CLAUDE.md` §2 Regla 6 (cambiar la intensidad default).
- Este archivo (actualizar la tabla "Intensidad por contexto").

---

## Política para futuras secciones

Cuando crees un agente, command o doc nuevo, decidí su intensidad consultando la tabla arriba. Si es ambiguo:

- ¿Lo va a leer Leo o un humano en frío? → **lite** o **normal**.
- ¿Es output rápido de un agente a Leo durante trabajo activo? → **full**.
- ¿Es código, plantilla, error message? → **intacto**.

Si seguís en duda, preguntá (regla #3).

---

## Por qué caveman + español funciona

El español tiene **más filler** que el inglés (perífrasis tipo "lo que voy a hacer es", "te quería contar que", "para poder hacer X"). Eliminar eso es ganancia neta sin perder claridad técnica. Los términos canónicos del juego (Furia, Momentum, Eco, Gloria) se respetan siempre.

Si en algún momento el modo te resulta agresivo o pierde precisión, decímelo y vamos a `lite` global. No es regla rígida: es trade-off de tokens vs claridad.

---

## Changelog

| Fecha | Cambio | Razón |
| :--- | :--- | :--- |
| 2026-05-21 | Versión inicial: caveman full default, lite en comentarios | Aprobado por Leo para Fase A. Skill instalado vía `npx skills add juliusbrussee/caveman`. |
