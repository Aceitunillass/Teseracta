extends Node
## Un puente local Ollama. El modelo no modifica el mundo; propone comandos.
## La interfaz del mundo (observe + submit_action) es independiente de Ollama.

signal partial_speech(text: String)
signal finished(packet: Dictionary)
signal failed(message: String)
signal metrics(text: String)

const HOST := "127.0.0.1"
const PORT := 11434
const TIMEOUT_MS := 90000

var pending: bool = false
var autonomous_request: bool = false
var client: HTTPClient = HTTPClient.new()
var sent: bool = false
var started_ms: int = 0
var request_content: String = ""
var received: PackedByteArray = PackedByteArray()
var output: String = ""
var previous_preview: String = ""
var last_model: String = ""
var body_received: bool = false


func request(prompt: String, model: String, api: Dictionary, observation: Dictionary, history: Array[Dictionary], verified_events: Array[Dictionary], current_message: String, autonomous: bool) -> bool:
    if pending:
        return false
    var schema: Dictionary = {
        "type": "object",
        "properties": {
            "speech": {"type": "string"},
            "reflection": {"type": "string"},
            "action": {
                "type": "object",
                "properties": {
                    "type": {"type": "string", "enum": ["MoveTo", "Stop", "Inspect", "Use", "Wait"]},
                    "data": {"type": "object"}
                },
                "required": ["type", "data"],
                "additionalProperties": false
            }
        },
        "required": ["speech", "reflection", "action"],
        "additionalProperties": false
    }
    # Guía operativa del protocolo, independiente del prompt editable del usuario.
    # Evita que un modelo pequeño confunda IDs de objetos con coordenadas.
    var action_help: String = "\n\nCONTRATO DE ACCIONES (no es un guion de conducta):\n"
    action_help += "Si deseas acercarte a un objeto visible como food: action={\"type\":\"MoveTo\",\"data\":{\"id\":\"food\"}}. "
    action_help += "Si deseas ir a un punto libre: action={\"type\":\"MoveTo\",\"data\":{\"position\":[0.5,0.3]}}. "
    action_help += "Para usar el objeto una vez cerca: action={\"type\":\"Use\",\"data\":{\"id\":\"food\"}}. "
    action_help += "Stop y Wait usan data={}. Elige tú mismo si quieres actuar; la voz no mueve el cuerpo. "
    action_help += "Si el mundo rechaza una acción, lee la razón y no repitas la misma orden sin cambiar algo o recabar información. "
    action_help += "No repitas la misma frase o pregunta de conversaciones previas si ya ha sido respondida. "
    action_help += "Si no sucede nada nuevo durante un ciclo autónomo puedes esperar en silencio (speech vacío), reflexionar o buscar otra experiencia. "
    var system_text: String = prompt + action_help + "\n\nPROTOCOLO DEL MUNDO:\n" + JSON.stringify(api) + "\n\nOBSERVACIÓN ACTUAL:\n" + JSON.stringify(observation) + "\n\nÚLTIMOS HECHOS VERIFICADOS (incluidos rechazos de acciones):\n" + JSON.stringify(verified_events)
    var turns: Array[Dictionary] = [{"role": "system", "content": system_text}]
    for item in history:
        var role: String = str(item.get("role", ""))
        if role == "user" or role == "assistant":
            turns.append({"role": role, "content": str(item.get("content", "")).substr(0, 400)})
    if current_message.strip_edges().is_empty():
        turns.append({"role": "user", "content": "[Aviso interno del mundo, NO lo ha escrito la persona] Ha llegado una oportunidad de deliberar. Observa los resultados recientes. No necesitas repetir tu última intervención ni decir nada si no tienes una nueva idea. Puedes explorar, actuar o esperar por elección propia."})
    else:
        turns.append({"role": "user", "content": current_message.substr(0, 550)})
    var payload: Dictionary = {
        "model": model,
        "stream": true,
        "think": false,
        "keep_alive": "10m",
        "format": schema,
        "messages": turns,
        "options": {"num_ctx": 3072, "temperature": 0.65}
    }
    request_content = JSON.stringify(payload)
    client.close()
    client.blocking_mode_enabled = false
    sent = false
    received.clear()
    output = ""
    previous_preview = ""
    body_received = false
    started_ms = Time.get_ticks_msec()
    last_model = model
    autonomous_request = autonomous
    var error: Error = client.connect_to_host(HOST, PORT)
    if error != OK:
        failed.emit("No se pudo abrir la conexión local con Ollama (código %d)." % error)
        return false
    pending = true
    return true


func cancel_autonomous() -> bool:
    if not pending or not autonomous_request:
        return false
    pending = false
    client.close()
    received.clear()
    output = ""
    previous_preview = ""
    return true


func elapsed_seconds() -> float:
    if not pending:
        return 0.0
    return float(Time.get_ticks_msec() - started_ms) / 1000.0


