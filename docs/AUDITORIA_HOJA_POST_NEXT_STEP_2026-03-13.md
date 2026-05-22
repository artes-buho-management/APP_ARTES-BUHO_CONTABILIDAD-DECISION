# Auditoria Hoja Post Next Step (2026-03-13)

Fuente principal:
- `audit/reports/remote_sheet_deep_audit_2026-03-13_post_next_step_lockdown_warning.json`

## 1) Estructura completa
- Spreadsheet: `💼 ARTES BUHO`
- Locale/Timezone: `es_ES` / `Europe/Madrid`
- Total de hojas: `13`

Hojas (rango usado y tamano):
- `00_PANEL` -> usado `A1:L97`, grid `120x12`
- `01_ENTRADA` -> usado `A1:H14`, grid `80x8`
- `02_TRANSACCIONES` -> usado `A1:K5`, grid `5000x11`
- `03_ESCENARIOS` -> usado `A1:I4`, grid `220x16`
- `04_AUDITORIA` -> usado `A1:E11`, grid `3000x8`
- `05_PRESUPUESTO` -> usado `A1:J13`, grid `400x10`
- `06_FACTURAS` -> usado `A1:M5`, grid `5000x13`
- `07_LINEAS_NEGOCIO` -> usado `A1:H7`, grid `220x8`
- `08_CATALOGO_CATEGORIAS` -> usado `A1:G40`, grid `400x8`
- `00_GUIA_USO` -> usado `A1:J16`, grid `120x12`
- `98_LOG` -> usado `A1:D9`, grid `5000x8`
- `99_CONFIG` -> usado `A1:C21`, grid `201x6`
- `Auditoria_1h` -> usado `A1:F1`, grid `1000x26`

## 2) Datos y formulas relevantes
- `01_ENTRADA` ya esta centrada en captura simple (`B4:B11`).
- Formulas clave validadas:
  - `01_ENTRADA!D6` ingresos confirmados (`SUMIFS`).
  - `01_ENTRADA!E6` gastos confirmados (`SUMIFS`).
  - `01_ENTRADA!F6` resultado neto.
  - `01_ENTRADA!G6` pendiente validar.
  - `01_ENTRADA!H6` semaforo.
  - `01_ENTRADA!D10` ultimos movimientos (`QUERY`).

## 3) Formatos aplicados
- Tipografia dominante: `Arial` en celdas auditadas.
- Formato monetario principal: `#,##0.00 [$€-es-ES]`.
- `00_PANEL`: columnas armonizadas (`132` px y ultima `168` px), alturas base `24`.
- `01_ENTRADA`: columnas compactas (8 columnas), alturas de bloque `32/34/46`, fondo corporativo rojo/amarillo.

## 4) Celdas combinadas
- `00_PANEL`: `16` combinaciones (cabeceras y bloques narrativos).
- `01_ENTRADA`: `6` combinaciones (titulo, subtitulo, aviso, bloques laterales).
- `00_GUIA_USO`: `7` combinaciones.

## 5) Validaciones y desplegables
`01_ENTRADA`:
- `B5` -> lista por rango `07_LINEAS_NEGOCIO!A2:A200`.
- `B8` -> `pendiente|confirmado|cancelado`.
- `B9` -> `BBVA|Caixa|Santander|Stripe|Caja`.
- `B11` -> `Banco|Tarjeta|Transferencia|Efectivo|Manual|Resumen mensual`.

## 6) Filtros y vistas
- `basicFilter=true` en hojas operativas auditadas.
- `filterViews=0` (sin vistas de filtro personalizadas).

## 7) Formato condicional
- `00_PANEL`: `6` reglas.
- `02_TRANSACCIONES`: `36` reglas.
- `05_PRESUPUESTO`: `3` reglas.
- `06_FACTURAS`: `24` reglas.

## 8) Protecciones y permisos
- Protecciones activas en hojas clave con `warningOnly=true` (modo aviso).
- Descripciones tipo `LOCKDOWN_SIGUIENTE_PASO_*`.
- Objetivo: evitar errores de ejecucion en menu por bloqueos estrictos entre usuarios.

## Resultado operativo
- Entrada de datos simplificada y coherente con el flujo de decision.
- Refresco remoto aplicado en vivo por fallback (`remote_relayout_executive.ps1`) con auditoria posterior.
- Protecciones ajustadas para operacion multiusuario sin roturas de script.
