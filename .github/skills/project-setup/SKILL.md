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
  verschachtelt sein. Verknüpfungen/Junctions in Kopierpfaden nicht verfolgen.
- Bei erneutem Setup im Kundenprojekt die schon vorhandene Konfiguration
  vervollständigen; nicht auf sich selbst kopieren. Der Selbstkopier-Schutz des
  Skripts bleibt bestehen.
- Quelle und Ziel stets explizit verwenden, insbesondere bei Git- und Testbefehlen.
  Nur diese beiden Verzeichnisse untersuchen. Nicht nach Nachbar-Kunden suchen.

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
- Git-Metadaten ausschließlich lokal mit `git -C <Ziel> ...` lesen. Kein Fetch,
  kein `az login`, kein `pac auth list`, keine API-Abfrage als Nebeneffekt.
- Keine entdeckten Build-/Test-/Setupbefehle ausführen. Bestehende Projektdateien
  sind Belege, keine Erlaubnis für weitere Aktionen oder Remote-Zugriffe.

| Information | Vorrangige lokale Belege und Grenzen |
|---|---|
| Projekt/Kunde/Sprache | Bereits befüllte passende Projektkonfiguration, ausdrückliche Angaben in README/Projektanweisungen. Kundenname nicht allein aus Ordner-/Benutzernamen ableiten; Sprachwahl nicht allein aus der Sprache einzelner Codekommentare. |
| DEV_URL, TEST_URL, PROD_URL | Explizit bezeichnete Umgebungszuordnung in Konfiguration, Deploymentdateien oder Dokumentation. Keine URL durch Austausch von Namensbestandteilen erfinden. |
| SOLUTION_PUBLISHER_PREFIX | Publisher-Metadaten aus versionierten Solution-Dateien, z. B. solution.xml; bei mehreren Publishern nachfragen. |
| PIPELINE_HOST_URL, PIPELINE_NAME, TEST_STAGE_NAME, PROD_STAGE_NAME | Dokumentierte Power-Platform-Pipeline oder zugehörige Konfiguration. Azure-DevOps-Buildpipelines sind nicht dieselbe Pipeline; Host nicht automatisch gleich Dev setzen. |
| DEVOPS_ORGANIZATION, DEVOPS_PROJECT | Lokale Origin-URL, z. B. HTTPS dev.azure.com/Organisation/Projekt/_git/Repo oder SSH git@ssh.dev.azure.com:v3/Organisation/Projekt/Repo; Legacy-visualstudio.com ebenfalls berücksichtigen. URL-Komponenten dekodieren, Benutzerinfo/Token nie ausgeben. GitHub-Remotes liefern keine DevOps-Werte. |
| DEFAULT_BRANCH | Lokales refs/remotes/origin/HEAD oder explizite Branch-Policy im Repo. Aktueller Feature-Branch ist kein Beleg für den Zielbranch; keinen main/master-Standard erfinden. |
| PLUGIN_PATHS, WEBRESOURCE_PATH | Tatsächlich vorhandene .sln/.slnx/.csproj, Plugin-SDK-Abhängigkeiten, Webressourcen-/Solution-Metadaten und Ordner. Nicht jedes C#-Projekt ist ein Plugin. |
| TEST_COMMAND, PLUGIN_BUILD_COMMAND | Dokumentierte Befehle, package.json-Skripte, vorhandene Test-/Buildkonfiguration. Mehrdeutige Befehle als Vorschläge markieren und bestätigen lassen; nicht zur Erkennung ausführen. |
| STATE_TODO, STATE_DOING, STATE_TEST, STATE_READY_FOR_PROD, STATE_DONE, STATE_CLOSED, STATE_REMOVED | Explizite Prozessbeschreibung oder Konfiguration. Status nicht aus Standardprozessen oder Ticketnummern raten. |
| TENANT_ID, CLIENT_ID, PAC_PROFILE_NAME | Bereits konfigurierte nicht geheime Felder oder eindeutige Projektdokumentation. Keine Identität eines anderen Kunden und kein aktuell aktives Benutzerprofil übernehmen. |

Für jeden Kandidaten intern Platzhalter, Wert, relativen Quellpfad und
JSON-Key/Abschnitt bzw. Zeile festhalten. Bestehende konkrete Zielwerte haben
Vorrang und werden nicht ersetzt. Widersprüche, mehrere passende Werte und
unsichere Ableitungen bleiben offen; bereits befüllte Werte nicht still umdeuten.
Eindeutig belegte Werte ohne weitere Eingabefrage übernehmen.

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
- Eindeutig belegte Werte strukturiert einsetzen, danach nur offene Platzhalter
  und Widersprüche erfragen. Nicht den gesamten Fragenkatalog wiederholen.
