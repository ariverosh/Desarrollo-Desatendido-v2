#!/bin/bash
# auto-discovery-universal.sh - Sistema Universal de Auto-descubrimiento
# Detecta automáticamente la estructura de CUALQUIER proyecto

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$BASE_DIR/state/project-config.sh"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🔍 Sistema Universal de Auto-Discovery v2.0${NC}"
echo "============================================"
echo ""

# Función para encontrar la raíz del proyecto
find_project_root() {
    echo -e "${YELLOW}Buscando raíz del proyecto...${NC}" >&2
    
    local CURRENT_DIR="$BASE_DIR"
    local PROJECT_ROOT=""
    local MAX_LEVELS=5
    local LEVEL=0
    
    # Subir niveles hasta encontrar indicadores de proyecto
    while [[ "$CURRENT_DIR" != "/" ]] && [[ $LEVEL -lt $MAX_LEVELS ]]; do
        # Buscar indicadores comunes de raíz de proyecto
        if [[ -d "$CURRENT_DIR/.git" ]] || 
           [[ -f "$CURRENT_DIR/package.json" ]] ||
           [[ -f "$CURRENT_DIR/pom.xml" ]] ||
           [[ -f "$CURRENT_DIR/build.gradle" ]] ||
           [[ -f "$CURRENT_DIR/Cargo.toml" ]] ||
           [[ -f "$CURRENT_DIR/go.mod" ]] ||
           [[ -f "$CURRENT_DIR/requirements.txt" ]] ||
           [[ -f "$CURRENT_DIR/Gemfile" ]] ||
           [[ -f "$CURRENT_DIR/.project" ]] ||
           [[ -f "$CURRENT_DIR/CMakeLists.txt" ]] ||
           [[ -f "$CURRENT_DIR/Makefile" ]] ||
           [[ -f "$CURRENT_DIR/*.sln" ]] ||
           [[ -f "$CURRENT_DIR/*.csproj" ]] ||
           [[ -f "$CURRENT_DIR/*.fsproj" ]]; then
            PROJECT_ROOT="$CURRENT_DIR"
            echo -e "${GREEN}✅ Encontrado en: $PROJECT_ROOT${NC}" >&2
            break
        fi
        
        CURRENT_DIR="$(dirname "$CURRENT_DIR")"
        ((LEVEL++))
    done
    
    if [[ -z "$PROJECT_ROOT" ]]; then
        echo -e "${YELLOW}⚠️  No se encontró raíz obvia del proyecto${NC}" >&2
        echo "   Usando directorio padre: $(dirname "$BASE_DIR")" >&2
        PROJECT_ROOT="$(dirname "$BASE_DIR")"
    fi
    
    echo "$PROJECT_ROOT"
}

