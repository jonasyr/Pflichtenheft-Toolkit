<#
.SYNOPSIS
Erzeugt je Version ein Abnahmeheft aus dem Pflichtenheft und rendert es.

.DESCRIPTION
Wird ueber Abnahmehefte-aktualisieren.cmd per Doppelklick aufgerufen.

Aufgabenteilung, absichtlich so und nicht anders:

  Das Pflichtenheft sagt, WAS gebaut werden soll. Es traegt keinen Status -
  sonst liesse sich spaeter nicht mehr unterscheiden, was vereinbart war,
  von dem, was daraus geworden ist.

  Das Abnahmeheft sagt, WAS DAVON DA IST. Es traegt den Status und richtet
  sich an Leser ohne technische Tiefe.

Dieses Skript ueberbrueckt beides, ohne die Prosa zu erzeugen:

  - Es GERUESTET: fehlende Anforderungszeilen einer Version werden in das
    Heft eingetragen, mit Status "offen".
  - Es BEWAHRT: vorhandene Statuswerte, umformulierte Anforderungstexte und
    saemtliche Prosa bleiben unangetastet.
  - Es VERRIEGELT: nennt ein Heft eine unbekannte Kennung oder eine Kennung
    aus einer anderen Version, bricht dieses Heft ab.

Die Prosa bleibt Handarbeit. Automatisch gekuerzter Fachtext ist kein
Abnahmetext, sondern derselbe Fachtext mit weniger Woertern.
#>
[CmdletBinding()]
param(
    [string] $PflichtenheftPfad,

    # Ohne Angabe: 'abnahme' NEBEN dem Pflichtenheft, nicht neben dem Skript.
    # Die Hefte gehoeren zum Dokument, nicht zum Werkzeug.
    [string] $HeftOrdner,

    [switch] $NichtOeffnen,

    # Erlaubt ausnahmsweise, einer bereits abgenommenen Version Anforderungen
    # hinzuzufuegen. Ohne diesen Schalter wird das abgewiesen - siehe die
    # Begruendung bei der Pruefung weiter unten.
    [switch] $AbgenommenErweitern,

    # Wird von der .cmd gesetzt: bei Problemen darf nachgefragt werden statt
    # abzubrechen. Ohne diesen Schalter laeuft alles ohne Rueckfrage durch.
    [switch] $Interaktiv
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StatusWerte = @('offen', 'geplant', 'in Arbeit', 'fertig', 'abgenommen')

# Feste Lesehilfe. Sie steht in jedem Heft, damit auch jemand mitlesen kann,
# der das Dokument zum ersten Mal sieht. Kein Prosatext, sondern ein
# unveraenderlicher Block - darum darf das Werkzeug ihn schreiben.
$Lesehilfe = @(
    '## Lesehilfe'
    ''
    '| Status | Bedeutung |'
    '|---|---|'
    '| offen | Noch nicht begonnen |'
    '| geplant | Eingeplant, Umsetzung steht bevor |'
    '| in Arbeit | Wird gerade umgesetzt |'
    '| fertig | Umgesetzt und geprüft, Abnahme steht aus |'
    '| abgenommen | Abgenommen |'
    ''
    'Kennungen wie `/LF20.1/` verweisen auf das Pflichtenheft; dort steht die ausführliche Fassung derselben Anforderung.'
    ''
)
$Renderer = Join-Path $PSScriptRoot 'Pflichtenheft-aktualisieren.ps1'
if (-not (Test-Path $Renderer)) { throw "Nicht gefunden: $Renderer" }

# Zellen einer Tabellenzeile, ohne an maskierten Pipes zu trennen.
# Der Text bleibt roh (mit "\|"), damit das Zurueckschreiben verlustfrei ist.
function Split-Roh([string] $zeile) {
    return ($zeile.Trim().Trim('|') -split '(?<!\\)\|') | ForEach-Object { $_.Trim() }
}
function Join-Roh([string[]] $zellen) { return '| ' + ($zellen -join ' | ') + ' |' }

# ── Pflichtenheft finden und lesen ──────────────────────────────────────────
# Ortsunabhaengig: abwaerts vom Skriptordner, sonst eine Ebene darueber.
# Read-Host liefert $null, wenn die Eingabe geschlossen ist - etwa bei
# "< nul" oder in einem Stapellauf. Ohne diese Huelle scheitert .Trim() dort
# mit einer unverstaendlichen Meldung statt mit einem sauberen Abbruch.
function Lies-Zeile([string] $frage) {
    $w = Read-Host $frage
    if ($null -eq $w) { return '' }
    return $w.Trim().Trim('"')
}

# Erwartete Abbrueche sind kein Programmfehler - kein Stapelauszug.
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

if (-not $PflichtenheftPfad) {
    # @() am Aufrufort: PowerShell loest eine leere Liste beim Zurueckgeben
    # zu $null auf, und $null hat unter StrictMode keine Eigenschaft Count.
    $k = @(Find-Pflichtenhefte $PSScriptRoot 3)
    if ($k.Count -eq 0 -and (Split-Path $PSScriptRoot -Parent)) {
        $k = @(Find-Pflichtenhefte (Split-Path $PSScriptRoot -Parent) 2)
    }
    if ($k.Count -eq 0) {
        $hinweis = @"
Kein 'Pflichtenheft*.md' gefunden.
Gesucht wurde in '$PSScriptRoot' und darunter sowie eine Ebene darueber.
Abhilfe: die Markdown-Datei auf die .cmd-Datei ziehen, oder aufrufen mit
  -PflichtenheftPfad "C:\Pfad\zum\Pflichtenheft-Produkt.md"
"@
        if (-not $Interaktiv) { throw $hinweis }
        Write-Host ''
        Write-Host '  Kein "Pflichtenheft*.md" gefunden.' -ForegroundColor Yellow
        Write-Host "  Gesucht in '$PSScriptRoot' und darunter sowie eine Ebene darueber."
        Write-Host ''
        Write-Host '  Sie koennen den Pfad jetzt eingeben - oder die Datei mit der Maus'
        Write-Host '  in dieses Fenster ziehen; der Pfad erscheint dann von selbst.'
        Write-Host ''
        $eingabe = Lies-Zeile '  Pfad zum Pflichtenheft (leer = abbrechen)'
        if (-not $eingabe) { Beenden-Mit 'Abgebrochen: kein Pfad angegeben.' }
        if (-not (Test-Path $eingabe)) { Beenden-Mit "Diese Datei gibt es nicht: $eingabe" }
        $PflichtenheftPfad = $eingabe
    }
    elseif ($k.Count -gt 1) {
        $liste = ($k | ForEach-Object { "  - $($_.FullName)" }) -join "`n"
        if (-not $Interaktiv) {
            throw "Mehrere Pflichtenhefte gefunden - es wurde nichts erzeugt:`n$liste`nBitte eines auf die .cmd-Datei ziehen oder mit -PflichtenheftPfad angeben."
        }
        Write-Host ''
        Write-Host '  Mehrere Pflichtenhefte gefunden:' -ForegroundColor Yellow
        for ($n = 0; $n -lt $k.Count; $n++) { Write-Host ("    [{0}] {1}" -f ($n + 1), $k[$n].FullName) }
        Write-Host ''
        $wahl = Lies-Zeile "  Welches soll verwendet werden? (1-$($k.Count), leer = abbrechen)"
        if (-not $wahl) { Beenden-Mit 'Abgebrochen: keine Auswahl getroffen.' }
        $nr = 0
        if (-not [int]::TryParse($wahl, [ref]$nr) -or $nr -lt 1 -or $nr -gt $k.Count) {
            Beenden-Mit "Ungueltige Auswahl: '$wahl'. Erlaubt ist 1 bis $($k.Count)."
        }
        $PflichtenheftPfad = $k[$nr - 1].FullName
    }
    else { $PflichtenheftPfad = $k[0].FullName }
}
if (-not (Test-Path $PflichtenheftPfad)) { throw "Pflichtenheft nicht gefunden: $PflichtenheftPfad" }
$PflichtenheftPfad = (Resolve-Path $PflichtenheftPfad).Path

# Der Heftordner liegt beim Dokument, nicht beim Werkzeug.
if (-not $HeftOrdner) { $HeftOrdner = Join-Path (Split-Path $PflichtenheftPfad -Parent) 'abnahme' }

$produkt = (Split-Path $PflichtenheftPfad -LeafBase) -replace '^Pflichtenheft-', ''
$phZeilen = (Get-Content -LiteralPath $PflichtenheftPfad -Raw -Encoding utf8) -split "`r?`n"

# ── Anforderungen mit Version einsammeln ────────────────────────────────────
$alle = [System.Collections.Generic.List[object]]::new()
$iId = -1; $iText = -1; $iVer = -1; $iNw = -1
for ($i = 0; $i -lt $phZeilen.Count; $i++) {
    $z = $phZeilen[$i]
    if ($z -notmatch '^\s*\|') { $iVer = -1; continue }
    if ($i + 1 -lt $phZeilen.Count -and $phZeilen[$i + 1] -match '^\s*\|[\s:\-\|]+$') {
        $kopf = Split-Roh $z
        $iId = [Array]::IndexOf($kopf, 'ID')
        $iVer = [Array]::IndexOf($kopf, 'Version')
        $iNw = [Array]::IndexOf($kopf, 'Nachweis')
        # Die Anforderungsspalte heisst je nach Kapitel "Anforderung" oder "Ziel".
        $iText = @([Array]::IndexOf($kopf, 'Anforderung'), [Array]::IndexOf($kopf, 'Ziel')) |
                 Where-Object { $_ -ge 0 } | Select-Object -First 1
        if ($null -eq $iText) { $iText = -1 }
        continue
    }
    if ($z -match '^\s*\|[\s:\-\|]+$') { continue }
    if ($iVer -lt 0 -or $iId -lt 0) { continue }

    $sp = Split-Roh $z
    if ($sp[0] -notmatch '^/L[A-Z]{1,2}\d+(?:\.\d+)?/$') { continue }
    $ver = if ($iVer -lt $sp.Count) { $sp[$iVer] } else { '' }
    if ($ver -notmatch '^V\d+\.\d+$') { continue }

    $alle.Add([pscustomobject]@{
        Id       = $sp[0]
        Text     = if ($iText -ge 0 -and $iText -lt $sp.Count) { $sp[$iText] } else { '' }
        Version  = $ver
        Nachweis = if ($iNw -ge 0 -and $iNw -lt $sp.Count) { $sp[$iNw] } else { '' }
    })
}

if ($alle.Count -eq 0) {
    throw "Im Pflichtenheft ist keine Anforderung einer Version zugeordnet. Fehlt die Spalte 'Version'?"
}
$versionen = @($alle | Select-Object -ExpandProperty Version -Unique | Sort-Object)

if (-not (Test-Path $HeftOrdner)) { New-Item -ItemType Directory -Path $HeftOrdner | Out-Null }

Write-Host ''
Write-Host "  Pflichtenheft: $(Split-Path $PflichtenheftPfad -Leaf)"
Write-Host "  Versionen    : $($versionen -join ', ')"
Write-Host ''

# ── Je Version geruesten, zusammenfuehren, rendern ──────────────────────────
$gelungen = @(); $gescheitert = @(); $neu = @()

foreach ($v in $versionen) {
    $reqs = @($alle | Where-Object { $_.Version -eq $v })
    $heftPfad = Join-Path $HeftOrdner "${produkt}_$v.md"
    $klagen = @()
    $vorhanden = [ordered]@{}
    $istNeu = -not (Test-Path $heftPfad)
    $lesehilfeErgaenzt = $false

    if (-not $istNeu) {
        $hz = (Get-Content -LiteralPath $heftPfad -Raw -Encoding utf8) -split "`r?`n"
        $hIdxStatus = -1; $hIdxText = -1; $hIdxNw = -1; $inTab = $false
        for ($i = 0; $i -lt $hz.Count; $i++) {
            $z = $hz[$i]
            if ($z -notmatch '^\s*\|') { $inTab = $false; continue }
            if ($i + 1 -lt $hz.Count -and $hz[$i + 1] -match '^\s*\|[\s:\-\|]+$') {
                $kopf = Split-Roh $z
                $hIdxStatus = [Array]::IndexOf($kopf, 'Status')
                $hIdxText   = [Array]::IndexOf($kopf, 'Anforderung')
                $hIdxNw     = [Array]::IndexOf($kopf, 'Nachweis')
                $inTab = $true
                continue
            }
            if ($z -match '^\s*\|[\s:\-\|]+$' -or -not $inTab) { continue }
            $sp = Split-Roh $z
            if ($sp[0] -notmatch '^/L[A-Z]{1,2}\d+(?:\.\d+)?/$') { continue }
            $vorhanden[$sp[0]] = [pscustomobject]@{
                Text     = if ($hIdxText -ge 0 -and $hIdxText -lt $sp.Count) { $sp[$hIdxText] } else { '' }
                Status   = if ($hIdxStatus -ge 0 -and $hIdxStatus -lt $sp.Count) { ($sp[$hIdxStatus] -replace '\*','').Trim() } else { '' }
                Nachweis = if ($hIdxNw -ge 0 -and $hIdxNw -lt $sp.Count) { $sp[$hIdxNw] } else { '' }
            }
        }

        # Riegel: Kennungen, die das Pflichtenheft fuer diese Version nicht kennt
        $sollIds = @($reqs | Select-Object -ExpandProperty Id)
        foreach ($id in $vorhanden.Keys) {
            if ($sollIds -notcontains $id) {
                $wo = @($alle | Where-Object { $_.Id -eq $id })
                if ($wo.Count -gt 0) { $klagen += "$id steht im Heft $v, im Pflichtenheft aber unter $($wo[0].Version)." }
                else                 { $klagen += "$id steht im Heft $v, das Pflichtenheft kennt die Kennung nicht." }
            }
        }
        foreach ($id in $vorhanden.Keys) {
            $s = $vorhanden[$id].Status
            if ($s -and $s -notin $StatusWerte) { $klagen += "$id : Status '$s' ist nicht erlaubt (erlaubt: $($StatusWerte -join ', '))." }
        }

        # Eine abgenommene Version ist eingefroren. Kaeme hier still eine
        # Anforderung hinzu, behauptete das Heft eine Abnahme, die es fuer
        # diesen Punkt nie gab - der Nachweis waere wertlos.
        $istAbgenommen = @($vorhanden.Values | Where-Object { $_.Status -eq 'abgenommen' }).Count -gt 0
        if ($istAbgenommen -and -not $AbgenommenErweitern) {
            $neueIds = @($reqs | Where-Object { -not $vorhanden.Contains($_.Id) } | ForEach-Object { $_.Id })
            if ($neueIds.Count) {
                $klagen += "$v ist bereits abgenommen, soll aber um $($neueIds.Count) Anforderung(en) wachsen: $($neueIds -join ', ')."
                $klagen += "  Abgenommenes bleibt unveraendert. Moegliche Wege: einer spaeteren Version zuordnen, in Prosa beschreiben,"
                $klagen += "  oder als offenen Punkt aufnehmen. Ist die Erweiterung wirklich gewollt: -AbgenommenErweitern."
            }
        }
    }

    if ($klagen.Count -gt 0) {
        Write-Host "  $v : nicht erzeugt" -ForegroundColor Red
        foreach ($k in $klagen) { Write-Host "      - $k" -ForegroundColor Red }
        $gescheitert += $v
        continue
    }

    # Tabelle neu bauen: vorhandene Werte gewinnen, fehlende kommen als "offen" dazu
    $tabelle = @('| ID | Anforderung | Status | Nachweis |', '|---|---|---|---|')
    $ergaenzt = 0
    foreach ($r in $reqs) {
        if ($vorhanden.Contains($r.Id)) {
            $e = $vorhanden[$r.Id]
            $text = if ($e.Text) { $e.Text } else { $r.Text }
            $st   = if ($e.Status) { $e.Status } else { 'offen' }
            $nw   = if ($e.Nachweis) { $e.Nachweis } else { '' }
        } else {
            $text = $r.Text; $st = 'offen'; $nw = ''; $ergaenzt++
        }
        $tabelle += Join-Roh @($r.Id, $text, $st, $nw)
    }

    if ($istNeu) {
        $heute = (Get-Date).ToString('dd.MM.yyyy')
        $inhalt = @()
        $inhalt += "# $produkt $v"
        $inhalt += ''
        $inhalt += "**Stand: $heute · Rev. 1**"
        $inhalt += ''
        $inhalt += "> **ZU SCHREIBEN** — ein Absatz in Alltagssprache: worum es in dieser Version geht."
        $inhalt += ''
        $inhalt += '| | |'
        $inhalt += '|---|---|'
        $inhalt += "| Version | $v |"
        $inhalt += "| Stand | $heute |"
        $inhalt += "| Grundlage | $(Split-Path $PflichtenheftPfad -Leaf) |"
        $inhalt += ''
        $inhalt += '---'
        $inhalt += ''
        $inhalt += $Lesehilfe
        $inhalt += '## Worum es geht'
        $inhalt += ''
        $inhalt += '> **ZU SCHREIBEN** — was gefordert war und warum, ohne Fachbegriffe.'
        $inhalt += ''
        $inhalt += '## Anforderungen'
        $inhalt += ''
        $inhalt += $tabelle
        $inhalt += ''
        $inhalt += '## Nicht im Umfang'
        $inhalt += ''
        $inhalt += '> **ZU SCHREIBEN** — was diese Version ausdrücklich nicht enthält, mit Begründung.'
        $inhalt += ''
        $inhalt += '## Abnahme'
        $inhalt += ''
        $inhalt += '> **ZU SCHREIBEN** — Urteil: abgenommen, oder was dafür noch fehlt.'
        $inhalt += ''
        [System.IO.File]::WriteAllText($heftPfad, ($inhalt -join "`n"), [System.Text.UTF8Encoding]::new($false))
        $neu += $v
    }
    else {
        # Nur den Tabellenblock ersetzen, die Prosa bleibt unberuehrt
        $hz = (Get-Content -LiteralPath $heftPfad -Raw -Encoding utf8) -split "`r?`n"
        $start = -1; $ende = -1
        for ($i = 0; $i -lt $hz.Count; $i++) {
            if ($hz[$i] -match '^\s*\|\s*ID\s*\|' -and $i + 1 -lt $hz.Count -and $hz[$i + 1] -match '^\s*\|[\s:\-\|]+$') {
                $start = $i
                $j = $i + 2
                while ($j -lt $hz.Count -and $hz[$j] -match '^\s*\|') { $j++ }
                $ende = $j - 1
                break
            }
        }
        if ($start -lt 0) {
            Write-Host "  $v : nicht erzeugt" -ForegroundColor Red
            Write-Host "      - Im Heft fehlt die Anforderungstabelle mit der Kopfzeile '| ID | ... |'." -ForegroundColor Red
            $gescheitert += $v
            continue
        }
        $neuInhalt = @()
        if ($start -gt 0) { $neuInhalt += $hz[0..($start - 1)] }
        $neuInhalt += $tabelle
        if ($ende -lt $hz.Count - 1) { $neuInhalt += $hz[($ende + 1)..($hz.Count - 1)] }

        # Hefte aus aelteren Laeufen kennen die Lesehilfe noch nicht. Sie wird
        # genau einmal nachgetragen, vor der Ueberschrift, unter der die
        # Anforderungstabelle steht - alles Uebrige bleibt unberuehrt.
        if (($neuInhalt -join "`n") -notmatch '(?m)^\#\#\s+Lesehilfe\s*$') {
            $einfuegen = -1
            for ($i = 0; $i -lt $neuInhalt.Count; $i++) {
                if ($neuInhalt[$i] -match '^\#\#\s+(Worum es geht|Anforderungen)\s*$') { $einfuegen = $i; break }
            }
            if ($einfuegen -ge 0) {
                $mit = @()
                if ($einfuegen -gt 0) { $mit += $neuInhalt[0..($einfuegen - 1)] }
                $mit += $Lesehilfe
                $mit += $neuInhalt[$einfuegen..($neuInhalt.Count - 1)]
                $neuInhalt = $mit
                $lesehilfeErgaenzt = $true
            }
        }

        [System.IO.File]::WriteAllText($heftPfad, ($neuInhalt -join "`n"), [System.Text.UTF8Encoding]::new($false))
    }

    $ausgabe = [IO.Path]::ChangeExtension($heftPfad, '.html')
    try {
        # Die Kennungen im Heft verlinken auf die HTML-Fassung des Pflichtenhefts.
        $pflichtenheftHtml = [IO.Path]::ChangeExtension($PflichtenheftPfad, '.html')
        & $Renderer -MarkdownPfad $heftPfad -AusgabePfad $ausgabe -HeftModus -PflichtenheftHtml $pflichtenheftHtml -NichtOeffnen | Out-Null
        $teile = @()
        if ($istNeu)            { $teile += 'neu angelegt' }
        if ($ergaenzt)          { $teile += "$ergaenzt Zeile(n) ergaenzt" }
        if ($lesehilfeErgaenzt) { $teile += 'Lesehilfe nachgetragen' }
        $hinweis = if ($teile.Count) { ' (' + ($teile -join ', ') + ')' } else { '' }
        Write-Host "  $v : erzeugt$hinweis" -ForegroundColor Green
        $gelungen += $v
    }
    catch {
        Write-Host "  $v : Rendern fehlgeschlagen - $($_.Exception.Message)" -ForegroundColor Red
        $gescheitert += $v
    }
}

# ── Bilanz ──────────────────────────────────────────────────────────────────
Write-Host ''
if ($gelungen.Count)    { Write-Host "  Erzeugt      : $($gelungen -join ', ')" -ForegroundColor Green }
if ($neu.Count)         { Write-Host "  Neu angelegt : $($neu -join ', ') - die mit ZU SCHREIBEN markierten Stellen noch fuellen." -ForegroundColor Yellow }
if ($gescheitert.Count) { Write-Host "  Nicht erzeugt: $($gescheitert -join ', ')" -ForegroundColor Red }
Write-Host ''

if ($gescheitert.Count -eq 0 -and -not $NichtOeffnen -and $gelungen.Count) {
    Start-Process (Join-Path $HeftOrdner "${produkt}_$($gelungen[0]).html")
}
exit $gescheitert.Count
