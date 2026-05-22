const APP = {
  version: '2.0.0',
  name: 'CONTABILIDAD ARTES BUHO V2',
  sheets: {
    panel: '00_PANEL',
    input: '01_ENTRADA',
    guide: '00_GUIA_USO',
    tx: '02_TRANSACCIONES',
    scenarios: '03_ESCENARIOS',
    audit: '04_AUDITORIA',
    budget: '05_PRESUPUESTO',
    invoices: '06_FACTURAS',
    lines: '07_LINEAS_NEGOCIO',
    categories: '08_CATALOGO_CATEGORIAS',
    log: '98_LOG',
    config: '99_CONFIG'
  },
  businessLines: [
    'Escuela',
    'Management',
    'Ticket Buho',
    'Sala Bella Bestia',
    'Discografica',
    'Eventos'
  ],
  categoryDefaults: [
    ['Escuela', 'Formacion', 'Matricula', 'ingreso', 'activa'],
    ['Escuela', 'Formacion', 'Mensualidad', 'ingreso', 'activa'],
    ['Escuela', 'Operacion', 'Profesorado', 'gasto', 'activa'],
    ['Escuela', 'Operacion', 'Material', 'gasto', 'activa'],

    ['Management', 'Servicios', 'Comision management', 'ingreso', 'activa'],
    ['Management', 'Servicios', 'Booking', 'ingreso', 'activa'],
    ['Management', 'Operacion', 'Viajes', 'gasto', 'activa'],
    ['Management', 'Operacion', 'Legal', 'gasto', 'activa'],

    ['Ticket Buho', 'Entradas', 'Venta online', 'ingreso', 'activa'],
    ['Ticket Buho', 'Entradas', 'Fee servicio', 'ingreso', 'activa'],
    ['Ticket Buho', 'Operacion', 'Pasarela de pago', 'gasto', 'activa'],
    ['Ticket Buho', 'Marketing', 'Campanas', 'gasto', 'activa'],

    ['Sala Bella Bestia', 'Sala', 'Taquilla', 'ingreso', 'activa'],
    ['Sala Bella Bestia', 'Sala', 'Barra', 'ingreso', 'activa'],
    ['Sala Bella Bestia', 'Operacion', 'Tecnica', 'gasto', 'activa'],
    ['Sala Bella Bestia', 'Operacion', 'Seguridad', 'gasto', 'activa'],

    ['Discografica', 'Catalogo', 'Royalties', 'ingreso', 'activa'],
    ['Discografica', 'Produccion', 'Grabacion', 'gasto', 'activa'],
    ['Discografica', 'Marketing', 'Lanzamiento', 'gasto', 'activa'],

    ['Eventos', 'Eventos', 'Cache', 'ingreso', 'activa'],
    ['Eventos', 'Eventos', 'Produccion tecnica', 'gasto', 'activa'],
    ['Eventos', 'Eventos', 'Logistica', 'gasto', 'activa']
  ],
  scenarioFactors: {
    optimista: { income: 1.15, expense: 0.95 },
    base: { income: 1.0, expense: 1.0 },
    pesimista: { income: 0.88, expense: 1.08 }
  }
};

const THEME = {
  red: '#B30000',
  redDark: '#7A0000',
  yellow: '#FFD400',
  yellowSoft: '#FFF3BF',
  white: '#FFFFFF',
  black: '#7A0000',
  gray: '#FFF3BF',
  grayDark: '#7A0000'
};

const MONEY_FORMAT = '#,##0.00 [$€-es-ES]';
const PERCENT_FORMAT = '0.00%';
const DATE_FORMAT = 'dd/MM/yyyy';
const QUARTER_REFRESH_HANDLER = 'runQuarterRefreshTrigger';
const WEEKLY_HANDLER = 'runWeeklyAutomationTrigger';

function onOpen() {
  disableLegacyAutomations_();
  // Menu desactivado temporalmente por limpieza de interfaz.
}

function onEdit(e) {
  try {
    handleDependentValidations_(e);
  } catch (err) {
    appendLog_('ERROR', 'onEdit', { error: String(err) });
  }
}

function safeMenuAction_(actionName, runner, successMessage) {
  try {
    const result = runner();
    if (successMessage) {
      SpreadsheetApp.getActiveSpreadsheet().toast(successMessage, actionName, 5);
    }
    return result;
  } catch (err) {
    appendLog_('ERROR', actionName, { error: String(err) });
    SpreadsheetApp.getUi().alert(actionName + ' fallo. Revisa 98_LOG para detalle tecnico.');
    return null;
  }
}

function setupWorkspaceSafe() {
  return safeMenuAction_(
    'REHACER APLICACION',
    function () {
      const result = withLock_(function () {
        const setupResult = setupWorkspace_({ resetVisualSheets: true });
        refreshDecisionPanel_();
        simulateScenarios_();
        generateAiNarrative_();
        return setupResult;
      });
      return result;
    },
    'Base nueva aplicada. Panel y entrada listos.'
  );
}

function submitDataEntryFromFormSafe() {
  return safeMenuAction_(
    'Guardar movimiento rapido',
    function () {
      const res = submitDataEntryFromForm_();
      refreshDecisionPanel_();
      simulateScenarios_();
      generateAiNarrative_();
      return res;
    },
    'Movimiento guardado y panel actualizado.'
  );
}

function refreshDecisionPanelSafe() {
  return safeMenuAction_(
    'Refrescar panel',
    function () {
      return refreshDecisionPanel_();
    },
    'Panel actualizado.'
  );
}

function simulateScenariosSafe() {
  return safeMenuAction_(
    'Recalcular escenarios',
    function () {
      return simulateScenarios_();
    },
    'Escenarios recalculados.'
  );
}

function generateAiNarrativeSafe() {
  return safeMenuAction_(
    'Resumen inteligente',
    function () {
      return generateAiNarrative_();
    },
    'Resumen actualizado en 00_PANEL.'
  );
}

function showStatusSafe() {
  return safeMenuAction_('Estado del sistema', showStatus_, '');
}
function goToEntradaRapida() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('IntroduccionDatos') || getSheet_(APP.sheets.input, true);
  SpreadsheetApp.getActiveSpreadsheet().setActiveSheet(sheet);
  SpreadsheetApp.getActiveSpreadsheet().toast('Usa esta tabla para introducir datos.', sheet.getName(), 5);
}

