/* Run: node runtime/browser_qa.cjs runtime/browser_qa_config.json
   This script needs a browser-capable host and a live Shiny server. */
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const configPath = process.argv[2];
const cfg = configPath ? JSON.parse(fs.readFileSync(configPath, 'utf8')) : {};
const outputDir = path.resolve(cfg.outputDir || path.join(__dirname, 'browser-qa'));
fs.mkdirSync(outputDir, { recursive: true });
const report = { startedAt: new Date().toISOString(), url: cfg.url || 'http://127.0.0.1:3838', checks: [], browserErrors: [], consoleErrors: [], failedRequests: [], screenshots: [], downloads: [] };
const check = (name, details = {}) => report.checks.push({ name, status: 'passed', ...details });
const remembered = new Map();

function csvRecords(text) {
  const rows = []; let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '"') {
      if (quoted && text[i + 1] === '"') { field += '"'; i++; }
      else quoted = !quoted;
    } else if (ch === ',' && !quoted) { row.push(field); field = ''; }
    else if ((ch === '\n' || ch === '\r') && !quoted) {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(field); rows.push(row); row = []; field = '';
    } else field += ch;
  }
  if (quoted) throw new Error('CSV has an unterminated quoted field');
  if (field.length || row.length) { row.push(field); rows.push(row); }
  const header = rows.shift() || [];
  if (!header.length) throw new Error('CSV has no header');
  return { header, records: rows.filter(r => r.some(v => v.length)).map(r => Object.fromEntries(header.map((key, i) => [key, r[i] ?? '']))) };
}

async function noOverflow(page, name) {
  const dimensions = await page.evaluate(() => ({ viewport: window.innerWidth, document: document.documentElement.scrollWidth }));
  if (dimensions.document > dimensions.viewport + 2) throw new Error(name + ' horizontal document overflow: ' + JSON.stringify(dimensions));
  check(name + ' has no horizontal document overflow', dimensions);
}

async function expectedText(page, assertion) {
  await page.waitForFunction(({ selector, expected, exact }) => {
    const node = document.querySelector(selector);
    return node && (exact ? node.innerText.trim() === expected : node.innerText.includes(expected));
  }, { selector: assertion.selector || 'body', expected: assertion.text, exact: Boolean(assertion.exact) }, { timeout: 30000 });
}

async function settled(page) {
  await page.waitForFunction(() => window.Shiny && window.Shiny.shinyapp && window.Shiny.shinyapp.$socket && window.Shiny.shinyapp.$socket.readyState === 1, null, { timeout: 30000 });
  await page.evaluate(() => {
    if (!window.__stoplarisQaActivityHook) {
      window.__stoplarisQaActivityHook = true;
      window.jQuery(document).on('shiny:busy shiny:idle shiny:value shiny:inputchanged shiny:visualchange', () => { window.__stoplarisQaActivity = Date.now(); });
    }
    window.__stoplarisQaActivity = Date.now();
  });
  await page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy') && !document.querySelector('.recalculating') && Date.now() - window.__stoplarisQaActivity >= 1200, null, { timeout: 60000 });
  await page.waitForFunction(() => Array.from(document.querySelectorAll('.shiny-plot-output img')).filter(n => n.getBoundingClientRect().width > 0).every(n => n.complete && n.naturalWidth > 0), null, { timeout: 30000 });
  const errors = await page.locator('.shiny-output-error:visible').allTextContents();
  if (errors.length) throw new Error('Visible Shiny output errors: ' + errors.join(' | '));
}

async function clickTab(page, selector) {
  const tab = page.locator(selector).first();
  if (!(await tab.isVisible())) {
    const toggle = page.locator('.navbar-toggle:visible, .navbar-toggler:visible').first();
    if (await toggle.count()) await toggle.click();
  }
  await tab.click();
  await settled(page);
}

