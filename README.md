# Managed FinOps Service für Azure

Dieses Repository enthält die technischen Grundlagen für den "Managed FinOps & Ressourcen-Optimierung"-Service. Das Ziel dieses Services ist es, die Cloud-Kosten für unsere Kunden durch **automatisierte und konfigurierbare GitHub Actions Workflows** proaktiv zu senken.

## Strategischer Ansatz

Die Lösung ist als ein einziger, robuster GitHub Actions Workflow aufgebaut, der sich über eine zentrale Konfigurationsdatei (`finops.config.json`) steuern lässt. Dieser Ansatz gewährleistet maximale Sicherheit, Wiederholbarkeit und einfache Anpassbarkeit für den Kunden.

**Aktueller Fokus:** Die Entwicklung konzentriert sich derzeit auf die Implementierung für **Microsoft Azure**.

## Kern-Workflow: `1-analyze-and-report.yml`

Dieser zentrale Workflow führt den gesamten Prozess in zwei logischen, voneinander getrennten Jobs aus:

1.  **`analyze` Job**:
    *   Wird manuell (`workflow_dispatch`) oder bei Code-Änderungen (`push`) ausgelöst.
    *   Verbindet sich sicher über eine passwortlose OIDC-Verbindung mit der Azure-Subscription des Kunden (nur Leserechte).
    *   Führt die in `finops.config.json` aktivierten Analyse-Module aus (z.B. ungenutzte Disks, alte Snapshots, Advisor-Empfehlungen).
    *   Speichert die Rohdaten als sicheres Workflow-Artefakt.

2.  **`report` Job**:
    *   Startet automatisch nach dem erfolgreichen Abschluss des `analyze`-Jobs.
    *   Lädt die Analyse-Rohdaten herunter.
    *   Generiert einen management-tauglichen Kosten-Optimierungs-Report im Markdown-Format.

Ein separater Workflow, **`2-remediate-resources.yml`**, existiert für die optionale, manuelle Bereinigung der gefundenen Ressourcen und erfordert separate, erhöhte Berechtigungen.

## Quick Start

1.  **Azure-Anmeldedaten einrichten:** Folgen Sie der Anleitung im **[Customer Onboarding Guide](./docs/1-customer-onboarding.md)**, um die notwendigen Azure-Credentials als GitHub Secrets zu konfigurieren.
2.  **Analyse konfigurieren:** Passen Sie die Datei **`finops.config.json`** an Ihre Bedürfnisse an. Aktivieren/deaktivieren Sie Module und definieren Sie Ressourcengruppen, die von der Analyse ausgeschlossen werden sollen.
3.  **Workflow starten:** Lösen Sie den Workflow **`1 - Analyze and Report`** manuell über die GitHub Actions UI aus ("Run workflow").
4.  **Ergebnis prüfen:** Nach Abschluss des Laufs finden Sie den fertigen Bericht (`finops-cost-report.md`) im Artefakt-Bereich des Workflow-Laufs zum Download.

---

## Lizenz

Dieses Projekt ist unter der [MIT License](LICENSE) lizenziert.

Copyright (c) 2026 aitimatic GmbH

## Disclaimer

**Dieses Repository wird "as-is" ohne jegliche Garantie bereitgestellt.**

Die Nutzung erfolgt auf eigenes Risiko. Wir übernehmen keine Haftung für Schäden, die durch die Verwendung dieses Codes entstehen.

Für Details siehe [LICENSE](LICENSE) und [SECURITY.md](SECURITY.md).

---
**Status:** In Entwicklung | **Primäre Plattform:** Azure | **Konfiguration:** `finops.config.json`
