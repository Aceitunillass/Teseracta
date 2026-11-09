extends Node3D
signal arrived

const CANONICAL_MODEL := "res://assets/characters/Pomi_Base_V05_Canonico.glb"
const GRID_UNIT := 0.5

var grid: AStarGrid2D
var waypoints: Array[Vector3] = []
var current_action := ""
var moving := false
var speed := 1.7
var visual: Node3D

func _ready() -> void:
    _setup_grid()
    _create_visual()

func _create_visual() -> void:
    if ResourceLoader.exists(CANONICAL_MODEL):
        var resource = load(CANONICAL_MODEL)
        if resource is PackedScene:
            visual = resource.instantiate() as Node3D
            if visual != null:
                visual.name = "Pomi_V05_CANONICO"
                visual.scale = Vector3.ONE * 1.45
                add_child(visual)
                _make_unshaded(visual)
                return
    # Fallback simple si alguien descarga únicamente la rama de código de GitHub.
    visual = Node3D.new()
    visual.name = "Avatar_provisional_sin_GLb"
    add_child(visual)
    for p in [Vector3(0, 0.90, 0), Vector3(0, 1.25, 0)]:
        var primitive := MeshInstance3D.new()
        primitive.mesh = SphereMesh.new()
        primitive.scale = Vector3(0.28, 0.39, 0.22)
        primitive.position = p
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("e8a0a0")
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        primitive.material_override = mat
        visual.add_child(primitive)

func _make_unshaded(root: Node) -> void:
    if root is MeshInstance3D:
        var instance: MeshInstance3D = root as MeshInstance3D
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if instance.mesh:
            for i in range(instance.mesh.get_surface_count()):
                var source: Material = instance.mesh.surface_get_material(i)
                if source is BaseMaterial3D:
                    var copy: BaseMaterial3D = source.duplicate() as BaseMaterial3D
                    copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
                    copy.vertex_color_use_as_albedo = true
                    instance.set_surface_override_material(i, copy)
    for child in root.get_children():
        _make_unshaded(child)

func _setup_grid() -> void:
    grid = AStarGrid2D.new()
    grid.region = Rect2i(-12, -8, 25, 17)
    grid.cell_size = Vector2(GRID_UNIT, GRID_UNIT)
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()
    # Separación entre tres habitaciones; abertura de puerta en z = [-1,1].
    for gx in [-4, 4]:
        for gz in range(-8, 9):
            if abs(gz) > 2:
                grid.set_point_solid(Vector2i(gx, gz), true)

func request_walk(destination: Vector3, action_name: String) -> bool:
    var start_id := Vector2i(roundi(position.x / GRID_UNIT), roundi(position.z / GRID_UNIT))
    var end_id := Vector2i(roundi(destination.x / GRID_UNIT), roundi(destination.z / GRID_UNIT))
    if not grid.is_in_boundsv(end_id) or grid.is_point_solid(end_id):
        return false
    if not grid.is_in_boundsv(start_id):
        return false
    var cells: Array[Vector2i] = grid.get_id_path(start_id, end_id)
    if cells.is_empty():
        return false
    waypoints.clear()
    for cell in cells:
        waypoints.append(Vector3(cell.x * GRID_UNIT, 0.0, cell.y * GRID_UNIT))
    current_action = action_name
    moving = true
    return true

func _process(delta: float) -> void:
    if not moving:
        return
    while not waypoints.is_empty() and position.distance_to(waypoints[0]) < 0.12:
        waypoints.pop_front()
    if waypoints.is_empty():
        moving = false
        arrived.emit()
        return
    var direction: Vector3 = waypoints[0] - position
    var step := minf(speed * delta, direction.length())
    if step > 0.0:
        position += direction.normalized() * step
        if visual != null:
            visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, 5.0 * delta))

func restore_position(data: Variant) -> void:
    if data is Array and data.size() == 3:
        position = Vector3(clampf(float(data[0]), -5.75, 5.75), 0.0, clampf(float(data[2]), -3.75, 3.75))
    moving = false
    current_action = ""
    waypoints.clear()
