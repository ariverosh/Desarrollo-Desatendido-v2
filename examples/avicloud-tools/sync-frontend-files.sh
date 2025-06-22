#!/bin/bash

# sync-frontend-files.sh - Sincronizar archivos frontend con compilación
# Copia automáticamente archivos estáticos modificados sin necesidad de recompilar

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Rutas principales
SOURCE_WWWROOT="$PROJECT_ROOT/Avicloud-Display-Server/AvicloudLocalServer/wwwroot"
TARGET_COMPILATION="/mnt/d/Desarrollo/Compilación/Avicloud/Avicloud LocalServer/bin/wwwroot"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_header() {
    echo -e "${BLUE}🔄 SINCRONIZACIÓN FRONTEND AVICLOUD${NC}"
    echo "=========================================="
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

check_directories() {
    log_info "Verificando directorios..."
    
    if [[ ! -d "$SOURCE_WWWROOT" ]]; then
        log_error "Directorio fuente no encontrado: $SOURCE_WWWROOT"
        exit 1
    fi
    
    if [[ ! -d "$TARGET_COMPILATION" ]]; then
        log_warning "Directorio destino no existe, creándolo..."
        mkdir -p "$TARGET_COMPILATION"
    fi
    
    log_info "Fuente: $SOURCE_WWWROOT"
    log_info "Destino: $TARGET_COMPILATION"
}

sync_files() {
    local mode="$1"
    local changed_files=0
    
    case "$mode" in
        "all")
            log_info "Sincronizando TODOS los archivos frontend..."
            ;;
        "watch")
            log_info "Modo vigilancia - solo archivos modificados..."
            ;;
        "force")
            log_info "Sincronización FORZADA - sobrescribiendo todo..."
            ;;
    esac
    
    # Archivos y carpetas a sincronizar
    declare -a SYNC_PATHS=(
        "css"
        "js" 
        "html"
        "img"
        "favicon.ico"
        "*.html"
    )
    
    for path in "${SYNC_PATHS[@]}"; do
        local source_path="$SOURCE_WWWROOT/$path"
        local target_path="$TARGET_COMPILATION/$path"
        
        if [[ -e "$source_path" ]]; then
            if [[ -d "$source_path" ]]; then
                # Es un directorio
                log_info "Sincronizando directorio: $path"
                
                if [[ "$mode" == "force" ]]; then
                    # Sincronización forzada
                    rsync -av --delete "$source_path/" "$target_path/" 2>/dev/null
                else
                    # Sincronización incremental
                    rsync -av --update "$source_path/" "$target_path/" 2>/dev/null
                fi
                
                if [[ $? -eq 0 ]]; then
                    local file_count=$(find "$source_path" -type f | wc -l)
                    log_success "✓ $path ($file_count archivos)"
                    ((changed_files++))
                else
                    log_error "Error sincronizando $path"
                fi
            else
                # Es un archivo
                if [[ "$source_path" -nt "$target_path" ]] || [[ "$mode" == "force" ]]; then
                    log_info "Copiando archivo: $path"
                    cp "$source_path" "$target_path" 2>/dev/null
                    
                    if [[ $? -eq 0 ]]; then
                        log_success "✓ $path"
                        ((changed_files++))
                    else
                        log_error "Error copiando $path"
                    fi
                fi
            fi
        fi
    done
    
    return $changed_files
}

check_avicloud_running() {
    if tasklist.exe 2>/dev/null | grep -q "AvicloudLocalServer.exe"; then
        return 0  # Está corriendo
    else
        return 1  # No está corriendo
    fi
}

restart_avicloud_if_needed() {
    local changed_files="$1"
    
    if [[ $changed_files -gt 0 ]] && check_avicloud_running; then
        log_warning "Detectados $changed_files cambios. ¿Reiniciar Avicloud? (y/N)"
        
        # En modo automático, no preguntar
        if [[ "$AUTO_RESTART" == "true" ]]; then
            log_info "Modo automático: reiniciando Avicloud..."
            restart_avicloud
        else
            read -n 1 -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                restart_avicloud
            else
                log_info "Avicloud no reiniciado. Los cambios se aplicarán en el próximo reinicio."
            fi
        fi
    fi
}

