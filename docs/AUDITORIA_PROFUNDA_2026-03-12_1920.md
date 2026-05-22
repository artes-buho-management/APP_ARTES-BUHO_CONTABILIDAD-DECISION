# Auditoria Profunda y Optimizacion (12/03/2026 19:20)

## Alcance ejecutado sin intervencion manual
- Inspeccion remota completa de la hoja activa: `audit/reports/artes_buho_deep_post_compact_2026-03-12.json`.
- Auditoria profunda de los Excel madre origen:
  - `C:/Users/elrub/Downloads/Copia de 1. Forecast y flujo caja 2026 (1).xlsx`
  - `C:/Users/elrub/Downloads/Copia de 1. 2026 Pagos e ingresos .xlsx`
  - salida: `audit/reports/excel_madre_deep_audit_2026-03-12-v2.json`.
- Compactacion visual en vivo aplicada por API de Google Sheets: `tools/remote_compact_live_panel.ps1`.

## 1) Estructura completa (libro, pestanas, rangos usados)
- Libro: `ARTES BUHO`.
- Locale/Zona: `es_ES` / `Europe/Madrid`.
- Total pestanas: 13.
- Visibles: `00_PANEL`, `01_ENTRADA`, `02_TRANSACCIONES`, `03_ESCENARIOS`, `05_PRESUPUESTO`, `06_FACTURAS`, `00_GUIA_USO`.
- Ocultas tecnicas: `04_AUDITORIA`, `98_LOG`, `99_CONFIG`, `Auditoria_1h`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`.
- Rangos usados principales:
  - `00_PANEL`: `'00_PANEL'!A1:L136`
  - `01_ENTRADA`: `'01_ENTRADA'!A1:B14`
  - `02_TRANSACCIONES`: `'02_TRANSACCIONES'!A1:K5`
  - `03_ESCENARIOS`: `'03_ESCENARIOS'!A1:J37`

## 2) Datos visibles y formulas relevantes
- `00_PANEL` contiene KPIs, resumen mensual y resumen por linea.
- Formula base de indicadores en panel:
  - ingresos confirmados via `SUMIFS` sobre `02_TRANSACCIONES`.
  - gastos confirmados via `SUMIFS`.
  - resultado neto = ingresos + gastos.
  - pendiente por validar via `SUMIFS` por estado `pendiente`.
- `03_ESCENARIOS` ya usa cabecera ampliada con 10 columnas:
  - Escenario, Linea de negocio, Mes, Ingresos, Gastos, Resultado, Caja acumulada, Punto de equilibrio, Brecha, Riesgo.

## 3) Formatos aplicados
- Paleta corporativa aplicada: rojo/amarillo/blanco.
- Tipografia uniforme en bloques visibles (panel, entrada, transacciones, escenarios).
- Formato monetario EUR con 2 decimales en tablas financieras clave.
- Ajustes de ancho/alto armonicos aplicados por script en vivo.

## 4) Celdas combinadas
- `00_PANEL`: 14 celdas combinadas (titulos, bloques visuales).

## 5) Validaciones de datos y desplegables
- `01_ENTRADA`: 7 validaciones.
- `02_TRANSACCIONES`: 28 validaciones.
- Desplegables operativos: tipo, linea, cuenta, estado, origen.

## 6) Filtros y vistas de filtro
- Sin filtros complejos activos en vistas visibles (no se detecta uso intensivo de filter views).

## 7) Formato condicional
- `00_PANEL`: 6 reglas.
- `02_TRANSACCIONES`: 36 reglas.
- `05_PRESUPUESTO`: 3 reglas.
- `06_FACTURAS`: 24 reglas.

## 8) Protecciones de hoja/rango y permisos
- Modelo activo: 1 proteccion por hoja principal visible + tecnicas.
- Entrada permitida en `01_ENTRADA` con rango desbloqueado de captura.
- Hojas de panel/escenarios/auditoria/log/config protegidas para evitar roturas.

## Auditoria comparativa Excel madre (origen)

### Copia de 1. Forecast y flujo caja 2026 (1).xlsx
- 9 hojas, foco en forecasting y flujos de caja mensuales.
- Hoja mas densa: `Forecast, Escenarios y objetivo` con 1408 celdas no vacias y 40 formulas muestreadas.
- Multiples versiones de flujo (01-7, 1-8, 16-8, 15-10, 31-10) -> evidencia de iteraciones manuales y riesgo de duplicidad operacional.

### Copia de 1. 2026 Pagos e ingresos .xlsx
- 4 hojas, foco en inversiones, objetivos y pagos mensuales.
- `Pagos Enero 2025` y `Pagos Febrero 2025` concentran volumen operativo (361 y 393 celdas no vacias).
- Sin validaciones de datos robustas -> alto riesgo de inconsistencias manuales.

## Cambios aplicados ahora (automatico)
- `appscript/Code.js` ajustado para:
  - panel mas compacto (sin huecos exagerados),
  - recolocacion de graficos para evitar solapes,
  - bloque semanal adelantado y con menor altura,
  - escenarios por linea con cabecera extendida,
  - refresco cada 15 minutos disponible en menu.
- Nuevo script operativo en vivo: `tools/remote_compact_live_panel.ps1`.
- Compactacion visual aplicada con exito en la hoja (103 requests).

## Estado de sincronizacion Apps Script
- Push remoto de `Code.js`: OK con perfil `booking_clasp_admin`.
- Ejecucion remota de funciones (`setupWorkspace`) bloqueada por permisos de ejecucion del script (no por codigo).

## Resultado neto de esta iteracion
- Hoja operativa mas limpia y compacta para decision.
- Lineas de negocio normalizadas para decision:
  - Escuela, Management, Ticket Buho, Eventos, Discografica.
- Base lista para seguir puliendo UX del panel con siguiente ronda visual.
