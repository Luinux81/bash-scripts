# Scripts de Seguridad

## web_security_laravel.sh

Endurece la seguridad de aplicaciones Laravel a nivel de sistema de archivos.

### Descripción

Configura automáticamente permisos y propietarios de archivos para minimizar riesgos de seguridad en aplicaciones Laravel en producción. Implementa el principio de mínimo privilegio, permitiendo al servidor web solo los permisos estrictamente necesarios.

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

### Validaciones

El script realiza las siguientes validaciones antes de ejecutar:

- ✅ Verifica que el directorio de la aplicación existe
- ✅ Verifica que se ejecuta con permisos de root/sudo
- ✅ Verifica que el usuario web existe en el sistema
- ✅ Verifica que el usuario propietario existe en el sistema

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

- Después de desplegar una aplicación Laravel
- Tras actualizar código en producción
- Como parte de un proceso de hardening de servidor
- Cuando se detectan permisos incorrectos

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

