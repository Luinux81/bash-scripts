#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Verifica la seguridad de una aplicación Laravel a nivel de sistema
# DESCRIPTION
#   Comprueba permisos, propietarios y configuración de Nginx para
#   aplicaciones Laravel en producción.
# USAGE
#   ./check_web_security_laravel.sh [APP_PATH]
#   sudo ./check_web_security_laravel.sh [APP_PATH]  # Recomendado
# EXAMPLES
#   ./check_web_security_laravel.sh
#   ./check_web_security_laravel.sh /var/www/myapp
#   sudo ./check_web_security_laravel.sh /var/www/myapp
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

# --- CONTADORES ---
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# --- FUNCIONES AUXILIARES ---

# Función para normalizar permisos (elimina bits especiales para comparación)
normalize_perms() {
    local perms="$1"
    # Elimina el primer dígito si hay 4 dígitos (bits especiales)
    if [[ ${#perms} -eq 4 ]]; then
        echo "${perms:1}"
    else
        echo "$perms"
    fi
}

# Función para verificar permisos (acepta con o sin bits especiales)
check_permissions() {
    local path="$1"
    local expected="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ ! -e "$path" ]]; then
        echo -e "${COLOR_YELLOW}⚠️  $description no existe${COLOR_RESET}"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        return
    fi
    
    local actual=$(stat -c '%a' "$path" 2>/dev/null || stat -f '%A' "$path" 2>/dev/null)
    local actual_normalized=$(normalize_perms "$actual")
    
    if [[ "$actual_normalized" == "$expected" ]]; then
        echo -e "${COLOR_GREEN}✅ $description tiene permisos $actual_normalized${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ $description tiene permisos $actual (esperado: $expected)${COLOR_RESET}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Función para verificar propietario y grupo
check_ownership() {
    local path="$1"
    local expected_owner="$2"
    local expected_group="$3"
    local description="$4"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [[ ! -e "$path" ]]; then
        echo -e "${COLOR_YELLOW}⚠️  $description no existe${COLOR_RESET}"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
        return
    fi
    
    local actual_owner=$(stat -c '%U' "$path" 2>/dev/null || stat -f '%Su' "$path" 2>/dev/null)
    local actual_group=$(stat -c '%G' "$path" 2>/dev/null || stat -f '%Sg' "$path" 2>/dev/null)
    
    if [[ "$actual_group" == "$expected_group" ]]; then
        echo -e "${COLOR_GREEN}✅ Grupo es $expected_group${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ Grupo es $actual_group (esperado: $expected_group)${COLOR_RESET}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Función para verificar si un usuario puede escribir en un directorio
can_write() {
    local user="$1"
    local path="$2"
    
    if [[ $EUID -eq 0 ]]; then
        # Si somos root, podemos usar sudo
        sudo -u "$user" test -w "$path"
    else
        # Sin sudo, solo podemos verificar el usuario actual
        if [[ "$(whoami)" == "$user" ]]; then
            test -w "$path"
        else
            # No podemos verificar, retornamos éxito para directorios
            # pero fallaremos en archivos sensibles como .env
            if [[ -d "$path" ]]; then
                return 0
            else
                return 1
            fi
        fi
    fi
}

# Función para verificar si un usuario puede leer un archivo
can_read() {
    local user="$1"
    local path="$2"
    
    if [[ $EUID -eq 0 ]]; then
        sudo -u "$user" test -r "$path"
    else
        if [[ "$(whoami)" == "$user" ]]; then
            test -r "$path"
        else
            return 0
        fi
    fi
}

# --- PROCESAMIENTO DE ARGUMENTOS ---
APP_PATH=""

if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << EOF
Uso: $0 [APP_PATH]

Verifica la seguridad de una aplicación Laravel.

ARGUMENTOS:
    APP_PATH    Ruta a la aplicación Laravel (default: directorio actual)

OPCIONES:
    -h, --help  Muestra esta ayuda

NOTA: Se recomienda ejecutar con sudo para verificaciones completas.
EOF
        exit 0
    fi
    APP_PATH="$1"
else
    APP_PATH="$DEFAULT_APP_PATH"
fi

# Convertir a ruta absoluta
APP_PATH="$(cd "$APP_PATH" 2>/dev/null && pwd)" || {
    echo -e "${COLOR_RED}Error: No se puede acceder al directorio '$APP_PATH'${COLOR_RESET}" >&2
    exit 1
}

# Verificar que es un directorio Laravel
if [[ ! -f "$APP_PATH/artisan" ]] || [[ ! -f "$APP_PATH/composer.json" ]]; then
    echo -e "${COLOR_YELLOW}⚠️  Advertencia: Este directorio no parece ser una aplicación Laravel${COLOR_RESET}"
fi

# Advertencia si no se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_YELLOW}Advertencia: Se recomienda ejecutar con sudo para verificaciones completas${COLOR_RESET}"
fi

# --- INICIO DE VERIFICACIÓN ---
echo -e "${COLOR_BLUE}🔍 Verificación de Seguridad de Laravel${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📁 Aplicación: ${COLOR_YELLOW}$APP_PATH${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- VERIFICAR PERMISOS DE DIRECTORIOS ---
echo -e "${COLOR_BLUE}📂 Verificando permisos de directorios...${COLOR_RESET}"

check_permissions "$APP_PATH/storage" "775" "storage/"
check_permissions "$APP_PATH/bootstrap/cache" "775" "bootstrap/cache/"
check_permissions "$APP_PATH/app" "755" "app/"
check_permissions "$APP_PATH/config" "755" "config/"

# database/ puede ser 755 o 775 dependiendo de si hay SQLite
# Si hay archivos .sqlite, debe ser 775 para permitir crear archivos temporales
HAS_SQLITE=false
if [[ -d "$APP_PATH/database" ]]; then
    if find "$APP_PATH/database" -type f -name "*.sqlite" 2>/dev/null | grep -q .; then
        HAS_SQLITE=true
        check_permissions "$APP_PATH/database" "775" "database/"
    else
        check_permissions "$APP_PATH/database" "755" "database/"
    fi
fi

check_permissions "$APP_PATH/public" "755" "public/"
check_permissions "$APP_PATH/routes" "755" "routes/"

# --- VERIFICAR PERMISOS DE ARCHIVOS CLAVE ---
echo -e "${COLOR_BLUE}📄 Verificando permisos de archivos...${COLOR_RESET}"

check_permissions "$APP_PATH/.env" "640" ".env"
check_permissions "$APP_PATH/composer.json" "644" "composer.json"
check_permissions "$APP_PATH/artisan" "644" "artisan"

# Verificar archivos SQLite si existen
if [[ -d "$APP_PATH/database" ]]; then
    SQLITE_FILES=$(find "$APP_PATH/database" -type f -name "*.sqlite" 2>/dev/null)
    if [[ -n "$SQLITE_FILES" ]]; then
        echo -e "${COLOR_BLUE}💾 Verificando bases de datos SQLite...${COLOR_RESET}"
        while IFS= read -r sqlite_file; do
            if [[ -f "$sqlite_file" ]]; then
                check_permissions "$sqlite_file" "664" "$(basename "$sqlite_file")"
            fi
        done <<< "$SQLITE_FILES"
    fi
fi

if [[ -d "$APP_PATH/storage/database" ]]; then
    SQLITE_FILES=$(find "$APP_PATH/storage/database" -type f -name "*.sqlite" 2>/dev/null)
    if [[ -n "$SQLITE_FILES" ]]; then
        while IFS= read -r sqlite_file; do
            if [[ -f "$sqlite_file" ]]; then
                check_permissions "$sqlite_file" "664" "storage/$(basename "$sqlite_file")"
            fi
        done <<< "$SQLITE_FILES"
    fi
fi

# --- VERIFICAR PROPIETARIOS ---
echo -e "${COLOR_BLUE}👤 Verificando propietarios...${COLOR_RESET}"

actual_owner=$(stat -c '%U' "$APP_PATH" 2>/dev/null || stat -f '%Su' "$APP_PATH" 2>/dev/null)
actual_group=$(stat -c '%G' "$APP_PATH" 2>/dev/null || stat -f '%Sg' "$APP_PATH" 2>/dev/null)

echo -e "${COLOR_BLUE}ℹ️  Propietario: $actual_owner:$actual_group${COLOR_RESET}"

# Verificar que el grupo es www-data (o nginx en algunos sistemas)
if [[ "$actual_group" == "www-data" ]] || [[ "$actual_group" == "nginx" ]]; then
    echo -e "${COLOR_GREEN}✅ Grupo es $actual_group${COLOR_RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WEB_USER="$actual_group"
else
    echo -e "${COLOR_RED}❌ Grupo es $actual_group (esperado: www-data o nginx)${COLOR_RESET}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    WEB_USER="www-data"  # Asumimos www-data para las siguientes verificaciones
fi

# --- VERIFICAR PERMISOS DE ESCRITURA ---
echo -e "${COLOR_BLUE}✍️  Verificando permisos de escritura...${COLOR_RESET}"

# storage debe ser escribible por www-data
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if can_write "$WEB_USER" "$APP_PATH/storage"; then
    echo -e "${COLOR_GREEN}✅ $WEB_USER puede escribir en storage/${COLOR_RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${COLOR_RED}❌ $WEB_USER NO puede escribir en storage/${COLOR_RESET}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# bootstrap/cache debe ser escribible por www-data
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if can_write "$WEB_USER" "$APP_PATH/bootstrap/cache"; then
    echo -e "${COLOR_GREEN}✅ $WEB_USER puede escribir en bootstrap/cache/${COLOR_RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${COLOR_RED}❌ $WEB_USER NO puede escribir en bootstrap/cache/${COLOR_RESET}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# .env debe ser legible por www-data
if [[ -f "$APP_PATH/.env" ]]; then
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if can_read "$WEB_USER" "$APP_PATH/.env"; then
        echo -e "${COLOR_GREEN}✅ $WEB_USER puede leer .env${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ $WEB_USER NO puede leer .env${COLOR_RESET}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    # .env NO debe ser escribible por www-data
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Si no somos root, verificar por permisos en lugar de test -w
    if [[ $EUID -ne 0 ]]; then
        # Obtener permisos del archivo
        env_perms=$(stat -c '%a' "$APP_PATH/.env" 2>/dev/null || stat -f '%A' "$APP_PATH/.env" 2>/dev/null)
        env_perms_normalized=$(normalize_perms "$env_perms")
        
        # Verificar si el grupo tiene permiso de escritura (segundo dígito debe ser 4 o 0, no 6)
        group_perm="${env_perms_normalized:1:1}"
        
        if [[ "$group_perm" -ge 6 ]]; then
            echo -e "${COLOR_RED}❌ $WEB_USER puede escribir .env (riesgo de seguridad)${COLOR_RESET}"
            echo -e "${COLOR_YELLOW}   El grupo tiene permisos de escritura. Ejecuta: chmod 640 .env${COLOR_RESET}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${COLOR_GREEN}✅ $WEB_USER NO puede escribir .env (seguro)${COLOR_RESET}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        # Si somos root, podemos hacer la verificación real
        if can_write "$WEB_USER" "$APP_PATH/.env"; then
            echo -e "${COLOR_RED}❌ $WEB_USER puede escribir .env (riesgo de seguridad)${COLOR_RESET}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            echo -e "${COLOR_GREEN}✅ $WEB_USER NO puede escribir .env (seguro)${COLOR_RESET}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    fi
fi

# --- VERIFICAR CONFIGURACIÓN DE NGINX ---
echo -e "${COLOR_BLUE}🌐 Verificando configuración de Nginx...${COLOR_RESET}"

# Buscar archivo de configuración de Nginx para este sitio
NGINX_CONFIG=""
SITE_NAME=""

# Buscar en sites-enabled primero
if [[ -d "/etc/nginx/sites-enabled" ]]; then
    for conf in /etc/nginx/sites-enabled/*; do
        if [[ -f "$conf" ]] && grep -q "root.*$APP_PATH" "$conf" 2>/dev/null; then
            NGINX_CONFIG="$conf"
            SITE_NAME=$(basename "$conf")
            break
        fi
    done
fi

# Si no se encontró, buscar en sites-available
if [[ -z "$NGINX_CONFIG" ]] && [[ -d "/etc/nginx/sites-available" ]]; then
    for conf in /etc/nginx/sites-available/*; do
        if [[ -f "$conf" ]] && grep -q "root.*$APP_PATH" "$conf" 2>/dev/null; then
            NGINX_CONFIG="$conf"
            SITE_NAME=$(basename "$conf")
            break
        fi
    done
fi

# Si no se encontró, buscar en conf.d
if [[ -z "$NGINX_CONFIG" ]] && [[ -d "/etc/nginx/conf.d" ]]; then
    for conf in /etc/nginx/conf.d/*.conf; do
        if [[ -f "$conf" ]] && grep -q "root.*$APP_PATH" "$conf" 2>/dev/null; then
            NGINX_CONFIG="$conf"
            SITE_NAME=$(basename "$conf")
            break
        fi
    done
fi

if [[ -n "$NGINX_CONFIG" ]]; then
    echo -e "${COLOR_BLUE}ℹ️  Analizando: $SITE_NAME${COLOR_RESET}"
    
    # Verificar protección de archivos ocultos
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q 'location.*~.*\\\.\(\?!well-known\)' "$NGINX_CONFIG" || \
       grep -q 'location.*~.*\\\.(?!well-known)' "$NGINX_CONFIG" || \
       grep -q 'location.*~.*\\\.\.\*' "$NGINX_CONFIG"; then
        echo -e "${COLOR_GREEN}✅ ✓ Protección de archivos ocultos (.env, .git, etc.)${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ NO se encontró protección de archivos ocultos${COLOR_RESET}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    # Verificar bloqueo de extensiones peligrosas
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if grep -q 'location.*~.*\\\..*env\|log\|sql\|git\|sh\|bak' "$NGINX_CONFIG"; then
        echo -e "${COLOR_GREEN}✅ ✓ Bloqueo de extensiones peligrosas (.env, .log, .sql, etc.)${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ NO se encontró bloqueo de extensiones peligrosas${COLOR_RESET}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    # Verificar protección de PHP (nueva configuración)
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    # Buscar la regla de location = /index.php (con o sin espacios)
    has_index_php=false
    if grep -E 'location[[:space:]]*=[[:space:]]*/index\.php' "$NGINX_CONFIG" >/dev/null 2>&1; then
        has_index_php=true
    fi
    
    # Buscar la regla de bloqueo de otros PHP
    has_php_block=false
    if grep -E 'location[[:space:]]*~[[:space:]]*\\\.php' "$NGINX_CONFIG" >/dev/null 2>&1 && \
       grep -E 'deny[[:space:]]+all' "$NGINX_CONFIG" >/dev/null 2>&1; then
        has_php_block=true
    fi
    
    if [[ "$has_index_php" == true ]] && [[ "$has_php_block" == true ]]; then
        echo -e "${COLOR_GREEN}✅ ✓ Protección de archivos PHP (solo index.php permitido)${COLOR_RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "${COLOR_RED}❌ NO se encontró protección de archivos PHP en Nginx${COLOR_RESET}"
        if [[ "$has_index_php" == false ]]; then
            echo -e "${COLOR_YELLOW}   Falta: location = /index.php${COLOR_RESET}"
        fi
        if [[ "$has_php_block" == false ]]; then
            echo -e "${COLOR_YELLOW}   Falta: location ~ \\.php\$ con deny all${COLOR_RESET}"
        fi
        echo -e "${COLOR_YELLOW}   Añade estas reglas a tu configuración de Nginx:${COLOR_RESET}"
        echo ""
        echo "    location = /index.php {"
        echo "        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;"
        echo "        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;"
        echo "        include fastcgi_params;"
        echo "        fastcgi_hide_header X-Powered-By;"
        echo "    }"
        echo ""
        echo "    location ~ \\.php\$ {"
        echo "        deny all;"
        echo "        return 403;"
        echo "    }"
        echo ""
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
else
    echo -e "${COLOR_YELLOW}⚠️  No se encontró configuración de Nginx para esta aplicación${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}   Verifica manualmente: /etc/nginx/sites-enabled/${COLOR_RESET}"
    WARNING_CHECKS=$((WARNING_CHECKS + 3))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 3))
fi

# --- RESUMEN ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${COLOR_BLUE}📊 Resumen de Verificación${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Total de verificaciones: $TOTAL_CHECKS"
echo -e "${COLOR_GREEN}Pasadas: $PASSED_CHECKS${COLOR_RESET}"
echo -e "${COLOR_RED}Fallidas: $FAILED_CHECKS${COLOR_RESET}"
echo -e "${COLOR_YELLOW}Advertencias: $WARNING_CHECKS${COLOR_RESET}"

if [[ $FAILED_CHECKS -eq 0 ]] && [[ $WARNING_CHECKS -eq 0 ]]; then
    echo -e "${COLOR_GREEN}✅ ¡Configuración de seguridad correcta!${COLOR_RESET}"
    exit 0
elif [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}⚠️  Configuración correcta con algunas advertencias.${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_RED}❌ Se encontraron problemas de seguridad. Revisa los errores arriba.${COLOR_RESET}"
    echo "Para corregir los permisos, ejecuta:"
    echo -e "  ${COLOR_GREEN}sudo /ruta/al/web_security_laravel.sh $APP_PATH${COLOR_RESET}"
    exit 1
fi