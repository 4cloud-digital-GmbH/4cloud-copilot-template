# 4cloud digital gmbh - Copilot-Vorlage für D365-Projekte

Kundenneutrale Vorlage für Dynamics 365 / Dataverse. Dieses Verzeichnis ist eine
Mastervorlage, keine fertig konfigurierte oder bereits verbundene Kundenumgebung.
Es enthält keine echten Zugangsdaten. Alle projektspezifischen Werte stehen als
`{{PLACEHOLDER}}` in den JSON-Konfigurationen.

## Manuelle Schritte für den Projekt-Owner

Copilot übernimmt die Dateikopie, liest vorhandene Projektinformationen und füllt
eindeutig belegbare Konfigurationswerte aus. Folgende Schritte muss der Owner selbst
ausführen oder verantwortliche Administratoren darum bitten:

1. **Repositories bereitstellen:** Vorlagenrepository klonen. Ein
   Kundenrepository muss der Owner bei Bedarf selbst bereitstellen und lokal
   klonen. Copilot erstellt oder initialisiert keine GitHub-Repositories und
   führt auch kein `git init` aus. Copilot im Root des Vorlagen-Clones starten
   und den Zielpfad angeben. Bestehende Projektdateien werden nicht automatisch
   committet oder gepusht.
2. **Offene Angaben klären:** Von Copilot erkannte Konflikte und Rückfragen
   beantworten, insbesondere bei mehrdeutigen Umgebungen, Publishern, Pipeline-
   oder DevOps-Status. Nicht belegbare Werte werden nicht automatisch geraten.
   Azure DevOps wird immer verwendet. Copilot ermittelt Organisation und Projekt
   zuerst über Azure-DevOps-MCP und fragt nur bei fehlendem Zugriff oder
   mehrdeutiger Zuordnung nach. Projektbezogene Leseoperationen sind ohne
   zusätzliche Freigabe erlaubt, auch in UAT/Prod. Vor Remote-Schreibaktionen
   fragt Copilot nach Freigabe für die konkrete Änderung und das Ziel.
   Keine Test-Schreibaktionen beim Setup. Der Kundenname
   (`Project.Customer`) entspricht immer dem exakten DevOps-Projektnamen;
   er wird nicht separat erfragt. Vor Pipeline-
   Recherche klärt es Vorhandensein und Nutzung der Deploymentpipelines.
   Vor Client-ID-Angaben fragt es, ob ein
   Service Principal für lokale Skripte existiert und für welche Umgebungen.
3. **Zugangsdaten lokal vervollständigen:** Vor Tenant-/Client-ID zuerst fragen,
   ob ein Service Principal existiert und für welche Umgebung(en) er vorgesehen
   ist. Eine vorhandene Power-Platform-Verbindung nicht ungeprüft als die
   Skript-Identität übernehmen. Client-IDs je Umgebung eintragen; die
   Client-Secrets nur lokal in `CrmAccess\credentials.json` des Kundenprojekts
   hinterlegen. Secrets niemals im Chat, in `*.example.json` oder in Git ablegen.
4. **Berechtigungen sicherstellen:** Nur für bestätigte Integrationen die
   benötigten Rollen einrichten: Dataverse-App-Benutzer und Service Principals
   je verwendeter Umgebung, Azure-DevOps-Zugriff sowie Pipeline-/Zielumgebungs-
   Rechte. Pipeline-/Service-Principal-Nutzung nicht voraussetzen; bei Bedarf den
   zuständigen Administrator einbeziehen.
5. **Lokale Tools anmelden:** Für `DevOps.ps1` Azure CLI installieren und sich
   separat mit `az login` anmelden. Nur für bestätigte
   lokale Pipeline-Deployments Power Platform CLI und ein PAC-Profil für den
   konfigurierten Pipeline-Host einrichten. Bei ausschließlicher Bereitstellung
   in Power Apps ist kein PAC-Profil nötig: `Deployment.PacProfile` bleibt leer.
   Andere Hilfsskripte und lesende Statusabfragen bleiben nutzbar. Geheimnisse nicht als
   Kommandozeilenargument übergeben.
