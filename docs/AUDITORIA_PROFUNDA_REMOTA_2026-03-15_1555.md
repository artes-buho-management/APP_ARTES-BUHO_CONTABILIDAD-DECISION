# AUDITORIA PROFUNDA REMOTA - 2026-03-15 15:55

## 1) Alcance auditado
- Hoja Google productiva: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`
- Scripts remotos:
  - `tools/remote_decision_mode_minimal.ps1`
  - `tools/audit_sheet_remote_deep.ps1`
  - `tools/publish_manual_drive.ps1`
- Excel madre:
  - `C:\Users\elrub\Downloads\Copia de 1. Forecast y flujo caja 2026 (1).xlsx`
  - `C:\Users\elrub\Downloads\Copia de 1. 2026 Pagos e ingresos .xlsx`

Evidencias generadas:
- `audit/reports/remote_sheet_deep_audit.json`
- `audit/reports/excel_deep_audit_2026-03-15_full.json`

## 2) Resultado global de calidad
- Estado general: `OK`
- Errores de formula: `0`
- Solapes de graficos: `0`
- Graficos fuera de rango: `0`
- Hojas visibles protegidas: `SI`
- Validaciones activas en entrada: `28`

## 3) Inspeccion completa de hoja (checklist obligatorio)

### 3.1 Estructura completa (libro, pestanas, rangos usados, filas/columnas)
- Libro: `💼 ARTES BUHO`
- Locale: `es_ES`
- Zona horaria: `Europe/Madrid`
- Pestanas totales: `13`
- Pestanas visibles: `00_PANEL`, `01_ENTRADA`, `00_GUIA_USO`

Detalle por pestana:
1. `00_PANEL` | visible | usado `'00_PANEL'!A1:L55` | tamano `130 x 12`
2. `01_ENTRADA` | visible | usado `'01_ENTRADA'!A1:H12` | tamano `220 x 8`
3. `02_TRANSACCIONES` | oculta | usado `'02_TRANSACCIONES'!A1:K5` | tamano `5000 x 11`
4. `03_ESCENARIOS` | oculta | usado `'03_ESCENARIOS'!A1:I4` | tamano `220 x 16`
5. `04_AUDITORIA` | oculta | usado `'04_AUDITORIA'!A1:E11` | tamano `3000 x 8`
6. `98_LOG` | oculta | usado `'98_LOG'!A1:D9` | tamano `5000 x 8`
7. `99_CONFIG` | oculta | usado `'99_CONFIG'!A1:C21` | tamano `201 x 6`
8. `05_PRESUPUESTO` | oculta | usado `'05_PRESUPUESTO'!A1:J13` | tamano `400 x 10`
9. `Auditoria_1h` | oculta | usado `'Auditoria_1h'!A1:F1` | tamano `1000 x 26`
10. `06_FACTURAS` | oculta | usado `'06_FACTURAS'!A1:M5` | tamano `5000 x 13`
11. `07_LINEAS_NEGOCIO` | oculta | usado `'07_LINEAS_NEGOCIO'!A1:H7` | tamano `220 x 8`
12. `08_CATALOGO_CATEGORIAS` | oculta | usado `'08_CATALOGO_CATEGORIAS'!A1:G40` | tamano `400 x 8`
13. `00_GUIA_USO` | visible | usado `'00_GUIA_USO'!A1:G24` | tamano `120 x 10`

### 3.2 Datos visibles relevantes y formulas
- En `00_PANEL`:
  - KPIs en `A5`, `D5`, `G5`, `J5` (liquidez, ingresos acumulados, gastos acumulados, desviacion).
  - Radar por linea en `A10:G15`.
  - Escenarios 12M por linea en `A33:H38`.
  - Resumen global escenarios en `J33:L35`.
  - Bloque IA en `A46:D52` (formulas `FILTER` separadas para evitar `#REF!`).
