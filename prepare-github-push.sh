#!/bin/bash
# prepare-github-push.sh - Prepara el repositorio para subir a GitHub

echo "🚀 Preparando repositorio para GitHub"
echo "===================================="
echo ""

# Remover referencias específicas a Avicloud que quedan
echo "🔧 Limpiando referencias específicas..."

# Renombrar el auto-discovery original si existe
if [[ -f "core/auto-discovery.sh" ]]; then
    mv core/auto-discovery.sh core/auto-discovery-avicloud.sh.example
    echo "  ✅ auto-discovery.sh → auto-discovery-avicloud.sh.example"
fi

# Hacer el universal el principal
if [[ -f "core/auto-discovery-universal.sh" ]]; then
    cp core/auto-discovery-universal.sh core/auto-discovery.sh
    echo "  ✅ auto-discovery-universal.sh → auto-discovery.sh"
fi

# Limpiar herramientas específicas de Avicloud
if [[ -d "tools/avicloud" ]]; then
    mkdir -p examples/avicloud-tools
    mv tools/avicloud/* examples/avicloud-tools/ 2>/dev/null || true
    rmdir tools/avicloud
    echo "  ✅ Herramientas Avicloud movidas a examples/"
fi

# Crear un proyecto de ejemplo
mkdir -p examples/sample-project
cat > examples/sample-project/README.md << 'EOF'
# Proyecto de Ejemplo

Este es un proyecto de ejemplo para demostrar cómo el Sistema de Desarrollo Desatendido
se adapta a diferentes tipos de proyectos.

## Uso

1. Clonar el sistema en la raíz de tu proyecto
2. Ejecutar `./bootstrap.sh`
3. Ejecutar `./core/auto-discovery.sh`
4. El sistema se adaptará automáticamente
EOF

# Limpiar la configuración específica actual
if [[ -f "state/project-config.sh" ]]; then
    mv state/project-config.sh state/project-config.sh.example
    echo "  ✅ Configuración movida a ejemplo"
fi

# Actualizar bootstrap para ser universal
sed -i 's/Avicloud Display/tu proyecto/g' bootstrap.sh 2>/dev/null || true
sed -i 's/Avicloud/proyecto/g' verify-bootstrap.sh 2>/dev/null || true

echo ""
echo "📝 Creando documentación adicional..."

# Crear guía de inicio rápido
cat > QUICKSTART.md << 'EOF'
# 🚀 Inicio Rápido - Sistema de Desarrollo Desatendido

## 1. Instalación

```bash
# Clonar en tu proyecto
git clone https://github.com/ariverosh/Desarrollo-Desatendido-v2.git

# Entrar al directorio
cd Desarrollo-Desatendido-v2

# Ejecutar bootstrap
./bootstrap.sh
```

## 2. Auto-Discovery

```bash
# Descubrir la estructura de tu proyecto
./core/auto-discovery.sh
```

## 3. Verificación

```bash
# Verificar que todo esté correcto
./verify-bootstrap.sh
```

## 4. Comenzar a Usar

El sistema ahora conoce tu proyecto y puede:
- Ejecutar tareas de desarrollo
- Mantener documentación actualizada
- Ejecutar tests automáticamente
- Coordinar cambios en múltiples repositorios
- Y mucho más...
EOF

echo "  ✅ QUICKSTART.md creado"

# Estado final
echo ""
echo "✅ Repositorio preparado para GitHub"
echo ""
echo "📋 Próximos pasos:"
echo "1. Revisar y hacer commit de los cambios:"
echo "   git add -A"
echo "   git commit -m 'feat: Convertir a sistema universal'"
echo ""
echo "2. Crear repositorio en GitHub:"
echo "   - Nombre: Desarrollo-Desatendido-v2"
echo "   - Descripción: Sistema Universal de Desarrollo Desatendido con IA"
echo "   - Tipo: Público o Privado (tu elección)"
echo ""
echo "3. Conectar y subir:"
echo "   git remote add origin https://github.com/ariverosh/Desarrollo-Desatendido-v2.git"
echo "   git branch -M main"
echo "   git push -u origin main"