# Customer Onboarding Guide: Connecting GitHub to Azure

Dieses Dokument beschreibt die notwendigen Schritte, um eine sichere, passwortlose Verbindung (via OpenID Connect) zwischen diesem GitHub-Repository und einer Azure Subscription herzustellen.

**Ziel:** Einen "Service Principal" in Azure erstellen und ihm erlauben, sich von GitHub Actions aus zu authentifizieren.

---

## Teil A: Konfiguration in Microsoft Azure

Für die Einrichtung in Azure gibt es drei Wege, je nach Ihrem technischen Kenntnisstand und Ihren bevorzugten Werkzeugen. Wählen Sie den Weg, der am besten zu Ihnen passt.

* **Weg 1: Azure Cloud Shell (Empfohlen):** Der schnellste und einfachste Weg, da keine lokale Installation notwendig ist.
* **Weg 2: Lokale Azure CLI:** Für technische Anwender, die die Azure CLI bereits auf ihrem Computer installiert haben.
* **Weg 3: Azure Portal (GUI):** Für Anwender, die eine schrittweise, grafische Konfiguration ohne Kommandozeile bevorzugen.

Diese Schritte müssen von einer Person mit ausreichenden Berechtigungen in der Azure Subscription (z.B. "Owner" oder "User Access Administrator") durchgeführt werden.

### Weg 1: Azure Cloud Shell
#### 1: Azure Cloud Shell öffnen

