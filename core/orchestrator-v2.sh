#!/bin/bash
# orchestrator-v2.sh - Orquestador Principal del Sistema Autónomo v2
# Núcleo central que coordina todas las operaciones

set -euo pipefail

# Configuración base
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar utilidades comunes
source "$BASE_DIR/common/utils.sh"

# Cargar configuración del proyecto
if [[ -f "$BASE_DIR/state/project-config.sh" ]]; then
    source "$BASE_DIR/state/project-config.sh"
else
    error_with_solution \
        "No se encontró configuración del proyecto" \
        "Ejecutar ./core/auto-discovery.sh primero"
fi

# Variables globales
ORCHESTRATOR_PID=$$
ORCHESTRATOR_ID="orch-$(date +%s)-$$"
STATE_DB="$BASE_DIR/state/progress.db"
LOCKS_DB="$BASE_DIR/state/locks.db"
LOG_FILE="$BASE_DIR/logs/orchestrator/orchestrator-$(date +%Y%m%d-%H%M%S).log"

# Asegurar que existe el directorio de logs
ensure_directory "$BASE_DIR/logs/orchestrator"

# Función de logging específica del orquestador
orch_log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    
    # Log a archivo
    echo "[$timestamp] [ORCH:$ORCHESTRATOR_ID] [$level] $message" >> "$LOG_FILE"
    
    # También a stdout con color
    case $level in
        ERROR)
            echo -e "${COLOR_RED}[ORCH] $message${COLOR_NC}"
            ;;
        WARN)
            echo -e "${COLOR_YELLOW}[ORCH] $message${COLOR_NC}"
            ;;
        INFO)
            echo -e "${COLOR_BLUE}[ORCH] $message${COLOR_NC}"
            ;;
        SUCCESS)
            echo -e "${COLOR_GREEN}[ORCH] $message${COLOR_NC}"
            ;;
        *)
            echo "[ORCH] $message"
            ;;
    esac
}

# Registrar inicio del orquestador
register_orchestrator_start() {
    orch_log "INFO" "🚀 Iniciando Orquestador v2.0"
    orch_log "INFO" "ID: $ORCHESTRATOR_ID"
    orch_log "INFO" "PID: $ORCHESTRATOR_PID"
    orch_log "INFO" "Proyecto: ${PROJECT_NAME:-Unknown}"
    
    # Registrar en base de datos
    sqlite3 "$STATE_DB" << EOF
INSERT INTO milestones (id, name, description)
VALUES ('orch-start-$ORCHESTRATOR_ID', 'Orquestador Iniciado', 'PID: $ORCHESTRATOR_PID');
EOF
}

# Verificar estado del sistema
check_system_health() {
    orch_log "INFO" "🔍 Verificando salud del sistema..."
    
    local issues=0
    
    # Verificar bases de datos
    if ! sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks" &>/dev/null; then
        orch_log "ERROR" "Base de datos de progreso corrupta"
        ((issues++))
    fi
    
    if ! sqlite3 "$LOCKS_DB" "SELECT COUNT(*) FROM active_locks" &>/dev/null; then
        orch_log "ERROR" "Base de datos de locks corrupta"
        ((issues++))
    fi
    
    # Verificar espacio en disco
    check_disk_space "$BASE_DIR" 500 || ((issues++))
    
    # Verificar lock manager
    if [[ ! -x "$BASE_DIR/modules/lock-manager/lock-manager.sh" ]]; then
        orch_log "ERROR" "Lock manager no encontrado o no ejecutable"
        ((issues++))
    fi
    
    if [[ $issues -eq 0 ]]; then
        orch_log "SUCCESS" "✅ Sistema saludable"
        return 0
    else
        error_with_solution \
            "Sistema con $issues problemas críticos" \
            "Revisar logs y ejecutar ./verify-bootstrap.sh"
    fi
}

# Obtener siguiente tarea pendiente
get_next_task() {
    local next_task=$(sqlite3 "$STATE_DB" << 'EOF'
SELECT id, phase, name 
FROM tasks 
WHERE status = 'pending' 
ORDER BY phase, id 
LIMIT 1;
EOF
    )
    
    echo "$next_task"
}

# Delegar tarea al modelo apropiado
delegate_task() {
    local task_id=$1
    local phase=$2
    local name=$3
    
    orch_log "INFO" "📋 Delegando tarea: $task_id - $name"
    
    # Determinar modelo óptimo según la fase y tipo de tarea
    local model="sonnet" # Por defecto
    
    case $phase in
        documentation)
            model="haiku"  # Tareas simples de documentación
            ;;
        orchestration|architecture)
            model="opus"   # Tareas complejas de diseño
            ;;
        testing|analysis)
            model="sonnet" # Balance entre capacidad y costo
            ;;
    esac
    
    orch_log "INFO" "Modelo seleccionado: Claude $model"
    
    # Verificar si hay locks disponibles para esta tarea
    local task_context_file="$BASE_DIR/contexts/active/task-$task_id.md"
    
    # Crear contexto para la tarea
    create_task_context "$task_id" "$phase" "$name" "$task_context_file"
    
    # Aquí es donde se invocaría a Claude con el contexto
    # Por ahora, simulamos la delegación
    orch_log "INFO" "Contexto creado en: $task_context_file"
    orch_log "WARN" "Delegación a Claude pendiente de implementación"
    
    # Marcar tarea como en progreso
    sqlite3 "$STATE_DB" "UPDATE tasks SET status = 'in_progress', started_at = datetime('now') WHERE id = '$task_id'"
    
    return 0
}

