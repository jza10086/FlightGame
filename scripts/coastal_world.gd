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
