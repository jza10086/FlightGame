extends Node3D
class_name PlaneVisual
## Original faceted sport aircraft. Local forward is -Z; wheel contact is y = -1.05.
## All meshes are generated here, with no imported art or third-party code.

var _propeller: Node3D
var _left_aileron: Node3D
var _right_aileron: Node3D
var _elevator: Node3D
var _rudder: Node3D
var _wheel_meshes: Array[MeshInstance3D] = []
var _crashed: bool = false
var _materials: Dictionary = {}
var _batches: Dictionary = {}

func _ready() -> void:
	_materials["ivory"] = _material(Color("f4edce"))
	_materials["belly"] = _material(Color("cccab2"))
	_materials["orange"] = _material(Color("d65b31"))
	_materials["dark"] = _material(Color("153b49"))
	_materials["rubber"] = _material(Color("243137"))
	_materials["metal"] = _material(Color("8d9a98"), 0.55)
	_materials["glass"] = _material(Color("255b68"), 0.38)
	_materials["light"] = _material(Color("ffe8aa"))
	_build_body()
	_build_wings()
	_build_tail()
	_build_gear()
	_build_propeller()
	_flush_batches()

func _material(color: Color, roughness: float = 0.78) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

# Eight-sided sections give the aircraft a deliberate, flat-shaded low-poly shape.
func _build_body() -> void:
	var sections: Array[Vector4] = [
		Vector4(-3.73, 0.07, 0.27, 0.28),
		Vector4(-3.12, 0.05, 0.47, 0.42),
		Vector4(-1.50, 0.08, 0.60, 0.46),
		Vector4(0.55, 0.08, 0.55, 0.44),
		Vector4(2.55, 0.12, 0.23, 0.23),
		Vector4(3.62, 0.15, 0.065, 0.11)]
	for j in range(sections.size() - 1):
		for i in range(8):
			var a := _section_point(sections[j], i)
			var b := _section_point(sections[j], (i + 1) % 8)
			var c := _section_point(sections[j + 1], (i + 1) % 8)
			var d := _section_point(sections[j + 1], i)
			var mat_name: String = "belly" if i >= 4 else "ivory"
			_quad(mat_name, a, b, c, d)
	# A low horizontal orange belt follows the tapered body instead of floating above it.
	for side in [-1.0, 1.0]:
		for j in range(sections.size() - 1):
			var s: Vector4 = sections[j]
			var t: Vector4 = sections[j + 1]
			_quad_facing("orange", Vector3(side * (s.z + 0.008), s.y + 0.10, s.x), Vector3(side * (s.z + 0.008), s.y - 0.09, s.x), Vector3(side * (t.z + 0.008), t.y - 0.055, t.x), Vector3(side * (t.z + 0.008), t.y + 0.06, t.x), Vector3(side, 0, 0))
	# Faceted canopy, with opaque blue glass for stable silhouettes at distance.
	var front_l := Vector3(-0.49, 0.40, -1.30)
	var front_r := Vector3(0.49, 0.40, -1.30)
	var roof_l := Vector3(-0.35, 1.08, -0.40)
	var roof_r := Vector3(0.35, 1.08, -0.40)
	var rear_l := Vector3(-0.36, 0.88, 0.59)
	var rear_r := Vector3(0.36, 0.88, 0.59)
	var end_l := Vector3(-0.48, 0.43, 1.08)
	var end_r := Vector3(0.48, 0.43, 1.08)
	_quad("glass", front_l, roof_l, roof_r, front_r)
	_quad("glass", roof_l, rear_l, rear_r, roof_r)
	_quad("glass", rear_l, end_l, end_r, rear_r)
	_quad("glass", front_l, end_l, rear_l, roof_l)
	_quad("glass", front_r, roof_r, rear_r, end_r)
	for pair in [[front_l, roof_l], [front_r, roof_r], [roof_l, rear_l], [roof_r, rear_r], [rear_l, end_l], [rear_r, end_r], [rear_l, rear_r]]:
		_rod(pair[0], pair[1], 0.035, "ivory", self)
	# Dark engine intake under the spinner, and an amber forward landing lamp.
	_box(Vector3(0, -0.15, -3.53), Vector3(0.27, 0.14, 0.08), "dark")
	_box(Vector3(0, -0.24, -2.91), Vector3(0.20, 0.11, 0.035), "light")

