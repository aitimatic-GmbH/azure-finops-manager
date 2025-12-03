# Developer Setup Guide

**Dokumenten-ID:** `INT-DEV-GUIDE-V1.0`
**Status:** Aktiv
**Zielgruppe:** Interne Entwickler

## 1. Zweck dieses Dokuments

Dieses Dokument sammelt Anleitungen und Best Practices für wiederkehrende Entwicklungs- und Testaufgaben, die für die Arbeit an diesem Repository notwendig sind.

---

## 2. Testen von Workflows in Feature-Branches (OIDC-Verbindung zu Azure)

### 2.1 Das Problem

Aufgrund einer technischen Einschränkung von Azure und GitHub funktioniert die OIDC-Authentifizierung nur, wenn der exakte Name des ausführenden Branches in der "Verbundenen Anmeldeinformation" in Microsoft Entra ID hinterlegt ist. Die Verwendung von Wildcards (z.B. `feature/*`) ist **nicht zuverlässig**.

Das bedeutet: Für einen aktiven Feature-Branch muss sichergestellt sein, dass eine passende, temporäre Konfiguration in Azure existiert, um die Workflows testen zu können.

### 2.2 Voraussetzungen: Notwendige Azure-Berechtigungen

Um die folgenden Schritte durchführen zu können, benötigt der verwendete Azure-Account mindestens die folgende Rolle auf der Ebene der App-Registrierung:

*   **Anwendungsentwickler (Application Developer):** Erlaubt das Verwalten von "Verbundenen Anmeldeinformationen".
*   **Besitzer / Mitwirkender (auf Subscription-Ebene):** Notwendig, um einen komplett neuen Service Principal zu erstellen (nur für den initialen Setup-Fall).

Fehlt eine Berechtigung, ist ein Administrator zu kontaktieren.

### 2.3 Prozess für das Testen eines Feature-Branches

Angenommen, die Arbeit findet in einem Branch namens `feature/neues-analyse-modul` statt.

**Schritt 1: Sicherstellen, dass der Service Principal existiert**

1.  Navigiere zum **Azure Portal** -> **Microsoft Entra ID** -> **App-Registrierungen**.
2.  Suche nach den zentralen Service Principals (z.B. `aitimatic-GmbH_FinOps_Reader`).
3.  **Wenn der Service Principal nicht existiert:** Dies ist ein initialer Setup-Fall. Folge der Anleitung in **[1-customer-onboarding.md](./1-customer-onboarding.md)**, um den Service Principal einmalig zu erstellen. Kehre danach zu diesem Dokument zurück.

**Schritt 2: Eine "Verbundene Anmeldeinformation" für deinen Branch hinzufügen**

**Prüfe immer zuerst, ob eine bestehende wiederverwendet werden kann!**

#### Option A: Bestehende, ungenutzte Anmeldeinformation wiederverwenden (Bevorzugter Weg)

1.  Wähle in der Liste der App-Registrierungen den relevanten, **bereits existierenden** Service Principal aus.
2.  Gehe zu **Zertifikate & Geheimnisse** -> **Verbundene Anmeldeinformationen**.
3.  Suche nach einem Eintrag, der nicht mehr aktiv genutzt wird (z.B. von einem bereits gemergten Branch, markiert als `UNUSED`).
4.  Klicke auf den Namen des Eintrags, um ihn zu bearbeiten.
5.  Ändere im Feld **Verzweigung (Branch)** den alten Namen auf den **exakten Namen deines neuen Feature-Branches**.
6.  Aktualisiere die **Beschreibung**.
7.  Klicke auf **Speichern**.

#### Option B: Neue, temporäre Anmeldeinformation erstellen

Diese Option ist nur zu verwenden, wenn alle bestehenden Einträge aktiv von anderen Entwicklern genutzt werden.

1.  Navigiere zur **selben, bereits existierenden App-Registrierung** wie in Option A.
2.  Gehe zu **Zertifikate & Geheimnisse** -> **Verbundene Anmeldeinformationen**.
3.  Klicke auf **+ Anmeldeinformationen hinzufügen**.
4.  Fülle die Felder aus (Organisation, Repository, **dein exakter Branch-Name**).
5.  Klicke auf **Hinzufügen**.

### 2.4 Aufräumen nach dem Merge (WICHTIG!)