function openIntroduccionDatosSheet_() {
  goToEntradaRapida();
}

function focusOnlyInputSheet_() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const input = ss.getSheetByName('IntroduccionDatos') || ss.getSheetByName(APP.sheets.input);
  if (!input) {
    SpreadsheetApp.getUi().alert('No encuentro la hoja IntroduccionDatos.');
    return;
  }

  ss.getSheets().forEach(function(sh) {
    if (sh.getName() === input.getName()) {
      sh.showSheet();
    } else {
      try {
        sh.hideSheet();
      } catch (err) {
        // no-op
      }
    }
  });

  ss.setActiveSheet(input);
  ss.toast('Vista simplificada: solo tabla de introduccion de datos.', 'CONTABILIDAD SIMPLE', 5);
}

function disableLegacyAutomations_() {
  const handlers = {};
  handlers[QUARTER_REFRESH_HANDLER] = true;
  handlers[WEEKLY_HANDLER] = true;
  handlers['runQuarterRefreshTrigger'] = true;
  handlers['runWeeklyAutomationTrigger'] = true;
  handlers['runDeepHourAuditChunk'] = true;

  ScriptApp.getProjectTriggers().forEach(function(t) {
    const fn = String(t.getHandlerFunction() || '');
    if (handlers[fn]) {
      try {
        ScriptApp.deleteTrigger(t);
      } catch (err) {
        // no-op
      }
    }
  });
}

function goToPanelDecision() {
  const sheet = getSheet_(APP.sheets.panel, true);
  SpreadsheetApp.getActiveSpreadsheet().setActiveSheet(sheet);
  SpreadsheetApp.getActiveSpreadsheet().toast('Panel abierto. Mira KPI, semaforo y acciones.', '00_PANEL', 5);
}

function openQuickGuide_() {
  const sheet = getSheet_(APP.sheets.guide, true);
  SpreadsheetApp.getActiveSpreadsheet().setActiveSheet(sheet);
}

function runQuarterRefreshFromMenu() {
  return safeMenuAction_(
    'Refresh remoto',
    function () {
      return runQuarterRefresh();
    },
    'Refresh remoto completado.'
  );
}

function runQuarterRefresh() {
  return withLock_(function () {
    setupWorkspace_({ resetVisualSheets: false });
    const panel = refreshDecisionPanel_();
    const scenarios = simulateScenarios_();
    const summary = generateAiNarrative_();
    const out = {
      ok: true,
      version: APP.version,
      panel: panel,
      scenarios: scenarios,
      summary: summary,
      executedAt: new Date().toISOString()
    };
    appendAudit_('RUN', 'INFO', 'runQuarterRefresh ejecutado', JSON.stringify(out));
    setConfigValue_('lastQuarterRefresh', out.executedAt);
    return out;
  });
}

function runQuarterRefreshTrigger() {
  return runQuarterRefresh();
}

function runWeeklyAutomationFromMenu() {
  return safeMenuAction_(
    'Ciclo semanal',
    function () {
      return runWeeklyAutomationTrigger();
    },
    'Ciclo semanal completado.'
  );
}

function runWeeklyAutomationTrigger() {
  return withLock_(function () {
    setupWorkspace_({ resetVisualSheets: false });
    const panel = refreshDecisionPanel_();
    const scenarios = simulateScenarios_();
    const summary = generateAiNarrative_();
    const out = {
      ok: true,
      type: 'weekly',
      panel: panel,
      scenarios: scenarios,
      summary: summary,
      executedAt: new Date().toISOString()
    };
    appendAudit_('AUTOMATION', 'INFO', 'runWeeklyAutomationTrigger', JSON.stringify(out));
    setConfigValue_('lastWeeklyAutomation', out.executedAt);
    return out;
  });
}

function activateQuarterRefresh() {
  removeTriggersByHandler_(QUARTER_REFRESH_HANDLER);
  ScriptApp.newTrigger(QUARTER_REFRESH_HANDLER).timeBased().everyMinutes(15).create();
  SpreadsheetApp.getUi().alert('Refresh 15 min ACTIVADO.');
}

function deactivateQuarterRefresh() {
  removeTriggersByHandler_(QUARTER_REFRESH_HANDLER);
  SpreadsheetApp.getUi().alert('Refresh 15 min PAUSADO.');
}

function activateWeeklyAutomation() {
  removeTriggersByHandler_(WEEKLY_HANDLER);
  ScriptApp.newTrigger(WEEKLY_HANDLER).timeBased().everyWeeks(1).onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(9).create();
  SpreadsheetApp.getUi().alert('Ciclo semanal ACTIVADO (lunes 09:00).');
}

function deactivateWeeklyAutomation() {
  removeTriggersByHandler_(WEEKLY_HANDLER);
  SpreadsheetApp.getUi().alert('Ciclo semanal PAUSADO.');
}

function syncScriptAccessWithSheetEditors() {
  const msg = 'Modo safe: no se alteraron permisos. Flujo de datos y refresh siguen operativos.';
  appendAudit_('PERMISSIONS', 'INFO', 'syncScriptAccessWithSheetEditors', msg);
  SpreadsheetApp.getUi().alert(msg);
  return { ok: true, mode: 'safe', message: msg };
}

function setupWorkspace_(opts) {
  const options = opts || {};
  const resetVisual = !!options.resetVisualSheets;
  const sheets = ensureAllSheets_();

  setupLinesSheet_(sheets.lines);
  setupCategoriesSheet_(sheets.categories);
  setupTransactionsSheet_(sheets.tx);
  setupSupportSheets_(sheets);

  if (resetVisual) {
    setupInputSheet_(sheets.input);
    setupDashboardShell_(sheets.panel);
    setupGuideSheet_(sheets.guide);
  } else {
    ensureInputScaffold_(sheets.input);
    ensureDashboardScaffold_(sheets.panel);
    ensureGuideScaffold_(sheets.guide);
  }

  hideTechnicalSheets_(sheets);
  protectReadOnlySheets_([sheets.panel, sheets.guide]);

  setConfigValue_('appVersion', APP.version);
  setConfigValue_('lastWorkspaceBuild', new Date().toISOString());
  appendAudit_('WORKSPACE', 'INFO', 'setupWorkspace', resetVisual ? 'resetVisualSheets=true' : 'resetVisualSheets=false');

  return {
    ok: true,
    resetVisualSheets: resetVisual,
    version: APP.version
  };
}

