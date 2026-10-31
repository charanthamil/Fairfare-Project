@echo off
title FairFare - local website
cd /d "%~dp0"

echo.
echo ========================================
echo   FairFare local site
echo ========================================
echo   1. This window must stay OPEN while you browse.
echo   2. In the browser use EXACTLY:
echo.
echo      http://localhost:5173/
echo.
echo   (not https, not another port unless you changed it)
echo ========================================
echo.

where npm >nul 2>&1
if errorlevel 1 (
    echo ERROR: npm not found. Install Node.js from https://nodejs.org/
    echo Then reopen CMD and run this file again.
    pause
    exit /b 1
)

npm run dev
echo.
echo Server stopped. Press any key to close.
pause >nul
