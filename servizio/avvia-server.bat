@echo off
rem Programma "server": lo lancia all'accensione del PC l'attivita' pianificata "PicchioFlung" (INSTALLA.bat).
rem Se il programma si ferma, riparte dopo 30 secondi. Log in logs\server.log nella radice del repo, ruotato a 10 MB.
rem Generato dalla skill riavvia-servizi da servizio\servizio.json: modificare quello e rigenerare.
setlocal
pushd "%~dp0.."
set "RADICE=%CD%"
popd
if not exist "%RADICE%\logs" mkdir "%RADICE%\logs"
set "LOG=%RADICE%\logs\server.log"
cd /d "%RADICE%"
set PYTHONUNBUFFERED=1
set PYTHONUTF8=1
:avvio
if exist "%LOG%" for %%F in ("%LOG%") do if %%~zF GTR 10485760 move /y "%LOG%" "%LOG%.1" >nul
echo [%date% %time%] avvio >> "%LOG%"
"C:\Program Files\Python312\python.exe" -I "%CD%\server.py" >> "%LOG%" 2>&1
echo [%date% %time%] fermo (codice %errorlevel%), riavvio tra 30 secondi >> "%LOG%"
ping -n 31 127.0.0.1 >nul
goto avvio
