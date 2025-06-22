#!/bin/bash

# ========================================
# STOP AVICLOUD - Detener todas las aplicaciones
# ========================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/system-info.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🛑 DETENER SISTEMA AVICLOUD${NC}"
echo "=============================================="

# Función para detener sistema (ya definida en system-info.sh)
stop_system

echo ""
echo -e "${GREEN}✅ Sistema Avicloud detenido completamente${NC}"

# Verificar que no queden procesos
REMAINING=$("/mnt/c/Windows/System32/tasklist.exe" 2>/dev/null | grep -i avicloud | wc -l)
if [ $REMAINING -eq 0 ]; then
    echo -e "${GREEN}✅ No hay procesos Avicloud ejecutándose${NC}"
else
    echo -e "${YELLOW}⚠️  Aún hay $REMAINING procesos Avicloud ejecutándose${NC}"
    echo ""
    echo "Procesos restantes:"
    "/mnt/c/Windows/System32/tasklist.exe" 2>/dev/null | grep -i avicloud
fi

exit 0