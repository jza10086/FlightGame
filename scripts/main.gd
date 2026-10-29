extends Node3D

const Flight = preload("res://scripts/flight_model.gd")
const World = preload("res://scripts/coastal_world.gd")
const AirplaneVisual = preload("res://scripts/plane_visual.gd")
const MouseFlight = preload("res://scripts/mouse_flight_input.gd")
const HUD = preload("res://scripts/flight_hud.gd")

var model: FlightModel = Flight.new()
var plane: Node3D
var camera: Camera3D
var hud: FlightHUD
var world: Node3D
var paused: bool = false
var wide_camera: bool = false
var camera_heading: float = 0.0
var gates: Array[Node3D] = []
var gate_index: int = 0
var gate_points: Array[Vector3] = [Vector3(0, 95, -950), Vector3(380, 145, -1600), Vector3(1080, 170, -1700), Vector3(1370, 125, -700), Vector3(800, 100, 200)]
var previous_position := Vector3.ZERO
var engine_audio: AudioStreamPlayer
var muted: bool = false
var engine_volume: float = 0.0
var landing_mode: bool = false
var mouse_flight: MouseFlightInput = MouseFlight.new()
var mouse_captured: bool = false
var window_focused: bool = true
var capture_guard: float = 0.0
const FLIGHT_ACTIONS: Array[String] = ["pitch_up", "pitch_down", "bank_left", "bank_right", "yaw_left", "yaw_right", "throttle_up", "throttle_down", "brake"]

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_bind_inputs()
	_make_sky()
	world = World.new()
	add_child(world)
	plane = AirplaneVisual.new()
	add_child(plane)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.15
	camera.far = 12000.0
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	hud.model = model
	hud.mouse_flight = mouse_flight
	layer.add_child(hud)
	_make_gates()
	_make_audio()
	reset_flight()

func _bind_inputs() -> void:
	var bindings: Dictionary = {
		"pitch_up": [KEY_S, KEY_DOWN], "pitch_down": [KEY_W, KEY_UP],
		"bank_left": [KEY_A, KEY_LEFT], "bank_right": [KEY_D, KEY_RIGHT],
		"yaw_left": [KEY_Q], "yaw_right": [KEY_E],
		"throttle_up": [KEY_SHIFT], "throttle_down": [KEY_CTRL], "brake": [KEY_SPACE]
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _make_sky() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("4b94b1")
	sky_material.sky_horizon_color = Color("b7d7cf")
	sky_material.ground_bottom_color = Color("287684")
	sky_material.ground_horizon_color = Color("b7d7cf")
	sky_material.sky_curve = 0.3
	sky_material.sun_angle_max = 8.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5d6df")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("9bc6c8")
	environment.fog_light_energy = 0.7
	environment.fog_density = 0.00008
	environment.fog_sky_affect = 0.15
	var env_node := WorldEnvironment.new()
	env_node.environment = environment
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -35, 0)
	sun.light_color = Color("ffdfac")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	add_child(sun)

func _make_gates() -> void:
	for i: int in gate_points.size():
		var gate := Node3D.new()
		add_child(gate)
		gate.position = gate_points[i]
		var prior: Vector3 = gate_points[i - 1] if i > 0 else Vector3(0, 50, -500)
		gate.look_at(gate.position + (gate.position - prior).normalized())
		var torus := TorusMesh.new()
		torus.inner_radius = 44.0
		torus.outer_radius = 47.0
		torus.rings = 48
		torus.ring_segments = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ffc16c")
		material.emission_enabled = true
		material.emission = Color("cb7e34")
		material.emission_energy_multiplier = 0.25
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		torus.material = material
		var mesh := MeshInstance3D.new()
		mesh.mesh = torus
		mesh.rotation.x = PI / 2
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gate.add_child(mesh)
		gates.append(gate)
	_update_gates()

func _update_gates() -> void:
	for i: int in gates.size():
		gates[i].visible = i >= gate_index
		var mesh := gates[i].get_child(0) as MeshInstance3D
		var mat: StandardMaterial3D = mesh.mesh.material
		mat.albedo_color = Color("ffc16c") if i == gate_index else Color("8dbcb4")

func _make_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	engine_audio = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/propeller.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = 22050
	engine_audio.stream = stream
	engine_audio.volume_db = -24.0
	add_child(engine_audio)
	engine_audio.play()

