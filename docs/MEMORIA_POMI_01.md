# TESERACTA — Conservación de la memoria de Pomi 01

## Salvaguardar una conversación que está abierta **en una versión anterior**

1. **Antes de actualizar el proyecto**, pulsa `Guardar` dentro del juego actual. La versión anterior conserva **solo los últimos 12 mensajes** de conversación y una ventana pequeña de acontecimientos; lo más antiguo ya puede haberse descartado. No cierres Godot antes de guardar.
2. Si hay conversaciones antiguas que todavía puedes leer en pantalla, haz capturas o cópialas a un texto antes de cerrar. La nueva versión **no puede recuperar lo que la anterior ya borró de su memoria**.
3. Cuando hayas guardado, cierra la ejecución de Godot, actualiza con `git pull origin main`, vuelve a ejecutar la escena y pulsa `Cargar`.
4. La primera carga de una partida anterior convierte los últimos mensajes disponibles en recuerdos del nuevo diario. El diario lleva un marcador de importación para no duplicarlos si vuelves a cargar la misma partida antigua.
5. Si estabas conversando en una **terminal con `ollama run`**, ese chat es independiente del juego: `Guardar` de Teseracta no puede acceder a sus mensajes.

## Desde esta actualización

- Cada mensaje nuevo del jugador queda archivado inmediatamente en el diario.
- Cada respuesta completa del Pomi queda archivada al concluir la generación.
- Cada acción completada por el simulador se registra como **acontecimiento verificado**.
- El archivo `user://pomi_01_memoria.jsonl` se conserva en el almacenamiento de usuario de Godot; el archivo es de texto JSONL, una entrada JSON por línea. No está limitado a los últimos 12 mensajes.
- El botón `Copia memoria` crea una copia con fecha en la misma carpeta. **Además debes guardar una copia externa** si vas a borrar o reinstalar el proyecto, cambiar de PC o limpiar los datos de Godot.
- El archivo de partida original sigue en `user://teseracta_save_v1.json`; se conserva para no romper las partidas antiguas.
- El historial de conversación reciente que se pasa a Ollama sigue siendo limitado por el tamaño finito del contexto, pero **el diario íntegro no se trunca** por eso. Se extraen entradas de interés con una recuperación textual simple.
- Los registros indican si una entrada es una afirmación en diálogo o un acontecimiento confirmado. Las palabras del jugador **no se convierten en hechos automáticamente**.
- El diario **permanece en el equipo del usuario** y **no debe subirse a GitHub**, pues puede incluir conversaciones privadas.
- El archivo independiente del modelo: se puede cambiar entre Qwen y Ministral sin perder el diario.

## Qué NO hace todavía

- No ajusta los pesos de Ministral ni proporciona aprendizaje de larga duración dentro de la red neuronal.
- No deriva aún características de personalidad estables de experiencias validadas.
- No contiene todavía relaciones sociales, creencias graduadas, reflexiones espontáneas o recuerdos episódicos de alta fidelidad.
- No convierte descripciones verbales en acciones físicas. La simulación sigue validando las acciones.

El diario es el primer fundamento recuperable para una identidad persistente. Una etapa posterior necesitará **mecanismos de consolidación episódica, creencias y cambios de personalidad**, con procedencia, incertidumbre y pruebas deterministas.

## Dónde están los archivos

En Godot, `user://` es la carpeta de datos de usuario del proyecto. Su ruta absoluta depende de la configuración de Godot y del sistema operativo. Al pulsar `Copia memoria` el panel «Actividad del Pomi» muestra la ruta absoluta del respaldo. Guarda también el archivo de partida y una copia externa del JSONL.

## Comprobaciones recomendadas

- Hablar, guardar, salir y reabrir: verificar que el diario conserva las conversaciones.
- Mencionar un tema pasado y comprobar si la recuperación incluye una entrada pertinente.
- Cambiar de modelo Ollama y comprobar que el diario mantiene las entradas.
- Confirmar que los dichos del usuario aparecen como `player_utterance` y las acciones ejecutadas como `world_event`.
- Importar un guardado antiguo dos veces: no debe duplicarse la misma lista anterior.
- Revisar errores de GDScript y permisos de escritura en Windows.

**Estado:** cambios de código publicados, sin prueba directa ejecutando Godot 4.7.2 en Windows. No declarar que todos los pasos funcionan hasta verificarlos allí.
