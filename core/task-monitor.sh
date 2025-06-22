#!/bin/bash
# task-monitor.sh - Monitor de Tareas Concurrentes
# Supervisa tareas en ejecución y previene conflictos

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$BASE_DIR/common/utils.sh"

# Configuración
MONITOR_INTERVAL=${MONITOR_INTERVAL:-10}  # Segundos entre chequeos
MAX_CONCURRENT_TASKS=${MAX_CONCURRENT_TASKS:-3}
TASK_TIMEOUT=${TASK_TIMEOUT:-3600}  # 1 hora por defecto

# Colores adicionales
COLOR_CYAN='\033[0;36m'
COLOR_MAGENTA='\033[0;35m'

# Estado del monitor
MONITOR_PID=$$
MONITOR_LOG="$BASE_DIR/logs/orchestrator/monitor-$(date +%Y%m%d-%H%M%S).log"

# Función de logging del monitor
monitor_log() {
    local level=$1
    shift
    local message="$@"
    
    log "$level" "[MONITOR] $message"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$MONITOR_LOG"
}

# Obtener tareas activas con información detallada
get_active_tasks() {
    sqlite3 "$BASE_DIR/state/progress.db" << 'EOF'
SELECT 
    t.id,
    t.name,
    t.phase,
    t.status,
    t.started_at,
    ROUND((julianday('now') - julianday(t.started_at)) * 24 * 60) as minutes_elapsed,
    h.model,
    h.task_type
FROM tasks t
LEFT JOIN task_history h ON t.id = h.task_id
WHERE t.status = 'in_progress'
ORDER BY t.started_at;
EOF
}

# Verificar locks activos
check_active_locks() {
    local task_id=$1
    
    # Usar el lock manager para verificar
    if [[ -x "$BASE_DIR/modules/lock-manager/lock-manager.sh" ]]; then
        "$BASE_DIR/modules/lock-manager/lock-manager.sh" list | grep -q "$task_id" && return 0
    fi
    
    return 1
}

# Detectar tareas colgadas
detect_stalled_tasks() {
    monitor_log "INFO" "🔍 Detectando tareas colgadas..."
    
    local stalled_count=0
    
    while IFS='|' read -r id name phase status started_at elapsed model task_type; do
        if [[ -n "$id" ]] && [[ "$elapsed" -gt $((TASK_TIMEOUT / 60)) ]]; then
            monitor_log "WARN" "⚠️  Tarea colgada detectada: $id - $name"
            monitor_log "WARN" "   Tiempo transcurrido: ${elapsed} minutos"
            ((stalled_count++))
            
            # Verificar si tiene locks activos
            if check_active_locks "$id"; then
                monitor_log "WARN" "   La tarea aún tiene locks activos"
            else
                monitor_log "ERROR" "   La tarea NO tiene locks activos - posible fallo"
                
                # Marcar como fallida
                mark_task_failed "$id" "Timeout después de $elapsed minutos sin actividad"
            fi
        fi
    done < <(get_active_tasks)
    
    if [[ $stalled_count -eq 0 ]]; then
        monitor_log "INFO" "✅ No hay tareas colgadas"
    fi
    
    return $stalled_count
}

# Marcar tarea como fallida
mark_task_failed() {
    local task_id=$1
    local reason=$2
    
    monitor_log "ERROR" "❌ Marcando tarea $task_id como fallida: $reason"
    
    sqlite3 "$BASE_DIR/state/progress.db" << EOF
UPDATE tasks 
SET status = 'failed', 
    completed_at = datetime('now'),
    error_log = '$reason'
WHERE id = '$task_id';

INSERT INTO task_history (task_id, model, status, run_date)
VALUES ('$task_id', 'monitor', 'failed', datetime('now'));
EOF
    
    # Liberar locks si existen
    if [[ -x "$BASE_DIR/modules/lock-manager/lock-manager.sh" ]]; then
        "$BASE_DIR/modules/lock-manager/lock-manager.sh" release "$task_id" 2>/dev/null || true
    fi
}

