# README_CODEX_CONTINUIDAD.md

## 1) Que es este proyecto
Este proyecto convierte Google Sheets en una app de **contabilidad de decision** para Artes Buho.
No busca sustituir el software contable oficial; busca **tomar decisiones rapidas** por linea de negocio.

## 2) IDs y entorno oficial
- Repositorio: `https://github.com/rubencoton/artes-buho-contabilidad-ia`
- Rama de trabajo: `codex/unificacion-contabilidad-ia`
- Spreadsheet ID: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`
- Apps Script ID: `1n74ILY87l_lgs5EWWMufVsJSyqsINKacfbmeUM27dWtlJ4HxTqnFLnHm`
- Colores corporativos: rojo / amarillo / blanco

## 3) Estructura funcional actual (modo decision)
Hojas visibles para usuario final:
1. `00_PANEL` (solo lectura): cuadro de mando, semaforo, escenarios, recomendaciones y graficos.
2. `01_ENTRADA` (editable): unica hoja para meter datos.
3. `00_GUIA_USO` (solo lectura): manual rapido dentro de la propia hoja.

Hojas tecnicas (ocultas):
- `02_TRANSACCIONES`, `03_ESCENARIOS`, `04_AUDITORIA`, `05_PRESUPUESTO`, `06_FACTURAS`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`, `98_LOG`, `99_CONFIG`, `Auditoria_1h`.

## 4) Regla de oro para cualquier agente Codex nuevo
- **No tocar manualmente** el layout de la hoja.
- Reaplicar siempre el modo decision ejecutando:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\remote_decision_mode_minimal.ps1
```

## 4.1) Regla operativa permanente de respuesta
- Antes de cerrar cada respuesta al usuario:
1. actualizar README (este y/o README principal) si cambia flujo, codigo o estructura,
2. publicar a GitHub,
3. publicar Apps Script,
4. revalidar hoja remota y manual.

## 5) Publicacion automatica completa (obligatoria antes de responder)
Comando unico:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\pipeline_respuesta_automatica.ps1 -PublishManual -CommitMessage "mensaje claro"
```

Este flujo hace:
1. Commit + push GitHub.
2. Push a Apps Script remoto.
3. Reaplica layout y formulas en Google Sheets.
4. Ejecuta refresh del panel.
5. Publica manual en Google Doc + PDF y borra versiones obsoletas.

## 6) Scripts clave (que hace cada uno)
- `tools/remote_decision_mode_minimal.ps1`: constructor principal del dashboard visible.
- `tools/audit_sheet_remote_deep.ps1`: auditoria profunda de estructura, validaciones, formato, protecciones y reglas.
- `tools/publish_manual_drive.ps1`: genera manual en Doc/PDF dentro de la carpeta del proyecto.
- `tools/pipeline_respuesta_automatica.ps1`: pipeline end-to-end de publicacion.
- `appscript/scripts/push_api.ps1`: subida de codigo Apps Script.

## 7) Checklist de calidad antes de cerrar una tarea
1. Sin errores `#REF!` ni `#ERROR!` en `00_PANEL`, `01_ENTRADA`, `00_GUIA_USO`.
2. `00_PANEL` y `00_GUIA_USO` protegidas (solo lectura).
3. `01_ENTRADA` editable solo en celdas de entrada.
4. No hay solape de graficos con tablas ni bloques de texto.
5. Semaforo visible (verde/amarillo/rojo) en radar, escenarios y recomendaciones.
6. Manual actualizado en hoja + Doc + PDF.
7. Commit en GitHub con mensaje claro.

## 8) Lineas de negocio oficiales
- Escuela
- Management
- Ticket Buho
- Sala Bella Bestia
- Discografica
- Eventos

## 9) Si aparece un fallo tipico
- Error de permisos OAuth (`invalid_grant` o `org_internal`): usar la cuenta correcta del proyecto y relanzar pipeline.
- Layout roto o tablas solapadas: reejecutar `remote_decision_mode_minimal.ps1`.
- Manual desactualizado: ejecutar pipeline con `-PublishManual`.
- Error de formulas por texto con simbolos: revisar celdas con textos que empiezan por `=` o `+`.

## 10) Objetivo de negocio que nunca debe perderse
Sistema simple para **tomar decisiones**:
- meter pocos datos,
- ver estado por linea,
- comparar escenarios,
- actuar cada semana con recomendacion clara.
