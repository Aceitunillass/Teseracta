extends Node3D
## Teseracta ZERO — interfaz, visualización y orquestación.
## La física, las memorias y las solicitudes a Ollama están separadas.

const WorldScript = preload("res://scripts/world.gd")
const MemoryScript = preload("res://scripts/memory.gd")
const BrainScript = preload("res://scripts/brain.gd")

var world = WorldScript.new()
var memory = MemoryScript.new()
var brain: Node
var avatar: MeshInstance3D
var objects_root: Node3D
var status_line: Label
var dialogue: RichTextLabel
var message_input: LineEdit
var prompt_edit: TextEdit
var model_input: LineEdit
var memory_edit: TextEdit
var debug_display: RichTextLabel
var editor_choice: OptionButton
var palette_choice: OptionButton
var material_choice: OptionButton
var editor_name: LineEdit
var editor_numbers: Dictionary = {}
var autonomy_button: Button
var confirm_clear: ConfirmationDialog
var queued_messages: Array[String] = []
var active_direct_message: String = ""
var next_chat_retry: float = 0.0
var debug_lines: Array[String] = []
var partial_speech: String = ""
var shown_partial: String = ""
var next_visual_update_ms: int = 0
var autonomy_enabled: bool = true
var autonomous_next: float = 18.0
var elapsed: float = 0.0
var physics_accumulator: float = 0.0
var status_accumulator: float = 0.0


func _ready() -> void:
    var saved: Variant = memory.load_world()
    if saved != null:
        if not world.restore_snapshot(saved):
            push_warning("La partida nueva no pudo restaurarse; se usará el mundo inicial.")
    _create_room()
    brain = BrainScript.new()
    add_child(brain)
    brain.partial_speech.connect(_on_partial_speech)
    brain.finished.connect(_on_reply)
    brain.failed.connect(_on_brain_error)
    brain.metrics.connect(_on_metrics)
    _create_ui()
    _refresh_chat()
    _refresh_debug()
    _update_status()


func _create_room() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#161B29")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    environment.environment = env
    add_child(environment)

    _static_cube("Suelo", Vector3(0, -0.18, 0), Vector3(8.1, 0.30, 6.3), Color("#48506B"))
    _static_cube("Pared norte", Vector3(0, 1.35, -3.12), Vector3(8.1, 2.7, 0.16), Color("#313B55"))
    _static_cube("Pared izquierda", Vector3(-4.00, 1.35, 0), Vector3(0.16, 2.7, 6.3), Color("#323C58"))
    _static_cube("Pared derecha", Vector3(4.00, 1.35, 0), Vector3(0.16, 2.7, 6.3), Color("#323C58"))
    objects_root = Node3D.new()
    objects_root.name = "ObjetosEditor"
    add_child(objects_root)

    avatar = MeshInstance3D.new()
    avatar.name = "404_Cubo"
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(0.55, 0.7, 0.55)
    avatar.mesh = body_mesh
    avatar.material_override = _material(Color("#F1A0BA"), 0.0)
    add_child(avatar)
    _refresh_meshes()

    var camera := Camera3D.new()
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 9.4
    camera.position = Vector3(8.0, 10.0, 10.0)
    add_child(camera)
    camera.look_at(Vector3(0, 0.6, 0))
    camera.current = true


