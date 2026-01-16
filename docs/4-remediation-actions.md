# Dokumentation: Aktionen des FinOps Remediate-Workflows

Dieses Dokument beschreibt die exakten Aktionen, die der manuelle `remediate`-Workflow auf die von der Analyse identifizierten Azure-Ressourcen anwendet.

## Zusammenfassung

Der `remediate`-Workflow führt je nach Ressourcentyp unterschiedliche Aktionen aus. Das Ziel ist immer, unnötige Kosten zu stoppen. In den meisten Fällen bedeutet dies eine **permanente Löschung** der Ressource. Eine wichtige Ausnahme bilden die Virtuellen Maschinen (VMs), die zur Sicherheit nicht gelöscht, sondern nur "dealloziert" werden.

---

## Detaillierte Aktionen pro Ressourcentyp

### 1. Verwaiste Festplatten (Unattached Disks)

- **Identifizierte Ressource:** Ein verwalteter Azure-Datenträger (Managed Disk), der an keine laufende oder gestoppte VM angehängt ist.
- **Ausgeführter Befehl:** `az disk delete --yes`
- **Aktion:** **Permanente Löschung**
- **Konsequenz:**
    - Der Datenträger und alle darauf gespeicherten Daten werden **unumkehrbar gelöscht**.
    - Die Kosten für den Speicherplatz des Datenträgers fallen sofort weg.
    - Eine Wiederherstellung ist nur möglich, wenn zuvor ein Snapshot oder ein Backup des Datenträgers erstellt wurde.

---

### 2. Ungenutzte Öffentliche IPs (Unassociated Public IPs)

- **Identifizierte Ressource:** Eine öffentliche IP-Adressen-Ressource, die keiner Netzwerkschnittstelle (und somit keiner VM, keinem Load Balancer etc.) zugeordnet ist.
- **Ausgeführter Befehl:** `az network public-ip delete`
- **Aktion:** **Permanente Löschung**
- **Konsequenz:**
    - Die IP-Adressen-Ressource wird **unumkehrbar gelöscht**.
    - Die reservierte öffentliche IP-Adresse wird freigegeben und geht zurück in den Pool von Azure. Es ist nicht garantiert, dass man dieselbe IP-Adresse erneut erhält.
    - Die Kosten für die reservierte, aber ungenutzte IP-Adresse fallen sofort weg.

---

### 3. Alte Snapshots (Old Snapshots)

- **Identifizierte Ressource:** Ein Snapshot eines Datenträgers, dessen Erstellungsdatum älter ist als der im `finops.config.json` definierte Schwellenwert.
- **Ausgeführter Befehl:** `az snapshot delete`
- **Aktion:** **Permanente Löschung**
- **Konsequenz:**
    - Der Snapshot wird **unumkehrbar gelöscht**.
    - Dies hat **keine Auswirkung** auf den ursprünglichen Datenträger oder auf andere Snapshots.
    - Die Möglichkeit, den Zustand des Datenträgers zum Zeitpunkt dieses Snapshots wiederherzustellen, geht verloren.
    - Die Kosten für den Speicherplatz des Snapshots fallen sofort weg.

---

### 4. Unterauslastete Virtuelle Maschinen (Underutilized VMs)

- **Identifizierte Ressource:** Eine laufende VM, deren durchschnittliche CPU-Auslastung über den definierten Zeitraum unter dem konfigurierten Schwellenwert liegt.
- **Ausgeführter Befehl:** `az vm deallocate`
- **Aktion:** **Deallokierung (Freigabe der Zuweisung)**
- **Konsequenz:**
    - Die VM wird heruntergefahren und der Status ändert sich zu **"Gestoppt (Zuordnung aufgehoben)"**.
    - **WICHTIG:** Die VM wird **NICHT gelöscht**. Die Konfiguration der VM, ihre Netzwerkschnittstellen und ihre Datenträger bleiben vollständig erhalten.
    - Die teuren Rechenressourcen (CPU, RAM) werden an Azure zurückgegeben. Die Kosten für die Rechenleistung fallen damit sofort weg.
    - **Kosten für die Datenträger fallen weiterhin an**, da diese weiterhin existieren und Speicherplatz belegen.
    - Die öffentliche IP-Adresse (falls dynamisch) wird freigegeben.
    - Die VM kann jederzeit über das Azure-Portal oder per CLI wieder gestartet werden. Beim Neustart erhält sie neue Rechenressourcen und (falls dynamisch) eine neue öffentliche IP-Adresse zugewiesen.

> Dieses Sicherheitsnetz bei VMs ist bewusst so gewählt, um einen versehentlichen Datenverlust zu verhindern und Administratoren die Möglichkeit zu geben, die VM zu einem späteren Zeitpunkt zu überprüfen oder ihre Größe anzupassen ("Right-Sizing").
