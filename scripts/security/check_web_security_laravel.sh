#!/usr/bin/env bash

#####################################################################
# SYNOPSIS
#   Verifica la configuración de seguridad de una aplicación Laravel
# DESCRIPTION
#   Comprueba permisos de archivos y configuración de Nginx
# USAGE
#   sudo ./check_web_security_laravel.sh [APP_PATH]
# EXAMPLES
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
DEFAULT_WEB_USER="www-data"

# --- FUNCIÓN DE AYUDA ---
show_usage() {
    cat << EOF
Uso: sudo $(basename "$0") [APP_PATH]

Verifica la configuración de seguridad de una aplicación Laravel.

ARGUMENTOS:
    APP_PATH                Ruta a la aplicación Laravel
                            Default: directorio actual

OPCIONES:
    -h, --help              Muestra esta ayuda

EJEMPLOS:
    # Verificar aplicación en el directorio actual
    sudo $(basename "$0")

    # Verificar aplicación específica
    sudo $(basename "$0") /var/www/myapp

EOF
    exit 0
}

# --- PROCESAMIENTO DE ARGUMENTOS ---
APP_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
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
if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${COLOR_RED}Error: El directorio '$APP_PATH' no existe${COLOR_RESET}" >&2
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo -e "${COLOR_YELLOW}Advertencia: Se recomienda ejecutar con sudo para verificaciones completas${COLOR_RESET}"
fi

