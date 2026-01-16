import os
import json
import sys
from datetime import datetime, timedelta, timezone
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.monitor import MonitorManagementClient
from itertools import chain

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

def get_avg_cpu(credential, subscription_id, vm_id, start_iso, end_iso):
    monitor_client = MonitorManagementClient(credential, subscription_id)
    metrics_data = monitor_client.metrics.list(
        vm_id,
        metricnames="Percentage CPU",
        aggregation="Average",
        timespan=f"{start_iso}/{end_iso}",
        interval="P1D"
    )
    try:
        avg = metrics_data.value[0].timeseries[0].data[0].average
        if avg is None:
            return 0.0
        return avg
    except (IndexError, TypeError, AttributeError):
        return 0.0

def analyze_vm(credential, subscription_id, vm, rg, start_iso, end_iso, cpu_treshold):
    avg_cpu = get_avg_cpu(credential, subscription_id, vm['id'], start_iso, end_iso)
    if avg_cpu == 0.0:
        print (f"     - VM: {vm['name']}, Avg CPU: N/A (No metrics found)")
    else:
        print (f"     - VM: {vm['name']}, Avg CPU: {avg_cpu:.2f}%")
    if avg_cpu < cpu_treshold:
        print("       -> MARKED as underutilized.")
        return f"{vm['name']}\t{rg}\t{vm['size']}\t{avg_cpu:.0f}"
    return None

def analyze_resource_group(credential, subscription_id, rg, start_iso, end_iso, cpu_treshold):
    print(f"   - Scanning resource group: {rg}")
    running_vms = get_running_vms(credential, subscription_id, rg)
    return filter(
        None,
        (
            analyze_vm(credential, subscription_id, vm, rg, start_iso, end_iso, cpu_treshold) for vm in running_vms
        )
    )
    
# --- Hauptlogik ---

def main():
    # 1. Konfiguration lesen
    with open('runtime_config.json', 'r') as f:
        config = json.load(f)
    
    vm_config = config['analysis_modules']['underutilized_vms']
    excluded_rgs = set(config['global_settings']['excluded_resource_groups'])
    
    evaluation_days = vm_config.get('evaluation_period_days', 7)
    cpu_threshold = vm_config.get('max_cpu_percentage_threshold', 5)

    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(days=evaluation_days)

    # ISO 8601 Format für Azure API
    start_iso = start_time.replace(microsecond=0).isoformat().replace('+00:00', 'Z')
    end_iso = end_time.replace(microsecond=0).isoformat().replace('+00:00', 'Z')

    print(f"INFO: Searching for VMs with CPU below {cpu_threshold}% over {evaluation_days} days.")

    # 2. Azure-Verbindung herstellen
    credential = get_azure_credential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]

    # 3. Ressourcengruppen filtern
    all_rgs = get_all_resource_groups(credential, subscription_id)
    rgs_to_scan = [rg for rg in all_rgs if rg not in excluded_rgs]
    print(f"INFO: Found {len(rgs_to_scan)} resource groups to scan.")

    # 4. VMs analysieren und Ergebnisse schreiben
    results = list(
        chain.from_iterable(
            analyze_resource_group(
                credential,
                subscription_id,
                rg,
                start_iso,
                end_iso,
                cpu_threshold
            )
            for rg in rgs_to_scan
        )
    )

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
