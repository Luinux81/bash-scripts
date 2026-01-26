# Scripts de Seguridad

## web_security_laravel.sh

Endurece la seguridad de aplicaciones Laravel a nivel de sistema de archivos.

### Descripción

Configura automáticamente permisos y propietarios de archivos para minimizar riesgos de seguridad en aplicaciones Laravel en producción. Implementa el principio de mínimo privilegio, permitiendo al servidor web solo los permisos estrictamente necesarios.

**Ideal para:** Servidores de producción, VPS, entornos compartidos.

### Uso

```bash
sudo ./web_security_laravel.sh [APP_PATH] [OPCIONES]
```

### Parámetros

#### Argumentos Posicionales

- `APP_PATH` (opcional): Ruta a la aplicación Laravel
  - Default: **Directorio actual** donde se ejecuta el script
  - Puede ser ruta absoluta o relativa

#### Opciones

- `--web-user USER`: Usuario del servidor web
  - Default: `www-data`
  - Ejemplos: `nginx`, `apache`, `www-data`
  - Debe ser un usuario existente en el sistema

- `--owner USER`: Usuario propietario de los archivos
  - Default: **Usuario que ejecuta sudo** (o usuario actual si no se usa sudo)
  - Debe ser un usuario existente en el sistema
  - Automáticamente detecta el usuario real cuando se usa sudo

- `-h, --help`: Muestra la ayuda del script

### Ejemplos

```bash
# Aplicar en el directorio actual (detecta automáticamente tu usuario)
cd /var/www/myapp
sudo ./web_security_laravel.sh

# Especificar solo la ruta de la aplicación
sudo ./web_security_laravel.sh /var/www/myapp

# Cambiar usuario web (útil si usas nginx en lugar de apache)
sudo ./web_security_laravel.sh /var/www/myapp --web-user nginx

# Especificar todos los parámetros (ej: servidor con usuario deploy)
sudo ./web_security_laravel.sh /var/www/myapp --web-user nginx --owner deploy

# Los parámetros pueden ir en cualquier orden
sudo ./web_security_laravel.sh --owner john --web-user www-data /var/www/app

# Ver ayuda completa
./web_security_laravel.sh --help
```

### Instalación en VPS (Recomendado)

Para usar este script en múltiples servidores de producción:

```bash
# 1. Clonar el repositorio en tu VPS
ssh usuario@tu-vps.com
git clone https://github.com/Luinux81/bash-scripts.git ~/.scripts-repo

# 2. Crear enlace simbólico
mkdir -p ~/bin
ln -s ~/.scripts-repo/scripts/security/web_security_laravel.sh ~/bin/harden-laravel

# 3. Añadir al PATH (opcional)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. Usar desde cualquier directorio
cd /var/www/mi-aplicacion
sudo harden-laravel

# 5. Actualizar el script cuando haya cambios
cd ~/.scripts-repo && git pull
```

### Validaciones y Seguridad

El script incluye múltiples capas de validación para prevenir errores:

#### Validaciones Automáticas

- ✅ Verifica que el directorio de la aplicación existe
- ✅ Convierte rutas relativas a absolutas
- ✅ Verifica que se ejecuta con permisos de root/sudo
- ✅ Verifica que el usuario web existe en el sistema
- ✅ Verifica que el usuario propietario existe en el sistema

#### Detección de Estructura Laravel

El script analiza el directorio para verificar que es una aplicación Laravel:

- Busca directorios típicos: `app`, `bootstrap`, `config`, `database`, `public`, `resources`, `routes`, `storage`
- Verifica archivos clave: `artisan`, `composer.json`
- **Advertencia**: Si faltan más de 3 directorios típicos, muestra un warning antes de continuar

#### Confirmación Interactiva

Antes de aplicar cambios, el script:

1. **Muestra la ruta completa** donde se aplicarán los permisos
2. **Repite el warning de Laravel** si el directorio no parece ser una aplicación Laravel (para máxima visibilidad)
3. **Lista todos los cambios** que se realizarán (propietarios, permisos)
4. **Solicita confirmación explícita** del usuario (debe escribir "si")
5. **Permite cancelar** en cualquier momento sin hacer cambios

Si el directorio **NO** parece Laravel, el warning se muestra **dos veces**:
- Una vez durante la verificación inicial
- **Otra vez justo antes del prompt de confirmación** (para que sea imposible pasarlo por alto)

### Qué Hace el Script

1. **Muestra configuración**: Presenta los parámetros que se aplicarán
2. **Establece propietarios**: Usuario del sistema como dueño, servidor web como grupo
3. **Permisos base**: 755 para directorios, 644 para archivos (solo lectura para web)
4. **Excepciones Laravel**: 775 en `storage/` y `bootstrap/cache/` (escritura necesaria)
5. **Protección .env**: 640 (solo propietario y grupo pueden leer)

### Configuración Adicional Requerida

**⚠️ IMPORTANTE**: Después de ejecutar el script, debes configurar Nginx para prevenir ejecución de PHP en directorios de uploads.

Añade a tu configuración de Nginx (`/etc/nginx/sites-available/tu-sitio`):

