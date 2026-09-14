<#
.SYNOPSIS
Prueft das Toolkit auf diesem Rechner durch - alle bekannten Situationen.

.DESCRIPTION
Legt in einem temporaeren Ordner nacheinander Testfaelle an, ruft die beiden
Erzeuger auf und prueft das Ergebnis. Am Ende steht eine Bilanz.

Es wird ausschliesslich unterhalb des temporaeren Ordners geschrieben; eigene
Dokumente werden nicht angefasst. Der Ordner wird am Ende geloescht.
#>
[CmdletBinding()]
param([switch] $Behalten)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Renderer = Join-Path $PSScriptRoot 'Pflichtenheft-aktualisieren.ps1'
$Hefte    = Join-Path $PSScriptRoot 'Abnahmehefte-aktualisieren.ps1'
foreach ($f in @($Renderer, $Hefte)) { if (-not (Test-Path $f)) { throw "Nicht gefunden: $f" } }

$Basis = Join-Path $env:TEMP ("toolkit-selbsttest-" + (Get-Random -Maximum 999999))
New-Item -ItemType Directory -Path $Basis -Force | Out-Null

$script:Ergebnisse = [System.Collections.Generic.List[object]]::new()

# Jeder Fall bekommt einen eigenen Elternordner. Sonst fiele die Suche eine
# Ebene nach oben in die Dokumente der anderen Faelle - was zwar korrekt
# abbraeche, aber den falschen Fehler pruefen wuerde.
function Neuer-Ordner([string] $name) {
    $p = Join-Path (Join-Path $Basis $name) 'projekt'
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

function Werkzeuge-Nach([string] $ordner) {
    Copy-Item (Join-Path $PSScriptRoot 'Pflichtenheft-aktualisieren.ps1') $ordner -Force
    Copy-Item (Join-Path $PSScriptRoot 'Abnahmehefte-aktualisieren.ps1')  $ordner -Force
}

# Minimales, gueltiges Pflichtenheft. Schalter steuern die Sonderfaelle.
function Neues-Pflichtenheft {
    param(
        [string] $Pfad,
        [switch] $OhneVersion,
        [switch] $OhneAnforderungen,
        [switch] $MitMaskiertemPipe,
        [switch] $MussOhneNachweis,
        [switch] $NachweisAufLuecke,
        [switch] $CRLF,
        [switch] $MitOffenenPunkten,
        [switch] $MitAenderungsverzeichnis
    )
    $z = [System.Collections.Generic.List[string]]::new()
    $z.Add('# Pflichtenheft — Prüfling')
    $z.Add('')
    # Kopfangabe wie im Abnahmeheft-Geruest: darf NICHT als Vorspann gelten.
    $z.Add('**Stand: 09.09.2026 · Rev. 1**')
    $z.Add('')
    $z.Add('Kurzes Dokument für den **Selbsttest**, mit Umlauten: äöüß und einem Gedankenstrich —.')
    $z.Add('')
    $z.Add('| | |'); $z.Add('|---|---|')
    $z.Add('| Version | 1.0 — Entwurf |')
    $z.Add('| Stand | 09.09.2026 |')
    $z.Add('')
    # Die Lesehilfe steht in jedem Dokument. Ihre Tabellen enthalten Zeilen,
    # die wie Anforderungen oder Statuswerte aussehen - sie duerfen aber
    # nicht mitgezaehlt werden. Darum ist sie hier immer dabei.
    $z.Add('## Lesehilfe')
    $z.Add('')
    $z.Add('| Kennung | Bedeutung | Kapitel |'); $z.Add('|---|---|---|')
    $z.Add('| `/LZ…/` | Musskriterium | 1.1 |')
    $z.Add('| `/LA…/` | Abgrenzung | 1.3 |')
    $z.Add('')
    $z.Add('| Priorität | Bedeutung |'); $z.Add('|---|---|')
    $z.Add('| Muss | Abnahmerelevant |')
    $z.Add('| Soll | Verhandelbar |')
    $z.Add('| Kann | Optional |')
    $z.Add('')
    $z.Add('| Status | Bedeutung |'); $z.Add('|---|---|')
    $z.Add('| offen | Noch nicht begonnen |')
    $z.Add('| fertig | Umgesetzt und geprüft |')
    $z.Add('')
    $z.Add('---'); $z.Add('')
    $z.Add('## 1 Zielbestimmung')
    $z.Add('')
    if (-not $OhneAnforderungen) {
        if ($OhneVersion) {
            $z.Add('| ID | Ziel | Prio | Nachweis |'); $z.Add('|---|---|---|---|')
            $z.Add('| /LZ10/ | Erstes Ziel. | Muss | T-01 |')
            $z.Add('| /LZ20/ | Zweites Ziel. | Soll | Review |')
        } else {
            $z.Add('| ID | Ziel | Version | Prio | Nachweis |'); $z.Add('|---|---|---|---|---|')
            $z.Add('| /LZ10/ | Erstes Ziel. | V1.0 | Muss | T-01 |')
            $z.Add('| /LZ20/ | Zweites Ziel. | V1.1 | Soll | Review |')
            if ($MussOhneNachweis)  { $z.Add('| /LZ30/ | Drittes Ziel ohne Nachweis. | V1.0 | Muss |  |') }
            if ($NachweisAufLuecke) { $z.Add('| /LZ40/ | Viertes Ziel. | V1.0 | Muss | T-99 |') }
            if ($MitMaskiertemPipe) { $z.Add('| /LZ50/ | Muster `^(FP\|P)\d+$` im Text. | V1.0 | Muss | T-01 |') }
        }
        $z.Add('')
        $z.Add('## 1.3 Abgrenzung')
        $z.Add('')
        $z.Add('| ID | Nicht Gegenstand | Begründung |'); $z.Add('|---|---|---|')
        $z.Add('| /LA10/ | Etwas ausdrücklich Ausgeschlossenes. | Entscheid |')
        $z.Add('')
        $z.Add('---'); $z.Add('')
        $z.Add('## 2 Testfälle')
        $z.Add('')
        $z.Add('| ID | Testfall | Erwartetes Ergebnis | Prüft |'); $z.Add('|---|---|---|---|')
        $z.Add('| T-01 | Ein Testfall | Ein Ergebnis | /LZ10/ |')
    }
    if ($MitOffenenPunkten) {
        # Jeder Punkt steht vorschriftsgemaess zweimal: an seiner Stelle und
        # im Kapitel Risiken. Gezaehlt werden duerfen trotzdem nur zwei.
        $p1 = '> **ZU KLÄREN** — Wie lange werden Protokolle aufbewahrt? — Entscheidung durch: Projektleitung — blockiert die Abnahme: ja'
        $p2 = '> **ZU KLÄREN** — Welche Dokumentarten sind vorgesehen? — Entscheidung durch: Fachbereich — blockiert die Abnahme: nein'
        $z.Add(''); $z.Add('## 3 Fachliches'); $z.Add(''); $z.Add($p1); $z.Add(''); $z.Add($p2)
        $z.Add(''); $z.Add('---'); $z.Add(''); $z.Add('## 12 Risiken und offene Punkte'); $z.Add('')
        $z.Add($p1); $z.Add(''); $z.Add($p2)
    }
    if ($MitAenderungsverzeichnis) {
        # Eine Spalte "Version" spaeter im Dokument darf den Kopf nicht verfaelschen.
        $z.Add(''); $z.Add('---'); $z.Add(''); $z.Add('## Änderungsverzeichnis'); $z.Add('')
        $z.Add('| Datum | Version | Was |'); $z.Add('|---|---|---|')
        $z.Add('| 01.01.2027 | 9.9 — Falschwert | Nur ein Eintrag |')
    }
    $z.Add('')
    $text = $z -join $(if ($CRLF) { "`r`n" } else { "`n" })
    [System.IO.File]::WriteAllText($Pfad, $text, [System.Text.UTF8Encoding]::new($false))
}

function Starte([string] $skript, [string[]] $argumente) {
    $alle = @($argumente) + @('-NichtOeffnen')
    $ausgabe = & pwsh -NoProfile -ExecutionPolicy Bypass -File $skript @alle 2>&1 | Out-String
    return [pscustomobject]@{ Ausgabe = $ausgabe; Code = $LASTEXITCODE }
}

# Wie Starte, aber mit -Interaktiv und einer vorbereiteten Eingabe auf stdin.
# So laesst sich der Weg pruefen, den ein Doppelklick nimmt.
function Starte-MitEingabe([string] $skript, [string[]] $argumente, [string] $eingabe) {
    $alle = @($argumente) + @('-NichtOeffnen', '-Interaktiv')
    $ausgabe = $eingabe | & pwsh -NoProfile -ExecutionPolicy Bypass -File $skript @alle 2>&1 | Out-String
    return [pscustomobject]@{ Ausgabe = $ausgabe; Code = $LASTEXITCODE }
}

# Interaktiv, aber mit geschlossener Eingabe. Read-Host liefert dann $null -
# das muss zu einem sauberen Abbruch fuehren, nicht zu einer Ausnahme.
function Starte-OhneEingabe([string] $skript, [string[]] $argumente) {
    $argText = @($argumente | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $befehl = "pwsh -NoProfile -ExecutionPolicy Bypass -File ""$skript"" $argText -NichtOeffnen -Interaktiv < nul"
    $ausgabe = & cmd.exe /c $befehl 2>&1 | Out-String
    return [pscustomobject]@{ Ausgabe = $ausgabe; Code = $LASTEXITCODE }
}

function Pruefe([string] $name, [scriptblock] $block) {
    try {
        $meldung = & $block
        if ($meldung) { $script:Ergebnisse.Add([pscustomobject]@{ Fall = $name; Ergebnis = 'FEHLER'; Grund = $meldung }) }
        else          { $script:Ergebnisse.Add([pscustomobject]@{ Fall = $name; Ergebnis = 'ok';     Grund = '' }) }
    } catch {
        $script:Ergebnisse.Add([pscustomobject]@{ Fall = $name; Ergebnis = 'FEHLER'; Grund = $_.Exception.Message })
    }
    $letzte = $script:Ergebnisse[$script:Ergebnisse.Count - 1]
    $farbe = if ($letzte.Ergebnis -eq 'ok') { 'Green' } else { 'Red' }
    Write-Host ("  {0,-4} {1}" -f $letzte.Ergebnis, $name) -ForegroundColor $farbe
    if ($letzte.Grund) { Write-Host ("       -> {0}" -f $letzte.Grund) -ForegroundColor DarkYellow }
}

Write-Host ''
Write-Host '  Selbsttest des Pflichtenheft-Toolkits' -ForegroundColor Cyan
Write-Host "  PowerShell $($PSVersionTable.PSVersion)"
Write-Host "  Arbeitsordner: $Basis"
Write-Host ''
Write-Host '  --- Ablageorte ---'

Pruefe 'A1 Werkzeuge und Dokument im selben Ordner' {
    $o = Neuer-Ordner 'a1'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code)" }
    if (-not (Test-Path (Join-Path $o 'Pflichtenheft-Pruefling.html'))) { return 'HTML fehlt' }
}

Pruefe 'A2 Werkzeuge in der Wurzel, Dokument in docs' {
    $o = Neuer-Ordner 'a2'; Werkzeuge-Nach $o
    $d = Join-Path $o 'docs'; New-Item -ItemType Directory -Path $d -Force | Out-Null
    Neues-Pflichtenheft -Pfad (Join-Path $d 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $d 'Pflichtenheft-Pruefling.html'))) { return 'HTML nicht neben dem Dokument' }
}

