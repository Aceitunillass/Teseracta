extends Node3D
## Teseracta 404: una sala, tres recursos, ninguna accion voluntaria predeterminada.
## Toda iniciativa y propuesta de accion procede de Ministral. Godot valida y ejecuta.
const BodyScript = preload("res://scripts/body404.gd")
const BrainScript = preload("res://scripts/brain404.gd")
const JournalScript = preload("res://scripts/memory_journal.gd")
const SAVE_V2 := "user://teseracta_404_save_v2.json"
const SAVE_V1 := "user://teseracta_save_v1.json"
const AVATAR_PATH := "res://assets/characters/Pomi_Base_V05_Canonico.glb"
const SETTINGS_PATH := "res://config/ai_404.json"

var body = BodyScript.new()
var journal = JournalScript.new()
var brain: Node
var pomi: Node3D
var avatar: Node3D
var camera: Camera3D
var dialogue: RichTextLabel
var world_log: RichTextLabel
var status_label: Label
var cognition_label: Label
var chat_input: LineEdit
var autonomy_button: Button
var simulation_pause_button: Button
var targets: Dictionary = {
    "food": Vector3(-2.45, 0.0, -1.4),
    "bed": Vector3(0.0, 0.0, -1.4),
    "toilet": Vector3(2.45, 0.0, -1.4),
    "center": Vector3(0.0, 0.0, 1.15)
}
var queued_chat: Array[String] = []
var active_destination: String = ""
var use_after_walk: String = ""
var walk_target: Vector3 = Vector3.ZERO
var moving: bool = false
var autonomy_enabled: bool = true
var autonomy_interval: float = 55.0
var elapsed_real: float = 0.0
var next_thought_at: float = 9.0
var refresh_at: float = 0.0
var autosave_at: float = 35.0
var last_result: String = "Acabas de iniciar esta version sencilla de la habitacion."
var chat_retry_at: float = 0.0
var simulation_paused: bool = false

func _ready() -> void:
    _load_settings()
    _create_room()
    _create_pomi()
    _restore_from_disk()
    # Evitar que un guardado crítico empeore antes de que el usuario lo atienda.
    if body.health <= 10.0:
        simulation_paused = true
    brain = BrainScript.new()
    add_child(brain)
    brain.connect("decision_ready", Callable(self, "_on_decision"))
    brain.connect("inference_failed", Callable(self, "_on_brain_error"))
    brain.connect("inference_metrics", Callable(self, "_on_brain_metrics"))
    _create_interface()
    _event("Habitacion de 404: tres cubos y sin rutinas automaticas de actividad.")
    _event("La memoria y el guardado V1 no se modificaran ni se borraran.")
    _event("Hay %d registros en el diario autobiografico." % journal.entries.size())
    if simulation_paused:
        _event("PROTECCION: salud critica detectada. El tiempo corporal esta pausado hasta que decidas reanudarlo.")
    _refresh_status()

func _load_settings() -> void:
    if not FileAccess.file_exists(SETTINGS_PATH):
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
    if data is Dictionary:
        autonomy_interval = clampf(float(data.get("autonomy_interval_seconds", autonomy_interval)), 15.0, 240.0)

func _material(value: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = value
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func _cube(label_text: String, at: Vector3, scale_value: Vector3, tint: Color) -> void:
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = label_text
    var box := BoxMesh.new()
    box.size = scale_value
    mesh_node.mesh = box
    mesh_node.material_override = _material(tint)
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_node.position = at
    add_child(mesh_node)

func _floating_label(word: String, at: Vector3) -> void:
    var sign_label := Label3D.new()
    sign_label.text = word
    sign_label.font_size = 52
    sign_label.pixel_size = 0.005
    sign_label.modulate = Color("e6e7f0")
    sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign_label.no_depth_test = true
    sign_label.position = at
    add_child(sign_label)

func _create_room() -> void:
    _cube("Suelo", Vector3(0.0, -0.12, 0.0), Vector3(8.0, 0.24, 6.2), Color("343b54"))
    _cube("Pared_fondo", Vector3(0.0, 1.3, -3.07), Vector3(8.0, 2.6, 0.12), Color("272a3d"))
    _cube("Pared_izquierda", Vector3(-3.97, 1.3, 0.0), Vector3(0.12, 2.6, 6.1), Color("272a3d"))
    _cube("Pared_derecha", Vector3(3.97, 1.3, 0.0), Vector3(0.12, 2.6, 6.1), Color("272a3d"))
    _cube("Cubo_comida", Vector3(-2.45, 0.5, -2.05), Vector3(1.1, 1.0, 1.0), Color("e5b072"))
    _cube("Cubo_cama", Vector3(0.0, 0.5, -2.05), Vector3(1.1, 1.0, 1.0), Color("a58cdd"))
    _cube("Cubo_vater", Vector3(2.45, 0.5, -2.05), Vector3(1.1, 1.0, 1.0), Color("77c8c5"))
    _floating_label("COMER", Vector3(-2.45, 1.43, -2.05))
    _floating_label("DORMIR", Vector3(0.0, 1.43, -2.05))
    _floating_label("VATER", Vector3(2.45, 1.43, -2.05))
    camera = Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 9.0
    camera.position = Vector3(8.8, 11.0, 12.0)
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.65, -0.35), Vector3.UP)
    camera.current = true
    var world_environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("121625")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    world_environment.environment = env
    add_child(world_environment)

