# Bash Scripts

Colección de scripts útiles para Bash que facilitan tareas comunes de filesystem y utilidades del sistema.

## 📋 Contenido

- **Filesystem**: Scripts para navegación y visualización de archivos
  - `show-selected-files.sh`: Selector interactivo con FZF
  - `get-file-contents.sh`: Visualizador de contenido de archivos

- **Security**: Scripts de seguridad para aplicaciones web
  - `web_security_laravel.sh`: Hardening de permisos para Laravel

- **Utils**: Utilidades del sistema
  - `set-clipboard.sh`: Copiar al portapapeles

## 🚀 Inicio Rápido

### Para Usuarios

#### Opción A: Kit de Herramientas con Symlinks (Recomendado para VPS)

Ideal si gestionas múltiples servidores y quieres mantener los scripts actualizados.

```bash
# 1. Clonar el repositorio en una carpeta oculta
git clone https://github.com/Luinux81/bash-scripts.git ~/.scripts-repo

# 2. Crear carpeta bin si no existe
mkdir -p ~/bin

# 3. Crear enlaces simbólicos a los scripts que necesites
ln -s ~/.scripts-repo/scripts/security/web_security_laravel.sh /usr/local/bin/harden-laravel
ln -s ~/.scripts-repo/scripts/filesystem/show-selected-files.sh /usr/local/bin/show-files

# 4. Añadir ~/bin al PATH (opcional pero recomendado)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 5. Ahora puedes ejecutar desde cualquier directorio
harden-laravel --help
show-files
```

**Ventajas:**

- ✅ Actualización fácil: `cd ~/.scripts-repo && git pull`
- ✅ Centralización: Un solo repositorio, múltiples scripts disponibles
- ✅ Escalabilidad: Añade más symlinks según necesites

#### Opción B: Instalación Completa Local

Para desarrollo o uso local con todas las herramientas:

```bash
git clone https://github.com/Luinux81/bash-scripts.git
cd bash-scripts
chmod +x scripts/**/*.sh
```

#### Opción C: Scripts Individuales (Copiar y Pegar)

Si solo necesitas un script específico sin el repositorio:

```bash
# Copiar un script específico
cp scripts/filesystem/show-selected-files.sh ~/bin/

# Hacerlo ejecutable
chmod +x ~/bin/show-selected-files.sh

# Crear un alias en tu .bashrc o .zshrc
echo 'alias show-files="~/bin/show-selected-files.sh"' >> ~/.bashrc
```

### Para Desarrolladores

```bash
# Clonar el repositorio
git clone https://github.com/Luinux81/bash-scripts.git
cd bash-scripts

# Hacer ejecutables todos los scripts
find scripts -name "*.sh" -exec chmod +x {} \;

# Instalar dependencias (Ubuntu/Debian)
sudo apt install fzf xclip bat fd-find
```

### Gestión en Múltiples VPS

Si gestionas varios servidores, puedes mantener los scripts sincronizados:

```bash
# En cada VPS, clonar en ~/.scripts-repo
ssh usuario@vps1.ejemplo.com
git clone https://github.com/Luinux81/bash-scripts.git ~/.scripts-repo

# Crear symlinks solo a los scripts que necesites en ese servidor
ln -s ~/.scripts-repo/scripts/security/web_security_laravel.sh ~/bin/harden-laravel

# Para actualizar en todos los servidores
cd ~/.scripts-repo && git pull
```

**Tip:** Puedes automatizar el despliegue con un script de provisioning (Ansible, Terraform, etc.)

## 📖 Uso

### show-selected-files.sh

Selector interactivo de archivos con previsualización:

```bash
# Desde el directorio actual
./scripts/filesystem/show-selected-files.sh

# Desde un directorio específico
./scripts/filesystem/show-selected-files.sh /ruta/directorio

# Copiar resultado al portapapeles
./scripts/filesystem/show-selected-files.sh . --clipboard
```

### get-file-contents.sh

Mostrar contenido de archivos:

```bash
# Un archivo
./scripts/filesystem/get-file-contents.sh archivo.txt

# Múltiples archivos
./scripts/filesystem/get-file-contents.sh file1.js file2.js file3.js
```

### web_security_laravel.sh

Hardening de seguridad para Laravel:

```bash
# Aplicar en directorio actual (detecta tu usuario automáticamente)
cd /var/www/myapp
sudo ./scripts/security/web_security_laravel.sh

# Especificar ruta de la aplicación
sudo ./scripts/security/web_security_laravel.sh /var/www/myapp

# Cambiar usuario web (ej: nginx)
sudo ./scripts/security/web_security_laravel.sh /var/www/myapp --web-user nginx
```

### set-clipboard.sh

Copiar al portapapeles:

```bash
# Copiar texto
echo "Hola mundo" | ./scripts/utils/set-clipboard.sh

# Copiar archivo
cat documento.txt | ./scripts/utils/set-clipboard.sh
```

## 🔧 Dependencias

### Requeridas

- **bash** 4.0+

### Opcionales (mejoran funcionalidad)

- **fzf**: Selector interactivo (requerido para `show-selected-files.sh`)
- **xclip**: Portapapeles (requerido para `--clipboard`)
- **bat**: Syntax highlighting
- **fd**: Búsqueda rápida de archivos

### Instalación de Dependencias

```bash
# Ubuntu/Debian
sudo apt install fzf xclip bat fd-find

# Fedora
sudo dnf install fzf xclip bat fd-find

# macOS
brew install fzf bat fd

# Arch Linux
sudo pacman -S fzf xclip bat fd
```

## 📚 Documentación Detallada

Cada directorio de scripts contiene su propio README con documentación específica:

- [Scripts de Filesystem](scripts/filesystem/README.md)
- [Scripts de Seguridad](scripts/security/README.md)
- [Scripts de Utilidades](scripts/utils/README.md)

## 🛠️ Desarrollo

### Estructura del Proyecto

```text
bash-scripts/
├── scripts/
│   ├── filesystem/      # Scripts de manejo de archivos
│   │   ├── README.md
│   │   ├── show-selected-files.sh
│   │   └── get-file-contents.sh
│   ├── security/        # Scripts de seguridad
│   │   ├── README.md
│   │   └── web_security_laravel.sh
│   └── utils/           # Utilidades del sistema
│       ├── README.md
│       └── set-clipboard.sh
└── README.md
```

### Convenciones

- Todos los scripts usan `#!/usr/bin/env bash`
- Modo estricto: `set -euo pipefail`
- Documentación en formato SYNOPSIS/USAGE al inicio
- Colores definidos como constantes readonly
- Validación de dependencias antes de ejecutar

### Agregar Nuevos Scripts

1. Crear el script en el directorio apropiado
2. Agregar header con SYNOPSIS y USAGE
3. Hacerlo ejecutable: `chmod +x script.sh`
4. Actualizar el README del directorio
5. Actualizar este README si es necesario

## 📝 Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request
