# Auditoria Hoja Post Automatizacion de Permisos (2026-03-13)

Fuentes principales:
- `audit/reports/remote_sheet_deep_audit_2026-03-13_pre_next_block.json`
- `audit/reports/remote_sheet_deep_audit_2026-03-13_post_permission_selfheal_step.json`
- salida de `tools/remote_refresh_decision_panel.ps1` (autocorreccion de permisos)

## 1) Estructura completa (libro, pestanas, rangos usados, filas/columnas)
- Spreadsheet: `💼 ARTES BUHO`
- Locale/Timezone: `es_ES` / `Europe/Madrid`
- Total pestanas: `13`

Resumen estructural:
- `00_PANEL` -> usado `A1:L97`, grid `100x12`.
- `01_ENTRADA` -> usado `A1:H14`, grid `60x8`.
- `02_TRANSACCIONES` -> usado `A1:K5`, grid `5000x11`.
- `03_ESCENARIOS` -> usado `A1:I4`, grid `220x16`.
- `04_AUDITORIA` -> usado `A1:E11`, grid `3000x8`.
- `05_PRESUPUESTO` -> usado `A1:J13`, grid `400x10`.
- `06_FACTURAS` -> usado `A1:M5`, grid `5000x13`.
- `07_LINEAS_NEGOCIO` -> usado `A1:H7`, grid `220x8`.
- `08_CATALOGO_CATEGORIAS` -> usado `A1:G40`, grid `400x8`.
- `00_GUIA_USO` -> usado `A1:J16`, grid `70x12`.
- `98_LOG` -> usado `A1:D9`, grid `5000x8`.
- `99_CONFIG` -> usado `A1:C21`, grid `201x6`.
- `Auditoria_1h` -> usado `A1:F1`, grid `1000x26`.

## 2) Datos visibles relevantes y formulas
- `00_PANEL` mantiene formulas de consolidacion (`SUMIFS`, `COUNTIF`, `ARRAYFORMULA`, `SCAN`) para KPIs y acumulados.
- `01_ENTRADA` mantiene captura simplificada en `B4:B11` y formulas de impacto en `D6:H6`.
- `02_TRANSACCIONES` y `03_ESCENARIOS` conservan calculo y estructura para toma de decisiones.

## 3) Formatos aplicados
- Tipografias detectadas en cabeceras/rangos: `Arial` y `Montserrat` (segun hoja).
- Formato monetario principal: `#,##0.00 [$€-es-ES]`.
- `00_PANEL`: alturas compactadas (`24/22` px en bloques bajos) y columnas armonizadas.
- `01_ENTRADA`: estilo corporativo rojo/amarillo/blanco, bloque de entrada legible y centrado.

## 4) Celdas combinadas
- `00_PANEL`: `16` combinaciones.
- `01_ENTRADA`: `6` combinaciones.
- `03_ESCENARIOS`: `2` combinaciones.
- `00_GUIA_USO`: `7` combinaciones.

## 5) Validaciones de datos y desplegables
- `01_ENTRADA`: `4` validaciones activas:
  - `B5` linea de negocio desde `07_LINEAS_NEGOCIO`.
  - `B8` estado (`pendiente/confirmado/cancelado`).
  - `B9` cuenta (`BBVA/Caixa/Santander/Stripe/Caja`).
  - `B11` origen (`Banco/Tarjeta/Transferencia/Efectivo/Manual/Resumen mensual`).
- `02_TRANSACCIONES`: `28` validaciones (tipo, linea, categoria, subcategoria, cuenta, estado, origen).

## 6) Filtros y vistas de filtro
- `basicFilter=false` en las hojas auditadas tras esta iteracion.
- `filterViews=0` (sin vistas personalizadas).

## 7) Reglas de formato condicional
- `00_PANEL`: `6` reglas (semaforo y alertas de estado).
- `02_TRANSACCIONES`: `36` reglas.
- `05_PRESUPUESTO`: `3` reglas.
- `06_FACTURAS`: `24` reglas.

## 8) Protecciones de hoja/rango y permisos aplicados
- Todas las hojas auditadas mantienen protecciones activas (`count=1` por hoja principal) en modo aviso (`warningOnly`).
- Descripciones de proteccion con prefijo `LOCKDOWN_SIGUIENTE_PASO_*`.
- `01_ENTRADA` sigue siendo el punto de captura editable guiado para usuarios no tecnicos.

## Resultado tecnico de esta fase
- Se endurecio `tools/remote_refresh_decision_panel.ps1` para detectar OAuth v2 de `.clasprc`.
- Se implemento autocorreccion de permisos del proyecto Apps Script:
  - nuevo script `tools/sync_script_permissions_service_account.ps1`.
  - resultado: se sincronizaron usuarios y se anadio `danielgomezartesbuho@gmail.com` al script.
- `scripts.run` sigue devolviendo `403 PERMISSION_DENIED` con el token OAuth local actual, pero:
  - el fallback por API de Sheets queda activo y estable.
  - el panel y layout se siguen actualizando automaticamente sin bloqueo operativo.
