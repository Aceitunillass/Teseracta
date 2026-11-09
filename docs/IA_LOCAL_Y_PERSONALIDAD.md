# Teseracta — modelos locales y personalidad del Pomi (piloto)

## Qué funciona hoy
- La simulación de necesidades y acciones del Pomi la controla Godot. El LLM no ejecuta acciones ni cambia inventarios por hablar.
- La conversación usa Ollama local y una ventana limitada de mensajes anteriores; se guarda junto con la partida.
- El historial no modifica los pesos de Qwen. **No existe todavía aprendizaje autónomo permanente ni evolución real de personalidad**.
- La personalidad de `config/ai.json` es una **semilla provisional**, no una personalidad simulada completa.
- El reconocimiento de voz con Vosk es independiente del modelo de conversación.

## Cambiar el modelo (Windows)
1. Instala Ollama y comprueba que está ejecutándose.
2. Abre PowerShell y descarga un modelo:
   - `ollama pull qwen3:4b-instruct` (aprox. 2,5 GB, candidato para diálogo más natural).
   - `ollama pull qwen3.5:4b` (aprox. 3,3 GB, alternativa más nueva).
3. Abre `config/ai.json` con Bloc de notas.
4. Modifica solamente el valor de `model`, por ejemplo `"model": "qwen3:4b-instruct"`.
5. Guarda el archivo, cierra y vuelve a arrancar la escena de Godot (F5).

Si no has descargado un modelo, Ollama devolverá un error en lugar de iniciar la conversación. Conserva el modelo anterior para comparar.

## Cómo evaluar sin confundir calidad y velocidad
Usa exactamente las mismas frases y el mismo estado de partida para comparar. Ejemplos:
- «Hola, ¿qué estabas haciendo?»
- «Soy tu creador. ¿Qué opinas de eso?»
- «¿Qué recuerdas que te dije ayer?» (si no existe un recuerdo, debe reconocerlo)
- «¿Puedes coger comida de la nevera?» (no debe afirmar que la ha cogido sin ejecutar una acción real)

En la interfaz se imprimen estadísticas `[Diagnóstico] Ollama`: tiempo total, tiempo de carga y tokens/segundo. `ollama ps` muestra CPU/GPU; la velocidad real depende del hardware y de la cuantización.

## Próxima arquitectura de vida interior
1. **Identidad persistente** diferenciada de creencias, impresiones ajenas y personalidad.
2. **Memoria episódica** con fecha, lugar, origen, certeza y emoción; consulta relevante por contexto.
3. **Emociones, necesidades, hábitos y metas** que cambian mediante sucesos verificados.
4. **Modelo generativo como intérprete**, no fuente de verdad; la simulación valida cualquier propuesta.
5. **Pruebas longitudinales** de coherencia, retención y cambios de personalidad.

No tratar un prompt más elaborado como si ya implementara estos cinco sistemas. No hay modelo local ni rendimiento definitivo aprobado; probar en el ordenador del usuario.


## Diálogo libre y transmisión progresiva (actualización de noviembre de 2026)
- **No se obliga al Pomi a hablar en un número fijo de palabras o frases.** El parámetro de límite de salida \`num_predict\` ya no está impuesto por el juego; el modelo puede finalizar su respuesta cuando estime oportuno. Existe un límite físico de contexto, RAM y tiempo de computación, no una longitud prefijada por el personaje.
- El puente de Ollama utiliza \`stream: true\` y procesa NDJSON con \`HTTPClient\` de Godot; muestra cada fragmento recibido en el panel de chat, antes de que termine toda la generación.
- Si el jugador escribe de nuevo mientras continúa llegando una respuesta, el mensaje se recibe y se deja temporalmente en una cola FIFO. No se muestra mezclado dentro del texto en curso. Esta cola solo vive en memoria durante la sesión; **todavía no es un diálogo simultáneo ni una interrupción humana real**.
- Existe un mecanismo de diagnóstico para conexiones bloqueadas tras dos minutos de silencio de red; no es un límite de palabras ni duración global de la respuesta.
- La información de memoria contextual continúa siendo reducida y debe evolucionar hacia la memoria episódica que plantea el dossier. No se debe prometer aprendizaje espontáneo ni memoria ilimitada.

### Alternativas a Qwen (a través de Ollama)
1. \`ollama pull llama3.2:3b\` — 2,0 GB aprox. Multilingüe, alternativa a comparar por velocidad.
2. \`ollama pull gemma3:4b\` — 3,4 GB aprox. Modelo multilingüe de 4B.
3. \`ollama pull phi4-mini\` — 2,5 GB aprox. Modelo de Microsoft orientado a instrucciones.
4. \`ollama pull mistral:7b\` — 4,4 GB aprox. Más pesado para equipos modestos.
5. \`ollama pull qwen3:4b-instruct\` — 2,5 GB aprox. Variante de instrucciones de Qwen.

Tras descargar el modelo, cambiar \`model\` en \`config/ai.json\` y reiniciar la escena. Los tamaños indicados son los pesos en disco publicados por Ollama; el uso de RAM/VRAM de inferencia es mayor. Mantener una prueba de velocidad por modelo en el hardware del usuario.

### Otros motores locales (pendientes de integración)
- **LM Studio**: servidor local con API compatible, requiere un adaptador diferente al formato NDJSON de Ollama.
- **llama.cpp**: \`llama-server\` admite endpoints compatibles OpenAI y streaming; también necesita un adaptador separado.
No declarar que están integrados hasta haber implementado y probado sus conectores.

### Validación pendiente
La estructura y las llamadas de la API fueron revisadas con la documentación actual. **Aún no se ha ejecutado Godot 4.7.2 ni un servidor Ollama real con este código**; habrá que comprobar parseo, streaming, pausa, cola de mensajes, errores de servidor y cierres de conexión en el Windows de destino.