func _process(dt: float) -> void:
	capture_guard = maxf(capture_guard - dt, 0.0)
	hud.mouse_captured = mouse_captured
	_update_camera(dt)
	_update_audio(dt)
	if gate_index < gate_points.size() and not landing_mode:
		var target: Vector3 = gate_points[gate_index]
		hud.marker_visible = not camera.is_position_behind(target)
		hud.marker = camera.unproject_position(target)
		hud.target_caption = "BEACON %02d  /  %d m" % [gate_index + 1, int(model.position.distance_to(target))]
	else:
		var home := Vector3(0, 4, -160)
		hud.marker_visible = not camera.is_position_behind(home)
		hud.marker = camera.unproject_position(home)
		hud.target_caption = "AIRFIELD  /  %d m" % int(model.position.distance_to(home))
	var destination: Vector3 = gate_points[gate_index] if gate_index < gate_points.size() and not landing_mode else Vector3(0, 4, -160)
	var delta_target: Vector3 = destination - model.position
	var target_bearing: float = atan2(-delta_target.x, -delta_target.z)
	var bearing_error: float = wrapf(target_bearing - model.heading, -PI, PI)
	var direction: String = "AHEAD" if absf(bearing_error) < 0.18 else ("← LEFT" if bearing_error > 0 else "RIGHT →")
	hud.navigation_hint = "%s  ·  %s  ·  %d m" % ["BEACON %02d" % (gate_index + 1) if gate_index < gate_points.size() and not landing_mode else "AIRFIELD", direction, int(delta_target.length())]

func _physics_process(dt: float) -> void:
	if paused:
		return
	var mouse_command: Vector2 = mouse_flight.sample(dt) if mouse_captured else Vector2.ZERO
	# Keyboard retains authority on its own axis, so it never fights a mouse tail.
	var keyboard_pitch: float = Input.get_axis("pitch_down", "pitch_up")
	var keyboard_roll: float = Input.get_axis("bank_left", "bank_right")
	var elevator: float = keyboard_pitch if keyboard_pitch != 0.0 else mouse_command.y
	var aileron: float = keyboard_roll if keyboard_roll != 0.0 else mouse_command.x
	var rudder: float = Input.get_axis("yaw_left", "yaw_right")
	if model.status != "crashed" and model.status != "success":
		model.throttle = clampf(model.throttle + Input.get_axis("throttle_down", "throttle_up") * dt * 0.42, 0.0, 1.0)
	var starting: bool = model.status == "ready"
	previous_position = model.position
	model.step(dt, elevator, aileron, rudder, Input.is_action_pressed("brake"),
		World.terrain_height(model.position.x, model.position.z), World.is_runway(model.position))
	if starting and model.status == "takeoff":
		hud.show_help = false
	# Sample wing tips against terrain too, rather than letting banks clip hills.
	if not model.grounded and model.status == "flying":
		for side: float in [-4.6, 4.6]:
			var wing: Vector3 = model.position + model.attitude() * Vector3(side, 0.0, 0.0)
			if wing.y < World.terrain_height(wing.x, wing.z) + 0.1:
				model.crash("Wing strike")
	plane.position = model.position
	plane.basis = model.attitude()
	plane.update_controls(dt, model.throttle, elevator, aileron, rudder, model.velocity.length())
	plane.set_crashed(model.status == "crashed")
	if model.status == "crashed" or model.status == "success":
		_release_mouse()
	if gate_index < gate_points.size() and not landing_mode and model.status == "flying":
		# A swept proximity test means a low frame rate cannot skip a beacon.
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(gate_points[gate_index], previous_position, model.position)
		if closest.distance_to(gate_points[gate_index]) < 44.0:
			gate_index += 1
			hud.gate_count = gate_index
			_update_gates()

func _update_camera(dt: float, snap: bool = false) -> void:
	if camera == null:
		return
	camera_heading = model.heading if snap else lerp_angle(camera_heading, model.heading, 1.0 - exp(-3.8 * dt))
	var flat_frame := Basis(Vector3.UP, camera_heading)
	var offset := Vector3(0, 7.5, 25.0) if not wide_camera else Vector3(0, 16.0, 48.0)
	var desired: Vector3 = model.position + flat_frame * offset
	desired.y = maxf(desired.y, World.terrain_height(desired.x, desired.z) + 4.0)
	camera.position = desired if snap else camera.position.lerp(desired, 1.0 - exp(-5.5 * dt))
	var focus: Vector3 = model.position + flat_frame * Vector3(0, 3.2, -28)
	camera.look_at(focus, Vector3.UP)

