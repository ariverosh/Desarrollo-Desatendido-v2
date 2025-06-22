# 🤖 Avicloud Autonomous Development System v2

## 📋 Información del Repositorio

Este es un repositorio **independiente** del sistema principal Avicloud Display, diseñado específicamente para el Sistema Autónomo de Desarrollo v2.

### 🎯 Propósito
- Sistema 100% autónomo para desarrollo desatendido
- Orquestación inteligente de múltiples instancias Claude
- Prevención de conflictos con sistema de locks
- Documentación auto-mantenida
- Portable y auto-configurable

### 📦 Repositorios Relacionados

Este sistema trabaja con los siguientes repositorios de Avicloud:

1. **Avicloud-Display** - Repositorio principal (configuración/docs)
2. **Avicloud-Display-Server** - Backend .NET Core
3. **Avicloud-Display-Core** - Aplicaciones F# 
4. **Avicloud-Display-Shared** - Modelos compartidos
5. **Avicloud-Display-Pro** - Versión profesional
6. **Avicloud-Display-Server-Blazor** - Versión Blazor

### 🔧 Configuración Inicial

```bash
# Clonar este repositorio
git clone [URL_DEL_REPO] "Desarrollo Desatendido v2"

# Ejecutar bootstrap
cd "Desarrollo Desatendido v2"
./bootstrap.sh

# Verificar instalación
./verify-bootstrap.sh
```

### 📊 Estado Actual

- **Fase 0**: ✅ Bootstrap (COMPLETADO)
- **Fase 1**: ⏳ Sistema de Orquestación (Pendiente)
- **Fase 2**: ⏳ Documentación Viva (Pendiente)
- **Fase 3**: ⏳ Testing Inteligente (Pendiente)
- **Fase 4**: ⏳ Git Multi-Repo (Pendiente)
- **Fase 5**: ⏳ Dashboard y Monitoreo (Pendiente)

### 🚀 Características Principales

- **100% Portable**: Usa rutas relativas exclusivamente
- **Multi-instancia**: Sistema de locks previene conflictos
- **Auto-discovery**: Detecta estructura del proyecto automáticamente
- **Modelo óptimo**: Selecciona Claude apropiado por tarea
- **Auto-recuperación**: Continúa donde se interrumpió

### 📁 Estructura del Repositorio

```
├── core/           # Núcleo del sistema
├── modules/        # Módulos especializados
├── contexts/       # Plantillas y contextos
├── state/          # Estado persistente (DBs, docs)
├── logs/           # Logs del sistema
├── tools/          # Herramientas migradas
└── .locks/         # Sistema de concurrencia
```

### 🔐 Sistema de Locks

El sistema implementa locks con:
- Heartbeat cada 5 segundos
- Auto-cleanup de locks muertos
- Prevención de conflictos entre instancias
- Tracking en base de datos SQLite

### 📝 Notas Importantes

1. Este repositorio es **independiente** del código principal
2. No modificar archivos en `.locks/` manualmente
3. Las bases de datos en `state/` contienen el progreso
4. Los logs se auto-rotan para evitar crecimiento excesivo

---

Para más información, consultar `MASTER_PLAN_AUTONOMOUS_V2.md`