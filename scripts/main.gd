extends Node3D
## Teseracta 0.1.0 — Vertical slice: un Pomi, casa interactiva, simulación y puentes locales.

const SimScript = preload("res://scripts/sim_state.gd")
const AgentScript = preload("res://scripts/pomi_agent.gd")
const HouseScript = preload("res://scripts/house.gd")
const OllamaScript = preload("res://scripts/ollama_bridge.gd")
const VoiceScript = preload("res://scripts/voice_bridge.gd")

var state = SimScript.new()
var home: Node3D
var pomi: Node3D
var ollama: Node
var voice: Node
var busy_action: String = ""
var dwell_time: float = 0.0
var idle_time: float = 3.0
var hud_timer: float = 0.0
var camera: Camera3D
var status_label: Label
var needs_label: Label
var inventory_label: Label
var log_view: RichTextLabel
var chat_input: LineEdit
var mic_button: Button
var pause_button: Button
var drag_last_pos := Vector2.ZERO
var chat_stream_started: bool = false
var queued_chat_messages: Array[String] = []

func _ready() -> void:
    _build_scene()
    ollama = OllamaScript.new()
    add_child(ollama)
    ollama.reply_received.connect(_on_ollama_answer)
    ollama.connect("reply_delta", Callable(self, "_on_ollama_chunk"))
    ollama.unavailable.connect(_on_ollama_error)
    ollama.connect("inference_stats", Callable(self, "_on_ollama_stats"))
    voice = VoiceScript.new()
    add_child(voice)
    voice.transcript_ready.connect(_on_transcript)
    voice.voice_error.connect(_on_voice_error)
    voice.record_state_changed.connect(_on_recording_state)
    _build_ui()
    pomi.arrived.connect(_on_pomi_arrived)
    _log("Bienvenido a la casa del primer Pomi. Haz clic en los muebles o usa los botones.")
    _log("La simulación funciona sin IA. Ollama y Vosk son opcionales.")
    _refresh_status()

func _build_scene() -> void:
    home = HouseScript.new()
    home.name = "Vivienda_Pomi"
    add_child(home)
    home.build()
    pomi = AgentScript.new()
    pomi.name = "Pomi_01"
    pomi.position = Vector3(-3.80, 0.0, 1.10)
    add_child(pomi)
    camera = Camera3D.new()
    camera.name = "Camara_Isometrica"
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 13.5
    camera.position = Vector3(12, 15, 17)
    add_child(camera)
    camera.look_at(Vector3(0, 0.7, 0), Vector3.UP)
    camera.current = true
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("111426")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color.WHITE
    environment.ambient_light_energy = 1.0
    world_environment.environment = environment
    add_child(world_environment)

func _make_button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.pressed.connect(callback)
    return button

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -355.0
    panel.offset_right = -12.0
    panel.offset_top = 12.0
    panel.offset_bottom = -12.0
    canvas.add_child(panel)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 14)
    margin.add_theme_constant_override("margin_bottom", 14)
    panel.add_child(margin)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    margin.add_child(content)
    var title := Label.new()
    title.text = "TESERACTA  |  POMI 01"
    title.add_theme_font_size_override("font_size", 22)
    content.add_child(title)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(status_label)
    needs_label = Label.new()
    needs_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_child(needs_label)
    inventory_label = Label.new()
    content.add_child(inventory_label)
    content.add_child(HSeparator.new())
    var caption := Label.new()
    caption.text = "ACCIONES — haz clic en un mueble o elige:"
    content.add_child(caption)
    var action_grid := GridContainer.new()
    action_grid.columns = 3
    content.add_child(action_grid)
    var options := {"Comer": "eat", "Dormir": "sleep", "Baño": "toilet", "Ducha": "shower", "Sofá": "relax"}
    for option_name in options.keys():
        var requested_action: String = options[option_name]
        action_grid.add_child(_make_button(option_name, Callable(self, "_send_to_action").bind(requested_action, true)))
    content.add_child(HSeparator.new())
    var commands := HBoxContainer.new()
    content.add_child(commands)
    pause_button = _make_button("Pausar", _toggle_pause)
    commands.add_child(pause_button)
    commands.add_child(_make_button("Guardar", _save_game))
    commands.add_child(_make_button("Cargar", _load_game))
    var chat_caption := Label.new()
    chat_caption.text = "HABLAR CON POMI (IA LOCAL OPCIONAL)"
    content.add_child(chat_caption)
    log_view = RichTextLabel.new()
    log_view.fit_content = false
    log_view.scroll_following = true
    log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_view.custom_minimum_size = Vector2(0, 135)
    content.add_child(log_view)
    chat_input = LineEdit.new()
    chat_input.placeholder_text = "Escríbele algo al Pomi..."
    chat_input.text_submitted.connect(_send_chat)
    content.add_child(chat_input)
    var chat_buttons := HBoxContainer.new()
    content.add_child(chat_buttons)
    chat_buttons.add_child(_make_button("Enviar", func(): _send_chat(chat_input.text)))
    mic_button = _make_button("Grabar voz", func(): voice.toggle_recording())
    chat_buttons.add_child(mic_button)
    var hint := Label.new()
    hint.text = "IA: Ollama 127.0.0.1:11434 | Voz: Vosk 127.0.0.1:8765\nClic izquierdo: mobiliario · Rueda: zoom"
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 11)
    content.add_child(hint)

