#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Endurece la seguridad de una aplicación Laravel a nivel de sistema
# DESCRIPTION
#   Configura permisos y propietarios de archivos para minimizar
#   riesgos de seguridad en aplicaciones Laravel en producción.
# USAGE
#   sudo ./web_security_laravel.sh [APP_PATH] [--web-user USER] [--owner USER]
# EXAMPLES
#   sudo ./web_security_laravel.sh /var/www/myapp
#   sudo ./web_security_laravel.sh /var/www/myapp --web-user nginx --owner deploy
#   sudo ./web_security_laravel.sh --web-user www-data --owner john /var/www/app
# NOTES
#   - Requiere permisos de superusuario (sudo)
#   - Recuerda configurar Nginx según las instrucciones finales
#####################################################################

set -euo pipefail

# --- COLORES ---
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RESET='\033[0m'

# --- VALORES POR DEFECTO ---
DEFAULT_APP_PATH="$(pwd)"
DEFAULT_WEB_USER="www-data"
DEFAULT_OWNER_USER="${SUDO_USER:-$(whoami)}"

# --- FUNCIÓN DE AYUDA ---
show_usage() {
    cat << EOF
Uso: sudo $0 [APP_PATH] [OPCIONES]

Endurece la seguridad de una aplicación Laravel configurando permisos apropiados.

ARGUMENTOS:
    APP_PATH                Ruta a la aplicación Laravel
                            Default: directorio actual

OPCIONES:
    --web-user USER         Usuario del servidor web
                            Default: www-data
    --owner USER            Usuario propietario de los archivos
                            Default: usuario que ejecuta sudo (o usuario actual)
    -h, --help              Muestra esta ayuda

EJEMPLOS:
    # Aplicar en el directorio actual con defaults
    sudo $0

    # Especificar ruta de la aplicación
    sudo $0 /var/www/myapp

    # Cambiar usuario web (ej: nginx en lugar de www-data)
    sudo $0 /var/www/myapp --web-user nginx

    # Especificar todos los parámetros
    sudo $0 /var/www/myapp --web-user nginx --owner deploy

NOTA: Este script debe ejecutarse con sudo o como root.
EOF
    exit 0
}

# --- PROCESAMIENTO DE ARGUMENTOS ---
APP_PATH=""
WEB_USER="$DEFAULT_WEB_USER"
OWNER_USER="$DEFAULT_OWNER_USER"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            ;;
        --web-user)
            if [[ -z "${2:-}" ]]; then
                echo -e "${COLOR_RED}Error: --web-user requiere un argumento${COLOR_RESET}" >&2
                exit 1
            fi
            WEB_USER="$2"
            shift 2
            ;;
        --owner)
            if [[ -z "${2:-}" ]]; then
                echo -e "${COLOR_RED}Error: --owner requiere un argumento${COLOR_RESET}" >&2
                exit 1
            fi
            OWNER_USER="$2"
            shift 2
            ;;
        -*)
            echo -e "${COLOR_RED}Error: Opción desconocida: $1${COLOR_RESET}" >&2
            echo "Usa --help para ver las opciones disponibles" >&2
            exit 1
            ;;
        *)
            if [[ -z "$APP_PATH" ]]; then
                APP_PATH="$1"
            else
                echo -e "${COLOR_RED}Error: Múltiples rutas especificadas${COLOR_RESET}" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Si no se especificó APP_PATH, usar el valor por defecto
if [[ -z "$APP_PATH" ]]; then
    APP_PATH="$DEFAULT_APP_PATH"
fi

# Convertir a ruta absoluta
APP_PATH="$(cd "$APP_PATH" 2>/dev/null && pwd)" || {
    echo -e "${COLOR_RED}Error: No se puede acceder al directorio '$APP_PATH'${COLOR_RESET}" >&2
    exit 1
}

# --- VALIDACIONES ---
# Verificar que el directorio existe
if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${COLOR_RED}Error: El directorio '$APP_PATH' no existe${COLOR_RESET}" >&2
    exit 1
fi

# Verificar que se está ejecutando como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_RED}Error: Este script debe ejecutarse con sudo o como root${COLOR_RESET}" >&2
    exit 1
fi

# Verificar que los usuarios existen
if ! id "$WEB_USER" &>/dev/null; then
    echo -e "${COLOR_RED}Error: El usuario '$WEB_USER' no existe en el sistema${COLOR_RESET}" >&2
    exit 1
fi

if ! id "$OWNER_USER" &>/dev/null; then
    echo -e "${COLOR_RED}Error: El usuario '$OWNER_USER' no existe en el sistema${COLOR_RESET}" >&2
    exit 1
fi

# --- VALIDACIÓN DE ESTRUCTURA LARAVEL ---
echo ""
echo -e "${COLOR_YELLOW}🔍 Verificando estructura de Laravel...${COLOR_RESET}"

# Directorios típicos de Laravel
LARAVEL_DIRS=("app" "bootstrap" "config" "database" "public" "resources" "routes" "storage")
MISSING_DIRS=()
FOUND_DIRS=0

for dir in "${LARAVEL_DIRS[@]}"; do
    if [[ -d "$APP_PATH/$dir" ]]; then
        ((FOUND_DIRS++))
    else
        MISSING_DIRS+=("$dir")
    fi
done

