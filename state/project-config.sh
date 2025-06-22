#!/bin/bash
# project-config.sh - Configuración auto-descubierta del proyecto
# Generado automáticamente por auto-discovery-universal.sh
# Fecha: Sun Jun 22 14:45:43 -04 2025

# Raíz del proyecto
export PROJECT_ROOT="/mnt/d/desarrollo/Avicloud Display/Desarrollo Desatendido v2"
export PROJECT_NAME="Desarrollo Desatendido v2"

# Tipo de proyecto detectado
export PROJECT_TYPES=(
    "Unknown"
)

# Repositorios Git descubiertos
export REPOS=(
    "/mnt/d/desarrollo/Avicloud Display/Desarrollo Desatendido v2"
)

# Herramientas de build detectadas
export BUILD_TOOLS=(
    ""
)

# Frameworks de testing detectados
export TEST_FRAMEWORKS=(
    ""
)

# Rutas comunes (si existen)
[[ -d "$PROJECT_ROOT/src" ]] && export SRC_ROOT="$PROJECT_ROOT/src"
[[ -d "$PROJECT_ROOT/test" ]] && export TEST_ROOT="$PROJECT_ROOT/test"
[[ -d "$PROJECT_ROOT/tests" ]] && export TEST_ROOT="$PROJECT_ROOT/tests"
[[ -d "$PROJECT_ROOT/docs" ]] && export DOCS_ROOT="$PROJECT_ROOT/docs"
[[ -d "$PROJECT_ROOT/scripts" ]] && export SCRIPTS_ROOT="$PROJECT_ROOT/scripts"

# Sistema de desarrollo desatendido
export AUTONOMOUS_ROOT="/mnt/d/desarrollo/Avicloud Display/Desarrollo Desatendido v2"

# Función helper para obtener rutas relativas
get_relative_path() {
    local TARGET=$1
    local FROM=${2:-$(pwd)}
    realpath --relative-to="$FROM" "$TARGET" 2>/dev/null || echo "$TARGET"
}

# Función para verificar contexto del proyecto
verify_project_context() {
    if [[ ! -d "$PROJECT_ROOT" ]]; then
        echo "⚠️  Error: No se encuentra el proyecto en $PROJECT_ROOT"
        return 1
    fi
    return 0
}

echo "✅ Configuración del proyecto cargada"
echo "   Proyecto: $PROJECT_NAME"
echo "   Tipo: ${PROJECT_TYPES[0]}"
echo "   Repositorios: ${#REPOS[@]}"
