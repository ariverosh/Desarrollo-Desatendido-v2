#!/bin/bash
# auto-discovery.sh - Sistema de auto-descubrimiento de la estructura del proyecto
# Detecta automáticamente ubicaciones, repositorios y estructura

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$BASE_DIR/state/project-config.sh"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Sistema de Auto-Discovery v1.0${NC}"
echo "========================================"
echo ""

# Función para buscar la raíz de Avicloud
find_avicloud_root() {
    echo -e "${YELLOW}Buscando raíz del proyecto Avicloud Display...${NC}" >&2
    
    local CURRENT_DIR="$BASE_DIR"
    local AVICLOUD_ROOT=""
    local MAX_LEVELS=5
    local LEVEL=0
    
    # Subir niveles hasta encontrar características del proyecto
    while [[ "$CURRENT_DIR" != "/" ]] && [[ $LEVEL -lt $MAX_LEVELS ]]; do
        # Buscar indicadores del proyecto Avicloud
        if [[ -d "$CURRENT_DIR/Avicloud-Display-Server" ]] && 
           [[ -d "$CURRENT_DIR/Avicloud-Display-Core" ]]; then
            AVICLOUD_ROOT="$CURRENT_DIR"
            echo -e "${GREEN}✅ Encontrado en: $AVICLOUD_ROOT${NC}" >&2
            break
        fi
        
        CURRENT_DIR="$(dirname "$CURRENT_DIR")"
        ((LEVEL++))
    done
    
    if [[ -z "$AVICLOUD_ROOT" ]]; then
        echo -e "${YELLOW}⚠️  No se encontró la raíz de Avicloud Display${NC}" >&2
        echo "   Usando ubicación relativa por defecto: ../.." >&2
        AVICLOUD_ROOT="$(cd "$BASE_DIR/../.." && pwd)"
    fi
    
    echo "$AVICLOUD_ROOT"
}

# Función para descubrir repositorios Git
discover_git_repos() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Descubriendo repositorios Git...${NC}" >&2
    
    local REPOS=()
    
    # Buscar todos los directorios .git
    while IFS= read -r git_dir; do
        if [[ -n "$git_dir" ]]; then
            local REPO_PATH=$(dirname "$git_dir")
            local REPO_NAME=$(basename "$REPO_PATH")
            
            # Obtener información del repositorio
            cd "$REPO_PATH" 2>/dev/null
            local BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
            local COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            local STATUS_COUNT=$(git status --porcelain 2>/dev/null | wc -l || echo 0)
            
            REPOS+=("$REPO_PATH")
            
            echo "  📦 $REPO_NAME" >&2
            echo "     ├─ Rama: $BRANCH" >&2
            echo "     ├─ Commit: $COMMIT" >&2
            echo "     └─ Archivos modificados: $STATUS_COUNT" >&2
        fi
    done < <(find "$ROOT_DIR" -maxdepth 3 -name ".git" -type d 2>/dev/null | sort)
    
    cd "$BASE_DIR"
    echo -e "${GREEN}✅ Encontrados ${#REPOS[@]} repositorios${NC}" >&2
    
    # Imprimir cada repositorio en una línea separada
    for repo in "${REPOS[@]}"; do
        echo "$repo"
    done
}

