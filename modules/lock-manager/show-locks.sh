#!/bin/bash
# show-locks.sh - Visualizador de locks activos con formato mejorado

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCKS_DIR="$BASE_DIR/.locks"
LOCKS_DB="$BASE_DIR/state/locks.db"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║             🔒 SISTEMA DE LOCKS - ESTADO ACTUAL            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Función para calcular tiempo transcurrido
calculate_age() {
    local CREATED=$1
    local CREATED_EPOCH=$(date -d "$CREATED" +%s 2>/dev/null || echo 0)
    local NOW_EPOCH=$(date +%s)
    local AGE=$((NOW_EPOCH - CREATED_EPOCH))
    
    if [[ $AGE -lt 60 ]]; then
        echo "${AGE}s"
    elif [[ $AGE -lt 3600 ]]; then
        echo "$((AGE / 60))m $((AGE % 60))s"
    else
        echo "$((AGE / 3600))h $((AGE % 3600 / 60))m"
    fi
}

# Verificar locks activos
ACTIVE_COUNT=0
TOTAL_FILES=0

echo -e "${YELLOW}📊 Locks Activos:${NC}"
echo "─────────────────────────────────────────────────────────────"

for lock_file in "$LOCKS_DIR"/*.lock; do
    [[ -f "$lock_file" ]] || continue
    
    # Verificar si el lock está vivo
    if "$SCRIPT_DIR/lock-manager.sh" is_lock_alive "$lock_file" 2>/dev/null; then
        TASK_ID=$(basename "$lock_file" .lock)
        
        # Extraer información del lock
        if [[ -f "$lock_file" ]]; then
            PID=$(jq -r '.pid // "Unknown"' "$lock_file" 2>/dev/null)
            CREATED=$(jq -r '.created // "Unknown"' "$lock_file" 2>/dev/null)
            HEARTBEAT=$(jq -r '.heartbeat // "Unknown"' "$lock_file" 2>/dev/null)
            FILES=($(jq -r '.files[]? // empty' "$lock_file" 2>/dev/null))
            FILE_COUNT=${#FILES[@]}
            
            AGE=$(calculate_age "$CREATED")
            
            ((ACTIVE_COUNT++))
            ((TOTAL_FILES += FILE_COUNT))
            
            echo -e "${GREEN}✓${NC} Tarea: ${BLUE}$TASK_ID${NC}"
            echo "  ├─ PID: $PID"
            echo "  ├─ Edad: $AGE"
            echo "  ├─ Archivos bloqueados: $FILE_COUNT"
            
            if [[ $FILE_COUNT -gt 0 && $FILE_COUNT -le 5 ]]; then
                for file in "${FILES[@]}"; do
                    echo "  │  └─ $file"
                done
            elif [[ $FILE_COUNT -gt 5 ]]; then
                echo "  │  └─ (mostrando primeros 5 de $FILE_COUNT)"
                for i in {0..4}; do
                    echo "  │     └─ ${FILES[$i]}"
                done
            fi
            
            echo "  └─ Último heartbeat: $(calculate_age "$HEARTBEAT") atrás"
            echo ""
        fi
    fi
done

if [[ $ACTIVE_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✨ No hay locks activos${NC}"
    echo ""
fi

# Mostrar estadísticas de la base de datos
echo -e "${YELLOW}📈 Estadísticas del Sistema:${NC}"
echo "─────────────────────────────────────────────────────────────"

# Total de locks en las últimas 24 horas
LOCKS_24H=$(sqlite3 "$LOCKS_DB" "SELECT COUNT(*) FROM lock_history WHERE timestamp > datetime('now', '-1 day') AND action = 'acquired';" 2>/dev/null || echo 0)

# Conflictos en las últimas 24 horas
CONFLICTS_24H=$(sqlite3 "$LOCKS_DB" "SELECT COUNT(*) FROM lock_history WHERE timestamp > datetime('now', '-1 day') AND action = 'conflict';" 2>/dev/null || echo 0)

# Locks expirados en las últimas 24 horas
EXPIRED_24H=$(sqlite3 "$LOCKS_DB" "SELECT COUNT(*) FROM lock_history WHERE timestamp > datetime('now', '-1 day') AND action = 'expired';" 2>/dev/null || echo 0)

echo "  Últimas 24 horas:"
echo "  ├─ Locks adquiridos: $LOCKS_24H"
echo "  ├─ Conflictos: $CONFLICTS_24H"
echo "  └─ Locks expirados: $EXPIRED_24H"
echo ""

# Mostrar conflictos recientes si los hay
if [[ $CONFLICTS_24H -gt 0 ]]; then
    echo -e "${RED}⚠️  Conflictos Recientes:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    sqlite3 -column "$LOCKS_DB" << EOF
SELECT 
    strftime('%H:%M:%S', timestamp) as hora,
    task_id as tarea,
    substr(details, 1, 50) || '...' as detalles
FROM lock_history 
WHERE action = 'conflict' 
  AND timestamp > datetime('now', '-1 hour')
ORDER BY timestamp DESC
LIMIT 5;
EOF
    echo ""
fi

# Resumen final
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                          RESUMEN                           ║${NC}"
echo -e "${BLUE}╟────────────────────────────────────────────────────────────╢${NC}"
printf "${BLUE}║${NC} %-30s: ${GREEN}%-27d${NC} ${BLUE}║${NC}\n" "Locks activos" "$ACTIVE_COUNT"
printf "${BLUE}║${NC} %-30s: ${YELLOW}%-27d${NC} ${BLUE}║${NC}\n" "Archivos bloqueados" "$TOTAL_FILES"
printf "${BLUE}║${NC} %-30s: %-27s ${BLUE}║${NC}\n" "Última actualización" "$(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"