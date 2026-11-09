extends RefCounted
## Teseracta ZERO: mundo físico autoritativo, independiente del modelo LLM.
## No decide acciones voluntarias, solo valida, ejecuta y observa.

const X_MIN := -3.30
const X_MAX := 3.30
const Z_MIN := -2.35
const Z_MAX := 2.35
const WALK_SPEED := 1.70
const PALETTES := {
    "marron": "#A47B56",
    "turquesa": "#65C4BE",
    "rosa": "#DB94B7",
    "gris": "#929AB0",
    "verde": "#83B88B",
    "violeta": "#AD98D9"
}
const MATERIALS := ["madera", "metal", "cristal", "piedra", "tela", "plastico", "hierba"]

var objects: Array[Dictionary] = []
var agent_position: Vector3 = Vector3(0.0, 0.0, 1.6)
var destination: Vector3 = Vector3.ZERO
var journey_origin: Vector3 = Vector3.ZERO
var moving: bool = false
var ticks: int = 0
var messages: Array[Dictionary] = []
var sequence: int = 0


func _init() -> void:
    reset()


func reset() -> void:
    ticks = 0
    sequence = 0
    moving = false
    agent_position = Vector3(0.0, 0.0, 1.6)
    destination = agent_position
    objects = [
        _new_box("food", "Cubo comida", -2.2, -1.45, "marron", "madera"),
        _new_box("bed", "Cubo descanso", 0.0, -1.45, "violeta", "tela"),
        _new_box("toilet", "Cubo aseo", 2.2, -1.45, "turquesa", "plastico")
    ]
    messages.clear()


func _new_box(id: String, label: String, x: float, z: float, palette: String, material: String) -> Dictionary:
    return {
        "id": id, "name": label, "shape": "box",
        "x": x, "z": z, "width": 0.85, "height": 0.9, "depth": 0.85,
        "palette": palette, "material": material,
        "roughness": 0.5, "transmission": 0.0, "temperature_c": 21.0
    }


func palette_color(name: String) -> Color:
    return Color(str(PALETTES.get(name, "#929AB0")))


func _event(kind: String, detail: String) -> void:
    messages.append({"tick": ticks, "kind": kind, "detail": detail})
    if messages.size() > 50:
        messages.pop_front()


func drain_events() -> Array[Dictionary]:
    var result: Array[Dictionary] = messages.duplicate(true)
    messages.clear()
    return result


func _valid_position(x: float, z: float) -> bool:
    if is_nan(x) or is_nan(z) or is_inf(x) or is_inf(z):
        return false
    if x < X_MIN or x > X_MAX or z < Z_MIN or z > Z_MAX:
        return false
    for obj in objects:
        if absf(x - float(obj["x"])) < float(obj["width"]) * 0.5 + 0.30 and absf(z - float(obj["z"])) < float(obj["depth"]) * 0.5 + 0.30:
            return false
    return true


func _find_object(object_id: String) -> Dictionary:
    for obj in objects:
        if str(obj.get("id", "")) == object_id:
            return obj
    return {}


func _distance_to(obj: Dictionary) -> float:
    return agent_position.distance_to(Vector3(float(obj["x"]), 0.0, float(obj["z"])))


func _segment_clear(start: Vector3, finish: Vector3) -> bool:
    # Aceptar destinos accesibles, no atravesar cubos en una trayectoria recta.
    var count: int = maxi(1, ceili(start.distance_to(finish) / 0.12))
    for i in range(1, count + 1):
        var sample: Vector3 = start.lerp(finish, float(i) / float(count))
        if not _valid_position(sample.x, sample.z):
            return false
    return true


func _approach_object(obj: Dictionary) -> Variant:
    # Convertir un ID observable a una posición libre al alcance del objeto.
    var x: float = float(obj["x"])
    var z: float = float(obj["z"])
    var clearance_x: float = float(obj["width"]) * 0.5 + 0.40
    var clearance_z: float = float(obj["depth"]) * 0.5 + 0.40
    var candidates: Array[Vector3] = [
        Vector3(x, 0.0, z + clearance_z),
        Vector3(x, 0.0, z - clearance_z),
        Vector3(x + clearance_x, 0.0, z),
        Vector3(x - clearance_x, 0.0, z)
    ]
    var closest_distance: float = INF
    var selected: Variant = null
    for point in candidates:
        if not _valid_position(point.x, point.z):
            continue
        if not _segment_clear(agent_position, point):
            continue
        var distance: float = agent_position.distance_to(point)
        if distance < closest_distance:
            selected = point
            closest_distance = distance
    return selected


func action_api() -> Dictionary:
    return {
        "name": "Teseracta ZERO World Protocol",
        "version": 1,
        "actions": {
            "MoveTo": {"data": {"position": "[x,z] para un punto libre", "id": "ID de objeto visible para acercarse a él (alternativa a position)"}, "rule": "Usa SOLO position O id. Con id Godot calcula un punto cercano transitable; no utiliza el objeto."},
            "Stop": {},
            "Inspect": {"id": "Identificador de un objeto visible y cercano"},
            "Use": {"id": "Identificador de un objeto al alcance (distancia <= 1.25 m)"},
            "Wait": {}
        },
        "note": "Primero observa. El mundo decide si una acción funciona. No hace falta WASD ni una inferencia por fotograma."
    }


