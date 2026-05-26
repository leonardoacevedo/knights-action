---
description: Valida una propuesta de feature contra los 4 pilares de diseño.
argument-hint: <descripción de la feature o cambio, ej. "agregar daily reward que dé +5% XP por día consecutivo">
allowed-tools: Read, Agent
---

> **Estilo de output:** caveman full (ver [`../docs/estilo-caveman.md`](../docs/estilo-caveman.md)). El **veredicto** y el cierre estructurado intactos (es lo que Leo lee para decidir).

# /pillar-check — Validación de pilares

Evalúa la propuesta contra los 4 pilares no negociables del juego.

## Los 4 pilares

1. **Mi build importa, mi skill también.** Ni puro loot, ni puro reflejos. La intersección.
2. **Cada muerte enseña algo.** Nada debe sentirse aleatorio o injusto.
3. **El ranking premia al que mejora, no al que farmea.** El tiempo invertido cuenta menos que la habilidad.
4. **5 minutos bastan, 5 horas también.** Sesiones cortas con profundidad opcional.

## Propuesta a evaluar
$ARGUMENTS

## Flujo

### 1. Delegá a `game-designer` (Agent)
Pasale la propuesta y pedile específicamente:
1. ¿Qué pilar(es) refuerza? (con justificación de 1 línea).
2. ¿Contradice algún pilar? (con justificación de 1 línea).
3. ¿Encaja en la fase actual del proyecto?
4. ¿Encaja en el MVP (§11 GDD)?
5. Costo estimado en tiempo de Leo (dev solo).
6. Riesgos al sistema actual.
7. **Veredicto:** adelante / reformular / posponer / descartar.
8. Si "reformular", 2 variantes más baratas.

### 2. Devolvé la respuesta
Mostrá el veredicto al usuario con el resumen del agente. **No** implementes nada — este comando es solo de validación.

## Cierre

```
PROPUESTA: <...>
VEREDICTO: [adelante/reformular/posponer/descartar]
PILARES REFORZADOS: [...]
PILARES CONTRADICHOS: [...]
ENCAJE EN FASE / MVP: [SÍ / NO + razón]
COSTO ESTIMADO: [horas / días de Leo]
PRÓXIMO PASO: [si adelante, qué comando/agente; si descartar, por qué no insistir]
```
