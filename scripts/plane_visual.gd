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

func _ready() -> void:
	_propeller = %Propeller
	_left_aileron = %LeftAileron
	_right_aileron = %RightAileron
	_elevator = %Elevator
	_rudder = %Rudder
	for wheel: MeshInstance3D in find_children("Wheel*", "MeshInstance3D", true, false):
		if wheel.is_in_group("flight_wheels"):
			_wheel_meshes.append(wheel)

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
