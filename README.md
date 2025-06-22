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
