#!/bin/bash
# test-locks.sh - Prueba del sistema de locks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Probando sistema de locks..."
echo ""

# Test 1: Adquirir lock simple
echo "Test 1: Adquirir y liberar lock"
"$SCRIPT_DIR/lock-manager.sh" acquire test-task-1 "/js/test/file1.js"
sleep 2
"$SCRIPT_DIR/show-locks.sh"
"$SCRIPT_DIR/lock-manager.sh" release test-task-1
echo ""

# Test 2: Conflicto de locks
echo "Test 2: Probar conflicto de locks"
"$SCRIPT_DIR/lock-manager.sh" acquire test-task-2 "/js/test/file2.js" &
PID1=$!
sleep 1
echo "Intentando adquirir el mismo archivo desde otra tarea..."
"$SCRIPT_DIR/lock-manager.sh" acquire test-task-3 "/js/test/file2.js" || echo "✅ Conflicto detectado correctamente"
wait $PID1
"$SCRIPT_DIR/lock-manager.sh" release test-task-2
echo ""

# Test 3: Múltiples archivos
echo "Test 3: Lock con múltiples archivos"
"$SCRIPT_DIR/lock-manager.sh" acquire test-task-4 "/js/test/file3.js" "/js/test/file4.js" "/js/test/file5.js"
"$SCRIPT_DIR/lock-manager.sh" check "/js/test/file3.js" "/js/test/file6.js"
"$SCRIPT_DIR/lock-manager.sh" release test-task-4
echo ""

echo "✅ Pruebas completadas"