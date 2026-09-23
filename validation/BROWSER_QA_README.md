# Browser and HTTP validation

The 22 September 2026 run used a real R Shiny server, Playwright and official Chrome Headless Shell. The HTTP harness starts and stops its own R subprocess so the browser and server share the same process/network namespace.

From the app directory, with R dependencies, Python 3, Node and Playwright installed:

```sh
python validation/http_qa.py . StopLaris
```

To include browser checks, install the Playwright Chromium browser or set CHROME_EXECUTABLE to a compatible Chrome Headless Shell:

```sh
STOPLARIS_BROWSER_QA_CONFIG=validation/browser_qa_config.json python validation/http_qa.py . StopLaris
```

The recorded run passed 74 browser checks and 23 HTTP/asset checks. It verifies:

- Both supplied logo images load; the PNG asset is served successfully.
- All seven tabs fit desktop (1440 × 1000) and mobile (390 × 844) viewports.
- Cohort, patient, cell-type, expression-range and measurement filters produce exact source-grounded cell counts.
- Main and calibrated model stages, a 96-row filtered CSV, PNG download signature and permutation-table alignment.
- Patient JK124 displays 3.3/10 with 96 cells; JK126 displays 10.0/10 with 6 cells.
- Patient CSV exports contain the exact method, source version, 10-patient/842-cell reference, clinical_risk_available=FALSE and no clinical risk probability.
- Changing explorer filters does not change the fixed patient assessment.

Eight screenshots cover overview, explorer, models and patient assessment on both viewports. Screenshots wait until Shiny finishes recalculation and plot images are loaded. Port 3838 must be available.

See browser-qa-report.json, http-qa-report.json and runtime_versions.json for the recorded results. These tests verify application behavior; they do not establish clinical validity of the descriptive research index.
