extends RefCounted
## Nuevo estado de Teseracta ZERO. Ninguna importación desde partidas o diarios previos.

const ROOT := "user://teseracta_zero/"
const PROMPT_FILE := ROOT + "prompt_404.txt"
const MEMORY_FILE := ROOT + "memory_404.json"
const EVENTS_FILE := ROOT + "verified_events_404.jsonl"
const MODEL_FILE := ROOT + "model_404.txt"
const WORLD_FILE := ROOT + "world.json"
const DEFAULT_PROMPT_PATH := "res://config/default_prompt.txt"

var prompt: String = ""
var model: String = "qwen3:1.7b"
var entries: Array[Dictionary] = []
var events: Array[Dictionary] = []


func _init() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
    if FileAccess.file_exists(PROMPT_FILE):
        prompt = FileAccess.get_file_as_string(PROMPT_FILE)
    elif FileAccess.file_exists(DEFAULT_PROMPT_PATH):
        prompt = FileAccess.get_file_as_string(DEFAULT_PROMPT_PATH)
        _write(PROMPT_FILE, prompt)
    if FileAccess.file_exists(MODEL_FILE):
        model = FileAccess.get_file_as_string(MODEL_FILE).strip_edges()
    if FileAccess.file_exists(MEMORY_FILE):
        var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MEMORY_FILE))
        if parsed is Array:
            for item in parsed:
                if item is Dictionary and item.has("kind") and item.has("text"):
                    entries.append(item.duplicate(true))
    if FileAccess.file_exists(EVENTS_FILE):
        var lines: PackedStringArray = FileAccess.get_file_as_string(EVENTS_FILE).split("\n", false)
        for line in lines:
            var event: Variant = JSON.parse_string(line)
            if event is Dictionary:
                events.append(event)
    if model.is_empty():
        model = "qwen3:1.7b"


func _write(path: String, content: String) -> bool:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(content)
    file.close()
    return true


func save_prompt(value: String) -> bool:
    if value.strip_edges().is_empty():
        return false
    if not _write(PROMPT_FILE, value):
        return false
    prompt = value
    return true


func save_model(value: String) -> bool:
    var cleaned: String = value.strip_edges()
    if cleaned.is_empty():
        return false
    if not _write(MODEL_FILE, cleaned):
        return false
    model = cleaned
    return true


func save_world(data: Dictionary) -> bool:
    return _write(WORLD_FILE, JSON.stringify(data, "\t"))


func load_world() -> Variant:
    if not FileAccess.file_exists(WORLD_FILE):
        return null
    return JSON.parse_string(FileAccess.get_file_as_string(WORLD_FILE))


func record(kind: String, content: String) -> void:
    # Conversación y reflexión: datos generados, nunca hechos físicos verificados.
    if kind not in ["user", "agent", "reflection", "user_note"]:
        return
    var entry: Dictionary = {
        "kind": kind,
        "text": content,
        "time": Time.get_datetime_string_from_system(),
        "origin": "user" if kind in ["user", "user_note"] else "model"
    }
    entries.append(entry)
    _write(MEMORY_FILE, JSON.stringify(entries, "\t"))


func record_event(event: Dictionary) -> void:
    # Solo el motor del mundo llama a este método; no se mezcla con el editor de recuerdos.
    var value: Dictionary = event.duplicate(true)
    events.append(value)
    var file: FileAccess = FileAccess.open(EVENTS_FILE, FileAccess.READ_WRITE)
    if file == null:
        file = FileAccess.open(EVENTS_FILE, FileAccess.WRITE)
    if file == null:
        return
    file.seek_end()
    file.store_line(JSON.stringify(value))
    file.close()


func dialogue_history(limit: int = 8) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(entries.size() - 1, -1, -1):
        var item: Dictionary = entries[index]
        var kind: String = str(item.get("kind", ""))
        if kind not in ["user", "agent"]:
            continue
        result.append({
            "role": "user" if kind == "user" else "assistant",
            "content": str(item.get("text", "")).substr(0, 400)
        })
        if result.size() >= limit:
            break
    result.reverse()
    return result


func recent_verified_events(limit: int = 5) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(events.size() - 1, -1, -1):
        result.append(events[index].duplicate(true))
        if result.size() >= limit:
            break
    result.reverse()
    return result


func memory_json() -> String:
    return JSON.stringify(entries, "\t")


func replace_edited_memories(text: String) -> bool:
    # La persona puede editar sus propias memorias, sin sobrescribir el registro
    # separado de hechos confirmados por el motor.
    var parsed: Variant = JSON.parse_string(text)
    if not (parsed is Array) or parsed.size() > 5000:
        return false
    var clean: Array[Dictionary] = []
    for value in parsed:
        if not (value is Dictionary):
            return false
        if not value.has("kind") or not value.has("text"):
            return false
        var entry: Dictionary = value.duplicate(true)
        entry["origin"] = "manually_edited"
        clean.append(entry)
    if not _write(MEMORY_FILE, JSON.stringify(clean, "\t")):
        return false
    entries = clean
    return true


func clear_memory() -> bool:
    if not _write(MEMORY_FILE, "[]"):
        return false
    entries.clear()
    return true
