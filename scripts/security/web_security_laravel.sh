#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Endurece la seguridad de una aplicación Laravel a nivel de sistema
# DESCRIPTION
#   Configura permisos y propietarios de archivos para minimizar
#   riesgos de seguridad en aplicaciones Laravel en producción.
# USAGE
#   sudo ./web_security_laravel.sh [APP_PATH] [--web-user USER] [--owner USER] [--force]
# EXAMPLES
#   sudo ./web_security_laravel.sh /var/www/myapp
#   sudo ./web_security_laravel.sh /var/www/myapp --web-user nginx --owner deploy
#   sudo ./web_security_laravel.sh /var/www/myapp --force
#   sudo ./web_security_laravel.sh --web-user www-data --owner john /var/www/app --force
# NOTES
#   - Requiere permisos de superusuario (sudo)
#   - Recuerda configurar Nginx según las instrucciones finales
#####################################################################

set -euo pipefail

# --- COLORES ---
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
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
    --force                 Omite la confirmación interactiva
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

    # Ejecutar sin confirmación (útil para scripts automatizados)
    sudo $0 /var/www/myapp --force

NOTA: Este script debe ejecutarse con sudo o como root.
EOF
    exit 0
}

# --- PROCESAMIENTO DE ARGUMENTOS ---
APP_PATH=""
WEB_USER="$DEFAULT_WEB_USER"
OWNER_USER="$DEFAULT_OWNER_USER"
FORCE_MODE=false

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
        --force)
            FORCE_MODE=true
            shift
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
LARAVEL_WARNING=""

for dir in "${LARAVEL_DIRS[@]}"; do
    if [[ -d "$APP_PATH/$dir" ]]; then
        FOUND_DIRS=$((FOUND_DIRS + 1))
    else
        MISSING_DIRS+=("$dir")
    fi
done

# Determinar el estado de la validación
if [[ $FOUND_DIRS -ge 5 ]] && [[ -f "$APP_PATH/artisan" ]] && [[ -f "$APP_PATH/composer.json" ]]; then
    # Estructura Laravel válida
    echo -e "${COLOR_GREEN}✅ Estructura de Laravel detectada correctamente${COLOR_RESET}"
    LARAVEL_WARNING=""
