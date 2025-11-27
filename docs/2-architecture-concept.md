# Architektur-Konzept: Managed FinOps Service

**Dokumenten-ID:** `INT-ARCH-FINOPS-V1.0`   
**Status:** Entwurf   
**Datum:** 26.11.2025   

## 1. Vision & Leitprinzipien

### 1.1 Vision

Dieses Dokument beschreibt die technische Architektur des "Managed FinOps & Ressourcen-Optimierung"-Service. Das Ziel des Services ist es, die Azure-Cloud-Kosten für unsere Kunden proaktiv, sicher und nachvollziehbar durch einen hohen Automatisierungsgrad zu senken.

### 1.2 Leitprinzipien der Architektur

Die gesamte Lösung basiert auf den folgenden, nicht verhandelbaren Prinzipien, um maximale Sicherheit, Transparenz und Wiederholbarkeit zu gewährleisten.

*   **Workflow-First:** Die gesamte Logik ist in GitHub Actions Workflows gekapselt. Es gibt keine Abhängigkeiten zu externen Servern oder manuellen lokalen Ausführungen.
*   **Garantierte Ausführung:** Die Automatisierung ist so konzipiert, dass sie bei korrekter Konfiguration garantiert und vorhersagbar läuft. Die Ausführungsumgebung (`ubuntu-latest`) ist standardisiert und nicht von lokalen Maschinen abhängig.
*   **Sicherheit durch minimale Berechtigungen (Least Privilege):** Jeder Workflow erhält nur die minimal notwendigen Berechtigungen für seine spezifische Aufgabe. Lesende und schreibende/löschende Operationen sind strikt getrennt.
*   **Sicherheit durch explizite Trigger:** Automatisierte, ändernde Eingriffe in die Kundenumgebung sind ausgeschlossen. Jede potenziell destruktive Aktion erfordert einen expliziten, manuellen Trigger durch einen autorisierten Benutzer.
*   **Transparenz und Auditierbarkeit:** Jeder Schritt, jede Analyse und jede Änderung wird protokolliert und ist über die GitHub Actions Logs und die erzeugten Artifacts jederzeit nachvollziehbar.

---

## 2. Gesamtarchitektur: Die 3-Workflow-Kette

Die Service-Architektur besteht aus einer Kette von drei spezialisierten und voneinander entkoppelten GitHub Actions Workflows. Jeder Workflow hat eine klar definierte Aufgabe und übergibt sein Ergebnis über Workflow-Artifacts an den nächsten Schritt.

**Diagramm des Prozesses:**
`[Manueller Trigger] -> [Workflow 1: Analyse] -> (Artifact: Rohdaten) -> [Workflow 2: Reporting] -> (Artifact: Report) -> [Manueller Trigger mit Genehmigung] -> [Workflow 3: Remediation] -> (Artifact: Audit-Log)`

### 2.1 Workflow 1: Analyse (`1-analyze-resources.yml`)

*   **Zweck:** Führt ausschließlich lesende Operationen auf der Azure-Subscription des Kunden durch, um Einsparpotenziale zu identifizieren. Dieser Workflow nimmt **niemals** Änderungen vor.
*   **Trigger:**
    *   **Manuell (`workflow_dispatch`):** Für Ad-hoc-Analysen.
    *   **Zeitgesteuert (`schedule`):** Für regelmäßige, wöchentliche oder monatliche Scans.
*   **Authentifizierung:** Nutzt OpenID Connect (OIDC) für eine passwortlose Anmeldung bei Azure mit einer dedizierten App-Registrierung, die ausschließlich **"Leser" (Reader)**-Berechtigungen besitzt.
*   **Output:** Erstellt für jedes Analyse-Modul eine separate Rohdaten-Datei (z.B. `.tsv`) und lädt alle gefundenen Dateien als einzelnes Workflow-Artifact mit dem Namen `finops-analysis-results` hoch.

### 2.2 Workflow 2: Reporting (`2-generate-report.yml`)

*   **Zweck:** Verarbeitet die vom Analyse-Workflow bereitgestellten Rohdaten und wandelt sie in einen menschenlesbaren, management-tauglichen Bericht im Markdown-Format um.
*   **Trigger:**
    *   **Automatisch (`workflow_run`):** Startet automatisch, sobald ein Lauf des Workflows "1 - Analyze Azure Resources" erfolgreich abgeschlossen wurde.
*   **Authentifizierung:** Benötigt keine Azure-Berechtigungen.
*   **Output:** Erstellt eine `report.md`-Datei und lädt diese als Workflow-Artifact mit dem Namen `finops-cost-report` hoch.

### 2.3 Workflow 3: Remediation (`3-remediate-resources.yml`)