function setupLinesSheet_(sheet) {
  const rows = [
    ['Linea', 'ObjetivoMensualEUR', 'Responsable', 'Estado', 'Color'],
    ['Escuela', 12000, 'Direccion Escuela', 'activa', '#8B0000'],
    ['Management', 9000, 'Direccion Management', 'activa', '#B30000'],
    ['Ticket Buho', 14000, 'Operacion Ticketing', 'activa', '#FFD400'],
    ['Sala Bella Bestia', 11000, 'Direccion Sala', 'activa', '#7A0000'],
    ['Discografica', 5000, 'Direccion Artistica', 'activa', '#B30000'],
    ['Eventos', 8000, 'Direccion Eventos', 'activa', '#FFFFFF']
  ];

  sheet.clear({ contentsOnly: false });
  writeMatrix_(sheet, 1, 1, rows);
  sheet.getRange(1, 1, 1, rows[0].length).setFontWeight('bold').setBackground(THEME.gray);
  sheet.setFrozenRows(1);
}

function setupCategoriesSheet_(sheet) {
  const rows = [['Linea', 'Categoria', 'Subcategoria', 'TipoDefault', 'Estado']];
  APP.categoryDefaults.forEach(function (row) {
    rows.push(row);
  });

  sheet.clear({ contentsOnly: false });
  writeMatrix_(sheet, 1, 1, rows);
  sheet.getRange(1, 1, 1, rows[0].length).setFontWeight('bold').setBackground(THEME.gray);
  sheet.setFrozenRows(1);
}

function setupTransactionsSheet_(sheet) {
  const header = [
    'Fecha',
    'Tipo',
    'Linea',
    'Categoria',
    'Subcategoria',
    'Concepto',
    'ImporteEUR',
    'Estado',
    'Fuente',
    'FechaRegistro',
    'Usuario'
  ];

  const existing = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, Math.min(11, sheet.getLastColumn())).getValues() : [];
  sheet.clear({ contentsOnly: false });
  writeMatrix_(sheet, 1, 1, [header]);
  if (existing.length > 0) {
    writeMatrix_(sheet, 2, 1, existing.map(normalizeTxRow_));
  }
  sheet.getRange(1, 1, 1, header.length).setFontWeight('bold').setBackground(THEME.gray);
  sheet.setFrozenRows(1);

  const maxRows = Math.max(sheet.getMaxRows() - 1, 1);
  sheet.getRange(2, 1, maxRows, 1).setNumberFormat(DATE_FORMAT);
  sheet.getRange(2, 7, maxRows, 1).setNumberFormat(MONEY_FORMAT);
  sheet.getRange(2, 10, maxRows, 1).setNumberFormat('dd/MM/yyyy HH:mm');
}

function normalizeTxRow_(row) {
  const out = new Array(11).fill('');
  for (let i = 0; i < Math.min(row.length, 11); i += 1) {
    out[i] = row[i];
  }
  return out;
}
function setupSupportSheets_(sheets) {
  const auditHeader = ['Fecha', 'Bloque', 'Nivel', 'Detalle', 'Valor'];
  const logHeader = ['Fecha', 'Nivel', 'Accion', 'Detalle'];
  const configHeader = ['Clave', 'Valor', 'ActualizadoEn'];
  const budgetHeader = ['Mes', 'Linea', 'PresupuestoIngresos', 'PresupuestoGastos', 'ObjetivoResultado'];
  const invoicesHeader = ['Fecha', 'Linea', 'Cliente', 'Concepto', 'Importe', 'Vencimiento', 'Estado'];

  setupGenericHeader_(sheets.audit, auditHeader);
  setupGenericHeader_(sheets.log, logHeader);
  setupGenericHeader_(sheets.config, configHeader);
  setupGenericHeader_(sheets.budget, budgetHeader);
  setupGenericHeader_(sheets.invoices, invoicesHeader);
}

function setupGenericHeader_(sheet, header) {
  const hasHeader = sheet.getLastRow() > 0 && String(sheet.getRange(1, 1).getValue()).trim() !== '';
  if (!hasHeader) {
    sheet.clear({ contentsOnly: false });
    writeMatrix_(sheet, 1, 1, [header]);
  } else {
    const current = sheet.getRange(1, 1, 1, header.length).getValues()[0];
    if (current.join('|') !== header.join('|')) {
      sheet.clear({ contentsOnly: false });
      writeMatrix_(sheet, 1, 1, [header]);
    }
  }
  sheet.getRange(1, 1, 1, header.length).setFontWeight('bold').setBackground(THEME.gray);
  sheet.setFrozenRows(1);
}

