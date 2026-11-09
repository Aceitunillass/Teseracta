extends SceneTree

const World = preload("res://scripts/world.gd")

func _check(condition: bool, explanation: String) -> bool:
    if not condition:
        push_error("SMOKE FAILURE: " + explanation)
        quit(1)
        return false
    return true


func _initialize() -> void:
    var world = World.new()
    if not _check(world.objects.size() == 3, "new world should contain three editable cubes"):
        return
    if not _check(world.ticks == 0, "world should start at tick 0"):
        return
    var observation: Dictionary = world.observe()
    if not _check(observation.has("visible_objects") and observation.has("position"), "observation contract"):
        return

    var accepted: Dictionary = world.submit_action({"type": "MoveTo", "data": {"position": [0.0, 0.0]}})
    if not _check(bool(accepted.get("ok", false)), "free MoveTo must be accepted"):
        return
    for index in range(20):
        world.step(0.1)
    if not _check(not world.moving and world.agent_position.distance_to(Vector3.ZERO) < 0.03, "movement must terminate at target"):
        return
    var movement_events: Array[Dictionary] = world.drain_events()
    var found_completion: bool = false
    for event in movement_events:
        if str(event.get("kind", "")) == "move_completed":
            found_completion = true
    if not _check(found_completion, "movement completion must be measured and logged"):
        return

    var blocked: Dictionary = world.submit_action({"type": "MoveTo", "data": {"position": [0.0, -1.45]}})
    if not _check(not bool(blocked.get("ok", true)), "cannot walk into a solid cube"):
        return
    var inspect: Dictionary = world.submit_action({"type": "Inspect", "data": {"id": "bed"}})
    if not _check(bool(inspect.get("ok", false)), "nearby object is inspectable"):
        return
    var use_far: Dictionary = world.submit_action({"type": "Use", "data": {"id": "bed"}})
    if not _check(not bool(use_far.get("ok", true)), "use must enforce physical reach"):
        return
    var start: Dictionary = world.submit_action({"type": "MoveTo", "data": {"position": [3.0, 0.0]}})
    if not _check(bool(start.get("ok", false)), "second MoveTo should work"):
        return
    var stopped: Dictionary = world.submit_action({"type": "Stop", "data": {}})
    if not _check(bool(stopped.get("ok", false)) and not world.moving, "Stop must cancel movement"):
        return

    world.add_box()
    if not _check(world.objects.size() == 4, "editor can add an object"):
        return
    var edited: bool = world.update_box(3, {"palette": "verde", "temperature_c": 32.0})
    if not _check(edited and str(world.objects[3]["palette"]) == "verde", "editor can change palette"):
        return
    var snapshot: Dictionary = world.snapshot()
    var second = World.new()
    if not _check(second.restore_snapshot(snapshot), "snapshot should restore in independent world"):
        return
    if not _check(second.objects.size() == 4 and second.ticks == world.ticks, "snapshot preserves definitions and time"):
        return
    print("TESERACTA ZERO world smoke OK")
    quit(0)
