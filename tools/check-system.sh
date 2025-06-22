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