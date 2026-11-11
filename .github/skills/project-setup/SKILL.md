---
name: project-setup
description: Richtet aus dem zentral geklonten 4cloud-Vorlagenrepository ein D365-Kundenprojekt anhand seines Zielpfads ein. Kopiert Vorlagendateien, ermittelt Projektwerte aus vorhandenen lokalen Dateien und fragt nur fehlende oder widersprüchliche Angaben ab.
---

# Kundenprojekt vom zentralen Clone aus einrichten

Einstieg: Der Nutzer nennt zunächst nur den absoluten Pfad zum Kundenprojekt.
Die KI übernimmt Kopieren, lokale Bestandsaufnahme und das automatische Befüllen
belegbarer Platzhalter. Keine manuelle Vorabkopie verlangen. Die zentrale
Mastervorlage bleibt unverändert; keine Kundenumgebungen verändern.

## 1. Quelle und Ziel bestimmen

- Wenn der Nutzer bereits einen Zielpfad genannt hat, ihn verwenden, nicht erneut
  erfragen. Andernfalls als erste und zunächst einzige Frage: „Welcher absolute
  Pfad soll für das Kundenprojekt verwendet werden?“
- Das Verzeichnis des tatsächlich geladenen SKILL.md als Ausgangspunkt verwenden:
  `<Skill-Verzeichnis>\..\..\..` ist bei `.github\skills\project-setup`
  der Vorlagen-Root. Nicht das aktuelle
  Arbeitsverzeichnis und keinen fest eingebauten Clone-Pfad als Quelle annehmen.
- Fehlen dort `tools\copilot\Initialize-Project.ps1` oder die Beispiel-JSONs
  (etwa bei einem isoliert installierten Skill), den zentralen Clone-Pfad erfragen.
  Keine andere Quelle erraten und keinen Download starten.
- Ziel muss existieren; Quelle und Ziel dürfen weder identisch noch ineinander
  verschachtelt sein. Das Kopierskript folgt Reparse Points wie Junctions und
  OneDrive-Verknüpfungen. Vor dem Kopieren den tatsächlichen Zielpfad und die
  betroffenen Ordner prüfen; Dateien können dadurch am verknüpften Speicherort
  angelegt werden.
- Bei erneutem Setup im Kundenprojekt die schon vorhandene Konfiguration
  vervollständigen; nicht auf sich selbst kopieren. Der Selbstkopier-Schutz des
  Skripts bleibt bestehen.
- Quelle und Ziel stets explizit verwenden, insbesondere bei Git- und Testbefehlen.
  Zusätzlich nur einen vom Nutzer ausdrücklich genannten lokalen Checkout-Pfad
  untersuchen. Nicht in benachbarten Kundenordnern suchen.
- Git-Status nur ausführen, wenn im Ziel ein Repository vorhanden ist. Fehlt
  `.git`, weder `git init` ausführen noch nach GitHub-Owner/Repository fragen oder
  ein GitHub-Repository prüfen, erstellen oder initialisieren. Die Vorlagendateien
  können ins vorhandene Zielverzeichnis übernommen werden. Frage bei offenen
  Git-abhängigen Werten zuerst nach dem Pfad zu einem vorhandenen lokalen Projekt-
  Checkout; der Nutzer muss ihn selbst bereitstellen. Prüfe genau diesen Pfad.
  Ist er nicht vorhanden, melde den Pfad und frage nach dem richtigen Checkout
  oder nutze bei ausdrücklichem Auftrag die Azure-DevOps-MCP-Lesewerkzeuge für
  das vom Nutzer benannte Projekt. Keine Dateien automatisch committen oder
  pushen und kein bestehendes Remote mit lokalem Inhalt zusammenführen.

## 2. Vorhandenes Projekt zuerst lesend untersuchen

- Vor dem Kopieren Dateien und Git-Status im Ziel aufnehmen, damit ursprüngliche
  Kundeninformationen nicht mit neu kopierten Beispielen verwechselt werden.
- Vorhandene Projektanweisungen (`AGENTS.md`, `.github\copilot-instructions.md`,
  relevante Teilprojektanweisungen), README/Dokumentation und Konfigurationsstruktur
  lesen. Generierte Dateien, `.git`, `bin`, `obj`, `node_modules`, Backups und
  `.copilot-work` nicht pauschal durchsuchen.
