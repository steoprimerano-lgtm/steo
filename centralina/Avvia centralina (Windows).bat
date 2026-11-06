@echo off
chcp 65001 > NUL
title Centralina Luci
cd /d "%~dp0"
where node > NUL 2> NUL
if errorlevel 1 (
  echo Node.js non e' installato. Scaricalo da https://nodejs.org ^(versione LTS^) e riprova.
  pause
  exit /b 1
)
node server.js
echo.
echo La centralina si e' fermata.
pause