Pruefe 'A3 Werkzeuge in tools, Dokument in docs' {
    $o = Neuer-Ordner 'a3'
    $t = Join-Path $o 'tools'; $d = Join-Path $o 'docs'
    New-Item -ItemType Directory -Path $t, $d -Force | Out-Null
    Werkzeuge-Nach $t
    Neues-Pflichtenheft -Pfad (Join-Path $d 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $t 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $d 'abnahme\Pruefling_V1.0.html'))) { return 'Heftordner nicht neben dem Dokument' }
}

Pruefe 'A4 Dokument tief verschachtelt' {
    $o = Neuer-Ordner 'a4'; Werkzeuge-Nach $o
    $d = Join-Path $o 'doku\fachlich\stand'
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Neues-Pflichtenheft -Pfad (Join-Path $d 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code)" }
    if (-not (Test-Path (Join-Path $d 'Pflichtenheft-Pruefling.html'))) { return 'HTML fehlt' }
}

Pruefe 'A5 Dokument ausserhalb, per Parameter uebergeben' {
    $o = Neuer-Ordner 'a5'; Werkzeuge-Nach $o
    $f = Neuer-Ordner 'a5-fremd'
    $md = Join-Path $f 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @('-MarkdownPfad', $md)
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $f 'Pflichtenheft-Pruefling.html'))) { return 'HTML nicht neben dem Dokument' }
}

