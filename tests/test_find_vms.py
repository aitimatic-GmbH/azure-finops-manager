import unittest
from unittest.mock import patch, MagicMock
import os
import json

# Importiere das Skript, das wir testen wollen
# Wir müssen den Pfad anpassen, damit Python es findet
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../.github/scripts')))
import find_underutilized_vms

class TestFindVMs(unittest.TestCase):

    @patch('find_underutilized_vms.get_azure_credential')
    @patch('find_underutilized_vms.get_all_resource_groups')
    @patch('find_underutilized_vms.get_running_vms')
    @patch('find_underutilized_vms.get_avg_cpu')
    def test_main_logic(self, mock_get_avg_cpu, mock_get_running_vms, mock_get_all_rgs, mock_get_credential):
        """
        Testet die Hauptlogik mit gemockten Azure-Aufrufen.
        """
        # --- Setup der Mocks ---
        # Simuliere, dass wir 2 RGs finden
        mock_get_all_rgs.return_value = ['rg-test-1', 'rg-excluded']
        
        # Simuliere, dass wir in rg-test-1 zwei VMs finden
        mock_get_running_vms.return_value = [
            {'id': '.../vm-low-cpu', 'name': 'vm-low-cpu', 'size': 'Standard_B1s'},
            {'id': '.../vm-high-cpu', 'name': 'vm-high-cpu', 'size': 'Standard_B1s'}
        ]
        
        # Simuliere die CPU-Antworten
        # Wenn get_avg_cpu mit der ID von vm-low-cpu aufgerufen wird, gib 2.0 zurück.
        # Wenn es mit der ID von vm-high-cpu aufgerufen wird, gib 25.0 zurück.
        def cpu_side_effect(cred, sub, vm_id, start, end):
            if 'vm-low-cpu' in vm_id:
                return 2.0
            if 'vm-high-cpu' in vm_id:
                return 25.0
            return 0.0
        mock_get_avg_cpu.side_effect = cpu_side_effect

        # Erstelle eine gefälschte runtime_config.json
        mock_config = {
            "analysis_modules": { "underutilized_vms": { "evaluation_period_days": 7, "max_cpu_percentage_threshold": 5 }},
            "global_settings": { "excluded_resource_groups": ["rg-excluded"] }
        }
        with open('runtime_config.json', 'w') as f:
            json.dump(mock_config, f)
            
        # Setze die notwendige Umgebungsvariable
        os.environ["AZURE_SUBSCRIPTION_ID"] = "mock-sub-id"

        # --- Ausführung ---
        find_underutilized_vms.main()

        # --- Überprüfung ---
        with open('analysis-underutilized-vms.tsv', 'r') as f:
            lines = f.readlines()
            
        # Wir erwarten genau eine Zeile im Ergebnis
        self.assertEqual(len(lines), 1)
        # Und diese Zeile sollte die vm-low-cpu enthalten
        self.assertIn('vm-low-cpu', lines[0])
        self.assertNotIn('vm-high-cpu', lines[0])

        # --- Aufräumen ---
        os.remove('runtime_config.json')
        os.remove('analysis-underutilized-vms.tsv')

# Erlaube die Ausführung des Tests direkt aus der Kommandozeile
if __name__ == '__main__':
    unittest.main()