# Verificar capacidad para nuevas tareas
check_capacity() {
    local active_count=$(sqlite3 "$BASE_DIR/state/progress.db" \
        "SELECT COUNT(*) FROM tasks WHERE status = 'in_progress'")
    
    local available=$((MAX_CONCURRENT_TASKS - active_count))
    
    monitor_log "INFO" "📊 Capacidad: $active_count/$MAX_CONCURRENT_TASKS tareas activas"
    
    if [[ $available -gt 0 ]]; then
        monitor_log "INFO" "✅ Capacidad disponible para $available tareas más"
        return 0
    else
        monitor_log "WARN" "⚠️  Capacidad máxima alcanzada"
        return 1
    fi
}

# Mostrar dashboard de estado
show_dashboard() {
    clear
    echo -e "${COLOR_CYAN}╔════════════════════════════════════════════════════════════╗${COLOR_NC}"
    echo -e "${COLOR_CYAN}║         Monitor de Tareas - Sistema Autónomo v2            ║${COLOR_NC}"
    echo -e "${COLOR_CYAN}╚════════════════════════════════════════════════════════════╝${COLOR_NC}"
    echo ""
    
    # Estadísticas generales
    local total_tasks=$(sqlite3 "$BASE_DIR/state/progress.db" "SELECT COUNT(*) FROM tasks")
    local completed=$(sqlite3 "$BASE_DIR/state/progress.db" "SELECT COUNT(*) FROM tasks WHERE status = 'completed'")
    local in_progress=$(sqlite3 "$BASE_DIR/state/progress.db" "SELECT COUNT(*) FROM tasks WHERE status = 'in_progress'")
    local failed=$(sqlite3 "$BASE_DIR/state/progress.db" "SELECT COUNT(*) FROM tasks WHERE status = 'failed'")
    local pending=$(sqlite3 "$BASE_DIR/state/progress.db" "SELECT COUNT(*) FROM tasks WHERE status = 'pending'")
    
    echo -e "${COLOR_BLUE}📊 Estadísticas Generales:${COLOR_NC}"
    echo "├─ Total: $total_tasks tareas"
    echo "├─ ✅ Completadas: $completed"
    echo "├─ 🔄 En progreso: $in_progress"
    echo "├─ ❌ Fallidas: $failed"
    echo "└─ ⏳ Pendientes: $pending"
    echo ""
    
    # Tareas activas
    echo -e "${COLOR_BLUE}🔄 Tareas Activas:${COLOR_NC}"
    if [[ $in_progress -eq 0 ]]; then
        echo "  No hay tareas en ejecución"
    else
        sqlite3 "$BASE_DIR/state/progress.db" -box << 'EOF'
SELECT 
    id as ID,
    substr(name, 1, 30) as Tarea,
    phase as Fase,
    ROUND((julianday('now') - julianday(started_at)) * 24 * 60) || ' min' as Tiempo
FROM tasks
WHERE status = 'in_progress'
ORDER BY started_at;
EOF
    fi
    echo ""
    
    # Locks activos
    echo -e "${COLOR_BLUE}🔒 Locks Activos:${COLOR_NC}"
    if [[ -f "$BASE_DIR/state/locks.db" ]]; then
        local lock_count=$(sqlite3 "$BASE_DIR/state/locks.db" "SELECT COUNT(*) FROM active_locks")
        if [[ $lock_count -eq 0 ]]; then
            echo "  No hay locks activos"
        else
            sqlite3 "$BASE_DIR/state/locks.db" -box << 'EOF'
SELECT 
    task_id as Tarea,
    substr(files, 1, 40) as Archivos,
    ROUND((julianday('now') - julianday(heartbeat)) * 24 * 60 * 60) || 's ago' as Heartbeat
FROM active_locks
ORDER BY created_at;
EOF
        fi
    fi
    echo ""
    
    # Última actualización
    echo -e "${COLOR_GREEN}Última actualización: $(date +'%Y-%m-%d %H:%M:%S')${COLOR_NC}"
    echo -e "${COLOR_YELLOW}Presiona Ctrl+C para salir${COLOR_NC}"
}