# Función para descubrir estructura JavaScript
discover_js_structure() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Analizando estructura JavaScript...${NC}" >&2
    
    local JS_ROOT="$ROOT_DIR/Avicloud-Display-Server/AvicloudLocalServer/wwwroot/js"
    
    if [[ -d "$JS_ROOT" ]]; then
        echo -e "${GREEN}✅ Directorio JS encontrado: $JS_ROOT${NC}" >&2
        
        # Contar archivos y carpetas
        local JS_FILES=$(find "$JS_ROOT" -name "*.js" -type f | wc -l)
        local JS_DIRS=$(find "$JS_ROOT" -mindepth 1 -type d | wc -l)
        
        echo "  📊 Estadísticas:" >&2
        echo "     ├─ Archivos JavaScript: $JS_FILES" >&2
        echo "     └─ Carpetas: $JS_DIRS" >&2
        
        # Listar módulos principales
        echo "  📁 Módulos principales:" >&2
        for dir in "$JS_ROOT"/*/; do
            if [[ -d "$dir" ]]; then
                local MODULE_NAME=$(basename "$dir")
                local FILE_COUNT=$(find "$dir" -name "*.js" -type f | wc -l)
                echo "     ├─ $MODULE_NAME/ ($FILE_COUNT archivos)" >&2
            fi
        done
    else
        echo -e "${YELLOW}⚠️  No se encontró directorio JavaScript estándar${NC}" >&2
    fi
}

# Función para descubrir estructura de tests
discover_test_structure() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Analizando estructura de tests...${NC}" >&2
    
    # Buscar directorios de tests comunes
    local TEST_DIRS=(
        "$ROOT_DIR/Desarrollo Desatendido/testing"
        "$ROOT_DIR/Avicloud-Display-Server/tests"
        "$ROOT_DIR/tests"
    )
    
    local FOUND_TESTS=false
    
    for test_dir in "${TEST_DIRS[@]}"; do
        if [[ -d "$test_dir" ]]; then
            FOUND_TESTS=true
            echo -e "${GREEN}✅ Directorio de tests: $test_dir${NC}" >&2
            
            # Contar tipos de tests
            local JEST_TESTS=$(find "$test_dir" -name "*.test.js" -o -name "*.spec.js" 2>/dev/null | wc -l || echo 0)
            local PLAYWRIGHT_TESTS=$(find "$test_dir" -name "*playwright*" -name "*.js" 2>/dev/null | wc -l || echo 0)
            local OTHER_TESTS=$(find "$test_dir" -name "test-*.js" -o -name "verify-*.js" 2>/dev/null | wc -l || echo 0)
            
            echo "  📊 Tests encontrados:" >&2
            echo "     ├─ Jest: $JEST_TESTS" >&2
            echo "     ├─ Playwright: $PLAYWRIGHT_TESTS" >&2
            echo "     └─ Otros: $OTHER_TESTS" >&2
        fi
    done
    
    if [[ "$FOUND_TESTS" == "false" ]]; then
        echo -e "${YELLOW}⚠️  No se encontraron directorios de tests${NC}" >&2
    fi
}

# Función para detectar herramientas disponibles
discover_tools() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Detectando herramientas disponibles...${NC}" >&2
    
    local TOOLS_DIR="$ROOT_DIR/Desarrollo Desatendido/tools"
    local FOUND_TOOLS=()
    
    if [[ -d "$TOOLS_DIR" ]]; then
        echo -e "${GREEN}✅ Directorio de herramientas: $TOOLS_DIR${NC}" >&2
        
        # Buscar scripts ejecutables
        while IFS= read -r tool; do
            if [[ -n "$tool" ]]; then
                local TOOL_NAME=$(basename "$tool")
                FOUND_TOOLS+=("$TOOL_NAME")
                echo "  🔧 $TOOL_NAME" >&2
            fi
        done < <(find "$TOOLS_DIR" -name "*.sh" -type f -executable 2>/dev/null | sort)
        
        echo -e "${GREEN}✅ Encontradas ${#FOUND_TOOLS[@]} herramientas${NC}" >&2
    else
        echo -e "${YELLOW}⚠️  No se encontró directorio de herramientas${NC}" >&2
    fi
}

# Función principal de descubrimiento
main() {
    echo "Iniciando auto-descubrimiento del proyecto..."
    echo ""
    
    # Descubrir raíz de Avicloud
    AVICLOUD_ROOT=$(find_avicloud_root)
    
    # Descubrir repositorios
    mapfile -t REPOS < <(discover_git_repos "$AVICLOUD_ROOT")
    
    # Descubrir estructura JS
    discover_js_structure "$AVICLOUD_ROOT"
    
    # Descubrir tests
    discover_test_structure "$AVICLOUD_ROOT"
    
    # Descubrir herramientas
    discover_tools "$AVICLOUD_ROOT"
    
    # Generar archivo de configuración
    echo -e "\n${YELLOW}Generando archivo de configuración...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# project-config.sh - Configuración auto-descubierta del proyecto
# Generado automáticamente por auto-discovery.sh
# Fecha: $(date)

# Raíz del proyecto Avicloud Display
export AVICLOUD_ROOT="$AVICLOUD_ROOT"

# Rutas principales (relativas a AVICLOUD_ROOT)
export JS_ROOT="\$AVICLOUD_ROOT/Avicloud-Display-Server/AvicloudLocalServer/wwwroot/js"
export TEST_ROOT="\$AVICLOUD_ROOT/Desarrollo Desatendido/testing"
export TOOLS_ROOT="\$AVICLOUD_ROOT/Desarrollo Desatendido/tools"
export V1_SYSTEM="\$AVICLOUD_ROOT/Desarrollo Desatendido"

# Repositorios Git descubiertos
export REPOS=(
$(for repo in "${REPOS[@]}"; do echo "    \"$repo\""; done)
)

# Función helper para obtener rutas relativas
get_relative_path() {
    local TARGET=\$1
    local FROM=\${2:-\$(pwd)}
    realpath --relative-to="\$FROM" "\$TARGET" 2>/dev/null || echo "\$TARGET"
}

# Función para verificar si estamos en el proyecto correcto
verify_project_context() {
    if [[ ! -d "\$AVICLOUD_ROOT/Avicloud-Display-Server" ]]; then
        echo "⚠️  Error: No se encuentra en el contexto del proyecto Avicloud Display"
        return 1
    fi
    return 0
}

# Estadísticas del proyecto
export PROJECT_STATS=(
    "Total repos: ${#REPOS[@]}"
    "JS Root: \$JS_ROOT"
    "Test Root: \$TEST_ROOT"
)

echo "✅ Configuración del proyecto cargada"
EOF
    
    chmod +x "$CONFIG_FILE"
    
    # Crear symlink para fácil acceso
    ln -sf "$CONFIG_FILE" "$BASE_DIR/project-config.sh" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Archivo de configuración generado: $CONFIG_FILE${NC}"
    
    # Resumen final
    echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          RESUMEN DE DESCUBRIMIENTO         ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "  📍 Raíz del proyecto: $AVICLOUD_ROOT"
    echo "  📦 Repositorios encontrados: ${#REPOS[@]}"
    echo "  📁 Módulos JavaScript detectados"
    echo "  🧪 Estructura de tests identificada"
    echo "  🔧 Herramientas disponibles"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Para usar la configuración en otros scripts:"
    echo "  source $CONFIG_FILE"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi