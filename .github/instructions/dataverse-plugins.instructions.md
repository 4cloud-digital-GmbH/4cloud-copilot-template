---
applyTo: "**/*.cs,**/*.csproj"
---

# Dataverse-Plugins

- Tatsaechliche Plugin-Projekte ueber `Repository.PluginPaths` in
  `CrmAccess\appsettings.json` und vorhandene Loesungsdateien ermitteln.
- Bestehende SDK-, Framework-, Registrierungs- und Paketstruktur beibehalten.
- Bei Aenderungen Plugin-Paketversion erhoehen; vorhandene README aktualisieren.
- Konfigurierten Buildbefehl pruefen, bauen und passende Tests ausfuehren.
- Keine kundenspezifischen URLs, IDs oder Geheimnisse in den Code aufnehmen.
- Registrierung oder Deployment auf Prod nur nach ausdruecklicher Freigabe.