func _create_pomi() -> void:
    pomi = Node3D.new()
    pomi.name = "404"
    pomi.position = Vector3(0.0, 0.0, 1.1)
    add_child(pomi)
    if ResourceLoader.exists(AVATAR_PATH):
        var loaded: Resource = load(AVATAR_PATH)
        if loaded is PackedScene:
            avatar = loaded.instantiate() as Node3D
            if avatar != null:
                avatar.name = "Pomi_V05_Canonico"
                avatar.scale = Vector3.ONE * 1.45
                pomi.add_child(avatar)
                _unshade(avatar)
                return
    avatar = Node3D.new()
    avatar.name = "Modelo_provisional_faltan_archivos"
    pomi.add_child(avatar)
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = CapsuleMesh.new()
    mesh_instance.position = Vector3(0.0, 0.85, 0.0)
    mesh_instance.material_override = _material(Color("e8a0a9"))
    avatar.add_child(mesh_instance)

func _unshade(node: Node) -> void:
    if node is MeshInstance3D:
        var part: MeshInstance3D = node as MeshInstance3D
        part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if part.mesh != null:
            for index in range(part.mesh.get_surface_count()):
                var original: Material = part.mesh.surface_get_material(index)
                if original is BaseMaterial3D:
                    var copy: BaseMaterial3D = original.duplicate() as BaseMaterial3D
                    copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                    copy.vertex_color_use_as_albedo = true
                    part.set_surface_override_material(index, copy)
    for child in node.get_children():
        _unshade(child)

func _button(label_text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label_text
    button.pressed.connect(callback)
    return button

func _create_interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -420
    panel.offset_right = -12
    panel.offset_top = 12
    panel.offset_bottom = -12
    layer.add_child(panel)
    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 10)
    margins.add_theme_constant_override("margin_right", 10)
    margins.add_theme_constant_override("margin_top", 10)
    margins.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margins)
    var contents := VBoxContainer.new()
    contents.add_theme_constant_override("separation", 7)
    margins.add_child(contents)
    var heading := Label.new()
    heading.text = "TESERACTA · 404"
    heading.add_theme_font_size_override("font_size", 22)
    contents.add_child(heading)
    status_label = Label.new()
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    contents.add_child(status_label)
    cognition_label = Label.new()
    cognition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    contents.add_child(cognition_label)
    var save_controls := HBoxContainer.new()
    contents.add_child(save_controls)
    save_controls.add_child(_button("Guardar 404", _save_state))
    save_controls.add_child(_button("Cargar", _reload_state))
    save_controls.add_child(_button("Copia memoria", _backup_memory))
    var maintenance := HBoxContainer.new()
    contents.add_child(maintenance)
    maintenance.add_child(_button("Reponer comida (+12)", _restock_food))
    maintenance.add_child(_button("Cuidar a 404", _restore_404_health))
    simulation_pause_button = _button("Reanudar tiempo" if simulation_paused else "Pausar tiempo", _toggle_simulation_pause)
    contents.add_child(simulation_pause_button)
    autonomy_button = _button("Pausar iniciativa", _toggle_autonomy)
    contents.add_child(autonomy_button)
    var heading_events := Label.new()
    heading_events.text = "ACONTECIMIENTOS VERIFICADOS"
    contents.add_child(heading_events)
    world_log = RichTextLabel.new()
    world_log.scroll_following = true
    world_log.custom_minimum_size = Vector2(0, 95)
    contents.add_child(world_log)
    contents.add_child(HSeparator.new())
    var heading_chat := Label.new()
    heading_chat.text = "HABLAR CON 404"
    contents.add_child(heading_chat)
    dialogue = RichTextLabel.new()
    dialogue.scroll_following = true
    dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue.custom_minimum_size = Vector2(0, 160)
    contents.add_child(dialogue)
    chat_input = LineEdit.new()
    chat_input.placeholder_text = "Escribe a 404..."
    chat_input.text_submitted.connect(_send_chat)
    contents.add_child(chat_input)
    var chat_buttons := HBoxContainer.new()
    contents.add_child(chat_buttons)
    chat_buttons.add_child(_button("Enviar", func(): _send_chat(chat_input.text)))
    chat_buttons.add_child(_button("Observar", _request_observation))
    var hint := Label.new()
    hint.text = "404 decide qué decir y qué intentar hacer.\nGodot valida. Ministral se ejecuta localmente con Ollama."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 11)
    contents.add_child(hint)