func _update_audio(dt: float) -> void:
	if engine_audio == null:
		return
	var active: bool = not paused and model.status != "crashed" and model.status != "success" and not muted
	engine_volume = lerpf(engine_volume, 0.20 + model.throttle * 0.8 if active else 0.0, minf(dt * 6.0, 1.0))
	engine_audio.volume_db = linear_to_db(maxf(engine_volume, 0.001)) - 24.0
	engine_audio.pitch_scale = 0.65 + model.throttle * 0.65

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_R:
			reset_flight()
		KEY_L:
			landing_practice()
		KEY_ESCAPE:
			if model.status != "crashed" and model.status != "success":
				_set_paused(not paused)
		KEY_F2:
			_change_mouse_option("toggle")
		KEY_I:
			_change_mouse_option("invert")
		KEY_BRACKETLEFT:
			_change_mouse_option("less")
		KEY_BRACKETRIGHT:
			_change_mouse_option("more")
		KEY_H:
			hud.show_help = not hud.show_help
		KEY_C:
			wide_camera = not wide_camera
		KEY_M:
			muted = not muted
		KEY_F11:
			var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func reset_flight() -> void:
	var restore_capture: bool = mouse_captured and model.status != "crashed" and model.status != "success"
	_release_mouse()
	_clear_flight_inputs()
	model.reset()
	landing_mode = false
	hud.landing_mode = false
	paused = false
	hud.paused = false
	gate_index = 0
	hud.gate_count = 0
	_update_gates()
	plane.position = model.position
	plane.basis = model.attitude()
	plane.set_crashed(false)
	_update_camera(1.0, true)
	if restore_capture:
		_capture_mouse()

func landing_practice() -> void:
	reset_flight()
	landing_mode = true
	hud.landing_mode = true
	for gate in gates:
		gate.visible = false
	model.position = Vector3(0, 42, 630)
	model.velocity = Vector3(0, -2.2, -36)
	model.pitch = 0.016
	model.throttle = 0.30
	model.grounded = false
	model.was_airborne = true
	model.status = "flying"
	hud.show_help = false
	plane.position = model.position
	_update_camera(1.0, true)

func _exit_tree() -> void:
	_release_mouse()
	if is_instance_valid(engine_audio):
		engine_audio.stop()
		engine_audio.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false
		if hud != null:
			_set_paused(true)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		window_focused = true

func _quit_cleanly() -> void:
	_release_mouse()
	paused = true
	if is_instance_valid(engine_audio):
		engine_audio.stop()
		engine_audio.stream = null
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if mouse_captured and not paused and window_focused and capture_guard <= 0.0:
			mouse_flight.feed_motion(event.screen_relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if paused:
			var option: String = hud.pause_mouse_option_at(event.position)
			if not option.is_empty():
				_change_mouse_option(option)
		elif not mouse_captured:
			_capture_mouse()

func _clear_flight_inputs() -> void:
	mouse_flight.clear()
	for action: String in FLIGHT_ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)

func _capture_mouse() -> void:
	if not mouse_flight.enabled or paused or not window_focused or model.status == "crashed" or model.status == "success":
		return
	_clear_flight_inputs()
	capture_guard = 0.08 # Ignore the platform's capture/warp transition, not player motion afterwards.
	mouse_captured = true
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _release_mouse() -> void:
	mouse_captured = false
	capture_guard = 0.0
	mouse_flight.clear()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _set_paused(value: bool) -> void:
	paused = value
	hud.paused = value
	_release_mouse()
	_clear_flight_inputs()
	if not paused:
		_capture_mouse()

func _change_mouse_option(option: String) -> void:
	match option:
		"toggle":
			mouse_flight.enabled = not mouse_flight.enabled
			_release_mouse()
			if not paused:
				_capture_mouse()
		"invert":
			mouse_flight.set_inverted(not mouse_flight.invert_y)
		"less":
			mouse_flight.set_sensitivity(mouse_flight.sensitivity - 0.25)
		"more":
			mouse_flight.set_sensitivity(mouse_flight.sensitivity + 0.25)
