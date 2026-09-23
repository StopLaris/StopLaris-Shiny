"""Run a real Shiny server and HTTP checks in the same process namespace.

Usage: python runtime/http_qa.py /absolute/app/path [expected title text]
Optional STOPLARIS_BROWSER_QA_CONFIG=/absolute/config.json also invokes browser QA.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urljoin
from urllib.request import urlopen

app_path = str(Path(sys.argv[1]).resolve())
expected = sys.argv[2] if len(sys.argv) > 2 else "StopLaris"
output = Path(__file__).parent / "http-qa"
output.mkdir(exist_ok=True)
report = {"app_path": app_path, "status": "failed", "checks": []}
server_log = open(output / "server.log", "w", encoding="utf-8")
server = subprocess.Popen([
    "Rscript", "-e",
    'args <- commandArgs(TRUE); shiny::runApp(args[1], host="127.0.0.1", port=3838, launch.browser=FALSE)',
    app_path,
], stdout=server_log, stderr=subprocess.STDOUT, cwd=app_path)
url = "http://127.0.0.1:3838/"
try:
    last_error = None
    for _ in range(120):
        if server.poll() is not None:
            raise RuntimeError(f"Shiny server exited with status {server.returncode}")
        try:
            with urlopen(url, timeout=2) as response:
                html = response.read().decode("utf-8")
                status = response.status
            break
        except OSError as exc:
            last_error = exc
            time.sleep(0.5)
    else:
        raise RuntimeError(f"Shiny server never became ready: {last_error}")
    if status != 200 or expected not in html:
        raise AssertionError(f"Unexpected UI response: status={status}, expected text={expected!r}")
    (output / "initial-ui.html").write_text(html, encoding="utf-8")
    report["checks"].append({"name": "Shiny HTTP UI", "status": "passed", "http_status": status, "bytes": len(html.encode("utf-8"))})
    assets = list(dict.fromkeys(re.findall(r'<(?:script|link|img)[^>]+(?:src|href)="([^"]+)"', html)))
    for asset in assets:
        if asset.startswith(("http://", "https://", "data:", "#", "//")):
            continue
        with urlopen(urljoin(url, asset), timeout=10) as response:
            content = response.read()
            if response.status != 200 or not content:
                raise AssertionError(f"Missing UI asset: {asset}")
        if "stoplaris-logo" in asset:
            if not content.startswith(b"\x89PNG\r\n\x1a\n"):
                raise AssertionError(f"Logo is not a valid PNG response: {asset}")
            report["checks"].append({"name": "Supplied logo PNG served", "status": "passed", "path": asset, "bytes": len(content)})
        else:
            report["checks"].append({"name": "UI asset", "status": "passed", "path": asset, "bytes": len(content)})
    browser_config = os.environ.get("STOPLARIS_BROWSER_QA_CONFIG")
    if browser_config:
        subprocess.run(["node", str(Path(__file__).parent / "browser_qa.cjs"), browser_config], check=True)
    report["status"] = "passed"
except Exception as exc:
    report["error"] = str(exc)
    raise
finally:
    server.terminate()
    try:
        server.wait(timeout=10)
    except subprocess.TimeoutExpired:
        server.kill()
        server.wait()
    server_log.close()
    (output / "http-qa-report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, indent=2, ensure_ascii=False))