Sobald der Pull Request genehmigt und der Feature-Branch in `main` gemerged wurde, liegt es in der **Verantwortung des Entwicklers**, die genutzte temporäre Anmeldeinformation wieder freizugeben oder zu löschen.

*   **Bei Nutzung von Option A:** Bearbeite den Eintrag erneut und ändere den Branch-Namen zurück auf `UNUSED`.
*   **Bei Nutzung von Option B:** Lösche den erstellten Eintrag vollständig.

**Warum ist das wichtig?**
Dieser Schritt hält die Azure-Konfiguration sauber und verhindert eine Ansammlung von veralteten Berechtigungen.

### 2.5 Einrichten der OIDC-Verbindung für Pull Requests

**Wichtiger Hinweis:** Dieser Schritt ist in der Regel eine **einmalige Konfiguration** für das Repository.

#### Das Problem

Wenn ein Pull Request (PR) gegen den `main`-Branch erstellt wird, führt GitHub die Workflows in einem speziellen `pull_request`-Kontext aus. Die Identität ("Subject"), mit der sich der Workflow bei Azure meldet, lautet dann `repo:IHRE_ORG/IHR_REPO:pull_request`.

Wenn diese Identität nicht explizit in den "Verbundenen Anmeldeinformationen" des Service Principals in Azure hinterlegt ist, schlägt die Anmeldung mit dem Fehler `AADSTS700213: No matching federated identity record found` fehl.

#### Die Lösung: Eine Anmeldeinformation für Pull Requests hinzufügen

Um die CI-Pipeline für Pull Requests zu aktivieren, muss eine entsprechende Vertrauensstellung für **beide** Service Principals (Lesen und Schreiben) hinzugefügt werden.

1.  **Navigieren Sie zur App-Registrierung im Azure Portal:**
    *   Gehen Sie zu **Microsoft Entra ID** -> **App-Registrierungen**.
    *   Wählen Sie die relevante App-Registrierung aus (z.B. `aitimatic-GmbH_FinOps_Reader`).

2.  **Neue "Verbundene Anmeldeinformation" hinzufügen:**
    *   Klicken Sie auf **Zertifikate & Geheimnisse** -> **Verbundene Anmeldeinformationen**.
    *   Klicken Sie auf **+ Anmeldeinformationen hinzufügen**.
    *   Füllen Sie die Felder wie folgt aus:
        *   **Szenario:** `GitHub Actions zum Bereitstellen von Azure-Ressourcen`.
        *   **Organisation:** Ihr GitHub-Organisationsname (z.B. `aitimatic-GmbH`).
        *   **Repository:** Ihr Repository-Name (z.B. `DevOpsMaintenance`).
        *   **Entitätstyp:** Wählen Sie **Pull-Anforderung** (Pull Request).
        *   **Beschreibung:** `Allow GitHub Actions on Pull Requests`.
    *   Klicken Sie auf **Hinzufügen**.

3.  **Wiederholen Sie den Vorgang für den "Writer"-Service Principal:**
    *   Führen Sie die Schritte 1 und 2 auch für den Service Principal mit Schreibrechten durch (z.B. `aitimatic-GmbH_FinOps_Writer`). Dies stellt sicher, dass der `on-push-validation`-Job im `remediate`-Workflow ebenfalls im PR-Kontext funktioniert.

Nachdem diese Konfiguration einmalig vorgenommen wurde, werden alle zukünftigen Pull Requests die Azure-Authentifizierung erfolgreich durchlaufen.

---

## 3. Ausführen des manuellen Remediate-Workflows via CLI

Der `4-remediate-resources.yml`-Workflow ist bewusst so konzipiert, dass er nur manuell gestartet werden kann, um maximale Kontrolle und Sicherheit zu gewährleisten. Die GitHub CLI (`gh`) ist das bevorzugte Werkzeug für diese Aufgabe.

### 3.1 Grundprinzip

Der Start des Workflows erfordert immer zwei grundlegende Informationen:
1.  **Die `run_id` des Analyse-Laufs:** Sie müssen dem Remediate-Workflow mitteilen, auf Basis welcher Analyse-Ergebnisse er arbeiten soll.
2.  **Den `resource_type_to_remediate`:** Sie müssen explizit angeben, *was* bereinigt werden soll.

### 3.2 Schritt 1: Die korrekte `run_id` identifizieren

