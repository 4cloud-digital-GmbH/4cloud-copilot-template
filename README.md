# 4cloud digital gmbh - Copilot-Vorlage für D365-Projekte

Kundenneutrale Vorlage für Dynamics 365 / Dataverse. Dieses Verzeichnis ist eine
Mastervorlage, keine fertig konfigurierte oder bereits verbundene Kundenumgebung.
Es enthält keine echten Zugangsdaten. Alle projektspezifischen Werte stehen als
`{{PLACEHOLDER}}` in den JSON-Konfigurationen.

## Zentraler Einstieg nach dem Klonen

Nach dem Klonen dieses Vorlagenrepositories Copilot in dessen Root starten.
Als erste Eingabe genügt:

> Verwende project-setup für das Projekt unter `C:\Repos\Kundenprojekt`.

Ohne Pfad fragt der Skill zuerst nur nach dem Zielpfad. Das Kundenrepository muss
bereits geklont sein bzw. das Zielverzeichnis existieren. Du musst keine
Vorlagendateien vorab manuell in das Kundenprojekt kopieren.

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
4. **Nur Restfragen stellen:** Fehlende oder widersprüchliche Angaben gebündelt
   erfragen. Keine Kunden-, Umgebungs- oder Pipelinewerte erraten. Ein ClientSecret
   niemals im Chat nennen: nur direkt lokal im Kundenprojekt eintragen.
5. **Offline prüfen:** Vorlage testen, verbleibende Platzhalter und notwendige
   lokale Schritte melden. Keine Anmeldung oder Remote-Abfrage durchführen.

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
| Lokal | `CrmAccess\credentials.json` | Tenant-/Client-ID und Secret, mit Platzhaltern vorbelegt |
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
Fehlen Pipeline/DevOps oder andere notwendige Angaben, bleibt die Einrichtung
ausdrücklich unvollständig; betroffene Skripte nicht verwenden.

- PowerShell 7 für alle Skripte; Offline-Tests benötigen keine Zusatzmodule.
- Azure CLI und lokale Anmeldung für `DevOps.ps1`.
- Dataverse-App-Benutzer mit passenden Rollen je Umgebung für API-Zugriffe.
- Power Platform CLI für Deployments; bestehendes Auth-Profil passend zum
  Pipeline-Host und dessen Berechtigungen lokal einrichten. Keine automatische
  Übergabe des ClientSecrets als Kommandozeilenargument.
- Token werden nicht in Dateien gecacht. API-Aufrufe authentifizieren sich erneut.
- `-AllowProdWrite` ersetzt keine ausdrückliche Freigabe im aktuellen Gespräch.
- Import-Warteprüfungen sind keine verteilte Sperre: Deployments organisatorisch
  serialisieren und keine parallelen Agents für dieselbe Pipeline verwenden.
- Pipeline-Schema, CLI-Ausgabe und Berechtigungen müssen beim ersten Kundeneinsatz
  lesend und anschließend auf Dev/Test geprüft werden. Offline-Tests ersetzen
  keinen echten Integrationstest.
