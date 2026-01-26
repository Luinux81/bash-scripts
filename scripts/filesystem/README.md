# Scripts de Filesystem

## show-selected-files.sh

Selector interactivo de archivos con previsualización y visualización de contenido.

### Descripción

Utiliza FZF para seleccionar múltiples archivos de forma interactiva y muestra su contenido. Opcionalmente puede copiar el resultado al portapapeles.

### Uso

```bash
./show-selected-files.sh [directorio] [--clipboard]
```

### Parámetros

- `directorio` (opcional): Directorio desde donde buscar archivos. Por defecto usa el directorio actual.
- `--clipboard` o `-c` (opcional): Copia el contenido al portapapeles además de mostrarlo.

### Ejemplos

```bash
# Seleccionar archivos desde el directorio actual
./show-selected-files.sh

# Seleccionar archivos desde una ruta específica
./show-selected-files.sh /ruta/al/directorio

# Seleccionar y copiar al portapapeles
./show-selected-files.sh . --clipboard
```

### Dependencias

- **fzf**: Selector interactivo de archivos
- **xclip**: Necesario solo si se usa `--clipboard`
- **bat** (opcional): Mejora la previsualización con syntax highlighting
- **fd** (opcional): Búsqueda de archivos más rápida

---

## get-file-contents.sh

Muestra el contenido de uno o más archivos con formato mejorado.

### Descripción

Visualiza el contenido de archivos con separadores visuales y syntax highlighting (si bat está disponible).

### Uso

```bash
./get-file-contents.sh archivo1 [archivo2 ...]
```

### Parámetros

- `archivo1, archivo2, ...`: Uno o más archivos a mostrar.

### Ejemplos

```bash
# Mostrar un archivo
./get-file-contents.sh config.json

# Mostrar múltiples archivos
./get-file-contents.sh package.json tsconfig.json README.md
```

### Dependencias

- **bat** (opcional): Syntax highlighting y numeración de líneas

### Características

- Separadores visuales entre archivos
- Syntax highlighting automático (con bat)
- Manejo de errores para archivos no encontrados
- Continúa con el siguiente archivo si uno falla