async function screenshot(page, name) {
  await page.evaluate(() => window.scrollTo(0, 0));
  await settled(page);
  const target = path.join(outputDir, name + '.png');
  await page.screenshot({ path: target, fullPage: true, animations: 'disabled' });
  if (!report.screenshots.includes(target)) report.screenshots.push(target);
}

async function action(page, step, viewportName) {
  if (step.type === 'tab') await clickTab(page, step.selector);
  else if (step.type === 'select') {
    const el = page.locator(step.selector);
    const isSelectize = await el.evaluate(n => Boolean(n.selectize));
    if (isSelectize) await el.evaluate((n, value) => n.selectize.setValue(value), step.value);
    else await el.selectOption(step.value);
    await settled(page);
  } else if (step.type === 'fill') {
    await page.locator(step.selector).fill(String(step.value));
    await page.locator(step.selector).blur();
    await settled(page);
  } else if (step.type === 'click') {
    await page.locator(step.selector).click();
    await settled(page);
  } else if (step.type === 'slider') {
    await page.locator(step.selector).evaluate((n, value) => {
      const range = window.jQuery(n).data('ionRangeSlider');
      range.update({ from: value[0], to: value[1] });
      window.jQuery(n).trigger('change');
    }, step.value);
    await settled(page);
  } else if (step.type === 'screenshot') {
    await screenshot(page, step.filename);
  } else if (step.type === 'rememberText') {
    remembered.set(step.key, await page.locator(step.selector).innerText());
  } else if (step.type === 'assertRemembered') {
    const actual = await page.locator(step.selector).innerText();
    if (actual !== remembered.get(step.key)) throw new Error('Explorer filters changed fixed patient assessment: ' + step.key);
  } else if (step.type === 'assert') {
    await settled(page);
  } else if (step.type === 'tableAlignment') {
    const root = page.locator(step.selector);
    let header = root.locator('.dataTables_scrollHead thead th').first();
    let body = root.locator('.dataTables_scrollBody tbody td').first();
    if (!(await header.count())) header = root.locator('thead th').first();
    if (!(await body.count())) body = root.locator('tbody td').first();
    const headBox = await header.boundingBox();
    const bodyBox = await body.boundingBox();
    if (!headBox || !bodyBox) throw new Error('Table header/body not visible: ' + step.selector);
    if (Math.abs(headBox.x - bodyBox.x) > 3) throw new Error('Table header/body columns misaligned: ' + JSON.stringify({ headBox, bodyBox }));
    report.checks.push({ name: step.name, status: 'passed', selector: step.selector, headerX: headBox.x, bodyX: bodyBox.x });
    return;
  } else if (step.type === 'download') {
    const pending = page.waitForEvent('download');
    await page.locator(step.selector).click();
    const download = await pending;
    const target = path.join(outputDir, path.basename(download.suggestedFilename()));
    await download.saveAs(target);
    const bytes = fs.readFileSync(target);
    if (bytes.length < 2) throw new Error('Download is empty');
    if (step.format === 'png') {
      if (bytes.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') throw new Error('Download is not a PNG');
      report.downloads.push({ path: target, bytes: bytes.length, format: 'png' });
    } else {
      const text = bytes.toString('utf8');
      const csv = csvRecords(text);
      for (const column of step.requiredColumns || []) {
        if (!csv.header.includes(column)) throw new Error('Missing CSV column: ' + column);
      }
      const rows = csv.records.length;
      if (step.expectedRows != null && rows !== step.expectedRows) throw new Error(`Expected ${step.expectedRows} CSV records; got ${rows}`);
      for (const record of csv.records) {
        for (const [key, expected] of Object.entries(step.expectedFields || {})) {
          if (record[key] !== String(expected)) throw new Error(`CSV field ${key}: expected ${expected}; got ${record[key]}`);
        }
        for (const [key, expected] of Object.entries(step.numericFields || {})) {
          if (!Number.isFinite(Number(record[key])) || Math.abs(Number(record[key]) - expected) > 1e-9) throw new Error(`CSV numeric field ${key}: expected ${expected}; got ${record[key]}`);
        }
        for (const key of step.nonemptyFields || []) if (!record[key]) throw new Error('Empty CSV field: ' + key);
      }
      report.downloads.push({ path: target, bytes: bytes.length, header: csv.header, rows, checkedFields: step.expectedFields || {}, checkedNumericFields: step.numericFields || {} });
    }
  } else throw new Error('Unknown action type: ' + step.type);
  if (step.assertText) {
    await expectedText(page, { selector: step.assertSelector, text: step.assertText, exact: step.assertExact });
    await settled(page);
  }
  for (const assertion of step.assertions || []) await expectedText(page, assertion);
  if (step.assertImage) {
    await page.waitForFunction(selector => { const n = document.querySelector(selector); return n && n.complete && n.naturalWidth > 0 && n.getBoundingClientRect().width > 0; }, step.assertImage, { timeout: 30000 });
  }
  if (step.type === 'tab' || step.checkOverflow) await noOverflow(page, viewportName + ' ' + (step.name || step.type));
  check(step.name || step.type, { selector: step.selector });
}

(async () => {
  let browser;
  try {
    browser = await chromium.launch({
      executablePath: cfg.executablePath || process.env.CHROME_EXECUTABLE || chromium.executablePath(),
      headless: true,
      args: ['--no-sandbox', '--disable-dev-shm-usage'],
    });
    for (const viewport of [{ name: 'desktop', width: 1440, height: 1000 }, { name: 'mobile', width: 390, height: 844 }]) {
      const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height }, acceptDownloads: true, deviceScaleFactor: 1 });
      const page = await context.newPage();
      page.on('pageerror', error => report.browserErrors.push({ viewport: viewport.name, message: error.message }));
      page.on('console', msg => { if (msg.type() === 'error') report.consoleErrors.push({ viewport: viewport.name, message: msg.text() }); });
      page.on('requestfailed', req => report.failedRequests.push({ viewport: viewport.name, url: req.url(), failure: req.failure() }));
      await page.goto(report.url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await settled(page);
      if (cfg.overviewSelector) await clickTab(page, cfg.overviewSelector);
      for (const selector of cfg.logoSelectors || []) {
        await page.waitForFunction(s => { const n = document.querySelector(s); return n && n.complete && n.naturalWidth > 0 && n.getBoundingClientRect().width > 0 && n.getAttribute('src').includes('stoplaris-logo'); }, selector, { timeout: 30000 });
        check(viewport.name + ' supplied logo loaded', { selector });
      }
      await screenshot(page, viewport.name + '-overview');
      check(viewport.name + ' overview rendered');
      await noOverflow(page, viewport.name + ' overview');
      if (cfg.explorerSelector) {
        await clickTab(page, cfg.explorerSelector);
        await screenshot(page, viewport.name + '-explorer');
        check(viewport.name + ' explorer rendered');
      }
      await noOverflow(page, viewport.name + ' explorer');
      const steps = viewport.name === 'desktop' ? (cfg.steps || []) : (cfg.mobileSteps || []);
      for (const step of steps) await action(page, step, viewport.name);
      await context.close();
    }
    if (report.browserErrors.length || report.consoleErrors.length || report.failedRequests.length) throw new Error('Browser JavaScript, console, or request errors detected');
    report.status = 'passed';
  } catch (error) {
    report.status = 'failed';
    report.error = error.message;
    process.exitCode = 1;
  } finally {
    if (browser) await browser.close();
    report.finishedAt = new Date().toISOString();
    fs.writeFileSync(path.join(outputDir, 'browser-qa-report.json'), JSON.stringify(report, null, 2));
    console.log(JSON.stringify({ status: report.status, checks: report.checks.length, screenshots: report.screenshots.length, error: report.error }, null, 2));
  }
})();
