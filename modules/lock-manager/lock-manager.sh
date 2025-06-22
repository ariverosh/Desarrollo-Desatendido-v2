#!/bin/bash
# lock-manager.sh - Sistema de gestión de locks para concurrencia
# Previene conflictos entre múltiples instancias de Claude

set -euo pipefail

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCKS_DIR="$BASE_DIR/.locks"
LOCKS_DB="$BASE_DIR/state/locks.db"

# Funciones principales

# Adquirir un lock para archivos específicos
acquire_lock() {
    local TASK_ID=$1
    shift
    local FILES=("$@")
    local LOCK_FILE="$LOCKS_DIR/${TASK_ID}.lock"
    
    echo "🔒 Intentando adquirir lock para tarea: $TASK_ID"
    
    # Verificar conflictos con locks existentes
    for file in "${FILES[@]}"; do
        local EXISTING_LOCKS=$(find "$LOCKS_DIR" -name "*.lock" -exec grep -l "\"$file\"" {} \; 2>/dev/null || true)
        if [[ -n "$EXISTING_LOCKS" ]]; then
            for existing_lock in $EXISTING_LOCKS; do
                # Verificar si el lock está vivo
                if is_lock_alive "$existing_lock"; then
                    local BLOCKING_TASK=$(basename "$existing_lock" .lock)
                    echo "❌ Conflicto: $file está bloqueado por tarea $BLOCKING_TASK"
                    log_lock_event "$TASK_ID" "conflict" "Bloqueado por $BLOCKING_TASK en $file"
                    return 1
                else
                    echo "🧹 Limpiando lock muerto: $existing_lock"
                    rm -f "$existing_lock"
                fi
            done
        fi
    done
    
    # Crear lock con metadata
    local LOCK_DATA=$(cat << EOF
{
    "task_id": "$TASK_ID",
    "pid": $$,
    "files": $(printf '%s\n' "${FILES[@]}" | jq -R . | jq -s .),
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "expires": "$(date -u -d '+1 hour' +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    echo "$LOCK_DATA" > "$LOCK_FILE"
    
    # Registrar en base de datos
    sqlite3 "$LOCKS_DB" << EOF
INSERT INTO active_locks (task_id, files, pid, expires_at)
VALUES ('$TASK_ID', '$(printf '%s\n' "${FILES[@]}" | jq -R . | jq -s . -c)', $$, datetime('now', '+1 hour'));
EOF
    
    log_lock_event "$TASK_ID" "acquired" "Lock adquirido para ${#FILES[@]} archivos"
    
    echo "✅ Lock adquirido exitosamente: $TASK_ID"
    
    # Iniciar heartbeat en background
    start_heartbeat "$TASK_ID" &
    
    return 0
}

# Liberar un lock
release_lock() {
    local TASK_ID=$1
    local LOCK_FILE="$LOCKS_DIR/${TASK_ID}.lock"
    
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        
        # Actualizar base de datos
        sqlite3 "$LOCKS_DB" "DELETE FROM active_locks WHERE task_id = '$TASK_ID';"
        
        log_lock_event "$TASK_ID" "released" "Lock liberado voluntariamente"
        
        echo "🔓 Lock liberado: $TASK_ID"
    else
        echo "⚠️ No se encontró lock para: $TASK_ID"
    fi
}

# Verificar si un lock está vivo
is_lock_alive() {
    local LOCK_FILE=$1
    
    if [[ ! -f "$LOCK_FILE" ]]; then
        return 1
    fi
    
    # Verificar PID
    local PID=$(jq -r .pid "$LOCK_FILE" 2>/dev/null || echo "0")
    if [[ "$PID" != "0" ]] && kill -0 "$PID" 2>/dev/null; then
        # Proceso existe, verificar heartbeat
        local HEARTBEAT=$(jq -r .heartbeat "$LOCK_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")
        local HEARTBEAT_EPOCH=$(date -d "$HEARTBEAT" +%s 2>/dev/null || echo 0)
        local NOW_EPOCH=$(date +%s)
        local AGE=$((NOW_EPOCH - HEARTBEAT_EPOCH))
        
        # Si el heartbeat tiene más de 2 minutos, considerar muerto
        if [[ $AGE -gt 120 ]]; then
            return 1
        fi
        
        return 0
    fi
    
    return 1
}

# Limpiar locks muertos
cleanup_dead_locks() {
    echo "🧹 Limpiando locks muertos..."
    
    local CLEANED=0
    
    for lock_file in "$LOCKS_DIR"/*.lock; do
        [[ -f "$lock_file" ]] || continue
        
        if ! is_lock_alive "$lock_file"; then
            local TASK_ID=$(basename "$lock_file" .lock)
            echo "   Removiendo lock muerto: $TASK_ID"
            rm -f "$lock_file"
            
            # Limpiar de la base de datos
            sqlite3 "$LOCKS_DB" "DELETE FROM active_locks WHERE task_id = '$TASK_ID';"
            
            log_lock_event "$TASK_ID" "expired" "Lock expirado y removido"
            
            ((CLEANED++))
        fi
    done
    
    echo "✅ Limpiados $CLEANED locks muertos"
}

# Iniciar heartbeat para mantener lock vivo
start_heartbeat() {
    local TASK_ID=$1
    local LOCK_FILE="$LOCKS_DIR/${TASK_ID}.lock"
    local MY_PID=$$
    
    (
        while kill -0 $MY_PID 2>/dev/null && [[ -f "$LOCK_FILE" ]]; do
            # Actualizar heartbeat
            local TEMP_FILE="${LOCK_FILE}.tmp"
            if jq '.heartbeat = $newtime' --arg newtime "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LOCK_FILE" > "$TEMP_FILE"; then
                mv "$TEMP_FILE" "$LOCK_FILE"
                
                # Actualizar en base de datos
                sqlite3 "$LOCKS_DB" "UPDATE active_locks SET heartbeat = datetime('now') WHERE task_id = '$TASK_ID';" 2>/dev/null || true
            fi
            
            sleep 30
        done
        
        # Al salir, liberar lock si aún existe
        if [[ -f "$LOCK_FILE" ]]; then
            release_lock "$TASK_ID"
        fi
    ) &
}

# Mostrar locks activos
show_active_locks() {
    echo "🔒 LOCKS ACTIVOS:"
    echo "=================="
    
    local COUNT=0
    
    for lock_file in "$LOCKS_DIR"/*.lock; do
        [[ -f "$lock_file" ]] || continue
        
        if is_lock_alive "$lock_file"; then
            local TASK_ID=$(basename "$lock_file" .lock)
            local FILES_COUNT=$(jq -r '.files | length' "$lock_file" 2>/dev/null || echo 0)
            local CREATED=$(jq -r '.created' "$lock_file" 2>/dev/null || echo "Unknown")
            local PID=$(jq -r '.pid' "$lock_file" 2>/dev/null || echo "Unknown")
            
            echo "📌 Tarea: $TASK_ID"
            echo "   PID: $PID"
            echo "   Archivos bloqueados: $FILES_COUNT"
            echo "   Creado: $CREATED"
            echo ""
            
            ((COUNT++))
        fi
    done
    
    if [[ $COUNT -eq 0 ]]; then
        echo "No hay locks activos"
    else
        echo "Total: $COUNT locks activos"
    fi
}

# Registrar evento en el historial
log_lock_event() {
    local TASK_ID=$1
    local ACTION=$2
    local DETAILS=$3
    
    sqlite3 "$LOCKS_DB" << EOF
INSERT INTO lock_history (task_id, action, details)
VALUES ('$TASK_ID', '$ACTION', '$DETAILS');
EOF
}

# Verificar archivos específicos
check_files_locked() {
    local FILES=("$@")
    local LOCKED_FILES=()
    
    for file in "${FILES[@]}"; do
        local LOCKS=$(find "$LOCKS_DIR" -name "*.lock" -exec grep -l "\"$file\"" {} \; 2>/dev/null || true)
        
        for lock in $LOCKS; do
            if is_lock_alive "$lock"; then
                LOCKED_FILES+=("$file (por $(basename $lock .lock))")
            fi
        done
    done
    
    if [[ ${#LOCKED_FILES[@]} -gt 0 ]]; then
        echo "❌ Archivos bloqueados:"
        printf '   - %s\n' "${LOCKED_FILES[@]}"
        return 1
    else
        echo "✅ Todos los archivos están disponibles"
        return 0
    fi
}

# Función principal para uso desde línea de comandos
main() {
    local COMMAND=${1:-help}
    
    case "$COMMAND" in
        acquire)
            shift
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 acquire <task_id> <archivo1> [archivo2...]"
                exit 1
            fi
            acquire_lock "$@"
            ;;
            
        release)
            if [[ $# -lt 2 ]]; then
                echo "Uso: $0 release <task_id>"
                exit 1
            fi
            release_lock "$2"
            ;;
            
        cleanup)
            cleanup_dead_locks
            ;;
            
        show)
            show_active_locks
            ;;
            
        check)
            shift
            if [[ $# -lt 1 ]]; then
                echo "Uso: $0 check <archivo1> [archivo2...]"
                exit 1
            fi
            check_files_locked "$@"
            ;;
            
        help|*)
            echo "Sistema de Gestión de Locks v1.0"
            echo ""
            echo "Comandos disponibles:"
            echo "  acquire <task_id> <archivos...>  - Adquirir lock para archivos"
            echo "  release <task_id>                - Liberar lock"
            echo "  cleanup                          - Limpiar locks muertos"
            echo "  show                             - Mostrar locks activos"
            echo "  check <archivos...>              - Verificar si archivos están bloqueados"
            echo "  help                             - Mostrar esta ayuda"
            ;;
    esac
}

# Ejecutar función principal si se llama directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi