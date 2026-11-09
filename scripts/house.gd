extends Node3D
## Diorama isométrico: las paredes frontales se omiten sin alterar los datos lógicos.
## TODOS los materiales son planos y unshaded: sin sombras ni degradados.

const FLOOR_BED := Color("343553")
const FLOOR_KITCHEN := Color("334955")
const FLOOR_BATH := Color("3b3e59")
const WALL := Color("22243c")
const WALL_TRIM := Color("777bb0")
const MAGENTA := Color("ea7eb9")
const CYAN := Color("7adddf")
const CREAM := Color("ded2bf")

var interactables: Dictionary = {}

func flat_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.metallic = 0.0
    material.roughness = 1.0
    return material

func block(part_name: String, center: Vector3, dimensions: Vector3, color: Color, parent_node: Node3D = null) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    var cube := BoxMesh.new()
    cube.size = dimensions
    part.mesh = cube
    part.material_override = flat_material(color)
    part.position = center
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if parent_node == null:
        parent_node = self
    parent_node.add_child(part)
    return part

func interactable(action: String, title: String, position_3d: Vector3, size_3d: Vector3, approach: Vector3) -> void:
    var area := Area3D.new()
    area.name = "Usar_" + action
    area.collision_layer = 2
    area.collision_mask = 0
    area.position = position_3d
    area.set_meta("action", action)
    area.set_meta("title", title)
    area.set_meta("approach", approach)
    var collider := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = size_3d
    collider.shape = box_shape
    area.add_child(collider)
    add_child(area)
    interactables[action] = {"title": title, "approach": approach}

func _room_label(text_value: String, at: Vector3, color: Color) -> void:
    var room_label := Label3D.new()
    room_label.text = text_value
    room_label.font_size = 52
    room_label.pixel_size = 0.005
    room_label.modulate = color
    room_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    room_label.no_depth_test = true
    room_label.position = at
    add_child(room_label)

