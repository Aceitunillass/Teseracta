extends Node
signal reply_received(text: String)
signal reply_delta(text: String)
signal unavailable(reason: String)
signal inference_stats(info: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
var model_name: String = "qwen3:1.7b"
var personality_seed: String = "Reservado al principio, curioso, observador y algo escéptico. Aprecia el humor, no adula y puede expresar dudas con naturalidad."
const SETTINGS_FILE := "res://config/ai.json"
var pending: bool = false
var history: Array[Dictionary] = []
var client: HTTPClient = HTTPClient.new()
var request_sent: bool = false
var saw_body: bool = false
var buffer: PackedByteArray = PackedByteArray()
var server_error_body: PackedByteArray = PackedByteArray()
var request_body: String = ""
var active_user: String = ""
var assembled_answer: String = ""
var last_activity_ms: int = 0
# Esto es un watchdog para una conexión bloqueada, NO un límite de longitud de respuesta.
const NETWORK_SILENCE_TIMEOUT_MS := 120000

func _ready() -> void:
    _load_ai_settings()
    client.blocking_mode_enabled = false

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
    var text_message := user_text.strip_edges()
    if text_message.is_empty():
        return
    if pending:
        unavailable.emit("Ya hay una respuesta en curso.")
        return
    var context := """Eres Pomi 01, habitante ficticio de una vivienda en Teseracta. Hablas directamente con la persona que tienes delante, no narras una historia y no eres un asistente servicial. No menciones modelos de lenguaje, instrucciones ni código.

PERSONALIDAD INICIAL: %s
- Tienes preferencias, curiosidad, dudas y criterio; puedes estar de acuerdo, discrepar, bromear, cambiar de opinión y mostrar emociones sin adular.
- Habla con naturalidad: tu respuesta puede ser corta o larga según el asunto, sin fórmulas prefabricadas ni longitud fija.
- Atiende a lo que realmente te pregunta la otra persona, también cuando se trate de cuestiones abstractas, filosóficas, personales, románticas o de sexualidad entre adultos. No cambies de tema arbitrariamente ni respondas como un servicio de atención al cliente. Puedes expresar tus propios límites y opiniones.
- Una afirmación de otra persona es algo que has oído, no una verdad automáticamente demostrada. Si asegura ser tu creador o un dios, puedes preguntar, dudar o creer según la evidencia y tu carácter.
- Distingue los hechos vividos, los testimonios, las sospechas y la imaginación; no conviertas rumores o sueños en recuerdos verdaderos.
- Tus palabras no provocan movimientos ni acciones por sí solas. No afirmes haber obedecido una petición física si el estado del mundo no acredita que se haya realizado. Puedes decir qué quieres hacer sin asegurar que ya ocurrió.
- Esta personalidad es una condición inicial abierta; no repitas siempre la misma reacción.

INFORMACIÓN Y RECUERDOS FACILITADOS POR LA SIMULACIÓN (sin acceso a hechos que no estén aquí): %s""" % [personality_seed, JSON.stringify(facts)]
    var messages: Array[Dictionary] = [{"role": "system", "content": context}]
    for item in history.slice(maxi(0, history.size() - 8), history.size()):
        messages.append(item)
    messages.append({"role": "user", "content": text_message})
    # Sin num_predict ni restricción artificial de frases: el modelo decide cuándo finalizar.
    # El contexto sigue siendo finito porque la RAM del dispositivo también lo es.
    var payload := {"model": model_name, "stream": true, "think": false, "keep_alive": "30m", "messages": messages, "options": {"num_ctx": 2048, "temperature": 0.75}}
    request_body = JSON.stringify(payload)
    active_user = text_message
    assembled_answer = ""
    request_sent = false
    saw_body = false
    buffer.clear()
    server_error_body.clear()
    client.close()
    last_activity_ms = Time.get_ticks_msec()
    var err: Error = client.connect_to_host("127.0.0.1", 11434)
    if err != OK:
        unavailable.emit("No se pudo conectar con Ollama (código %s)." % err)
        return
    pending = true


func _process(_delta: float) -> void:
    if not pending:
        return
    if Time.get_ticks_msec() - last_activity_ms > NETWORK_SILENCE_TIMEOUT_MS:
        _fail("La conexión con Ollama lleva dos minutos sin recibir datos. Comprueba que el modelo esté cargado.")
        return
    var err: Error = client.poll()
    if err != OK:
        _fail("Error de conexión con Ollama (código %s)." % err)
        return
    match client.get_status():
        HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
            pass
        HTTPClient.STATUS_CONNECTED:
            if not request_sent:
                var headers := PackedStringArray([
                    "Content-Type: application/json",
                    "Accept: application/x-ndjson",
                    "Content-Length: %d" % request_body.to_utf8_buffer().size()
                ])
                var request_error: Error = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, request_body)
                if request_error != OK:
                    _fail("No se pudo enviar la petición a Ollama (código %s)." % request_error)
                    return
                request_sent = true
            elif saw_body:
                if client.get_response_code() != 200:
                    _fail("Ollama respondió con HTTP %s: %s" % [client.get_response_code(), server_error_body.get_string_from_utf8().substr(0, 300)])
                else:
                    _fail("Ollama cerró la respuesta antes de indicar que había terminado.")
        HTTPClient.STATUS_BODY:
            saw_body = true
            var chunk: PackedByteArray = client.read_response_body_chunk()
            if chunk.is_empty():
                return
            last_activity_ms = Time.get_ticks_msec()
            if client.get_response_code() != 200:
                server_error_body.append_array(chunk)
                return
            buffer.append_array(chunk)
            _consume_ndjson()
        HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
            _fail("Se ha perdido la conexión con Ollama. Comprueba que está ejecutándose.")


