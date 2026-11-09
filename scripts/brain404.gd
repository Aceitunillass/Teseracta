extends Node
## Interfaz generativa de 404. Solo propone decisiones: NO escribe estado del mundo.
signal decision_ready(decision: Dictionary)
signal inference_failed(reason: String)
signal inference_metrics(details: String)

const ENDPOINT := "http://127.0.0.1:11434/api/chat"
const CONFIG := "res://config/ai_404.json"
const IDENTITY := "res://config/identity_404.txt"

var model_name: String = "ministral-3:8b"
var pending: bool = false
var http: HTTPRequest

func _ready() -> void:
    if FileAccess.file_exists(CONFIG):
        var settings: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
        if settings is Dictionary:
            var selected: String = str(settings.get("model", model_name)).strip_edges()
            if not selected.is_empty():
                model_name = selected
    http = HTTPRequest.new()
    http.timeout = 240.0
    add_child(http)
    http.request_completed.connect(_on_response)

func deliberate(perception: Dictionary, autobiographical_context: Array[Dictionary], trigger: String) -> bool:
    if pending:
        return false
    var prompt_text: String = ""
    if FileAccess.file_exists(IDENTITY):
        prompt_text = FileAccess.get_file_as_string(IDENTITY)
    if prompt_text.is_empty():
        inference_failed.emit("No se encontró el protocolo de identidad 404.")
        return false
    var input_packet: Dictionary = {
        "trigger": trigger,
        "world_observation": perception,
        "recalled_records": autobiographical_context,
        "protocol": "Devuelve un objeto JSON con speech, action, target y reflection. Sin Markdown ni texto fuera del JSON."
    }
    var schema := {
        "type": "object",
        "properties": {
            "speech": {"type": "string"},
            "action": {"type": "string", "enum": ["none", "move", "use", "inspect", "wait"]},
            "target": {"type": "string", "enum": ["none", "food", "bed", "toilet", "center"]},
            "reflection": {"type": "string"}
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
        "options": {"num_ctx": 6144, "temperature": 0.7}
    }
    pending = true
    var result: Error = http.request(
        ENDPOINT,
        PackedStringArray(["Content-Type: application/json"]),
        HTTPClient.METHOD_POST,
        JSON.stringify(payload)
    )
    if result != OK:
        pending = false
        inference_failed.emit("No se pudo enviar la solicitud a Ollama (error %d)." % result)
        return false
    return true

func _on_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    pending = false
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
        "reflection": str(decision.get("reflection", ""))
    }
    decision_ready.emit(clean)
    var seconds: float = float(response.get("total_duration", 0)) / 1000000000.0
    var tokens: int = int(response.get("eval_count", 0))
    var generation_seconds: float = float(response.get("eval_duration", 0)) / 1000000000.0
    if seconds > 0.0:
        inference_metrics.emit("%s: %.1fs, %d tokens, %.1f tokens/s" % [model_name, seconds, tokens, float(tokens) / maxf(generation_seconds, 0.001)])
