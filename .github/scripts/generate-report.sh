#!/bin/bash

# ==============================================================================
# generate-report.sh
#
# Zweck: Liest die analyse-*.tsv Dateien und erstellt einen sauberen
#        Markdown-Report (report.md).
# ==============================================================================

# --- Initialisierung ---
REPORT_FILE="report.md"

# Erstellt die Kopfzeile des Reports
cat > $REPORT_FILE << EOF
# Kosten-Optimierungs-Report
Dieser Report fasst die Ergebnisse der automatisierten FinOps-Analyse zusammen.
EOF

# --- Hilfsfunktion zum Erstellen einer Tabelle ---
# Diese Funktion macht den Code sauberer und vermeidet Wiederholungen.
#
# Verwendung: create_table "Titel" "Header" "tsv_file"
# Beispiel: create_table "Verwaiste Festplatten" "| Name | Resource Group | Size (GB) | Location |" "analysis-unattached-disks.tsv"
#
create_table() {
    local title="$1"
    local header="$2"
    local file="$3"
    
    # Prüfen, ob die Datei existiert und nicht leer ist
    if [ -s "$file" ]; then
        echo "" >> $REPORT_FILE
        echo "## $title" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        echo "$header" >> $REPORT_FILE
        
        # Erzeugt die korrekte Trennlinie basierend auf der Anzahl der Spalten im Header
        local num_columns=$(echo "$header" | awk -F'|' '{print NF-2}')
        local separator="| $(printf -- '-%.0s' {1..10}) "
        local full_separator=""
        for ((i=1; i<=num_columns; i++)); do
            full_separator+="$separator"
        done
        full_separator+="|"
        echo "$full_separator" >> $REPORT_FILE

        # Fügt die Datenzeilen hinzu, indem jede Zeile mit "|" umschlossen und die Tabs durch "|" ersetzt werden
        while IFS= read -r line; do
            echo "| $line |" | sed 's/\t/ | /g' >> $REPORT_FILE
        done < "$file"
    else
        # Gibt eine freundliche Nachricht aus, wenn keine Ergebnisse gefunden wurden
        echo "" >> $REPORT_FILE
        echo "## $title" >> $REPORT_FILE
        echo "" >> $REPORT_FILE
        echo "*✅ Keine relevanten Ressourcen in dieser Kategorie gefunden.*" >> $REPORT_FILE
    fi
}

# --- Tabellen erstellen ---
# Ruft die Hilfsfunktion für jede Analyse-Datei auf.

create_table "Verwaiste Festplatten" \
             "| Name | Resource Group | Size (GB) | Location |" \
             "analysis-unattached-disks.tsv"

create_table "Ungenutzte öffentliche IPs" \
             "| Name | Resource Group | IP Address | Location |" \
             "analysis-unassociated-public-ips.tsv"

# Holt die Aufbewahrungstage aus der Konfigurationsdatei für einen dynamischen Titel
RETENTION_DAYS=$(jq -r '.analysis_modules.old_snapshots.retention_days' finops.config.json 2>/dev/null || echo "90")
create_table "Alte Snapshots (>${RETENTION_DAYS} Tage)" \
             "| Name | Resource Group | Size (GB) | Location |" \
             "analysis-old-snapshots.tsv"

create_table "Azure Advisor Empfehlungen" \
             "| Beschreibung | Ressource | Kategorie |" \
             "analysis-azure-advisor-recommendations.tsv"


# --- Fußzeile ---
# Fügt den Zeitstempel am Ende des Reports hinzu
echo "" >> $REPORT_FILE
echo "---" >> $REPORT_FILE
echo "*Dieser Report wurde automatisch am $(date) generiert.*" >> $REPORT_FILE

echo "✅ Report 'report.md' wurde erfolgreich generiert."

