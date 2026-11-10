---
name: project-setup
description: Richtet die wiederverwendbare 4cloud-Copilot-Vorlage fuer ein D365-Kundenprojekt ein. Verwenden bei Projekt einrichten, Vorlage konfigurieren, Kunde onboarden oder nicht ausgefuellten Platzhaltern.
---

# Kundenprojekt interaktiv einrichten

Ziel: alle Projektplatzhalter konsistent ersetzen, ohne Geheimnisse im Gespraech
abzufragen und ohne Kundenumgebungen zu veraendern.

## 1. Bestand und Ziel pruefen

- `.github\copilot-instructions.md`, `README.md` und die beiden JSON-Dateien unter
  `CrmAccess` lesen. Geheimnisse nicht ausgeben, falls bereits echte Werte vorliegen.
- Fragen, ob dies eine unveraenderte Mastervorlage oder eine Kundenkopie ist.
  Mastervorlage nicht personalisieren; Ziel fuer eine Kundenkopie erfragen.
- Vorhandene Kunden-Dateien und Ignore-Regeln nicht ueberschreiben. Konflikte zeigen
  (ohne Geheimnisse) und Entscheidung einholen.
- Platzhalter aus Stringwerten der JSON-Dateien mit dem Muster
  `\{\{([A-Z][A-Z0-9_]*)\}\}` ermitteln und eindeutige Namen sammeln.
  Wiederholungen eines Platzhalters muessen denselben Wert bekommen.

## 2. Fragen stellen

Nutze das verfuegbare Rueckfrage-/Formularwerkzeug; ansonsten stelle die Fragen
direkt und warte auf Antworten. In ueberschaubaren Gruppen fragen, nicht raten.
Bereits bestaetigte Werte uebernehmen; Aenderungen daran separat bestaetigen.

| Gruppe | Platzhalter | Fragen / Hinweise |
|---|---|---|
| Projekt | PROJECT_NAME, CUSTOMER_NAME, COMMUNICATION_LANGUAGE | Projektname, Kundenname, Kommunikationssprache? Sprache als BCP-47-Code, z. B. de-DE. Dienstleister bleibt 4cloud digital gmbh. |
| Dataverse | DEV_URL, TEST_URL, PROD_URL | Vollstaendige HTTPS-Basis-URLs ohne API-Pfad, Query oder Zugangsdaten? Sind Dev/Test/Prod wirklich getrennt? |
| Loesungen | SOLUTION_PUBLISHER_PREFIX | Existierendes Publisher-Praefix? Kein neues Praefix ohne Abstimmung erfinden. |
| Pipeline | PIPELINE_HOST_URL, PIPELINE_NAME, TEST_STAGE_NAME, PROD_STAGE_NAME, PAC_PROFILE_NAME | Host-URL, exakter Pipeline-Name, exakte Stage-Namen und lokales pac-Profil? Host kann Dev sein. Test- und Prod-Stage muessen verschieden sein. |
| Azure DevOps | DEVOPS_ORGANIZATION, DEVOPS_PROJECT | Organisations-Slug ohne URL und exakter Projektname? |
| Status | STATE_TODO, STATE_DOING, STATE_TEST, STATE_READY_FOR_PROD, STATE_DONE, STATE_CLOSED, STATE_REMOVED | Welche exakten Statusnamen verwendet der Prozess? Nicht vorhandene Status auf einen bestaetigten existierenden Status abbilden, keine Status anlegen. TerminalStates anschliessend deduplizieren. |
| Repository | DEFAULT_BRANCH, PLUGIN_PATHS, WEBRESOURCE_PATH, TEST_COMMAND, PLUGIN_BUILD_COMMAND | Zielbranch, relative Pluginpfade/Globs, Webressourcenpfad, Test- und Buildbefehl? Struktur lesend pruefen. Fuer nicht vorhandene Bereiche nach Bestaetigung "nicht vorhanden" bzw. "nicht anwendbar" eintragen. Befehle nicht automatisch ausfuehren. |
| Identitaet | TENANT_ID, CLIENT_ID | Tenant-ID und App-/Client-ID fuer den Service Principal? Keine Secrets abfragen. Benoetigte Dataverse-Rollen pro Umgebung vom Verantwortlichen bestaetigen lassen. |
| Geheimnis | CLIENT_SECRET | Nur anweisen, den Secret-Wert lokal direkt in credentials.json einzutragen. Niemals nach dem Wert im Chat, Formular, Kommentar oder Kommando fragen. |

Fehlt eine Pipeline oder Azure DevOps, die Einrichtung der zugehoerigen Skripte
als blockiert kennzeichnen. Keine fiktiven URLs/Status/IDs einsetzen. Betroffene
Platzhalter stehen lassen und das Ergebnis ausdruecklich als unvollstaendig melden.

## 3. Antworten anwenden

- Zusammenfassung aller nicht geheimen Zuordnungen zeigen und bestaetigen lassen.
- Nur die Kundenkopie bearbeiten. JSON parsen und Werte strukturiert ersetzen,
  kein blindes Text-Replacement: Backslashes/Anfuehrungszeichen korrekt serialisieren.
- Fuer CLIENT_SECRET den Platzhalter stehen lassen, bis der Nutzer die lokale
  Eingabe selbst bestaetigt. Keine echten Secrets in Vorlagen oder Beispielen ablegen.
- `credentials.json`, `appsettings.json`, `appsettings.Local.json` und
  `.copilot-work` per `.gitignore` schuetzen. Bereits getrackte Dateien melden;
  nicht automatisch aus dem Index entfernen oder committen.
- Die beiden pfadbezogenen Instructions mit dem Projekt abgleichen.
  `applyTo` bei Bedarf auf die bestaetigten relativen Verzeichnisse begrenzen.
- Neue, unbekannte Platzhalter ausdruecklich erfragen statt still zu ignorieren.

## 4. Lokal validieren

- `pwsh -NoProfile -File .\tools\copilot\Test-Template.ps1` ausfuehren:
  reine Offline-Tests ohne Login, Dataverse- oder DevOps-Aufrufe.
- Nicht geheime Konfiguration auf verbleibende Platzhalter, gueltige HTTPS-URLs,
  getrennte Dev/Test/Prod-Umgebungen und verschiedene Stages pruefen.
- Tenant-/Client-ID auf GUID-Format pruefen. Secret nur lokal auf
  vorhanden/nicht leer/kein Platzhalter pruefen, niemals den Inhalt ausgeben.
- Vorhandene Platzhalter nur mit Dateipfad und Namen melden, nicht mit
  kompletten Konfigurationsdateien oder Secret-Werten.
- Ein bestehendes pac-Profil muss separat lokal eingerichtet werden.
  Nicht automatisch `pac auth create --clientSecret ...` ausfuehren.
- Kein Login, kein Deployment, keine Remote-Abfrage und kein Commit/Push als
  Nebeneffekt dieses Skills.

## Abschluss

Kurz melden: Zielverzeichnis, konfigurierte Bereiche, Offline-Testergebnis und
offene Platzhalter/lokale Schritte. Erst vollstaendig nennen, wenn alle Werte
einschliesslich der lokal eingetragenen Zugangsdaten validiert sind.
