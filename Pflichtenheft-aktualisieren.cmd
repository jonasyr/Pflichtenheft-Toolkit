@echo off
REM Doppelklick: erzeugt die HTML neu aus der Markdown-Datei und oeffnet sie.
REM Alternativ eine Markdown-Datei auf diese Datei ziehen - dann wird genau
REM diese verwendet, egal wo sie liegt.
REM Voraussetzung: PowerShell 7 oder neuer (wegen ConvertFrom-Markdown).
setlocal
cd /d "%~dp0"
set "MINVERSION=7"

set "ARGS="
if not "%~1"=="" set ARGS=-MarkdownPfad "%~1"

REM 1) Ist pwsh ueberhaupt vorhanden?
where pwsh >nul 2>&1
if errorlevel 1 goto :fehlt

REM 2) Welche Hauptversion? Windows PowerShell 5.1 reicht nicht aus.
set "PSMAJOR="
for /f "usebackq delims=" %%v in (`pwsh -NoProfile -NoLogo -Command "$PSVersionTable.PSVersion.Major" 2^>nul`) do set "PSMAJOR=%%v"
if not defined PSMAJOR goto :fehlt
if %PSMAJOR% LSS %MINVERSION% goto :zualt

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Pflichtenheft-aktualisieren.ps1" %ARGS% -Interaktiv
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo   Es ist ein Fehler aufgetreten. Die Meldung steht oben.
  echo.
)
pause
endlocal & exit /b %RC%

:fehlt
echo.
echo  ==========================================================
echo    PowerShell %MINVERSION% wird benoetigt - nicht gefunden
echo  ==========================================================
echo.
echo   Diese Datei erzeugt die HTML mit "ConvertFrom-Markdown".
echo   Diesen Befehl gibt es erst ab PowerShell 7. Das in Windows
echo   enthaltene "Windows PowerShell 5.1" reicht nicht aus.
echo.
echo   So installieren Sie es - eine der beiden Moeglichkeiten:
echo.
echo     A. In der Eingabeaufforderung eingeben:
echo          winget install --id Microsoft.PowerShell --source winget
echo.
echo     B. Oder hier herunterladen und installieren:
echo          https://aka.ms/powershell
echo.
echo   WICHTIG: Nach der Installation dieses Fenster schliessen
echo   und die Datei erneut per Doppelklick starten. Der Befehl
echo   "pwsh" ist erst in einem neu geoeffneten Fenster bekannt.
echo.
pause
endlocal
exit /b 1

:zualt
echo.
echo  ==========================================================
echo    PowerShell ist zu alt
echo  ==========================================================
echo.
echo   Gefunden:   Version %PSMAJOR%
echo   Benoetigt:  Version %MINVERSION% oder neuer
echo.
echo   Aktualisieren - eine der beiden Moeglichkeiten:
echo.
echo     A. winget install --id Microsoft.PowerShell --source winget
echo     B. https://aka.ms/powershell
echo.
echo   WICHTIG: Danach dieses Fenster schliessen und die Datei
echo   erneut per Doppelklick starten.
echo.
pause
endlocal
exit /b 1
