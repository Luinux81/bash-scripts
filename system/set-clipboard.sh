#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Copia la entrada estándar al portapapeles
# USAGE
#   echo "texto" | ./set-clipboard.sh
#   cat archivo.txt | ./set-clipboard.sh
#####################################################################

# Verificar que xclip está instalado
if ! command -v xclip &> /dev/null; then
    echo "Error: xclip no está instalado" >&2
    echo "Instálalo con: sudo apt install xclip" >&2
    exit 1
fi

# Leer de stdin y copiar al portapapeles
# Eliminar códigos de color ANSI antes de copiar
sed 's/\x1b\[[0-9;]*m//g' | xclip -selection clipboard

echo "✅ Contenido copiado al portapapeles!" >&2