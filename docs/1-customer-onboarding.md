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
Dieser Weg ist vollständig klickbar, erfordert aber mehr manuelle Schritte.
1\. App-Registrierung erstellen

* Gehen Sie zu Azure Active Directory -> App-Registrierungen -> Neue Registrierung.
* Geben Sie einen Namen ein (z.B. "GitHub FinOps Workflow") und klicken Sie auf "Registrieren".
* Kopieren Sie die Anwendungs-ID (Client-ID) und die Verzeichnis-ID (Tenant-ID) von der Übersichtsseite. Das sind zwei Ihrer drei Werte.

2\. Berechtigungen zuweisen

* Gehen Sie zu Ihrer Subscription -> Zugriffssteuerung (IAM) -> Hinzufügen -> Rollenzuweisung hinzufügen.
* Wählen Sie die Rolle "Leser" (Reader).
* Suchen und wählen Sie den Namen Ihrer App-Registrierung ("GitHub FinOps Workflow").
* Klicken Sie auf "Speichern".

3\. Vertrauensstellung (Federated Credential) einrichten

* Gehen Sie zurück zu Ihrer App-Registrierung (Azure AD -> App-Registrierungen -> Ihre App).
* Klicken Sie auf Zertifikate & Geheimnisse -> Verbundene Anmeldeinformationen -> Anmeldeinformationen hinzufügen.
* Wählen Sie als Szenario "GitHub Actions zum Bereitstellen von Azure-Ressourcen".
* Füllen Sie die Felder aus:
  * Organisation: Ihr GitHub-Organisationsname.
  * Repository: Ihr Repository-Name.
  * Entitätstyp: Branch.
  * Branch: main (oder * für alle Branches).
* Klicken Sie auf "Hinzufügen".

**Azure-Konfiguration abgeschlossen!**
Sie sollten nun die folgenden drei Informationen zur Hand haben, um sie im nächsten Teil in GitHub zu hinterlegen:

1. Subscription ID (aus Schritt 2 )
2. Client ID (appId aus Schritt 3)
3. Tenant ID (tenant aus Schritt 3)

## Teil B: Konfiguration in GitHub
Nachdem Sie die Konfiguration in Azure abgeschlossen haben, müssen Sie die gesammelten Werte als "Secrets" in Ihrem GitHub-Repository hinterlegen. Secrets sind verschlüsselte Variablen, die nur von GitHub Actions Workflows gelesen werden können.
Voraussetzung: Sie benötigen Admin-Rechte für das GitHub-Repository.

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
