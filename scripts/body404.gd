extends RefCounted
## Fisiologia causal de 404. GODOT es la fuente de verdad;
## la IA puede observar estas variables y pedir acciones, nunca editarlas.

var satiety: float = 75.0
var energy: float = 75.0
var bladder_relief: float = 75.0
var health: float = 100.0
var food_units: int = 12
var elapsed_minutes: float = 8.0 * 60.0
const MINUTES_PER_REAL_SECOND := 2.5

func _advance_minutes(minutes_elapsed: float) -> void:
    var minutes_passed: float = maxf(0.0, minutes_elapsed)
    elapsed_minutes += minutes_passed
    satiety = clampf(satiety - 0.10 * minutes_passed, 0.0, 100.0)
    energy = clampf(energy - 0.055 * minutes_passed, 0.0, 100.0)
    bladder_relief = clampf(bladder_relief - 0.13 * minutes_passed, 0.0, 100.0)
    # La privacion tiene consecuencias fisicas reales, no solo una frase.
    var deficit: float = maxf(0.0, 12.0 - satiety) + maxf(0.0, 8.0 - energy)
    health = clampf(health - deficit * 0.002 * minutes_passed, 0.0, 100.0)

func tick(delta: float) -> void:
    _advance_minutes(delta * MINUTES_PER_REAL_SECOND)

func movement_factor() -> float:
    if health <= 0.0:
        return 0.0
    return clampf(0.4 + 0.6 * minf(health / 100.0, energy / 100.0), 0.15, 1.0)

func clock_text() -> String:
    return "%02d:%02d" % [int(elapsed_minutes / 60.0) % 24, int(elapsed_minutes) % 60]

func day_index() -> int:
    return int(elapsed_minutes / 1440.0) + 1

func observation() -> Dictionary:
    var sensations: Array[String] = []
    if satiety < 35:
        sensations.append("hambre" if satiety >= 12 else "hambre intensa y debilidad")
    if energy < 35:
        sensations.append("cansancio" if energy >= 8 else "agotamiento")
    if bladder_relief < 35:
        sensations.append("ganas de ir al baño" if bladder_relief >= 12 else "urgencia de vejiga")
    if health < 70:
        sensations.append("malestar fisico")
    return {
        "dia": day_index(),
        "hora": clock_text(),
        "saciedad_0_a_100": snappedf(satiety, 0.1),
        "energia_0_a_100": snappedf(energy, 0.1),
        "alivio_vejiga_0_a_100": snappedf(bladder_relief, 0.1),
        "salud_0_a_100": snappedf(health, 0.1),
        "comida_disponible": food_units,
        "sensaciones": sensations,
        "capacidad_movimiento": snappedf(movement_factor(), 0.01)
    }

func interact(kind: String) -> Dictionary:
    match kind:
        "food":
            if food_units <= 0:
                return {"success": false, "event": "404 intentó comer, pero no queda comida."}
            food_units -= 1
            satiety = clampf(satiety + 34.0, 0.0, 100.0)
            _advance_minutes(8.0)
            health = minf(100.0, health + 0.4)
            return {"success": true, "event": "404 comió una ración del cubo de alimentos. Quedan %d." % food_units}
        "bed":
            _advance_minutes(90.0)
            energy = clampf(energy + 65.0, 0.0, 100.0)
            return {"success": true, "event": "404 durmió 90 minutos simulados en el cubo-cama."}
        "toilet":
            _advance_minutes(5.0)
            bladder_relief = clampf(bladder_relief + 80.0, 0.0, 100.0)
            return {"success": true, "event": "404 utilizó el cubo-váter y alivió la vejiga."}
    return {"success": false, "event": "Ese objeto no ofrece una interaccion corporal."}

func to_dict() -> Dictionary:
    return {
        "satiety": satiety,
        "energy": energy,
        "bladder_relief": bladder_relief,
        "health": health,
        "food_units": food_units,
        "elapsed_minutes": elapsed_minutes
    }

func restore(data: Variant) -> void:
    if not (data is Dictionary):
        return
    satiety = clampf(float(data.get("satiety", satiety)), 0.0, 100.0)
    energy = clampf(float(data.get("energy", energy)), 0.0, 100.0)
    bladder_relief = clampf(float(data.get("bladder_relief", bladder_relief)), 0.0, 100.0)
    health = clampf(float(data.get("health", health)), 0.0, 100.0)
    food_units = maxi(0, int(data.get("food_units", food_units)))
    elapsed_minutes = maxf(0.0, float(data.get("elapsed_minutes", elapsed_minutes)))

func import_legacy(data: Dictionary) -> void:
    var old_needs: Variant = data.get("needs", {})
    if old_needs is Dictionary:
        satiety = clampf(float(old_needs.get("hunger", satiety)), 0.0, 100.0)
        energy = clampf(float(old_needs.get("energy", energy)), 0.0, 100.0)
        bladder_relief = clampf(float(old_needs.get("bladder", bladder_relief)), 0.0, 100.0)
    var old_inventory: Variant = data.get("inventory", {})
    if old_inventory is Dictionary:
        food_units = maxi(0, int(old_inventory.get("food", food_units)))
    elapsed_minutes = maxf(0.0, float(data.get("minutes", elapsed_minutes)))
