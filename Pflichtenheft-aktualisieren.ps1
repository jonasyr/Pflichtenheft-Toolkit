<#
.SYNOPSIS
Erzeugt die HTML-Lesefassung eines Pflichtenhefts aus der Markdown-Quelle.

.DESCRIPTION
Wird ueber Pflichtenheft-aktualisieren.cmd per Doppelklick aufgerufen.
Keine Installation noetig: ConvertFrom-Markdown ist seit PowerShell 6 eingebaut.

Die Markdown-Datei ist die Quelle. Die Kennzahlen im Kopf werden aus ihr
gezaehlt, nicht gepflegt - damit koennen Zahl und Inhalt nicht auseinanderlaufen.
#>
[CmdletBinding()]
param(
    [string] $MarkdownPfad,
    [string] $AusgabePfad,
    [switch] $NichtOeffnen,

    # Heft-Modus: rendert ein Abnahmeheft statt des Pflichtenhefts. Die Kacheln
    # zaehlen dann Statuswerte statt Prioritaeten.
    [switch] $HeftModus,

    # Heft-Modus: HTML-Fassung des zugehoerigen Pflichtenhefts. Ist sie angegeben,
    # werden die Kennungen der Anforderungstabelle zu Links, die das Pflichtenheft
    # in einem neuen Tab an genau dieser Anforderung oeffnen.
    [string] $PflichtenheftHtml,

    # Wird von der .cmd gesetzt: bei Problemen darf nachgefragt werden statt
    # abzubrechen. Ohne diesen Schalter laeuft alles ohne Rueckfrage durch -
    # noetig fuer den Selbsttest und fuer Aufrufe im Stapel.
    [switch] $Interaktiv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Eigene Laufzeit pruefen, falls direkt gestartet ─────────────────────────
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host ''
    Write-Host '  PowerShell 7 wird benoetigt - gefunden: Version ' -NoNewline
    Write-Host $PSVersionTable.PSVersion.Major
    Write-Host ''
    Write-Host '  Dieses Skript erzeugt die HTML mit "ConvertFrom-Markdown".'
    Write-Host '  Diesen Befehl gibt es erst ab PowerShell 7.'
    Write-Host ''
    Write-Host '    A. winget install --id Microsoft.PowerShell --source winget'
    Write-Host '    B. https://aka.ms/powershell'
    Write-Host ''
    Write-Host '  WICHTIG: Danach das Fenster schliessen und neu starten.'
    Write-Host ''
    exit 1
}

# ── Quelle finden ───────────────────────────────────────────────────────────
# Das Skript darf irgendwo liegen: im Wurzelverzeichnis, in docs, in einem
# Werkzeugordner. Gesucht wird darum abwaerts vom eigenen Ordner und, falls
# dort nichts liegt, eine Ebene darueber.
# Ein Logo neben dem Dokument oder beim Werkzeug wird in die HTML eingebettet.
# Eingebettet und nicht verknuepft, damit die Datei auch dann vollstaendig ist,
# wenn jemand nur sie weitergibt.
function Find-Logo([string[]] $ordner) {
    foreach ($o in $ordner) {
        if (-not $o -or -not (Test-Path $o)) { continue }
        $f = @(Get-ChildItem -Path $o -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -match '(?i)logo' -and $_.Extension -match '(?i)^\.(png|jpe?g|svg)$' } |
               Sort-Object Name)
        if ($f.Count) { return $f[0].FullName }
    }
    return ''
}

