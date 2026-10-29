extends Node3D
class_name CoastalWorld
## Original mesh-built coastal airfield. Units are metres; runway heading is -Z.
## terrain_height is shared with the flight controller (flat runway is exactly y=0).

const ISLANDS: Array[Vector4] = [
	Vector4(-110.0, -100.0, 690.0, 1070.0),
	Vector4(-1430.0, -1450.0, 620.0, 860.0),
	Vector4(1410.0, -1750.0, 550.0, 770.0),
	Vector4(-130.0, -3430.0, 860.0, 590.0),
	Vector4(1800.0, 850.0, 660.0, 600.0),
	Vector4(-1800.0, 1300.0, 720.0, 760.0),
	Vector4(3100.0, -4000.0, 1200.0, 1100.0),
	Vector4(-3300.0, -4200.0, 1400.0, 900.0),
	Vector4(150.0, 3300.0, 1500.0, 720.0),
]
const PEAKS: Array[float] = [0.0, 380.0, 280.0, 330.0, 230.0, 310.0, 640.0, 720.0, 450.0]
var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}

static func _island_height(x: float, z: float, index: int) -> float:
	var island: Vector4 = ISLANDS[index]
	var nx: float = (x - island.x) / island.z
	var nz: float = (z - island.y) / island.w
	var angle: float = atan2(nz, nx)
	var radial: float = sqrt(nx * nx + nz * nz)
	# Broad irregular coves rather than a perfectly round outline.
	var shore: float = 1.0 + 0.055 * sin(angle * 5.0 + float(index)) + 0.035 * cos(angle * 9.0)
	var r: float = radial / shore
	if r >= 1.0:
		return -4.0
	var coast: float = -4.0 + 4.0 * smoothstep(1.0, 0.85, r)
	if index == 0:
		# Airport plateau stays level, hills sit well west of the approach.
		var hill: float = 118.0 * exp(-pow((x + 450.0) / 180.0, 2.0) - pow((z + 170.0) / 320.0, 2.0))
		hill += 68.0 * exp(-pow((x + 340.0) / 160.0, 2.0) - pow((z - 510.0) / 220.0, 2.0))
		var flat_mask: float = smoothstep(-170.0, -310.0, x)
		return coast + hill * flat_mask * smoothstep(1.0, 0.72, r)
	var summit: float = pow(maxf(0.0, 1.0 - r * r), 2.0)
	var ridge: float = 0.83 + 0.17 * sin(nx * 5.0 + nz * 3.0 + float(index))
	return coast + PEAKS[index] * summit * ridge

static func terrain_height(x: float, z: float) -> float:
	var height: float = -4.0
	for index in ISLANDS.size():
		height = maxf(height, _island_height(x, z, index))
	return height

static func is_runway(p: Vector3) -> bool:
	return absf(p.x) <= 14.0 and p.z >= -500.0 and p.z <= 180.0

func _ready() -> void:
	rng.seed = 83625
	_make_materials()
	_make_landscape()
	_make_airport()
	_make_trees()
	_make_landmarks()
	_batch_static_geometry()

func _material(key: String, color: String, roughness: float = 0.9) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = roughness
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mats[key] = mat
	return mat

func _make_materials() -> void:
	_material("sea", "258c99", 0.65)
	_material("asphalt", "414956")
	_material("shoulder", "78837d")
	_material("paint", "f3edd5")
	_material("yellow", "f4c870")
	_material("wall", "dcb798")
	_material("rust", "bd7157")
	_material("roof", "c6dbd9")
	_material("glass", "345b69", 0.35)
	_material("dark", "34424b")
	_material("white", "eee5d1")
	_material("red", "dc7259")
	_material("trunk", "746653")
	_material("leaf", "507c62")
	_material("leaf_light", "6b9270")
	_material("rock", "9ba49a")
	_material("foam", "92c8bd")
	var terrain_mat := StandardMaterial3D.new()
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.roughness = 1.0
	terrain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	terrain_mat.cull_mode = BaseMaterial3D.CULL_BACK
	mats["terrain"] = terrain_mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, material: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mats[material]
	node.position = pos
	if size.y < 0.3:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, pos: Vector3, bottom: float, top: float, height: float, material: String, segments: int = 8) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mats[material]
	node.position = pos
	parent.add_child(node)
	return node

