#!/bin/bash
# bootstrap-v2.sh - Inicializa el sistema siguiendo las Reglas de Oro
# Sistema de desarrollo desatendido universal

set -euo pipefail

# Detectar ubicación del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="$SCRIPT_DIR/common"

# Crear directorio common si no existe (necesario para el primer bootstrap)
[[ -d "$COMMON_DIR" ]] || mkdir -p "$COMMON_DIR"

# Si utils.sh no existe, crear una versión mínima para bootstrap
if [[ ! -f "$COMMON_DIR/utils.sh" ]]; then
    cat > "$COMMON_DIR/utils.sh" << 'UTILS_EOF'
#!/bin/bash
set -euo pipefail
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_NC='\033[0m'

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$1] ${@:2}"
}

error_with_solution() {
    echo -e "${COLOR_RED}ERROR: $1${COLOR_NC}" >&2
    echo -e "${COLOR_YELLOW}Solución: $2${COLOR_NC}" >&2
    exit 1
}

require_command() {
    command -v "$1" &>/dev/null || error_with_solution \
        "Comando '$1' no encontrado" \
        "${2:-Instalar con el gestor de paquetes de tu sistema}"
}
UTILS_EOF
fi

# Cargar utilidades comunes
source "$COMMON_DIR/utils.sh"

# Cambiar al directorio del script
cd "$SCRIPT_DIR"

log "INFO" "🚀 Iniciando Bootstrap del Sistema Autónomo v2..."
log "INFO" "================================================"
log "INFO" "📍 Ubicación del sistema: $SCRIPT_DIR"

# Verificar dependencias críticas
log "INFO" "🔍 Verificando dependencias..."
require_command "sqlite3" "Instalar sqlite3: apt-get install sqlite3 (Ubuntu) o brew install sqlite (macOS)"
require_command "git" "Instalar git desde https://git-scm.com/"
require_command "curl" "Instalar curl: apt-get install curl"

# Definir estructura de directorios
DIRECTORIES=(
    "common"
    "core"
    "modules/lock-manager"
    "modules/doc-guardian"
    "modules/test-runner"
    "modules/dependency-tracker"
    "modules/git-sync"
    "modules/file-inspector"
    "modules/dashboard"
    "contexts/templates"
    "contexts/active"
    "state/test-results"
    "state/documentation/modules"
    "state/snapshots"
    "logs/orchestrator"
    "logs/tasks"
    "logs/errors"
    "tools/test-utilities"
    ".locks"
)

# Crear directorios
log "INFO" "📁 Creando estructura de directorios..."
for dir in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "INFO" "  ✅ Creado: $dir"
    else
        log "INFO" "  ↩️  Ya existe: $dir"
    fi
done

# Crear archivos .gitkeep para mantener directorios vacíos
log "INFO" "📄 Creando archivos .gitkeep..."
GITKEEP_DIRS=(".locks" "logs/orchestrator" "logs/tasks" "logs/errors" 
              "contexts/active" "state/test-results" "state/snapshots")

for dir in "${GITKEEP_DIRS[@]}"; do
    gitkeep_file="$dir/.gitkeep"
    if [[ ! -f "$gitkeep_file" ]]; then
        touch "$gitkeep_file"
        log "INFO" "  ✅ Creado: $gitkeep_file"
    fi
done

# Inicializar archivos de estado
log "INFO" "📄 Inicializando archivos de estado..."

# dependencies.json
if [[ ! -f "state/dependencies.json" ]]; then
    echo "{}" > state/dependencies.json
    log "INFO" "  ✅ Creado: state/dependencies.json"
else
    log "INFO" "  ↩️  Ya existe: state/dependencies.json"
fi

# progress.md
if [[ ! -f "state/progress.md" ]]; then
    cat > state/progress.md << 'PROGRESS_EOF'
# Progreso del Sistema Autónomo v2

## Estado General
- **Inicio**: $(date)
- **Sistema**: Desarrollo Desatendido Universal
- **Versión**: 2.0

## Fases Completadas
- [x] Bootstrap inicial

## Próximas Fases
- [ ] Sistema de Orquestación
- [ ] Documentación Viva
- [ ] Testing Inteligente
- [ ] Git Multi-Repo
- [ ] Dashboard y Monitoreo
PROGRESS_EOF
    log "INFO" "  ✅ Creado: state/progress.md"
fi

# Inicializar base de datos de progreso
log "INFO" "🗄️ Inicializando base de datos de progreso..."

if [[ ! -f "state/progress.db" ]]; then
    sqlite3 state/progress.db << 'SQL_EOF'
-- Tabla de tareas
CREATE TABLE IF NOT EXISTS tasks (
    id TEXT PRIMARY KEY,
    phase TEXT NOT NULL,
    name TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending', 'in_progress', 'completed', 'failed')),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_log TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de hitos
CREATE TABLE IF NOT EXISTS milestones (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    achieved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tasks_completed INTEGER DEFAULT 0,
    description TEXT
);

-- Tabla de historial de tareas
CREATE TABLE IF NOT EXISTS task_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    model TEXT NOT NULL,
    task_type TEXT,
    duration INTEGER,
    status TEXT,
    run_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_id) REFERENCES tasks(id)
);

