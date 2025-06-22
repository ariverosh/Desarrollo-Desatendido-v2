# 🏆 REGLAS DE ORO - Sistema de Desarrollo Desatendido

Estas reglas son **INQUEBRANTABLES** y deben respetarse en todo el código del sistema.

## 1. ❌ NO Fallbacks - Errores Explícitos

### NUNCA hacer esto:
```bash
# ❌ MAL - Oculta errores
comando_importante || echo "Continuando de todos modos..."
resultado=$(curl -s "$URL" || echo "{}")
```

### SIEMPRE hacer esto:
```bash
# ✅ BIEN - Falla explícitamente
if ! comando_importante; then
    echo "ERROR: comando_importante falló"
    echo "Solución: Verificar que X esté instalado/configurado"
    exit 1
fi

# ✅ BIEN - Manejo explícito
if ! resultado=$(curl -s "$URL"); then
    echo "ERROR: No se pudo conectar a $URL"
    echo "Solución: Verificar conexión a internet y que el servidor esté activo"
    exit 1
fi
```

## 2. 🔨 NO Parches - Soluciones Reales

### NUNCA hacer esto:
```bash
# ❌ MAL - Parche temporal
sleep 5  # Esperar a que "probablemente" esté listo
pkill -9 proceso  # Forzar cierre "por si acaso"
```

### SIEMPRE hacer esto:
```bash
# ✅ BIEN - Solución real
# Esperar con condición específica
timeout=30
while [[ ! -f "$READY_FILE" ]] && [[ $timeout -gt 0 ]]; do
    sleep 1
    ((timeout--))
done

if [[ $timeout -eq 0 ]]; then
    echo "ERROR: Servicio no se inició en 30 segundos"
    exit 1
fi
```

## 3. ♻️ Reutilización Absoluta - DRY

### NUNCA hacer esto:
```bash
# ❌ MAL - Código duplicado
# En script1.sh
check_server() {
    curl -s http://localhost:5000/health > /dev/null
}

# En script2.sh
verify_server() {
    curl -s http://localhost:5000/health > /dev/null
}
```

### SIEMPRE hacer esto:
```bash
# ✅ BIEN - Función compartida en common/utils.sh
check_server_health() {
    local url=${1:-"http://localhost:5000/health"}
    curl -s "$url" > /dev/null
}

# Importar en cualquier script
source "$(dirname "${BASH_SOURCE[0]}")/../common/utils.sh"
check_server_health
```

## 4. 🔍 Verificar, No Suponer

### NUNCA hacer esto:
```bash
# ❌ MAL - Asume que existe
cd $PROJECT_ROOT/src
cat config.json
```

### SIEMPRE hacer esto:
```bash
# ✅ BIEN - Verifica explícitamente
if [[ ! -d "$PROJECT_ROOT/src" ]]; then
    echo "ERROR: Directorio $PROJECT_ROOT/src no existe"
    echo "Solución: Ejecutar auto-discovery.sh primero"
    exit 1
fi

if [[ ! -f "$PROJECT_ROOT/src/config.json" ]]; then
    echo "ERROR: Archivo config.json no encontrado"
    echo "Solución: Crear configuración con init-config.sh"
    exit 1
fi
```

## 5. 👁️ Transparencia Total

### Principios:
- Cada operación debe loguear qué está haciendo
- Los logs deben ser útiles para debugging
- Estado consultable en cualquier momento

```bash
# ✅ BIEN - Transparente
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Iniciando compilación del módulo auth..."
echo "  - Directorio: $BUILD_DIR"
echo "  - Configuración: $CONFIG_FILE"
echo "  - Modo: $BUILD_MODE"

# Comando con salida visible
make -C "$BUILD_DIR" 2>&1 | tee "$LOG_DIR/build-auth.log"
```

## 6. 🔄 Idempotencia

### Operaciones seguras para repetir:
```bash
# ✅ BIEN - Idempotente
ensure_directory() {
    local dir=$1
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

create_symlink() {
    local source=$1
    local target=$2
    
    # Remover si existe
    [[ -L "$target" ]] && rm "$target"
    
    # Crear nuevo
    ln -s "$source" "$target"
}
```

## 7. 📦 Aislamiento de Contexto

### NUNCA contaminar el ambiente global:
```bash
# ❌ MAL - Contamina ambiente
PROJECT_ROOT=/path/to/project
cd $PROJECT_ROOT

# ✅ BIEN - Aislado
function build_module() {
    local PROJECT_ROOT=$1
    (
        # Subshell para aislar cambios
        cd "$PROJECT_ROOT" || exit 1
        # Operaciones aquí no afectan el shell padre
    )
}
```

## 8. 📚 Documentación Como Código

### La documentación DEBE actualizarse automáticamente:
```bash
# ✅ BIEN - Auto-documentado
generate_function_docs() {
    local script=$1
    local output=$2
    
    echo "# Funciones en $script" > "$output"
    echo "" >> "$output"
    
    # Extraer funciones y sus comentarios
    grep -B1 "^function\|^[a-zA-Z_]*\(\)" "$script" | \
        grep -E "^#|^function|^[a-zA-Z_]*\(\)" >> "$output"
}
```

## 🚨 Aplicación de las Reglas

1. **Code Review**: Ningún PR se aprueba si viola estas reglas
2. **CI/CD**: Tests automáticos para verificar cumplimiento
3. **Pre-commit Hooks**: Validación antes de cada commit
4. **Documentación**: Ejemplos de cada regla en acción

## 📝 Excepciones

Las únicas excepciones permitidas deben:
1. Estar documentadas en el código
2. Tener una justificación técnica sólida
3. Incluir un plan para eliminar la excepción
4. Ser aprobadas por el equipo

```bash
# EXCEPCIÓN DOCUMENTADA:
# TODO: Eliminar este workaround cuando se actualice a v2.0
# Razón: Bug conocido en librería X v1.5
# Ticket: #1234
# Plan: Actualizar cuando se lance v2.0 (Q1 2025)
```

---

**Recuerda**: Estas reglas existen para crear un sistema robusto, mantenible y confiable. 
El código limpio es más importante que el código que "funciona por ahora".