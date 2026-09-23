"""Run the packaged R launcher from an unrelated directory and check local assets.
Usage: python scripts/check_local_start.py
Requires Rscript with the application R packages; Python standard library only.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from urllib.parse import urljoin
from urllib.request import urlopen

root = Path(__file__).resolve().parent.parent
validation = root / "validation"
validation.mkdir(exist_ok=True)
rscript = shutil.which("Rscript")
if not rscript:
    raise SystemExit("Rscript bulunamadı; önce R kurun.")
environment = os.environ.copy()
environment.update(STOPLARIS_OPEN_BROWSER="false", STOPLARIS_HOST="127.0.0.1", STOPLARIS_PORT="3838")
result = {"status": "failed", "launch_from_unrelated_directory": True, "checks": []}
with tempfile.TemporaryDirectory(prefix="stoplaris-start-") as cwd:
    with open(validation / "startup_server.log", "w", encoding="utf-8") as log:
        process = subprocess.Popen([rscript, str(root / "run_app.R")], cwd=cwd,
                                   env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            url = "http://127.0.0.1:3838/"
            for attempt in range(80):
                if process.poll() is not None:
                    raise RuntimeError("R sunucusu açılamadı; startup_server.log dosyasını inceleyin.")
                try:
                    with urlopen(url, timeout=2) as response:
                        html = response.read().decode("utf-8")
                        assert response.status == 200
                    break
                except OSError:
                    time.sleep(0.25)
            else:
                raise RuntimeError("R sunucusu zamanında yanıt vermedi.")
            assert "StopLaris" in html and "Hücre keşfi" in html
            result["checks"].append({"name": "launcher_http_ui", "status": "passed"})
            for asset in re.findall(r'<(?:script|link)[^>]+(?:src|href)="([^"]+)"', html):
                if asset.startswith(("http://", "https://", "//", "#", "data:")):
                    continue
                with urlopen(urljoin(url, asset), timeout=10) as response:
                    body = response.read()
                    assert response.status == 200 and body
                result["checks"].append({"name": "local_asset", "asset": asset, "status": "passed"})
            result["status"] = "passed"
        except Exception as error:
            result["error"] = str(error)
            raise
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            (validation / "portable_startup.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
print(json.dumps({"status": result["status"], "checks": len(result["checks"])}, ensure_ascii=False))
