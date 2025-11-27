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

# --- Argumenten-Verarbeitung ---
# Verarbeitet Kommandozeilen-Argumente (z.B. --type "unattached-disks")
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --type) RESOURCE_TYPE="$2"; shift ;;
        *) log_error "Unbekanntes Argument: $1"; exit 1 ;;
    esac
    shift
done

# Überprüft, ob der Ressourcentyp übergeben wurde.
if [ -z "$RESOURCE_TYPE" ]; then
    log_error "Fehler: Der Ressourcentyp muss mit --type angegeben werden."
    exit 1
fi

# --- Log-Datei initialisieren ---
echo "Remediation run started at $(date)" > $LOG_FILE
echo "Selected resource type: $RESOURCE_TYPE" >> $LOG_FILE
echo "-------------------------------------------" >> $LOG_FILE

# --- Haupt-Logik: Case-Statement zur Steuerung ---
case $RESOURCE_TYPE in
    "unattached-disks")
        log_info "Remediating unattached disks..."
        if [ ! -f analysis-unattached-disks.tsv ]; then log_error "analysis-unattached-disks.tsv not found!"; exit 1; fi
        
        while IFS=$'\t' read -r name group size location; do
            log_info "Deleting disk '$name' in resource group '$group'..."
            az disk delete --name "$name" --resource-group "$group" --yes || log_warning "Failed to delete disk $name"
            echo "DELETED: Disk '$name' in RG '$group'" >> $LOG_FILE
        done < analysis-unattached-disks.tsv
        ;;

    "unassociated-public-ips")
        log_info "Remediating unassociated public IPs..."
        if [ ! -f analysis-unassociated-public-ips.tsv ]; then log_error "analysis-unassociated-public-ips.tsv not found!"; exit 1; fi

        while IFS=$'\t' read -r name group ip location; do
            log_info "Deleting public IP '$name' in resource group '$group'..."
            az network public-ip delete --name "$name" --resource-group "$group" || log_warning "Failed to delete public IP $name"
            echo "DELETED: Public IP '$name' in RG '$group'" >> $LOG_FILE
        done < analysis-unassociated-public-ips.tsv
        ;;

    "old-snapshots")
        log_info "Remediating old snapshots..."
        if [ ! -f analysis-old-snapshots.tsv ]; then log_error "analysis-old-snapshots.tsv not found!"; exit 1; fi

        while IFS=$'\t' read -r name group size location; do
            log_info "Deleting snapshot '$name' in resource group '$group'..."
            az snapshot delete --name "$name" --resource-group "$group" || log_warning "Failed to delete snapshot $name"
            echo "DELETED: Snapshot '$name' in RG '$group'" >> $LOG_FILE
        done < analysis-old-snapshots.tsv
        ;;

    "SIMULATION-ONLY")
        log_info "SIMULATION MODE: No resources will be deleted."
        echo "SIMULATION MODE: No resources will be deleted." >> $LOG_FILE
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
