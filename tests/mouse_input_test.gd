extends SceneTree
## Relative-mouse response tests, independent of a display server or a mouse device.
const MouseInput = preload("res://scripts/mouse_flight_input.gd")
var checks: int = 0
var failures: int = 0

func check(ok: bool, title: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func integrated_response(ticks_per_second: int) -> Vector2:
	var input := MouseInput.new()
	input.feed_motion(Vector2(2.0, 3.0))
	var integral := Vector2.ZERO
	var dt: float = 1.0 / float(ticks_per_second)
	for i in ticks_per_second:
		integral += input.sample(dt) * dt
	return integral

func _initialize() -> void:
	var input := MouseInput.new()
	input.feed_motion(Vector2(4.0, 5.0))
	var output: Vector2 = input.sample(1.0 / 60.0)
	check(output.x > 0.0 and output.y > 0.0, "Right mouse rolls right; default pull-down pitches up")
	input.clear()
	input.set_inverted(false)
	input.feed_motion(Vector2(4.0, 5.0))
	output = input.sample(1.0 / 60.0)
	check(output.x > 0.0 and output.y < 0.0, "Invert toggle changes only the vertical axis")

	var low := MouseInput.new()
	var high := MouseInput.new()
	low.set_sensitivity(0.5)
	high.set_sensitivity(1.0)
	low.feed_motion(Vector2(1.0, 1.0))
	high.feed_motion(Vector2(1.0, 1.0))
	check((high.sample(1.0 / 60.0) - low.sample(1.0 / 60.0) * 2.0).length() < 0.00001, "Sensitivity scales unsaturated response")

	var split := MouseInput.new()
	var batch := MouseInput.new()
	split.feed_motion(Vector2(0.5, 1.0))
	split.feed_motion(Vector2(1.0, 1.5))
	batch.feed_motion(Vector2(1.5, 2.5))
	check((split.sample(1.0 / 60.0) - batch.sample(1.0 / 60.0)).length() < 0.00001, "Same motion batched or split gives the same response")
	var response_30: Vector2 = integrated_response(30)
	var response_60: Vector2 = integrated_response(60)
	var response_120: Vector2 = integrated_response(120)
	check((response_30 - response_60).length() < 0.0001 and (response_60 - response_120).length() < 0.0001, "Integrated response agrees at 30 / 60 / 120 Hz")

	input = MouseInput.new()
	input.feed_motion(Vector2(50, 50))
	for i in 42:
		output = input.sample(1.0 / 60.0)
	check(output.length() < 0.01, "Stopped mouse decays to neutral within 0.7 seconds")
	input.feed_motion(Vector2(10, -10))
	input.sample(1.0 / 60.0)
	input.feed_motion(Vector2(10, -10))
	input.clear()
	check(input.sample(1.0 / 60.0) == Vector2.ZERO and input.command == Vector2.ZERO and input.pending == Vector2.ZERO, "Clear discards both buffered motion and decaying command")

	input.feed_motion(Vector2(100000.0, -100000.0))
	output = input.sample(1.0 / 60.0)
	check(is_finite(output.x) and is_finite(output.y) and absf(output.x) <= 1.0 and absf(output.y) <= 1.0, "Extreme relative motion remains finite and clamped")
	input.enabled = false
	input.feed_motion(Vector2(20, 20))
	check(input.sample(1.0 / 60.0) == Vector2.ZERO, "Disabled mouse produces no command")
	input.enabled = true
	check(input.sample(1.0 / 60.0) == Vector2.ZERO, "Re-enabling cannot replay disabled motion")
	input.set_sensitivity(-100.0)
	check(input.sensitivity > 0.0 and input.sensitivity <= 0.5, "Sensitivity has a safe positive lower bound")
	input.set_sensitivity(100.0)
	check(input.sensitivity >= 1.0 and input.sensitivity <= 4.0, "Sensitivity has a bounded maximum")

	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
