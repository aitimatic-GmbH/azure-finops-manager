import os
import json
import sys
from datetime import datetime, timedelta
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.monitor import MonitorManagementClient

# --- Hilfsfunktionen (können später für Tests gemockt werden) ---

def get_azure_credential():
    return DefaultAzureCredential()

def get_all_resource_groups(credential, subscription_id):
    resource_client = ResourceManagementClient(credential, subscription_id)
    return [rg.name for rg in resource_client.resource_groups.list()]

def get_running_vms(credential, subscription_id, resource_group):
    compute_client = ComputeManagementClient(credential, subscription_id)
    vms = []
    for vm in compute_client.virtual_machines.list(resource_group):
        # Prüfe den Power State der VM
        vm_details = compute_client.virtual_machines.get(resource_group, vm.name, expand='instanceView')
        power_state = next((s.code for s in vm_details.instance_view.statuses if s.code.startswith('PowerState/')), None)
        if power_state == 'PowerState/running':
            vms.append({'id': vm.id, 'name': vm.name, 'size': vm.hardware_profile.vm_size})
    return vms

def get_avg_cpu(credential, subscription_id, vm_id, start_time, end_time):
    monitor_client = MonitorManagementClient(credential, subscription_id)
    metrics_data = monitor_client.metrics.list(
        vm_id,
        metricnames="Percentage CPU",
        aggregation="Average",
        timespan=f"{start_time}/{end_time}",
        interval="P1D"
    )
    try:
        return metrics_data.value[0].timeseries[0].data[0].average
    except (IndexError, TypeError, AttributeError):
        return 0.0

# --- Hauptlogik ---

def main():
    # 1. Konfiguration lesen
    with open('runtime_config.json', 'r') as f:
        config = json.load(f)
    
    vm_config = config['analysis_modules']['underutilized_vms']
    excluded_rgs = set(config['global_settings']['excluded_resource_groups'])
    
    evaluation_days = vm_config.get('evaluation_period_days', 7)
    cpu_threshold = vm_config.get('max_cpu_percentage_threshold', 5)

    end_time = datetime.utcnow()
    start_time = end_time - timedelta(days=evaluation_days)

    print(f"INFO: Searching for VMs with CPU below {cpu_threshold}% over {evaluation_days} days.")

    # 2. Azure-Verbindung herstellen
    credential = get_azure_credential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]

    # 3. Ressourcengruppen filtern
    all_rgs = get_all_resource_groups(credential, subscription_id)
    rgs_to_scan = [rg for rg in all_rgs if rg not in excluded_rgs]
    print(f"INFO: Found {len(rgs_to_scan)} resource groups to scan.")

    # 4. VMs analysieren und Ergebnisse schreiben
    results = []
    for rg in rgs_to_scan:
        print(f"   - Scanning resource group: {rg}")
        running_vms = get_running_vms(credential, subscription_id, rg)
        for vm in running_vms:
            avg_cpu = get_avg_cpu(credential, subscription_id, vm['id'], start_time, end_time)
            
            # Behandelt den Fall, dass die Azure Monitor API keine Daten (None) zurückgibt.
            if avg_cpu is None:
                # Wenn keine Metriken gefunden wurden, behandeln wir es als 0% CPU, geben aber eine Warnung aus.
                print(f"     - VM: {vm['name']}, Avg CPU: N/A (No metrics found)")
                avg_cpu = 0.0
            else:
                print(f"     - VM: {vm['name']}, Avg CPU: {avg_cpu:.2f}%")
            # === ENDE DER ÄNDERUNG ===

            if avg_cpu < cpu_threshold:
                print("       -> MARKED as underutilized.")
                results.append(f"{vm['name']}\t{rg}\t{vm['size']}\t{avg_cpu:.0f}")

    # 5. Ergebnisdatei schreiben
    with open('analysis-underutilized-vms.tsv', 'w') as f:
        for line in results:
            f.write(line + '\n')
            
    print("--------------------------------------------------")
    print(f"Found {len(results)} underutilized VMs.")

if __name__ == "__main__":
    # Dieser Block ermöglicht es uns, das Skript direkt auszuführen.
    # Im Fehlerfall wird das Programm mit einem Fehlercode beendet.
    try:
        main()
    except Exception as e:
        print(f"ERROR: An unexpected error occurred: {e}", file=sys.stderr)
        sys.exit(1)