func _process(delta: float) -> void:
    state.tick(delta)
    if state.paused:
        return
    if not busy_action.is_empty() and not pomi.moving:
        dwell_time -= delta
        if dwell_time <= 0.0:
            var action_result: String = state.execute_action(busy_action)
            _log("Pomi: " + action_result)
            busy_action = ""
            idle_time = 3.5
    elif busy_action.is_empty() and not pomi.moving:
        idle_time -= delta
        if idle_time <= 0.0:
            _send_to_action(state.propose_action(), false)
            idle_time = 7.0
    hud_timer -= delta
    if hud_timer <= 0.0:
        _refresh_status()
        hud_timer = 0.35

func _send_to_action(action_name: String, manual: bool) -> void:
    if not home.interactables.has(action_name):
        return
    if action_name == "eat" and int(state.inventory["food"]) < 1:
        _log("No queda comida. La simulación no puede inventar recursos.")
        return
    if action_name == "shower" and int(state.inventory["water"]) < 1:
        _log("No queda agua.")
        return
    var target: Vector3 = home.interactables[action_name]["approach"]
    if not pomi.request_walk(target, action_name):
        _log("Pomi no encontró camino hasta ese mueble.")
        return
    busy_action = action_name
    dwell_time = 999.0 # se empieza a contar al llegar
    if manual:
        _log("Has pedido al Pomi: " + str(home.interactables[action_name]["title"]))

func _on_pomi_arrived() -> void:
    if not busy_action.is_empty():
        dwell_time = 3.0 if busy_action != "sleep" else 5.0

func _refresh_status() -> void:
    if status_label == null:
        return
    status_label.text = "Día %d · %s · %s | Estado de ánimo %d%%" % [state.day_index(), state.clock_text(), "PAUSA" if state.paused else "VIVO", roundi(state.mood())]
    var names := {"hunger": "Saciedad", "energy": "Energía", "bladder": "Vejiga", "hygiene": "Higiene", "fun": "Diversión"}
    var parts := PackedStringArray()
    for key in SimScript.NEED_KEYS:
        parts.append("%s %d%%" % [names[key], roundi(float(state.needs[key]))])
    needs_label.text = " · ".join(parts)
    inventory_label.text = "Nevera %s | Agua %s | Créditos %s" % [state.inventory["food"], state.inventory["water"], state.inventory["credits"]]

func _log(message: String) -> void:
    if log_view:
        log_view.append_text(message + "\n")

func _send_chat(text_value: String) -> void:
    var text_message := text_value.strip_edges()
    if text_message.is_empty():
        return
    chat_input.clear()
    _log("Tú: " + text_message)
    state.remember("El jugador dijo: " + text_message.substr(0, 70))
    # Recibir el mensaje es inmediato, aunque la inferencia anterior siga en curso.
    if bool(ollama.get("pending")):
        queued_chat_messages.append(text_message)
        return
    _request_pomi_reply(text_message)