function Get-LogoHtml([string] $pfad) {
    if (-not $pfad) { return '' }
    try {
        $mime = switch ([IO.Path]::GetExtension($pfad).ToLowerInvariant()) {
            '.png'  { 'image/png' }
            '.svg'  { 'image/svg+xml' }
            '.jpg'  { 'image/jpeg' }
            '.jpeg' { 'image/jpeg' }
            default { 'image/png' }
        }
        $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfad))
        return "<img class=""marke"" src=""data:$mime;base64,$b64"" alt="""" />"
    } catch {
        Write-Warning "Logo konnte nicht eingebettet werden: $($_.Exception.Message)"
        return ''
    }
}

# Read-Host liefert $null, wenn die Eingabe geschlossen ist - etwa bei
# "< nul" oder in einem Stapellauf. Ohne diese Huelle scheitert .Trim() dort
# mit einer unverstaendlichen Meldung statt mit einem sauberen Abbruch.
function Lies-Zeile([string] $frage) {
    $w = Read-Host $frage
    if ($null -eq $w) { return '' }
    return $w.Trim().Trim('"')
}

# Erwartete Abbrueche - etwa eine leere Eingabe - sind kein Programmfehler.
# "throw" wuerde dafuer einen Stapelauszug zeigen, den niemand lesen will.
function Beenden-Mit([string] $meldung) {
    Write-Host ''
    Write-Host "  $meldung" -ForegroundColor Yellow
    Write-Host ''
    exit 1
}

function Find-Pflichtenhefte([string] $wurzel, [int] $tiefe) {
    $ausschluss = @('node_modules', '.git', 'bin', 'obj', '.vs', 'packages', 'dist', 'build', 'abnahme')
    return @(Get-ChildItem -Path $wurzel -Filter 'Pflichtenheft*.md' -File -Recurse -Depth $tiefe -ErrorAction SilentlyContinue |
             Where-Object {
                 $_.Name -notlike 'Prompt*' -and
                 @($_.FullName -split '[\\/]' | Where-Object { $ausschluss -contains $_ }).Count -eq 0
             } | Sort-Object FullName)
}

if (-not $MarkdownPfad) {
    # @() am Aufrufort: PowerShell loest eine leere Liste beim Zurueckgeben
    # zu $null auf, und $null hat unter StrictMode keine Eigenschaft Count.
    $kandidaten = @(Find-Pflichtenhefte $PSScriptRoot 3)
    if ($kandidaten.Count -eq 0 -and (Split-Path $PSScriptRoot -Parent)) {
        $kandidaten = @(Find-Pflichtenhefte (Split-Path $PSScriptRoot -Parent) 2)
    }
    if ($kandidaten.Count -eq 0) {
        $hinweis = @"
Keine Datei 'Pflichtenheft*.md' gefunden.
Gesucht wurde in '$PSScriptRoot' und darunter sowie eine Ebene darueber.
Abhilfe: die Markdown-Datei auf die .cmd-Datei ziehen, oder aufrufen mit
  -MarkdownPfad "C:\Pfad\zum\Pflichtenheft-Produkt.md"
"@
        if (-not $Interaktiv) { throw $hinweis }
        Write-Host ''
        Write-Host '  Keine Datei "Pflichtenheft*.md" gefunden.' -ForegroundColor Yellow
        Write-Host "  Gesucht in '$PSScriptRoot' und darunter sowie eine Ebene darueber."
        Write-Host ''
        Write-Host '  Sie koennen den Pfad jetzt eingeben - oder die Datei mit der Maus'
        Write-Host '  in dieses Fenster ziehen; der Pfad erscheint dann von selbst.'
        Write-Host ''
        $eingabe = Lies-Zeile '  Pfad zur Markdown-Datei (leer = abbrechen)'
        if (-not $eingabe) { Beenden-Mit 'Abgebrochen: kein Pfad angegeben.' }
        if (-not (Test-Path $eingabe)) { Beenden-Mit "Diese Datei gibt es nicht: $eingabe" }
        $MarkdownPfad = $eingabe
    }
    elseif ($kandidaten.Count -gt 1) {
        $liste = ($kandidaten | ForEach-Object { "  - $($_.FullName)" }) -join "`n"
        if (-not $Interaktiv) {
            throw "Mehrere Pflichtenhefte gefunden - es wurde nichts erzeugt:`n$liste`nBitte das gewuenschte auf die .cmd-Datei ziehen oder mit -MarkdownPfad angeben."
        }
        Write-Host ''
        Write-Host '  Mehrere Pflichtenhefte gefunden:' -ForegroundColor Yellow
        for ($n = 0; $n -lt $kandidaten.Count; $n++) { Write-Host ("    [{0}] {1}" -f ($n + 1), $kandidaten[$n].FullName) }
        Write-Host ''
        $wahl = Lies-Zeile "  Welches soll erzeugt werden? (1-$($kandidaten.Count), leer = abbrechen)"
        if (-not $wahl) { Beenden-Mit 'Abgebrochen: keine Auswahl getroffen.' }
        $nr = 0
        if (-not [int]::TryParse($wahl, [ref]$nr) -or $nr -lt 1 -or $nr -gt $kandidaten.Count) {
            Beenden-Mit "Ungueltige Auswahl: '$wahl'. Erlaubt ist 1 bis $($kandidaten.Count)."
        }
        $MarkdownPfad = $kandidaten[$nr - 1].FullName
    }
    else { $MarkdownPfad = $kandidaten[0].FullName }
}
if (-not (Test-Path $MarkdownPfad)) { throw "Markdown-Datei nicht gefunden: $MarkdownPfad" }
$MarkdownPfad = (Resolve-Path $MarkdownPfad).Path
if (-not $AusgabePfad) { $AusgabePfad = [IO.Path]::ChangeExtension($MarkdownPfad, '.html') }

$markdown = Get-Content -LiteralPath $MarkdownPfad -Raw -Encoding utf8
$zeilen   = $markdown -split "`r?`n"

# ── Kopfangaben herausloesen ────────────────────────────────────────────────
$titel = 'Pflichtenheft'
foreach ($z in $zeilen) { if ($z -match '^\#\s+(.+?)\s*$') { $titel = $Matches[1]; break } }

# Vorspann: erster echter Satz nach der H1. Uebersprungen werden Ueberschriften,
# Tabellen, Trennlinien, Zitate - und durchgehend fett gesetzte Zeilen wie
# "**Stand: 09.09.2026 - Rev. 1**". Solche Zeilen sind Kopfangaben, kein
# Vorspann; stuenden sie im Kopf, faende sich dort eine Datumszeile statt einer
# Beschreibung.
$lead = ''
$nachH1 = $false
foreach ($z in $zeilen) {
    if (-not $nachH1) { if ($z -match '^\#\s+') { $nachH1 = $true }; continue }
    $t = $z.Trim()
    if ($t -eq '' -or $t -like '#*' -or $t -like '|*' -or $t -like '>*' -or $t -eq '---') { continue }
    if ($t -match '^\*\*[^*]+\*\*$') { continue }
    $lead = $t; break
}

# Nur die Kopfdatentabelle auswerten, also alles vor dem ersten Kapitel.
# Sonst wuerde eine Spalte "Version" in einer spaeteren Tabelle - etwa im
# Aenderungsverzeichnis - als Dokumentversion gelesen und den Kopf verfaelschen.
$stand   = ''
$version = ''
foreach ($z in $zeilen) {
    if ($z -match '^\s*---\s*$' -or $z -match '^\#\#\s') { break }
    if (-not $stand   -and $z -match '^\|\s*Stand\s*\|\s*(.+?)\s*\|')   { $stand   = $Matches[1] }
    if (-not $version -and $z -match '^\|\s*Version\s*\|\s*(.+?)\s*\|') { $version = $Matches[1] }
}
if (-not $stand) { $stand = (Get-Date).ToString('dd.MM.yyyy') }

# ── Zaehlen: Spalten ueber die Kopfzeile finden, nicht ueber feste Position ──

# Tabellenzeile in Zellen zerlegen. Ein maskiertes "\|" gehoert zum Text und
# darf nicht trennen - sonst verrutschen alle Spalten dahinter.
function Split-Zellen([string] $zeile) {
    return ($zeile.Trim().Trim('|') -split '(?<!\\)\|') |
           ForEach-Object { $_.Trim() -replace '\\\|', '|' }
}

$StatusWerte = @('offen', 'geplant', 'in Arbeit', 'fertig', 'abgenommen')
$prioZahlen = [ordered]@{ Muss = 0; Soll = 0; Kann = 0; 'ohne' = 0 }
$statusZahlen = [ordered]@{}
foreach ($s in $StatusWerte) { $statusZahlen[$s] = 0 }
$anforderungen = [System.Collections.Generic.List[object]]::new()
$testfaelle    = [System.Collections.Generic.List[string]]::new()
$idxPrio = -1; $idxNachweis = -1; $idxStatus = -1

for ($i = 0; $i -lt $zeilen.Count; $i++) {
    $z = $zeilen[$i]
    if ($z -notmatch '^\s*\|') { $idxPrio = -1; $idxNachweis = -1; $idxStatus = -1; continue }

    # Kopfzeile erkennen: die naechste Zeile ist die Trennzeile
    if ($i + 1 -lt $zeilen.Count -and $zeilen[$i + 1] -match '^\s*\|[\s:\-\|]+$') {
        $kopf = Split-Zellen $z
        $idxPrio     = [Array]::IndexOf($kopf, 'Prio')
        $idxNachweis = [Array]::IndexOf($kopf, 'Nachweis')
        $idxStatus   = [Array]::IndexOf($kopf, 'Status')
        continue
    }
    if ($z -match '^\s*\|[\s:\-\|]+$') { continue }

    $sp = Split-Zellen $z

    if ($sp[0] -match '^/L[A-Z]{1,2}\d+(?:\.\d+)?/$') {
        $prio = if ($idxPrio -ge 0 -and $idxPrio -lt $sp.Count) { $sp[$idxPrio] } else { '' }
        $nw   = if ($idxNachweis -ge 0 -and $idxNachweis -lt $sp.Count) { $sp[$idxNachweis] } else { '' }
        $st = if ($idxStatus -ge 0 -and $idxStatus -lt $sp.Count) { $sp[$idxStatus] -replace '\*', '' } else { '' }
        if ($prio -in @('Muss','Soll','Kann')) { $prioZahlen[$prio]++ } else { $prioZahlen['ohne']++ }
        if ($statusZahlen.Contains($st)) { $statusZahlen[$st]++ }
        $anforderungen.Add([pscustomobject]@{ Id = $sp[0]; Prio = $prio; Nachweis = $nw; Status = $st; HatPrioSpalte = ($idxPrio -ge 0) })
    }
    elseif ($sp[0] -match '^T-\d+$') { $testfaelle.Add($sp[0]) }
}

$anzahlAnf   = $anforderungen.Count
# @() ist noetig: PowerShell loest eine leere Pipeline zu $null auf, und unter
# StrictMode hat $null keine Eigenschaft Count.
$anzahlTests = @($testfaelle | Sort-Object -Unique).Count
# Offene Punkte stehen vorschriftsgemaess zweimal: an ihrer Stelle und im
# Kapitel Risiken. Gezaehlt werden deshalb die Punkte, nicht die Nennungen -
# unterschieden an der Frage, die auf "ZU KLAEREN" folgt.
$offeneSchluessel = [System.Collections.Generic.HashSet[string]]::new()
$nennungen = 0
foreach ($z in $zeilen) {
    if ($z -notmatch 'ZU KL[ÄA]REN') { continue }
    $nennungen++
    if ($z -match 'ZU KL[ÄA]REN\**\s*[—–-]\s*(.+?)\s*[—–-]\s*Entscheidung') { $schluessel = $Matches[1] }
    else { $schluessel = $z }
    $schluessel = ($schluessel -replace '[>*`_|]', '' -replace '\s+', ' ').Trim().ToLowerInvariant()
    if ($schluessel) { [void]$offeneSchluessel.Add($schluessel) }
}
$anzahlOffen = $offeneSchluessel.Count

# ── Riegel: Rueckverfolgbarkeit pruefen ─────────────────────────────────────
$warnungen = [System.Collections.Generic.List[string]]::new()

if ($HeftModus) {
    # Im Heft zaehlt der Status, nicht die Prioritaet.
    $falscherStatus = @($anforderungen | Where-Object { $_.Status -and $_.Status -notin $StatusWerte })
    foreach ($a in $falscherStatus) { $warnungen.Add("$($a.Id): Status '$($a.Status)' ist nicht erlaubt. Erlaubt: $($StatusWerte -join ', ')") }
    $ohneStatus = @($anforderungen | Where-Object { -not $_.Status })
    foreach ($a in $ohneStatus) { $warnungen.Add("$($a.Id): kein Status eingetragen.") }
}
else {
    $ohneNachweis = @($anforderungen | Where-Object { $_.Prio -eq 'Muss' -and -not $_.Nachweis })
    foreach ($a in $ohneNachweis) { $warnungen.Add("Muss-Anforderung ohne Nachweis: $($a.Id)") }

    # Eine Tabelle mit Prio-Spalte, deren Wert nicht Muss/Soll/Kann ist, deutet fast
    # immer auf eine verrutschte Spalte hin - etwa durch ein "|" im Text.
    $falschePrio = @($anforderungen | Where-Object { $_.HatPrioSpalte -and $_.Prio -notin @('Muss','Soll','Kann') })
    foreach ($a in $falschePrio) { $warnungen.Add("$($a.Id): Prioritaet nicht erkannt ('$($a.Prio)') - Spalte verrutscht?") }
}

$bekannteTests = @($testfaelle | Sort-Object -Unique)
foreach ($a in $anforderungen) {
    foreach ($t in [regex]::Matches($a.Nachweis, 'T-\d+')) {
        if ($bekannteTests -notcontains $t.Value) {
            $warnungen.Add("$($a.Id) verweist auf nicht vorhandenen Testfall $($t.Value)")
        }
    }
}
$doppelt = @($anforderungen | Group-Object Id | Where-Object { $_.Count -gt 1 })
foreach ($d in $doppelt) { $warnungen.Add("Kennung mehrfach vergeben: $($d.Name)") }

$mitNachweis = @($anforderungen | Where-Object { $_.Prio -eq 'Muss' -and $_.Nachweis }).Count
$anzahlMuss  = $prioZahlen['Muss']
$anteilNw    = if ($anzahlMuss) { [Math]::Round(100 * $mitNachweis / $anzahlMuss) } else { 100 }

# ── Kacheln bauen ───────────────────────────────────────────────────────────
function New-Kachel([string]$wert, [string]$text, [int]$anteil = -1) {
    $sb = "      <div class=`"kachel`">`n"
    $sb += "        <div class=`"kachel__wert`">$wert</div>`n"
    $sb += "        <div class=`"kachel__text`">$text</div>`n"
    if ($anteil -ge 0) { $sb += "        <div class=`"balken`"><i style=`"width:$anteil%`"></i></div>`n" }
    $sb += "      </div>`n"
    return $sb
}
$erledigt = $statusZahlen['fertig'] + $statusZahlen['abgenommen']
$anteilFertig = if ($anzahlAnf) { [Math]::Round(100 * $erledigt / $anzahlAnf) } else { 0 }

$kacheln = "    <div class=`"gesamt`">`n"
if ($HeftModus) {
    $kacheln += New-Kachel "$erledigt / $anzahlAnf" 'Punkte fertig' $anteilFertig
    $kacheln += New-Kachel $statusZahlen['abgenommen'] 'abgenommen'
    $kacheln += New-Kachel ($statusZahlen['in Arbeit'] + $statusZahlen['geplant']) 'in Arbeit oder geplant'
    $kacheln += New-Kachel $statusZahlen['offen'] 'offen'
}
else {
    $kacheln += New-Kachel $anzahlAnf 'Anforderungen' $anteilNw
    $kacheln += New-Kachel $anzahlMuss 'davon Muss'
    $kacheln += New-Kachel $anzahlTests 'Testfaelle'
    $kacheln += New-Kachel $anzahlOffen 'offene Punkte'
}
$kacheln += '    </div>'

# ── Markdown in HTML wandeln ────────────────────────────────────────────────
# Kopfzeile und Vorspann stehen schon im Seitenkopf; im Fliesstext entfielen sie doppelt.
$inhaltMd = ($markdown -replace '(?m)^\#\s+.+?$', '')
if ($lead) { $inhaltMd = $inhaltMd.Replace($lead, '') }

$html = ($inhaltMd | ConvertFrom-Markdown).Html

# 1) Kennungen in der ersten Spalte. Im Pflichtenheft bekommt die erste Nennung
#    jeder Kennung einen Anker (id="LF20.1"); im Heft wird die Kennung zum Link
#    auf diesen Anker. Der Link ist relativ, damit er auch in einer Kopie des
#    Ordners stimmt.
$ankerVergeben = [System.Collections.Generic.HashSet[string]]::new()
$linkZiel = $null
if ($HeftModus -and $PflichtenheftHtml) {
    $heftOrdner = Split-Path -Parent ([IO.Path]::GetFullPath($AusgabePfad))
    $relativ = [IO.Path]::GetRelativePath($heftOrdner, [IO.Path]::GetFullPath($PflichtenheftHtml)) -replace '\\', '/'
    $linkZiel = @($relativ -split '/' | ForEach-Object {
        if ($_ -in @('.', '..')) { $_ } else { [Uri]::EscapeDataString($_) }
    }) -join '/'
}
$html = [regex]::Replace($html, '<td>(/(L[A-Z]{1,2}\d+(?:\.\d+)?)/)</td>', {
    param($m)
    $kennung = $m.Groups[1].Value
    $anker   = $m.Groups[2].Value
    if ($linkZiel) {
        "<td class=`"id`"><a class=`"id-link`" href=`"$linkZiel#$anker`" target=`"_blank`" rel=`"noopener`" title=`"Im Pflichtenheft öffnen`">$kennung</a></td>"
    }
    elseif (-not $HeftModus -and $ankerVergeben.Add($anker)) {
        "<td class=`"id`" id=`"$anker`">$kennung</td>"
    }
    else {
        "<td class=`"id`">$kennung</td>"
    }
})
$html = [regex]::Replace($html, '<td>(T-\d+)</td>', '<td class="id">$1</td>')

# 2) Prioritaeten als Plaketten
foreach ($p in @('Muss', 'Soll', 'Kann')) {
    $html = $html -replace "<td>$p</td>", "<td><span class=`"pr pr--$($p.ToLower())`">$p</span></td>"
}

# 3) Aenderungsarten (Stufe B) als Plaketten
$artKlassen = @{ 'Neu' = 'fertig'; 'Geändert' = 'arbeit'; 'Entfällt' = 'offen'; 'Unverändert' = 'geplant' }
foreach ($a in $artKlassen.Keys) {
    $html = $html -replace "<td>$a</td>", "<td><span class=`"st st--$($artKlassen[$a])`">$a</span></td>"
}

# 3b) Statuswerte als Plaketten (Abnahmehefte)
$statusKlassen = [ordered]@{ 'abgenommen' = 'abgenommen'; 'fertig' = 'fertig'; 'in Arbeit' = 'arbeit'; 'geplant' = 'geplant'; 'offen' = 'offen' }
foreach ($s in $statusKlassen.Keys) {
    $html = $html -replace "<td>(?:<strong>)?$([regex]::Escape($s))(?:</strong>)?</td>",
                           "<td><span class=`"st st--$($statusKlassen[$s])`">$s</span></td>"
}

# 4) Offene Punkte hervorheben
$html = $html -replace '<strong>ZU KL(Ä|A)REN</strong>', '<span class="st st--offen">ZU KLÄREN</span>'

# 5) Absaetze der Form "<strong>Wort:</strong> Text" werden Hinweiskaesten
$html = [regex]::Replace($html, '<p><strong>([^<:]{3,60}):</strong>\s*(.+?)</p>', {
    param($m)
    "<div class=`"kasten`">`n<div class=`"kasten__titel`">$($m.Groups[1].Value)</div>`n<p>$($m.Groups[2].Value)</p>`n</div>"
}, [System.Text.RegularExpressions.RegexOptions]::Singleline)

# 6) Tabellen rollbar einfassen
$html = ($html -replace '<table>', '<div class="tabelle"><table>') -replace '</table>', '</table></div>'

# 7) Abschnitte, damit der Druck sauber umbricht
$html = $html -replace '<hr />', ('</section>' + "`n" + '<section>')
$html = "<section>`n$html`n</section>"

# ── Vorlage ─────────────────────────────────────────────────────────────────
$vorlage = @'
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>{{TITEL}}</title>
<meta name="color-scheme" content="light" />
<link rel="preconnect" href="https://fonts.googleapis.com" />
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600;700&family=IBM+Plex+Sans+Condensed:wght@500;600;700&family=IBM+Plex+Mono:wght@400;500&display=swap" />
<style>
  :root {
    color-scheme: light;
    --karmin: #8D2327;      --karmin-weich: #F7EFEF;
    --grund: #F4F3F3;       --flaeche: #FFFFFF;      --flaeche-still: #FAF9F9;
    --linie: #E3E0E0;       --linie-stark: #CFCACA;
    --tinte: #1B1A1A;       --tinte-leise: #595555;  --tinte-still: #8A8484;
    --gut: #2E6B4C;         --gut-weich: #EAF2ED;
    --offen: #8A6113;       --offen-weich: #F7F0E1;
    --fehler: #8D2327;      --fehler-weich: #F6EAEA;
    --neutral: #4A5568;     --neutral-weich: #EDEFF2;
    --serifenlos: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
    --schmal: "IBM Plex Sans Condensed", "IBM Plex Sans", "Segoe UI", sans-serif;
    --mono: "IBM Plex Mono", ui-monospace, "Cascadia Mono", monospace;
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--grund); color:var(--tinte); font-family:var(--serifenlos); font-size:16px; line-height:1.6; -webkit-font-smoothing:antialiased; }
  .huelle { width: min(1080px, 92vw); margin-inline: auto; }

  .kopf { background:var(--flaeche); border-bottom:3px solid var(--karmin); padding:2.4rem 0 1.8rem; }
  .kopf__zeile { display:flex; flex-wrap:wrap; gap:1rem; align-items:baseline; justify-content:space-between; }
  .kopf h1 { font-family:var(--schmal); font-size:clamp(1.8rem,3.6vw,2.6rem); font-weight:700; margin:0; letter-spacing:-0.015em; text-wrap:balance; }
  .kopf__stand { font-family:var(--mono); font-size:0.82rem; color:var(--tinte-leise); background:var(--karmin-weich); border:1px solid var(--linie); border-radius:999px; padding:0.3rem 0.85rem; white-space:nowrap; }
  .kopf__lead { margin:1rem 0 0; max-width:68ch; color:var(--tinte-leise); }
  .kopf__marke { display:flex; justify-content:flex-end; margin-bottom:1.3rem; }
  .kopf__marke:empty { display:none; }
  .marke { height:32px; width:auto; display:block; }
  @media (max-width:520px) { .marke { height:26px; } }

  .gesamt { margin-top:1.6rem; display:grid; grid-template-columns:repeat(auto-fit,minmax(210px,1fr)); gap:0.9rem; }
  .kachel { background:var(--flaeche-still); border:1px solid var(--linie); border-radius:10px; padding:0.95rem 1.1rem; }
  .kachel__wert { font-family:var(--schmal); font-size:1.9rem; font-weight:700; line-height:1.1; font-variant-numeric:tabular-nums; }
  .kachel__text { font-size:0.86rem; color:var(--tinte-leise); }
  .balken { margin-top:0.55rem; height:6px; border-radius:999px; background:var(--linie); overflow:hidden; }
  .balken > i { display:block; height:100%; background:var(--karmin); border-radius:999px; }

  main { padding:2.4rem 0 4rem; }
  section { margin-bottom:2.8rem; }
  h2 { font-family:var(--schmal); font-size:1.5rem; font-weight:700; margin:2.6rem 0 0.2rem; padding-bottom:0.5rem; border-bottom:2px solid var(--linie-stark); }
  h3 { font-family:var(--schmal); font-size:1.08rem; font-weight:600; margin:1.8rem 0 0.6rem; }
  p { margin:0.7rem 0; max-width:76ch; }
  main ul, main ol { max-width:76ch; padding-left:1.3rem; }
  main li { margin:0.35rem 0; }
  main hr { border:none; border-top:1px solid var(--linie); margin:2.2rem 0; }

  .tabelle, .tabellenhuelle { overflow-x:auto; margin:1rem 0; }
  table { width:100%; border-collapse:collapse; font-size:0.9rem; background:var(--flaeche); display:table; }
  thead th { text-align:left; font-family:var(--schmal); font-weight:600; font-size:0.78rem; text-transform:uppercase; letter-spacing:0.05em; color:var(--tinte-leise); background:var(--flaeche-still); border-bottom:1px solid var(--linie-stark); padding:0.55rem 0.7rem; white-space:nowrap; }
  tbody td { border-bottom:1px solid var(--linie); padding:0.62rem 0.7rem; vertical-align:top; }
  tbody tr:last-child td { border-bottom:none; }
  td.id { font-family:var(--mono); font-size:0.8rem; white-space:nowrap; font-weight:500; color:var(--karmin); }
  td.id a.id-link { color:inherit; text-decoration:none; border-bottom:1px dotted currentColor; }
  td.id a.id-link:hover, td.id a.id-link:focus-visible { border-bottom-style:solid; background:var(--karmin-weich); outline:none; }
  td.id[id] { scroll-margin-top:30vh; }
  tr:has(> td.id:target) > td { background:var(--karmin-weich); }
  tr:has(> td.id:target) > td.id { box-shadow:inset 3px 0 0 var(--karmin); }

  code { font-family:var(--mono); font-size:0.86em; background:var(--flaeche-still); border:1px solid var(--linie); border-radius:4px; padding:0.06em 0.32em; }
  pre { background:var(--flaeche-still); border:1px solid var(--linie); border-left:3px solid var(--linie-stark); border-radius:0 6px 6px 0; padding:0.8rem 1rem; overflow-x:auto; font-family:var(--mono); font-size:0.82rem; line-height:1.55; }
  pre code { background:none; border:none; padding:0; }

  .st, .pr { display:inline-block; font-family:var(--schmal); font-size:0.76rem; font-weight:600; letter-spacing:0.02em; border-radius:999px; padding:0.16rem 0.62rem; white-space:nowrap; border:1px solid transparent; }
  .pr--muss { background:var(--fehler-weich);  color:var(--fehler);  border-color:#E5C9C9; }
  .pr--soll { background:var(--offen-weich);   color:var(--offen);   border-color:#E6D6AE; }
  .pr--kann { background:var(--neutral-weich); color:var(--neutral); border-color:#D3D8E0; }
  .st--fertig  { background:var(--gut-weich);     color:var(--gut);     border-color:#C6DDD0; }
  .st--arbeit  { background:var(--offen-weich);   color:var(--offen);   border-color:#E6D6AE; }
  .st--offen   { background:var(--fehler-weich);  color:var(--fehler);  border-color:#E5C9C9; }
  .st--geplant { background:var(--neutral-weich); color:var(--neutral); border-color:#D3D8E0; }
  .st--abgenommen { background:var(--gut); color:#FFFFFF; border-color:var(--gut); }
  .st--abgenommen::before { content:"\2713\00a0"; }

  .kasten { margin:1.2rem 0; padding:0.95rem 1.15rem; border:1px solid var(--linie); border-left:3px solid var(--linie-stark); border-radius:0 8px 8px 0; background:var(--flaeche); }
  .kasten--wichtig { border-left-color:var(--karmin); background:var(--fehler-weich); }
  .kasten--gut { border-left-color:var(--gut); background:var(--gut-weich); }
  .kasten__titel { font-family:var(--schmal); font-weight:700; font-size:0.82rem; text-transform:uppercase; letter-spacing:0.05em; margin-bottom:0.35rem; color:var(--tinte-leise); }
  .kasten p { margin:0.35rem 0 0; font-size:0.93rem; }
  .kasten p:first-of-type { margin-top:0; }

  main blockquote { margin:1rem 0 1.4rem; padding:0.9rem 1.1rem; background:var(--karmin-weich); border-left:3px solid var(--karmin); border-radius:0 8px 8px 0; }
  main blockquote p { margin:0.3rem 0; font-size:0.95rem; max-width:none; }

  .fuss { border-top:1px solid var(--linie); background:var(--flaeche); padding:1.4rem 0; font-size:0.84rem; color:var(--tinte-still); }
  .fuss__zeile { display:flex; flex-wrap:wrap; gap:0.8rem; justify-content:space-between; }

  @media print {
    body { background:#fff; font-size:11pt; }
    .kopf { border-bottom-width:2px; }
    section { break-inside:avoid; }
    table { font-size:9.5pt; }
    .gesamt { display:none; }
  }
</style>
</head>
<body>

<header class="kopf">
  <div class="huelle">
    <div class="kopf__marke">{{LOGO}}</div>
    <div class="kopf__zeile">
      <h1>{{TITEL}}</h1>
      <span class="kopf__stand">{{STAND}}</span>
    </div>
    <p class="kopf__lead">{{LEAD}}</p>
{{KACHELN}}
  </div>
</header>

<main class="huelle">
{{INHALT}}
</main>

<footer class="fuss">
  <div class="huelle fuss__zeile">
    <span>{{TITEL}} · {{STAND}}</span>
    <span>{{FUSS}}</span>
  </div>
</footer>

</body>
</html>
'@

# Der Vorspann darf Auszeichnungen enthalten - fett, kursiv, Verweise. Als
# reiner Text eingesetzt stuenden die Sternchen sichtbar im Kopf.
$leadHtml = if ($lead) { ((($lead | ConvertFrom-Markdown).Html) -replace '</?p>', '').Trim() } else { '' }

# Zuerst beim Dokument suchen, dann beim Werkzeug: so kann ein einzelnes
# Vorhaben ein eigenes Logo fuehren, ohne das gemeinsame zu ersetzen.
$logoHtml = Get-LogoHtml (Find-Logo @((Split-Path $MarkdownPfad -Parent), $PSScriptRoot))

$fuss = if ($version) { "Version $version · erzeugt aus $(Split-Path $MarkdownPfad -Leaf)" }
        else { "Erzeugt aus $(Split-Path $MarkdownPfad -Leaf)" }

$ergebnis = $vorlage.
    Replace('{{TITEL}}',   [System.Net.WebUtility]::HtmlEncode($titel)).
    Replace('{{STAND}}',   [System.Net.WebUtility]::HtmlEncode($stand)).
    Replace('{{LEAD}}',    $leadHtml).
    Replace('{{LOGO}}',    $logoHtml).
    Replace('{{KACHELN}}', $kacheln).
    Replace('{{INHALT}}',  $html).
    Replace('{{FUSS}}',    [System.Net.WebUtility]::HtmlEncode($fuss))

[System.IO.File]::WriteAllText($AusgabePfad, $ergebnis, [System.Text.UTF8Encoding]::new($false))

# ── Bericht ─────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host ("  {0} wurde aus {1} erzeugt." -f (Split-Path $AusgabePfad -Leaf), (Split-Path $MarkdownPfad -Leaf)) -ForegroundColor Green
Write-Host "  Stand: $stand"
Write-Host ''
if ($HeftModus) {
    Write-Host ("    Punkte        : {0,3}   ({1} fertig oder abgenommen = {2} %)" -f $anzahlAnf, $erledigt, $anteilFertig)
    foreach ($s in $StatusWerte) { Write-Host ("      {0,-12}: {1,3}" -f $s, $statusZahlen[$s]) }
}
else {
    Write-Host ("    Anforderungen : {0,3}   (Muss {1}, Soll {2}, Kann {3}, ohne Prio {4})" -f `
                $anzahlAnf, $prioZahlen['Muss'], $prioZahlen['Soll'], $prioZahlen['Kann'], $prioZahlen['ohne'])
    Write-Host ("    Testfaelle    : {0,3}" -f $anzahlTests)
    $zusatz = if ($nennungen -ne $anzahlOffen) { "   ($nennungen Nennungen)" } else { '' }
    Write-Host ("    Offene Punkte : {0,3}{1}" -f $anzahlOffen, $zusatz)
    Write-Host ("    Muss mit Nachweis: {0} %" -f $anteilNw)
}
Write-Host ''
if ($warnungen.Count -gt 0) {
    Write-Warning "$($warnungen.Count) Abweichung(en) bei der Rueckverfolgbarkeit:"
    foreach ($w in $warnungen) { Write-Host "    - $w" -ForegroundColor Yellow }
    Write-Host ''
} else {
    Write-Host '    Rueckverfolgbarkeit: keine Abweichung.' -ForegroundColor Green
    Write-Host ''
}

if (-not $NichtOeffnen) { Start-Process $AusgabePfad }
