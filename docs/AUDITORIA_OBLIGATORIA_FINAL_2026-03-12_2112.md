# Auditoria Obligatoria Final (12-03-2026 21:12)

## Alcance
- Hoja auditada: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg` (ARTES BUHO).
- Auditoria profunda remota completa (estructura, datos, formulas, formato, merges, validaciones, filtros, condicionales, protecciones, permisos):
  - `audit/reports/remote_sheet_deep_audit_2026-03-12_post_relayout_exec_v2.json`
- Auditoria previa de Excel madre (sin tocar origen):
  - `audit/reports/excel_madre_deep_audit_2026-03-12-v2.json`

## 1) Estructura completa
- Locale: `es_ES`
- Zona horaria: `Europe/Madrid`
- Total pestanas: `13`

| Pestana | Visible | Rango usado | Filas usadas/max | Cols usadas/max |
|---|---:|---|---:|---:|
| 00_PANEL | si | A1:L97 | 97/120 | 12/12 |
| 01_ENTRADA | si | A1:H14 | 14/90 | 8/12 |
| 02_TRANSACCIONES | si | A1:K5 | 5/5000 | 11/11 |
| 03_ESCENARIOS | si | A1:J37 | 37/220 | 10/16 |
| 04_AUDITORIA | no | A1:E15 | 15/3000 | 5/8 |
| 98_LOG | no | A1:D2 | 2/5000 | 4/8 |
| 99_CONFIG | no | A1:C14 | 14/201 | 3/6 |
| 05_PRESUPUESTO | si | A1:J13 | 13/400 | 10/10 |
| Auditoria_1h | no | A1:F1 | 1/1000 | 6/26 |
| 06_FACTURAS | si | A1:M5 | 5/5000 | 13/13 |
| 07_LINEAS_NEGOCIO | no | A1:H6 | 6/220 | 8/8 |
| 08_CATALOGO_CATEGORIAS | no | A1:G34 | 34/400 | 7/8 |
| 00_GUIA_USO | si | A1:J16 | 16/120 | 10/12 |

## 2) Datos visibles y formulas relevantes
- Panel (`00_PANEL`): KPIs de caja, ingresos/gastos, pendiente, tabla mensual y tabla por linea con `SUMIFS/ARRAYFORMULA/SCAN`.
- Entrada (`01_ENTRADA`): formulario simplificado + bloque "impacto en tiempo real" y consulta de ultimos movimientos con `QUERY`.
- Escenarios (`03_ESCENARIOS`): motor de escenarios optimista/base/pesimista por formulas matriciales.
- Guia (`00_GUIA_USO`): contenido operativo en castellano, sin tecnicismos.

## 3) Formatos aplicados
- Paleta activa: rojo/amarillo/blanco corporativo.
- Tipografia dominante: `Montserrat`.
- Formato monetario EUR aplicado en bloques contables y de escenarios.
- Alineaciones y wraps ajustados para lectura horizontal limpia.
- Altos de fila y anchos de columna compactados para evitar dispersion visual.

## 4) Celdas combinadas
- 00_PANEL: 14 merges.
- 01_ENTRADA: 5 merges.
- 00_GUIA_USO: 7 merges.
- Resto: sin merges relevantes.

## 5) Validaciones y desplegables
- 01_ENTRADA:
  - Tipo: ingreso/gasto
  - Linea/categoria/subcategoria por catalogo
  - Cuenta: BBVA, Caixa, Santander, Stripe, Caja
  - Estado: pendiente, confirmado, cancelado
- 02_TRANSACCIONES:
  - Tipo, linea, categoria, subcategoria, cuenta, estado y origen validados
  - Origen depurado sin opcion "API"; queda: Banco, Tarjeta, Transferencia, Efectivo, Manual, Resumen mensual

## 6) Filtros y vistas de filtro
- Sin filtros basicos activos.
- Sin filter views configuradas.

## 7) Formato condicional
- 00_PANEL: 6 reglas (semaforo operativo).
- 02_TRANSACCIONES: 36 reglas (lectura por tipo/estado y alertas visuales).
- 05_PRESUPUESTO: 3 reglas.
- 06_FACTURAS: 24 reglas.

## 8) Protecciones y permisos
- Todas las pestanas clave con proteccion activa.
- En enfoque operativo actual:
  - Paneles de visualizacion protegidos.
  - Entrada controlada por rango editable.
- Permisos Drive detectados:
  - Owner: `booking@artesbuhomanagement.com`
  - Writers: equipo interno + robot de servicio
  - Link compartido lectura (`anyone reader`)

## Conclusiones de auditoria final
- Se redujo la dispersion visual del panel (uso real hasta fila 97, antes muy fragmentado).
- 01_ENTRADA y 00_GUIA_USO quedaron mas claros y orientados a usuario no tecnico.
- Se mantiene el bloque IA semanal activo en panel.
- Se confirma consistencia de validaciones, protecciones y formato corporativo.