# Si faltan más de 3 directorios típicos, mostrar advertencia
if [[ $FOUND_DIRS -lt 5 ]]; then
    echo ""
    echo -e "${COLOR_RED}⚠️  ADVERTENCIA: Este directorio NO parece ser una aplicación Laravel${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}Directorios típicos de Laravel encontrados: $FOUND_DIRS de ${#LARAVEL_DIRS[@]}${COLOR_RESET}"

    if [[ ${#MISSING_DIRS[@]} -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}Directorios faltantes: ${MISSING_DIRS[*]}${COLOR_RESET}"
    fi

    echo -e "${COLOR_YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}¿Estás seguro de que quieres aplicar permisos de Laravel en este directorio?${COLOR_RESET}"
    echo ""
elif [[ -f "$APP_PATH/artisan" ]] && [[ -f "$APP_PATH/composer.json" ]]; then
    echo -e "${COLOR_GREEN}✅ Estructura de Laravel detectada correctamente${COLOR_RESET}"
else
    echo -e "${COLOR_YELLOW}⚠️  Advertencia: Algunos archivos típicos de Laravel no fueron encontrados${COLOR_RESET}"
fi

# --- MOSTRAR CONFIGURACIÓN Y CONFIRMACIÓN ---
echo ""
echo -e "${COLOR_GREEN}🛡️ Configuración de Endurecimiento de Seguridad${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📁 Ruta completa:  ${COLOR_YELLOW}$APP_PATH${COLOR_RESET}"
echo -e "👤 Propietario:    ${COLOR_YELLOW}$OWNER_USER${COLOR_RESET}"
echo -e "🌐 Usuario Web:    ${COLOR_YELLOW}$WEB_USER${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${COLOR_YELLOW}⚠️  Este script modificará los permisos de TODOS los archivos en:${COLOR_RESET}"
echo -e "${COLOR_YELLOW}   $APP_PATH${COLOR_RESET}"
echo ""
echo -e "Los cambios que se aplicarán:"
echo -e "  • Propietario: ${COLOR_YELLOW}$OWNER_USER:$WEB_USER${COLOR_RESET}"
echo -e "  • Directorios: ${COLOR_YELLOW}755${COLOR_RESET} (rwxr-xr-x)"
echo -e "  • Archivos: ${COLOR_YELLOW}644${COLOR_RESET} (rw-r--r--)"
echo -e "  • storage/: ${COLOR_YELLOW}775${COLOR_RESET} (rwxrwxr-x)"
echo -e "  • bootstrap/cache/: ${COLOR_YELLOW}775${COLOR_RESET} (rwxrwxr-x)"
echo -e "  • .env: ${COLOR_YELLOW}640${COLOR_RESET} (rw-r-----)"
echo ""

# Prompt de confirmación
read -p "¿Deseas continuar? (escribe 'si' para confirmar): " -r CONFIRM
echo ""

if [[ ! "$CONFIRM" =~ ^(si|SI|Si|sí|SÍ|Sí|yes|YES|Yes)$ ]]; then
    echo -e "${COLOR_YELLOW}❌ Operación cancelada por el usuario${COLOR_RESET}"
    exit 0
fi

echo -e "${COLOR_GREEN}✅ Confirmado. Iniciando proceso...${COLOR_RESET}"
echo ""

# 1. RESETEAR PROPIEDAD
# Establecemos al usuario propietario como dueño y al usuario web como grupo.
# Esto asegura que el servidor web no sea el 'dueño' de los archivos.
echo -e "${COLOR_GREEN}👤 Ajustando propietarios a $OWNER_USER:$WEB_USER...${COLOR_RESET}"
chown -R "$OWNER_USER:$WEB_USER" "$APP_PATH"

# 2. PERMISOS DE ARCHIVOS Y DIRECTORIOS
# Directorios en 755 (rwxr-xr-x) y Archivos en 644 (rw-r--r--)
# Con esto, el usuario web puede leer y ejecutar la web, pero NO puede escribir.
echo -e "${COLOR_GREEN}🔒 Aplicando permisos 755/644 (Solo lectura para el servidor web)...${COLOR_RESET}"
find "$APP_PATH" -type d -exec chmod 755 {} \;
find "$APP_PATH" -type f -exec chmod 644 {} \;

# 3. EXCEPCIONES PARA LARAVEL (ESCRITURA)
# Solo las carpetas que Laravel necesita obligatoriamente para funcionar.
echo -e "${COLOR_GREEN}📂 Otorgando permisos de escritura solo en storage y cache...${COLOR_RESET}"
if [[ -d "$APP_PATH/storage" ]]; then
    chmod -R 775 "$APP_PATH/storage"
fi

if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
    chmod -R 775 "$APP_PATH/bootstrap/cache"
fi

# 4. PROTECCIÓN ESTRICTA DEL .ENV
# Solo el dueño puede leerlo y escribirlo. El servidor web solo leerlo.
echo -e "${COLOR_GREEN}🔑 Asegurando archivo .env...${COLOR_RESET}"
if [[ -f "$APP_PATH/.env" ]]; then
    chmod 640 "$APP_PATH/.env"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${COLOR_GREEN}✅ Proceso de permisos completado. App asegurada a nivel de sistema.${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${COLOR_YELLOW}⚠️  ¡ATENCIÓN: PASO FINAL REQUERIDO EN NGINX! ⚠️${COLOR_RESET}"
echo ""
echo "Para evitar que se ejecuten scripts maliciosos subidos a storage,"
echo "debes añadir esta regla a tu configuración de Nginx:"
echo ""
echo -e "${COLOR_YELLOW}location ~* ^/(storage|uploads|images)/.*\.php$ {${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    deny all;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    return 403;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}}${COLOR_RESET}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