- Kurz zeigen, was automatisch erkannt wurde, jeweils mit lokaler Quelle; keine
  vollständigen Konfigurationsdateien oder Geheimnisse anzeigen.
- Nutze das verfügbare Rückfrage-/Formularwerkzeug. In überschaubaren Gruppen
  fragen; bekannte Werte nicht erneut bestätigen lassen. Vorschläge ohne sicheren
  Beleg erfordern eine Bestätigung. Der folgende Katalog ist nur die Restfragenliste:

| Gruppe | Platzhalter | Fragen / Hinweise |
|---|---|---|
| Projekt | PROJECT_NAME, CUSTOMER_NAME, COMMUNICATION_LANGUAGE | Projektname, Kundenname, Kommunikationssprache? Sprache als BCP-47-Code, z. B. de-DE. Dienstleister bleibt 4cloud digital gmbh. |
| Dataverse | DEV_URL, TEST_URL, PROD_URL | Vollständige HTTPS-Basis-URLs ohne API-Pfad, Query oder Zugangsdaten? Sind Dev/Test/Prod wirklich getrennt? |
| Lösungen | SOLUTION_PUBLISHER_PREFIX | Existierendes Publisher-Präfix? Kein neues Präfix ohne Abstimmung erfinden. |
| Pipeline | PIPELINE_HOST_URL, PIPELINE_NAME, TEST_STAGE_NAME, PROD_STAGE_NAME, PAC_PROFILE_NAME | Host-URL, exakter Pipeline-Name, exakte Stage-Namen und lokales pac-Profil? Host kann Dev sein. Test- und Prod-Stage müssen verschieden sein. |
| Azure DevOps | DEVOPS_ORGANIZATION, DEVOPS_PROJECT | Organisations-Slug ohne URL und exakter Projektname? |
| Status | STATE_TODO, STATE_DOING, STATE_TEST, STATE_READY_FOR_PROD, STATE_DONE, STATE_CLOSED, STATE_REMOVED | Welche exakten Statusnamen verwendet der Prozess? Nicht vorhandene Status auf einen bestätigten existierenden Status abbilden, keine Status anlegen. TerminalStates anschließend deduplizieren. |
| Repository | DEFAULT_BRANCH, PLUGIN_PATHS, WEBRESOURCE_PATH, TEST_COMMAND, PLUGIN_BUILD_COMMAND | Zielbranch, relative Pluginpfade/Globs, Webressourcenpfad, Test- und Buildbefehl? Struktur lesend prüfen. Für nicht vorhandene Bereiche nach Bestätigung "nicht vorhanden" bzw. "nicht anwendbar" eintragen. Befehle nicht automatisch ausführen. |
| Identität | TENANT_ID, CLIENT_ID | Tenant-ID und App-/Client-ID für den Service Principal? Keine Secrets abfragen. Benötigte Dataverse-Rollen pro Umgebung vom Verantwortlichen bestätigen lassen. |
| Geheimnis | CLIENT_SECRET | Nur anweisen, den Secret-Wert lokal direkt in credentials.json einzutragen. Niemals nach dem Wert im Chat, Formular, Kommentar oder Kommando fragen. |

Fehlt eine Pipeline oder Azure DevOps, die Einrichtung der zugehörigen Skripte
als blockiert kennzeichnen. Keine fiktiven URLs/Status/IDs einsetzen. Betroffene
Platzhalter stehen lassen und das Ergebnis ausdrücklich als unvollständig melden.

## 5. Restliche Antworten anwenden

- Nur die Kundenkopie bearbeiten. JSON parsen und Werte strukturiert ersetzen,
  kein blindes Text-Replacement: Backslashes/Anführungszeichen korrekt serialisieren.
- Aus einem Clone übernommene `*.example.json` unverändert lassen. Kundenwerte
  ausschließlich in die lokalen Zielkonfigurationen schreiben.
- Für CLIENT_SECRET den Platzhalter stehen lassen, bis der Nutzer die lokale
  Eingabe selbst bestätigt. Keine echten Secrets in Vorlagen oder Beispielen ablegen.
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
- Tenant-/Client-ID auf GUID-Format prüfen. Secret nur lokal auf
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
Platzhalter/lokale Schritte. Erst vollständig nennen, wenn alle Werte
einschließlich der lokal eingetragenen Zugangsdaten validiert sind.