Pruefe 'A6 Pfad mit Leerzeichen und Umlauten' {
    $o = Neuer-Ordner 'a6 Projekt Müller & Söhne'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $o 'abnahme\Pruefling_V1.1.md'))) { return 'Heft fehlt' }
}

Pruefe 'A7 Heftordner liegt beim Dokument, nicht beim Werkzeug' {
    $o = Neuer-Ordner 'a7'
    $t = Join-Path $o 'werkzeug'; $d = Join-Path $o 'unterlagen'
    New-Item -ItemType Directory -Path $t, $d -Force | Out-Null
    Werkzeuge-Nach $t
    Neues-Pflichtenheft -Pfad (Join-Path $d 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $t 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    if (Test-Path (Join-Path $t 'abnahme')) { return 'Heftordner faelschlich beim Werkzeug angelegt' }
    if (-not (Test-Path (Join-Path $d 'abnahme'))) { return 'Heftordner fehlt beim Dokument' }
}

Write-Host ''
Write-Host '  --- Fehlerfaelle ---'

Pruefe 'B1 Kein Pflichtenheft vorhanden' {
    $o = Neuer-Ordner 'b1'; Werkzeuge-Nach $o
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Keine Datei|nicht gefunden') { return 'Meldung nennt die Ursache nicht' }
    if ($r.Ausgabe -notmatch 'MarkdownPfad') { return 'Meldung nennt den Ausweg nicht' }
}

Pruefe 'B2 Zwei Pflichtenhefte - Abbruch mit Auflistung' {
    $o = Neuer-Ordner 'b2'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Eins.md')
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Zwei.md')
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Mehrere') { return 'Meldung nennt die Ursache nicht' }
    if (Test-Path (Join-Path $o 'Pflichtenheft-Eins.html')) { return 'Trotz Abbruch geschrieben' }
}

Pruefe 'B3 Ohne Versionsspalte - Hefte melden das verstaendlich' {
    $o = Neuer-Ordner 'b3'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -OhneVersion
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Version') { return 'Meldung nennt die fehlende Spalte nicht' }
}

Pruefe 'B4 Pflichtenheft ohne Anforderungen' {
    $o = Neuer-Ordner 'b4'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -OhneAnforderungen
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Sollte durchlaufen, meldete aber $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $o 'Pflichtenheft-Pruefling.html'))) { return 'HTML fehlt' }
}

