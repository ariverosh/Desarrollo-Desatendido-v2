#!/bin/bash
# create-github-repo.sh - Script para crear el repositorio en GitHub usando gh CLI

set -euo pipefail

echo "🚀 Script para crear repositorio en GitHub"
echo "========================================"
echo ""

# Verificar si gh está instalado
if ! command -v gh &>/dev/null; then
    echo "❌ GitHub CLI (gh) no está instalado"
    echo ""
    echo "Para instalar:"
    echo "  - Windows: winget install GitHub.cli"
    echo "  - macOS: brew install gh"
    echo "  - Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
    echo ""
    echo "Después de instalar, ejecuta: gh auth login"
    exit 1
fi

# Verificar autenticación
if ! gh auth status &>/dev/null; then
    echo "❌ No estás autenticado en GitHub CLI"
    echo ""
    echo "Ejecuta: gh auth login"
    echo "Y sigue las instrucciones"
    exit 1
fi

echo "✅ GitHub CLI detectado y autenticado"
echo ""

# Opciones del repositorio
REPO_NAME="Desarrollo-Desatendido-v2"
DESCRIPTION="Sistema Universal de Desarrollo Desatendido con IA - Orquestación inteligente de Claude para cualquier proyecto"
VISIBILITY="public"  # Cambiar a "private" si lo prefieres

echo "📋 Configuración del repositorio:"
echo "  Nombre: $REPO_NAME"
echo "  Descripción: $DESCRIPTION"
echo "  Visibilidad: $VISIBILITY"
echo ""

read -p "¿Crear repositorio con esta configuración? (s/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Ss]$ ]]; then
    # Crear repositorio
    echo "Creando repositorio..."
    
    if gh repo create "$REPO_NAME" \
        --description "$DESCRIPTION" \
        --$VISIBILITY \
        --source=. \
        --remote=origin \
        --push; then
        
        echo ""
        echo "✅ Repositorio creado exitosamente!"
        echo ""
        echo "URL: https://github.com/$(gh api user -q .login)/$REPO_NAME"
        echo ""
        
        # Configurar topics
        echo "Configurando topics..."
        gh repo edit --add-topic "automation"
        gh repo edit --add-topic "ai"
        gh repo edit --add-topic "claude"
        gh repo edit --add-topic "development-tools"
        gh repo edit --add-topic "universal"
        
        echo "✅ Topics agregados"
        echo ""
        echo "🎉 ¡Todo listo! Tu repositorio está en línea."
        
    else
        echo "❌ Error al crear el repositorio"
        echo ""
        echo "Posibles causas:"
        echo "1. El repositorio ya existe"
        echo "2. No tienes permisos"
        echo "3. Problema de conexión"
    fi
else
    echo "Operación cancelada"
fi