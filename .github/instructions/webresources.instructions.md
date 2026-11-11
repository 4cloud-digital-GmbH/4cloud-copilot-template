---
applyTo: "**/*.js,**/*.ts,**/*.cjs,**/*.html"
---

# Dataverse-Webressourcen

- Relevanz für Dataverse zuerst prüfen; Quellpfad steht unter
  `Repository.WebResourcePath` in `CrmAccess\appsettings.json`.
- Bestehende Formular-/Ribbon-Patterns, Namen und Lokalisierung beibehalten.
- Unterstützte Client-API verwenden; keine fest codierten Umgebungs-URLs.
- Regressionstest für geänderte Logik ergänzen; `Repository.TestCommand`
  prüfen und ausführen, sofern für diese Änderung passend.
- Vor Upload Repo, Dev, Test und Prod sowie Active-Layer vergleichen.
- Nur eigene Komponenten gezielt veröffentlichen. Prod nur nach Freigabe.