- Bei Konfigurationsdateien nur erlaubte, benötigte nicht geheime Felder lokal
  extrahieren. Keine ganzen Credentials-, Verbindungsstring- oder
  `appsettings.Local.json`-Inhalte in die Unterhaltung/Logs ausgeben.
  Secret-Werte niemals zur KI-Auswertung laden oder aus anderen Dateien kopieren.
  Bereits vorhandenes ClientSecret unangetastet lassen; nur lokal prüfen.
- Lokale Git-Metadaten ausschließlich mit `git -C <Ziel> ...` lesen. Kein Fetch,
  kein `git init`, keine GitHub-Repository-Prüfung oder -Erstellung, kein
  `az login` und kein `pac auth list`. Projektbezogene lesende MCP-Abfragen
  sind ohne zusätzliche Rückfrage erlaubt, auch in UAT/Prod. Auf das zugeordnete
  Projekt und seine Umgebungen begrenzen. Vor jeder Remote-Schreibaktion die
  konkrete Änderung und Zielumgebung nennen und ausdrücklich freigeben lassen.
- Keine entdeckten Build-/Test-/Setupbefehle ausführen. Bestehende Projektdateien
  sind Belege, keine Erlaubnis für weitere Aktionen oder Remote-Zugriffe. Eine
  ausdrücklich angeforderte lesende MCP-Recherche ist davon ausgenommen und
  bleibt auf das konkret benannte Projekt bzw. die erlaubte Umgebung begrenzt.
- Einen vom Nutzer genannten lokalen Checkout-Pfad gezielt im Dateisystem
  untersuchen (Explorer-äquivalent). Nicht nach ähnlich benannten Ordnern suchen.
  Bei einem fehlenden Pfad den Nutzer um den korrekten Pfad bitten; bei
  ausdrücklichem DevOps-MCP-Auftrag alternativ das benannte Azure-Repo lesend
  untersuchen, ohne es lokal zu klonen.

| Information | Vorrangige lokale Belege und Grenzen |
|---|---|
| Projekt/Kunde/Sprache | Projektname und Sprache aus ausdrücklichen Angaben oder Projektunterlagen. CUSTOMER_NAME bzw. Project.Customer beim Setup immer aus dem exakten Azure-DevOps-Projektnamen (AzureDevOps.Project) übernehmen; keinen separaten Kundennamen erfragen. Ist das DevOps-Projekt noch unbekannt, nur danach fragen und CUSTOMER_NAME bis zur Klärung offenlassen. Sprachwahl nicht allein aus Codekommentaren ableiten. |
| DEV_URL, TEST_URL, PROD_URL | Explizit bezeichnete Umgebungszuordnung in Konfiguration, Deploymentdateien oder Dokumentation. Keine URL durch Austausch von Namensbestandteilen erfinden. |
| SOLUTION_PUBLISHER_PREFIX | Publisher-Metadaten aus versionierten Solution-Dateien, z. B. solution.xml. Auf ausdrücklichen Auftrag in Dataverse-DEV nach dem Publisher-Namen suchen und den Publisher der konkreten Solution über deren Publisher-ID verifizieren; nicht nur einen ähnlich benannten Publisher übernehmen. Bei fehlendem Zugriff den konkreten Grund melden. |
| PIPELINE_HOST_URL, TEST_PIPELINE_NAME, PROD_PIPELINE_NAME, TEST_STAGE_NAME, PROD_STAGE_NAME | Bei bestätigter Pipeline-Nutzung nach `deploymentpipelines` und `deploymentstages` suchen; DEV/UAT/Prod des Projekts dürfen ohne weitere Lesefreigabe geprüft werden. Test und Prod können getrennte Pipelines sein. Azure-DevOps-Buildpipelines sind nicht dieselbe Pipeline; Host nicht automatisch gleich Dev setzen. |
| DEVOPS_ORGANIZATION, DEVOPS_PROJECT | Lokale Origin-URL oder Azure-DevOps-MCP-Projekt-/Repository-Metadaten bei ausdrücklichem Auftrag. Projekt- und Work-Item-Suche auf den vom Nutzer benannten Kundenbereich eingrenzen. Legacy-visualstudio.com ebenfalls berücksichtigen. URL-Komponenten dekodieren, Benutzerinfo/Token nie ausgeben. GitHub-Remotes liefern keine DevOps-Werte. |
| DEFAULT_BRANCH | Lokales refs/remotes/origin/HEAD, Azure-DevOps-Repository-Metadaten bei ausdrücklichem Auftrag oder explizite Branch-Policy im Repo. Aktueller Feature-Branch ist kein Beleg für den Zielbranch; keinen main/master-Standard erfinden. |
| PLUGIN_PATHS, WEBRESOURCE_PATH | Tatsächlich vorhandene .sln/.slnx/.csproj, Plugin-SDK-Abhängigkeiten, Webressourcen-/Solution-Metadaten und Ordner. Nicht jedes C#-Projekt ist ein Plugin. |
| TEST_COMMAND, PLUGIN_BUILD_COMMAND | Dokumentierte Befehle, package.json-Skripte, vorhandene Test-/Buildkonfiguration. Mehrdeutige Befehle als Vorschläge markieren und bestätigen lassen; nicht zur Erkennung ausführen. |
| STATE_TODO, STATE_DOING, STATE_REVIEW, STATE_TEST, STATE_READY_FOR_PROD, STATE_DONE, STATE_CLOSED, STATE_REMOVED | Explizite Prozessbeschreibung, Konfiguration oder Statuswerte aus Azure-DevOps-MCP-Abfragen zum benannten Projekt. Status nicht aus Standardprozessen raten; zusätzliche oder mehrdeutige Status dem Nutzer zur Zuordnung vorlegen. |
| TENANT_ID, DEV_CLIENT_ID, TEST_CLIENT_ID, PROD_CLIENT_ID, HOST_CLIENT_ID, PAC_PROFILE_NAME | Erst fragen, ob ein Service Principal existiert, für lokale Skripte vorgesehen ist und für welche Umgebungen. Client-IDs nur für bestätigte Umgebungen übernehmen; HOST_CLIENT_ID nur, wenn der Pipeline-Host nicht mit dev/test/prod übereinstimmt. Niemals ClientSecrets erfragen. |

