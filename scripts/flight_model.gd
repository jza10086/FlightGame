class_name FlightModel
extends RefCounted
## An original, intentionally forgiving fixed-wing model, in metres / seconds.
## Attitude is pilot-controlled; velocity is integrated from aerodynamic forces.
## There is no altitude lock, forward-speed floor, or thrust vectoring.

const MASS: float = 850.0
const WING_AREA: float = 16.2
const AIR_DENSITY: float = 1.225
const GEAR_HEIGHT: float = 1.05
const ROTATION_SPEED: float = 27.0
const STALL_SPEED: float = 24.0

var position := Vector3(0.0, GEAR_HEIGHT, 130.0)
var velocity := Vector3.ZERO
var pitch: float = 0.0
var roll: float = 0.0
var heading: float = 0.0
var throttle: float = 0.0
var aoa: float = 0.0
var lift_acceleration: float = 0.0
var stalled: bool = false
var grounded: bool = true
var was_airborne: bool = false
var status: String = "ready"
var crash_reason: String = ""
var touchdown_sink: float = 0.0
var flight_time: float = 0.0
var distance_flown: float = 0.0

func reset() -> void:
	position = Vector3(0.0, GEAR_HEIGHT, 130.0)
	velocity = Vector3.ZERO
	pitch = 0.0
	roll = 0.0
	heading = 0.0
	throttle = 0.0
	aoa = 0.0
	lift_acceleration = 0.0
	stalled = false
	grounded = true
	was_airborne = false
	status = "ready"
	crash_reason = ""
	touchdown_sink = 0.0
	flight_time = 0.0
	distance_flown = 0.0

func attitude() -> Basis:
	return Basis.from_euler(Vector3(pitch, heading, roll))

func step(dt: float, elevator: float, aileron: float, rudder: float, brake: bool,
		ground_height: float, runway: bool) -> void:
	if status == "crashed" or status == "success":
		return
	var speed: float = velocity.length()
	var authority: float = clampf(speed / 32.0, 0.0, 1.0)
	var prior_grounded: bool = grounded
	if grounded:
		# Nosewheel steering is intentionally limited at high ground speed.
		heading -= (rudder + aileron * 0.45) * 0.45 * clampf(speed / 7.0, 0.0, 1.0) * dt
		roll = move_toward(roll, 0.0, dt)
		if speed > ROTATION_SPEED:
			pitch = clampf(pitch + elevator * 0.30 * dt, 0.0, 0.24)
		else:
			pitch = move_toward(pitch, 0.0, dt * 0.35)
	else:
		roll = clampf(roll - aileron * 0.95 * authority * dt, -1.1, 1.1)
		if absf(aileron) < 0.01:
			roll = move_toward(roll, 0.0, dt * 0.18)
		pitch = clampf(pitch + elevator * 0.30 * authority * dt, -0.65, 0.78)
		var flight_path: float = atan2(velocity.y, maxf(Vector2(velocity.x, velocity.z).length(), 0.1))
		var q_per_mass: float = 0.5 * AIR_DENSITY * speed * speed * WING_AREA / MASS
		var trim_aoa: float = clampf((9.81 / maxf(q_per_mass * cos(roll), 0.1) - 0.32) / 4.4, -0.03, 0.14)
		if absf(elevator) < 0.01:
			# Gentle trim reduces keyboard workload, but cannot prevent a stall.
			pitch = lerp(pitch, clampf(flight_path + trim_aoa, -0.65, 0.78), 1.0 - exp(-0.75 * dt))
		# Weathercock stability keeps the nose approximately into the airflow.
		var path_heading: float = atan2(-velocity.x, -velocity.z)
		heading = lerp_angle(heading, path_heading, 1.0 - exp(-1.6 * dt))
		heading -= rudder * 0.32 * authority * dt
	var frame: Basis = attitude()
	var forward: Vector3 = -frame.z
	var local_v: Vector3 = frame.inverse() * velocity
	var forward_speed: float = maxf(-local_v.z, 0.0)
	aoa = atan2(-local_v.y, maxf(forward_speed, 0.1))
	var cl: float = clampf(0.32 + 4.4 * aoa, -1.2, 1.6)
	var stall_blend: float = smoothstep(deg_to_rad(16.0), deg_to_rad(30.0), absf(aoa))
	cl *= lerp(1.0, 0.20, stall_blend)
	stalled = not grounded and (speed < STALL_SPEED or absf(aoa) > deg_to_rad(18.0))
	var dynamic_pressure: float = 0.5 * AIR_DENSITY * forward_speed * forward_speed
	lift_acceleration = dynamic_pressure * WING_AREA * cl / MASS
	var airflow: Vector3 = velocity.normalized() if speed > 0.1 else forward
	var lift_direction: Vector3 = (frame.y - airflow * frame.y.dot(airflow)).normalized()
	var drag_coefficient: float = 0.031 + 0.065 * cl * cl + stall_blend * 0.23
	var drag: Vector3 = -airflow * (0.5 * AIR_DENSITY * speed * speed * WING_AREA * drag_coefficient / MASS)
	var thrust: Vector3 = forward * throttle * 5.7 * clampf(1.0 - speed / 115.0, 0.08, 1.0)
	var side_force: Vector3 = -frame.x * local_v.x * (0.8 if grounded else 0.52)
	var acceleration: Vector3 = Vector3.DOWN * 9.81 + lift_direction * lift_acceleration + drag + thrust + side_force
	if grounded:
		var rolling_drag: float = 0.45 + (6.5 if brake else 0.0)
		var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		acceleration -= horizontal.normalized() * minf(rolling_drag, horizontal.length() / dt)
		if acceleration.y < 0.0:
			acceleration.y = 0.0
		if throttle > 0.05:
			status = "takeoff" if not was_airborne else "rollout"
	velocity += acceleration * dt
	position += velocity * dt
	var floor_y: float = ground_height + GEAR_HEIGHT
	grounded = position.y <= floor_y + 0.02 and velocity.y <= 0.0
	if position.y > floor_y + 2.0:
		was_airborne = true
		status = "flying"
	if grounded:
		if not prior_grounded:
			touchdown_sink = maxf(-velocity.y, 0.0)
			if ground_height < -2.0:
				crash("Water landing")
			elif not runway:
				crash("Off-runway landing")
			elif touchdown_sink > 3.8:
				crash("Hard landing · reduce your descent")
			elif absf(roll) > deg_to_rad(13.0) or pitch < -0.10 or pitch > 0.30:
				crash("Wing / nose strike · level before touchdown")
			elif speed > 49.0:
				crash("Landing too fast")
			elif absf(sin(heading)) > 0.30:
				crash("Cross-runway touchdown")
			elif was_airborne:
				status = "rollout"
		position.y = floor_y
		velocity.y = 0.0
		if was_airborne:
			pitch = move_toward(pitch, 0.0, dt * 0.22)
		if not runway and speed > 13.0:
			crash("Runway excursion")
		if was_airborne and status == "rollout" and speed < 3.0 and throttle < 0.1:
			status = "success"
			velocity = Vector3.ZERO
	if not grounded:
		flight_time += dt
		distance_flown += speed * dt
	if position.y > 1800.0 or Vector2(position.x, position.z).length() > 9000.0:
		crash("Outside the island flying area")

func crash(reason: String) -> void:
	status = "crashed"
	crash_reason = reason
	throttle = 0.0
	velocity = Vector3.ZERO