func _make_landscape() -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(22000.0, 22000.0)
	var sea_node := MeshInstance3D.new()
	sea_node.mesh = sea
	sea_node.material_override = mats["sea"]
	sea_node.position.y = -4.08
	sea_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea_node)
	for index in ISLANDS.size():
		_make_island(index)

func _make_island(index: int) -> void:
	var island: Vector4 = ISLANDS[index]
	var steps: int = 32 if index == 0 else 22
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in steps:
		for xi in steps:
			var x0: float = island.x - island.z * 1.12 + (float(xi) / steps) * island.z * 2.24
			var z0: float = island.y - island.w * 1.12 + (float(zi) / steps) * island.w * 2.24
			var x1: float = x0 + island.z * 2.24 / steps
			var z1: float = z0 + island.w * 2.24 / steps
			var a := Vector3(x0, _island_height(x0, z0, index) - 0.025, z0)
			var b := Vector3(x1, _island_height(x1, z0, index) - 0.025, z0)
			var c := Vector3(x1, _island_height(x1, z1, index) - 0.025, z1)
			var d := Vector3(x0, _island_height(x0, z1, index) - 0.025, z1)
			_terrain_triangle(surface, a, c, b, index, xi + zi * steps)
			_terrain_triangle(surface, a, d, c, index, xi + zi * steps + 379)
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = mats["terrain"]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _terrain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, index: int, seed_value: int) -> void:
	var average: float = (a.y + b.y + c.y) / 3.0
	var color := Color("779276")
	if average < -0.3:
		color = Color("d4c6a0")
	elif average > 180.0:
		color = Color("88918a")
	elif average > 65.0:
		color = Color("8a9276")
	elif index > 0:
		color = Color("69876e")
	var tint: float = 0.94 + fmod(absf(sin(float(seed_value * 17 + index * 53)) * 4358.6), 0.12)
	color *= tint
	color.a = 1.0
	surface.set_color(color)
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(b)

func _make_airport() -> void:
	_box(self, Vector3(0, 0.02, -160), Vector3(35, 0.08, 695), "shoulder")
	_box(self, Vector3(0, 0.08, -160), Vector3(28, 0.08, 680), "asphalt")
	# Runway edge stripes and broad threshold piano keys.
	for x in [-13.2, 13.2]:
		_box(self, Vector3(x, 0.13, -160), Vector3(0.35, 0.025, 674), "paint")
	for z in range(-450, 151, 35):
		_box(self, Vector3(0, 0.14, z), Vector3(0.65, 0.03, 16), "paint")
	for x in [-10.0, -7.0, -4.0, 4.0, 7.0, 10.0]:
		for z in [-482.0, 162.0]:
			_box(self, Vector3(x, 0.14, z), Vector3(1.4, 0.03, 18), "paint")
	for z in [-420.0, 100.0]:
		for x in [-8.0, 8.0]:
			_box(self, Vector3(x, 0.14, z), Vector3(3.0, 0.03, 20), "paint")
	_runway_number("18", Vector3(0, 0.17, 133), 0.0)
	_runway_number("36", Vector3(0, 0.17, -453), PI)
	# Shoulder markers batched together (no individual lights/shadow cost).
	var markers: Array[Transform3D] = []
	for z in range(-495, 181, 30):
		for x in [-17.0, 17.0]:
			markers.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.35, z)))
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.4, 0.5, 0.4)
	_multimesh(marker_mesh, mats["yellow"], markers)
	# Apron and taxiway connect the field to a small coastal aero club.
	_box(self, Vector3(39, 0.025, 76), Vector3(70, 0.06, 14), "asphalt")
	_box(self, Vector3(69, 0.03, 67), Vector3(65, 0.06, 112), "asphalt")
	_box(self, Vector3(41, 0.075, 76), Vector3(73, 0.025, 0.4), "yellow")
	for z in [35.0, 66.0, 99.0]:
		_box(self, Vector3(67, 0.09, z), Vector3(15, 0.025, 0.35), "yellow")
		_box(self, Vector3(61, 0.09, z), Vector3(0.35, 0.025, 12), "yellow")
	_hangar(Vector3(102, 0, 39), Vector3(36, 12, 43))
	_hangar(Vector3(106, 0, -15), Vector3(29, 9, 31))
	# Air traffic cabin: warmer masonry under a clean band of blue glass.
	_box(self, Vector3(73, 9, 126), Vector3(9, 18, 9), "wall")
	_box(self, Vector3(73, 19.5, 126), Vector3(14, 3.4, 12), "glass")
	_box(self, Vector3(73, 21.7, 126), Vector3(16, 0.9, 14), "roof")
	_box(self, Vector3(73, 17.6, 126), Vector3(15, 0.7, 13), "roof")
	for x in [66.2, 79.8]:
		_box(self, Vector3(x, 19.5, 126), Vector3(0.45, 4, 12), "white")
	_cylinder(self, Vector3(73, 25, 126), 0.13, 0.13, 6, "dark")
	_box(self, Vector3(104, 3.2, 108), Vector3(35, 6.4, 17), "wall")
	_box(self, Vector3(104, 6.7, 108), Vector3(38, 0.8, 20), "roof")
	_box(self, Vector3(86.4, 3.4, 108), Vector3(0.2, 3.0, 12), "glass")
	for z in [143.0, 152.0, 161.0]:
		_box(self, Vector3(106, 1.5, z), Vector3(9, 3, 5.8), "rust")
	_windsock(Vector3(37, 0, 139))
	# A small safety fence at the back of the club, away from the runway.
	for z in range(-55, 191, 18):
		_cylinder(self, Vector3(139, 1.4, z), 0.18, 0.18, 2.8, "white", 6)
	_box(self, Vector3(139, 1.7, 66), Vector3(0.18, 0.15, 255), "white")

