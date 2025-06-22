#!/bin/bash
# start-autonomous.sh - Inicia el Sistema Autónomo v2
# Arranca todos los componentes necesarios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Cargar utilidades
source "$SCRIPT_DIR/common/utils.sh"

# PID file para el sistema
PID_FILE="$SCRIPT_DIR/.autonomous.pid"

# Verificar que no esté ya ejecutándose
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if ps -p "$OLD_PID" > /dev/null 2>&1; then
        error_with_solution \
            "El sistema ya está en ejecución (PID: $OLD_PID)" \
            "Ejecutar ./stop-autonomous.sh primero"
    else
        log "WARN" "PID file encontrado pero proceso no existe, limpiando..."
        rm -f "$PID_FILE"
    fi
fi

log "INFO" "🚀 Iniciando Sistema Autónomo v2..."

# Verificar bootstrap
if [[ ! -f "state/progress.db" ]]; then
    error_with_solution \
        "Sistema no inicializado" \
        "Ejecutar ./bootstrap.sh primero"
fi

# Verificar configuración del proyecto
if [[ ! -f "state/project-config.sh" ]]; then
    log "WARN" "No se encontró configuración del proyecto"
    log "INFO" "Ejecutando auto-discovery..."
    ./core/auto-discovery.sh
fi

# Limpiar logs antiguos (mantener últimos 10)
log "INFO" "📄 Limpiando logs antiguos..."
find logs/ -name "*.log" -type f | sort -r | tail -n +11 | xargs -r rm -f

# Iniciar monitor en background
log "INFO" "👀 Iniciando monitor de tareas..."
./core/task-monitor.sh start > logs/monitor.log 2>&1 &
MONITOR_PID=$!
log "SUCCESS" "Monitor iniciado (PID: $MONITOR_PID)"

# Esperar a que el monitor esté listo
sleep 2

# Verificar capacidad
if ! ./core/task-monitor.sh capacity > /dev/null 2>&1; then
    log "WARN" "Sistema al máximo de capacidad"
fi

# Iniciar orquestador
log "INFO" "🎯 Iniciando orquestador principal..."
./core/orchestrator-v2.sh --continuous > logs/orchestrator.log 2>&1 &
ORCHESTRATOR_PID=$!
log "SUCCESS" "Orquestador iniciado (PID: $ORCHESTRATOR_PID)"

# Guardar PIDs
echo "$ORCHESTRATOR_PID" > "$PID_FILE"
echo "$MONITOR_PID" >> "$PID_FILE"

# Mostrar estado
log "SUCCESS" "✅ Sistema Autónomo v2 iniciado correctamente"
echo ""
echo "📊 Componentes activos:"
echo "  - Orquestador: PID $ORCHESTRATOR_PID"
echo "  - Monitor: PID $MONITOR_PID"
echo ""
echo "📁 Logs en:"
echo "  - logs/orchestrator.log"
echo "  - logs/monitor.log"
echo ""
echo "🛠️ Comandos útiles:"
echo "  - Ver dashboard: ./core/task-monitor.sh dashboard"
echo "  - Ver logs: tail -f logs/orchestrator.log"
echo "  - Detener: ./stop-autonomous.sh"
echo "  - Estado: ./status-autonomous.sh"
echo ""

# Crear script de status
cat > status-autonomous.sh << 'EOF'
#!/bin/bash
# status-autonomous.sh - Muestra el estado del sistema

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/utils.sh"

PID_FILE="$SCRIPT_DIR/.autonomous.pid"

echo "📊 Estado del Sistema Autónomo v2"
echo "================================="
echo ""

if [[ -f "$PID_FILE" ]]; then
    ORCHESTRATOR_PID=$(head -1 "$PID_FILE")
    MONITOR_PID=$(tail -1 "$PID_FILE")
    
    echo "🎯 Orquestador:"
    if ps -p "$ORCHESTRATOR_PID" > /dev/null 2>&1; then
        echo "  ✅ Activo (PID: $ORCHESTRATOR_PID)"
    else
        echo "  ❌ Inactivo"
    fi
    
    echo ""
    echo "👀 Monitor:"
    if ps -p "$MONITOR_PID" > /dev/null 2>&1; then
        echo "  ✅ Activo (PID: $MONITOR_PID)"
    else
        echo "  ❌ Inactivo"
    fi
else
    echo "❌ Sistema no está en ejecución"
fi

echo ""
echo "📈 Tareas:"
sqlite3 "$SCRIPT_DIR/state/progress.db" -box << 'SQL'
SELECT 
    status as Estado,
    COUNT(*) as Cantidad
FROM tasks
GROUP BY status;
SQL

echo ""
echo "🔒 Locks activos:"
sqlite3 "$SCRIPT_DIR/state/locks.db" -box << 'SQL'
SELECT COUNT(*) as Total FROM active_locks;
SQL
EOF

chmod +x status-autonomous.sh

# Crear script de stop
cat > stop-autonomous.sh << 'EOF'
#!/bin/bash
# stop-autonomous.sh - Detiene el Sistema Autónomo v2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common/utils.sh"

PID_FILE="$SCRIPT_DIR/.autonomous.pid"

log "INFO" "🛑 Deteniendo Sistema Autónomo v2..."

if [[ -f "$PID_FILE" ]]; then
    ORCHESTRATOR_PID=$(head -1 "$PID_FILE")
    MONITOR_PID=$(tail -1 "$PID_FILE")
    
    # Detener orquestador
    if ps -p "$ORCHESTRATOR_PID" > /dev/null 2>&1; then
        log "INFO" "Deteniendo orquestador (PID: $ORCHESTRATOR_PID)..."
        kill "$ORCHESTRATOR_PID" 2>/dev/null || true
        
        # Esperar hasta 5 segundos
        for i in {1..5}; do
            if ! ps -p "$ORCHESTRATOR_PID" > /dev/null 2>&1; then
                break
            fi
            sleep 1
        done
        
        # Forzar si es necesario
        if ps -p "$ORCHESTRATOR_PID" > /dev/null 2>&1; then
            kill -9 "$ORCHESTRATOR_PID" 2>/dev/null || true
        fi
    fi
    
    # Detener monitor
    if ps -p "$MONITOR_PID" > /dev/null 2>&1; then
        log "INFO" "Deteniendo monitor (PID: $MONITOR_PID)..."
        kill "$MONITOR_PID" 2>/dev/null || true
        sleep 1
        kill -9 "$MONITOR_PID" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log "SUCCESS" "✅ Sistema detenido"
else
    log "WARN" "El sistema no estaba en ejecución"
fi

# Limpiar locks huérfanos
if [[ -x "$SCRIPT_DIR/modules/lock-manager/lock-manager.sh" ]]; then
    log "INFO" "Limpiando locks..."
    "$SCRIPT_DIR/modules/lock-manager/lock-manager.sh" cleanup 2>/dev/null || true
fi
EOF

chmod +x stop-autonomous.sh