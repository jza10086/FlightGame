class_name MouseFlightInput
extends RefCounted
## Relative-motion flight input, not an absolute cursor / virtual joystick.
## x = right roll, y = nose up. Pixel impulses are filtered in continuous time.
const RESPONSE_SECONDS: float = 0.10
const GAIN: float = 0.006
const MAX_COMMAND_MEMORY: float = 2.0
var enabled: bool = true
var invert_y: bool = true
var sensitivity: float = 1.0
var pending := Vector2.ZERO
var command := Vector2.ZERO

func feed_motion(delta: Vector2) -> void:
	if not enabled or not delta.is_finite():
		return
	pending += Vector2(delta.x, delta.y if invert_y else -delta.y) * GAIN * sensitivity / RESPONSE_SECONDS

func sample(dt: float) -> Vector2:
	if not enabled:
		clear()
		return Vector2.ZERO
	if dt <= 0.0 or not is_finite(dt):
		return Vector2.ZERO
	command += pending
	pending = Vector2.ZERO
	command = command.clamp(Vector2.ONE * -MAX_COMMAND_MEMORY, Vector2.ONE * MAX_COMMAND_MEMORY)
	var decay: float = exp(-dt / RESPONSE_SECONDS)
	# Exact average of the exponential over this step: response doesn't scale with FPS.
	var output: Vector2 = command * (1.0 - decay) * RESPONSE_SECONDS / dt
	command *= decay
	if command.length_squared() < 0.000001:
		command = Vector2.ZERO
	return output.clamp(-Vector2.ONE, Vector2.ONE)

func clear() -> void:
	pending = Vector2.ZERO
	command = Vector2.ZERO

func set_sensitivity(value: float) -> void:
	if is_finite(value):
		sensitivity = clampf(value, 0.25, 3.0)
	clear()

func set_inverted(value: bool) -> void:
	invert_y = value
	clear()