6. **Ergebnis und Git prüfen:** Automatisch übernommene Werte und Dateikonflikte
   überprüfen. Sicherstellen, dass `CrmAccess\credentials.json` und
   `CrmAccess\appsettings.json` nicht bereits von Git verfolgt werden; eine
   `.gitignore` schützt keine Dateien, die schon versioniert sind.
7. **Verbindungen separat testen:** Der Setup-Skill und
   `Test-Template.ps1` arbeiten offline und bestätigen keine echten
   Berechtigungen oder Verbindungen. Bei einem ausdrücklichen Rechercheauftrag
   kann Copilot lesende Azure-DevOps-/Power-Platform-MCP-Abfragen für das
   zugeordnete Projekt und seine Umgebungen ohne weitere Bestätigung verwenden,
   auch in UAT/Prod. Verbindungen und Deployments anschließend
   separat gezielt auf Dev/Test prüfen.

Produktionsänderungen benötigen weiterhin eine ausdrückliche Freigabe im aktuellen
Auftrag. `-AllowProdWrite` allein ist keine Freigabe.

## Zentraler Einstieg nach dem Klonen

Nach dem Klonen dieses Vorlagenrepositories Copilot in dessen Root starten.
Als erste Eingabe genügt:

> Verwende project-setup für das Projekt unter `C:\Repos\Kundenprojekt`.

Ohne Pfad fragt der Skill zuerst nur nach dem Zielpfad. Das Zielverzeichnis muss
existieren. Fehlt dort ein Git-Repository, erstellt oder initialisiert Copilot
keines und prüft auch kein GitHub-Repository. Die lokalen Vorlagendateien können
trotzdem übernommen werden. Bei fehlenden Git-abgeleiteten Werten fragt Copilot
nach dem Pfad zu einem vorhandenen lokalen Projekt-Checkout. Unbeantwortete
Fragen und Platzhalter bedeuten, dass die Einrichtung unvollständig bleibt.

Der Ablauf:

1. **Bestand lesen:** Vorhandene Anweisungen, Dokumentation, Projektstruktur,
   geeignete Konfigurationsfelder und lokale Git-Metadaten im Ziel untersuchen.
2. **Dateien übernehmen:** `Initialize-Project.ps1` kopiert Instructions, Skills,
   Skripte und Beispiele. Bestehende Dateien bleiben erhalten und Unterschiede
   werden als Konflikte gemeldet; Copilot führt kompatible Inhalte gezielt zusammen.
   Die `.gitignore` wird ergänzt. Master-`.git`, lokale Master-Einstellungen und
   Zugangsdaten werden niemals kopiert.
3. **Automatisch ausfüllen:** Eindeutig belegte Werte in die lokalen
   Zielkonfigurationen übernehmen, z. B. DevOps-Organisation/Projekt aus Origin,
   Standardbranch aus lokalem Origin-HEAD, Codepfade aus der Struktur und
   Umgebungs-URLs aus expliziter Projektkonfiguration.
   Wenn der Nutzer es ausdrücklich beauftragt, das benannte Projekt zusätzlich
   mit Azure-DevOps-MCP (Projekt, Repository, Branches, Prozessstatus) und
   Power-Platform-MCP in DEV (Publisher der konkreten Solution, Pipeline, Stages)
   lesend durchsuchen. Test- und Prod-Pipeline können getrennte Namen haben.
   Bei fehlendem Zugriff oder ohne Treffer den Grund nennen
   und gezielt nachfragen. UAT/Prod dürfen projektbezogen ohne zusätzliche
   Lesefreigabe abgefragt werden; Remote-Schreibaktionen benötigen Freigabe.
4. **Offene Fragen klären:** Nach der Recherche fehlende oder widersprüchliche,
   nicht geheime Angaben in kleinen thematischen Gruppen vor der Fertigmeldung
   erfragen. Keine Kunden-, Umgebungs- oder Pipelinewerte erraten. Ein
   ClientSecret niemals im Chat erfragen oder nennen: nur direkt lokal im
   Kundenprojekt eintragen. Ohne Antworten bleibt die Einrichtung unvollständig.
