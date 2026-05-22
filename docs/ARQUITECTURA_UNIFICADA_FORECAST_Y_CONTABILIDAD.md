# Arquitectura unificada (forecast + contabilidad)

Objetivo: sustituir la estructura dispersa de muchas pestanas por un sistema claro, visual y automatizado.

## Pestanas finales (modelo simple)

1. `EntradaDatos`: formulario visual para alta de movimientos.
2. `Transacciones`: tabla canonica de todas las operaciones.
3. `Panel`: situacion global con KPI y graficos automaticos.
4. `Escenarios`: optimista/base/pesimista a 12 meses.
5. `Auditoria`: incidencias de calidad y reglas incumplidas.
6. `Config`: parametros de negocio, IA y permisos.
7. `Log`: trazabilidad tecnica.

## Reglas de oro

- Un solo ledger (`Transacciones`) como fuente de verdad.
- Nada de copiar a mano entre hojas.
- Todo grafico se recalcula automaticamente al registrar un dato.
- Escenarios construidos desde datos reales + supuestos de `Config`.

## Modelo de datos minimo (Transacciones)

Campos:

- `fecha`
- `tipo` (`ingreso` / `gasto`)
- `linea_negocio`
- `categoria`
- `subcategoria`
- `concepto`
- `cuenta`
- `importe`
- `estado` (`pendiente` / `confirmado` / `cancelado`)
- `origen`
- `nota`

## Motor de escenarios

Entradas:

- Media historica de ingresos/gastos.
- Supuestos de crecimiento en `Config`.

Salidas:

- Escenario `optimista`.
- Escenario `base`.
- Escenario `pesimista`.
- Caja acumulada mes a mes.

## Panel visual (automatico)

KPI:

- Ingresos confirmados.
- Gastos confirmados.
- Resultado neto.
- Pendiente por validar.
- Total transacciones.
- Numero de lineas de negocio.
- Ratio de confirmacion.

Graficos:

- Linea: ingresos vs gastos por mes.
- Columnas: resultado por linea de negocio.
- Circular: peso de ingresos por linea.
- Escenarios: evolucion de caja acumulada.

## IA aplicada

1. Auditoria automatica de la hoja:
   - faltan campos,
   - signos incorrectos,
   - estados invalidos,
   - importes atipicos pendientes.
2. Resumen narrativo IA para direccion:
   - situacion actual,
   - riesgos,
   - oportunidades,
   - acciones semanales.
3. Fallback heuristico si no hay API key IA activa.

## Permisos

- Modo actual: `TEAM_OPEN` (operativo para cualquier editor del spreadsheet).
- Recomendacion de hardening posterior:
  - roles por area,
  - aprobacion para movimientos de alto impacto,
  - bitacora de cambios por usuario.

## Roadmap de migracion

### Fase 1 (inmediata)

- Congelar hojas legacy (solo lectura).
- Activar estructura unificada.
- Cargar transacciones historicas en el ledger.

### Fase 2

- Validar taxonomia final de lineas/categorias.
- Ajustar escenario base con negocio real.
- Definir reglas de auditoria financiera.

### Fase 3

- Automatizar ingestiones externas.
- Activar workflow de aprobaciones y cierre mensual.
