#!/bin/bash
# task-delegator.sh - Delegador Inteligente de Tareas
# Selecciona el modelo Claude óptimo y gestiona la ejecución

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cargar utilidades
source "$BASE_DIR/common/utils.sh"

# Configuración de modelos
declare -A MODEL_COSTS=(
    ["haiku"]="0.25"      # Por millón de tokens
    ["sonnet"]="3.00"     # Por millón de tokens  
    ["opus"]="15.00"      # Por millón de tokens
)

declare -A MODEL_CAPABILITIES=(
    ["haiku"]="simple"    # Tareas simples, documentación, análisis básico
    ["sonnet"]="medium"   # Desarrollo general, refactoring, tests
    ["opus"]="complex"    # Arquitectura, diseño complejo, debugging difícil
)

# Función para estimar complejidad de la tarea
estimate_task_complexity() {
    local task_id=$1
    local task_name=$2
    local phase=$3
    
    local complexity="simple"
    
    # Análisis por palabras clave en el nombre
    if [[ "$task_name" =~ (arquitectura|diseño|complex|sistema|principal) ]]; then
        complexity="complex"
    elif [[ "$task_name" =~ (refactor|implement|crear|desarrollar|test) ]]; then
        complexity="medium"
    elif [[ "$task_name" =~ (documentar|actualizar|verificar|simple) ]]; then
        complexity="simple"
    fi
    
    # Ajustar por fase
    case $phase in
        orchestration|architecture)
            [[ "$complexity" == "simple" ]] && complexity="medium"
            ;;
        documentation)
            [[ "$complexity" == "complex" ]] && complexity="medium"
            ;;
    esac
    
    echo "$complexity"
}

# Función para estimar tokens necesarios
estimate_tokens() {
    local context_file=$1
    local complexity=$2
    
    # Estimación básica: caracteres / 4 = tokens aproximados
    local context_size=0
    if [[ -f "$context_file" ]]; then
        context_size=$(wc -c < "$context_file")
    fi
    
    local base_tokens=$((context_size / 4))
    
    # Multiplicador por complejidad
    case $complexity in
        simple)
            echo $((base_tokens * 2))  # Input + output similar
            ;;
        medium)
            echo $((base_tokens * 5))  # Más análisis y código
            ;;
        complex)
            echo $((base_tokens * 10)) # Mucho razonamiento y output
            ;;
    esac
}

# Seleccionar modelo óptimo
select_optimal_model() {
    local task_id=$1
    local task_name=$2
    local phase=$3
    local context_file=$4
    
    log "INFO" "🤖 Analizando tarea para selección de modelo..."
    
    # Estimar complejidad
    local complexity=$(estimate_task_complexity "$task_id" "$task_name" "$phase")
    log "INFO" "Complejidad estimada: $complexity"
    
    # Estimar tokens
    local estimated_tokens=$(estimate_tokens "$context_file" "$complexity")
    log "INFO" "Tokens estimados: $estimated_tokens"
    
    # Selección basada en complejidad y costo
    local selected_model="sonnet"  # Por defecto
    
    case $complexity in
        simple)
            if [[ $estimated_tokens -lt 50000 ]]; then
                selected_model="haiku"
            else
                selected_model="sonnet"  # Haiku puede ser lento en contextos grandes
            fi
            ;;
        medium)
            selected_model="sonnet"
            ;;
        complex)
            if [[ "$phase" == "orchestration" ]] || [[ "$phase" == "architecture" ]]; then
                selected_model="opus"  # Vale la pena para tareas críticas
            else
                selected_model="sonnet"  # Balance costo/beneficio
            fi
            ;;
    esac
    
    # Calcular costo estimado
    local cost_per_million=${MODEL_COSTS[$selected_model]}
    local estimated_cost=$(awk "BEGIN {printf \"%.4f\", ($estimated_tokens / 1000000) * $cost_per_million}")
    
    log "INFO" "Modelo seleccionado: Claude $selected_model"
    log "INFO" "Costo estimado: \$$estimated_cost USD"
    
    # Retornar modelo y metadata
    echo "$selected_model|$complexity|$estimated_tokens|$estimated_cost"
}

# Preparar contexto optimizado para el modelo
prepare_optimized_context() {
    local model=$1
    local context_file=$2
    local output_file=$3
    
    log "INFO" "📝 Optimizando contexto para $model..."
    
    # Header con instrucciones específicas del modelo
    cat > "$output_file" << EOF
# Contexto Optimizado para Claude $model

## Instrucciones del Modelo
EOF

    case $model in
        haiku)
            cat >> "$output_file" << 'EOF'
- Sé conciso y directo
- Enfócate en la tarea específica
- Evita explicaciones largas
- Código simple y claro

EOF
            ;;
        sonnet)
            cat >> "$output_file" << 'EOF'
