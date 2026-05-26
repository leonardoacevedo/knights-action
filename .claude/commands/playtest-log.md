---
description: Captura feedback de un playtest y lo conecta con el GDD / pilares / próximos pasos.
argument-hint: <feedback libre del playtest, ej. "el combate se siente flotante en el dash">
allowed-tools: Read, Write, Edit, Glob, Grep, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). **Excepción crítica:** la entrada que escribís en `docs/playtest/YYYY-MM-DD-<slug>.md` va **normal** (Leo o futuros colaboradores la leen en frío). El feedback bruto del usuario se preserva textual.

# /playtest-log — Registrar y procesar feedback de playtest

La regla de oro (§16 GDD): *"Si lo que diseñé acá no se siente bien al jugarlo, gana el playtest, no el documento."*

Este comando captura feedback de un playtest, lo conecta con el sistema relevante del GDD, y propone próximos pasos.

## Input
$ARGUMENTS

## Flujo

### 1. Categorizá el feedback
Antes de procesarlo, clasificalo:
- **Feel del combate** → `combat-system`.
- **Balance numérico** → `balance-engineer`.
- **UX / controles** → `ux-mobile`.
- **Diseño de enemigo / boss** → `enemy-ai` o `boss-designer`.
- **Diseño de zona / pacing** → `level-designer`.
- **Decisión de diseño global / scope** → `game-designer`.
- **Item / refinamiento** → `equipment-system`.

### 2. Pedile al agente correspondiente que evalúe
Pasale:
- El feedback textual.
- Qué parte del juego se estaba jugando.
- Qué versión / commit (si Leo lo sabe).
- Si fue Leo solo o un tester externo.

### 3. Documentá

Creá entrada en `docs/playtest/YYYY-MM-DD-<slug>.md` (si la carpeta no existe, creala):

```markdown
# Playtest <fecha> — <slug>

**Probador:** <Leo / tester>
**Versión / commit:** <...>
**Sesión:** <Zona X, Etapa Y / Coliseo / Refinamiento>

## Feedback bruto
> <copy del input del usuario>

## Categorización
- Sistema afectado: <...>
- Pilar(es) en juego: <...>

## Diagnóstico (del agente)
<...>

## Próximos pasos
1. <acción 1 con qué comando/agente>
2. <acción 2>

## Decisión: ¿GDD necesita actualizarse?
- [ ] Sí — cambio en §<...> propuesto a Leo.
- [ ] No — el problema es de implementación, no de diseño.
```

### 4. Si el feedback contradice algo del GDD
- **NO modifiques el GDD unilateralmente.**
- Avisá a Leo: "El playtest sugiere cambiar §X.Y. Mi recomendación es Z. ¿Aprobás?"
- Si Leo aprueba, actualizar GDD.md y aumentar la versión (v2.1 → v2.2) con changelog en `docs/features/gdd_changes/vN.md`.

## Reglas inviolables

1. **Todo feedback va a un archivo en `docs/playtest/`.** Sin excepciones — para tener trazabilidad.
2. **El GDD se actualiza con aprobación de Leo, nunca por iniciativa propia.**
3. **Si el feedback es vago ("se siente raro")**, pedí aclaración antes de procesarlo. Vaguedad genera cambios inútiles.

## Cierre

```
PLAYTEST LOG: docs/playtest/<fecha>-<slug>.md
CATEGORÍA: [...]
AGENTE CONSULTADO: [...]
ACCIONES PROPUESTAS: [n cambios]
GDD UPDATE NECESARIO: [SÍ - pedir OK / NO]
```