func _runway_number(text: String, position_value: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 160
	label.pixel_size = 0.04
	label.outline_size = 0
	label.modulate = Color("f3edd5")
	label.position = position_value
	label.rotation = Vector3(-PI / 2.0, 0, yaw)
	label.no_depth_test = false
	add_child(label)

func _hangar(pos: Vector3, size: Vector3) -> void:
	_box(self, pos + Vector3(0, size.y / 2, 0), size, "rust")
	_box(self, pos + Vector3(-size.x / 2.0 - 0.1, size.y * 0.4, 0), Vector3(0.2, size.y * 0.74, size.z * 0.78), "dark")
	for direction in [-1.0, 1.0]:
		var roof := _box(self, pos + Vector3(direction * size.x * 0.25, size.y + 1.5, 0), Vector3(size.x * 0.55, 0.7, size.z + 3), "roof")
		roof.rotation.z = -direction * 0.15
	_box(self, pos + Vector3(-size.x / 2 - 0.15, size.y * 0.4, 0), Vector3(0.25, size.y * 0.74, 0.3), "roof")

func _windsock(pos: Vector3) -> void:
	_cylinder(self, pos + Vector3(0, 5, 0), 0.15, 0.12, 10, "white")
	for i in 5:
		var sock := _cylinder(self, pos + Vector3(float(i) * 0.85 + 0.3, 10.3 - float(i) * 0.1, 0), 0.54 - i * 0.065, 0.48 - i * 0.065, 0.85, "red" if i % 2 == 0 else "white", 8)
		sock.rotation.z = PI / 2 + 0.12

func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _make_trees() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var tops: Array[Transform3D] = []
	for i in 490:
		var island_index: int = i % 5
		var island: Vector4 = ISLANDS[island_index]
		var x: float = island.x + rng.randf_range(-island.z * 0.84, island.z * 0.84)
		var z: float = island.y + rng.randf_range(-island.w * 0.84, island.w * 0.84)
		var ground: float = terrain_height(x, z)
		if ground < -0.1 or ground > 260.0:
			continue
		if island_index == 0 and x > -158.0 and x < 155.0 and z < 260.0 and z > -650.0:
			continue
		var scale_value: float = rng.randf_range(0.75, 1.65)
		var scaled_basis := Basis.IDENTITY.scaled(Vector3.ONE * scale_value)
		trunks.append(Transform3D(scaled_basis, Vector3(x, ground + 3.5 * scale_value, z)))
		crowns.append(Transform3D(scaled_basis, Vector3(x, ground + 8 * scale_value, z)))
		tops.append(Transform3D(scaled_basis, Vector3(x, ground + 11.4 * scale_value, z)))
	var trunk := CylinderMesh.new()
	trunk.bottom_radius = 0.6
	trunk.top_radius = 0.4
	trunk.height = 7
	trunk.radial_segments = 5
	trunk.rings = 1
	var crown := CylinderMesh.new()
	crown.bottom_radius = 4.6
	crown.top_radius = 0
	crown.height = 11
	crown.radial_segments = 6
	crown.rings = 1
	var top := CylinderMesh.new()
	top.bottom_radius = 3.3
	top.top_radius = 0
	top.height = 7
	top.radial_segments = 6
	top.rings = 1
	_multimesh(trunk, mats["trunk"], trunks)
	_multimesh(crown, mats["leaf"], crowns)
	_multimesh(top, mats["leaf_light"], tops)

func _make_landmarks() -> void:
	# Landmark lighthouse on the northeastern headland, clear of all gates.
	var lighthouse_pos := Vector3(364, terrain_height(364, -620), -620)
	_cylinder(self, lighthouse_pos + Vector3(0, 1, 0), 14, 14, 2, "rock", 10)
	_cylinder(self, lighthouse_pos + Vector3(0, 13, 0), 5.4, 4.0, 25, "white", 10)
	_cylinder(self, lighthouse_pos + Vector3(0, 14, 0), 4.8, 4.6, 5, "red", 10)
	_cylinder(self, lighthouse_pos + Vector3(0, 26, 0), 6.1, 6.1, 1.5, "dark", 10)
	_cylinder(self, lighthouse_pos + Vector3(0, 28, 0), 4, 4, 3, "glass", 8)
	_cylinder(self, lighthouse_pos + Vector3(0, 30.5, 0), 6.1, 0.2, 3, "red", 10)
	# A calm anchorage with a simple jetty and two small sailboats.
	_box(self, Vector3(548, -1.1, 87), Vector3(70, 1.3, 7), "trunk")
	for x in [520.0, 540.0, 560.0, 580.0]:
		_cylinder(self, Vector3(x, -1, 84), 0.7, 0.7, 7, "trunk", 6)
		_cylinder(self, Vector3(x, -1, 90), 0.7, 0.7, 7, "trunk", 6)
	_sailboat(Vector3(650, -3.5, -70), 0.5)
	_sailboat(Vector3(850, -3.5, 140), -0.4)
	# A few scattered, low cottages establish the island scale without clutter.
	for i in 12:
		var x: float = 220 + float(i % 3) * 33.0 + rng.randf_range(-4, 4)
		var z: float = 230 + float(i / 3) * 40.0
		var y: float = terrain_height(x, z)
		_box(self, Vector3(x, y + 3.5, z), Vector3(16, 7, 12), "wall")
		var roof := _box(self, Vector3(x, y + 7.5, z), Vector3(19, 1.5, 15), "rust")
		roof.rotation.z = 0.07
		_box(self, Vector3(x, y + 3, z - 6.05), Vector3(9, 2.3, 0.15), "glass")

func _sailboat(pos: Vector3, yaw: float) -> void:
	var boat := Node3D.new()
	boat.position = pos
	boat.rotation.y = yaw
	add_child(boat)
	var hull := _cylinder(boat, Vector3.ZERO, 3.8, 3.1, 2.5, "white", 6)
	hull.scale = Vector3(1, 1, 2.8)
	_cylinder(boat, Vector3(0, 10, 0), 0.16, 0.12, 20, "dark", 6)
	var sail_surface := SurfaceTool.new()
	sail_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in [Vector3(0, 3, 0), Vector3(0, 19, 0), Vector3(0, 3, 8)]:
		sail_surface.set_normal(Vector3.RIGHT)
		sail_surface.add_vertex(p)
	var sail := MeshInstance3D.new()
	sail.mesh = sail_surface.commit()
	var sail_mat: StandardMaterial3D = mats["white"].duplicate()
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sail.material_override = sail_mat
	boat.add_child(sail)

func _batch_static_geometry() -> void:
	# Static props share a handful of material batches instead of hundreds of draws.
	var groups: Dictionary = {}
	var candidates: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for candidate in candidates:
		var node := candidate as MeshInstance3D
		if not (node.mesh is BoxMesh or node.mesh is CylinderMesh):
			continue
		var material: Material = node.material_override
		if material == null:
			continue
		if not groups.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[material] = surface
		var surface: SurfaceTool = groups[material]
		surface.append_from(node.mesh, 0, global_transform.affine_inverse() * node.global_transform)
		node.visible = false
		node.queue_free()
	for material: Material in groups:
		var node := MeshInstance3D.new()
		var surface: SurfaceTool = groups[material]
		node.mesh = surface.commit()
		node.material_override = material
		# A clean low-poly look; distant props don't need real-time shadow passes.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