- Balance entre detalle y eficiencia
- Explica decisiones importantes
- Código robusto y bien estructurado
- Considera casos edge

EOF
            ;;
        opus)
            cat >> "$output_file" << 'EOF'
- Análisis profundo y completo
- Considera múltiples alternativas
- Documenta el razonamiento
- Arquitectura escalable y mantenible
- Anticipa problemas futuros

EOF
            ;;
    esac
    
    # Agregar contexto original
    cat "$context_file" >> "$output_file"
    
    # Agregar limitaciones según modelo
    echo "" >> "$output_file"
    echo "## Limitaciones del Modelo" >> "$output_file"
    
    case $model in
        haiku)
            echo "- Mantén respuestas bajo 2000 tokens" >> "$output_file"
            echo "- Una solución directa es mejor que múltiples opciones" >> "$output_file"
            ;;
        sonnet)
            echo "- Apunta a respuestas de 2000-5000 tokens" >> "$output_file"
            echo "- Proporciona la mejor solución con alternativas si es relevante" >> "$output_file"
            ;;
        opus)
            echo "- Puedes usar hasta 10000 tokens si es necesario" >> "$output_file"
            echo "- Explora completamente el espacio del problema" >> "$output_file"
            ;;
    esac
}

# Registrar delegación en la base de datos
register_delegation() {
    local task_id=$1
    local model=$2
    local complexity=$3
    local tokens=$4
    local cost=$5
    
    sqlite3 "$BASE_DIR/state/progress.db" << EOF
INSERT INTO task_history (task_id, model, task_type, status, run_date)
VALUES ('$task_id', '$model', '$complexity', 'delegated', datetime('now'));
EOF
    
    log "INFO" "✅ Delegación registrada en base de datos"
}

# Función principal de delegación
delegate() {
    local task_id=$1
    local task_name=$2
    local phase=$3
    local context_file=$4
    
    require_file "$context_file" "El contexto de la tarea debe existir"
    
    log "INFO" "🎯 Iniciando delegación de tarea $task_id"
    
    # Seleccionar modelo óptimo
    local model_info=$(select_optimal_model "$task_id" "$task_name" "$phase" "$context_file")
    IFS='|' read -r model complexity tokens cost <<< "$model_info"
    
    # Preparar contexto optimizado
    local optimized_context="$BASE_DIR/contexts/active/optimized-$task_id.md"
    prepare_optimized_context "$model" "$context_file" "$optimized_context"
    
    # Registrar delegación
    register_delegation "$task_id" "$model" "$complexity" "$tokens" "$cost"
    
    # Aquí es donde se ejecutaría Claude
    # Por ahora, creamos un placeholder
    local result_file="$BASE_DIR/state/results/task-$task_id-result.md"
    ensure_directory "$(dirname "$result_file")"
    
    cat > "$result_file" << EOF
# Resultado de Tarea $task_id

## Metadata
- Modelo: Claude $model
- Complejidad: $complexity
- Tokens estimados: $tokens
- Costo estimado: \$$cost USD
- Timestamp: $(date)

## Estado
⏳ Pendiente de ejecución real con Claude API

## Próximos Pasos
1. Integrar Claude API
2. Ejecutar con el contexto optimizado
3. Procesar resultado
4. Actualizar estado de la tarea

---
Placeholder generado por task-delegator.sh
EOF
    
    log "SUCCESS" "✅ Tarea delegada exitosamente"
    log "INFO" "Contexto optimizado en: $optimized_context"
    log "INFO" "Resultado esperado en: $result_file"
    
    return 0
}

# Mostrar estadísticas de delegación
show_stats() {
    log "INFO" "📊 Estadísticas de Delegación"
    
    sqlite3 "$BASE_DIR/state/progress.db" -header -column << EOF
SELECT 
    model as Modelo,
    COUNT(*) as Tareas,
    task_type as Tipo
FROM task_history
WHERE status = 'delegated'
GROUP BY model, task_type
ORDER BY model;
EOF
}

# Procesar argumentos
case "${1:-}" in
    stats)
        show_stats
        ;;
    delegate)
        shift
        if [[ $# -lt 4 ]]; then
            error_with_solution \
                "Uso incorrecto del delegador" \
                "delegate <task_id> <task_name> <phase> <context_file>"
        fi
        delegate "$@"
        ;;
    *)
        cat << EOF
Uso: $0 <comando> [argumentos]

Comandos:
    delegate <task_id> <task_name> <phase> <context_file>
        Delegar una tarea al modelo óptimo
        
    stats
        Mostrar estadísticas de delegación

Ejemplo:
    $0 delegate "1.1" "Implementar Orquestador" "orchestration" "/path/to/context.md"

EOF
        exit 1
        ;;
esac