# ARTES BUHO - Contabilidad de Decision (Google Sheets + Apps Script)

Este repositorio mantiene una aplicacion de **contabilidad para toma de decisiones**.
No sustituye el software contable oficial. Su objetivo es:

1. introducir pocos datos,
2. ver estado real por linea de negocio,
3. comparar escenarios,
4. decidir acciones semanales con semaforo y recomendaciones.

## ACTUALIZACION V2 (REHECHO)

- App Script rehacido en `appscript/Code.js` (version `2.0.0`) con estructura mas simple:
  - `00_PANEL`, `01_ENTRADA`, `00_GUIA_USO` como cara visible.
  - captacion rapida en `01_ENTRADA` (`B4:B11`).
  - panel limpio con KPI + semaforo + acciones.
  - escenarios de 12 meses en `03_ESCENARIOS`.
- Comando de refresh operativo por OAuth en scripts locales:
  - `tools/run_refresh_cycle.ps1`
  - `tools/pipeline_respuesta_automatica.ps1`
- Para rehacer desde la propia hoja:
  - menu `BUHO FINANZAS V2` -> `1) REHACER APLICACION (base nueva)`.

## 1) Estado actual del sistema

- Repo: `https://github.com/rubencoton/artes-buho-contabilidad-ia`
- Rama principal de trabajo: `codex/unificacion-contabilidad-ia`
- Spreadsheet ID: `1f1JTbbf1IL7FABJRdrl-rWurDka8VIFQIo7W8Z3eVGg`
- Apps Script ID: `1n74ILY87l_lgs5EWWMufVsJSyqsINKacfbmeUM27dWtlJ4HxTqnFLnHm`
- Colores corporativos: rojo / amarillo / blanco
- Modo operativo: decision simple (solo 3 hojas visibles)

## 2) Que ve el usuario final en la hoja

Hojas visibles:

1. `00_PANEL` (solo lectura): KPIs, radar por linea, escenarios 12M, recomendaciones y graficos.
2. `01_ENTRADA` (editable): unica hoja para cargar datos de decision.
3. `00_GUIA_USO` (solo lectura): manual rapido dentro de la propia hoja.

Hojas ocultas (tecnicas):
- `02_TRANSACCIONES`, `03_ESCENARIOS`, `04_AUDITORIA`, `05_PRESUPUESTO`, `06_FACTURAS`, `07_LINEAS_NEGOCIO`, `08_CATALOGO_CATEGORIAS`, `98_LOG`, `99_CONFIG`, `Auditoria_1h`.

## 3) Flujo funcional de negocio

1. Usuario rellena filas en `01_ENTRADA`.
2. Formulas calculan resultado y semaforo automaticamente.
3. `00_PANEL` consolida por linea de negocio.
4. Se generan escenarios (optimista / base / pesimista).
5. Se muestra accion semanal sugerida por linea.

Lineas oficiales:
- Escuela
- Management
- Ticket Buho
- Sala Bella Bestia
- Discografica
- Eventos

## 4) Arquitectura tecnica

### 4.1 Apps Script (`appscript/Code.js`)
Archivo principal unico con:
- menu personalizado,
- construccion visual de hojas,
- validaciones y protecciones,
- refresco de panel,
- auditoria rapida/profunda,
- integracion IA (Gemini),
- sincronizacion y utilidades.

### 4.2 Scripts de automatizacion (`tools/`)
Scripts PowerShell para operar remoto sobre Google APIs.

Scripts clave:
- `tools/remote_decision_mode_minimal.ps1`
  - construye layout visible final,
  - reaplica formulas, validaciones, protecciones,
  - recrea graficos sin solapes.
- `tools/audit_sheet_remote_deep.ps1`
  - auditoria tecnica completa de la hoja remota:
    estructura, datos, formulas, formatos, merges, validaciones,
    filtros, formato condicional y protecciones.
- `tools/pipeline_respuesta_automatica.ps1`
  - flujo completo de publicacion automatica:
    commit/push + push Apps Script + refresh hoja + manual Doc/PDF.
- `tools/publish_manual_drive.ps1`
  - publica manual en Google Doc y PDF,
  - elimina versiones obsoletas.
- `tools/run_refresh_cycle.ps1`
  - fuerza actualizacion de panel/ciclos de recalculo.

