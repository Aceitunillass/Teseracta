extends RefCounted
## Fuente autoritativa: el LLM NO puede escribir aquí; solo acciones validadas.

const NEED_KEYS := ["hunger", "energy", "bladder", "hygiene", "fun"]
var needs: Dictionary = {"hunger": 82.0, "energy": 76.0, "bladder": 82.0, "hygiene": 80.0, "fun": 73.0}
var inventory: Dictionary = {"food": 12, "water": 40, "credits": 120}
var minutes: float = 8.0 * 60.0
var elapsed_real: float = 0.0
var paused: bool = false
var rate: float = 2.5 # minutos simulados por segundo real
var history: Array[String] = []
var action_count: int = 0

func tick(delta: float) -> void:
    if paused:
        return
    elapsed_real += delta
    minutes += delta * rate
    var step := delta * rate
    needs["hunger"] = clampf(float(needs["hunger"]) - 0.125 * step, 0, 100)
    needs["energy"] = clampf(float(needs["energy"]) - 0.075 * step, 0, 100)
    needs["bladder"] = clampf(float(needs["bladder"]) - 0.13 * step, 0, 100)
    needs["hygiene"] = clampf(float(needs["hygiene"]) - 0.05 * step, 0, 100)
    needs["fun"] = clampf(float(needs["fun"]) - 0.07 * step, 0, 100)

func mood() -> float:
    var sum: float = 0.0
    for k in NEED_KEYS:
        sum += float(needs[k])
    return sum / float(NEED_KEYS.size())

func clock_text() -> String:
    var h := int(minutes / 60.0) % 24
    var m := int(minutes) % 60
    return "%02d:%02d" % [h, m]

func day_index() -> int:
    return int(minutes / 1440.0) + 1

func propose_action() -> String:
    # Utilidad: el déficit determina la urgencia, con prerrequisitos reales.
    var options := {
        "eat": 100.0 - float(needs["hunger"]) if int(inventory["food"]) > 0 else -1.0,
        "sleep": 100.0 - float(needs["energy"]),
        "toilet": 100.0 - float(needs["bladder"]),
        "shower": 100.0 - float(needs["hygiene"]) if int(inventory["water"]) > 0 else -1.0,
        "relax": 100.0 - float(needs["fun"])
    }
    var best := "relax"
    var high: float = -999.0
    for name in options.keys():
        var utility := float(options[name])
        if utility > high:
            best = name
            high = utility
    return best

func execute_action(action_name: String) -> String:
    var message := ""
    match action_name:
        "eat":
            if int(inventory["food"]) <= 0:
                return "No queda comida en la nevera."
            inventory["food"] = int(inventory["food"]) - 1
            needs["hunger"] = clampf(float(needs["hunger"]) + 35, 0, 100)
            message = "He comido algo de la nevera."
        "sleep":
            needs["energy"] = clampf(float(needs["energy"]) + 45, 0, 100)
            message = "He descansado en mi cama."
        "toilet":
            needs["bladder"] = clampf(float(needs["bladder"]) + 65, 0, 100)
            message = "He ido al baño."
        "shower":
            if int(inventory["water"]) <= 0:
                return "No queda agua disponible."
            inventory["water"] = int(inventory["water"]) - 1
            needs["hygiene"] = clampf(float(needs["hygiene"]) + 65, 0, 100)
            message = "Me he dado una ducha."
        "relax":
            needs["fun"] = clampf(float(needs["fun"]) + 28, 0, 100)
            message = "He pasado un rato descansando en el sofá."
        _:
            return "Acción inexistente."
    action_count += 1
    remember(message)
    return message

func remember(event_text: String) -> void:
    history.append("Día %d %s — %s" % [day_index(), clock_text(), event_text])
    while history.size() > 40:
        history.pop_front()

func as_dict() -> Dictionary:
    return {"save_version": 1, "needs": needs.duplicate(true), "inventory": inventory.duplicate(true), "minutes": minutes, "history": history.duplicate(), "action_count": action_count}

func load_dict(data: Dictionary) -> bool:
    if int(data.get("save_version", 0)) != 1:
        return false
    if not (data.get("needs") is Dictionary and data.get("inventory") is Dictionary):
        return false
    var new_needs: Dictionary = data["needs"]
    var new_inventory: Dictionary = data["inventory"]
    for k in NEED_KEYS:
        if not new_needs.has(k):
            return false
        var v: float = float(new_needs[k])
        if not is_finite(v) or v < 0.0 or v > 100.0:
            return false
    for k in ["food", "water", "credits"]:
        if not new_inventory.has(k) or int(new_inventory[k]) < 0:
            return false
    needs = new_needs.duplicate(true)
    inventory = new_inventory.duplicate(true)
    minutes = maxf(0.0, float(data.get("minutes", 480.0)))
    action_count = maxi(0, int(data.get("action_count", 0)))
    history.clear()
    for record in data.get("history", []):
        history.append(str(record).substr(0, 200))
    while history.size() > 40:
        history.pop_front()
    return true