Pruefe 'B5 Heft mit unbekannter Kennung wird abgewiesen' {
    $o = Neuer-Ordner 'b5'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = Get-Content $h -Raw -Encoding utf8
    $t = $t -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LXX9/ | Erfunden. | offen |  |`n"
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $vorher = Get-Content $h -Raw -Encoding utf8
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'LXX9') { return 'Meldung nennt die Kennung nicht' }
    if ((Get-Content $h -Raw -Encoding utf8) -ne $vorher) { return 'Heft wurde trotz Abbruch veraendert' }
}

Pruefe 'B6 Heft mit unzulaessigem Status wird abgewiesen' {
    $o = Neuer-Ordner 'b6'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = (Get-Content $h -Raw -Encoding utf8) -replace '\| offen \|', '| halbfertig |'
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'halbfertig') { return 'Meldung nennt den Wert nicht' }
}

Pruefe 'B7 Heft ohne Anforderungstabelle' {
    $o = Neuer-Ordner 'b7'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    [System.IO.File]::WriteAllText($h, "# Pruefling V1.0`n`nNur Prosa, keine Tabelle.`n", [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Anforderungstabelle') { return 'Meldung nennt die Ursache nicht' }
}

Write-Host ''
Write-Host '  --- Inhaltliche Sonderfaelle ---'

Pruefe 'C1 Maskiertes Pipe im Text verschiebt keine Spalte' {
    $o = Neuer-Ordner 'c1'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -MitMaskiertemPipe
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Ausgabe -match 'verrutscht') { return 'Spalte verrutscht' }
    if ($r.Ausgabe -notmatch 'Muss 2') { return "Muss-Zahl falsch: $($r.Ausgabe)" }
}

Pruefe 'C2 Anforderung ohne Prio-Spalte wird gesondert gezaehlt' {
    $o = Neuer-Ordner 'c2'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Ausgabe -notmatch 'ohne Prio 1') { return "Erwartet 'ohne Prio 1': $($r.Ausgabe)" }
}

Pruefe 'C3 Muss ohne Nachweis wird gemeldet' {
    $o = Neuer-Ordner 'c3'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -MussOhneNachweis
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Ausgabe -notmatch 'LZ30') { return 'Fehlender Nachweis nicht gemeldet' }
}

Pruefe 'C4 Nachweis auf nicht vorhandenen Testfall wird gemeldet' {
    $o = Neuer-Ordner 'c4'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -NachweisAufLuecke
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Ausgabe -notmatch 'T-99') { return 'Luecke nicht gemeldet' }
}

Pruefe 'C5 Windows-Zeilenenden' {
    $o = Neuer-Ordner 'c5'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -CRLF
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
}

Pruefe 'C6 Umlaute kommen in der HTML richtig an' {
    $o = Neuer-Ordner 'c6'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -notmatch 'Umlauten') { return 'Text fehlt' }
    if ($h -match 'Ã¤|Ã¶|Ã¼') { return 'Falsche Zeichenkodierung' }
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $o 'Pflichtenheft-Pruefling.html'))
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) { return 'BOM vorhanden' }
}

Write-Host ''
Write-Host '  --- Wiederholte Laeufe ---'

