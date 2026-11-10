# 4cloud digital gmbh - Copilot-Vorlage fuer D365-Projekte

Kundenneutrale Vorlage fuer Dynamics 365 / Dataverse. Dieses Verzeichnis ist eine
Mastervorlage, keine fertig konfigurierte oder bereits verbundene Kundenumgebung.
Es enthaelt keine echten Zugangsdaten. Alle projektspezifischen Werte stehen als
`{{PLACEHOLDER}}` in den JSON-Konfigurationen.

## Verwendung

1. Inhalt in das Kundenrepository kopieren, einschliesslich versteckter `.github`.
   Vorhandene Dateien vergleichen und zusammenfuehren, nicht ueberschreiben.
   Die Mastervorlage nicht fuer einen einzelnen Kunden personalisieren.
2. Copilot beauftragen: **"Verwende den Skill project-setup und richte diese
   Vorlage fuer dieses Kundenprojekt ein."**
3. Der Skill fragt Projekt, URLs, Pipeline, DevOps-Prozess und Codepfade ab und
   ersetzt die Platzhalter konsistent. Ein ClientSecret niemals im Chat nennen:
   direkt lokal in `CrmAccess\credentials.json` eintragen.
4. Lokal validieren:

   ```powershell
   pwsh -NoProfile -File .\tools\copilot\Test-Template.ps1
   ```

5. Erst nach vollstaendiger Einrichtung und separater Freigabe Remote-Zugriffe
   ausfuehren. Einrichtungs-Skill und Offline-Tests verbinden sich mit keinem Dienst.

Die Beispielkonfigurationen `*.example.json` sind fuer die Weitergabe per Git
gedacht und bleiben unveraendert. Fehlen die lokalen Dateien in einer neuen Kopie:

```powershell
Copy-Item .\CrmAccess\appsettings.example.json .\CrmAccess\appsettings.json
Copy-Item .\CrmAccess\credentials.example.json .\CrmAccess\credentials.json
```

Diese Befehle nur ausfuehren, wenn die Zieldateien noch nicht existieren.
`appsettings.json` und `credentials.json` sind bewusst git-ignoriert.
Keine echten Kundenwerte oder Secrets in `*.example.json` eintragen.
Die Hilfsskripte lesen ausschliesslich `appsettings.json`, nicht
`appsettings.Local.json`. Diese Konfiguration ist fuer die Hilfsskripte gedacht,
nicht als Ersatz fuer beliebige bestehende .NET-Appsettings.

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
| Skript | `tools\copilot\Import-Solution.ps1` | Managed-Import als begruendete Ausnahme |
| Skript | `tools\copilot\Remove-ActiveCustomization.ps1` | Active-Layer entfernen, erst nach Vergleich und Backup |
| Hilfsdatei | `tools\copilot\Common.ps1` | Konfiguration, Authentifizierung und Import-Wartefunktion |
| Offline-Tests | `tools\copilot\Test-Template.ps1` | Syntax, Platzhaltervertrag und Verhalten mit simulierten Diensten |
| Lokal | `CrmAccess\appsettings.json` | Projektwerte und Umgebungen, mit Platzhaltern vorbelegt |
| Lokal | `CrmAccess\credentials.json` | Tenant-/Client-ID und Secret, mit Platzhaltern vorbelegt |
| Beispiele | `CrmAccess\appsettings.example.json`, `CrmAccess\credentials.example.json` | Versionierbare, unveraenderte Platzhaltervorlagen |
| Git | `.gitignore` | Lokale Konfiguration, Arbeitsdateien und Buildartefakte ausschliessen |

Die beiden teilprojektspezifischen Instructions sind durch generische,
pfadbezogene Instructions ersetzt. Es werden keine kundenspezifischen Ordnernamen
vorausgesetzt. Beim Einrichten koennen die `applyTo`-Globs eingegrenzt werden.

## Platzhalter und Voraussetzungen

Die vollstaendige Fragen-/Platzhaltertabelle steht im Skill `project-setup`.
Variabel sind Kunde/Projekt/Sprache, Publisher-Praefix, vier Umgebungs-URLs,
DevOps-Organisation/Projekt/Status, Pipeline/Stages/Auth-Profil, Branch,
Codepfade/Build-/Testbefehle und die lokale App-Identitaet.

Standardisiert bleiben technische Werte wie API-Versionen, OAuth-Endpunkt,
Azure-DevOps-Ressourcen-ID und SOAP-Namensraeume. Das sind keine Kundenwerte.
Fehlen Pipeline/DevOps oder andere notwendige Angaben, bleibt die Einrichtung
ausdruecklich unvollstaendig; betroffene Skripte nicht verwenden.

- PowerShell 7 fuer alle Skripte; Offline-Tests benoetigen keine Zusatzmodule.
- Azure CLI und lokale Anmeldung fuer `DevOps.ps1`.
- Dataverse-App-Benutzer mit passenden Rollen je Umgebung fuer API-Zugriffe.
- Power Platform CLI fuer Deployments; bestehendes Auth-Profil passend zum
  Pipeline-Host und dessen Berechtigungen lokal einrichten. Keine automatische
  Uebergabe des ClientSecrets als Kommandozeilenargument.
- Token werden nicht in Dateien gecacht. API-Aufrufe authentifizieren sich erneut.
- `-AllowProdWrite` ersetzt keine ausdrueckliche Freigabe im aktuellen Gespraech.
- Import-Wartepruefungen sind keine verteilte Sperre: Deployments organisatorisch
  serialisieren und keine parallelen Agents fuer dieselbe Pipeline verwenden.
- Pipeline-Schema, CLI-Ausgabe und Berechtigungen muessen beim ersten Kundeneinsatz
  lesend und anschliessend auf Dev/Test geprueft werden. Offline-Tests ersetzen
  keinen echten Integrationstest.
