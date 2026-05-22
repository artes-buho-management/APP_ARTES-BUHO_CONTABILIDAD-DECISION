# Estabilizacion de ejecucion y uso simple (13/03/2026)

## Objetivo aplicado

Reducir errores de operacion y dejar un flujo de uso centrado en:
- introduccion de datos rapida
- lectura inmediata del estado del negocio
- escenarios para toma de decisiones

## Diagnostico tecnico observado

1. `scripts.run` con OAuth sigue bloqueado por permisos en varios perfiles (`403 PERMISSION_DENIED`).
2. Perfil principal de automatizacion (`booking_clasp_admin`) presenta `invalid_grant` (subtipo `invalid_rapt`).
3. Para evitar bloqueo operativo, se mantiene fallback automatico por API de Sheets.

## Flujo estable activo

1. Intento de refresco por Apps Script remoto.
2. Si falla por permisos, aplicacion automatica de fallback visual/estructural por API de Sheets.
3. Auditoria remota profunda al final del ciclo.
4. Si aparece `PERMISSION_DENIED`, autocorreccion de permisos del proyecto script con cuenta de servicio y reintento.
5. En scheduler (cada 15 min) se usa modo ligero sin auditoria profunda para evitar `RATE_LIMIT_EXCEEDED`.
6. Scheduler con `ForceFallback` para evitar reintentos OAuth ruidosos y mantener refresco continuo.

Script orquestador:
- `tools/remote_refresh_decision_panel.ps1`
- `tools/sync_script_permissions_service_account.ps1` (autocorreccion de permisos)
- `tools/run_refresh_cycle.ps1` (runner de ciclo automatico con log)
- `tools/install_refresh_task.ps1` (instalador de tarea cada 15 min)

## Uso operativo (equipo no tecnico)

1. Ir a `01_ENTRADA`.
2. Editar solo celdas amarillas `B4:B11`.
3. Ejecutar `Guardar dato rapido`.
4. Revisar `00_PANEL` para semaforo, KPIs y decisiones.
5. Revisar `03_ESCENARIOS` para base/optimista/pesimista.

## Evidencia de ejecucion actual

- Auditoria pre-cambio:
  - `audit/reports/remote_sheet_deep_audit_2026-03-13_pre_fallback_total.json`
- Auditoria post-estabilizacion:
  - `audit/reports/remote_sheet_deep_audit_2026-03-13_post_estabilidad_menu_simple.json`
- Auditoria post-autocorreccion de permisos:
  - `audit/reports/remote_sheet_deep_audit_2026-03-13_post_permission_selfheal_step.json`

## Estado actual validado

- Libro: `💼 ARTES BUHO`
- Locale/timezone: `es_ES` / `Europe/Madrid`
- Hojas auditadas: `13`
- Hojas clave visibles para operativa: `00_PANEL`, `01_ENTRADA`, `02_TRANSACCIONES`, `03_ESCENARIOS`, `05_PRESUPUESTO`, `06_FACTURAS`, `00_GUIA_USO`
- Protecciones activas por hoja para evitar roturas.