Pruefe 'D1 Zweiter Lauf aendert nichts' {
    $o = Neuer-Ordner 'd1'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $vorher = Get-Content $h -Raw -Encoding utf8
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    if ((Get-Content $h -Raw -Encoding utf8) -ne $vorher) { return 'Heft hat sich veraendert' }
}

Pruefe 'D2 Prosa und Statuswerte bleiben erhalten' {
    $o = Neuer-Ordner 'd2'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = Get-Content $h -Raw -Encoding utf8
    $t = $t -replace 'ZU SCHREIBEN\*\* — was gefordert war und warum, ohne Fachbegriffe\.', 'Eigene Prosa steht hier.'
    $t = $t -replace '\| /LZ10/ \| (.*?) \| offen \|', '| /LZ10/ | $1 | abgenommen |'
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code)" }
    $neu = Get-Content $h -Raw -Encoding utf8
    if ($neu -notmatch 'Eigene Prosa steht hier') { return 'Prosa verloren' }
    if ($neu -notmatch '/LZ10/.*abgenommen')      { return 'Status verloren' }
}

Pruefe 'D3 Neue Anforderung wird als offen ergaenzt' {
    $o = Neuer-Ordner 'd3'; Werkzeuge-Nach $o
    $md = Join-Path $o 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $c = (Get-Content $md -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LZ15/ | Nachtraeglich ergaenzt. | V1.0 | Muss | T-01 |`n"
    [System.IO.File]::WriteAllText($md, $c, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code)" }
    $h = Get-Content (Join-Path $o 'abnahme\Pruefling_V1.0.md') -Raw -Encoding utf8
    if ($h -notmatch '/LZ15/.*offen') { return 'Neue Anforderung fehlt oder hat falschen Status' }
}

Pruefe 'D4 Kennung in der falschen Version wird erkannt' {
    $o = Neuer-Ordner 'd4'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = (Get-Content $h -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LZ20/ | Gehoert zu V1.1. | offen |  |`n"
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'V1\.1') { return 'Meldung nennt die richtige Version nicht' }
}

