#!/bin/bash

# Script mejorado para compilar Avicloud desde WSL usando .NET de Windows
# Archivo: /tools/build-avicloud-enhanced.sh

PROJECT_DIR="/mnt/d/desarrollo/Avicloud Display/Avicloud-Display-Server/AvicloudLocalServer"
PROJECT_DIR_WIN="D:\\desarrollo\\Avicloud Display\\Avicloud-Display-Server\\AvicloudLocalServer"
LOG_FILE="$HOME/avicloud_build_$(date +%Y%m%d_%H%M%S).log"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "$(date '+%H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
}

log_error() {
    log "${RED}❌ $1${NC}"
}

echo "🏗️ COMPILACIÓN AVICLOUD DISPLAY (WSL → Windows .NET)"
echo "====================================================="

# Verificar que el directorio existe
if [ ! -d "$PROJECT_DIR" ]; then
    log_error "No se puede acceder al directorio: $PROJECT_DIR"
    exit 1
fi

log_info "Directorio WSL: $PROJECT_DIR"
log_info "Directorio Windows: $PROJECT_DIR_WIN"
log_info "Log: $LOG_FILE"

# Verificar .NET de Windows via cmd
log_info "Verificando .NET de Windows..."
DOTNET_VERSION=$(cmd.exe /c "dotnet --version" 2>/dev/null | tr -d '\r\n')
if [ -z "$DOTNET_VERSION" ]; then
    log_error ".NET SDK de Windows no encontrado"
    log_error "Asegúrate de que .NET esté instalado en Windows y en el PATH"
    exit 1
fi

log_success ".NET SDK Windows: $DOTNET_VERSION"

# Función para ejecutar comando dotnet via Windows con PowerShell
dotnet_win() {
    local cmd="$1"
    log_info "Ejecutando: dotnet $cmd"
    # Usar PowerShell para mejor manejo de rutas con espacios
    powershell.exe -Command "Set-Location 'D:\\desarrollo\\Avicloud Display\\Avicloud-Display-Server\\AvicloudLocalServer'; dotnet $cmd" 2>&1 | tee -a "$LOG_FILE"
    return ${PIPESTATUS[0]}
}

# Limpiar compilación anterior
log_info "Limpiando compilación anterior..."
if dotnet_win "clean AvicloudLocalServer.csproj"; then
    log_success "Limpieza completada"
else
    log_error "Error en limpieza (continuando de todos modos)"
fi

# Restaurar packages
log_info "Restaurando packages..."
if dotnet_win "restore AvicloudLocalServer.csproj"; then
    log_success "Packages restaurados"
else
    log_error "Error restaurando packages"
    exit 1
fi

# Compilar
log_info "Compilando proyecto..."
if dotnet_win "build AvicloudLocalServer.csproj --no-restore --configuration Release"; then
    log_success "Compilación exitosa"
    
    # Verificar que el ejecutable se creó
    EXECUTABLE_PATH="/mnt/d/Desarrollo/Compilación/Avicloud/Avicloud LocalServer/bin/AvicloudLocalServer.exe"
    if [ -f "$EXECUTABLE_PATH" ]; then
        log_success "Ejecutable generado: $EXECUTABLE_PATH"
    else
        log_error "Ejecutable no encontrado en: $EXECUTABLE_PATH"
    fi
else
    log_error "Error en compilación"
    exit 1
fi

log_success "Build completado exitosamente desde WSL"
echo "📄 Log completo: $LOG_FILE"