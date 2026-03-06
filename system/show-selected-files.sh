#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# SYNOPSIS
#   Selecciona archivos usando FZF y muestra su contenido.
# DESCRIPTION
#   Interactúa con FZF para selección múltiple de archivos y luego 
#   muestra su contenido via get-file-contents.sh.
# USAGE
#   ./show-selected-files.sh [directorio] [--clipboard]
# EXAMPLES
#   ./show-selected-files.sh                    # Usa directorio actual
#   ./show-selected-files.sh .                  # Usa directorio actual
#   ./show-selected-files.sh /ruta              # Usa ruta específica
#   ./show-selected-files.sh . --clipboard      # Copia al portapapeles
#####################################################################

# Colores para output
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RESET='\033[0m'

# 1. Detectar directorio raíz del repositorio
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 2. Procesar argumentos
START_DIR="$(pwd)"
COPY_TO_CLIPBOARD=false

for arg in "$@"; do
    if [[ "$arg" == "--clipboard" ]] || [[ "$arg" == "-c" ]]; then
        COPY_TO_CLIPBOARD=true
    elif [[ -d "$arg" ]]; then
        START_DIR="$(cd "$arg" && pwd)"
    elif [[ "$arg" != "--clipboard" ]] && [[ "$arg" != "-c" ]]; then
        echo -e "${COLOR_RED}Error: El directorio '$arg' no existe${COLOR_RESET}" >&2
        exit 1
    fi
done

echo -e "${COLOR_CYAN}📁 Repo raíz detectada: ${REPO_ROOT}${COLOR_RESET}"
echo -e "${COLOR_CYAN}📂 Buscando archivos desde: ${START_DIR}${COLOR_RESET}"

# 3. Definir rutas
MODULE_PATH="${REPO_ROOT}/modulos/FileHelper/file-helper.sh"
GET_FILE_CONTENTS_SCRIPT="${REPO_ROOT}/scripts/filesystem/get-file-contents.sh"
SET_CLIPBOARD_SCRIPT="${REPO_ROOT}/scripts/utils/set-clipboard.sh"

# 4. Verificar que FZF está instalado
if ! command -v fzf &> /dev/null; then
    echo -e "${COLOR_RED}Error: fzf no está instalado${COLOR_RESET}" >&2
    echo "Instálalo con: sudo apt install fzf (Ubuntu/Debian) o brew install fzf (macOS)" >&2
    exit 1
fi

# 5. Si se requiere clipboard, verificar xclip
if [[ "$COPY_TO_CLIPBOARD" == true ]] && ! command -v xclip &> /dev/null; then
    echo -e "${COLOR_RED}Error: xclip no está instalado (necesario para --clipboard)${COLOR_RESET}" >&2
    echo "Instálalo con: sudo apt install xclip" >&2
    exit 1
fi

# 6. Importar funciones del módulo (si existe)
if [[ -f "${MODULE_PATH}" ]]; then
    source "${MODULE_PATH}"
fi

# 7. Verificar script de get-file-contents
if [[ ! -f "${GET_FILE_CONTENTS_SCRIPT}" ]]; then
    echo -e "${COLOR_RED}Error: No se encontró el script get-file-contents.sh en: ${GET_FILE_CONTENTS_SCRIPT}${COLOR_RESET}" >&2
    exit 1
fi

# 8. Cambiar al directorio deseado ANTES de buscar archivos
cd "${START_DIR}"

# 9. Función para seleccionar archivos con FZF
select_files_with_fzf() {
    # Ya estamos en el directorio correcto gracias al cd anterior
    
    # Usar fd si está disponible, sino usar find
    if command -v fd &> /dev/null; then
        fd --type f --hidden --exclude .git --exclude node_modules \
            | fzf --multi \
                  --height=80% \
                  --border \
                  --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || cat {}' \
                  --preview-window=right:60% \
                  --prompt="📄 Selecciona archivos (TAB para marcar, Enter para confirmar): " \
                  --header="Navegando desde: ${START_DIR}"
    else
        find . -type f \
            ! -path "*/.git/*" \
            ! -path "*/node_modules/*" \
            -printf '%P\n' \
            | fzf --multi \
                  --height=80% \
                  --border \
                  --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null || cat {}' \
                  --preview-window=right:60% \
                  --prompt="📄 Selecciona archivos (TAB para marcar, Enter para confirmar): " \
                  --header="Navegando desde: ${START_DIR}"
    fi
}

# 10. Llamar a FZF para seleccionar archivos
mapfile -t SELECTED_FILES < <(select_files_with_fzf)

# 11. Verificar si se seleccionaron archivos
if [[ ${#SELECTED_FILES[@]} -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}⚠️  No se seleccionó ningún archivo.${COLOR_RESET}"
    exit 0
fi

# 12. Convertir rutas relativas a absolutas
ABSOLUTE_PATHS=()
for file in "${SELECTED_FILES[@]}"; do
    if [[ "${file}" = /* ]]; then
        # Ya es ruta absoluta
        ABSOLUTE_PATHS+=("${file}")
    else
        # Convertir a ruta absoluta desde START_DIR
        ABSOLUTE_PATHS+=("${START_DIR}/${file}")
    fi
done

# 13. Mostrar contenido de los archivos seleccionados
if [[ "$COPY_TO_CLIPBOARD" == true ]]; then
    # Guardar en archivo temporal, mostrar y copiar
    TEMP_OUTPUT=$(mktemp)
    "${GET_FILE_CONTENTS_SCRIPT}" "${ABSOLUTE_PATHS[@]}" | tee "$TEMP_OUTPUT"
    
    # Copiar al portapapeles (eliminar códigos ANSI)
    sed 's/\x1b\[[0-9;]*m//g' "$TEMP_OUTPUT" | xclip -selection clipboard
    echo -e "\n${COLOR_GREEN}✅ Contenido copiado al portapapeles!${COLOR_RESET}"
    
    # Limpiar
    rm -f "$TEMP_OUTPUT"
else
    # Solo mostrar
    "${GET_FILE_CONTENTS_SCRIPT}" "${ABSOLUTE_PATHS[@]}"
fi