func observe() -> Dictionary:
    # MVP: proximidad espacial; aún no hay FOV, raycasts ni materiales ocultos.
    var seen: Array[Dictionary] = []
    for obj in objects:
        var distance: float = _distance_to(obj)
        if distance > 5.0:
            continue
        var item: Dictionary = {
            "id": obj["id"], "shape": "box",
            "relative_x": snappedf(float(obj["x"]) - agent_position.x, 0.01),
            "relative_z": snappedf(float(obj["z"]) - agent_position.z, 0.01),
            "distance": snappedf(distance, 0.01),
            "color_family": obj["palette"],
            "optical_transmission": obj["transmission"],
            "apparent_size": [obj["width"], obj["height"], obj["depth"]]
        }
        if distance < 1.25:
            item["contact_material"] = obj["material"]
            item["contact_roughness"] = obj["roughness"]
            item["contact_temperature_c"] = obj["temperature_c"]
        seen.append(item)
    return {
        "tick": ticks,
        "agent_id": "404",
        "position": [snappedf(agent_position.x, 0.01), snappedf(agent_position.z, 0.01)],
        "moving": moving,
        "destination": [destination.x, destination.z] if moving else [],
        "bounds": {"x": [X_MIN, X_MAX], "z": [Z_MIN, Z_MAX]},
        "visible_objects": seen,
        "perception_limit": "Proximidad geométrica inicial; no visión multimodal, FOV ni rayos todavía."
    }


func submit_action(command: Dictionary) -> Dictionary:
    var kind: String = str(command.get("type", "Wait"))
    var raw_data: Variant = command.get("data", {})
    var data: Dictionary = raw_data if raw_data is Dictionary else {}
    if kind == "Wait":
        return {"ok": true, "message": "Sin acción voluntaria."}
    if kind == "Stop":
        var was_moving: bool = moving
        moving = false
        _event("stop", "404 detuvo el desplazamiento." if was_moving else "404 solicitó detenerse cuando ya estaba parado.")
        return {"ok": true, "message": "Detenido."}
    if kind == "MoveTo":
        var chosen: Vector3 = Vector3.ZERO
        var label: String = ""
        if data.has("position") and data.has("id"):
            _event("rejected", "MoveTo rechazado: indicar position O id, no ambos.")
            return {"ok": false, "message": "Elige un solo tipo de destino: position o id."}
        if data.has("position"):
            var pos: Variant = data["position"]
            if not (pos is Array) or pos.size() != 2:
                _event("rejected", "MoveTo rechazado: position debe ser [x,z].")
                return {"ok": false, "message": "Formato incorrecto: position requiere [x,z]."}
            if not ((pos[0] is float or pos[0] is int) and (pos[1] is float or pos[1] is int)):
                _event("rejected", "MoveTo rechazado: coordenadas no numéricas.")
                return {"ok": false, "message": "Coordenadas no numéricas."}
            chosen = Vector3(float(pos[0]), 0.0, float(pos[1]))
            if not _valid_position(chosen.x, chosen.z):
                _event("rejected", "MoveTo rechazado: destino ocupado o fuera de los límites.")
                return {"ok": false, "message": "Destino ocupado o fuera de la habitación."}
            label = "punto (%.2f, %.2f)" % [chosen.x, chosen.z]
        elif data.has("id"):
            var object_id: String = str(data.get("id", ""))
            var target_object: Dictionary = _find_object(object_id)
            if target_object.is_empty():
                _event("rejected", "MoveTo rechazado: objeto desconocido '%s'." % object_id)
                return {"ok": false, "message": "No existe un objeto visible con ese ID."}
            var approach: Variant = _approach_object(target_object)
            if not (approach is Vector3):
                _event("rejected", "MoveTo rechazado: no hay camino recto libre hacia %s." % object_id)
                return {"ok": false, "message": "No existe una ruta recta despejada; prueba otro punto intermedio."}
            chosen = approach
            label = "objeto " + object_id
        else:
            _event("rejected", "MoveTo requiere data.position=[x,z] o data.id.")
            return {"ok": false, "message": "Falta destino: proporciona position=[x,z] o id."}
        if not _segment_clear(agent_position, chosen):
            _event("rejected", "MoveTo rechazado: hay un obstáculo en el camino a %s." % label)
            return {"ok": false, "message": "La trayectoria está bloqueada; solicita otro punto intermedio."}
        if agent_position.distance_to(chosen) < 0.08:
            _event("move_completed", "404 ya estaba al alcance de %s; desplazamiento 0.00 m." % label)
            return {"ok": true, "message": "404 ya está en el destino. Puede elegir otra acción."}
        destination = chosen
        journey_origin = agent_position
        moving = true
        _event("move_started", "404 empezó a caminar hacia %s, objetivo (%.2f, %.2f)." % [label, chosen.x, chosen.z])
        return {"ok": true, "message": "Movimiento hacia %s aceptado; resultado físico pendiente." % label}
    if kind == "Inspect" or kind == "Use":
        var object_id: String = str(data.get("id", ""))
        var obj: Dictionary = _find_object(object_id)
        if obj.is_empty():
            _event("rejected", "%s rechazado: objeto desconocido '%s'." % [kind, object_id])
            return {"ok": false, "message": "Objeto desconocido."}
        var distance: float = _distance_to(obj)
        var limit: float = 3.0 if kind == "Inspect" else 1.25
        if distance > limit:
            _event("rejected", "%s rechazado: %s a %.2f m, alcance %.2f m." % [kind, object_id, distance, limit])
            return {"ok": false, "message": "Objeto fuera de alcance."}
        if kind == "Inspect":
            _event("inspected", "404 examinó %s desde %.2f m." % [object_id, distance])
        else:
            _event("used", "404 utilizó %s. Todavía no hay metabolismo ni efecto de necesidad." % object_id)
        return {"ok": true, "message": "Acción verificada."}
    _event("rejected", "Acción desconocida: " + kind)
    return {"ok": false, "message": "Acción inexistente."}