func build() -> void:
    block("Solar", Vector3(0, -0.28, 0), Vector3(13, 0.35, 9), Color("141728"))
    block("Suelo_Dormitorio", Vector3(-4, -0.06, 0), Vector3(4, 0.12, 8), FLOOR_BED)
    block("Suelo_Salon", Vector3(0, -0.06, 0), Vector3(4, 0.12, 8), FLOOR_KITCHEN)
    block("Suelo_Bano", Vector3(4, -0.06, 0), Vector3(4, 0.12, 8), FLOOR_BATH)
    # Pared trasera y laterales, sin techo ni muro frontal (cutaway).
    block("Pared_trasera", Vector3(0, 1.45, -4), Vector3(12.3, 2.9, 0.2), WALL)
    block("Pared_lateral_izq", Vector3(-6.06, 1.45, 0), Vector3(0.2, 2.9, 8), WALL)
    block("Pared_lateral_der", Vector3(6.06, 1.45, 0), Vector3(0.2, 2.9, 8), WALL)
    for x in [-2.0, 2.0]:
        block("Tabique_trasero", Vector3(x, 1.0, -2.48), Vector3(0.16, 2.0, 3.0), WALL)
        block("Tabique_delantero", Vector3(x, 1.0, 2.50), Vector3(0.16, 2.0, 3.0), WALL)
        block("Marco_superior_puerta", Vector3(x, 2.40, 0), Vector3(0.18, 0.16, 2.05), WALL_TRIM)
    for x in [-4.0, 0.0, 4.0]:
        block("Neon_pared", Vector3(x, 2.7, -3.87), Vector3(2.5, 0.055, 0.065), CYAN if x != 0 else MAGENTA)
    _room_label("DORMITORIO", Vector3(-4, 2.98, -3.82), CREAM)
    _room_label("COCINA · SALÓN", Vector3(0, 2.98, -3.82), CREAM)
    _room_label("BAÑO", Vector3(4, 2.98, -3.82), CREAM)
    # Dormitorio
    block("Cama_base", Vector3(-4.60, 0.23, -2.55), Vector3(2.25, 0.45, 1.65), Color("7a506c"))
    block("Colchon", Vector3(-4.60, 0.50, -2.55), Vector3(2.05, 0.15, 1.46), CREAM)
    block("Manta", Vector3(-5.06, 0.60, -2.55), Vector3(1.04, 0.09, 1.46), Color("9578cf"))
    block("Almohada", Vector3(-3.77, 0.64, -2.55), Vector3(0.40, 0.10, 1.2), Color("a4d8ed"))
    block("Mesita", Vector3(-5.25, 0.4, 0.12), Vector3(0.90, 0.8, 0.75), Color("78648a"))
    block("Armario", Vector3(-5.55, 1.05, 2.4), Vector3(0.60, 2.1, 1.8), Color("62526f"))
    block("Pantalla", Vector3(-5.19, 1.35, 2.4), Vector3(0.05, 0.8, 1.3), CYAN)
    interactable("sleep", "Dormir", Vector3(-4.60, 0.8, -2.55), Vector3(2.25, 1.5, 1.65), Vector3(-4.0, 0, -1.3))
    # Cocina y salón
    block("Encimera", Vector3(0.10, 0.49, -3.34), Vector3(3.55, 0.98, 0.95), Color("617786"))
    block("Superficie", Vector3(0.10, 1.01, -3.34), Vector3(3.60, 0.07, 0.98), Color("bdd7ce"))
    block("Frigorifico", Vector3(-1.42, 1.03, -2.76), Vector3(0.75, 2.06, 0.85), CREAM)
    block("Frigo_banda", Vector3(-1.42, 1.32, -2.29), Vector3(0.6, 0.08, 0.02), CYAN)
    block("Mesa", Vector3(0.3, 0.7, 1.45), Vector3(1.55, 0.14, 1.35), Color("bc8d9b"))
    block("Pata", Vector3(0.3, 0.34, 1.45), Vector3(0.25, 0.70, 0.25), Color("6a6c88"))
    block("Sofa", Vector3(-0.12, 0.40, 3.3), Vector3(2.4, 0.75, 0.8), Color("a674ba"))
    block("Respaldo", Vector3(-0.12, 0.85, 3.65), Vector3(2.4, 1.0, 0.22), Color("69508d"))
    interactable("eat", "Comer", Vector3(0.30, 0.9, 1.45), Vector3(1.65, 1.4, 1.4), Vector3(1.35, 0, 1.35))
    interactable("relax", "Descansar", Vector3(-0.12, 0.65, 3.3), Vector3(2.4, 1.3, 0.8), Vector3(-0.7, 0, 2.25))
    # Baño
    block("Ducha_base", Vector3(4.74, 0.11, -2.90), Vector3(2, 0.2, 1.85), Color("769ba9"))
    block("Ducha_panel", Vector3(4.74, 1.16, -3.83), Vector3(1.6, 2.0, 0.12), CYAN)
    block("Ducha_rociador", Vector3(4.74, 2.25, -3.1), Vector3(0.62, 0.12, 0.55), Color("c6dbe2"))
    block("Inodoro_base", Vector3(3.31, 0.37, 1.85), Vector3(0.78, 0.74, 1), CREAM)
    block("Inodoro_tanque", Vector3(3.31, 0.80, 2.30), Vector3(0.86, 0.60, 0.30), CREAM)
    block("Lavabo", Vector3(5.28, 0.82, 1.86), Vector3(1.07, 0.24, 0.82), Color("c3e9df"))
    block("Lavabo_pedestal", Vector3(5.28, 0.37, 1.86), Vector3(0.35, 0.72, 0.32), CREAM)
    block("Espejo", Vector3(5.87, 1.58, 1.86), Vector3(0.09, 1.05, 1.17), CYAN)
    interactable("shower", "Ducharse", Vector3(4.74, 1.1, -2.90), Vector3(2.00, 2.2, 1.85), Vector3(4.55, 0, -1.25))
    interactable("toilet", "Ir al baño", Vector3(3.31, 0.8, 1.85), Vector3(0.90, 1.5, 1.1), Vector3(3.3, 0, 0.5))
    block("Borde_luz_entrada", Vector3(0, 0.035, 4.05), Vector3(12, 0.07, 0.06), MAGENTA)