Für jeden Kandidaten intern Platzhalter, Wert, relativen Quellpfad und
JSON-Key/Abschnitt bzw. Zeile festhalten. Bestehende konkrete Zielwerte haben
Vorrang und werden nicht ersetzt. Widersprüche, mehrere passende Werte und
unsichere Ableitungen bleiben offen; bereits befüllte Werte nicht still umdeuten.
Eindeutig belegte Werte ohne weitere Eingabefrage übernehmen.

Bei ausdrücklich gewünschter MCP-Recherche:

- Azure DevOps wird in dieser Vorlage immer verwendet. Nicht nach seiner Nutzung
  fragen. Organisation und Projekt zuerst über Azure-DevOps-MCP ermitteln, nicht
  direkt beim Nutzer abfragen. Der Setup-Auftrag umfasst diese Recherche; keine
  separate Lesefreigabe für Azure DevOps erfragen. Zur Zuordnung darf
  die Projektliste gelesen werden; nur passende Projekte weiter untersuchen.
  Organisation aus der zurückgegebenen Projekt-URL ableiten. Bei mehreren
  passenden Projekten die Auswahl erfragen; bei fehlendem MCP-Zugriff den Grund
  nennen und erst dann nach fehlenden Angaben fragen.
- Projektbezogene Leseoperationen sind immer ohne weitere Rückfrage erlaubt,
  auch in Dataverse-UAT/Prod. Dies erlaubt keine Schreibaktion. Vor Remote-
  Schreiboperationen über Azure DevOps oder Power Platform stets die konkrete
  Änderung und das Ziel zur Freigabe vorlegen. Setup selbst ermittelt nur Werte;
  keine Work Items, Repositories oder Prozesse probeweise ändern.
- Vor Pipeline-Recherche zuerst fragen, ob Power-Platform-Deploymentpipelines
  vorhanden sind und verwendet werden sollen. Nicht aus Verbindungen oder
  Pipeline-Metadaten auf die Nutzung schließen. Bereits ausdrücklich beantwortete
  Fragen nicht erneut stellen.
- Vor PAC-Profil-Fragen klären, ob lokal über `Deploy-Pipeline.ps1` oder nur in
  Power Apps bereitgestellt wird. Bei Power Apps keinen PAC-Profilnamen erfragen;
  `Deployment.PacProfile` leer setzen und lokale Deployments nicht ausführen.
  Pipeline-Metadaten können weiterhin lesend geprüft werden.
- Vor Client-ID-Abfragen zuerst fragen, ob ein Service Principal existiert,
  für lokale Skripte vorgesehen ist und in welchen Umgebungen er genutzt wird.
  Eine bestehende Verbindung oder ein Pipeline-Eintrag beweist weder die
  vorgesehene Nutzung noch die Berechtigung zur Übernahme.
