# MANUAL DE USO - ARTES BÚHO CONTABILIDAD DE DECISIÓN

Version: 1.2.4  
Fecha: 2026-03-16  
Empresa: Artes Búho  
Colores corporativos: Rojo / Amarillo / Blanco

## PORTADA
Objetivo del sistema:
- introducir pocos datos,
- ver el estado real por línea de negocio,
- decidir rápido cada semana.

Regla principal:
- Solo se edita `01_ENTRADA`.
- `00_PANEL` y `00_GUIA_USO` están en solo lectura para evitar errores.
- Si aparece un bloqueo, revisa que estés editando solo celdas de entrada.
- Celdas editables reales: `A:E` y `H` desde la fila 5.
- Celdas automáticas protegidas: `F` y `G`.
- Vista de entrada simplificada: menos filas con desplegable para evitar ruido visual.
- Panel más compacto: menos espacio vacío y gráficos más grandes para lectura rápida.

---

## PÁGINA 1 - FLUJO SIMPLE (1 MINUTO)
1. Abre `01_ENTRADA`.
2. Rellena una fila por línea de negocio:
- Mes (YYYY-MM)
- Línea de negocio
- Ingresos reales
- Gastos reales
- Objetivo mensual
- Nota breve
3. Pulsa el botón rojo `VER PANEL Y DECIDIR`.
4. Revisa semáforo y gráficos del `00_PANEL`.
5. Elige una acción semanal por línea.
6. Contrasta decisión con escenario optimista/base/pesimista.

---

## PÁGINA 2 - QUÉ MIRAR EN EL PANEL
KPIs principales:
- Liquidez total actual
- Ingresos acumulados del año
- Gastos acumulados del año
- Desviación del objetivo

Bloques de decisión:
- Radar por línea de negocio
- Resultado por línea (gráfico de barras)
- Distribución de ingresos (gráfico circular con porcentaje visible)
- Escenarios 12 meses por línea y global: optimista, base y pesimista
- Resumen global 12M con mismo criterio visual en las 3 filas (optimista/base/pesimista)
- Recomendación semanal IA por línea, con acción y objetivo de ingreso extra
- Tendencia de margen por línea (en barras, lectura limpia)
- Comparativa de ingresos vs gastos por línea (en barras, sin líneas confusas)
- Panel limpio: sin tablas técnicas auxiliares visibles

Lectura del semáforo:
- VERDE: línea rentable, se puede escalar.
- AMARILLO: margen ajustado, vigilar gasto y conversión.
- ROJO: riesgo de pérdida, activar plan de choque de 7 días.

---

## PÁGINA 3 - LÍNEAS DE NEGOCIO OFICIALES
- Escuela
- Management
- Ticket Buho
- Sala Bella Bestia
- Discográfica
- Eventos

Uso recomendado:
- actualizar todas las líneas 1 vez por semana,
- comparar resultado vs objetivo,
- priorizar acciones en líneas amarillas y rojas.

---

## PÁGINA 4 - EJEMPLO PRÁCTICO
Ejemplo de lectura:
- si `Eventos` da semáforo VERDE, priorizar captación y fechas.
- si `Discográfica` sale AMARILLO, limitar gasto variable y validar campañas.
- si `Management` sale ROJO, revisar costes directos y activar cobro rápido.

Pregunta guía de decisión:
- ¿qué línea deja más margen?
- ¿qué línea necesita ingresos extra para punto de equilibrio?
- ¿qué acción concreta hago esta semana para mejorar el resultado?

---

## PUBLICACIÓN Y VERSIONADO
En cada nueva versión:
1. actualizar este manual local,
2. publicar Google Doc corporativo,
3. publicar PDF corporativo,
4. guardar ambos en la carpeta del proyecto,
5. eliminar manuales obsoletos del mismo prefijo.

Script oficial:
- `tools/publish_manual_drive.ps1`

Nota técnica:
- el sistema refresca panel y escenarios cada 15 minutos.