func _say(message: String) -> void:
    if dialogue != null:
        dialogue.add_text(message + "\n")

func _event(message: String) -> void:
    if world_log != null:
        world_log.add_text(message + "\n")

func _refresh_status() -> void:
    if status_label == null:
        return
    status_label.text = "Día %d · %s | %s\nSaciedad %.0f | Energía %.0f | Vejiga %.0f | Salud %.0f\nComida restante: %d" % [
        body.day_index(), body.clock_text(), "TIEMPO PAUSADO" if simulation_paused else "EN CURSO",
        body.satiety, body.energy, body.bladder_relief, body.health, body.food_units
    ]
    if bool(brain.get("pending")):
        var wait_seconds: float = float(brain.call("seconds_waiting"))
        var waiting_for: String = str(brain.get("active_trigger"))
        var task: String = "tu mensaje" if waiting_for.begins_with("mensaje_del_interlocutor") else "una decisión propia"
        cognition_label.text = "%s: procesando %s (%.0f s). Mensajes en cola: %d" % [str(brain.get("model_name")), task, wait_seconds, queued_chat.size()]
    elif moving:
        cognition_label.text = "404 se desplaza hacia " + active_destination
    elif autonomy_enabled:
        cognition_label.text = "404 puede decidir por su cuenta."
    else:
        cognition_label.text = "Iniciativa autónoma pausada."

func _process(delta: float) -> void:
    elapsed_real += delta
    if not simulation_paused:
        body.tick(delta)
        _update_walk(delta)
        if body.health <= 10.0:
            simulation_paused = true
            if simulation_pause_button != null:
                simulation_pause_button.text = "Reanudar tiempo"
            _event("PROTECCION: salud critica. Tiempo corporal pausado para permitir cuidados.")
    refresh_at -= delta
    if refresh_at <= 0.0:
        _refresh_status()
        refresh_at = 0.4
    if elapsed_real >= autosave_at:
        _write_state(false)
        autosave_at = elapsed_real + 35.0
    if brain == null or bool(brain.get("pending")) or moving:
        return
    if not queued_chat.is_empty():
        if elapsed_real >= chat_retry_at:
            _dispatch_chat()
    elif autonomy_enabled and elapsed_real >= next_thought_at:
        _start_decision("iniciativa_autonoma", "Puedes decidir espontaneamente si hablar, observar, actuar o esperar.")

func _observation() -> Dictionary:
    var objects := {
        "food": {"label": "Cubo de comida", "position": [-2.45, 0.0, -1.4], "use": "Comer una racion si existe"},
        "bed": {"label": "Cubo de sueño", "position": [0.0, 0.0, -1.4], "use": "Dormir durante un periodo"},
        "toilet": {"label": "Cubo de vejiga", "position": [2.45, 0.0, -1.4], "use": "Utilizar el vater"},
        "center": {"label": "Centro de la habitacion", "position": [0.0, 0.0, 1.15], "use": "No se puede usar"}
    }
    return {
        "identidad_visible": "404",
        "habitacion": "Habitacion experimental unica con tres cubos",
        "modelo_visual": "Pomi V05; sin esqueleto articulado de manos o rostro",
        "posicion_actual": [pomi.position.x, pomi.position.y, pomi.position.z],
        "en_movimiento": moving,
        "ultimo_resultado_del_mundo": last_result,
        "objetos_detectados": objects,
        "sensaciones_corporales": body.observation(),
        "capacidades": ["move", "use", "inspect", "wait", "none"],
        "limitaciones": ["no mover huesos individuales", "no simular gestos por texto", "no inventar objetos"]
    }

