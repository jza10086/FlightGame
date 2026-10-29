extends SceneTree
## Run: godot --headless --path . --script tests/flight_model_test.gd
const F = preload("res://scripts/flight_model.gd")
const W = preload("res://scripts/coastal_world.gd")
var checks: int = 0
var failures: int = 0
func check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + title)
	else:
		print("PASS: " + title)
func tick(f: FlightModel, elevator: float = 0.0, aileron: float = 0.0, rudder: float = 0.0, brake: bool = false) -> void:
	f.step(1.0 / 60.0, elevator, aileron, rudder, brake, W.terrain_height(f.position.x, f.position.z), W.is_runway(f.position))
func airborne(pos: Vector3, vel: Vector3, pitch_value: float = 0.0) -> FlightModel:
	var f := F.new()
	f.position = pos
	f.velocity = vel
	f.pitch = pitch_value
	f.grounded = false
	f.was_airborne = true
	f.status = "flying"
	return f
func _initialize() -> void:
	var f := F.new()
	for i in 600:
		tick(f)
	check(f.velocity.length() < 0.01 and f.position.is_equal_approx(Vector3(0, 1.05, 130)), "Idle stays parked")
	f.throttle = 1.0
	for i in 1080:
		var elevator: float = 0.65 if f.velocity.length() > 29.0 and f.pitch < 0.15 else 0.0
		tick(f, elevator)
	check(f.was_airborne and f.position.y > 35.0 and f.status == "flying", "Full-power runway roll, rotation and climb")
	check(f.position.z > -500, "Takeoff clears ground within runway length")
	var before_x: float = f.position.x
	for i in 360:
		tick(f, 0, 0.6 if i < 100 else 0.0)
	check(f.position.x > before_x + 20.0 and f.heading < -0.1, "Right bank produces right turn")
	var glide := airborne(Vector3(0, 600, -1500), Vector3(0, 0, -45), 0.04)
	for i in 1800:
		tick(glide)
	check(glide.position.y < 570 and glide.position.y > 0 and glide.velocity.length() > 20, "Idle glides and loses altitude; no hover")
	var no_speed := airborne(Vector3(0, 400, -1200), Vector3.ZERO, 0.0)
	no_speed.throttle = 1.0
	for i in 120:
		tick(no_speed)
	check(no_speed.position.y < 390, "Full thrust without airspeed cannot hover")
	var normal := airborne(Vector3(0, 400, -1500), Vector3(0, 0, -40), 0.18)
	var stalled := airborne(Vector3(0, 400, -1500), Vector3(0, 0, -40), 0.62)
	tick(normal, 0.001)
	tick(stalled, 0.001)
	check(stalled.stalled and stalled.lift_acceleration < normal.lift_acceleration * 0.6, "Excessive AoA collapses lift")
	var recover := airborne(Vector3(0, 800, -1500), Vector3(0, 0, -29), 0.55)
	recover.throttle = 1.0
	for i in 420:
		tick(recover, -0.5 if recover.pitch > -0.1 else 0.0)
	check(not recover.stalled and recover.velocity.length() > 30.0, "Nose-down + power recovers airflow")
	var land := airborne(Vector3(0, 1.12, 80), Vector3(0, -1.7, -34), 0.08)
	for i in 8:
		tick(land)
	check(land.status == "rollout" and land.grounded, "Gentle aligned landing enters rollout")
	for i in 420:
		tick(land, 0, 0, 0, true)
	check(land.status == "success", "Idle and wheel brake complete safe landing")
	var approach := airborne(Vector3(0, 42, 630), Vector3(0, -2.2, -36), 0.016)
	approach.throttle = 0.30
	for i in 1500:
		approach.throttle = maxf(approach.throttle - 0.42 / 60.0, 0.0)
		tick(approach, 0, 0, 0, true)
	check(approach.status == "success", "Practice approach: ordinary idle + brake lands and stops")
	var hard := airborne(Vector3(0, 1.1, 80), Vector3(0, -8, -35), 0.0)
	tick(hard)
	check(hard.status == "crashed", "Hard impact crashes")
	var water := airborne(Vector3(900, -2.93, -600), Vector3(0, -3, -35), 0.0)
	tick(water)
	check(water.status == "crashed", "Water contact crashes")
	var banked := airborne(Vector3(0, 1.1, 50), Vector3(0, -2, -32), 0.08)
	banked.roll = 0.4
	tick(banked)
	check(banked.status == "crashed", "Banked touchdown rejects wing strike")
	for i in 10:
		hard.reset()
		hard.throttle = 1.0
		tick(hard)
		hard.crash("test")
		hard.reset()
	check(hard.status == "ready" and hard.throttle == 0 and hard.velocity == Vector3.ZERO and not hard.was_airborne, "Repeated reset clears all flight outcomes")
	print("RESULT: %d / %d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
