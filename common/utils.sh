#!/bin/bash
# utils.sh - Funciones comunes reutilizables
# Sigue las Reglas de Oro: NO duplicación, errores explícitos

set -euo pipefail

# Colores para output consistente
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_NC='\033[0m'

# Función para logging con timestamp
log() {
    local level=$1
    shift
    local message="$@"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message"
}

# Función para errores con solución sugerida
error_with_solution() {
    local error_msg=$1
    local solution=$2
    
    echo -e "${COLOR_RED}ERROR: $error_msg${COLOR_NC}" >&2
    echo -e "${COLOR_YELLOW}Solución: $solution${COLOR_NC}" >&2
    exit 1
}

# Verificar que un comando existe
require_command() {
    local cmd=$1
    local install_hint=${2:-"Instalar con el gestor de paquetes de tu sistema"}
    
    if ! command -v "$cmd" &>/dev/null; then
        error_with_solution \
            "Comando '$cmd' no encontrado" \
            "$install_hint"
    fi
}

# Verificar que un archivo existe
require_file() {
    local file=$1
    local hint=${2:-"Verificar que el archivo exista o crearlo"}
    
    if [[ ! -f "$file" ]]; then
        error_with_solution \
            "Archivo requerido no encontrado: $file" \
            "$hint"
    fi
}

# Verificar que un directorio existe
require_directory() {
    local dir=$1
    local hint=${2:-"Crear el directorio o verificar la ruta"}
    
    if [[ ! -d "$dir" ]]; then
        error_with_solution \
            "Directorio requerido no encontrado: $dir" \
            "$hint"
    fi
}

# Crear directorio de forma idempotente
ensure_directory() {
    local dir=$1
    
    if [[ ! -d "$dir" ]]; then
        log "INFO" "Creando directorio: $dir"
        mkdir -p "$dir"
    fi
}

# Verificar conexión a servidor
check_server_health() {
    local url=${1:-"http://localhost:5000/health"}
    local timeout=${2:-5}
    
    log "INFO" "Verificando servidor en: $url"
    
    if ! curl -s --max-time "$timeout" "$url" > /dev/null; then
        error_with_solution \
            "No se pudo conectar al servidor en $url" \
            "1. Verificar que el servidor esté iniciado
2. Verificar la URL y puerto
3. Verificar firewall/conectividad"
    fi
    
    log "INFO" "Servidor respondiendo correctamente"
}

# Esperar a que un archivo aparezca
wait_for_file() {
    local file=$1
    local timeout=${2:-30}
    local check_interval=${3:-1}
    
    log "INFO" "Esperando archivo: $file (timeout: ${timeout}s)"
    
    local elapsed=0
    while [[ ! -f "$file" ]] && [[ $elapsed -lt $timeout ]]; do
        sleep "$check_interval"
        ((elapsed += check_interval))
    done
    
    if [[ ! -f "$file" ]]; then
        error_with_solution \
            "Timeout esperando archivo: $file" \
            "Verificar el proceso que debe crear este archivo"
    fi
    
    log "INFO" "Archivo encontrado: $file"
}

# Ejecutar comando con retry
retry_command() {
    local max_attempts=${1:-3}
    local delay=${2:-1}
    shift 2
    local command=("$@")
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log "INFO" "Intento $attempt/$max_attempts: ${command[*]}"
        
        if "${command[@]}"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log "WARN" "Comando falló, reintentando en ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    error_with_solution \
        "Comando falló después de $max_attempts intentos: ${command[*]}" \
        "Verificar los logs para más detalles"
}

# Limpiar recursos al salir
cleanup_on_exit() {
    local cleanup_function=$1
    trap "$cleanup_function" EXIT INT TERM
}

# Validar que una variable no esté vacía
require_var() {
    local var_name=$1
    local var_value=${!var_name:-}
    local hint=${2:-"Definir la variable $var_name"}
    
    if [[ -z "$var_value" ]]; then
        error_with_solution \
            "Variable requerida vacía: $var_name" \
            "$hint"
    fi
}

# Obtener ruta absoluta de forma portable
get_absolute_path() {
    local path=$1
    
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
    else
        error_with_solution \
            "Ruta no existe: $path" \
            "Verificar que la ruta sea correcta"
    fi
}

# Verificar espacio en disco
check_disk_space() {
    local path=$1
    local required_mb=${2:-100}
    
    local available_mb=$(df -m "$path" | awk 'NR==2 {print $4}')
    
    if [[ $available_mb -lt $required_mb ]]; then
        error_with_solution \
            "Espacio insuficiente en $path: ${available_mb}MB disponibles, ${required_mb}MB requeridos" \
            "Liberar espacio en disco o cambiar la ubicación"
    fi
    
    log "INFO" "Espacio disponible: ${available_mb}MB"
}

# Exportar todas las funciones para subshells
export -f log error_with_solution require_command require_file
export -f require_directory ensure_directory check_server_health
export -f wait_for_file retry_command cleanup_on_exit require_var
export -f get_absolute_path check_disk_space