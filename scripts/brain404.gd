extends Node
## Interfaz generativa de 404. Solo propone decisiones: NO escribe estado del mundo.
signal decision_ready(decision: Dictionary)
signal inference_failed(reason: String)
signal inference_metrics(details: String)
signal speech_preview(text: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
const CONFIG := "res://config/ai_404.json"
const IDENTITY := "res://config/identity_404_runtime.txt"

var model_name: String = "ministral-3:8b"
var pending: bool = false
var active_trigger: String = ""
var started_at_ms: int = 0
var request_timeout_seconds: float = 100.0
var context_window: int = 3072
var client: HTTPClient = HTTPClient.new()
var request_sent: bool = false
var body_started: bool = false
var received_bytes: PackedByteArray = PackedByteArray()
var failed_response_bytes: PackedByteArray = PackedByteArray()
var request_body: String = ""
var assembled_answer: String = ""
var last_preview: String = ""

func _ready() -> void:
    if FileAccess.file_exists(CONFIG):
        var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
        if settings is Dictionary:
            var selected: String = str(settings.get("model", model_name)).strip_edges()
            if not selected.is_empty():
                model_name = selected
            request_timeout_seconds = clampf(float(settings.get("request_timeout_seconds", request_timeout_seconds)), 25.0, 240.0)
            context_window = clampi(int(settings.get("context_window", context_window)), 2048, 8192)

func deliberate(perception: Dictionary, autobiographical_context: Array[Dictionary], trigger: String) -> bool:
    if pending:
        return false
    var prompt_text: String = ""
    if FileAccess.file_exists(IDENTITY):
        prompt_text = FileAccess.get_file_as_string(IDENTITY)
    if prompt_text.is_empty():
        inference_failed.emit("No se encontró el protocolo de identidad 404.")
        return false
    # El archivo de diario sigue íntegro. Solo se limita la información
    # enviada en ESTA inferencia para que Ministral responda antes.
    var recalled: Array[Dictionary] = []
    for entry in autobiographical_context.slice(0, 4):
        recalled.append({
            "kind": str(entry.get("kind", "")),
            "text": str(entry.get("text", "")).substr(0, 380),
            "provenance": str(entry.get("provenance", "desconocido"))
        })
    var direct_message: bool = trigger.begins_with("mensaje_del_interlocutor")
    var input_packet: Dictionary = {
        "trigger": trigger,
        "interaction_type": "direct_message" if direct_message else "autonomous_deliberation",
        "speech_requirement": "Responde verbalmente a la persona en speech. No respondas solo en reflection." if direct_message else "Puedes decidir callar, hablar o actuar.",
        "world_observation": perception,
        "recalled_records": recalled,
        "protocol": "Devuelve solo JSON válido y escribe speech primero, después action, target y reflection. Sin Markdown."
    }
    var speech_schema: Dictionary = {"type": "string"}
    if direct_message:
        # Un chat dirigido a 404 requiere una respuesta verbal verificable;
        # en iniciativas autónomas sigue pudiendo guardar silencio.
        speech_schema["minLength"] = 1
    var schema := {
        "type": "object",
        "properties": {
            "speech": speech_schema,
            "action": {"type": "string", "enum": ["none", "move", "use", "inspect", "wait"]},
            "target": {"type": "string", "enum": ["none", "food", "bed", "toilet", "center"]},
            "reflection": {"type": "string", "maxLength": 240}
        },
        "required": ["speech", "action", "target", "reflection"],
        "additionalProperties": false
    }
    var payload := {
        "model": model_name,
        "stream": true,
        "think": false,
        "keep_alive": "30m",
        "format": schema,
        "messages": [
            {"role": "system", "content": prompt_text},
            {"role": "user", "content": JSON.stringify(input_packet)}
        ],
        "options": {"num_ctx": context_window, "temperature": 0.7}
    }
    request_body = JSON.stringify(payload)
    client.close()
    client.blocking_mode_enabled = false
    request_sent = false
    body_started = false
    received_bytes.clear()
    failed_response_bytes.clear()
    assembled_answer = ""
    last_preview = ""
    started_at_ms = Time.get_ticks_msec()
    var result: Error = client.connect_to_host("127.0.0.1", 11434)
    if result != OK:
        inference_failed.emit("No fue posible conectar con Ollama (error %d)." % result)
        return false
    pending = true
    active_trigger = trigger
    return true


func seconds_waiting() -> float:
    if not pending:
        return 0.0
    return float(Time.get_ticks_msec() - started_at_ms) / 1000.0


func cancel_autonomous_for_chat() -> bool:
    if not pending or not active_trigger.begins_with("iniciativa_autonoma"):
        return false
    # Cerrar la conexión cancela la lectura y evita mezclar respuestas.
    pending = false
    active_trigger = ""
    client.close()
    received_bytes.clear()
    assembled_answer = ""
    last_preview = ""
    return true


func _process(_delta: float) -> void:
    if not pending:
        return
    if seconds_waiting() > request_timeout_seconds:
        _fail("Ministral superó %.0f s sin terminar. Comprueba el modelo y la carga de Ollama." % request_timeout_seconds)
        return
    var result: Error = client.poll()
    if result != OK:
        _fail("Fallo de conexión con Ollama (error %d)." % result)
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
                var send_error: Error = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, request_body)
                if send_error != OK:
                    _fail("Error enviando a Ollama (codigo %d)." % send_error)
                    return
                request_sent = true
            elif body_started:
                if client.get_response_code() != 200:
                    _fail("Ollama HTTP %d: %s" % [client.get_response_code(), failed_response_bytes.get_string_from_utf8().substr(0, 300)])
                else:
                    _fail("Ollama cerró la conexión sin finalizar la respuesta.")
        HTTPClient.STATUS_BODY:
            body_started = true
            var chunk: PackedByteArray = client.read_response_body_chunk()
            if chunk.is_empty():
                return
            if client.get_response_code() != 200:
                failed_response_bytes.append_array(chunk)
                return
            received_bytes.append_array(chunk)
            _consume_lines()
        HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
            _fail("Se perdió la conexión con Ollama.")