function setupInputSheet_(sheet) {
  sheet.clear({ contentsOnly: false });

  sheet.setColumnWidths(1, 1, 230);
  sheet.setColumnWidths(2, 1, 320);
  sheet.setColumnWidths(3, 6, 120);

  sheet.getRange('A1:H1').merge().setValue('01_ENTRADA - CAPTURA RAPIDA').setBackground(THEME.red).setFontColor(THEME.white).setFontWeight('bold').setFontSize(15);
  sheet.getRange('A2:H2').merge().setValue('Rellena B4:B11 y ejecuta "Guardar movimiento rapido" desde el menu.').setBackground(THEME.yellowSoft).setFontColor(THEME.black);

  const labels = [
    ['Fecha'],
    ['Tipo (ingreso/gasto)'],
    ['Linea de negocio'],
    ['Categoria'],
    ['Subcategoria'],
    ['Concepto'],
    ['Importe EUR'],
    ['Estado (confirmado/pendiente/vencida)']
  ];
  writeMatrix_(sheet, 4, 1, labels);
  sheet.getRange('A4:A11').setFontWeight('bold').setBackground(THEME.gray);

  const defaults = [
    [new Date()],
    ['ingreso'],
    [APP.businessLines[0]],
    [''],
    [''],
    [''],
    [''],
    ['confirmado']
  ];
  writeMatrix_(sheet, 4, 2, defaults);
  sheet.getRange('B4:B11').setBackground(THEME.yellowSoft).setBorder(true, true, true, true, false, false, THEME.grayDark, SpreadsheetApp.BorderStyle.SOLID);
  sheet.getRange('B4').setNumberFormat(DATE_FORMAT);
  sheet.getRange('B10').setNumberFormat(MONEY_FORMAT);

  const typeValidation = SpreadsheetApp.newDataValidation().requireValueInList(['ingreso', 'gasto'], true).setAllowInvalid(false).build();
  const lineValidation = SpreadsheetApp.newDataValidation().requireValueInList(APP.businessLines, true).setAllowInvalid(false).build();
  const statusValidation = SpreadsheetApp.newDataValidation().requireValueInList(['confirmado', 'pendiente', 'vencida'], true).setAllowInvalid(false).build();
  sheet.getRange('B5').setDataValidation(typeValidation);
  sheet.getRange('B6').setDataValidation(lineValidation);
  sheet.getRange('B11').setDataValidation(statusValidation);

  sheet.getRange('D4:H11').clear({ contentsOnly: false });
  sheet.getRange('D4:H4').merge().setValue('CHECKLIST RAPIDO').setBackground(THEME.redDark).setFontColor(THEME.white).setFontWeight('bold');
  writeMatrix_(
    sheet,
    5,
    4,
    [
      ['1) Fecha correcta'],
      ['2) Tipo correcto (ingreso/gasto)'],
      ['3) Linea + categoria + subcategoria'],
      ['4) Concepto claro'],
      ['5) Importe en EUR'],
      ['6) Estado actualizado']
    ]
  );
  sheet.getRange('D5:H10').setBackground(THEME.white).setFontColor(THEME.black);
  sheet.getRange('D12:H13').merge().setValue('TIP: si cambias LINEA, se actualiza automaticamente la lista de categorias.').setBackground(THEME.gray).setWrap(true);

  applyDependentValidationsForInput_(sheet);
}

function ensureInputScaffold_(sheet) {
  if (sheet.getLastRow() < 8 || String(sheet.getRange('A1').getValue()).indexOf('01_ENTRADA') === -1) {
    setupInputSheet_(sheet);
    return;
  }
  applyDependentValidationsForInput_(sheet);
}

function setupDashboardShell_(sheet) {
  sheet.clear({ contentsOnly: false });
  sheet.setColumnWidths(1, 12, 130);

  sheet.getRange('A1:L1').merge().setValue('00_PANEL - CONTROL FINANCIERO SEMANAL').setBackground(THEME.red).setFontColor(THEME.white).setFontWeight('bold').setFontSize(16);
  sheet.getRange('A2:L2').merge().setValue('Vista ejecutiva simple: 4 KPI, semaforo, lineas y acciones.').setBackground(THEME.yellowSoft).setFontColor(THEME.black);

  sheet.getRange('A4:C4').merge().setValue('INGRESOS').setBackground(THEME.yellowSoft).setFontWeight('bold').setHorizontalAlignment('center');
  sheet.getRange('D4:F4').merge().setValue('GASTOS').setBackground(THEME.white).setFontWeight('bold').setHorizontalAlignment('center');
  sheet.getRange('G4:I4').merge().setValue('RESULTADO').setBackground(THEME.yellow).setFontWeight('bold').setHorizontalAlignment('center');
  sheet.getRange('J4:L4').merge().setValue('PENDIENTE').setBackground(THEME.redDark).setFontColor(THEME.white).setFontWeight('bold').setHorizontalAlignment('center');

  sheet.getRange('A5:C7').merge().setFontSize(18).setFontWeight('bold').setHorizontalAlignment('center').setVerticalAlignment('middle');
  sheet.getRange('D5:F7').merge().setFontSize(18).setFontWeight('bold').setHorizontalAlignment('center').setVerticalAlignment('middle');
  sheet.getRange('G5:I7').merge().setFontSize(18).setFontWeight('bold').setHorizontalAlignment('center').setVerticalAlignment('middle');
  sheet.getRange('J5:L7').merge().setFontSize(18).setFontWeight('bold').setHorizontalAlignment('center').setVerticalAlignment('middle');

  sheet.getRange('A9:D9').merge().setValue('SEMAFORO').setBackground(THEME.redDark).setFontColor(THEME.white).setFontWeight('bold');
  sheet.getRange('A10:D12').merge().setFontSize(14).setFontWeight('bold').setWrap(true).setVerticalAlignment('middle').setHorizontalAlignment('center');

  sheet.getRange('A14:F14').setValues([['Mes', 'Ingresos', 'Gastos', 'Resultado', 'Margen', 'Movimiento']]).setFontWeight('bold').setBackground(THEME.gray);
  sheet.getRange('H14:L14').setValues([['Linea', 'Ingresos', 'Gastos', 'Resultado', 'Riesgo']]).setFontWeight('bold').setBackground(THEME.gray);

  sheet.getRange('A24:L24').merge().setValue('ACCIONES PRIORITARIAS').setBackground(THEME.redDark).setFontColor(THEME.white).setFontWeight('bold');
  sheet.getRange('A25:L32').merge().setWrap(true).setVerticalAlignment('top').setBackground(THEME.white);

  sheet.getRange('A34:L34').merge().setValue('RESUMEN INTELIGENTE').setBackground(THEME.redDark).setFontColor(THEME.white).setFontWeight('bold');
  sheet.getRange('A35:L40').merge().setWrap(true).setVerticalAlignment('top').setBackground(THEME.white);
}

function ensureDashboardScaffold_(sheet) {
  if (sheet.getLastRow() < 20 || String(sheet.getRange('A1').getValue()).indexOf('00_PANEL') === -1) {
    setupDashboardShell_(sheet);
  }
}

