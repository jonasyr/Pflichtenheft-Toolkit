# Pflichtenheft-Toolkit

Erzeugt ein Pflichtenheft nach fachlichem Standard als Markdown und HTML — und, wenn das Vorhaben Versionen hat, je Version ein kurzes Abnahmeheft für Projektleitung und Geschäftsführung.

## Ordnerinhalt

| Datei | Wozu |
|---|---|
| `Prompt-Pflichtenheft.md` | Der Text, den Sie an Claude Code übergeben |
| `Pflichtenheft-aktualisieren.cmd` | Doppelklick: erzeugt die HTML des Pflichtenhefts neu |
| `Pflichtenheft-aktualisieren.ps1` | Der Erzeuger, Gestaltung eingebaut |
| `Abnahmehefte-aktualisieren.cmd` | Doppelklick: erzeugt die Abnahmehefte je Version |
| `Abnahmehefte-aktualisieren.ps1` | Gerüstung, Zusammenführung und Prüfung |
| `Toolkit-Selbsttest.cmd` / `.ps1` | Doppelklick: prüft, ob auf diesem Rechner alles läuft |

## Vor dem ersten Einsatz

`Toolkit-Selbsttest.cmd` doppelklicken. Er spielt 25 Situationen in einem temporären Ordner durch — verschiedene Ablageorte, Fehlerfälle, Umlaute, wiederholte Läufe — und meldet am Ende, ob alles bestanden ist. Eigene Dokumente werden dabei nicht angefasst. Dauert etwa eine Minute.

## In drei Schritten

1. **Ordner anlegen** für das Vorhaben und die Skriptdateien hineinkopieren.
2. **Claude Code in diesem Ordner starten.** Aus `Prompt-Pflichtenheft.md` alles zwischen den beiden `═══`-Linien kopieren und einfügen. Darunter anhängen, was schon vorliegt — Lastenheft, Besprechungsnotiz, Mailverlauf, Stichpunkte. Auch ohne Anhang möglich: es wird dann alles erfragt.
3. **Fragen beantworten.** Zuerst kommen drei Fragen zum Umfang, danach die inhaltlichen. Jede Frage enthält einen Vorschlag, den Sie nur bestätigen müssen. Am Ende sehen Sie eine Gliederungsvorschau zur Freigabe.

Danach liegen die Dateien im Ordner. Die HTML öffnen Sie per Doppelklick.

## Etwas ändern

Claude Code erneut im selben Ordner starten und denselben Prompt einfügen. Die vorhandenen Dateien werden erkannt, der Bestand wird berichtet, und es wird gefragt, was sich ändern soll. Kennungen bleiben dabei erhalten — nur so bleibt nachvollziehbar, was sich wann geändert hat. Jede Änderung landet im Änderungsverzeichnis am Dokumentende.

## Firmenlogo

Liegt eine Bilddatei mit `Logo` im Namen (`.png`, `.jpg` oder `.svg`) **neben dem Dokument** oder **beim Werkzeug**, erscheint sie oben rechts im Kopf jeder erzeugten HTML — auch in den Abnahmeheften.

Das Bild wird dabei **in die HTML eingebettet**, nicht verknüpft. Die Datei bleibt also vollständig, wenn Sie sie per Mail verschicken oder auf einen anderen Rechner kopieren.

Ein Logo neben dem Dokument sticht das beim Werkzeug — so kann ein einzelnes Vorhaben ein eigenes führen. Ohne Logodatei bleibt der Kopf unverändert; es entsteht keine Lücke.

## Wo die Dateien liegen dürfen

Überall. Die Skripte suchen das Pflichtenheft von ihrem eigenen Ordner abwärts und, wenn dort nichts liegt, eine Ebene darüber. Damit funktionieren die üblichen Anordnungen ohne Zutun:

- alles in einem Ordner
- Skripte in der Wurzel, Dokument in `docs\`
- Skripte in `tools\`, Dokument in `docs\`

Der Ordner `abnahme\` entsteht immer **beim Dokument**, nicht beim Werkzeug.

Zwei Sonderfälle, beide werden im Fenster abgefragt:

- **Kein Pflichtenheft gefunden:** Sie können den Pfad eingeben — oder die Datei mit der Maus ins Fenster ziehen, der Pfad erscheint dann von selbst. Leer lassen bricht ab.
- **Mehrere Pflichtenhefte gefunden:** Sie bekommen eine nummerierte Liste und wählen per Zahl.

Alternativ jederzeit möglich: die Markdown-Datei auf die `.cmd`-Datei ziehen. Sie wird dann verwendet, unabhängig vom Suchergebnis.

**Das Fenster bleibt immer offen**, bis Sie eine Taste drücken — auch wenn alles geklappt hat. So können Sie die Meldungen in Ruhe lesen.

## Nach Hand-Änderungen an der Markdown-Datei

Die Markdown-Datei ist die Quelle, die HTML wird daraus erzeugt. Wer im Markdown etwas ändert, startet danach `Pflichtenheft-aktualisieren.cmd` per Doppelklick — und bei Versionen zusätzlich `Abnahmehefte-aktualisieren.cmd`.

Die HTML niemals von Hand bearbeiten: Sie wird beim nächsten Lauf überschrieben.

## Voraussetzung

**PowerShell 7 oder neuer.** Das in Windows enthaltene „Windows PowerShell 5.1" reicht nicht aus. Fehlt es, sagen die beiden `.cmd`-Dateien das beim Start und nennen den Installationsweg:

```
winget install --id Microsoft.PowerShell --source winget
```

oder <https://aka.ms/powershell>. Danach das Fenster schließen und die Datei erneut per Doppelklick starten — der Befehl `pwsh` ist erst in einem neu geöffneten Fenster bekannt.

## Wie die Dokumente zusammenhängen

**Das Pflichtenheft** sagt, *was gebaut werden soll*, und trägt bewusst **keinen Status**. Nur so lässt sich später unterscheiden, was vereinbart war, von dem, was daraus geworden ist.

**Das Abnahmeheft** sagt je Version, *was davon da ist*. Es trägt den Status und ist für Leser ohne technische Tiefe geschrieben.

`Abnahmehefte-aktualisieren.cmd` hält beides zusammen: Fehlende Anforderungen werden ins Heft eingetragen, vorhandene Statuswerte und sämtliche Prosa bleiben unangetastet, und ein Heft, das eine unbekannte Kennung oder einen unzulässigen Status enthält, wird abgewiesen — dann wird für dieses Heft nichts geschrieben und die Meldung nennt den Grund.

**Vom Heft ins Pflichtenheft springen:** In der HTML eines Abnahmehefts ist jede Kennung ein Link. Ein Klick öffnet die HTML des Pflichtenhefts in einem neuen Tab, springt zu genau dieser Anforderung und hebt die Zeile hervor. Dafür muss die HTML des Pflichtenhefts erzeugt sein und im selben Verhältnis zum Heftordner liegen wie beim Erzeugen — beim Weitergeben also den ganzen Ordner mitgeben.

Beide Dokumente beginnen mit einer **Lesehilfe**: Das Pflichtenheft erklärt darin die Kennungen (`/LF…/`, `/LZ…/` und so fort), die Prioritäten und die Nachweisarten; das Abnahmeheft erklärt die fünf Statuswerte. Damit kann auch jemand mitlesen, der das Dokument zum ersten Mal sieht.

Die Prosa der Hefte bleibt Handarbeit. Automatisch gekürzter Fachtext ist kein Abnahmetext, sondern derselbe Fachtext mit weniger Wörtern.
