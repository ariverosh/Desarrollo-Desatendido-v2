#!/bin/bash
# bootstrap.sh - Inicializa el sistema autónomo v2
# Sistema de desarrollo desatendido para Avicloud Display

set -euo pipefail

echo "🚀 Iniciando Bootstrap del Sistema Autónomo v2..."
echo "================================================"

# Auto-detectar ubicación
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "📍 Ubicación del sistema: $SCRIPT_DIR"

# Crear estructura completa de directorios
echo "📁 Creando estructura de directorios..."
mkdir -p {core,modules/{lock-manager,doc-guardian,test-runner,dependency-tracker,git-sync,file-inspector,dashboard},contexts/{templates,active},state/{test-results,documentation/modules,snapshots},logs/{orchestrator,tasks,errors},tools/test-utilities,.locks}

# Crear archivos base necesarios
echo "📄 Creando archivos base..."
touch .locks/.gitkeep
echo "{}" > state/dependencies.json
echo "# Progreso del Sistema Autónomo v2" > state/progress.md
echo "# Logs del Orquestador" > logs/orchestrator/activity.log

# Inicializar base de datos de progreso
echo "🗄️ Inicializando base de datos de progreso..."
sqlite3 state/progress.db << 'EOF'
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

CREATE TABLE IF NOT EXISTS milestones (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    achieved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tasks_completed INTEGER DEFAULT 0,
    description TEXT
);

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

-- Insertar tareas iniciales de la Fase 0
INSERT INTO tasks (id, phase, name) VALUES
    ('0.1', 'bootstrap', 'Crear Estructura y Bootstrap Script'),
    ('0.2', 'bootstrap', 'Sistema de Locks Básico'),
    ('0.3', 'bootstrap', 'Auto-Discovery del Proyecto'),
    ('0.4', 'bootstrap', 'Migrar Herramientas Críticas'),
    ('0.5', 'bootstrap', 'Verificación del Bootstrap');

-- Marcar tarea 0.1 como en progreso (este script)
UPDATE tasks SET status = 'in_progress', started_at = datetime('now') WHERE id = '0.1';
EOF

# Inicializar base de datos de locks
echo "🔒 Inicializando base de datos de locks..."
sqlite3 state/locks.db << 'EOF'
CREATE TABLE IF NOT EXISTS active_locks (
    task_id TEXT PRIMARY KEY,
    files TEXT NOT NULL,
    purpose TEXT,
    pid INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lock_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('acquired', 'released', 'expired', 'conflict')),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);
EOF

# Crear script de verificación
echo "✔️ Creando script de verificación..."
cat > verify-bootstrap.sh << 'VERIFY_EOF'
#!/bin/bash
# verify-bootstrap.sh - Verifica la instalación del sistema

echo "🔍 Verificando instalación del Sistema Autónomo v2..."

ERRORS=0

# Verificar estructura de directorios
echo -n "📁 Verificando directorios... "
for dir in core modules contexts state logs tools .locks; do
    if [[ ! -d "$dir" ]]; then
        echo -e "\n   ❌ Falta directorio: $dir"
        ((ERRORS++))
    fi
done
[[ $ERRORS -eq 0 ]] && echo "✅"

# Verificar bases de datos
echo -n "🗄️ Verificando bases de datos... "
for db in state/progress.db state/locks.db; do
    if [[ ! -f "$db" ]]; then
        echo -e "\n   ❌ Falta base de datos: $db"
        ((ERRORS++))
    fi
done
[[ $ERRORS -eq 0 ]] && echo "✅"

# Verificar archivos de configuración
echo -n "📄 Verificando archivos base... "
for file in state/dependencies.json state/progress.md; do
    if [[ ! -f "$file" ]]; then
        echo -e "\n   ❌ Falta archivo: $file"
        ((ERRORS++))
    fi
done
[[ $ERRORS -eq 0 ]] && echo "✅"

# Resultado final
echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "✅ Bootstrap verificado exitosamente!"
    echo "   El sistema está listo para usar."
else
    echo "❌ Se encontraron $ERRORS errores durante la verificación."
    echo "   Por favor, ejecute ./bootstrap.sh nuevamente."
    exit 1
fi
VERIFY_EOF

chmod +x verify-bootstrap.sh

# Crear README del sistema
echo "📚 Creando documentación inicial..."
cat > README.md << 'README_EOF'
# Sistema Autónomo de Desarrollo Desatendido v2

## 🚀 Inicio Rápido

```bash
# Ejecutar bootstrap (solo primera vez)
./bootstrap.sh

# Verificar instalación
./verify-bootstrap.sh

# Iniciar sistema autónomo
./start-autonomous.sh
```

## 📁 Estructura

- `core/` - Núcleo del sistema de orquestación
- `modules/` - Módulos especializados (locks, docs, tests, etc.)
- `contexts/` - Plantillas y contextos activos para tareas
- `state/` - Estado persistente (DBs, docs, snapshots)
- `logs/` - Logs consolidados del sistema
- `tools/` - Herramientas migradas del sistema v1
- `.locks/` - Archivos de lock para concurrencia

## 🔧 Características

- ✅ 100% Portable (rutas relativas)
- ✅ Multi-instancia con prevención de conflictos
- ✅ Documentación auto-mantenida
- ✅ Selección inteligente de modelo Claude
- ✅ Auto-recuperación de interrupciones
- ✅ Dashboard visual de progreso

## 📊 Estado del Sistema

Ver `MASTER_PLAN_AUTONOMOUS_V2.md` para el progreso detallado.
README_EOF

# Marcar tarea 0.1 como completada
echo "✅ Actualizando progreso..."
sqlite3 state/progress.db "UPDATE tasks SET status = 'completed', completed_at = datetime('now') WHERE id = '0.1'"

# Mensaje final
echo ""
echo "✅ Bootstrap inicial completado!"
echo "================================================"
echo "📁 Sistema creado en: $SCRIPT_DIR"
echo "📊 Bases de datos inicializadas"
echo "📝 Estructura de directorios creada"
echo ""
echo "Próximos pasos:"
echo "1. Ejecutar: ./verify-bootstrap.sh"
echo "2. Continuar con tareas 0.2 - 0.5"
echo ""
echo "Para ver el progreso:"
echo "sqlite3 state/progress.db 'SELECT * FROM tasks WHERE phase=\"bootstrap\"'"