func _request_pomi_reply(text_message: String) -> void:
    var facts: Dictionary = {"nombre": "Pomi 01", "ubicacion": "Su casa en Teseracta", "día": state.day_index(), "hora": state.clock_text(), "necesidades": state.needs, "comida_disponible": state.inventory["food"], "agua_disponible": state.inventory["water"], "recuerdos_relevantes": state.history.slice(maxi(0, state.history.size() - 5), state.history.size())}
    chat_stream_started = false
    ollama.ask(text_message, facts)


func _on_ollama_chunk(delta_text: String) -> void:
    if log_view == null:
        return
    if not chat_stream_started:
        log_view.append_text("Pomi: ")
        chat_stream_started = true
    log_view.append_text(delta_text)


func _on_ollama_answer(text_value: String) -> void:
    if chat_stream_started:
        log_view.append_text("\n")
    else:
        _log("Pomi: " + text_value)
    chat_stream_started = false
    state.remember("Pomi respondió al jugador: " + text_value.substr(0, 70))
    call_deferred("_dispatch_queued_chat")


func _on_ollama_error(reason: String) -> void:
    if chat_stream_started and log_view:
        log_view.append_text("\n")
    chat_stream_started = false
    _log("[IA no disponible] " + reason)
    call_deferred("_dispatch_queued_chat")


func _dispatch_queued_chat() -> void:
    if not queued_chat_messages.is_empty() and not bool(ollama.get("pending")):
        var next_message: String = queued_chat_messages.pop_front()
        _request_pomi_reply(next_message)


func _on_ollama_stats(info: String) -> void:
    _log("[Diagnóstico] " + info)


func _on_transcript(text_value: String) -> void:
    _log("[Voz reconocida] " + text_value)
    _send_chat(text_value)

func _on_voice_error(reason: String) -> void:
    _log("[Micrófono] " + reason)

func _on_recording_state(active: bool) -> void:
    mic_button.text = "Detener" if active else "Grabar voz"

func _toggle_pause() -> void:
    state.paused = not state.paused
    pomi.set_process(not state.paused)
    pause_button.text = "Reanudar" if state.paused else "Pausar"
    _refresh_status()

func _save_game() -> void:
    var data := state.as_dict()
    data["pomi_position"] = [pomi.position.x, pomi.position.y, pomi.position.z]
    data["conversation"] = ollama.export_history()
    var file := FileAccess.open("user://teseracta_save_v1.json", FileAccess.WRITE)
    if file == null:
        _log("Error de guardado: %s" % FileAccess.get_open_error())
        return
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    _log("Partida guardada en user://teseracta_save_v1.json")

func _load_game() -> void:
    var file := FileAccess.open("user://teseracta_save_v1.json", FileAccess.READ)
    if file == null:
        _log("No se encontró ninguna partida guardada.")
        return
    var data: Variant = JSON.parse_string(file.get_as_text())
    if not (data is Dictionary) or not state.load_dict(data):
        _log("El guardado no es válido o no es compatible.")
        return
    pomi.restore_position(data.get("pomi_position", []))
    ollama.load_history(data.get("conversation", []))
    busy_action = ""
    idle_time = 4.0
    _refresh_status()
    _log("Partida cargada correctamente.")

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.size = maxf(7, camera.size - 0.8)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.size = minf(25, camera.size + 0.8)
        elif event.button_index == MOUSE_BUTTON_LEFT:
            var from: Vector3 = camera.project_ray_origin(event.position)
            var to: Vector3 = from + camera.project_ray_normal(event.position) * 100.0
            var query := PhysicsRayQueryParameters3D.create(from, to)
            query.collision_mask = 2
            query.collide_with_areas = true
            query.collide_with_bodies = false
            var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
            if not result.is_empty():
                var item: Object = result.get("collider")
                if item != null and item.has_meta("action"):
                    _send_to_action(str(item.get_meta("action")), true)
