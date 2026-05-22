# Benchmark de herramientas contables + IA

Fecha: 2026-03-11
Objetivo: extraer patrones top de mercado para implementarlos en nuestra app de Google Sheets + Apps Script.

## Principio

No se copian productos ni codigo propietario. Se copian patrones funcionales de alto impacto.

## Patrones detectados en plataformas lider

| Patron | Evidencia en mercado | Decision para nuestra app |
|---|---|---|
| Permisos granulares por rol | QuickBooks custom roles y permisos por area/accion; Zoho roles personalizados y aprobaciones por rol; Odoo access rights por usuario/grupo | Implementar modelo `TEAM_OPEN` configurable + matriz de permisos por rol en `Config` |
| Planificacion de caja con escenarios | QuickBooks Cash Flow Planner (proyecciones y eventos); Xero analytics/short-term cash flow y snapshot visual | Motor de escenarios `optimista/base/pesimista` con 12 meses y caja acumulada |
| Dashboard visual altamente configurable | Xero Business Snapshot; Zoho Custom Dashboards con paneles, graficos y permisos | Panel unico con KPI, graficos por mes, graficos por linea de negocio y resumen IA |
| Controles de aprobacion y auditoria | Zoho aprobaciones por rol; Copilot Finance enfasis en reconciliacion y trazabilidad | Hoja `Auditoria` + reglas de calidad de datos + log de eventos |
| Integracion con sistemas y analitica avanzada | Zoho Books + Zoho Analytics; Copilot Finance con conexion ERP (Dynamics/SAP) | Capas de ingestion/import y conectores API como fase 2 |
| Soporte IA para explicacion y decisiones | Copilot Finance: reconciliacion, variances, recomendaciones; Xero Analytics Plus menciona predicciones asistidas por IA | Resumen narrativo IA en panel + recomendaciones accionables semanales |

## Capacidades a implantar (v1 -> v3)

### V1 (base operativa)

1. Formulario visual de entrada de datos.
2. Ledger unificado de transacciones.
3. Dashboard automatico con KPI + graficos.
4. Escenarios base/optimista/pesimista.
5. Auditoria de calidad de datos (reglas).

### V2 (inteligencia de negocio)

1. Narrativa IA ejecutiva por linea de negocio.
2. Alertas de desviacion mensual y de caja.
3. Recomendaciones de accion por prioridad.

### V3 (automatizacion avanzada)

1. Conectores externos (bancos/ERP/fuentes de cobros).
2. Flujo de aprobaciones por rol.
3. Cierre mensual asistido por IA (checklist + evidencias).

## Fuentes oficiales consultadas

- QuickBooks custom roles: https://quickbooks.intuit.com/online/advanced/customizations/
- QuickBooks cash flow planner: https://quickbooks.intuit.com/learn-support/en-us/help-article/budget-forecast-reports/use-cash-flow-planner-quickbooks-online/L2l59mIqe_US_en_US
- Xero dashboard: https://www.xero.com/us/accounting-software/dashboard/
- Xero business snapshot: https://www.xero.com/accounting-software/analytics/snapshot/
- Xero analytics plus (app store): https://apps.xero.com/us/app/xero-analytics-plus
- Zoho users and roles: https://www.zoho.com/us/books/help/settings/users.html
- Zoho custom dashboards: https://www.zoho.com/us/books/help/home/custom-dashboards.html
- Zoho approvals by role: https://www.zoho.com/us/books/help/transaction-approval/users-and-roles.html
- Zoho advanced analytics integration: https://www.zoho.com/books/help/integrations/advanced-analytics.html
- Odoo access rights: https://www.odoo.com/documentation/master/applications/general/users/access_rights.html
- Odoo analytic accounting: https://www.odoo.com/documentation/19.0/applications/finance/accounting/reporting/analytic_accounting.html
- Odoo budgets: https://www.odoo.com/documentation/19.0/applications/finance/accounting/reporting/budget.html
- Microsoft Copilot for Finance (GA): https://www.microsoft.com/en-us/dynamics-365/blog/it-professional/2025/10/20/empowering-finance-with-an-ai-assistant-in-microsoft-365-copilot/
- Microsoft Copilot for Finance release plan: https://learn.microsoft.com/en-us/dynamics365/release-plan/2024wave2/finance-supply-chain/microsoft-copilot-finance/