- Falls eine Integration nicht genutzt wird oder noch nicht existiert, nicht
  nach IDs/Profilen fragen und keine Remote-Abfrage dazu ausführen. Die
  zugehörigen Skripte als nicht eingerichtet kennzeichnen; vor einer
  alternativen Authentifizierung oder Bereitstellung separat nachfragen.
- Azure DevOps: Projekt und Repository über MCP auflösen; Branch-Standard aus
  Repository-Metadaten, Verzeichnisstruktur aus dem Repo-Baum und Statuswerte
  aus Work Items des konkreten Projekts ermitteln. Nur beobachtete Werte
  übernehmen; zusätzliche oder nicht eindeutig zuordenbare Status nachfragen.
- Power Platform: in DEV den Publisher der konkreten Solution sowie
  Deployment-Pipelines und Stages lesend abfragen. Ein leerer Treffer ist kein
  Beleg, dass eine Pipeline in einem anderen Host nicht existiert. Die bekannten
  UAT-/Prod-Umgebungen dürfen ohne weitere Lesefreigabe geprüft werden.
  Fehlende Berechtigung
  und leere Suchergebnisse klar unterscheiden.
- Service Principal: zuerst feststellen bzw. fragen, ob ein vorhandener Principal
  für die gewünschten Umgebungen vorgesehen ist. Eine vorhandene MCP-Verbindung
  ist nur ein Hinweis, keine automatische Freigabe zur Übernahme ihrer Identität.

## 3. Vorlage ins Ziel übernehmen

Vom zentralen Clone aus das Kopierskript mit absolutem Ziel aufrufen:

```powershell
& '<Vorlagen-Root>\tools\copilot\Initialize-Project.ps1' -ProjectPath '<Kundenprojekt>'
```

- Das Skript kopiert nur die festgelegten Instructions, Skills, Skripte und
  Beispiele. Es kopiert weder `.git` noch lokale Master-Konfigurationen/Secrets.
  Lokale Zielkonfigurationen entstehen ausschließlich aus den Beispiel-JSONs.
- Bestehende Dateien werden nicht überschrieben; `.gitignore` wird ergänzt.
  `Conflict`-Ergebnisse inhaltlich vergleichen und Änderungen gezielt zusammenführen.
  Projekt-README erhalten, nur bei Bedarf einen Setup-Hinweis ergänzen.
- Nicht widersprüchliche Ergänzungen übernehmen; bei fachlichen oder technischen
  Konflikten nur den betroffenen Bereich stoppen und gezielt nachfragen.
- Vorhandene fachfremde `CrmAccess\appsettings.json`-Schemas nicht umbauen.
  Kompatibilität klären; unbekannte Eigenschaften und echte Zielwerte erhalten.
- Git-Index des Ziels auf bereits getrackte lokale Konfigurationen prüfen;
  nur Dateinamen melden. Keine automatische Indexbereinigung und kein Commit.

## 4. Belegbare Platzhalter füllen, dann gezielt fragen

- Platzhalter aus Stringwerten der lokalen Ziel-JSONs mit dem Muster
  `\{\{([A-Z][A-Z0-9_]*)\}\}` ermitteln und eindeutige Namen sammeln.
  Wiederholungen eines Platzhalters müssen denselben Wert bekommen.
- Fehlende Schlüssel aus dem Beispielschema nur ergänzen, wenn die Zielkonfiguration
  kompatibel ist. Vorhandene konkrete Werte nie als Platzhalter behandeln.
- Wenn `Environments.host` dieselbe URL wie `dev`, `test` oder `prod` hat, die
  lokale `credentials.json` auf den passenden Environment-Eintrag abbilden und
  den optionalen `host`-Block entfernen; nur für einen eigenständigen Host
  separate HOST_CLIENT_ID/HOST_CLIENT_SECRET erfragen.
- Eindeutig belegte Werte strukturiert einsetzen, danach nur offene Platzhalter
  und Widersprüche erfragen. Nicht den gesamten Fragenkatalog wiederholen.