function setupGuideSheet_(sheet) {
  sheet.clear({ contentsOnly: false });
  sheet.setColumnWidths(1, 1, 260);
  sheet.setColumnWidths(2, 1, 760);

  sheet.getRange('A1:B1').merge().setValue('00_GUIA_USO - COMO USARLO EN 3 PASOS').setBackground(THEME.red).setFontColor(THEME.white).setFontWeight('bold').setFontSize(15);
  writeMatrix_(
    sheet,
    3,
    1,
    [
      ['Paso 1', 'Rellena 01_ENTRADA (B4:B11) y guarda movimiento rapido.'],
      ['Paso 2', 'Abre 00_PANEL y revisa: resultado, semaforo y acciones.'],
      ['Paso 3', 'Si cambia negocio, recalcula escenarios desde el menu.'],
      ['', ''],
      ['Reglas de oro', 'a) No edites hojas tecnicas ocultas. b) Usa siempre categorias oficiales. c) Revisa pendientes cada semana.'],
      ['', ''],
      ['Donde mirar primero', '1) Resultado 2) Pendiente 3) Riesgo por linea 4) Acciones prioritarias.'],
      ['', ''],
      ['Comandos del menu', 'REHACER APLICACION, Guardar movimiento, Refrescar panel, Recalcular escenarios, Resumen inteligente.']
    ]
  );

  sheet.getRange(3, 1, 9, 2).setBorder(true, true, true, true, true, true, THEME.grayDark, SpreadsheetApp.BorderStyle.SOLID);
  sheet.getRange('A3:A11').setFontWeight('bold').setBackground(THEME.gray);
  sheet.getRange('B3:B11').setWrap(true).setVerticalAlignment('top').setBackground(THEME.white);
}

function ensureGuideScaffold_(sheet) {
  if (sheet.getLastRow() < 6 || String(sheet.getRange('A1').getValue()).indexOf('00_GUIA_USO') === -1) {
    setupGuideSheet_(sheet);
  }
}
function refreshDecisionPanel_() {
  const panel = getSheet_(APP.sheets.panel, true);
  ensureDashboardScaffold_(panel);

  const tx = readTransactions_();
  const kpi = computeKpi_(tx);
  const monthly = buildMonthlySummary_(tx, 6);
  const byLine = computeByLineSummary_(tx);
  const risk = computeRiskStatus_(kpi, byLine);
  const actions = buildActions_(kpi, byLine, risk);

  panel.getRange('A5').setValue(kpi.income);
  panel.getRange('D5').setValue(kpi.expense);
  panel.getRange('G5').setValue(kpi.result);
  panel.getRange('J5').setValue(kpi.pending);
  panel.getRange('A5:C7').setNumberFormat(MONEY_FORMAT);
  panel.getRange('D5:F7').setNumberFormat(MONEY_FORMAT);
  panel.getRange('G5:I7').setNumberFormat(MONEY_FORMAT);
  panel.getRange('J5:L7').setNumberFormat(MONEY_FORMAT);

  panel.getRange('A10:D12').setValue(risk.label + '\n' + risk.detail);
  panel.getRange('A10:D12').setBackground(risk.background).setFontColor(risk.fontColor);

  clearRangeValues_(panel, 15, 1, 12, 6);
  if (monthly.length > 0) {
    writeMatrix_(panel, 15, 1, monthly.map(function (row) {
      return [row.month, row.income, row.expense, row.result, row.margin, row.movements];
    }));
    panel.getRange(15, 2, monthly.length, 3).setNumberFormat(MONEY_FORMAT);
    panel.getRange(15, 5, monthly.length, 1).setNumberFormat(PERCENT_FORMAT);
  }

  clearRangeValues_(panel, 15, 8, 12, 5);
  if (byLine.length > 0) {
    writeMatrix_(panel, 15, 8, byLine.map(function (row) {
      return [row.line, row.income, row.expense, row.result, row.risk];
    }));
    panel.getRange(15, 9, byLine.length, 3).setNumberFormat(MONEY_FORMAT);
    panel.getRange(15, 12, byLine.length, 1).setHorizontalAlignment('center').setFontWeight('bold');
  }

  panel.getRange('A25').setValue(actions.join('\n'));

  setConfigValue_('lastPanelRefresh', new Date().toISOString());
  appendAudit_('PANEL', 'INFO', 'refreshDecisionPanel', JSON.stringify({
    income: kpi.income,
    expense: kpi.expense,
    result: kpi.result,
    risk: risk.label
  }));

  return {
    kpi: kpi,
    risk: risk.label,
    monthlyRows: monthly.length,
    lineRows: byLine.length
  };
}

function simulateScenarios_() {
  const sheet = getSheet_(APP.sheets.scenarios, true);
  const tx = readTransactions_();
  const byLine = computeByLineSummary_(tx);

  const headers = ['Escenario', 'Linea', 'Mes', 'IngresosEUR', 'GastosEUR', 'ResultadoEUR', 'CajaAcumuladaEUR', 'Riesgo'];
  const rows = [];
  const order = ['optimista', 'base', 'pesimista'];

  order.forEach(function (scenarioName) {
    const factor = APP.scenarioFactors[scenarioName];
    APP.businessLines.forEach(function (line) {
      const lineData = byLine.find(function (x) { return x.line === line; }) || { income: 0, expense: 0, result: 0 };
      const monthlyIncomeBase = lineData.income / 3 || 0;
      const monthlyExpenseBase = lineData.expense / 3 || 0;
      let cash = 0;
      for (let m = 1; m <= 12; m += 1) {
        const inc = monthlyIncomeBase * factor.income;
        const exp = monthlyExpenseBase * factor.expense;
        const res = inc - exp;
        cash += res;
        rows.push([
          scenarioName,
          line,
          m,
          round2_(inc),
          round2_(exp),
          round2_(res),
          round2_(cash),
          res >= 0 ? 'BAJO' : (res > -1000 ? 'MEDIO' : 'ALTO')
        ]);
      }
    });
  });

  sheet.clear({ contentsOnly: false });
  writeMatrix_(sheet, 1, 1, [headers]);
  if (rows.length > 0) {
    writeMatrix_(sheet, 2, 1, rows);
    sheet.getRange(2, 4, rows.length, 4).setNumberFormat(MONEY_FORMAT);
  }
  sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold').setBackground(THEME.gray);
  sheet.setFrozenRows(1);

  appendAudit_('ESCENARIOS', 'INFO', 'simulateScenarios', 'rows=' + rows.length);
  setConfigValue_('lastScenarioRefresh', new Date().toISOString());
  return { rows: rows.length };
}

