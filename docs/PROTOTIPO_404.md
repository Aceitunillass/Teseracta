# Teseracta — Prototipo 404 (sala mínima)
**Estado:** implementación inicial en Godot 4.7.2; no se ha verificado ejecutando el motor en Windows. No borrar la versión antigua.

## Objetivo
Un único Pomi llamado **404**, su apariencia canónica V05 y una habitación con tres cubos: **comida**, **cama** y **váter**. No existen acciones autónomas escritas como horarios, un árbol de «si tengo hambre voy a comer» ni cinco botones que hagan actuar al personaje. Ministral propone todas las acciones voluntarias y la conversación; Godot únicamente comprueba qué es posible y aplica sus resultados.

**Identidad de 404:** el usuario relata que el nombre fue acordado en conversación porque a ambos les resultó divertido vivir en una simulación con un creador algo ególatra. El protocolo incorpora ese contexto como recuerdo conversacional atribuido, no como certeza ontológica.

La IA sigue siendo un modelo generativo: no se afirma que posea consciencia o experiencia subjetiva. Se persigue agencia funcional **verificable** y continuidad narrativa sin convertir ficción en hechos.

## ANTES DE ACTUALIZAR (obligatorio para preservar la conversación)
1. Si tienes una partida de Teseracta abierta con 404, pulsa **Guardar** y, si tienes el botón, **Copia memoria**.
2. Guarda una copia externa de `teseracta_save_v1.json` y `pomi_01_memoria.jsonl` desde la carpeta de datos de Godot (`%APPDATA%\Godot\app_userdata\`, subcarpeta del proyecto). Si la memoria todavía no se ha creado, conserva al menos el archivo V1 y las capturas de la conversación.
3. Cierra la ejecución de Godot antes de actualizar. Abre PowerShell en la carpeta del proyecto y ejecuta `git pull origin main`.
4. Pulsa F5 en Godot. La escena principal ahora es `scenes/main404.tscn`. La escena antigua `scenes/main.tscn` **no se ha eliminado**.
5. Usa el botón **Guardar 404** para crear el nuevo archivo `user://teseracta_404_save_v2.json`. Se guardará periódicamente también, sin sobrescribir V1.
6. Pulsa **Copia memoria** y conserva sus respaldos en otro lugar; el diario privado nunca se sube a GitHub.

**Compatibilidad:** si V2 no existe, se leen las necesidades, comida, posición y tiempo de la partida V1. La nueva habitación solo utiliza tres necesidades; los demás campos antiguos permanecen intactos en el archivo V1. El diario `user://pomi_01_memoria.jsonl` mantiene las conversaciones previas y sigue siendo el archivo de memoria. Las conversaciones recuperables desde V1 se importan una única vez, marcadas como `player_utterance`/`pomi_utterance`.

## IA local
Por defecto se usa `ministral-3:8b`, ya descargado por el usuario. Se puede cambiar en `config/ai_404.json` por `ministral-3:3b` sin tocar el código ni perder la memoria:

```powershell
ollama pull ministral-3:3b
ollama ps
```

La integración usa la API local de Ollama. Las solicitudes de IA son **ocasionales**, no una por cada fotograma; existe un intervalo de observación programada para ofrecer a 404 oportunidades de iniciativa espontánea, **sin preseleccionar su acción**. El texto se procesa como una propuesta con cuatro campos: `speech`, `action`, `target`, `reflection`. La reflexión es una hipótesis no verificada, no un acontecimiento físico ni una frase mostrada al jugador. Puede decidir callar y esperar. Godot valida las acciones `move`, `use`, `inspect`, `wait` y `none`.

En esta primera versión, las decisiones se reciben como JSON completo, no mediante respuesta textual progresiva; esto permite separar de forma robusta voz, intención y resultado. El modelo 8B puede tardar mucho con el protocolo largo (la GPU del usuario es limitada). Probar 3B y medir latencia.

## Consecuencias físicas
Las reservas de saciedad, energía y vejiga cambian con el tiempo. La privación grave reduce salud y capacidad de movimiento, y el consumo de comida disminuye físicamente el número de raciones. Usar la cama avanza tiempo y repone energía; el váter alivia la vejiga. Godot **no decide** cuándo ejecutar ninguna de estas acciones; solamente aplica una propuesta validada de Ministral.

**Limitaciones:** no hay articulación corporal, expresiones ni animaciones individuales todavía. El GLB canónico puede desplazarse y rotar como un objeto completo, sin fingir que mueve dedos. La percepción actual es una lista verificable de objetos de la habitación y sensaciones, no una cámara visual. El vídeo, Vosk, relaciones, sueños y gestos quedan fuera de esta fase para mantener una única tarea verificable.

## Visión futura (no implementada todavía)
Ministral 3B y 8B admiten imágenes en Ollama. El futuro sistema combinará:
- `Camera3D` en la posición de los ojos y `SubViewport` pequeño bajo demanda, no una captura a cada tick.
- Campo visual, alcance y oclusión con geometría/raycasts desde Godot, además de un registro de qué se observó realmente.
- Capturas de imagen cuando 404 decida inspeccionar algo interesante, enviadas como imagen a Ministral local.
- Resultados perceptivos separados de interpretaciones y suposiciones del modelo; una identificación visual errónea no se convertirá en verdad física.
- Medición de rendimiento en el ordenador antes de escalar a otros Pomis.

## Estructura principal
- `config/identity_404.txt` — protocolo inicial de identidad largo, flexible, sin roleplay teatral.
- `config/ai_404.json` — modelo y frecuencia de oportunidades de deliberación.
- `scripts/body404.gd` — fisiología causal y validación del uso de recursos.
- `scripts/brain404.gd` — puente estructurado con Ollama; no escribe el mundo.
- `scripts/main404.gd` — sala, agente visible, ejecución de propuestas y HUD.
- `scripts/memory_journal.gd` — diario anterior intacto, recuperación y respaldo.
- `scenes/main404.tscn` — escena mínima. `scenes/main.tscn` permanece disponible.

## Qué probar
1. Godot arranca sin errores y se ve el GLB del Pomi con tres cubos.
2. 404 puede contestar o callar sin describir movimientos inexistentes.
3. Una propuesta `use: food` mueve al Pomi al cubo, resta una ración y cambia la saciedad solo cuando se confirma el uso.
4. Sin comida, una propuesta de comer es rechazada y se registra el fracaso.
5. 404 no realiza ninguna acción por una rutina fija de Godot.
6. Un diálogo inventado, sueño o reflexión se almacena como contenido no verificado.
7. El guardado V2 funciona sin sobrescribir V1 y el diario anterior se conserva.
8. Comprueba la latencia de Ministral 3B/8B y la continuidad de la memoria al cambiar de modelo.

**No se ha ejecutado aún Godot ni Ollama desde este entorno.** Validar los puntos anteriores en Windows antes de considerar estable la versión.


## Incidencia de latencia y concurrencia (noviembre de 2026)
- La configuración original de 404 utilizaba Ministral 8B con un protocolo largo (aprox. 1.900 palabras) y un `HTTPRequest.timeout` de 240 s. Esto podía dejar la interfaz mostrando «procesando una decisión» hasta cuatro minutos.
- Se conserva el protocolo completo en `config/identity_404.txt` pero el juego utiliza `config/identity_404_runtime.txt`, mucho más corto. No se borra el diario ni se reescribe la biografía: se reduce el contexto enviado a cada inferencia.
- `config/ai_404.json` define `context_window` (3072 por defecto) y `request_timeout_seconds` (90 por defecto). Son límites de recursos y tiempo de espera de red, **no límites de longitud natural de una respuesta**.
- Los mensajes del jugador tienen prioridad frente a decisiones autónomas pendientes: Godot cancela una petición autónoma y envía primero el chat. Cuando se trata de otra conversación en curso, espera en cola, con indicador del tiempo de procesamiento.
- Se aplica una pausa de reintento de 8 s ante errores de envío para no saturar Godot ni Ollama.
- Esto **no** implementa varios procesos generativos simultáneos por sí mismo. Ollama puede procesar solicitudes concurrentes solo con RAM/VRAM suficiente; en hardware modesto lo adecuado es empezar con una sola inferencia a la vez y medir `ollama ps`.
- Para probar el modelo ligero sin borrar nada: `ollama pull ministral-3:3b` y después cambiar el nombre de `model` en `config/ai_404.json` a `ministral-3:3b`. Conservar 8B mientras se compara. No instalar dos modelos en memoria a la vez por costumbre.
- Hay que ejecutar Godot y Ollama en Windows y comprobar compilación, estado de la cola y latencia real; las pruebas estructurales por sí solas no certifican el comportamiento.