- Stelle alle noch offenen, nicht geheimen Fragen in kleinen, thematisch
  passenden Gruppen mit dem Rückfrage-/Formularwerkzeug, bevor du die Einrichtung als vollständig
  bezeichnest. Frage auch nach einem vorhandenen lokalen Checkout, falls
  Git-abgeleitete Werte fehlen; niemals nach GitHub-Owner/Repository, um eines
  anzulegen. Verwende bei einem ausdrücklich angeforderten MCP-Lookup zunächst
  die verfügbare Azure-DevOps-/Power-Platform-Lesefunktion für genau das benannte
  Projekt bzw. DEV. Fehlen Zugriffsrechte oder Suchergebnisse, nenne dies
  ausdrücklich und frage den Nutzer nach dem fehlenden Wert oder einem lokalen
  Beleg. Ohne Antwort oder bei aufgeschobenen Angaben Platzhalter belassen und
  die Einrichtung ausdrücklich als unvollständig kennzeichnen. Ein Wert darf
  nur entfallen, wenn der Nutzer bestätigt, dass er nicht anwendbar ist.
- Repository-Pfade, Testbefehle und Buildbefehle nicht als einen überladenen
  Fragenblock erfragen: zuerst Checkout/Repo-Baum und Projektdateien lesen,
  sicher erkennbare Werte übernehmen und nur die verbleibenden Punkte gezielt
  nachfragen. Mehrdeutige Befehle als Vorschlag kennzeichnen und bestätigen lassen.
- Kurz zeigen, was automatisch erkannt wurde, jeweils mit lokaler Quelle; keine
  vollständigen Konfigurationsdateien oder Geheimnisse anzeigen.
- Nutze das verfügbare Rückfrage-/Formularwerkzeug. In überschaubaren Gruppen
  fragen; bekannte Werte nicht erneut bestätigen lassen. Vorschläge ohne sicheren
  Beleg erfordern eine Bestätigung. Der folgende Katalog ist nur die Restfragenliste:

| Gruppe | Platzhalter | Fragen / Hinweise |
|---|---|---|
| Integrationen | — | Azure DevOps wird immer verwendet; nicht nach seiner Nutzung fragen. Für Power-Platform-Deploymentpipelines und Service Principals zuerst Vorhandensein und vorgesehene Nutzung klären. Nur bestätigte Integrationen weiter untersuchen. |
| Projekt | PROJECT_NAME, CUSTOMER_NAME, COMMUNICATION_LANGUAGE | Nur fehlenden Projektnamen und Kommunikationssprache erfragen. CUSTOMER_NAME immer aus AzureDevOps.Project übernehmen, nicht separat erfragen. Sprache als BCP-47-Code, z. B. de-DE. Dienstleister bleibt 4cloud digital gmbh. |
| Dataverse | DEV_URL, TEST_URL, PROD_URL | Vollständige HTTPS-Basis-URLs ohne API-Pfad, Query oder Zugangsdaten? Sind Dev/Test/Prod wirklich getrennt? |
| Lösungen | SOLUTION_PUBLISHER_PREFIX | Existierendes Publisher-Präfix? Kein neues Präfix ohne Abstimmung erfinden. |
| Pipeline | PIPELINE_HOST_URL, TEST_PIPELINE_NAME, PROD_PIPELINE_NAME, TEST_STAGE_NAME, PROD_STAGE_NAME, PAC_PROFILE_NAME | Nur wenn Pipeline-Deployments verwendet werden: Host-URL, Pipeline-Name und Stage für Test sowie Pipeline-Name und Stage für Prod; pac-Profil nur, wenn lokal eingerichtet. Host kann Dev sein. Getrennte Pipelines sind zulässig; bei derselben Pipeline müssen die Stages verschieden sein. |
| Azure DevOps | DEVOPS_ORGANIZATION, DEVOPS_PROJECT | Zuerst Azure-DevOps-MCP nutzen: Organisations-Slug aus Projekt-URL, exakten Projektnamen aus Metadaten übernehmen. Nur bei mehrdeutigen Treffern die Auswahl oder bei fehlendem Zugriff die nicht ermittelbaren Angaben erfragen. Kein separates Zugriffsformular. |
| Status | STATE_TODO, STATE_DOING, STATE_REVIEW, STATE_TEST, STATE_READY_FOR_PROD, STATE_DONE, STATE_CLOSED, STATE_REMOVED | Welche exakten Statusnamen verwendet der Prozess? Nicht vorhandene Status auf einen bestätigten existierenden Status abbilden, keine Status anlegen. TerminalStates anschließend deduplizieren. |
| Repository | DEFAULT_BRANCH, PLUGIN_PATHS, WEBRESOURCE_PATH, TEST_COMMAND, PLUGIN_BUILD_COMMAND | Zielbranch, relative Pluginpfade/Globs, Webressourcenpfad, Test- und Buildbefehl? Struktur lesend prüfen. Für nicht vorhandene Bereiche nach Bestätigung "nicht vorhanden" bzw. "nicht anwendbar" eintragen. Befehle nicht automatisch ausführen. |
| Identität | TENANT_ID, DEV_CLIENT_ID, TEST_CLIENT_ID, PROD_CLIENT_ID, HOST_CLIENT_ID | Nur wenn Service Principals für lokale Skripte verwendet werden: Tenant-ID und jeweilige App-/Client-ID je bestätigter Umgebung. HOST nur bei eigenständigem Pipeline-Host. Keine Secrets abfragen. Benötigte Dataverse-Rollen pro Umgebung bestätigen lassen. |
| Geheimnis | DEV_CLIENT_SECRET, TEST_CLIENT_SECRET, PROD_CLIENT_SECRET, HOST_CLIENT_SECRET | Nur anweisen, Secrets der bestätigten Umgebungen lokal direkt in credentials.json einzutragen; HOST nur bei eigenständigem Pipeline-Host. Niemals Secret-Werte im Chat, Formular, Kommentar oder Kommando erfragen. |