5. **Offline prüfen:** Vorlage testen und verbleibende Platzhalter sowie
   notwendige lokale Schritte melden. Keine GitHub-Repository-Prüfung oder
   -Erstellung und keine Anmeldung, Schreibaktion oder Bereitstellung als
   Nebeneffekt durchführen.

Die zentrale Mastervorlage bleibt unverändert. Jeder belegte automatisch
übernommene Wert wird mit seiner lokalen Quelle ausgewiesen. Bereits befüllte
Zielwerte bleiben erhalten. Wiederholtes Setup vervollständigt das Ziel, statt
es zurückzusetzen.

Optional kann die zentrale Skill-Sammlung einmalig für andere Arbeitsverzeichnisse
registriert werden (Copilot CLI):

```powershell
copilot skill add 'C:\Pfad\zum\Vorlagen-Clone\.github\skills'
```

Das Verzeichnis registrieren, nicht nur das einzelne SKILL.md installieren:
Der Skill benötigt den zugehörigen Clone mit Skripten und Beispielkonfigurationen.
Dieser Registrierungsschritt ist nicht nötig, wenn Copilot im Vorlagen-Root läuft.
Es wird nichts automatisch in persönliche Copilot-Einstellungen installiert.

## Kopieren und Validieren ohne KI

Das Kopierskript kann auch direkt vom Vorlagen-Root ausgeführt werden:

```powershell
.\tools\copilot\Initialize-Project.ps1 -ProjectPath 'C:\Repos\Kundenprojekt'
```

Es meldet `Created`, `Unchanged`, `Preserved`, `Merged` oder `Conflict` mit relativem
Dateipfad. Es überschreibt keine Zieldateien außer der ausdrücklich ergänzten
`.gitignore`, interpretiert aber selbst keine Projektinformationen und füllt keine
Platzhalter: Analyse und Befüllung übernimmt der KI-Skill.

```powershell
pwsh -NoProfile -File 'C:\Repos\Kundenprojekt\tools\copilot\Test-Template.ps1'
```

Erst nach Einrichtung und separater Freigabe Remote-Zugriffe ausführen.
Offline-Tests sind kein Nachweis vollständiger Kundenwerte oder funktionierender
Verbindungen.

Die Beispielkonfigurationen `*.example.json` sind für die Weitergabe per Git
gedacht und bleiben unverändert. Das Kopierskript erzeugt fehlende lokale Dateien
automatisch daraus. Bei manueller Übernahme können sie ebenfalls kopiert werden:

```powershell
Copy-Item .\CrmAccess\appsettings.example.json .\CrmAccess\appsettings.json
Copy-Item .\CrmAccess\credentials.example.json .\CrmAccess\credentials.json
```

Diese Befehle nur ausführen, wenn die Zieldateien noch nicht existieren.
`appsettings.json` und `credentials.json` sind bewusst git-ignoriert.
Keine echten Kundenwerte oder Secrets in `*.example.json` eintragen.
Die Hilfsskripte lesen ausschließlich `appsettings.json`, nicht
`appsettings.Local.json`. Diese Konfiguration ist für die Hilfsskripte gedacht,
nicht als Ersatz für beliebige bestehende .NET-Appsettings.

## Dateien