func step(delta: float) -> void:
    ticks += 1
    if not moving:
        return
    var remaining: Vector3 = destination - agent_position
    if remaining.length() <= 0.015:
        agent_position = destination
        moving = false
        _event("move_completed", "Godot verificó que 404 recorrió %.2f metros hasta (%.2f, %.2f)." % [journey_origin.distance_to(agent_position), destination.x, destination.z])
        return
    var step_size: float = minf(WALK_SPEED * delta, remaining.length())
    var candidate: Vector3 = agent_position + remaining.normalized() * step_size
    if not _valid_position(candidate.x, candidate.z):
        moving = false
        _event("move_blocked", "404 se detuvo al encontrar un cubo u obstáculo en su trayectoria. Requiere otro itinerario.")
        return
    agent_position = candidate


func add_box() -> void:
    sequence += 1
    var object_id: String = "obj_%d" % sequence
    var obj: Dictionary = _new_box(object_id, "Objeto %d" % sequence, 1.0, 0.0, "rosa", "plastico")
    objects.append(obj)
    _event("editor", "El usuario creó un objeto con ID " + object_id)


func update_box(index: int, new_data: Dictionary) -> bool:
    if index < 0 or index >= objects.size():
        return false
    var obj: Dictionary = objects[index].duplicate(true)
    for key in ["name", "x", "z", "width", "height", "depth", "palette", "material", "roughness", "transmission", "temperature_c"]:
        if new_data.has(key):
            obj[key] = new_data[key]
    if not PALETTES.has(str(obj["palette"])) or not MATERIALS.has(str(obj["material"])):
        return false
    for key in ["x", "z", "width", "height", "depth", "roughness", "transmission", "temperature_c"]:
        var num: float = float(obj[key])
        if is_nan(num) or is_inf(num):
            return false
    if float(obj["width"]) < 0.15 or float(obj["height"]) < 0.15 or float(obj["depth"]) < 0.15:
        return false
    if absf(float(obj["x"])) > 3.4 or absf(float(obj["z"])) > 2.4:
        return false
    obj["roughness"] = clampf(float(obj["roughness"]), 0.0, 1.0)
    obj["transmission"] = clampf(float(obj["transmission"]), 0.0, 1.0)
    objects[index] = obj
    _event("editor", "Se modificó el objeto %s." % str(obj["id"]))
    return true


func remove_box(index: int) -> void:
    if index < 0 or index >= objects.size():
        return
    var id: String = str(objects[index]["id"])
    objects.remove_at(index)
    _event("editor", "El usuario eliminó el objeto " + id)


func snapshot() -> Dictionary:
    return {
        "version": 1,
        "ticks": ticks,
        "position": [agent_position.x, agent_position.z],
        "objects": objects.duplicate(true),
        "sequence": sequence
    }


func restore_snapshot(value: Variant) -> bool:
    if not (value is Dictionary) or int(value.get("version", -1)) != 1:
        return false
    var loaded: Variant = value.get("objects", [])
    if not (loaded is Array) or loaded.size() > 100:
        return false
    var validated: Array[Dictionary] = []
    for item in loaded:
        if not (item is Dictionary):
            return false
        if not item.has("id") or not item.has("x") or not item.has("z") or not item.has("palette"):
            return false
        validated.append(item.duplicate(true))
    objects = validated
    ticks = maxi(0, int(value.get("ticks", 0)))
    sequence = maxi(0, int(value.get("sequence", 0)))
    var position: Variant = value.get("position", [0.0, 1.6])
    if position is Array and position.size() == 2:
        agent_position = Vector3(clampf(float(position[0]), X_MIN, X_MAX), 0.0, clampf(float(position[1]), Z_MIN, Z_MAX))
    destination = agent_position
    moving = false
    messages.clear()
    return true
