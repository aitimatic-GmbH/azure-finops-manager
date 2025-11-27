#!/bin/bash

# Definiert den Namen der finalen Report-Datei.
OUTPUT_FILE="report.md"

# Erstellt eine leere Report-Datei und schreibt den Haupt-Titel.
echo "# Kosten-Optimierungs-Report" > $OUTPUT_FILE
echo "" >> $OUTPUT_FILE
echo "Dieser Report fasst die Ergebnisse der automatisierten FinOps-Analyse zusammen." >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# --- Funktion zur Verarbeitung einer einzelnen TSV-Datei ---
# Nimmt den Dateipfad, den Titel für den Report-Abschnitt und die Spaltenüberschriften als Argumente.
function process_tsv_file() {
    local file_path=$1
    local title=$2
    local headers=$3

    # Prüft, ob die Datei existiert und nicht leer ist.
    if [ -s "$file_path" ]; then
        echo "Verarbeite Datei: $file_path"
        
        # Fügt den Abschnitt zum Report hinzu.
        echo "## $title" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        
        # Konvertiert die TSV-Daten in eine Markdown-Tabelle.
        {
            echo "$headers"
            # Erstellt die Trennlinie für die Markdown-Tabelle dynamisch.
            echo "$headers" | sed 's/|/|--/g'
            # Liest die TSV-Datei und formatiert sie.
            cat "$file_path" | awk -F'\t' '{
                printf "| "
                for(i=1; i<=NF; i++) {
                    printf "%s | ", $i
                }
                printf "\n"
            }'
        } >> $OUTPUT_FILE
        
        echo "" >> $OUTPUT_FILE
    fi
}

# --- Haupt-Logik: Ruft die Funktion für jede erwartete Datei auf ---
process_tsv_file "analysis-unattached-disks.tsv" "Verwaiste Festplatten" "| Name | Resource Group | Size (GB) | Location |"
process_tsv_file "analysis-unassociated-public-ips.tsv" "Ungenutzte öffentliche IPs" "| Name | Resource Group | IP Address | Location |"
process_tsv_file "analysis-old-snapshots.tsv" "Alte Snapshots (>90 Tage)" "| Name | Resource Group | Size (GB) | Location |"
process_tsv_file "analysis-azure-advisor-recommendations.tsv" "Azure Advisor Empfehlungen" "| Beschreibung | Ressource | Kategorie |"
# Hier können wir einfach neue Zeilen für zukünftige Analyse-Module hinzufügen.

# Fügt den Footer hinzu.
echo "---" >> $OUTPUT_FILE
echo "*Dieser Report wurde automatisch am $(date) generiert.*" >> $OUTPUT_FILE

echo "Finaler Report '$OUTPUT_FILE' wurde erfolgreich erstellt."