function generateAiNarrative_() {
  const panel = getSheet_(APP.sheets.panel, true);
  const tx = readTransactions_();
  const kpi = computeKpi_(tx);
  const byLine = computeByLineSummary_(tx);
  const top = byLine.slice().sort(function (a, b) { return b.result - a.result; })[0] || null;
  const weak = byLine.slice().sort(function (a, b) { return a.result - b.result; })[0] || null;
  const risk = computeRiskStatus_(kpi, byLine);

  const lines = [];
  lines.push('Resumen ejecutivo: ' + risk.label + '.');
  lines.push('Ingresos: ' + formatMoneyText_(kpi.income) + ' | Gastos: ' + formatMoneyText_(kpi.expense) + ' | Resultado: ' + formatMoneyText_(kpi.result) + '.');
  if (top) {
    lines.push('Linea fuerte: ' + top.line + ' con resultado ' + formatMoneyText_(top.result) + '.');
  }
  if (weak) {
    lines.push('Linea en tension: ' + weak.line + ' con resultado ' + formatMoneyText_(weak.result) + '.');
  }
  lines.push('Foco semanal: reduce pendientes y revisa gastos en las lineas con riesgo ALTO.');

  const text = lines.join('\n');
  panel.getRange('A35').setValue(text);
  appendAudit_('NARRATIVA', 'INFO', 'generateAiNarrative', text);
  setConfigValue_('lastNarrativeRefresh', new Date().toISOString());
  return { text: text };
}

function showStatus_() {
  const tx = readTransactions_();
  const kpi = computeKpi_(tx);
  const msg = [
    'APP VERSION: ' + APP.version,
    'Movimientos: ' + tx.length,
    'Ingresos: ' + formatMoneyText_(kpi.income),
    'Gastos: ' + formatMoneyText_(kpi.expense),
    'Resultado: ' + formatMoneyText_(kpi.result),
    'Ultimo refresh panel: ' + (getConfigValue_('lastPanelRefresh') || 'sin dato'),
    'Ultimo refresh escenarios: ' + (getConfigValue_('lastScenarioRefresh') || 'sin dato')
  ].join('\n');
  SpreadsheetApp.getUi().alert(msg);
  return { ok: true, message: msg };
}

function submitDataEntryFromForm_() {
  const input = getSheet_(APP.sheets.input, true);
  const txSheet = getSheet_(APP.sheets.tx, true);

  const values = input.getRange('B4:B11').getValues().map(function (r) { return r[0]; });
  const date = toDate_(values[0]);
  const type = String(values[1] || '').toLowerCase().trim();
  const line = String(values[2] || '').trim();
  const category = String(values[3] || '').trim();
  const subcategory = String(values[4] || '').trim();
  const concept = String(values[5] || '').trim();
  const amount = toNumber_(values[6]);
  const status = String(values[7] || '').toLowerCase().trim();

  if (!date) { throw new Error('Fecha invalida en B4.'); }
  if (['ingreso', 'gasto'].indexOf(type) === -1) { throw new Error('Tipo invalido en B5.'); }
  if (!line) { throw new Error('Linea vacia en B6.'); }
  if (!category) { throw new Error('Categoria vacia en B7.'); }
  if (!subcategory) { throw new Error('Subcategoria vacia en B8.'); }
  if (!concept) { throw new Error('Concepto vacio en B9.'); }
  if (!isFinite(amount) || amount === 0) { throw new Error('Importe invalido en B10.'); }
  if (['confirmado', 'pendiente', 'vencida'].indexOf(status) === -1) { throw new Error('Estado invalido en B11.'); }

  const signedAmount = type === 'gasto' ? -Math.abs(amount) : Math.abs(amount);
  const userEmail = Session.getActiveUser().getEmail() || 'desconocido';
  txSheet.appendRow([date, type, line, category, subcategory, concept, signedAmount, status, 'manual', new Date(), userEmail]);

  input.getRange('B4').setValue(new Date());
  input.getRange('B9:B10').clearContent();
  input.getRange('B11').setValue('confirmado');

  appendAudit_('ENTRADA', 'INFO', 'submitDataEntry', JSON.stringify({
    type: type,
    line: line,
    amount: signedAmount,
    status: status
  }));

  return { ok: true, saved: 1 };
}
function handleDependentValidations_(e) {
  if (!e || !e.range) { return; }
  const sheet = e.range.getSheet();
  if (sheet.getName() !== APP.sheets.input) { return; }
  if (e.range.getA1Notation() === 'B6') {
    applyCategoryValidation_(sheet);
    sheet.getRange('B8').clearContent();
    applySubcategoryValidation_(sheet);
  }
  if (e.range.getA1Notation() === 'B7') {
    applySubcategoryValidation_(sheet);
  }
}

function applyDependentValidationsForInput_(sheet) {
  applyCategoryValidation_(sheet);
  applySubcategoryValidation_(sheet);
}

function applyCategoryValidation_(inputSheet) {
  const line = String(inputSheet.getRange('B6').getValue() || '').trim();
  const categories = getCategoriesForLine_(line);
  if (categories.length === 0) {
    inputSheet.getRange('B7').clearDataValidations();
    return;
  }
  const dv = SpreadsheetApp.newDataValidation().requireValueInList(categories, true).setAllowInvalid(false).build();
  inputSheet.getRange('B7').setDataValidation(dv);
  if (categories.indexOf(String(inputSheet.getRange('B7').getValue() || '').trim()) === -1) {
    inputSheet.getRange('B7').setValue(categories[0]);
  }
}

function applySubcategoryValidation_(inputSheet) {
  const line = String(inputSheet.getRange('B6').getValue() || '').trim();
  const category = String(inputSheet.getRange('B7').getValue() || '').trim();
  const subcategories = getSubcategoriesForLineCategory_(line, category);
  if (subcategories.length === 0) {
    inputSheet.getRange('B8').clearDataValidations();
    return;
  }
  const dv = SpreadsheetApp.newDataValidation().requireValueInList(subcategories, true).setAllowInvalid(false).build();
  inputSheet.getRange('B8').setDataValidation(dv);
  if (subcategories.indexOf(String(inputSheet.getRange('B8').getValue() || '').trim()) === -1) {
    inputSheet.getRange('B8').setValue(subcategories[0]);
  }
}

function getCategoriesForLine_(line) {
  if (!line) { return []; }
  const sheet = getSheet_(APP.sheets.categories, true);
  const rows = readDataRows_(sheet, 1, 5);
  const set = {};
  rows.forEach(function (r) {
    if (String(r[0]).trim() === line && String(r[4]).toLowerCase() === 'activa') {
      set[String(r[1]).trim()] = true;
    }
  });
  return Object.keys(set).sort();
}

