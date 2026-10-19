@echo off
cd /d "%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0validate-files.py" %*
) else (
  python "%~dp0validate-files.py" %*
)
if errorlevel 1 echo Validation stopped. Install Python 3.9+ from python.org if Python was not found.
pause
