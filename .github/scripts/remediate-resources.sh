#!/bin/bash

# Stoppt das Skript sofort, wenn ein Befehl fehlschlägt.
set -e

# --- Hilfsfunktionen ---
function log_info() {
    echo "[INFO] $1"
}

function log_error() {
    echo "::error::[ERROR] $1"
}

function log_warning() {
    echo "::warning::[WARN] $1"
}

# --- Skript-Initialisierung ---
LOG_FILE="remediation-log.txt"
RESOURCE_TYPE=""
IS_DRY_RUN=false # Neue Variable für den DRY-RUN-Modus

# --- Argumenten-Verarbeitung ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --type) RESOURCE_TYPE="$2"; shift ;;
        *) log_error "Unbekanntes Argument: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$RESOURCE_TYPE" ]; then
    log_error "Fehler: Der Ressourcentyp muss mit --type angegeben werden."
    exit 1
fi

# --- Prüfen, ob es ein DRY-RUN ist ---
if [[ "$RESOURCE_TYPE" == "DRY-RUN" ]]; then
    IS_DRY_RUN=true
    log_info "DRY-RUN-Modus aktiviert. Es werden keine Ressourcen gelöscht."
    # Wir müssen den Ressourcentyp für den Report wissen, den der Benutzer eigentlich testen wollte.
    # Hier könnten wir eine Logik hinzufügen, um das aus einem optionalen zweiten Parameter zu lesen.
    # Fürs Erste simulieren wir einfach alle Typen.
fi

# --- Log-Datei initialisieren ---
echo "Remediation run started at $(date)" > $LOG_FILE
echo "Selected mode: $RESOURCE_TYPE" >> $LOG_FILE
echo "-------------------------------------------" >> $LOG_FILE

# --- Haupt-Logik: Case-Statement zur Steuerung ---
# Wir verwenden eine Funktion, um die Logik nicht zu wiederholen.
function process_remediation() {
    local file_path=$1
    local resource_name_singular=$2
    local az_command_template=$3

    if [ ! -f "$file_path" ]; then
        log_warning "$file_path nicht gefunden. Überspringe diesen Typ."
        return
    fi

    log_info "Processing $resource_name_singular from $file_path..."
    
    while IFS=$'\t' read -r name group etc; do
        # Ersetzt die Platzhalter im Befehls-Template mit den echten Werten.
        # Das 'eval' ist notwendig, um die Variablen im String zu expandieren.
        delete_command=$(eval echo $az_command_template)

        if [ "$IS_DRY_RUN" = true ]; then
            # DRY-RUN-Modus: Befehl nur ausgeben.
            log_info "[DRY-RUN] Would execute: $delete_command"
            echo "[DRY-RUN] SIMULATED DELETE: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
        else
            # Echter Modus: Befehl ausführen.
            log_info "Executing: $delete_command"
            if $delete_command; then
                echo "DELETED: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
            else
                log_warning "Failed to delete $resource_name_singular $name"
                echo "FAILED: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
            fi
        fi
    done < "$file_path"
}


# --- Aufruf der Verarbeitungs-Funktion basierend auf dem Input ---
case $RESOURCE_TYPE in
    "unattached-disks" | "DRY-RUN")
        process_remediation "analysis-unattached-disks.tsv" "Disk" 'az disk delete --name "$name" --resource-group "$group" --yes'
        if [[ "$RESOURCE_TYPE" != "DRY-RUN" ]]; then break; fi
        ;&
    "unassociated-public-ips" | "DRY-RUN")
        process_remediation "analysis-unassociated-public-ips.tsv" "Public IP" 'az network public-ip delete --name "$name" --resource-group "$group"'
        if [[ "$RESOURCE_TYPE" != "DRY-RUN" ]]; then break; fi
        ;&
    "old-snapshots" | "DRY-RUN")
        process_remediation "analysis-old-snapshots.tsv" "Snapshot" 'az snapshot delete --name "$name" --resource-group "$group"'
        if [[ "$RESOURCE_TYPE" != "DRY-RUN" ]]; then break; fi
        ;;
    "SIMULATION-ONLY")
        log_info "SIMULATION MODE: No actions taken."
        echo "SIMULATION MODE: No actions taken." >> $LOG_FILE
        ;;
    *)
        log_error "Ungültiger Ressourcentyp '$RESOURCE_TYPE'. Remediation abgebrochen."
        exit 1
        ;;
esac


# --- Skript-Abschluss ---
echo "-------------------------------------------" >> $LOG_FILE
echo "Remediation run finished at $(date)" >> $LOG_FILE

log_info "Remediation script finished successfully."