-- Insertar tarea de bootstrap como completada
INSERT INTO tasks (id, phase, name, status, started_at, completed_at) 
VALUES ('bootstrap', 'init', 'Bootstrap del Sistema', 'completed', datetime('now'), datetime('now'));

-- Insertar hito
INSERT INTO milestones (id, name, tasks_completed, description)
VALUES ('bootstrap-complete', 'Bootstrap Completado', 1, 'Sistema inicializado correctamente');
SQL_EOF
    log "INFO" "  ✅ Base de datos de progreso creada"
else
    log "INFO" "  ↩️  Base de datos ya existe"
fi

# Inicializar base de datos de locks
log "INFO" "🔒 Inicializando base de datos de locks..."

if [[ ! -f "state/locks.db" ]]; then
    sqlite3 state/locks.db << 'LOCKS_SQL_EOF'
-- Tabla de locks activos
CREATE TABLE IF NOT EXISTS active_locks (
    task_id TEXT PRIMARY KEY,
    files TEXT NOT NULL,
    purpose TEXT,
    pid INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Tabla de historial de locks
CREATE TABLE IF NOT EXISTS lock_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('acquired', 'released', 'expired', 'conflict')),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);

-- Índices para mejor rendimiento
CREATE INDEX idx_active_locks_heartbeat ON active_locks(heartbeat);
CREATE INDEX idx_lock_history_task ON lock_history(task_id);
CREATE INDEX idx_lock_history_timestamp ON lock_history(timestamp);
LOCKS_SQL_EOF
    log "INFO" "  ✅ Base de datos de locks creada"
else
    log "INFO" "  ↩️  Base de datos de locks ya existe"
fi

# Crear script de verificación
log "INFO" "✔️ Creando script de verificación..."

if [[ ! -f "verify-bootstrap.sh" ]] || [[ "$0" == "./bootstrap-v2.sh" ]]; then
    cat > verify-bootstrap.sh << 'VERIFY_EOF'
#!/bin/bash
# verify-bootstrap.sh - Verifica la instalación del sistema

set -euo pipefail

# Cargar utilidades
source "$(dirname "${BASH_SOURCE[0]}")/common/utils.sh"

log "INFO" "🔍 Verificando instalación del Sistema Autónomo v2..."

ERRORS=0

# Verificar directorios críticos
log "INFO" "📁 Verificando directorios..."
CRITICAL_DIRS=("core" "modules" "contexts" "state" "logs" "tools" ".locks" "common")

for dir in "${CRITICAL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir - FALTA"
        ((ERRORS++))
    fi
done

# Verificar bases de datos
log "INFO" "🗄️ Verificando bases de datos..."
DBS=("state/progress.db" "state/locks.db")

for db in "${DBS[@]}"; do
    if [[ -f "$db" ]]; then
        # Verificar integridad
        if sqlite3 "$db" "PRAGMA integrity_check;" &>/dev/null; then
            echo "  ✅ $db - OK"
        else
            echo "  ❌ $db - CORRUPTA"
            ((ERRORS++))
        fi
    else
        echo "  ❌ $db - FALTA"
        ((ERRORS++))
    fi
done

# Verificar archivos críticos
log "INFO" "📄 Verificando archivos críticos..."
FILES=("state/dependencies.json" "state/progress.md" "common/utils.sh")

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file - FALTA"
        ((ERRORS++))
    fi
done

# Resultado final
echo ""
if [[ $ERRORS -eq 0 ]]; then
    log "INFO" "✅ Bootstrap verificado exitosamente!"
    log "INFO" "   El sistema está listo para usar."
    exit 0
else
    error_with_solution \
        "Se encontraron $ERRORS errores durante la verificación" \
        "Ejecutar ./bootstrap-v2.sh nuevamente"
fi
VERIFY_EOF
    chmod +x verify-bootstrap.sh
    log "INFO" "  ✅ Script de verificación creado"
fi

# Crear README si no existe
if [[ ! -f "README.md" ]]; then
    log "INFO" "📚 Creando documentación inicial..."
    # Copiar desde plantilla o crear básico
    echo "# Sistema de Desarrollo Desatendido v2" > README.md
    echo "" >> README.md
    echo "Sistema inicializado. Ver documentación completa en GOLDEN_RULES.md" >> README.md
fi

# Resumen final
log "INFO" ""
log "INFO" "✅ Bootstrap completado exitosamente!"
log "INFO" "================================================"
log "INFO" "📁 Sistema creado en: $SCRIPT_DIR"
log "INFO" "📊 Bases de datos inicializadas"
log "INFO" "📝 Estructura de directorios creada"
log "INFO" ""
log "INFO" "Próximos pasos:"
log "INFO" "1. Ejecutar: ./verify-bootstrap.sh"
log "INFO" "2. Ejecutar: ./core/auto-discovery.sh"
log "INFO" "3. Revisar: GOLDEN_RULES.md"
log "INFO" ""
log "INFO" "Para ver el progreso:"
log "INFO" "sqlite3 state/progress.db 'SELECT * FROM tasks'"