## 5) Comando obligatorio de publicacion total

Usar este comando para dejar trazabilidad completa:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\pipeline_respuesta_automatica.ps1 -PublishManual -CommitMessage "mensaje claro"
```

Atajo rapido desde la raiz del repo:

```bat
.\PUBLICAR_TODO.bat "mensaje claro"
```

Atajos de Apps Script:

```bat
.\SUBIR_APPS_SCRIPT.bat
.\TRAER_APPS_SCRIPT.bat
```

Nota de entorno (Windows):
- si aparece error de `node` no reconocido, ejecutar en la misma sesion:

```powershell
$env:PATH += ';C:\Program Files\nodejs'
```

Que hace en cadena:
1. `git add/commit/push`
2. push a Apps Script remoto
3. reconstruccion/reaplicacion del modo decision
4. refresh del panel
5. publicacion manual en Google Doc + PDF
6. registro de reportes en `audit/reports/`

## 6) Auditoria minima antes de cerrar cualquier cambio

Checklist:

1. `00_PANEL`, `01_ENTRADA`, `00_GUIA_USO` sin `#REF!` ni `#ERROR!`.
2. sin solape de tablas, textos o graficos.
3. protecciones correctas:
   - panel y guia bloqueadas,
   - entrada editable solo en celdas de carga.
4. semaforo activo (verde/amarillo/rojo) en radar + escenarios + recomendaciones.
5. manual actualizado en hoja + Doc + PDF.
6. commit en GitHub con mensaje descriptivo.

## 7) Trazabilidad y evidencias

Se guardan en `audit/reports/`:
- auditorias remotas,
- logs de refresh,
- publicaciones de manual,
- reportes de pipeline.

Esto permite reconstruir que se hizo, cuando y con que resultado.

## 8) Guia rapida para un chat nuevo de Codex

Si se abre un hilo nuevo, ejecutar en este orden:

1. leer `README.md`
2. leer `README_CODEX_CONTINUIDAD.md`
3. ejecutar auditoria remota:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\audit_sheet_remote_deep.ps1
```

4. aplicar estado visual productivo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\remote_decision_mode_minimal.ps1
```

