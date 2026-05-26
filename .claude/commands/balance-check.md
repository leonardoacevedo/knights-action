---
description: Audita números del juego — DPS, TTK, economía de drops, curva de XP, drop rates.
argument-hint: <área a auditar, ej. "TTK contra R3 nivel 12" o "economía de Piedras de Resonancia">
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). Plantillas estructuradas y números en tablas intactos. Si proponés cambio numérico → reportá antes/después claro, no caveman (regla #2: cambio numérico puede romper economía).

# /balance-check — Auditoría de balance

Vas a auditar un área numérica específica del juego. El objetivo es detectar exploits, dead-ends y curvas mal calibradas.

## Input
$ARGUMENTS

## Flujo

### 1. Delegá a `balance-engineer` (Agent)
Pasale:
- Área a auditar.
- Contexto: ¿es un cambio propuesto o estado actual?
- Datos relevantes: si hay un PR/cambio puntual, citalo. Si es estado general, dejá que lea archivos.

### 2. El agente debe responder
Esperá una respuesta con:
- Números actuales.
- Simulación (si se justifica) — el agente puede escribir scripts en `tests/sims/`.
- Comparación con valores esperados según GDD y [`.claude/docs/formulas.md`](.claude/docs/formulas.md).
- Recomendación (mantener / ajustar X → Y).
- Riesgos al ajustar.

### 3. Si hay propuesta de cambio numérico
- **NO la apliques unilateralmente** salvo que sea trivial y dentro del scope explícito del comando.
- Mostrale al usuario el "antes/después" y pedí OK.
- Si OK, aplicar el cambio y actualizar [`.claude/docs/formulas.md`](.claude/docs/formulas.md) y `docs/features/<area>.md`.

## Áreas típicas a auditar

- DPS del jugador por tier de arma (R1/R2/R3) y refinamiento (+0 a +10).
- TTK del jugador contra R1/R2/R3/Boss por nivel.
- Curva de XP: tiempo hasta cap 30.
- Economía de drops: piezas R3 craftables por hora de juego.
- Probabilidad real vs esperada del refinamiento (test con N alto).
- Distribución de Gloria: nadie debería caer bajo 500 ni subir sobre 4000 sin esfuerzo.
- Furia: ¿es realista mantener 80%+ del tiempo con build agresiva?

## Cierre

```
ÁREA AUDITADA: <...>
ESTADO ACTUAL: [números]
ESPERADO: [números según fórmulas / objetivo de diseño]
DESVÍO: [%]
RECOMENDACIÓN: [mantener / ajustar X → Y]
RIESGOS: [...]
SCRIPT DE SIMULACIÓN GENERADO: [tests/sims/...]
DOCS ACTUALIZADAS: [si aplica]
```
