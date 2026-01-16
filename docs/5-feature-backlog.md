# Technisches Backlog & Zukünftige Features

Dieses Dokument dient als Sammlung für geplante, aber noch nicht implementierte Analyse-Module und Feature-Erweiterungen. Es stellt sicher, dass Ideen nicht verloren gehen und dient als Grundlage für zukünftige Entwicklungs-Sprints.

---

## Geplante Analyse-Module (Priorität 1)

Diese Module waren Teil des ursprünglichen Architektur-Konzepts und stellen die nächsten logischen Implementierungsschritte dar.

### Modul: Verwaiste Ressourcen
-   [ ] **Verwaiste Netzwerkschnittstellen (Detached NICs)**
    -   **Ziel:** Finde Netzwerkkarten, die keiner VM mehr zugeordnet sind.
    -   **Logik:** `az network nic list --query "[?virtualMachine==null]"`

### Modul: Überdimensionierte Ressourcen (Right-Sizing)
-   [ ] **Unterausgelastete App Service Pläne**
    -   **Ziel:** Finde App Service Pläne, die konstant überdimensioniert sind.
    -   **Logik:** Abfrage von Azure Monitor Metriken für `CpuPercentage` und `MemoryPercentage`.

### Modul: Ungenutzte oder veraltete Ressourcen
-   [ ] **Leere Ressourcengruppen**
    -   **Ziel:** Finde Ressourcengruppen, die keine Ressourcen mehr enthalten.
    -   **Logik:** Iteriere durch `az group list` und prüfe mit `az resource list --resource-group`.

### Modul: Sicherheit & Konfiguration
-   [ ] **Veraltete App Service TLS/SSL-Einstellungen**
    -   **Ziel:** Finde App Services, die noch unsichere TLS-Versionen erlauben.
    -   **Logik:** `az webapp list --query "[?httpsSettings.minTlsVersion!='1.2']"`

---

## Mögliche zukünftige Analyse-Module (Ideenspeicher )

Diese Module sind Ideen für eine spätere Weiterentwicklung und wurden noch nicht fest eingeplant.

-   [ ] **Überdimensionierte SQL-Datenbanken:** Identifiziere SQL-Datenbanken mit konstant niedriger DTU- oder vCore-Nutzung.
-   [ ] **Premium Storage für Standard-VMs:** Finde VMs ohne Premium-Support (z.B. B-Serie), deren OS-Disk auf teurem Premium-SSD-Speicher liegt.
-   [ ] **Nicht genutzte ExpressRoute- oder VPN-Gateways:** Identifiziere teure Netzwerk-Gateways mit sehr geringem Datenverkehr.
-   [ ] **Speicherkonten ohne HTTPS-Zwang:** Finde Storage Accounts, bei denen die sichere Übertragung nicht erzwungen wird.
-   [ ] **Classic-Ressourcen (veraltet):** Finde veraltete "Classic"-Ressourcen, die auf das modernere ARM-Modell migriert werden sollten.
-   [ ] **Verwaiste Network Security Groups (NSGs):** Finde NSGs, die keiner Subnetz- oder Netzwerkschnittstelle zugeordnet sind.
-   [ ] **Gestoppte (aber nicht deallozierte) VMs:** Finde VMs im Status "Gestoppt", die weiterhin unnötig Rechenkosten verursachen.

---

## Roadmap für System-Erweiterungen

Dieser Abschnitt beschreibt geplante und mögliche Erweiterungen der Kernfunktionalität des Systems.

### Geplante Erweiterungen (Priorität 1)

-   [ ] **Scheduler für automatische Analyse:** Implementierung eines `schedule`-Triggers im `0-main-workflow.yml`, um die Analyse (z.B. wöchentlich) automatisch auszuführen.
-   [ ] **Erweiterte Remediation-Optionen:** Hinzufügen von "Right-Sizing"-Aktionen im Remediate-Workflow (z.B. `az vm resize`), nicht nur Deallokierung.

### Mögliche zukünftige Erweiterungen (Ideenspeicher)

-   [ ] **Budget-Alerts:** Ein Modul, das `az consumption budget`-Warnungen auswertet und in den Report integriert.
-   [ ] **Tag-basierte Filterung:** Ermögliche das Ausschließen von Ressourcen basierend auf spezifischen Azure-Tags (z.B. `finops-ignore=true`).
-   [ ] **Grafische Auswertungen im Report:** Anreicherung des Markdown-Reports um visuelle Elemente.
    -   *Mögliche Umsetzung:* Die Generierung von Diagrammen könnte beispielsweise durch `mermaid`-Syntax direkt im Markdown erfolgen, um die Kostenverteilung pro Ressourcentyp oder das Einsparpotenzial zu visualisieren.