# Crear contexto mínimo para una tarea
create_task_context() {
    local task_id=$1
    local phase=$2
    local name=$3
    local output_file=$4
    
    orch_log "INFO" "Creando contexto para tarea $task_id"
    
    cat > "$output_file" << EOF
# Contexto de Tarea: $task_id

## Información de la Tarea
- **ID**: $task_id
- **Fase**: $phase
- **Nombre**: $name
- **Fecha**: $(date)
- **Orquestador**: $ORCHESTRATOR_ID

## Objetivo
$name

## Recursos Disponibles
- **Base del Sistema**: $BASE_DIR
- **Proyecto**: $PROJECT_ROOT
- **Tipo de Proyecto**: ${PROJECT_TYPES[0]:-Unknown}

## Reglas de Oro (OBLIGATORIAS)
$(head -20 "$BASE_DIR/GOLDEN_RULES.md" | tail -15)

## Archivos Relevantes
EOF

    # Agregar archivos relevantes según la tarea
    case $phase in
        orchestration)
            echo "- $BASE_DIR/core/*.sh" >> "$output_file"
            echo "- $BASE_DIR/modules/lock-manager/*.sh" >> "$output_file"
            ;;
        documentation)
            echo "- $BASE_DIR/*.md" >> "$output_file"
            echo "- $BASE_DIR/state/documentation/*.md" >> "$output_file"
            ;;
        testing)
            echo "- $TEST_ROOT/**/*.js" >> "$output_file"
            echo "- $BASE_DIR/modules/test-runner/*.sh" >> "$output_file"
            ;;
    esac
    
    # Agregar instrucciones específicas
    cat >> "$output_file" << EOF

## Instrucciones
1. Seguir estrictamente las Reglas de Oro
2. NO crear archivos duplicados - verificar existentes primero
3. Usar funciones de common/utils.sh cuando sea posible
4. Documentar cada decisión importante
5. Reportar progreso regularmente

## Criterios de Éxito
- Código funcional sin errores
- Tests pasando (si aplica)
- Documentación actualizada
- Sin violaciones a las Reglas de Oro

---
Contexto generado automáticamente por orchestrator-v2.sh
EOF
}

# Monitor de tareas en progreso
monitor_active_tasks() {
    orch_log "INFO" "👀 Monitoreando tareas activas..."
    
    local active_tasks=$(sqlite3 "$STATE_DB" "SELECT COUNT(*) FROM tasks WHERE status = 'in_progress'")
    
    if [[ $active_tasks -gt 0 ]]; then
        orch_log "INFO" "Tareas en progreso: $active_tasks"
        
        # Listar tareas activas
        sqlite3 "$STATE_DB" -header -column << EOF
SELECT id, name, 
       ROUND((julianday('now') - julianday(started_at)) * 24 * 60) as minutes_elapsed
FROM tasks 
WHERE status = 'in_progress';
EOF
    else
        orch_log "INFO" "No hay tareas activas"
    fi
}

# Cleanup al salir
cleanup_on_exit() {
    orch_log "INFO" "🛑 Deteniendo orquestador..."
    
    # Registrar fin
    sqlite3 "$STATE_DB" << EOF
INSERT INTO milestones (id, name, description)
VALUES ('orch-stop-$ORCHESTRATOR_ID', 'Orquestador Detenido', 'Duración: $SECONDS segundos');
EOF
    
    orch_log "SUCCESS" "Orquestador finalizado correctamente"
}

# Configurar trap
trap cleanup_on_exit EXIT INT TERM

# Función principal
main() {
    # Registrar inicio
    register_orchestrator_start
    
    # Verificar salud del sistema
    check_system_health
    
    # Bucle principal
    local cycles=0
    local max_cycles=${1:-1}  # Por defecto, solo un ciclo
    
    while [[ $cycles -lt $max_cycles ]] || [[ "$max_cycles" == "continuous" ]]; do
        ((cycles++))
        
        orch_log "INFO" "🔄 Ciclo $cycles iniciado"
        
        # Monitor de tareas activas
        monitor_active_tasks
        
        # Obtener siguiente tarea
        local next_task=$(get_next_task)
        
        if [[ -n "$next_task" ]]; then
            # Parsear información de la tarea
            IFS='|' read -r task_id phase name <<< "$next_task"
            
            # Delegar tarea
            delegate_task "$task_id" "$phase" "$name"
        else
            orch_log "INFO" "No hay tareas pendientes"
        fi
        
        # Esperar antes del siguiente ciclo
        if [[ "$max_cycles" == "continuous" ]] || [[ $cycles -lt $max_cycles ]]; then
            orch_log "INFO" "Esperando 30 segundos antes del siguiente ciclo..."
            sleep 30
        fi
    done
    
    orch_log "SUCCESS" "✅ Orquestador completó $cycles ciclos"
}

# Mostrar ayuda
show_help() {
    cat << EOF
Uso: $0 [opciones] [ciclos]

Opciones:
    -h, --help          Mostrar esta ayuda
    -c, --continuous    Ejecutar continuamente
    -m, --monitor       Solo monitorear, no delegar
    -t, --test          Modo de prueba (un ciclo)

Argumentos:
    ciclos              Número de ciclos a ejecutar (default: 1)
                       Usar 'continuous' para ejecución continua

Ejemplos:
    $0                  # Ejecutar un ciclo
    $0 5                # Ejecutar 5 ciclos
    $0 --continuous     # Ejecutar indefinidamente
    $0 --monitor        # Solo monitorear tareas

EOF
}

# Procesar argumentos
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -c|--continuous)
        main "continuous"
        ;;
    -m|--monitor)
        monitor_active_tasks
        exit 0
        ;;
    -t|--test)
        main 1
        ;;
    *)
        main "${1:-1}"
        ;;
esac