func _start_decision(trigger: String, note: String) -> void:
    if brain == null or bool(brain.get("pending")):
        return
    var memory_query := note
    var relevant: Array[Dictionary] = journal.recall(memory_query, 6)
    if brain.call("deliberate", _observation(), relevant, trigger + ": " + note):
        next_thought_at = elapsed_real + autonomy_interval

func _send_chat(message: String) -> void:
    var clean: String = message.strip_edges()
    if clean.is_empty():
        return
    chat_input.clear()
    _say("Tú: " + clean)
    journal.record("player_utterance", clean, body.day_index(), body.clock_text())
    queued_chat.append(clean)
    if brain != null and bool(brain.get("pending")):
        # Prioridad humana: cancelar una reflexión autónoma para poder atender el chat.
        if bool(brain.call("cancel_autonomous_for_chat")):
            _event("Reflexión autónoma interrumpida para atender tu mensaje.")
    if brain != null and not bool(brain.get("pending")) and not moving:
        chat_retry_at = elapsed_real
        _dispatch_chat()

func _dispatch_chat() -> void:
    if queued_chat.is_empty() or bool(brain.get("pending")):
        return
    var message: String = queued_chat[0]
    _start_decision("mensaje_del_interlocutor", "La otra persona ha dicho: " + message)
    if brain != null and bool(brain.get("pending")):
        queued_chat.pop_front()
    else:
        chat_retry_at = elapsed_real + 8.0
        _event("No se pudo enviar el mensaje; sigue en cola para reintentar.")

func _request_observation() -> void:
    if brain != null and not bool(brain.get("pending")):
        _start_decision("observacion_del_entorno", "Observa tus condiciones y reflexiona sobre lo que te parece importante.")

func _on_decision(decision: Dictionary) -> void:
    var spoken: String = str(decision.get("speech", "")).strip_edges()
    if not spoken.is_empty():
        _say("404: " + spoken)
        journal.record("pomi_utterance", spoken, body.day_index(), body.clock_text())
    elif str(decision.get("_origin", "")) == "direct_message":
        # Un JSON válido puede expresar silencio; hacerlo visible como estado
        # técnico, no fabricar una frase atribuida a 404 ni guardarla como diálogo.
        _say("[Sistema: 404 no ha emitido ninguna respuesta verbal.]")
        _event("Ministral devolvió speech vacío al responder un mensaje. Se ejecutará su acción si es válida.")
    var reflection: String = str(decision.get("reflection", "")).strip_edges()
    if not reflection.is_empty():
        journal.record("private_reflection", reflection, body.day_index(), body.clock_text())
    var requested_action: String = str(decision.get("action", "none"))
    var requested_target: String = str(decision.get("target", "none"))
    _execute_proposal(requested_action, requested_target)
    call_deferred("_continue_dialogue")

func _continue_dialogue() -> void:
    if not queued_chat.is_empty() and brain != null and not bool(brain.get("pending")) and not moving and elapsed_real >= chat_retry_at:
        _dispatch_chat()

func _execute_proposal(action: String, target: String) -> void:
    if action == "none" or action == "wait":
        return
    if not targets.has(target):
        _result("404 pidió un objetivo que no existe: " + target)
        return
    if action == "inspect":
        var distance: float = pomi.position.distance_to(targets[target])
        if distance > 2.8:
            _result("404 intentó inspeccionar %s, pero estaba demasiado lejos." % target)
        else:
            _result("Observación del objeto %s: %s; distancia %.1f metros." % [target, JSON.stringify(_observation()["objetos_detectados"][target]), distance])
        return
    if action == "use" and target == "center":
        _result("404 intentó utilizar el centro de la sala, pero no es un objeto utilizable.")
        return
    if body.movement_factor() <= 0.0:
        _result("404 no pudo moverse: su estado físico no se lo permite.")
        return
    if action != "move" and action != "use":
        _result("Se rechazó una acción inexistente.")
        return
    walk_target = targets[target]
    active_destination = target
    use_after_walk = target if action == "use" else ""
    moving = true
    _event("404 decidió desplazarse hacia %s." % target)

func _update_walk(delta: float) -> void:
    if not moving:
        return
    var vector: Vector3 = walk_target - pomi.position
    if vector.length() < 0.06:
        pomi.position = walk_target
        moving = false
        var destination: String = active_destination
        active_destination = ""
        var should_use: String = use_after_walk
        use_after_walk = ""
        if should_use.is_empty():
            _result("404 llegó a %s." % destination)
        else:
            var outcome: Dictionary = body.interact(should_use)
            _result(str(outcome.get("event", "Sin resultado.")))
        return
    var speed: float = 1.65 * body.movement_factor()
    var step: float = minf(speed * delta, vector.length())
    if step <= 0.0:
        moving = false
        _result("404 no pudo continuar caminando por su estado físico.")
        return
    var direction: Vector3 = vector.normalized()
    pomi.position += direction * step
    if avatar != null:
        avatar.rotation.y = lerp_angle(avatar.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 5.0))

