---
description: Genera un handoff de la sesión actual en docs/handoffs/ y actualiza LATEST.md para que la próxima sesión lo lea al iniciar.
argument-hint: <opcional: notas adicionales que querés incluir en el handoff>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, PowerShell
---

# /genera-resumen — Handoff de sesión

Genera un resumen consolidado de la sesión actual para que la próxima conversación (vos misma, o una sesión nueva) arranque sin perder contexto.

## Notas opcionales del usuario
$ARGUMENTS

## Flujo obligatorio

### 1. Inspeccioná el estado real (no inventés)

Antes de escribir nada, reuní evidencia con herramientas:

- **Cambios en el repo:** `git status`, `git diff --stat`, `git log --oneline -20` si el repo está bajo git.
- **Archivos nuevos / modificados en esta sesión:** mirá los `Write` / `Edit` que ejecutaste — si dudás, releé timestamps con `Get-ChildItem -Recurse` en carpetas tocadas.
- **Estado de tasks:** `TaskList` para ver lo completed vs in_progress vs pending.
- **GDD vigente y fase actual:** `Get-Content GDD.md -TotalCount 20` para confirmar versión, y leé [`.claude/docs/fases.md`](.claude/docs/fases.md) para la fase declarada.

**No inventés progreso.** Si una feature está "implementada parcialmente", decilo así, no como "completada".

### 2. Calculá el timestamp del archivo

Formato: `YYYY-MM-DD-HHMM` en hora local del usuario.

PowerShell:
```powershell
Get-Date -Format "yyyy-MM-dd-HHmm"
```

Usalo para nombrar el archivo histórico: `docs/handoffs/2026-05-21-1410.md`.

### 3. Escribí el handoff usando el template

El template canónico está en [`docs/handoffs/README.md`](../../docs/handoffs/README.md). Estructura mínima:

```markdown
# Handoff — <fecha-hora legible>

**Sesión:** <breve descripción del foco — ej. "Setup .claude/ inicial" o "Implementación de MomentumSystem">
**Fase del proyecto:** <#1-5 + nombre>
**GDD versión vigente:** <vN.M>
**Generado por:** /genera-resumen

---

## 1. Qué se hizo en esta sesión

<Lista accionable de cambios. Una línea por cambio. Citá archivos por path.>

- [archivo creado/modificado/borrado] — [qué se hizo, en 1 línea]
- ...

## 2. En qué estamos ahora

<Estado actual del proyecto tras la sesión. Foco en lo accionable.>

- **Fase y hito:** <fase #X — qué falta para cerrarla>
- **Última feature tocada:** <nombre>
- **Estado del repo:** <limpio / con cambios sin commitear / con WIP>
- **Tests:** <pasando / pendientes / no hay>
- **Decisiones tomadas en esta sesión:**
  - <decisión 1 con justificación>
  - ...
- **Decisiones pendientes (esperan a Leo):**
  - <decisión pendiente 1>
  - ...

## 3. Qué sigue

<Acciones concretas en orden. Si hay tasks vivas en TaskList, listalas.>

- **Próximo paso recomendado:** <una sola acción concreta>
- **Backlog corto de la fase:**
  1. <item>
  2. <item>
- **Cosas a verificar manualmente (Leo, en Godot):**
  - <item>

## 4. Contexto necesario para la próxima sesión

<Cualquier cosa que la próxima sesión necesite saber y NO esté ya en CLAUDE.md o GDD.md.>

- <regla efímera o trade-off discutido>
- <atajo o convención nueva acordada>

## 5. Archivos clave de esta sesión

| Archivo | Cambio | Razón |
| :--- | :--- | :--- |
| <path> | nuevo / modificado / borrado | <1 línea> |
```

### 4. Guardalo en 2 lugares

1. **Archivo histórico:** `docs/handoffs/<timestamp>.md` con el contenido completo.
2. **LATEST.md:** sobrescribí `docs/handoffs/LATEST.md` con el mismo contenido + una primera línea que indique el archivo histórico de origen:
   ```markdown
   > **Origen:** [<timestamp>.md](<timestamp>.md) · Generado: <timestamp legible>

   # Handoff — ...
   ```

### 5. Verificá

- `Get-ChildItem docs/handoffs/` debe mostrar ambos archivos.
- Que el LATEST.md sea idéntico al histórico (excepto la línea de origen).
- Que el handoff sea **≤300 líneas** (si crece más, estás documentando demasiado fino — resumí).

### 6. Cerrá la sesión con un mensaje corto al usuario

```
Handoff generado:
  - docs/handoffs/<timestamp>.md (histórico)
  - docs/handoffs/LATEST.md (entrypoint para próxima sesión)

Próximo paso: <una línea>
```

---

## Reglas duras

1. **No inventés.** Solo escribí lo que efectivamente pasó en la sesión.
2. **No mientas sobre estado.** Si algo quedó a mitad, decilo así.
3. **Cita archivos por path completo** (relativo al repo).
4. **Resumí, no transcribas.** El handoff es un mapa, no una bitácora completa.
5. **No borres handoffs anteriores.** Son historia.
6. **Si no hay nada nuevo desde el último handoff** (sesión 100% conversación, sin cambios al repo), avisá al usuario y preguntá si igual quiere registrarlo (puede tener valor: "Leo y yo discutimos diseño de skill X, decisión: no implementar todavía").

## Anti-patrones

- ❌ Escribir handoffs antes de inspeccionar el estado real.
- ❌ Listar "trabajo futuro" que nunca se discutió en la sesión.
- ❌ Copiar el GDD entero en el handoff.
- ❌ Sobreescribir LATEST.md sin crear el histórico (perdés la trazabilidad).
- ❌ Skip de la verificación del paso 5.

## Aplicación de las 5 reglas

- **#3 (preguntar):** si tenés dudas sobre qué clasificar como "hecho" o "pendiente", preguntá antes de escribir.
- **#5 (mejoras):** si detectás que el handoff revela una decisión pendiente importante, mencionala en sección 2.
- **#4 (español):** todo el handoff en español.

## Cierre

```
HANDOFF: docs/handoffs/<timestamp>.md
LATEST ACTUALIZADO: SÍ
LÍNEAS: <n>
PRÓXIMO PASO REGISTRADO: <una línea>
```
