@echo off
rem Registra i programmi di questo repo come attivita' pianificate all'accensione del PC e li avvia.
rem Gira dalla cartella del repo, come e' adesso: nessuna copia altrove. Chiede i permessi di amministratore.
rem Rilanciarlo e' sicuro: aggiorna attivita', permessi e dipendenze senza toccare i dati.
rem Generato dalla skill riavvia-servizi: la configurazione e' in servizio\servizio.json.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0servizio\servizio.ps1" -Azione installa
set "CODICE=%errorlevel%"
if not "%CODICE%"=="0" if not defined AUTODEPLOY pause
exit /b %CODICE%
