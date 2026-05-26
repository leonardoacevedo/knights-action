# docs/handoffs/

**Pase de guión entre sesiones de Claude Code.** Para que ninguna sesión arranque "en cero" — siempre hay un estado documentado al que enchufarse.

## Cómo funciona

```
┌────────────────────────────────────────────────────────────────┐
│ Leo trabaja una sesión con Claude                              │
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼ al terminar
              Leo escribe: "genera resumen"
                           │
                           ▼
              Claude ejecuta /genera-resumen
                           │
                           ├─▶ docs/handoffs/YYYY-MM-DD-HHMM.md  (histórico)
                           └─▶ docs/handoffs/LATEST.md           (entrypoint)
                           
                           
┌────────────────────────────────────────────────────────────────┐
│ Próxima sesión arranca                                          │
└──────────────────────────┬─────────────────────────────────────┘
                           │
                           ▼
              Hook SessionStart en .claude/settings.json
              ejecuta: Get-Content docs/handoffs/LATEST.md
                           │
                           ▼
              Su contenido entra automáticamente al contexto
                           │
                           ▼
              Claude arranca sabiendo dónde quedó todo
```

## Archivos en esta carpeta

| Archivo | Propósito |
| :--- | :--- |
| `README.md` | Este archivo. Convenciones. |
| `LATEST.md` | **Siempre el más reciente.** Lo lee el hook SessionStart automáticamente. Se sobrescribe en cada /genera-resumen. |
| `YYYY-MM-DD-HHMM.md` | Histórico inmutable. Una entrada por /genera-resumen ejecutado. |

## Cuándo correr /genera-resumen

- ✅ Al terminar una sesión productiva (cambios al repo, decisiones, plan revisado).
- ✅ Antes de cerrar la app si trabajaste >1h.
- ✅ Al final de un sprint de features (después de mergear/cerrar tareas).
- ✅ Cuando vas a pausar el proyecto por varios días.
- ⚠️ Pregunto antes de generarlo si en la sesión NO hubo cambios al repo (puede igual valer si discutimos diseño, pero confirmá vos).

## Cuándo NO correr /genera-resumen

- ❌ Cada 5 min (inflás el historial).
- ❌ Tras una sesión 100% lectura sin decisiones nuevas.
- ❌ Como "checkpoint cosmético" sin progreso real.

## Estructura del archivo de handoff

```markdown
# Handoff — <fecha-hora legible>

**Sesión:** <foco principal de la sesión>
**Fase del proyecto:** <#1-5 + nombre>
**GDD versión vigente:** <vN.M>
**Generado por:** /genera-resumen

---

## 1. Qué se hizo en esta sesión
- Lista breve de cambios. Una línea por cambio. Path completo.

## 2. En qué estamos ahora
- Estado del proyecto tras la sesión. Decisiones tomadas y pendientes.

## 3. Qué sigue
- Próximo paso recomendado (UNA acción concreta).
- Backlog corto.
- Cosas a verificar manualmente en Godot (Leo).

## 4. Contexto necesario para la próxima sesión
- Reglas efímeras, atajos, trade-offs acordados que NO están en CLAUDE.md ni GDD.

## 5. Archivos clave de esta sesión
Tabla: path | cambio | razón.
```

Detalle completo y reglas en [`.claude/commands/genera-resumen.md`](../../.claude/commands/genera-resumen.md).

## Reglas

1. **Histórico inmutable.** Una vez generado, NO se borran ni se editan los `YYYY-MM-DD-HHMM.md`. Si una decisión cambia, el siguiente handoff lo refleja — no se reescribe el viejo.
2. **LATEST.md siempre es copia exacta del histórico más reciente** (más una primera línea que apunta al archivo origen).
3. **Tamaño objetivo:** ≤300 líneas. Si supera, el handoff está muy detallado — resumir.
4. **No agreguen ruido.** Si la sesión fue 90% conversación y 10% código, el handoff hace foco en el código + la decisión.
5. **Si el hook SessionStart falla** por cualquier razón, la próxima sesión debe leer LATEST.md manualmente. Documentado en CLAUDE.md como red de seguridad.

## Limpieza

- **NO borrar handoffs antiguos** por defecto.
- Si la carpeta crece a >100 archivos y querés limpiar, archivá en `docs/handoffs/_archive/<año>/` en vez de borrar. Eso es una acción de mantenimiento que **requiere consulta** según regla #1 del proyecto.

## Si rompiste algo durante una sesión sin documentar

- Corré `/genera-resumen` igual y documentá honestamente: "feature X quedó rota porque Y, revertir cambios en `archivo.gd` antes de continuar".
- Es mucho mejor que un handoff mentiroso.