func _process(_delta: float) -> void:
    if not pending:
        return
    if Time.get_ticks_msec() - started_ms > TIMEOUT_MS:
        _fail("Ollama superó 90 segundos; revisa el modelo o el uso de CPU/GPU.")
        return
    var polled: Error = client.poll()
    if polled != OK:
        _fail("Fallo de conexión con Ollama (código %d)." % polled)
        return
    match client.get_status():
        HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_REQUESTING:
            pass
        HTTPClient.STATUS_CONNECTED:
            if not sent:
                var headers: PackedStringArray = PackedStringArray([
                    "Content-Type: application/json",
                    "Accept: application/x-ndjson",
                    "Content-Length: %d" % request_content.to_utf8_buffer().size()
                ])
                var result: Error = client.request(HTTPClient.METHOD_POST, "/api/chat", headers, request_content)
                if result != OK:
                    _fail("No se pudo enviar la petición (código %d)." % result)
                else:
                    sent = true
            elif body_received:
                _fail("Ollama terminó la conexión sin mensaje final.")
        HTTPClient.STATUS_BODY:
            body_received = true
            var chunk: PackedByteArray = client.read_response_body_chunk()
            if not chunk.is_empty():
                received.append_array(chunk)
                _parse_lines()
        HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
            _fail("La conexión con Ollama se perdió.")


func _parse_lines() -> void:
    while pending:
        var newline: int = received.find(10)
        if newline < 0:
            return
        var line: String = received.slice(0, newline).get_string_from_utf8().strip_edges()
        received = received.slice(newline + 1)
        if line.is_empty():
            continue
        var parsed: Variant = JSON.parse_string(line)
        if not (parsed is Dictionary):
            _fail("Fragmento de Ollama no válido.")
            return
        var packet: Dictionary = parsed
        if packet.has("error"):
            _fail(str(packet["error"]))
            return
        var msg: Variant = packet.get("message", {})
        if msg is Dictionary:
            var delta_text: String = str(msg.get("content", ""))
            if not delta_text.is_empty():
                output += delta_text
                var partial: String = _partial_speech(output)
                if partial.length() > previous_preview.length() and partial.begins_with(previous_preview):
                    previous_preview = partial
                    partial_speech.emit(partial)
        if bool(packet.get("done", false)):
            _complete(packet)
            return


func _partial_speech(raw: String) -> String:
    var key: int = raw.find('"speech"')
    if key < 0:
        return ""
    var colon: int = raw.find(":", key + 8)
    if colon < 0:
        return ""
    var start: int = colon + 1
    while start < raw.length() and raw.substr(start, 1) in [" ", "\r", "\n", "\t"]:
        start += 1
    if start >= raw.length() or raw.substr(start, 1) != '"':
        return ""
    var escaped: bool = false
    var encoded: String = ""
    for i in range(start + 1, raw.length()):
        var character: String = raw.substr(i, 1)
        if escaped:
            if character == "u":
                if i + 4 >= raw.length():
                    break
                encoded += raw.substr(i - 1, 6)
                # Unicode escapes are completed as a unit by JSON parser below.
                # Re-reading their hex tail would duplicate data; defer preview.
                return previous_preview
            encoded += "\\" + character
            escaped = false
            continue
        if character == "\\":
            escaped = true
            continue
        if character == '"':
            break
        encoded += character
    var decoded: Variant = JSON.parse_string('"' + encoded + '"')
    return str(decoded) if decoded is String else previous_preview


func _complete(meta: Dictionary) -> void:
    if not pending:
        return
    pending = false
    client.close()
    var parsed: Variant = JSON.parse_string(output.strip_edges())
    if not (parsed is Dictionary):
        failed.emit("El modelo no devolvió un JSON completo válido.")
        return
    var packet: Dictionary = parsed
    var action: Variant = packet.get("action", {})
    if not (action is Dictionary):
        failed.emit("El modelo no devolvió un comando con estructura válida.")
        return
    var kind: String = str(action.get("type", "Wait"))
    if kind not in ["MoveTo", "Stop", "Inspect", "Use", "Wait"]:
        failed.emit("Acción desconocida en la respuesta del modelo.")
        return
    finished.emit({
        "speech": str(packet.get("speech", "")),
        "reflection": str(packet.get("reflection", "")),
        "action": action
    })
    var generated: int = int(meta.get("eval_count", 0))
    var generation_s: float = float(meta.get("eval_duration", 0)) / 1000000000.0
    var total_s: float = float(meta.get("total_duration", 0)) / 1000000000.0
    metrics.emit("%s · %.1f s · %d tokens · %.1f tok/s" % [
        last_model, total_s, generated, float(generated) / maxf(0.001, generation_s)
    ])


func _fail(reason: String) -> void:
    pending = false
    client.close()
    failed.emit(reason)