*   **Zweck:** Führt aktive, ändernde Operationen (z.B. das Löschen von Ressourcen) auf der Azure-Subscription durch.
*   **Trigger:**
    *   **Ausschließlich Manuell (`workflow_dispatch`):** Kann unter keinen Umständen automatisch gestartet werden.
*   **Sicherheits-Gates:**
    *   **Explizite Genehmigung:** Der Workflow erfordert manuelle Inputs vom Benutzer, um zu definieren, welche Aktionen durchgeführt werden sollen.
    *   **Bestätigungs-Schutz:** Eine zusätzliche manuelle Eingabe (z.B. das Eintippen von "LÖSCHEN BESTÄTIGEN") ist erforderlich, um den Lauf zu starten.
*   **Authentifizierung:** Nutzt eine **separate, hochprivilegierte App-Registrierung** mit schreibenden Berechtigungen (z.B. "Contributor").
*   **Output:** Erstellt ein detailliertes Audit-Log (`remediation-log.txt`) und lädt dieses als Workflow-Artifact mit dem Namen `finops-remediation-log` hoch.

---

## 3. Implementierungs-Details: Analyse-Module

Dieses Kapitel beschreibt die konkreten technischen Logiken, die im Analyse-Workflow zur Identifizierung von Einsparpotenzialen verwendet werden.

### 3.1 Modul: Verwaiste Ressourcen

*   **Ziel:** Identifiziere Ressourcen, die Kosten verursachen, aber keiner aktiven Hauptressource mehr zugeordnet sind.
*   **3.1.1 Verwaiste Festplatten (Unattached Disks)**
    *   **Logik:** `az disk list --query "[?diskState=='Unattached']"`
    *   **Output-Datei:** `analysis-unattached-disks.tsv`
*   **3.1.2 Ungenutzte öffentliche IP-Adressen (Unassociated Public IPs)**
    *   **Logik:** `az network public-ip list --query "[?ipConfiguration==null]"`
    *   **Output-Datei:** `analysis-unassociated-public-ips.tsv`
*   **3.1.3 Verwaiste Netzwerkschnittstellen (Detached NICs)**
    *   **Logik:** `az network nic list --query "[?virtualMachine==null]"`
    *   **Output-Datei:** `analysis-detached-nics.tsv`

### 3.2 Modul: Überdimensionierte Ressourcen (Right-Sizing)

*   **Ziel:** Identifiziere Ressourcen, deren gebuchte Leistung signifikant höher ist als die tatsächliche Nutzung.
*   **3.2.1 Überdimensionierte VMs (CPU)**
    *   **Logik:** Abfrage von Azure Monitor Metriken (`az monitor metrics list`) für `Percentage CPU` über die letzten 30 Tage. Filtere VMs, deren durchschnittliche oder maximale Auslastung unter einem Schwellenwert (z.B. `avg < 15%`) liegt.
    *   **Output-Datei:** `analysis-downsize-vm-candidates.tsv`
*   **3.2.2 Unterausgelastete App Service Pläne**
    *   **Logik:** Abfrage von Azure Monitor Metriken für `CpuPercentage` und `MemoryPercentage` des App Service Plans. Filtere Pläne, die konstant unterausgelastet sind.
    *   **Output-Datei:** `analysis-downsize-asp-candidates.tsv`

### 3.3 Modul: Ungenutzte oder veraltete Ressourcen

*   **Ziel:** Identifiziere Ressourcen, die seit langer Zeit nicht mehr genutzt werden oder durch veraltete Konfigurationen ein Risiko darstellen.
*   **3.3.1 Alte Snapshots von VMs**
    *   **Logik:** `az snapshot list --query "[?timeCreated < '$(date -d '-90 days' -u +'%Y-%m-%dT%H:%M:%SZ')']"`
    *   **Output-Datei:** `analysis-old-snapshots.tsv`
*   **3.3.2 Leere Ressourcengruppen**
    *   **Logik:** Iteriere durch alle Ressourcengruppen (`az group list`) und prüfe für jede Gruppe die Anzahl der enthaltenen Ressourcen (`az resource list --resource-group [RG_NAME]`). Filtere Gruppen mit 0 Ressourcen.
    *   **Output-Datei:** `analysis-empty-resource-groups.tsv`
*   **3.3.3 Veraltete App Service TLS/SSL-Einstellungen**
    *   **Logik:** `az webapp list --query "[?httpsSettings.minTlsVersion!='1.2']"`
    *   **Output-Datei:** `analysis-outdated-tls-settings.tsv`

### 3.4 Modul: Azure Advisor Empfehlungen

*   **Ziel:** Systematische Sammlung und Kategorisierung der von Azure selbst generierten Empfehlungen.
*   **Logik:** `az advisor recommendation list --query "[?category=='Cost' || category=='HighAvailability']"`
*   **Output-Datei:** `analysis-azure-advisor-recommendations.tsv`