func _result(message: String) -> void:
    last_result = message
    _event(message)
    journal.record("world_event", message, body.day_index(), body.clock_text())
    next_thought_at = minf(next_thought_at, elapsed_real + 2.0)

func _on_brain_error(message: String) -> void:
    _event("Error de inferencia: " + message)
    chat_retry_at = elapsed_real + 8.0
    next_thought_at = elapsed_real + autonomy_interval
    # Evitar un ciclo de reintentos en el mismo fotograma cuando falla la conexión.
    call_deferred("_continue_dialogue")

func _on_brain_metrics(details: String) -> void:
    if world_log != null:
        world_log.add_text("[Inferencia] " + details + "\n")

func _restock_food() -> void:
    # Mantenimiento explícito del usuario, no una decisión voluntaria de 404.
    body.food_units += 12
    _result("Intervención externa verificada: se añadieron 12 raciones de alimento.")
    _write_state(false)
    _refresh_status()


func _restore_404_health() -> void:
    # El prototipo necesita herramientas de recuperación mientras desarrollamos la IA.
    body.health = 100.0
    body.satiety = maxf(body.satiety, 75.0)
    body.energy = maxf(body.energy, 75.0)
    body.bladder_relief = maxf(body.bladder_relief, 75.0)
    _result("Intervención externa verificada: cuidados de emergencia restauraron la salud y las reservas fisiológicas de 404.")
    _write_state(false)
    _refresh_status()


func _toggle_simulation_pause() -> void:
    simulation_paused = not simulation_paused
    if simulation_pause_button != null:
        simulation_pause_button.text = "Reanudar tiempo" if simulation_paused else "Pausar tiempo"
    _event("Tiempo corporal pausado." if simulation_paused else "Tiempo corporal reanudado.")
    _refresh_status()


func _toggle_autonomy() -> void:
    autonomy_enabled = not autonomy_enabled
    autonomy_button.text = "Pausar iniciativa" if autonomy_enabled else "Reanudar iniciativa"
    next_thought_at = elapsed_real + 5.0
    _refresh_status()

func _write_state(show_notice: bool) -> void:
    var data: Dictionary = {
        "save_version": 2,
        "name": "404",
        "body": body.to_dict(),
        "position": [pomi.position.x, pomi.position.y, pomi.position.z],
        "last_world_result": last_result
    }
    var file := FileAccess.open(SAVE_V2, FileAccess.WRITE)
    if file == null:
        if show_notice:
            _event("No se pudo guardar la partida V2.")
        return
    file.store_string(JSON.stringify(data, "  "))
    file.close()
    if show_notice:
        _event("Estado de 404 guardado en un archivo V2 independiente.")

func _save_state() -> void:
    _write_state(true)

func _reload_state() -> void:
    _restore_from_disk()
    moving = false
    use_after_walk = ""
    active_destination = ""
    _event("Estado corporal y posicion recuperados. El diario autobiografico permanece intacto.")

func _restore_from_disk() -> void:
    if FileAccess.file_exists(SAVE_V2):
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_V2))
        if data is Dictionary and int(data.get("save_version", 0)) == 2:
            body.restore(data.get("body", {}))
            _restore_position(data.get("position", []))
            last_result = str(data.get("last_world_result", last_result))
            return
    # Importacion compatible: se LEE la partida antigua sin alterarla.
    if FileAccess.file_exists(SAVE_V1):
        var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_V1))
        if data is Dictionary:
            body.import_legacy(data)
            _restore_position(data.get("pomi_position", []))
            journal.import_legacy_conversation(data.get("conversation", []), body.day_index(), body.clock_text())

func _restore_position(value: Variant) -> void:
    if value is Array and value.size() == 3:
        pomi.position = Vector3(
            clampf(float(value[0]), -3.4, 3.4),
            0.0,
            clampf(float(value[2]), -2.3, 2.5)
        )

func _backup_memory() -> void:
    var result: String = journal.backup()
    if result.is_empty():
        _event("No se pudo copiar la memoria; comprueba el diario.")
    else:
        if world_log != null:
            world_log.add_text("Copia de la memoria: " + result + "\n")
