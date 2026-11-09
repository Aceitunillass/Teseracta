extends Node
## Interfaz generativa de 404. Solo propone decisiones: NO escribe estado del mundo.
signal decision_ready(decision: Dictionary)
signal inference_failed(reason: String)
signal inference_metrics(details: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
const CONFIG := "res://config/ai_404.json"
const IDENTITY := "res://config/identity_404_runtime.txt"

var model_name: String = "ministral-3:8b"
var pending: bool = false
var active_trigger: String = ""
var started_at_ms: int = 0
var request_timeout_seconds: float = 100.0
var context_window: int = 3072
var http: HTTPRequest
var request_serial: int = 0

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
        "protocol": "Devuelve un objeto JSON con speech, action, target y reflection. Sin Markdown ni texto fuera del JSON."
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
        "stream": false,
        "think": false,
        "keep_alive": "30m",
        "format": schema,
        "messages": [
            {"role": "system", "content": prompt_text},
            {"role": "user", "content": JSON.stringify(input_packet)}
        ],
        "options": {"num_ctx": context_window, "temperature": 0.7}
    }
    request_serial += 1
    http = HTTPRequest.new()
    http.timeout = request_timeout_seconds
    add_child(http)
    http.request_completed.connect(Callable(self, "_on_response").bind(request_serial))
    pending = true
    active_trigger = trigger
    started_at_ms = Time.get_ticks_msec()
    var result: Error = http.request(
        ENDPOINT,
        PackedStringArray(["Content-Type: application/json"]),
        HTTPClient.METHOD_POST,
        JSON.stringify(payload)
    )
    if result != OK:
        pending = false
        active_trigger = ""
        http.queue_free()
        http = null
        inference_failed.emit("No se pudo enviar la solicitud a Ollama (error %d)." % result)
        return false
    return true

func seconds_waiting() -> float:
    if not pending:
        return 0.0
    return float(Time.get_ticks_msec() - started_at_ms) / 1000.0


func cancel_autonomous_for_chat() -> bool:
    if not pending or not active_trigger.begins_with("iniciativa_autonoma"):
        return false
    # Cada solicitud lleva número propio; una respuesta vieja no debe
    # confundirse con la conversación nueva después de una cancelación.
    request_serial += 1
    pending = false
    active_trigger = ""
    if is_instance_valid(http):
        http.cancel_request()
        http.queue_free()
    http = null
    return true


func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, received_serial: int) -> void:
    if received_serial != request_serial or not pending:
        return
    var was_direct_message: bool = active_trigger.begins_with("mensaje_del_interlocutor")
    pending = false
    active_trigger = ""
    if is_instance_valid(http):
        http.queue_free()
    http = null
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
        inference_failed.emit("Ministral no respondió correctamente (HTTP %d, red %d): %s" % [response_code, result, body.get_string_from_utf8().substr(0, 350)])
        return
    var response: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (response is Dictionary):
        inference_failed.emit("Ollama devolvió un paquete inválido.")
        return
    var message: Variant = response.get("message", {})
    if not (message is Dictionary):
        inference_failed.emit("Ollama no devolvió mensaje.")
        return
    var raw: String = str(message.get("content", "")).strip_edges()
    var decision: Variant = JSON.parse_string(raw)
    if not (decision is Dictionary):
        inference_failed.emit("Ministral no generó una decisión estructurada: " + raw.substr(0, 170))
        return
    var valid_actions := ["none", "move", "use", "inspect", "wait"]
    var valid_targets := ["none", "food", "bed", "toilet", "center"]
    var action: String = str(decision.get("action", "none"))
    var target: String = str(decision.get("target", "none"))
    if not valid_actions.has(action) or not valid_targets.has(target):
        inference_failed.emit("La propuesta contiene una acción o un objetivo inexistente.")
        return
    # El texto es un acto de habla, jamás una acción corporal verificada.
    var clean: Dictionary = {
        "speech": str(decision.get("speech", "")),
        "action": action,
        "target": target,
        "reflection": str(decision.get("reflection", "")),
        "_origin": "direct_message" if was_direct_message else "autonomous"
    }
    decision_ready.emit(clean)
    var seconds: float = float(response.get("total_duration", 0)) / 1000000000.0
    var tokens: int = int(response.get("eval_count", 0))
    var generation_seconds: float = float(response.get("eval_duration", 0)) / 1000000000.0
    if seconds > 0.0:
        inference_metrics.emit("%s: %.1fs, %d tokens, %.1f tokens/s; habla: %d caracteres; origen: %s" % [model_name, seconds, tokens, float(tokens) / maxf(generation_seconds, 0.001), str(clean["speech"]).length(), str(clean["_origin"])])
