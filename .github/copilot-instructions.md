# Copilot-Anweisungen - 4cloud digital gmbh

Wiederverwendbare Arbeitsgrundlage für D365-/Dataverse-Kundenprojekte
(Sales, Customer Service, Project Operations und kundenspezifische Erweiterungen).

## Einrichtung und Projektkontext
- Beim zentralen Setup aus diesem Clone zuerst nur den Zielpfad des Kundenprojekts
  erfragen (oder den bereits genannten verwenden). Der Skill `project-setup`
  untersucht vorhandene Zieldateien, übernimmt die Vorlage und befüllt belegbare
  Platzhalter automatisch. Alle offenen, nicht geheimen Angaben vor der Meldung
  eines vollständigen Setups gezielt nachfragen; bei unbeantworteten Punkten
  bleibt die Einrichtung ausdrücklich unvollständig. Erst lokale Projektdateien
  und bei ausdrücklichem Auftrag die passenden Azure-DevOps-/Power-Platform-MCP-
  Lesewerkzeuge nutzen; offene Fragen in kleinen thematischen Gruppen stellen.
- Quelle und Ziel getrennt halten: Kundenwerte ausschließlich im Ziel bearbeiten.
  Änderungen an der Mastervorlage selbst erfordern keine Kundenkonfiguration.
- Projektwerte ausschließlich aus `CrmAccess\appsettings.json` lesen.
- Solange dort Platzhalter stehen oder die Datei fehlt: zuerst den Skill
  `.github\skills\project-setup\SKILL.md` verwenden. Keine Kundenwerte raten.
- Kommunikationssprache: `Project.Language`; Name und Kunde: `Project.Name` und
  `Project.Customer`. Technische Namen und bestehende Lokalisierung beibehalten.
- Beim Setup `Project.Customer` immer aus dem exakten Azure-DevOps-Projektnamen
  (`AzureDevOps.Project`) übernehmen; keinen separaten Kundennamen erfragen.
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
- Bei reiner Dateieinrichtung keine Anmeldung oder Remote-Abfrage. Bei
  ausdrücklichem Rechercheauftrag ausschließlich lesende MCP-Abfragen zum
  benannten Azure-DevOps-Projekt und zur DEV-Umgebung; UAT/Prod auch lesend nur
  nach ausdrücklicher Bestätigung für die jeweilige Umgebung.
- Azure DevOps wird immer verwendet; nicht nach seiner Nutzung fragen.
  Organisation und Projekt zuerst über Azure-DevOps-MCP ermitteln; nur bei
  fehlendem Zugriff oder mehrdeutiger Zuordnung nachfragen. Der Setup-Auftrag
  umfasst diese Recherche, ohne separates Zugriffsformular.
- Azure-DevOps-MCP für auftragsbezogene Lese- und Schreiboperationen verwenden.
  Keine Test-Schreibaktionen beim Setup; nur konkret angeforderte Änderungen
  ausführen. Dies erteilt keine Dataverse-UAT-/Prod-Freigabe.
- Vor Pipeline-Recherche fragen, ob Power-Platform-Pipelines vorhanden sind und
  verwendet werden sollen. Vor Client-ID-Abfragen zusätzlich klären, ob
  ein Service Principal für lokale Skripte existiert und für welche Umgebungen
  er vorgesehen ist; aus Verbindungen oder Metadaten keine Nutzung ableiten.

## Repository und Zugangsdaten
- `CrmAccess\credentials.json`: lokale TenantId und je Umgebung ClientId/ClientSecret.
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
- Keine GitHub-Repositories prüfen, erstellen oder initialisieren und kein
  `git init` ausführen. Fehlt im Projekt ein Git-Checkout, lokale Vorlage bei
  Bedarf ins vorhandene Ziel übernehmen und bei fehlenden Git-Werten nach dem
  Pfad zu einem vorhandenen lokalen Checkout fragen. Git-abgeleitete Werte offen
  lassen, bis der Nutzer ihn bereitstellt oder sie anderweitig beantwortet.
- Lokale Projektpfade gezielt prüfen; wenn ein genannter Pfad fehlt, den Nutzer
  nach dem korrekten Pfad fragen und nicht in benachbarten Ordnern suchen. Bei
  ausdrücklichem Auftrag darf das benannte Azure-Repo per MCP lesend untersucht
  werden.
- Vor der Client-ID zuerst fragen, ob ein Service Principal existiert und für
  welche Umgebung(en) er vorgesehen ist. Verbindungen nicht ohne Bestätigung
  als die für lokale Skripte gedachte App-Identität übernehmen. Secrets nie
  erfragen.

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