function getSubcategoriesForLineCategory_(line, category) {
  if (!line || !category) { return []; }
  const sheet = getSheet_(APP.sheets.categories, true);
  const rows = readDataRows_(sheet, 1, 5);
  const set = {};
  rows.forEach(function (r) {
    if (String(r[0]).trim() === line && String(r[1]).trim() === category && String(r[4]).toLowerCase() === 'activa') {
      set[String(r[2]).trim()] = true;
    }
  });
  return Object.keys(set).sort();
}

function readTransactions_() {
  const sheet = getSheet_(APP.sheets.tx, true);
  const rows = readDataRows_(sheet, 1, 11);
  const tx = [];
  rows.forEach(function (r) {
    const d = toDate_(r[0]);
    if (!d) { return; }
    tx.push({
      date: d,
      type: String(r[1] || '').toLowerCase().trim(),
      line: String(r[2] || '').trim(),
      category: String(r[3] || '').trim(),
      subcategory: String(r[4] || '').trim(),
      concept: String(r[5] || '').trim(),
      amount: toNumber_(r[6]),
      status: String(r[7] || '').toLowerCase().trim(),
      source: String(r[8] || '').trim()
    });
  });
  return tx;
}

function computeKpi_(tx) {
  let income = 0;
  let expense = 0;
  let pending = 0;
  let confirmed = 0;
  tx.forEach(function (t) {
    if (t.amount >= 0) {
      income += t.amount;
    } else {
      expense += Math.abs(t.amount);
    }
    if (t.status === 'confirmado') {
      confirmed += 1;
    } else {
      pending += Math.abs(t.amount);
    }
  });
  const result = income - expense;
  return {
    income: round2_(income),
    expense: round2_(expense),
    result: round2_(result),
    pending: round2_(pending),
    margin: income === 0 ? 0 : round2_(result / income),
    movements: tx.length,
    confirmedRate: tx.length === 0 ? 0 : round2_(confirmed / tx.length)
  };
}

function buildMonthlySummary_(tx, monthCount) {
  const now = new Date();
  const keys = [];
  for (let i = monthCount - 1; i >= 0; i -= 1) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    keys.push(monthKey_(d));
  }

  const map = {};
  keys.forEach(function (k) {
    map[k] = { income: 0, expense: 0, movements: 0 };
  });

  tx.forEach(function (t) {
    const key = monthKey_(t.date);
    if (!map[key]) { return; }
    if (t.amount >= 0) {
      map[key].income += t.amount;
    } else {
      map[key].expense += Math.abs(t.amount);
    }
    map[key].movements += 1;
  });

  return keys.map(function (k) {
    const r = map[k];
    const result = r.income - r.expense;
    return {
      month: k,
      income: round2_(r.income),
      expense: round2_(r.expense),
      result: round2_(result),
      margin: r.income === 0 ? 0 : round2_(result / r.income),
      movements: r.movements
    };
  });
}

function computeByLineSummary_(tx) {
  const map = {};
  APP.businessLines.forEach(function (line) {
    map[line] = { income: 0, expense: 0, result: 0 };
  });

  tx.forEach(function (t) {
    const line = map[t.line] ? t.line : 'Sin clasificar';
    if (!map[line]) {
      map[line] = { income: 0, expense: 0, result: 0 };
    }
    if (t.amount >= 0) {
      map[line].income += t.amount;
    } else {
      map[line].expense += Math.abs(t.amount);
    }
  });

  const out = Object.keys(map).map(function (line) {
    const income = round2_(map[line].income);
    const expense = round2_(map[line].expense);
    const result = round2_(income - expense);
    const risk = result >= 0 ? 'BAJO' : (result > -2000 ? 'MEDIO' : 'ALTO');
    return { line: line, income: income, expense: expense, result: result, risk: risk };
  });

  return out.filter(function (x) { return APP.businessLines.indexOf(x.line) >= 0; });
}

function computeRiskStatus_(kpi, byLine) {
  let score = 0;
  if (kpi.result < 0) { score += 40; }
  if (kpi.pending > Math.max(kpi.income * 0.35, 2000)) { score += 30; }
  if (kpi.confirmedRate < 0.65) { score += 20; }
  const highLines = byLine.filter(function (x) { return x.risk === 'ALTO'; }).length;
  if (highLines >= 2) { score += 20; }

  if (score >= 70) {
    return {
      label: 'ROJO',
      detail: 'Tension alta. Prioriza caja y recorte de gasto no critico.',
      background: '#FDE2E2',
      fontColor: '#7A0000'
    };
  }
  if (score >= 40) {
    return {
      label: 'AMARILLO',
      detail: 'Atencion. Ajusta gasto y acelera cobros pendientes.',
      background: '#FFF3BF',
      fontColor: '#7A0000'
    };
  }
  return {
    label: 'BLANCO',
    detail: 'Controlado. Mantener disciplina y crecimiento rentable.',
    background: '#FFFFFF',
    fontColor: '#7A0000'
  };
}

function buildActions_(kpi, byLine, risk) {
  const weak = byLine.slice().sort(function (a, b) { return a.result - b.result; })[0];
  const best = byLine.slice().sort(function (a, b) { return b.result - a.result; })[0];
  const actions = [];
  actions.push('1) Semaforo actual: ' + risk.label + '.');
  actions.push('2) Pendiente total: ' + formatMoneyText_(kpi.pending) + '. Ejecutar seguimiento de cobros hoy.');
  if (weak) {
    actions.push('3) Linea critica: ' + weak.line + ' (' + formatMoneyText_(weak.result) + '). Revisar precio/coste esta semana.');
  }
  if (best) {
    actions.push('4) Linea fuerte: ' + best.line + ' (' + formatMoneyText_(best.result) + '). Proteger margen y replicar estrategia.');
  }
  actions.push('5) Objetivo semanal: subir tasa de confirmado por encima de 80%.');
  return actions;
}
function ensureAllSheets_() {
  return {
    panel: getSheet_(APP.sheets.panel, true),
    input: getSheet_(APP.sheets.input, true),
    guide: getSheet_(APP.sheets.guide, true),
    tx: getSheet_(APP.sheets.tx, true),
    scenarios: getSheet_(APP.sheets.scenarios, true),
    audit: getSheet_(APP.sheets.audit, true),
    budget: getSheet_(APP.sheets.budget, true),
    invoices: getSheet_(APP.sheets.invoices, true),
    lines: getSheet_(APP.sheets.lines, true),
    categories: getSheet_(APP.sheets.categories, true),
    log: getSheet_(APP.sheets.log, true),
    config: getSheet_(APP.sheets.config, true)
  };
}