func _consume_lines() -> void:
    # NDJSON del servidor, no fragmentos arbitrarios de UTF-8.
    while pending:
        var at_newline: int = received_bytes.find(10)
        if at_newline < 0:
            return
        var json_line: String = received_bytes.slice(0, at_newline).get_string_from_utf8().strip_edges()
        received_bytes = received_bytes.slice(at_newline + 1)
        if json_line.is_empty():
            continue
        var decoded: Variant = JSON.parse_string(json_line)
        if not (decoded is Dictionary):
            _fail("Ollama devolvió un fragmento NDJSON inválido.")
            return
        var packet: Dictionary = decoded
        if packet.has("error"):
            _fail(str(packet["error"]))
            return
        var message: Variant = packet.get("message", {})
        if message is Dictionary:
            var delta_text: String = str(message.get("content", ""))
            if not delta_text.is_empty():
                assembled_answer += delta_text
                if active_trigger.begins_with("mensaje_del_interlocutor"):
                    var partial: String = _extract_partial_speech(assembled_answer)
                    if partial.length() > last_preview.length() and partial.begins_with(last_preview):
                        last_preview = partial
                        speech_preview.emit(partial)
        if bool(packet.get("done", false)):
            _finish(packet)
            return


func _extract_partial_speech(raw_json: String) -> String:
    # Extraer únicamente el campo "speech", nunca reflection ni JSON crudo.
    # Se descartan escapes incompletos hasta recibirlos enteros.
    var key_start: int = raw_json.find('"speech"')
    if key_start < 0:
        return ""
    var colon: int = raw_json.find(":", key_start + 8)
    if colon < 0:
        return ""
    var start: int = colon + 1
    while start < raw_json.length() and raw_json.substr(start, 1) in [" ", "\n", "\r", "\t"]:
        start += 1
    if start >= raw_json.length() or raw_json.substr(start, 1) != '"':
        return ""
    var raw_value: String = ""
    var i: int = start + 1
    while i < raw_json.length():
        var character: String = raw_json.substr(i, 1)
        if character == '"':
            break
        if character == "\\":
            if i + 1 >= raw_json.length():
                break
            var escape_char: String = raw_json.substr(i + 1, 1)
            if escape_char == "u":
                if i + 5 >= raw_json.length():
                    break
                raw_value += raw_json.substr(i, 6)
                i += 6
                continue
            if escape_char not in ['"', "\\", "/", "b", "f", "n", "r", "t"]:
                break
            raw_value += raw_json.substr(i, 2)
            i += 2
            continue
        raw_value += character
        i += 1
    var decoded: Variant = JSON.parse_string('"' + raw_value + '"')
    return str(decoded) if decoded is String else ""


func _finish(metadata: Dictionary) -> void:
    if not pending:
        return
    var direct: bool = active_trigger.begins_with("mensaje_del_interlocutor")
    pending = false
    active_trigger = ""
    client.close()
    var decoded: Variant = JSON.parse_string(assembled_answer.strip_edges())
    if not (decoded is Dictionary):
        inference_failed.emit("Ministral no devolvió JSON válido: " + assembled_answer.substr(0, 180))
        return
    var decision: Dictionary = decoded
    var action: String = str(decision.get("action", "none"))
    var target: String = str(decision.get("target", "none"))
    if action not in ["none", "move", "use", "inspect", "wait"] or target not in ["none", "food", "bed", "toilet", "center"]:
        inference_failed.emit("Ministral intentó una acción o destino inexistente.")
        return
    var final_decision: Dictionary = {
        "speech": str(decision.get("speech", "")),
        "action": action,
        "target": target,
        "reflection": str(decision.get("reflection", "")),
        "_origin": "direct_message" if direct else "autonomous"
    }
    decision_ready.emit(final_decision)
    var duration: float = float(metadata.get("total_duration", 0)) / 1000000000.0
    var tokens: int = int(metadata.get("eval_count", 0))
    var generation_seconds: float = float(metadata.get("eval_duration", 0)) / 1000000000.0
    if duration > 0.0:
        inference_metrics.emit("%s: %.1f s, %d tokens, %.1f tokens/s; habla: %d caracteres; origen: %s" % [
            model_name, duration, tokens, float(tokens) / maxf(generation_seconds, 0.001),
            str(final_decision["speech"]).length(), str(final_decision["_origin"])
        ])


func _fail(reason: String) -> void:
    if not pending:
        return
    pending = false
    active_trigger = ""
    client.close()
    inference_failed.emit(reason)