func _section_point(s: Vector4, index: int) -> Vector3:
	var angle: float = TAU * float(index) / 8.0
	return Vector3(cos(angle) * s.z, sin(angle) * s.w + s.y, s.x)

func _build_wings() -> void:
	for side in [-1.0, 1.0]:
		_wing_panel(side, 0.43, 4.25, -1.55, -1.03, 0.70, 0.32, -0.10, 0.15, "ivory")
		_wing_panel(side, 4.25, 5.30, -1.03, -0.68, 0.32, 0.10, 0.15, 0.22, "orange")
		# Slender contrasting band and a navigation lamp at each tip.
		_wing_panel(side, 3.65, 3.83, -1.11, -1.08, 0.39, 0.37, 0.123, 0.135, "orange", 0.017)
		_box(Vector3(side * 5.27, 0.24, -0.12), Vector3(0.07, 0.065, 0.12), "light")
		var aileron := Node3D.new()
		aileron.name = "LeftAileron" if side < 0.0 else "RightAileron"
		aileron.position = Vector3(side * 3.1, 0.13, 0.31)
		add_child(aileron)
		# Narrow exposed trailing-edge flap moves independently of the rigid wing.
		var mesh: MeshInstance3D = _simple_box(Vector3(2.0, 0.065, 0.31), "ivory")
		mesh.position = Vector3(0.0, 0.0, 0.13)
		aileron.add_child(mesh)
		if side < 0.0:
			_left_aileron = aileron
		else:
			_right_aileron = aileron
	# A discreet stylized orange roundel visible from the chase camera.
	_box(Vector3(-2.4, 0.075, -0.35), Vector3(0.65, 0.015, 0.13), "orange")
	_box(Vector3(-2.4, 0.075, -0.35), Vector3(0.13, 0.015, 0.65), "orange")

func _wing_panel(side: float, inner: float, outer: float, front_inner: float, front_outer: float, rear_inner: float, rear_outer: float, y_inner: float, y_outer: float, mat_name: String, thickness: float = 0.13) -> void:
	var a := Vector3(side * inner, y_inner, front_inner)
	var b := Vector3(side * outer, y_outer, front_outer)
	var c := Vector3(side * outer, y_outer - 0.025, rear_outer)
	var d := Vector3(side * inner, y_inner - 0.025, rear_inner)
	var e := Vector3(side * inner, y_inner + thickness * 0.58, lerpf(front_inner, rear_inner, 0.28))
	var f := Vector3(side * outer, y_outer + thickness * 0.40, lerpf(front_outer, rear_outer, 0.28))
	_quad_facing(mat_name, a, b, f, e, Vector3.UP)
	_quad_facing(mat_name, e, f, c, d, Vector3.UP)
	var down := Vector3(0, -thickness * 0.45, 0)
	_quad_facing("belly" if mat_name == "ivory" else mat_name, a + down, d + down, c + down, b + down, Vector3.DOWN)
	_quad_facing(mat_name, a, a + down, b + down, b, Vector3.FORWARD)
	_quad_facing(mat_name, d, c, c + down, d + down, Vector3.BACK)
	_quad_facing(mat_name, b, b + down, c + down, c, Vector3(side, 0, 0))

