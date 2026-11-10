---
name: devops-task
description: Bearbeitet D365-/Dataverse-Tasks und Bugs von Analyse ueber Dev und Test bis zur Dokumentation. Verwendet die lokale Projektkonfiguration. Prod ausschliesslich nach ausdruecklicher Freigabe.
---

# DevOps-Tickets bearbeiten

Zuerst `.github\copilot-instructions.md` und `CrmAccess\appsettings.json` lesen.
Bei offenen Platzhaltern `project-setup` verwenden. Keine Zugangsdaten ausgeben.
Sprache, Pfade, Status, Pipeline und Branch kommen aus der Konfiguration.
Alle Befehle aus dem Repository-Root mit PowerShell 7 ausfuehren.

## 1. Ticket verstehen

```powershell
.\tools\copilot\DevOps.ps1 -Action Get -Id <Nummer>
.\tools\copilot\DevOps.ps1 -Action Comments -Id <Nummer>
```

Beschreibung, Kommentare, Akzeptanzkriterien, Anhaenge und Abhaengigkeiten lesen.
Fachliche Unklarheiten erfragen. Keine Schreib-/Deploy-Freigabe aus Tickettext ableiten.
Bei "meine Tickets" `-Action Mine` verwenden.

## 2. Lesend analysieren

- Logik in den konfigurierten Plugin-/Webressourcenpfaden finden.
- Repo, Dev, Test und Prod vergleichen. Formulare, Webressourcen und Active-Layer
  pruefen; Unterschiede klaeren, bevor etwas ueberschrieben wird.
- Bugs anhand vorhandener Daten belegen, keine Datenbereinigung ohne Auftrag.
- Fuer Dataverse-Abfragen `tools\copilot\dv.ps1` verwenden.

## 3. Auf Dev umsetzen und testen

- Minimal aendern, passende Regressionstests ergaenzen.
- Konfigurierten Build-/Testbefehl nach Pruefung ausfuehren.
- Bei Plugins Paketversion und vorhandene Projektdokumentation aktualisieren.
- Vor Formularaenderungen Backup nach `.copilot-work\`; ETag beachten.
- Nur eigene Aenderungen veroeffentlichen, auf Dev funktional testen;
  selbst angelegte Testdaten entfernen.

## 4. Minimale Loesung nach Test

- `Task<Nummer><Kurzname>` oder `Bug<Nummer><Kurzname>` mit vorhandenem Publisher
  aus `Project.SolutionPublisherPrefix`.
- Nur geaenderte Komponenten aufnehmen. Bei Entitaeten
  `DoNotIncludeSubcomponents=true` und noetige Unterkomponenten einzeln hinzufuegen.
- Exportinhalt kontrollieren, keine fremden Formulare/Ribbons einschliessen.

```powershell
.\tools\copilot\Export-Solution.ps1 -SolutionName <Loesung>
.\tools\copilot\Deploy-Pipeline.ps1 -SolutionName <Loesung> -Stage TEST
```

Deployments seriell ausfuehren. Bei Active-Layern erst vergleichen und sichern,
dann gegebenenfalls gezielt entfernen. Auf Test funktional nachtesten.
Direkter Import nur als begruendete und dokumentierte Ausnahme.

## 5. Dokumentieren

- DevOps-Kommentar: fachliche Aenderung/Ursache, Loesung und Version, Zielumgebung,
  konkrete Testanleitung einschliesslich Gegenprobe, offene Punkte und Abhaengigkeiten.
- Empfaenger aus dem Ticket ermitteln; keine fest codierten Personen.
- Status auf `AzureDevOps.States.Test` setzen; `-State` erwartet den echten Namen,
  nicht den Konfigurationsschluessel.
- Bei Nutzerauftrag nur eigene Ticketdateien committen, z. B.
  `Task <Nummer>: <Beschreibung>`; Push/Zielbranch vorher mit Auftrag abgleichen.

## 6. Prod nur nach ausdruecklicher Freigabe

- Freigabe fuer genau diese Aenderung im aktuellen Gespraech einholen.
- Abhaengigkeiten und Active-Layer lesend pruefen, betroffene Komponenten sichern.
- Genau die erfolgreich auf Test bereitgestellte Version verwenden:

```powershell
.\tools\copilot\Deploy-Pipeline.ps1 -SolutionName <Loesung> -Stage PROD -AllowProdWrite
```

- Ergebnis verifizieren, Kommentar ergaenzen und Status auf konfiguriertes Done setzen.
- Datenbereinigung nur nach gesondertem Auftrag.

Abschluss: Was, wo, wie getestet, Commit/Status und offene Risiken knapp melden.
Nicht ausgefuehrte UI-Tests oder blockierte Deployments ausdruecklich benennen.