# Función para detectar el tipo de proyecto
detect_project_type() {
    local ROOT_DIR=$1
    local PROJECT_TYPES=()
    
    echo -e "\n${YELLOW}Detectando tipo de proyecto...${NC}" >&2
    
    # Detectar por archivos característicos
    [[ -f "$ROOT_DIR/package.json" ]] && PROJECT_TYPES+=("Node.js/JavaScript")
    [[ -f "$ROOT_DIR/pom.xml" ]] && PROJECT_TYPES+=("Java/Maven")
    [[ -f "$ROOT_DIR/build.gradle" ]] || [[ -f "$ROOT_DIR/build.gradle.kts" ]] && PROJECT_TYPES+=("Java/Gradle")
    [[ -f "$ROOT_DIR/Cargo.toml" ]] && PROJECT_TYPES+=("Rust")
    [[ -f "$ROOT_DIR/go.mod" ]] && PROJECT_TYPES+=("Go")
    [[ -f "$ROOT_DIR/requirements.txt" ]] || [[ -f "$ROOT_DIR/setup.py" ]] && PROJECT_TYPES+=("Python")
    [[ -f "$ROOT_DIR/Gemfile" ]] && PROJECT_TYPES+=("Ruby")
    [[ -f "$ROOT_DIR/composer.json" ]] && PROJECT_TYPES+=("PHP")
    [[ -f "$ROOT_DIR/*.sln" ]] && PROJECT_TYPES+=(".NET/C#")
    [[ -f "$ROOT_DIR/*.xcodeproj" ]] || [[ -f "$ROOT_DIR/*.xcworkspace" ]] && PROJECT_TYPES+=("iOS/macOS")
    [[ -f "$ROOT_DIR/pubspec.yaml" ]] && PROJECT_TYPES+=("Flutter/Dart")
    
    if [[ ${#PROJECT_TYPES[@]} -eq 0 ]]; then
        PROJECT_TYPES+=("Unknown")
    fi
    
    for type in "${PROJECT_TYPES[@]}"; do
        echo "  🏷️  $type" >&2
    done
    
    printf '%s\n' "${PROJECT_TYPES[@]}"
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

# Función para detectar estructura del proyecto
detect_project_structure() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Analizando estructura del proyecto...${NC}" >&2
    
    # Contar archivos por extensión
    echo "  📊 Archivos por tipo:" >&2
    local EXTENSIONS=("js" "ts" "jsx" "tsx" "py" "java" "cs" "cpp" "c" "h" "go" "rs" "rb" "php" "swift" "kt" "dart")
    
    for ext in "${EXTENSIONS[@]}"; do
        local COUNT=$(find "$ROOT_DIR" -name "*.$ext" -type f 2>/dev/null | wc -l)
        if [[ $COUNT -gt 0 ]]; then
            echo "     ├─ .$ext: $COUNT archivos" >&2
        fi
    done
    
    # Detectar directorios importantes
    echo "  📁 Directorios clave:" >&2
    local KEY_DIRS=("src" "lib" "test" "tests" "spec" "docs" "build" "dist" "bin" "scripts" "config" "public" "static")
    
    for dir in "${KEY_DIRS[@]}"; do
        if [[ -d "$ROOT_DIR/$dir" ]]; then
            local FILE_COUNT=$(find "$ROOT_DIR/$dir" -type f 2>/dev/null | wc -l)
            echo "     ├─ $dir/ ($FILE_COUNT archivos)" >&2
        fi
    done
}

# Función para detectar herramientas de build
detect_build_tools() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Detectando herramientas de build...${NC}" >&2
    
    local BUILD_TOOLS=()
    
    # Detectar herramientas comunes
    [[ -f "$ROOT_DIR/Makefile" ]] && BUILD_TOOLS+=("Make")
    [[ -f "$ROOT_DIR/CMakeLists.txt" ]] && BUILD_TOOLS+=("CMake")
    [[ -f "$ROOT_DIR/package.json" ]] && command -v npm &>/dev/null && BUILD_TOOLS+=("npm")
    [[ -f "$ROOT_DIR/yarn.lock" ]] && BUILD_TOOLS+=("Yarn")
    [[ -f "$ROOT_DIR/pnpm-lock.yaml" ]] && BUILD_TOOLS+=("pnpm")
    [[ -f "$ROOT_DIR/Cargo.toml" ]] && BUILD_TOOLS+=("Cargo")
    [[ -f "$ROOT_DIR/go.mod" ]] && BUILD_TOOLS+=("Go")
    [[ -f "$ROOT_DIR/build.gradle" ]] && BUILD_TOOLS+=("Gradle")
    [[ -f "$ROOT_DIR/pom.xml" ]] && BUILD_TOOLS+=("Maven")
    
    if [[ ${#BUILD_TOOLS[@]} -gt 0 ]]; then
        echo "  🔧 Herramientas encontradas:" >&2
        for tool in "${BUILD_TOOLS[@]}"; do
            echo "     ├─ $tool" >&2
        done
    else
        echo "  ⚠️  No se detectaron herramientas de build" >&2
    fi
    
    printf '%s\n' "${BUILD_TOOLS[@]}"
}

# Función para detectar frameworks de testing
detect_test_frameworks() {
    local ROOT_DIR=$1
    echo -e "\n${YELLOW}Detectando frameworks de testing...${NC}" >&2
    
    local TEST_FRAMEWORKS=()
    
    # JavaScript/TypeScript
    [[ -f "$ROOT_DIR/jest.config.js" ]] || [[ -f "$ROOT_DIR/jest.config.ts" ]] && TEST_FRAMEWORKS+=("Jest")
    [[ -f "$ROOT_DIR/.mocharc.json" ]] || [[ -f "$ROOT_DIR/mocha.opts" ]] && TEST_FRAMEWORKS+=("Mocha")
    [[ -f "$ROOT_DIR/karma.conf.js" ]] && TEST_FRAMEWORKS+=("Karma")
    [[ -f "$ROOT_DIR/cypress.json" ]] || [[ -f "$ROOT_DIR/cypress.config.js" ]] && TEST_FRAMEWORKS+=("Cypress")
    [[ -d "$ROOT_DIR/tests/playwright" ]] || [[ -f "$ROOT_DIR/playwright.config.js" ]] && TEST_FRAMEWORKS+=("Playwright")
    
    # Python
    [[ -f "$ROOT_DIR/pytest.ini" ]] || [[ -f "$ROOT_DIR/conftest.py" ]] && TEST_FRAMEWORKS+=("pytest")
    [[ -f "$ROOT_DIR/tox.ini" ]] && TEST_FRAMEWORKS+=("tox")
    
    # Java
    [[ -d "$ROOT_DIR/src/test/java" ]] && TEST_FRAMEWORKS+=("JUnit")
    
    # .NET
    [[ -f "$ROOT_DIR/*.Test.csproj" ]] || [[ -f "$ROOT_DIR/*.Tests.csproj" ]] && TEST_FRAMEWORKS+=("xUnit/.NET")
    
    if [[ ${#TEST_FRAMEWORKS[@]} -gt 0 ]]; then
        echo "  🧪 Frameworks de testing:" >&2
        for framework in "${TEST_FRAMEWORKS[@]}"; do
            echo "     ├─ $framework" >&2
        done
    fi
    
    printf '%s\n' "${TEST_FRAMEWORKS[@]}"
}

# Función principal
main() {
    echo "Iniciando auto-descubrimiento universal del proyecto..."
    echo ""
    
    # Descubrir raíz del proyecto
    PROJECT_ROOT=$(find_project_root)
    
    # Detectar tipo de proyecto
    mapfile -t PROJECT_TYPES < <(detect_project_type "$PROJECT_ROOT")
    
    # Descubrir repositorios
    mapfile -t REPOS < <(discover_git_repos "$PROJECT_ROOT")
    
    # Detectar estructura
    detect_project_structure "$PROJECT_ROOT"
    
    # Detectar herramientas de build
    mapfile -t BUILD_TOOLS < <(detect_build_tools "$PROJECT_ROOT")
    
    # Detectar frameworks de testing
    mapfile -t TEST_FRAMEWORKS < <(detect_test_frameworks "$PROJECT_ROOT")
    
    # Generar archivo de configuración
    echo -e "\n${YELLOW}Generando archivo de configuración...${NC}"
    
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
# project-config.sh - Configuración auto-descubierta del proyecto
# Generado automáticamente por auto-discovery-universal.sh
# Fecha: $(date)

# Raíz del proyecto
export PROJECT_ROOT="$PROJECT_ROOT"
export PROJECT_NAME="$(basename "$PROJECT_ROOT")"

# Tipo de proyecto detectado
export PROJECT_TYPES=(
$(for type in "${PROJECT_TYPES[@]}"; do echo "    \"$type\""; done)
)

# Repositorios Git descubiertos
export REPOS=(
$(for repo in "${REPOS[@]}"; do echo "    \"$repo\""; done)
)

# Herramientas de build detectadas
export BUILD_TOOLS=(
$(for tool in "${BUILD_TOOLS[@]}"; do echo "    \"$tool\""; done)
)

# Frameworks de testing detectados
export TEST_FRAMEWORKS=(
$(for framework in "${TEST_FRAMEWORKS[@]}"; do echo "    \"$framework\""; done)
)

# Rutas comunes (si existen)
[[ -d "\$PROJECT_ROOT/src" ]] && export SRC_ROOT="\$PROJECT_ROOT/src"
[[ -d "\$PROJECT_ROOT/test" ]] && export TEST_ROOT="\$PROJECT_ROOT/test"
[[ -d "\$PROJECT_ROOT/tests" ]] && export TEST_ROOT="\$PROJECT_ROOT/tests"
[[ -d "\$PROJECT_ROOT/docs" ]] && export DOCS_ROOT="\$PROJECT_ROOT/docs"
[[ -d "\$PROJECT_ROOT/scripts" ]] && export SCRIPTS_ROOT="\$PROJECT_ROOT/scripts"

# Sistema de desarrollo desatendido
export AUTONOMOUS_ROOT="$BASE_DIR"

# Función helper para obtener rutas relativas
get_relative_path() {
    local TARGET=\$1
    local FROM=\${2:-\$(pwd)}
    realpath --relative-to="\$FROM" "\$TARGET" 2>/dev/null || echo "\$TARGET"
}

# Función para verificar contexto del proyecto
verify_project_context() {
    if [[ ! -d "\$PROJECT_ROOT" ]]; then
        echo "⚠️  Error: No se encuentra el proyecto en \$PROJECT_ROOT"
        return 1
    fi
    return 0
}

echo "✅ Configuración del proyecto cargada"
echo "   Proyecto: \$PROJECT_NAME"
echo "   Tipo: \${PROJECT_TYPES[0]}"
echo "   Repositorios: \${#REPOS[@]}"
EOF
    
    chmod +x "$CONFIG_FILE"
    
    # Crear symlink para fácil acceso
    ln -sf "$CONFIG_FILE" "$BASE_DIR/project-config.sh" 2>/dev/null || true
    
    echo -e "${GREEN}✅ Archivo de configuración generado: $CONFIG_FILE${NC}"
    
    # Resumen final
    echo -e "\n${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}          RESUMEN DE DESCUBRIMIENTO         ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo "  📍 Raíz del proyecto: $PROJECT_ROOT"
    echo "  🏷️  Tipo: ${PROJECT_TYPES[0]:-Unknown}"
    echo "  📦 Repositorios Git: ${#REPOS[@]}"
    echo "  🔧 Herramientas de build: ${#BUILD_TOOLS[@]}"
    echo "  🧪 Frameworks de testing: ${#TEST_FRAMEWORKS[@]}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""
    echo "Para usar la configuración en otros scripts:"
    echo "  source $CONFIG_FILE"
}

# Ejecutar si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi