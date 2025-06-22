#!/bin/bash
# create-repo-with-api.sh - Crear repositorio usando GitHub API

set -euo pipefail

echo "🚀 Creando repositorio en GitHub via API"
echo "========================================"
echo ""

# Extraer token de los repositorios existentes
echo "🔍 Buscando token en configuración existente..."

# Buscar en los remotos de git
EXISTING_REMOTE=$(cd "/mnt/d/desarrollo/Avicloud Display" && git remote -v 2>/dev/null | grep push | grep github.com | head -1 || true)

if [[ -n "$EXISTING_REMOTE" ]]; then
    # Extraer token del URL
    if [[ "$EXISTING_REMOTE" =~ github_pat_[A-Za-z0-9_]+ ]]; then
        TOKEN="${BASH_REMATCH[0]}"
        echo "✅ Token encontrado"
    else
        echo "❌ No se pudo extraer el token del remoto"
        exit 1
    fi
else
    echo "❌ No se encontraron remotos con token"
    echo ""
    echo "Por favor, proporciona el token manualmente:"
    echo "export GITHUB_TOKEN=tu_token_aqui"
    exit 1
fi

# Configuración del repositorio
REPO_NAME="Desarrollo-Desatendido-v2"
DESCRIPTION="Sistema Universal de Desarrollo Desatendido con IA - Orquestación inteligente de Claude para cualquier proyecto"
USERNAME="ariverosh"

echo ""
echo "📋 Configuración:"
echo "  Usuario: $USERNAME"
echo "  Repositorio: $REPO_NAME"
echo "  Token: ${TOKEN:0:10}..."
echo ""

# Crear el repositorio
echo "📡 Creando repositorio..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/user/repos \
  -d @- << EOF
{
  "name": "$REPO_NAME",
  "description": "$DESCRIPTION",
  "private": false,
  "has_issues": true,
  "has_projects": false,
  "has_wiki": false,
  "auto_init": false
}
EOF
)

# Separar respuesta y código HTTP
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
JSON_RESPONSE=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "201" ]]; then
    echo "✅ Repositorio creado exitosamente!"
    echo ""
    
    # Extraer URL del repositorio
    REPO_URL=$(echo "$JSON_RESPONSE" | grep -o '"clone_url":"[^"]*' | cut -d'"' -f4)
    
    if [[ -n "$REPO_URL" ]]; then
        # Modificar URL para incluir token
        REPO_URL_WITH_TOKEN="https://$USERNAME:$TOKEN@github.com/$USERNAME/$REPO_NAME.git"
        
        echo "📎 Configurando remoto..."
        git remote add origin "$REPO_URL_WITH_TOKEN" 2>/dev/null || git remote set-url origin "$REPO_URL_WITH_TOKEN"
        
        echo "📤 Subiendo código..."
        git branch -M main
        git push -u origin main
        
        echo ""
        echo "🎉 ¡Todo listo!"
        echo "URL: https://github.com/$USERNAME/$REPO_NAME"
    fi
    
elif [[ "$HTTP_CODE" == "422" ]]; then
    echo "❌ El repositorio ya existe"
    echo ""
    echo "Opciones:"
    echo "1. Eliminar el existente desde GitHub"
    echo "2. Usar otro nombre"
    echo "3. Simplemente hacer push al existente:"
    echo "   git remote add origin https://$USERNAME:TOKEN@github.com/$USERNAME/$REPO_NAME.git"
    echo "   git push -u origin main"
    
elif [[ "$HTTP_CODE" == "401" ]]; then
    echo "❌ Token inválido o sin permisos"
    echo "Verifica que el token tenga permisos de 'repo'"
    
else
    echo "❌ Error al crear repositorio (HTTP $HTTP_CODE)"
    echo "$JSON_RESPONSE"
fi