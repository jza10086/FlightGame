extends SceneTree
## Headless session/input lifecycle checks; no screenshots or helper files required.
var failures: int = 0
var checks: int = 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)
func key(game: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	game._unhandled_key_input(event)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.model.status == "ready" and game.gates.size() == 5, "Fresh session has runway start and five optional beacons")
	check(InputMap.has_action("pitch_up") and InputMap.has_action("throttle_up"), "Keyboard flight actions registered")
	key(game, KEY_L)
	check(game.landing_mode and game.hud.landing_mode and game.model.was_airborne, "Landing practice configures approach and HUD")
	var visible_gates: int = 0
	for gate in game.gates:
		visible_gates += int(gate.visible)
	check(visible_gates == 0, "Practice removes distracting course gates")
	key(game, KEY_ESCAPE)
	var before: Vector3 = game.model.position
	game._physics_process(0.1)
	check(game.paused and game.model.position == before, "Pause freezes aircraft physics")
	key(game, KEY_ESCAPE)
	check(not game.paused, "Pause resumes without changing the session")
	key(game, KEY_C)
	check(game.wide_camera, "Camera toggle selects wide chase")
	key(game, KEY_M)
	check(game.muted, "Engine mute toggles")
	game.model.crash("test")
	key(game, KEY_R)
	check(game.model.status == "ready" and not game.landing_mode and game.gate_index == 0 and not game.paused, "Restart clears crash, practice, course and pause state")
	check(game.gates[0].visible, "Restart restores course beacons")
	check(not game.mouse_captured, "Fresh restart after a terminal state leaves cursor available")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._input(click)
	check(game.mouse_captured, "Intentional click captures mouse")
	game.capture_guard = 0.0
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(12, 8)
	game._input(motion)
	check(game.mouse_flight.pending.length() > 0, "Captured screen-relative motion reaches flight input")
	key(game, KEY_ESCAPE)
	check(not game.mouse_captured and game.mouse_flight.pending == Vector2.ZERO and game.mouse_flight.command == Vector2.ZERO, "Pause releases mouse and flushes motion")
	game._input(motion)
	check(game.mouse_flight.pending == Vector2.ZERO, "Moving cursor over settings cannot steer")
	var old_sensitivity: float = game.mouse_flight.sensitivity
	key(game, KEY_BRACKETRIGHT)
	key(game, KEY_I)
	check(game.mouse_flight.sensitivity > old_sensitivity and not game.mouse_flight.invert_y, "Pause keyboard settings change sensitivity and invert")
	key(game, KEY_ESCAPE)
	check(game.mouse_captured and game.capture_guard > 0 and game.mouse_flight.command == Vector2.ZERO, "Resume captures with neutral input and warp guard")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(game.paused and not game.mouse_captured and not game.window_focused, "Focus loss pauses and releases mouse")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(game.paused and not game.mouse_captured, "Focus return does not silently resume flight")
	key(game, KEY_ESCAPE)
	key(game, KEY_F2)
	check(not game.mouse_flight.enabled and not game.mouse_captured, "Mouse off releases cursor without removing keyboard control")
	key(game, KEY_F2)
	check(game.mouse_flight.enabled and game.mouse_captured, "Mouse on intentionally recaptures during play")
	game.mouse_flight.feed_motion(Vector2(10, 10))
	key(game, KEY_R)
	check(game.mouse_captured and game.mouse_flight.pending == Vector2.ZERO, "Restart preserves chosen capture mode but removes motion")
	game.model.crash("mouse cleanup test")
	game._physics_process(1.0 / 60.0)
	check(not game.mouse_captured and game.mouse_flight.command == Vector2.ZERO, "Crash releases captured mouse")
	game.queue_free()
	await process_frame
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
