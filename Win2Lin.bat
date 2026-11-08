@echo off
:: Win2Lin.bat - Double-click wizard (works from any folder)
setlocal enabledelayedexpansion

set "BAT_DIR=%~dp0"
set "PS1_FILE="

if exist "%BAT_DIR%scripts\Win2Lin.ps1" set "PS1_FILE=%BAT_DIR%scripts\Win2Lin.ps1"
if not defined PS1_FILE if exist "%BAT_DIR%Win2Lin.ps1" set "PS1_FILE=%BAT_DIR%Win2Lin.ps1"
if not defined PS1_FILE if exist "%BAT_DIR%Win2Lin_script.ps1" set "PS1_FILE=%BAT_DIR%Win2Lin_script.ps1"
if not defined PS1_FILE if exist "%BAT_DIR%scripts\Win2Lin-lite.ps1" set "PS1_FILE=%BAT_DIR%scripts\Win2Lin-lite.ps1"

if not defined PS1_FILE (
    echo [ERROR] Win2Lin script not found. Keep Win2Lin.bat next to the scripts\ folder.
    pause
    exit /b 1
)

:menu
cls
echo ============================================================
echo   Win2Lin  -  Windows to Linux migration helper
echo ============================================================
echo.
echo   Script: %PS1_FILE%
echo.
echo   What do you want to do?
echo     1 = See what I have (safe, copies nothing)
echo     2 = Copy my files (dry-run preview first)
echo     3 = Help
echo     0 = Quit
echo.
set /p choice="  Type 1, 2, 3 or 0 and press Enter: "

if "%choice%"=="1" goto inventory
if "%choice%"=="2" goto copy
if "%choice%"=="3" goto help
if "%choice%"=="0" exit /b 0
echo. Invalid choice.
timeout /t 1 /nobreak >nul
goto menu

:inventory
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%PS1_FILE%" -Mode Inventory
goto done

:copy
echo.
echo [Preview] Dry run first (writes nothing to export).
powershell -ExecutionPolicy Bypass -NoProfile -File "%PS1_FILE%" -Mode Copy -DryRun
echo.
set /p ok="  Preview looks good? Type Y to do the real copy, N to stop: "
if /i not "%ok%"=="Y" goto done
echo.
echo [Copy] Running. Do NOT close this window. Plug in power.
powershell -ExecutionPolicy Bypass -NoProfile -File "%PS1_FILE%" -Mode Copy -Resume
goto done

:help
cls
echo ============================================================
echo   Help - 4 steps
echo ============================================================
echo.
echo 1. CHECK  - Type 1. Lists apps. Copies nothing.
echo 2. COPY   - Type 2. Preview first, then Y to copy.
echo 3. USB    - Export is in C:\Win2Lin_export\^<date^>_...
echo             Copy that WHOLE folder to USB. On Linux: ~/Win2Lin_export/
echo 4. LOGIN  - On Linux: 1) Brave Sync 2) Edge Sync
echo             3) Google Password Manager 4) Antigravity 5) OpenCode
echo.
echo Notes:
echo - Browser passwords are NOT copied (Windows-locked). Use Sync.
echo - Default export is local C:\Win2Lin_export (not OneDrive).
echo - Keep Windows for 14 days after switching.
echo - Simple alternative: scripts\Win2Lin-lite.ps1 (uses robocopy).
echo.
pause
goto menu

:done
echo.
pause