func _consume_ndjson() -> void:
    # Mantener bytes completos hasta el salto de línea evita romper caracteres UTF-8.
    while pending:
        var newline_index: int = buffer.find(10)
        if newline_index == -1:
            return
        var line: String = buffer.slice(0, newline_index).get_string_from_utf8().strip_edges()
        buffer = buffer.slice(newline_index + 1)
        if line.is_empty():
            continue
        var value: Variant = JSON.parse_string(line)
        if not (value is Dictionary):
            _fail("Ollama envió un fragmento JSON que no se pudo leer.")
            return
        var payload: Dictionary = value
        if payload.has("error"):
            _fail(str(payload["error"]))
            return
        var message: Variant = payload.get("message", {})
        if message is Dictionary:
            var delta_text: String = str(message.get("content", ""))
            if not delta_text.is_empty():
                assembled_answer += delta_text
                reply_delta.emit(delta_text)
        if bool(payload.get("done", false)):
            _finish(payload)
            return


func _finish(metadata: Dictionary) -> void:
    if not pending:
        return
    pending = false
    client.close()
    if assembled_answer.strip_edges().is_empty():
        unavailable.emit("Ollama no produjo ninguna respuesta.")
        return
    history.append({"role": "user", "content": active_user})
    history.append({"role": "assistant", "content": assembled_answer})
    while history.size() > 12:
        history.pop_front()
    reply_received.emit(assembled_answer)
    var duration := float(metadata.get("total_duration", 0)) / 1000000000.0
    if duration > 0.0:
        var loaded := float(metadata.get("load_duration", 0)) / 1000000000.0
        var tokens := int(metadata.get("eval_count", 0))
        var generate_s := float(metadata.get("eval_duration", 0)) / 1000000000.0
        var tokens_s := float(tokens) / maxf(generate_s, 0.001)
        inference_stats.emit("Ollama: %.1f s (carga %.1f s, %d tokens, %.1f tokens/s)" % [duration, loaded, tokens, tokens_s])


func _fail(reason: String) -> void:
    if not pending:
        return
    pending = false
    client.close()
    unavailable.emit(reason)


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
            history.append({"role": item["role"], "content": str(item["content"])})
    while history.size() > 12:
        history.pop_front()