| Kategorie | Pfad | Zweck |
|---|---|---|
| Instructions | `.github\copilot-instructions.md` | Projektweite Regeln, Freigaben und Konfigurationsquellen |
| Instructions | `.github\instructions\dataverse-plugins.instructions.md` | Pfadbezogene Plugin-/C#-Regeln |
| Instructions | `.github\instructions\webresources.instructions.md` | Pfadbezogene JS-/Webressourcen-Regeln |
| Skill | `.github\skills\project-setup\SKILL.md` | Interaktive Fragen, Platzhalter-Zuordnung und lokale Validierung |
| Skill | `.github\skills\devops-task\SKILL.md` | Kundenneutraler Ticketablauf |
| Skript | `tools\copilot\dv.ps1` | Dataverse-Web-API, mit Prod-Schreibschutz |
| Skript | `tools\copilot\DevOps.ps1` | Work Items, Kommentare, Zuweisungen und Status |
| Skript | `tools\copilot\Deploy-Pipeline.ps1` | Pipeline-Deployments und Status, optional separater Pipeline-Host |
| Skript | `tools\copilot\Export-Solution.ps1` | Managed-/Unmanaged-Export |
| Skript | `tools\copilot\Import-Solution.ps1` | Managed-Import als begründete Ausnahme |
| Skript | `tools\copilot\Remove-ActiveCustomization.ps1` | Active-Layer entfernen, erst nach Vergleich und Backup |
| Einrichtung | `tools\copilot\Initialize-Project.ps1` | Zentrale Übernahme ins Kundenprojekt ohne Überschreiben bestehender Dateien |
| Hilfsdatei | `tools\copilot\Common.ps1` | Konfiguration, Authentifizierung und Import-Wartefunktion |
| Offline-Tests | `tools\copilot\Test-Template.ps1` | Syntax, Platzhaltervertrag und Verhalten mit simulierten Diensten |
| Lokal | `CrmAccess\appsettings.json` | Projektwerte und Umgebungen, mit Platzhaltern vorbelegt |
| Lokal | `CrmAccess\credentials.json` | Tenant-ID sowie Client-ID/Secret je Umgebung, mit Platzhaltern vorbelegt |
| Beispiele | `CrmAccess\appsettings.example.json`, `CrmAccess\credentials.example.json` | Versionierbare, unveränderte Platzhaltervorlagen |
| Git | `.gitignore` | Lokale Konfiguration, Arbeitsdateien und Buildartefakte ausschließen |

Die beiden teilprojektspezifischen Instructions sind durch generische,
pfadbezogene Instructions ersetzt. Es werden keine kundenspezifischen Ordnernamen
vorausgesetzt. Beim Einrichten können die `applyTo`-Globs eingegrenzt werden.

## Platzhalter und Voraussetzungen

Die vollständige Fragen-/Platzhaltertabelle steht im Skill `project-setup`.
Variabel sind Kunde/Projekt/Sprache, Publisher-Präfix, vier Umgebungs-URLs,
DevOps-Organisation/Projekt/Status, Pipeline/Stages/Auth-Profil, Branch,
Codepfade/Build-/Testbefehle und die lokale App-Identität.

Standardisiert bleiben technische Werte wie API-Versionen, OAuth-Endpunkt,
Azure-DevOps-Ressourcen-ID und SOAP-Namensräume. Das sind keine Kundenwerte.
Fehlen notwendige Azure-DevOps-Angaben oder Angaben zu verwendeten Pipelines, bleibt die Einrichtung
ausdrücklich unvollständig; betroffene Skripte nicht verwenden.

- PowerShell 7 für alle Skripte; Offline-Tests benötigen keine Zusatzmodule.
- Azure CLI und lokale Anmeldung für `DevOps.ps1`; Azure DevOps wird immer verwendet.
- Dataverse-App-Benutzer mit passenden Rollen je Umgebung nur, wenn die
  bestätigte Authentifizierung Service Principals nutzt.
- Power Platform CLI und passendes Auth-Profil nur für bestätigte
  Pipeline-Deployments. Keine automatische Übergabe von ClientSecrets als
  Kommandozeilenargument.
- Token werden nicht in Dateien gecacht. API-Aufrufe authentifizieren sich erneut.
- `-AllowProdWrite` ersetzt keine ausdrückliche Freigabe im aktuellen Gespräch.
- Import-Warteprüfungen sind keine verteilte Sperre: Deployments organisatorisch
  serialisieren und keine parallelen Agents für dieselbe Pipeline verwenden.
- Pipeline-Schema, CLI-Ausgabe und Berechtigungen müssen beim ersten Kundeneinsatz
  lesend und anschließend auf Dev/Test geprüft werden. Offline-Tests ersetzen
  keinen echten Integrationstest.
