# Teseracta ZERO

Prototipo mínimo desde cero de un mundo low-poly para agentes encarnados. Un 404-cubo, tres objetos-cubo, paredes, editor de objetos y paneles de conversación, prompt, memoria y depuración. Protocolo observar → proponer una acción → Godot valida → recibir resultado, inspirado arquitectónicamente en [Clawblox/Eko](https://github.com/nacloos/clawblox).

**Estado:** primera base experimental. Godot 4.7.2; requiere Ollama local para activar conversación e inferencia. No instala ni descarga modelos; usa el que selecciones en la pestaña Agente. Por defecto qwen3:1.7b.

## Ejecutar

Abre project.godot en Godot 4.7.2 y pulsa F5. Primero puedes probar el editor de objetos sin Ollama. Después instala/ejecuta Ollama y selecciona el identificador exacto del modelo en el panel Agente.

En la pestaña Editor puedes añadir cubos, variar parámetros y guardarlos. Agente permite editar prompt y modelo. Memoria muestra un JSON nuevo, completamente independiente de cualquier archivo anterior. Registro contiene acciones verificadas por Godot, propuestas del modelo y notas reflection generadas explícitamente.

No importamos ni leemos partidas, personalidad, avatar ni diario anteriores. Datos nuevos: user://teseracta_zero/.

La versión precedente del repositorio no forma parte de este árbol de trabajo. Git conserva commits previos en su historial; si necesitas borrado definitivo del repositorio remoto y su historia, hay que eliminarlo y crear otro desde GitHub, operación que no está cubierta por esta integración.

Consulta [arquitectura](docs/ARCHITECTURE.md) para limitaciones y próximos pasos.
