---
applyTo: "**/*.js,**/*.ts,**/*.cjs,**/*.html"
---

# Dataverse-Webressourcen

- Relevanz fuer Dataverse zuerst pruefen; Quellpfad steht unter
  `Repository.WebResourcePath` in `CrmAccess\appsettings.json`.
- Bestehende Formular-/Ribbon-Patterns, Namen und Lokalisierung beibehalten.
- Unterstuetzte Client-API verwenden; keine fest codierten Umgebungs-URLs.
- Regressionstest fuer geaenderte Logik ergaenzen; `Repository.TestCommand`
  pruefen und ausfuehren, sofern fuer diese Aenderung passend.
- Vor Upload Repo, Dev, Test und Prod sowie Active-Layer vergleichen.
- Nur eigene Komponenten gezielt veroeffentlichen. Prod nur nach Freigabe.