```nginx
location ~* ^/(storage|uploads|images)/.*\.php$ {
    deny all;
    return 403;
}
```

Luego recarga Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Dependencias

- **sudo**: Permisos de superusuario
- **find**: Búsqueda de archivos (incluido en sistemas Unix)
- **chmod/chown**: Gestión de permisos (incluido en sistemas Unix)

### Características de Seguridad

- ✅ Principio de mínimo privilegio
- ✅ Servidor web sin permisos de escritura (excepto storage)
- ✅ Protección del archivo .env
- ✅ Prevención de ejecución de scripts maliciosos
- ✅ Separación de propietario y grupo

### Cuándo Usar

- ✅ Después de desplegar una aplicación Laravel
- ✅ Tras actualizar código en producción (deploy)
- ✅ Como parte de un proceso de hardening de servidor
- ✅ Cuando se detectan permisos incorrectos
- ✅ Al configurar un nuevo VPS para Laravel
- ✅ Después de clonar un repositorio en producción

### Flujo de Trabajo Típico en Producción

```bash
# 1. Desplegar código (git pull, composer install, etc.)
cd /var/www/mi-app
git pull origin main
composer install --no-dev --optimize-autoloader

# 2. Aplicar permisos de seguridad
sudo harden-laravel
# El script mostrará:
# - Verificación de estructura Laravel
# - Ruta completa donde se aplicarán los cambios
# - Lista de permisos que se modificarán
# - Solicitud de confirmación (escribe 'si')

# 3. Limpiar caché de Laravel
php artisan config:cache
php artisan route:cache
php artisan view:cache

# 4. Verificar que todo funciona
curl -I https://mi-app.com
```

### Ejemplo de Ejecución

#### Caso 1: Aplicación Laravel Válida

```text
$ cd /var/www/mi-aplicacion
$ sudo harden-laravel

🔍 Verificando estructura de Laravel...
✅ Estructura de Laravel detectada correctamente

🛡️ Configuración de Endurecimiento de Seguridad
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Ruta completa:  /var/www/mi-aplicacion
👤 Propietario:    usuario
🌐 Usuario Web:    www-data
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Este script modificará los permisos de TODOS los archivos en:
   /var/www/mi-aplicacion

Los cambios que se aplicarán:
  • Propietario: usuario:www-data
  • Directorios: 755 (rwxr-xr-x)
  • Archivos: 644 (rw-r--r--)
  • storage/: 775 (rwxrwxr-x)
  • bootstrap/cache/: 775 (rwxrwxr-x)
  • .env: 640 (rw-r-----)

¿Deseas continuar? (escribe 'si' para confirmar): si

✅ Confirmado. Iniciando proceso...

👤 Ajustando propietarios a usuario:www-data...
🔒 Aplicando permisos 755/644 (Solo lectura para el servidor web)...
📂 Otorgando permisos de escritura solo en storage y cache...
🔑 Asegurando archivo .env...

✅ Proceso de permisos completado. App asegurada a nivel de sistema.
```

#### Caso 2: Directorio que NO parece Laravel

```text
$ cd /home/usuario/temporal
$ sudo harden-laravel

🔍 Verificando estructura de Laravel...
⚠️  ADVERTENCIA: Este directorio NO parece ser una aplicación Laravel
   Directorios típicos encontrados: 2 de 8
   Directorios faltantes: app config database public resources routes

🛡️ Configuración de Endurecimiento de Seguridad
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Ruta completa:  /home/usuario/temporal
👤 Propietario:    usuario
🌐 Usuario Web:    www-data
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  ADVERTENCIA: Este directorio NO parece ser una aplicación Laravel
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Directorios típicos de Laravel encontrados: 2 de 8
   Directorios faltantes: app config database public resources routes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Este script modificará los permisos de TODOS los archivos en:
   /home/usuario/temporal

Los cambios que se aplicarán:
  • Propietario: usuario:www-data
  • Directorios: 755 (rwxr-xr-x)
  • Archivos: 644 (rw-r--r--)
  • storage/: 775 (rwxrwxr-x)
  • bootstrap/cache/: 775 (rwxrwxr-x)
  • .env: 640 (rw-r-----)

¿Deseas continuar? (escribe 'si' para confirmar): n

❌ Operación cancelada por el usuario
```

### Notas de Seguridad

- **No ejecutar en desarrollo**: Puede interferir con herramientas como `php artisan`
- **Solo para producción**: Diseñado para entornos de producción
- **Backup recomendado**: Haz backup antes de cambiar permisos masivamente
- **Verificar después**: Comprueba que la aplicación funciona correctamente

### Solución de Problemas

**Error: Permission denied al escribir logs**
```bash
# Verificar permisos de storage
ls -la /ruta/app/storage
# Debe mostrar 775 y grupo www-data
```

**Error: .env no se puede leer**
```bash
# Verificar permisos del .env
ls -la /ruta/app/.env
# Debe mostrar 640 y grupo www-data
```

**La aplicación no funciona después del script**
```bash
# Verificar que el usuario web está en el grupo correcto
groups www-data

# Revertir permisos si es necesario
sudo chmod -R 775 /ruta/app/storage
```

