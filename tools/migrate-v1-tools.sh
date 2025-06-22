#!/bin/bash
# migrate-v1-tools.sh - Migra herramientas críticas del sistema v1
# Copia y adapta las herramientas esenciales para el sistema v2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar configuración del proyecto
source "$BASE_DIR/state/project-config.sh"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔧 Migración de Herramientas v1 → v2${NC}"
echo "======================================"
echo ""

# Lista de herramientas críticas a migrar
CRITICAL_TOOLS=(
    "start-avicloud.sh"
    "stop-avicloud.sh"
    "restart-avicloud.sh"
    "build-avicloud-enhanced.sh"
    "sync-frontend-files.sh"
    "check-avicloud-status.sh"
)

# Crear directorio de herramientas si no existe
mkdir -p "$BASE_DIR/tools/avicloud"

# Contador de herramientas migradas
MIGRATED=0
FAILED=0

# Función para migrar una herramienta
migrate_tool() {
    local TOOL_NAME=$1
    local SOURCE_PATH="$V1_SYSTEM/tools/$TOOL_NAME"
    local DEST_PATH="$BASE_DIR/tools/avicloud/$TOOL_NAME"
    
    echo -ne "  📄 $TOOL_NAME... "
    
    if [[ -f "$SOURCE_PATH" ]]; then
        # Copiar herramienta
        cp "$SOURCE_PATH" "$DEST_PATH"
        
        # Hacer ejecutable
        chmod +x "$DEST_PATH"
        
        # Crear wrapper con rutas actualizadas
        local WRAPPER_PATH="$BASE_DIR/tools/$TOOL_NAME"
        cat > "$WRAPPER_PATH" << EOF
#!/bin/bash
# Wrapper para $TOOL_NAME - Sistema v2
# Auto-generado por migrate-v1-tools.sh

# Cargar configuración del proyecto
source "\$(dirname "\${BASH_SOURCE[0]}")/../state/project-config.sh"

# Ejecutar herramienta original con contexto actualizado
cd "\$AVICLOUD_ROOT"
exec "\$(dirname "\${BASH_SOURCE[0]}")/avicloud/$TOOL_NAME" "\$@"
EOF
        
        chmod +x "$WRAPPER_PATH"
        
        echo -e "${GREEN}✅${NC}"
        ((MIGRATED++))
    else
        echo -e "${YELLOW}⚠️  No encontrada${NC}"
        ((FAILED++))
    fi
}

# Migrar herramientas críticas
echo -e "${YELLOW}Migrando herramientas críticas...${NC}"
for tool in "${CRITICAL_TOOLS[@]}"; do
    migrate_tool "$tool"
done

# Crear herramienta de verificación de estado
echo -e "\n${YELLOW}Creando herramientas adicionales...${NC}"

# Crear check-system.sh
cat > "$BASE_DIR/tools/check-system.sh" << 'CHECK_EOF'
#!/bin/bash
# check-system.sh - Verifica el estado del sistema Avicloud

source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"

echo "🔍 Verificando Sistema Avicloud..."
echo ""

# Verificar servidor
if curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "✅ Servidor Avicloud: Activo"
else
    echo "❌ Servidor Avicloud: Inactivo"
fi

# Verificar procesos
echo ""
echo "📊 Procesos activos:"
tasklist.exe 2>/dev/null | grep -E "(AvicloudLocalServer|Avicloud Display)" | head -5 || echo "  Ninguno encontrado"

# Verificar logs recientes
LOG_DIR="$AVICLOUD_ROOT/Compilación/Avicloud/Avicloud LocalServer/bin/logs"
if [[ -d "$LOG_DIR" ]]; then
    echo ""
    echo "📝 Logs más recientes:"
    ls -lt "$LOG_DIR"/*.log 2>/dev/null | head -3 | awk '{print "  " $9}'
fi
CHECK_EOF

chmod +x "$BASE_DIR/tools/check-system.sh"
echo -e "  📄 check-system.sh... ${GREEN}✅${NC}"

# Crear quick-test.sh
cat > "$BASE_DIR/tools/quick-test.sh" << 'TEST_EOF'
#!/bin/bash
# quick-test.sh - Ejecuta pruebas rápidas del sistema

source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"

echo "🧪 Ejecutando pruebas rápidas..."
echo ""

# Verificar que el servidor esté activo
if ! curl -s http://localhost:5000/health > /dev/null 2>&1; then
    echo "⚠️  El servidor no está activo. Iniciando..."
    "$AVICLOUD_ROOT/Desarrollo Desatendido/tools/start-avicloud.sh"
    sleep 5
fi

# Ejecutar prueba básica
cd "$TEST_ROOT"
if [[ -f "playwright/playlists/test-1-activation.js" ]]; then
    echo "Ejecutando test de activación de playlists..."
    node playwright/playlists/test-1-activation.js
else
    echo "⚠️  No se encontraron tests de Playwright"
fi
TEST_EOF

chmod +x "$BASE_DIR/tools/quick-test.sh"
echo -e "  📄 quick-test.sh... ${GREEN}✅${NC}"

# Resumen
echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}         RESUMEN DE MIGRACIÓN         ${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo "  ✅ Herramientas migradas: $MIGRATED"
echo "  ⚠️  No encontradas: $FAILED"
echo "  📁 Ubicación: $BASE_DIR/tools/"
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo ""
echo "Las herramientas están disponibles en:"
echo "  ./tools/start-avicloud.sh"
echo "  ./tools/stop-avicloud.sh"
echo "  ./tools/check-system.sh"
echo "  etc..."