Pruefe 'D5 Ein fehlerhaftes Heft blockiert die uebrigen nicht' {
    $o = Neuer-Ordner 'd5'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = (Get-Content $h -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LYY9/ | Erfunden. | offen |  |`n"
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Ausgabe -notmatch 'V1\.1 : erzeugt') { return 'Die intakte Version wurde nicht erzeugt' }
    if ($r.Code -ne 1) { return "Erwarteter Rueckgabewert 1, war $($r.Code)" }
}

Write-Host ''
Write-Host '  --- Nachfrage beim Doppelklick ---'

Pruefe 'E1 Kein Dokument: eingegebener Pfad wird verwendet' {
    $o = Neuer-Ordner 'e1'; Werkzeuge-Nach $o
    $f = Neuer-Ordner 'e1-fremd'
    $md = Join-Path $f 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() $md
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $f 'Pflichtenheft-Pruefling.html'))) { return 'HTML fehlt' }
}

Pruefe 'E2 Kein Dokument: Pfad in Anfuehrungszeichen wird angenommen' {
    $o = Neuer-Ordner 'e2'; Werkzeuge-Nach $o
    $f = Neuer-Ordner 'e2-fremd'
    $md = Join-Path $f 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() ('"' + $md + '"')
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $f 'Pflichtenheft-Pruefling.html'))) { return 'HTML fehlt' }
}

Pruefe 'E3 Kein Dokument: leere Eingabe bricht sauber ab' {
    $o = Neuer-Ordner 'e3'; Werkzeuge-Nach $o
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() ''
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Abgebrochen') { return 'Meldung nennt den Abbruch nicht' }
    if ($r.Ausgabe -match 'Exception:|null-valued') { return 'Stapelauszug statt verstaendlicher Meldung' }
}

Pruefe 'E4 Kein Dokument: falscher Pfad wird benannt' {
    $o = Neuer-Ordner 'e4'; Werkzeuge-Nach $o
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() 'X:\gibt\es\nicht.md'
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'gibt es nicht') { return 'Meldung nennt die Datei nicht' }
    if ($r.Ausgabe -match 'Exception:|null-valued') { return 'Stapelauszug statt verstaendlicher Meldung' }
}

Pruefe 'E5 Mehrere Dokumente: Auswahl per Nummer' {
    $o = Neuer-Ordner 'e5'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Eins.md')
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Zwei.md')
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() '2'
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $o 'Pflichtenheft-Zwei.html'))) { return 'Das gewaehlte Dokument wurde nicht erzeugt' }
    if (Test-Path (Join-Path $o 'Pflichtenheft-Eins.html'))       { return 'Das andere Dokument wurde faelschlich erzeugt' }
}

Pruefe 'E6 Mehrere Dokumente: ungueltige Auswahl wird abgewiesen' {
    $o = Neuer-Ordner 'e6'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Eins.md')
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Zwei.md')
    $r = Starte-MitEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() '9'
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'Ungueltige Auswahl') { return 'Meldung nennt die Ursache nicht' }
    if ($r.Ausgabe -match 'Exception:|null-valued') { return 'Stapelauszug statt verstaendlicher Meldung' }
}

Pruefe 'E7 Hefte: eingegebener Pfad wird verwendet' {
    $o = Neuer-Ordner 'e7'; Werkzeuge-Nach $o
    $f = Neuer-Ordner 'e7-fremd'
    $md = Join-Path $f 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    $r = Starte-MitEingabe (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() $md
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if (-not (Test-Path (Join-Path $f 'abnahme\Pruefling_V1.0.md'))) { return 'Heft fehlt' }
}

Pruefe 'E8 Geschlossene Eingabe bricht sauber ab, ohne Ausnahme' {
    $o = Neuer-Ordner 'e8'; Werkzeuge-Nach $o
    $r = Starte-OhneEingabe (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -match 'null-valued|Ausnahme|Exception') { return 'Unverstaendliche Ausnahme statt Abbruchmeldung' }
    if ($r.Ausgabe -notmatch 'Abgebrochen') { return 'Meldung nennt den Abbruch nicht' }
    if ($r.Ausgabe -match 'Exception:|null-valued') { return 'Stapelauszug statt verstaendlicher Meldung' }
}

Pruefe 'E9 Hefte: geschlossene Eingabe bricht sauber ab' {
    $o = Neuer-Ordner 'e9'; Werkzeuge-Nach $o
    $r = Starte-OhneEingabe (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -match 'null-valued') { return 'Unverstaendliche Ausnahme statt Abbruchmeldung' }
    if ($r.Ausgabe -notmatch 'Abgebrochen') { return 'Meldung nennt den Abbruch nicht' }
    if ($r.Ausgabe -match 'Exception:|null-valued') { return 'Stapelauszug statt verstaendlicher Meldung' }
}

Pruefe 'C10 Ohne Logo bleibt der Kopf sauber' {
    $o = Neuer-Ordner 'c10'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -match '\{\{LOGO\}\}') { return 'Platzhalter nicht ersetzt' }
    if ($h -match '<img class="marke"') { return 'Bild ohne Logodatei eingefuegt' }
}

Pruefe 'C11 Logo wird eingebettet, nicht verknuepft' {
    $o = Neuer-Ordner 'c11'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    # Kleinstes gueltiges PNG als Logodatei
    $png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
    [IO.File]::WriteAllBytes((Join-Path $o 'Firma_Logo.png'), $png)
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -notmatch '<img class="marke" src="data:image/png;base64,') { return 'Logo nicht eingebettet' }
    if ($h -match 'src="[^"]*Firma_Logo\.png"') { return 'Logo nur verknuepft statt eingebettet' }
}

Pruefe 'C12 Logo beim Dokument sticht das beim Werkzeug' {
    $o = Neuer-Ordner 'c12'; Werkzeuge-Nach $o
    $d = Join-Path $o 'docs'; New-Item -ItemType Directory -Path $d -Force | Out-Null
    Neues-Pflichtenheft -Pfad (Join-Path $d 'Pflichtenheft-Pruefling.md')
    $png = [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
    [IO.File]::WriteAllBytes((Join-Path $o 'Werkzeug_Logo.png'), $png)
    [IO.File]::WriteAllBytes((Join-Path $d 'Projekt_Logo.png'), $png)
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code)" }
    $h = Get-Content (Join-Path $d 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -notmatch '<img class="marke"') { return 'Kein Logo eingebettet' }
}

Pruefe 'C13 Kennungen im Heft verlinken auf die Stelle im Pflichtenheft' {
    $o = Neuer-Ordner 'c13'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    $ph   = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    $heft = Get-Content (Join-Path $o 'abnahme\Pruefling_V1.0.html') -Raw -Encoding utf8
    if ($ph -notmatch '<td class="id" id="LZ10">/LZ10/</td>')   { return 'Anker im Pflichtenheft fehlt' }
    if (([regex]::Matches($ph, 'id="LZ10"')).Count -ne 1)       { return 'Anker nicht eindeutig (Testfall-Spalte doppelt verankert)' }
    if ($heft -notmatch 'href="\.\./Pflichtenheft-Pruefling\.html#LZ10"') { return 'Link im Heft fehlt oder zeigt falsch' }
    if ($heft -notmatch 'href="[^"]+#LZ10" target="_blank"')   { return 'Link oeffnet keinen neuen Tab' }
    if ($heft -match 'id="LZ10"')                              { return 'Heft vergibt eigene Anker' }
}

Pruefe 'C9 Vorspann: Kopfangabe wird uebersprungen, Auszeichnung gerendert' {
    $o = Neuer-Ordner 'c9'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    $m = [regex]::Match($h, '(?s)kopf__lead">(.*?)</p>')
    if (-not $m.Success) { return 'Kein Vorspann im Kopf' }
    $lead = $m.Groups[1].Value
    if ($lead -match 'Stand:')  { return 'Kopfangabe wurde als Vorspann genommen' }
    if ($lead -match '\*\*')    { return 'Sternchen stehen sichtbar im Vorspann' }
    if ($lead -notmatch '<strong>Selbsttest</strong>') { return 'Fettschrift im Vorspann nicht gerendert' }
    if ($lead -notmatch 'Umlauten') { return 'Falscher Vorspann' }
}

Pruefe 'C7 Offene Punkte werden als Punkte gezaehlt, nicht als Nennungen' {
    $o = Neuer-Ordner 'c7'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -MitOffenenPunkten
    $r = Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @()
    if ($r.Ausgabe -notmatch 'Offene Punkte :\s+2\b') { return "Erwartet 2 Punkte: $($r.Ausgabe)" }
    if ($r.Ausgabe -notmatch '4 Nennungen') { return 'Nennungszahl wird nicht ausgewiesen' }
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -notmatch '(?s)kachel__wert">2</div>\s*<div class="kachel__text">offene Punkte') { return 'Kachel zeigt die falsche Zahl' }
}

Pruefe 'C8 Spalte Version im Aenderungsverzeichnis verfaelscht den Kopf nicht' {
    $o = Neuer-Ordner 'c8'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md') -MitAenderungsverzeichnis
    Starte (Join-Path $o 'Pflichtenheft-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'Pflichtenheft-Pruefling.html') -Raw -Encoding utf8
    if ($h -match 'Falschwert') {
        if ($h -match 'fuss__zeile[\s\S]{0,200}Falschwert') { return 'Fusszeile zeigt die falsche Version' }
    }
    if ($h -notmatch 'Version 1\.0') { return 'Richtige Dokumentversion fehlt in der Fusszeile' }
}

Write-Host ''
Write-Host '  --- Abgenommenes bleibt unangetastet ---'

Pruefe 'G1 Abgenommene Version darf nicht wachsen' {
    $o = Neuer-Ordner 'g1'; Werkzeuge-Nach $o
    $md = Join-Path $o 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null

    # V1.0 abnehmen
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = (Get-Content $h -Raw -Encoding utf8) -replace '\| /LZ10/ \| (.*?) \| offen \|', '| /LZ10/ | $1 | abgenommen |'
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $vorher = Get-Content $h -Raw -Encoding utf8

    # Nachtraeglich eine Anforderung in die abgenommene Version einschleusen
    $c = (Get-Content $md -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LZ99/ | Nachtraeglich eingeschleust. | V1.0 | Muss | T-01 |`n"
    [System.IO.File]::WriteAllText($md, $c, [System.Text.UTF8Encoding]::new($false))

    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -eq 0) { return 'Kein Fehler gemeldet' }
    if ($r.Ausgabe -notmatch 'LZ99')                { return 'Meldung nennt die neue Kennung nicht' }
    if ($r.Ausgabe -notmatch 'bereits abgenommen')  { return 'Meldung nennt die Ursache nicht' }
    if ($r.Ausgabe -notmatch 'spaeteren Version')   { return 'Meldung nennt die Auswege nicht' }
    if ((Get-Content $h -Raw -Encoding utf8) -ne $vorher) { return 'Heft wurde trotz Abbruch veraendert' }
}

