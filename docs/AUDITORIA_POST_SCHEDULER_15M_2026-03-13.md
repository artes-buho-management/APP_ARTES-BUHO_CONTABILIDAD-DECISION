# Auditoria Post Scheduler 15 Min (2026-03-13)

Fuentes:
- `audit/reports/install_refresh_task_2026-03-13_0805.json`
- `audit/reports/run_refresh_cycle_manual_2026-03-13_0813.json`
- `audit/reports/remote_sheet_deep_audit_2026-03-13_post_scheduler_hardening.json`
- `audit/reports/scheduler_refresh_log.jsonl`

## Estado operativo
- Tarea instalada: `Codex-ArtesBuho-Refresh15m`.
- Frecuencia: `15` minutos.
- Estado task scheduler: `Ready/Running` segun ciclo, con `LastTaskResult=0` en validacion final.
- Siguiente ejecucion detectada: cada 15 min (`NextRunTime` valido).

## Ajustes aplicados
1. `install_refresh_task.ps1` corregido para registrar tarea con `Register-ScheduledTask` (evita fallo de quoting por rutas con espacios).
2. `run_refresh_cycle.ps1` ajustado para usar ruta absoluta en auditorias y `Set-Location` al repo.
3. `remote_refresh_decision_panel.ps1` actualizado con:
   - `-SkipDeepAudit` (modo ligero sin auditoria profunda por ciclo).
   - `-ForceFallback` (evita ruido OAuth y mantiene continuidad por Sheets API).
4. Scheduler configurado en modo ligero + fallback forzado para no saturar cuotas.

## Validacion de cuota/API
- Incidencia observada y mitigada:
  - `429 RESOURCE_EXHAUSTED` por exceso de lecturas en ciclos con auditoria profunda.
  - Resuelto en operativa 15 min con `SkipDeepAudit + ForceFallback`.
- Resultado manual final:
  - `run_refresh_cycle_manual_2026-03-13_0813.json` -> `ok=true`, `mode=sheets_api_fallback`.

## Auditoria de hoja (post hardening)
- Archivo: `audit/reports/remote_sheet_deep_audit_2026-03-13_post_scheduler_hardening.json`
- Libro: `💼 ARTES BUHO`
- Locale/timezone: `es_ES` / `Europe/Madrid`
- Hojas: `13`
- Protecciones principales: activas (1 por hoja clave).
- Validaciones:
  - `01_ENTRADA`: 4
  - `02_TRANSACCIONES`: 28
- Formato condicional:
  - `00_PANEL`: 6
  - `02_TRANSACCIONES`: 36
  - `05_PRESUPUESTO`: 3
  - `06_FACTURAS`: 24

## Manual de uso publicado
- Version: `1.0.4`
- Doc: `https://docs.google.com/document/d/1W0LoRXwZC1grW9kclNzLmM1C_VaJPCX_gVHRGEClnP4/edit?usp=drivesdk`
- PDF: `https://drive.google.com/file/d/REPLACE_WITH_ID/view?usp=drivesdk`
- Obsoletos eliminados: version `1.0.3` (Doc + PDF).
