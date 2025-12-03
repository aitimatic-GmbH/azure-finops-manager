#!/bin/bash

# ==============================================================================
# create-mock-data.sh
#
# Zweck: Erstellt gefälschte Analyse-Ergebnisdateien (.tsv) für Mock Tests.
#        Die Anzahl der Einträge kann über Umgebungsvariablen gesteuert werden.
#
# Anwendung (Lokal):
#   # Mit Standardwerten:
#   bash .github/scripts/create-mock-data.sh
#
#   # Mit eigenen Werten:
#   NUM_DISKS=5 NUM_IPS=0 ./github/scripts/create-mock-data.sh
# ==============================================================================

# --- Konfiguration ---
# Liest Umgebungsvariablen. Falls nicht gesetzt, werden die Standardwerte (nach :-) verwendet.
# Die Namen sind an die GitHub Repository Variables angepasst (MOCK_...).
NUM_DISKS=${MOCK_NUM_DISKS:-3}
NUM_IPS=${MOCK_NUM_IPS:-2}
NUM_SNAPSHOTS=${MOCK_NUM_SNAPSHOTS:-4}
NUM_ADVISOR_HIGH_AVAILABILITY=${MOCK_NUM_ADVISOR_HA:-1}
NUM_ADVISOR_COST=${MOCK_NUM_ADVISOR_COST:-2}

# --- Start ---
echo "🚀 Generating mock data files with the following configuration:"
echo "   - Unattached Disks: $NUM_DISKS"
echo "   - Unassociated IPs: $NUM_IPS"
echo "   - Old Snapshots: $NUM_SNAPSHOTS"
echo "   - Advisor (HA): $NUM_ADVISOR_HIGH_AVAILABILITY"
echo "   - Advisor (Cost): $NUM_ADVISOR_COST"

# Lösche alte Mock-Dateien, falls vorhanden
rm -f analysis-*.tsv
echo "   - Cleaned up old files."

# --- Modul 1: Unattached Disks ---
# (Der Rest des Skripts bleibt exakt gleich, da er die oben definierten Variablen verwendet)
if [ "$NUM_DISKS" -gt 0 ]; then
    for i in $(seq 1 $NUM_DISKS); do
        echo -e "disk-unattached-mock-$i\trg-mock-data\t128\twesteurope" >> analysis-unattached-disks.tsv
    done
    echo "   - Created 'analysis-unattached-disks.tsv' with $NUM_DISKS entries."
else
    touch analysis-unattached-disks.tsv
    echo "   - Created empty 'analysis-unattached-disks.tsv'."
fi

# --- Modul 2: Unassociated Public IPs ---
if [ "$NUM_IPS" -gt 0 ]; then
    for i in $(seq 1 $NUM_IPS); do
        echo -e "pip-unassociated-mock-$i\trg-mock-data\t20.10.20.$i\twesteurope" >> analysis-unassociated-public-ips.tsv
    done
    echo "   - Created 'analysis-unassociated-public-ips.tsv' with $NUM_IPS entries."
else
    touch analysis-unassociated-public-ips.tsv
    echo "   - Created empty 'analysis-unassociated-public-ips.tsv'."
fi

# --- Modul 3: Old Snapshots ---
if [ "$NUM_SNAPSHOTS" -gt 0 ]; then
    for i in $(seq 1 $NUM_SNAPSHOTS); do
        echo -e "snapshot-old-mock-$i\trg-mock-data\t256\teastus" >> analysis-old-snapshots.tsv
    done
    echo "   - Created 'analysis-old-snapshots.tsv' with $NUM_SNAPSHOTS entries."
else
    touch analysis-old-snapshots.tsv
    echo "   - Created empty 'analysis-old-snapshots.tsv'."
fi

# --- Modul 4: Azure Advisor Recommendations ---
if [ "$((NUM_ADVISOR_HIGH_AVAILABILITY + NUM_ADVISOR_COST))" -gt 0 ]; then
    for i in $(seq 1 $NUM_ADVISOR_HIGH_AVAILABILITY); do
        echo -e "Enable read-access geo-redundant storage\t/subscriptions/sub-id/resourceGroups/rg-mock-data/providers/Microsoft.Storage/storageAccounts/mockstorage$i\tHighAvailability" >> analysis-azure-advisor-recommendations.tsv
    done
    for i in $(seq 1 $NUM_ADVISOR_COST); do
        echo -e "Right-size or shutdown underutilized virtual machines\t/subscriptions/sub-id/resourceGroups/rg-mock-data/providers/Microsoft.Compute/virtualMachines/mock-vm$i\tCost" >> analysis-azure-advisor-recommendations.tsv
    done
    echo "   - Created 'analysis-azure-advisor-recommendations.tsv' with $((NUM_ADVISOR_HIGH_AVAILABILITY + NUM_ADVISOR_COST)) entries."
else
    touch analysis-azure-advisor-recommendations.tsv
    echo "   - Created empty 'analysis-azure-advisor-recommendations.tsv'."
fi

# --- Modul 5: Underutilized VMs ---
if [ "$NUM_UNDERUTILIZED_VMS" -gt 0 ]; then
    for i in $(seq 1 $NUM_UNDERUTILIZED_VMS); do
        # Wir simulieren eine VM mit sehr niedriger CPU-Last.
        echo -e "vm-underutilized-mock-$i\trg-mock-data\tStandard_B1s\t2" >> analysis-underutilized-vms.tsv
    done
    echo "   - Created 'analysis-underutilized-vms.tsv' with $NUM_UNDERUTILIZED_VMS entries."
else
    touch analysis-underutilized-vms.tsv
    echo "   - Created empty 'analysis-underutilized-vms.tsv'."
fi

echo "✅ Mock data generation complete."