Pruefe 'G2 Mit ausdruecklichem Schalter ist die Erweiterung moeglich' {
    $o = Neuer-Ordner 'g2'; Werkzeuge-Nach $o
    $md = Join-Path $o 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'
    $t = (Get-Content $h -Raw -Encoding utf8) -replace '\| /LZ10/ \| (.*?) \| offen \|', '| /LZ10/ | $1 | abgenommen |'
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    $c = (Get-Content $md -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LZ99/ | Bewusst ergaenzt. | V1.0 | Muss | T-01 |`n"
    [System.IO.File]::WriteAllText($md, $c, [System.Text.UTF8Encoding]::new($false))

    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @('-AbgenommenErweitern')
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    $neu = Get-Content $h -Raw -Encoding utf8
    if ($neu -notmatch '/LZ99/.*offen')      { return 'Neue Anforderung fehlt' }
    if ($neu -notmatch '/LZ10/.*abgenommen') { return 'Bestehender Status verloren' }
}

Pruefe 'G3 Ohne Abnahme wachsen Versionen wie bisher' {
    $o = Neuer-Ordner 'g3'; Werkzeuge-Nach $o
    $md = Join-Path $o 'Pflichtenheft-Pruefling.md'
    Neues-Pflichtenheft -Pfad $md
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $c = (Get-Content $md -Raw -Encoding utf8) -replace '(\| /LZ10/ [^\r\n]*\r?\n)', "`$1| /LZ98/ | Ganz normal ergaenzt. | V1.0 | Muss | T-01 |`n"
    [System.IO.File]::WriteAllText($md, $c, [System.Text.UTF8Encoding]::new($false))
    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    if ((Get-Content (Join-Path $o 'abnahme\Pruefling_V1.0.md') -Raw -Encoding utf8) -notmatch '/LZ98/') { return 'Ergaenzung fehlt' }
}

Write-Host ''
Write-Host '  --- Nachruesten aelterer Hefte ---'

Pruefe 'F1 Heft ohne Lesehilfe wird nachgetragen, Prosa bleibt' {
    $o = Neuer-Ordner 'f1'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Join-Path $o 'abnahme\Pruefling_V1.0.md'

    # Zustand eines Hefts aus einem aelteren Lauf herstellen
    $t = Get-Content $h -Raw -Encoding utf8
    $t = [regex]::Replace($t, '(?s)\#\# Lesehilfe.*?(?=\#\# Worum es geht)', '')
    $t = $t -replace 'ZU SCHREIBEN\*\* — was gefordert war und warum, ohne Fachbegriffe\.', 'Eigene Prosa aus dem alten Lauf.'
    $t = $t -replace '\| /LZ10/ \| (.*?) \| offen \|', '| /LZ10/ | $1 | fertig |'
    [System.IO.File]::WriteAllText($h, $t, [System.Text.UTF8Encoding]::new($false))
    if ((Get-Content $h -Raw -Encoding utf8) -match 'Lesehilfe') { return 'Vorbereitung misslungen' }

    $r = Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @()
    if ($r.Code -ne 0) { return "Rueckgabewert $($r.Code): $($r.Ausgabe)" }
    $neu = Get-Content $h -Raw -Encoding utf8
    if ($neu -notmatch '(?m)^\#\# Lesehilfe\s*$')       { return 'Lesehilfe nicht nachgetragen' }
    if ($neu -notmatch 'Noch nicht begonnen')            { return 'Statuslegende fehlt' }
    if ($neu -notmatch 'Eigene Prosa aus dem alten Lauf'){ return 'Prosa verloren' }
    if ($neu -notmatch '/LZ10/.*fertig')                 { return 'Status verloren' }
    if ($r.Ausgabe -notmatch 'Lesehilfe nachgetragen')   { return 'Nachtrag wird nicht gemeldet' }
}

Pruefe 'F2 Lesehilfe wird kein zweites Mal eingefuegt' {
    $o = Neuer-Ordner 'f2'; Werkzeuge-Nach $o
    Neues-Pflichtenheft -Pfad (Join-Path $o 'Pflichtenheft-Pruefling.md')
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    Starte (Join-Path $o 'Abnahmehefte-aktualisieren.ps1') @() | Out-Null
    $h = Get-Content (Join-Path $o 'abnahme\Pruefling_V1.0.md') -Raw -Encoding utf8
    $n = ([regex]::Matches($h, '(?m)^\#\# Lesehilfe\s*$')).Count
    if ($n -ne 1) { return "Lesehilfe $n mal vorhanden" }
}

# ── Bilanz ──────────────────────────────────────────────────────────────────
$ok      = @($script:Ergebnisse | Where-Object { $_.Ergebnis -eq 'ok' }).Count
$fehler  = @($script:Ergebnisse | Where-Object { $_.Ergebnis -ne 'ok' })

Write-Host ''
Write-Host ('  ' + ('=' * 58))
if ($fehler.Count -eq 0) {
    Write-Host "  Alle $ok Pruefungen bestanden. Das Toolkit ist einsatzbereit." -ForegroundColor Green
} else {
    Write-Host "  $ok bestanden, $($fehler.Count) fehlgeschlagen:" -ForegroundColor Red
    foreach ($f in $fehler) { Write-Host "    - $($f.Fall): $($f.Grund)" -ForegroundColor Red }
}
Write-Host ('  ' + ('=' * 58))
Write-Host ''

if ($Behalten) { Write-Host "  Testordner bleibt: $Basis"; }
else { Remove-Item $Basis -Recurse -Force -ErrorAction SilentlyContinue }

exit $fehler.Count
