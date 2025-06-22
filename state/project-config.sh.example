#!/bin/bash
# project-config.sh - Configuración auto-descubierta del proyecto
# Generado automáticamente por auto-discovery.sh
# Fecha: Sun Jun 22 13:45:23 -04 2025

# Raíz del proyecto Avicloud Display
export AVICLOUD_ROOT="/mnt/d/desarrollo/Avicloud Display"

# Rutas principales (relativas a AVICLOUD_ROOT)
export JS_ROOT="$AVICLOUD_ROOT/Avicloud-Display-Server/AvicloudLocalServer/wwwroot/js"
export TEST_ROOT="$AVICLOUD_ROOT/Desarrollo Desatendido/testing"
export TOOLS_ROOT="$AVICLOUD_ROOT/Desarrollo Desatendido/tools"
export V1_SYSTEM="$AVICLOUD_ROOT/Desarrollo Desatendido"

# Repositorios Git descubiertos
export REPOS=(
    "/mnt/d/desarrollo/Avicloud Display"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Core"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Pro"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Server-Blazor"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Server"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Shared"
    "/mnt/d/desarrollo/Avicloud Display/Avicloud-Display"
)

# Función helper para obtener rutas relativas
get_relative_path() {
    local TARGET=$1
    local FROM=${2:-$(pwd)}
    realpath --relative-to="$FROM" "$TARGET" 2>/dev/null || echo "$TARGET"
}

# Función para verificar si estamos en el proyecto correcto
verify_project_context() {
    if [[ ! -d "$AVICLOUD_ROOT/Avicloud-Display-Server" ]]; then
        echo "⚠️  Error: No se encuentra en el contexto del proyecto Avicloud Display"
        return 1
    fi
    return 0
}

# Estadísticas del proyecto
export PROJECT_STATS=(
    "Total repos: 7"
    "JS Root: $JS_ROOT"
    "Test Root: $TEST_ROOT"
)

echo "✅ Configuración del proyecto cargada"