Fehlen Azure-DevOps-Angaben, sie zuerst über MCP ermitteln und nur bei fehlendem
Zugriff oder Mehrdeutigkeit nachfragen; Azure DevOps nicht als optional behandeln.
Fehlt eine Pipeline, die zugehörigen
Skripte als nicht eingerichtet kennzeichnen und nach der vorgesehenen Nutzung
fragen. Keine fiktiven URLs/Status/IDs einsetzen. Betroffene Platzhalter
stehen lassen und das Ergebnis ausdrücklich als unvollständig melden, bis der
Nutzer die offenen Fragen beantwortet oder die Nichtanwendbarkeit bestätigt hat.

## 5. Restliche Antworten anwenden

- Nur die Kundenkopie bearbeiten. JSON parsen und Werte strukturiert ersetzen,
  kein blindes Text-Replacement: Backslashes/Anführungszeichen korrekt serialisieren.
- Aus einem Clone übernommene `*.example.json` unverändert lassen. Kundenwerte
  ausschließlich in die lokalen Zielkonfigurationen schreiben.
- Für ClientSecrets Platzhalter stehen lassen, bis der Nutzer die lokalen
  Eingaben selbst bestätigt. Keine echten Secrets in Vorlagen oder Beispielen ablegen.
- `credentials.json`, `appsettings.json`, `appsettings.Local.json` und
  `.copilot-work` per `.gitignore` schützen. Bereits getrackte Dateien melden;
  nicht automatisch aus dem Index entfernen oder committen.
- Die beiden pfadbezogenen Instructions mit dem Projekt abgleichen.
  `applyTo` bei Bedarf auf die bestätigten relativen Verzeichnisse begrenzen.
- Neue, unbekannte Platzhalter ausdrücklich erfragen statt still zu ignorieren.

## 6. Lokal validieren

- Nach Prüfung des Zielskripts `pwsh -NoProfile -File
  '<Kundenprojekt>\tools\copilot\Test-Template.ps1'` ausführen:
  reine Offline-Tests ohne Login, Dataverse- oder DevOps-Aufrufe.
- Nicht geheime Konfiguration auf verbleibende Platzhalter, gültige HTTPS-URLs,
  getrennte Dev/Test/Prod-Umgebungen und verschiedene Stages prüfen.
- Tenant-ID und jede verwendete Client-ID auf GUID-Format prüfen. Secrets nur lokal auf
  vorhanden/nicht leer/kein Platzhalter prüfen, niemals den Inhalt ausgeben.
- Vorhandene Platzhalter nur mit Dateipfad und Namen melden, nicht mit
  kompletten Konfigurationsdateien oder Secret-Werten.
- Ein bestehendes pac-Profil muss separat lokal eingerichtet werden.
  Nicht automatisch `pac auth create --clientSecret ...` ausführen.
- Kein Login, kein Deployment, keine Remote-Abfrage und kein Commit/Push als
  Nebeneffekt dieses Skills.

## Abschluss

Kurz melden: Zielverzeichnis, kopierte/zusammengeführte Dateien, automatisch
befüllte Werte mit Quellen, Konflikte, Offline-Testergebnis und offene
Platzhalter/lokale Schritte. Offene Fragen vorher gezielt stellen. Erst vollständig
nennen, wenn alle Fragen geklärt, nicht anwendbare Werte bestätigt und alle Werte
einschließlich der lokal eingetragenen Zugangsdaten validiert sind.
