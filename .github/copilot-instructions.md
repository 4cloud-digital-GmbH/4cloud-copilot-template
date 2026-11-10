# Copilot-Anweisungen - 4cloud digital gmbh

Wiederverwendbare Arbeitsgrundlage fuer D365-/Dataverse-Kundenprojekte
(Sales, Customer Service, Project Operations und kundenspezifische Erweiterungen).

## Einrichtung und Projektkontext
- Projektwerte ausschliesslich aus `CrmAccess\appsettings.json` lesen.
- Solange dort Platzhalter stehen oder die Datei fehlt: zuerst den Skill
  `.github\skills\project-setup\SKILL.md` verwenden. Keine Kundenwerte raten.
- Kommunikationssprache: `Project.Language`; Name und Kunde: `Project.Name` und
  `Project.Customer`. Technische Namen und bestehende Lokalisierung beibehalten.
- Codepfade, Build-/Testbefehle und Zielbranch stehen unter `Repository`.
  Vorhandene Struktur pruefen; konfigurierte Befehle vor Ausfuehrung lesen.
- Fuer Tickets den Skill `.github\skills\devops-task\SKILL.md` verwenden.

## Umgebungen und Freigaben
- `Environments.dev`: Entwicklung, unmanaged.
- `Environments.test`: managed Loesungen, funktional testen, eigene Testdaten entfernen.
- `Environments.prod`: nur lesend. Jede Aenderung braucht eine ausdrueckliche
  Freigabe des Nutzers im aktuellen Gespraech; vorab betroffene Komponenten sichern.
- `Environments.host`: Host der Power-Platform-Pipeline; kann von Dev abweichen.
- `-AllowProdWrite` ist nur eine technische Sperre, niemals eine fachliche Freigabe.
- Keine Anmeldung, Datenabfrage oder Bereitstellung waehrend der reinen Einrichtung.

## Repository und Zugangsdaten
- `CrmAccess\credentials.json`: lokale TenantId, ClientId und ClientSecret.
  Niemals ausgeben, in Chat/Formularen abfragen, in Logs schreiben oder committen.
- `CrmAccess\appsettings.json`: lokale Projektkonfiguration, ebenfalls git-ignoriert.
  Die Hilfsskripte verwenden diese Datei; kein appsettings.Local.json-Override.
- Arbeitsdateien, Backups, ZIPs und CSVs nach `.copilot-work\`.
- Vorhandene `.gitignore` beim Uebernehmen ergaenzen, nicht ersetzen.
  Ignore-Regeln schuetzen keine bereits versionierten Dateien: Index pruefen.
- Vor Formular-/Webressourcen-Aenderungen Repo, Dev, Test und Prod lesend vergleichen.
  Fremde und parallele Aenderungen niemals ueberschreiben.
- Nur ticketbezogene eigene Aenderungen committen. Kein automatischer Push;
  Commit/Push nur gemaess Nutzerauftrag, Zielbranch aus `Repository.DefaultBranch`.

## Loesungen und Deployments
- Pro Ticket eine minimale Loesung `Task<Nummer><Kurzname>` oder `Bug<Nummer><Kurzname>`.
  Publisher-Praefix: `Project.SolutionPublisherPrefix`.
- Nur geaenderte Komponenten aufnehmen; Entitaeten nicht pauschal mit allen
  Unterkomponenten hinzufuegen.
- Standardweg: `tools\copilot\Deploy-Pipeline.ps1`, TEST vor PROD.
  Pipeline und Stage-Namen aus `Deployment`. PROD erhaelt dieselbe Version wie TEST.
- `Import-Solution.ps1` nur als begruendete, dokumentierte Ausnahme.
- Importe/Deployments nicht parallel ausfuehren. Ein einzelnes Skript kann
  konkurrierende Starts anderer Prozesse nicht vollstaendig ausschliessen.
- Active-Layer vor managed Deployments pruefen. Entfernen nur nach Vergleich
  und Backup; auf Prod zusaetzlich Freigabe erforderlich.
- Bestehende Daten nur bereinigen, wenn das Ticket es ausdruecklich verlangt.

## Entwicklung und Validierung
- Vorhandene Patterns, Tests, Formatierung und Lokalisierung beibehalten.
- Bei Plugin-Aenderungen Paketversion erhoehen und vorhandene Projektdokumentation
  aktualisieren; Build-/Registrierungsart zuerst im Projekt pruefen.
- Fuer geaenderte Logik fokussierte Regressionstests ergaenzen.
- Eigene Formularaenderungen gezielt per PublishXml veroeffentlichen;
  kein pauschales PublishAllXml fuer fremde unveroeffentlichte Aenderungen.
- Formular-PATCH mit If-Match/ETag. Tabellenmetadaten vor Annahmen ueber Spalten pruefen.
- Testdaten nach Tests entfernen; Fehler, Grenzen und nicht getestete UI-Schritte
  ehrlich dokumentieren.
- Hilfsskripte benoetigen PowerShell 7; DevOps zusaetzlich Azure CLI mit `az login`,
  Pipeline-Deployments Power Platform CLI mit bereits eingerichtetem Auth-Profil.
