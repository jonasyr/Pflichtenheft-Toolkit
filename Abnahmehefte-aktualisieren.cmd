@echo off
REM Doppelklick: erzeugt je Version ein Abnahmeheft aus dem Pflichtenheft
REM und prueft die Hefte dagegen. Vorhandene Prosa und Statuswerte bleiben.
REM Voraussetzung: PowerShell 7 oder neuer (wegen ConvertFrom-Markdown).
REM Alternativ das Pflichtenheft auf diese Datei ziehen - dann wird genau
REM dieses verwendet, egal wo es liegt.
setlocal
cd /d "%~dp0"
set "MINVERSION=7"

set "ARGS="
if not "%~1"=="" set ARGS=-PflichtenheftPfad "%~1"

where pwsh >nul 2>&1
if errorlevel 1 goto :fehlt

set "PSMAJOR="
for /f "usebackq delims=" %%v in (`pwsh -NoProfile -NoLogo -Command "$PSVersionTable.PSVersion.Major" 2^>nul`) do set "PSMAJOR=%%v"
if not defined PSMAJOR goto :fehlt
if %PSMAJOR% LSS %MINVERSION% goto :zualt

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Abnahmehefte-aktualisieren.ps1" %ARGS% -Interaktiv
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo   Mindestens ein Heft weicht vom Pflichtenheft ab. Die Meldung steht oben.
  echo   Fuer diese Hefte wurde nichts geschrieben.
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
