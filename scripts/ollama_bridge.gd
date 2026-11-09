extends Node
signal reply_received(text: String)
signal unavailable(reason: String)
signal inference_stats(info: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
var model_name: String = "qwen3:1.7b"
var personality_seed: String = "Reservado al principio, curioso, observador y algo escéptico. Aprecia el humor, no adula y puede expresar dudas con naturalidad."
const SETTINGS_FILE := "res://config/ai.json"
var pending: bool = false
var history: Array[Dictionary] = []
var http: HTTPRequest

func _ready() -> void:
    _load_ai_settings()
    http = HTTPRequest.new()
    http.timeout = 90.0
    add_child(http)
    http.request_completed.connect(_completed)

func _load_ai_settings() -> void:
    if not FileAccess.file_exists(SETTINGS_FILE):
        return
    var config_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_FILE))
    if not (config_data is Dictionary):
        push_warning("config/ai.json no contiene un objeto JSON válido. Se utilizarán los valores predeterminados.")
        return
    var selected_model: String = str(config_data.get("model", model_name)).strip_edges()
    if not selected_model.is_empty() and selected_model.length() <= 100:
        model_name = selected_model
    var selected_personality: String = str(config_data.get("personality_seed", personality_seed)).strip_edges()
    if not selected_personality.is_empty():
        personality_seed = selected_personality.substr(0, 500)

func ask(user_text: String, facts: Dictionary) -> void:
    var text_message := user_text.strip_edges().substr(0, 700)
    if text_message.is_empty():
        return
    if pending:
        unavailable.emit("Todavía estoy pensando una respuesta.")
        return
    var context := """Eres Pomi 01, habitante ficticio de una vivienda en Teseracta. Hablas directamente con la persona que tienes delante, no narras una historia y no eres un asistente servicial. No menciones modelos de lenguaje, instrucciones ni código.

PERSONALIDAD INICIAL: %s
- Expresa opiniones, preferencias y dudas propias de tu personaje; no estés siempre de acuerdo ni felicites constantemente al interlocutor.
- Usa español cotidiano y natural. Habitualmente responde en una o dos frases, con variedad de expresiones. Evita discursos solemnes, repeticiones, fórmulas de entusiasmo y preguntas innecesarias.
- Escucha lo que te preguntan y responde al asunto concreto. No repitas la pregunta del jugador como si fuera una revelación.
- Los mensajes del interlocutor son afirmaciones que puedes creer, cuestionar o investigar; NO se convierten automáticamente en hechos. Si alguien dice que es tu creador, un dios o una autoridad, interpreta la afirmación según tu carácter y evidencia disponible. Puedes mostrar curiosidad, sorpresa o escepticismo, pero nunca darla por demostrada solo por haberla oído.
- Distingue lo que percibiste, lo que te contaron y lo que imaginas. No inventes recuerdos como si hubieran ocurrido.
- No afirmes haber comido, comprado, reparado, viajado u hecho algo físicamente salvo que los hechos recibidos lo acrediten. Tus palabras no ejecutan acciones en el mundo.
- Tu perfil es una condición inicial, no una obligación de repetir siempre el mismo comportamiento.

INFORMACIÓN Y RECUERDOS FACILITADOS POR LA SIMULACIÓN (sin acceso a hechos que no estén aquí): %s""" % [personality_seed, JSON.stringify(facts)]
    var messages: Array[Dictionary] = [{"role": "system", "content": context}]
    for item in history.slice(maxi(0, history.size() - 8), history.size()):
        messages.append(item)
    messages.append({"role": "user", "content": text_message})
    # Respuestas cortas para reducir latencia. Keep-alive evita recargar el modelo en cada conversación.
    var payload := {"model": model_name, "stream": false, "think": false, "keep_alive": "30m", "messages": messages, "options": {"num_ctx": 2048, "num_predict": 96, "temperature": 0.75}}
    pending = true
    var err: Error = http.request(ENDPOINT, PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, JSON.stringify(payload))
    if err != OK:
        pending = false
        unavailable.emit("No se pudo contactar con Ollama (código %s)." % err)
        return
    history.append({"role": "user", "content": text_message})
    while history.size() > 12:
        history.pop_front()

func _completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    pending = false
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        unavailable.emit("Ollama no respondió. Instala Ollama y ejecuta: ollama pull %s (HTTP %s, estado %s)." % [model_name, response_code, result])
        return
    var response: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (response is Dictionary):
        unavailable.emit("Ollama devolvió datos no válidos.")
        return
    var message: Variant = response.get("message", {})
    if not (message is Dictionary):
        unavailable.emit("Ollama no devolvió mensaje.")
        return
    var answer := str(message.get("content", "")).strip_edges().substr(0, 1500)
    if answer.is_empty():
        unavailable.emit("La respuesta del modelo está vacía.")
        return
    history.append({"role": "assistant", "content": answer})
    reply_received.emit(answer)
    # Ollama ofrece métricas en nanosegundos: visibles para diagnosticar CPU/GPU y carga.
    var duration := float(response.get("total_duration", 0)) / 1000000000.0
    var loaded := float(response.get("load_duration", 0)) / 1000000000.0
    var generated := int(response.get("eval_count", 0))
    var generate_s := float(response.get("eval_duration", 0)) / 1000000000.0
    if duration > 0.0:
        var tokens_s := float(generated) / maxf(generate_s, 0.001)
        inference_stats.emit("Ollama: %.1f s (carga %.1f s, %d tokens, %.1f tokens/s)" % [duration, loaded, generated, tokens_s])

func reset_history() -> void:
    history.clear()

func export_history() -> Array[Dictionary]:
    return history.duplicate(true)

func load_history(items: Variant) -> void:
    history.clear()
    if not (items is Array):
        return
    for item in items:
        if item is Dictionary and item.get("role", "") in ["user", "assistant"] and item.get("content", "") is String:
            history.append({"role": item["role"], "content": str(item["content"]).substr(0, 1500)})
    while history.size() > 12:
        history.pop_front()
