@echo off
REM Doppelklick: prueft das Toolkit auf diesem Rechner durch.
REM Es wird nur in einem temporaeren Ordner gearbeitet, eigene Dokumente
REM werden nicht angefasst.
setlocal
cd /d "%~dp0"
set "MINVERSION=7"

where pwsh >nul 2>&1
if errorlevel 1 goto :fehlt

set "PSMAJOR="
for /f "usebackq delims=" %%v in (`pwsh -NoProfile -NoLogo -Command "$PSVersionTable.PSVersion.Major" 2^>nul`) do set "PSMAJOR=%%v"
if not defined PSMAJOR goto :fehlt
if %PSMAJOR% LSS %MINVERSION% goto :zualt

pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Toolkit-Selbsttest.ps1"

echo.
pause
endlocal
exit /b 0

:fehlt
echo.
echo  ==========================================================
echo    PowerShell %MINVERSION% wird benoetigt - nicht gefunden
echo  ==========================================================
echo.
echo   Das Toolkit erzeugt die HTML mit "ConvertFrom-Markdown".
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
echo   und die Datei erneut per Doppelklick starten.
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
echo     A. winget install --id Microsoft.PowerShell --source winget
echo     B. https://aka.ms/powershell
echo.
echo   WICHTIG: Danach dieses Fenster schliessen und die Datei
echo   erneut per Doppelklick starten.
echo.
pause
endlocal
exit /b 1
