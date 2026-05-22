# Auditoria hoja post simplificacion (2026-03-13)

## Contexto
- Hoja auditada: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`
- Evidencia JSON completa: `audit/reports/remote_sheet_deep_audit_2026-03-13_post_decision_minimal.json`
- Modo aplicado: `decision_minimal_full` (2 pestanas visibles)

## 1) Estructura completa del libro
- Total de pestanas: 13.
- Visibles: `00_PANEL`, `01_ENTRADA`.
- Ocultas: `02_TRANSACCIONES`, `03_ESCENARIOS`, `04_AUDITORIA`, `98_LOG`, `99_CONFIG`, `05_PRESUPUESTO`, `Auditoria_1h`, `06_FACTURAS`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`, `00_GUIA_USO`.
- Rangos usados principales:
  - `00_PANEL`: `A1:J36` (90x12 configurado).
  - `01_ENTRADA`: `A1:H6` (220x8 configurado).
  - Backoffice oculto preservado para trazabilidad historica.

## 2) Datos visibles relevantes y formulas
- `00_PANEL`:
  - KPIs: liquidez total, ingresos YTD, gastos YTD, desviacion vs objetivo.
  - Tabla radar por linea: `QUERY` agregando desde `01_ENTRADA`.
  - Escenarios 12M: optimista/base/pesimista con formulas sobre resultado total.
  - Bloque IA semanal por linea: riesgo + recomendacion automatica por semaforo.
- `01_ENTRADA`:
  - Tabla unica de captura: `Mes`, `Linea`, `Ingresos`, `Gastos`, `Objetivo`, `Resultado`, `Semaforo`, `Nota`.
  - Formulas master:
    - `F5`: `ARRAYFORMULA` resultado (`Ingresos - Gastos`).
    - `G5`: `ARRAYFORMULA` semaforo (`VERDE/AMARILLO/ROJO`).
- Migracion automatica de base previa:
  - Filas detectadas en entrada previa: 0.
  - Filas importadas desde `02_TRANSACCIONES`: 4 (agregadas en 2 filas consolidadas).

## 3) Formatos aplicados
- Branding corporativo activo: rojo (`#B20000`), amarillo (`#FFD300`), blanco.
- Tipografia dominante: `Montserrat` en cabeceras + `Arial` en celdas base.
- Formatos numericos:
  - Moneda en KPIs, tabla radar y entrada (`CURRENCY`).
  - Porcentaje en margen (`0.00%`).
- Tamanos:
  - `00_PANEL`: filas 48/32 cabecera y 26 cuerpo, anchos armonizados 150-180 px.
  - `01_ENTRADA`: filas 48/32/26, anchos 140-380 px para lectura de notas.

## 4) Celdas combinadas
- `00_PANEL`: 13 merges (titulo, subtitulo, cards KPI y bloques de seccion).
- `01_ENTRADA`: 3 merges (titulo, subtitulo, instruccion).

## 5) Validaciones y desplegables
- `01_ENTRADA` validaciones activas:
  - Columna `B`: desplegable cerrado de lineas (`Escuela`, `Management`, `Ticket Buho`, `Sala Bella Bestia`, `Discografica`, `Eventos`).
  - Columnas `C:D:E`: numero mayor o igual a 0.
- Muestreo auditoria: 8 validaciones detectadas en celdas usadas (B5:E6).

## 6) Filtros y vistas de filtro
- Sin filtros activos en las dos pestanas visibles.
- Sin filter views activas.

## 7) Formato condicional
- `01_ENTRADA`: 3 reglas en `G5:G220` para semaforo:
  - `VERDE` fondo verde claro.
  - `AMARILLO` fondo amarillo claro.
  - `ROJO` fondo rojo claro.
- Pestanas ocultas conservan reglas historicas anteriores (no visibles para usuario final).

## 8) Protecciones y permisos
- `00_PANEL`: protegido en modo advertencia (`warningOnly`) para evitar roturas del cuadro de mando.
- `01_ENTRADA`: protegido en modo advertencia con desbloqueo solo para captura:
  - Editable: `A5:E220` y `H5:H220`.
  - Bloqueado para usuario: formulas/estado (`F:G`) y cabeceras.
- Editores preservados (equipo + robot de servicio) para mantenimiento automatico.

## Resultado operativo
- Objetivo de simplicidad cumplido: usuario final solo ve `00_PANEL` + `01_ENTRADA`.
- Sin solapes de graficos en panel (graficos embebidos eliminados en esta version para evitar dispersion visual).
- Refresco automatico cada 15 min activo con fallback ligero (`refresh_only`) sin necesidad de pulsar botones.
