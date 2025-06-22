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
