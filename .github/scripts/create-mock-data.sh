#!/bin/bash

# ==============================================================================
# create-mock-data.sh
#
# Zweck: Erstellt gefälschte Analyse-Ergebnisdateien (.tsv) für lokale Tests
#        des 'report'-Jobs, ohne eine Verbindung zu Azure zu benötigen.
#
# Anwendung: Führen Sie das Skript vom Hauptverzeichnis des Projekts aus:
#            bash .github/scripts/create-mock-data.sh
# ==============================================================================

# --- Konfiguration ---
# Ändern Sie diese Werte, um verschiedene Szenarien zu testen (z.B. 0 für leere Reports)
NUM_DISKS=3
NUM_IPS=2
NUM_SNAPSHOTS=4
NUM_ADVISOR_HIGH_AVAILABILITY=1
NUM_ADVISOR_COST=2

# --- Start ---
echo "🚀 Generating mock data files..."

# Lösche alte Mock-Dateien, falls vorhanden
rm -f analysis-*.tsv
echo "   - Cleaned up old files."

# --- Modul 1: Unattached Disks ---
# Format: Name, ResourceGroup, SizeGB, Location
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
# Format: Name, ResourceGroup, IPAddress, Location
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
# Format: Name, ResourceGroup, SizeGB, Location
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
# Format: Description, Resource, Category
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

echo "✅ Mock data generation complete."
echo "   You can now test the report generation script locally."

