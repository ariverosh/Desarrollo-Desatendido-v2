# Sistema Universal de Desarrollo Desatendido v2

## 🌍 Sistema Universal para Cualquier Proyecto

Este es un sistema de desarrollo autónomo **universal** que puede adaptarse a cualquier proyecto de software. No está limitado a un proyecto específico y puede auto-descubrir la estructura de cualquier codebase.

## 🚀 Inicio Rápido

```bash
# Clonar en cualquier proyecto
git clone https://github.com/ariverosh/Desarrollo-Desatendido-v2.git

# Ejecutar bootstrap (solo primera vez)
cd Desarrollo-Desatendido-v2
./bootstrap.sh

# El sistema auto-descubrirá tu proyecto
./core/auto-discovery.sh

# Verificar instalación
./verify-bootstrap.sh
```

## 🎯 Características Universales

- **🔍 Auto-Discovery**: Detecta automáticamente la estructura de cualquier proyecto
- **🌐 Agnóstico de Tecnología**: Funciona con cualquier lenguaje/framework
- **📦 Portable**: 100% rutas relativas, funciona en cualquier ubicación
- **🔐 Multi-instancia**: Sistema de locks previene conflictos
- **🤖 IA Inteligente**: Selecciona el modelo Claude óptimo por tarea
- **📚 Documentación Viva**: Se auto-actualiza según los cambios
- **🔄 Auto-recuperación**: Continúa donde se interrumpió

## 📁 Estructura

- `core/` - Núcleo del sistema de orquestación
- `modules/` - Módulos especializados (locks, docs, tests, etc.)
- `contexts/` - Plantillas y contextos activos para tareas
- `state/` - Estado persistente (DBs, docs, snapshots)
- `logs/` - Logs consolidados del sistema
- `tools/` - Herramientas específicas del proyecto
- `.locks/` - Archivos de lock para concurrencia

## 🔧 Adaptación a Tu Proyecto

1. **Auto-Discovery**: El sistema detectará automáticamente:
   - Estructura de directorios
   - Repositorios Git
   - Lenguajes de programación
   - Frameworks utilizados
   - Herramientas de build
   - Suites de testing

2. **Configuración**: Después del discovery, encontrarás:
   - `state/project-config.sh` - Configuración auto-generada
   - Puedes personalizar según necesidades específicas

3. **Herramientas**: Coloca scripts específicos en `tools/`
   - El sistema los integrará automáticamente

## 📊 Estado del Sistema

Ver `MASTER_PLAN_AUTONOMOUS_V2.md` para capacidades completas.