restart_avicloud() {
    log_info "Reiniciando sistema Avicloud..."
    
    # Usar el script de reinicio existente
    if [[ -f "$PROJECT_ROOT/Desarrollo Desatendido/tools/restart-avicloud.sh" ]]; then
        "$PROJECT_ROOT/Desarrollo Desatendido/tools/restart-avicloud.sh"
    else
        log_warning "Script de reinicio no encontrado, reinicio manual requerido"
    fi
}

watch_mode() {
    log_info "Iniciando modo vigilancia..."
    log_info "Presiona Ctrl+C para detener"
    echo ""
    
    # Verificar si inotifywait está disponible
    if ! command -v inotifywait &> /dev/null; then
        log_warning "inotifywait no disponible. Usando modo polling cada 30 segundos..."
        
        while true; do
            sync_files "watch"
            local changed=$?
            
            if [[ $changed -gt 0 ]]; then
                log_success "Sincronizados $changed elementos"
                restart_avicloud_if_needed $changed
            fi
            
            sleep 30
        done
    else
        # Usar inotifywait para vigilancia en tiempo real
        inotifywait -m -r -e modify,create,delete,move "$SOURCE_WWWROOT" \
            --format '%w%f %e' 2>/dev/null | while read file event; do
            
            # Filtrar solo archivos relevantes
            if [[ "$file" =~ \.(js|css|html|json|png|jpg|jpeg|gif|ico)$ ]]; then
                log_info "Detectado cambio: $(basename "$file") ($event)"
                sync_files "watch"
                local changed=$?
                
                if [[ $changed -gt 0 ]]; then
                    restart_avicloud_if_needed $changed
                fi
            fi
        done
    fi
}

show_usage() {
    cat << EOF
🔄 SINCRONIZADOR FRONTEND AVICLOUD

Uso: $(basename "$0") [OPCIONES] [MODO]

MODOS:
  all      Sincronizar todos los archivos (por defecto)
  watch    Modo vigilancia - sincronizar cambios automáticamente  
  force    Sincronización forzada - sobrescribir todo
  
OPCIONES:
  --auto-restart    Reiniciar Avicloud automáticamente tras cambios
  --dry-run        Mostrar qué se haría sin ejecutar
  --help           Mostrar esta ayuda

EJEMPLOS:
  $(basename "$0")                    # Sincronización básica
  $(basename "$0") watch              # Vigilancia continua
  $(basename "$0") force --auto-restart  # Forzado con reinicio automático
  
DESCRIPCIÓN:
  Este script sincroniza archivos estáticos (JS, CSS, HTML) desde el código
  fuente hacia la carpeta de compilación, evitando recompilar solo por
  cambios en frontend.
  
  Útil durante desarrollo para aplicar cambios inmediatamente.
EOF
}

# === FUNCIÓN PRINCIPAL ===
main() {
    local mode="all"
    local dry_run=false
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-restart)
                AUTO_RESTART="true"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            all|watch|force)
                mode="$1"
                shift
                ;;
            *)
                log_error "Argumento desconocido: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_header
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "MODO DRY-RUN - No se ejecutarán cambios"
        echo ""
    fi
    
    check_directories
    echo ""
    
    if [[ "$mode" == "watch" ]]; then
        watch_mode
    else
        sync_files "$mode"
        local changed=$?
        
        echo ""
        if [[ $changed -gt 0 ]]; then
            log_success "Sincronización completada: $changed elementos procesados"
            restart_avicloud_if_needed $changed
        else
            log_info "No hay cambios que sincronizar"
        fi
    fi
}

# Manejar Ctrl+C en modo watch
trap 'log_info "Deteniendo vigilancia..."; exit 0' INT

# Ejecutar función principal
main "$@"