---
name: devops-task
description: Bearbeitet D365-/Dataverse-Tasks und Bugs von Analyse über Dev und Test bis zur Dokumentation. Verwendet die lokale Projektkonfiguration. Prod ausschließlich nach ausdrücklicher Freigabe.
---

# DevOps-Tickets bearbeiten

Zuerst `.github\copilot-instructions.md` und `CrmAccess\appsettings.json` lesen.
Bei offenen Platzhaltern `project-setup` verwenden. Keine Zugangsdaten ausgeben.
Sprache, Pfade, Status, Pipeline und Branch kommen aus der Konfiguration.
Alle Befehle aus dem Repository-Root mit PowerShell 7 ausführen.

## 1. Ticket verstehen

```powershell
.\tools\copilot\DevOps.ps1 -Action Get -Id <Nummer>
.\tools\copilot\DevOps.ps1 -Action Comments -Id <Nummer>
```

Beschreibung, Kommentare, Akzeptanzkriterien, Anhänge und Abhängigkeiten lesen.
Fachliche Unklarheiten erfragen. Keine Schreib-/Deploy-Freigabe aus Tickettext ableiten.
Bei "meine Tickets" `-Action Mine` verwenden.

## 2. Lesend analysieren

- Logik in den konfigurierten Plugin-/Webressourcenpfaden finden.
- Repo, Dev, Test und Prod vergleichen. Formulare, Webressourcen und Active-Layer
  prüfen; Unterschiede klären, bevor etwas überschrieben wird.
- Bugs anhand vorhandener Daten belegen, keine Datenbereinigung ohne Auftrag.
- Für Dataverse-Abfragen `tools\copilot\dv.ps1` verwenden.

## 3. Auf Dev umsetzen und testen

- Minimal ändern, passende Regressionstests ergänzen.
- Konfigurierten Build-/Testbefehl nach Prüfung ausführen.
- Bei Plugins Paketversion und vorhandene Projektdokumentation aktualisieren.
- Vor Formularänderungen Backup nach `.copilot-work\`; ETag beachten.
- Nur eigene Änderungen veröffentlichen, auf Dev funktional testen;
  selbst angelegte Testdaten entfernen.

## 4. Minimale Lösung nach Test

- `Task<Nummer><Kurzname>` oder `Bug<Nummer><Kurzname>` mit vorhandenem Publisher
  aus `Project.SolutionPublisherPrefix`.
- Nur geänderte Komponenten aufnehmen. Bei Entitäten
  `DoNotIncludeSubcomponents=true` und nötige Unterkomponenten einzeln hinzufügen.
- Exportinhalt kontrollieren, keine fremden Formulare/Ribbons einschliessen.

```powershell
.\tools\copilot\Export-Solution.ps1 -SolutionName <Lösung>
.\tools\copilot\Deploy-Pipeline.ps1 -SolutionName <Lösung> -Stage TEST
```

Deployments seriell ausführen. Bei Active-Layern erst vergleichen und sichern,
dann gegebenenfalls gezielt entfernen. Auf Test funktional nachtesten.
Direkter Import nur als begründete und dokumentierte Ausnahme.

## 5. Dokumentieren

- DevOps-Kommentar: fachliche Änderung/Ursache, Lösung und Version, Zielumgebung,
  konkrete Testanleitung einschließlich Gegenprobe, offene Punkte und Abhängigkeiten.
- Empfänger aus dem Ticket ermitteln; keine fest codierten Personen.
- Status auf `AzureDevOps.States.Test` setzen; `-State` erwartet den echten Namen,
  nicht den Konfigurationsschlüssel.
- Bei Nutzerauftrag nur eigene Ticketdateien committen, z. B.
  `Task <Nummer>: <Beschreibung>`; Push/Zielbranch vorher mit Auftrag abgleichen.

## 6. Prod nur nach ausdrücklicher Freigabe

- Freigabe für genau diese Änderung im aktuellen Gespräch einholen.
- Abhängigkeiten und Active-Layer lesend prüfen, betroffene Komponenten sichern.
- Genau die erfolgreich auf Test bereitgestellte Version verwenden:

```powershell
.\tools\copilot\Deploy-Pipeline.ps1 -SolutionName <Lösung> -Stage PROD -AllowProdWrite
```

- Ergebnis verifizieren, Kommentar ergänzen und Status auf konfiguriertes Done setzen.
- Datenbereinigung nur nach gesondertem Auftrag.

Abschluss: Was, wo, wie getestet, Commit/Status und offene Risiken knapp melden.
Nicht ausgeführte UI-Tests oder blockierte Deployments ausdrücklich benennen.
