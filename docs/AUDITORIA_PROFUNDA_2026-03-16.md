# AUDITORIA PROFUNDA REMOTA - 2026-03-16

Fecha: 2026-03-16  
Spreadsheet: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`  
Metodo: `tools/audit_sheet_remote_deep.ps1` (cuenta de servicio, modo remoto)

## 1) ESTRUCTURA COMPLETA

Hojas visibles:
1. `00_PANEL` -> 70 filas x 12 columnas
2. `01_ENTRADA` -> 90 filas x 8 columnas
3. `00_GUIA_USO` -> 32 filas x 10 columnas

Hojas ocultas (tecnicas):
`02_TRANSACCIONES`, `03_ESCENARIOS`, `04_AUDITORIA`, `05_PRESUPUESTO`, `06_FACTURAS`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`, `98_LOG`, `99_CONFIG`, `Auditoria_1h`.

Rangos usados:
1. `00_PANEL`: `'00_PANEL'!A1:L55`
2. `01_ENTRADA`: `'01_ENTRADA'!A1:H12`
3. `00_GUIA_USO`: `'00_GUIA_USO'!A1:G24`

## 2) DATOS VISIBLES Y FORMULAS

`00_PANEL`:
1. KPI: liquidez, ingresos anuales, gastos anuales y desviacion.
2. Radar por linea: Escuela, Management, Ticket Buho, Sala Bella Bestia, Discografica, Eventos.
3. Escenarios: base/optimista/pesimista 12 meses.
4. Bloque IA con recomendacion semanal.
5. Formulas sin error detectado.

`01_ENTRADA`:
1. Tabla simple para mes, linea, ingresos, gastos, objetivo, resultado, semaforo y nota.
2. Formulas activas en:
   - `F5`: resultado por fila (arrayformula)
   - `G5`: semaforo por fila (arrayformula)
   - `H12`: boton "VER PANEL Y DECIDIR" (hipervinculo)
3. Sin `#REF!` ni `#ERROR!`.

`00_GUIA_USO`:
1. Manual rapido en tabla de pasos y lectura de semaforo.
2. Sin formulas (contenido explicativo).

## 3) FORMATOS APLICADOS

Paleta:
1. Rojo corporativo (`#B20000`) para cabeceras.
2. Amarillo corporativo (`#FFD300`) para bloques de accion.
3. Blanco y tonos claros para lectura.

Tipografia:
1. Principal: Montserrat (dominante).
2. Fallback detectado en algunos elementos: Arial (graficos/autoestilo Sheets).

Numero/fecha/moneda:
1. Moneda en EUR con 2 decimales.
2. Porcentaje con `0.00%`.
3. Fecha en formato mensual `yyyy-mm` en entrada.

Bordes/alineacion:
1. Bordes activos en tablas clave.
2. Alineacion centrada en cabeceras y bloques KPI.
3. Ajuste de texto en tablas de guia y recomendaciones.

## 4) CELDAS COMBINADAS

Conteo:
1. `00_PANEL`: 16 merges
2. `01_ENTRADA`: 5 merges
3. `00_GUIA_USO`: 9 merges

Estado:
1. Sin merges rotos.
2. Merges alineados con cabeceras y bloques visuales.

## 5) VALIDACIONES Y DESPLEGABLES

`01_ENTRADA`:
1. Validaciones activas en rango de captura (`B5:E90`).
2. `B`: lista oficial de lineas.
3. `C:D:E`: numeros `>= 0`.
4. `showCustomUi = false` para reducir ruido visual.

## 6) FILTROS Y VISTAS DE FILTRO

Estado actual:
1. No hay filtro basico activo en las 3 hojas visibles.
2. No hay filter views activas en las 3 hojas visibles.

## 7) FORMATO CONDICIONAL

`00_PANEL`:
1. Semaforo en radar (`VERDE/AMARILLO/ROJO`).
2. Riesgo en escenarios (`BAJO/MEDIO/ALTO`).
3. Riesgo IA en bloque de recomendaciones.

`01_ENTRADA`:
1. Semaforo por fila colorea la fila completa.

## 8) PROTECCIONES Y PERMISOS

Protecciones:
1. `00_PANEL` bloqueada (`DECISION_MODE_PANEL`).
2. `00_GUIA_USO` bloqueada (`DECISION_MODE_GUIDE`).
3. `01_ENTRADA` bloqueada por hoja completa con zonas editables:
   - `A5:E90`
   - `H5:H90`

Permisos del archivo (Drive):
1. `booking@artesbuhomanagement.com` como propietario.
2. Editores de equipo + cuenta de servicio `robot-codex@...`.

## RESULTADO GLOBAL DE AUDITORIA

1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Conclusión:
La hoja queda estable, sin errores de formula y sin solapes de graficos, con proteccion correcta y foco en toma de decision.
