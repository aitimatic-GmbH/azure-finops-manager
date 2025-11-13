# DevOpsMaintenance
# Managed Service: FinOps & Ressourcen-Optimierung

Dieses Repository enthält die technischen Grundlagen für den "Managed FinOps & Ressourcen-Optimierung"-Service. Das Ziel dieses Services ist es, die Cloud-Kosten für unsere Kunden durch **automatisierte GitHub Actions Workflows** proaktiv zu senken.

## Strategischer Ansatz

Die Lösung ist als eine Reihe von wiederverwendbaren und konfigurierbaren GitHub Actions Workflows aufgebaut.
Die gesamte Logik für Analyse und Reporting ist in den Workflow-Dateien gekapselt, um maximale Wiederholbarkeit und Sicherheit zu gewährleisten.

**Aktueller Fokus:** Die Entwicklung konzentriert sich derzeit auf die Implementierung für **Microsoft Azure**.

## Kern-Workflows

- **`1-analyze-resources.yml`**: Dieser Workflow wird manuell oder zeitgesteuert ausgelöst. Er verbindet sich sicher mit der Azure-Subscription des Kunden, führt eine Analyse zur Identifizierung von Einsparpotenzialen durch (z.B. ungenutzte Disks, überdimensionierte VMs) und speichert die Rohdaten als sicheres Workflow-Artifact.
- **`2-generate-report.yml`**: Dieser Workflow verarbeitet die vom Analyse-Workflow erstellten Artifacts und generiert einen management-tauglichen Kosten-Optimierungs-Report im Markdown-Format.

## Quick Start (Für einen neuen Kunden)

Die Implementierung des Services erfolgt vollständig über GitHub Actions.

1.  **Kunden-Onboarding:** Folgen Sie der Anleitung im **[Customer Onboarding Guide](./docs/1-customer-onboarding.md)**, um die notwendigen Azure-Credentials als GitHub Secrets für das Repository zu konfigurieren.
2.  **Analyse starten:** Lösen Sie den Workflow `1-analyze-resources.yml` manuell über die GitHub Actions UI aus ("Run workflow").
3.  **Report generieren:** Nach erfolgreichem Abschluss des Analyse-Workflows wird der Report-Workflow `2-generate-report.yml` automatisch (oder manuell) gestartet.
4.  **Ergebnis prüfen:** Der fertige Report wird als Artifact des zweiten Workflows zum Download bereitgestellt.

Detaillierte Anweisungen zur Konfiguration der Secrets und der Workflow-Parameter finden Sie im **[Customer Onboarding Guide](./docs/1-customer-onboarding.md)**.

---
**Status:** In Entwicklung | **Primäre Plattform:** Azure |