- En `01_ENTRADA`:
  - Carga manual en columnas `A:E` y `H`.
  - Calculo automatico en `F` (resultado) y `G` (semaforo) con `ARRAYFORMULA`.
- Errores de formula detectados en visibles: `0`.

### 3.3 Formatos aplicados
- Colores corporativos activos:
  - Rojo principal: `#B20000`
  - Amarillo principal: `#FFD300`
  - Blanco de fondo y bloques neutros.
- Tipografia principal: `Montserrat`.
- Formato numerico:
  - Moneda EUR en KPIs y tablas de decision.
  - Porcentaje en margenes y peso por linea.
- Bordes y alineacion:
  - Tablas con bordes visibles.
  - Alineacion centrada en cabeceras y valores clave.

### 3.4 Celdas combinadas
- `00_PANEL`: 16 combinaciones.
- `01_ENTRADA`: 5 combinaciones.
- `00_GUIA_USO`: 4 combinaciones.

### 3.5 Validaciones de datos y desplegables
- Total validaciones en hoja: `28` (en `01_ENTRADA`).
- Regla de linea de negocio (`B5:B220`) con lista cerrada:
  - Escuela, Management, Ticket Buho, Sala Bella Bestia, Discografica, Eventos.
- Reglas numericas en `C:E`:
  - `NUMBER_GREATER_THAN_EQ 0`.

### 3.6 Filtros y vistas de filtro
- Filtro basico activo: `NO`.
- Vistas de filtro: `0`.

### 3.7 Reglas de formato condicional
- `00_PANEL`: `9` reglas (semaforo radar + escenarios + bloque IA).
- `01_ENTRADA`: `3` reglas (fila completa por color de semaforo).
- `00_GUIA_USO`: `0` reglas.

### 3.8 Protecciones de hoja/rango y permisos
- `00_PANEL`:
  - Protegido en rango `'00_PANEL'!A1:L130`.
- `01_ENTRADA`:
  - Proteccion de hoja completa (`'01_ENTRADA'!HOJA_COMPLETA`) con excepcion editable solo en:
    - `A5:E220`
    - `H5:H220`
  - Formulas protegidas:
    - `F5:F220`
    - `G5:G220`
- `00_GUIA_USO`:
  - Protegido en rango `'00_GUIA_USO'!A1:J120`.
- Editores detectados en protecciones:
  - `booking@artesbuhomanagement.com`
  - `robot-codex@profound-media-489618-d8.iam.gserviceaccount.com`

## 4) Auditoria profunda de Excel madre
- Workbooks auditados: `2`
- Hojas auditadas: `13`
- Rangos combinados: `99`
- Celdas con borde: `3734`
- Celdas en negrita: `908`
- Reglas condicionales detectadas: `0`
- Validaciones detectadas: `0`
- Errores de auditoria en origen: `0`

## 5) Mejoras aplicadas en esta ronda
1. `tools/remote_decision_mode_minimal.ps1`
   - Aniadidos reintentos con backoff para errores transitorios API (`429/5xx`).
   - Protecciones reforzadas:
     - panel y guia con rango explicito,
     - entrada con hoja completa + rangos editables controlados.
   - Tamaños de hoja parametrizados con constantes (`panel/input/guide`).
2. `tools/audit_sheet_remote_deep.ps1`
   - Aniadidos reintentos automáticos anti-cuota (`429`) y errores temporales.
   - Mejora en lectura de protecciones:
     - cuando la API devuelve solo `sheetId`, ahora reporta `HOJA_COMPLETA` y no un rango falso.

## 6) Riesgos abiertos y accion
- Riesgo externo OAuth de Apps Script (`invalid_grant`) puede aparecer en push remoto.
- Mitigacion activa:
  - pipeline con fallback y trazabilidad completa en reportes.

## 7) Estado final
- Hoja remota estable y lista para decision semanal.
- Sin errores de formula ni solapes graficos.
- Entrada simple y protegida para evitar roturas.
- Auditoria completa documentada y trazable.
