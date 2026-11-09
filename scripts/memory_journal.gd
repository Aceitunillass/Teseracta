extends RefCounted
## Diario autobiografico local del primer Pomi.
## Cada linea es un registro JSON. Nunca se almacena en el repositorio GitHub.
## El diario es persistente y no se elimina al limitar el contexto del LLM.

const JOURNAL_PATH := "user://pomi_01_memoria.jsonl"
var entries: Array[Dictionary] = []

func _init() -> void:
    _load()


func _load() -> void:
    entries.clear()
    if not FileAccess.file_exists(JOURNAL_PATH):
        return
    var file := FileAccess.open(JOURNAL_PATH, FileAccess.READ)
    if file == null:
        push_warning("No se pudo leer la memoria persistente del Pomi.")
        return
    while not file.eof_reached():
        var line: String = file.get_line().strip_edges()
        if line.is_empty():
            continue
        var decoded: Variant = JSON.parse_string(line)
        if decoded is Dictionary and decoded.has("kind") and decoded.has("text"):
            entries.append(decoded)
    file.close()


func record(kind: String, content: String, day: int, clock: String) -> bool:
    if content.strip_edges().is_empty():
        return false
    var provenance := "observacion_confirmada" if kind == "world_event" else "conversacion_no_verificada"
    if kind == "migration_marker":
        provenance = "metadato"
    var entry: Dictionary = {
        "kind": kind,
        "text": content,
        "day": day,
        "clock": clock,
        "recorded_at": Time.get_datetime_string_from_system(),
        "provenance": provenance
    }
    # Abrir y cerrar cada registro: una interrupcion del juego no borra la sesion entera.
    if not FileAccess.file_exists(JOURNAL_PATH):
        var created := FileAccess.open(JOURNAL_PATH, FileAccess.WRITE)
        if created == null:
            push_warning("No se pudo crear la memoria del Pomi.")
            return false
        created.close()
    var file := FileAccess.open(JOURNAL_PATH, FileAccess.READ_WRITE)
    if file == null:
        push_warning("No se pudo abrir el diario del Pomi para escritura.")
        return false
    file.seek_end()
    file.store_line(JSON.stringify(entry))
    file.flush()
    file.close()
    entries.append(entry)
    return true


func import_legacy_conversation(history: Variant, day: int, clock: String) -> void:
    # Solo al cargar una partida V1 anterior a la incorporacion del diario.
    if not (history is Array) or history.is_empty():
        return
    var signature: String = JSON.stringify(history).sha256_text()
    for entry in entries:
        if str(entry.get("kind", "")) == "migration_marker" and str(entry.get("text", "")) == signature:
            return
    for message in history:
        if not (message is Dictionary):
            continue
        var role: String = str(message.get("role", ""))
        var content: String = str(message.get("content", ""))
        if role == "user":
            record("player_utterance", content, day, clock)
        elif role == "assistant":
            record("pomi_utterance", content, day, clock)
    record("migration_marker", signature, day, clock)


func recent_dialogue(limit: int = 8) -> Array[Dictionary]:
    # Historial real de turnos, no resumen semántico. Evitar reflexiones
    # privadas y eventos del mundo: no son intervenciones de los hablantes.
    # No se elimina ni modifica ningún registro original.
    var recent: Array[Dictionary] = []
    var wanted: int = clampi(limit, 1, 12)
    for idx in range(entries.size() - 1, -1, -1):
        var entry: Dictionary = entries[idx]
        var kind: String = str(entry.get("kind", ""))
        var role: String = ""
        if kind == "player_utterance":
            role = "user"
        elif kind == "pomi_utterance":
            role = "assistant"
        else:
            continue
        var content: String = str(entry.get("text", "")).strip_edges()
        if content.is_empty():
            continue
        # Se conserva el diario entero, solo limitamos el texto que se manda a Ollama.
        recent.append({"role": role, "content": content.substr(0, 450)})
        if recent.size() >= wanted:
            break
    recent.reverse()
    return recent


func recall(query: String, count: int = 8) -> Array[Dictionary]:
    # Recuperacion lexical economica: relevancia + recencia. No relee los archivos
    # ni lanza el LLM para cada recuerdo.
    var matches: Array[Dictionary] = []
    var words: PackedStringArray = query.to_lower().split(" ", false)
    for idx in range(entries.size()):
        var entry: Dictionary = entries[idx]
        if str(entry.get("kind", "")) == "migration_marker":
            continue
        var content: String = str(entry.get("text", "")).to_lower()
        var score: float = 0.01 * float(idx + 1) / float(maxi(1, entries.size()))
        for word in words:
            if word.length() >= 4 and content.contains(word):
                score += 1.0
        matches.append({"score": score, "index": idx})
    matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
    var selected: Array[Dictionary] = []
    for item in matches.slice(0, mini(count, matches.size())):
        var entry: Dictionary = entries[int(item["index"])]
        selected.append(entry.duplicate(true))
    return selected


func backup() -> String:
    if not FileAccess.file_exists(JOURNAL_PATH):
        return ""
    var contents: PackedByteArray = FileAccess.get_file_as_bytes(JOURNAL_PATH)
    var date_suffix: String = Time.get_datetime_string_from_system().replace(":", "-")
    var target: String = "user://pomi_01_memoria_copia_%s.jsonl" % date_suffix
    var file := FileAccess.open(target, FileAccess.WRITE)
    if file == null:
        return ""
    file.store_buffer(contents)
    file.close()
    return ProjectSettings.globalize_path(target)
