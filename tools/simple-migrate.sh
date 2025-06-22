#!/bin/bash
# simple-migrate.sh - Migración simplificada de herramientas

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$BASE_DIR/state/project-config.sh"

echo "🔧 Migrando herramientas críticas..."
echo ""

# Crear directorio
mkdir -p "$BASE_DIR/tools/avicloud"

# Lista de herramientas
TOOLS=(
    "start-avicloud.sh"
    "stop-avicloud.sh"
    "restart-avicloud.sh"
    "build-avicloud-enhanced.sh"
    "sync-frontend-files.sh"
)

# Copiar herramientas
for tool in "${TOOLS[@]}"; do
    SOURCE="$V1_SYSTEM/tools/$tool"
    DEST="$BASE_DIR/tools/avicloud/$tool"
    
    if [[ -f "$SOURCE" ]]; then
        echo "  ✅ $tool"
        cp "$SOURCE" "$DEST"
        chmod +x "$DEST"
        
        # Crear wrapper simple
        WRAPPER="$BASE_DIR/tools/$tool"
        echo '#!/bin/bash' > "$WRAPPER"
        echo "# Wrapper para $tool" >> "$WRAPPER"
        echo 'source "$(dirname "${BASH_SOURCE[0]}")/../state/project-config.sh"' >> "$WRAPPER"
        echo 'cd "$AVICLOUD_ROOT"' >> "$WRAPPER"
        echo "exec \"\$(dirname \"\${BASH_SOURCE[0]}\")/avicloud/$tool\" \"\$@\"" >> "$WRAPPER"
        chmod +x "$WRAPPER"
    else
        echo "  ⚠️  $tool no encontrado"
    fi
done

echo ""
echo "✅ Migración completada"
echo "   Herramientas en: $BASE_DIR/tools/"