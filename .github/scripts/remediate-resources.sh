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
IS_DRY_RUN=false

# --- Argumenten-Verarbeitung ---
# Verarbeitet die Kommandozeilen-Argumente, um den --type zu extrahieren.
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
    log_info "DRY-RUN-Modus aktiviert. Es werden keine Ressourcen geändert."
fi

# --- Log-Datei initialisieren ---
echo "Remediation run started at $(date)" > $LOG_FILE
echo "Selected mode: $RESOURCE_TYPE" >> $LOG_FILE
echo "-------------------------------------------" >> $LOG_FILE

# --- Haupt-Logik: Zentrale Funktion zur Verarbeitung ---
# Diese Funktion verarbeitet eine gegebene TSV-Datei und führt ein Kommando-Template aus.
# Argumente:
# $1: Pfad zur TSV-Datei
# $2: Anzeigename des Ressourcentyps für die Logs
# $3: Azure CLI Kommando-Template als String. Muss '$name' und '$group' als Platzhalter enthalten.
function process_remediation() {
    local file_path=$1
    local resource_name_singular=$2
    local az_command_template=$3

    if [ ! -f "$file_path" ] || [ ! -s "$file_path" ]; then
        log_warning "$file_path nicht gefunden oder leer. Überspringe diesen Typ."
        return
    fi

    log_info "Processing $resource_name_singular from $file_path..."
    
    # Liest die TSV-Datei Zeile für Zeile.
    # Format: name<TAB>group<TAB>... (weitere Spalten werden in 'etc' ignoriert)
    while IFS=$'\t' read -r name group etc; do
        # Ersetzt die Platzhalter im Befehls-Template mit den echten Werten.
        # 'eval' ist hier sicher, da das Template im Skript hartcodiert ist.
        action_command=$(eval echo $az_command_template)

        if [ "$IS_DRY_RUN" = true ]; then
            # DRY-RUN-Modus: Befehl nur ausgeben.
            log_info "[DRY-RUN] Would execute: $action_command"
            echo "[DRY-RUN] SIMULATED ACTION: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
        else
            # Echter Modus: Befehl ausführen.
            log_info "Executing: $action_command"
            if $action_command; then
                echo "SUCCESS: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
            else
                log_warning "Failed to process $resource_name_singular $name"
                echo "FAILED: $resource_name_singular '$name' in RG '$group'" >> $LOG_FILE
            fi
        fi
    done < "$file_path"
}

# --- Auswahl der Remediation basierend auf dem Ressourcentyp ---
# Steuert, welche Ressourcentypen verarbeitet werden.
case $RESOURCE_TYPE in
    "DRY-RUN")
        # Im DRY-RUN-Modus werden alle Aktionen für alle Typen simuliert.
        log_info "Executing DRY-RUN for all resource types..."
        process_remediation "analysis-unattached-disks.tsv" "Disk" 'az disk delete --name "$name" --resource-group "$group" --yes'
        process_remediation "analysis-unassociated-public-ips.tsv" "Public IP" 'az network public-ip delete --name "$name" --resource-group "$group"'
        process_remediation "analysis-old-snapshots.tsv" "Snapshot" 'az snapshot delete --name "$name" --resource-group "$group"'
        process_remediation "analysis-underutilized-vms.tsv" "Underutilized VM" 'az vm deallocate --name "$name" --resource-group "$group" --no-wait'
        ;;

    "all")
        # Im "all"-Modus werden alle Aktionen für alle Typen tatsächlich ausgeführt.
        log_info "Executing remediation for ALL resource types..."
        process_remediation "analysis-unattached-disks.tsv" "Disk" 'az disk delete --name "$name" --resource-group "$group" --yes'
        process_remediation "analysis-unassociated-public-ips.tsv" "Public IP" 'az network public-ip delete --name "$name" --resource-group "$group"'
        process_remediation "analysis-old-snapshots.tsv" "Snapshot" 'az snapshot delete --name "$name" --resource-group "$group"'
        process_remediation "analysis-underutilized-vms.tsv" "Underutilized VM" 'az vm deallocate --name "$name" --resource-group "$group" --no-wait'
        ;;

    "unattached-disks")
        process_remediation "analysis-unattached-disks.tsv" "Disk" 'az disk delete --name "$name" --resource-group "$group" --yes'
        ;;

    "unassociated-public-ips")
        process_remediation "analysis-unassociated-public-ips.tsv" "Public IP" 'az network public-ip delete --name "$name" --resource-group "$group"'
        ;;

    "old-snapshots")
        process_remediation "analysis-old-snapshots.tsv" "Snapshot" 'az snapshot delete --name "$name" --resource-group "$group"'
        ;;

    "underutilized-vms")
        process_remediation "analysis-underutilized-vms.tsv" "Underutilized VM" 'az vm deallocate --name "$name" --resource-group "$group" --no-wait'
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
