extends RefCounted
## Local bindings shared by formal input and F6 defaults. Reading does not persist them.
static func schema() -> Dictionary:
	var fields: Dictionary = {
		"flight_pitch_up": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_S, "physical": true}, {"kind": "key", "code": KEY_DOWN, "physical": true}],
			"title": "抬头", "action": "flight_pitch_up", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_pitch_down": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_W, "physical": true}, {"kind": "key", "code": KEY_UP, "physical": true}],
			"title": "低头", "action": "flight_pitch_down", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_bank_left": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_A, "physical": true}, {"kind": "key", "code": KEY_LEFT, "physical": true}],
			"title": "向左滚转", "action": "flight_bank_left", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_bank_right": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_D, "physical": true}, {"kind": "key", "code": KEY_RIGHT, "physical": true}],
			"title": "向右滚转", "action": "flight_bank_right", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_yaw_left": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_Q, "physical": true}],
			"title": "左方向舵", "action": "flight_yaw_left", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_yaw_right": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_E, "physical": true}],
			"title": "右方向舵", "action": "flight_yaw_right", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_throttle_up": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_SHIFT, "physical": true}],
			"title": "增加油门", "action": "flight_throttle_up", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_throttle_down": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_CTRL, "physical": true}],
			"title": "减少油门", "action": "flight_throttle_down", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_brake": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_SPACE, "physical": true}],
			"title": "刹车", "action": "flight_brake", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_reset": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_R, "physical": true}],
			"title": "重新起飞", "action": "flight_reset", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_landing": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_L, "physical": true}],
			"title": "着陆练习", "action": "flight_landing", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_mouse": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_F2, "physical": true}],
			"title": "鼠标操纵开关", "action": "flight_mouse", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_invert": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_I, "physical": true}],
			"title": "反转鼠标", "action": "flight_invert", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_less": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_BRACKETLEFT, "physical": true}],
			"title": "降低灵敏度", "action": "flight_less", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_more": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_BRACKETRIGHT, "physical": true}],
			"title": "提高灵敏度", "action": "flight_more", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_help": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_H, "physical": true}],
			"title": "操作说明", "action": "flight_help", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_camera": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_C, "physical": true}],
			"title": "切换相机", "action": "flight_camera", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_mute": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_M, "physical": true}],
			"title": "声音开关", "action": "flight_mute", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"flight_capture": {"type": "array", "control": "binding", "default": [{"kind": "mouse", "code": MOUSE_BUTTON_LEFT}],
			"title": "捕获鼠标", "action": "flight_capture", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false}
	}
	var layout: Array[Dictionary] = []
	for key: String in fields:
		layout.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}