# --- VARIABLES DE CONTADORES ---
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# --- FUNCIONES DE VERIFICACIÓN ---
check_pass() {
    echo -e "${COLOR_GREEN}✅ $1${COLOR_RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

check_fail() {
    echo -e "${COLOR_RED}❌ $1${COLOR_RESET}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

check_warn() {
    echo -e "${COLOR_YELLOW}⚠️  $1${COLOR_RESET}"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
}

check_info() {
    echo -e "${COLOR_BLUE}ℹ️  $1${COLOR_RESET}"
}

# --- INICIO DE VERIFICACIÓN ---
echo ""
echo -e "${COLOR_BLUE}🔍 Verificación de Seguridad de Laravel${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "📁 Aplicación: ${COLOR_YELLOW}$APP_PATH${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# --- SECCIÓN 1: PERMISOS DE DIRECTORIOS ---
echo -e "${COLOR_BLUE}📂 Verificando permisos de directorios...${COLOR_RESET}"
echo ""

# Verificar storage/
if [[ -d "$APP_PATH/storage" ]]; then
    STORAGE_PERMS=$(stat -c "%a" "$APP_PATH/storage")
    if [[ "$STORAGE_PERMS" == "775" ]]; then
        check_pass "storage/ tiene permisos 775"
    else
        check_fail "storage/ tiene permisos $STORAGE_PERMS (esperado: 775)"
    fi
else
    check_warn "storage/ no existe"
fi

# Verificar bootstrap/cache/
if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
    CACHE_PERMS=$(stat -c "%a" "$APP_PATH/bootstrap/cache")
    if [[ "$CACHE_PERMS" == "775" ]]; then
        check_pass "bootstrap/cache/ tiene permisos 775"
    else
        check_fail "bootstrap/cache/ tiene permisos $CACHE_PERMS (esperado: 775)"
    fi
else
    check_warn "bootstrap/cache/ no existe"
fi

# Verificar directorios normales (deben ser 755)
for dir in app config database public routes; do
    if [[ -d "$APP_PATH/$dir" ]]; then
        DIR_PERMS=$(stat -c "%a" "$APP_PATH/$dir")
        if [[ "$DIR_PERMS" == "755" ]]; then
            check_pass "$dir/ tiene permisos 755"
        else
            check_fail "$dir/ tiene permisos $DIR_PERMS (esperado: 755)"
        fi
    fi
done

echo ""

# --- SECCIÓN 2: PERMISOS DE ARCHIVOS ---
echo -e "${COLOR_BLUE}📄 Verificando permisos de archivos...${COLOR_RESET}"
echo ""

# Verificar .env
if [[ -f "$APP_PATH/.env" ]]; then
    ENV_PERMS=$(stat -c "%a" "$APP_PATH/.env")
    if [[ "$ENV_PERMS" == "640" ]]; then
        check_pass ".env tiene permisos 640"
    else
        check_fail ".env tiene permisos $ENV_PERMS (esperado: 640)"
    fi
else
    check_warn ".env no existe"
fi

# Verificar algunos archivos comunes (deben ser 644)
for file in composer.json artisan; do
    if [[ -f "$APP_PATH/$file" ]]; then
        FILE_PERMS=$(stat -c "%a" "$APP_PATH/$file")
        if [[ "$FILE_PERMS" == "644" ]]; then
            check_pass "$file tiene permisos 644"
        else
            check_fail "$file tiene permisos $FILE_PERMS (esperado: 644)"
        fi
    fi
done

echo ""

# --- SECCIÓN 3: PROPIETARIOS ---
echo -e "${COLOR_BLUE}👤 Verificando propietarios...${COLOR_RESET}"
echo ""

ROOT_OWNER=$(stat -c "%U" "$APP_PATH")
ROOT_GROUP=$(stat -c "%G" "$APP_PATH")
check_info "Propietario: $ROOT_OWNER:$ROOT_GROUP"

# Verificar que www-data es el grupo
if [[ "$ROOT_GROUP" == "$DEFAULT_WEB_USER" ]]; then
    check_pass "Grupo es $DEFAULT_WEB_USER"
else
    check_warn "Grupo es $ROOT_GROUP (esperado: $DEFAULT_WEB_USER)"
fi

echo ""

# --- SECCIÓN 4: PERMISOS DE ESCRITURA ---
echo -e "${COLOR_BLUE}✍️  Verificando permisos de escritura...${COLOR_RESET}"
echo ""

# Verificar que www-data puede escribir en storage
if [[ -d "$APP_PATH/storage" ]]; then
    if sudo -u "$DEFAULT_WEB_USER" test -w "$APP_PATH/storage" 2>/dev/null; then
        check_pass "$DEFAULT_WEB_USER puede escribir en storage/"
    else
        check_fail "$DEFAULT_WEB_USER NO puede escribir en storage/"
    fi
fi

# Verificar que www-data puede escribir en bootstrap/cache
if [[ -d "$APP_PATH/bootstrap/cache" ]]; then
    if sudo -u "$DEFAULT_WEB_USER" test -w "$APP_PATH/bootstrap/cache" 2>/dev/null; then
        check_pass "$DEFAULT_WEB_USER puede escribir en bootstrap/cache/"
    else
        check_fail "$DEFAULT_WEB_USER NO puede escribir en bootstrap/cache/"
    fi
fi

# Verificar que www-data puede leer .env
if [[ -f "$APP_PATH/.env" ]]; then
    if sudo -u "$DEFAULT_WEB_USER" test -r "$APP_PATH/.env" 2>/dev/null; then
        check_pass "$DEFAULT_WEB_USER puede leer .env"
    else
        check_fail "$DEFAULT_WEB_USER NO puede leer .env"
    fi
fi

# Verificar que www-data NO puede escribir .env (seguridad)
if [[ -f "$APP_PATH/.env" ]]; then
    if sudo -u "$DEFAULT_WEB_USER" test -w "$APP_PATH/.env" 2>/dev/null; then
        check_fail "$DEFAULT_WEB_USER puede escribir .env (RIESGO DE SEGURIDAD)"
    else
        check_pass "$DEFAULT_WEB_USER NO puede escribir .env (seguro)"
    fi
fi

echo ""

# --- SECCIÓN 5: CONFIGURACIÓN DE NGINX ---
echo -e "${COLOR_BLUE}🌐 Verificando configuración de Nginx...${COLOR_RESET}"
echo ""

# Buscar archivos de configuración de Nginx
NGINX_CONFIGS=$(find /etc/nginx/sites-enabled /etc/nginx/sites-available -type f 2>/dev/null | grep -v "default" || true)

if [[ -z "$NGINX_CONFIGS" ]]; then
    check_warn "No se encontraron configuraciones de Nginx"
else
    # Verificar reglas de seguridad
    FOUND_PHP_PROTECTION=false
    FOUND_INDEX_ONLY=false
    FOUND_DOTFILES_PROTECTION=false
    FOUND_DANGEROUS_EXTENSIONS=false

    for config in $NGINX_CONFIGS; do
        # Verificar si el config apunta al directorio de la aplicación
        if grep -q "root.*$APP_PATH" "$config" 2>/dev/null || [[ "$config" =~ $(basename "$APP_PATH") ]]; then
            check_info "Analizando: $(basename "$config")"

            # Regla 1: Protección de PHP (método quirúrgico o regex)
            # Buscar "location = /index.php" (método quirúrgico) O "location ~ \.php$" con deny
            if grep -q "location = /index\.php" "$config" 2>/dev/null; then
                FOUND_INDEX_ONLY=true
                check_pass "✓ Protección quirúrgica: Solo index.php permitido (location =)"
            fi

            if grep -q "location ~ .*\.php" "$config" 2>/dev/null && grep -A 2 "location ~ .*\.php" "$config" | grep -q "deny all"; then
                FOUND_PHP_PROTECTION=true
                check_pass "✓ Bloqueo de otros archivos PHP (location ~ \.php$ + deny all)"
            fi

            # Regla 2: Protección de archivos ocultos (.env, .git, etc.)
            # Buscar "location ~ /\." o similar
            if grep -q "location ~ /\\\." "$config" 2>/dev/null || grep -q "location.*\.env\|\.git" "$config" 2>/dev/null; then
                FOUND_DOTFILES_PROTECTION=true
                check_pass "✓ Protección de archivos ocultos (.env, .git, etc.)"
            fi

            # Regla 3: Bloqueo de extensiones peligrosas
            # Buscar "location ~* \.(env|log|sql|..." o similar
            if grep -q "location.*\\.env\|log\|sql\|git\|sh\|bak" "$config" 2>/dev/null; then
                FOUND_DANGEROUS_EXTENSIONS=true
                check_pass "✓ Bloqueo de extensiones peligrosas (.env, .log, .sql, etc.)"
            fi
        fi
    done

    # Verificar que al menos tengamos protección básica de PHP
    if $FOUND_INDEX_ONLY || $FOUND_PHP_PROTECTION; then
        if ! $FOUND_INDEX_ONLY; then
            check_warn "No se encontró 'location = /index.php' (recomendado para máxima seguridad)"
        fi
        if ! $FOUND_PHP_PROTECTION; then
            check_warn "No se encontró bloqueo explícito de otros archivos PHP"
        fi
    else
        check_fail "NO se encontró protección de archivos PHP en Nginx"
    fi

    # Verificar protección de archivos sensibles
    if ! $FOUND_DOTFILES_PROTECTION && ! $FOUND_DANGEROUS_EXTENSIONS; then
        check_warn "No se encontró protección de archivos sensibles (.env, .git, etc.)"
    fi
fi

echo ""

# --- RESUMEN FINAL ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${COLOR_BLUE}📊 Resumen de Verificación${COLOR_RESET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total de verificaciones: ${COLOR_BLUE}$TOTAL_CHECKS${COLOR_RESET}"
echo -e "Pasadas: ${COLOR_GREEN}$PASSED_CHECKS${COLOR_RESET}"
echo -e "Fallidas: ${COLOR_RED}$FAILED_CHECKS${COLOR_RESET}"
echo -e "Advertencias: ${COLOR_YELLOW}$WARNING_CHECKS${COLOR_RESET}"
echo ""

# Determinar estado general
if [[ $FAILED_CHECKS -eq 0 ]] && [[ $WARNING_CHECKS -eq 0 ]]; then
    echo -e "${COLOR_GREEN}✅ ¡Excelente! Todos los checks pasaron correctamente.${COLOR_RESET}"
    exit 0
elif [[ $FAILED_CHECKS -eq 0 ]]; then
    echo -e "${COLOR_YELLOW}⚠️  Configuración aceptable, pero hay advertencias.${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_RED}❌ Se encontraron problemas de seguridad. Revisa los errores arriba.${COLOR_RESET}"
    echo ""
    echo "Para corregir los permisos, ejecuta:"
    echo -e "${COLOR_YELLOW}  sudo /ruta/al/web_security_laravel.sh $APP_PATH${COLOR_RESET}"
    exit 1
fi