func _build_tail() -> void:
	for side in [-1.0, 1.0]:
		_wing_panel(side, 0.12, 1.78, 2.18, 2.69, 3.40, 3.58, 0.22, 0.31, "ivory", 0.09)
		_wing_panel(side, 1.42, 1.78, 2.58, 2.69, 3.54, 3.58, 0.295, 0.315, "orange", 0.07)
	_elevator = Node3D.new()
	_elevator.position = Vector3(0, 0.26, 3.42)
	add_child(_elevator)
	var elevator_mesh: MeshInstance3D = _simple_box(Vector3(2.8, 0.055, 0.30), "orange")
	elevator_mesh.position.z = 0.12
	_elevator.add_child(elevator_mesh)
	# Swept vertical stabilizer. Two separate faces create a slim, solid fin.
	var fin: Array[Vector3] = [Vector3(0, 0.19, 1.95), Vector3(0, 1.70, 2.84), Vector3(0, 1.64, 3.40), Vector3(0, 0.23, 3.58)]
	_extrude_fin(fin, 0.085, "orange")
	# Ivory diagonal accent on each side of the tail.
	for side in [-1.0, 1.0]:
		_quad_facing("ivory", Vector3(side * 0.086, 0.59, 2.34), Vector3(side * 0.086, 0.80, 2.47), Vector3(side * 0.086, 0.99, 3.46), Vector3(side * 0.086, 0.77, 3.49), Vector3(side, 0, 0))
	_rudder = Node3D.new()
	_rudder.position = Vector3(0, 0.93, 3.42)
	add_child(_rudder)
	var rudder_mesh: MeshInstance3D = _simple_box(Vector3(0.08, 1.12, 0.20), "orange")
	rudder_mesh.position.z = 0.10
	_rudder.add_child(rudder_mesh)

func _build_gear() -> void:
	for side in [-1.0, 1.0]:
		var wheel_pos := Vector3(side * 1.20, -0.81, -0.28)
		_rod(Vector3(side * 0.5, -0.25, -0.38), wheel_pos + Vector3(0, 0.04, 0), 0.055, "metal", self)
		_wheel(wheel_pos, 0.24, 0.15)
	var nose_pos := Vector3(0, -0.83, -2.73)
	_rod(Vector3(0, -0.23, -2.65), nose_pos, 0.05, "metal", self)
	_wheel(nose_pos, 0.22, 0.12)

func _wheel(pos: Vector3, radius: float, width: float) -> void:
	var tire := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = width
	cylinder.radial_segments = 12
	tire.mesh = cylinder
	tire.material_override = _materials["rubber"]
	tire.rotation.z = PI * 0.5
	tire.position = pos
	add_child(tire)
	_wheel_meshes.append(tire)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.40
	hub_mesh.bottom_radius = radius * 0.40
	hub_mesh.height = width + 0.02
	hub_mesh.radial_segments = 10
	hub.mesh = hub_mesh
	hub.material_override = _materials["metal"]
	hub.rotation.z = PI * 0.5
	hub.position = pos
	add_child(hub)

func _build_propeller() -> void:
	_propeller = Node3D.new()
	_propeller.position = Vector3(0, 0.07, -3.88)
	add_child(_propeller)
	var spinner := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.29
	cone.height = 0.46
	cone.radial_segments = 12
	spinner.mesh = cone
	spinner.material_override = _materials["orange"]
	spinner.rotation.x = -PI * 0.5
	spinner.position.z = -0.14
	_propeller.add_child(spinner)
	for side in [-1.0, 1.0]:
		var blade: MeshInstance3D = _simple_box(Vector3(0.15, 0.79, 0.065), "dark")
		blade.position = Vector3(0, side * 0.53, 0.035)
		blade.rotation.y = 0.24
		_propeller.add_child(blade)
		var tip: MeshInstance3D = _simple_box(Vector3(0.15, 0.13, 0.068), "light")
		tip.position = Vector3(0, side * 0.875, 0.035)
		tip.rotation.y = 0.24
		_propeller.add_child(tip)

