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