func _material(tint: Color, transmission: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if transmission > 0.01:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        tint.a = 1.0 - 0.7 * clampf(transmission, 0.0, 1.0)
    mat.albedo_color = tint
    return mat


func _static_cube(label: String, where: Vector3, size: Vector3, tint: Color) -> void:
    var mesh := MeshInstance3D.new()
    mesh.name = label
    var box := BoxMesh.new()
    box.size = size
    mesh.mesh = box
    mesh.position = where
    mesh.material_override = _material(tint, 0.0)
    add_child(mesh)


func _refresh_meshes() -> void:
    if objects_root == null:
        return
    for child in objects_root.get_children():
        child.queue_free()
    for obj in world.objects:
        var mesh := MeshInstance3D.new()
        mesh.name = str(obj["id"])
        var box := BoxMesh.new()
        box.size = Vector3(float(obj["width"]), float(obj["height"]), float(obj["depth"]))
        mesh.mesh = box
        mesh.position = Vector3(float(obj["x"]), float(obj["height"]) * 0.5, float(obj["z"]))
        mesh.material_override = _material(world.palette_color(str(obj["palette"])), float(obj["transmission"]))
        objects_root.add_child(mesh)
    avatar.position = world.agent_position + Vector3(0.0, 0.38, 0.0)


func _button(label_text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label_text
    button.pressed.connect(callback)
    return button


func _label(parent: Node, content: String) -> Label:
    var item := Label.new()
    item.text = content
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(item)
    return item


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
    var root := VBoxContainer.new()
    root.name = title
    root.add_theme_constant_override("separation", 7)
    tabs.add_child(root)
    return root


func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var sidebar := PanelContainer.new()
    sidebar.anchor_left = 1.0
    sidebar.anchor_right = 1.0
    sidebar.anchor_top = 0.0
    sidebar.anchor_bottom = 1.0
    sidebar.offset_left = -468
    sidebar.offset_right = -10
    sidebar.offset_top = 10
    sidebar.offset_bottom = -10
    var background := StyleBoxFlat.new()
    background.bg_color = Color("#192033")
    background.border_color = Color("#64718B")
    background.border_width_left = 1
    sidebar.add_theme_stylebox_override("panel", background)
    layer.add_child(sidebar)

    var margins := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 10)
    sidebar.add_child(margins)

    var layout := VBoxContainer.new()
    margins.add_child(layout)
    _label(layout, "TESERACTA · ZERO | 404-CUBO")
    status_line = _label(layout, "")
    var tabs := TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(tabs)

    _build_chat_tab(_tab(tabs, "Chat"))
    _build_editor_tab(_tab(tabs, "Editor"))
    _build_agent_tab(_tab(tabs, "Agente"))
    _build_memory_tab(_tab(tabs, "Memoria"))
    _build_debug_tab(_tab(tabs, "Registro"))


func _build_chat_tab(root: VBoxContainer) -> void:
    _label(root, "Las frases no ejecutan acciones: 404 envía comandos aparte.")
    dialogue = RichTextLabel.new()
    dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dialogue.scroll_following = true
    root.add_child(dialogue)

    message_input = LineEdit.new()
    message_input.placeholder_text = "Hablar con 404..."
    message_input.text_submitted.connect(_send_message)
    root.add_child(message_input)
    var buttons := HBoxContainer.new()
    root.add_child(buttons)
    buttons.add_child(_button("Enviar", func(): _send_message(message_input.text)))
    buttons.add_child(_button("Observar / decidir", _request_autonomous))
    buttons.add_child(_button("Detener", _ask_stop))


func _editor_number(parent: VBoxContainer, key: String, title: String, low: float, high: float, step: float) -> void:
    var line := HBoxContainer.new()
    parent.add_child(line)
    var name_label := _label(line, title)
    name_label.custom_minimum_size.x = 160
    var field := SpinBox.new()
    field.min_value = low
    field.max_value = high
    field.step = step
    field.allow_greater = false
    field.allow_lesser = false
    field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    line.add_child(field)
    editor_numbers[key] = field


func _build_editor_tab(root: VBoxContainer) -> void:
    _label(root, "Editor inicial: cubos con parámetros. Paredes fijas en esta versión.")
    var choice_row := HBoxContainer.new()
    root.add_child(choice_row)
    editor_choice = OptionButton.new()
    editor_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    editor_choice.item_selected.connect(_on_object_selected)
    choice_row.add_child(editor_choice)
    choice_row.add_child(_button("+ Cubo", _editor_add_box))
    choice_row.add_child(_button("Eliminar", _editor_delete_box))

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    root.add_child(scroll)
    var fields := VBoxContainer.new()
    fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(fields)

    _label(fields, "Nombre del objeto")
    editor_name = LineEdit.new()
    fields.add_child(editor_name)
    _editor_number(fields, "x", "Posición X", -3.4, 3.4, 0.1)
    _editor_number(fields, "z", "Posición Z", -2.4, 2.4, 0.1)
    _editor_number(fields, "width", "Anchura", 0.15, 3.0, 0.05)
    _editor_number(fields, "height", "Altura", 0.15, 2.5, 0.05)
    _editor_number(fields, "depth", "Profundidad", 0.15, 3.0, 0.05)

    _label(fields, "Familia de paleta cromática (variantes tonales después)")
    palette_choice = OptionButton.new()
    fields.add_child(palette_choice)
    for color in WorldScript.PALETTES.keys():
        palette_choice.add_item(str(color))

    _label(fields, "Material sensorial")
    material_choice = OptionButton.new()
    fields.add_child(material_choice)
    for kind in WorldScript.MATERIALS:
        material_choice.add_item(kind)
    _editor_number(fields, "roughness", "Rugosidad", 0.0, 1.0, 0.05)
    _editor_number(fields, "transmission", "Transparencia", 0.0, 1.0, 0.05)
    _editor_number(fields, "temperature_c", "Temperatura °C", -50.0, 150.0, 1.0)

    var actions := HBoxContainer.new()
    root.add_child(actions)
    actions.add_child(_button("Aplicar cambios", _editor_apply))
    actions.add_child(_button("Guardar mundo", _save_world))
    actions.add_child(_button("Restablecer mundo", _reset_world))
    _refresh_object_choices()


func _build_agent_tab(root: VBoxContainer) -> void:
    _label(root, "Prompt inicial editable (archivo NUEVO, sin biografía anterior).")
    prompt_edit = TextEdit.new()
    prompt_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    prompt_edit.text = memory.prompt
    root.add_child(prompt_edit)
    root.add_child(_button("Guardar prompt", _save_prompt))
    _label(root, "Modelo de Ollama")
    model_input = LineEdit.new()
    model_input.text = memory.model
    root.add_child(model_input)
    root.add_child(_button("Guardar modelo", _save_model))
    autonomy_button = _button("Pausar iniciativa", _toggle_autonomy)
    root.add_child(autonomy_button)


func _build_memory_tab(root: VBoxContainer) -> void:
    _label(root, "Memorias NUEVAS en JSON editable. Nunca importamos el diario anterior.")
    memory_edit = TextEdit.new()
    memory_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    memory_edit.text = memory.memory_json()
    root.add_child(memory_edit)
    var actions := HBoxContainer.new()
    root.add_child(actions)
    actions.add_child(_button("Recargar", _reload_memory_editor))
    actions.add_child(_button("Guardar edición", _save_memory_editor))
    actions.add_child(_button("Vaciar", _confirm_clear_memory))
    confirm_clear = ConfirmationDialog.new()
    confirm_clear.dialog_text = "¿Borrar todas las NUEVAS memorias de 404 de Teseracta ZERO?"
    confirm_clear.confirmed.connect(_clear_new_memory)
    add_child(confirm_clear)


func _build_debug_tab(root: VBoxContainer) -> void:
    _label(root, "Resultados físicos verificados, propuestas y notas declaradas del modelo. No son pensamientos ocultos.")
    debug_display = RichTextLabel.new()
    debug_display.scroll_following = true
    debug_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(debug_display)
    root.add_child(_button("Actualizar registro", _refresh_debug))


func _select_option(choice: OptionButton, value: String) -> void:
    for i in range(choice.item_count):
        if choice.get_item_text(i) == value:
            choice.select(i)
            return


func _refresh_object_choices() -> void:
    if editor_choice == null:
        return
    var wanted: int = editor_choice.selected
    editor_choice.clear()
    for obj in world.objects:
        editor_choice.add_item("%s [%s]" % [str(obj["name"]), str(obj["id"])])
    if world.objects.is_empty():
        return
    editor_choice.select(clampi(wanted, 0, world.objects.size() - 1))
    _on_object_selected(editor_choice.selected)


func _on_object_selected(index: int) -> void:
    if index < 0 or index >= world.objects.size():
        return
    var obj: Dictionary = world.objects[index]
    editor_name.text = str(obj["name"])
    for key in editor_numbers:
        var spin: SpinBox = editor_numbers[key]
        spin.value = float(obj[key])
    _select_option(palette_choice, str(obj["palette"]))
    _select_option(material_choice, str(obj["material"]))


func _editor_apply() -> void:
    var index: int = editor_choice.selected
    if index < 0:
        return
    var update: Dictionary = {"name": editor_name.text.strip_edges()}
    for key in editor_numbers:
        var spin: SpinBox = editor_numbers[key]
        update[key] = spin.value
    update["palette"] = palette_choice.get_item_text(palette_choice.selected)
    update["material"] = material_choice.get_item_text(material_choice.selected)
    if not world.update_box(index, update):
        _debug("Editor: datos no válidos.")
        return
    _refresh_meshes()
    _save_world()
    _refresh_object_choices()
    _drain_world_events()


func _editor_add_box() -> void:
    world.add_box()
    _refresh_meshes()
    _refresh_object_choices()
    editor_choice.select(world.objects.size() - 1)
    _on_object_selected(editor_choice.selected)
    _save_world()
    _drain_world_events()


func _editor_delete_box() -> void:
    world.remove_box(editor_choice.selected)
    _refresh_meshes()
    _refresh_object_choices()
    _save_world()
    _drain_world_events()


func _save_world() -> void:
    _debug("Mundo guardado." if memory.save_world(world.snapshot()) else "No se pudo guardar el mundo.")


func _reset_world() -> void:
    world.reset()
    _refresh_meshes()
    _refresh_object_choices()
    _save_world()
    _debug("Mundo ZERO restablecido. No se ha borrado la memoria.")


func _save_prompt() -> void:
    _debug("Prompt guardado." if memory.save_prompt(prompt_edit.text) else "Prompt vacío o no se pudo guardar.")


func _save_model() -> void:
    _debug("Modelo guardado." if memory.save_model(model_input.text) else "Modelo inválido.")


func _toggle_autonomy() -> void:
    autonomy_enabled = not autonomy_enabled
    autonomy_button.text = "Pausar iniciativa" if autonomy_enabled else "Reanudar iniciativa"
    autonomous_next = elapsed + 10.0
    _update_status()


func _reload_memory_editor() -> void:
    memory_edit.text = memory.memory_json()


func _save_memory_editor() -> void:
    _debug("Memorias editadas y guardadas." if memory.replace_edited_memories(memory_edit.text) else "JSON de memoria inválido: no se ha guardado.")


func _confirm_clear_memory() -> void:
    confirm_clear.popup_centered()


func _clear_new_memory() -> void:
    if memory.clear_memory():
        memory_edit.text = memory.memory_json()
        _debug("Memorias NUEVAS de 404 borradas.")
        _refresh_chat()


func _debug(text: String) -> void:
    debug_lines.append(text)
    if debug_lines.size() > 80:
        debug_lines.pop_front()
    _refresh_debug()


func _refresh_debug() -> void:
    if debug_display == null:
        return
    var content: PackedStringArray = []
    for event in memory.recent_verified_events(25):
        content.append("[MUNDO tick %s / %s] %s" % [
            str(event.get("tick", "?")), str(event.get("kind", "?")), str(event.get("detail", ""))
        ])
    for entry in memory.entries:
        if str(entry.get("kind", "")) == "reflection":
            content.append("[REFLEXIÓN DECLARADA] " + str(entry.get("text", "")))
    for line in debug_lines:
        content.append("[SISTEMA] " + line)
    debug_display.text = "\n\n".join(content)


func _refresh_chat() -> void:
    if dialogue == null:
        return
    var lines: PackedStringArray = []
    var starting: int = maxi(0, memory.entries.size() - 40)
    for i in range(starting, memory.entries.size()):
        var entry: Dictionary = memory.entries[i]
        var kind: String = str(entry.get("kind", ""))
        if kind == "user":
            lines.append("Tú: " + str(entry.get("text", "")))
        elif kind == "agent":
            lines.append("404: " + str(entry.get("text", "")))
    if not shown_partial.is_empty():
        lines.append("404: " + shown_partial)
    dialogue.text = "\n\n".join(lines)


func _send_message(content: String) -> void:
    var cleaned: String = content.strip_edges()
    if cleaned.is_empty():
        return
    message_input.clear()
    memory.record("user", cleaned)
    _refresh_chat()
    queued_messages.append(cleaned)
    if brain.pending and brain.cancel_autonomous():
        shown_partial = ""
        partial_speech = ""
        _refresh_chat()
        _debug("Deliberación autónoma cancelada para atender al usuario.")
    _send_next_if_possible()


func _send_next_if_possible() -> void:
    if brain.pending or queued_messages.is_empty() or elapsed < next_chat_retry:
        return
    var content: String = queued_messages[0]
    if _begin_request(content, false):
        active_direct_message = content
        queued_messages.pop_front()
    else:
        next_chat_retry = elapsed + 8.0


func _begin_request(message: String, autonomous: bool) -> bool:
    if brain.pending:
        return false
    var history: Array[Dictionary] = memory.dialogue_history(8)
    if not autonomous and not history.is_empty():
        if str(history[-1].get("role", "")) == "user" and str(history[-1].get("content", "")) == message.substr(0, 400):
            history.pop_back()
    var started: bool = brain.request(memory.prompt, memory.model, world.action_api(), world.observe(), history, memory.recent_verified_events(5), message, autonomous)
    if started:
        autonomous_next = elapsed + 35.0
    return started


func _request_autonomous() -> void:
    _begin_request("", true)


func _ask_stop() -> void:
    # Botón de control de depuración humano, distinto de una decisión de 404.
    var outcome: Dictionary = world.submit_action({"type": "Stop", "data": {}})
    _debug("Orden externa de parar: " + str(outcome.get("message", "")))
    _drain_world_events()


func _on_partial_speech(text: String) -> void:
    partial_speech = text
    if next_visual_update_ms == 0:
        next_visual_update_ms = Time.get_ticks_msec() + 650


func _on_reply(result: Dictionary) -> void:
    active_direct_message = ""
    partial_speech = ""
    shown_partial = ""
    next_visual_update_ms = 0
    var words: String = str(result.get("speech", "")).strip_edges()
    var note: String = str(result.get("reflection", "")).strip_edges()
    if not words.is_empty():
        memory.record("agent", words)
    if not note.is_empty():
        memory.record("reflection", note)
    _refresh_chat()
    var action: Variant = result.get("action", {"type": "Wait", "data": {}})
    if action is Dictionary:
        _debug("404 propuso: " + JSON.stringify(action))
        var verdict: Dictionary = world.submit_action(action)
        _debug("Respuesta del mundo: " + str(verdict.get("message", "")))
        _drain_world_events()
    _send_next_if_possible()


func _on_brain_error(reason: String) -> void:
    partial_speech = ""
    shown_partial = ""
    next_visual_update_ms = 0
    _refresh_chat()
    _debug("Error del modelo: " + reason)
    if not active_direct_message.is_empty():
        queued_messages.push_front(active_direct_message)
        active_direct_message = ""
        next_chat_retry = elapsed + 8.0
        _debug("Mensaje conservado; reintento en al menos 8 s.")
    autonomous_next = elapsed + 35.0


func _on_metrics(details: String) -> void:
    _debug("Inferencia: " + details)


func _drain_world_events() -> void:
    var new_events: Array[Dictionary] = world.drain_events()
    if new_events.is_empty():
        return
    for item in new_events:
        memory.record_event(item)
    _refresh_debug()


func _physics_process(delta: float) -> void:
    physics_accumulator += delta
    while physics_accumulator >= 0.1:
        world.step(0.1)
        physics_accumulator -= 0.1
    if avatar != null:
        avatar.position = world.agent_position + Vector3(0.0, 0.38, 0.0)
    _drain_world_events()


func _process(delta: float) -> void:
    elapsed += delta
    status_accumulator += delta
    if status_accumulator >= 0.5:
        status_accumulator = 0.0
        _update_status()
    if not partial_speech.is_empty() and Time.get_ticks_msec() >= next_visual_update_ms:
        if partial_speech != shown_partial:
            shown_partial = partial_speech
            _refresh_chat()
        next_visual_update_ms = Time.get_ticks_msec() + 650
    if not brain.pending:
        if not queued_messages.is_empty():
            _send_next_if_possible()
        elif autonomy_enabled and elapsed >= autonomous_next:
            if not _begin_request("", true):
                autonomous_next = elapsed + 35.0


func _update_status() -> void:
    if status_line == null:
        return
    var model_status: String = "procesando %.0f s" % brain.elapsed_seconds() if brain != null and brain.pending else "disponible"
    status_line.text = "Tick %d · 404 (%.2f, %.2f) · %s\n%s · autonomía %s" % [
        world.ticks, world.agent_position.x, world.agent_position.z,
        "caminando" if world.moving else "parado", model_status,
        "activa" if autonomy_enabled else "pausada"
    ]