function getSheet_(name, createIfMissing) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(name);
  if (!sheet && createIfMissing) {
    sheet = ss.insertSheet(name);
  }
  if (!sheet) {
    throw new Error('No existe hoja: ' + name);
  }
  return sheet;
}

function hideTechnicalSheets_(sheets) {
  const visible = {};
  visible[APP.sheets.panel] = true;
  visible[APP.sheets.input] = true;
  visible[APP.sheets.guide] = true;

  Object.keys(sheets).forEach(function (k) {
    const sheet = sheets[k];
    if (!sheet) { return; }
    if (visible[sheet.getName()]) {
      sheet.showSheet();
    } else {
      sheet.hideSheet();
    }
  });
}

function protectReadOnlySheets_(sheets) {
  sheets.forEach(function (sheet) {
    try {
      const protections = sheet.getProtections(SpreadsheetApp.ProtectionType.SHEET);
      protections.forEach(function (p) {
        if (String(p.getDescription() || '').indexOf('READ_ONLY_V2') >= 0) {
          p.remove();
        }
      });
      const protection = sheet.protect();
      protection.setDescription('READ_ONLY_V2');
      protection.setWarningOnly(true);
    } catch (err) {
      appendLog_('WARN', 'protectReadOnlySheets', { sheet: sheet.getName(), error: String(err) });
    }
  });
}

function appendAudit_(block, level, detail, value) {
  try {
    const sheet = getSheet_(APP.sheets.audit, true);
    setupGenericHeader_(sheet, ['Fecha', 'Bloque', 'Nivel', 'Detalle', 'Valor']);
    sheet.appendRow([new Date(), block, level, detail, String(value || '')]);
  } catch (err) {
    appendLog_('WARN', 'appendAudit fallback', { error: String(err) });
  }
}

function appendLog_(level, action, detailObj) {
  const sheet = getSheet_(APP.sheets.log, true);
  setupGenericHeader_(sheet, ['Fecha', 'Nivel', 'Accion', 'Detalle']);
  const detail = detailObj ? JSON.stringify(detailObj) : '';
  sheet.appendRow([new Date(), level, action, detail]);
}

function setConfigValue_(key, value) {
  const sheet = getSheet_(APP.sheets.config, true);
  setupGenericHeader_(sheet, ['Clave', 'Valor', 'ActualizadoEn']);
  const last = sheet.getLastRow();
  if (last < 2) {
    sheet.appendRow([key, String(value), new Date()]);
    return;
  }
  const keys = sheet.getRange(2, 1, last - 1, 1).getValues();
  for (let i = 0; i < keys.length; i += 1) {
    if (String(keys[i][0]) === key) {
      sheet.getRange(i + 2, 2).setValue(String(value));
      sheet.getRange(i + 2, 3).setValue(new Date());
      return;
    }
  }
  sheet.appendRow([key, String(value), new Date()]);
}

function getConfigValue_(key) {
  const sheet = getSheet_(APP.sheets.config, true);
  const last = sheet.getLastRow();
  if (last < 2) { return ''; }
  const rows = sheet.getRange(2, 1, last - 1, 2).getValues();
  for (let i = 0; i < rows.length; i += 1) {
    if (String(rows[i][0]) === key) {
      return String(rows[i][1] || '');
    }
  }
  return '';
}

function readDataRows_(sheet, startRow, width) {
  if (sheet.getLastRow() < startRow + 1) { return []; }
  return sheet.getRange(startRow + 1, 1, sheet.getLastRow() - startRow, width).getValues();
}

function clearRangeValues_(sheet, row, col, numRows, numCols) {
  sheet.getRange(row, col, numRows, numCols).clearContent();
}

function writeMatrix_(sheet, row, col, matrix) {
  if (!matrix || matrix.length === 0) { return; }
  const numRows = matrix.length;
  const numCols = matrix[0].length;
  sheet.getRange(row, col, numRows, numCols).setValues(matrix);
}

function removeTriggersByHandler_(handlerName) {
  ScriptApp.getProjectTriggers().forEach(function (trigger) {
    if (trigger.getHandlerFunction() === handlerName) {
      ScriptApp.deleteTrigger(trigger);
    }
  });
}

function withLock_(runner) {
  const lock = LockService.getDocumentLock();
  lock.waitLock(20000);
  try {
    return runner();
  } finally {
    lock.releaseLock();
  }
}

function toNumber_(value) {
  if (value === null || typeof value === 'undefined') { return 0; }
  if (typeof value === 'number') { return value; }
  let t = String(value).trim();
  if (!t) { return 0; }
  t = t.replace(/[^\d,.\-]/g, '');
  if (t.indexOf(',') >= 0 && t.indexOf('.') >= 0) {
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replace(/\./g, '').replace(',', '.');
    } else {
      t = t.replace(/,/g, '');
    }
  } else if (t.indexOf(',') >= 0) {
    t = t.replace(/\./g, '').replace(',', '.');
  }
  const n = parseFloat(t);
  return isFinite(n) ? n : 0;
}

function toDate_(value) {
  if (!value) { return null; }
  if (Object.prototype.toString.call(value) === '[object Date]' && !isNaN(value.getTime())) {
    return value;
  }
  if (typeof value === 'number') {
    const d = new Date(Math.round((value - 25569) * 86400 * 1000));
    if (!isNaN(d.getTime())) { return d; }
  }
  const parsed = new Date(value);
  if (!isNaN(parsed.getTime())) { return parsed; }
  return null;
}

function monthKey_(date) {
  const y = date.getFullYear();
  const m = date.getMonth() + 1;
  return y + '-' + (m < 10 ? '0' + m : String(m));
}

function round2_(n) {
  return Math.round((Number(n) || 0) * 100) / 100;
}

function formatMoneyText_(n) {
  const v = round2_(n);
  return (v < 0 ? '-' : '') + Math.abs(v).toLocaleString('es-ES', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' EUR';
}