1.  Melden Sie sich im [Azure Portal](https://portal.azure.com ) an.
2.  Öffnen Sie die **Azure Cloud Shell**, indem Sie auf das `>_`-Icon in der oberen Menüleiste klicken.
3.  Stellen Sie sicher, dass die Shell auf **Bash** eingestellt ist.

#### 2: Notwendige Informationen sammeln

Wir benötigen die ID Ihrer Azure Subscription. Führen Sie den folgenden Befehl in der Cloud Shell aus und kopieren Sie die `id`-Zeile des Ergebnisses.

```bash
az account show --query "{subscriptionId:id, name:name}"

```
Bewahren Sie diese subscriptionId für später auf.

#### 3: Service Principal erstellen

Ein Service Principal ist eine Identität für Anwendungen. Unser GitHub-Workflow wird diese Identität annehmen.

1\. Definieren Sie einen Namen für Ihren neuen Service Principal. Er sollte auf das Projekt hinweisen.

```bash
# Passen Sie den Namen an
SERVICE_PRINCIPAL_NAME="github-finops-workflow"

```

2\. Führen Sie den folgenden Befehl aus, um den Service Principal zu erstellen.
Bash

````bash
az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --role reader --scopes /subscriptions/IHRE_SUBSCRIPTION_ID

````
Ersetzen Sie IHRE_SUBSCRIPTION_ID durch die ID, die Sie in Schritt 2 kopiert haben.

3\. Wichtiger Output: Der Befehl erzeugt einen JSON-Output. Kopieren Sie die Werte für appId (das ist Ihre Client ID) und tenant (das ist Ihre Tenant ID).

````JSON
{
  "appId": "KOPIEREN_SIE_DIESEN_WERT", // Ihre AZURE_CLIENT_ID
  "displayName": "github-finops-workflow",
  "password": "...", // Dieses Passwort ignorieren wir, da wir OIDC verwenden
  "tenant": "KOPIEREN_SIE_DIESEN_WERT" // Ihre AZURE_TENANT_ID
}

````

#### 4: Vertrauensstellung für GitHub einrichten (Federated Credential)
Jetzt sagen wir dem neuen Service Principal, dass er Anmeldungen aus Ihrem GitHub-Repository vertrauen soll.

1\. Holen Sie sich die objectId des gerade erstellten Service Principals.

````Bash
OBJECT_ID=$(az ad sp list --display-name $SERVICE_PRINCIPAL_NAME --query "[].id" -o tsv)

````

2\. Definieren Sie den Pfad zu Ihrem GitHub-Repository.

````Bash
# Passen Sie 'IHR_GITHUB_ORG/IHR_REPO_NAME' an
GITHUB_REPO="IHR_GITHUB_ORG/IHR_REPO_NAME"
````

3\. Erstellen Sie die "Federated Credential" (die eigentliche Vertrauensstellung). Dieser Befehl erlaubt es jedem Branch in Ihrem Repository, sich zu authentifizieren.

````Bash
az ad app federated-credential create --id $OBJECT_ID --parameters '{"name":"github-branch-creds","issuer":"https://token.actions.githubusercontent.com","subject":"repo:'$GITHUB_REPO':ref:refs/heads/*","description":"GitHub Actions on any branch","audiences":["api://AzureADTokenExchange"]}'

````
## Weg 2: Lokale Azure CLI
Diese Schritte sind identisch zu Weg 1, aber Sie führen sie in Ihrem lokalen Terminal aus, nachdem Sie sich mit az login angemeldet haben.

1\. Anmelden: az login
2\. Subscription festlegen (falls nötig): az account set --subscription "IHRE_SUBSCRIPTION_ID"
3\. Befehle ausführen: Führen Sie die Schritte 2, 3 und 4 von "Weg 1" aus.

## Weg 3: Azure Portal (Grafische Oberfläche)
Dieser Weg ist vollständig klickbar und erfordert keine lokale Kommandozeile.

1.  **App-Registrierung in Microsoft Entra ID erstellen**
    *   Gehen Sie zum **Microsoft Entra ID** Service im Azure Portal.
    *   Navigieren Sie im linken Menü zu **App-Registrierungen** und klicken Sie auf **+ Neue Registrierung**.
    *   **WICHTIG:** Geben Sie einen klaren, sprechenden Namen ein, der den Zweck und den Kontext widerspiegelt (z.B. `aitimatic-GmbH_FinOps_Reader` oder `GitHub-FinOps-Workflow`). Klicken Sie dann auf **Registrieren**.
    *   Kopieren Sie von der Übersichtsseite die **Anwendungs-ID (Client-ID)** und die **Verzeichnis-ID (Mandanten-ID)**. Dies sind zwei Ihrer drei benötigten Werte.

2.  **Berechtigungen zuweisen**
    *   Gehen Sie zu Ihrer **Abonnements**-Ansicht und wählen Sie das relevante Abonnement aus.
    *   Klicken Sie auf **Zugriffssteuerung (IAM)** -> **+ Hinzufügen** -> **Rollenzuweisung hinzufügen**.
    *   Wählen Sie die Rolle **Leser** (Reader) aus und klicken Sie auf **Weiter**.
    *   Klicken Sie auf den blauen Link **+ Mitglieder auswählen**. Ein Fenster öffnet sich auf der rechten Seite.
    *   Geben Sie im Suchfeld den **exakten Namen** Ihrer App-Registrierung ein (z.B. `aitimatic-GmbH_FinOps_Reader`). Der **Dienstprinzipal** (Service Principal) mit diesem Namen sollte erscheinen.
    *   Wählen Sie den gefundenen Dienstprinzipal aus und klicken Sie unten auf den Button **Auswählen**.
    *   Klicken Sie auf **Überprüfen + zuweisen**, um die Rollenzuweisung abzuschließen.

3.  **Vertrauensstellung (Verbundene Anmeldeinformation) einrichten**
    *   Gehen Sie zurück zu **Microsoft Entra ID** -> **App-Registrierungen** und wählen Sie Ihre App aus.
    *   Klicken Sie auf **Zertifikate & Geheimnisse** -> **Verbundene Anmeldeinformationen** -> **+ Anmeldeinformationen hinzufügen**.
    *   Wählen Sie als Szenario für die verbundenen Anmeldeinformationen **GitHub Actions zum Bereitstellen von Azure-Ressourcen**.
    *   Füllen Sie die Felder aus:
        *   **Organisation:** Ihr GitHub-Organisationsname.
        *   **Repository:** Ihr Repository-Name.
        *   **Entitätstyp:** Wählen Sie **Verzweigung** (Branch).
        *   **Verzweigung:** Geben Sie `main` ein (oder den Namen Ihres Haupt-Branches).
    *   Geben Sie eine Beschreibung ein (z.B. "GitHub Actions für FinOps-Repo") und klicken Sie auf **Hinzufügen**.

**Fertig!** Sie haben nun alle drei Werte gesammelt, die Sie als Secrets in GitHub hinterlegen müssen:
1.  **Subscription ID** (Die ID Ihres Azure-Abonnements)
2.  **Client ID** (Die Anwendungs-ID aus Schritt 1)
3.  **Tenant ID** (Die Mandanten-ID aus Schritt 1)

### Secrets im GitHub-Repository anlegen

1\. Navigieren Sie zu Ihrem GitHub-Repository.
2\. Klicken Sie auf den "Settings"-Tab.
3\. Wählen Sie im linken Menü "Secrets and variables" -> "Actions".
4\. Stellen Sie sicher, dass Sie sich im "Secrets"-Tab befinden.
5\. Erstellen Sie die folgenden drei Secrets, indem Sie auf "New repository secret" klicken:
1. **Secret 1:**
   1. Name: AZURE_CLIENT_ID
   2. Value: Fügen Sie hier die Client ID (appId) aus Azure ein.
2. **Secret 2:**
   1. Name: AZURE_TENANT_ID
   2. Value: Fügen Sie hier die Tenant ID (tenant) aus Azure ein.
3. **Secret 3:**
   1. Name: AZURE_SUBSCRIPTION_ID
   2. Value: Fügen Sie hier Ihre Subscription ID aus Azure ein.

**Onboarding abgeschlossen!**
Ihr Repository ist jetzt bereit. Sie können den Workflow 1 - Analyze Azure Resources über den "Actions"-Tab manuell starten. Der Workflow wird sich nun sicher mit Ihrer Azure Subscription verbinden.

---

## Teil B: Einrichtung der Credentials für Remediation (Schreibzugriff)

**Wichtiger Hinweis:** Dieser Teil ist **optional** und nur notwendig, wenn Sie den Remediation-Workflow (`2-remediate-resources.yml`) nutzen möchten, der aktive Änderungen (z.B. das Löschen von Ressourcen) in Ihrer Azure-Umgebung vornimmt.

**Ziel:** Einen **zweiten, separaten Service Principal** mit Schreibrechten ("Contributor") erstellen, um das Prinzip der minimalen Berechtigungen strikt einzuhalten.

### Zusammenfassung der Änderungen

Sie werden die Schritte aus **Teil A** im Wesentlichen wiederholen, jedoch mit zwei entscheidenden Unterschieden:

1.  **Neuer Name:** Verwenden Sie einen anderen, klaren Namen für den Service Principal, z.B. `aitimatic-GmbH_FinOps_Writer`.
2.  **Andere Rolle:** Anstelle der "Leser" (Reader)-Rolle weisen Sie die Rolle **"Mitwirkender" (Contributor)** zu.

### Detaillierte Schritte

1.  **Erstellen Sie einen neuen Service Principal:**
    *   Folgen Sie den Anweisungen aus **Teil A** (Weg 1, 2 oder 3), um eine **neue** App-Registrierung zu erstellen.
    *   **Namensgebung:** Verwenden Sie einen Namen, der den Schreibzugriff klar kennzeichnet, z.B. `aitimatic-GmbH_FinOps_Writer`.
    *   Notieren Sie sich die neue **Client ID** und **Tenant ID**.

2.  **Weisen Sie die "Contributor"-Rolle zu:**
    *   Folgen Sie den Anweisungen aus **Teil A, Schritt 2 (Berechtigungen zuweisen)**.
    *   Wählen Sie bei der Rollenauswahl jedoch **"Mitwirkender" (Contributor)** anstelle von "Leser" aus.

3.  **Richten Sie die Vertrauensstellung ein:**
    *   Folgen Sie den Anweisungen aus **Teil A, Schritt 3 (Vertrauensstellung einrichten)** für den *neuen* Service Principal. Die Konfiguration (Organisation, Repository, etc.) ist identisch.

### Neue Secrets im GitHub-Repository anlegen

Nachdem Sie den zweiten Service Principal erstellt haben, müssen Sie zwei neue Secrets in Ihrem GitHub-Repository anlegen. **Die `AZURE_SUBSCRIPTION_ID` bleibt dieselbe und muss nicht neu erstellt werden.**

1.  Navigieren Sie erneut zu `Settings` -> `Secrets and variables` -> `Actions`.
2.  Erstellen Sie die folgenden beiden Secrets:
    *   **Secret 4:**
        *   **Name:** `AZURE_WRITE_CLIENT_ID`
        *   **Value:** Fügen Sie hier die **Client ID** des *neuen* "Writer"-Service Principals ein.
    *   **Secret 5:**
        *   **Name:** `AZURE_WRITE_TENANT_ID`
        *   **Value:** Fügen Sie hier die **Tenant ID** des *neuen* "Writer"-Service Principals ein.

**Einrichtung für Remediation abgeschlossen!**
Der Workflow `2-remediate-resources.yml` ist nun in der Lage, sich bei einem `push` für den Verbindungstest und bei einem manuellen Start für die Bereinigung sicher mit den Schreibrechten zu authentifizieren.
