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
