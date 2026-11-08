@echo off
rem Abre o painel de pedidos no Chrome com impressao direta (sem janela de impressao).
rem A comanda sai na IMPRESSORA PADRAO do Windows.
set URL=https://marombas-burguer.vercel.app/admin.html
set PERFIL=%LOCALAPPDATA%\MarombasPainel
set CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe
if not exist "%CHROME%" set CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe
if not exist "%CHROME%" set CHROME=%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe
if exist "%CHROME%" (
  start "" "%CHROME%" --kiosk-printing --user-data-dir="%PERFIL%" --no-first-run --app=%URL%
) else (
  start "" msedge --kiosk-printing --user-data-dir="%PERFIL%" --no-first-run --app=%URL%
)
