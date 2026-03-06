# Bash Scripts

Colección de scripts útiles organizados por categoría para automatización de tareas en sistemas Linux.

## 📋 Estructura

```
bash-scripts/
├── laravel/          # Scripts específicos de Laravel
│   ├── security-check.sh
│   └── security-set.sh
│
├── system/           # Utilidades generales del sistema
│   ├── get-file-contents.sh
│   ├── set-clipboard.sh
│   └── show-selected-files.sh
│
└── scripts/ (deprecated) # Estructura antigua, se eliminará
```

## 🚀 Instalación

### Opción 1: Kit de Herramientas con Symlinks (Recomendado para VPS)

```bash
# 1. Clonar en carpeta oculta
git clone https://github.com/Luinux81/bash-scripts.git ~/.scripts-repo

# 2. Crear enlaces simbólicos según necesites
ln -s ~/.scripts-repo/laravel/security-check.sh /usr/local/bin/laravel-security-check
ln -s ~/.scripts-repo/laravel/security-set.sh /usr/local/bin/laravel-security-set
ln -s ~/.scripts-repo/system/show-selected-files.sh /usr/local/bin/show-files

# 3. Ejecutar desde cualquier lugar
laravel-security-check /var/www/myapp
show-files
```

**Actualizar scripts:**
```bash
cd ~/.scripts-repo && git pull
```

---

### Opción 2: Instalación Local Completa

```bash
git clone https://github.com/Luinux81/bash-scripts.git
cd bash-scripts
find . -name "*.sh" -exec chmod +x {} \;
```

---

### Opción 3: Scripts Individuales

```bash
# Descargar un script específico
curl -O https://raw.githubusercontent.com/Luinux81/bash-scripts/main/system/show-selected-files.sh
chmod +x show-selected-files.sh
```

---

## 📦 Categorías

### Laravel
Scripts para proyectos Laravel en producción/staging:
- **security-check.sh**: Auditoría de seguridad (permisos, nginx, .env)
- **security-set.sh**: Aplicar hardening de permisos

### System
Utilidades generales del sistema:
- **get-file-contents.sh**: Visualizar contenido de archivos
- **set-clipboard.sh**: Copiar al portapapeles
- **show-selected-files.sh**: Selector interactivo con FZF

---

## 🔧 Dependencias

### Requeridas
- bash 4.0+

### Opcionales (según script)
- **fzf**: Para `show-selected-files.sh`
- **xclip**: Para `--clipboard` en varios scripts
- **bat**: Syntax highlighting
- **fd**: Búsqueda rápida de archivos

**Instalación (Ubuntu/Debian):**
```bash
sudo apt install fzf xclip bat fd-find
```

---

## 💡 Uso

Todos los scripts incluyen `--help`:

```bash
./laravel/security-check.sh --help
./system/show-selected-files.sh --help
```

---

## 🚢 Deployment

### Para Proyectos Laravel

Los scripts de `laravel/` están diseñados para incluirse en templates de devcontainer:

```
docs-proyectos/templates/laravel/.devcontainer/deployment/
└── scripts/
    ├── security-check.sh  # ← Copiado desde bash-scripts/laravel/
    └── security-set.sh    # ← Copiado desde bash-scripts/laravel/
```

Luego GitHub Actions los copia al servidor durante el deploy.

---

## 🛠️ Desarrollo

### Agregar Nuevos Scripts

1. Crear en la categoría apropiada (`laravel/`, `system/`, etc.)
2. Añadir shebang: `#!/usr/bin/env bash`
3. Incluir `--help` con SYNOPSIS/USAGE
4. Hacerlo ejecutable: `chmod +x script.sh`
5. Documentar en este README

### Convenciones

- Modo estricto: `set -euo pipefail`
- Colores como constantes `readonly`
- Validación de dependencias antes de ejecutar
- Exit codes: 0 (éxito), 1 (error general), 2 (argumentos inválidos)

---

## 📝 Migración desde `scripts/` (Deprecated)

La estructura antigua será eliminada. Mapping de scripts:

| Antigua Ubicación | Nueva Ubicación |
|-------------------|-----------------|
| `scripts/security/web_security_laravel.sh` | `laravel/security-set.sh` |
| `scripts/security/check_web_security_laravel.sh` | `laravel/security-check.sh` |
| `scripts/filesystem/*` | `system/*` |
| `scripts/utils/*` | `system/*` |

**Actualizar symlinks:**
```bash
# Eliminar symlinks antiguos
rm /usr/local/bin/harden-laravel

# Crear nuevos
ln -s ~/.scripts-repo/laravel/security-set.sh /usr/local/bin/laravel-security-set
```

---

## 📝 Licencia

MIT License - Ver [LICENSE](LICENSE) para más detalles.

## 🤝 Contribuciones

1. Fork el proyecto
2. Crea una rama: `git checkout -b feature/nueva-funcionalidad`
3. Commit: `git commit -am 'Add: nueva funcionalidad'`
4. Push: `git push origin feature/nueva-funcionalidad`
5. Abre un Pull Request