# Monitoreo continuo
continuous_monitor() {
    monitor_log "INFO" "🚀 Iniciando monitoreo continuo (PID: $MONITOR_PID)"
    monitor_log "INFO" "Intervalo: ${MONITOR_INTERVAL}s, Max tareas: $MAX_CONCURRENT_TASKS"
    
    local cycles=0
    
    while true; do
        ((cycles++))
        
        if [[ $((cycles % 6)) -eq 0 ]]; then  # Cada minuto
            monitor_log "INFO" "🔄 Ciclo de monitoreo #$cycles"
            
            # Detectar tareas colgadas
            detect_stalled_tasks
            
            # Verificar capacidad
            check_capacity
            
            # Limpiar locks muertos
            if [[ -x "$BASE_DIR/modules/lock-manager/lock-manager.sh" ]]; then
                "$BASE_DIR/modules/lock-manager/lock-manager.sh" cleanup 2>/dev/null || true
            fi
        fi
        
        # Actualizar dashboard si está en modo interactivo
        if [[ "${MONITOR_MODE:-}" == "dashboard" ]]; then
            show_dashboard
        fi
        
        sleep "$MONITOR_INTERVAL"
    done
}

# Generar reporte
generate_report() {
    local report_file="$BASE_DIR/state/monitor-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Reporte del Monitor de Tareas

**Fecha**: $(date)
**Monitor PID**: $MONITOR_PID

## Resumen Ejecutivo

$(sqlite3 "$BASE_DIR/state/progress.db" -markdown << 'SQL'
SELECT 
    status as Estado,
    COUNT(*) as Cantidad,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM tasks), 1) || '%' as Porcentaje
FROM tasks
GROUP BY status
ORDER BY COUNT(*) DESC;
SQL
)

## Tareas por Fase

$(sqlite3 "$BASE_DIR/state/progress.db" -markdown << 'SQL'
SELECT 
    phase as Fase,
    COUNT(*) as Total,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as Completadas,
    SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) as EnProgreso,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as Fallidas
FROM tasks
GROUP BY phase
ORDER BY phase;
SQL
)

## Historial de Ejecuciones

$(sqlite3 "$BASE_DIR/state/progress.db" -markdown << 'SQL'
SELECT 
    task_id as Tarea,
    model as Modelo,
    task_type as Tipo,
    status as Estado,
    strftime('%Y-%m-%d %H:%M', run_date) as Fecha
FROM task_history
ORDER BY run_date DESC
LIMIT 20;
SQL
)

## Tareas Fallidas

$(sqlite3 "$BASE_DIR/state/progress.db" -markdown << 'SQL'
SELECT 
    id as ID,
    name as Nombre,
    error_log as Error,
    strftime('%Y-%m-%d %H:%M', completed_at) as Fecha
FROM tasks
WHERE status = 'failed'
ORDER BY completed_at DESC;
SQL
)

---
Reporte generado automáticamente por task-monitor.sh
EOF
    
    monitor_log "SUCCESS" "✅ Reporte generado: $report_file"
    echo "$report_file"
}

# Cleanup al salir
cleanup() {
    monitor_log "INFO" "🛑 Deteniendo monitor..."
    monitor_log "SUCCESS" "Monitor finalizado después de $SECONDS segundos"
}

trap cleanup EXIT INT TERM

# Procesar argumentos
case "${1:-}" in
    start)
        continuous_monitor
        ;;
    dashboard)
        MONITOR_MODE="dashboard"
        continuous_monitor
        ;;
    check)
        detect_stalled_tasks
        check_capacity
        ;;
    report)
        generate_report
        ;;
    capacity)
        check_capacity
        exit $?
        ;;
    *)
        cat << EOF
Uso: $0 <comando>

Comandos:
    start       Iniciar monitoreo continuo (modo daemon)
    dashboard   Iniciar con dashboard visual
    check       Verificación única de tareas
    report      Generar reporte de estado
    capacity    Verificar capacidad disponible

Variables de entorno:
    MONITOR_INTERVAL        Segundos entre chequeos (default: 10)
    MAX_CONCURRENT_TASKS    Máximo de tareas concurrentes (default: 3)
    TASK_TIMEOUT           Timeout en segundos (default: 3600)

Ejemplo:
    MONITOR_INTERVAL=5 $0 dashboard

EOF
        exit 1
        ;;
esac