elif [[ $FOUND_DIRS -lt 5 ]]; then
    # Faltan muchos directorios típicos
    echo -e "${COLOR_RED}⚠️  ADVERTENCIA: Este directorio NO parece ser una aplicación Laravel${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Directorios típicos encontrados: $FOUND_DIRS de ${#LARAVEL_DIRS[@]}${COLOR_RESET}"
    if [[ ${#MISSING_DIRS[@]} -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}   Directorios faltantes: ${MISSING_DIRS[*]}${COLOR_RESET}"
    fi
    LARAVEL_WARNING="NOT_LARAVEL"
else
    # Tiene los directorios pero faltan archivos clave
    echo -e "${COLOR_YELLOW}⚠️  Advertencia: Algunos archivos típicos de Laravel no fueron encontrados${COLOR_RESET}"
    LARAVEL_WARNING="PARTIAL"
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

# Mostrar warning de Laravel si existe
if [[ "$LARAVEL_WARNING" == "NOT_LARAVEL" ]]; then
    echo -e "${COLOR_RED}⚠️  ADVERTENCIA: Este directorio NO parece ser una aplicación Laravel${COLOR_RESET}"
    echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Directorios típicos de Laravel encontrados: $FOUND_DIRS de ${#LARAVEL_DIRS[@]}${COLOR_RESET}"
    if [[ ${#MISSING_DIRS[@]} -gt 0 ]]; then
        echo -e "${COLOR_YELLOW}   Directorios faltantes: ${MISSING_DIRS[*]}${COLOR_RESET}"
    fi
    echo -e "${COLOR_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
elif [[ "$LARAVEL_WARNING" == "PARTIAL" ]]; then
    echo -e "${COLOR_YELLOW}⚠️  Advertencia: Algunos archivos típicos de Laravel no fueron encontrados${COLOR_RESET}"
    echo ""
fi

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
echo -e "  • *.sqlite: ${COLOR_YELLOW}664${COLOR_RESET} (rw-rw-r--) ${COLOR_BLUE}[si existen]${COLOR_RESET}"
echo ""

# Prompt de confirmación (omitir si --force está activo)
if [[ "$FORCE_MODE" == false ]]; then
    read -p "¿Deseas continuar? (escribe 'si' para confirmar): " -r CONFIRM
    echo ""

    if [[ ! "$CONFIRM" =~ ^(si|SI|Si|sí|SÍ|Sí|yes|YES|Yes)$ ]]; then
        echo -e "${COLOR_YELLOW}❌ Operación cancelada por el usuario${COLOR_RESET}"
        exit 0
    fi

    echo -e "${COLOR_GREEN}✅ Confirmado. Iniciando proceso...${COLOR_RESET}"
else
    echo -e "${COLOR_GREEN}✅ Modo --force activado. Procediendo sin confirmación...${COLOR_RESET}"
fi
echo ""

# 1. RESETEAR PROPIEDAD
# Establecemos al usuario propietario como dueño y al usuario web como grupo.
# Esto asegura que el servidor web no sea el 'dueño' de los archivos.
echo -e "${COLOR_GREEN}👤 Ajustando propietarios a $OWNER_USER:$WEB_USER...${COLOR_RESET}"
chown -R "$OWNER_USER:$WEB_USER" "$APP_PATH"

# 2. PERMISOS DE ARCHIVOS Y DIRECTORIOS
# Directorios en 755 (rwxr-xr-x) y Archivos en 644 (rw-r--r--)
# Con esto, el usuario web puede leer y ejecutar la web, pero NO puede escribir.
# Nota: Usamos u=rwX,g=rX,o=rX para preservar bits especiales (como SGID)
# mientras aplicamos los permisos base deseados
echo -e "${COLOR_GREEN}🔒 Aplicando permisos 755/644 (Solo lectura para el servidor web)...${COLOR_RESET}"
find "$APP_PATH" -type d -exec chmod u=rwx,g=rx,o=rx {} \;
find "$APP_PATH" -type f -exec chmod u=rw,g=r,o=r {} \;

# 3. EXCEPCIONES PARA LARAVEL (ESCRITURA)
# Solo las carpetas que Laravel necesita obligatoriamente para funcionar.
# Nota: Usamos u=rwx,g=rwx,o=rx para preservar bits especiales como SGID
echo -e "${COLOR_GREEN}📂 Otorgando permisos de escritura solo en storage y cache...${COLOR_RESET}"
if [[ -d "$APP_PATH/storage" ]]; then
    chmod -R u=rwx,g=rwx,o=rx "$APP_PATH/storage"
fi

if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
    chmod -R u=rwx,g=rwx,o=rx "$APP_PATH/bootstrap/cache"
fi

# MANEJO ESPECIAL PARA SQLITE
# SQLite necesita permisos de escritura tanto en el archivo .sqlite como en su directorio
echo -e "${COLOR_GREEN}💾 Verificando bases de datos SQLite...${COLOR_RESET}"

# Buscar archivos .sqlite en database/
if [[ -d "$APP_PATH/database" ]]; then
    SQLITE_FILES=$(find "$APP_PATH/database" -type f -name "*.sqlite" 2>/dev/null)
    
    if [[ -n "$SQLITE_FILES" ]]; then
        echo -e "${COLOR_YELLOW}   ℹ️  Se encontraron bases de datos SQLite${COLOR_RESET}"
        
        while IFS= read -r sqlite_file; do
            if [[ -f "$sqlite_file" ]]; then
                # El archivo SQLite debe ser escribible por el grupo
                chmod 664 "$sqlite_file"
                echo -e "${COLOR_YELLOW}      • $(basename "$sqlite_file"): permisos 664 (rw-rw-r--)${COLOR_RESET}"
                
                # El directorio que contiene el SQLite también debe ser escribible
                sqlite_dir=$(dirname "$sqlite_file")
                chmod 775 "$sqlite_dir"
            fi
        done <<< "$SQLITE_FILES"
    fi
fi

# También verificar en storage/database/ (ubicación alternativa)
if [[ -d "$APP_PATH/storage/database" ]]; then
    SQLITE_FILES=$(find "$APP_PATH/storage/database" -type f -name "*.sqlite" 2>/dev/null)
    
    if [[ -n "$SQLITE_FILES" ]]; then
        while IFS= read -r sqlite_file; do
            if [[ -f "$sqlite_file" ]]; then
                chmod 664 "$sqlite_file"
                echo -e "${COLOR_YELLOW}      • storage/$(basename "$sqlite_file"): permisos 664 (rw-rw-r--)${COLOR_RESET}"
            fi
        done <<< "$SQLITE_FILES"
    fi
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
echo -e "${COLOR_YELLOW}⚠️  ¡ATENCIÓN: CONFIGURACIÓN REQUERIDA EN NGINX! ⚠️${COLOR_RESET}"
echo ""
echo "Para completar el endurecimiento de seguridad, añade esta sección"
echo "a tu configuración de Nginx (dentro del bloque 'server'):"
echo ""
echo -e "${COLOR_YELLOW}    # --- SEGURIDAD WEB ---${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}    # 1. PERMITIR ÚNICAMENTE el punto de entrada de Laravel${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    # El uso de \"=\" da prioridad máxima y exclusividad.${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    location = /index.php {${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        fastcgi_param SCRIPT_FILENAME \\\$realpath_root\\\$fastcgi_script_name;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        include fastcgi_params;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        fastcgi_hide_header X-Powered-By; # Oculta que usas PHP${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    }${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}    # 2. BLOQUEAR CUALQUIER OTRO ARCHIVO .php${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    # Cualquier intento de ejecutar otro archivo .php en public o subcarpetas${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    # morirá aquí con un 403, protegiéndote de WebShells subidas.${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    location ~ \\.php\$ {${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        deny all;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        return 403;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    }${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}    # --- BLOQUEO DE ARCHIVOS SENSIBLES Y OCULTOS ---${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}    # Bloquear archivos que empiezan por punto (.env, .git, .htaccess, etc.)${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    # Exceptuamos .well-known para que Certbot pueda renovar certificados.${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    location ~ /\\.(?!well-known).* {${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        deny all;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    }${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}    # Bloquear extensiones peligrosas o de backup${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    location ~* \\.(env|log|sql|git|sh|bak|config|php~)\$ {${COLOR_RESET}"
echo -e "${COLOR_YELLOW}        deny all;${COLOR_RESET}"
echo -e "${COLOR_YELLOW}    }${COLOR_RESET}"
echo ""
echo "Después de añadir estas reglas, verifica y recarga Nginx:"
echo ""
echo -e "${COLOR_GREEN}  sudo nginx -t${COLOR_RESET}"
echo -e "${COLOR_GREEN}  sudo systemctl reload nginx${COLOR_RESET}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"