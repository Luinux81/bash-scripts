#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Muestra el contenido de uno o más archivos
# USAGE
#   ./get-file-contents.sh archivo1.txt archivo2.txt
#####################################################################

set -euo pipefail

readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

if [[ $# -eq 0 ]]; then
    echo "Error: No se proporcionaron archivos" >&2
    echo "Uso: $0 archivo1 [archivo2 ...]" >&2
    exit 1
fi

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo -e "${COLOR_BLUE}⚠️  Archivo no encontrado: ${file}${COLOR_RESET}" >&2
        continue
    fi
    
    echo -e "\n${COLOR_GREEN}═══════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_GREEN}📄 Archivo: ${file}${COLOR_RESET}"
    echo -e "${COLOR_GREEN}═══════════════════════════════════════════════════════${COLOR_RESET}\n"
    
    # Usar bat si está disponible, sino cat
    if command -v bat &> /dev/null; then
        bat --style=numbers,grid --color=always "$file"
    else
        cat "$file"
    fi
    
    echo -e "\n"
done