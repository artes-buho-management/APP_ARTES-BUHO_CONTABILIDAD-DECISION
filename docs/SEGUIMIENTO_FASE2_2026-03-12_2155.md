# Seguimiento Fase 2 - 12/03/2026 21:55

## Acciones ejecutadas automaticamente

1. Publicacion remota del proyecto Apps Script:
   - Script ID: `1n74ILY87l_lgs5EWWMufVsJSyqsINKacfbmeUM27dWtlJ4HxTqnFLnHm`
   - Metodo: `appscript/scripts/push_api.ps1`
   - Resultado: `PUSH_OK`

2. Intento de ejecucion remota inmediata de funciones:
   - Funciones probadas: `rebuildDashboard`, `simulateScenarios`, `runQuickAudit`, `showStatus`
   - Endpoint: `https://script.googleapis.com/v1/scripts/{scriptId}:run`
   - Perfiles probados: `booking_workspace_full_bella`, `default`, `booking_ecosistema_apis`, `booking_clasp_admin`
   - Resultado: `403 PERMISSION_DENIED` en todos los perfiles
   - Conclusion tecnica: el despliegue de contenido funciona, pero la ejecucion remota via Execution API sigue sin permiso de llamada.

3. Aplicacion en vivo por API de Sheets (sin esperar menu manual):
   - Script: `tools/remote_relayout_executive.ps1`
   - Resultado:
     - `appliedRequests = 96`
     - `updatedRanges = 20`
     - Marca temporal: `2026-03-12T21:50:22+01:00`

4. Auditoria remota profunda post-relayout:
   - Archivo: `audit/reports/remote_sheet_deep_audit_2026-03-12_post_fase2_relayout.json`
   - Spreadsheet: `ARTES BUHO` (`1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`)
   - Locale/Timezone: `es_ES` / `Europe/Madrid`
   - Hojas auditadas: `13`

## Estado validado tras esta iteracion

- `00_PANEL`: rango usado `'00_PANEL'!A1:L97` (sin solapes detectados por API).
- `01_ENTRADA`: rango usado `'01_ENTRADA'!A1:H14`.
- `02_TRANSACCIONES`: rango usado `'02_TRANSACCIONES'!A1:K5`.
- Protecciones: visibles en auditoria (`LOCKDOWN_SIGUIENTE_PASO_PANEL` y bloqueo por hojas/paneles), manteniendo enfoque de solo entrada editable.

## Nota operativa

El flujo de publicacion y actualizacion visual queda automatico desde scripts remotos.
La unica limitacion pendiente es la ejecucion directa de funciones Apps Script por API (`scripts.run`) con permisos del caller.