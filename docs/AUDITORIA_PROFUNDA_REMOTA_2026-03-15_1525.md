# AUDITORIA PROFUNDA REMOTA - 2026-03-15 15:25

## 1) Alcance auditado
- Hoja Google productiva: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`
- Codigo local (scripts remotos + publicacion manual + README)
- Excel madre:
  - `C:\Users\elrub\Downloads\Copia de 1. Forecast y flujo caja 2026 (1).xlsx`
  - `C:\Users\elrub\Downloads\Copia de 1. 2026 Pagos e ingresos .xlsx`

## 2) Resultado global
- Estado calidad hoja remota: `OK`
- Errores de formula: `0`
- Solapes de graficos: `0`
- Graficos fuera de rango: `0`
- Hojas visibles protegidas: `SI`
- Validaciones activas en entrada: `28`

Evidencia:
- `audit/reports/remote_sheet_deep_audit.json`
- `audit/reports/excel_deep_audit_2026-03-15_full.json`

## 3) Checklist completa obligatoria (hoja Google)

### 3.1 Estructura completa
- Libro: `💼 ARTES BUHO`
- Locale: `es_ES`
- Zona horaria: `Europe/Madrid`
- Total pestanas: `13`
- Visibles: `00_PANEL`, `01_ENTRADA`, `00_GUIA_USO`

Detalle visible:
- `00_PANEL`: rango usado `A1:L55`, 55 filas, 12 columnas, 5 graficos
- `01_ENTRADA`: rango usado `A1:H12`, 12 filas, 8 columnas
- `00_GUIA_USO`: rango usado `A1:G24`, 24 filas, 7 columnas

### 3.2 Datos visibles y formulas relevantes
- KPI panel:
  - Liquidez (`A5`) desde `01_ENTRADA!F`
  - Ingresos anuales (`D5`) desde `01_ENTRADA!C`
  - Gastos anuales (`G5`) desde `01_ENTRADA!D`
  - Desviacion (`J5`) desde ingresos menos objetivos
- Radar por linea: formulas `ARRAYFORMULA` en `B10:G10`
- Escenarios 12M: formulas `ARRAYFORMULA` en `B33:H33`
- Bloque IA: formulas `FILTER` separadas en `A46:D46` (sin array literal)
- Entrada:
  - `F5`: resultado automatico
  - `G5`: semaforo automatico

### 3.3 Formatos aplicados
- Paleta: rojo / amarillo / blanco corporativo
- Tipografia principal: `Montserrat`
- Fondos:
  - cabeceras rojas (`#B20000`)
  - bandas amarillas (`#FFD300`)
  - celdas decision verde/amarillo/rojo por semaforo
- Numero:
  - moneda EUR en panel y entrada
  - porcentaje en margenes y pesos
- Bordes:
  - tablas del panel, entrada y guia con bordes de separacion visibles

### 3.4 Celdas combinadas
- `00_PANEL`: 16 combinaciones (cabeceras y bloques visuales)
- `01_ENTRADA`: 5 combinaciones
- `00_GUIA_USO`: 4 combinaciones

### 3.5 Validaciones y desplegables
- Total validaciones en `01_ENTRADA`: 28
- Lineas de negocio (lista cerrada):
  - Escuela
  - Management
  - Ticket Buho
  - Sala Bella Bestia
  - Discografica
  - Eventos
- Reglas numericas en ingresos/gastos/objetivo: `>= 0`

### 3.6 Filtros y vistas de filtro
- Filtro basico activo: `NO`
- Vistas de filtro: `0`

### 3.7 Formato condicional
- `00_PANEL`: 9 reglas (semaforo radar, escenarios y bloque IA)
- `01_ENTRADA`: 3 reglas (fila completa por semaforo)
- `00_GUIA_USO`: 0 reglas

### 3.8 Protecciones y permisos
- `00_PANEL`: protegido (solo editores autorizados)
- `01_ENTRADA`: hoja protegida con solo celdas de entrada editables
  - desbloqueadas: `A:E` y `H` (carga manual)
  - bloqueadas: `F:G` (formulas)
- `00_GUIA_USO`: protegido
- Permisos Drive detectados: propietario + editores de equipo + cuenta robot

## 4) Hallazgos de auditoria y correcciones aplicadas

### 4.1 Error intermitente `#REF!` (corregido)
Hallazgo:
- posible bloqueo de `ARRAYFORMULA` al escribir valores vacios en columnas calculadas.

Correccion:
- `tools/remote_decision_mode_minimal.ps1`
  - ahora carga solo columnas manuales `A:E` y `H`
  - deja `F:G` solo para formulas automaticas
  - bloque IA de panel cambiado a 4 `FILTER` separados (`A46:D46`)

### 4.2 Simbolos raros en manual PDF/Doc (corregido)
Hallazgo:
- posibilidad de caracteres rotos en exportacion (`Búho`).

Correccion:
- `tools/publish_manual_drive.ps1`
  - modo principal cambiado a `corporate_html`
  - prioridad de HTML con entidades Unicode
  - fallback a Docs API, y ultimo fallback a texto plano

## 5) Auditoria de Excel madre
- Workbooks auditados: 2
- Hojas auditadas: 13
- Errores de celda detectados: 0
- Rangos combinados detectados: 99
- Reglas condicionales detectadas: 0
- Validaciones detectadas: 0

Notas:
- Los Excel madre son base historica de datos.
- La hoja de decision actual ya no depende de cargar todo el detalle transaccional.

## 6) Riesgos abiertos (externos al codigo)
- Push remoto de Apps Script puede fallar por OAuth/`invalid_grant` en algunos perfiles.
- Mitigacion ya implementada:
  - fallback automatico `clasp push --force`
  - trazabilidad completa de error en reportes de pipeline.

## 7) Estado final de esta auditoria
- Hoja remota estable y visualmente consistente.
- Sin errores de formula ni solapes.
- Protecciones activas en las 3 hojas visibles.
- Entrada simplificada para uso no tecnico.
- Informe y trazabilidad guardados en repo.
