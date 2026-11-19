@echo off
rem Ferma i programmi di questo repo, scarica gli aggiornamenti (git pull --ff-only) e li fa ripartire.
rem Se l'aggiornamento non riesce, riparte la versione attuale. Chiede i permessi di amministratore.
rem Lo lancia anche AutoDeploy con AUTODEPLOY=1: nessuna pausa, codice 0 solo se tutto risponde.
rem Generato dalla skill riavvia-servizi: la configurazione e' in servizio\servizio.json.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0servizio\servizio.ps1" -Azione riavvia
set "CODICE=%errorlevel%"
if not "%CODICE%"=="0" if not defined AUTODEPLOY pause
exit /b %CODICE%
