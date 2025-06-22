#!/bin/bash

# ========================================
# RESTART AVICLOUD - Reiniciar sistema completo
# ========================================
# Reutiliza los scripts existentes stop-avicloud.sh y start-avicloud.sh
# para hacer un reinicio limpio del sistema

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 REINICIAR SISTEMA AVICLOUD${NC}"
echo "=============================================="

# 1. Detener sistema usando script existente
echo -e "${YELLOW}📍 Paso 1: Deteniendo sistema...${NC}"
if "$SCRIPT_DIR/stop-avicloud.sh"; then
    echo -e "${GREEN}✅ Sistema detenido correctamente${NC}"
else
    echo -e "${RED}❌ Error al detener el sistema${NC}"
    exit 1
fi

echo ""

# 2. Esperar un momento para asegurar limpieza completa
echo -e "${YELLOW}📍 Paso 2: Esperando limpieza completa (2 segundos)...${NC}"
sleep 2

# 3. Iniciar sistema usando script existente
echo -e "${YELLOW}📍 Paso 3: Iniciando sistema...${NC}"
if "$SCRIPT_DIR/start-avicloud.sh"; then
    echo ""
    echo -e "${GREEN}🎉 REINICIO COMPLETADO EXITOSAMENTE${NC}"
    echo ""
    echo "📋 Sistema listo para usar:"
    echo "   🌐 Servidor: http://172.28.80.1:5000"
    echo "   👁️  Visor: http://172.28.80.1:5000/viewer"
    echo "   🔐 Credenciales: admin / admin888"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}❌ Error al reiniciar el sistema${NC}"
    echo ""
    echo "🔧 Posibles soluciones:"
    echo "   1. Verificar compilación: ./tools/build-avicloud-enhanced.sh"
    echo "   2. Intentar manualmente:"
    echo "      ./tools/stop-avicloud.sh"
    echo "      ./tools/start-avicloud.sh"
    echo "   3. Revisar logs en: /mnt/d/Desarrollo/Compilación/Avicloud/"
    echo ""
    exit 1
fi