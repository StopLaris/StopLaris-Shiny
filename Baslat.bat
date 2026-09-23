@echo off
cd /d "%~dp0"
where Rscript >nul 2>nul
if errorlevel 1 (
  echo Rscript bulunamadi. RStudio icinde bu klasoru acip source^('run_app.R'^) calistirin.
  pause
  exit /b 1
)
Rscript install.R
if errorlevel 1 (
  pause
  exit /b 1
)
Rscript run_app.R
pause
