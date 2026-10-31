@echo off
title FairFare dev server
cd /d "%~dp0"

where node >nul 2>nul
if errorlevel 1 (
  echo.
  echo  [X] Node.js was not found. Install LTS from https://nodejs.org/
  echo      Then close and reopen this file.
  echo.
  pause
  exit /b 1
)

if not exist "node_modules\" (
  echo Installing npm packages ^(first time only^)...
  call npm install
  if errorlevel 1 (
    echo npm install failed.
    pause
    exit /b 1
  )
  echo.
)

echo.
echo  ============================================================
echo   FairFare — keep this window OPEN while you use the site.
echo.
echo   In your browser, open EXACTLY:
echo.
echo      http://localhost:5173
echo.
echo   On another device ^(same Wi-Fi^), use the "Network:" URL
echo   that appears below ^(http://192.168.x.x:5173^).
echo.
echo   Do NOT double-click index.html — that will not work.
echo   Press Ctrl+C in this window to stop the server.
echo  ============================================================
echo.

call npm run dev
echo.
pause
