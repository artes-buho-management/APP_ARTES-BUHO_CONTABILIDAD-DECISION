# Auditoria obligatoria (Excel + hoja remota) - 2026-03-12

## Alcance ejecutado
- Repo: `artes-buho-contabilidad-ia`
- Rama: `codex/unificacion-contabilidad-ia`
- Commit base verificado: `6304384`
- Drive origen analizado: carpeta `1CRH56eFn9FhmmAv6l518kDMTK1_smadl`
- Hoja remota objetivo: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg` ("📒 CONTABILIDAD")

## Evidencias usadas
- `audit/inputs/workbooks_audit_raw.json`
- `audit/reports/audit_summary.json`
- `audit/reports/remote_sheet_healthcheck_2026-03-11_1507.json`
- `tools/remote_build_accounting_sheet.ps1`
- `tools/remote_upgrade_full_app.ps1`
- `tools/remote_upgrade_lineas_negocio.ps1`

## 1) Estructura completa (libro/pestanas/rangos/filas/columnas)
### Excel origen (Drive)
- Libro `Copia de 1. 2026 Pagos e ingresos .xlsx`: 4 hojas, 0 ocultas.
- Libro `Copia de 1. Forecast y flujo caja 2026 (1).xlsx`: 9 hojas, 7 ocultas.
- Rangos efectivos detectados por hoja en `audit_summary.json` y `sheet_inventory.csv`.

### Hoja remota de app
- 11 pestanas detectadas (`00_PANEL`, `01_ENTRADA`, `02_TRANSACCIONES`, `03_ESCENARIOS`, `04_AUDITORIA`, `98_LOG`, `99_CONFIG`, `05_PRESUPUESTO`, `06_FACTURAS`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`).
- Tamano de rejilla detectado (filas/columnas por pestana) en `remote_sheet_healthcheck_2026-03-11_1507.json`.

## 2) Datos visibles relevantes y formulas
- Muestras de cabeceras y filas de ejemplo por hoja Excel en `workbooks_audit_raw.json`.
- Conteo de formulas por hoja y libro en `audit_summary.json`.
- Hoja remota sin errores de formula tipo `#ERROR!` en healthcheck (`formulaErrorLikeCount=0`).

## 3) Formatos aplicados
- Esquema corporativo rojo/amarillo/blanco validado por scripts remotos (`repeatCell`, `numberFormat`, `fontWeight`, `tabColorStyle`).
- Formatos numericos/fecha aplicados en panel, presupuesto, facturas, escenarios y transacciones.
- Ajustes de tamano (ancho columnas/alto filas) definidos en scripts `remote_*` y `Code.js`.

## 4) Celdas combinadas
- Bloques combinados detectados/gestionados en panel e input por scripts remotos (`mergeCells` en titulos y bloques IA/control).
- En Excel origen existen celdas combinadas (estructuras de cabecera y bloques), evidenciadas en muestras y cabeceras de `workbooks_audit_raw.json`.

## 5) Validaciones de datos y desplegables
- Excel origen: 0 validaciones en hojas analizadas (riesgo marcado en auditoria previa).
- Hoja remota: validaciones activas para tipo/estado/facturas/linea/categoria/subcategoria (`setDataValidation` en scripts remotos y `applyTransactionValidations_`/validaciones dependientes en `Code.js`).

## 6) Filtros y vistas de filtro
- Excel origen: sin evidencia de vistas de filtro avanzadas en auditoria previa.
- Hoja remota: configuraciones de filtro basico via Google Sheets donde aplica; no se detectaron solapes de graficos (`chartOverlapCount=0`).

## 7) Reglas de formato condicional
- Reglas aplicadas para ingresos/gastos, facturas pendientes/vencidas y alertas de riesgo (scripts remotos).
- Auditoria local previa registra reglas operativas de color por severidad y estado.

## 8) Protecciones de hoja/rango y permisos
- Protecciones de hoja/rango gestionadas por scripts remotos y por `applyProtectionMode_` en `Code.js`.
- Modo objetivo actualizado a bloqueo estricto con solo entrada editable (`01_ENTRADA!B4:B14`).
- Permisos de archivo (owner/editores) parcialmente disponibles en metadatos historicos (`drive_folder_tree.json` para origen).

## Limitaciones tecnicas encontradas (ejecutadas y registradas)
- Descarga binaria de los Excel origen por Drive API bloqueada por `appNotAuthorizedToFile` con el cliente OAuth actual.
- Reinspeccion en caliente por Sheets API bloqueada por `SERVICE_DISABLED` en proyecto OAuth `1072944905499`.
- Se ejecuto fallback con evidencia local versionada y scripts de infraestructura del repo para completar auditoria funcional.