5. publicar todo:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\pipeline_respuesta_automatica.ps1 -PublishManual -CommitMessage "actualizacion"
```

## 9) Objetivo que nunca cambia

Mantener un sistema **muy visual, simple y robusto** para tomar decisiones claras por linea de negocio,
con datos minimos, escenarios utiles y accion semanal concreta.

## 10) Auditoria continua (2026-03-15)

Mejoras aplicadas tras auditoria total:
1. robustez de entorno en scripts remotos: eliminada dependencia fragil de `node` en PATH.
2. todos los scripts `tools/*.ps1` que usan token de cuenta de servicio ahora autodetectan `node.exe`.
3. pipeline de publicacion mantiene refresco remoto estable aunque cambie el entorno local.
4. re-ejecutada auditoria profunda remota y sincronizacion completa (GitHub + Apps Script + hoja).
5. auditoria visual de graficos mejorada:
   - deteccion automatica de solapes,
   - deteccion automatica de graficos fuera de rango,
   - checklist `qualityChecks` en JSON final.
6. correccion aplicada en layout:
   - reajuste del grafico de escenarios en `00_PANEL`,
   - limpieza de graficos residuales en hojas ocultas para evitar ruido.

Evidencia:
- `audit/reports/remote_sheet_deep_audit.json`
- `audit/reports/scheduler_refresh_log.jsonl`
- `audit/reports/AUDITORIA_PROFUNDA_COMPLETA_2026-03-15.md`

Bloqueo externo detectado (no de codigo):
- `appscript/scripts/push_api.ps1` ya diagnostica automaticamente todos los modos.
- estado actual:
1. perfiles OAuth locales con scope insuficiente para `script.projects.updateContent`,
2. cuenta de servicio con error de Apps Script API habilitacion de usuario.
- la pipeline no se rompe: sigue publicando hoja + manual y deja el motivo exacto en `pushApiOutput`.

## 11) Ultima auditoria profunda ejecutada (2026-03-15)

Acciones hechas:
1. se ejecuto `tools/remote_decision_mode_minimal.ps1` en modo completo.
2. se aplico una pasada final de tipografia (Montserrat) al final del script remoto.
3. se ejecuto `tools/audit_sheet_remote_deep.ps1` y se guardo reporte actualizado.
4. se corrigio la cabecera HTML del manual para evitar simbolos rotos en `BÃšHO` al exportar Doc/PDF.

Resultado de calidad:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Hojas visibles validadas:
1. `00_PANEL`
2. `01_ENTRADA`
3. `00_GUIA_USO`

Evidencia actualizada:
- `audit/reports/remote_sheet_deep_audit.json`

## 12) Mejora remota completa aplicada (version 1.1.1)

Objetivo de esta ronda:
1. mejorar claridad visual sin tocar operativa del usuario,
2. reforzar guia paso a paso,
3. publicar todo con trazabilidad total.

Cambios aplicados:
1. `appscript/Code.js`: version subida a `1.1.1`.
2. `tools/remote_decision_mode_minimal.ps1`:
   - panel mas compacto (`rowCount` reducido),
   - bordes en bloques clave de panel/entrada/guia,
   - guia interna mas clara y directa para uso no tecnico,
   - mejor equilibrio de anchos de columnas en `00_GUIA_USO`,
   - reajuste de graficos para mantener distribucion visual uniforme.
3. `tools/publish_manual_drive.ps1`:
   - texto de cabecera del manual corregido para evitar simbolos rotos.
4. `docs/MANUAL_USO_CONTABILIDAD_IA.md`:
   - version manual actualizada a `1.1.1`,
   - bloque de lectura del panel ampliado con nuevos graficos de apoyo.
5. `appscript/scripts/push_api.ps1`:
   - agregado fallback automatico `clasp push --force` cuando falle Apps Script API,
   - mejor trazabilidad del error real en `PUSH_FAILED_ALL`.

Resultado auditoria remota tras cambios:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

## 13) Correcciones de estabilidad aplicadas (2026-03-15)

Objetivo:
evitar errores intermitentes `#REF!` y mejorar legibilidad del manual publicado.

Cambios:
1. `tools/remote_decision_mode_minimal.ps1`
   - solucionado posible bloqueo de `ARRAYFORMULA` en `01_ENTRADA`:
     ahora la carga remota escribe solo columnas manuales (`A:E` y `H`);
     `F` y `G` quedan reservadas para formulas automaticas.
   - simplificado bloque IA de `00_PANEL`:
     se reemplazo array literal en `A46` por 4 formulas `FILTER` separadas (`A46:D46`) para evitar errores de derrame.
2. `tools/publish_manual_drive.ps1`
   - modo principal de publicacion cambiado a `corporate_html`.
   - prioridad de HTML con entidades Unicode para evitar caracteres rotos en PDF/Doc.
   - fallback automatico a Docs API y, si falla, a texto plano.

Validacion esperada tras publicar:
1. sin `#REF!` en `00_PANEL` y `01_ENTRADA`;
2. manual Doc/PDF con tildes correctas (`Artes BÃºho`);
3. hoja protegida con edicion solo en celdas de entrada.

## 14) Auditoria profunda remota + hardening API (2026-03-15 15:55)

Objetivo de esta ronda:
1. auditar toda la hoja remota con checklist completa;
2. detectar y prevenir errores por cuota API (`429`);
3. reforzar protecciones y trazabilidad para trabajo remoto continuo.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - reintentos con backoff para llamadas API transitorias (`429/5xx`);
   - proteccion explicita de `00_PANEL` y `00_GUIA_USO` por rango completo;
   - `01_ENTRADA` protegida con hoja completa y solo editables `A:E` y `H` (desde fila 5);
   - constantes de dimension para evitar desajustes de rango.
2. `tools/audit_sheet_remote_deep.ps1`
   - reintentos anti-limite API;
   - mejora de lectura de protecciones de hoja completa (`HOJA_COMPLETA`), evitando falsos rangos.

Validacion ejecutada en remoto:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit.json`
2. `audit/reports/excel_deep_audit_2026-03-15_full.json`
3. `docs/AUDITORIA_PROFUNDA_REMOTA_2026-03-15_1555.md`

## 15) Auditoria profunda + optimizacion visual (2026-03-16)

Objetivo de esta ronda:
1. corregir solapes visuales reportados en capturas;
2. reducir ruido en `01_ENTRADA` y `00_GUIA_USO`;
3. dejar ejecucion remota estable aunque no exista Node.js.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - rangos duros sustituidos por constantes (`$panelMaxRows`, `$inputMaxRows`, `$guideMaxRows`);
   - limpieza remota por rango real:
     - `00_PANEL!A1:L70`
     - `01_ENTRADA!A1:H90`
     - `00_GUIA_USO!A1:J32`;
   - formulas del panel ahora leen `01_ENTRADA` hasta fila dinamica (`...:90`) para evitar cortes y errores;
   - `ARRAYFORMULA` de `F` y `G` en entrada tambien en rango dinamico (`B5:B90`, etc.);
   - validaciones sin desplegable ruidoso (`showCustomUi=false`) para una vista mas limpia;
   - grafico **Escenarios 12 meses** redimensionado para no pisar el bloque `RESUMEN GLOBAL 12M`:
     - ancho `460px`, alto `230px`, ancla `G32`;
   - `00_GUIA_USO` mejorado:
     - anchos de columna mas legibles,
     - filas de reglas finales unificadas en bloques anchos (`A20:G24`) para evitar texto cortado.
2. `tools/audit_sheet_remote_deep.ps1`
   - hardening de autenticacion: fallback automatico a Python si falta Node.
3. `tools/get_service_account_access_token.py` (nuevo)
   - helper para token de cuenta de servicio usando `google-auth`;
   - evita bloqueos de ejecucion en entornos sin `node.exe`.

Ejecucion y validacion remota completadas:
1. despliegue remoto de layout/productivo:
   - `tools/remote_decision_mode_minimal.ps1` -> `ok=true`.
2. auditoria profunda remota:
   - `tools/audit_sheet_remote_deep.ps1` -> `REMOTE_DEEP_AUDIT_OK`.
3. resultado de calidad:
   - `qualityChecks.ok = true`
   - `formulaErrorsTotal = 0`
   - `chartOverlapsTotal = 0`
   - `chartOverflowTotal = 0`
   - `visibleSheetsProtected = true`
   - `entryValidationCount = 28`

Evidencia de esta ronda:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16.json`
2. `docs/AUDITORIA_PROFUNDA_2026-03-16.md`

## 16) Ajuste visual fino por captura (2026-03-16 11:48)

Objetivo:
1. eliminar solapes entre paneles;
2. quitar huecos visuales raros (fila 39 y fila 52);
3. ocultar la tabla tecnica visible en columnas `K/L` (filas 10 a 15).

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - grafico **Escenarios 12 meses** compactado para no pisar `RESUMEN GLOBAL 12M`:
     - ancla: `G32`
     - tamano: `320x220`;
   - ajuste de rangos visuales para evitar filas vacias formateadas:
     - bloque escenarios: fin en fila 38 (antes 39),
     - bloque IA: fin en fila 51 (antes 52),
     - bloque analisis movido arriba (`A52/A53`) para reducir huecos;
   - helper de porcentajes movido fuera del radar principal:
     - de `K9:L15` -> `J64:K70`,
     - radar limpio, sin tabla tecnica visible al usuario;
   - borde del radar reducido a zona util (`A:G`) para evitar cuadricula sobrante;
   - charts inferiores subidos a `A54` y `G54` para mejor continuidad visual.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1148.json`
2. `audit/reports/manual_publish_2026-03-16_115102.json`

## 17) Auditoria profunda + correccion de maquetacion final (2026-03-16 18:45)

Objetivo de esta ronda:
1. quitar solapes visuales detectados en capturas;
2. dejar el panel limpio sin tabla helper visible;
3. compactar bloques para evitar huecos confusos;
4. recortar filas sobrantes para que no aparezcan zonas infinitas al bajar.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - helper del donut movido a `99_CONFIG` (oculto), fuera de `00_PANEL`;
   - graficos superiores recolocados en 3 columnas fijas (A-D / E-H / I-L):
     - Resultado por linea,
     - Escenarios 12 meses,
     - Distribucion de ingresos;
   - bloque IA movido a `A39:D46` para eliminar hueco visual en fila 39;
   - bloque analisis visual movido a `A47:L48` y graficos inferiores subidos a fila 49;
   - bordes retocados para separar mejor escenarios y resumen;
   - recorte automatico de filas/columnas sobrantes en hojas visibles:
     - `00_PANEL` -> 66 filas,
     - `01_ENTRADA` -> 90 filas,
     - `00_GUIA_USO` -> 32 filas.
2. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - actualizado encabezado de fecha;
   - refuerzo de lectura: panel sin tablas tecnicas visibles.
3. Publicacion manual:
   - Google Doc + PDF regenerados y versiones obsoletas eliminadas.

Validacion remota de calidad:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1845.json`
2. `audit/reports/manual_publish_2026-03-16_125414.json`

Nota Apps Script:
1. `npx clasp push --force` ejecutado en `appscript/` (estado: `Script is already up to date`).
2. El push por API directa con cuenta de servicio sigue limitado por configuracion de Google:
   `User has not enabled the Apps Script API`.

## 18) Ajuste final de legibilidad + proteccion intuitiva (2026-03-16 19:11)

Objetivo de esta ronda:
1. hacer la entrada mas intuitiva (sin sensacion de hoja bloqueada completa);
2. mejorar lectura de escenarios/resumen para evitar textos cortados;
3. mantener panel limpio y estable.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - protecciones de `01_ENTRADA` cambiadas a modo por rangos:
     - cabeceras (`A1:H4`),
     - formulas (`F5:G90`),
     - boton (`H12:H13`);
   - entrada manual (`A:E` y `H` desde fila 5) queda libre para editar;
   - anchos de columnas del panel aumentados en zona derecha para que acciones y resumen se lean mejor;
   - filas de escenarios y bloque IA con mayor alto para lectura clara;
   - se mantiene helper del donut en `99_CONFIG` oculta (no visible para usuario).
2. ejecucion remota completa aplicada de nuevo sobre la hoja productiva.
3. `clasp push --force` ejecutado (estado: sin cambios pendientes en Apps Script).
4. manual Doc + PDF publicado de nuevo en la carpeta oficial.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencia:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1707_post_fino4.json`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1911.json`
2. `audit/reports/manual_publish_2026-03-16_131400.json`

## 19) Ajuste puntual por capturas (2026-03-16 13:32)

Objetivo de esta ronda:
1. unificar criterio visual de `RESUMEN GLOBAL 12M`;
2. eliminar separacion visual entre `ESCENARIOS 12 MESES` y `RESUMEN GLOBAL`;
3. quitar graficos con lineas confusas para lectura mas limpia.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - bloque `RESUMEN GLOBAL 12M` movido de `J:L` a `I:K` para quedar pegado al bloque de escenarios (sin hueco intermedio);
   - filas Optimista/Base/Pesimista con estilo uniforme (mismo fondo y misma jerarquia visual);
   - bordes del resumen reajustados al nuevo bloque (`I31:K35`);
   - grafico `Escenarios 12 meses` reconfigurado al nuevo rango (`I/J`) sin desalineacion;
   - graficos de analisis convertidos a barras:
     - `Tendencia de margen por linea (%)` -> `COLUMN`,
     - `Comparativa ingresos vs gastos por linea` -> `COLUMN`.
2. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version subida a `1.1.3`;
   - manual actualizado con lectura visual del nuevo resumen y graficos sin lineas raras.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencia:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1338.json`

## 20) Ajuste fino final de maquetacion (2026-03-16 14:10)

Objetivo de esta ronda:
1. mejorar lectura visual sin romper bloques;
2. mantener criterios consistentes entre tablas de escenarios y resumen;
3. evitar lineas raras y cortes de texto.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - anchos de columnas del panel reajustados para lectura de textos largos:
     - mejora especial en columnas `G`, `H` y `K`;
   - cabeceras de escenarios/resumen con `wrap` para evitar cortes;
   - `RESUMEN GLOBAL 12M` mantenido en bloque continuo `I:K`;
   - tres graficos superiores redimensionados a `350x280` para encaje limpio:
     - sin pisarse entre si,
     - sin salirse del rango visible.
2. `appscript/Code.js`
   - version subida a `1.1.4`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.4`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1410.json`
2. `audit/reports/manual_publish_2026-03-16_141301.json`

## 21) Ajuste fino continuo (2026-03-16 14:24)

Objetivo de esta ronda:
1. dejar el bloque escenarios/resumen con lectura mas limpia;
2. mejorar encaje visual de texto largo sin cortes;
3. mantener el panel compacto sin solapes.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - ajuste de anchos en la zona de escenarios/recomendaciones:
     - mayor espacio en columnas de accion y texto largo;
   - aumento de alto de filas de escenarios para legibilidad (`44px`);
   - mejora de `wrap + alineacion vertical` en cabeceras y celdas del resumen;
   - borde del `RESUMEN GLOBAL 12M` suavizado para evitar efecto de doble linea entre bloques.
2. `appscript/Code.js`
   - version subida a `1.1.5`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.5`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1424.json`
2. `audit/reports/manual_publish_2026-03-16_142640.json`

## 22) Ajuste fino de separacion visual (2026-03-16 14:49)

Objetivo de esta ronda:
1. eliminar la sensacion de solape entre `ESCENARIOS 12 MESES` y `RESUMEN GLOBAL 12M`;
2. unificar estilo de filas del resumen (sin destacar solo una fila);
3. mejorar legibilidad en bloques de recomendacion y acciones.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - bloque `RESUMEN GLOBAL 12M` movido de `I:K` a `J:L` para dejar columna separadora visual;
   - cabeceras, formulas y formato del resumen realineados al nuevo bloque `J:L`;
   - grafico `Escenarios 12 meses` actualizado para leer categorias/valores desde `J:K`;
   - correccion de celda combinada de resumen:
     - de `I31:K31` a `J31:L31`;
   - ajuste de anchos de columnas del panel para texto largo:
     - `I` como separador,
     - `L` ampliada para accion global.
2. `appscript/Code.js`
   - version subida a `1.1.6`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.6`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1838_post.json`
2. `audit/reports/remote_sheet_deep_audit_2026-03-16_1846_post2.json`
3. `audit/reports/remote_sheet_deep_audit_2026-03-16_1849_post3.json`

## 23) Ajuste fino de compactacion y limpieza visual (2026-03-16 15:03)

Objetivo de esta ronda:
1. reducir huecos visuales sin perder legibilidad;
2. limpiar la separacion entre tabla de escenarios y resumen global;
3. dejar el manual interno mas compacto.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - `00_PANEL` reducido de 66 a 62 filas para evitar espacio muerto final;
   - `00_GUIA_USO` reducido de 32 a 28 filas para ajuste compacto;
   - tabla `ESCENARIOS 12 MESES - POR LINEA Y GLOBAL` con borde sin lateral derecho
     para eliminar linea dura contra el bloque de resumen;
   - se mantiene separador visual con columna `I` y bloque de resumen en `J:L`.
2. `appscript/Code.js`
   - version subida a `1.1.7`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.7`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencia:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1903_post4.json`

## 24) Ajuste fino de legibilidad en graficos (2026-03-16 15:16)

Objetivo de esta ronda:
1. mejorar lectura de nombres largos de lineas de negocio;
2. evitar etiquetas cortadas en ejes de graficos;
3. mantener todo sin solapes ni desbordes.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - grafico `Resultado por linea de negocio` cambiado a `BAR` (horizontal);
   - grafico `Comparativa ingresos vs gastos por linea` cambiado a `BAR` (horizontal);
   - ajuste de ejes en ambos graficos para lectura clara:
     - eje inferior = EUR,
     - eje lateral = Linea.
2. Se mantuvo el resto del layout sin cambios estructurales para no romper el flujo visual ya aprobado.
3. `appscript/Code.js`
   - version subida a `1.1.8`.
4. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.8`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1914_pre_next.json`
2. `audit/reports/remote_sheet_deep_audit_2026-03-16_1916_post5.json`

## 25) Ajuste fino de limpieza en entrada (2026-03-16 15:26)

Objetivo de esta ronda:
1. reducir ruido visual en `01_ENTRADA`;
2. evitar desplegables y colores en filas vacias lejanas;
3. mantener capacidad de calculo sin romper formulas.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - nuevo limite visual `inputUiRows = 24`;
   - validaciones de datos limitadas a filas visibles de trabajo (`A5:H24`);
   - formato condicional del semaforo limitado a filas visibles (`A5:H24`);
   - formato de moneda de entrada limitado a filas visibles (`C5:F24`);
   - colores de area de entrada aplicados solo a bloque util, evitando ruido visual.
2. `appscript/Code.js`
   - version subida a `1.1.9`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.1.9`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1926_post6.json`

## 26) Ajuste fino de guia ultra-clara (2026-03-16 15:40)

Objetivo de esta ronda:
1. simplificar `00_GUIA_USO` para lectura inmediata;
2. eliminar columnas vacias que no aportan;
3. mantener pasos visibles en pantalla sin desplazamiento lateral.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - `00_GUIA_USO` pasa de 10 a 7 columnas reales (`A:G`);
   - combinados de cabecera ajustados a ancho real de la guia;
   - limpieza del rango de guia en `A1:G` (antes `A1:J`);
   - anchos de columnas de guia recalibrados para lectura:
     - mas espacio en "Que haces" y "Decision recomendada";
   - filas de pasos ampliadas a `38px` para mejor legibilidad.
2. `appscript/Code.js`
   - version subida a `1.2.0`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.2.0`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`
7. `00_GUIA_USO`: `A1:G24`, `rows=28`, `cols=7`, `merges=9`

Evidencias:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1942_pre_guide.json`
2. `audit/reports/remote_sheet_deep_audit_2026-03-16_1940_post7.json`

## 27) Ajuste fino de continuidad visual (2026-03-16 16:02)

Objetivo de esta ronda:
1. quitar hueco visual entre `ESCENARIOS 12M` y `RESUMEN GLOBAL 12M`;
2. mejorar legibilidad de cabeceras largas en escenarios/acciones;
3. mantener panel compacto sin perder calidad de graficos.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - bloque `RESUMEN GLOBAL 12M` movido a `I:K` (antes `J:L`) para continuidad visual;
   - grafico `Escenarios 12 meses` actualizado a la nueva fuente (`I:J`);
   - anchos de columnas del panel reajustados para evitar textos cortados:
     - mas ancho en accion semanal y accion global,
     - mejor lectura en escenarios;
   - filas de escenarios elevadas a `48px` para reducir cortes de texto;
   - panel final estabilizado en `62` filas para evitar overflow de graficos.
2. `appscript/Code.js`
   - version subida a `1.2.1`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.2.1`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

Evidencia:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_ajuste_fino_post2.json`
2. `audit/reports/manual_publish_2026-03-16_160802.json`

## 28) Robustez de publicacion Apps Script (2026-03-16 16:10)

Objetivo de esta ronda:
1. evitar bloqueos al publicar script cuando `.clasprc` no tenga bloque `tokens`;
2. mantener flujo totalmente automatico sin corte intermedio.

Cambios aplicados:
1. `appscript/scripts/push_api.ps1`
   - ya no hace `throw` inmediato en modo `auto` si falta `tokens`;
   - registra el intento OAuth fallido y continua automaticamente con:
     - cuenta de servicio,
     - y si falla, `clasp_fallback`.
2. validacion ejecutada:
   - `AUTH_MODE=clasp_fallback`
   - `DETAIL=Script is already up to date.`

## 29) Ajuste fino de consistencia visual y bloqueo (2026-03-16 16:31)

Objetivo de esta ronda:
1. quitar diferencias visuales en el bloque de escenarios;
2. reforzar el bloqueo del panel para evitar ediciones accidentales;
3. mantener panel limpio sin solapes ni errores.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - se homogeneiza la primera fila de datos del bloque `ESCENARIOS 12 MESES` con el mismo color que el resto (sin destacado aislado);
   - se mantiene la estructura continua `ESCENARIOS` + `RESUMEN GLOBAL 12M` en una sola franja visual;
   - bloqueo fuerte de panel/guia: robot como editor explÃ­cito en rangos protegidos (Google puede mantener al propietario del archivo por polÃ­tica interna).
2. `appscript/Code.js`
   - version subida a `1.2.2`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.2.2` con aclaraciÃ³n de criterio uniforme en resumen 12M.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`
7. `00_PANEL usedRange = '00_PANEL'!A1:K48`

Evidencia:
1. `audit/reports/remote_sheet_deep_audit_2026-03-16_1631_post_fino.json`

## 30) Ajuste fino de limpieza visual en entrada y bloque IA (2026-03-16 16:40)

Objetivo de esta ronda:
1. reducir ruido visual en `01_ENTRADA` (menos desplegables visibles);
2. limpiar continuidad de color en cabecera del bloque IA;
3. mantener todo sin errores de formula ni solapes.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - `inputUiRows` ajustado de `24` a `18` para una vista mas corta y clara;
   - bloque visual automatico (`F:G`) limitado a filas utiles (`5-11`) y el resto vuelve a color de entrada;
   - cabecera del bloque `BLOQUE IA - RECOMENDACIONES CONTABLES` uniforme en todo el ancho (`A:L`) para eliminar cortes visuales.
2. `appscript/Code.js`
   - version subida a `1.2.3`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.2.3`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount` coherente con filas visibles de entrada.

## 31) Ajuste fino de legibilidad y compactacion del panel (2026-03-16 16:49)

Objetivo de esta ronda:
1. mejorar lectura de etiquetas largas en graficos;
2. reducir espacio muerto sin perder visibilidad;
3. homogeneizar tabla de escenarios para evitar filas visualmente distintas.

Cambios aplicados:
1. `tools/remote_decision_mode_minimal.ps1`
   - `00_PANEL` estabilizado en `62` filas (sin desborde de graficos) y `00_GUIA_USO` compactado a `26` filas;
   - filas de escenarios y bloque IA ajustadas de alto para lectura mas limpia;
   - tabla `ESCENARIOS 12M` unificada con mismo estilo en todas las filas;
   - columna de accion global del resumen alineada a la izquierda para lectura natural;
   - se probÃ³ ampliaciÃ³n de graficos y se ajustÃ³ al tamaÃ±o estable sin solapes:
     - bloque superior: `350x280`,
     - bloque inferior: `560x260`.
2. `appscript/Code.js`
   - version subida a `1.2.4`.
3. `docs/MANUAL_USO_CONTABILIDAD_IA.md`
   - version manual actualizada a `1.2.4`.

Validacion remota:
1. `qualityChecks.ok = true`
2. `formulaErrorsTotal = 0`
3. `chartOverlapsTotal = 0`
4. `chartOverflowTotal = 0`
5. `visibleSheetsProtected = true`
6. `entryValidationCount = 28`

---

## CIERRE DE ENTORNO LOCAL (MIGRACION)

- Fecha de cierre: 2026-04-08 15:24:45
- Estado: preparado para migrar a nuevo PC/sistema cloud.
- Repositorio: sincronizado con GitHub en la rama activa.
- Nota: este proyecto queda listo para retomar desde otro equipo clonando el repo.

### CHECKLIST RAPIDA

- [x] Codigo versionado en GitHub.
- [x] README actualizado para traspaso.
- [x] Trabajo local preparado para cierre.


<!-- CIERRE_MIGRACION_2026_04_08 -->
## Cierre de migracion (2026-04-08)
- Estado: preparado para mover a nuevo PC/sistema cloud.
- Fecha de cierre: 
2026-04-08 15:25:38 +02:00
- Rama activa: 
codex/unificacion-contabilidad-ia
- Nota: cambios subidos a GitHub para reanudar desde otro entorno.



## CIERRE CLOUD (2026-04-08)

- Estado: repositorio preparado para migracion a nuevo sistema.
- Ultimo cierre tecnico: 2026-04-08 (Europe/Madrid).
- Siguiente uso recomendado: clonar desde GitHub y continuar en la rama actual.


## CIERRE MIGRACION CLOUD

- Fecha: 2026-04-08
- Estado: preparado para retomar desde nuevo sistema


## CIERRE CLOUD 2026-04-08
- Estado: sincronizado para migracion a nuevo PC/sistema.
- Preparado para retomar desde GitHub.
- Ultima revision: 2026-04-08 15:26:05 +02:00

<!-- MIGRACION_CLOUD_START -->
## ESTADO MIGRACION CLOUD
- Revisado: 2026-04-08
- Repo listo para continuar en otro sistema.
- Estado Git al cerrar: sincronizado en GitHub.
<!-- MIGRACION_CLOUD_END -->
