@echo off
cd /d "%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0store-setup.py" %*
) else (
  python "%~dp0store-setup.py" %*
)
if errorlevel 1 echo Preparation stopped. Install Python 3.9+ from python.org if Python was not found.
pause
