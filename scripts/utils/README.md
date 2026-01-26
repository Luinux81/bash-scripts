# Scripts de Utilidades

## set-clipboard.sh

Copia la entrada estándar al portapapeles del sistema.

### Descripción

Lee datos desde stdin y los copia al portapapeles, eliminando automáticamente los códigos de color ANSI para obtener texto limpio.

### Uso

```bash
echo "texto" | ./set-clipboard.sh
cat archivo.txt | ./set-clipboard.sh
comando | ./set-clipboard.sh
```

### Parámetros

No requiere parámetros. Lee desde la entrada estándar (stdin).

### Ejemplos

```bash
# Copiar texto simple
echo "Hola mundo" | ./set-clipboard.sh

# Copiar contenido de un archivo
cat config.json | ./set-clipboard.sh

# Copiar salida de un comando
ls -la | ./set-clipboard.sh

# Encadenar con otros scripts
./get-file-contents.sh archivo.txt | ./set-clipboard.sh
```

### Dependencias

- **xclip**: Herramienta para interactuar con el portapapeles de X11

### Instalación de dependencias

```bash
# Ubuntu/Debian
sudo apt install xclip

# Fedora
sudo dnf install xclip

# Arch Linux
sudo pacman -S xclip
```

### Características

- Elimina códigos de color ANSI automáticamente
- Copia al portapapeles del sistema (clipboard selection)
- Confirmación visual al copiar
- Manejo de errores si xclip no está instalado

