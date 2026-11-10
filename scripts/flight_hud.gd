class_name FlightHUD
extends Control

const MouseFlightInputScript = preload("res://games/minigame/gp_flight/scripts/mouse_flight_input.gd")

const FlightModelScript = preload("res://games/minigame/gp_flight/scripts/flight_model.gd")

var model: FlightModelScript
var paused: bool = false
var formal: bool = false
var mouse_flight: MouseFlightInputScript
var mouse_captured: bool = false
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

const DefaultText: Translation = preload("res://games/minigame/gp_flight/i18n/zh_Hans.po")
var i18n: RefCounted

func _text_value(key: StringName, values: Dictionary) -> String:
	return DefaultText.get_message(key).format(values) if i18n == null else i18n.text(key, values)

func _process(_delta: float) -> void:
	if model == null:
		return
	var heading: int = int(fposmod(rad_to_deg(model.heading) * -1.0 + 180.0, 360.0))
	%Heading.text = _text_value(&"hud.heading", {"degrees": "%03d" % heading})
	%Clock.text = _text_value(&"hud.clock", {"time": "%02d:%02d" % [int(model.flight_time) / 60, int(model.flight_time) % 60]})
	%Speed.text = _text_value(&"hud.speed", {"speed": "%03d" % int(model.velocity.length() * 3.6)})
	%Altitude.text = _text_value(&"hud.altitude", {"height": "%04d" % maxi(int(model.position.y - FlightModelScript.GEAR_HEIGHT), 0)})
	%ThrottleBar.value = model.throttle * 100.0
	%Throttle.text = _text_value(&"hud.throttle", {"percent": int(model.throttle * 100)})
	var banner: String = _text_value(&"hud.circuit", {"current": gate_count, "total": gate_total})
	if model.status == "ready" or model.status == "takeoff":
		banner = "RUNWAY 18  ·  READY FOR DEPARTURE"
	elif model.status == "rollout":
		banner = "TOUCHDOWN  ·  THROTTLE IDLE + SPACE TO BRAKE"
	elif landing_mode:
		banner = "FINAL APPROACH  ·  LANDING PRACTICE"
	elif gate_count == gate_total:
		banner = "CIRCUIT COMPLETE  ·  RETURN TO THE AIRSTRIP"
	%Banner.text = banner
	var hint: String = "MOUSE  PITCH / ROLL    W/S A/D  BACKUP    Q/E  RUDDER    SPACE  BRAKE    C  CAMERA    H  HELP    ESC  SETTINGS"
	if mouse_flight != null and not mouse_flight.enabled:
		hint = "KEYBOARD MODE    W/S  PITCH    A/D  BANK    Q/E  RUDDER    SPACE  BRAKE    F2  MOUSE ON    ESC  SETTINGS"
	%Keys.text = _text_value(&"hud.formal_controls", {}) if formal else hint
	var instruction: String = ""
	if model.status == "ready" or model.status == "takeoff":
		instruction = "Hold SHIFT for power. At 100 km/h, tap S or ↓ to raise the nose."
		if mouse_flight != null and mouse_flight.enabled:
			if not mouse_captured:
				instruction = "CLICK TO CAPTURE MOUSE  ·  Pitch / roll with mouse  ·  ESC releases"
			else:
				instruction = "SHIFT for power. At 100 km/h, gently move mouse %s to lift off." % ("down" if mouse_flight.invert_y else "up")
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
	if model.status == "flying" and not paused and mouse_flight != null and mouse_flight.enabled and not mouse_captured:
		instruction = "CLICK TO CAPTURE MOUSE  ·  Keyboard controls still available  ·  ESC settings"
	%Prompt.visible = not instruction.is_empty()
	%Instruction.text = _text_value(&"hud.formal_capture", {}) if formal and not mouse_captured and mouse_flight.enabled and model.status in ["ready", "takeoff", "flying"] else instruction
	%Navigation.visible = model.status == "flying"
	%Navigation.text = navigation_hint
	%Help.visible = show_help and model.status == "ready"
	%Notes.visible = show_help and model.status == "flying"
	%Result.visible = model.status in ["crashed", "success"]
	%Menu.visible = paused and not %Result.visible
	if %Menu.visible:
		%Toggle.text = "F2  MOUSE " + ("ON" if mouse_flight.enabled else "OFF")
		%Invert.text = "I  " + ("PULL DOWN = UP" if mouse_flight.invert_y else "MOVE UP = UP")
		%Sensitivity.text = _text_value(&"hud.sensitivity", {"value": "%.2f" % mouse_flight.sensitivity})
	if %Result.visible:
		%ResultTitle.text = "LET’S TRY THAT AGAIN" if model.status == "crashed" else "WELCOME HOME, PILOT"
		%ResultText.text = model.crash_reason if model.status == "crashed" else _text_value(&"hud.landing", {"current":gate_count, "total":gate_total, "distance":"%.1f" % (model.distance_flown / 1000.0)})
		%Sink.visible = model.status == "success"
		%Sink.text = _text_value(&"hud.sink", {"speed":"%.1f" % model.touchdown_sink})
	queue_redraw()

func _draw() -> void:
	if model == null:
		return
	var k: float = minf(size.x / 1600.0, size.y / 900.0)
	var s: Vector2 = size / k
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * k)
	if marker_visible and model.status == "flying":
		var m: Vector2 = marker / k
		if m.x > 45 and m.x < s.x - 45 and m.y > 110 and m.y < s.y - 170:
			draw_arc(m, 13, 0, TAU, 24, accent, 2, true)
			draw_circle(m, 2, accent)
			draw_string(font, m + Vector2(-120, -25), target_caption, HORIZONTAL_ALIGNMENT_CENTER, 240, 13, accent)
	# Short dash as an unobtrusive flight reference.
	if not model.grounded:
		var c := Vector2(s.x * 0.5, s.y * 0.48)
		draw_line(c + Vector2(-24, 0), c + Vector2(-8, 0), Color(1, 1, 1, 0.55), 2, true)
		draw_line(c + Vector2(8, 0), c + Vector2(24, 0), Color(1, 1, 1, 0.55), 2, true)
		draw_circle(c, 2, Color(1, 1, 1, 0.7))

func pause_mouse_option_at(point: Vector2) -> String:
	if not %Menu.visible:
		return ""
	for button: Button in [%Toggle, %Invert, %Less, %More]:
		if button.get_global_rect().has_point(point):
			return str(button.name).to_lower()
	return ""