Die Analyse-Ergebnisse werden vom `0 - Main CI Workflow` erzeugt. Wir benötigen also die ID des letzten erfolgreichen Laufs dieses Workflows auf dem relevanten Branch.

Führen Sie den folgenden Befehl aus, um die ID zu finden:

```bash
# Passen Sie den --branch-Parameter bei Bedarf an
gh run list --workflow="0 - Main CI Workflow" --branch="feature/finops-initial-setup" --status="success" --limit=1
```

**Beispiel-Ausgabe:**
```
STATUS    TITLE                                       WORKFLOW              BRANCH                        EVENT  ID           ELAPSED  AGE
✓         feat(remediate): add all case               0 - Main CI Workflow  feature/finops-initial-setup  push   19897123456  2m45s    about 5 minutes ago
```

Kopieren Sie die `ID` aus der Ausgabe (in diesem Beispiel `19897123456`). Dies ist Ihre `<RUN_ID>` für die folgenden Befehle.

### 3.3 Schritt 2: Den Workflow ausführen (Szenarien)

Alle Befehle folgen diesem Grundmuster:
```bash
gh workflow run "4-remediate-resources.yml" \
--ref <BRANCH_NAME> \
-f analysis_run_id=<RUN_ID> \
-f resource_type_to_remediate=<RESOURCE_TYPE> \
-f confirmation_phrase=<CONFIRMATION>
```

#### Szenario A: DRY-RUN (Simulation aller Aktionen)

Ein DRY-RUN ist der sicherste erste Schritt. Er simuliert alle Aktionen, ohne etwas in Azure zu ändern. Die `confirmation_phrase` ist hier nicht erforderlich.

```bash
# Ersetzen Sie <RUN_ID> durch die ID aus Schritt 1
gh workflow run "4-remediate-resources.yml" \
--ref feature/finops-initial-setup \
-f analysis_run_id=<RUN_ID> \
-f resource_type_to_remediate=DRY-RUN
```

#### Szenario B: Bereinigung eines einzelnen Ressourcentyps

Um nur einen spezifischen Ressourcentyp zu bereinigen (z.B. alle alten Snapshots), wählen Sie diesen explizit aus und fügen die Bestätigungsphrase `DELETE` hinzu.

```bash
# Ersetzen Sie <RUN_ID> durch die ID aus Schritt 1
gh workflow run "4-remediate-resources.yml" \
--ref feature/finops-initial-setup \
-f analysis_run_id=<RUN_ID> \
-f resource_type_to_remediate=old-snapshots \
-f confirmation_phrase=DELETE
```

#### Szenario C: Bereinigung aller Ressourcentypen

Um alle gefundenen Probleme in einem einzigen Durchlauf zu beheben, verwenden Sie `all` als Ressourcentyp.

```bash
# Ersetzen Sie <RUN_ID> durch die ID aus Schritt 1
gh workflow run "4-remediate-resources.yml" \
--ref feature/finops-initial-setup \
-f analysis_run_id=<RUN_ID> \
-f resource_type_to_remediate=all \
-f confirmation_phrase=DELETE
```

#### Szenario D: Bereinigung mehrerer, aber nicht aller Ressourcentypen

Das System ist so konzipiert, dass es entweder **einen** Typ oder **alle** Typen auf einmal verarbeitet. Es gibt keine eingebaute Funktion, um z.B. nur "Disks" und "IPs" auszuwählen.

**Workaround:** Wenn Sie mehrere, aber nicht alle Typen bereinigen müssen, führen Sie den Workflow einfach mehrmals hintereinander mit den jeweils gewünschten spezifischen Ressourcentypen aus.

**Beispiel: Nur Disks und IPs löschen:**

1.  **Erster Lauf (für Disks):**
    ```bash
    gh workflow run "4-remediate-resources.yml" \
    --ref feature/finops-initial-setup \
    -f analysis_run_id=<RUN_ID> \
    -f resource_type_to_remediate=unattached-disks \
    -f confirmation_phrase=DELETE
    ```

2.  **Zweiter Lauf (für IPs), nachdem der erste abgeschlossen ist:**
    ```bash
    gh workflow run "4-remediate-resources.yml" \
    --ref feature/finops-initial-setup \
    -f analysis_run_id=<RUN_ID> \
    -f resource_type_to_remediate=unassociated-public-ips \
    -f confirmation_phrase=DELETE
    ```
