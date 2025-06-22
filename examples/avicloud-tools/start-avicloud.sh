#!/bin/bash

# ========================================
# START AVICLOUD - Iniciar sistema completo
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/system-info.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Procesar parámetros
KILL_CLIENT_APPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --kill-apps|--close-apps)
            KILL_CLIENT_APPS=true
            shift
            ;;
        --help|-h)
            echo "🚀 INICIAR SISTEMA AVICLOUD"
            echo "=============================================="
            echo ""
            echo "Uso: $0 [opciones]"
            echo ""
            echo "Opciones:"
            echo "  --kill-apps, --close-apps    Cerrar todas las aplicaciones cliente antes de iniciar"
            echo "                               (útil para testing de recuperación de contexto)"
            echo "  --help, -h                   Mostrar esta ayuda"
            echo ""
            echo "Ejemplos:"
            echo "  $0                           # Inicio normal (preserva apps cliente)"
            echo "  $0 --kill-apps              # Inicio cerrando todas las apps cliente"
            echo ""
            exit 0
            ;;
        *)
            echo "❌ Parámetro desconocido: $1"
            echo "   Usa --help para ver opciones disponibles"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}🚀 INICIAR SISTEMA AVICLOUD${NC}"
echo "=============================================="

if [ "$KILL_CLIENT_APPS" = true ]; then
    echo "⚠️  Modo: Cerrar aplicaciones cliente existentes"
else
    echo "ℹ️  Modo: Preservar aplicaciones cliente existentes"
fi
echo ""

# Función para iniciar sistema (ya definida en system-info.sh)
if start_system "$KILL_CLIENT_APPS"; then
    echo ""
    echo -e "${GREEN}✅ Sistema Avicloud iniciado exitosamente${NC}"
    echo ""
    echo "📋 URLs disponibles:"
    echo "   🌐 Servidor: $SERVER_URL"
    echo "   👁️  Visor: $VIEWER_URL"
    echo "   🔐 Login: $LOGIN_URL"
    echo ""
    echo "🔑 Credenciales:"
    echo "   Usuario: $ADMIN_USER"
    echo "   Contraseña: $ADMIN_PASS"
    echo ""
    echo -e "${BLUE}💡 Para abrir visor automáticamente:${NC}"
    echo "   ./tools/open-viewer.sh"
    
    exit 0
else
    echo ""
    echo -e "${RED}❌ Error al iniciar el sistema Avicloud${NC}"
    echo ""
    echo "🔧 Posibles soluciones:"
    echo "   1. Verificar que esté compilado: ./tools/build-avicloud-enhanced.sh"
    echo "   2. Verificar logs: tail -f \"$LOGS_DIR/general [$(date +%Y-%m-%d)].log\""
    echo "   3. Reiniciar sistema: ./tools/stop-avicloud.sh && ./tools/start-avicloud.sh"
    
    exit 1
fi