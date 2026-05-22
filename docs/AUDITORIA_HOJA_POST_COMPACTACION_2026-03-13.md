# Auditoria Hoja Post Compactacion (2026-03-13)

Fuente principal:
- `audit/reports/remote_sheet_deep_audit_2026-03-13_post_compact_step.json`

## 1) Estructura completa (libro, pestanas y rangos)
- Spreadsheet: `💼 ARTES BUHO`
- Locale/Timezone: `es_ES` / `Europe/Madrid`
- Hojas totales: `13`

Hojas clave (rango usado y tamano):
- `00_PANEL` -> usado `'00_PANEL'!A1:L97`, grid `100x12`.
- `01_ENTRADA` -> usado `'01_ENTRADA'!A1:H14`, grid `60x8`.
- `02_TRANSACCIONES` -> usado `'02_TRANSACCIONES'!A1:K5`, grid `5000x11`.
- `03_ESCENARIOS` -> usado `'03_ESCENARIOS'!A1:I4`, grid `220x16`.
- `05_PRESUPUESTO` -> usado `'05_PRESUPUESTO'!A1:J13`, grid `400x10`.
- `06_FACTURAS` -> usado `'06_FACTURAS'!A1:M5`, grid `5000x13`.
- `00_GUIA_USO` -> usado `'00_GUIA_USO'!A1:J16`, grid `70x12`.

## 2) Datos visibles y formulas relevantes
- `00_PANEL` mantiene KPIs de caja/resultado y semaforo con formulas `SUMIFS`, `COUNTIF`, `ARRAYFORMULA`, `SCAN`.
- `01_ENTRADA` mantiene captura simple en `B4:B11` y bloque de impacto en tiempo real (`D6:H6`).
- `03_ESCENARIOS` conserva lectura de escenarios y brecha de caja para decision.

## 3) Formatos aplicados
- Tipografia: predominio `Arial` en celdas auditadas (estructuras corporativas ya aplicadas).
- Moneda: `#,##0.00 [$€-es-ES]` en paneles financieros.
- `00_PANEL`: columnas armonizadas (`132px` y `168px` final), alturas compactadas (`24px/22px`).
- `01_ENTRADA`: bloque visual rojo/amarillo, entrada amarilla y layout corto para uso rapido.

## 4) Celdas combinadas
- `00_PANEL`: `16` combinaciones (titulares, bloques narrativos y bloques IA).
- `01_ENTRADA`: `6` combinaciones (cabecera, subtitulo y resumen lateral).
- `00_GUIA_USO`: `7` combinaciones.

## 5) Validaciones y desplegables
- `01_ENTRADA`: `4` validaciones activas:
  - `B5` -> linea de negocio por rango `07_LINEAS_NEGOCIO!A2:A200`.
  - `B8` -> `pendiente|confirmado|cancelado`.
  - `B9` -> `BBVA|Caixa|Santander|Stripe|Caja`.
  - `B11` -> `Banco|Tarjeta|Transferencia|Efectivo|Manual|Resumen mensual`.
- `02_TRANSACCIONES`: `28` validaciones en cascada para tipo, linea, categoria, subcategoria, cuenta, estado y origen.

## 6) Filtros y vistas de filtro
- `basicFilter=false` en las hojas principales auditadas tras compactacion.
- `filterViews=0` en el libro.

## 7) Formato condicional
- `00_PANEL`: `6` reglas activas (semaforo y alertas).
- Resto de hojas clave auditadas sin cambios de reglas en esta fase.

## 8) Protecciones y permisos
- Protecciones por hoja activas en modo `warningOnly=true`.
- Conteo principal:
  - `00_PANEL`: `1` proteccion.
  - `01_ENTRADA`: `1` proteccion.
  - `03_ESCENARIOS`: `1` proteccion.
  - `00_GUIA_USO`: `1` proteccion.
- Modelo vigente: visualizaciones protegidas y entrada guiada para evitar roturas.

## Resultado de esta iteracion
- Compactacion aplicada sin romper formulas ni flujo operativo.
- Refresco ejecutado en vivo por fallback (`sheets_api_fallback`) con auditoria post-ejecucion.
- Manual actualizado a `v1.0.2` y republicado (Doc+PDF), con limpieza de versiones obsoletas.
