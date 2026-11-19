@echo off
rem Ferma i programmi di questo repo (per esempio per copiare un database). Chiede i permessi di amministratore.
rem Ripartono con RIAVVIA.bat o alla prossima accensione del PC.
rem Generato dalla skill riavvia-servizi: la configurazione e' in servizio\servizio.json.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0servizio\servizio.ps1" -Azione ferma
set "CODICE=%errorlevel%"
if not "%CODICE%"=="0" if not defined AUTODEPLOY pause
exit /b %CODICE%
