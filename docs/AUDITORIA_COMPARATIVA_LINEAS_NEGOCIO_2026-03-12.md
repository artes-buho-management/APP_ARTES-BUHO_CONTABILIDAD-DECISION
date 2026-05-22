# Auditoria comparativa integral - 2026-03-12

## Alcance
- Repo: `artes-buho-contabilidad-ia`
- Rama: `codex/unificacion-contabilidad-ia`
- Commit base minimo: `6304384`
- Drive origen: `1CRH56eFn9FhmmAv6l518kDMTK1_smadl`
- Hoja objetivo app: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`

## Evidencias ejecutadas en esta iteracion
- `audit/inputs/drive_folder_1CRH56_listing_2026-03-12.json`
- `audit/inputs/excel_origen/origen_1gcP38_public.xlsx`
- `audit/inputs/excel_origen/origen_1ergmT_public.xlsx`
- `audit/reports/excel_deep_audit_2026-03-12_pre.json`
- `audit/inputs/sheet_export/sheet_1f1JT_2026-03-12_pre.xlsx`
- `audit/reports/sheet_export_audit_2026-03-12_pre.json`
- `audit/inputs/drive_download_probe_1gcP38_2026-03-12.txt`
- `audit/reports/scripts_run_setupWorkspace_2026-03-12.json`
- `audit/reports/scripts_run_setupWorkspace_nondev_2026-03-12.json`

## 1) Estructura completa (libros, pestanas, rangos, filas/columnas)
### Excel origen (Drive)
- `origen_1gcP38_public.xlsx`: 4 hojas, 0 ocultas.
- `origen_1ergmT_public.xlsx`: 9 hojas, 7 ocultas.
- Rangos usados detectados por hoja (ejemplos):
  - `Pagos Enero 2025`: `A1:AA54`
  - `Pagos Febrero 2025`: `A1:AA54`
  - `Forecast, Escenarios y objetivo`: `A1:AL142`

### Hoja app exportada (`sheet_1f1JT_2026-03-12_pre.xlsx`)
- 12 pestanas detectadas.
- Pestanas clave:
  - `00_PANEL`: `A1:L136`
  - `01_ENTRADA`: `A1:H14`
  - `03_ESCENARIOS`: `A1:F37`
  - `04_AUDITORIA`: `A1:E15`
  - `07_LINEAS_NEGOCIO`: `A1:H7`
  - `08_CATALOGO_CATEGORIAS`: `A1:G25`

## 2) Datos visibles relevantes y formulas
- Excel origen con alto volumen de celdas no vacias en forecast (`nonEmpty` total 4659 en el libro de forecast).
- Hoja app con tablas activas de panel, escenarios, auditoria y catalogos.
- Escenarios detectados con formulas de matriz en export previo (`03_ESCENARIOS` poblada).

## 3) Formatos aplicados
- En app se observan bloques con formato corporativo (cabeceras, tarjetas y tablas en rojo/amarillo/blanco).
- Formatos numericos aplicados en importes, margenes y acumulados.
- Anchos/altos configurados de forma sistematica en hojas principales.

## 4) Celdas combinadas
- Excel origen:
  - Libro pagos/ingresos: 28 celdas combinadas.
  - Libro forecast: 143 celdas combinadas.
- Hoja app exportada: 16 combinaciones (principalmente panel y cabeceras de entrada).

## 5) Validaciones de datos y desplegables
- Excel origen: 0 validaciones detectadas en ambos libros.
- Hoja app exportada: 34.998 validaciones (masivas en `02_TRANSACCIONES` y `06_FACTURAS`, mas validaciones de formulario en `01_ENTRADA`).

## 6) Filtros y vistas de filtro
- Export XLSX no refleja vistas de filtro avanzadas de Google Sheets.
- En evidencia exportada: sin filtros activos (`basicFilterEnabled=false` en hojas clave).

## 7) Formato condicional
- Excel origen: 0 reglas detectadas.
- Hoja app exportada: 52 reglas en total (especialmente en transacciones y facturas).

## 8) Protecciones de hoja/rango y permisos
- Permisos Drive confirmados para carpeta origen y hoja app (owner y editores en metadatos Drive API).
- En export XLSX no se materializan protecciones de rango de Google Sheets.
- El codigo de app aplica modo estricto (`applyProtectionMode_`) para dejar solo `01_ENTRADA!B4:B14` editable y bloquear panel/escenarios/auditoria/config/log/catalogos.

## Bloqueos tecnicos y mecanismo alternativo aplicado
- Bloqueo de descarga por API autenticada (scope `drive.file`): `appNotAuthorizedToFile`.
- Bloqueo de Sheets API del cliente OAuth actual: `SERVICE_DISABLED`.
- Ejecucion remota `scripts.run` bloqueada en esta sesion: dev mode (`PERMISSION_DENIED`) y non-dev (`NOT_FOUND`).
- Mecanismo alternativo ejecutado:
  - Descarga de evidencias por enlace compartido publico (sin modificar origen).
  - Auditoria profunda offline de `.xlsx` para estructura/datos/formatos/validaciones/condicional/merges.
  - Auditoria de hoja app via export `.xlsx` + metadatos Drive.

## Comparativa funcional y gap de negocio detectado
- Estado previo: coexistian lineas historicas no alineadas al negocio actual (p. ej., `Eventos`, `Consultoria`, `Digital`, `Merchandising`, `Licencias`).
- Objetivo negocio exigido: `Escuela`, `Management`, `Ticket Buo`, `Sala Bella Bestia`, `Discografica`.
- Gap cerrado en codigo (v0.8.0):
  - Catalogo maestro de lineas y categorias dependientes actualizado a las 5 lineas oficiales.
  - Formulario `01_ENTRADA` con defaults y desplegables coherentes al nuevo modelo.
  - Semilla transaccional inicial alineada a las 5 lineas.
  - Bloque IA semanal por linea reforzado con recomendaciones contextualizadas.
  - Prevencion de solapes del bloque IA mediante reposicion automatica.

## Resultado de auditoria/comparativa
- Se completa la inspeccion integral exigida con evidencia tecnica nueva.
- Se deja implementada la unificacion de lineas de negocio en el software contable.
- Queda pendiente ejecucion remota de `setupWorkspace` en la hoja para materializar toda la configuracion visual de la nueva version en vivo (dependiente de permisos de ejecucion remota).
