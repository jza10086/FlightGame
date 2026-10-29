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
	game.queue_free()
	await process_frame
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
