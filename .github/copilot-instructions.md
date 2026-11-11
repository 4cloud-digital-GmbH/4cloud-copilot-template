# Copilot-Anweisungen - 4cloud digital gmbh

Wiederverwendbare Arbeitsgrundlage für D365-/Dataverse-Kundenprojekte
(Sales, Customer Service, Project Operations und kundenspezifische Erweiterungen).

## Einrichtung und Projektkontext
- Beim zentralen Setup aus diesem Clone zuerst nur den Zielpfad des Kundenprojekts
  erfragen (oder den bereits genannten verwenden). Der Skill `project-setup`
  untersucht vorhandene Zieldateien, übernimmt die Vorlage und befüllt belegbare
  Platzhalter automatisch. Nur fehlende/widersprüchliche Angaben nachfragen.
- Quelle und Ziel getrennt halten: Kundenwerte ausschließlich im Ziel bearbeiten.
  Änderungen an der Mastervorlage selbst erfordern keine Kundenkonfiguration.
- Projektwerte ausschließlich aus `CrmAccess\appsettings.json` lesen.
- Solange dort Platzhalter stehen oder die Datei fehlt: zuerst den Skill
  `.github\skills\project-setup\SKILL.md` verwenden. Keine Kundenwerte raten.
- Kommunikationssprache: `Project.Language`; Name und Kunde: `Project.Name` und
  `Project.Customer`. Technische Namen und bestehende Lokalisierung beibehalten.
- Codepfade, Build-/Testbefehle und Zielbranch stehen unter `Repository`.
  Vorhandene Struktur prüfen; konfigurierte Befehle vor Ausführung lesen.
- Für Tickets den Skill `.github\skills\devops-task\SKILL.md` verwenden.

## Umgebungen und Freigaben
- `Environments.dev`: Entwicklung, unmanaged.
- `Environments.test`: managed Lösungen, funktional testen, eigene Testdaten entfernen.
- `Environments.prod`: nur lesend. Jede Änderung braucht eine ausdrückliche
  Freigabe des Nutzers im aktuellen Gespräch; vorab betroffene Komponenten sichern.
- `Environments.host`: Host der Power-Platform-Pipeline; kann von Dev abweichen.
- `-AllowProdWrite` ist nur eine technische Sperre, niemals eine fachliche Freigabe.
- Keine Anmeldung, Datenabfrage oder Bereitstellung während der reinen Einrichtung.

## Repository und Zugangsdaten
- `CrmAccess\credentials.json`: lokale TenantId, ClientId und ClientSecret.
  Niemals ausgeben, in Chat/Formularen abfragen, in Logs schreiben oder committen.
- `CrmAccess\appsettings.json`: lokale Projektkonfiguration, ebenfalls git-ignoriert.
  Die Hilfsskripte verwenden diese Datei; kein appsettings.Local.json-Override.
- Arbeitsdateien, Backups, ZIPs und CSVs nach `.copilot-work\`.
- Vorhandene `.gitignore` beim Übernehmen ergänzen, nicht ersetzen.
  Ignore-Regeln schützen keine bereits versionierten Dateien: Index prüfen.
- Vor Formular-/Webressourcen-Änderungen Repo, Dev, Test und Prod lesend vergleichen.
  Fremde und parallele Änderungen niemals überschreiben.
- Nur ticketbezogene eigene Änderungen committen. Kein automatischer Push;
  Commit/Push nur gemäß Nutzerauftrag, Zielbranch aus `Repository.DefaultBranch`.

## Lösungen und Deployments
- Pro Ticket eine minimale Lösung `Task<Nummer><Kurzname>` oder `Bug<Nummer><Kurzname>`.
  Publisher-Präfix: `Project.SolutionPublisherPrefix`.
- Nur geänderte Komponenten aufnehmen; Entitäten nicht pauschal mit allen
  Unterkomponenten hinzufügen.
- Standardweg: `tools\copilot\Deploy-Pipeline.ps1`, TEST vor PROD.
  Pipeline und Stage-Namen aus `Deployment`. PROD erhält dieselbe Version wie TEST.
- `Import-Solution.ps1` nur als begründete, dokumentierte Ausnahme.
- Importe/Deployments nicht parallel ausführen. Ein einzelnes Skript kann
  konkurrierende Starts anderer Prozesse nicht vollständig ausschließen.
- Active-Layer vor managed Deployments prüfen. Entfernen nur nach Vergleich
  und Backup; auf Prod zusätzlich Freigabe erforderlich.
- Bestehende Daten nur bereinigen, wenn das Ticket es ausdrücklich verlangt.

## Entwicklung und Validierung
- Vorhandene Patterns, Tests, Formatierung und Lokalisierung beibehalten.
- Bei Plugin-Änderungen Paketversion erhöhen und vorhandene Projektdokumentation
  aktualisieren; Build-/Registrierungsart zuerst im Projekt prüfen.
- Für geänderte Logik fokussierte Regressionstests ergänzen.
- Eigene Formularänderungen gezielt per PublishXml veröffentlichen;
  kein pauschales PublishAllXml für fremde unveröffentlichte Änderungen.
- Formular-PATCH mit If-Match/ETag. Tabellenmetadaten vor Annahmen über Spalten prüfen.
- Testdaten nach Tests entfernen; Fehler, Grenzen und nicht getestete UI-Schritte
  ehrlich dokumentieren.
- Hilfsskripte benötigen PowerShell 7; DevOps zusätzlich Azure CLI mit `az login`,
  Pipeline-Deployments Power Platform CLI mit bereits eingerichtetem Auth-Profil.
