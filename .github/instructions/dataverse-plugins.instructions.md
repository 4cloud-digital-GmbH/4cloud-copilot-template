---
applyTo: "**/*.cs,**/*.csproj"
---

# Dataverse-Plugins

- Tatsächliche Plugin-Projekte über `Repository.PluginPaths` in
  `CrmAccess\appsettings.json` und vorhandene Lösungsdateien ermitteln.
- Bestehende SDK-, Framework-, Registrierungs- und Paketstruktur beibehalten.
- Bei Änderungen Plugin-Paketversion erhöhen; vorhandene README aktualisieren.
- Konfigurierten Buildbefehl prüfen, bauen und passende Tests ausführen.
- Keine kundenspezifischen URLs, IDs oder Geheimnisse in den Code aufnehmen.
- Registrierung oder Deployment auf Prod nur nach ausdrücklicher Freigabe.
