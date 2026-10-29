class_name FlightHUD
extends Control

var model: FlightModel
var paused: bool = false
var show_help: bool = true
var gate_count: int = 0
var gate_total: int = 5
var target_caption: String = ""
var marker: Vector2 = Vector2(-100, -100)
var marker_visible: bool = false
var navigation_hint: String = ""
var landing_mode: bool = false
var compact_help: bool = false
var font: Font = ThemeDB.fallback_font
var ink := Color("ecf4ed")
var quiet := Color("b5d3cf")
var accent := Color("ffc377")
var dark := Color(0.035, 0.11, 0.15, 0.84)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _text(p: Vector2, value: String, size_px: int = 18, color: Color = ink) -> void:
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _center(p: Vector2, value: String, size_px: int = 18, color: Color = ink) -> void:
	_text(p - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5, 0), value, size_px, color)

func _panel(rect: Rect2, color: Color = dark, radius: int = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	draw_style_box(style, rect)

func _draw() -> void:
	if model == null:
		return
	var s: Vector2 = size
	var k: float = minf(s.x / 1600.0, s.y / 900.0)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * k)
	s /= k
	_text(Vector2(42, 54), "C O A S T L I N E", 26)
	_text(Vector2(43, 79), "ISLAND FLIGHT CLUB  /  TERN 01", 12, quiet)
	var heading_deg: int = int(fposmod(rad_to_deg(model.heading) * -1.0 + 180.0, 360.0))
	_text(Vector2(s.x - 204, 50), "%03d°  /  HDG" % heading_deg, 20)
	_text(Vector2(s.x - 204, 76), "%02d:%02d  FLIGHT TIME" % [int(model.flight_time) / 60, int(model.flight_time) % 60], 12, quiet)
	var banner: String = "COASTAL CIRCUIT  ·  %d / %d BEACONS" % [gate_count, gate_total]
	if model.status == "ready" or model.status == "takeoff":
		banner = "RUNWAY 18  ·  READY FOR DEPARTURE"
	elif model.status == "rollout":
		banner = "TOUCHDOWN  ·  THROTTLE IDLE + SPACE TO BRAKE"
	elif landing_mode:
		banner = "FINAL APPROACH  ·  LANDING PRACTICE"
	elif gate_count == gate_total:
		banner = "CIRCUIT COMPLETE  ·  RETURN TO THE AIRSTRIP"
	_panel(Rect2(s.x / 2 - 235, 30, 470, 40), Color(0.04, 0.13, 0.16, 0.55), 20)
	_center(Vector2(s.x / 2, 56), banner, 14)
	# Three primary readouts; no debug panel obscures the flying view.
	_panel(Rect2(40, s.y - 142, 390, 92))
	_text(Vector2(61, s.y - 114), "AIRSPEED", 12, quiet)
	_text(Vector2(61, s.y - 70), "%03d" % int(model.velocity.length() * 3.6), 36)
	_text(Vector2(137, s.y - 72), "km/h", 12, quiet)
	draw_line(Vector2(185, s.y - 120), Vector2(185, s.y - 67), Color(0.5, 0.7, 0.7, 0.25), 1)
	_text(Vector2(207, s.y - 114), "ALTITUDE / FIELD", 12, quiet)
	_text(Vector2(207, s.y - 70), "%04d" % maxi(int(model.position.y - FlightModel.GEAR_HEIGHT), 0), 36)
	_text(Vector2(308, s.y - 72), "m", 12, quiet)
	var throttle_x: float = s.x - 230
	_panel(Rect2(throttle_x, s.y - 142, 190, 92))
	_text(Vector2(throttle_x + 19, s.y - 113), "THROTTLE", 12, quiet)
	_text(Vector2(throttle_x + 111, s.y - 112), "%3d%%" % int(model.throttle * 100), 18)
	draw_rect(Rect2(throttle_x + 20, s.y - 90, 150, 8), Color("32505a"))
	draw_rect(Rect2(throttle_x + 20, s.y - 90, 150 * model.throttle, 8), accent)
	_text(Vector2(throttle_x + 20, s.y - 63), "SHIFT +     CTRL −", 12, quiet)
	var hint: String = "W/S  PITCH    A/D  BANK    Q/E  RUDDER    SPACE  BRAKE    C  CAMERA    H  HELP    ESC  PAUSE"
	_panel(Rect2(s.x / 2 - 480, s.y - 42, 960, 30), Color(0.035, 0.11, 0.15, 0.6), 15)
	_center(Vector2(s.x / 2, s.y - 22), hint, 12, quiet)
	var instruction: String = ""
	if model.status == "ready" or model.status == "takeoff":
		instruction = "Hold SHIFT for power. At 100 km/h, tap S or ↓ to raise the nose."
	elif model.status == "rollout":
		instruction = "A smooth arrival. Hold CTRL to idle, then SPACE to stop on the runway."
	elif not model.grounded and model.velocity.length() < 27.0:
		instruction = "LOW AIRSPEED  ·  Nose down (W / ↑) and add power"
	elif not model.grounded and absf(model.aoa) > deg_to_rad(18.0):
		instruction = "STALL  ·  Ease the nose down (W / ↑) to regain airflow"
	elif landing_mode:
		instruction = "CTRL toward idle · 110–150 km/h · S to flare · SPACE after touchdown"
	elif gate_count == gate_total:
		instruction = "Land in either runway direction: 110–150 km/h, wings level, descend gently."
	if not instruction.is_empty():
		_panel(Rect2(s.x / 2 - 335, s.y - 128, 670, 45), Color(0.035, 0.11, 0.15, 0.74), 22)
		_center(Vector2(s.x / 2, s.y - 99), instruction, 15, accent)
	if marker_visible and model.status == "flying":
		var m: Vector2 = marker / k
		if m.x > 45 and m.x < s.x - 45 and m.y > 110 and m.y < s.y - 170:
			draw_arc(m, 13, 0, TAU, 24, accent, 2, true)
			draw_circle(m, 2, accent)
			_center(m + Vector2(0, -25), target_caption, 13, accent)
	if model.status == "flying":
		_panel(Rect2(s.x / 2 - 185, 80, 370, 31), Color(0.035, 0.11, 0.15, 0.55), 15)
		_center(Vector2(s.x / 2, 101), navigation_hint, 12, quiet)
	# Short dash as an unobtrusive flight reference.
	if not model.grounded:
		var c := Vector2(s.x * 0.5, s.y * 0.48)
		draw_line(c + Vector2(-24, 0), c + Vector2(-8, 0), Color(1, 1, 1, 0.55), 2, true)
		draw_line(c + Vector2(8, 0), c + Vector2(24, 0), Color(1, 1, 1, 0.55), 2, true)
		draw_circle(c, 2, Color(1, 1, 1, 0.7))
	if show_help and model.status == "ready":
		_panel(Rect2(s.x / 2 - 275, 104, 550, 126), Color(0.035, 0.11, 0.15, 0.78))
		_center(Vector2(s.x / 2, 138), "A LITTLE AIRPLANE. A WHOLE COAST TO EXPLORE.", 16, accent)
		_center(Vector2(s.x / 2, 168), "Fly the five coastal beacons, or simply make your own route.", 16)
		_center(Vector2(s.x / 2, 197), "Come home, touch down gently, and stop to complete your flight.", 14, quiet)
		_center(Vector2(s.x / 2, 218), "No timer. No combat. Just flying.   ·   H to hide help", 12, quiet)
	elif show_help and model.status == "flying":
		_panel(Rect2(40, 104, 365, 118), Color(0.035, 0.11, 0.15, 0.7))
		_text(Vector2(59, 135), "FLIGHT NOTES", 13, accent)
		_text(Vector2(59, 162), "Small inputs. Bank to turn; release to level.", 14)
		_text(Vector2(59, 186), "Idle still glides — keep your speed up.", 14)
		_text(Vector2(59, 208), "L: landing practice   R: restart   M: mute", 13, quiet)
	if paused or model.status == "crashed" or model.status == "success":
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.07, 0.10, 0.45))
		_panel(Rect2(s.x / 2 - 290, s.y / 2 - 115, 580, 230), Color(0.035, 0.11, 0.15, 0.96), 18)
		var title: String = "FLIGHT PAUSED"
		var body: String = "Take a breath. The coast can wait."
		var action: String = "ESC  RESUME    ·    R  RESTART    ·    L  LANDING PRACTICE"
		if model.status == "crashed":
			title = "LET’S TRY THAT AGAIN"
			body = model.crash_reason
			action = "R  NEW DEPARTURE    ·    L  LANDING PRACTICE"
		elif model.status == "success":
			title = "WELCOME HOME, PILOT"
			body = "Safe landing · %d / %d beacons · %.1f km flown" % [gate_count, gate_total, model.distance_flown / 1000.0]
			action = "R  FLY AGAIN    ·    L  PRACTISE ANOTHER LANDING"
		_center(Vector2(s.x / 2, s.y / 2 - 57), title, 27, accent)
		_center(Vector2(s.x / 2, s.y / 2 - 11), body, 17)
		if model.status == "success":
			_center(Vector2(s.x / 2, s.y / 2 + 23), "Touchdown descent  %.1f m/s" % model.touchdown_sink, 14, quiet)
		_center(Vector2(s.x / 2, s.y / 2 + 72), action, 13, quiet)