func update_controls(delta: float, throttle: float, pitch_input: float, roll_input: float, yaw_input: float, speed: float) -> void:
	if not is_instance_valid(_propeller):
		return
	var rpm: float = (5.0 + throttle * 76.0) if not _crashed else 0.0
	_propeller.rotation.z = fposmod(_propeller.rotation.z + delta * rpm, TAU)
	_left_aileron.rotation.x = lerpf(_left_aileron.rotation.x, roll_input * 0.28, minf(delta * 12.0, 1.0))
	_right_aileron.rotation.x = -_left_aileron.rotation.x
	_elevator.rotation.x = lerpf(_elevator.rotation.x, pitch_input * 0.26, minf(delta * 12.0, 1.0))
	_rudder.rotation.y = lerpf(_rudder.rotation.y, -yaw_input * 0.3, minf(delta * 12.0, 1.0))
	for wheel in _wheel_meshes:
		wheel.rotate_y(delta * speed / 0.24)

func set_crashed(value: bool) -> void:
	_crashed = value

func _simple_box(size: Vector3, mat_name: String) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.material_override = _materials[mat_name]
	return result

func _box(pos: Vector3, size: Vector3, mat_name: String) -> void:
	var h := size * 0.5
	var a := pos + Vector3(-h.x, -h.y, -h.z)
	var b := pos + Vector3(h.x, -h.y, -h.z)
	var c := pos + Vector3(h.x, h.y, -h.z)
	var d := pos + Vector3(-h.x, h.y, -h.z)
	var e := pos + Vector3(-h.x, -h.y, h.z)
	var f := pos + Vector3(h.x, -h.y, h.z)
	var g := pos + Vector3(h.x, h.y, h.z)
	var h2 := pos + Vector3(-h.x, h.y, h.z)
	_quad(mat_name, d, c, b, a)
	_quad(mat_name, g, h2, e, f)
	_quad(mat_name, h2, g, c, d)
	_quad(mat_name, a, b, f, e)
	_quad(mat_name, e, h2, d, a)
	_quad(mat_name, c, g, f, b)

func _extrude_fin(outline: Array[Vector3], half_width: float, mat_name: String) -> void:
	for side in [-1.0, 1.0]:
		for i in range(1, outline.size() - 1):
			if side > 0.0:
				_triangle(mat_name, outline[0] + Vector3(side * half_width, 0, 0), outline[i] + Vector3(side * half_width, 0, 0), outline[i + 1] + Vector3(side * half_width, 0, 0))
			else:
				_triangle(mat_name, outline[i + 1] + Vector3(side * half_width, 0, 0), outline[i] + Vector3(side * half_width, 0, 0), outline[0] + Vector3(side * half_width, 0, 0))
	for i in range(outline.size()):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		_quad(mat_name, a + Vector3(-half_width, 0, 0), b + Vector3(-half_width, 0, 0), b + Vector3(half_width, 0, 0), a + Vector3(half_width, 0, 0))

func _rod(a: Vector3, b: Vector3, radius: float, mat_name: String, parent: Node3D) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.material_override = _materials[mat_name]
	mesh.position = (a + b) * 0.5
	var direction: Vector3 = (b - a).normalized()
	var tangent: Vector3 = direction.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < 0.01:
		tangent = Vector3.RIGHT
	mesh.basis = Basis(tangent, direction, tangent.cross(direction)).orthonormalized()
	parent.add_child(mesh)

func _quad_facing(mat_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if (b - a).cross(c - a).dot(outward) >= 0.0:
		_quad(mat_name, a, b, c, d)
	else:
		_quad(mat_name, d, c, b, a)

func _quad(mat_name: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(mat_name, a, b, c)
	_triangle(mat_name, a, c, d)

func _triangle(mat_name: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	if not _batches.has(mat_name):
		_batches[mat_name] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array()}
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	_batches[mat_name]["vertices"].append_array(PackedVector3Array([a, b, c]))
	_batches[mat_name]["normals"].append_array(PackedVector3Array([normal, normal, normal]))

func _flush_batches() -> void:
	for key in _batches:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _batches[key]["vertices"]
		arrays[Mesh.ARRAY_NORMAL] = _batches[key]["normals"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new()
		instance.name = "Airframe_" + str(key)
		instance.mesh = mesh
		instance.material_override = _materials[key]
		add_child(instance)
	_batches.clear()
